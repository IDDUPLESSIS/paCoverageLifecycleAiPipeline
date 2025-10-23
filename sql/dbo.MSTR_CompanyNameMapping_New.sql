USE [MASTERDATA]
GO

/****** Object:  Table [dbo].[MSTR_CompanyNameMapping_New]    Script Date: 10/23/2025 11:15:47 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [dbo].[MSTR_CompanyNameMapping_New](
	[RowId] [bigint] IDENTITY(1,1) NOT NULL,
	[MasterCompanyId] [bigint] NOT NULL,
	[IsAnchor] [bit] NOT NULL,
	[Status] [varchar](20) NOT NULL,
	[SourceSystem] [varchar](50) NOT NULL,
	[CanonicalCompanyName] [nvarchar](255) NULL,
	[LegalName] [varchar](250) NULL,
	[ParentExternalId] [nvarchar](64) NULL,
	[ParentCompanyName] [varchar](250) NULL,
	[ChildExternalId] [nvarchar](64) NULL,
	[ChildCompanyName] [varchar](250) NULL,
	[IsBillingCompany] [bit] NOT NULL,
	[Email] [varchar](320) NULL,
	[Domain]  AS (case when [Email] IS NOT NULL AND charindex('@',[Email])>(0) then lower(right([Email],len([Email])-charindex('@',[Email])))  end) PERSISTED,
	[AddressLine1] [nvarchar](200) NULL,
	[AddressLine2] [nvarchar](200) NULL,
	[AddressLine3] [nvarchar](200) NULL,
	[City] [nvarchar](100) NULL,
	[StateProvince] [nvarchar](100) NULL,
	[PostalCode] [nvarchar](20) NULL,
	[CountryCode] [nvarchar](60) NULL,
	[AddressRaw] [nvarchar](500) NULL,
	[Latitude] [decimal](9, 6) NULL,
	[Longitude] [decimal](9, 6) NULL,
	[AddressLastVerifiedOn] [datetime2](0) NULL,
	[FQDN_Inferred] [varchar](255) NULL,
	[FQDN_Inferred_Source] [varchar](2048) NULL,
	[FQDN_Inferred_Confidence] [decimal](5, 4) NULL,
	[LegalName_Inferred] [nvarchar](255) NULL,
	[LegalName_Source] [varchar](2048) NULL,
	[EnrichmentRunId] [uniqueidentifier] NULL,
	[LastEnrichedOn] [datetime2](0) NULL,
	[LastEnrichedBy] [sysname] NULL,
	[RelationshipNote] [nvarchar](500) NULL,
	[CreatedBy] [sysname] NOT NULL,
	[CreatedOn] [datetime2](0) NOT NULL,
	[UpdatedBy] [sysname] NULL,
	[UpdatedOn] [datetime2](0) NULL,
	[MatchDomain]  AS (lower(coalesce(case when [Email] IS NOT NULL AND charindex('@',[Email])>(0) then right([Email],len([Email])-charindex('@',[Email]))  end,[FQDN_Inferred]))) PERSISTED,
 CONSTRAINT [PK_MSTR_CompanyNameMapping_New] PRIMARY KEY CLUSTERED 
(
	[RowId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO

ALTER TABLE [dbo].[MSTR_CompanyNameMapping_New] ADD  CONSTRAINT [DF_MSTRCNM_New_IsAnchor]  DEFAULT ((0)) FOR [IsAnchor]
GO

ALTER TABLE [dbo].[MSTR_CompanyNameMapping_New] ADD  CONSTRAINT [DF_MSTRCNM_New_Status]  DEFAULT ('Active') FOR [Status]
GO

ALTER TABLE [dbo].[MSTR_CompanyNameMapping_New] ADD  CONSTRAINT [DF_MSTRCNM_New_IsBillingCompany]  DEFAULT ((0)) FOR [IsBillingCompany]
GO

ALTER TABLE [dbo].[MSTR_CompanyNameMapping_New] ADD  CONSTRAINT [DF_MSTRCNM_New_CreatedBy]  DEFAULT (suser_sname()) FOR [CreatedBy]
GO

ALTER TABLE [dbo].[MSTR_CompanyNameMapping_New] ADD  CONSTRAINT [DF_MSTRCNM_New_CreatedOn]  DEFAULT (sysutcdatetime()) FOR [CreatedOn]
GO

ALTER TABLE [dbo].[MSTR_CompanyNameMapping_New]  WITH CHECK ADD  CONSTRAINT [CK_MSTRCNM_New_AnchorRules] CHECK  (([IsAnchor]=(1) AND [CanonicalCompanyName] IS NOT NULL AND ([ParentExternalId] IS NULL OR ltrim(rtrim([ParentExternalId]))=N'') AND ([ChildExternalId] IS NULL OR ltrim(rtrim([ChildExternalId]))=N'') OR [IsAnchor]=(0) AND ([ParentExternalId] IS NOT NULL AND ltrim(rtrim([ParentExternalId]))<>N'' OR [ChildExternalId] IS NOT NULL AND ltrim(rtrim([ChildExternalId]))<>N'') AND [CanonicalCompanyName] IS NULL))
GO

ALTER TABLE [dbo].[MSTR_CompanyNameMapping_New] CHECK CONSTRAINT [CK_MSTRCNM_New_AnchorRules]
GO


