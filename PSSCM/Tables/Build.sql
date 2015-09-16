create table Build
(
	BuildName varchar(32) not null,
	Version varchar(32) not null,
	OperatingSystemID tinyint not null,
	UnattendXmlTemplate varchar(max) not null,
	ImageIndex tinyint not null,
	constraint PK_Build primary key (BuildName),
	constraint FK_Build_OperatingSystem foreign key (OperatingSystemID) references OperatingSystem(OperatingSystemID)
)
GO