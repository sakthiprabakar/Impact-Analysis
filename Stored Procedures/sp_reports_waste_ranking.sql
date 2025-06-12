CREATE PROCEDURE [dbo].[sp_reports_waste_ranking]
/*
	@debug						int = 0 			-- 0 or 1 for no debug/debug mode
	, @customer_id_list			varchar(max) = '-1'	-- Comma Separated Customer ID List - what customers to include
	,
*/	
	@generator_id_list		varchar(max) = '-1'	-- Comma Separated Generator ID List - what generators to include
/*	
	, @site_type_list			varchar(max) = ''
	, @generator_state_list		varchar(max) = ''
	, @generator_country_list	varchar(max) = ''
*/	
	, @start_date				datetime = NULL	-- Service Start Date
	, @end_date					datetime = NULL	-- Service End Date
	, @group_by					varchar(max) = 'waste stream'
	, @result_count				int = 20
	, @total_field				varchar(max) = 'total_pounds'
--	, @report_type				char(1),		-- Group report by 'A'pproval or 'G'enerator
	, @contact_id				int = 0	-- Contact_id
--	, @level					char(1) = 'S'	-- 'S'ummary or 'D'etail
as

/****************************************************************************************************
sp_reports_waste_ranking:

Returns the data for Waste Ranking Report.

LOAD TO PLT_AI*

10/27/2017 JPB	Created from sp_reports_waste_summary

exec sp_reports_waste_ranking
	@start_date				= '1/1/2017'	-- Service Start Date
	, @end_date				= '12/31/2019'	-- Service End Date
	, @group_by				= 'waste type'
	, @result_count			= 20
	, @total_field			= 'total_pounds'
	, @generator_id_list	= '169151'
	, @contact_id		= -1 -- associates


****************************************************************************************************/
SET NOCOUNT ON
SET ANSI_WARNINGS OFF
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

-- Avoid bad trans plan caching:
declare
	@i_debug					int = 0
	, @i_customer_id_list		varchar(max)
	, @i_generator_id_list		varchar(max) = @generator_id_list
	, @i_site_type_list			varchar(max)
	, @i_generator_state_list	varchar(max)
	, @i_generator_country_list	varchar(max)
	, @d_serv_start_date		datetime
	, @d_serv_end_date			datetime
	, @i_serv_start_date		varchar(40)
	, @i_serv_end_date			varchar(40)
	, @i_contact_id				varchar(10) = convert(varchar(10), @contact_id)

-- Handle text inputs into temp tables
	CREATE TABLE #Generator (generator_id int)
	INSERT #Generator 
	EXEC sp_reports_generator_criteria_master
	@customer_id_list			= @i_customer_id_list
	, @generator_id_list		= @i_generator_id_list
	, @site_type_list			= @i_site_Type_list
	, @generator_state_list		= @i_generator_state_list
	, @generator_country_list	= @i_generator_country_list
	, @contact_id				= @i_contact_id


-- internals
declare	@execute_sql		varchar(max) = '',
	@execute_group 			varchar(max) = '',
	@execute_order 			varchar(max) = '',
	@generator_login_list	varchar(max) = '',
	@genCount				int = 0,
	@where					varchar(max) = '',
	@starttime				datetime = getdate(),
	@session_added			datetime = getdate(),
	@date_where				varchar(max) = '',
	@workorder_access_filter varchar(max) = '',
	@sql_wo_disposal_join	varchar(max) = '',
	@sql_wo_service_join	varchar(max) = ''

-- date cleanup
select
	@d_serv_start_date		= isnull(@start_date, dateadd(m, -6, getdate())),
	@d_serv_end_date		= isnull(@end_date, getdate()),
	@d_serv_end_date		= case when datepart(hh, @d_serv_end_date) = '0' and datepart(n, @d_serv_end_date) = '0' then 
								@d_serv_end_date + 0.99999 else @d_serv_end_date end,
	@i_serv_start_date		= convert(varchar(40), @d_serv_start_date, 121),
	@i_serv_end_date		= convert(varchar(40), @d_serv_end_date, 121)


if @i_debug > 3 select datediff(ms, @starttime, getdate()) as timer, 'Before Var setup' as description


	select @genCount = count(*) from #generator	

    IF @i_debug >= 1 PRINT '@genCount:  ' + convert(varchar(20), @genCount)
	if @i_debug >= 1 print 'Elapsed time: ' + convert(varchar(20), datediff(ms, @starttime, getdate())) + 'ms'


	if @i_debug >= 1 SELECT '#generator', * FROM #generator

	-- abort if there's nothing possible to see
	if @genCount = 0
	or len(ltrim(rtrim(isnull(@i_serv_start_date, '')))) +
		len(ltrim(rtrim(isnull(@i_serv_end_date, '')))) 
		= 0 RETURN


	CREATE TABLE #Work_WasteReceivedSummaryListResult_min (
		[company_id] [int] NULL,
		[profit_ctr_id] [int] NULL,
		receipt_id int null,
		resource_type char(1) null,
		line_id int null,
		tsdf_code	varchar(15) null,
		[customer_id] [int] NULL,
		[approval_code] [varchar](40) NULL,
		[profile_id] [int] NULL,
		[waste_description] [varchar](150) NULL,
		[haz_flag] [char](1) NULL,
		[generator_id] [int] NULL,
		wastetype_id int null,
		treatment_process_id int null,
		disposal_service_id int null,
		[total_pounds] [float] NULL,
		[total_charges] money NULL,
		[mode] [varchar](20) NULL
	)


-----------------------------------------
-------		Receipt Data:	--------
-----------------------------------------
	-- Create #access_filter table to hold subset of fields (quicker to run queries this way?)
		CREATE TABLE #access_filter (
			company_id				int, 
			profit_ctr_id			int, 
			receipt_id				int,
			line_id					int,
			source					char(1)
		)
	
	-- Create Where clause to be used on Inbound waste queries:
		SET @where = ' WHERE 1=1 '
	
		-- For everyone:
--		IF (select count(*) from #customer_id_list) > 0
--			SET @where = @where + ' AND ( r.customer_id IN (select id from #customer_id_list) ) '

		IF (select count(*) from #generator) > 0
			SET @where = @where + ' AND ( wss.generator_id IN (select generator_id from #generator) ) '
	
	-- service date
		IF LEN(@i_serv_start_date) > 0 OR LEN(@i_serv_end_date) > 0
		BEGIN
		-- This is lousy.
			SET @where = @where + ' AND ( 
				wss.service_date BETWEEN COALESCE(NULLIF(''' + @i_serv_start_date + ''',''''), r.receipt_date) AND COALESCE(NULLIF(''' + @i_serv_end_date + ''',''''), r.receipt_date) 
				) '
		END

		SET @where = @where + ' 
			AND r.submitted_flag = ''T'' 
			AND r.trans_type = ''D'' 
			AND r.receipt_status = ''A'' 
			AND pfc.status = ''A'' 
			AND pfc.view_on_web IN (''P'', ''C'') 
			AND pfc.view_waste_summary_on_web = ''T'' 
			AND cpy.view_on_web = ''T'' 
			'

		SET @where = @where + ' AND NOT EXISTS (
			select 1 
			from #access_filter 
			where receipt_id = r.receipt_id 
			and line_id = r.line_id 
			and company_id = r.company_id 
			and profit_ctr_id = r.profit_ctr_id) 
			'

	    IF @i_debug >= 1 PRINT '@where:  ' + @where

/*
		-- intermediate step: build a #access_filter table of the calculated columns:
	IF (select count(*) from #customer where customer_id <> -1) > 0 BEGIN
		SET @execute_sql = ' INSERT #access_filter SELECT --DISTINCT 
			r.company_id,
			r.profit_ctr_id,
			r.receipt_id,
			r.line_id,
			''C'' as source
			FROM Receipt r
			INNER JOIN WasteSummaryStats wss
			ON r.receipt_id = wss.receipt_id
				AND r.company_id = wss.company_id
				AND r.profit_ctr_id = wss.profit_ctr_id
				AND r.line_id = wss.line_id
				AND wss.trans_source = ''R''
				
			--INNER JOIN Billing bill ON
			--	r.receipt_id = bill.receipt_id
			--	AND r.company_id = bill.company_id
			--	AND r.profit_ctr_id = bill.profit_ctr_id
			--	AND r.line_id = bill.line_id
			--	AND bill.trans_source = ''R''
			--	AND bill.status_code = ''I''
			INNER JOIN Company cpy ON r.company_id = cpy.company_id
			INNER JOIN ProfitCenter pfc ON 
				r.company_id = pfc.company_id 
				and r.profit_ctr_id = pfc.profit_ctr_id
			-- INNER JOIN #customer customer_list ON customer_list.customer_id = r.customer_id
			' + @where
		
		IF @i_debug >= 1
		BEGIN
			PRINT @execute_sql
			
			PRINT ''
		END
		
		if @i_debug < 10
			EXEC(@execute_sql)
	END
*/
	
	if @i_debug >= 1 print 'Elapsed time: ' + convert(varchar(20), datediff(ms, @starttime, getdate())) + 'ms'

	IF (select count(*) from #generator where generator_id <> -1) > 0 BEGIN
		SET @execute_sql = ' 
		INSERT #access_filter 
		SELECT DISTINCT
			r.company_id,
			r.profit_ctr_id,
			r.receipt_id,
			r.line_id,
			''G'' as source
			FROM Receipt r
			INNER JOIN WasteSummaryStats wss
			ON r.receipt_id = wss.receipt_id
				AND r.company_id = wss.company_id
				AND r.profit_ctr_id = wss.profit_ctr_id
				AND r.line_id = wss.line_id
				AND wss.trans_source = ''R''
			--INNER JOIN Billing bill ON
			--	r.receipt_id = bill.receipt_id
			--	AND r.company_id = bill.company_id
			--	AND r.profit_ctr_id = bill.profit_ctr_id
			--	AND r.line_id = bill.line_id
			--	AND bill.trans_source = ''R''
			--	AND bill.status_code = ''I''
			INNER JOIN Company cpy ON r.company_id = cpy.company_id
			INNER JOIN ProfitCenter pfc ON 
				r.company_id = pfc.company_id 
				and r.profit_ctr_id = pfc.profit_ctr_id
			INNER JOIN #generator gen ON gen.generator_id = wss.generator_id
			' + @where + ''

		IF @i_debug >= 1
		BEGIN
			PRINT @execute_sql
			PRINT ''
		END
		
		if @i_debug < 10
			EXEC(@execute_sql)

	END

	if @i_debug >= 1 print 'Elapsed time: ' + convert(varchar(20), datediff(ms, @starttime, getdate())) + 'ms'

	select distinct * into #a from #access_filter
	truncate table #access_filter
	insert #access_filter select * from #a

	-- create index idx_temp on #access_filter(company_id, profit_ctr_id, receipt_id)

	IF @i_debug >= 1 and 1000 > (select count(*) from #access_filter)
	BEGIN
		-- SELECT '#customer_id_list', * FROM #customer_id_list 	
		SELECT '#access_filter', * FROM #access_filter
	END

	if (select count(*) from #access_filter) > 0 begin


		-- Group Option Specific Code:		
		--IF @report_type = 'A'
		--BEGIN	-- Group by Approval
			-- final step: build query to populate Work_WasteReceivedSummaryListResult from #access_filter 
			
			SET @execute_sql = ' INSERT #Work_WasteReceivedSummaryListResult_min
				(company_id, 
					profit_ctr_id, 
					receipt_id,
					line_id,
					customer_id, 
					approval_code, 
					profile_id,
					waste_description, 
					haz_flag, 
					generator_id, 
					wastetype_id,
					treatment_process_id,
					disposal_service_id,
					total_pounds, 
					total_charges,
					mode)
			SELECT 
				wss.company_id,
				wss.profit_ctr_id,
				wss.receipt_id,
				wss.line_id,
				wss.customer_id,
				pqa.approval_code,
				wss.profile_id,
				convert(varchar(150), ltrim(rtrim(isnull(p.approval_desc, '''')))) as waste_description,
				wss.haz_flag,
				wss.generator_id,
				wss.wastetype_id,
				wss.treatment_process_id,
				wss.disposal_service_id,
				wss.pounds, 
				wss.charges,
				''Inbound'' as mode
			FROM #access_filter t
			inner join WasteSummaryStats wss (nolock) on 
				t.receipt_id = wss.receipt_id 
				and t.line_id = wss.line_id
				and t.company_id = wss.company_id 
				and t.profit_ctr_id = wss.profit_ctr_id
				and wss.trans_source = ''R''
			INNER JOIN Profile P ON wss.profile_id = p.profile_id
			INNER JOIN ProfileQuoteApproval PQA ON wss.profile_id = pqa.profile_id
				AND wss.profit_ctr_id = PQA.profit_ctr_id
				AND wss.company_id = PQA.company_id
		'

		-- -- -- -- -- -- --
		-- debugging: Control whether this part of the SP runs
		IF 1=1 BEGIN
		-- -- -- -- -- -- --

		if @i_debug between 5 and 10 and 1000 > (select count(*) from #access_filter)
			SELECT 'access_filter' as table_name, * from #access_filter

		IF @i_debug >= 1
		BEGIN
			PRINT @execute_sql
			PRINT ''
		END

		if @i_debug < 10
			EXEC(@execute_sql)
		if @i_debug >= 1 print 'Elapsed time: ' + convert(varchar(20), datediff(ms, @starttime, getdate())) + 'ms'


		if @i_debug between 5 and 10
			SELECT 'WasteSummary' as table_name, * from #Work_WasteReceivedSummaryListResult_min
			
		-- -- -- -- -- -- --
		END
		-- -- -- -- -- -- --


	end

-- OUTBOUND (TSDF) WASTE DATA: --------------------------------------
-- OUTBOUND (TSDF) WASTE DATA: --------------------------------------
-- OUTBOUND (TSDF) WASTE DATA: --------------------------------------
-- OUTBOUND (TSDF) WASTE DATA: --------------------------------------
-- OUTBOUND (TSDF) WASTE DATA: --------------------------------------
-- OUTBOUND (TSDF) WASTE DATA: --------------------------------------
-- OUTBOUND (TSDF) WASTE DATA: --------------------------------------
-- OUTBOUND (TSDF) WASTE DATA: --------------------------------------  Hey, might THIS line be redundant?
-- OUTBOUND (TSDF) WASTE DATA: --------------------------------------

	-- Create #workorder_access_filter table to hold subset of fields (quicker to run queries this way?)
IF object_id('tempdb..#workorder_access_filter') is not null drop table #workorder_access_filter

		CREATE TABLE #workorder_access_filter (
			company_id				int, 
			profit_ctr_id			int, 
			workorder_id			int,
			resource_type			char(1),
			sequence_id				int,
			customer_id				int,
			generator_id			int,
			submitted_flag			char(1)
		)

		set @workorder_access_filter = ' INSERT INTO #workorder_access_filter(
			company_id, 
			profit_ctr_id, 
			workorder_id,
			resource_type,
			sequence_id,
			customer_id,
			generator_id,
			submitted_flag)
				SELECT DISTINCT
					wss.company_id, 
					wss.profit_ctr_id, 
					wss.receipt_id as workorder_id,
					wss.resource_type,
					wss.sequence_id,
					wss.customer_id,
					wss.generator_id,
					w.submitted_flag
				FROM 
			WasteSummaryStats wss
			INNER JOIN WorkOrderHeader w
			ON w.workorder_id = wss.receipt_id
				AND w.company_id = wss.company_id
				AND w.profit_ctr_id = wss.profit_ctr_id
				AND wss.trans_source = ''W''
			INNER JOIN tsdfapproval t ON t.tsdf_approval_id = wss.TSDF_Approval_ID
			INNER JOIN tsdf on wss.tsdf_code = tsdf.tsdf_code
			INNER JOIN Company cpy ON wss.company_id = cpy.company_id
			INNER JOIN ProfitCenter pfc ON wss.company_id = pfc.company_id 
				AND wss.profit_ctr_id = pfc.profit_ctr_id
				WHERE 1=1 '

--		IF (select count(*) from #customer_id_list) > 0
--			SET @workorder_access_filter = @workorder_access_filter + ' AND ( w.customer_id IN (select id from #customer_id_list) ) '

		IF (select count(*) from #generator) > 0
			SET @workorder_access_filter = @workorder_access_filter + ' 
			AND ( wss.generator_id IN (select generator_id from #generator) ) 
			'

		IF LEN(@i_serv_start_date) > 0 OR LEN(@i_serv_end_date) > 0
			SET @workorder_access_filter = @workorder_access_filter + ' 
			AND ( wss.service_date BETWEEN COALESCE(NULLIF(''' + @i_serv_start_date + ''',''''), w.end_date) AND COALESCE(NULLIF(''' + @i_serv_end_date + ''',''''), w.end_date)) 
			'

		SET @workorder_access_filter = @workorder_access_filter + '
			AND tsdf.eq_flag = ''F''
			AND w.submitted_flag = ''T''
			AND pfc.status = ''A''
			AND pfc.view_on_web IN (''P'', ''C'')
			AND pfc.view_workorders_on_web = ''T''
			AND cpy.VIEW_ON_WEB = ''T''
		'

	EXEC(@workorder_access_filter)
		if @i_debug >= 1 print 'Elapsed time: ' + convert(varchar(20), datediff(ms, @starttime, getdate())) + 'ms'

	IF @i_debug >= 1
	BEGIN
		
		PRINT @workorder_access_filter
		SELECT '#workorder_access_filter' as table_name, * from #workorder_access_filter
		PRINT ''
	END

	if (select count(*) from #workorder_access_filter) > 0 begin


			if @i_debug >= 1 print '(Starting Outbound logic) Elapsed time: ' + convert(varchar(20), datediff(ms, @starttime, getdate())) + 'ms'

				SET @execute_sql = '
				INSERT #Work_WasteReceivedSummaryListResult_min (
					company_id, 
					profit_ctr_id, 
					receipt_id,
					resource_type,
					line_id,
					tsdf_code,
					customer_id, 
					approval_code, 
					profile_id,
					waste_description, 
					haz_flag, 
					generator_id, 
					wastetype_id,
					treatment_process_id,
					disposal_service_id,
					total_pounds, 
					total_charges,
					mode					
				)
				SELECT DISTINCT
					wss.company_id,
					wss.profit_ctr_id,
					wss.receipt_id,
					wss.resource_type,
					wss.sequence_id,
					wss.tsdf_code,
					wss.customer_id,
					t.tsdf_approval_code as approval_code,
					wss.tsdf_approval_id as profile_id,
					convert(varchar(150), ltrim(rtrim(isnull(t.waste_desc, '''')))) as waste_description,
					wss.haz_flag,
					wss.generator_id,
					wss.wastetype_id,
					wss.treatment_process_id,
					wss.disposal_service_id,
					wss.pounds, 
					wss.charges,
					''Outbound'' as mode
					'				
											
			-- END	-- Group by Approval

			-- Add FROM clause and the beginning of the WHERE clause (that's common to both report types)
			SET @sql_wo_service_join = @execute_sql + '
				FROM #workorder_access_filter waf
				inner join WasteSummaryStats wss
					on wss.trans_source = ''W''
					and waf.workorder_id = wss.receipt_id
					and waf.company_id = wss.company_id
					and waf.profit_ctr_id = wss.profit_ctr_id
					and waf.resource_type = wss.resource_type
					and waf.sequence_id = wss.sequence_id
					AND wss.resource_type <> ''D''
					INNER JOIN tsdfapproval t ON t.tsdf_approval_id = wss.TSDF_Approval_ID
					INNER JOIN tsdf on t.tsdf_code = wss.tsdf_code and tsdf.tsdf_code = t.tsdf_code
				WHERE 1=1 '

			
				SET @sql_wo_disposal_join = @execute_sql + '
					FROM #workorder_access_filter waf
				inner join WasteSummaryStats wss
					on wss.trans_source = ''W''
					and waf.workorder_id = wss.receipt_id
					and waf.company_id = wss.company_id
					and waf.profit_ctr_id = wss.profit_ctr_id
					and waf.resource_type = wss.resource_type
					and waf.sequence_id = wss.sequence_id
					AND wss.resource_type = ''D''
					INNER JOIN tsdfapproval t ON t.tsdf_approval_id = wss.TSDF_Approval_ID
					INNER JOIN tsdf on t.tsdf_code = wss.tsdf_code and tsdf.tsdf_code = t.tsdf_code
				WHERE 1=1 '	
				
			
				SET @sql_wo_disposal_join = @sql_wo_disposal_join + '
					AND tsdf.eq_flag = ''F''
					AND waf.submitted_flag = ''T'' '
					
				SET @sql_wo_service_join = @sql_wo_service_join + '
					AND tsdf.eq_flag = ''F''
					AND waf.submitted_flag = ''T'' '
				

				--print @execute_sql



			-- -- -- -- -- -- --
			-- debugging: Control whether this part of the SP runs
			IF 1=1 BEGIN
			-- -- -- -- -- -- --

				IF @i_debug >= 1
				BEGIN
					PRINT 'svc join ' + @sql_wo_service_join
					PRINT ''
				END

				if @i_debug < 10
					EXEC(@sql_wo_service_join)
				if @i_debug >= 1 print 'Elapsed time: ' + convert(varchar(20), datediff(ms, @starttime, getdate())) + 'ms'

				IF @i_debug >= 1
				BEGIN
					PRINT 'disposal join ' + @sql_wo_disposal_join
					PRINT ''
				END

				if @i_debug < 10
					EXEC(@sql_wo_disposal_join)
					
				if @i_debug >= 1 print 'Elapsed time: ' + convert(varchar(20), datediff(ms, @starttime, getdate())) + 'ms'

			-- -- -- -- -- -- --
			END
			-- -- -- -- -- -- --

		--ELSE
		--if @i_debug >= 1 print '(Skipping Outbound logic) Elapsed time: ' + convert(varchar(20), datediff(ms, @starttime, getdate())) + 'ms'
		-- END
	end

if @i_debug > = 1
SELECT * FROM #Work_WasteReceivedSummaryListResult_min

set @execute_sql = ''

if @group_by = 'waste stream' begin
	set @execute_sql = '
		select /* top N */
			rank() over ( /* order by */ ) as _rank
			--, r.company_id
			--, r.profit_ctr_id
			--, r.tsdf_code
			--, r.profile_id
			--, r.approval_code
			, r.waste_description as _description
			--, wt.category as wastetype_category
			--, wt.description as wastetype_description
			--, ds.disposal_service_desc
			, r.haz_flag
			, /* total field */ as _total
		from #Work_WasteReceivedSummaryListResult_min r
		left join WasteType wt on r.wastetype_id = wt.wastetype_id
		left join DisposalService ds on r.disposal_service_id = ds.disposal_service_id
		group by 
			--r.company_id
			--, r.profit_ctr_id
			--, r.tsdf_code
			--, r.profile_id
			--, r.approval_code
			r.waste_description
			--, wt.category
			--, wt.description
			--, ds.disposal_service_desc
			, r.haz_flag
		/* compute sum(total_pounds) */
			/* order by */
'
end

if @group_by = 'waste type' begin
	set @execute_sql = '
		select /* top N */
			rank() over ( /* order by */ ) as _rank
			--, r.generator_id
			--, r.company_id
			--, r.profit_ctr_id
			--, r.tsdf_code
			--, r.profile_id
			--, r.approval_code
			--, r.waste_description
			--, wt.category as wastetype_category
			, wt.description as _description
			--, ds.disposal_service_desc
			, r.haz_flag
			, /* total field */ as _total
		from #Work_WasteReceivedSummaryListResult_min r
		left join WasteType wt on r.wastetype_id = wt.wastetype_id
		left join DisposalService ds on r.disposal_service_id = ds.disposal_service_id
		group by 
			--, r.generator_id
			--, r.company_id
			--, r.profit_ctr_id
			--, r.tsdf_code
			--, r.profile_id
			--, r.approval_code
			--, r.waste_description
			--, wt.category
			wt.description
			--, ds.disposal_service_desc
			, r.haz_flag
		/* compute sum(total_pounds) */
			/* order by */
'
end

if @group_by = 'waste category' begin
	set @execute_sql = '
		select /* top N */
			rank() over ( /* order by */ ) as _rank
			--, r.generator_id
			--, r.company_id
			--, r.profit_ctr_id
			--, r.tsdf_code
			--, r.profile_id
			--, r.approval_code
			--, r.waste_description
			, wt.category as _description
			--, wt.description as wastetype_description
			--, ds.disposal_service_desc
			, r.haz_flag
			, /* total field */ as _total
		from #Work_WasteReceivedSummaryListResult_min r
		left join WasteType wt on r.wastetype_id = wt.wastetype_id
		left join DisposalService ds on r.disposal_service_id = ds.disposal_service_id
		group by 
			--, r.generator_id
			--, r.company_id
			--, r.profit_ctr_id
			--, r.tsdf_code
			--, r.profile_id
			--, r.approval_code
			--, r.waste_description
			wt.category
			--, wt.description
			--, ds.disposal_service_desc
			, r.haz_flag
		/* compute sum(total_pounds) */
			/* order by */
'
end


if @group_by = 'disposal service' begin
	set @execute_sql = '
		select /* top N */
			rank() over ( /* order by */ ) as _rank
			--, r.generator_id
			--, r.company_id
			--, r.profit_ctr_id
			--, r.tsdf_code
			--, r.profile_id
			--, r.approval_code
			--, r.waste_description
			--, wt.category as wastetype_category
			--, wt.description as wastetype_description
			, ds.disposal_service_desc as _description
			, r.haz_flag
			, /* total field */ as _total
		from #Work_WasteReceivedSummaryListResult_min r
		left join WasteType wt on r.wastetype_id = wt.wastetype_id
		left join DisposalService ds on r.disposal_service_id = ds.disposal_service_id
		group by 
			--, r.generator_id
			--, r.company_id
			--, r.profit_ctr_id
			--, r.tsdf_code
			--, r.profile_id
			--, r.approval_code
			--, r.waste_description
			--, wt.category
			--, wt.description
			ds.disposal_service_desc
			, r.haz_flag
		/* compute sum(total_pounds) */
			/* order by */
'
end

/*

	set @execute_sql = '
		select /* top N */
			rank() over ( /* order by */ ) as _rank
			, r.generator_id
			, r.company_id
			, r.profit_ctr_id
			, r.tsdf_code
			, r.profile_id
			, r.approval_code
			, r.waste_description
			, wt.category as wastetype_category
			, wt.description as wastetype_description
			, ds.disposal_service_desc
			, r.haz_flag
			, /* total field */ /* this will be r.total_pounds or dollars */
		from #Work_WasteReceivedSummaryListResult_min r
		left join WasteType wt on r.wastetype_id = wt.wastetype_id
		left join DisposalService ds on r.disposal_service_id = ds.disposal_service_id
		group by
			r.generator_id
			, r.company_id
			, r.profit_ctr_id
			, r.tsdf_code
			, r.profile_id
			, r.approval_code
			, r.waste_description
			, wt.category
			, wt.description
			, ds.disposal_service_desc
			, r.haz_flag
		/* compute sum(total_pounds) */
			/* order by */
'
*/
if @i_debug >= 1
	select @execute_sql
	
if @execute_sql <> '' begin
	set @execute_sql = replace(@execute_sql, '/* top N */', 'TOP ' + convert(varchar(5), @result_count))
	set @execute_sql = replace(@execute_sql, '/* total field */', 'SUM(' + @total_field + ') ')
	set @execute_sql = replace(@execute_sql, '/* order by */', ' order by SUM(' + @total_field + ') desc ')

if @i_debug >= 1
	select @execute_sql

	exec(@execute_sql)
end


/*

-- '

*/

if @i_debug >= 1 print 'Elapsed time: ' + convert(varchar(20), datediff(ms, @starttime, getdate())) + 'ms'


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_reports_waste_ranking] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_reports_waste_ranking] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_reports_waste_ranking] TO [EQAI]
    AS [dbo];

