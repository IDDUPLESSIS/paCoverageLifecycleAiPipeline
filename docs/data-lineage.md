# Data Lineage

Navi's output is generated from mapped and verified enterprise data. The flow below summarizes how account evidence becomes an AI-assisted executive brief.

```text
Source systems
  -> client-name mapping
  -> aicm normalization views
  -> account-level payloads
  -> Power Automate flow
  -> AI Builder prompt chain
  -> HTML account brief
  -> SharePoint / email / SQL output
```

## Source-To-Output Mapping

| Source | Transformation | Output Contribution |
| --- | --- | --- |
| Master client-name mapping | Resolves inconsistent client names and domains. | Ensures records across systems refer to the same account. |
| RACS hardware inventory | Filters and normalizes collector-verified asset rows. | Grounds the brief in verified installed asset evidence. |
| Cisco lifecycle / coverage data | Derives lifecycle, coverage, renewal, and attach signals. | Supports sales plays and account-risk context. |
| Collector data | Confirms discovered asset details. | Adds evidence-backed asset context. |
| Salesforce opportunities | Aggregates opportunity details by account. | Adds pipeline, stage, close date, value, and owner context. |
| SAP renewals | Aggregates renewal exposure by account. | Adds contract timing, vendor, ACV/TCV, and renewal buckets. |
| Churn model output | Scores customer churn risk. | Adds prioritization and retention context. |
| SharePoint RAG context | Loads internal service and capability context. | Helps prompt outputs align to internal offerings. |
| AI Builder prompts | Generate structured narrative from account context. | Produces summary, SWOT/TOWS, IT4IT, and value-stream sections. |

## Public Repo Data Policy

The public repository should include only sanitized schema, synthetic samples, and documentation. Real client records, generated customer HTML, prompt record IDs, tenant URLs, and connection identifiers should not be committed.