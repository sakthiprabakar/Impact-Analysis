  create procedure sp_rpt_wm_trip_export (
      @trip_id_list   varchar(max) = null,
      @site_type_list varchar(max) = null,
      @site_code_list varchar(max) = null,
      @start_date     datetime = null,
      @end_date       datetime = null,
      @debug          int = 0
  ) as
  /* *************************************
  sp_rpt_wm_trip_export
      WM-formatted export of trip data.
      Accepts input: 
          list of trip_ids (optional)
          list of site types (optional)<title></title>
          start_date (optional) compares to trip arrive date
          end_date (optional) compares to trip arrive date
  
  9/9/2010 - JPB - Added Site Code List as an input.
  10/21/2010 - JPB - convert(varchar(20), datetime, xxx) WAS 112. Should've been 121. Fixed.
  10/22/2010 - JPB - wh.trip_act_arrive -> COALESCE(wh.trip_act_arrive, wh.start_date)
  11/17/2010 - JPB - Per Brie, if the Generation date data is missing, use the pickup date month/year.
  
  sp_rpt_wm_trip_export '', '', '', '2010/10/01', '2010/10/31', 0
  
  select distinct
	t.company_id,
	t.profit_ctr_id,
	t.workorder_id,
	t.resource_type,
	t.sequence_id,
	-- t.sub_sequence_id,
	convert(int,t.site_code),
	t.generator_city,
	t.generator_state,
	t.shipment_date,
	t.manifest,
	t.manifest_line as manifest_line,
	(
		select sum(x.weight)
		from EQ_Extract..WM_Trip_Export x
		where x.site_code = t.site_code
		and x.manifest = t.manifest
		and x.manifest_line = t.manifest_line
		and x.date_added = t.date_added
		and x.added_by = t.added_by
	) as trip_weight,
	(
		select sum(d.pounds)
		from EQ_Extract..WalmartDisposalExtract d
		where t.site_code = d.site_code
		and t.manifest = d.manifest
		and t.manifest_line = d.manifest_line
		and d.date_added = '2010-10-19 15:11:58.877'
		and d.added_by = 'jonathan'
	) as DISPOSAL_weight,
	(
		(
			select sum(x.weight)
			from EQ_Extract..WM_Trip_Export x
			where x.site_code = t.site_code
			and x.manifest = t.manifest
			and x.manifest_line = t.manifest_line
			and x.date_added = t.date_added
			and x.added_by = t.added_by
		) 
		-
		(
			select sum(d.pounds)
			from EQ_Extract..WalmartDisposalExtract d
			where t.site_code = d.site_code
			and t.manifest = d.manifest
			and t.manifest_line = d.manifest_line
			and d.date_added = '2010-10-19 15:11:58.877'
			and d.added_by = 'jonathan'
		)
	) as WEIGHT_DIFFERENCE
	from EQ_Extract..WM_Trip_Export t
	where t.date_added = '2010-11-02 18:31:49.550'
	and t.added_by = 'jonathan'
	and 	(
		select sum(x.weight)
		from EQ_Extract..WM_Trip_Export x
		where x.site_code = t.site_code
		and x.manifest = t.manifest
		and x.manifest_line = t.manifest_line
		and x.date_added = t.date_added
		and x.added_by = t.added_by
	) 
	<>
	(
		select sum(d.pounds)
		from EQ_Extract..WalmartDisposalExtract d
		where t.site_code = d.site_code
		and t.manifest = d.manifest
		and t.manifest_line = d.manifest_line
		and d.date_added = '2010-10-19 15:11:58.877'
		and d.added_by = 'jonathan'
	)
	order by convert(int,t.site_code), t.manifest, t.manifest_line

select top 10 * from 		EQ_Extract..WM_Trip_Export d		

select * from EQ_Extract..WM_Trip_Export d where date_added ='2010-11-02 18:31:49.550' and manifest = '007201787JJK' and manifest_line = 3
select * from EQ_Extract..WalmartDisposalExtract d where date_added ='2010-10-19 15:11:58.877' and manifest = '007201787JJK' and manifest_line =3

select * from workorderdetail where workorder_id = 2545600 and company_id = 14 and manifest_line = 3
select * from workorderdetailitem where workorder_id = 2545600 and company_id = 14 and sequence_id = 3

  
  
  select distinct site_type from generator
  
  sp_rpt_wm_trip_export '3081, 3082, 3209, 3218, 3235', 'Wal-Mart', '', ''        
  ************************************* */
  
  declare @added_by varchar(10), @date_added datetime
  set @added_by = system_user
  set @date_added = getdate()

  IF @debug > 0 select @added_by added_by, @date_added date_added

  
  -- Create tmp table to store the trip id's to report on (not from user input, just overall)
  create table #filter (
      workorder_id    int,
      company_id      int,
      profit_ctr_id   int,
      pickup_date	  datetime
  )
  
  -- Copy format of #filter for the list from input (limit results to these)
  create table #tmpTripID (
      trip_id         int
  )
  
  -- Create tmp table to store input site types
  create table #sitetype(site_type varchar(40))

  -- Create tmp table to store input site codes
  create table #sitecode(site_code varchar(16))
  
  -- Convert input trip id list to #tmpTripID table
  if isnull(@trip_id_list, '') <> '' begin
      Insert #tmpTripID
      select convert(int, row)
      from dbo.fn_SplitXsvText(',', 1, @trip_id_list)
      where isnull(row, '') <> ''
  end
  
  -- Convert input site type list to #sitetype table
  if isnull(@site_type_list, '') <> '' and @site_type_list not like '%(Any)%' begin
      Insert #sitetype
      select row
      from dbo.fn_SplitXsvText(',', 1, @site_type_list)
      where isnull(row, '') <> ''
  end

  -- Convert input site code list to #sitecode table
if isnull(@site_code_list, '') <> '' begin
    Insert #sitecode
    select row
    from dbo.fn_SplitXsvText(',', 1, @site_code_list)
    where isnull(row, '') <> ''
end
  
  -- Declare variables
  declare @sql varchar(1000)
  
  -- create dynamic sql to populate #filter from inputs + business logic rules
  set @sql = 'insert #filter 
	select distinct wh.workorder_id, wh.company_id, wh.profit_ctr_id, Coalesce( Nullif( wh.trip_act_arrive, ''1/1/1900'' ), wh.start_date ) as pickup_date
	from workorderheader wh 
  inner join workorderdetail wd on wh.workorder_id = wd.workorder_id and wh.company_id = wd.company_id and wh.profit_ctr_id = wd.profit_ctr_id
  '
  if (select count(*) from #sitetype) > 0
      set @sql = @sql + ' inner join generator g on wh.generator_id = g.generator_id 
          inner join #sitetype tg on g.site_type = tg.site_type '

  if (select count(*) from #sitecode) > 0
    set @sql = @sql + ' inner join generator gs on wh.generator_id = gs.generator_id 
        inner join #sitecode tgs on gs.site_code = tgs.site_code '
      
  set @sql = @sql + ' where (wh.customer_id = 10673 or wh.generator_id in (select generator_id from customergenerator where customer_id = 10673)) and wh.workorder_status <> ''V'' '
  
  if (select count(*) from #tmpTripID) > 0
      set @sql = @sql + ' and wh.trip_id in (select trip_id from #tmpTripID) '
      
  if isnull(@start_date, '') <> ''
      set @sql = @sql + ' and Coalesce( Nullif( wh.trip_act_arrive, ''1/1/1900'' ), wh.start_date ) >= ''' + convert(varchar(40), @start_date, 121) + ''' '
      
  if isnull(@end_date, '') <> ''
      set @sql = @sql + ' and Coalesce( Nullif( wh.trip_act_arrive, ''1/1/1900'' ), wh.start_date ) < ''' + convert(varchar(40), @end_date + 0.9999, 121) + ''' '
  
  IF @debug > 0 select @sql as sql_stmt
      
  exec (@sql)

  IF @debug > 0 select '#filter contents: ', * from #filter


-- DROP TABLE   EQ_Extract..WM_Trip_Export
 
INSERT EQ_Extract..WM_Trip_Export
  select
      g.site_code, 
      g.generator_city, 
      g.generator_state,
      f.pickup_date as shipment_date,
      case when wodi.month is null or wodi.year is null then
		convert(datetime, 
			convert(varchar(2), datepart(m, f.pickup_date)) + '/01/' + convert(varchar(4), datepart(yyyy, f.pickup_date))
		)
		else
			convert(datetime, convert(varchar(2), wodi.month) + '/01/' + CONVERT(varchar(4), wodi.year)) 
	  end as generation_date,
      g.epa_id,
      isnull(wodi.pounds, 0) + (isnull(wodi.ounces, 0)/16.0) as Weight,
      wod.tsdf_approval_code,
      wod.manifest,
      wod.manifest_line,
      wod.company_id,
      wod.profit_ctr_id,
      wod.workorder_id,
      wod.resource_type,
      wod.sequence_id,
      wodi.sub_sequence_id,
      @added_by as added_by,
      @date_added as date_added
  from workorderheader wo
  inner join #filter f
      on wo.workorder_id = f.workorder_id
      and wo.company_id = f.company_id
      and wo.profit_ctr_id = f.profit_ctr_id
  inner join workorderdetail wod
      on wo.workorder_id = wod.workorder_id
      and wo.company_id = wod.company_id
      and wo.profit_ctr_id = wod.profit_ctr_id
      and wod.bill_rate > -2
      and wod.resource_type = 'D'
      /*       -2 = void      -1 = manifest only      0 = no charge      1 = standard      1.5 = OT      2 = double time      */
  inner join generator g 
      on wo.generator_id = g.generator_id
  left outer join workorderdetailitem wodi
      on wod.workorder_id = wodi.workorder_id
      and wod.sequence_id = wodi.sequence_id
      and wod.company_id = wodi.company_id
      and wod.profit_ctr_id = wodi.profit_ctr_id
  where 
  wo.trip_id is not null
  and (
      wo.customer_id = 10673
      or
      wo.generator_id in (select generator_id from customergenerator where customer_id = 10673)
  )
  and exists (select 1 from profilewastecode pwc inner join wastecode wc on pwc.waste_code = wc.waste_code where pwc.profile_id = wod.profile_id)


  IF @debug > 0 select 'EQ_Extract..WM_Trip_Export populated'

	select      
      site_code as [Facility Number], 
      generator_city as City, 
      generator_state as State,
      shipment_date as [Shipment Date],
      generation_date as [Generation Date],
      epa_id as [Haz Waste Generator EPA ID],
      sum(weight) as Weight,
      tsdf_approval_code as [Waste Profile Number], -- tsdf_approval_code always correct?, looks ok.
      'EQIS' as [Vendor Name]
	FROM EQ_Extract..WM_Trip_Export
	WHERE added_by = @added_by
	AND date_added = @date_added
  group by
      site_code,
      generator_city, 
      generator_state,
      shipment_date,
      generation_date,
      epa_id,
      tsdf_approval_code
  order by 
      site_code, 
      generator_city, 
      generator_state,
      shipment_date, -- ?? arrive or depart make a difference?
      generation_date,
      epa_id,
      tsdf_approval_code
  

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_wm_trip_export] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_wm_trip_export] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_wm_trip_export] TO [EQAI]
    AS [dbo];

