#!/bin/bash
# 08_click_verify_link.sh — Fetch a Cloudflare email verification URL to confirm it
# Usage: bash 08_click_verify_link.sh "<url>"
# Example: bash 08_click_verify_link.sh "https://cloudflare.com/verify?token=abc123"
#
# This script is called by Claude Code after it extracts the verification URL
# from Gmail using the Gmail MCP tool (search_emails + read_email).
#
# Output: JSON { status, url, http_code, verified }

set -euo pipefail

VERIFY_URL="${1:-}"

if [ -z "$VERIFY_URL" ]; then
  echo '{"error":"Missing argument: url","usage":"bash 08_click_verify_link.sh \"<verification_url>\""}' >&2
  exit 1
fi

# Follow redirects, capture final HTTP status code
# Note: --max-redirects is not supported on macOS curl, omitted for compatibility
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -L \
  --connect-timeout 15 \
  "$VERIFY_URL")

if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "302" ] || [ "$HTTP_CODE" = "301" ]; then
  echo "{\"status\":\"success\",\"url\":\"$VERIFY_URL\",\"http_code\":$HTTP_CODE,\"verified\":true}"
  exit 0
else
  echo "{\"status\":\"error\",\"url\":\"$VERIFY_URL\",\"http_code\":$HTTP_CODE,\"verified\":false}" >&2
  exit 1
fi
