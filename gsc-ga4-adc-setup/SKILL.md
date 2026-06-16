---
name: gsc-ga4-adc-setup
description: Use when setting up or troubleshooting local Google Application Default Credentials for Google Search Console and GA4 APIs, including OAuth client setup, scopes, quota project, and read-only verification.
---

# GSC/GA4 ADC Setup

Use this skill to help a user configure local Application Default Credentials (ADC) for read-only Google Search Console and Google Analytics 4 API access.

Keep the workflow generic. Do not bake project-specific domains, property IDs, account emails, OAuth client secrets, tokens, or business data into the skill or scripts.

## Boundaries

- Prefer read-only verification before any setup change.
- Never print access tokens, refresh tokens, OAuth client secrets, cookies, or raw credential JSON.
- Keep OAuth client JSON outside repositories, for example under `~/.config/gcloud/`.
- Do not modify Search Console or GA4 property permissions unless the user explicitly asks.
- Do not assume Google Cloud IAM grants access to GSC or GA4 data; product-level property permissions are separate.

## Mental Model

```text
ADC account + OAuth scopes = who is calling and what API categories are allowed
GSC / GA4 property permissions = which data that account can read
quota project = which Cloud Project supplies API enablement, quota, and billing context
OAuth client = which app is asking the user for delegated consent
```

One ADC login can usually read future GSC or GA4 properties if the same Google account is granted access to those properties and the existing scopes cover the required APIs.

## Required Scopes

For the usual read-only GSC and GA4 workflow, request:

```text
https://www.googleapis.com/auth/cloud-platform
https://www.googleapis.com/auth/webmasters.readonly
https://www.googleapis.com/auth/analytics.readonly
```

`cloud-platform` may be required by `gcloud auth application-default login` even when the target data APIs are GSC and GA4.

## Setup Workflow

1. Pick an active Google Cloud Project to act as the quota/OAuth project.

   ```bash
   gcloud projects list
   gcloud config set project PROJECT_ID
   ```

2. Enable the required APIs on that project.

   ```bash
   gcloud services enable \
     searchconsole.googleapis.com \
     analyticsdata.googleapis.com \
     analyticsadmin.googleapis.com \
     cloudresourcemanager.googleapis.com \
     --project=PROJECT_ID
   ```

3. In Google Cloud Console, create or reuse an OAuth consent screen for the chosen project.

   For local scripts, use a Desktop OAuth client. If the app is in testing mode, add the user's Google account as a test user. If the app is unverified, a developer-owned local client may show an advanced warning that the user can choose to continue through.

4. Download the Desktop OAuth client JSON and store it outside the repository.

   ```text
   ~/.config/gcloud/oauth-client.json
   ```

5. Run ADC login with the Desktop OAuth client.

   ```bash
   gcloud auth application-default login \
     --client-id-file="$HOME/.config/gcloud/oauth-client.json" \
     --scopes=https://www.googleapis.com/auth/cloud-platform,https://www.googleapis.com/auth/webmasters.readonly,https://www.googleapis.com/auth/analytics.readonly
   ```

6. Set the ADC quota project.

   ```bash
   gcloud auth application-default set-quota-project PROJECT_ID
   ```

7. Verify access without printing tokens.

   ```bash
   "$HOME/.codex/skills/gsc-ga4-adc-setup/scripts/verify-gsc-ga4-adc.sh" \
     --gsc-site "sc-domain:example.com" \
     --ga4-property "properties/123456789"
   ```

## Manual Verification Commands

Generate a token only into a shell variable:

```bash
TOKEN="$(gcloud auth application-default print-access-token)"
```

List Search Console sites:

```bash
curl -s -H "Authorization: Bearer $TOKEN" \
  "https://www.googleapis.com/webmasters/v3/sites"
```

List GA4 accounts and properties:

```bash
curl -s -H "Authorization: Bearer $TOKEN" \
  "https://analyticsadmin.googleapis.com/v1beta/accountSummaries"
```

Run a minimal GA4 report:

```bash
curl -s -X POST \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  "https://analyticsdata.googleapis.com/v1beta/properties/PROPERTY_ID:runReport" \
  -d '{"dateRanges":[{"startDate":"7daysAgo","endDate":"yesterday"}],"metrics":[{"name":"sessions"}],"limit":1}'
```

For `properties/123456789`, `PROPERTY_ID` is `123456789`.

## Common Errors

- `insufficient authentication scopes`: The current ADC token lacks `webmasters.readonly` or `analytics.readonly`; rerun ADC login with the full scope list.
- `cloud-platform scope is required but not requested`: Add `https://www.googleapis.com/auth/cloud-platform` to `--scopes`.
- `access_denied` with testing message: The OAuth app is in testing mode and the selected Google account is not listed as a test user.
- Unverified app warning: The OAuth app requests sensitive scopes and has not completed Google verification. For a developer-owned local workflow, the user can continue through the advanced warning if they trust the OAuth client.
- `cloudresourcemanager.googleapis.com not enabled`: Enable Cloud Resource Manager API on the quota project, then retry `set-quota-project`.
- Console cannot find a project that `gcloud projects list` shows: Search by project name, project ID, and project number; confirm the browser is using the same Google account and project selector filters are cleared.
- `environment tag` warning: This is a governance reminder, not a failed `gcloud config set project`.
- Empty GSC rows with no API error: Try recent complete dates first; for very fresh data, use `dataState=all`.

## ADC vs Service Account

Use ADC with user credentials when:

- The user is running local scripts or Codex automations on their own machine.
- The same Google account already has GSC and GA4 product permissions.
- Simplicity matters more than headless production-grade credential management.

Use a service account when:

- The job must run reliably on a server without user login.
- The organization wants credential ownership independent of one user account.
- The service account can be added to Search Console and GA4 properties.

Service account creation itself is not normally a paid resource, but API usage and any surrounding infrastructure may have quotas or costs.
