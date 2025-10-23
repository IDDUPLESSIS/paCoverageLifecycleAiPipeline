-- dbo.fn_CleanMini (toy string cleaner)
IF OBJECT_ID('dbo.fn_CleanMini','FN') IS NOT NULL DROP FUNCTION dbo.fn_CleanMini;
GO
CREATE FUNCTION dbo.fn_CleanMini (@s NVARCHAR(MAX))
RETURNS NVARCHAR(MAX)
AS
BEGIN
    IF @s IS NULL RETURN NULL;
    DECLARE @r NVARCHAR(MAX) = LTRIM(RTRIM(@s));
    SET @r = REPLACE(@r, CHAR(9), ' ');
    SET @r = REPLACE(@r, CHAR(13)+CHAR(10), ' ');
    WHILE CHARINDEX('  ', @r) > 0 SET @r = REPLACE(@r, '  ', ' ');
    RETURN @r;
END
GO
