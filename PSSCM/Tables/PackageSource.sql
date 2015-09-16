create table PackageSource
(
	PackageSourceID int identity(1,1) not null,
	SourceName varchar(32) not null,
	OSInstallRootUNC varchar(256) not null,
	PackageInstallRootUNC varchar(256) null,
	IsDefault bit not null constraint DEF_PackageSource_IsDefault default (0),
	NetDriveMapUsername varchar(50) null,
    NetDriveMapPassword varchar(32) null,
    constraint PK_PackageSource primary key (PackageSourceID)
)
GO