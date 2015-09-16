create table BuildSystemVariable
(
	BuildSystemVariableName varchar(32) not null,
	TypeName varchar(32) not null,
	Value varchar(max) null,
	constraint PK_BuildSystemVariable primary key (BuildSystemVariableName)
)
GO