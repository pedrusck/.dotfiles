#!/usr/bin/env zsh

setopt errexit nounset pipefail

# Usage: ./update_opencode_models.sh [PROVIDER_DISPLAY_NAME] [API_ENDPOINT] [CONFIGURATION_FILE]
#
# Arguments:
#	PROVIDER_DISPLAY_NAME	Human-readable provider name (default: defined on a password store entry)
#							Will be converted to snake_case for the provider key
#	API_ENDPOINT			OpenAI-compatible API endpoint (default: defined on a password store entry)
#	CONFIGURATION_FILE		Path to opencode's configuration file (default: `opencode.secret.json`)
#
# Environment Variables:
#	API_KEY					API key for authentication (default: defined on a password store entry)
#
# Behaviour:
#	The script prefers the LiteLLM-style `<endpoint>/model/info` route, which returns rich
#	per-model metadata (costs, token limits, modalities, capability flags). It maps that data
#	onto OpenCode's model schema (cost, limit, modalities, tool_call, reasoning, attachment,
#	temperature, variants). Only chat models are kept. If `/model/info` is unavailable it falls
#	back to the plain `<endpoint>/models` route (model names only), so it still works against
#	any OpenAI-compatible endpoint.
#
# Examples:
#	./update_opencode_models.sh
#	API_KEY=sk-xxx ./update_opencode_models.sh "OpenAI Compatible" https://api.example.com config.json

# ── Dependencies ────────────────────────────────────────────────────
for cmd in curl jq; do
	if ! command -v "$cmd" &> /dev/null; then
		echo "Error: $cmd is required but not installed" >&2
		exit 1
	fi
done

# ── Environment values ──────────────────────────────────────────────
API_KEY="${API_KEY:-$(pass large_llanguage_model/opencode_key | head -n 1)}"

if [ -z "$API_KEY" ]; then
	echo "Error: API_KEY is required (set the API_KEY environment variable)" >&2
	exit 1
fi

# ── Arguments & defaults ────────────────────────────────────────────
PROVIDER_DISPLAY_NAME="${1:-$(pass large_llanguage_model/opencode_key | sed -n 's/.*provider_name:[[:space:]]*//p')}"
API_ENDPOINT="${2:-$(pass large_llanguage_model/opencode_key | sed -n 's/.*url:[[:space:]]*//p')}"
CONFIGURATION_FILE="${3:-opencode.secret.json}"

PROVIDER_KEY=$(echo "$PROVIDER_DISPLAY_NAME" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/_/g; s/__*/_/g; s/^_\|_$//g')

# ── Bootstrap config file if it doesn't exist ──────────────────────
if [ ! -f "$CONFIGURATION_FILE" ]; then
	echo "Configuration file '$CONFIGURATION_FILE' not found; creating it" >&2
	jq -n --tab '{
		"$schema": "https://opencode.ai/config.json",
		"autoupdate": true,
		"provider": {}
	}' > "$CONFIGURATION_FILE"
fi

# ── Fetch models ────────────────────────────────────────────────────
# Fetch a single route into a temp file, echoing the HTTP status code.
fetch_route() {
	local url="$1" out="$2"
	curl -s -o "$out" -w '%{http_code}' \
		-H "Authorization: Bearer $API_KEY" \
		-H "Content-Type: application/json" \
		"$url"
}

RESPONSE_TEMPORARY_FILE=$(mktemp /tmp/opencode_models.XXXXXX)
trap 'rm -f "$RESPONSE_TEMPORARY_FILE"' EXIT

# ── Rich-first: try LiteLLM-style /model/info ──────────────────────
FETCH_MODE="basic"
echo "Fetching rich model metadata from: $API_ENDPOINT/model/info" >&2
http_code=$(fetch_route "$API_ENDPOINT/model/info" "$RESPONSE_TEMPORARY_FILE")

if [ "$http_code" -ge 200 ] && [ "$http_code" -lt 300 ] \
	&& jq -e '.data[0].model_info' "$RESPONSE_TEMPORARY_FILE" > /dev/null 2>&1; then
	FETCH_MODE="rich"
	echo "Using rich metadata (/model/info)" >&2
else
	# ── Fallback: plain OpenAI-compatible /models ──────────────────
	echo "Rich metadata unavailable (HTTP $http_code); falling back to: $API_ENDPOINT/models" >&2
	http_code=$(fetch_route "$API_ENDPOINT/models" "$RESPONSE_TEMPORARY_FILE")

	if [ "$http_code" -lt 200 ] || [ "$http_code" -ge 300 ]; then
		echo "Error: endpoint returned HTTP $http_code" >&2
		cat "$RESPONSE_TEMPORARY_FILE" >&2
		exit 1
	fi
fi

models_response=$(cat "$RESPONSE_TEMPORARY_FILE")

if ! echo "$models_response" | jq -e '.data' > /dev/null 2>&1; then
	echo "Error: Invalid response (not valid JSON or missing 'data' field)" >&2
	echo "Response: $models_response" >&2
	exit 1
fi

model_count=$(echo "$models_response" | jq '.data | if type == "array" then length else 0 end')

# ── Build the models object ────────────────────────────────────────
# Shared jq helper: turn a raw model id into a human-friendly display name.
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

if [ "$model_count" -eq 0 ]; then
	echo "Warning: No models found at endpoint — writing empty provider" >&2
	new_models='{}'
elif [ "$FETCH_MODE" = "rich" ]; then
	# Map LiteLLM model_info onto OpenCode's model schema.
	new_models=$(echo "$models_response" | jq "
		$JQ_FORMAT_NAME
		def to_num: if type == \"string\" then (tonumber // 0) else (if . != null then . else 0 end) end;
		def fmt: ((to_num * 1000000 * 10000 | floor) / 10000);

		.data
		# Keep chat models only (null/missing mode treated as chat)
		| map(select((.model_info.mode // \"chat\") == \"chat\"))
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
		)
		| sort_by(.name)
		| map({(.id): (del(.id))})
		| add // {}
	")
	model_count=$(echo "$new_models" | jq 'length')
else
	# Basic path: OpenAI-compatible /models — names only.
	new_models=$(echo "$models_response" | jq "
		$JQ_FORMAT_NAME
		.data
		| map({id: .id, name: (.id | format_name)})
		| sort_by(.name)
		| map({(.id): {name: .name}})
		| add // {}
	")
fi

# ── Write configuration ────────────────────────────────────────────
jq --tab \
	--argjson new_models "$new_models" \
	--arg provider "$PROVIDER_KEY" \
	--arg display_name "$PROVIDER_DISPLAY_NAME" \
	--arg base_url "$API_ENDPOINT" \
	'.provider[$provider].models = $new_models |
	 .provider[$provider].name = $display_name |
	 .provider[$provider].npm = "@ai-sdk/openai-compatible" |
	 .provider[$provider].options = ((.provider[$provider].options // {}) + {"baseURL": $base_url})' \
	"$CONFIGURATION_FILE" > "$CONFIGURATION_FILE.tmp"

mv "$CONFIGURATION_FILE.tmp" "$CONFIGURATION_FILE"

echo "Successfully updated provider: $PROVIDER_DISPLAY_NAME ($model_count models, $FETCH_MODE metadata)" >&2

if [ "$model_count" -gt 0 ]; then
	echo "Models:" >&2
	jq -r --arg provider "$PROVIDER_KEY" '
		.provider[$provider].models | to_entries[]
		| .value as $m
		| ([ (if $m.tool_call then "tools" else empty end),
			 (if $m.reasoning then "reasoning" else empty end),
			 (if ($m.modalities.input // []) | index("image") then "vision" else empty end)
		  ] | if length > 0 then " [" + join(",") + "]" else "" end) as $flags
		| "\t\($m.name) (\(.key))\($flags)"
	' "$CONFIGURATION_FILE" >&2
fi
