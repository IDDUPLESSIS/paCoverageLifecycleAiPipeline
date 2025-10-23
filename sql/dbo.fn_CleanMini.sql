USE [IBA]
GO

/****** Object:  UserDefinedFunction [dbo].[fn_CleanMini]    Script Date: 10/23/2025 11:12:21 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


/* ==============================================
   2) Helper: strip odd whitespace & lowercase
      (NBSP, tabs, CR/LF, NUL, BOM, zero-width)
   ============================================== */
CREATE   FUNCTION [dbo].[fn_CleanMini] (@s NVARCHAR(4000))
RETURNS NVARCHAR(4000)
AS
BEGIN
    DECLARE @x NVARCHAR(4000) = LOWER(COALESCE(@s,''));
    SET @x = LTRIM(RTRIM(@x));
    SET @x = REPLACE(@x, NCHAR(160),  '');  -- NBSP
    SET @x = REPLACE(@x, CHAR(9),     '');  -- TAB
    SET @x = REPLACE(@x, CHAR(13),    '');  -- CR
    SET @x = REPLACE(@x, CHAR(10),    '');  -- LF
    SET @x = REPLACE(@x, CHAR(0),     '');  -- NUL
    SET @x = REPLACE(@x, NCHAR(65279),'');  -- BOM
    SET @x = REPLACE(@x, NCHAR(8203), '');  -- zero-width space
    SET @x = REPLACE(@x, ' ',         '');  -- normal spaces
    RETURN @x;
END
GO


