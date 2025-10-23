USE [IBA]
GO

/****** Object:  Table [aicm].[DomainClientMap]    Script Date: 10/23/2025 11:00:16 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [aicm].[DomainClientMap](
	[domain_clean] [nvarchar](255) NOT NULL,
	[client_key] [nvarchar](190) NOT NULL,
	[source] [varchar](32) NOT NULL,
	[created_at_utc] [datetime2](3) NOT NULL,
	[last_seen_utc] [datetime2](3) NULL
) ON [PRIMARY]
GO

ALTER TABLE [aicm].[DomainClientMap] ADD  CONSTRAINT [DF_DCKM_created]  DEFAULT (sysutcdatetime()) FOR [created_at_utc]
GO

ALTER TABLE [aicm].[DomainClientMap] ADD  CONSTRAINT [DF_DCKM_last_seen_utc]  DEFAULT (sysutcdatetime()) FOR [last_seen_utc]
GO

ALTER TABLE [aicm].[DomainClientMap]  WITH CHECK ADD  CONSTRAINT [CK_DCKM_ClientKey_NotBlank] CHECK  (([client_key] IS NOT NULL AND ltrim(rtrim([client_key]))<>''))
GO

ALTER TABLE [aicm].[DomainClientMap] CHECK CONSTRAINT [CK_DCKM_ClientKey_NotBlank]
GO


