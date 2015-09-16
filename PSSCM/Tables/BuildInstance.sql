create table BuildInstance
(
	BuildInstanceID int identity(1,1) not null,
	BuildName varchar(32) not null,
	PackageSourceID int not null,
	ComputerName varchar(64) not null,
	MACAddresses varchar(256) null,--This is OK because the script will prompt if no entry exists
	UnattendXml varchar(max) null,
	UserLocale varchar(32) null,
	DiskCount tinyint not null constraint DEF_BuildInstance_DiskCount default (1),
	DSCConfigurationID uniqueidentifier null,
	DSCPullServerURI varchar(512) null,
	DSCScript varchar(max) null,
	DSCConfigurationData varchar(max) null,
	RequestedBy varchar(32) not null,
	Status varchar(32) not null constraint DEF_BuildInstance_Status default ('Requested'),
	RequestedAtDTO datetimeoffset not null constraint DEF_BuildInstance_RequestedAtDTO default (sysdatetimeoffset()),
	StartedAtDTO datetimeoffset null,
	FinishedAtDTO datetimeoffset null,
	constraint PK_BuildInstance primary key (BuildInstanceID),
	constraint FK_BuildInstance_Build foreign key (BuildName) references Build(BuildName),
	constraint FK_BuildInstance_PackageSource foreign key (PackageSourceID) references PackageSource(PackageSourceID)
)
GO