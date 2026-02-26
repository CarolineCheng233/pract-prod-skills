#!/bin/bash
# 11_brevo_authenticate.sh — Trigger Brevo domain authentication and poll until verified
# Usage: bash 11_brevo_authenticate.sh <domain> [timeout_seconds]
# Example: bash 11_brevo_authenticate.sh example.com 300
#
# Requires: BREVO_API_KEY environment variable
#
# Brevo checks: brevo_code (required), dkim (required), dmarc_record (recommended)
# DKIM can be either TXT (dkim_record) or CNAME (dkim1Record + dkim2Record) depending on account type.
# DNS propagation can take minutes to hours. This script retries with backoff.
#
# Output: JSON { domain, authenticated, dns_records_status, elapsed_seconds }

set -euo pipefail

DOMAIN="${1:-}"
TIMEOUT="${2:-300}"

if [ -z "$DOMAIN" ]; then
  echo '{"error":"Missing argument: domain","usage":"bash 11_brevo_authenticate.sh <domain> [timeout_seconds]"}' >&2
  exit 1
fi

if [ -z "${BREVO_API_KEY:-}" ]; then
  echo '{"error":"BREVO_API_KEY is not set"}' >&2
  exit 1
fi

BREVO_BASE="https://api.brevo.com/v3"
INTERVAL=30
ELAPSED=0

# Helper: fetch individual record statuses via GET /senders/domains/{domain}
# (the list endpoint GET /senders/domains does NOT include dns_records)
fetch_status() {
  local RESP
  RESP=$(curl -s -X GET "$BREVO_BASE/senders/domains/$DOMAIN" \
    -H "api-key: $BREVO_API_KEY")

  BREVO_CODE_OK=$(echo "$RESP" | jq -r '.dns_records.brevo_code.status // false')
  DMARC_OK=$(echo "$RESP" | jq -r '.dns_records.dmarc_record.status // false')

  # DKIM: check both CNAME format (dkim1Record/dkim2Record) and TXT format (dkim_record)
  local DKIM1_OK DKIM2_OK DKIM_TXT_OK
  DKIM1_OK=$(echo "$RESP" | jq -r '.dns_records.dkim1Record.status // false')
  DKIM2_OK=$(echo "$RESP" | jq -r '.dns_records.dkim2Record.status // false')
  DKIM_TXT_OK=$(echo "$RESP" | jq -r '.dns_records.dkim_record.status // false')

  if [ "$DKIM1_OK" = "true" ] && [ "$DKIM2_OK" = "true" ]; then
    DKIM_OK=true
  elif [ "$DKIM_TXT_OK" = "true" ]; then
    DKIM_OK=true
  else
    DKIM_OK=false
  fi
}

echo "Triggering Brevo domain authentication for $DOMAIN..." >&2

# Trigger the authentication check
# PUT /authenticate returns {"domain_name":"...","message":"..."} on success,
# NOT an "authenticated" boolean. Check via GET after triggering.
curl -s -X PUT "$BREVO_BASE/senders/domains/$DOMAIN/authenticate" \
  -H "api-key: $BREVO_API_KEY" \
  -H "Content-Type: application/json" > /dev/null

# Check if already authenticated via GET
GET_CHECK=$(curl -s -X GET "$BREVO_BASE/senders/domains/$DOMAIN" \
  -H "api-key: $BREVO_API_KEY")
IS_AUTH=$(echo "$GET_CHECK" | jq -r '.authenticated // false')

if [ "$IS_AUTH" = "true" ]; then
  fetch_status
  echo "{\"domain\":\"$DOMAIN\",\"authenticated\":true,\"elapsed_seconds\":0,\"dns_records_status\":{\"brevo_code\":$BREVO_CODE_OK,\"dkim\":$DKIM_OK,\"dmarc\":$DMARC_OK}}"
  exit 0
fi

echo "Waiting for DNS propagation and Brevo verification (checking every ${INTERVAL}s, timeout ${TIMEOUT}s)..." >&2

while [ "$ELAPSED" -lt "$TIMEOUT" ]; do
  sleep "$INTERVAL"
  ELAPSED=$((ELAPSED + INTERVAL))

  # Re-trigger authentication check, then verify via GET
  curl -s -X PUT "$BREVO_BASE/senders/domains/$DOMAIN/authenticate" \
    -H "api-key: $BREVO_API_KEY" \
    -H "Content-Type: application/json" > /dev/null

  IS_AUTH=$(curl -s -X GET "$BREVO_BASE/senders/domains/$DOMAIN" \
    -H "api-key: $BREVO_API_KEY" | jq -r '.authenticated // false')

  # Fetch individual record statuses
  fetch_status

  echo "  [${ELAPSED}s] authenticated=$IS_AUTH | brevo_code=$BREVO_CODE_OK | dkim=$DKIM_OK | dmarc=$DMARC_OK" >&2

  if [ "$IS_AUTH" = "true" ]; then
    echo "{\"domain\":\"$DOMAIN\",\"authenticated\":true,\"elapsed_seconds\":$ELAPSED,\"dns_records_status\":{\"brevo_code\":$BREVO_CODE_OK,\"dkim\":$DKIM_OK,\"dmarc\":$DMARC_OK}}"
    exit 0
  fi
done

# Timeout — return current state so the caller can decide
echo "{\"domain\":\"$DOMAIN\",\"authenticated\":false,\"elapsed_seconds\":$ELAPSED,\"dns_records_status\":{\"brevo_code\":$BREVO_CODE_OK,\"dkim\":$DKIM_OK,\"dmarc\":$DMARC_OK},\"warning\":\"timeout_reached — DNS propagation may still be in progress. Re-run this script later or check Brevo dashboard: Settings > Senders, Domains, IPs > Domains.\"}"
exit 1
