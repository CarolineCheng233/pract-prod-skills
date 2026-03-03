---
name: dns-email-r2-setup
description: Automate full domain onboarding across Cloudflare, Spaceship, and Brevo, plus Cloudflare R2 storage bucket setup. Covers adding the domain to Cloudflare, DNS setup, nameserver updates on Spaceship, zone activation, email routing, destination email verification, Brevo transactional email domain authentication, and R2 bucket creation with API credentials written to the project .env.local file.
---

# Cloudflare + Spaceship + Brevo Domain Setup Skill

This skill automates the full domain onboarding workflow using the Cloudflare, Spaceship, and Brevo REST APIs via bash scripts in the `scripts/` directory.

## Prerequisites

Before running any steps, ensure the following environment variables are set and tools are installed:

| Variable | Required for | Description |
|----------|-------------|-------------|
| `CF_API_TOKEN` | Steps 1–8, 14–15 | Cloudflare API token (see required permissions below) |
| `CF_ACCOUNT_ID` | Steps 14–15 | Cloudflare Account ID (dashboard → right sidebar → Account ID) |
| `SPACESHIP_API_KEY` | Step 4 | Spaceship API key (spaceship.com → API Manager) |
| `SPACESHIP_API_SECRET` | Step 4 | Spaceship API secret (shown only once at creation) |
| `BREVO_API_KEY` | Steps 9–13 | Brevo API key (app.brevo.com/settings/keys/api) |
| `BREVO_SMTP_KEY` | Step 13 | Brevo SMTP key (Brevo → Settings → SMTP & API → SMTP tab) |

Tools required: `curl` (macOS built-in), `jq` (`brew install jq`)

**Cloudflare API Token required permissions:**

| Scope | Permission | Access |
|-------|-----------|--------|
| Account | Account Settings | Edit |
| Account | Workers R2 Storage | Edit |
| Zone | Email Routing Rules | Edit |
| Zone | Zone Settings | Edit |
| Zone | Zone | Edit |
| Zone | DNS | Edit |

> **R2 note:** `Workers R2 Storage: Edit` is only required if you plan to run Steps 14–15. If your token was created before adding R2 steps, edit it to add this permission (Account → Workers R2 Storage → Edit).

Always run the environment check first:

```bash
bash scripts/check_env.sh
```

`BREVO_API_KEY` is optional — if not set, `check_env.sh` prints a warning (not an error) and Steps 9–11 are skipped.

---

## User Inputs

Collect the following from the user before executing any steps:

### Required
- **Domain name** — the domain to configure (e.g. `example.com`)

### Step 1 Options (ask the user, defaults shown)

**DNS scan method:**
- `quick` *(default)* — Cloudflare auto-scans and imports common DNS records
- `manual` — enter DNS records manually after setup
- `zone_file` — upload a DNS zone file after setup

**Block AI training bots:**
- `none` *(default)* — allow all AI crawlers
- `all` — block on all pages
- `ads` — block only on hostnames with ads

**Instruct AI bots via robots.txt:**
- `true` *(default)*
- `false`

### Step 7 Options (ask the user)
- **Email forward prefix** — e.g. `contact` → becomes `contact@example.com`
- **Destination email** — e.g. `you@gmail.com`

---

## Workflow

Execute steps **in order**. Each step returns JSON — capture and pass results to subsequent steps.

> ⚠️ **Important:** Steps 6 and 7 (Email Routing) require the zone to be **active**. They cannot be run in parallel with Steps 4–5. Email Routing is only available after Cloudflare confirms the nameserver change.

---

### Step 1 — Add Domain to Cloudflare

```bash
bash scripts/01_add_domain.sh <domain> [dns_method] [block_ai] [robots_txt]
# Defaults: dns_method=quick  block_ai=none  robots_txt=true
# Example:  bash scripts/01_add_domain.sh example.com quick none true
```

**Returns:**
```json
{ "zone_id": "<zone_id>", "domain": "example.com", "status": "pending" }
```

Save `zone_id` — required for all subsequent steps.

---

### Step 2 — Delete Default DNS Records

```bash
bash scripts/02_delete_dns_records.sh <zone_id>
```

**Returns:**
```json
{ "deleted": ["<id1>", "<id2>"], "count": 2, "skipped": [] }
```

---

### Step 3 — Get Cloudflare Nameservers

```bash
bash scripts/03_get_nameservers.sh <zone_id>
```

**Returns:**
```json
{ "zone_id": "<zone_id>", "domain": "example.com", "nameservers": ["<ns1>", "<ns2>"] }
```

Save `nameservers[0]` and `nameservers[1]` — required for Step 4.

---

### Step 4 — Update Nameservers on Spaceship

Use the nameservers from Step 3 to update the domain at the Spaceship registrar.

```bash
bash scripts/04_update_nameservers.sh <domain> <ns1> <ns2>
# Example: bash scripts/04_update_nameservers.sh example.com <ns1> <ns2>
```

**Returns:**
```json
{ "domain": "example.com", "nameservers": ["<ns1>", "<ns2>"], "status": "updated" }
```

---

### Step 5 — Wait for Zone Activation

After updating nameservers, Cloudflare needs to verify the change before the zone becomes active. This step triggers a verification check and polls until the zone is active.

```bash
bash scripts/05_verify_zone.sh <zone_id> [timeout_seconds]
# Default timeout: 300 seconds (5 minutes). DNS propagation can take up to 24 hours.
# Example: bash scripts/05_verify_zone.sh <zone_id> 300
```

**Returns (success):**
```json
{ "zone_id": "<zone_id>", "status": "active", "elapsed_seconds": 60 }
```

**Returns (timeout):**
```json
{ "zone_id": "<zone_id>", "status": "pending", "elapsed_seconds": 300, "warning": "timeout_reached — DNS propagation may still be in progress. Re-run this script or check Cloudflare dashboard." }
```

If timeout is reached, inform the user that DNS propagation is still in progress. They should check the Cloudflare dashboard and re-run Step 5 later. **Do not proceed to Steps 6–7 until status is `active`.**

---

### Step 6 — Enable Email Routing

> Requires zone status = `active` from Step 5.

```bash
bash scripts/06_enable_email_routing.sh <zone_id>
```

**Returns:**
```json
{ "enabled": true, "zone_id": "<zone_id>" }
```

If `"already_enabled": true` is present — not an error, continue.

---

### Step 7 — Add Email Forwarding Rule

```bash
bash scripts/07_add_email_rule.sh <zone_id> <from_prefix> <to_email>
# Example: bash scripts/07_add_email_rule.sh <zone_id> contact you@gmail.com
```

**Returns:**
```json
{ "rule_id": "<rule_id>", "from": "contact@example.com", "to": "you@gmail.com", "enabled": true }
```

---

### Step 8 — Verify Destination Email

After Step 7, Cloudflare sends a verification email to the destination address. Follow this decision tree exactly:

#### 8a — Check if auto-verification is possible

Evaluate ALL three conditions:

1. **Is the destination email a Gmail address?**
   - Check: does `<to_email>` end with `@gmail.com` or `@googlemail.com`?
   - If not Gmail → skip to [Manual fallback](#manual-fallback) immediately.

2. **Is Gmail MCP installed and available?**
   - Check: attempt to call the Gmail MCP tool `search_emails` with query `from:noreply@cloudflare.com` and `maxResults: 1`.
   - If the tool is not available (MCP not installed / not running) → skip to [Manual fallback](#manual-fallback).

3. **Is the authenticated Gmail account the same as the destination email?**
   - After calling `search_emails`, check the `from` address on returned results, or call `get_profile` if available to get the authenticated email.
   - Alternatively: attempt a search restricted to the inbox — if results come back, the account matches.
   - If the authenticated account does not match `<to_email>` → skip to [Manual fallback](#manual-fallback).

If **all three conditions pass** → proceed to [Auto-verification](#auto-verification).

---

#### Auto-verification

Use Gmail MCP to search for the Cloudflare verification email. Poll up to 5 times with 30-second waits between attempts (total ~2.5 minutes):

```
Gmail MCP tool: search_emails
Query: "from:cloudflare.com subject:verify newer_than:10m"
maxResults: 5
```

Once an email is found:

```
Gmail MCP tool: read_email
messageId: <id from search result>
```

From the email body, extract the verification URL. It will match one of these patterns:
- `https://dash.cloudflare.com/email_fwdr/verify?token=...`
- `https://cloudflare.com/...` containing `verify` or a long token

Print the URL to the user, then open it using **Playwright** (required because Cloudflare uses browser challenges that block curl):

```
Playwright MCP tool: browser_navigate
url: "<extracted_url>"
```

After navigation, take a screenshot to confirm verification:

```
Playwright MCP tool: browser_take_screenshot
type: png
fullPage: true
```

Check the screenshot or page snapshot for text like "Your email address is now verified" to confirm success. Inform the user: "Email verified successfully. Email forwarding is now active."

> **Note:** `scripts/08_click_verify_link.sh` (curl-based) is available as a fallback but will likely return 403 due to Cloudflare's browser challenge. Prefer Playwright.

If polling times out (5 attempts, no email found), tell the user to check their spam folder and offer to retry.

---

#### Manual fallback

If any condition in 8a is not met, display this message to the user:

```
⚠️  Auto-verification not available.

Please verify manually:
1. Check the inbox of <to_email>
2. Look for an email from noreply@cloudflare.com with subject "Verify your email address"
3. Click the verification link in that email

Email forwarding will not work until this step is completed.
```

---

## Brevo Domain Authentication (Steps 9–11)

> **Prerequisite check:** Before starting Step 9, verify that `BREVO_API_KEY` was present and valid when `check_env.sh` was run. If it was not set (showed `WARN` not `ERROR`), skip Steps 9–11 entirely and inform the user that Brevo setup requires `BREVO_API_KEY`.

These steps configure the domain in Brevo for transactional email sending and add the required DNS records to Cloudflare automatically.

---

### Step 9 — Add Domain to Brevo

```bash
bash scripts/09_brevo_add_domain.sh <domain>
# Example: bash scripts/09_brevo_add_domain.sh example.com
```

**Returns:**
```json
{
  "domain_id": "abc123",
  "domain_name": "example.com",
  "domain_provider": "Cloudflare",
  "dkim_format": "cname",
  "dns_records": {
    "brevo_code": { "host_name": "@", "type": "TXT", "value": "brevo-code=abc123", "status": false },
    "dkim_record": null,
    "dkim1Record": { "host_name": "brevo1._domainkey", "type": "CNAME", "value": "b1.example-com.dkim.brevo.com", "status": false },
    "dkim2Record": { "host_name": "brevo2._domainkey", "type": "CNAME", "value": "b2.example-com.dkim.brevo.com", "status": false },
    "dmarc_record": { "host_name": "_dmarc", "type": "TXT", "value": "v=DMARC1; p=none; rua=...", "status": false }
  }
}
```

`dkim_format` values: `"cname"` (new accounts, two CNAME records), `"txt"` (old accounts, single TXT), `"none"` (not yet available).

Pipe the output directly to Step 10, or save it for reference.

---

### Step 10 — Add Brevo DNS Records to Cloudflare

Pipe Step 9 output directly to Step 10. The script auto-detects DKIM format (CNAME vs TXT) from the `dkim_format` field.

```bash
# Preferred: pipe Step 9 output directly
bash scripts/09_brevo_add_domain.sh example.com | bash scripts/10_brevo_add_dns_records.sh <zone_id>

# Alternative: pass saved JSON as second argument
bash scripts/10_brevo_add_dns_records.sh <zone_id> '<json_from_step9>'
```

The script automatically:
- Adds `brevo_code` TXT record on `@`
- Adds DKIM as CNAME (`dkim1Record` + `dkim2Record`) or TXT (`dkim_record`) based on `dkim_format`
- Adds or updates `_dmarc` TXT record (appends Brevo `rua` tag if DMARC already exists)
- Skips records that already exist (not an error)
- Warns on null/missing values (not a hard failure)

**Returns:**
```json
{ "records_added": ["TXT @", "CNAME brevo1._domainkey", "CNAME brevo2._domainkey", "TXT _dmarc"], "records_skipped": [], "warnings": [], "count": 4 }
```

---

### Step 11 — Authenticate Domain in Brevo

Trigger Brevo's authentication check and poll until all records are verified. DNS propagation can take up to 48 hours; the script polls for up to 5 minutes by default and exits gracefully on timeout.

```bash
bash scripts/11_brevo_authenticate.sh <domain> [timeout_seconds]
# Default timeout: 300 seconds. Re-run later if DNS hasn't propagated.
# Example: bash scripts/11_brevo_authenticate.sh example.com 300
```

**Returns (success):**
```json
{ "domain": "example.com", "authenticated": true, "elapsed_seconds": 60, "dns_records_status": { "brevo_code": true, "dkim": true, "dmarc": true } }
```

**Returns (timeout):**
```json
{ "domain": "example.com", "authenticated": false, "elapsed_seconds": 300, "dns_records_status": { "brevo_code": true, "dkim": false, "dmarc": true }, "warning": "timeout_reached — re-run this script later or check Brevo dashboard." }
```

If timeout is reached, display the `dns_records_status` to the user so they know which specific record hasn't propagated yet. They can re-run Step 11 later without needing to redo Steps 9–10.

> **When Step 11 succeeds (`authenticated: true`), immediately proceed to Step 12 — do not stop to ask the user.**

---

### Step 12 — Send Test Email (Verification)

> **This step is automatic.** When Step 11 succeeds, execute Step 12 immediately without asking.

After Brevo authentication completes, send a test email from the domain via Brevo's transactional API to verify end-to-end delivery.

**Determining `from_email` and `to_email`:**
- `from_email`: use the email forwarding address configured in Step 7 (e.g. `contact@example.com`). If Step 7 was not executed in this session, use `contact@<domain>` as default.
- `to_email`: use the Brevo account email (shown by `check_env.sh` as the BREVO_API_KEY owner), or the destination email from Step 7 if available.

```bash
bash scripts/12_test_email.sh <from_email> <to_email> [from_name]
# Example: bash scripts/12_test_email.sh contact@example.com you@gmail.com "Example Support"
```

**Returns (success):**
```json
{ "status": "sent", "message_id": "<...@smtp-relay.mailin.fr>", "from": "contact@example.com", "to": "you@gmail.com", "timestamp": "2026-02-26T17:04:00Z" }
```

After sending, verify delivery:

1. **If Gmail MCP is available and destination is Gmail:** Search for the email using Gmail MCP:
   ```
   Gmail MCP tool: gmail_search_messages
   Query: "from:<from_email> subject:\"Domain email test\" newer_than:5m"
   maxResults: 5
   ```
   If found in inbox (not spam), email setup is fully verified.

2. **Manual fallback:** Ask the user to check their inbox for the test email.

---

## Gmail "Send mail as" Configuration (Step 13)

> **Prerequisite:** Steps 7 (email forwarding), 9–11 (Brevo authentication) must be completed. `BREVO_SMTP_KEY` must be set.

This step retrieves SMTP credentials and outputs step-by-step instructions for the user to manually configure Gmail's "Send mail as" feature. The user will be able to send emails from their custom domain address (e.g. `contact@example.com`) directly in Gmail, using Brevo as the SMTP relay.

---

### Step 13 — Get SMTP Config & Display Setup Instructions

```bash
bash scripts/13_gmail_send_as_config.sh <domain> <from_prefix>
# Use the same from_prefix from Step 7
# Example: bash scripts/13_gmail_send_as_config.sh example.com contact
```

**Returns:**
```json
{
  "smtp_server": "smtp-relay.brevo.com",
  "smtp_port": 587,
  "smtp_login": "<your-brevo-smtp-login>@smtp-brevo.com",
  "smtp_password_env": "BREVO_SMTP_KEY",
  "display_name": "ExampleCom Team",
  "from_email": "contact@example.com",
  "domain": "example.com",
  "tls": true
}
```

After getting the JSON, **display detailed setup instructions to the user** with all values filled in. Use the template below, substituting values from the JSON output and the actual `BREVO_SMTP_KEY` environment variable value:

````
📧 Gmail "Send mail as" Setup Instructions

Please follow these steps to add {from_email} as a send-as address in Gmail:

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Step 1: Open Gmail Settings
   → Open https://mail.google.com/mail/u/0/#settings/accounts
   → Or: Gmail → ⚙️ Settings (gear icon) → See all settings → "Accounts and Import" tab

Step 2: Add another email address
   → In the "Send mail as" section, click "Add another email address"
   → A popup window will open

Step 3: Fill in your identity (popup window page 1)
   → Name:  {display_name}
   → Email: {from_email}
   → Click "Next Step"

Step 4: Fill in SMTP settings (popup window page 2)
   → SMTP Server: smtp-relay.brevo.com
   → Port:        587
   → Username:    {smtp_login}
   → Password:    {actual BREVO_SMTP_KEY value}
   → Security:    ◉ Secured connection using TLS (recommended)
   → Click "Add Account"

Step 5: Verify ownership
   → Gmail will send a verification email to {from_email}
   → This email is forwarded to your Gmail inbox via Cloudflare Email Routing
   → Open the verification email and enter the confirmation code in the popup
   → Click "Verify"

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

✅ Once verified, you can compose emails in Gmail and select
   "{display_name} <{from_email}>" in the "From" dropdown.
````

**Important:** Print the actual `BREVO_SMTP_KEY` value in the password field (read from the environment variable), so the user can copy-paste it directly. Do NOT print just the env var name.

---

## Error Handling

- If any script exits non-zero, surface the raw error JSON to the user and stop.
- Step 1: if zone already exists, returns `"note": "zone_already_exists"` — not an error, continue.
- Step 5: if timeout is reached without `active` status, stop and ask the user to wait and retry.
- Step 6: if Email Routing already enabled, returns `"already_enabled": true` — not an error, continue.
- Step 7: if rule already exists for the same address, returns `"note": "rule_already_exists"` — not an error, continue.
- Step 8: Gmail MCP search fails → fall back to manual. Playwright navigation fails or page does not show "verified" → tell user to click the link manually in their browser, or request a new verification email from Cloudflare dashboard → Email → Routing rules → Destination addresses.
- Step 9: if domain already exists in Brevo, returns `"note": "domain_already_exists"` with existing DNS record data — not an error, pass the DNS data to Step 10 as normal.
- Step 10: records already present are skipped (not errors). DMARC is updated (not replaced) if it exists.
- Step 11: timeout is not a hard failure — DNS propagation can take up to 48 hours. Tell the user to re-run Step 11 once they believe DNS has propagated.
- Step 12: if Brevo API returns an error (e.g. sender not authorized), surface the error. If the test email is sent but not found via Gmail MCP, ask the user to check spam folder manually.
- Step 13: if `BREVO_SMTP_KEY` is not set, surface the error with the hint to find it at Brevo → Settings → SMTP & API. If the Brevo API call fails, surface the raw error JSON.

---

## R2 Storage Setup (Steps 14–17)

> **Prerequisite:** `CF_ACCOUNT_ID` must be set and `CF_API_TOKEN` must have `Workers R2 Storage: Edit` permission. R2 must also be enabled for the account — if not yet enabled, go to Cloudflare Dashboard → R2 Object Storage → click **Enable R2** (requires a payment method on file). These steps are independent of the DNS/email steps above and can be run on their own.

Steps 14–15 are automated. Steps 16–17 are manual (dashboard + .env.local editing).

**Bucket naming:** R2 bucket names cannot contain dots. Replace `.` with `-` when converting a domain to a bucket name (e.g. `example.com` → `example-com`).

---

### Step 14 — Create R2 Bucket

Creates a bucket with automatic location and Standard storage class. **Convert the domain to a valid bucket name by replacing `.` with `-`** before passing it (e.g. `example.com` → `example-com`).

```bash
bash scripts/14_r2_create_bucket.sh <bucket_name>
# Example: bash scripts/14_r2_create_bucket.sh example-com
```

**Returns:**
```json
{ "bucket_name": "example-com", "location": "auto", "storage_class": "Standard", "created": true }
```

If `"note": "bucket_already_exists"` is present — not an error, continue.

---

### Step 15 — Enable Public Development URL

Enables the R2 public development URL so objects can be accessed via HTTPS without extra configuration.

```bash
bash scripts/15_r2_enable_public_url.sh <bucket_name>
# Example: bash scripts/15_r2_enable_public_url.sh example-com
```

**Returns:**
```json
{ "bucket_name": "example-com", "public_url": "https://example-com.<account_id>.r2.dev", "enabled": true }
```

Save `public_url` — used for `STORAGE_DOMAIN` in Step 17. In production, replace this with your custom CDN domain.

---

### Step 16 — Create R2 API Token (Manual — Dashboard Only)

> **This step is manual.** Creating R2 API tokens via the REST API requires `User API Tokens: Edit` — a high-privilege scope that would allow the token to create tokens with any permission. To avoid granting excessive access, this step is done in the Cloudflare Dashboard.

Display the following instructions to the user and wait for them to provide the three values:

---

```
📦 R2 API Token Setup (Manual)

Please follow these steps in the Cloudflare Dashboard:

1. Open: https://dash.cloudflare.com → R2 Object Storage → Overview
2. Click "Manage R2 API Tokens" (top right)
3. Click "Create API token"
4. Configure:
   - Token name:   <bucket_name>-rw
   - Permissions:  Object Read & Write
   - Apply to:     ✓ Specify bucket(s) → select "<bucket_name>"
5. Click "Create API Token"
6. Copy the following (shown only once):
   - Access Key ID
   - Secret Access Key
   - Endpoint  (format: https://<account_id>.r2.cloudflarestorage.com)

⚠️  The Secret Access Key is shown only once. Save it immediately.
```

---

Once the user provides all three values, proceed to Step 17.

---

### Step 17 — Write Storage Config to .env.local

Use the Edit tool to write the known values directly into the project's `.env.local` file, then show the user what still needs to be filled in manually.

**What Claude already knows from previous steps:**
- `STORAGE_BUCKET` — bucket name from Step 14
- `STORAGE_DOMAIN` — public dev URL from Step 15
- `STORAGE_REGION` — always `auto`

**What the user must fill in manually (from Step 16):**
- `STORAGE_ENDPOINT` — format: `https://<account_id>.r2.cloudflarestorage.com`
- `STORAGE_ACCESS_KEY` — Access Key ID
- `STORAGE_SECRET_KEY` — Secret Access Key

Use the Edit tool to set or update these lines in the project's `.env.local` file (ask the user for the path if unknown; default is `<project_root>/.env.local`):

```
STORAGE_ENDPOINT=（待填写）
STORAGE_REGION=auto
STORAGE_ACCESS_KEY=（待填写）
STORAGE_SECRET_KEY=（待填写）
STORAGE_BUCKET=<actual bucket name from Step 14>
STORAGE_DOMAIN=<actual public_url from Step 15>
```

After writing, display this message to the user:

```
✅ 已写入 .env.local：STORAGE_BUCKET、STORAGE_DOMAIN、STORAGE_REGION

请手动填写以下三项（值来自 Step 16 Dashboard 页面）：
  STORAGE_ENDPOINT=https://<account_id>.r2.cloudflarestorage.com
  STORAGE_ACCESS_KEY=<Access Key ID>
  STORAGE_SECRET_KEY=<Secret Access Key>

注意：.env.local 包含密钥，确保已加入 .gitignore
```

---

### R2 Error Handling

- Step 14: bucket already exists → `"note": "bucket_already_exists"` — not an error, continue.
- Step 15: if the API returns an error about the bucket not existing, make sure Step 14 ran successfully first.
- Step 16: if the user cannot find "Manage R2 API Tokens" in the dashboard, make sure R2 has been enabled for the account (R2 Overview page → Enable R2). If "Specify bucket(s)" option is missing, R2 may not have any buckets yet — ensure Step 14 completed successfully first.
- Step 17: if `.env.local` does not exist in the project root, create it. If the user asks why not `.env`, explain that `.env.local` takes precedence in Next.js and is conventionally excluded from version control.

---

## Reference

See `REFERENCE.md` for full API endpoint documentation and response schemas.
