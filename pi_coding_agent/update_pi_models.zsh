#!/usr/bin/env zsh

setopt errexit nounset pipefail

# Usage: ./update_pi_models.sh [PROVIDER_DISPLAY_NAME] [API_ENDPOINT] [CONFIGURATION_FILE]
#
# Arguments:
#	PROVIDER_DISPLAY_NAME	Human-readable provider name (default: defined on a password store entry)
#							Will be converted to snake_case for the provider key
#	API_ENDPOINT			OpenAI-compatible API endpoint (default: defined on a password store entry)
#	CONFIGURATION_FILE		Path to pi's models configuration file (default: `models.secret.json`)
#
# Environment Variables:
#	API_KEY					API key for authentication (default: defined on a password store entry)
#
# Behaviour:
#	The script prefers the LiteLLM-style `<endpoint>/model/info` route, which returns rich
#	per-model metadata (costs, token limits, modalities, capability flags). It maps that data
#	onto pi's model schema (contextWindow, maxTokens, reasoning, input, cost). Only chat models
#	are kept. Pi's schema is narrower than some others: there is no per-model tool-calling flag
#	(tools are assumed) and `input` only supports "text"/"image" (no pdf/audio). If `/model/info`
#	is unavailable it falls back to the plain `<endpoint>/models` route (model names only), so it
#	still works against any OpenAI-compatible endpoint.
#
# Examples:
#	./update_pi_models.sh
#	API_KEY=sk-xxx ./update_pi_models.sh "OpenAI Compatible" https://api.example.com config.json

# ── Dependencies ────────────────────────────────────────────────────
for cmd in curl jq; do
	if ! command -v "$cmd" &> /dev/null; then
		echo "Error: $cmd is required but not installed" >&2
		exit 1
	fi
done

# ── Environment values ──────────────────────────────────────────────
API_KEY="${API_KEY:-$(pass large_llanguage_model/pi_key | head -n 1)}"

if [ -z "$API_KEY" ]; then
	echo "Error: API_KEY is required (set the API_KEY environment variable)" >&2
	exit 1
fi

# ── Arguments & defaults ────────────────────────────────────────────
PROVIDER_DISPLAY_NAME="${1:-$(pass large_llanguage_model/pi_key | sed -n 's/.*provider_name:[[:space:]]*//p')}"
API_ENDPOINT="${2:-$(pass large_llanguage_model/pi_key | sed -n 's/.*url:[[:space:]]*//p')}"
CONFIGURATION_FILE="${3:-models.secret.json}"

PROVIDER_KEY=$(echo "$PROVIDER_DISPLAY_NAME" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/_/g; s/__*/_/g; s/^_\|_$//g')

# ── Bootstrap config file if it doesn't exist ──────────────────────
if [ ! -f "$CONFIGURATION_FILE" ]; then
	echo "Configuration file '$CONFIGURATION_FILE' not found; creating it" >&2
	jq -n --tab '{ "providers": {} }' > "$CONFIGURATION_FILE"
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

RESPONSE_TEMPORARY_FILE=$(mktemp /tmp/pi_models.XXXXXX)
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

# ── Build the models array ─────────────────────────────────────────
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
	new_models='[]'
elif [ "$FETCH_MODE" = "rich" ]; then
	# Map LiteLLM model_info onto pi's model schema.
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
			# Pi input schema supports only text/image (no pdf/audio)
			| ([\"text\"] + (if \$info.supports_vision then [\"image\"] else [] end)) as \$input_mod
			| (\$info.supports_reasoning == true) as \$reasoning
			|
			{
				id: \$name,
				name: (\$name | format_name),
				reasoning: \$reasoning,
				input: \$input_mod,
				contextWindow: (\$info.max_input_tokens // \$info.max_tokens // 128000),
				maxTokens: (\$info.max_output_tokens // \$info.max_tokens // 16384),
				cost: {
					input: (\$info.input_cost_per_token | fmt),
					output: (\$info.output_cost_per_token | fmt),
					cacheRead: (\$info.cache_read_input_token_cost | fmt),
					cacheWrite: (\$info.cache_creation_input_token_cost | fmt)
				}
			}
		)
		| sort_by(.name)
	")
	model_count=$(echo "$new_models" | jq 'length')
else
	# Basic path: OpenAI-compatible /models — emit only fetched fields
	# (id + derived name); pi fills in schema defaults at load time.
	new_models=$(echo "$models_response" | jq "
		$JQ_FORMAT_NAME
		.data
		| map({
			id: .id,
			name: (.id | format_name)
		})
		| sort_by(.name)
	")
fi

# ── Write configuration ────────────────────────────────────────────
jq --tab \
	--argjson new_models "$new_models" \
	--arg provider "$PROVIDER_KEY" \
	--arg display_name "$PROVIDER_DISPLAY_NAME" \
	--arg base_url "$API_ENDPOINT" \
	'.providers[$provider].name = $display_name |
	 .providers[$provider].baseUrl = $base_url |
	 .providers[$provider].api = "openai-completions" |
	 .providers[$provider].apiKey = "!pass large_llanguage_model/pi_key | head -n 1" |
	 .providers[$provider].models = $new_models' \
	"$CONFIGURATION_FILE" > "$CONFIGURATION_FILE.tmp"

mv "$CONFIGURATION_FILE.tmp" "$CONFIGURATION_FILE"

echo "Successfully updated provider: $PROVIDER_DISPLAY_NAME ($model_count models, $FETCH_MODE metadata)" >&2

if [ "$model_count" -gt 0 ]; then
	echo "Models:" >&2
	jq -r --arg provider "$PROVIDER_KEY" '
		.providers[$provider].models[] as $m
		| ([ (if $m.reasoning then "reasoning" else empty end),
			 (if ($m.input // []) | index("image") then "vision" else empty end)
		  ] | if length > 0 then " [" + join(",") + "]" else "" end) as $flags
		| "\t\($m.name) (\($m.id))\($flags)"
	' "$CONFIGURATION_FILE" >&2
fi
