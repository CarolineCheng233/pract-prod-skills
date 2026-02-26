#!/bin/bash
# 03_get_nameservers.sh — Retrieve Cloudflare nameservers assigned to a zone
# Usage: bash 03_get_nameservers.sh <zone_id>
# Output: JSON { zone_id, domain, nameservers: [...] }

set -euo pipefail

ZONE_ID="${1:-}"
if [ -z "$ZONE_ID" ]; then
  echo '{"error":"Missing argument: zone_id","usage":"bash 03_get_nameservers.sh <zone_id>"}' >&2
  exit 1
fi

BASE_URL="https://api.cloudflare.com/client/v4"

RESPONSE=$(curl -s -X GET "$BASE_URL/zones/$ZONE_ID" \
  -H "Authorization: Bearer $CF_API_TOKEN" \
  -H "Content-Type: application/json")

SUCCESS=$(echo "$RESPONSE" | jq -r '.success')

if [ "$SUCCESS" != "true" ]; then
  echo "$RESPONSE" | jq '{error: .errors[0].message, code: .errors[0].code}' >&2
  exit 1
fi

DOMAIN=$(echo "$RESPONSE" | jq -r '.result.name')
NS=$(echo "$RESPONSE" | jq '[.result.name_servers[]]')

echo "{\"zone_id\":\"$ZONE_ID\",\"domain\":\"$DOMAIN\",\"nameservers\":$NS}"
