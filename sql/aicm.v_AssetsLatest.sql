USE [IBA]
GO

/****** Object:  View [aicm].[v_AssetsLatest]    Script Date: 10/23/2025 11:08:21 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO




-- A. Latest-only slice of your base view
CREATE   VIEW [aicm].[v_AssetsLatest]
AS
SELECT *
FROM [aicm].[v_AssetCompany]
WHERE is_latest = 1;
GO


