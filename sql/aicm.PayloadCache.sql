-- aicm.PayloadCache
IF OBJECT_ID('aicm.PayloadCache','U') IS NOT NULL DROP TABLE aicm.PayloadCache;
GO
CREATE TABLE aicm.PayloadCache
(
    PayloadCacheId  BIGINT IDENTITY(1,1) PRIMARY KEY,
    CompanyUrl      NVARCHAR(255)   NOT NULL,
    PayloadType     NVARCHAR(50)    NOT NULL DEFAULT 'email',
    JsonPayload     NVARCHAR(MAX)   NOT NULL,        -- compact JSON
    GeneratedOn     DATETIME2       NOT NULL DEFAULT SYSUTCDATETIME(),
    GeneratedBy     NVARCHAR(100)   NULL,
    HashKey         VARBINARY(32)   NULL             -- optional content hash
);
GO

CREATE INDEX IX_PayloadCache_CompanyUrl ON aicm.PayloadCache(CompanyUrl, GeneratedOn DESC);
GO
