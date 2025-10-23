-- samples/setup.sql : minimal demo objects + data
:r .\sql\000_create_schema.sql
:r .\sql\aicm.DomainClientMap.sql
GO

-- Minimal asset table for demo purposes
IF OBJECT_ID('aicm.RAI_SP0','U') IS NOT NULL DROP TABLE aicm.RAI_SP0;
GO
CREATE TABLE aicm.RAI_SP0
(
    AssetId         BIGINT IDENTITY(1,1) PRIMARY KEY,
    SerialNumber    NVARCHAR(100) NOT NULL,
    ProductFamily   NVARCHAR(100) NULL,
    CoverageStatus  NVARCHAR(50)  NULL,  -- Covered / Uncovered
    LifecycleState  NVARCHAR(50)  NULL,  -- e.g., LDOS_12M, EOSM_12M, Normal
    SiteName        NVARCHAR(200) NULL,
    Domain          NVARCHAR(255) NOT NULL,
    IsLatest        BIT           NOT NULL DEFAULT(1)
);
GO

-- Seed domain map
INSERT INTO aicm.DomainClientMap (MasterCompanyId, CompanyUrl, Domain, IsAnchor, ConfidenceScore, Source)
VALUES
(1001, 'https://example.com', 'example.com', 1, 80, 'seed'),
(1002, 'https://acme.test',   'acme.test',   1, 75, 'seed');
GO

-- Load a few records (synthetic)
INSERT INTO aicm.RAI_SP0 (SerialNumber, ProductFamily, CoverageStatus, LifecycleState, SiteName, Domain, IsLatest)
VALUES
('SN-1001', 'Switches', 'Covered',   'Normal',    'Charlotte HQ', 'example.com', 1),
('SN-1002', 'Routers',  'Uncovered', 'LDOS_12M',  'Durham DC',    'example.com', 1),
('SN-1003', 'Wireless', 'Covered',   'Normal',    'Raleigh',      'acme.test',   1),
('SN-1004', 'Security', 'Uncovered', 'EOSM_12M',  'Cary',         'acme.test',   1);
GO

:r .\sql\dbo.fn_NormalizeDomain.sql
:r .\sql\dbo.fn_CleanMini.sql
:r .\sql\aicm.v_Domains.sql
:r .\sql\aicm.v_DomainTokens.sql
:r .\sql\aicm.v_AssetsLatest.sql
:r .\sql\aicm.v_AssetCompany.sql
:r .\sql\aicm.sp_RefreshDomainMap.sql
:r .\sql\aicm.sp_RebuildPayloadCache.sql
:r .\sql\aicm.sp_GetLatestPayloadByUrl.sql
GO
