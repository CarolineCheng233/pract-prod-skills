#!/bin/bash
# 06_update_nameservers.sh — Update domain nameservers on Spaceship registrar
# Usage: bash 06_update_nameservers.sh <domain> <ns1> <ns2>
# Example: bash 06_update_nameservers.sh example.com ns1.cloudflare.com ns2.cloudflare.com
# Output: JSON { domain, nameservers: [...], status }

set -euo pipefail

DOMAIN="${1:-}"
NS1="${2:-}"
NS2="${3:-}"

if [ -z "$DOMAIN" ] || [ -z "$NS1" ] || [ -z "$NS2" ]; then
  echo '{"error":"Missing arguments","usage":"bash 06_update_nameservers.sh <domain> <ns1> <ns2>"}' >&2
  exit 1
fi

if [ -z "${SPACESHIP_API_KEY:-}" ] || [ -z "${SPACESHIP_API_SECRET:-}" ]; then
  echo '{"error":"SPACESHIP_API_KEY and SPACESHIP_API_SECRET must be set"}' >&2
  exit 1
fi

SS_BASE="https://spaceship.dev/api/v1"

# Update nameservers via Spaceship API
# Spaceship requires {"provider":"custom","hosts":[...]} format
RESPONSE=$(curl -s -X PUT "$SS_BASE/domains/$DOMAIN/nameservers" \
  -H "X-API-Key: $SPACESHIP_API_KEY" \
  -H "X-API-Secret: $SPACESHIP_API_SECRET" \
  -H "Content-Type: application/json" \
  --data "{\"provider\":\"custom\",\"hosts\":[\"$NS1\",\"$NS2\"]}")

# Check if response contains the expected provider/hosts fields (HTTP 200 success)
PROVIDER=$(echo "$RESPONSE" | jq -r '.provider // empty')
if [ "$PROVIDER" = "custom" ]; then
  echo "{\"domain\":\"$DOMAIN\",\"nameservers\":[\"$NS1\",\"$NS2\"],\"status\":\"updated\"}"
  exit 0
fi

# Empty response also indicates success (some API versions return 204)
if [ -z "$RESPONSE" ]; then
  echo "{\"domain\":\"$DOMAIN\",\"nameservers\":[\"$NS1\",\"$NS2\"],\"status\":\"updated\"}"
  exit 0
fi

# If there's an error response
HTTP_STATUS=$(echo "$RESPONSE" | jq -r '.status // empty')
ERROR_MSG=$(echo "$RESPONSE" | jq -r '.title // .detail // "unknown error"')

if [ -n "$HTTP_STATUS" ] && [ "$HTTP_STATUS" != "200" ]; then
  echo "{\"error\":\"$ERROR_MSG\",\"status\":$HTTP_STATUS}" >&2
  exit 1
fi

# Unexpected response
echo "{\"domain\":\"$DOMAIN\",\"nameservers\":[\"$NS1\",\"$NS2\"],\"status\":\"updated\",\"response\":$RESPONSE}"
