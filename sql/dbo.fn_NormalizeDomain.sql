USE [IBA]
GO

/****** Object:  UserDefinedFunction [dbo].[fn_NormalizeDomain]    Script Date: 10/23/2025 11:12:58 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


/* =========================
   1) Helper: URL → bare domain
   ========================= */
CREATE   FUNCTION [dbo].[fn_NormalizeDomain] (@url NVARCHAR(512))
RETURNS NVARCHAR(255)
AS
BEGIN
    DECLARE @u NVARCHAR(512) = LOWER(LTRIM(RTRIM(@url)));
    IF @u IS NULL OR @u = '' RETURN NULL;

    IF LEFT(@u,8) = 'https://' SET @u = SUBSTRING(@u,9,4000);
    ELSE IF LEFT(@u,7) = 'http://' SET @u = SUBSTRING(@u,8,4000);

    IF CHARINDEX('/', @u) > 0 SET @u = LEFT(@u, CHARINDEX('/', @u)-1);
    IF LEFT(@u,4) = 'www.' SET @u = SUBSTRING(@u,5,4000);
    RETURN @u;
END
GO


