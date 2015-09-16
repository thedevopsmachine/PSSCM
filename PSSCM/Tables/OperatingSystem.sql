create table OperatingSystem
(
	OperatingSystemID tinyint identity(1,1) not null,
	OSName varchar(32) not null,
	constraint PK_OperatingSystem primary key (OperatingSystemID)
)
GO