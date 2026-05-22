# Navi AI Client Manager

Navi is a data-grounded AI Client Manager that turns verified account, asset, renewal, sales, churn, and service context into executive-ready engagement briefs.

The project combines SQL Server data products, Power Automate orchestration, SharePoint knowledge context, and AI Builder prompt chaining. The important design choice is that the AI output is guided by mapped enterprise data, not by generic web summarization.

## Problem And Solution

Account planning depends on data scattered across systems that do not share clean identifiers. The same client may appear under different names in CRM, SAP, Cisco datasets, collector extracts, RACS, churn outputs, and internal research files. Preparing a complete brief means reconciling those systems, validating installed assets, checking upcoming renewals, reviewing open opportunities, and turning that evidence into a usable executive narrative.

Navi treats account brief generation as a repeatable data pipeline. It resolves the client through a master client-name mapping layer, pulls verified operational evidence through the `aicm` SQL layer, injects RACS/Cisco/collector asset context, runs a controlled AI prompt chain, and produces an HTML brief that can be saved to SharePoint, emailed, or persisted back to SQL.

## What Navi Does

1. Resolves active account domains from SQL.
2. Uses master client-name mapping to connect differently named records across CRM, SAP, Cisco, collector, RACS, and churn sources.
3. Pulls account intelligence from `aicm` views and payload tables.
4. Grounds the brief with verified asset context, including RACS hardware evidence and Cisco/collector lifecycle signals.
5. Runs AI Builder prompts to generate executive summary, SWOT/TOWS, IT4IT, and value-stream content.
6. Merges structured operational rows and AI narrative into HTML.
7. Outputs the brief through Power Automate and preserves the payload/output for reuse.

## Data Sources

| Source | Role in Navi |
| --- | --- |
| Master client-name mapping | Resolves account names across systems so records align to the same client. |
| `aicm` SQL objects | Expose account driver lists, asset intelligence, payload cache, and generated-output procedures. |
| `[RACS].[dbo].[RAW_Hardware]` | Provides collector-verified hardware asset evidence used to ground the brief. |
| Cisco lifecycle and coverage data | Supplies installed base, lifecycle, coverage, renewal, and opportunity signals. |
| Collector data | Confirms discovered client asset details and supports evidence-backed recommendations. |
| Salesforce opportunities | Adds pipeline, stage, close date, value, product, and owner context. |
| SAP renewals | Adds renewal timing, vendor, type, ACV/TCV, and exposure context. |
| Churn model output | Adds external churn-risk signals for prioritization. |
| SharePoint RAG context | Provides reusable service catalog and internal context for prompts. |
| AI Builder prompts | Transform grounded evidence into executive narrative and strategy sections. |

## Generated Brief Sections

Each generated account brief can include:

- executive summary
- customer churn predictions
- sales plays summary
- Salesforce opportunity context
- SAP contract renewal exposure
- business model analysis
- SWOT and TOWS strategy framing
- IT4IT operating-model framing
- value-stream mapping
- account-specific evidence and next-action context

## Power Automate Run Flow

The production flow processes account domains one at a time and combines SQL, SharePoint, and AI Builder actions.

```text
Recurrence trigger
        |
        v
Initialize HTML and row variables
        |
        v
Get active account domains
        |
        v
For each account domain
        |
        +--> Resolve domain/account identity
        |
        +--> Fetch account evidence
        |       |
        |       +--> Sales plays
        |       +--> Salesforce opportunities
        |       +--> SAP renewals
        |       +--> Cached JSON payload
        |       +--> Churn prediction output
        |       +--> RACS/Cisco/collector asset context
        |
        +--> Run AI prompt chain
        |       |
        |       +--> Executive summary
        |       +--> Business model extraction
        |       +--> SWOT extraction and enrichment
        |       +--> Adversarial review
        |       +--> TOWS strategy
        |       +--> IT4IT framing
        |       +--> Value-stream mapping
        |
        +--> Assemble HTML brief
        +--> Write or send output
        +--> Persist payload/output for recovery
```

## Why This Is Data-Grounded AI

Navi is more than a prompt that summarizes a company website. The AI prompt chain is downstream from the data engineering work:

- account identity is resolved before generation
- internal SQL views define what evidence is available to the prompt chain
- verified asset records from RACS and collector data guide recommendations
- Cisco, SAP, Salesforce, and churn signals are injected as structured account context
- generated payloads and HTML can be reviewed, reused, and recovered
- the same orchestration can run repeatedly across many account domains

AI writes and organizes the narrative, but the account facts come from mapped enterprise systems.

## Repository Guide

| Folder | Purpose |
| --- | --- |
| `/sql` | Sanitized schema objects, views, procedures, and helper functions. |
| `/power-automate` | Flow setup notes and import package references. |
| `/prompts` | Prompt specification used to generate strict HTML output. |
| `/samples` | Synthetic sample data and output preview. |
| `/docs` | Architecture and data-lineage documentation. |

## Quickstart

1. Create a SQL Server database.
2. Run the scripts in `/sql` in dependency order.
3. Load the synthetic sample data from `/samples`.
4. Refresh the mapping and payload cache procedures.
5. Import or recreate the Power Automate flow using `/power-automate/setup.md`.
6. Review the generated sample output under `/samples`.

## Security And Redaction

- No real client data should be committed.
- Public samples should remain synthetic.
- Secrets belong in Power Platform connections or environment variables.
- Tenant-specific SharePoint URLs, connection IDs, prompt IDs, generated customer HTML, and cached real payloads should be excluded or sanitized.

## Results

The project demonstrates an end-to-end account intelligence pattern:

- deterministic data normalization and client matching
- verified asset and lifecycle evidence
- structured payload generation
- AI-assisted executive narrative
- repeatable Power Automate orchestration
- recoverable output persistence

## License

MIT (see `LICENSE`).