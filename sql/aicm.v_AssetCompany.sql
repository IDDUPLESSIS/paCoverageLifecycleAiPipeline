-- aicm.v_AssetCompany (demo placeholder)
IF OBJECT_ID('aicm.v_AssetCompany','V') IS NOT NULL DROP VIEW aicm.v_AssetCompany;
GO
CREATE VIEW aicm.v_AssetCompany AS
SELECT 
    a.AssetId,
    a.SerialNumber,
    a.ProductFamily,
    a.CoverageStatus,
    a.LifecycleState,
    a.SiteName,
    m.MasterCompanyId,
    m.Domain,
    CASE WHEN a.LifecycleState IN ('LDOS_12M','EOSM_12M') THEN 1 ELSE 0 END AS FlagLifecycleRisk
FROM aicm.RAI_SP0 a
JOIN aicm.DomainClientMap m
  ON a.Domain = m.Domain;
GO
