USE [IBA]
GO

/****** Object:  StoredProcedure [aicm].[sp_RefreshDomainMap]    Script Date: 10/23/2025 11:05:11 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


/*========================================================================================
Proc: aicm.sp_RefreshDomainMap  (Optimized, NULL-safe, #Chosen materialized)
Goal:
  Choose the best (domain_clean → client_key) per domain using MASTERDATA names
  (Parent/Canonical/Legal/Child) + ExistingMap fallback, scored by actual rows in
  aicm.v_AssetCompany. Fast via staged, indexed temp tables. Robust to NULLs.

Inputs:
  @DomainList : dbo.ListOfVarchars READONLY (empty = ALL)
  @PurgeDays  : INT (NULL = no purge)

Key implementation notes:
  • Stages assets in #V with normalized columns and indexes (NULL-safe).
  • Two scoring paths: client_key equality and prefix LIKE (seek via prefix4).
  • Materializes final picks into #Chosen (so no CTE-scope surprises).
  • No synonyms; reads MASTERDATA.dbo.MSTR_CompanyNameMapping_New directly.
========================================================================================*/
CREATE   PROCEDURE [aicm].[sp_RefreshDomainMap]
    @DomainList dbo.ListOfVarchars READONLY,
    @PurgeDays  INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF OBJECT_ID('aicm.DomainClientMap','U') IS NULL
        RAISERROR('Missing table aicm.DomainClientMap.',16,1);

    /* 1) Scope domains */
    IF OBJECT_ID('tempdb..#Domains') IS NOT NULL DROP TABLE #Domains;
    CREATE TABLE #Domains(domain_clean NVARCHAR(255) NOT NULL PRIMARY KEY);

    IF EXISTS (SELECT 1 FROM @DomainList)
        INSERT #Domains(domain_clean)
        SELECT DISTINCT LOWER(LTRIM(RTRIM(value))) FROM @DomainList;
    ELSE IF OBJECT_ID('aicm.v_Domains','V') IS NOT NULL
        INSERT #Domains(domain_clean)
        SELECT DISTINCT LOWER(LTRIM(RTRIM(Domain))) FROM aicm.v_Domains;
    ELSE
        INSERT #Domains(domain_clean)
        SELECT DISTINCT domain_clean FROM aicm.DomainClientMap;

    /* 2) Candidate names from MASTERDATA + existing map */
    IF OBJECT_ID('tempdb..#NameCandidates') IS NOT NULL DROP TABLE #NameCandidates;
    CREATE TABLE #NameCandidates
    (
        domain_clean NVARCHAR(255) NOT NULL,
        raw_name     NVARCHAR(512) NOT NULL,
        src_col      NVARCHAR(40)  NOT NULL
    );

    IF OBJECT_ID('MASTERDATA.dbo.MSTR_CompanyNameMapping_New','U') IS NOT NULL
    BEGIN
        ;WITH CM AS (
            SELECT
                domain_clean = LOWER(LTRIM(RTRIM(cm.Domain))),
                ParentCompanyName     = LTRIM(RTRIM(cm.ParentCompanyName)),
                CanonicalCompanyName  = LTRIM(RTRIM(cm.CanonicalCompanyName)),
                LegalName             = LTRIM(RTRIM(cm.LegalName)),
                ChildCompanyName      = LTRIM(RTRIM(cm.ChildCompanyName))
            FROM MASTERDATA.dbo.MSTR_CompanyNameMapping_New cm
            JOIN #Domains d ON d.domain_clean = LOWER(LTRIM(RTRIM(cm.Domain)))
        )
        INSERT #NameCandidates(domain_clean, raw_name, src_col)
        SELECT domain_clean, ParentCompanyName,    N'ParentCompanyName'    FROM CM WHERE ParentCompanyName    IS NOT NULL AND LEN(ParentCompanyName)    > 0
        UNION ALL
        SELECT domain_clean, CanonicalCompanyName, N'CanonicalCompanyName' FROM CM WHERE CanonicalCompanyName IS NOT NULL AND LEN(CanonicalCompanyName) > 0
        UNION ALL
        SELECT domain_clean, LegalName,            N'LegalName'            FROM CM WHERE LegalName             IS NOT NULL AND LEN(LegalName)            > 0
        UNION ALL
        SELECT domain_clean, ChildCompanyName,     N'ChildCompanyName'     FROM CM WHERE ChildCompanyName      IS NOT NULL AND LEN(ChildCompanyName)     > 0;
    END

    -- Include existing map key as a candidate
    INSERT #NameCandidates(domain_clean, raw_name, src_col)
    SELECT m.domain_clean, LTRIM(RTRIM(m.client_key)), N'ExistingMap'
    FROM aicm.DomainClientMap m
    JOIN #Domains d ON d.domain_clean = m.domain_clean
    WHERE m.client_key IS NOT NULL AND LEN(LTRIM(RTRIM(m.client_key))) > 0;

    /* 3) Normalize candidates + prefix for seeks */
    IF OBJECT_ID('tempdb..#NormCandidates') IS NOT NULL DROP TABLE #NormCandidates;
    CREATE TABLE #NormCandidates
    (
        domain_clean  NVARCHAR(255) NOT NULL,
        raw_name      NVARCHAR(512) NOT NULL,
        raw_name_norm NVARCHAR(512) NOT NULL,
        norm_name     NVARCHAR(512) NOT NULL,
        prefix4       NVARCHAR(4)   NOT NULL,
        src_col       NVARCHAR(40)  NOT NULL
    );

    INSERT #NormCandidates(domain_clean, raw_name, raw_name_norm, norm_name, prefix4, src_col)
    SELECT
        nc.domain_clean,
        nc.raw_name,
        UPPER(LTRIM(RTRIM(nc.raw_name))) AS raw_name_norm,
        s_final.s AS norm_name,
        LEFT(s_final.s, 4) AS prefix4,
        nc.src_col
    FROM #NameCandidates nc
    CROSS APPLY (SELECT UPPER(LTRIM(RTRIM(nc.raw_name))) ) s0(s)
    CROSS APPLY (SELECT REPLACE(s0.s, N'.', N'')         ) s1(s)
    CROSS APPLY (SELECT REPLACE(s1.s, N',', N'')         ) s2(s)
    CROSS APPLY (SELECT REPLACE(s2.s, N' LIMITED', N'')  ) s3(s)
    CROSS APPLY (SELECT REPLACE(s3.s, N' LTD', N'')      ) s4(s)
    CROSS APPLY (SELECT REPLACE(s4.s, N' CORPORATION',N'')) s5(s)
    CROSS APPLY (SELECT REPLACE(s5.s, N' CORP', N'')     ) s6(s)
    CROSS APPLY (SELECT REPLACE(s6.s, N' COMPANY', N'')  ) s7(s)
    CROSS APPLY (SELECT REPLACE(s7.s, N' CO', N'')       ) s8(s)
    CROSS APPLY (SELECT REPLACE(s8.s, N' INCORPORATED',N'')) s9(s)
    CROSS APPLY (SELECT REPLACE(s9.s, N' INC', N'')      ) s10(s)
    CROSS APPLY (SELECT REPLACE(s10.s, N' LLC', N'')     ) s_final(s);

    CREATE INDEX IX_NormCandidates_Prefix ON #NormCandidates(prefix4, norm_name);
    CREATE INDEX IX_NormCandidates_Domain ON #NormCandidates(domain_clean);

    /* 4) Stage asset slice with normalized columns + indexes (NULL-safe) */
    IF OBJECT_ID('tempdb..#V') IS NOT NULL DROP TABLE #V;
    CREATE TABLE #V
    (
        client_key                NVARCHAR(190) NOT NULL,
        client_key_norm           NVARCHAR(190) NOT NULL,
        primary_company_name_norm NVARCHAR(512) NULL,
        prefix4                   NVARCHAR(4)   NULL
    );

    INSERT #V(client_key, client_key_norm, primary_company_name_norm, prefix4)
    SELECT
        v.client_key,
        UPPER(LTRIM(RTRIM(v.client_key))) AS client_key_norm,
        CASE 
            WHEN v.primary_company_name IS NULL OR LEN(LTRIM(RTRIM(v.primary_company_name))) = 0 
                THEN NULL
            ELSE UPPER(LTRIM(RTRIM(v.primary_company_name)))
        END AS primary_company_name_norm,
        CASE 
            WHEN v.primary_company_name IS NULL OR LEN(LTRIM(RTRIM(v.primary_company_name))) = 0 
                THEN NULL
            ELSE LEFT(UPPER(LTRIM(RTRIM(v.primary_company_name))), 4)
        END AS prefix4
    FROM aicm.v_AssetCompany v;

    CREATE INDEX IX_V_ClientKeyNorm ON #V(client_key_norm) INCLUDE (client_key);
    CREATE INDEX IX_V_PrimaryPrefix ON #V(prefix4, primary_company_name_norm) INCLUDE (client_key);

    /* 5) Score candidates (equality + prefix), keep MASTER vs EXISTING groups */
    IF OBJECT_ID('tempdb..#Scored') IS NOT NULL DROP TABLE #Scored;
    CREATE TABLE #Scored
    (
        domain_clean NVARCHAR(255) NOT NULL,
        client_key   NVARCHAR(190) NOT NULL,
        src_group    NVARCHAR(12)  NOT NULL, -- 'MASTER' or 'EXISTING'
        asset_rows   BIGINT        NOT NULL
    );

    -- (A) Equality on client_key (fast seek)
    INSERT #Scored(domain_clean, client_key, src_group, asset_rows)
    SELECT c.domain_clean, v.client_key,
           CASE WHEN c.src_col = N'ExistingMap' THEN N'EXISTING' ELSE N'MASTER' END,
           COUNT_BIG(*)
    FROM #NormCandidates c
    JOIN #V v
      ON v.client_key_norm = c.raw_name_norm
    GROUP BY c.domain_clean, v.client_key,
             CASE WHEN c.src_col = N'ExistingMap' THEN N'EXISTING' ELSE N'MASTER' END;

    -- (B) Prefix on primary_company_name (seek via prefix4 + LIKE), NULL-safe
    INSERT #Scored(domain_clean, client_key, src_group, asset_rows)
    SELECT c.domain_clean, v.client_key,
           CASE WHEN c.src_col = N'ExistingMap' THEN N'EXISTING' ELSE N'MASTER' END,
           COUNT_BIG(*)
    FROM #NormCandidates c
    JOIN #V v
      ON v.prefix4 IS NOT NULL
     AND c.prefix4 IS NOT NULL
     AND v.prefix4 = c.prefix4
     AND v.primary_company_name_norm LIKE c.norm_name + N'%'
    GROUP BY c.domain_clean, v.client_key,
             CASE WHEN c.src_col = N'ExistingMap' THEN N'EXISTING' ELSE N'MASTER' END;

    -- Collapse duplicates
    IF OBJECT_ID('tempdb..#ScoredAgg') IS NOT NULL DROP TABLE #ScoredAgg;
    SELECT domain_clean, client_key, src_group, MAX(asset_rows) AS asset_rows
    INTO #ScoredAgg
    FROM #Scored
    GROUP BY domain_clean, client_key, src_group;

    CREATE INDEX IX_ScoredAgg_Domain ON #ScoredAgg(domain_clean);

    /* 6) Candidate set with priority: MASTER first (pri=1), EXISTING fallback (pri=9) */
    IF OBJECT_ID('tempdb..#Candidates') IS NOT NULL DROP TABLE #Candidates;
    CREATE TABLE #Candidates
    (
        domain_clean NVARCHAR(255) NOT NULL,
        client_key   NVARCHAR(190) NOT NULL,
        pri          INT           NOT NULL,
        asset_rows   BIGINT        NOT NULL
    );

    -- MASTER-derived
    INSERT #Candidates(domain_clean, client_key, pri, asset_rows)
    SELECT domain_clean, client_key, 1, asset_rows
    FROM #ScoredAgg
    WHERE src_group = N'MASTER';

    -- EXISTING (scored)
    INSERT #Candidates(domain_clean, client_key, pri, asset_rows)
    SELECT domain_clean, client_key, 9, asset_rows
    FROM #ScoredAgg
    WHERE src_group = N'EXISTING';

    -- EXISTING (true fallback zero-score if not added yet)
    INSERT #Candidates(domain_clean, client_key, pri, asset_rows)
    SELECT d.domain_clean, m.client_key, 9, 0
    FROM #Domains d
    JOIN aicm.DomainClientMap m ON m.domain_clean = d.domain_clean
    WHERE m.client_key IS NOT NULL AND LEN(LTRIM(RTRIM(m.client_key))) > 0
      AND NOT EXISTS (
            SELECT 1 FROM #Candidates c
            WHERE c.domain_clean = d.domain_clean AND c.client_key = m.client_key
      );

    /* 7) Pick best per domain -> materialize into #Chosen, then MERGE */
    IF OBJECT_ID('tempdb..#Chosen') IS NOT NULL DROP TABLE #Chosen;
    ;WITH ranked AS (
        SELECT c.*,
               ROW_NUMBER() OVER (
                 PARTITION BY c.domain_clean
                 ORDER BY c.asset_rows DESC, c.pri ASC, c.client_key
               ) AS rn
        FROM #Candidates c
    )
    SELECT domain_clean, client_key, pri
    INTO #Chosen
    FROM ranked
    WHERE rn = 1;

    MERGE aicm.DomainClientMap AS T
    USING #Chosen AS S
      ON T.domain_clean = S.domain_clean
    WHEN MATCHED THEN
        UPDATE SET
            T.client_key    = S.client_key,
            T.source        = CASE WHEN S.pri = 1 THEN 'MASTER' ELSE 'ExistingMap' END,
            T.last_seen_utc = SYSUTCDATETIME()
    WHEN NOT MATCHED THEN
        INSERT (domain_clean, client_key, source, created_at_utc, last_seen_utc)
        VALUES (S.domain_clean, S.client_key,
                CASE WHEN S.pri = 1 THEN 'MASTER' ELSE 'ExistingMap' END,
                SYSUTCDATETIME(), SYSUTCDATETIME());

    /* 8) Optional purge */
    IF @PurgeDays IS NOT NULL
        DELETE FROM aicm.DomainClientMap
        WHERE DATEDIFF(DAY, last_seen_utc, SYSUTCDATETIME()) > @PurgeDays;

    /* 9) Summary (no SUM/NULL warnings) */
    SELECT
        domains_processed = (SELECT COUNT(*) FROM #Domains),
        chosen_rows       = (SELECT COUNT(*) FROM #Chosen),
        master_chosen     = (SELECT COUNT(*) FROM aicm.DomainClientMap T
                             WHERE T.domain_clean IN (SELECT domain_clean FROM #Domains)
                               AND T.source = 'MASTER'),
        existing_chosen   = (SELECT COUNT(*) FROM aicm.DomainClientMap T
                             WHERE T.domain_clean IN (SELECT domain_clean FROM #Domains)
                               AND T.source = 'ExistingMap');
END
GO


