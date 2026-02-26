#!/bin/bash
# 02_delete_dns_records.sh — Delete all DNS records in a zone
# Usage: bash 02_delete_dns_records.sh <zone_id>
# Output: JSON { deleted: [...], count, skipped: [...] }

set -euo pipefail

ZONE_ID="${1:-}"
if [ -z "$ZONE_ID" ]; then
  echo '{"error":"Missing argument: zone_id","usage":"bash 02_delete_dns_records.sh <zone_id>"}' >&2
  exit 1
fi

BASE_URL="https://api.cloudflare.com/client/v4"

# Fetch all DNS records
RECORDS_RESPONSE=$(curl -s -X GET "$BASE_URL/zones/$ZONE_ID/dns_records?per_page=100" \
  -H "Authorization: Bearer $CF_API_TOKEN" \
  -H "Content-Type: application/json")

SUCCESS=$(echo "$RECORDS_RESPONSE" | jq -r '.success')
if [ "$SUCCESS" != "true" ]; then
  echo "$RECORDS_RESPONSE" | jq '{error: .errors[0].message}' >&2
  exit 1
fi

TOTAL=$(echo "$RECORDS_RESPONSE" | jq '.result | length')

if [ "$TOTAL" -eq 0 ]; then
  echo '{"deleted":[],"count":0,"skipped":[],"message":"No DNS records found"}'
  exit 0
fi

DELETED=()
SKIPPED=()

while IFS= read -r RECORD; do
  ID=$(echo "$RECORD" | jq -r '.id')
  TYPE=$(echo "$RECORD" | jq -r '.type')
  NAME=$(echo "$RECORD" | jq -r '.name')

  # NS records at zone apex cannot be deleted via API — skip them
  if [ "$TYPE" = "NS" ]; then
    SKIPPED+=("\"$ID ($TYPE $NAME)\"")
    continue
  fi

  DEL_RESPONSE=$(curl -s -X DELETE "$BASE_URL/zones/$ZONE_ID/dns_records/$ID" \
    -H "Authorization: Bearer $CF_API_TOKEN" \
    -H "Content-Type: application/json")

  DEL_SUCCESS=$(echo "$DEL_RESPONSE" | jq -r '.success')
  if [ "$DEL_SUCCESS" = "true" ]; then
    DELETED+=("\"$ID\"")
  else
    SKIPPED+=("\"$ID (delete failed)\"")
  fi
done < <(echo "$RECORDS_RESPONSE" | jq -c '.result[]')

DELETED_JSON="[$(IFS=,; echo "${DELETED[*]:-}")]"
SKIPPED_JSON="[$(IFS=,; echo "${SKIPPED[*]:-}")]"
COUNT=${#DELETED[@]}

echo "{\"deleted\":$DELETED_JSON,\"count\":$COUNT,\"skipped\":$SKIPPED_JSON}"
