USE [IBA]
GO

/****** Object:  View [aicm].[v_AssetCompany]    Script Date: 10/23/2025 11:07:14 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


/* ===========================================================================================
VIEW:       aicm.v_AssetCompany
PURPOSE:    Normalize asset data from RAI_SP0, compute lifecycle flags & derived fields,
            and enrich with MASTERDATA company ↔ domain mappings (new table).
AUTHOR:     David du Plessis (updated for RAI_SP0)
DATE:       2025-09-10
NOTES:
  - Treats '1900-01-01' as a sentinel unknown date using TRY_CONVERT.
  - Flags use GETDATE() for evaluation time.
  - Latest snapshot per client is based on Updatedon.
  - Domain enrichment uses MSTR_CompanyNameMapping_New (Domain; fallback to FQDN_Inferred).
  - Exposes serial/instance fields needed to match Excel asset counting logic.
FILTERS (added):
  - ParentChild = 'Parent'
  - ProductType = 'CHASSIS'
  - CoverageStatus IN ('Active','Signed')
DEPENDENCIES:
  - IBA.dbo.RAI_SP0
  - MASTERDATA.dbo.MSTR_CompanyNameMapping_New
COMPATIBILITY:
  - SQL Server 2016+: uses STUFF + FOR XML PATH for string aggregation.
=========================================================================================== */
CREATE VIEW [aicm].[v_AssetCompany]
AS
/* ==================  Source (RAI_SP0), normalization & flags  ================== */
WITH norm0 AS (
    SELECT
        AccountName,
        Updatedon,                                -- snapshot marker
        Manufacturer,
        PartNumber,
        AssetDescription,
        ProductFamily,
        ArchitectureGroup,
        ArchitectureSubgroup,
        ProductCategory,
        SiteId,
        LocationName,
        LocationCity,
        LocationStateProvince,
        LocationCountry,
        ProductListPrice,
        MaintenanceCatalogPrice,
        Quantity,
        CoverageStatus,
        AssetCovered,
        ServiceLevel,
        ContractNumber,
        AssetShipDate,
        EndOfSupportDate,                         -- LDOS (Last Date of Support)
        EndOfSaleDate,
        WarrantyEndDate,
        MaintenanceStartDate,
        MaintenanceEndDate,
        -- Serial / instance for Excel-equivalent counting
        SerialNumber,
        InstanceNumber
    FROM IBA.dbo.RAI_SP0
    WHERE [ParentChild] = 'Parent'
      AND [ProductType] = 'CHASSIS'
      AND [CoverageStatus] IN ('Active','Signed')
),
norm AS (
    SELECT
        n0.*,

        /* ---------- Normalize dates ---------- */
        TRY_CONVERT(date, AssetShipDate)         AS ship_dt_raw,
        TRY_CONVERT(date, EndOfSupportDate)      AS ldos_dt_raw,
        TRY_CONVERT(date, EndOfSaleDate)         AS eox_sales_dt_raw,
        TRY_CONVERT(date, WarrantyEndDate)       AS warranty_end_dt_raw,
        TRY_CONVERT(date, Updatedon)             AS updated_dt_raw,
        TRY_CONVERT(date, MaintenanceStartDate)  AS maint_start_dt_raw,
        TRY_CONVERT(date, MaintenanceEndDate)    AS maint_end_dt_raw,

        /* Cleaned dates (NULL if sentinel) */
        CASE WHEN TRY_CONVERT(date, AssetShipDate)        = '1900-01-01' THEN NULL ELSE TRY_CONVERT(date, AssetShipDate)        END AS ship_dt,
        CASE WHEN TRY_CONVERT(date, EndOfSupportDate)     = '1900-01-01' THEN NULL ELSE TRY_CONVERT(date, EndOfSupportDate)     END AS ldos_dt,
        CASE WHEN TRY_CONVERT(date, EndOfSaleDate)        = '1900-01-01' THEN NULL ELSE TRY_CONVERT(date, EndOfSaleDate)        END AS eox_sales_dt,
        CASE WHEN TRY_CONVERT(date, WarrantyEndDate)      = '1900-01-01' THEN NULL ELSE TRY_CONVERT(date, WarrantyEndDate)      END AS warranty_end_dt,
        CASE WHEN TRY_CONVERT(date, MaintenanceStartDate) = '1900-01-01' THEN NULL ELSE TRY_CONVERT(date, MaintenanceStartDate) END AS maint_start_dt,
        CASE WHEN TRY_CONVERT(date, MaintenanceEndDate)   = '1900-01-01' THEN NULL ELSE TRY_CONVERT(date, MaintenanceEndDate)   END AS maint_end_dt,

        /* ---------- Price/qty as numerics ---------- */
        TRY_CONVERT(decimal(19,4), ProductListPrice)        AS product_list_price_num,
        TRY_CONVERT(decimal(19,4), MaintenanceCatalogPrice) AS maintenance_list_price_num,
        TRY_CONVERT(decimal(19,4), Quantity)                AS qty_num,

        /* ---------- Serial / Instance normalized ---------- */
        serial_number       = NULLIF(LTRIM(RTRIM(SerialNumber)), ''),
        instance_number_raw = LTRIM(RTRIM(InstanceNumber)),
        instance_number_nodash =
            CASE WHEN LTRIM(RTRIM(InstanceNumber)) IN ('','-') THEN ''
                 ELSE LTRIM(RTRIM(InstanceNumber)) END,

        /* ---------- Coverage / lifecycle flags ---------- */
        CASE
          WHEN UPPER(ISNULL(AssetCovered,''))='COVERED'
           AND UPPER(ISNULL(CoverageStatus,''))='ACTIVE' THEN 1 ELSE 0
        END AS is_covered,

        /* LDOS within next 12 months */
        CASE
          WHEN TRY_CONVERT(date, EndOfSupportDate) IS NOT NULL
           AND TRY_CONVERT(date, EndOfSupportDate) <> '1900-01-01'
           AND TRY_CONVERT(date, EndOfSupportDate) BETWEEN CAST(GETDATE() AS DATE) AND DATEADD(MONTH,12,CAST(GETDATE() AS DATE))
          THEN 1 ELSE 0
        END AS flag_ldos_12m,

        /* EOSM not available in RAI_SP0 → emit NULL for compatibility */
        CAST(NULL AS bit) AS flag_eosm_12m,

        /* Covered contract ending within 90 days → renewal opportunity */
        CASE
          WHEN TRY_CONVERT(date, MaintenanceEndDate) IS NOT NULL
           AND TRY_CONVERT(date, MaintenanceEndDate) <> '1900-01-01'
           AND TRY_CONVERT(date, MaintenanceEndDate) BETWEEN CAST(GETDATE() AS DATE) AND DATEADD(DAY,90,CAST(GETDATE() AS DATE))
           AND UPPER(ISNULL(AssetCovered,''))='COVERED'
           AND UPPER(ISNULL(CoverageStatus,''))='ACTIVE'
          THEN 1 ELSE 0
        END AS flag_renewal_90d,

        /* ---------- Countdowns & asset age ---------- */
        CASE
          WHEN TRY_CONVERT(date, EndOfSupportDate) IS NULL
            OR TRY_CONVERT(date, EndOfSupportDate) = '1900-01-01'
          THEN NULL
          ELSE DATEDIFF(DAY, CAST(GETDATE() AS DATE), TRY_CONVERT(date, EndOfSupportDate))
        END AS days_to_ldos,

        /* No EOSM → days_to_eosm = NULL */
        CAST(NULL AS int) AS days_to_eosm,

        /* Age in years since ship date (NULL if unknown) */
        CASE
          WHEN TRY_CONVERT(date, AssetShipDate) IS NULL
            OR TRY_CONVERT(date, AssetShipDate) = '1900-01-01'
          THEN NULL
          ELSE DATEDIFF(YEAR, TRY_CONVERT(date, AssetShipDate), CAST(GETDATE() AS DATE))
        END AS age_years,

        /* Age buckets */
        CASE
          WHEN TRY_CONVERT(date, AssetShipDate) IS NULL
            OR TRY_CONVERT(date, AssetShipDate) = '1900-01-01' THEN 'Unknown'
          WHEN DATEDIFF(YEAR, TRY_CONVERT(date, AssetShipDate), CAST(GETDATE() AS DATE)) < 3 THEN '<3y'
          WHEN DATEDIFF(YEAR, TRY_CONVERT(date, AssetShipDate), CAST(GETDATE() AS DATE)) BETWEEN 3 AND 5 THEN '3–5y'
          WHEN DATEDIFF(YEAR, TRY_CONVERT(date, AssetShipDate), CAST(GETDATE() AS DATE)) BETWEEN 6 AND 7 THEN '6–7y'
          ELSE '8y+'
        END AS age_bucket,

        /* Attach potential (numeric; 0.0 for covered) */
        CASE
          WHEN UPPER(ISNULL(AssetCovered,''))='COVERED'
           AND UPPER(ISNULL(CoverageStatus,''))='ACTIVE' THEN CAST(0.0 AS decimal(19,4))
          ELSE ISNULL(TRY_CONVERT(decimal(19,4), MaintenanceCatalogPrice), CAST(0.0 AS decimal(19,4)))
        END AS attach_price_usd,

        /* Normalized client key from AccountName */
        client_key_raw = UPPER(REPLACE(REPLACE(LTRIM(RTRIM(AccountName)),'-',' '),'_',' '))
    FROM norm0 AS n0
),
norm_final AS (
    SELECT
        n.*,
        /* Squeeze multiple spaces (3x pass) */
        client_key = REPLACE(REPLACE(REPLACE(n.client_key_raw,'  ',' '),'  ',' '),'  ',' '),

        /* Latest snapshot (by Updatedon) per client */
        MAX(n.updated_dt_raw) OVER (PARTITION BY n.AccountName) AS latest_snapshot_date,

        /* Flag rows from latest snapshot */
        CASE WHEN n.updated_dt_raw = MAX(n.updated_dt_raw) OVER (PARTITION BY n.AccountName) THEN 1 ELSE 0 END AS is_latest
    FROM norm AS n
),

/* ==================  MASTERDATA (new table), aggregated safely  ================== */
md_base AS (
    SELECT
        CanonicalCompanyName,
        ParentCompanyName,
        LegalName,
        Domain,
        FQDN_Inferred,
        CreatedOn
    FROM MASTERDATA.dbo.MSTR_CompanyNameMapping_New
    WHERE (NULLIF(LTRIM(RTRIM(Domain)), '') IS NOT NULL
        OR NULLIF(LTRIM(RTRIM(FQDN_Inferred)), '') IS NOT NULL)
),
md_norm AS (
    /* Normalize CanonicalCompanyName to same client_key rules; strip http(s) and 'www.' */
    SELECT
        client_key = UPPER(REPLACE(REPLACE(LTRIM(RTRIM(CanonicalCompanyName)),'-',' '),'_',' ')),
        CanonicalCompanyName,
        ParentCompanyName,
        LegalName,
        CreatedOn,
        fqdn_clean = LOWER(
            CASE
              WHEN LEFT(ISNULL(Domain, FQDN_Inferred),8)='https://' THEN SUBSTRING(ISNULL(Domain, FQDN_Inferred),9,4000)
              WHEN LEFT(ISNULL(Domain, FQDN_Inferred),7)='http://'  THEN SUBSTRING(ISNULL(Domain, FQDN_Inferred),8,4000)
              ELSE ISNULL(Domain, FQDN_Inferred)
            END
        )
    FROM md_base
),
md_strip AS (
    SELECT
        client_key,
        CanonicalCompanyName,
        ParentCompanyName,
        LegalName,
        CreatedOn,
        fqdn2 = CASE
                  WHEN CHARINDEX('/', fqdn_clean) > 0 THEN LEFT(fqdn_clean, CHARINDEX('/', fqdn_clean)-1)
                  ELSE fqdn_clean
                END
    FROM md_norm
),
md_clean AS (
    SELECT
        client_key,
        CanonicalCompanyName,
        ParentCompanyName,
        LegalName,
        CreatedOn,
        fqdn = CASE WHEN LEFT(fqdn2,4)='www.' THEN SUBSTRING(fqdn2,5,4000) ELSE fqdn2 END
    FROM md_strip
),
md_rank AS (
    SELECT *,
           ROW_NUMBER() OVER (PARTITION BY client_key ORDER BY CreatedOn DESC, LEN(fqdn) ASC) AS rn
    FROM md_clean
),
md_primary AS (
    SELECT
        client_key,
        primary_company_name = MAX(CASE WHEN rn=1 THEN CanonicalCompanyName ELSE '' END),
        parent_company       = MAX(CASE WHEN rn=1 THEN ParentCompanyName ELSE '' END),
        legal_name           = MAX(CASE WHEN rn=1 THEN LegalName ELSE '' END),
        primary_fqdn         = MAX(CASE WHEN rn=1 THEN fqdn ELSE '' END)
    FROM md_rank
    GROUP BY client_key
),
md_all AS (
    SELECT c.client_key,
           all_fqdns = STUFF((
               SELECT ', ' + q.fqdn
               FROM (SELECT DISTINCT fqdn FROM md_clean WHERE client_key = c.client_key) AS q
               ORDER BY q.fqdn
               FOR XML PATH(''), TYPE
           ).value('.', 'NVARCHAR(MAX)'), 1, 2, '')
    FROM (SELECT DISTINCT client_key FROM md_clean) AS c
)

/* ==================  Final projection (assets + masterdata enrichment) ================== */
SELECT
    n.AccountName                AS client,
    n.Updatedon                  AS sso_update,       -- preserved name for continuity
    n.Manufacturer               AS vendor_name,
    n.PartNumber                 AS sku,
    n.AssetDescription           AS sku_description,
    n.ProductFamily              AS product_family,
    n.ArchitectureGroup          AS architecture,
    n.ArchitectureSubgroup       AS architecture_sub,
    /* item_type / device_type not available in RAI_SP0 */
    n.ProductCategory            AS device_category,
    n.SiteId                     AS site_id,
    n.LocationName               AS site_name,
    n.LocationCity               AS city,
    n.LocationStateProvince      AS state,
    n.LocationCountry            AS country,
    n.product_list_price_num     AS product_list_price,
    n.maintenance_list_price_num AS maintenance_list_price,
    n.qty_num                    AS qty,
    NULL                         AS order_qty,         -- not present in RAI_SP0
    n.CoverageStatus             AS contract_status,
    n.maint_start_dt             AS contract_start_date,
    n.maint_end_dt               AS contract_end_date,
    n.ServiceLevel               AS service_level,
    n.ContractNumber             AS contract_number,
    n.ship_dt                    AS ship_date,
    n.ldos_dt                    AS ldos,
    n.eox_sales_dt               AS eox_sales,
    NULL                         AS eox_sw_maintenance,  -- not present
    n.warranty_end_dt            AS warranty_end_date,

    /* Deriveds & flags */
    n.is_covered,
    n.flag_ldos_12m,
    n.flag_eosm_12m,
    n.flag_renewal_90d,
    n.days_to_ldos,
    n.days_to_eosm,
    n.age_years,
    n.age_bucket,
    n.attach_price_usd,

    /* Snapshot flags */
    n.updated_dt_raw            AS sso_update_dt,
    n.latest_snapshot_date,
    n.is_latest,

    /* Enrichment */
    mp.primary_company_name,
    mp.parent_company,
    mp.legal_name,
    mp.primary_fqdn,
    ma.all_fqdns,

    /* Serial/Instance (for Excel-equivalent counting) */
    n.serial_number,
    n.instance_number_raw,
    n.instance_number_nodash,

    /* Join key (optional to keep visible) */
    n.client_key
FROM norm_final AS n
LEFT JOIN md_primary AS mp ON mp.client_key = n.client_key
LEFT JOIN md_all     AS ma ON ma.client_key = n.client_key;
GO


