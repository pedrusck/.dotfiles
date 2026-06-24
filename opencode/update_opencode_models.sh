#!/bin/zsh

set -euo pipefail

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
echo "Fetching models from: $API_ENDPOINT" >&2

RESPONSE_TEMPORARY_FILE=$(mktemp /tmp/opencode_models.XXXXXX)

http_code=$(curl -s -o "$RESPONSE_TEMPORARY_FILE" -w '%{http_code}' \
	-H "Authorization: Bearer $API_KEY" "$API_ENDPOINT/models")

if [ "$http_code" -lt 200 ] || [ "$http_code" -ge 300 ]; then
	echo "Error: endpoint returned HTTP $http_code" >&2
	cat "$RESPONSE_TEMPORARY_FILE" >&2
	rm -f "$RESPONSE_TEMPORARY_FILE"
	exit 1
fi

models_response=$(cat "$RESPONSE_TEMPORARY_FILE")
rm -f "$RESPONSE_TEMPORARY_FILE"

if ! echo "$models_response" | jq -e '.data' > /dev/null 2>&1; then
	echo "Error: Invalid response (not valid JSON or missing 'data' field)" >&2
	echo "Response: $models_response" >&2
	exit 1
fi

model_count=$(echo "$models_response" | jq '.data | length')

# ── Build the models object ────────────────────────────────────────
if [ "$model_count" -eq 0 ]; then
	echo "Warning: No models found at endpoint — writing empty provider" >&2
	new_models='{}'
else
	new_models=$(echo "$models_response" | jq '
		.data
		| map({
			id: .id,
			name: (.id
				| gsub("[/_]"; "-")
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
				| gsub("(?<pre>^| )(?<num>[0-9.]+)b(?<post> |$)"; "\(.pre)\(.num)B\(.post)"))
		})
		| sort_by(.name)
		| map({(.id): {name: .name}})
		| add
	')
fi

# ── Write configuration ────────────────────────────────────────────
cp "$CONFIGURATION_FILE" "$CONFIGURATION_FILE.backup"

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
rm -f "$CONFIGURATION_FILE.backup"

echo "Successfully updated provider: $PROVIDER_DISPLAY_NAME ($model_count models)" >&2

if [ "$model_count" -gt 0 ]; then
	echo "Models:" >&2
	jq -r --arg provider "$PROVIDER_KEY" \
		'.provider[$provider].models | to_entries[] | "\t\(.value.name) (\(.key))"' \
		"$CONFIGURATION_FILE" >&2
fi
