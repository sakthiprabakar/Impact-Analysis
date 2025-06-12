
CREATE PROCEDURE dbo.sp_dbcc_inputbuffer
	@spid		int,
	@debug		int

AS
/***************************************************************************************************
LOAD TO PLT_AI
Filename:	L:\Apps\SQL\EQAI\PLT_AI\sp_dbcc_inputbuffer
PB Object(s):	d_dbcc_inputbuffer
		w_popup_sp_who

06/19/2006 JDB	Created

sp_dbcc_inputbuffer 319, 0
dbcc inputbuffer (319)

sp_who2
***************************************************************************************************/
DECLARE @execute_sql	varchar(255)

SET @execute_sql = 'DBCC INPUTBUFFER (' + CONVERT(varchar(10), @spid) + ')'

IF @debug = 1
	PRINT @execute_sql

EXECUTE (@execute_sql)
-- SELECT SPACE(30) AS EventType, 0 AS Parameters, SPACE(255) AS EventInfo


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_dbcc_inputbuffer] TO [EQAI]
    AS [dbo];

