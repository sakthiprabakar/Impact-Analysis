
/********************
sp_reports_schedule_master:

Returns the data for Schedules.

LOAD TO PLT_AI* on NTSQL1

sp_reports_schedule_master 0, ' 2|21, 3|1, 12|0, 14|0, 14|4, 14|6, 14|12, 15|1, 15|2, 21|0, 22|0, 23|0, 24|0', '2492', '', '', '', -1
sp_reports_schedule_master 0, ' 2|21, 3|1, 12|0, 14|0, 14|4, 14|6, 14|12, 15|1, 15|2, 21|0, 22|0, 23|0, 24|0', '2492', '', '12/1/2004', '12/31/2004', -1
sp_reports_schedule_master 0, ' 2|21, 3|1, 12|0, 14|0, 14|4, 14|6, 14|12, 15|1, 15|2, 21|0, 22|0, 23|0, 24|0', '888888', '', '4/1/2003', '5/1/2003', -1
sp_reports_schedule_master 0, ' 2|21, 3|1, 12|0, 14|0, 14|4, 14|6, 14|12, 15|1, 15|2, 21|0, 22|0, 23|0, 24|0', '70', '', '', '', -1
sp_reports_schedule_master 0, ' 2|21', '70', '', '6/1/2006', '6/30/2006', -1
sp_reports_schedule_master 0, ' 2|21, 3|1, 12|0, 14|0, 14|4, 14|6, 14|12, 15|1, 15|2, 21|0, 22|0, 23|0, 24|0', '5252', '', '', '', 536 - works with contact
sp_reports_schedule_master 0, ' 2|21, 3|1, 12|0, 14|0, 14|4, 14|6, 14|12, 15|1, 15|2, 21|0, 22|0, 23|0, 24|0', '5252', '', '', '', 5361 - won't work, wrong contact

05/26/2005 JPB Created
08/08/2006 JPB	Rewrote it to be aware of Profiles changes
08/15/2006 JPB Rewrote for speed
**********************/

CREATE PROCEDURE sp_reports_schedule_master
	@debug					int, 			-- 0 or 1 for no debug/debug mode
	@database_list			varchar(8000),	-- Comma Separated Company List
	@customer_id_list		varchar(8000),	-- Comma Separated Customer ID List -  what customers to include
	@confirmation_id			varchar(8000),	-- Confirmation ID List
	@start_date				varchar(20),	-- Start Date
	@end_date				varchar(20),	-- End Date
	@contact_id				int = 0			-- Contact ID or -1 for Associates.
AS

set nocount on


DECLARE @intcount int, @sql varchar(8000), @db_name varchar(60)

IF @customer_id_list IS NULL OR LEN(@customer_id_list) = 0
BEGIN
	SET @customer_id_list = '-1'
	IF @debug >= 1 PRINT '@customer_id_list:  ' + @customer_id_list
END

-- Create a temp table to hold the List of Customers submitted to the SP	
CREATE TABLE #1 (IDList int)

-- If a List of Customers was submitted to the SP, break it into the temp table.
IF LEN(@customer_id_list) > 0
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

	/* Insert the customer_id_list data into a temp table for use later */
	INSERT INTO #1
	SELECT  CONVERT(int, NULLIF(SUBSTRING(',' + @customer_id_list + ',' , ID ,
		CHARINDEX(',' , ',' + @customer_id_list + ',' , ID) - ID) , '')) AS IDList
	FROM tblToolsStringParserCounter
	WHERE ID <= LEN(',' + @customer_id_list + ',') AND SUBSTRING(',' + @customer_id_list + ',' , ID - 1, 1) = ','
	AND CHARINDEX(',' , ',' + @customer_id_list + ',' , ID) - ID > 0
	
	set @customer_id_list = '-1'

	if @contact_id <> -1	
		-- need to convert #1 to a string
		SELECT @customer_id_list = COALESCE(@customer_id_list + ', ', '') + CAST(IDList AS varchar(10))
		FROM #1 inner join contactxref x on #1.IDList = x.customer_id
		where x.contact_id = @contact_id and x.status = 'A' and x.web_access = 'A'
		ORDER BY IDList
	else
		-- need to convert #1 to a string
		SELECT @customer_id_list = COALESCE(@customer_id_list + ', ', '') + CAST(IDList AS varchar(10))
		FROM #1
		ORDER BY IDList
		
	if @customer_id_list = '-1, -1' set @customer_id_list = ''
		
END

create table #results (
	profit_ctr_id					int,
	confirmation_id					int,
	approved_confirmation_id		varchar(20),
	time_scheduled					datetime,
	quantity						float,
	approval_code					varchar(15),
	contact							varchar(40),
	contact_company					varchar(40),
	contact_fax						varchar(10),
	load_type						char(1),
	epa_id							varchar(12),
	generator_name					varchar(40),
	approval_desc					varchar(50),
	contact_phone					varchar(20),
	OTS_flag						varchar(1), 
    company_id						int
)

-- Create a temp table to hold the database list to query
CREATE TABLE #tmp_database (
	database_name varchar(60),
	company_id int,
	profit_ctr_id int,
	process_flag int
)
EXEC sp_reports_list_database @debug, @database_list

while (select count(*) from #tmp_database where process_flag = 0) > 0
begin
	set rowcount 1
	select @db_name = database_name from #tmp_database where process_flag = 0
	set rowcount 0
	
	set @sql = 'insert #results execute(''' + @db_name + 'sp_reports_schedule_slave ''''' + @customer_id_list + ''''', ''''' + @confirmation_id + ''''', ''''' + @start_date + ''''', ''''' + @end_date + ''''', ' + convert(varchar(20), @contact_id) + ' '')'
	if @debug > 0 select @sql
	exec(@sql)
	
	update #tmp_database set process_flag = 1 where database_name = @db_name
end

select * from #results ORDER BY company_id, profit_ctr_id, time_scheduled


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_reports_schedule_master] TO PUBLIC
    AS [dbo];

