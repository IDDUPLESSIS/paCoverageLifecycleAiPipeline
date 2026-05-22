# Architecture

Navi is organized as a data-grounded AI pipeline. SQL prepares account evidence, Power Automate orchestrates retrieval and prompt execution, and the output is rendered as an executive-ready HTML brief.

```text
Master client-name mapping
        |
        v
Account identity resolution
        |
        v
SQL Server aicm layer
        |
        +--> RACS RAW_Hardware
        +--> Cisco lifecycle / coverage data
        +--> Collector asset evidence
        +--> Salesforce opportunities
        +--> SAP renewals
        +--> Churn model output
        |
        v
aicm.PayloadCache / account views
        |
        v
Power Automate orchestration
        |
        +--> SQL Server connector
        +--> SharePoint RAG context
        +--> AI Builder prompt chain
        |
        v
Generated HTML account brief
        |
        +--> SharePoint / email output
        +--> SQL persistence
```

## Core Layers

| Layer | Responsibility |
| --- | --- |
| Client identity mapping | Resolves inconsistent client names across source systems. |
| `aicm` SQL layer | Normalizes source data and exposes account-level evidence. |
| Payload cache | Stores per-account JSON used by automation and prompt actions. |
| Power Automate | Schedules and orchestrates data retrieval, AI prompt execution, and output creation. |
| AI Builder prompts | Convert grounded account context into executive narrative and strategy sections. |
| Output persistence | Saves generated briefs so results can be reviewed, reused, and recovered. |

## Power Automate Flow

```text
Recurrence
  -> initialize variables
  -> get active account domains
  -> for each domain
       -> resolve account domain
       -> fetch SQL evidence
       -> fetch SharePoint context
       -> run AI prompt chain
       -> assemble HTML sections
       -> write/send output
       -> persist output
```