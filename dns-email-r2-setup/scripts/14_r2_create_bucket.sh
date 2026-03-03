#!/bin/bash
# 14_r2_create_bucket.sh — Create a Cloudflare R2 bucket
# Usage: bash scripts/14_r2_create_bucket.sh <bucket_name>
# Env:   CF_API_TOKEN, CF_ACCOUNT_ID

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

RESPONSE=$(curl -s -X POST \
  "https://api.cloudflare.com/client/v4/accounts/$CF_ACCOUNT_ID/r2/buckets" \
  -H "Authorization: Bearer $CF_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"name\":\"$BUCKET_NAME\",\"locationHint\":\"auto\",\"storageClass\":\"Standard\"}")

SUCCESS=$(echo "$RESPONSE" | jq -r '.success')

if [ "$SUCCESS" = "true" ]; then
  echo "{\"bucket_name\":\"$BUCKET_NAME\",\"location\":\"auto\",\"storage_class\":\"Standard\",\"created\":true}"
else
  ERROR_MSG=$(echo "$RESPONSE" | jq -r '.errors[0].message // "unknown error"')
  # Bucket already exists is not a fatal error
  if echo "$ERROR_MSG" | grep -qi "already exists"; then
    echo "{\"bucket_name\":\"$BUCKET_NAME\",\"created\":false,\"note\":\"bucket_already_exists\"}"
  else
    echo "{\"error\":\"$ERROR_MSG\",\"raw\":$RESPONSE}" >&2
    exit 1
  fi
fi
