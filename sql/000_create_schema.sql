-- Create schema if missing
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'aicm')
    EXEC('CREATE SCHEMA aicm');
GO
