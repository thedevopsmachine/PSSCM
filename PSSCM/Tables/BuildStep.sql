create table BuildStep
(
	BuildStepID int identity(1,1) not null,
	BuildName varchar(32) not null,
	StepName varchar(32) not null,
	ExecutionOrder tinyint not null,
	ScriptText varchar(max) not null,
	ExecuteIfScript varchar(max) null,
	BuildStage varchar(7) not null,
	IsEnabled bit not null constraint DEF_BuildStep_IsEnabled default (1),
	ErrorAction varchar(16) not null constraint DEF_BuildStep_ErrorAction default ('Stop'),
	constraint PK_BuildStep primary key (BuildStepID),
	constraint FK_BuildStep_Build foreign key (BuildName) references Build(BuildName) on delete cascade
)
GO