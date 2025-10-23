USE [IBA]
GO

/****** Object:  View [aicm].[v_DomainTokens]    Script Date: 10/23/2025 11:09:28 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


/* ===========================================================================================
VIEW:       dbo.v_PA_DomainTokens
PURPOSE:    Tokenize/enumerate domains per client from latest assets, prioritizing primary FQDN.
OUTPUT:     client_key, client, domain_clean, is_primary
DEPENDENCIES:
  - IBA.dbo.v_PA_AssetsLatest  (must expose client_key, client, primary_fqdn, all_fqdns)
=========================================================================================== */
CREATE   VIEW [aicm].[v_DomainTokens]
AS
WITH base AS (
    SELECT
        client_key,
        client,
        ISNULL(primary_fqdn, '') AS primary_fqdn,
        ISNULL(all_fqdns,   '')  AS all_fqdns
    FROM dbo.v_PA_AssetsLatest
),
rows AS (
    -- 1) primary first
    SELECT client_key, client, primary_fqdn AS raw_domain, 1 AS is_primary
    FROM base
    WHERE NULLIF(LTRIM(RTRIM(primary_fqdn)), '') IS NOT NULL

    UNION ALL

    -- 2) all_fqdns (CSV) -> rows
    SELECT b.client_key, b.client, LTRIM(RTRIM(value)) AS raw_domain, 0 AS is_primary
    FROM base AS b
    CROSS APPLY STRING_SPLIT(b.all_fqdns, ',')
    WHERE NULLIF(LTRIM(RTRIM(value)), '') IS NOT NULL
),
norm AS (
    SELECT
        client_key,
        client,
        CASE
          WHEN LEFT(LOWER(raw_domain),8)='https://' THEN SUBSTRING(LOWER(raw_domain),9,4000)
          WHEN LEFT(LOWER(raw_domain),7)='http://'  THEN SUBSTRING(LOWER(raw_domain),8,4000)
          ELSE LOWER(raw_domain)
        END AS d1,
        is_primary
    FROM rows
),
norm2 AS (
    SELECT
        client_key,
        client,
        CASE WHEN CHARINDEX('/', d1) > 0 THEN LEFT(d1, CHARINDEX('/', d1)-1) ELSE d1 END AS d2,
        is_primary
    FROM norm
),
norm3 AS (
    SELECT
        client_key,
        client,
        CASE WHEN LEFT(d2,4)='www.' THEN SUBSTRING(d2,5,4000) ELSE d2 END AS domain_clean,
        is_primary
    FROM norm2
    WHERE NULLIF(LTRIM(RTRIM(d2)), '') IS NOT NULL
)
SELECT DISTINCT client_key, client, domain_clean, MAX(is_primary) AS is_primary
FROM norm3
WHERE domain_clean IS NOT NULL AND domain_clean <> ''
GROUP BY client_key, client, domain_clean;
GO


