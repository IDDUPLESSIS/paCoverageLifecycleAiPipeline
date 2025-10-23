-- dbo.fn_NormalizeDomain (toy version)
IF OBJECT_ID('dbo.fn_NormalizeDomain','FN') IS NOT NULL DROP FUNCTION dbo.fn_NormalizeDomain;
GO
CREATE FUNCTION dbo.fn_NormalizeDomain (@domain NVARCHAR(255))
RETURNS NVARCHAR(255)
AS
BEGIN
    IF @domain IS NULL RETURN NULL;
    DECLARE @d NVARCHAR(255) = LOWER(LTRIM(RTRIM(@domain)));
    -- strip protocol and www
    IF LEFT(@d,8)='https://' SET @d = SUBSTRING(@d,9,255);
    IF LEFT(@d,7)='http://'  SET @d = SUBSTRING(@d,8,255);
    IF LEFT(@d,4)='www.'     SET @d = SUBSTRING(@d,5,255);
    RETURN @d;
END
GO
