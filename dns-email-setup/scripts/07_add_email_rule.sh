#!/bin/bash
# 05_add_email_rule.sh — Add an email forwarding rule to a Cloudflare zone
# Usage: bash 05_add_email_rule.sh <zone_id> <from_prefix> <to_email>
# Example: bash 05_add_email_rule.sh abc123 contact user@gmail.com
# Output: JSON { rule_id, from, to, enabled }

set -euo pipefail

ZONE_ID="${1:-}"
FROM_PREFIX="${2:-}"
TO_EMAIL="${3:-}"

if [ -z "$ZONE_ID" ] || [ -z "$FROM_PREFIX" ] || [ -z "$TO_EMAIL" ]; then
  echo '{"error":"Missing arguments","usage":"bash 05_add_email_rule.sh <zone_id> <from_prefix> <to_email>"}' >&2
  exit 1
fi

BASE_URL="https://api.cloudflare.com/client/v4"

# Get domain name from zone_id
ZONE_RESPONSE=$(curl -s -X GET "$BASE_URL/zones/$ZONE_ID" \
  -H "Authorization: Bearer $CF_API_TOKEN" \
  -H "Content-Type: application/json")
DOMAIN=$(echo "$ZONE_RESPONSE" | jq -r '.result.name')
FROM_ADDRESS="$FROM_PREFIX@$DOMAIN"

# Check if rule already exists
RULES_RESPONSE=$(curl -s -X GET "$BASE_URL/zones/$ZONE_ID/email/routing/rules" \
  -H "Authorization: Bearer $CF_API_TOKEN" \
  -H "Content-Type: application/json")

EXISTING_RULE=$(echo "$RULES_RESPONSE" | jq -r \
  ".result[] | select(.matchers[0].value == \"$FROM_ADDRESS\") | .id" 2>/dev/null || true)

if [ -n "$EXISTING_RULE" ]; then
  echo "{\"rule_id\":\"$EXISTING_RULE\",\"from\":\"$FROM_ADDRESS\",\"to\":\"$TO_EMAIL\",\"enabled\":true,\"note\":\"rule_already_exists\"}"
  exit 0
fi

# Create the forwarding rule
RULE_RESPONSE=$(curl -s -X POST "$BASE_URL/zones/$ZONE_ID/email/routing/rules" \
  -H "Authorization: Bearer $CF_API_TOKEN" \
  -H "Content-Type: application/json" \
  --data "{
    \"name\": \"Forward $FROM_PREFIX to destination\",
    \"enabled\": true,
    \"matchers\": [{
      \"type\": \"literal\",
      \"field\": \"to\",
      \"value\": \"$FROM_ADDRESS\"
    }],
    \"actions\": [{
      \"type\": \"forward\",
      \"value\": [\"$TO_EMAIL\"]
    }]
  }")

SUCCESS=$(echo "$RULE_RESPONSE" | jq -r '.success')

if [ "$SUCCESS" = "true" ]; then
  RULE_ID=$(echo "$RULE_RESPONSE" | jq -r '.result.id')
  ENABLED=$(echo "$RULE_RESPONSE" | jq -r '.result.enabled')
  echo "{\"rule_id\":\"$RULE_ID\",\"from\":\"$FROM_ADDRESS\",\"to\":\"$TO_EMAIL\",\"enabled\":$ENABLED}"
  exit 0
fi

echo "$RULE_RESPONSE" | jq '{error: .errors[0].message, code: .errors[0].code}' >&2
exit 1
