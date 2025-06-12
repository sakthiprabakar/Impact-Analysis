
CREATE PROCEDURE sp_LongQuery_insert

	@conn_string 	varchar(255),		-- required: db connection string (minus password!)
	@query 			text,				-- required: Query Text
	@seconds		float,				-- required: Number of seconds ran for
	@resultcount	bigint,				-- required: Number of results from query
	@Added_by 		varchar(60)			-- required: Who ran it
AS
/* *********************************************
sp_LongQuery_insert:
Inserts a long query report into LongQuery

LOAD TO plt_ai*

08/02/2007 JPB Created
08/22/2007 JPB Modified: LongQuery table now lives in EQ_IT db.
10/01/2007 WAC Removed references to NTSQL

sp_LongQuery_insert 'select ''some long query'' ', 'Provider=sqloledb;Connect Timeout=3;Data Source=255.255.255.255;User Id=SOMEUSER;Password=[not included];Initial Catalog=PLT_21_AI_TEST', 54, 0, 'JONATHAN'
********************************************* */

SET NOCOUNT ON
SET ANSI_WARNINGS OFF

INSERT EQ_IT..LONGQUERY (QUERY, CONN_STRING, SECONDS, RESULTCOUNT, ADDED_BY, DATE_ADDED)
VALUES (@query, @conn_string, @seconds, @resultcount, @added_by, GETDATE())
	
SET NOCOUNT OFF

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_LongQuery_insert] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_LongQuery_insert] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_LongQuery_insert] TO [EQAI]
    AS [dbo];

