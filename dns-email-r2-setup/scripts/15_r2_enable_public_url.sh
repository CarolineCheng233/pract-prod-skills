#!/bin/bash
# 15_r2_enable_public_url.sh — Enable public development URL for an R2 bucket
# Usage: bash scripts/15_r2_enable_public_url.sh <bucket_name>
# Env:   CF_API_TOKEN, CF_ACCOUNT_ID
#
# The public dev URL format is: https://{bucket_name}.{account_id}.r2.dev

set -euo pipefail

BUCKET_NAME="${1:-}"
if [ -z "$BUCKET_NAME" ]; then
  echo '{"error":"Missing argument: bucket_name"}' >&2
  exit 1
fi

CF_ACCOUNT_ID="${CF_ACCOUNT_ID:-}"
CF_API_TOKEN="${CF_API_TOKEN:-}"

if [ -z "$CF_ACCOUNT_ID" ] || [ -z "$CF_API_TOKEN" ]; then
  echo '{"error":"CF_ACCOUNT_ID and CF_API_TOKEN must be set"}' >&2
  exit 1
fi

RESPONSE=$(curl -s -X PUT \
  "https://api.cloudflare.com/client/v4/accounts/$CF_ACCOUNT_ID/r2/buckets/$BUCKET_NAME/domains/managed" \
  -H "Authorization: Bearer $CF_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"enabled":true}')

SUCCESS=$(echo "$RESPONSE" | jq -r '.success')

if [ "$SUCCESS" = "true" ]; then
  # Public dev URL is derived from account ID and bucket name
  PUBLIC_URL="https://${BUCKET_NAME}.${CF_ACCOUNT_ID}.r2.dev"
  echo "{\"bucket_name\":\"$BUCKET_NAME\",\"public_url\":\"$PUBLIC_URL\",\"enabled\":true}"
else
  ERROR_MSG=$(echo "$RESPONSE" | jq -r '.errors[0].message // "unknown error"')
  echo "{\"error\":\"$ERROR_MSG\",\"raw\":$RESPONSE}" >&2
  exit 1
fi
