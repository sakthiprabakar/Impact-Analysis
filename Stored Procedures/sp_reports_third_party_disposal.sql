CREATE PROCEDURE sp_reports_third_party_disposal (
    @debug					int = 0					-- 0 or 1 for no debug/debug mode
	, @database_list		varchar(max) = NULL		-- Comma Separated Company List
    , @customer_id_list		varchar(max) = NULL		-- Comma Separated Customer ID List - what customers to include
    , @generator_id_list	varchar(max) = NULL		-- Comma Separated Generator ID List - what generators to include
    , @trip_id_list			varchar(max) = NULL		-- Comma Separated Trip ID List - what trips to include
    , @start_date1			varchar(20) = NULL		-- Beginning Start Date
    , @start_date2			varchar(20) = NULL		-- Ending Start Date
    , @site_code_list		varchar(max) = NULL		-- Generator Site Code List
    , @site_type_list		varchar(max) = NULL		-- Generator Site Type List
    , @tsdf_code_list		varchar(max) = NULL		-- TSDF Code List
)
AS

/* -------------------------------------------------------------------------------
sp_reports_third_party_disposal
----------------------------------------------------------------------------------
This procedure validated several aspects of a trip for a validation report
Loads to PLT_AI

	03/01/2013 JPB	Copied from sp_trip_validate to make into sp_reports_third_party_disposal on EQIP
	01/05/2017 JPB	GEM-39851 - Adding new output fields to the report for Generator DEA ID and TSDF Approval: Reference ID

Sample:
	sp_reports_third_party_disposal @debug=0, @trip_id_list = '2731' -- Example trip, happens to be EQ
	sp_reports_third_party_disposal @debug=1, @trip_id_list = '16246' -- Example trip, Non EQ
	
	sp_reports_third_party_disposal @debug=1, @start_date1 = '1/1/2011', @start_date2 = '12/31/2012',  @tsdf_code_list = 'EEI'
	sp_reports_third_party_disposal @debug=0, @start_date1 = '1/1/2016', @start_date2 = '12/31/2017',  @tsdf_code_list = 'USECOLOGYNV'
	-- 12300, 31s
	sp_reports_third_party_disposal @debug=1, @start_date1 = '1/1/2012', @start_date2 = '12/31/2012', @customer_id_list = '4077'
	-- 39369, 1:29
	sp_reports_third_party_disposal @debug=1, @start_date1 = '10/1/2012', @start_date2 = '10/31/2012', @customer_id_list = '10673', @tsdf_code_list = 'EQOK'
	-- 18404, 47

sp_columns tsdfapproval
select top 100 
tsdfapproval.AESOP_waste_stream + '-' + convert(varchar(20), tsdfapproval.AESOP_profile_id)
, g.dea_id
, wd.* from workorderdetail wd
inner join workorderheader wh on wd.workorder_id = wh.workorder_id and wd.company_id = wh.company_id and wd.profit_ctr_id = wh.profit_ctr_id
inner join tsdfapproval on wd.tsdf_approval_id = tsdfapproval.tsdf_approval_id and wd.company_id = tsdfapproval.company_id 
inner join generator g on wh.generator_id = g.generator_id
where wd.tsdf_approval_id is not null 
and g.dea_id is not null
order by wd.date_added desc

-- Scratch:	
SELECT * FROM tsdf where tsdf_code like '%EEI%'
------------------------------------------------------------------------------- */

declare @timer datetime = getdate()

-- The only good way to handle the various search options possible is to EXECute a @sql string
-- Have been over this wheel many times, no need to re-invent it now. Just copying logic
-- from sp_reports_workorders

	create table #access_filter (
		company_id int, 
		profit_ctr_id int, 
		workorder_id int, 
		resource_type	char(1),
		sequence_id	int
	)		
	
	-- Database List: (expects x|y, x1|y1 format list)
		create table #database_list (company_id int, profit_ctr_id int)
		if datalength((@database_list)) > 0 begin
			declare @scrub table (dbname varchar(10), company_id int, profit_ctr_id int)

			-- Split the input list into the scub table's dbname column
			insert @scrub select row as dbname, null, null from dbo.fn_SplitXsvText(',', 1, @database_list) where isnull(row, '') <> ''

			-- Split the CO|PC values in dbname into company_id, profit_ctr_id: company_id first.
			update @scrub set company_id = convert(int, case when charindex('|', dbname) > 0 then left(dbname, charindex('|', dbname)-1) else dbname end) where dbname like '%|%'

			-- Split the CO|PC values in dbname into company_id, profit_ctr_id: profit_ctr_id's turn
			update @scrub set profit_ctr_id = convert(int, replace(dbname, convert(varchar(10), company_id) + '|', '')) where dbname like '%|%'

			-- Put the remaining, valid (process_flag = 0) scrub table results into #profitcenter_list
			insert #database_list
			select distinct company_id, profit_ctr_id from @scrub where company_id is not null and profit_ctr_id is not null
		end

	-- Customer IDs:
		create table #Customer_id_list (customer_id int)
		if datalength((@customer_id_list)) > 0 begin
			Insert #Customer_id_list
			select convert(int, row) from dbo.fn_SplitXsvText(',', 0, @customer_id_list)
			where isnull(row, '') <> ''
		end

	-- Generator IDs:
		create table #generator_id_list (generator_id int)
		if datalength((@generator_id_list)) > 0 begin
			Insert #generator_id_list
			select convert(int, row) from dbo.fn_SplitXsvText(',', 0, @generator_id_list)
			where isnull(row, '') <> ''
		end

	-- Trip IDs:
		create table #trip (trip_id int)
		set @trip_id_list = replace(@trip_id_list, ' ', ',')
		if len(ltrim(isnull(@trip_id_list, ''))) > 0 begin
			insert #Trip
			select convert(int, row) from dbo.fn_SplitXsvText(',', 1, @trip_id_list)
			where isnull(row, '') <> ''
		end

    -- Generator Site Codes
		create table #site_code_list (site_code varchar(16))
		if datalength((@site_code_list)) > 0 begin
			Insert #site_code_list
			select row from dbo.fn_SplitXsvText(',', 1, @site_code_list)
			where isnull(row, '') <> ''
		end

    -- Generator Type Codes
		create table #site_type_list (site_type varchar(40))
		if datalength((@site_type_list)) > 0 begin
			Insert #site_type_list
			select row from dbo.fn_SplitXsvText(',', 1, @site_type_list)
			where isnull(row, '') <> ''
		end

    -- TSDF Codes
		create table #tsdf_code_list (tsdf_code varchar(15))
		if datalength((@tsdf_code_list)) > 0 begin
			Insert #tsdf_code_list
			select row from dbo.fn_SplitXsvText(',', 1, @tsdf_code_list)
			where isnull(row, '') <> ''
		end

	-- If @start_date1 is given, @start_date2 is required.  And vice-versa
	if (@start_date1 is not null and @start_date2 is null) or (@start_date2 is not null and @start_date1 is null)
		return 'Error: start_date and end_date are required together'

	if @start_date1 is not null
		if isdate(@start_date1) = 0
			return 'Error: start_date must be a valid date'

	if @start_date2 is not null
		if isdate(@start_date2) = 0
			return 'Error: end_date must be a valid date'

if @debug > 0
	select 'setup' as step_finished, null as records_affected, datediff(ms, @timer, getdate()) / 1000.00 as elapsed_time_from_start

-- Abort early if there's just nothing to do here (no criteria given.  Criteria is required)
-- May need to revise this list, if some of them are always given, but meaningless.
    if 0 -- just for nicer formatting below...
        + (select count(*) from #customer_id_list)
        + (select count(*) from #generator_id_list)
        + (select count(*) from #trip)
        + (select count(*) from #site_code_list)
        + (select count(*) from #site_type_list)
        + (select count(*) from #tsdf_code_list)
        + datalength(ltrim(rtrim(isnull(@start_date1, '')))) 
        + datalength(ltrim(rtrim(isnull(@start_date2, '')))) 
    = 0 return


	
    declare @sql varchar(max) = '', @where varchar(max) = '', @groupby varchar(max) = ''

    set @sql = '
        insert #access_filter
            SELECT distinct w2.company_id, 
            w2.profit_ctr_id, 
            w2.workorder_id, 
            wod2.resource_type,
            wod2.sequence_id
        from workorderheader w2 (nolock)
        INNER JOIN Generator g (nolock) ON g.generator_id = w2.generator_id 
        inner join WorkOrderDetail wod2 (nolock) ON w2.workorder_id = wod2.workorder_id and w2.company_id = wod2.company_id and w2.profit_ctr_id = wod2.profit_ctr_id 
        /* 
        Testing: Dont require 3rd party tsdf
		inner join tsdf tsdf on tsdf.tsdf_code = wod2.TSDF_code and isnull(tsdf.eq_flag, ''F'') = ''F''
		*/
        '

    if (select count(*) from #customer_id_list) > 0
        set @sql = @sql + 'inner join #customer_id_list cil on w2.customer_id = cil.customer_id '

    if (select count(*) from #generator_id_list) > 0
        set @sql = @sql + ' inner join #generator_id_list gil on w2.generator_id = gil.generator_id '

    if (select count(*) from #database_list) > 0
        set @sql = @sql + ' inner join #database_list dl on w2.company_id = dl.company_id and w2.profit_ctr_id = dl.profit_ctr_id '

    if (select count(*) from #trip) > 0
        set @sql = @sql + ' inner join #trip trip ON w2.trip_id = trip.trip_id '

    if (select count(*) from #site_code_list) > 0
        set @sql = @sql + ' inner join #site_code_list gsc ON gsc.site_code = g.site_code '

    if (select count(*) from #site_type_list) > 0
        set @sql = @sql + ' inner join #site_type_list gst ON gst.site_type = g.site_type '

    if (select count(*) from #tsdf_code_list) > 0
        set @sql = @sql + ' inner join #tsdf_code_list tcl on wod2.tsdf_code = tcl.tsdf_code '

    set @where = @where + '
        WHERE 1=1 /* where-slug */
        AND w2.workorder_status NOT IN (''V'')
        AND (wod2.bill_rate > -2 OR (wod2.bill_rate = -2 AND wod2.resource_type = ''D''
				 and exists (
					Select 1 from workorderdetailunit (nolock) where
					workorder_id = wod2.workorder_ID and 
					sequence_id = wod2.sequence_id and
					company_id = wod2.company_id and
					profit_ctr_id = wod2.profit_ctr_ID and
					billing_flag = ''T'' and
					quantity > 0
				 )
        )) 
	    '
    
    if datalength(ltrim(@start_date1)) > 0
        set @where = replace(@where, '/* where-slug */', ' AND w2.start_date >= ''' + @start_date1 + ''' /* where-slug */')

    if datalength(ltrim(@start_date2)) > 0
        set @where = replace(@where, '/* where-slug */', ' AND w2.start_date <= ''' + @start_date2 + ''' /* where-slug */')


    -- Execute the sql that popoulates the #access_filter table.
    if @debug > 0 
		select @sql + @where + @groupby as access_filter_query

    exec(@sql + @where + @groupby)

if @debug > 0
	select 'access_filter' as step_finished, count(*) as records_affected, datediff(ms, @timer, getdate()) / 1000.00  as elapsed_time_from_start from #access_filter

	create index af_idx on #access_filter (workorder_id, company_id, profit_ctr_id, resource_type, sequence_id)

if @debug > 0
	select 'access_filter indexed' as step_finished, NULL as records_affected, datediff(ms, @timer, getdate())/ 1000.00  as elapsed_time_from_start

-- Found through trial/error/execution plan scheming that it's faster to simplify
-- output in a query by doing the straight-forward parts into one temp table,
-- then handling the complicated parts later.

	SELECT -- WorkOrderDetail.bill_rate > -2
		WorkorderHeader.trip_id,
		WorkorderHeader.trip_sequence_id,   
		WorkorderDetail.company_id,   
		WorkorderDetail.profit_ctr_ID,   
		WorkorderDetail.workorder_ID,   
		Customer.cust_name,   
		Customer.customer_ID,   
		Generator.generator_id,   
		Generator.generator_name,   
		Generator.generator_address_1,
		Generator.generator_address_2,
		Generator.generator_address_3,
		Generator.generator_address_4,
		Generator.generator_address_5,
		Generator.generator_city,
		Generator.generator_state,
		Generator.generator_zip_code,
		Generator.site_code,
		Generator.site_type,
		Generator.epa_id,
		Generator.DEA_ID,
		WorkorderDetail.DOT_shipping_name,   
		WorkorderDetail.TSDF_code,   
		WorkorderDetail.TSDF_approval_code,   
		WorkorderDetail.manifest,   
		WorkorderDetail.container_count,   
		WorkorderDetail.manifest_page_num,
		WorkorderDetail.manifest_line,
		WorkorderDetail.bill_rate,
		TSDF.TSDF_name,   
		WorkorderDetail.tsdf_approval_id,
		WorkorderDetail.profile_id,
		WorkorderDetail.resource_type,
		WorkorderDetail.sequence_ID,   
		WorkorderDetail.manifest_handling_code
		, WorkorderDetail.un_na_number
		, WorkorderDetail.container_code
	INTO #foo 
    FROM #access_filter af
        join WorkorderDetail (nolock) on WorkorderDetail.workorder_ID = af.workorder_ID  
			and WorkorderDetail.company_id = af.company_id  
			and WorkorderDetail.profit_ctr_ID = af.profit_ctr_ID    
			AND WorkorderDetail.resource_type = af.resource_type
			AND WorkorderDetail.sequence_id = af.sequence_id
		join WorkorderHeader (nolock) on WorkorderHeader.workorder_id = af.workorder_id 
			and WorkorderHeader.company_id = af.company_id 
			and WorkorderHeader.profit_ctr_id = af.profit_ctr_id
   		join Customer (nolock) on WorkorderHeader.customer_ID = Customer.customer_ID
        join TSDF (nolock) on WorkorderDetail.TSDF_code = TSDF.TSDF_code /* Testing - Don't Require Third Party: and isnull(tsdf.eq_flag, 'F') = 'F' */
		join Generator (nolock) on WorkorderHeader.generator_id = Generator.generator_id 

if @debug > 0
	select 'foo created' as step_finished, count(*) as records_affected, datediff(ms, @timer, getdate())/ 1000.00  as elapsed_time_from_start from #foo

	create index f_idx on #foo (workorder_id, company_id, profit_ctr_id, resource_type, sequence_id, tsdf_approval_id, profile_id, bill_rate)

if @debug > 0
	select 'foo indexed' as step_finished, NULL as records_affected, datediff(ms, @timer, getdate())/ 1000.00  as elapsed_time_from_start

-- Now the simple parts just come from the temp table
-- and the complicated parts get added in:
-- uh, yes... not everything that follows is "complicated". It goes here anyway.

 SELECT 
		f.manifest as tracking_number
		, f.manifest_line
		, f.generator_name as generator_site_name
		, f.generator_address_1
/*
		, f.generator_address_2
		, f.generator_address_3
		, f.generator_address_4
		, f.generator_address_5
*/		
		, f.generator_city
		, f.generator_state
		, f.generator_zip_code
		, f.site_code
		, f.epa_id
		, f.DEA_ID
		, f.TSDF_approval_code
		, coalesce(TSDFApproval.Waste_desc, profile.approval_desc) as approval_desc
		
		, isnull(tsdfapproval.AESOP_waste_stream, '')
			+ case when isnull(tsdfapproval.AESOP_waste_stream, '')<> '' and isnull(convert(varchar(20), tsdfapproval.AESOP_profile_id), '') <> '' THEN '-' ELSE '' END
			+ isnull(convert(varchar(20), tsdfapproval.AESOP_profile_id), '') 
			as TSDFApproval_ReferenceID

		/* This needs to be the top 6 waste codes */
		, dbo.fn_workorder_waste_code_list(f.workorder_id, f.company_id, f.profit_ctr_id, f.sequence_id) as epa_waste_codes

		, case when f.profile_id is not null then
			(
				select management_code 
				from treatmentheader th 
				inner join profilequoteapproval p 
					on p.treatment_id = th.treatment_id 
				inner join tsdf on f.tsdf_code = tsdf.tsdf_code
				where p.profile_id = f.profile_id 
				and p.company_id = tsdf.eq_company
				and p.profit_ctr_id = tsdf.eq_profit_ctr
			)
		else
			f.manifest_handling_code 
		end as epa_method_code
		, f.un_na_number
		, f.DOT_shipping_name
		, CASE WHEN isnull(wom.manifest_flag, '') = 'T' THEN wdu1.quantity ELSE NULL END as ship_quantity
		, CASE WHEN isnull(wom.manifest_flag, '') = 'T' THEN manbill.manifest_unit ELSE NULL END as man_uom
		, f.container_code as container_type
		, f.container_count
		, CASE WHEN wdu2.bill_unit_code = 'TONS' then (wdu2.quantity * 2000.0) ELSE wdu2.quantity END as pounds
		, f.trip_id

		, f.TSDF_code
		, f.TSDF_name
		, tsdf.tsdf_city
		, tsdf.tsdf_state
		, tsdf.tsdf_epa_id

-- EQ Fields:
/*		
		, f.company_id
		, f.profit_ctr_ID
		, f.trip_id
		, f.workorder_ID
		, f.cust_name
		, f.customer_ID
		, f.generator_id
		, f.manifest_page_num
		, f.sequence_ID
		, f.container_code
		, f.container_count
*/		
    FROM #foo f
        left outer join TSDFApproval (nolock) on 
			TSDFApproval.TSDF_APPROVAL_ID = f.TSDF_APPROVAL_ID
			and f.TSDF_APPROVAL_ID is not null 
		left outer join profile (nolock) on
			Profile.profile_id = f.profile_id
			and f.profile_id is not null
        Left outer Join WorkorderStop (nolock) on 
			WorkorderStop.workorder_ID = f.workorder_ID  
			and WorkorderStop.company_id = f.company_id  
			and WorkorderStop.profit_ctr_ID = f.profit_ctr_ID 
			and WorkorderStop.stop_sequence_id = 1
         Left Outer Join Workorderdetailunit wdu1 (nolock) on 
			wdu1.workorder_ID = f.workorder_ID
			and wdu1.company_id = f.company_id  
			and wdu1.profit_ctr_ID = f.profit_ctr_ID 	
			and wdu1.sequence_id = f.sequence_id 
			and wdu1.manifest_flag = 'T'
         Left Outer Join Workorderdetailunit wdu2 (nolock) on 
			wdu2.workorder_ID = f.workorder_ID
			and wdu2.company_id = f.company_id  
			and wdu2.profit_ctr_ID = f.profit_ctr_ID 	
			and wdu2.sequence_id = f.sequence_id 
			and wdu2.bill_unit_code in ('LBS', 'TONS')
		 Left Outer Join BillUnit manbill (nolock) on
			wdu1.bill_unit_code = manbill.bill_unit_code
		 Left Outer Join WorkorderManifest wom (nolock) on
			wom.workorder_ID = f.workorder_ID  
			and wom.company_id = f.company_id  
			and wom.profit_ctr_ID = f.profit_ctr_ID 
			and wom.manifest = f.manifest
			and wom.manifest_flag = 'T'
		left outer join TSDF tsdf (nolock) on
			f.tsdf_code = tsdf.tsdf_code
		 

-- For Ship QUantity and Man UOM, REQUIRE WOM.Manifest_flag = 'T'

-- For Ship QUantity and Man UOM, REQUIRE WOM.Manifest_flag = 'T'
-- Change field names to MANIFEST label names
-- This means results are only for manifest types, not BOLs.
-- Clean up the header from old version of SP
-- Add _'s to field names
-- Lin Number not manifest line number
-- get rid of scratch in comments.


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_reports_third_party_disposal] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_reports_third_party_disposal] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_reports_third_party_disposal] TO [EQAI]
    AS [dbo];

