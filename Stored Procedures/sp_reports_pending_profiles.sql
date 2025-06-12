
Create Procedure sp_reports_pending_profiles (
	@debug				int, 			-- 0 or 1 for no debug/debug mode
	@show_all			char(1) = 'F',	-- Show all forms? (Only works for Associates - @contact_id = '')
	@customer_id_list	varchar(8000),	-- Comma Separated Customer ID List - what customers to include
	@generator_id_list	varchar(8000),	-- Comma Separated Generator ID List - what generators to include
	@generator_name		varchar(60),		-- Generator Name
	@modified_by			varchar(60),		-- Modified By
	@form_id_list		varchar(60),		-- Comma Separated Form ID List
	@tracking_id_list	varchar(60),		-- Comma Separated Tracking ID List
	@waste_common_name	varchar(60),		-- Waste Common Name
	@start_date			varchar(20),		-- Start Date
	@end_date			varchar(20),		-- End Date
	@contact_id			varchar(100)		-- Contact_id
)
/************************************************************
Procedure    : sp_reports_pending_profiles
Database     : plt_ai* 
Created      : Wed Jan 10 09:48:46 EST 2007 - Jonathan Broome
Filename     : L:\Apps\SQL\Develop\Jonathan\Reports\sp_reports_pending_profiles.sqlaa
Description  : Returns pending profile (WCR) information

sp_reports_pending_profiles 0, '', '888888', '', '', '', '', '', '', '', '', ''
sp_reports_pending_profiles 0, 'T', '', '', '', '', '', '', '', '', '', ''
sp_reports_pending_profiles 0, '', '', '', '', '', '', '', '', '', '', '10913'
sp_reports_pending_profiles 0, '', '', '', '', '', '', '', '', '', '', '10914'
sp_reports_pending_profiles 0, '', '', '', '', '', '', '', '', '', '', ''
sp_reports_pending_profiles 0, '', '', '38452', '', '', '', '', '', '', '', '' 
sp_reports_pending_profiles 0, '', '', '38452', '', '', '', '', '', '', '', '10913' 
sp_reports_pending_profiles 0, '', '', '', 'ABC', '', '', '', '', '', '', '10913' 
sp_reports_pending_profiles 0, '', '', '', '', 'JONATHAN', '', '', '', '', '', '10913' 
sp_reports_pending_profiles 0, '', '', '', '', 'JONATHAN', '', '', '', '', '', '' 
sp_reports_pending_profiles 0, '', '', '', '', '', '21456, 21454, 21455, ', '', '', '', '', '' 
sp_reports_pending_profiles 0, '', '', '', '', '', '', '6061, 2342', '', '', '', ''
sp_reports_pending_profiles 0, '', '', '', '', '', '', '', 'Paint', '', '', ''
sp_reports_pending_profiles 1, '', '', '', '', '', '', '', '', '3/1/2005', '6/1/2005', '10913'


10/03/2007 JPB  Modified to remove NTSQL* references

************************************************************/

AS

SET NOCOUNT ON
SET ANSI_WARNINGS OFF

DECLARE	@execute_sql		varchar(8000),
	@execute_order 			varchar(8000),
	@generator_login_list	varchar(8000),
	@intCount 				int,
	@count_cust				int,
	@genCount				int,
	@custCount				int,
	@where					varchar(8000),
	@starttime				datetime

select @starttime = getdate(), @execute_sql = '', @execute_order = '', @where = ''

IF @contact_id IS NULL SET @contact_id = ''
IF @generator_id_list IS NULL SET @generator_id_list = ''

IF @customer_id_list IS NULL OR LEN(@customer_id_list) = 0
BEGIN
	SET @customer_id_list = '-1'
	IF @debug = 1 PRINT '@customer_id_list:  ' + @customer_id_list
END

IF @generator_id_list IS NULL OR LEN(@generator_id_list) = 0
BEGIN
	SET @generator_id_list = '-1'
	IF @debug = 1 PRINT '@generator_id_list:  ' + @generator_id_list
END

if @debug >= 1 print 'figure out if this user has inherent access to customers'
-- figure out if this user has inherent access to customers
    SELECT @custCount = 0, @genCount = 0
	create table #customer (customer_id int)
	create table #generator(generator_id int)
	create clustered index idx_tmp on #customer(customer_id)
	create clustered index idx_tmp on #generator(generator_id)
	IF LEN(@contact_id) > 0
	BEGIN
		insert #customer (customer_id)
		select customer_id from ContactXRef cxr
			Where cxr.contact_id = convert(int, @contact_id)
			AND cxr.customer_id is not null
			AND cxr.type = 'C' AND cxr.status = 'A' and cxr.web_access = 'A'
			
		insert #generator (generator_id)
		select generator_id from ContactXRef cxr
			Where cxr.contact_id = convert(int, @contact_id)
			AND cxr.generator_id is not null
			AND cxr.type = 'G' AND cxr.status = 'A' and cxr.web_access = 'A' 
		union
		Select cg.generator_id from CustomerGenerator cg, ContactXRef cxr, Customer c
			Where cxr.contact_id = convert(int, @contact_id)
			AND cg.customer_id = cxr.customer_id
			AND cxr.customer_id is not null
			AND cxr.type = 'C'
			AND cxr.status = 'A'
			AND cxr.web_access = 'A'
			AND cg.customer_id = c.customer_id
			AND c.generator_flag = 'T'
	END
	ELSE -- For Associates:
	BEGIN
		INSERT INTO #customer
		SELECT convert(int, SUBSTRING(',' + @customer_id_list + ',' , ID ,
			CHARINDEX(',' , ',' + @customer_id_list + ',' , ID) - ID)) AS customer_id
		FROM tblToolsStringParserCounter
		WHERE ID <= LEN(',' + @customer_id_list + ',') AND SUBSTRING(',' + @customer_id_list + ',' , ID - 1, 1) = ','
		AND CHARINDEX(',' , ',' + @customer_id_list + ',' , ID) - ID > 0
		DELETE FROM #customer where customer_id is null
		IF @debug >= 1 PRINT 'SELECT FROM #customer'
		IF @debug >= 1 SELECT * FROM #customer

		INSERT INTO #generator
		SELECT convert(int, SUBSTRING(',' + @generator_id_list + ',' , ID ,
			CHARINDEX(',' , ',' + @generator_id_list + ',' , ID) - ID)) AS generator_id
		FROM tblToolsStringParserCounter
		WHERE ID <= LEN(',' + @generator_id_list + ',') AND SUBSTRING(',' + @generator_id_list + ',' , ID - 1, 1) = ','
		AND CHARINDEX(',' , ',' + @generator_id_list + ',' , ID) - ID > 0
		DELETE FROM #generator where generator_id is null
		IF @debug >= 1 PRINT 'SELECT FROM #generator'
		IF @debug >= 1 SELECT * FROM #generator
	END

	create table #form_id_list (form_id int)
	INSERT INTO #form_id_list
	SELECT convert(int, SUBSTRING(',' + @form_id_list + ',' , ID ,
		CHARINDEX(',' , ',' + @form_id_list + ',' , ID) - ID)) AS form_id
	FROM tblToolsStringParserCounter
	WHERE ID <= LEN(',' + @form_id_list + ',') AND SUBSTRING(',' + @form_id_list + ',' , ID - 1, 1) = ','
	AND CHARINDEX(',' , ',' + @form_id_list + ',' , ID) - ID > 0
	DELETE FROM #form_id_list where form_id is null
	IF @debug >= 1 PRINT 'SELECT FROM #form_id_list'
	IF @debug >= 1 SELECT * FROM #form_id_list

	create table #tracking_id_list (tracking_id int)
	INSERT INTO #tracking_id_list
	SELECT convert(int, SUBSTRING(',' + @tracking_id_list + ',' , ID ,
		CHARINDEX(',' , ',' + @tracking_id_list + ',' , ID) - ID)) AS tracking_id
	FROM tblToolsStringParserCounter
	WHERE ID <= LEN(',' + @tracking_id_list + ',') AND SUBSTRING(',' + @tracking_id_list + ',' , ID - 1, 1) = ','
	AND CHARINDEX(',' , ',' + @tracking_id_list + ',' , ID) - ID > 0
	DELETE FROM #tracking_id_list where tracking_id is null
	IF @debug >= 1 PRINT 'SELECT FROM #tracking_id_list'
	IF @debug >= 1 SELECT * FROM #tracking_id_list
	
	-- Time saver?
	-- Eliminate #customer/#generator records that won't be found when @customer_id_list
	-- or @generator_id_list are specified:
	set @execute_sql = ''
	IF @customer_id_list <> '-1'
		set @execute_sql = 'DELETE from #customer where customer_id not in (' + @customer_id_list + ');'
	IF @generator_id_list <> '-1'
		set @execute_sql = 'DELETE from #generator where generator_id not in (' + @generator_id_list + ');'

	select @custCount = count(*) from #customer
	select @genCount = count(*) from #generator	

    IF @debug >= 1 PRINT '@custCount:  ' + convert(varchar(20), @custCount)
    IF @debug >= 1 PRINT '@genCount:  ' + convert(varchar(20), @genCount)
if @debug >= 1 print 'Elapsed time: ' + convert(varchar(20), datediff(ms, @starttime, getdate())) + 'ms'

-- abort if there's nothing possible to see
	if @custCount + 
		@genCount + 
		len(ltrim(rtrim(isnull(@generator_name, '')))) +
		len(ltrim(rtrim(isnull(@modified_by, '')))) +
		len(ltrim(rtrim(isnull(@form_id_list, '')))) +
		len(ltrim(rtrim(isnull(@tracking_id_list, '')))) +
		len(ltrim(rtrim(isnull(@waste_common_name, '')))) +
		len(ltrim(rtrim(isnull(@start_date, '')))) +
		len(ltrim(rtrim(isnull(@end_date, ''))))
		= 0 RETURN

set @execute_sql = '
	select 
		f.*, 
		doc_name as waste_common_name, 
		'''' as approvals 
	from formheaderdistinct f 
	where 1=1 
		and type=''wcr'' 
		and status=''A'' 
	'
	
	-- this section only applies to contacts
	IF LEN(@contact_id) > 0
		BEGIN
			SET @where = @where + ' AND ( 1=0 '
	
			IF @custCount > 0
				SET @where = @where + ' or exists ( Select customer_id from #customer cxr Where cxr.customer_id = f.customer_id ) '
				
			--IF @genCount > 0
				-- SET @where = @where + ' or exists ( Select generator_id from #generator cxr Where cxr.generator_id = f.generator_id ) '
					
			SET @where = @where + ' ) '
		END
	ELSE -- For Associates:
		IF @customer_id_list <> '-1'
			SET @where = @where + ' AND (1=1 ) '
			/*OR exists ( Select cg.generator_id from CustomerGenerator cg, Customer c Where cg.generator_id = f.generator_id AND cg.customer_id IN (' + @customer_id_list + ') AND cg.customer_id = c.customer_id AND c.generator_flag = ''T'' ) */
	
	IF not (@show_all = 'T' and len(@contact_id) = 0)
	BEGIN

		IF @customer_id_list <> '-1'
			BEGIN
				SET @where = @where + ' AND ( f.customer_id IN (' + @customer_id_list + ') '
				IF LEN(@contact_id) = 0
					SET @where = @where + ' OR f.customer_id_from_form IN (' + @customer_id_list + ') '
				SET @where = @where + ') '
			END
	
		IF @generator_id_list <> '-1'
			SET @where = @where + ' AND ( /* f.generator_id IN (' + @generator_id_list + ') 
				OR */ f.epa_id in (select epa_id from generator where generator_id in (' + @generator_id_list + ')) ) '
	
		IF LEN(@modified_by) > 0 AND LEN(@contact_id) = 0
			SET @where = @where + ' AND ( f.modified_by LIKE ''%' + @modified_by + '%'' ) '

		IF LEN(@form_id_list) > 0
			SET @where = @where + ' AND ( f.form_id in (select form_id from #form_id_list) ) '
			
		IF LEN(@generator_name) > 0
			SET @where = @where + ' AND ( f.generator_name LIKE ''%' + @generator_name + '%'' ) '

		IF LEN(@waste_common_name) > 0
			SET @where = @where + ' AND ( f.doc_name LIKE ''%' + @waste_common_name + '%'' ) '

		IF LEN(@tracking_id_list) > 0
			SET @where = @where + ' AND ( f.tracking_id in (select tracking_id from #tracking_id_list) ) '
			
		IF LEN(@start_date) > 0
			IF isDate(@start_date) = 1
				SET @where = @where + ' AND ( f.date_modified >= ''' + @start_date + ''') '
			IF isDate(@end_date) = 1
				SET @where = @where + ' AND ( f.date_modified <= ''' + @end_date + ''') '
			ELSE
				IF isDate(@start_date) = 1
					SET @where = @where + ' AND ( f.date_modified <= ''' + @start_date + ''') '
	END
	
	SET @execute_order = ' order by f.date_modified desc, waste_common_name asc '

/*	
strSQL = strSQL & " order by "

if len(trim(RQF("order"))) > 0 then
	strSQL = strSQL & RQF("order")
else
	strSQL = strSQL & "f.date_modified desc, waste_common_name asc"
end if
*/

if @debug > 0 select @execute_sql as execute_sql, @where as where_, @execute_order as execute_order

SET NOCOUNT OFF

	Exec(@execute_sql + @where + @execute_order)


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_reports_pending_profiles] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_reports_pending_profiles] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_reports_pending_profiles] TO [EQAI]
    AS [dbo];

