#!/bin/bash
# 12_test_email.sh — Send a test email via Brevo API to verify domain email setup
# Usage: bash 12_test_email.sh <from_email> <to_email> [from_name]
# Example: bash 12_test_email.sh contact@example.com you@gmail.com "Example Support"
#
# Requires: BREVO_API_KEY environment variable
#
# Sends a test email via Brevo transactional API (POST /v3/smtp/email).
# This verifies that:
#   1. The domain is properly authenticated in Brevo
#   2. Brevo can send emails on behalf of the domain
#   3. The email actually arrives at the destination
#
# Output: JSON { status, message_id, from, to }

set -euo pipefail

FROM_EMAIL="${1:-}"
TO_EMAIL="${2:-}"
FROM_NAME="${3:-Test}"

if [ -z "$FROM_EMAIL" ] || [ -z "$TO_EMAIL" ]; then
  echo '{"error":"Missing arguments","usage":"bash 12_test_email.sh <from_email> <to_email> [from_name]"}' >&2
  exit 1
fi

if [ -z "${BREVO_API_KEY:-}" ]; then
  echo '{"error":"BREVO_API_KEY is not set"}' >&2
  exit 1
fi

BREVO_BASE="https://api.brevo.com/v3"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
DOMAIN=$(echo "$FROM_EMAIL" | cut -d@ -f2)

RESPONSE=$(curl -s -X POST "$BREVO_BASE/smtp/email" \
  -H "api-key: $BREVO_API_KEY" \
  -H "accept: application/json" \
  -H "content-type: application/json" \
  --data "$(jq -n \
    --arg from_name "$FROM_NAME" \
    --arg from_email "$FROM_EMAIL" \
    --arg to_email "$TO_EMAIL" \
    --arg subject "Domain email test — $TIMESTAMP" \
    --arg html "<html><body><h2>Email Setup Verification</h2><p>This is a test email sent via Brevo API from <strong>$FROM_EMAIL</strong>.</p><p>If you received this email, your domain email setup is working correctly.</p><p>Sent at: $TIMESTAMP</p></body></html>" \
    '{
      sender: { name: $from_name, email: $from_email },
      to: [{ email: $to_email }],
      subject: $subject,
      htmlContent: $html
    }')")

# Check for messageId in response (success)
MESSAGE_ID=$(echo "$RESPONSE" | jq -r '.messageId // empty')

if [ -n "$MESSAGE_ID" ]; then
  echo "{\"status\":\"sent\",\"message_id\":\"$MESSAGE_ID\",\"from\":\"$FROM_EMAIL\",\"to\":\"$TO_EMAIL\",\"timestamp\":\"$TIMESTAMP\"}"
  exit 0
fi

# Error
ERROR_MSG=$(echo "$RESPONSE" | jq -r '.message // "unknown error"')
ERROR_CODE=$(echo "$RESPONSE" | jq -r '.code // "unknown"')
echo "{\"status\":\"error\",\"code\":\"$ERROR_CODE\",\"message\":\"$ERROR_MSG\"}" >&2
exit 1
