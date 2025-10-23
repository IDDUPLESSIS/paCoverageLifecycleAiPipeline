USE [IBA]
GO

/****** Object:  StoredProcedure [aicm].[sp_GetLatestPayloadByUrl]    Script Date: 10/23/2025 11:03:29 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


/* ============================================
   New canonical proc: aicm.sp_GetLatestPayloadByUrl
   - No dependencies on custom UDFs
   - Queries aicm.PayloadCache
   ============================================ */
CREATE   PROCEDURE [aicm].[sp_GetLatestPayloadByUrl]
    @CompanyUrl NVARCHAR(512)
AS
BEGIN
    SET NOCOUNT ON;

    -- Inline URL -> domain normalization
    DECLARE @u NVARCHAR(512) = LTRIM(RTRIM(@CompanyUrl));
    DECLARE @d NVARCHAR(255);

    -- strip scheme (://)
    DECLARE @pos INT = CHARINDEX('://', @u);
    IF @pos > 0 SET @u = SUBSTRING(@u, @pos + 3, 512);

    -- strip mailto:
    IF LEFT(@u,7) = 'mailto:' SET @u = SUBSTRING(@u, 8, 512);

    -- strip leading www.
    IF LOWER(LEFT(@u,4)) = 'www.' SET @u = SUBSTRING(@u, 5, 512);

    -- cut off path / query / fragment
    DECLARE @slash INT = NULLIF(NULLIF(NULLIF(
        NULLIF(CHARINDEX('/',  @u),0),
        CASE WHEN CHARINDEX('?',  @u) = 0 THEN NULL ELSE CHARINDEX('?',  @u) END),
        CASE WHEN CHARINDEX('#',  @u) = 0 THEN NULL ELSE CHARINDEX('#',  @u) END),0);

    IF @slash IS NOT NULL SET @u = LEFT(@u, @slash-1);

    -- cut off port if any
    DECLARE @colon INT = CHARINDEX(':', @u);
    IF @colon > 0 SET @u = LEFT(@u, @colon-1);

    -- trim whitespace, lowercase, strip trailing dot
    SET @u = LOWER(LTRIM(RTRIM(@u)));
    IF RIGHT(@u,1) = '.' SET @u = LEFT(@u, LEN(@u)-1);

    -- final domain
    SET @d = @u;

    -- Return latest payload for that domain
    SELECT TOP (1)
           payload,
           domain,
           generated_at,
           snapshot_date
    FROM aicm.PayloadCache
    WHERE domain = @d
    ORDER BY generated_at DESC;
END
GO


