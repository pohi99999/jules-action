#!/bin/bash
set -e

# scripts/invoke_jules.sh
# Securely invokes the Jules API and handles errors.

if [ -z "$JULES_API_KEY" ]; then
  printf "Error: JULES_API_KEY is not set.\n" >&2
  exit 1
fi

if [ ! -s "jules_payload.json" ]; then
  printf "Error: jules_payload.json not found or empty.\n" >&2
  exit 1
fi

# Create a temporary config file for curl to avoid exposure of the API key in process lists.
CURL_CONFIG=$(mktemp)
trap 'rm -f "$CURL_CONFIG"' EXIT

# Write the API key header to the config file
# Using printf to safely handle potential special characters in the API key
printf 'header = "X-Goog-Api-Key: %s"\n' "$JULES_API_KEY" > "$CURL_CONFIG"

printf "Invoking Jules API...\n"

# Invoke Jules API
# -sSL: Silent, show errors, follow redirects
# -w "\n%{http_code}": Append HTTP status code to the output
# -K <file>: Read config from file
RESPONSE=$(curl -sSL -w "\n%{http_code}" \
  'https://jules.googleapis.com/v1alpha/sessions' \
  -X POST \
  -H "Content-Type: application/json" \
  -K "$CURL_CONFIG" \
  -d @jules_payload.json)

# Extract status code (last line) and body (everything before)
HTTP_STATUS=$(printf "%s" "$RESPONSE" | tail -n 1)
RESPONSE_BODY=$(printf "%s" "$RESPONSE" | sed '$d')

if [ "$HTTP_STATUS" -lt 200 ] || [ "$HTTP_STATUS" -ge 300 ]; then
  printf "Error: Jules API request failed with status %s\n" "$HTTP_STATUS" >&2
  printf "Response body:\n%s\n" "$RESPONSE_BODY" >&2
  exit 1
fi

printf "Jules API invoked successfully.\n"
printf "%s\n" "$RESPONSE_BODY"
