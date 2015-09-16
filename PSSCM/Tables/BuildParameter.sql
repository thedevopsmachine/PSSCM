create table BuildParameter
(
	BuildParameterID int identity(1,1) not null,
	BuildName varchar(32) not null,
	ParameterName varchar(32) not null,
	Mandatory bit not null,
	DotNetDataType varchar(32) not null,
	ValidationType varchar(16) not null,
	ValidationValue varchar(max) null,
	DefaultValue varchar(max) null,
	constraint PK_BuildParameter primary key (BuildParameterID),
	constraint FK_BuildParameter_Build foreign key (BuildName) references Build(BuildName) on delete cascade
)
GO