#!/bin/bash
# 04_enable_email_routing.sh — Enable Email Routing for a Cloudflare zone
# Usage: bash 04_enable_email_routing.sh <zone_id>
# Output: JSON { enabled, zone_id, already_enabled? }

set -euo pipefail

ZONE_ID="${1:-}"
if [ -z "$ZONE_ID" ]; then
  echo '{"error":"Missing argument: zone_id","usage":"bash 04_enable_email_routing.sh <zone_id>"}' >&2
  exit 1
fi

BASE_URL="https://api.cloudflare.com/client/v4"

# Check current status first
STATUS_RESPONSE=$(curl -s -X GET "$BASE_URL/zones/$ZONE_ID/email/routing" \
  -H "Authorization: Bearer $CF_API_TOKEN" \
  -H "Content-Type: application/json")

CURRENT_ENABLED=$(echo "$STATUS_RESPONSE" | jq -r '.result.enabled // false')

if [ "$CURRENT_ENABLED" = "true" ]; then
  echo "{\"enabled\":true,\"zone_id\":\"$ZONE_ID\",\"already_enabled\":true}"
  exit 0
fi

# Enable Email Routing
ENABLE_RESPONSE=$(curl -s -X POST "$BASE_URL/zones/$ZONE_ID/email/routing/enable" \
  -H "Authorization: Bearer $CF_API_TOKEN" \
  -H "Content-Type: application/json")

SUCCESS=$(echo "$ENABLE_RESPONSE" | jq -r '.success')

if [ "$SUCCESS" = "true" ]; then
  echo "{\"enabled\":true,\"zone_id\":\"$ZONE_ID\"}"
  exit 0
fi

echo "$ENABLE_RESPONSE" | jq '{error: .errors[0].message, code: .errors[0].code}' >&2
exit 1
