# Data Lineage (High Level)

Input (RAI_SP0) → Normalize/Join (views) → KPIs (proc) → JSON (PayloadCache) → Email (Power Automate).

- **aicm.RAI_SP0**: asset rows (synthetic here)
- **aicm.DomainClientMap**: domain↔company mapping
- **Views**: summarize and flag risk
- **Procs**: compute KPI & write JSON
- **Power Automate**: render HTML email and send
