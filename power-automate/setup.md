# Power Automate — Setup

1) **Import**
- In Power Automate, import a solution/package (create a new Solution if preferred for AiSummary_20251023135659.zip).
- Re-create the following connections in your environment:
  - **SQL Server** (to your DB)
  - **Office 365 Outlook** (for Send email (V2))

2) **Environment Variables (recommended)**
- `AICM_SQL_CONNECTION` — SQL connection reference
- `AICM_DEFAULT_RECIPIENTS` — semicolon-separated emails
- `AICM_FROM_ADDRESS` — optional send-as

3) **Flow Outline**
- **Step 1:** `Execute stored procedure (V2)` → `aicm.sp_RebuildPayloadCache` with `@LatestOnly = 1`
- **Step 2:** `Execute stored procedure (V2)` → `aicm.sp_GetLatestPayloadByUrl(@CompanyUrl)`
- **Step 3:** `Compose` → build HTML from `/prompts/AiSummaryPrompt.md` rules and JSON outputs
- **Step 4:** `Send an email (V2)` → body = HTML

> Tip: For demo, hardcode `CompanyUrl = https://example.com` first.

4) **Security**
- Do not hardcode secrets in actions. Use connections / environment variables.
