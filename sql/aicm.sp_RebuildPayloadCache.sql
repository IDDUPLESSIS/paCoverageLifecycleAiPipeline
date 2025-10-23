USE [IBA]
GO

/****** Object:  StoredProcedure [aicm].[sp_RebuildPayloadCache]    Script Date: 10/23/2025 11:04:20 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO



/*================================================================================================
Proc: aicm.sp_RebuildPayloadCache
Goal: Build per-domain JSON (KPIs + “top” lists) and upsert into aicm.PayloadCache.

KPI logic (Excel/Qlik-aligned):
  - Build counts from deduped #A (1 row per asset_key).
  - Excluded = ProfileProductCoverageExclusions = Yes  (from dbo.RAI_SP0)
  - Covered & Uncovered exclude "invalid" rows (InvalidAsset / InvalidCiscoProductId).
  - eligible_assets = covered_assets + uncovered
  - excluded_assets = total_assets - eligible_assets
  - coverage_pct = 100 * covered_assets / (covered_assets + uncovered)

Other lists (evi/mig/att/sites/ren/mix/age) still derived from #A.
================================================================================================*/
CREATE PROCEDURE [aicm].[sp_RebuildPayloadCache]
    @LatestOnly   BIT = 1,
    @TopEvi       INT = 8,
    @TopMig       INT = 6,
    @TopAtt       INT = 6,
    @TopSites     INT = 6,
    @TopRen       INT = 8,
    @DomainList   dbo.ListOfVarchars READONLY,   -- empty TVP = ALL domains
    @RefreshMap   BIT = 1,                       -- optionally refresh domain map first
    @PurgeMapDays INT = NULL                     -- if @RefreshMap=1, optionally purge stale pairs
AS
BEGIN
    SET NOCOUNT ON;

    /* --- Dependency sanity checks --- */
    IF OBJECT_ID('aicm.DomainClientMap','U') IS NULL
        THROW 51010, 'Missing table: aicm.DomainClientMap', 1;
    IF OBJECT_ID('aicm.v_AssetCompany','V') IS NULL
        THROW 51011, 'Missing view: aicm.v_AssetCompany', 1;
    IF OBJECT_ID('aicm.PayloadCache','U') IS NULL
        THROW 51012, 'Missing table: aicm.PayloadCache', 1;

    /* 0) Optional refresh of the domain map */
    IF @RefreshMap = 1
    BEGIN
        DECLARE @dl dbo.ListOfVarchars;
        IF EXISTS (SELECT 1 FROM @DomainList)
            INSERT @dl(value) SELECT value FROM @DomainList;

        IF OBJECT_ID('aicm.sp_RefreshDomainMap','P') IS NOT NULL
            EXEC aicm.sp_RefreshDomainMap @DomainList=@dl, @PurgeDays=@PurgeMapDays;
        ELSE IF OBJECT_ID('dbo.sp_DomainClientKeyMap_Refresh','P') IS NOT NULL
            EXEC dbo.sp_DomainClientKeyMap_Refresh @DomainList=@dl, @PurgeDays=@PurgeMapDays;
    END

    /* 1) Scope: which domains */
    IF OBJECT_ID('tempdb..#Domains') IS NOT NULL DROP TABLE #Domains;
    CREATE TABLE #Domains(domain NVARCHAR(255) NOT NULL PRIMARY KEY);

    IF EXISTS (SELECT 1 FROM @DomainList)
        INSERT #Domains(domain)
        SELECT DISTINCT LOWER(LTRIM(RTRIM(value))) FROM @DomainList;
    ELSE
        INSERT #Domains(domain)
        SELECT DISTINCT domain_clean FROM aicm.DomainClientMap;

    /* 2) Keyset: (domain, client_key) */
    IF OBJECT_ID('tempdb..#Keyset') IS NOT NULL DROP TABLE #Keyset;
    CREATE TABLE #Keyset
    (
        domain     NVARCHAR(255) NOT NULL,
        client_key NVARCHAR(190) NOT NULL,
        PRIMARY KEY(domain, client_key)
    );

    INSERT #Keyset(domain, client_key)
    SELECT d.domain, m.client_key
    FROM #Domains d
    JOIN aicm.DomainClientMap m WITH (FORCESEEK)
      ON m.domain_clean = d.domain
    WHERE NULLIF(LTRIM(RTRIM(m.client_key)),'') IS NOT NULL;

    /* 3) Base slice from normalized view */
    IF OBJECT_ID('tempdb..#Base') IS NOT NULL DROP TABLE #Base;
    SELECT
        k.domain,
        v.client_key,
        v.primary_company_name,
        v.is_latest,
        v.instance_number_nodash,
        v.serial_number,
        v.is_covered,
        v.attach_price_usd,
        v.age_years,
        v.age_bucket,
        v.product_family,
        v.architecture,
        v.architecture_sub,
        v.sku,
        v.sku_description,
        v.site_id,
        v.site_name,
        v.city, v.state, v.country,
        v.ldos,
        v.days_to_ldos,
        v.flag_ldos_12m,
        v.flag_eosm_12m,
        v.days_to_eosm,
        v.flag_renewal_90d,
        v.contract_number,
        v.contract_end_date,
        v.service_level,
        v.maintenance_list_price,
        v.latest_snapshot_date
    INTO #Base
    FROM aicm.v_AssetCompany v
    JOIN #Keyset k
      ON v.client_key = k.client_key
    OPTION (RECOMPILE);

    IF @LatestOnly = 1
    BEGIN
        DELETE b
        FROM #Base AS b
        WHERE b.is_latest = 0
          AND EXISTS (SELECT 1 FROM #Base AS x WHERE x.domain=b.domain AND x.is_latest=1);
    END

    /* 4) One row per asset (dedupe -> #A) for TOP lists */
    IF OBJECT_ID('tempdb..#A') IS NOT NULL DROP TABLE #A;

    ;WITH ranked AS (
        SELECT
            b.*,
            asset_key =
                CASE
                    WHEN NULLIF(LTRIM(RTRIM(instance_number_nodash)),'') IS NOT NULL
                        THEN N'I|' + LTRIM(RTRIM(instance_number_nodash))
                    WHEN NULLIF(LTRIM(RTRIM(serial_number)),'') IS NOT NULL
                        THEN N'S|' + LTRIM(RTRIM(serial_number))
                    ELSE NULL
                END,
            rn = ROW_NUMBER() OVER (
                PARTITION BY
                    CASE
                        WHEN NULLIF(LTRIM(RTRIM(instance_number_nodash)),'') IS NOT NULL
                            THEN N'I|' + LTRIM(RTRIM(instance_number_nodash))
                        WHEN NULLIF(LTRIM(RTRIM(serial_number)),'') IS NOT NULL
                            THEN N'S|' + LTRIM(RTRIM(serial_number))
                        ELSE NULL
                    END
                ORDER BY
                    CASE WHEN is_covered = 1 THEN 0 ELSE 1 END,
                    ISNULL(attach_price_usd,0) DESC,
                    latest_snapshot_date DESC
            )
        FROM #Base b
        WHERE (NULLIF(LTRIM(RTRIM(instance_number_nodash)),'') IS NOT NULL
            OR NULLIF(LTRIM(RTRIM(serial_number)),'') IS NOT NULL)
    )
    SELECT * INTO #A FROM ranked WHERE rn = 1;

    /* Helpful temp indexes for TOP lists */
    CREATE CLUSTERED INDEX CX_A ON #A(domain, asset_key);
    CREATE INDEX IX_A_Attach ON #A(domain, is_covered, attach_price_usd DESC, age_years DESC)
      INCLUDE (sku, sku_description, site_name, city, state, country, age_bucket);
    CREATE INDEX IX_A_Mig ON #A(domain, flag_ldos_12m, flag_eosm_12m, days_to_ldos, days_to_eosm)
      INCLUDE (sku, sku_description, product_family, architecture, architecture_sub, site_name, city, state, country, ldos);
    CREATE INDEX IX_A_Sites ON #A(domain, site_id)
      INCLUDE (site_name, city, state, country, is_covered, flag_ldos_12m, flag_eosm_12m, flag_renewal_90d);
    CREATE INDEX IX_A_Ren ON #A(domain, flag_renewal_90d, contract_end_date)
      INCLUDE (contract_number, service_level, site_name, city, state, country);
    CREATE INDEX IX_A_Mix ON #A(domain, architecture, product_family);
    CREATE INDEX IX_A_Age ON #A(domain, age_bucket);
    CREATE INDEX IX_A_Kpi ON #A(domain, is_covered)
      INCLUDE (maintenance_list_price, attach_price_usd, flag_ldos_12m, flag_eosm_12m, flag_renewal_90d, site_id, latest_snapshot_date, primary_company_name);

    /* 4b) FLAGS from raw table (Excluded/Invalid) keyed by asset_key */
    IF OBJECT_ID('tempdb..#Flags') IS NOT NULL DROP TABLE #Flags;

    ;WITH raw AS (
        SELECT
            asset_key =
                CASE
                    WHEN NULLIF(LTRIM(RTRIM(InstanceNumber)),'') IS NOT NULL
                         AND LTRIM(RTRIM(InstanceNumber)) <> '-'
                        THEN N'I|' + LTRIM(RTRIM(InstanceNumber))
                    WHEN NULLIF(LTRIM(RTRIM(SerialNumber)),'') IS NOT NULL
                        THEN N'S|' + LTRIM(RTRIM(SerialNumber))
                    ELSE NULL
                END,
            InvalidAsset,
            InvalidCiscoProductId,
            ProfileProductCoverageExclusions
        FROM dbo.RAI_SP0
    ),
    norm AS (
        SELECT
            asset_key,
            invalid_asset =
                CASE WHEN UPPER(LTRIM(RTRIM(InvalidAsset))) IN ('1','Y','YES','TRUE') THEN 1 ELSE 0 END,
            invalid_pid   =
                CASE WHEN UPPER(LTRIM(RTRIM(InvalidCiscoProductId))) IN ('1','Y','YES','TRUE') THEN 1 ELSE 0 END,
            excl_product  =
                CASE WHEN UPPER(LTRIM(RTRIM(ProfileProductCoverageExclusions))) IN ('1','Y','YES','TRUE') THEN 1 ELSE 0 END
        FROM raw
        WHERE asset_key IS NOT NULL
    )
    SELECT asset_key,
           invalid_asset = MAX(invalid_asset),
           invalid_pid   = MAX(invalid_pid),
           excl_product  = MAX(excl_product)
    INTO #Flags
    FROM norm
    GROUP BY asset_key;

    CREATE UNIQUE CLUSTERED INDEX CX_Flags ON #Flags(asset_key);

    /* 5) Company (from #Base) */
    IF OBJECT_ID('tempdb..#Company') IS NOT NULL DROP TABLE #Company;
    ;WITH c AS (
      SELECT domain,
             primary_company_name = LTRIM(RTRIM(primary_company_name)),
             cnt = COUNT_BIG(*)
      FROM #Base
      WHERE NULLIF(LTRIM(RTRIM(primary_company_name)),'') IS NOT NULL
      GROUP BY domain, LTRIM(RTRIM(primary_company_name))
    ),
    r AS (
      SELECT *, rn = ROW_NUMBER() OVER (PARTITION BY domain ORDER BY cnt DESC, primary_company_name)
      FROM c
    )
    SELECT domain, company = primary_company_name
    INTO #Company
    FROM r
    WHERE rn = 1;

    /* 5a) KPI block (Excel/Qlik-aligned) from deduped #A + #Flags */

    -- CHANGE: silence "Null value is eliminated..." while aggregating
    SET ANSI_WARNINGS OFF;

    IF OBJECT_ID('tempdb..#KpiRaw') IS NOT NULL DROP TABLE #KpiRaw;

    SELECT
        a.domain,
        total_assets     = COUNT_BIG(*),
        /* eligible assets are those NOT excluded; split into covered/uncovered below (invalid rows excluded) */
        covered_assets   = SUM(CAST(CASE WHEN a.is_covered = 1
                                     AND ISNULL(f.excl_product,0) = 0
                                     AND ISNULL(f.invalid_asset,0) = 0
                                     AND ISNULL(f.invalid_pid,0)   = 0
                               THEN 1 ELSE 0 END AS BIGINT)),          -- CHANGE: BIGINT accumulator
        uncovered        = 
            SUM(CAST(CASE WHEN a.is_covered = 0
                                     AND ISNULL(f.excl_product,0) = 0
                                     AND ISNULL(f.invalid_asset,0) = 0
                                     AND ISNULL(f.invalid_pid,0)   = 0
                               THEN 1 ELSE 0 END AS BIGINT))            -- CHANGE: BIGINT accumulator
          - SUM(CAST(CASE WHEN a.is_covered = 1
                                     AND ISNULL(f.excl_product,0) = 0
                                     AND ISNULL(f.invalid_asset,0) = 0
                                     AND ISNULL(f.invalid_pid,0)   = 0
                               THEN 1 ELSE 0 END AS BIGINT)),           -- CHANGE: BIGINT accumulator
        excluded_assets  = SUM(CAST(CASE WHEN ISNULL(f.excl_product,0) = 1 THEN 1 ELSE 0 END AS BIGINT)), -- CHANGE

        attach_usd       = CAST(ROUND(SUM(CASE WHEN a.is_covered = 0
                                                 AND ISNULL(f.excl_product,0) = 0
                                                 AND ISNULL(f.invalid_asset,0) = 0
                                                 AND ISNULL(f.invalid_pid,0)   = 0
                                           THEN ISNULL(a.attach_price_usd,0) ELSE 0 END),2) AS DECIMAL(18,2)),
        runrate_usd      = CAST(ROUND(SUM(CASE WHEN a.is_covered = 1
                                                 AND ISNULL(f.excl_product,0) = 0
                                                 AND ISNULL(f.invalid_asset,0) = 0
                                                 AND ISNULL(f.invalid_pid,0)   = 0
                                           THEN ISNULL(a.maintenance_list_price,0) ELSE 0 END),2) AS DECIMAL(18,2)),

        ldos12m          = SUM(CAST(CASE WHEN a.flag_ldos_12m  = 1 AND ISNULL(f.excl_product,0)=0 THEN 1 ELSE 0 END AS BIGINT)), -- CHANGE
        eosm12m          = SUM(CAST(CASE WHEN a.flag_eosm_12m  = 1 AND ISNULL(f.excl_product,0)=0 THEN 1 ELSE 0 END AS BIGINT)), -- CHANGE
        ren90d           = SUM(CAST(CASE WHEN a.flag_renewal_90d= 1 AND ISNULL(f.excl_product,0)=0 THEN 1 ELSE 0 END AS BIGINT)), -- CHANGE
        sites            = COUNT(DISTINCT CASE WHEN ISNULL(f.excl_product,0)=0 THEN a.site_id END),
        snapshot_date    = CONVERT(NVARCHAR(10), MAX(a.latest_snapshot_date), 23)
    INTO #KpiRaw
    FROM #A a
    LEFT JOIN #Flags f ON f.asset_key = a.asset_key
    GROUP BY a.domain;

    IF OBJECT_ID('tempdb..#Kpi') IS NOT NULL DROP TABLE #Kpi;

    SELECT
        r.domain,
        r.total_assets,
        /* eligible = covered + uncovered (both already exclude invalid & excluded) */
        eligible_assets = (r.covered_assets + r.uncovered),
        r.covered_assets,
        r.uncovered,
        /* excluded = total - eligible */
        excluded_assets = (r.total_assets - (r.covered_assets + r.uncovered)),
        -- CHANGE: compute as wide type, then TRY_CAST down to avoid overflow (formula unchanged)
        coverage_pct    = TRY_CAST(ROUND(
                            CASE WHEN (r.covered_assets + r.uncovered) <> 0
                                 THEN (100.0 * r.covered_assets * 1.0) / (r.covered_assets + r.uncovered)
                                 ELSE NULL END, 2) AS DECIMAL(6,2)),
        r.attach_usd,
        r.ldos12m,
        r.eosm12m,
        r.ren90d,
        r.sites,
        r.runrate_usd,
        company       = COALESCE(c.company, ''),
        snapshot_date = r.snapshot_date
    INTO #Kpi
    FROM #KpiRaw r
    LEFT JOIN #Company c ON c.domain = r.domain;

    -- CHANGE: turn warnings back on
    SET ANSI_WARNINGS ON;

    /* 5b) Top lists from #A (unchanged logic) */
    IF OBJECT_ID('tempdb..#Evi') IS NOT NULL DROP TABLE #Evi;
    ;WITH r AS (
        SELECT domain, sku, sku_description,
               device_category = NULL, device_type = NULL, item_type = NULL,
               site_name, city, state, country, age_years, age_bucket,
               attach_usd = CAST(ROUND(ISNULL(attach_price_usd,0),2) AS DECIMAL(18,2)),
               rn = ROW_NUMBER() OVER (PARTITION BY domain ORDER BY ISNULL(attach_price_usd,0) DESC, age_years DESC)
        FROM #A
        WHERE is_covered = 0 AND ISNULL(attach_price_usd,0) > 0
    )
    SELECT * INTO #Evi FROM r WHERE rn <= @TopEvi;

    IF OBJECT_ID('tempdb..#Mig') IS NOT NULL DROP TABLE #Mig;
    ;WITH r AS (
        SELECT domain, sku, sku_description, product_family, architecture, architecture_sub,
               site_name, city, state, country,
               ldos = CONVERT(NVARCHAR(10), ldos, 23),
               eosm = NULL,
               days_to = COALESCE(days_to_ldos, days_to_eosm),
               migration_pid = NULL,
               rn = ROW_NUMBER() OVER (
                        PARTITION BY domain
                        ORDER BY COALESCE(days_to_ldos, days_to_eosm) ASC, product_family, sku)
        FROM #A
        WHERE flag_ldos_12m = 1 OR flag_eosm_12m = 1
    )
    SELECT * INTO #Mig FROM r WHERE rn <= @TopMig;

    IF OBJECT_ID('tempdb..#Att') IS NOT NULL DROP TABLE #Att;
    ;WITH g AS (
        SELECT domain, sku, sku_description,
               assets = COUNT_BIG(*),
               attach_usd = CAST(ROUND(SUM(CASE WHEN is_covered = 0 THEN ISNULL(attach_price_usd,0) ELSE 0 END),2) AS DECIMAL(18,2))
        FROM #A
        WHERE is_covered = 0
        GROUP BY domain, sku, sku_description
    ),
    r AS (
        SELECT *, rn = ROW_NUMBER() OVER (PARTITION BY domain ORDER BY attach_usd DESC, assets DESC)
        FROM g
    )
    SELECT * INTO #Att FROM r WHERE rn <= @TopAtt;

    IF OBJECT_ID('tempdb..#Sites') IS NOT NULL DROP TABLE #Sites;
    ;WITH g AS (
        SELECT domain, site_id, site_name, city, state, country,
               assets    = COUNT_BIG(*),
               uncovered = SUM(CAST(CASE WHEN is_covered = 0 THEN 1 ELSE 0 END AS BIGINT)),  -- CHANGE: BIGINT
               ldos12m   = SUM(CAST(CASE WHEN flag_ldos_12m = 1 THEN 1 ELSE 0 END AS BIGINT)), -- CHANGE
               eosm12m   = SUM(CAST(CASE WHEN flag_eosm_12m = 1 THEN 1 ELSE 0 END AS BIGINT)), -- CHANGE
               ren90d    = SUM(CAST(CASE WHEN flag_renewal_90d = 1 THEN 1 ELSE 0 END AS BIGINT)) -- CHANGE
        FROM #A
        GROUP BY domain, site_id, site_name, city, state, country
    ),
    r AS (
        SELECT *, rn = ROW_NUMBER() OVER (PARTITION BY domain ORDER BY uncovered DESC, ldos12m DESC, assets DESC)
        FROM g
    )
    SELECT * INTO #Sites FROM r WHERE rn <= @TopSites;

    IF OBJECT_ID('tempdb..#Ren') IS NOT NULL DROP TABLE #Ren;
    ;WITH d AS (
        SELECT DISTINCT domain, contract_number, contract_end_date, service_level, site_name, city, state, country
        FROM #A
        WHERE flag_renewal_90d = 1
    ),
    r AS (
        SELECT domain, contract_number,
               contract_end = CONVERT(NVARCHAR(10), contract_end_date, 23),
               service_level, site_name, city, state, country,
               rn = ROW_NUMBER() OVER (PARTITION BY domain ORDER BY contract_end_date ASC, contract_number)
        FROM d
    )
    SELECT * INTO #Ren FROM r WHERE rn <= @TopRen;

    IF OBJECT_ID('tempdb..#Mix') IS NOT NULL DROP TABLE #Mix;
    SELECT domain, architecture, product_family, assets = COUNT_BIG(*)
    INTO #Mix
    FROM #A
    GROUP BY domain, architecture, product_family;

    IF OBJECT_ID('tempdb..#Age') IS NOT NULL DROP TABLE #Age;
    SELECT domain, age_bucket, assets = COUNT_BIG(*)
    INTO #Age
    FROM #A
    GROUP BY domain, age_bucket;

	/* 6) Assemble JSON per domain -> materialize for MERGE, with progress output */
	IF OBJECT_ID('tempdb..#Upsert') IS NOT NULL DROP TABLE #Upsert;
	CREATE TABLE #Upsert
	(
		domain         NVARCHAR(255) NOT NULL PRIMARY KEY,
		payload        NVARCHAR(MAX) NOT NULL,
		payload_hash   VARBINARY(32) NOT NULL,
		company        NVARCHAR(400) NULL,
		snapshot_date  DATE NULL,
		generated_at   DATETIME2(7) NOT NULL
	);

	/* Worklist of domains to process, ordered; carry company for pretty progress lines */
	IF OBJECT_ID('tempdb..#Todo') IS NOT NULL DROP TABLE #Todo;
	SELECT
		rn      = ROW_NUMBER() OVER (ORDER BY k.domain),
		k.domain,
		k.company,
		k.snapshot_date
	INTO #Todo
	FROM #Kpi AS k;

	DECLARE
		@i            INT = 1,
		@n            INT = (SELECT COUNT(*) FROM #Todo),
		@domain       NVARCHAR(255),
		@company      NVARCHAR(400),
		@snap         NVARCHAR(10),
		@payload      NVARCHAR(MAX),
		@generated_at DATETIME2(7);

	WHILE @i <= @n
	BEGIN
		SELECT @domain = domain, @company = company, @snap = snapshot_date
		FROM #Todo WHERE rn = @i;

		/* Build JSON for just this domain (same shape as before) */
		SELECT @payload =
		(
		  SELECT
			kpi = (
				SELECT
					total_assets,
					eligible_assets,
					covered_assets,
					uncovered,
					excluded_assets,
					coverage_pct,
					attach_usd,
					ldos12m,
					eosm12m,
					ren90d,
					sites,
					runrate_usd,
					company       = COALESCE(NULLIF(k.company,''), ''),
					domain        = k.domain,
					snapshot_date = k.snapshot_date
				FROM #Kpi AS k
				WHERE k.domain = @domain
				FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
			),
			evi = (SELECT sku, sku_description, device_category, device_type, item_type,
						  site_name, city, state, country, age_years, age_bucket, attach_usd
				   FROM #Evi e WHERE e.domain = @domain
				   ORDER BY attach_usd DESC, age_years DESC
				   FOR JSON PATH),
			mig = (SELECT sku, sku_description, product_family, architecture, architecture_sub,
						  site_name, city, state, country, ldos, eosm, days_to, migration_pid
				   FROM #Mig m WHERE m.domain = @domain
				   ORDER BY days_to ASC, product_family, sku
				   FOR JSON PATH),
			att = (SELECT sku, sku_description, assets, attach_usd
				   FROM #Att a WHERE a.domain = @domain
				   ORDER BY attach_usd DESC, assets DESC
				   FOR JSON PATH),
			sites = (SELECT site_id, site_name, city, state, country, assets, uncovered, ldos12m, eosm12m, ren90d
					 FROM #Sites s WHERE s.domain = @domain
					 ORDER BY uncovered DESC, ldos12m DESC, assets DESC
					 FOR JSON PATH),
			ren = (SELECT contract_number, contract_end, service_level, site_name, city, state, country
				   FROM #Ren r WHERE r.domain = @domain
				   ORDER BY contract_end, contract_number
				   FOR JSON PATH),
			mix = (SELECT architecture, product_family, assets
				   FROM #Mix x WHERE x.domain = @domain
				   ORDER BY assets DESC
				   FOR JSON PATH),
			age = (SELECT age_bucket, assets
				   FROM #Age g WHERE g.domain = @domain
				   ORDER BY CASE g.age_bucket WHEN '<3y' THEN 1 WHEN N'3–5y' THEN 2 WHEN N'6–7y' THEN 3 WHEN N'8y+' THEN 4 ELSE 9 END
				   FOR JSON PATH)
		  FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
		);

		SET @generated_at = SYSUTCDATETIME();

		INSERT INTO #Upsert(domain, payload, payload_hash, company, snapshot_date, generated_at)
		VALUES
		(
			@domain,
			@payload,
			HASHBYTES('SHA2_256', CONVERT(VARBINARY(MAX), @payload)),
			@company,
			TRY_CONVERT(date, @snap),
			@generated_at
		);

		/* Progress line: e.g., 1/400_Acme Corp */
		RAISERROR('%d/%d_%s', 0, 1, @i, @n, @company) WITH NOWAIT;

		SET @i += 1;
	END;

	/* 7) Upsert into cache (unchanged) */
	MERGE aicm.PayloadCache AS T
	USING #Upsert AS S
	  ON T.domain = S.domain
	WHEN MATCHED THEN
		UPDATE SET
			T.client_key    = CASE
								WHEN T.payload_hash <> S.payload_hash
								  OR T.client_key IS NULL
								  OR LTRIM(RTRIM(T.client_key)) = ''
								THEN S.company
								ELSE T.client_key
							  END,
			T.company_url   = CASE WHEN T.payload_hash <> S.payload_hash THEN NULL            ELSE T.company_url   END,
			T.snapshot_date = CASE WHEN T.payload_hash <> S.payload_hash THEN S.snapshot_date ELSE T.snapshot_date END,
			T.generated_at  = CASE WHEN T.payload_hash <> S.payload_hash THEN S.generated_at  ELSE T.generated_at  END,
			T.latest_only   = CASE WHEN T.payload_hash <> S.payload_hash THEN @LatestOnly     ELSE T.latest_only   END,
			T.top_evi       = CASE WHEN T.payload_hash <> S.payload_hash THEN @TopEvi         ELSE T.top_evi       END,
			T.top_mig       = CASE WHEN T.payload_hash <> S.payload_hash THEN @TopMig         ELSE T.top_mig       END,
			T.top_att       = CASE WHEN T.payload_hash <> S.payload_hash THEN @TopAtt         ELSE T.top_att       END,
			T.top_sites     = CASE WHEN T.payload_hash <> S.payload_hash THEN @TopSites       ELSE T.top_sites     END,
			T.top_ren       = CASE WHEN T.payload_hash <> S.payload_hash THEN @TopRen         ELSE T.top_ren       END,
			T.payload       = CASE WHEN T.payload_hash <> S.payload_hash THEN S.payload       ELSE T.payload       END,
			T.payload_hash  = CASE WHEN T.payload_hash <> S.payload_hash THEN S.payload_hash  ELSE T.payload_hash  END,
			T.is_latest     = CASE WHEN T.payload_hash <> S.payload_hash THEN 1               ELSE T.is_latest     END,
			T.heartbeat_utc = SYSUTCDATETIME()
	WHEN NOT MATCHED BY TARGET THEN
		INSERT (client_key, company_url, domain, snapshot_date, generated_at, latest_only,
				top_evi, top_mig, top_att, top_sites, top_ren,
				payload, payload_hash, is_latest, heartbeat_utc)
		VALUES (S.company, NULL, S.domain, S.snapshot_date, S.generated_at, @LatestOnly,
				@TopEvi, @TopMig, @TopAtt, @TopSites, @TopRen,
				S.payload, S.payload_hash, 1, SYSUTCDATETIME());

	/* Final summary */
	SELECT COUNT(*) AS domains_processed FROM #Upsert;
END
GO


