#!/usr/bin/env bash
set -euo pipefail

GSC_SITE=""
GA4_PROPERTY=""

usage() {
  cat <<'USAGE'
Usage:
  verify-gsc-ga4-adc.sh [--gsc-site SITE_URL] [--ga4-property properties/PROPERTY_ID]

Examples:
  verify-gsc-ga4-adc.sh --gsc-site "sc-domain:example.com"
  verify-gsc-ga4-adc.sh --ga4-property "properties/123456789"
  verify-gsc-ga4-adc.sh --gsc-site "https://example.com/" --ga4-property "properties/123456789"

This script verifies local ADC access without printing tokens or credential JSON.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --gsc-site)
      GSC_SITE="${2:-}"
      shift 2
      ;;
    --ga4-property)
      GA4_PROPERTY="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 127
  fi
}

urlencode() {
  python3 - "$1" <<'PY'
import sys
from urllib.parse import quote
print(quote(sys.argv[1], safe=""))
PY
}

property_id() {
  local value="$1"
  value="${value#properties/}"
  printf '%s\n' "$value"
}

json_has_error() {
  python3 -c '
import json
import sys
try:
    data = json.load(sys.stdin)
except Exception:
    sys.exit(1)
sys.exit(0 if "error" in data else 1)
'
}

json_error_message() {
  python3 -c '
import json
import sys
try:
    data = json.load(sys.stdin)
except Exception:
    print("non-json response")
    sys.exit(0)
err = data.get("error", {})
print(err.get("message") or err.get("status") or "unknown error")
'
}

json_array_length() {
  local path="$1"
  python3 -c '
import json
import sys
path = sys.argv[1].split(".")
try:
    data = json.load(sys.stdin)
except Exception:
    print(0)
    sys.exit(0)
node = data
for key in path:
    if not key:
        continue
    if isinstance(node, dict):
        node = node.get(key, [])
    else:
        node = []
print(len(node) if isinstance(node, list) else 0)
' "$path"
}

json_contains_site() {
  local site="$1"
  python3 -c '
import json
import sys
target = sys.argv[1]
try:
    data = json.load(sys.stdin)
except Exception:
    sys.exit(1)
for entry in data.get("siteEntry", []):
    if entry.get("siteUrl") == target:
        sys.exit(0)
sys.exit(1)
' "$site"
}

request() {
  curl -sS "$@"
}

require_cmd gcloud
require_cmd curl
require_cmd python3

echo "[1/5] Checking ADC token..."
TOKEN="$(gcloud auth application-default print-access-token 2>/dev/null || true)"
if [[ -z "$TOKEN" ]]; then
  echo "FAIL: ADC token could not be generated."
  echo "Run: gcloud auth application-default login --scopes=..."
  exit 1
fi
echo "OK: ADC token generated."

echo "[2/5] Reading Search Console site list..."
GSC_RESPONSE="$(request -H "Authorization: Bearer $TOKEN" "https://www.googleapis.com/webmasters/v3/sites")"
if printf '%s' "$GSC_RESPONSE" | json_has_error; then
  echo "FAIL: Search Console API returned an error:"
  printf '%s' "$GSC_RESPONSE" | json_error_message
  exit 1
fi
GSC_COUNT="$(printf '%s' "$GSC_RESPONSE" | json_array_length "siteEntry")"
echo "OK: Search Console sites visible: $GSC_COUNT"

if [[ -n "$GSC_SITE" ]]; then
  if printf '%s' "$GSC_RESPONSE" | json_contains_site "$GSC_SITE"; then
    echo "OK: Target GSC site is visible."
  else
    echo "WARN: Target GSC site was not found in visible sites."
  fi

  echo "[3/5] Running minimal Search Analytics query..."
  ENCODED_SITE="$(urlencode "$GSC_SITE")"
  SEARCH_RESPONSE="$(request -X POST \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    "https://www.googleapis.com/webmasters/v3/sites/$ENCODED_SITE/searchAnalytics/query" \
    -d '{"startDate":"7daysAgo","endDate":"yesterday","dimensions":["date"],"rowLimit":1}')"
  if printf '%s' "$SEARCH_RESPONSE" | json_has_error; then
    echo "FAIL: Search Analytics query returned an error:"
    printf '%s' "$SEARCH_RESPONSE" | json_error_message
    exit 1
  fi
  echo "OK: Search Analytics endpoint is readable."
else
  echo "[3/5] Skipping Search Analytics query; no --gsc-site provided."
fi

echo "[4/5] Reading GA4 account summaries..."
GA4_ADMIN_RESPONSE="$(request -H "Authorization: Bearer $TOKEN" "https://analyticsadmin.googleapis.com/v1beta/accountSummaries")"
if printf '%s' "$GA4_ADMIN_RESPONSE" | json_has_error; then
  echo "FAIL: GA4 Admin API returned an error:"
  printf '%s' "$GA4_ADMIN_RESPONSE" | json_error_message
  exit 1
fi
GA4_ACCOUNT_COUNT="$(printf '%s' "$GA4_ADMIN_RESPONSE" | json_array_length "accountSummaries")"
echo "OK: GA4 account summaries visible: $GA4_ACCOUNT_COUNT"

if [[ -n "$GA4_PROPERTY" ]]; then
  echo "[5/5] Running minimal GA4 Data API report..."
  GA4_ID="$(property_id "$GA4_PROPERTY")"
  GA4_DATA_RESPONSE="$(request -X POST \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    "https://analyticsdata.googleapis.com/v1beta/properties/$GA4_ID:runReport" \
    -d '{"dateRanges":[{"startDate":"7daysAgo","endDate":"yesterday"}],"metrics":[{"name":"sessions"}],"limit":1}')"
  if printf '%s' "$GA4_DATA_RESPONSE" | json_has_error; then
    echo "FAIL: GA4 Data API returned an error:"
    printf '%s' "$GA4_DATA_RESPONSE" | json_error_message
    exit 1
  fi
  echo "OK: GA4 Data API endpoint is readable."
else
  echo "[5/5] Skipping GA4 Data API report; no --ga4-property provided."
fi

echo "DONE: ADC can read the requested Google APIs."
