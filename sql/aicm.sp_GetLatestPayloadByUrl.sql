-- aicm.sp_GetLatestPayloadByUrl
IF OBJECT_ID('aicm.sp_GetLatestPayloadByUrl','P') IS NOT NULL DROP PROCEDURE aicm.sp_GetLatestPayloadByUrl;
GO
CREATE PROCEDURE aicm.sp_GetLatestPayloadByUrl
    @CompanyUrl NVARCHAR(255)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT TOP(1)
        CompanyUrl,
        PayloadType,
        JsonPayload,
        GeneratedOn,
        GeneratedBy
    FROM aicm.PayloadCache
    WHERE CompanyUrl = @CompanyUrl
    ORDER BY GeneratedOn DESC;
END
GO
