--DevOps 39094

USE [PLT_AI]
GO

DROP PROCEDURE IF EXISTS [dbo].[sp_who_modified]
GO

/****** Object:  StoredProcedure [dbo].[sp_who_modified]    Script Date: 12/21/2022 9:22:11 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[sp_who_modified] 
	@loginame sysname = NULL
AS

/***************************************************************************************
This Procedure used only in EQAI > Help > System Monitor Screen.This provides info like the current users, sessions and all active processes 
Loads to PLT_AI

01/09/2023	DBS			Created (DevOps 39094 - To include a new column 'user name'.Prior to this SP, sys.sp_who was used)
03/22/2023  AM  DevOps:62909 - Getting data truncate error since cmd was varchar(16), so changed to varchar(50) also added to grant LOGIN_MGMT_SERVICE]
****************************************************************************************/


Create Table #who (
	spid int NULL
,	ecid int NULL
,   status varchar(30) NULL
,   loginame varchar(128) NULL
,   hostname varchar(128) NULL
,   blk char(5) NULL
,   dbname varchar(128) NULL
,   cmd varchar(50) NULL
,   request_id int NULL
)

INSERT INTO #who
EXEC sys.sp_who @loginame

select 
	#who.spid
,	#who.ecid
,   #who.status
,   #who.loginame
,   #who.hostname
,	#who.blk
,	#who.dbname
,   #who.cmd
,   #who.request_id
,   users.user_name as username
from #who
LEFT JOIN users
ON RTRIM(REPLACE(#who.loginame, '(2)', ''))  = users.user_code;

DROP TABLE #who
GO

GRANT EXECUTE
    ON OBJECT::[dbo].[sp_who_modified] TO [EQAI]
    AS [dbo];

GO

GRANT EXECUTE
    ON OBJECT::[dbo].[sp_who_modified] TO [LOGIN_MGMT_SERVICE]
    AS [dbo]; 
GO