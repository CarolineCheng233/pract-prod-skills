---
name: supabase-project-creator
description: Create a new Supabase project and configure the local development environment automatically. Use this skill whenever the user wants to create a Supabase project, set up Supabase for a new app, initialize Supabase credentials, or says things like "create a supabase project", "set up supabase", "init supabase", "connect supabase", or "configure supabase for this project". Also trigger when users mention needing a database for their project and Supabase is a reasonable choice.
---

# Supabase Project Creator

Create a Supabase project via MCP, retrieve all API credentials (including service_role key via CLI), write them to a local env file, and optionally restrict Claude Code's MCP access to only this project.

## Prerequisites

- **Supabase MCP**: Must be connected (global plugin or project-level). If not authenticated, prompt the user to run `/mcp` and authenticate Supabase first.
- **Supabase CLI**: Available via `npx supabase`. The user must have run `npx supabase login` at least once (needed for service_role key retrieval).

## Workflow

### Step 1: Collect User Input

Use `AskUserQuestion` to gather the following in a single prompt:

**Question 1 — Project name** (required):
- Ask the user for the Supabase project name
- Suggest using the current directory name as default

**Question 2 — Database password** (optional):
- Options: "Auto-generate strong password (Recommended)" / "I'll provide my own"
- If auto-generate: run `openssl rand -base64 32 | tr -d '/+=' | head -c 32`

**Question 3 — Region**:
- Default to `us-east-1`
- Common options: `us-east-1`, `us-west-1`, `eu-west-1`, `ap-southeast-1`, `ap-northeast-1`

**Question 4 — Restrict project access**:
- Ask: "Create a .mcp.json to restrict Claude Code in this directory to only access this Supabase project?"
- Options: "Yes, restrict access (Recommended for safety)" / "No, keep global access"
- Explain: restricting access prevents accidentally operating on other Supabase projects

### Step 2: Prepare

1. Generate database password if user chose auto-generate
2. Call `list_organizations` via Supabase MCP to get the organization list
3. If multiple organizations exist, ask the user which one to use
4. Call `get_cost` with the selected organization ID and type "project"
5. Inform the user of the cost (e.g., "$0/month for free tier")

### Step 3: Create the Project

1. Call `confirm_cost` to get a cost confirmation ID
2. Call `create_project` with:
   - `name`: user-provided project name
   - `region`: selected region
   - `organization_id`: from Step 2
   - `confirm_cost_id`: from confirm_cost
3. Record the returned `id` (this is the project ref)
4. Call `get_project` to verify status is `ACTIVE_HEALTHY`
   - If not active yet, wait a moment and retry (project creation can take a few minutes)

### Step 4: Retrieve All Credentials

**Publishable keys (via MCP):**
1. Call `get_publishable_keys` with the project ID
2. Extract the `anon` key from the results

**Service role key (via Supabase CLI):**
1. Run: `npx supabase projects api-keys --project-ref <project_ref>`
2. Parse the output to extract the `service_role` key value
3. If the command fails with "Access token not provided":
   - Tell the user: "Please run `npx supabase login` in your terminal first, then tell me when it's done."
   - Wait for user confirmation, then retry

**Project URL:**
- Construct from project ref: `https://<project_ref>.supabase.co`

### Step 5: Write Credentials to .env

1. Check if `.env` exists in the current project directory
   - If `.env` exists: read it and update/append Supabase variables
   - If `.env` does not exist: check if `.env.local` exists and use that instead
   - If neither exists: create `.env`
2. Write or update these variables:
   ```
   NEXT_PUBLIC_SUPABASE_URL=https://<project_ref>.supabase.co
   NEXT_PUBLIC_SUPABASE_ANON_KEY=<anon_key>
   SUPABASE_SERVICE_ROLE_KEY=<service_role_key>
   SUPABASE_DB_PASSWORD=<password>
   ```
3. When updating an existing file:
   - Replace existing Supabase variable values if they are present but empty
   - Do not overwrite variables that already have non-empty values (warn the user instead)
   - Preserve all other content in the file

### Step 6: Configure .mcp.json (Optional)

Only execute if the user chose to restrict project access in Step 1.

1. Check if `.mcp.json` exists in the current project directory
2. If it exists:
   - Read the file
   - Add or update the `supabase` entry in `mcpServers`
   - Preserve all other MCP server configurations
3. If it does not exist:
   - Create a new `.mcp.json`
4. The supabase entry should be:
   ```json
   {
     "mcpServers": {
       "supabase": {
         "type": "http",
         "url": "https://mcp.supabase.com/mcp?project_ref=<project_ref>"
       }
     }
   }
   ```
5. Tell the user:
   - "The .mcp.json has been created/updated. You need to **exit and reopen Claude Code** in this directory for the new MCP connection to take effect."
   - "The first time you use the project-scoped Supabase MCP, you'll need to authenticate via OAuth once."

### Step 7: Summary

Display a results table:

| Item | Value |
|------|-------|
| Project Name | ... |
| Project Ref | ... |
| Region | ... |
| Status | ACTIVE_HEALTHY |
| URL | https://xxx.supabase.co |
| Dashboard | https://supabase.com/dashboard/project/xxx |

Files modified:
- `.env` (or `.env.local`) — Supabase credentials written
- `.mcp.json` — (if applicable) project-scoped access configured

Reminders:
- Make sure `.env` is in your `.gitignore` — never commit secrets to git
- The `SUPABASE_SERVICE_ROLE_KEY` bypasses Row Level Security — use it only on the server side
- Dashboard: `https://supabase.com/dashboard/project/<project_ref>`
