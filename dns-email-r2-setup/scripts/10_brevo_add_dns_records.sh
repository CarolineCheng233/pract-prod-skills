#!/bin/bash
# 10_brevo_add_dns_records.sh — Add Brevo DNS records to Cloudflare
# Usage:
#   bash 09_brevo_add_domain.sh example.com | bash 10_brevo_add_dns_records.sh <zone_id>
#   bash 10_brevo_add_dns_records.sh <zone_id> '<json_from_step9>'
#
# Accepts Step 9 JSON via stdin (pipe) or as second argument.
# Automatically handles both DKIM formats:
#   - TXT:   dns_records.dkim_record
#   - CNAME: dns_records.dkim1Record + dkim2Record
# Null/missing DKIM records produce a warning, not an error.
#
# Requires: CF_API_TOKEN environment variable
#
# Output: JSON { records_added: [...], records_skipped: [...], warnings: [...], count: N }

set -euo pipefail

ZONE_ID="${1:-}"

if [ -z "$ZONE_ID" ]; then
  echo '{"error":"Missing argument: zone_id","usage":"bash 09_brevo_add_domain.sh example.com | bash 10_brevo_add_dns_records.sh <zone_id>"}' >&2
  exit 1
fi

if [ -z "${CF_API_TOKEN:-}" ]; then
  echo '{"error":"CF_API_TOKEN is not set"}' >&2
  exit 1
fi

# Read Step 9 JSON from second argument or stdin
if [ -n "${2:-}" ]; then
  INPUT_JSON="$2"
else
  INPUT_JSON=$(cat)
fi

if [ -z "$INPUT_JSON" ]; then
  echo '{"error":"No JSON input. Pipe Step 9 output or pass as second argument."}' >&2
  exit 1
fi

# Parse fields
DKIM_FORMAT=$(echo "$INPUT_JSON" | jq -r '.dkim_format // "none"')
BREVO_CODE_VALUE=$(echo "$INPUT_JSON" | jq -r '.dns_records.brevo_code.value // empty')
DMARC_VALUE=$(echo "$INPUT_JSON" | jq -r '.dns_records.dmarc_record.value // empty')

CF_BASE="https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records"
ADDED=()
SKIPPED=()
WARNINGS=()

# Get the domain name from zone
ZONE_INFO=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$ZONE_ID" \
  -H "Authorization: Bearer $CF_API_TOKEN")
DOMAIN=$(echo "$ZONE_INFO" | jq -r '.result.name')

# Helper: add a DNS record if it doesn't already exist
add_record() {
  local TYPE="$1"
  local NAME="$2"
  local CONTENT="$3"
  local COMMENT="${4:-}"
  local PROXIED="${5:-false}"

  # Check if record already exists
  EXISTING=$(curl -s -X GET "${CF_BASE}?type=${TYPE}&name=${NAME}" \
    -H "Authorization: Bearer $CF_API_TOKEN")
  COUNT=$(echo "$EXISTING" | jq '.result | length')

  if [ "$COUNT" -gt "0" ]; then
    SKIPPED+=("$TYPE $NAME")
    return
  fi

  RESULT=$(curl -s -X POST "$CF_BASE" \
    -H "Authorization: Bearer $CF_API_TOKEN" \
    -H "Content-Type: application/json" \
    --data "$(jq -n \
      --arg type "$TYPE" \
      --arg name "$NAME" \
      --arg content "$CONTENT" \
      --arg comment "$COMMENT" \
      --argjson proxied "$PROXIED" \
      '{type: $type, name: $name, content: $content, ttl: 1, proxied: $proxied, comment: $comment}')")

  SUCCESS=$(echo "$RESULT" | jq -r '.success')
  if [ "$SUCCESS" = "true" ]; then
    ADDED+=("$TYPE $NAME")
  else
    ERROR_MSG=$(echo "$RESULT" | jq -r '.errors[0].message // "unknown"')
    echo "  WARN: Failed to add $TYPE $NAME: $ERROR_MSG" >&2
    WARNINGS+=("Failed to add $TYPE $NAME: $ERROR_MSG")
  fi
}

# ── 1. Brevo code — TXT on root (@) ───────────────────────────────────────
if [ -n "$BREVO_CODE_VALUE" ]; then
  add_record "TXT" "@" "$BREVO_CODE_VALUE" "Brevo domain verification"
else
  WARNINGS+=("brevo_code value is empty, skipped")
  echo "  WARN: brevo_code value is empty, skipped" >&2
fi

# ── 2. DKIM — TXT or CNAME depending on dkim_format ──────────────────────
case "$DKIM_FORMAT" in
  cname)
    DKIM1_HOST=$(echo "$INPUT_JSON" | jq -r '.dns_records.dkim1Record.host_name // empty')
    DKIM1_VALUE=$(echo "$INPUT_JSON" | jq -r '.dns_records.dkim1Record.value // empty')
    DKIM2_HOST=$(echo "$INPUT_JSON" | jq -r '.dns_records.dkim2Record.host_name // empty')
    DKIM2_VALUE=$(echo "$INPUT_JSON" | jq -r '.dns_records.dkim2Record.value // empty')

    if [ -n "$DKIM1_HOST" ] && [ -n "$DKIM1_VALUE" ]; then
      add_record "CNAME" "$DKIM1_HOST" "$DKIM1_VALUE" "Brevo DKIM 1" "false"
    else
      WARNINGS+=("dkim1Record incomplete, skipped")
      echo "  WARN: dkim1Record incomplete, skipped" >&2
    fi

    if [ -n "$DKIM2_HOST" ] && [ -n "$DKIM2_VALUE" ]; then
      add_record "CNAME" "$DKIM2_HOST" "$DKIM2_VALUE" "Brevo DKIM 2" "false"
    else
      WARNINGS+=("dkim2Record incomplete, skipped")
      echo "  WARN: dkim2Record incomplete, skipped" >&2
    fi
    ;;
  txt)
    DKIM_HOST=$(echo "$INPUT_JSON" | jq -r '.dns_records.dkim_record.host_name // empty')
    DKIM_VALUE=$(echo "$INPUT_JSON" | jq -r '.dns_records.dkim_record.value // empty')

    if [ -n "$DKIM_HOST" ] && [ -n "$DKIM_VALUE" ]; then
      add_record "TXT" "$DKIM_HOST" "$DKIM_VALUE" "Brevo DKIM"
    else
      WARNINGS+=("dkim_record incomplete, skipped")
      echo "  WARN: dkim_record incomplete, skipped" >&2
    fi
    ;;
  none|*)
    WARNINGS+=("No DKIM records returned by Brevo (dkim_format=$DKIM_FORMAT)")
    echo "  WARN: No DKIM records returned by Brevo" >&2
    ;;
esac

# ── 3. DMARC — TXT on _dmarc ─────────────────────────────────────────────
if [ -n "$DMARC_VALUE" ]; then
  EXISTING_DMARC=$(curl -s -X GET "${CF_BASE}?type=TXT&name=_dmarc.${DOMAIN}" \
    -H "Authorization: Bearer $CF_API_TOKEN")
  DMARC_COUNT=$(echo "$EXISTING_DMARC" | jq '.result | length')

  if [ "$DMARC_COUNT" -gt "0" ]; then
    EXISTING_VAL=$(echo "$EXISTING_DMARC" | jq -r '.result[0].content')
    if echo "$EXISTING_VAL" | grep -q "rua=mailto:rua@dmarc.brevo.com"; then
      SKIPPED+=("TXT _dmarc (already has Brevo rua tag)")
    else
      DMARC_RECORD_ID=$(echo "$EXISTING_DMARC" | jq -r '.result[0].id')
      UPDATED_VAL="${EXISTING_VAL}; rua=mailto:rua@dmarc.brevo.com"
      curl -s -X PATCH "${CF_BASE}/${DMARC_RECORD_ID}" \
        -H "Authorization: Bearer $CF_API_TOKEN" \
        -H "Content-Type: application/json" \
        --data "$(jq -n --arg content "$UPDATED_VAL" '{content: $content}')" > /dev/null
      ADDED+=("TXT _dmarc (updated with Brevo rua)")
    fi
  else
    add_record "TXT" "_dmarc" "$DMARC_VALUE" "Brevo DMARC"
  fi
else
  WARNINGS+=("dmarc_record value is empty, skipped")
  echo "  WARN: dmarc_record value is empty, skipped" >&2
fi

# ── Output ────────────────────────────────────────────────────────────────
to_json_array() {
  if [ "$#" -eq 0 ]; then echo "[]"; else printf '%s\n' "$@" | jq -R . | jq -s .; fi
}
ADDED_JSON=$(to_json_array "${ADDED[@]+"${ADDED[@]}"}")
SKIPPED_JSON=$(to_json_array "${SKIPPED[@]+"${SKIPPED[@]}"}")
WARNINGS_JSON=$(to_json_array "${WARNINGS[@]+"${WARNINGS[@]}"}")
COUNT=${#ADDED[@]}

echo "{\"records_added\":$ADDED_JSON,\"records_skipped\":$SKIPPED_JSON,\"warnings\":$WARNINGS_JSON,\"count\":$COUNT}"
