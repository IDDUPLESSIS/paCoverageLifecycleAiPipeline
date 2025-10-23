-- aicm.v_Domains
IF OBJECT_ID('aicm.v_Domains','V') IS NOT NULL DROP VIEW aicm.v_Domains;
GO
CREATE VIEW aicm.v_Domains AS
SELECT DISTINCT
    d.DomainClientMapId,
    d.MasterCompanyId,
    d.CompanyUrl,
    d.Domain,
    d.IsAnchor,
    d.ConfidenceScore
FROM aicm.DomainClientMap d;
GO
