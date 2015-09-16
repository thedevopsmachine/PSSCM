﻿/*
Deployment script for PSSCMDB

This code was generated by a tool.
Changes to this file may cause incorrect behavior and will be lost if
the code is regenerated.
*/

GO
SET ANSI_NULLS, ANSI_PADDING, ANSI_WARNINGS, ARITHABORT, CONCAT_NULL_YIELDS_NULL, QUOTED_IDENTIFIER ON;

SET NUMERIC_ROUNDABORT OFF;


GO
:setvar DatabaseName "PSSCMDB"
:setvar DefaultFilePrefix "PSSCMDB"
:setvar DefaultDataPath "C:\Program Files\Microsoft SQL Server\MSSQL12.MSSQLSERVER\MSSQL\DATA\"
:setvar DefaultLogPath "C:\Program Files\Microsoft SQL Server\MSSQL12.MSSQLSERVER\MSSQL\DATA\"

GO
:on error exit
GO
/*
Detect SQLCMD mode and disable script execution if SQLCMD mode is not supported.
To re-enable the script after enabling SQLCMD mode, execute the following:
SET NOEXEC OFF; 
*/
:setvar __IsSqlCmdEnabled "True"
GO
IF N'$(__IsSqlCmdEnabled)' NOT LIKE N'True'
    BEGIN
        PRINT N'SQLCMD mode must be enabled to successfully execute this script.';
        SET NOEXEC ON;
    END


GO
USE [master];


GO

IF (DB_ID(N'$(DatabaseName)') IS NOT NULL) 
BEGIN
    ALTER DATABASE [$(DatabaseName)]
    SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE [$(DatabaseName)];
END

GO
PRINT N'Creating $(DatabaseName)...'
GO
CREATE DATABASE [$(DatabaseName)]
    ON 
    PRIMARY(NAME = [$(DatabaseName)], FILENAME = N'$(DefaultDataPath)$(DefaultFilePrefix)_Primary.mdf')
    LOG ON (NAME = [$(DatabaseName)_log], FILENAME = N'$(DefaultLogPath)$(DefaultFilePrefix)_Primary.ldf') COLLATE SQL_Latin1_General_CP1_CI_AS
GO
IF EXISTS (SELECT 1
           FROM   [master].[dbo].[sysdatabases]
           WHERE  [name] = N'$(DatabaseName)')
    BEGIN
        ALTER DATABASE [$(DatabaseName)]
            SET ANSI_NULLS ON,
                ANSI_PADDING ON,
                ANSI_WARNINGS ON,
                ARITHABORT ON,
                CONCAT_NULL_YIELDS_NULL ON,
                NUMERIC_ROUNDABORT OFF,
                QUOTED_IDENTIFIER ON,
                ANSI_NULL_DEFAULT ON,
                CURSOR_DEFAULT LOCAL,
                RECOVERY FULL,
                CURSOR_CLOSE_ON_COMMIT OFF,
                AUTO_CREATE_STATISTICS ON,
                AUTO_SHRINK OFF,
                AUTO_UPDATE_STATISTICS ON,
                RECURSIVE_TRIGGERS OFF 
            WITH ROLLBACK IMMEDIATE;
        ALTER DATABASE [$(DatabaseName)]
            SET AUTO_CLOSE OFF 
            WITH ROLLBACK IMMEDIATE;
    END


GO
IF EXISTS (SELECT 1
           FROM   [master].[dbo].[sysdatabases]
           WHERE  [name] = N'$(DatabaseName)')
    BEGIN
        ALTER DATABASE [$(DatabaseName)]
            SET ALLOW_SNAPSHOT_ISOLATION OFF;
    END


GO
IF EXISTS (SELECT 1
           FROM   [master].[dbo].[sysdatabases]
           WHERE  [name] = N'$(DatabaseName)')
    BEGIN
        ALTER DATABASE [$(DatabaseName)]
            SET READ_COMMITTED_SNAPSHOT OFF 
            WITH ROLLBACK IMMEDIATE;
    END


GO
IF EXISTS (SELECT 1
           FROM   [master].[dbo].[sysdatabases]
           WHERE  [name] = N'$(DatabaseName)')
    BEGIN
        ALTER DATABASE [$(DatabaseName)]
            SET AUTO_UPDATE_STATISTICS_ASYNC OFF,
                PAGE_VERIFY NONE,
                DATE_CORRELATION_OPTIMIZATION OFF,
                DISABLE_BROKER,
                PARAMETERIZATION SIMPLE,
                SUPPLEMENTAL_LOGGING OFF 
            WITH ROLLBACK IMMEDIATE;
    END


GO
IF IS_SRVROLEMEMBER(N'sysadmin') = 1
    BEGIN
        IF EXISTS (SELECT 1
                   FROM   [master].[dbo].[sysdatabases]
                   WHERE  [name] = N'$(DatabaseName)')
            BEGIN
                EXECUTE sp_executesql N'ALTER DATABASE [$(DatabaseName)]
    SET TRUSTWORTHY OFF,
        DB_CHAINING OFF 
    WITH ROLLBACK IMMEDIATE';
            END
    END
ELSE
    BEGIN
        PRINT N'The database settings cannot be modified. You must be a SysAdmin to apply these settings.';
    END


GO
IF IS_SRVROLEMEMBER(N'sysadmin') = 1
    BEGIN
        IF EXISTS (SELECT 1
                   FROM   [master].[dbo].[sysdatabases]
                   WHERE  [name] = N'$(DatabaseName)')
            BEGIN
                EXECUTE sp_executesql N'ALTER DATABASE [$(DatabaseName)]
    SET HONOR_BROKER_PRIORITY OFF 
    WITH ROLLBACK IMMEDIATE';
            END
    END
ELSE
    BEGIN
        PRINT N'The database settings cannot be modified. You must be a SysAdmin to apply these settings.';
    END


GO
ALTER DATABASE [$(DatabaseName)]
    SET TARGET_RECOVERY_TIME = 0 SECONDS 
    WITH ROLLBACK IMMEDIATE;


GO
IF EXISTS (SELECT 1
           FROM   [master].[dbo].[sysdatabases]
           WHERE  [name] = N'$(DatabaseName)')
    BEGIN
        ALTER DATABASE [$(DatabaseName)]
            SET FILESTREAM(NON_TRANSACTED_ACCESS = OFF),
                CONTAINMENT = NONE 
            WITH ROLLBACK IMMEDIATE;
    END


GO
IF EXISTS (SELECT 1
           FROM   [master].[dbo].[sysdatabases]
           WHERE  [name] = N'$(DatabaseName)')
    BEGIN
        ALTER DATABASE [$(DatabaseName)]
            SET AUTO_CREATE_STATISTICS ON(INCREMENTAL = OFF),
                MEMORY_OPTIMIZED_ELEVATE_TO_SNAPSHOT = OFF,
                DELAYED_DURABILITY = DISABLED 
            WITH ROLLBACK IMMEDIATE;
    END


GO
USE [$(DatabaseName)];


GO
IF fulltextserviceproperty(N'IsFulltextInstalled') = 1
    EXECUTE sp_fulltext_database 'enable';


GO
PRINT N'Creating [dbo].[Build]...';


GO
CREATE TABLE [dbo].[Build] (
    [BuildName]         VARCHAR (32)  NOT NULL,
    [Version]           VARCHAR (32)  NOT NULL,
    [OperatingSystemID] TINYINT       NOT NULL,
    [UnattendXml]       VARCHAR (MAX) NOT NULL,
    [ImageIndex]        TINYINT       NOT NULL,
    CONSTRAINT [PK_Build] PRIMARY KEY CLUSTERED ([BuildName] ASC)
);


GO
PRINT N'Creating [dbo].[BuildInstance]...';


GO
CREATE TABLE [dbo].[BuildInstance] (
    [BuildInstanceID]      INT                IDENTITY (1, 1) NOT NULL,
    [BuildName]            VARCHAR (32)       NOT NULL,
    [PackageSourceID]      INT                NOT NULL,
    [ComputerName]         VARCHAR (64)       NOT NULL,
    [MACAddresses]         VARCHAR (256)      NULL,
    [UnattendXml]          VARCHAR (MAX)      NULL,
    [UserLocale]           VARCHAR (32)       NULL,
    [DiskCount]            TINYINT            NOT NULL,
    [DSCConfigurationID]   UNIQUEIDENTIFIER   NULL,
    [DSCPullServerURI]     VARCHAR (512)      NULL,
    [DSCScript]            VARCHAR (MAX)      NULL,
    [DSCConfigurationData] VARCHAR (MAX)      NULL,
    [RequestedBy]          VARCHAR (32)       NOT NULL,
    [Status]               VARCHAR (32)       NOT NULL,
    [RequestedAtDTO]       DATETIMEOFFSET (7) NOT NULL,
    [StartedAtDTO]         DATETIMEOFFSET (7) NULL,
    [FinishedAtDTO]        DATETIMEOFFSET (7) NULL,
    CONSTRAINT [PK_BuildInstance] PRIMARY KEY CLUSTERED ([BuildInstanceID] ASC)
);


GO
PRINT N'Creating [dbo].[BuildInstanceVariable]...';


GO
CREATE TABLE [dbo].[BuildInstanceVariable] (
    [BuildInstanceVariableID] INT           IDENTITY (1, 1) NOT NULL,
    [BuildInstanceID]         INT           NOT NULL,
    [VariableName]            VARCHAR (32)  NOT NULL,
    [TypeName]                VARCHAR (32)  NOT NULL,
    [Value]                   VARCHAR (MAX) NULL,
    CONSTRAINT [PK_BuildInstanceVariable] PRIMARY KEY CLUSTERED ([BuildInstanceVariableID] ASC),
    CONSTRAINT [UNQ_BuildInstanceVariable_IDName] UNIQUE NONCLUSTERED ([BuildInstanceID] ASC, [VariableName] ASC)
);


GO
PRINT N'Creating [dbo].[BuildParameter]...';


GO
CREATE TABLE [dbo].[BuildParameter] (
    [BuildParameterID] INT           IDENTITY (1, 1) NOT NULL,
    [BuildName]        VARCHAR (32)  NOT NULL,
    [ParameterName]    VARCHAR (32)  NOT NULL,
    [Mandatory]        BIT           NOT NULL,
    [DotNetDataType]   VARCHAR (32)  NOT NULL,
    [ValidationType]   VARCHAR (16)  NOT NULL,
    [ValidationValue]  VARCHAR (MAX) NULL,
    [DefaultValue]     VARCHAR (MAX) NULL,
    CONSTRAINT [PK_BuildParameter] PRIMARY KEY CLUSTERED ([BuildParameterID] ASC)
);


GO
PRINT N'Creating [dbo].[BuildStep]...';


GO
CREATE TABLE [dbo].[BuildStep] (
    [BuildStepID]     INT           IDENTITY (1, 1) NOT NULL,
    [BuildName]       VARCHAR (32)  NOT NULL,
    [StepName]        VARCHAR (32)  NOT NULL,
    [ExecutionOrder]  TINYINT       NOT NULL,
    [ScriptText]      VARCHAR (MAX) NOT NULL,
    [ExecuteIfScript] VARCHAR (MAX) NULL,
    [BuildStage]      VARCHAR (7)   NOT NULL,
    [IsEnabled]       BIT           NOT NULL,
    [ErrorAction]     VARCHAR (16)  NOT NULL,
    CONSTRAINT [PK_BuildStep] PRIMARY KEY CLUSTERED ([BuildStepID] ASC)
);


GO
PRINT N'Creating [dbo].[BuildStepInstance]...';


GO
CREATE TABLE [dbo].[BuildStepInstance] (
    [BuildStepInstanceID] INT                IDENTITY (1, 1) NOT NULL,
    [BuildInstanceID]     INT                NOT NULL,
    [BuildStepID]         INT                NOT NULL,
    [StartedAtDTO]        DATETIMEOFFSET (7) NULL,
    [FinishedAtDTO]       DATETIMEOFFSET (7) NULL,
    [Status]              VARCHAR (32)       NOT NULL,
    [BuildStepOutput]     VARCHAR (MAX)      NULL,
    [ErrorDetails]        VARCHAR (MAX)      NULL,
    CONSTRAINT [PK_BuildStepInstance] PRIMARY KEY CLUSTERED ([BuildStepInstanceID] ASC)
);


GO
PRINT N'Creating [dbo].[BuildSystemVariable]...';


GO
CREATE TABLE [dbo].[BuildSystemVariable] (
    [BuildSystemVariableName] VARCHAR (32)  NOT NULL,
    [TypeName]                VARCHAR (32)  NOT NULL,
    [Value]                   VARCHAR (MAX) NULL,
    CONSTRAINT [PK_BuildSystemVariable] PRIMARY KEY CLUSTERED ([BuildSystemVariableName] ASC)
);


GO
PRINT N'Creating [dbo].[OperatingSystem]...';


GO
CREATE TABLE [dbo].[OperatingSystem] (
    [OperatingSystemID] TINYINT      IDENTITY (1, 1) NOT NULL,
    [OSName]            VARCHAR (32) NOT NULL,
    CONSTRAINT [PK_OperatingSystem] PRIMARY KEY CLUSTERED ([OperatingSystemID] ASC)
);


GO
PRINT N'Creating [dbo].[PackageSource]...';


GO
CREATE TABLE [dbo].[PackageSource] (
    [PackageSourceID]       INT           IDENTITY (1, 1) NOT NULL,
    [SourceName]            VARCHAR (32)  NOT NULL,
    [OSInstallRootUNC]      VARCHAR (256) NOT NULL,
    [PackageInstallRootUNC] VARCHAR (256) NULL,
    [IsDefault]             BIT           NOT NULL,
    CONSTRAINT [PK_PackageSource] PRIMARY KEY CLUSTERED ([PackageSourceID] ASC)
);


GO
PRINT N'Creating [dbo].[DEF_BuildInstance_DiskCount]...';


GO
ALTER TABLE [dbo].[BuildInstance]
    ADD CONSTRAINT [DEF_BuildInstance_DiskCount] DEFAULT (1) FOR [DiskCount];


GO
PRINT N'Creating [dbo].[DEF_BuildInstance_Status]...';


GO
ALTER TABLE [dbo].[BuildInstance]
    ADD CONSTRAINT [DEF_BuildInstance_Status] DEFAULT ('Requested') FOR [Status];


GO
PRINT N'Creating [dbo].[DEF_BuildInstance_RequestedAtDTO]...';


GO
ALTER TABLE [dbo].[BuildInstance]
    ADD CONSTRAINT [DEF_BuildInstance_RequestedAtDTO] DEFAULT (sysdatetimeoffset()) FOR [RequestedAtDTO];


GO
PRINT N'Creating [dbo].[DEF_BuildStep_IsEnabled]...';


GO
ALTER TABLE [dbo].[BuildStep]
    ADD CONSTRAINT [DEF_BuildStep_IsEnabled] DEFAULT (1) FOR [IsEnabled];


GO
PRINT N'Creating [dbo].[DEF_BuildStep_ErrorAction]...';


GO
ALTER TABLE [dbo].[BuildStep]
    ADD CONSTRAINT [DEF_BuildStep_ErrorAction] DEFAULT ('Stop') FOR [ErrorAction];


GO
PRINT N'Creating [dbo].[DEF_BuildStepInstance_Status]...';


GO
ALTER TABLE [dbo].[BuildStepInstance]
    ADD CONSTRAINT [DEF_BuildStepInstance_Status] DEFAULT ('Queued') FOR [Status];


GO
PRINT N'Creating [dbo].[DEF_PackageSource_IsDefault]...';


GO
ALTER TABLE [dbo].[PackageSource]
    ADD CONSTRAINT [DEF_PackageSource_IsDefault] DEFAULT (0) FOR [IsDefault];


GO
PRINT N'Creating [dbo].[FK_Build_OperatingSystem]...';


GO
ALTER TABLE [dbo].[Build]
    ADD CONSTRAINT [FK_Build_OperatingSystem] FOREIGN KEY ([OperatingSystemID]) REFERENCES [dbo].[OperatingSystem] ([OperatingSystemID]);


GO
PRINT N'Creating [dbo].[FK_BuildInstance_Build]...';


GO
ALTER TABLE [dbo].[BuildInstance]
    ADD CONSTRAINT [FK_BuildInstance_Build] FOREIGN KEY ([BuildName]) REFERENCES [dbo].[Build] ([BuildName]);


GO
PRINT N'Creating [dbo].[FK_BuildInstance_PackageSource]...';


GO
ALTER TABLE [dbo].[BuildInstance]
    ADD CONSTRAINT [FK_BuildInstance_PackageSource] FOREIGN KEY ([PackageSourceID]) REFERENCES [dbo].[PackageSource] ([PackageSourceID]);


GO
PRINT N'Creating [dbo].[FK_BuildInstanceVariable_BuildInstance]...';


GO
ALTER TABLE [dbo].[BuildInstanceVariable]
    ADD CONSTRAINT [FK_BuildInstanceVariable_BuildInstance] FOREIGN KEY ([BuildInstanceID]) REFERENCES [dbo].[BuildInstance] ([BuildInstanceID]) ON DELETE CASCADE;


GO
PRINT N'Creating [dbo].[FK_BuildParameter_Build]...';


GO
ALTER TABLE [dbo].[BuildParameter]
    ADD CONSTRAINT [FK_BuildParameter_Build] FOREIGN KEY ([BuildName]) REFERENCES [dbo].[Build] ([BuildName]) ON DELETE CASCADE;


GO
PRINT N'Creating [dbo].[FK_BuildStep_Build]...';


GO
ALTER TABLE [dbo].[BuildStep]
    ADD CONSTRAINT [FK_BuildStep_Build] FOREIGN KEY ([BuildName]) REFERENCES [dbo].[Build] ([BuildName]) ON DELETE CASCADE;


GO
PRINT N'Creating [dbo].[FK_BuildStepInstance_BuildInstance]...';


GO
ALTER TABLE [dbo].[BuildStepInstance]
    ADD CONSTRAINT [FK_BuildStepInstance_BuildInstance] FOREIGN KEY ([BuildInstanceID]) REFERENCES [dbo].[BuildInstance] ([BuildInstanceID]) ON DELETE CASCADE;


GO
PRINT N'Creating [dbo].[FK_BuildStepInstance_BuildStep]...';


GO
ALTER TABLE [dbo].[BuildStepInstance]
    ADD CONSTRAINT [FK_BuildStepInstance_BuildStep] FOREIGN KEY ([BuildStepID]) REFERENCES [dbo].[BuildStep] ([BuildStepID]);


GO
DECLARE @VarDecimalSupported AS BIT;

SELECT @VarDecimalSupported = 0;

IF ((ServerProperty(N'EngineEdition') = 3)
    AND (((@@microsoftversion / power(2, 24) = 9)
          AND (@@microsoftversion & 0xffff >= 3024))
         OR ((@@microsoftversion / power(2, 24) = 10)
             AND (@@microsoftversion & 0xffff >= 1600))))
    SELECT @VarDecimalSupported = 1;

IF (@VarDecimalSupported > 0)
    BEGIN
        EXECUTE sp_db_vardecimal_storage_format N'$(DatabaseName)', 'ON';
    END


GO
PRINT N'Update complete.';


GO
