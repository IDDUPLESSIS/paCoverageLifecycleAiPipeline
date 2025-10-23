-- aicm.sp_RefreshDomainMap (demo scoring/refresh stub)
IF OBJECT_ID('aicm.sp_RefreshDomainMap','P') IS NOT NULL DROP PROCEDURE aicm.sp_RefreshDomainMap;
GO
CREATE PROCEDURE aicm.sp_RefreshDomainMap
AS
BEGIN
    SET NOCOUNT ON;

    -- Example: ensure domains are normalized and confidence calculated
    UPDATE d
       SET Domain = dbo.fn_NormalizeDomain(Domain),
           ConfidenceScore = COALESCE(ConfidenceScore, 0) + CASE WHEN IsAnchor = 1 THEN 50 ELSE 10 END,
           UpdatedOn = SYSUTCDATETIME()
    FROM aicm.DomainClientMap d;
END
GO
