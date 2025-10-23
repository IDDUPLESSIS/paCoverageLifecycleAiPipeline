-- aicm.v_DomainTokens (very simple example)
IF OBJECT_ID('aicm.v_DomainTokens','V') IS NOT NULL DROP VIEW aicm.v_DomainTokens;
GO
CREATE VIEW aicm.v_DomainTokens AS
SELECT 
    d.DomainClientMapId,
    d.Domain,
    PARSENAME(REPLACE(d.Domain,'.','.'), 3) AS Token3, -- naive tokens for demo
    PARSENAME(REPLACE(d.Domain,'.','.'), 2) AS Token2,
    PARSENAME(REPLACE(d.Domain,'.','.'), 1) AS TLD
FROM aicm.DomainClientMap d;
GO
