create table BuildStepInstance
(
	BuildStepInstanceID int identity(1,1) not null,
	BuildInstanceID int not null,
	BuildStepID int not null,
	StartedAtDTO datetimeoffset null,
	FinishedAtDTO datetimeoffset null,
	Status varchar(32) not null constraint DEF_BuildStepInstance_Status default ('Queued'),
	BuildStepOutput varchar(max) null,
	ErrorDetails varchar(max) null,
	constraint PK_BuildStepInstance primary key (BuildStepInstanceID),
	constraint FK_BuildStepInstance_BuildInstance foreign key (BuildInstanceID) references BuildInstance(BuildInstanceID) on delete cascade,
	constraint FK_BuildStepInstance_BuildStep foreign key (BuildStepID) references BuildStep(BuildStepID)
)
GO