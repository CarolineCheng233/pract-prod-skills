#!/bin/bash
# 09_brevo_add_domain.sh — Add domain to Brevo and get ALL required DNS records
# Usage: bash 09_brevo_add_domain.sh <domain>
# Example: bash 09_brevo_add_domain.sh example.com
#
# Requires: BREVO_API_KEY environment variable
#
# Brevo returns two DKIM formats depending on account type:
#   - Old accounts: TXT  → dns_records.dkim_record  (single TXT record)
#   - New accounts: CNAME → dns_records.dkim1Record + dkim2Record (two CNAME records)
# POST /senders/domains often returns dkim_record as null for new accounts.
# This script always follows up with GET /senders/domains/{domain} to get the full set.
#
# Output: JSON {
#   domain_id, domain_name, domain_provider,
#   dkim_format: "cname"|"txt"|"none",
#   dns_records: { brevo_code, dkim_record, dkim1Record, dkim2Record, dmarc_record }
# }

set -euo pipefail

DOMAIN="${1:-}"

if [ -z "$DOMAIN" ]; then
  echo '{"error":"Missing argument: domain","usage":"bash 09_brevo_add_domain.sh <domain>"}' >&2
  exit 1
fi

if [ -z "${BREVO_API_KEY:-}" ]; then
  echo '{"error":"BREVO_API_KEY is not set","hint":"export BREVO_API_KEY=\"your_brevo_api_key\""}' >&2
  exit 1
fi

BREVO_BASE="https://api.brevo.com/v3"

# ── Step 1: POST to create the domain ──────────────────────────────────────
POST_RESPONSE=$(curl -s -X POST "$BREVO_BASE/senders/domains" \
  -H "api-key: $BREVO_API_KEY" \
  -H "Content-Type: application/json" \
  -d "{\"name\":\"$DOMAIN\"}")

ERROR_CODE=$(echo "$POST_RESPONSE" | jq -r '.code // empty')
if [ -n "$ERROR_CODE" ]; then
  MESSAGE=$(echo "$POST_RESPONSE" | jq -r '.message // "unknown error"')
  # Domain already exists — not fatal, continue to GET
  if ! echo "$MESSAGE" | grep -qi "already\|exist\|duplicate"; then
    echo "{\"error\":\"$ERROR_CODE\",\"message\":\"$MESSAGE\"}" >&2
    exit 1
  fi
  echo "Note: domain already exists in Brevo, fetching existing records..." >&2
fi

DOMAIN_ID=$(echo "$POST_RESPONSE" | jq -r '.id // "unknown"')
PROVIDER=$(echo "$POST_RESPONSE"  | jq -r '.domain_provider // "unknown"')

# ── Step 2: GET full record set (POST often omits CNAME DKIM for new accounts) ──
GET_RESPONSE=$(curl -s -X GET "$BREVO_BASE/senders/domains/$DOMAIN" \
  -H "api-key: $BREVO_API_KEY")

GET_ERROR=$(echo "$GET_RESPONSE" | jq -r '.code // empty')
if [ -n "$GET_ERROR" ]; then
  echo "{\"error\":\"$GET_ERROR\",\"message\":$(echo "$GET_RESPONSE" | jq '.message')}" >&2
  exit 1
fi

# ── Step 3: Detect DKIM format (CNAME vs TXT) ──────────────────────────────
# Brevo API uses camelCase: dkim1Record / dkim2Record (not dkim_record1)
DKIM1=$(echo "$GET_RESPONSE" | jq -r '.dns_records.dkim1Record // empty')
DKIM_TXT=$(echo "$GET_RESPONSE" | jq -r '.dns_records.dkim_record // empty')

if [ -n "$DKIM1" ] && [ "$DKIM1" != "null" ]; then
  DKIM_FORMAT="cname"
elif [ -n "$DKIM_TXT" ] && [ "$DKIM_TXT" != "null" ]; then
  DKIM_FORMAT="txt"
else
  DKIM_FORMAT="none"
fi

# ── Step 4: Output normalised result ───────────────────────────────────────
echo "$GET_RESPONSE" | jq \
  --arg id      "$DOMAIN_ID" \
  --arg prov    "$PROVIDER" \
  --arg dkimfmt "$DKIM_FORMAT" \
  '{
    domain_id:       $id,
    domain_name:     (.domain // .domain_name),
    domain_provider: $prov,
    dkim_format:     $dkimfmt,
    dns_records: {
      brevo_code:   .dns_records.brevo_code,
      dkim_record:  .dns_records.dkim_record,
      dkim1Record:  .dns_records.dkim1Record,
      dkim2Record:  .dns_records.dkim2Record,
      dmarc_record: .dns_records.dmarc_record
    }
  }'
