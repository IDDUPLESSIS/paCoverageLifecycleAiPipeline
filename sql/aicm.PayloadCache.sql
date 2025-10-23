USE [IBA]
GO

/****** Object:  Table [aicm].[PayloadCache]    Script Date: 10/23/2025 11:01:41 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [aicm].[PayloadCache](
	[cache_id] [bigint] IDENTITY(1,1) NOT NULL,
	[client_key] [nvarchar](200) NULL,
	[company_url] [nvarchar](512) NULL,
	[domain] [nvarchar](255) NOT NULL,
	[snapshot_date] [date] NULL,
	[generated_at] [datetime2](0) NOT NULL,
	[latest_only] [bit] NOT NULL,
	[top_evi] [int] NULL,
	[top_mig] [int] NULL,
	[top_att] [int] NULL,
	[top_sites] [int] NULL,
	[top_ren] [int] NULL,
	[payload] [nvarchar](max) NOT NULL,
	[payload_hash] [varbinary](32) NOT NULL,
	[is_latest] [bit] NOT NULL,
	[heartbeat_utc] [datetime2](0) NULL,
PRIMARY KEY CLUSTERED 
(
	[cache_id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO

ALTER TABLE [aicm].[PayloadCache] ADD  CONSTRAINT [DF_PA_LLM_Cache_generated_at]  DEFAULT (sysutcdatetime()) FOR [generated_at]
GO

ALTER TABLE [aicm].[PayloadCache] ADD  CONSTRAINT [DF_PA_LLM_Cache_latest_only]  DEFAULT ((1)) FOR [latest_only]
GO

ALTER TABLE [aicm].[PayloadCache] ADD  CONSTRAINT [DF_PA_LLM_Cache_is_latest]  DEFAULT ((1)) FOR [is_latest]
GO


