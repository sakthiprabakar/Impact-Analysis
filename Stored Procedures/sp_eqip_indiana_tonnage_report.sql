
create proc sp_eqip_indiana_tonnage_report (
	@dt_begin	datetime,		-- '01/01/2012'
	@dt_end		datetime,		-- '03/31/2012 23:59:59'
	@user_code		varchar(20),
	@permission_id	int,
	@report_log_id	int,
	@debug_code			int = 0
) AS
/* ****************************************************************************
sp_eqip_indiana_tonnage_report
	Creates an Indiana Tonnage Report to Excel for EQIP download

	5/2/2012 - JPB Created (Rob_B wrote the SQL, JPB just made it a SP for EQIP)
		
sp_eqip_indiana_tonnage_report '1/1/2012', '3/31/2012 23:59:59', 'jonathan', 123, 98076

select * from plt_export..export where report_log_id = 98076

**************************************************************************** */

	if datepart(hh, @dt_end) = 0 set @dt_end = @dt_end + 0.99999


	declare @run_id int, @sql varchar(max)
	select @run_id = isnull(max(run_id), 0) + 1 from eq_temp..sp_eqip_indiana_tonnage_report_worksheet_table

	DELETE FROM EQ_TEMP..sp_eqip_arcos_worksheet_table WHERE user_code = @user_code and @run_id <= @run_id

	-- collect all Outbound Receipt, Container, Inbound Receipt, and Weights into a temp table
	insert eq_temp..sp_eqip_indiana_tonnage_report_worksheet_table
	select
		@user_code, @run_id, 
			r.company_id, r.profit_ctr_id, r.receipt_id AS OB_receipt_id, r.line_id AS OB_line_id,
			r.TSDF_code AS OB_TSDF_code, r2.receipt_id, r2.line_id, cd.container_id, cd.sequence_id,
			cd.container_percent, r2.generator_id, g.EPA_ID, g.generator_name, g.generator_state,
			g.generator_county, c.county_name,
			dbo.fn_receipt_weight_container (r2.receipt_id, r2.line_id, r2.profit_ctr_id, r2.company_id,
											cd.container_id, cd.sequence_id) as total_pounds
	from Receipt r (nolock)
	join ContainerDestination cd (nolock)
		on r.location = cd.location
		and r.tracking_num = cd.tracking_num
		and r.cycle = cd.cycle
		and cd.location_type = 'P'
	join Receipt r2 (nolock)
		on cd.receipt_id = r2.receipt_id
		and cd.line_id = r2.line_id
		and cd.company_id = r2.company_id
		and cd.profit_ctr_id = r2.profit_ctr_id
		and r2.trans_mode = 'I'
		and r2.fingerpr_status NOT IN ('V', 'R')
		and r2.receipt_status NOT IN ('V')
	join Generator g (nolock)
		on r2.generator_id = g.generator_id
	left outer join County c (nolock)
		on g.generator_county = c.county_code
	where r.trans_mode = 'O'
	and r.company_id = 14
	and r.profit_ctr_id = 6
	and r.receipt_date between @dt_begin and @dt_end
	and r.fingerpr_status NOT IN ('V', 'R')
	and r.receipt_status NOT IN ('V')
	/*
	and (  (r.location = 'WM' and r.tracking_num in ('153','154','155','156','157') and r.cycle = 1)
		or (r.location = 'OIL' and r.tracking_num in ('90','91') and r.cycle = 1)
		or (r.location = 'RPP' and r.tracking_num in ('83','84','85','86') and r.cycle = 1)
		)
	*/


	-- generate report by Generator State and County
	insert eq_temp..sp_eqip_indiana_tonnage_report_state_county_table
	select @user_code, 
		@run_id, 
		1 as nOrder, 
		generator_state, 
		isnull(county_name,'<Unknown>') as generator_county,
		SUM(isnull(total_pounds,0)) / 2000 as total_tons
	from eq_temp..sp_eqip_indiana_tonnage_report_worksheet_table
	where run_id = @run_id
	group by generator_state, isnull(county_name,'<Unknown>')
	union
	select @user_code, 
		@run_id, 2 as nOrder, '', 'Total', SUM(isnull(total_pounds,0)) / 2000 as total_tons
	from eq_temp..sp_eqip_indiana_tonnage_report_worksheet_table
	where run_id = @run_id



	-- generate report by Destination Facility
	insert eq_temp..sp_eqip_indiana_tonnage_report_destination_table
	select @user_code, 
		@run_id, 
		1 as nOrder, 
		t.tsdf_code, 
		t.TSDF_name, 
		t.TSDF_city, 
		t.TSDF_state, 
		t.TSDF_zip_code,
		SUM(isnull(r.total_pounds,0)) / 2000 as total_tons
	from eq_temp..sp_eqip_indiana_tonnage_report_worksheet_table r
	join TSDF t (nolock)
		on r.OB_tsdf_code = t.TSDF_code
	where r.run_id = @run_id
	group by t.tsdf_code, t.TSDF_name, t.TSDF_city, t.TSDF_state, t.TSDF_zip_code
	union
	select @user_code, 
		@run_id, 
		2 as nOrder,
		'',
		'Total',
		'',
		'',
		'',
		SUM(isnull(r.total_pounds,0)) / 2000 as total_tons
	from eq_temp..sp_eqip_indiana_tonnage_report_worksheet_table r
	join TSDF t (nolock)
		on r.OB_tsdf_code = t.TSDF_code
	where r.run_id = @run_id


	-- generate report by Batch Number
	insert eq_temp..sp_eqip_indiana_tonnage_report_batch_table
	select @user_code, 
		@run_id, 
		1 as nOrder, 
		r.location, 
		r.tracking_num, 
		r.cycle, 
		SUM(isnull(rt.total_pounds,0)) / 2000 as total_tons
	from eq_temp..sp_eqip_indiana_tonnage_report_worksheet_table rt
	join Receipt r (nolock)
		on rt.company_id = r.company_id
		and rt.profit_ctr_id = r.profit_ctr_id
		and rt.OB_receipt_id = r.receipt_id
		and rt.OB_line_id = r.line_id
	where rt.run_id = @run_id
	group by r.location, r.tracking_num, r.cycle
	-- order by r.location, r.tracking_num, r.cycle
	union
	select @user_code, @run_id,
		2 as nOrder,
		'Total',
		'',
		'',
		SUM(isnull(r.total_pounds,0)) / 2000 as total_tons
	from eq_temp..sp_eqip_indiana_tonnage_report_worksheet_table r
	where r.run_id = @run_id

declare @from_to_file_date	varchar(100)

set @from_to_file_date = convert(varchar(4), datepart(yyyy, @dt_begin)) + '-' 
	+ right('00' + convert(varchar(2), datepart(mm, @dt_begin)),2) + '-' 
	+ right('00' + convert(varchar(2), datepart(dd, @dt_begin)),2) + '-to-' 
	+ convert(varchar(4), datepart(yyyy, @dt_end)) + '-'
	+ right('00' + convert(varchar(2), datepart(mm, @dt_end)),2) + '-' 
	+ right('00' + convert(varchar(2), datepart(dd, @dt_end)),2)

	-- output query:
	set @sql = 'select company_id, profit_ctr_id, OB_receipt_id, OB_line_id, OB_TSDF_code, receipt_id, line_id, container_id, sequence_id, container_percent, generator_id, EPA_ID, generator_name, generator_state, generator_county, county_name, total_pounds from eq_temp..sp_eqip_indiana_tonnage_report_worksheet_table where run_id = ' + convert(varchar(20), @run_id)
	declare @outfile varchar(200) = 'Indiana-Tonnage-Report' + @from_to_file_date + '.xlsx',
		@desc varchar(100) = 'Indiana Tonnage Report: ' + convert(varchar(10), @dt_begin, 110) + ' - ' + convert(varchar(12), @dt_end, 110)


	if @debug_code > 0 PRINT '
	OUTPUT #1...
	'

	exec plt_export.dbo.sp_export_query_to_excel
		@table_name	= @sql,
		@template	= 'sp_eqip_indiana_tonnage_report.1',
		@filename	= @outfile,
		@added_by	= @user_code,
		@export_desc = @desc,
		@report_log_id = @report_log_id
		, @debug = @debug_code

	select @outfile = [filename] from plt_export..export where report_log_id = @report_log_id and [description] = @desc 

	-- output query:
	set @sql = 'select generator_state, generator_county, total_tons from eq_temp..sp_eqip_indiana_tonnage_report_state_county_table where run_id = ' + convert(varchar(20), @run_id) + ' order by order_id, generator_state, generator_county'

	if @debug_code > 0 PRINT '
	OUTPUT #2...
	'

	exec plt_export.dbo.sp_export_QUERY_to_excel_worksheet
		@table_name	= @sql,
		@filename	= @outfile,
		@export_worksheet = 'Tons by State & County',
		@added_by	= @user_code,
		@report_log_id = @report_log_id
		, @debug = @debug_code

	-- output query:
	set @sql = 'select tsdf_code, tsdf_name, tsdf_city, tsdf_state, tsdf_zip_code, total_tons from eq_temp..sp_eqip_indiana_tonnage_report_destination_table where run_id = ' + convert(varchar(20), @run_id) + ' order by order_id, tsdf_code '

	if @debug_code > 0 PRINT '
	OUTPUT #3...
	'

	exec plt_export.dbo.sp_export_QUERY_to_excel_worksheet
		@table_name	= @sql,
		@filename	= @outfile,
		@export_worksheet = 'Tons by Destination Facility',
		@added_by	= @user_code,
		@report_log_id = @report_log_id
		, @debug = @debug_code

