# AI Summary Prompt (HTML Email)

**Mode:** HTML only (no markdown, no code fences).  
**Inputs:** `DATA_FEED_JSON` (single JSON object), `COMPANY_URL` (string).

## Requirements
- Output must be Outlook-safe HTML.
- Render a concise KPI block: total assets, covered, uncovered, lifecycle risk.
- Add a short paragraph explaining what changed since last run if deltas are provided.
- No external CSS; inline styles only.

## Minimal Template (pseudocode)
```
<html>
  <body>
    <h2>Operations Intel — {{company_name}}</h2>
    <table>...KPIs here...</table>
    <p>Notes...</p>
  </body>
</html>
```
