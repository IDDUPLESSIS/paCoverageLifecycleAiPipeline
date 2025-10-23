-- aicm.DomainClientMap
IF OBJECT_ID('aicm.DomainClientMap','U') IS NOT NULL DROP TABLE aicm.DomainClientMap;
GO
CREATE TABLE aicm.DomainClientMap
(
    DomainClientMapId   INT IDENTITY(1,1) PRIMARY KEY,
    MasterCompanyId     INT             NOT NULL,
    CompanyUrl          NVARCHAR(255)   NOT NULL, -- e.g., https://example.com
    Domain              NVARCHAR(255)   NOT NULL, -- e.g., example.com
    IsAnchor            BIT             NOT NULL DEFAULT(0),
    ConfidenceScore     DECIMAL(5,2)    NULL,
    Source              NVARCHAR(100)   NULL,
    CreatedOn           DATETIME2       NOT NULL DEFAULT SYSUTCDATETIME(),
    UpdatedOn           DATETIME2       NULL
);
GO

CREATE UNIQUE INDEX IX_DomainClientMap_UQ ON aicm.DomainClientMap(MasterCompanyId, Domain);
GO
