#!/usr/bin/env zsh

setopt errexit nounset pipefail extendedglob

# Usage: ./update_opencode_models.sh [PROVIDER_DISPLAY_NAME] [API_ENDPOINT] [CONFIGURATION_FILE]
#
# Arguments (all optional; no defaults — omitted values are ignored):
#	PROVIDER_DISPLAY_NAME	Human-readable provider name (converted to snake_case for the key).
#	API_ENDPOINT			OpenAI-compatible API endpoint.
#	CONFIGURATION_FILE		opencode config file (default: `opencode.secret.json`).
#
# Environment variables:
#	API_KEY					API key for the CLI/env provider (optional; no default).
#	PASSWORD_STORE_DIR		Password store location (default: `$HOME/.password-store`).
#	OPENCODE_PROVIDERS_SUBPATH
#							Store subfolder holding provider entries
#							(default: `large_llanguage_model/opencode_providers`).
#
# Providers come from two sources, all handled uniformly:
#	1. CLI/env	Built from $1 (name), $2 (endpoint) and $API_KEY. Included only if at least
#				one is set; otherwise omitted.
#	2. Store	Every entry under `<PASSWORD_STORE_DIR>/<OPENCODE_PROVIDERS_SUBPATH>/**`, each in
#				the 3-field format:
#					<api-key>                       (first line)
#					provider_name: <human name>
#					url: <OpenAI-compatible endpoint>
#
# Each provider is validated; any with a missing key/name/url is warned and skipped. A provider
# whose update fails (unreachable endpoint, bad key, ...) is likewise warned and skipped.
#
# Per provider: prefer the LiteLLM-style `<endpoint>/model/info` route (rich metadata: costs,
# limits, modalities, capability flags) mapped onto opencode's model schema, keeping chat models
# only. If unavailable, fall back to the plain `<endpoint>/models` route (names only).
#
# Examples:
#	./update_opencode_models.sh
#	API_KEY=sk-xxx ./update_opencode_models.sh "OpenAI Compatible" https://api.example.com config.json

# ── Dependencies ────────────────────────────────────────────────────
for cmd (curl jq); do
	if (( ! $+commands[$cmd] )); then
		print -ru2 -- "Error: $cmd is required but not installed"
		exit 1
	fi
done

# ══ Provider producers ══════════════════════════════════════════════
# Producers emit neutral, source-agnostic records to stdout, one per line:
#	<name>\t<endpoint>\t<key>\t<source_label>
# Consumers act on these records and never touch `pass`, so any producer can
# be swapped or extracted without affecting the rest of the script.

# ── Producer: CLI arguments + API_KEY environment variable ─────────
# Emits a single record only if at least one input is set; otherwise nothing.
collect_cli_env_provider() {
	local name=${1:-} endpoint=${2:-} key=${:API_KEY:-}

	if [[ -n $name || -n $endpoint || -n $key ]]; then
		print -r -- "$name	$endpoint	$key	cli/env"
	fi
	return 0
}

# ── Producer: password store subfolder ─────────────────────────────
# Sole owner of all `pass`/store knowledge. Emits one record per entry.
collect_pass_store_providers() {
	local store=${PASSWORD_STORE_DIR:-$HOME/.password-store}
	local subpath=${OPENCODE_PROVIDERS_SUBPATH:-large_llanguage_model/opencode_providers}
	local dir=$store/$subpath

	if (( ! $+commands[pass] )) || [[ ! -d $dir ]]; then
		print -ru2 -- "Warning: 'pass' not installed or OpenCode providers directory not available; skipping password store providers"
		return 0
	fi

	# Flat listing: top-level *opencode* entries, as store-relative names.
	local entry contents api_key api_endpoint provider_name
	local -a lines
	for entry in $dir/*opencode*.gpg(-.N:t:s/.gpg//); do
		contents=$(pass show "$subpath/$entry" 2>/dev/null) || {
			print -ru2 -- "Warning: skipping '$subpath/$entry': unable to read password store entry"
			continue
		}

		lines=("${(f)contents}")
		api_key=${contents%%$'\n'*}
		api_endpoint=${${lines[(r)url:*]:-}#url:[[:space:]]##}
		provider_name=${${lines[(r)provider_name:*]:-}#provider_name:[[:space:]]##}

		print -r -- "$provider_name	$api_endpoint	$api_key	$subpath/$entry"
	done
}

# ══ Provider consumers (source-agnostic) ════════════════════════════

# ── Validate a record; warn + return non-zero when invalid ─────────
validate_provider() {
	local name=$1 endpoint=$2 key=$3 source=$4
	[[ -z $key ]]      && { print -ru2 -- "Warning: skipping '$source': missing API key"; return 1 }
	[[ -z $name ]]     && { print -ru2 -- "Warning: skipping '$source': missing provider_name"; return 1 }
	[[ -z $endpoint ]] && { print -ru2 -- "Warning: skipping '$source': missing url"; return 1 }
	return 0
}

# ── Fetch a single route into a file, printing the HTTP status code ─
fetch_route() {  # url out key
	curl -s -o "$2" -w '%{http_code}' \
		-H "Authorization: Bearer $3" \
		-H "Content-Type: application/json" \
		"$1"
}

# ── jq helper: turn a raw model id into a human-friendly display name
JQ_FORMAT_NAME='
	def format_name:
		gsub("[/_]"; "-")
		# Protect param sizes: 3-27b -> 3 27b (space, not dot)
		| gsub("(?<d1>[0-9])-(?<d2>[0-9]+b)"; "\(.d1) \(.d2)")
		# Merge remaining version digits: 3-3 -> 3.3
		| gsub("(?<d1>[0-9])-(?<d2>[0-9])"; "\(.d1).\(.d2)")
		| split("-")
		| map((.[0:1] | ascii_upcase) + (.[1:] | ascii_downcase))
		| join(" ")
		# Uppercase known acronyms
		| gsub("(?<pre>^| )Gpt(?<post> |$)"; "\(.pre)GPT\(.post)")
		| gsub("(?<pre>^| )Oss(?<post> |$)"; "\(.pre)OSS\(.post)")
		| gsub("(?<pre>^| )It(?<post> |$)"; "\(.pre)IT\(.post)")
		# Lowercase version prefix
		| gsub("(?<pre>^| )V(?<version>[0-9.]+)(?<post> |$)"; "\(.pre)v\(.version)\(.post)")
		# Uppercase parameter sizes (7b -> 7B, 120b -> 120B)
		| gsub("(?<pre>^| )(?<num>[0-9.]+)b(?<post> |$)"; "\(.pre)\(.num)B\(.post)");
'

# ── Process a single provider: fetch models and write config ───────
# Returns non-zero on failure so the caller can warn and continue.
process_provider() {
	local display=$1 endpoint=$2 key=$3 config=$4
	local provider_key fetch_mode http_code models_response new_models tmp
	integer model_count

	# Slug: lowercase, non-alphanumerics -> '_', collapse runs, trim ends.
	provider_key=${(L)display}
	provider_key=${provider_key//[^a-z0-9]/_}
	provider_key=${provider_key//_##/_}
	provider_key=${${provider_key##_}%%_}

	tmp=$(mktemp "${TMPDIR:-/tmp}/opencode_models.XXXXXX")

{
	# Rich-first: try LiteLLM-style /model/info.
	fetch_mode=basic
	print -ru2 -- "Fetching rich model metadata from: $endpoint/model/info"
	http_code=$(fetch_route "$endpoint/model/info" "$tmp" "$key")

	if [[ $http_code -ge 200 && $http_code -lt 300 ]] && jq -e '.data[0].model_info' "$tmp" &>/dev/null; then
		fetch_mode=rich
		print -ru2 -- "Using rich metadata (/model/info)"
	else
		print -ru2 -- "Rich metadata unavailable (HTTP $http_code); falling back to: $endpoint/models"
		http_code=$(fetch_route "$endpoint/models" "$tmp" "$key")
		if [[ $http_code -lt 200 || $http_code -ge 300 ]]; then
			print -ru2 -- "Error: endpoint returned HTTP $http_code"
			print -ru2 -- "$(<$tmp)"
			return 1
		fi
	fi

	models_response=$(<$tmp)

	if ! jq -e '.data' <<<"$models_response" &>/dev/null; then
		print -ru2 -- "Error: invalid response (not valid JSON or missing 'data' field)"
		print -ru2 -- "Response: $models_response"
		return 1
	fi

	# Build the models object. A single jq call branches on $mode to produce a
	# [{id, name, ...}] array, then a shared tail turns it into the final map.
	new_models=$(jq --arg mode "$fetch_mode" "
		$JQ_FORMAT_NAME
		def to_num: if type == \"string\" then (tonumber // 0) else (. // 0) end;
		def fmt: ((to_num * 1000000 * 10000 | floor) / 10000);

		def rich:
			# Keep chat models only (null/missing mode treated as chat)
			map(select((.model_info.mode // \"chat\") == \"chat\"))
			| map(
				.model_name as \$name
				| (.model_info // {}) as \$info
				|
				([\"text\"]
					+ (if \$info.supports_vision then [\"image\"] else [] end)
					+ (if \$info.supports_audio_input then [\"audio\"] else [] end)
					+ (if \$info.supports_pdf_input then [\"pdf\"] else [] end)) as \$input_mod
				| ([\"text\"] + (if \$info.supports_audio_output then [\"audio\"] else [] end)) as \$output_mod
				|
				({}
					| (if \$info.input_cost_per_token != null then .input = (\$info.input_cost_per_token | fmt) else . end)
					| (if \$info.output_cost_per_token != null then .output = (\$info.output_cost_per_token | fmt) else . end)
					| (if \$info.cache_read_input_token_cost != null then .cache_read = (\$info.cache_read_input_token_cost | fmt) else . end)
					| (if \$info.cache_creation_input_token_cost != null then .cache_write = (\$info.cache_creation_input_token_cost | fmt) else . end)
				) as \$cost
				|
				({}
					| (if \$info.max_input_tokens != null then .context = \$info.max_input_tokens | .input = \$info.max_input_tokens
					   elif \$info.max_tokens != null then .context = \$info.max_tokens else . end)
					| (if \$info.max_output_tokens != null then .output = \$info.max_output_tokens
					   elif \$info.max_tokens != null then .output = \$info.max_tokens else . end)
				) as \$limit
				|
				((\$info.supports_function_calling == true) or (\$info.supports_tool_choice == true)) as \$tool_call
				| (\$info.supports_reasoning == true) as \$reasoning
				| ((\$info.supports_vision == true) or (\$info.supports_pdf_input == true) or (\$info.supports_audio_input == true)) as \$attachment
				|
				{
					id: \$name,
					name: (\$name | format_name),
					modalities: {input: \$input_mod, output: \$output_mod},
					tool_call: \$tool_call,
					reasoning: \$reasoning,
					attachment: \$attachment
				}
				+ (if (\$cost | length) > 0 then {cost: \$cost} else {} end)
				+ (if (\$limit | length) > 0 then {limit: \$limit} else {} end)
				# temperature: only assert false when LiteLLM explicitly says so
				+ (if \$info.supports_temperature == false then {temperature: false} else {} end)
				# reasoning models get low/high effort variants
				+ (if \$reasoning then {variants: {low: {reasoningEffort: \"low\"}, high: {reasoningEffort: \"high\"}}} else {} end)
			);

		def basic: map({id: .id, name: (.id | format_name)});

		.data
		| (if \$mode == \"rich\" then rich else basic end)
		| sort_by(.name)
		| map({(.id): (del(.id))})
		| add // {}
	" <<<"$models_response")

	model_count=$(jq 'length' <<<"$new_models")
	(( model_count == 0 )) && print -ru2 -- "Warning: no models found at endpoint — writing empty provider"

	# Write configuration atomically.
	jq --tab \
		--argjson new_models "$new_models" \
		--arg provider "$provider_key" \
		--arg display_name "$display" \
		--arg base_url "$endpoint" \
		'.provider[$provider].models = $new_models |
		 .provider[$provider].name = $display_name |
		 .provider[$provider].npm = "@ai-sdk/openai-compatible" |
		 .provider[$provider].options = ((.provider[$provider].options // {}) + {"baseURL": $base_url})' \
		"$config" > "$config.tmp"
	mv "$config.tmp" "$config"

	print -ru2 -- "Successfully updated provider: $display ($model_count models, $fetch_mode metadata)"

	if (( model_count > 0 )); then
		print -ru2 -- "Models:"
		jq -r --arg provider "$provider_key" '
			.provider[$provider].models | to_entries[]
			| .value as $m
			| ([ (if $m.tool_call then "tools" else empty end),
				 (if $m.reasoning then "reasoning" else empty end),
				 (if ($m.modalities.input // []) | index("image") then "vision" else empty end)
			  ] | if length > 0 then " [" + join(",") + "]" else "" end) as $flags
			| "\t\($m.name) (\(.key))\($flags)"
		' "$config" >&2
	fi
} always {
	rm -f "$tmp"
}
}

# ══ Orchestration ═══════════════════════════════════════════════════
config=${3:-opencode.secret.json}

# Bootstrap config file if it doesn't exist.
if [[ ! -f $config ]]; then
	print -ru2 -- "Configuration file '$config' not found; creating it"
	jq -n --tab '{
		"$schema": "https://opencode.ai/config.json",
		"autoupdate": true,
		"provider": {}
	}' > "$config"
fi

# Collect providers from all sources and process them uniformly.
integer processed=0 total=0

while IFS= read -r record; do
	local -a f=("${(@ps:\t:)record}")
	local name=${f[1]:-} endpoint=${f[2]:-} key=${f[3]:-} source=${f[4]:-}
	(( total += 1 ))

	validate_provider "$name" "$endpoint" "$key" "$source" || continue

	if process_provider "$name" "$endpoint" "$key" "$config"; then
		(( processed += 1 ))
	else
		print -ru2 -- "Warning: failed to update provider '$name' (from $source); skipping"
	fi
done < <(
	collect_cli_env_provider "${1:-}" "${2:-}"
	collect_pass_store_providers
)

print -ru2 -- "Done: updated $processed of $total provider(s)"
