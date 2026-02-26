#!/bin/bash
# 05_verify_zone.sh — Trigger Cloudflare zone verification and wait for activation
# Usage: bash 05_verify_zone.sh <zone_id> [timeout_seconds]
# Example: bash 05_verify_zone.sh <zone_id> 300
#
# This script:
#   1. Calls the Cloudflare API to trigger a nameserver check
#   2. Polls zone status every 30 seconds until "active" or timeout
#
# Output: JSON { zone_id, status, elapsed_seconds }

set -euo pipefail

ZONE_ID="${1:-}"
TIMEOUT="${2:-300}"   # default: wait up to 5 minutes (adjust if needed)

if [ -z "$ZONE_ID" ]; then
  echo '{"error":"Missing argument: zone_id","usage":"bash 05_verify_zone.sh <zone_id> [timeout_seconds]"}' >&2
  exit 1
fi

BASE_URL="https://api.cloudflare.com/client/v4"
INTERVAL=30
ELAPSED=0

# Trigger Cloudflare to re-check nameservers immediately
curl -s -X PUT "$BASE_URL/zones/$ZONE_ID/activation_check" \
  -H "Authorization: Bearer $CF_API_TOKEN" \
  -H "Content-Type: application/json" > /dev/null

echo "Waiting for zone to become active (checking every ${INTERVAL}s, timeout ${TIMEOUT}s)..." >&2

while [ "$ELAPSED" -lt "$TIMEOUT" ]; do
  RESPONSE=$(curl -s -X GET "$BASE_URL/zones/$ZONE_ID" \
    -H "Authorization: Bearer $CF_API_TOKEN" \
    -H "Content-Type: application/json")

  STATUS=$(echo "$RESPONSE" | jq -r '.result.status // "unknown"')

  if [ "$STATUS" = "active" ]; then
    echo "{\"zone_id\":\"$ZONE_ID\",\"status\":\"active\",\"elapsed_seconds\":$ELAPSED}"
    exit 0
  fi

  echo "  [${ELAPSED}s] status: $STATUS — still waiting..." >&2
  sleep "$INTERVAL"
  ELAPSED=$((ELAPSED + INTERVAL))
done

# Timeout reached — return current status for the caller to decide
FINAL_RESPONSE=$(curl -s -X GET "$BASE_URL/zones/$ZONE_ID" \
  -H "Authorization: Bearer $CF_API_TOKEN" \
  -H "Content-Type: application/json")
FINAL_STATUS=$(echo "$FINAL_RESPONSE" | jq -r '.result.status // "unknown"')

echo "{\"zone_id\":\"$ZONE_ID\",\"status\":\"$FINAL_STATUS\",\"elapsed_seconds\":$ELAPSED,\"warning\":\"timeout_reached — DNS propagation may still be in progress. Re-run this script or check Cloudflare dashboard.\"}"
exit 1
