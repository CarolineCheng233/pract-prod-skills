#!/bin/bash
# check_env.sh — Verify prerequisites before running any domain setup steps
# Checks: curl, jq, CF_API_TOKEN (Cloudflare), SPACESHIP_API_KEY + SPACESHIP_API_SECRET

set -euo pipefail

ERRORS=0

echo "Checking prerequisites..."
echo ""

# ── Tool checks ────────────────────────────────────────────

# Check curl
if ! command -v curl &>/dev/null; then
  echo "ERROR: curl is not installed"
  ERRORS=$((ERRORS + 1))
else
  echo "OK: curl $(curl --version | head -1 | awk '{print $2}')"
fi

# Check jq
if ! command -v jq &>/dev/null; then
  echo "ERROR: jq is not installed"
  echo "  Run: brew install jq"
  ERRORS=$((ERRORS + 1))
else
  echo "OK: jq $(jq --version)"
fi

echo ""

# ── Cloudflare credentials ─────────────────────────────────

if [ -z "${CF_API_TOKEN:-}" ]; then
  echo "ERROR: CF_API_TOKEN is not set"
  echo "  Run: export CF_API_TOKEN=\"your_cloudflare_token\""
  ERRORS=$((ERRORS + 1))
else
  # Verify token against Cloudflare API
  CF_VERIFY=$(curl -s -X GET "https://api.cloudflare.com/client/v4/user/tokens/verify" \
    -H "Authorization: Bearer $CF_API_TOKEN" \
    -H "Content-Type: application/json")
  CF_OK=$(echo "$CF_VERIFY" | jq -r '.success')
  if [ "$CF_OK" = "true" ]; then
    echo "OK: CF_API_TOKEN is valid"
  else
    echo "ERROR: CF_API_TOKEN is invalid or expired"
    echo "$CF_VERIFY" | jq -r '.errors[0].message // "unknown error"'
    ERRORS=$((ERRORS + 1))
  fi
fi

echo ""

# ── Brevo credentials (optional — only needed if using Brevo steps 9–11) ──

if [ -z "${BREVO_API_KEY:-}" ]; then
  echo "WARN:  BREVO_API_KEY is not set (required for Steps 9–11)"
  echo "  Run: export BREVO_API_KEY=\"your_brevo_api_key\""
  echo "  Get it from: app.brevo.com/settings/keys/api"
else
  # Verify Brevo key with a lightweight API call
  BREVO_VERIFY=$(curl -s -X GET "https://api.brevo.com/v3/account" \
    -H "api-key: $BREVO_API_KEY")
  BREVO_EMAIL=$(echo "$BREVO_VERIFY" | jq -r '.email // empty')
  if [ -n "$BREVO_EMAIL" ]; then
    echo "OK: BREVO_API_KEY is valid (account: $BREVO_EMAIL)"
  else
    echo "ERROR: BREVO_API_KEY is invalid or expired"
    echo "$BREVO_VERIFY" | jq -r '.message // "unknown error"'
    ERRORS=$((ERRORS + 1))
  fi
fi

echo ""

# ── Spaceship credentials ──────────────────────────────────

if [ -z "${SPACESHIP_API_KEY:-}" ]; then
  echo "ERROR: SPACESHIP_API_KEY is not set"
  echo "  Run: export SPACESHIP_API_KEY=\"your_spaceship_api_key\""
  ERRORS=$((ERRORS + 1))
else
  echo "OK: SPACESHIP_API_KEY is set"
fi

if [ -z "${SPACESHIP_API_SECRET:-}" ]; then
  echo "ERROR: SPACESHIP_API_SECRET is not set"
  echo "  Run: export SPACESHIP_API_SECRET=\"your_spaceship_api_secret\""
  ERRORS=$((ERRORS + 1))
else
  echo "OK: SPACESHIP_API_SECRET is set"
fi

# Verify Spaceship credentials if both are present
if [ -n "${SPACESHIP_API_KEY:-}" ] && [ -n "${SPACESHIP_API_SECRET:-}" ]; then
  SS_VERIFY=$(curl -s -X GET "https://spaceship.dev/api/v1/domains?take=1" \
    -H "X-API-Key: $SPACESHIP_API_KEY" \
    -H "X-API-Secret: $SPACESHIP_API_SECRET" \
    -H "Content-Type: application/json")
  # A valid response will have items array or empty result, not an auth error
  SS_STATUS=$(echo "$SS_VERIFY" | jq -r '.status // "ok"')
  if [ "$SS_STATUS" = "401" ] || [ "$SS_STATUS" = "403" ]; then
    echo "ERROR: SPACESHIP credentials are invalid"
    echo "$SS_VERIFY" | jq -r '.title // "unknown error"'
    ERRORS=$((ERRORS + 1))
  else
    echo "OK: SPACESHIP credentials are valid"
  fi
fi

echo ""

# ── Result ─────────────────────────────────────────────────

if [ "$ERRORS" -eq 0 ]; then
  echo '{"status":"ok","message":"All prerequisites met"}'
  exit 0
else
  echo "{\"status\":\"error\",\"errors\":$ERRORS,\"message\":\"$ERRORS prerequisite(s) failed\"}"
  exit 1
fi
