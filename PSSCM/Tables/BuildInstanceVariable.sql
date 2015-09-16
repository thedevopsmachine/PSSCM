create table BuildInstanceVariable
(
	BuildInstanceVariableID int identity(1,1) not null,
	BuildInstanceID int not null,
	VariableName varchar(32) not null,
	TypeName varchar(32) not null,
	Value varchar(max) null,
	constraint PK_BuildInstanceVariable primary key (BuildInstanceVariableID),
	constraint FK_BuildInstanceVariable_BuildInstance foreign key (BuildInstanceID) references BuildInstance(BuildInstanceID) on delete cascade,
	constraint UNQ_BuildInstanceVariable_IDName unique (BuildInstanceID, VariableName)
)
GO