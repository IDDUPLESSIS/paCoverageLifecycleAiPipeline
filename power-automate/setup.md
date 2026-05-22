# Power Automate Setup

This project uses Power Automate to orchestrate SQL retrieval, SharePoint context, AI prompt execution, and HTML output generation.

## Required Connections

- SQL Server
- SharePoint Online
- Dataverse / AI Builder
- Outlook or SharePoint output connector, depending on the deployment pattern

## Recommended Environment Variables

| Variable | Purpose |
| --- | --- |
| `AICM_SQL_CONNECTION` | SQL Server connection reference. |
| `AICM_SHAREPOINT_SITE` | SharePoint site used for RAG context and output files. |
| `AICM_OUTPUT_FOLDER` | Folder for generated account briefs. |
| `AICM_DEFAULT_RECIPIENTS` | Optional email recipients for demo or notification flows. |

## Flow Outline

```text
1. Trigger on recurrence or manual test run.
2. Read active account domains from SQL.
3. For each domain, fetch account evidence from aicm views and payload cache.
4. Read SharePoint RAG context.
5. Run AI Builder prompt actions.
6. Assemble Outlook-safe or SharePoint-safe HTML.
7. Write/send generated output.
8. Persist output metadata or HTML back to SQL.
```

## Implementation Notes

- Keep connector references environment-specific.
- Do not hardcode secrets, tenant URLs, or production recipient lists in exported files.
- Use one low-risk test domain when validating a new environment.
- Keep raw Power Automate exports private unless connection IDs, tenant URLs, prompt IDs, and customer references have been removed.

## Restore Checklist

- Recreate SQL objects and supporting source views.
- Confirm client-name mapping is current.
- Confirm upstream RACS, Cisco, collector, Salesforce, SAP, and churn dependencies are available.
- Recreate SharePoint RAG and output folder paths.
- Import or rebuild the flow.
- Rebind SQL, SharePoint, Dataverse, and output connectors.
- Recreate or remap AI Builder custom prompt IDs.
- Validate generated HTML and SQL persistence before enabling recurrence.