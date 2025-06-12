-- drop proc [sp_reports_waste_received]
go

CREATE PROCEDURE [dbo].[sp_reports_waste_received]
	@debug				int, 			-- 0 or 1 for no debug/debug mode
	@database_list		varchar(8000),	-- Comma Separated Company List
	@customer_id_list	text,	-- Comma Separated Customer ID List - what customers to include
	@generator_id_list	text,	-- Comma Separated Generator ID List - what generators to include
	@approval_code		text,	-- Approval Code
--	@waste_code			text,	-- Waste Code, someday.
	@receipt_id			text,	-- Receipt ID
	@manifest			text,	-- Manfiest Code
	@start_date			varchar(20),	-- Start Date
	@end_date			varchar(20),	-- Start Date
	@contact_id			varchar(100),	-- Contact_id
	@include_brokered	char(1),			-- 'Y' or 'N' for including waste where customer_id is not one of mine: ALWAYS 'Y'.
	@report_type		char(1),		-- 'L'ist or 'D'etail (Detail returns a 2nd recordset with detail info)
	@session_key		varchar(100) = NULL,	-- unique identifier key to a previously run query's results
	@row_from			int = 1,			-- when accessing a previously run query's results, what row should the return set start at?
	@row_to				int = 20,			-- when accessing a previously run query's results, what row should the return set end at (-1 = all)?
	@profit_ctr_id		int	= NULL,		-- only used when report type is 'D'
	@receipt_id_int		int	= NULL		-- this is a single number to represent the Detail Receipt ID we are going to select

AS
/* ***************************************************************************************************
sp_reports_waste_received:

Returns the data for Waste Receipts.

LOAD TO PLT_AI*

select convert(varchar(20), company_id) + '|' + convert(varchar(20), profit_ctr_id) from profitcenter

sp_reports_waste_received 0, '2|0, 3|0, 12|1, 14|12, 15|3, 16|0, 18|0, 21|2, 22|1, 23|0, 24|0, 25|0, 26|0, 27|0, 28|0, 29|0, 32|0', '1125', '', '', '', '', '12/1/1900', '12/31/2014', '', 'Y', 'L', NULL, 1, 20, NULL, NULL
-- 11s, 40585r, 1-20

sp_reports_waste_received 0, '2|0, 3|0, 12|1, 14|12, 15|3, 16|0, 18|0, 21|2, 22|1, 23|0, 24|0, 25|0, 26|0, 27|0, 28|0, 29|0, 32|0', '', '', '', '2323423423423234234424', '', '', '', '', 'Y', 'L', NULL, 1, 20, NULL, NULL

select max(receipt_id) from receipt
select 10* 1228469
	
sp_reports_waste_received 1, ', 2|21, 3|1, 12|0, 14|0, 14|4, 14|6, 14|12, 15|1, 15|2, 21|0, 22|0, 23|0, 24|0', '150079', '', '', '', '', '', '', '11156', 'N'
sp_reports_waste_received 1, ', 2|21, 3|1, 12|0, 14|0, 14|4, 14|6, 14|12, 15|1, 21|0, 22|0, 23|0, 24|0', '2492', '', '092805MAB', '', '', '12/14/2005', '12/31/2005', '1259', 'N'
sp_reports_waste_received 1, '14|6', '', '', '', '', '986', '', '', '', 'N'
sp_reports_waste_received 0, ' 2|21, 3|1, 12|0, 14|0, 14|4, 14|6, 14|12, 15|1, 21|0, 22|0, 23|0, 24|0', '1420', '41974', '', '', '', '01/01/2005', '12/31/2005', '10706', 'N'
sp_reports_waste_received 1, ' 2|21, 3|1, 12|0, 14|0, 14|4, 14|6, 14|12, 15|1, 21|0, 22|0, 23|0, 24|0', '2526', '39213', '', '', '', '', '', '1290', 'Y'
sp_reports_waste_received 1, '', '', '', '123456SH', '', '', '', '', '10913', 'Y'

sp_reports_waste_received 1, ', 2|21, 3|1, 12|0, 14|0, 14|4, 14|6, 14|12, 15|1, 15|2, 21|0, 22|0, 23|0, 24|0', '1125', '', '', '', '', '12/1/05', '12/31/2005', '', 'N'
sp_reports_waste_received 1, ', 2|21, 3|1, 12|0, 14|0, 14|4, 14|6, 14|12, 15|1, 15|2, 21|0, 22|0, 23|0, 24|0', '150079', '', '', '', '', '', '', '11156', 'N'
sp_reports_waste_received 1, ', 2|21, 3|1, 12|0, 14|0, 14|4, 14|6, 14|12, 15|1, 21|0, 22|0, 23|0, 24|0', '2492', '', '092805MAB', '', '', '12/14/2005', '12/31/2005', '1259', 'N'
sp_reports_waste_received 1, '14|6', '', '', '', '', '986', '', '', '', 'N'
sp_reports_waste_received 0, ' 2|21, 3|1, 12|0, 14|0, 14|4, 14|6, 14|12, 15|1, 21|0, 22|0, 23|0, 24|0', '1420', '41974', '', '', '', '01/01/2005', '12/31/2005', '10706', 'N'
sp_reports_waste_received 0, ' 2|21, 3|1, 12|0, 14|0, 14|4, 14|6, 14|12, 15|1, 21|0, 22|0, 23|0, 24|0', '2526', '39213', '', '', '', '', '', '1290', 'N'

debug(int), db_list(v8000), cust_ids(t), gen_ids(t), approvals(t), receipts(t), manifests(t), start_dt(v20), end_dt(v20), contact(i), 'Y'

sp_reports_waste_received 1, '2|21, 3|1, 12|0, 14|0, 14|4, 14|6, 14|12, 15|1, 21|0, 22|0, 23|0, 24|0', '888888', '', '', '', '', '', '', '', 'Y'
sp_reports_waste_received 1, '2|21, 3|1, 12|0, 14|0, 14|4, 14|6, 14|12, 15|1, 21|0, 22|0, 23|0, 24|0', '', '', '', '', '', '', '', '101296', 'Y'

sp_reports_waste_received 1, '2|21, 3|1, 12|0, 14|0, 14|4, 14|6, 14|12, 15|1, 21|0, 22|0, 23|0, 24|0', '', '', 'NC63056LP', '', '', '9/1/2006', '11/15/2006', '100913', 'Y'
sp_reports_waste_received 1, '2|21, 3|1, 12|0, 14|0, 14|4, 14|6, 14|12, 15|1, 21|0, 22|0, 23|0, 24|0', '', '', 'NC63056LP', '', '', '9/1/200', '11/15/2006', '101296', 'Y'

sp_reports_waste_received 1, '2|21, 3|1, 12|0, 14|0, 14|4, 14|6, 14|12, 15|1, 21|0, 22|0, 23|0, 24|0', '001125', '', '', '', '', '1/1/2005', '8/31/2005', '', 'Y'
sp_reports_waste_received 1, '2|21, 3|1, 12|0, 14|0, 14|4, 14|6, 14|12, 15|1, 21|0, 22|0, 23|0, 24|0', '', '', '', '', '', '', '', '', 'Y'
sp_reports_waste_received 0, '2|21, 3|1, 12|0, 14|0, 14|4, 14|6, 14|12, 15|1, 21|0, 22|0, 23|0, 24|0', '', '', '', '147108,147193,147425,147503,147563,147604,147762,147763,147768,147840', '', '', '', '', 'Y'
sp_reports_waste_received 0, '2|21, 3|1, 12|0, 14|0, 14|4, 14|6, 14|12, 15|1, 21|0, 22|0, 23|0, 24|0', '', '', '', '', 'MI9415459,MI9459024,MI9442694,MI9066966', '', '', '', 'Y'
sp_reports_waste_received 0, '2|21, 3|1, 12|0, 14|0, 14|4, 14|6, 14|12, 15|1, 21|0, 22|0, 23|0, 24|0', '', '', '', '', '', '1/1/2006', '1/4/2006', '', 'Y'

sp_reports_waste_received 0, '2|21, 3|1, 12|0, 14|0, 14|4, 14|6, 14|12, 15|1, 21|0, 22|0, 23|0, 24|0', '', '', '', '', '', '', '', 559, 'Y'

05/24/2005 JPB	Created
01/04/2006 JDB	Modified to use plt_rpt database
02/22/2006 JPB	Modified to return profit center name
05/06/2006 RG   Modified for b2bxcontact
05/22/2006 JPB  Modified per SCC to not use 1 as line_id, but to use min(line_id) for Approval transaction type
11/27/2006 RG   Modiifed to include the customergenerator for brokoered accounts
04/06/2007 JPB	Modified to conform to Central Invoicing table layouts/fields.
05/31/2007 JPB  Modified from varchar(8000) inputs to Text inputs
09/05/2007 JPB  Modified: CustomerGenerator not used in query (to find valid generators for the customer/contact)
						  Speed Improvements - hand "approval_code" query logic to the approval table and join to it.
											 - change invoicedetail subquery to use indexed link field, not multiple fields.
09/21/2007 JDB	Modified to use a "UNION" in the subselect for profile_id, instead of "OR".
10/03/2007 JPB  Modified to remove NTSQL* references
10/18/2007 JPB  Modified - no longer doing subquery to get min(line_id) - just group on receipt_id, etc.

Central Invoicing:
	When run by a contact and there's no input customer id list or generator id list, populate the #tmp tables
	 used to validate /join on those with all available id's for that contact.

#03/07/2008 JPB	
	Modified to handle profit_ctr_id and profit_ctr_name according to profitcenter.view_on_web rules
	Addresses bad behavior from sp_reports_list_database: Doesn't use srld anymore
	Properly renders the "display as" names for profitcenters that report as their parent company

9/11/2008 - JPB
	Undid the profit_ctr_id masking.  it's just wrong, man.

9/18/2008 - JPB
	Cut down the number of fields returned in this so that DISTINCT is accurate.
	
01/30/2009 - RJG 
	Modified code to include access filter (per JPB)

02/11/2009 - RJG
	Modified fn_surcharge_desc call to pass company_id

07/01/2009 - JPB
	- Modified code to require returned records to be for Invoiced receipts only,
	consistent with sp_reports_waste_received_all_lines

11/17/2009 - JPB
	- Speed racer was here: Converted "select count(*) from ..." to if exists(select * from ...)" for speed.
	- Rewrote the #access_filter joins for speed.

04/18/2011 - JPB
	- Rewrite of the 'D'etail version to enforce #access_filter restrictions
	
12/24/2011 - JPB
	- In the 4/18 work, a shortcut to the results for re-visited searches was removed and not noticed.
	  This had the effect of causing a re-run for detail or excel output to double-load the work table with
	  a 2nd (3rd, nth) set of results for the query and then return ALL of them.  Bad.
	  Fixed by replacing the GOTo that skips the Work_* table population, but still includes the #access_filter.
	  
3/1/2012 - JPB
	Revisit the above issue, as it was fixed for customers but not EQ associates.  Whoops.

3/27/2013 - JPB
	Add validation for super-large numbers given as receipt id's. Ignore them.

08/22/2013 - JPB
	Texas Waste Code Modification - the subquery for matching records by waste_code was updated so
		waste_code_uid is the field being joined on, and wastecode.display_name is the field being matched.
	Which is all moot at this point because @waste_code isn't really even a search param yet.
	
09/27/2019 - JPB
	Added (top 1) manifest to List output
	
*************************************************************************************************** */

SET NOCOUNT ON
SET ANSI_WARNINGS OFF

DECLARE	@database	varchar(30),
	@database_name	varchar(60),
	--@company_id		varchar(12),
	--@profit_ctr_id	varchar(12),
	@execute_sql	varchar(8000),
	@intCount		int,
	@custCount		int,
	@genCount		int,
	@waste_code		varchar(10), -- until its an input
	@contact_id_int	int,
	@new_session_key varchar(100)

set @new_session_key = newid()

SET NOCOUNT ON

-- IF @include_brokered IS NULL OR @include_brokered <> 'Y' SET @include_brokered = 'N'
-- IF @debug = 1 PRINT '@include_brokered:  ' + @include_brokered
SET @include_brokered = 'Y' -- It's ALWAYS 'y'

declare @starttime datetime
set @starttime = getdate()
if @debug > 3 select datediff(ms, @starttime, getdate()) as timer, 'Start' as description

-- Housekeeping.  Gets rid of old paging records.
DECLARE @eightHoursAgo as DateTime
set @eightHoursAgo = DateAdd(hh, -8, getdate())
if ((SELECT COUNT(session_added) FROM Work_WasteReceivedListResult where session_added < @eightHoursAgo) > 0)
BEGIN
	delete from Work_WasteReceivedListResult where session_added < @eightHoursAgo
END

 if @debug > 3 select datediff(ms, @starttime, getdate()) as timer, 'After Housekeeping' as description

-- Check to see if there's a @session_key provided with this query, and if that key is valid.
 if @debug > 3 select datediff(ms, @starttime, getdate()) as timer, @session_key AS session_key, @new_session_key AS new_session_key
if datalength(@session_key) > 0 begin
	if not exists(select distinct session_key from Work_WasteReceivedListResult where session_key = @session_key) begin
		set @session_key = NULL
		set @row_from = 1
		set @row_to = 20
	end
end
if @debug > 3 select datediff(ms, @starttime, getdate()) as timer, @session_key AS session_key, @new_session_key AS new_session_key

 if @debug > 3 select datediff(ms, @starttime, getdate()) as timer, 'Before Var setup' as description

-- Handle text inputs into temp tables
	CREATE TABLE #Customer_id_list (ID int)
	CREATE INDEX idx1 ON #Customer_id_list (ID)
	Insert #Customer_id_list 
		select convert(int, row) 
		from dbo.fn_SplitXsvText(',', 0, @customer_id_list) 
		where isnull(row, '') <> ''

	IF @debug > 3 SELECT * FROM #Customer_id_list

	CREATE TABLE #generator_id_list (ID int)
	CREATE INDEX idx2 ON #generator_id_list (ID)
	Insert #generator_id_list 
		select convert(int, row) 
		from dbo.fn_SplitXsvText(',', 0, @generator_id_list) 
		where isnull(row, '') <> ''

	IF @debug > 3 SELECT * FROM #generator_id_list

	CREATE TABLE #approval_code_list (approval_code varchar(20))
	CREATE INDEX idx3 ON #approval_code_list (approval_code)
	Insert #approval_code_list 
		select row 
		from dbo.fn_SplitXsvText(',', 1, @approval_code) 
		where isnull(row, '') <> ''

	IF @debug > 3 SELECT * FROM #approval_code_list

	CREATE TABLE #wastecode (waste_code varchar(10))
	CREATE INDEX idx4 ON #wastecode (waste_code)
	Insert #wastecode 
		select row 
		from dbo.fn_SplitXsvText(',', 1, @waste_code) 
		where isnull(row, '') <> ''

	IF @debug > 3 SELECT * FROM #wastecode
	
	CREATE TABLE #Receipt_id_list (ID int)
	CREATE INDEX idx5 ON #Receipt_id_list (ID)
	Insert #Receipt_id_list 
		select case when convert(bigint, row) < 2147483647 then convert(int, row) else -214748364 end
		from dbo.fn_SplitXsvText(',', 0, @receipt_id) 
		where isnull(row, '') <> '' and len(row) <= 10

	IF @debug > 3 SELECT * FROM #Receipt_id_list

	CREATE TABLE #manifest_list (manifest varchar(20))
	CREATE INDEX idx6 ON #manifest_list (manifest)
	Insert #manifest_list 
		select row 
		from dbo.fn_SplitXsvText(',', 1, @manifest) 
		where isnull(row, '') <> ''

	IF @debug > 3 SELECT * FROM #manifest_list

	CREATE TABLE #access_filter (
		ID int IDENTITY,
		company_id int, 
		profit_ctr_id int,
		receipt_id int,
		line_id int,
		container_type varchar(1),
		customer_id int
	)

	-- figure out if this user has inherent access to customers
    SELECT @custCount = 0, @genCount = 0
	IF LEN(@contact_id) > 0
	BEGIN
		SET @contact_id_int = convert(int, @contact_id)
		select @custCount = count(customer_id) from ContactXRef cxr
			Where cxr.contact_id = @contact_id_int
			AND cxr.status = 'A' and cxr.web_access = 'A'
			
		select @genCount = (
			select count(generator_id) from ContactXRef cxr
				Where cxr.contact_id = @contact_id_int
				AND cxr.status = 'A' and cxr.web_access = 'A' 
			) + ( 
			Select count(cg.generator_id) from CustomerGenerator cg, ContactXRef cxr, Customer c
				Where cxr.contact_id = @contact_id_int
				AND cg.customer_id = cxr.customer_id
				AND cxr.status = 'A'
				AND cxr.web_access = 'A'
				AND cg.customer_id = c.customer_id
				AND c.generator_flag = 'T'
			)	
	END
	ELSE -- For Associates:
	BEGIN
		set @custCount = 1
		set @genCount = 1
	END

    IF @debug >= 1 PRINT '@custCount:  ' + convert(varchar(20), @custCount)
    IF @debug >= 1 PRINT '@genCount:  ' + convert(varchar(20), @genCount)

	 if @debug > 3 select datediff(ms, @starttime, getdate()) as timer, 'After var->#table handling' as description


-- abort if there's nothing possible to see

	if case when LEN(@contact_id) > 0 then @custCount else 1 end + 
		case when LEN(@contact_id) > 0 then @genCount else 1 end + 
		len(ltrim(rtrim(isnull(@start_date, '')))) +
		len(ltrim(rtrim(isnull(@end_date, '')))) +
		CASE WHEN EXISTS (select * from #Receipt_id_list) THEN 1 ELSE 0 END +
		CASE WHEN EXISTS (select * from #approval_code_list) THEN 1 ELSE 0 END +
		CASE WHEN EXISTS (select * from #wastecode) THEN 1 ELSE 0 END +
		CASE WHEN EXISTS (select * from #manifest_list) THEN 1 ELSE 0 END
		= 0 RETURN

	 if @debug > 3 select datediff(ms, @starttime, getdate()) as timer, 'After abort if nothing to see' as description

	IF LEN(@contact_id) > 0 and @contact_id_int > -1
		IF @custCount <= 0 and @genCount <= 0
			RETURN



-- set @session_key = newid()
	
	-- Frisk contact-users (no smuggling in id's that aren't yours)		
	IF LEN(@contact_id) > 0 BEGIN -- in use by a contact, check CXR and CustomerGenerator

		 if @debug > 3 select datediff(ms, @starttime, getdate()) as timer, 'Building #Access_filter, starting direct query' as description

		SET @execute_sql = '
			INSERT #access_filter
			-- 1: inherent customers
				select  distinct
					r2.company_id,
					r2.profit_ctr_id,
					r2.receipt_id,
					r2.line_id,
					c.container_type,
					r2.customer_id
					from (
						select customer_id from ContactXRef WITH (nolock)
						WHERE contact_id = ' + convert(Varchar(20), @contact_id ) + '
							and type = ''C''
							AND status = ''A'' 
							and web_access = ''A''
					)CXR 
					inner join Receipt r2 WITH (nolock) ON r2.customer_id = CXR.customer_id '

IF @report_type = 'D' AND @receipt_id_int IS NOT NULL SET @execute_sql = @execute_sql + ' AND r2.receipt_id = ' + convert(varchar(20), @receipt_id_int)

			SET @execute_sql = @execute_sql + '
					LEFT OUTER JOIN Container c WITH (nolock) ON r2.receipt_id = c.receipt_id
						AND r2.line_id = c.line_id
						AND r2.profit_ctr_id = c.profit_ctr_id
						AND r2.company_id = c.company_id
		'
		IF EXISTS(select * from #generator_id_list)
			SET @execute_sql = @execute_sql + '
					INNER JOIN #generator_id_list gil on r2.generator_id = gil.id
			'
		IF EXISTS(select * from #customer_id_list)
			SET @execute_sql = @execute_sql + '
					INNER JOIN #customer_id_list cil on r2.customer_id = cil.id
			'
		IF EXISTS(select * from #receipt_id_list)
			SET @execute_sql = @execute_sql + '
					INNER JOIN #receipt_id_list ril on r2.receipt_id = ril.id
			'
		SET @execute_sql = @execute_sql + '
				UNION
			-- 2: inherent generators
				select  distinct
					r3.company_id,
					r3.profit_ctr_id,
					r3.receipt_id,
					r3.line_id,
					c.container_type,
					r3.customer_id
					from (
						select generator_id from ContactXRef  WITH (nolock)
						WHERE contact_id = ' + convert(Varchar(20), @contact_id ) + ' 
							and type = ''G'' 
							AND status = ''A'' 
							and web_access = ''A''
					)CXR 
					inner join receipt r3 ON r3.generator_id = CXR.generator_id '

IF @report_type = 'D' AND @receipt_id_int IS NOT NULL SET @execute_sql = @execute_sql + ' AND r3.receipt_id = ' + convert(varchar(20), @receipt_id_int)

			SET @execute_sql = @execute_sql + '
					LEFT OUTER JOIN Container c ON r3.receipt_id = c.receipt_id
						AND r3.line_id = c.line_id
						AND r3.profit_ctr_id = c.profit_ctr_id
						AND r3.company_id = c.company_id
		'
		IF EXISTS(select * from #generator_id_list)
			SET @execute_sql = @execute_sql + '
					INNER JOIN #generator_id_list gil on r3.generator_id = gil.id
			'
		IF EXISTS(select * from #customer_id_list)
			SET @execute_sql = @execute_sql + '
					INNER JOIN #customer_id_list cil on r3.customer_id = cil.id
			'
		IF EXISTS(select * from #receipt_id_list)
			SET @execute_sql = @execute_sql + '
					INNER JOIN #receipt_id_list ril on r3.receipt_id = ril.id
			'
		SET @execute_sql = @execute_sql + '
				UNION
			-- 3: generators via customergenerator x inherent customers
				select  distinct
					r4.company_id,
					r4.profit_ctr_id,
					r4.receipt_id,
					r4.line_id,
					c.container_type,
					r4.customer_id
					from (
						select customer_id from ContactXRef  WITH (nolock)
						WHERE contact_id = ' + convert(Varchar(20), @contact_id ) + ' 
							and type = ''C'' 
							AND status = ''A'' 
							and web_access = ''A''
					)CXR 
					INNER JOIN CustomerGenerator CG ON CG.Customer_id = CXR.customer_id 
					inner join Receipt r4 ON r4.generator_id = CG.generator_id '

IF @report_type = 'D' AND @receipt_id_int IS NOT NULL SET @execute_sql = @execute_sql + ' AND r4.receipt_id = ' + convert(varchar(20), @receipt_id_int)

			SET @execute_sql = @execute_sql + '
					LEFT OUTER JOIN Container c ON r4.receipt_id = c.receipt_id
						AND r4.line_id = c.line_id
						AND r4.profit_ctr_id = c.profit_ctr_id
						AND r4.company_id = c.company_id
		'
		IF EXISTS(select * from #generator_id_list)
			SET @execute_sql = @execute_sql + '
					INNER JOIN #generator_id_list gil on r4.generator_id = gil.id
			'
		IF EXISTS(select * from #customer_id_list)
			SET @execute_sql = @execute_sql + '
					INNER JOIN #customer_id_list cil on r4.customer_id = cil.id
			'
		IF EXISTS(select * from #receipt_id_list)
			SET @execute_sql = @execute_sql + '
					INNER JOIN #receipt_id_list ril on r4.receipt_id = ril.id
			'
			
		IF @debug >= 2 
			SELECT @execute_sql as sql_statement
		
		EXEC (@execute_sql)


		if (select count(*) from #access_filter) = 0 return
		
			-- CREATE INDEX idx_receipt_id ON #access_filter (receipt_id)

		 if @debug > 3 select datediff(ms, @starttime, getdate()) as timer, 'Indexing #Access_filter' as description
		CREATE INDEX idx_receipt_id ON #access_filter (receipt_id)

if @debug > 3 select datalength(@session_key) as session_key_datalength, @report_type as report_type, 'jump to returnresults?' as question
if datalength(@session_key) > 0 OR @report_type = 'D' goto returnresults

		SET @execute_sql = 'INSERT Work_WasteReceivedListResult '
		SET @execute_sql = @execute_sql + ' SELECT DISTINCT
			r.receipt_id,
			r.profit_ctr_id, 
			r.customer_id,
			r.company_id,
			dbo.fn_web_profitctr_display_name(r.company_id, r.profit_ctr_id) as profit_ctr_name,
			''' + case when isnull(@session_key, '') = '' then @new_session_key else @session_key end + ''' as session_key,
			GETDATE() as session_added
			FROM #access_filter af WITH (nolock)
			INNER JOIN Receipt r WITH (nolock) ON af.receipt_id = r.receipt_id
				AND af.company_id = r.company_id
				AND af.profit_ctr_id = r.profit_ctr_id
				AND af.line_id = r.line_id
				AND af.customer_id = r.customer_id
			INNER JOIN ProfitCenter p WITH (nolock) on r.company_id = p.company_id and r.profit_ctr_id = p.profit_ctr_id
			INNER JOIN Company c WITH (nolock)on r.company_id = c.company_id
			'
			
	END
	ELSE
	BEGIN -- associates are not filtered by the access filter
			-- Now, no matter what @customer_id_list or @generator_id_list was asked for, only the actually assigned - or associated-with-assigned-customers will show up.
			-- If you're an associate, you don't get "frisked" on the way in like contacts just did.
			
		if @debug > 3 select datediff(ms, @starttime, getdate()) as timer, 'Associate skip happened' as description


		if @debug > 3 select datalength(@session_key) as session_key_datalength, @report_type as report_type, 'jump to returnresults?' as question
		if datalength(@session_key) > 0 OR @report_type = 'D' goto returnresults
			
		INSERT #access_filter select 0, 0, -123456, 0, '', 0
		
		SET @execute_sql = 'INSERT Work_WasteReceivedListResult '
		SET @execute_sql = @execute_sql + 'SELECT DISTINCT
			r.receipt_id,
			r.profit_ctr_id, 
			r.customer_id,
			r.company_id,
			dbo.fn_web_profitctr_display_name(r.company_id, r.profit_ctr_id) as profit_ctr_name,
			''' + case when isnull(@session_key, '') = '' then @new_session_key else @session_key end + ''' as session_key,
			GETDATE() as session_added
			FROM Receipt r  WITH (nolock)
			INNER JOIN ProfitCenter p WITH (nolock) on r.company_id = p.company_id and r.profit_ctr_id = p.profit_ctr_id
			INNER JOIN Company c WITH (nolock) on r.company_id = c.company_id'
	END

	 if @debug > 3 select datediff(ms, @starttime, getdate()) as timer, 'Access Filter start of joins' as description

	IF LEN(@database_list) > 0 SET @execute_sql = @execute_sql + '
		INNER JOIN dbo.fn_web_profitctr_parse(''' + @database_list + ''') tmp on r.company_id = tmp.company_id 
		and r.profit_ctr_id = tmp.profit_ctr_id
		'

	SET @execute_sql = @execute_sql + '
		INNER JOIN Billing id WITH (nolock) ON 
			id.company_id = r.company_id
			AND id.profit_ctr_id = r.profit_ctr_id
			AND id.receipt_id = r.receipt_id
			AND id.line_id = r.line_id'

	IF @report_type = 'D' AND @receipt_id_int IS NOT NULL SET @execute_sql = @execute_sql + ' AND r.receipt_id = ' + convert(varchar(20), @receipt_id_int)

	SET @execute_sql = @execute_sql + ' WHERE 1 = 1 '


	 if @debug > 3 select datediff(ms, @starttime, getdate()) as timer, 'Access Filter start of where clause' as description
		
	-- Build the where clause	
	IF EXISTS(select * from #customer_id_list)
		SET @execute_sql = @execute_sql + ' AND ( r.customer_id IN (select id from #customer_id_list)) '

	IF EXISTS(select * from #generator_id_list)
		SET @execute_sql = @execute_sql + ' AND ( r.generator_id IN (select id from #generator_id_list) ) '
		
	IF EXISTS(select * from #wastecode)
		 SET @execute_sql = @execute_sql + ' AND exists (
				select 1
				from ReceiptWasteCode 
				where r.company_id = ReceiptWasteCode.company_id
					AND r.profit_ctr_id = ReceiptWasteCode.profit_ctr_id
					AND r.receipt_id = ReceiptWasteCode.receipt_id
					AND r.line_id = ReceiptWasteCode.line_id
					and ReceiptWasteCode.waste_code_uid in ( 
						select waste_code_uid 
						from wastecode sqwc 
						inner join #wastecode sqw 
						on sqwc.display_name = sqw.waste_code)
				) '


	IF EXISTS(select * from #receipt_id_list)
		SET @execute_sql = @execute_sql + '
			AND r.receipt_id IN (select id from #receipt_id_list) '

--	IF EXISTS(select * from #approval_code_list) SET @execute_sql = @execute_sql + '
--		AND r.link_Approval_Receipt IN (select link_Approval_Receipt from Approval where approval_code IN (select approval_code from #approval_code_list)) '

	IF EXISTS(select * from #approval_code_list)
		SET @execute_sql = @execute_sql + '
		AND  r.approval_code IN (select approval_code from #approval_code_list)'

	IF EXISTS(select * from #manifest_list)
		SET @execute_sql = @execute_sql + '
		AND r.manifest IN (select manifest from #manifest_list) '

	IF LEN(@start_date) > 0 
		SET @execute_sql = @execute_sql + ' AND r.receipt_date >= ''' + @start_date + ''' '
		
	IF LEN(@end_date) > 0
		SET @execute_sql = @execute_sql + ' AND r.receipt_date <= ''' + @end_date + ''' '
		
	SET @execute_sql = @execute_sql + '	
		AND r.receipt_date <= GETDATE()
		AND r.receipt_status = ''A'' 
		AND c.view_on_web = ''T''
		AND p.status = ''A''
		AND id.status_code = ''I''
		AND isnull(p.view_on_web, ''F'') <> ''F''
		AND isnull(p.view_waste_received_on_web, ''F'') = ''T''
		ORDER BY r.company_id, profit_ctr_name, r.receipt_id desc
	'

	 if @debug > 3 select datediff(ms, @starttime, getdate()) as timer, 'Access Filter query is built' as description

	if @debug > 3 select datediff(ms, @starttime, getdate()) as timer, @execute_sql AS sql_statement

	if @debug > 5 select * FROM #Access_Filter

--print @execute_sql
--SELECT * FROM #access_filter

	-- Debug? Print / Select
	IF @debug >= 1
	begin
		SELECT '#generator_id_list', * FROM #generator_id_list
		SELECT '#approval_code_list', * FROM #approval_code_list
		SELECT '#wastecode', * FROM #wastecode
		SELECT '#Receipt_id_list', * FROM #Receipt_id_list
		SELECT '#manifest_list', * FROM #manifest_list
		SELECT '#approval_code_list', * FROM #approval_code_list
		SELECT '#Customer_id_list', * FROM #Customer_id_list
		PRINT @execute_sql
	end
	IF @debug >= 2 
		SELECT @execute_sql as sql_statement

	-- Not Print-only? Run
	IF @debug < 10 BEGIN
		 if @debug > 3 select datediff(ms, @starttime, getdate()) as timer, 'Running #Access_filter string query' as description
	
		-- ON a return visit, there's a problem here: Associates haven't skipped to returnresults.
		-- so THIS executes, and double-loads the work table and multiplies results.  Yuck.
		EXEC(@execute_sql)
	END


	SET ANSI_WARNINGS ON

returnresults:
	 if @debug > 3 select datediff(ms, @starttime, getdate()) as timer, 'Reached returnresults:' as description

	 if @debug > 3 select datediff(ms, @starttime, getdate()) as timer, @session_key AS session_key, @new_session_key AS new_session_key

IF @session_key IS NULL SET @session_key = @new_session_key

if datalength(@session_key) > 0 
begin
		--print 'select from cache-table'
		-- select from cache-table

		declare @start_of_results int
		declare @end_of_results int

		select  @start_of_results = min(row_num)-1, 
				@end_of_results = max(row_num) 
			from Work_WasteReceivedListResult where session_key = @session_key

		IF @row_from IS NULL SET @row_from = 1
		IF @row_to IS NULL SET @row_to = 20

	 if @debug > 3 select datediff(ms, @starttime, getdate()) as timer, 'cache-table info:' AS oper, @start_of_results AS start_of_results, @end_of_results AS end_of_results, @row_from AS row_from, @row_to AS row_to, @session_key AS session_key, @new_session_key AS new_session_key
		
	if @report_type <> 'D' BEGIN
		set nocount on
		select 
			w.receipt_id, 
			w.profit_ctr_id, 
			w.customer_id, 
			w.company_id, 
			w.profit_ctr_name, 
			w.row_num, 
			w.session_key, 
			w.session_added,
			w.row_num - @start_of_results as row_number,
			@end_of_results - @start_of_results as record_count,
			(select top 1 r.manifest
				from receipt r
				where r.receipt_id = w.receipt_id
				and r.company_id = w.company_id
				and r.profit_ctr_id = w.profit_ctr_id
				and r.trans_type = 'D'
				and r.manifest is not null
			) as manifest
		from Work_WasteReceivedListResult w
		where w.session_key = @session_key
		and w.row_num >= @start_of_results + @row_from
		and w.row_num <= case 
			when @row_to = -1 
			then @end_of_results 
			else @start_of_results + @row_to 
		end
		order by w.row_num		
	END
end

	 if @debug > 3 select datediff(ms, @starttime, getdate()) as timer, 'After Summary Query' as description

if @report_type = 'D' 
begin
		-- select detail record
		--print 'select detail record'
		SET NOCOUNT ON
		if not exists (select 1 from #access_filter)
			if len(isnull(@contact_id, '')) = 0
				INSERT #access_filter select 0, 0, -123456, 0, '', 0
		
		SELECT	p.approval_desc,
			Company.company_name,
			Customer.cust_addr1,
			Customer.cust_addr2,
			Customer.cust_addr3,
			Customer.cust_addr4,
			RTrim(CASE WHEN (cust_city + ', ' + cust_state + ' ' + IsNull(cust_zip_code,'')) IS NULL THEN 'Missing City, State, and ZipCode' ELSE (cust_city + ', ' + cust_state + ' ' + IsNull(cust_zip_code,'')) END) AS cust_addr5,
			Customer.cust_name,
			Customer.terms_code,
			dbo.fn_insr_amt_receipt_AI(
				Receipt.receipt_id, 
				Receipt.profit_ctr_id,
				Receipt.company_id) AS insr_amt,
			dbo.fn_surcharge_desc_AI(
				ReceiptPrice.Receipt_id, 
				ReceiptPrice.line_id, 
				ReceiptPrice.price_id, 
				ReceiptPrice.profit_ctr_id,
				ReceiptPrice.company_id) AS surcharge_desc,
			Generator.EPA_ID,
			Generator.generator_name,
			ProfitCenter.address_1,
			ProfitCenter.address_2,
			ProfitCenter.address_3,
			ProfitCenter.profit_ctr_name,
			Receipt.approval_code,
			Receipt.bill_unit_code,
			Receipt.cash_received,
			Receipt.company_id,
			Receipt.customer_id,
			Receipt.date_added,
			Receipt.gross_weight,
			Receipt.hauler,
			Receipt.lab_comments,
			Receipt.line_id,
			Receipt.manifest,
			Receipt.manifest_comment,
			Receipt.manifest_line_id,
			Receipt.net_weight,
			Receipt.profit_ctr_id,
			Receipt.quantity,
			Receipt.receipt_date,
			Receipt.receipt_id,
			Receipt.receipt_status,
			CONVERT(varchar(15),'') AS secondary_manifest,
			Receipt.service_desc,
			Receipt.tare_weight,
			Receipt.tender_type,
			Receipt.time_in,
			Receipt.time_out,
			Receipt.trans_mode,
			Receipt.trans_type,
			Receipt.tsdf_approval_code,
			Receipt.waste_code,
			Receipt.waste_stream,
			ReceiptPrice.price,
			ReceiptPrice.quote_price,
			ReceiptPrice.sr_extended_amt,
			ReceiptPrice.sr_price,
			ReceiptPrice.sr_type,
			ReceiptPrice.total_extended_amt,
			ReceiptPrice.waste_extended_amt --,
			-- ReceiptWasteCode.waste_code,
			-- WasteCode.waste_code_desc
		FROM
			#access_filter af
		INNER JOIN Receipt WITH (nolock) ON ((af.receipt_id = -123456) OR (af.receipt_id = Receipt.receipt_id
			AND af.company_id = Receipt.company_id
			AND af.profit_ctr_id = Receipt.profit_ctr_id
			AND af.line_id = Receipt.line_id
			AND af.customer_id = Receipt.customer_id))
		left outer join 
		(
				SELECT 
					pqa.approval_code, 
					p.curr_status_code,
					pqa.company_id,
					pqa.profit_ctr_id,
					p.approval_desc,
					p.profile_id
				FROM Profile p
				INNER JOIN ProfileQuoteApproval pqa ON p.profile_id = pqa.profile_id
				INNER JOIN ProfileLab pl ON p.profile_id = pl.profile_id
				WHERE 1=1
				AND p.curr_status_code = 'A'
				AND pl.type = 'A'
		) approval on (receipt.approval_code = approval.approval_code 
			AND Receipt.profit_ctr_id = approval.profit_ctr_id 
			AND Receipt.company_id = approval.company_id
			AND approval.curr_status_code = 'A'
		)
		LEFT OUTER JOIN Profile p ON approval.profile_id = p.profile_id AND p.curr_status_code = 'A'
		INNER join Customer on Receipt.customer_id = Customer.customer_id
		LEFT OUTER JOIN Generator on Receipt.generator_id = Generator.generator_id
		JOIN Company ON (Receipt.company_id = Company.company_id) 
		join profitcenter on Receipt.profit_ctr_id = ProfitCenter.profit_ctr_id
			and Receipt.company_id = ProfitCenter.company_id
		left outer join ReceiptPrice on (
			Receipt.Receipt_id = ReceiptPrice.Receipt_id 
			and Receipt.Line_id = ReceiptPrice.Line_id 
			and Receipt.Profit_ctr_id = ReceiptPrice.Profit_ctr_id
			and Receipt.company_id = ReceiptPrice.company_id)
/*			
		left outer join ReceiptWasteCode on 
			(Receipt.receipt_id = ReceiptWasteCode.receipt_id 
			AND Receipt.line_id = ReceiptWasteCode.line_id 
			AND Receipt.profit_ctr_id = ReceiptWasteCode.profit_ctr_id 
			and Receipt.company_id = ReceiptWasteCode.company_id
			AND ReceiptWasteCode.primary_flag = 'T')
		left outer join WasteCode on (Receipt.waste_code = WasteCode.waste_code)
*/		
		INNER JOIN dbo.fn_web_profitctr_parse(@database_list) tmp on Receipt.company_id = tmp.company_id 
			and Receipt.profit_ctr_id = tmp.profit_ctr_id
	WHERE
		1=1
		AND Receipt.receipt_id = @receipt_id_int
		AND Receipt.profit_ctr_id = @profit_ctr_id
		AND (receipt.fingerpr_status = 'A' AND receipt.receipt_status = 'A')
		
end
	 if @debug > 3 select datediff(ms, @starttime, getdate()) as timer, 'After Detail Query' as description

	IF object_id('temdb..#Customer_id_list') IS NOT NULL DROP TABLE #Customer_id_list
	IF object_id('temdb..#generator_id_list') IS NOT NULL DROP TABLE #generator_id_list
	IF object_id('temdb..#approval_code_list') IS NOT NULL DROP TABLE #approval_code_list
	IF object_id('temdb..#wastecode') IS NOT NULL DROP TABLE #wastecode
	IF object_id('temdb..#Receipt_id_list') IS NOT NULL DROP TABLE #Receipt_id_list
	IF object_id('temdb..#manifest_list') IS NOT NULL DROP TABLE #manifest_list
GO

GRANT EXECUTE
    ON OBJECT::[dbo].[sp_reports_waste_received] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_reports_waste_received] TO [COR_USER]
    AS [dbo];

GO

