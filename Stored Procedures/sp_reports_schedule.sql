
/********************
sp_reports_schedule:

Returns the data for Schedules.

LOAD TO PLT_AI* on NTSQL1

select top 100 p.customer_id, x.contact_id, s.* from schedule s
inner join profile p on s.profile_id = p.profile_id
inner join contactxref x on p.generator_id = x.generator_id
where x.status = 'A' and x.web_access = 'A' and s.status = 'A' and p.curr_status_code = 'A'
and  exists (select 1 from contactxref x2 where x2.contact_id = x.contact_id and x2.type = 'C')
order by time_scheduled desc

sp_reports_schedule 1, ' 2|0', '2277', '', '1/9/2013', '11/1/2013', ''

SELECT * FROM contactxref where contact_id = 101261

   SELECT Distinct   s.company_id,   s.profit_ctr_id,   s.confirmation_ID,   case when s.approval_code = 'VARIOUS' then s.confirmation_id else null end as approved_confirmation_id,   s.time_scheduled,   s.quantity,   s.approval_code,   s.contact,   s.contact_company,   s.contact_fax,   s.load_type,   g.epa_id,   g.generator_name,   p.approval_desc,   s.contact_phone,   p.OTS_flag  
   FROM schedule s      inner join profile p on s.profile_id = p.profile_id      inner join #customer ct on p.customer_id = ct.customer_id      left outer join generator g on p.generator_id = g.generator_id     
   WHERE 1=1   AND (s.time_scheduled between coalesce(nullif('12/9/2000',''), s.time_scheduled) and coalesce(nullif('1/1/2013',''), s.time_scheduled) )      and s.status = 'A'    AND p.curr_status_code = 'A'   
   ORDER BY s.company_id, s.profit_ctr_id, s.time_scheduled     


sp_reports_schedule 0, ' 2|0, 3|0, 12|0, 14|0, 14|4, 14|6, 14|12, 15|1, 15|2, 21|0, 22|0, 23|0, 24|0', '2492', '', '', '', -1
sp_reports_schedule 0, ' 2|0, 3|0, 12|0, 14|0, 14|4, 14|6, 14|12, 15|1, 15|2, 21|0, 22|0, 23|0, 24|0', '2492', '', '12/1/2004', '12/31/2004', -1
sp_reports_schedule 0, ' 2|0, 3|0, 12|0, 14|0, 14|4, 14|6, 14|12, 15|1, 15|2, 21|0, 22|0, 23|0, 24|0', '888888', '', '4/1/2003', '5/1/2003', -1
sp_reports_schedule 0, ' 2|0, 3|0, 12|0, 14|0, 14|4, 14|6, 14|12, 15|1, 15|2, 21|0, 22|0, 23|0, 24|0', '70', '', '', '', -1
sp_reports_schedule 0, ' 2|0', '70', '', '6/1/2006', '6/30/2006', -1
sp_reports_schedule 0, ' 2|0, 3|0, 12|0, 14|0, 14|4, 14|6, 14|12, 15|1, 15|2, 21|0, 22|0, 23|0, 24|0', '5252', '', '', '', 536 -- works with contact
sp_reports_schedule 0, ' 2|0, 3|0, 12|0, 14|0, 14|4, 14|6, 14|12, 15|1, 15|2, 21|0, 22|0, 23|0, 24|0', '5252', '', '', '', 5361 -- won't work, wrong contact

05/26/2005 JPB Created
08/08/2006 JPB	Rewrote it to be aware of Profiles changes
08/15/2006 JPB Rewrote for speed
12/17/2012 JPB	Schedule has been converted to a centralized table in plt_ai.
	Updated security reads, etc.
08/01/2013 JPB	Fixed a bug during where #confirmation_id table was specified as global temp, not local temp.
05/13/2019 JPB	Added profit center name to the output list

**********************/

CREATE PROCEDURE sp_reports_schedule
	@debug					int, 			-- 0 or 1 for no debug/debug mode
	@database_list			varchar(8000),	-- Comma Separated Company List
	@customer_id_list		varchar(8000)='',	-- Comma Separated Customer ID List -  what customers to include
	@confirmation_id		varchar(8000),	-- Confirmation ID List
	@start_date				varchar(20),	-- Start Date
	@end_date				varchar(20),	-- End Date
	@contact_id				varchar(100),	-- Contact_id
    @generator_id_list varchar(max)=''  /* Added 2019-07-16 by AA */

AS

set nocount on

DECLARE	@sql		varchar(max),
	@execute_group 			varchar(max),
	@execute_order 			varchar(max),
	@generator_login_list	varchar(max),
	@intCount 				int,
	@count_cust				int,
	@genCount				int,
	@custCount				int,
	@where					varchar(max),
	@starttime				datetime

set @starttime = getdate()
declare @start_of_results int
declare @end_of_results int
declare @zero_based_index_offset int

-- Handle text inputs into temp tables
	CREATE TABLE #Customer_id_list (ID int)
	CREATE INDEX idx1 ON #Customer_id_list (ID)
	Insert #Customer_id_list select convert(int, row) from dbo.fn_SplitXsvText(',', 0, @customer_id_list) where isnull(row, '') <> ''

	CREATE TABLE #confirmation_list (confirmation_id int)
	CREATE INDEX idx3 ON #confirmation_list (confirmation_id)
	Insert #confirmation_list select row from dbo.fn_SplitXsvText(',', 1, @confirmation_id) where isnull(row, '') <> ''

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

		Select cg.generator_id from CustomerGenerator cg
			INNER JOIN ContactXRef cxr ON cxr.customer_id = cg.customer_id
				AND cxr.customer_id is not null
				AND cxr.type = 'C'
				AND cxr.status = 'A'
				AND cxr.web_access = 'A'
			INNER JOIN Customer c ON c.customer_ID = cg.customer_id
			WHERE cxr.contact_id = convert(int, @contact_id)
			AND c.generator_flag = 'T'
	END
	ELSE -- For Associates:
	BEGIN
	
		if exists (select id from #customer_id_list where id is not null)
			INSERT INTO #customer select id from #customer_id_list where id is not null
		else
			INSERT INTO #customer select customer_id from customer where customer_id is not null
			
		IF @debug >= 1 PRINT 'SELECT FROM #customer'
		IF @debug >= 1 SELECT * FROM #customer


--		if exists (select id from #generator_id_list where id is not null)
--			INSERT INTO #generator select id from #generator_id_list where id is not null
--		else
--			INSERT INTO #generator select generator_id from generator where generator_id is not null
			
		--IF @debug >= 1 PRINT 'SELECT FROM #generator'
		--IF @debug >= 1 SELECT * FROM #generator
	END

	-- Time saver?
	-- Eliminate #customer/#generator records that won't be found when @customer_id_list
	-- or @generator_id_list are specified:

	IF (select count(*) from #customer_id_list) > 0
		DELETE from #customer where customer_id not in (select id from #customer_id_list)
		
--	IF (select count(*) from #generator_id_list) > 0
--		DELETE from #generator where generator_id not in (select id from #generator_id_list)

	select @custCount = count(*) from #customer
	--select @genCount = count(*) from #generator	

    IF @debug >= 1 PRINT '@custCount:  ' + convert(varchar(20), @custCount)
    IF @debug >= 1 PRINT '@genCount:  ' + convert(varchar(20), @genCount)
	if @debug >= 1 print 'Elapsed time: ' + convert(varchar(20), datediff(ms, @starttime, getdate())) + 'ms'


	if @debug >= 1 BEGIN
		SELECT '#customer', * FROM #customer
		--SELECT '#generator', * FROM #generator
	END



	-- abort if there's nothing possible to see
	if @custCount + 
		@genCount + 
		len(ltrim(rtrim(isnull(@start_date, '')))) +
		len(ltrim(rtrim(isnull(@end_date, ''))))
		= 0 RETURN


set @sql = '
	SELECT Distinct
	s.company_id,
	s.profit_ctr_id,
	s.confirmation_ID,
	case when s.approval_code = ''VARIOUS'' then s.confirmation_id else null end as approved_confirmation_id,
	s.time_scheduled,
	s.quantity,
	s.approval_code,
	p.customer_id,
	s.contact,
	s.contact_company,
	s.contact_fax,
	s.load_type,
	g.generator_id,
	g.epa_id,
	g.generator_name,
	p.approval_desc,
	s.contact_phone,
	p.OTS_flag,
	u.name
FROM schedule s
    inner join profile p on s.profile_id = p.profile_id
	left outer join generator g on p.generator_id = g.generator_id
	left outer join USE_Profitcenter u
		on s.company_id = u.company_id
		and s.profit_ctr_id = u.profit_ctr_id
	'

set @sql = @sql + '
WHERE 1=1 
'

	if isnull(@confirmation_id, '') <> ''
		set @sql = @sql + 'AND (s.confirmation_id in (select confirmation_id from #confirmation_list))
		'

	if isnull(@customer_id_list, '') <> ''
		set @sql = @sql + 'AND (p.customer_id in (select id from #customer_id_list))
		'

	if len(@start_date) > 0 or len(@end_date) > 0
		set @sql = @sql + 'AND (s.time_scheduled between coalesce(nullif(''' + @start_date + ''',''''), s.time_scheduled) and coalesce(nullif(''' + @end_date + ''',''''), s.time_scheduled) ) '

	if @contact_id > 0 
		set @sql = @sql + 'AND (p.customer_id in (select customer_id from #customer)
							 OR
							 p.generator_id in (select generator_id from #generator)
						) 
						/* this is to guarantee there are no profiles for other customers, in this confirmation: */
						AND (select count(*) from scheduleapproval s2 inner join profile sp2 on s2.profile_id = sp2.profile_id where s2.confirmation_id = s.confirmation_id
						AND (sp2.customer_id not in (select customer_id from #customer)
						) 
						) = 0
						'
 		
set @sql = @sql + '		
	and s.status = ''A'' 
	AND p.curr_status_code = ''A'' 
ORDER BY s.company_id, s.profit_ctr_id, s.time_scheduled 

'

if @debug > 0 select (@sql)

exec (@sql)


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_reports_schedule] TO PUBLIC
    AS [dbo];


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_reports_schedule] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_reports_schedule] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_reports_schedule] TO [EQAI]
    AS [dbo];

