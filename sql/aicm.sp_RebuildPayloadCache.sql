-- aicm.sp_RebuildPayloadCache (demo payload builder)
IF OBJECT_ID('aicm.sp_RebuildPayloadCache','P') IS NOT NULL DROP PROCEDURE aicm.sp_RebuildPayloadCache;
GO
CREATE PROCEDURE aicm.sp_RebuildPayloadCache
    @LatestOnly BIT = 1
AS
BEGIN
    SET NOCOUNT ON;

    ;WITH cte AS (
        SELECT 
            m.CompanyUrl,
            COUNT(*) AS AssetCount,
            SUM(CASE WHEN a.CoverageStatus='Covered' THEN 1 ELSE 0 END) AS Covered,
            SUM(CASE WHEN a.CoverageStatus<>'Covered' THEN 1 ELSE 0 END) AS Uncovered,
            SUM(CASE WHEN a.LifecycleState IN ('LDOS_12M','EOSM_12M') THEN 1 ELSE 0 END) AS LifecycleRisk
        FROM aicm.RAI_SP0 a
        JOIN aicm.DomainClientMap m ON a.Domain = m.Domain
        WHERE (@LatestOnly = 0) OR (a.IsLatest = 1)
        GROUP BY m.CompanyUrl
    )
    INSERT INTO aicm.PayloadCache (CompanyUrl, PayloadType, JsonPayload, GeneratedBy)
    SELECT 
        c.CompanyUrl,
        'email',
        (
            SELECT
                c.AssetCount AS asset_count,
                c.Covered AS covered,
                c.Uncovered AS uncovered,
                c.LifecycleRisk AS lifecycle_risk,
                SYSUTCDATETIME() AS generated_on
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        ),
        SUSER_SNAME()
    FROM cte c;
END
GO
