CREATE PROCEDURE dbo.AUDIT_prc_DeleteArchitecture
	@RemoveServer bit 
AS
declare @cmptlvl int
-- Delete Audit Tables
IF  EXISTS (SELECT * FROM sysobjects WHERE id = OBJECT_ID(N'[dbo].[AUDIT_LOG_DATA]') AND type in (N'U')) DROP TABLE [dbo].[AUDIT_LOG_DATA]
IF  EXISTS (SELECT * FROM sysobjects WHERE id = OBJECT_ID(N'[dbo].[AUDIT_LOG_TRANSACTIONS]') AND type in (N'U')) DROP TABLE [dbo].[AUDIT_LOG_TRANSACTIONS]
Select @cmptlvl = t1.cmptlevel 
from master.dbo.sysdatabases t1
where t1.[name]=DB_NAME()
IF @cmptlvl > 70
BEGIN
declare 
@fn_sql nvarchar(4000)
set @fn_sql = 'DROP FUNCTION dbo.AUDIT_fn_HexToStr'
IF OBJECTPROPERTY(OBJECT_ID('dbo.AUDIT_fn_HexToStr'), 'IsScalarFunction') IS NOT NULL 
	exec sp_executesql @fn_sql 
set @fn_sql = 'DROP FUNCTION dbo.AUDIT_fn_SqlVariantToString'
IF OBJECTPROPERTY(OBJECT_ID('dbo.AUDIT_fn_SqlVariantToString'), 'IsScalarFunction') IS NOT NULL
	exec sp_executesql @fn_sql
END
-- Delete Audit View
IF OBJECT_ID('dbo.AUDIT_VIEW', 'V') IS NOT NULL DROP VIEW dbo.AUDIT_VIEW
IF OBJECT_ID('dbo.AUDIT_UNDO', 'V') IS NOT NULL DROP VIEW dbo.AUDIT_UNDO
-- Delete Common Reporting functions
if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[AUDIT_prc_ReportingStart]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
drop procedure [dbo].[AUDIT_prc_ReportingStart]
if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[AUDIT_prc_ReportingEnd]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
drop procedure [dbo].[AUDIT_prc_ReportingEnd]
-- Delete Aggregate Report
if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[AUDIT_prc_ReportingStart]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
	drop procedure [dbo].[AUDIT_prc_ReportingStart]
if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[AUDIT_prc_ReportingAddFilterValue]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
	drop procedure [dbo].[AUDIT_prc_ReportingAddFilterValue]
IF OBJECT_ID('dbo.AUDIT_prc_AggregateReport','P') IS NOT NULL DROP PROCEDURE dbo.AUDIT_prc_AggregateReport
-- Delete Standard Report
if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[AUDIT_prc_ReportingStart]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
	drop procedure [dbo].[AUDIT_prc_ReportingStart]
if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[AUDIT_prc_ReportingAddFilterValue]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
	drop procedure [dbo].[AUDIT_prc_ReportingAddFilterValue]
IF OBJECT_ID('dbo.AUDIT_prc_StandardReport','P') IS NOT NULL DROP PROCEDURE dbo.AUDIT_prc_StandardReport
-- Delete Purge Data Sproc
IF OBJECT_ID('dbo.AUDIT_prc_Purge_AUDIT_LOG','P') IS NOT NULL DROP PROCEDURE dbo.AUDIT_prc_Purge_AUDIT_LOG
-- Delete Undo Procedures
IF OBJECT_ID('dbo.AUDIT_prc_AddAuditUndoItem','P') IS NOT NULL DROP PROCEDURE dbo.AUDIT_prc_AddAuditUndoItem
IF OBJECT_ID('dbo.AUDIT_prc_CheckAuditUndo','P') IS NOT NULL DROP PROCEDURE dbo.AUDIT_prc_CheckAuditUndo
IF OBJECT_ID('dbo.AUDIT_prc_CommitUndo','P') IS NOT NULL DROP PROCEDURE dbo.AUDIT_prc_CommitUndo
IF OBJECT_ID('dbo.AUDIT_prc_RollbackUndo','P') IS NOT NULL DROP PROCEDURE dbo.AUDIT_prc_RollbackUndo
IF OBJECT_ID('dbo.AUDIT_prc_UndoGenerateCommand','P') IS NOT NULL DROP PROCEDURE [dbo].[AUDIT_prc_UndoGenerateCommand]
IF OBJECT_ID('dbo.AUDIT_prc_UndoCheck','P') IS NOT NULL DROP PROCEDURE [dbo].[AUDIT_prc_UndoCheck]
IF OBJECT_ID('dbo.AUDIT_prc_GetAuditUndoReport','P') IS NOT NULL DROP PROCEDURE [dbo].[AUDIT_prc_GetAuditUndoReport]
IF OBJECT_ID('dbo.AUDIT_prc_RunUndo','P') IS NOT NULL DROP PROCEDURE [dbo].[AUDIT_prc_RunUndo]
IF OBJECT_ID('dbo.AUDIT_prc_ExecUndo','P') IS NOT NULL DROP PROCEDURE [dbo].[AUDIT_prc_ExecUndo]
IF OBJECT_ID('dbo.AUDIT_prc_CreateAuditUndoReport','P') IS NOT NULL DROP PROCEDURE [dbo].[AUDIT_prc_CreateAuditUndoReport]
IF OBJECT_ID('dbo.AUDIT_prc_UndoAddTriggersCheck','P') IS NOT NULL DROP PROCEDURE [dbo].[AUDIT_prc_UndoAddTriggersCheck]
-- Delete Analyze Procedures
IF OBJECT_ID('dbo.AUDIT_prc_Analyze','P') IS NOT NULL DROP PROCEDURE dbo.AUDIT_prc_Analyze
-- Delete Audit Triggers
DECLARE @trname nvarchar(261)
DECLARE @usname nvarchar(261)
DECLARE @sql nvarchar(4000)
create table #names(username nvarchar(2000), name nvarchar(2000));
IF @cmptlvl < 90
set @sql='insert into #names select u.name, o.name 
from sysobjects o, syscomments c, sysusers u 
  where o.xtype = ''TR'' 
  and o.id = c.id 
  and c.colid = 1 
  and u.uid=o.uid 
  and c.text like ''%<TAG>SQLAUDIT GENERATED - DO NOT REMOVE</TAG>%'''
else
set @sql='insert into #names select u.name, o.name 
from sysobjects o, syscomments c, sys.schemas u 
  where o.xtype = ''TR'' 
  and o.id = c.id 
  and c.colid = 1 
  and u.schema_id=o.uid 
  and c.text like ''%<TAG>SQLAUDIT GENERATED - DO NOT REMOVE</TAG>%'''
EXEC sp_executesql @sql
DECLARE CRTR CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
  SELECT distinct username, name
  FROM #names
OPEN CRTR
FETCH CRTR INTO @usname, @trname
WHILE @@FETCH_STATUS=0
BEGIN
   SET @sql=N'DROP TRIGGER ['+@usname+'].['+@trname+']'
   print @sql
   EXEC sp_executesql @sql
   FETCH CRTR INTO @usname, @trname
END
CLOSE CRTR DEALLOCATE CRTR
drop table #names;
