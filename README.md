# AI Client Manager — Data→Insights→Email (Power Automate + SQL)

**What this shows:** An end-to-end, production-minded solution that normalizes hardware asset data, computes coverage & lifecycle risk, builds per-domain JSON payloads, and auto-generates internal executive emails via Power Automate.

## Highlights
- **Data normalization & enrichment:** `aicm.v_AssetCompany` derives lifecycle flags (e.g., LDOS 12m), renewals (e.g., 90d), attach potential, and joins to a master domain map.
- **Deterministic mapping:** `aicm.sp_RefreshDomainMap` chooses the best domain→client mapping using scored candidates from a mapping table.
- **Payload engine:** `aicm.sp_RebuildPayloadCache` dedupes assets, computes KPIs, and writes per-domain JSON to `aicm.PayloadCache`.
- **Automation:** Power Automate renders Outlook-safe HTML using a strict prompt and sends it to recipients.

## Folder Guide
- `/sql` — all schema objects (tables, views, procs, UDFs).  
- `/power-automate` — flow setup instructions (import, env vars).  
- `/prompts` — the HTML email prompt spec.  
- `/samples` — synthetic CSV & `setup.sql` to spin up a minimal demo.  
- `/docs` — architecture + lineage notes.

## Quickstart
1. Create a SQL Server DB (2016+).  
2. Run objects in `/sql` (tables → UDFs → views → procs).  
3. Load `/samples/RAI_SP0_sample.csv` via `BULK INSERT` or the provided `setup.sql`.  
4. Run: `EXEC aicm.sp_RebuildPayloadCache @LatestOnly = 1;`  
5. (Optional) `EXEC aicm.sp_GetLatestPayloadByUrl @CompanyUrl = 'https://example.com';`

## Security & Redaction
- No real client data in this repo; sample dataset is synthetic.
- Secrets live in environment variables / connection references; none are checked in.

## Results
- See `/samples/sample_output_email.html` for the generated Outlook-safe email preview.

## License
MIT (see `LICENSE`).
