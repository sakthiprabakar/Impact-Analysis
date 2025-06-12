
/************************************************************
Procedure    : sp_territory_list
Database     : PLT_AI*
Created      : Tue Apr 25 10:20:35 EDT 2006 - Jonathan Broome
Description  : Lists territory codes and regions, joined
	where possible to list the AE name, too.

sp_territory_list

************************************************************/
Create Procedure sp_territory_list (
	@territory_code	varchar(1000) = '' -- Optional input list to match on
)
AS

	set nocount on

    declare @intCount int
	
	CREATE TABLE #1 (territory int)
	
-- If a List of Territories was submitted to the SP, break it into the temp table.
	IF LEN(@territory_code) > 0
	BEGIN
		/* Check to see if the number parser table exists, create if necessary */
		SELECT @intCount = COUNT(*) FROM syscolumns c INNER JOIN sysobjects o on o.id = c.id AND o.name = 'tblToolsStringParserCounter' AND c.name = 'ID'
		IF @intCount = 0
		BEGIN
			CREATE TABLE tblToolsStringParserCounter (ID int)
	
			DECLARE @i INT
			SELECT  @i = 1
	
			WHILE (@i <= 8000)
			BEGIN
				INSERT INTO tblToolsStringParserCounter SELECT @i
				SELECT @i = @i + 1
			END
		END
	
		/* Insert the territory_code data into a temp table for use later */
		INSERT INTO #1
		SELECT  convert(int,NULLIF(SUBSTRING(',' + @territory_code + ',' , ID ,
			CHARINDEX(',' , ',' + @territory_code + ',' , ID) - ID) , '')) AS territory
		FROM tblToolsStringParserCounter
		WHERE ID <= LEN(',' + @territory_code + ',') AND SUBSTRING(',' + @territory_code + ',' , ID - 1, 1) = ','
		AND CHARINDEX(',' , ',' + @territory_code + ',' , ID) - ID > 0
	END
	ELSE
		INSERT #1 (territory) select convert(int, territory_code) from territory
	
	set nocount off
	
	select distinct
		t.territory_code,
		t.territory_desc,
		dbo.fn_territory_ae(t.territory_code),
		convert(int, t.territory_code)
	from 
		territory t
		inner join #1 tt on convert(int, t.territory_code) = tt.territory
	order by
	convert(int, t.territory_code)
	

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_territory_list] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_territory_list] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_territory_list] TO [EQAI]
    AS [dbo];

