#!/bin/bash
# 13_gmail_send_as_config.sh — Generate Gmail "Send mail as" SMTP configuration
# Usage: bash 13_gmail_send_as_config.sh <domain> <from_prefix>
# Example: bash 13_gmail_send_as_config.sh example.com contact
# Requires: BREVO_API_KEY, BREVO_SMTP_KEY environment variables

set -euo pipefail

DOMAIN="${1:?Usage: bash 13_gmail_send_as_config.sh <domain> <from_prefix>}"
FROM_PREFIX="${2:?Usage: bash 13_gmail_send_as_config.sh <domain> <from_prefix>}"

# Check BREVO_SMTP_KEY
if [ -z "${BREVO_SMTP_KEY:-}" ]; then
  echo '{"error":"BREVO_SMTP_KEY is not set","hint":"Find it at Brevo → Settings → SMTP & API → SMTP tab → SMTP Key"}' >&2
  exit 1
fi

# Check BREVO_API_KEY
if [ -z "${BREVO_API_KEY:-}" ]; then
  echo '{"error":"BREVO_API_KEY is not set"}' >&2
  exit 1
fi

# Get Brevo SMTP login (relay.data.userName, fallback to account email)
ACCOUNT_RESP=$(curl -s -X GET "https://api.brevo.com/v3/account" \
  -H "api-key: $BREVO_API_KEY")
SMTP_LOGIN=$(echo "$ACCOUNT_RESP" | jq -r '.relay.data.userName // .email // empty')

if [ -z "$SMTP_LOGIN" ]; then
  echo '{"error":"Failed to get Brevo SMTP login","response":'"$ACCOUNT_RESP"'}' >&2
  exit 1
fi

# Generate display name: split full domain by hyphens and dots, CamelCase each part, append " Team"
# e.g. my-app.com → MyApp Team, my-cool-site.com → MyCoolSiteCom Team
DISPLAY_NAME=$(echo "$DOMAIN" | awk -F'[-.]' '{
  result=""
  for(i=1;i<=NF;i++) {
    word=$i
    result = result toupper(substr(word,1,1)) substr(word,2)
  }
  print result
}')
DISPLAY_NAME="${DISPLAY_NAME} Team"

FROM_EMAIL="${FROM_PREFIX}@${DOMAIN}"

jq -n \
  --arg smtp_server "smtp-relay.brevo.com" \
  --argjson smtp_port 587 \
  --arg smtp_login "$SMTP_LOGIN" \
  --arg smtp_password_env "BREVO_SMTP_KEY" \
  --arg display_name "$DISPLAY_NAME" \
  --arg from_email "$FROM_EMAIL" \
  --arg domain "$DOMAIN" \
  --argjson tls true \
  '{
    smtp_server: $smtp_server,
    smtp_port: $smtp_port,
    smtp_login: $smtp_login,
    smtp_password_env: $smtp_password_env,
    display_name: $display_name,
    from_email: $from_email,
    domain: $domain,
    tls: $tls
  }'
