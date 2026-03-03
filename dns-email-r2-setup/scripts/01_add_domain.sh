#!/bin/bash
# 01_add_domain.sh — Add a domain to Cloudflare with DNS scan and AI crawler options
#
# Usage:
#   bash 01_add_domain.sh <domain> [dns_method] [block_ai] [robots_txt]
#
# Arguments:
#   domain       Required. Domain to add, e.g. example.com
#   dns_method   Optional. quick | manual | zone_file  (default: quick)
#   block_ai     Optional. none | all | ads             (default: none)
#   robots_txt   Optional. true | false                 (default: true)
#
# Output: JSON { zone_id, domain, status, options }

set -euo pipefail

DOMAIN="${1:-}"
DNS_METHOD="${2:-quick}"
BLOCK_AI="${3:-none}"
ROBOTS_TXT="${4:-true}"

if [ -z "$DOMAIN" ]; then
  echo '{"error":"Missing argument: domain","usage":"bash 01_add_domain.sh <domain> [dns_method] [block_ai] [robots_txt]"}' >&2
  exit 1
fi

# Validate dns_method
case "$DNS_METHOD" in
  quick|manual|zone_file) ;;
  *)
    echo "{\"error\":\"Invalid dns_method: $DNS_METHOD. Must be one of: quick, manual, zone_file\"}" >&2
    exit 1
    ;;
esac

# Validate block_ai
case "$BLOCK_AI" in
  none|all|ads) ;;
  *)
    echo "{\"error\":\"Invalid block_ai: $BLOCK_AI. Must be one of: none, all, ads\"}" >&2
    exit 1
    ;;
esac

# Validate robots_txt
case "$ROBOTS_TXT" in
  true|false) ;;
  *)
    echo "{\"error\":\"Invalid robots_txt: $ROBOTS_TXT. Must be true or false\"}" >&2
    exit 1
    ;;
esac

BASE_URL="https://api.cloudflare.com/client/v4"

# jump_start = true only for quick scan
if [ "$DNS_METHOD" = "quick" ]; then
  JUMP_START="true"
else
  JUMP_START="false"
fi

# Try to create the zone
RESPONSE=$(curl -s -X POST "$BASE_URL/zones" \
  -H "Authorization: Bearer $CF_API_TOKEN" \
  -H "Content-Type: application/json" \
  --data "{\"name\":\"$DOMAIN\",\"jump_start\":$JUMP_START}")

SUCCESS=$(echo "$RESPONSE" | jq -r '.success')

if [ "$SUCCESS" != "true" ]; then
  # Check if zone already exists (error code 1061)
  ERROR_CODE=$(echo "$RESPONSE" | jq -r '.errors[0].code // empty')
  if [ "$ERROR_CODE" = "1061" ]; then
    EXISTING=$(curl -s -X GET "$BASE_URL/zones?name=$DOMAIN" \
      -H "Authorization: Bearer $CF_API_TOKEN" \
      -H "Content-Type: application/json")
    ZONE_ID=$(echo "$EXISTING" | jq -r '.result[0].id // empty')
    STATUS=$(echo "$EXISTING" | jq -r '.result[0].status // empty')
    if [ -n "$ZONE_ID" ]; then
      echo "{\"zone_id\":\"$ZONE_ID\",\"domain\":\"$DOMAIN\",\"status\":\"$STATUS\",\"note\":\"zone_already_exists\",\"options\":{\"dns_method\":\"$DNS_METHOD\",\"block_ai\":\"$BLOCK_AI\",\"robots_txt\":$ROBOTS_TXT}}"
      exit 0
    fi
  fi
  echo "$RESPONSE" | jq '{error: .errors[0].message, code: .errors[0].code}' >&2
  exit 1
fi

ZONE_ID=$(echo "$RESPONSE" | jq -r '.result.id')
STATUS=$(echo "$RESPONSE" | jq -r '.result.status')

# Apply AI crawler setting via zone settings API
# Map block_ai option to Cloudflare's ai_scrape_shield value
case "$BLOCK_AI" in
  all)  AI_VALUE="block" ;;
  ads)  AI_VALUE="block_advertised" ;;
  none) AI_VALUE="allow" ;;
esac

curl -s -X PATCH "$BASE_URL/zones/$ZONE_ID/settings/ai_scrape_shield" \
  -H "Authorization: Bearer $CF_API_TOKEN" \
  -H "Content-Type: application/json" \
  --data "{\"value\":\"$AI_VALUE\"}" > /dev/null 2>&1 || true

# Apply robots_txt AI instruction setting
curl -s -X PATCH "$BASE_URL/zones/$ZONE_ID/settings/ai_bots_protection" \
  -H "Authorization: Bearer $CF_API_TOKEN" \
  -H "Content-Type: application/json" \
  --data "{\"value\":\"$ROBOTS_TXT\"}" > /dev/null 2>&1 || true

echo "{\"zone_id\":\"$ZONE_ID\",\"domain\":\"$DOMAIN\",\"status\":\"$STATUS\",\"options\":{\"dns_method\":\"$DNS_METHOD\",\"block_ai\":\"$BLOCK_AI\",\"robots_txt\":$ROBOTS_TXT}}"
