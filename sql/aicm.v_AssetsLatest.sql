-- aicm.v_AssetsLatest (demo placeholder)
IF OBJECT_ID('aicm.v_AssetsLatest','V') IS NOT NULL DROP VIEW aicm.v_AssetsLatest;
GO
CREATE VIEW aicm.v_AssetsLatest AS
SELECT *
FROM aicm.RAI_SP0 -- assume created by samples/setup.sql
WHERE IsLatest = 1;
GO
