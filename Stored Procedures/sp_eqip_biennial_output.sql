
-- 
drop proc if exists sp_eqip_biennial_output
go

create procedure sp_eqip_biennial_output (
	@copc			varchar(20),
	@start_date		datetime,
	@end_date		datetime,
	@user_code		varchar(20),
	@permission_id	int,
	@report_log_id	int,
	@debug			int = 0
	)
as

/* **************************************************************************************
sp_eqip_biennial_output

	Created to neutralize state-specific versions based on OH.
	Includes build & validation outputs, THEN file outputs.

History:
	02/09/2012	JPB	Created
	03/23/2012 JPB Changed export to excel queries to use QUERIES not TABLES.
	
	---------------------------
	IMPORTANT !
	The queries MUST be in a single line or they fail.
	----------------------------
	
Example:

	exec sp_eqip_biennial_output '2|0', '1/1/2023', '1/31/2023 23:59', 'JONATHAN', 236, 366645, 0
	
	
************************************************************************************** */
if @debug > 0 select getdate(), 'Started'

declare 
	@newid				int,
	@from_to_file_date	varchar(100),
	@tmp_filename		varchar(100),
	@template_name		varchar(100),
	@outputfile			varchar(100),
	@tmp_desc			varchar(255),
	@tmp_debug			int,
	@state				varchar(2),
	@tsdf_code			varchar(20),
	@tablename			varchar(max),
	@state_haz_waste_code	int = 0,
	@epa_id				varchar(20),
	@brs_filename_pre	varchar(20),
	@brs_filename_suf	varchar(20),
	@brs_outputfile		varchar(20),
	@max_excel_wastecode_len int = 200,
	@datetime_started	datetime = getdate()

select top 1 
	@state = tsdf_state 
	, @tsdf_code = isnull(tsdf_code, '')
	, @epa_id = isnull(tsdf_epa_id, '')
from tsdf 
where eq_flag = 'T' 
and TSDF_Status = 'A'
and convert(varchar(2), eq_company) + '|' + convert(varchar(2), eq_profit_ctr) = @copc

set @brs_filename_pre = upper(@state)
set @brs_filename_suf = right('000' + convert(varchar(3), datepart(dayofyear, getdate())), 3) + '.FIL'

set @from_to_file_date = convert(varchar(4), datepart(yyyy, @start_date)) + '-' 
	+ right('00' + convert(varchar(2), datepart(mm, @start_date)),2) + '-' 
	+ right('00' + convert(varchar(2), datepart(dd, @start_date)),2) + '-to-' 
	+ convert(varchar(4), datepart(yyyy, @end_date)) + '-'
	+ right('00' + convert(varchar(2), datepart(mm, @end_date)),2) + '-' 
	+ right('00' + convert(varchar(2), datepart(dd, @end_date)),2)

set @tmp_filename = 'Biennial-Validation ' + @tsdf_code + ' - ' + @from_to_file_date + '.xls'

set @tmp_desc = 'Biennial Validation Export: ' 
	+ @tsdf_code + ' - '
	+ convert(varchar(10), @start_date, 110) + ' - ' 
	+ convert(varchar(12), @end_date, 110)

set @tmp_debug = @debug

select 
	@state_haz_waste_code = 1 
where exists (
	select * from wastecode where waste_code_origin = 'S' and haz_flag = 'T' and state = @state
)

declare @recordsetname table (
	recordsetnumber	int identity(1,1),
	recordsetname varchar(50)
)

/***********************************************************
	BUILD PHASE: Collect raw data from PLT_AI Tables
***********************************************************/

insert EQ_Extract..BiennialDebugInfo (biennial_id, log_time, log_message) values (null, getdate(), 'Starting sp_eqip_biennial_output. No biennial_id yet. ' + @copc + ', ' + convert(varchar(20), @start_date) + ' - ' + convert(varchar(20), @end_date) + ', ' + @user_code)

set nocount on

exec sp_biennial_report_source null, @copc, @start_date, @end_date, @user_code

-- get the biennial_id that was generated
-- when the criteria for a run produce NO records in BRSD, the original select gets the PREVIOUS biennial_id that could be for a different date range.
-- This should read from a table that always gets populated, not BRSD
SELECT @newid = MAX(biennial_id) 
FROM EQ_Extract.dbo.BiennialLog 
WHERE added_by = @user_code
and company = @copc
and date_added >= @datetime_started

set nocount off

update EQ_Extract..BiennialLog set report_log_id = @report_log_id where biennial_id = @newid

if @debug = 1 print convert(varchar(30), getdate(), 121) +'   '+ 'Starting sp_biennial_validate'
insert EQ_Extract..BiennialDebugInfo (biennial_id, log_time, log_message) values (@newid, getdate(), 'Starting sp_biennial_validate')


/*********************************
	FILE OUTPUT: Validation
**********************************/

-- run the validation for this biennial run
exec sp_biennial_validate @newid
insert @recordsetname (recordsetname) values ('validation')


if @debug = 1 print convert(varchar(30), getdate(), 121) +'   '+ 'Ended sp_biennial_validate'
insert EQ_Extract..BiennialDebugInfo (biennial_id, log_time, log_message) values (@newid, getdate(), 'Ended sp_biennial_validate')

if @debug = 1 print convert(varchar(30), getdate(), 121) +'   '+ 'Starting sp_export_to_excel, sp_biennial_validate.1'
insert EQ_Extract..BiennialDebugInfo (biennial_id, log_time, log_message) values (@newid, getdate(), 'Starting sp_export_to_excel, sp_biennial_validate.1')

/*
exec plt_export.dbo.sp_export_to_excel
	@table_name	= 'eq_temp..sp_biennial_validate_TMP',
	@template	= 'sp_biennial_validate.1',
	@filename	= @tmp_filename,
	@added_by	= @user_code,
	@export_desc = @tmp_desc,
	@report_log_id = @report_log_id,
	@debug = @tmp_debug
*/
--select * from eq_temp..sp_biennial_validate_TMP WHERE biennial_id = @newid


if @debug = 1 print convert(varchar(30), getdate(), 121) +'   '+ 'Ended sp_export_to_excel, sp_biennial_validate.1'
insert EQ_Extract..BiennialDebugInfo (biennial_id, log_time, log_message) values (@newid, getdate(), 'Ended sp_export_to_excel, sp_biennial_validate.1')

if @debug = 1 print convert(varchar(30), getdate(), 121) +'   '+ 'starting sp_biennial_report_output_GM'
insert EQ_Extract..BiennialDebugInfo (biennial_id, log_time, log_message) values (@newid, getdate(), 'starting sp_biennial_report_output_GM')

exec sp_biennial_report_output_GM @newid, @state

if @debug = 1 print convert(varchar(30), getdate(), 121) +'   '+ 'starting sp_biennial_report_output_GM'
insert EQ_Extract..BiennialDebugInfo (biennial_id, log_time, log_message) values (@newid, getdate(), 'starting sp_biennial_report_output_GM')
	
/*********************************
	FILE OUTPUT: GM1
**********************************/
set @outputfile = 'GM1'	
set @brs_outputfile = @brs_filename_pre	+ @outputfile + @brs_filename_suf

-- exec sp_biennial_report_output_extract @newid, @state, @outputfile, 'T'

select 
	@tmp_desc = upper(@state) + ' Biennial ' + @outputfile + ' Export: ' 
		+ @tsdf_code + ' - '
		+ convert(varchar(10), @start_date, 110) + ' - ' 
		+ convert(varchar(12), @end_date, 110),
	@tmp_filename = upper(@state) + '-Biennial-' + @outputfile + ' ' 
		+ @tsdf_code + ' - '
		+ @from_to_file_date + ' - '
		+ @brs_outputfile + ' -.txt',
	@template_name = 'sp_biennial_' + upper(@state) + '_' + @outputfile + '.1',
	-- @tablename = 'SELECT HANDLER_ID + HZ_PG + FORM_CODE + UNIT_OF_MEASURE + WST_DENSITY + DENSITY_UNIT_OF_MEASURE + ORIGIN_MANAGEMENT_METHOD + WASTE_MINIMIZATION_CODE + SOURCE_CODE + GEN_QTY + INCLUDE_IN_NATIONAL_REPORT + DESCRIPTION + NOTES + ON_SITE_MANAGEMENT + OFF_SITE_SHIPMENT as [Report] FROM EQ_Extract..BiennialReportWork_GM1 WHERE biennial_id = ' + convert(varchar(20), @newid) + ' ORDER BY HANDLER_ID, HZ_PG '
	@tablename = 'SELECT HANDLER_ID + HZ_PG + FORM_CODE + UNIT_OF_MEASURE + WST_DENSITY + DENSITY_UNIT_OF_MEASURE + ORIGIN_MANAGEMENT_METHOD + WASTE_MINIMIZATION_CODE + SOURCE_CODE + CASE WHEN SOURCE_CODE = ''G61'' THEN ''          0.000000'' ELSE GEN_QTY END + INCLUDE_IN_NATIONAL_REPORT + DESCRIPTION + NOTES + ON_SITE_MANAGEMENT + OFF_SITE_SHIPMENT + MIXED_WASTE + CASE WHEN ''' + @state + ''' = ''OH'' THEN '''' ELSE COUNTRY_CODE END as [Report] FROM EQ_Extract..BiennialReportWork_GM1 WHERE biennial_id = ' + convert(varchar(20), @newid) + ' ORDER BY HANDLER_ID, HZ_PG '

if @debug = 1 print convert(varchar(30), getdate(), 121) +'   '+ 'Starting sp_export_query_to_text, ' + @template_name + ': ' + @tablename
insert EQ_Extract..BiennialDebugInfo (biennial_id, log_time, log_message) values (@newid, getdate(), 'Starting sp_export_query_to_text, ' + @template_name + ': ' + @tablename)

/*
exec plt_export.dbo.sp_export_query_to_text 
	@table_name	= @tablename,
	@template	= @template_name,
	@filename	= @tmp_filename,
	@header_lines_to_remove = 2,
	@added_by	= @user_code,
	@export_desc = @tmp_desc,
	@report_log_id = @report_log_id
*/

SELECT HANDLER_ID + HZ_PG + FORM_CODE + UNIT_OF_MEASURE 
	+ WST_DENSITY + DENSITY_UNIT_OF_MEASURE + ORIGIN_MANAGEMENT_METHOD 
	+ WASTE_MINIMIZATION_CODE + SOURCE_CODE 
	+ CASE WHEN SOURCE_CODE = 'G61' THEN '          0.000000' ELSE GEN_QTY END 
	+ INCLUDE_IN_NATIONAL_REPORT + DESCRIPTION + NOTES + ON_SITE_MANAGEMENT 
	+ OFF_SITE_SHIPMENT + MIXED_WASTE + CASE WHEN @state = 'OH' THEN '' ELSE COUNTRY_CODE END 
	as [Report] 
FROM EQ_Extract..BiennialReportWork_GM1 WHERE biennial_id = @newid
ORDER BY HANDLER_ID, HZ_PG 

insert @recordsetname (recordsetname) values (@outputfile + '.' + @brs_outputfile)

if @debug = 1 print convert(varchar(30), getdate(), 121) +'   '+ 'Ended sp_export_query_to_text, ' + @template_name + ': ' + @tablename
insert EQ_Extract..BiennialDebugInfo (biennial_id, log_time, log_message) values (@newid, getdate(), 'Ended sp_export_query_to_text, ' + @template_name + ': ' + @tablename)



/*********************************
	FILE OUTPUT: GM2
**********************************/

set @outputfile = 'GM2'	
set @brs_outputfile = @brs_filename_pre	+ @outputfile + @brs_filename_suf

-- exec sp_biennial_report_output_extract @newid, @state, @outputfile, 'T'

select 
	@tmp_desc = upper(@state) + ' Biennial ' + @outputfile + ' Export: ' 
		+ @tsdf_code + ' - '
		+ convert(varchar(10), @start_date, 110) + ' - ' 
		+ convert(varchar(12), @end_date, 110),
	@tmp_filename = upper(@state) + '-Biennial-' + @outputfile + ' ' 
		+ @tsdf_code + ' - '
		+ @from_to_file_date + ' - '
		+ @brs_outputfile + ' -.txt',
	@template_name = 'sp_biennial_' + upper(@state) + '_' + @outputfile + '.1',
	@tablename = 'SELECT HANDLER_ID + HZ_PG + EPA_WASTE_CODE as [Report] FROM EQ_Extract..BiennialReportWork_GM2 WHERE biennial_id = ' + convert(varchar(20), @newid) + ' ORDER BY HANDLER_ID, HZ_PG, EPA_WASTE_CODE'

if @debug = 1 print convert(varchar(30), getdate(), 121) +'   '+ 'Starting sp_export_query_to_text, ' + @template_name + ': ' + @tablename
insert EQ_Extract..BiennialDebugInfo (biennial_id, log_time, log_message) values (@newid, getdate(), 'Starting sp_export_query_to_text, ' + @template_name + ': ' + @tablename)

/*
exec plt_export.dbo.sp_export_query_to_text 
	@table_name	= @tablename,
	@template	= @template_name,
	@filename	= @tmp_filename,
	@header_lines_to_remove = 2,
	@added_by	= @user_code,
	@export_desc = @tmp_desc,
	@report_log_id = @report_log_id
*/

SELECT HANDLER_ID + HZ_PG + EPA_WASTE_CODE as [Report] 
FROM EQ_Extract..BiennialReportWork_GM2 
WHERE biennial_id = @newid
ORDER BY HANDLER_ID, HZ_PG, EPA_WASTE_CODE

insert @recordsetname (recordsetname) values (@outputfile + '.' + @brs_outputfile)

if @debug = 1 print convert(varchar(30), getdate(), 121) +'   '+ 'Ended sp_export_query_to_text, ' + @template_name + ': ' + @tablename
insert EQ_Extract..BiennialDebugInfo (biennial_id, log_time, log_message) values (@newid, getdate(), 'Ended sp_export_query_to_text, ' + @template_name + ': ' + @tablename)


/*********************************
	FILE OUTPUT: GM3
**********************************/

IF @state_haz_waste_code > 0 BEGIN
	set @outputfile = 'GM3'	
	set @brs_outputfile = @brs_filename_pre	+ @outputfile + @brs_filename_suf

	-- exec sp_biennial_report_output_extract @newid, @state, @outputfile, 'T'

	select 
		@tmp_desc = upper(@state) + ' Biennial ' + @outputfile + ' Export: ' 
			+ @tsdf_code + ' - '
			+ convert(varchar(10), @start_date, 110) + ' - ' 
			+ convert(varchar(12), @end_date, 110),
		@tmp_filename = upper(@state) + '-Biennial-' + @outputfile + ' ' 
			+ @tsdf_code + ' - '
			+ @from_to_file_date + ' - '
			+ @brs_outputfile + ' -.txt',
		@template_name = 'sp_biennial_' + upper(@state) + '_' + @outputfile + '.1',
		@tablename = 'SELECT HANDLER_ID + HZ_PG + STATE_WASTE_CODE as [Report] FROM EQ_Extract..BiennialReportWork_GM3 WHERE biennial_id = ' + convert(varchar(20), @newid) + ' ORDER BY HANDLER_ID, HZ_PG, STATE_WASTE_CODE'

	if @debug = 1 print convert(varchar(30), getdate(), 121) +'   '+ 'Starting sp_export_query_to_text, ' + @template_name + ': ' + @tablename
	insert EQ_Extract..BiennialDebugInfo (biennial_id, log_time, log_message) values (@newid, getdate(), 'Starting sp_export_query_to_text, ' + @template_name + ': ' + @tablename)

	/*
	exec plt_export.dbo.sp_export_query_to_text 
		@table_name	= @tablename,
		@template	= @template_name,
		@filename	= @tmp_filename,
		@header_lines_to_remove = 2,
		@added_by	= @user_code,
		@export_desc = @tmp_desc,
		@report_log_id = @report_log_id
	*/
	
	SELECT HANDLER_ID + HZ_PG + STATE_WASTE_CODE as [Report] 
	FROM EQ_Extract..BiennialReportWork_GM3 
	WHERE biennial_id = @newid
	ORDER BY HANDLER_ID, HZ_PG, STATE_WASTE_CODE

	insert @recordsetname (recordsetname) values (@outputfile + '.' + @brs_outputfile)

	if @debug = 1 print convert(varchar(30), getdate(), 121) +'   '+ 'Ended sp_export_query_to_text, ' + @template_name + ': ' + @tablename
	insert EQ_Extract..BiennialDebugInfo (biennial_id, log_time, log_message) values (@newid, getdate(), 'Ended sp_export_query_to_text, ' + @template_name + ': ' + @tablename)
		
END



/*********************************
	FILE OUTPUT: GM4
**********************************/
set @outputfile = 'GM4'	
set @brs_outputfile = @brs_filename_pre	+ @outputfile + @brs_filename_suf

-- exec sp_biennial_report_output_extract @newid, @state, @outputfile, 'T'

select 
	@tmp_desc = upper(@state) + ' Biennial ' + @outputfile + ' Export: ' 
		+ @tsdf_code + ' - '
		+ convert(varchar(10), @start_date, 110) + ' - ' 
		+ convert(varchar(12), @end_date, 110),
	@tmp_filename = upper(@state) + '-Biennial-' + @outputfile + ' ' 
		+ @tsdf_code + ' - '
		+ @from_to_file_date + ' - '
		+ @brs_outputfile + ' -.txt',
	@template_name = 'sp_biennial_' + upper(@state) + '_' + @outputfile + '.1',
	@tablename = 'SELECT HANDLER_ID + HZ_PG + IO_PG_NUM_SEQ + MANAGEMENT_METHOD + IO_TDR_ID + IO_TDR_QTY as [Report] FROM EQ_Extract..BiennialReportWork_GM4 WHERE biennial_id = ' + convert(varchar(20), @newid) + ' ORDER BY HANDLER_ID, HZ_PG, IO_PG_NUM_SEQ'	

if @debug = 1 print convert(varchar(30), getdate(), 121) +'   '+ 'Starting sp_export_query_to_text, ' + @template_name + ': ' + @tablename
insert EQ_Extract..BiennialDebugInfo (biennial_id, log_time, log_message) values (@newid, getdate(), 'Starting sp_export_query_to_text, ' + @template_name + ': ' + @tablename)

/*
exec plt_export.dbo.sp_export_query_to_text 
	@table_name	= @tablename,
	@template	= @template_name,
	@filename	= @tmp_filename,
	@header_lines_to_remove = 2,
	@added_by	= @user_code,
	@export_desc = @tmp_desc,
	@report_log_id = @report_log_id
*/

SELECT HANDLER_ID + HZ_PG + IO_PG_NUM_SEQ + MANAGEMENT_METHOD 
	+ IO_TDR_ID + IO_TDR_QTY as [Report] 
FROM EQ_Extract..BiennialReportWork_GM4 
WHERE biennial_id = @newid
ORDER BY HANDLER_ID, HZ_PG, IO_PG_NUM_SEQ

insert @recordsetname (recordsetname) values (@outputfile + '.' + @brs_outputfile)

if @debug = 1 print convert(varchar(30), getdate(), 121) +'   '+ 'Ended sp_export_query_to_text, ' + @template_name + ': ' + @tablename
insert EQ_Extract..BiennialDebugInfo (biennial_id, log_time, log_message) values (@newid, getdate(), 'Ended sp_export_query_to_text, ' + @template_name + ': ' + @tablename)



if @debug = 1 print convert(varchar(30), getdate(), 121) +'   '+ 'starting sp_biennial_report_output_OI'
insert EQ_Extract..BiennialDebugInfo (biennial_id, log_time, log_message) values (@newid, getdate(), 'starting sp_biennial_report_output_OI')

exec sp_biennial_report_output_OI @newid, @state

if @debug = 1 print convert(varchar(30), getdate(), 121) +'   '+ 'ended sp_biennial_report_output_OI'
insert EQ_Extract..BiennialDebugInfo (biennial_id, log_time, log_message) values (@newid, getdate(), 'ended sp_biennial_report_output_OI')

/*********************************
	FILE OUTPUT: GM5
**********************************/
set @outputfile = 'GM5'	
set @brs_outputfile = @brs_filename_pre	+ @outputfile + @brs_filename_suf

-- exec sp_biennial_report_output_extract @newid, @state, @outputfile, 'T'

select 
	@tmp_desc = upper(@state) + ' Biennial ' + @outputfile + ' Export: ' 
		+ @tsdf_code + ' - '
		+ convert(varchar(10), @start_date, 110) + ' - ' 
		+ convert(varchar(12), @end_date, 110),
	@tmp_filename = upper(@state) + '-Biennial-' + @outputfile + ' ' 
		+ @tsdf_code + ' - '
		+ @from_to_file_date + ' - '
		+ @brs_outputfile + ' -.txt',
	@template_name = 'sp_biennial_' + upper(@state) + '_' + @outputfile + '.1',
	@tablename = 'SELECT HANDLER_ID + HZ_PG + SYS_PG_NUM_SEQ + MANAGEMENT_METHOD + IO_TDR_QTY as [Report] FROM EQ_Extract..BiennialReportWork_GM5 WHERE biennial_id = ' + convert(varchar(20), @newid) + ' ORDER BY HANDLER_ID, HZ_PG, SYS_PG_NUM_SEQ'	

if @debug = 1 print convert(varchar(30), getdate(), 121) +'   '+ 'Starting sp_export_query_to_text, ' + @template_name + ': ' + @tablename
insert EQ_Extract..BiennialDebugInfo (biennial_id, log_time, log_message) values (@newid, getdate(), 'Starting sp_export_query_to_text, ' + @template_name + ': ' + @tablename)

/*
exec plt_export.dbo.sp_export_query_to_text 
	@table_name	= @tablename,
	@template	= @template_name,
	@filename	= @tmp_filename,
	@header_lines_to_remove = 2,
	@added_by	= @user_code,
	@export_desc = @tmp_desc,
	@report_log_id = @report_log_id
*/

SELECT HANDLER_ID + HZ_PG + SYS_PG_NUM_SEQ 
	+ MANAGEMENT_METHOD + IO_TDR_QTY as [Report] 
FROM EQ_Extract..BiennialReportWork_GM5 
WHERE biennial_id = @newid
ORDER BY HANDLER_ID, HZ_PG, SYS_PG_NUM_SEQ

insert @recordsetname (recordsetname) values (@outputfile + '.' + @brs_outputfile)

if @debug = 1 print convert(varchar(30), getdate(), 121) +'   '+ 'Ended sp_export_query_to_text, ' + @template_name + ': ' + @tablename
insert EQ_Extract..BiennialDebugInfo (biennial_id, log_time, log_message) values (@newid, getdate(), 'Ended sp_export_query_to_text, ' + @template_name + ': ' + @tablename)





if @debug = 1 print convert(varchar(30), getdate(), 121) +'   '+ 'starting sp_biennial_report_output_OI'
insert EQ_Extract..BiennialDebugInfo (biennial_id, log_time, log_message) values (@newid, getdate(), 'starting sp_biennial_report_output_OI')

exec sp_biennial_report_output_OI @newid, @state

if @debug = 1 print convert(varchar(30), getdate(), 121) +'   '+ 'ended sp_biennial_report_output_OI'
insert EQ_Extract..BiennialDebugInfo (biennial_id, log_time, log_message) values (@newid, getdate(), 'ended sp_biennial_report_output_OI')



/*********************************
	FILE OUTPUT: OI
**********************************/	
set @outputfile = 'OI'	
set @brs_outputfile = @brs_filename_pre	+ @outputfile + @brs_filename_suf


-- exec sp_biennial_report_output_extract @newid, @state, @outputfile, 'T'
--exec sp_biennial_report_output_extract_OH 309, 'GM1', 'F'

select 
	@tmp_desc = upper(@state) + ' Biennial ' + @outputfile + ' Export: ' 
		+ @tsdf_code + ' - '
		+ convert(varchar(10), @start_date, 110) + ' - ' 
		+ convert(varchar(12), @end_date, 110),
	@tmp_filename = upper(@state) + '-Biennial-' + @outputfile + ' ' 
		+ @tsdf_code + ' - '
		+ @from_to_file_date + ' - '
		+ @brs_outputfile + ' -.txt',
	@template_name = 'sp_biennial_' + upper(@state) + '_' + @outputfile + '.1',
	-- 2/11/2016 - Ohio is reporting that there's 169, even though my math says 168.  So I'm chopping the zip at 5 chars and adding 3, then taking 1 char off the zip at the end.
	-- @tablename = 'SELECT DISTINCT HANDLER_ID + OSITE_PGNUM + OFF_ID + WST_GEN_FLG + WST_TRNS_FLG + WST_TSDR_FLG + ONAME+ O1STREET+ O2STREET+ OCITY+ OSTATE+ OZIP+ CASE WHEN ''' + @state + ''' = ''OH'' THEN '''' ELSE LEFT(IsNull(NOTES,'' '') + SPACE(240), 240) END as [Report] FROM EQ_Extract..BiennialReportWork_OI WHERE biennial_id = ' + convert(varchar(20), @newid) + ' ORDER BY HANDLER_ID + OSITE_PGNUM + OFF_ID + WST_GEN_FLG + WST_TRNS_FLG + WST_TSDR_FLG + ONAME+ O1STREET+ O2STREET+ OCITY+ OSTATE+ OZIP+ CASE WHEN ''' + @state + ''' = ''OH'' THEN '''' ELSE LEFT(IsNull(NOTES,'' '') + SPACE(240), 240) END '	
	-- 1/25/2018 - EPA Spec Update
	-- @tablename = 'SELECT DISTINCT HANDLER_ID + OSITE_PGNUM + OFF_ID + WST_GEN_FLG + WST_TRNS_FLG + WST_TSDR_FLG + ONAME+ O1STREET+ O2STREET+ OCITY+ OSTATE+ CASE WHEN  ''' + @state + ''' = ''OH'' THEN LEFT(IsNull(OZIP,'' '') + SPACE(9), 8) ELSE OZIP END+ CASE WHEN ''' + @state + ''' = ''OH'' THEN '''' ELSE LEFT(IsNull(NOTES,'' '') + SPACE(240), 240) END as [Report] FROM EQ_Extract..BiennialReportWork_OI WHERE biennial_id = ' + convert(varchar(20), @newid) + ' ORDER BY HANDLER_ID + OSITE_PGNUM + OFF_ID + WST_GEN_FLG + WST_TRNS_FLG + WST_TSDR_FLG + ONAME+ O1STREET+ O2STREET+ OCITY+ OSTATE+ CASE WHEN  ''' + @state + ''' = ''OH'' THEN LEFT(IsNull(OZIP,'' '') + SPACE(9), 8) ELSE OZIP END+ CASE WHEN ''' + @state + ''' = ''OH'' THEN '''' ELSE LEFT(IsNull(NOTES,'' '') + SPACE(240), 240) END '	
	@tablename = 'SELECT DISTINCT HANDLER_ID + OSITE_PGNUM + OFF_ID + WST_GEN_FLG + WST_TRNS_FLG + WST_TSDR_FLG + ONAME+ OSTREETNO+ O1STREET+ O2STREET+ OCITY+ OSTATE+ OZIP+ OCOUNTRY+ CASE WHEN ''' + @state + ''' = ''OH'' THEN '''' ELSE LEFT(IsNull(NOTES,'' '') + SPACE(1000), 1000) END as [Report] FROM EQ_Extract..BiennialReportWork_OI WHERE biennial_id = ' + convert(varchar(20), @newid) + ' ORDER BY HANDLER_ID + OSITE_PGNUM + OFF_ID + WST_GEN_FLG + WST_TRNS_FLG + WST_TSDR_FLG + ONAME+ OSTREETNO+ O1STREET+ O2STREET+ OCITY+ OSTATE+ OZIP+ OCOUNTRY+ CASE WHEN ''' + @state + ''' = ''OH'' THEN '''' ELSE LEFT(IsNull(NOTES,'' '') + SPACE(1000), 1000) END '	

if @debug = 1 print convert(varchar(30), getdate(), 121) +'   '+ 'Starting sp_export_query_to_text, ' + @template_name + ': ' + @tablename
insert EQ_Extract..BiennialDebugInfo (biennial_id, log_time, log_message) values (@newid, getdate(), 'Starting sp_export_query_to_text, ' + @template_name + ': ' + @tablename)

/*
exec plt_export.dbo.sp_export_query_to_text 
	@table_name	= @tablename,
	@template	= @template_name,
	@filename	= @tmp_filename,
	@header_lines_to_remove = 2,
	@added_by	= @user_code,
	@export_desc = @tmp_desc,
	@report_log_id = @report_log_id
*/

SELECT DISTINCT HANDLER_ID + OSITE_PGNUM + OFF_ID 
	+ WST_GEN_FLG + WST_TRNS_FLG + WST_TSDR_FLG + ONAME
	+ OSTREETNO+ O1STREET+ O2STREET+ OCITY+ OSTATE
	+ OZIP+ OCOUNTRY+ CASE WHEN @state = 'OH' THEN '' ELSE LEFT(IsNull(NOTES,' ') + SPACE(1000), 1000) END 
	as [Report] 
FROM EQ_Extract..BiennialReportWork_OI WHERE biennial_id = @newid
ORDER BY HANDLER_ID + OSITE_PGNUM + OFF_ID + WST_GEN_FLG 
	+ WST_TRNS_FLG + WST_TSDR_FLG + ONAME+ OSTREETNO+ O1STREET
	+ O2STREET+ OCITY+ OSTATE+ OZIP+ OCOUNTRY
	+ CASE WHEN @state = 'OH' THEN '' ELSE LEFT(IsNull(NOTES,' ') + SPACE(1000), 1000) END 

insert @recordsetname (recordsetname) values (@outputfile + '.' + @brs_outputfile)


if @debug = 1 print convert(varchar(30), getdate(), 121) +'   '+ 'Ended sp_export_query_to_text, ' + @template_name + ': ' + @tablename
insert EQ_Extract..BiennialDebugInfo (biennial_id, log_time, log_message) values (@newid, getdate(), 'Ended sp_export_query_to_text, ' + @template_name + ': ' + @tablename)

if @debug = 1 print convert(varchar(30), getdate(), 121) +'   '+ 'starting sp_biennial_report_output_WR'
insert EQ_Extract..BiennialDebugInfo (biennial_id, log_time, log_message) values (@newid, getdate(), 'starting sp_biennial_report_output_WR')

exec sp_biennial_report_output_WR @newid, @state

if @debug = 1 print convert(varchar(30), getdate(), 121) +'   '+ 'ended sp_biennial_report_output_WR'
insert EQ_Extract..BiennialDebugInfo (biennial_id, log_time, log_message) values (@newid, getdate(), 'ended sp_biennial_report_output_WR')



/*********************************
	FILE OUTPUT: WR1
**********************************/
set @outputfile = 'WR1'	
set @brs_outputfile = @brs_filename_pre	+ @outputfile + @brs_filename_suf

-- exec sp_biennial_report_output_extract @newid, @state, @outputfile, 'T'

select 
	@tmp_desc = upper(@state) + ' Biennial ' + @outputfile + ' Export: ' 
		+ @tsdf_code + ' - '
		+ convert(varchar(10), @start_date, 110) + ' - ' 
		+ convert(varchar(12), @end_date, 110),
	@tmp_filename = upper(@state) + '-Biennial-' + @outputfile + ' ' 
		+ @tsdf_code + ' - '
		+ @from_to_file_date + ' - '
		+ @brs_outputfile + ' -.txt',
	@template_name = 'sp_biennial_' + upper(@state) + '_' + @outputfile + '.1',
	-- 2/10/2016 - Ohio is reporting that there's 126, even though my math says 125.  So I'm taking 1 char off the waste desc at the end.
	-- @tablename = 'SELECT HANDLER_ID + HZ_PG + SUB_PG_NUM + FORM_CODE + UNIT_OF_MEASURE + WST_DENSITY + DENSITY_UNIT_OF_MEASURE + INCLUDE_IN_NATIONAL_REPORT + MANAGEMENT_METHOD + IO_TDR_ID + IO_TDR_QTY + CASE ''' + @state + ''' WHEN ''OH'' THEN LEFT(IsNull(DESCRIPTION,'' '') + SPACE(60), 60) ELSE LEFT(IsNull(DESCRIPTION,'' '') + SPACE(240), 240) END + CASE ''' + @state + ''' WHEN ''OH'' THEN '''' ELSE LEFT(IsNull(NOTES,'' '') + SPACE(240), 240) END	as [Report] FROM EQ_Extract..BiennialReportWork_WR1 WHERE biennial_id = ' + convert(varchar(20), @newid) + ' ORDER BY HANDLER_ID, HZ_PG, SUB_PG_NUM '
	-- 2/4/2020 - OHIO wants the sub page # now.
	-- @tablename = 'SELECT HANDLER_ID + HZ_PG + CASE ''' + @state + ''' WHEN ''OH'' THEN '''' ELSE SUB_PG_NUM END + FORM_CODE + UNIT_OF_MEASURE + WST_DENSITY + DENSITY_UNIT_OF_MEASURE + INCLUDE_IN_NATIONAL_REPORT + MANAGEMENT_METHOD + IO_TDR_ID + IO_TDR_QTY + CASE ''' + @state + ''' WHEN ''OH'' THEN LEFT(IsNull(DESCRIPTION,'' '') + SPACE(60), 59) ELSE LEFT(IsNull(DESCRIPTION,'' '') + SPACE(240), 240) END + CASE ''' + @state + ''' WHEN ''OH'' THEN '''' ELSE LEFT(IsNull(NOTES,'' '') + SPACE(240), 240) END	as [Report] FROM EQ_Extract..BiennialReportWork_WR1 WHERE biennial_id = ' + convert(varchar(20), @newid) + ' ORDER BY HANDLER_ID, HZ_PG, SUB_PG_NUM '
	@tablename = 'SELECT HANDLER_ID + HZ_PG + SUB_PG_NUM + FORM_CODE + UNIT_OF_MEASURE + WST_DENSITY + DENSITY_UNIT_OF_MEASURE + INCLUDE_IN_NATIONAL_REPORT + MANAGEMENT_METHOD + IO_TDR_ID + IO_TDR_QTY + CASE ''' + @state + ''' WHEN ''OH'' THEN LEFT(IsNull(DESCRIPTION,'' '') + SPACE(60), 59) ELSE LEFT(IsNull(DESCRIPTION,'' '') + SPACE(240), 240) END + CASE ''' + @state + ''' WHEN ''OH'' THEN '''' ELSE LEFT(IsNull(NOTES,'' '') + SPACE(240), 240) END	as [Report] FROM EQ_Extract..BiennialReportWork_WR1 WHERE biennial_id = ' + convert(varchar(20), @newid) + ' ORDER BY HANDLER_ID, HZ_PG, SUB_PG_NUM '

	-- select @tmp_desc, @tmp_filename, @template_name, @tablename

if @debug = 1 print convert(varchar(30), getdate(), 121) +'   '+ 'Starting sp_export_query_to_text, ' + @template_name + ': ' + @tablename
insert EQ_Extract..BiennialDebugInfo (biennial_id, log_time, log_message) values (@newid, getdate(), 'Starting sp_export_query_to_text, ' + @template_name + ': ' + @tablename)

/*
exec plt_export.dbo.sp_export_query_to_text 
	@table_name	= @tablename,
	@template	= @template_name,
	@filename	= @tmp_filename,
	@header_lines_to_remove = 2,
	@added_by	= @user_code,
	@export_desc = @tmp_desc,
	@report_log_id = @report_log_id
*/

SELECT HANDLER_ID + HZ_PG + SUB_PG_NUM + FORM_CODE 
	+ UNIT_OF_MEASURE + WST_DENSITY + DENSITY_UNIT_OF_MEASURE 
	+ INCLUDE_IN_NATIONAL_REPORT + MANAGEMENT_METHOD 
	+ IO_TDR_ID + IO_TDR_QTY 
	+ CASE @state WHEN 'OH' THEN LEFT(IsNull(DESCRIPTION,' ') + SPACE(60), 59) 
		ELSE LEFT(IsNull(DESCRIPTION,' ') + SPACE(240), 240) END 
	+ CASE @state WHEN 'OH' THEN '' ELSE LEFT(IsNull(NOTES,' ') + SPACE(240), 240) END	
	as [Report] 
FROM EQ_Extract..BiennialReportWork_WR1 
WHERE biennial_id = @newid 
ORDER BY HANDLER_ID, HZ_PG, SUB_PG_NUM 

insert @recordsetname (recordsetname) values (@outputfile + '.' + @brs_outputfile)

if @debug = 1 print convert(varchar(30), getdate(), 121) +'   '+ 'Ending sp_export_query_to_text, ' + @template_name + ': ' + @tablename
insert EQ_Extract..BiennialDebugInfo (biennial_id, log_time, log_message) values (@newid, getdate(), 'Ending sp_export_query_to_text, ' + @template_name + ': ' + @tablename)
	
/*********************************
	FILE OUTPUT: WR2
**********************************/
set @outputfile = 'WR2'	
set @brs_outputfile = @brs_filename_pre	+ @outputfile + @brs_filename_suf

-- exec sp_biennial_report_output_extract @newid, @state, @outputfile, 'T'
--exec sp_biennial_report_output_extract_OH 309, 'GM1', 'F'
-- exec sp_biennial_report_output_extract 1110, 'OH', 'GM1', 'T'

select 
	@tmp_desc = upper(@state) + ' Biennial ' + @outputfile + ' Export: ' 
		+ @tsdf_code + ' - '
		+ convert(varchar(10), @start_date, 110) + ' - ' 
		+ convert(varchar(12), @end_date, 110),
	@tmp_filename = upper(@state) + '-Biennial-' + @outputfile + ' ' 
		+ @tsdf_code + ' - '
		+ @from_to_file_date + ' - '
		+ @brs_outputfile + ' -.txt',
	@template_name = 'sp_biennial_' + upper(@state) + '_' + @outputfile + '.1',
	@tablename = 'SELECT HANDLER_ID + HZ_PG + SUB_PG_NUM + EPA_WASTE_CODE as [Report] FROM EQ_Extract..BiennialReportWork_WR2 WHERE biennial_id = ' + convert(varchar(20), @newid) + ' ORDER BY HANDLER_ID, HZ_PG, SUB_PG_NUM, EPA_WASTE_CODE'

if @debug = 1 print convert(varchar(30), getdate(), 121) +'   '+ 'Starting sp_export_query_to_text, ' + @template_name + ': ' + @tablename
insert EQ_Extract..BiennialDebugInfo (biennial_id, log_time, log_message) values (@newid, getdate(), 'Starting sp_export_query_to_text, ' + @template_name + ': ' + @tablename)

/*
exec plt_export.dbo.sp_export_query_to_text 
	@table_name	= @tablename,
	@template	= @template_name,
	@filename	= @tmp_filename,
	@header_lines_to_remove = 2,
	@added_by	= @user_code,
	@export_desc = @tmp_desc,
	@report_log_id = @report_log_id
*/

SELECT HANDLER_ID + HZ_PG + SUB_PG_NUM + EPA_WASTE_CODE as [Report] 
FROM EQ_Extract..BiennialReportWork_WR2 
WHERE biennial_id = @newid
ORDER BY HANDLER_ID, HZ_PG, SUB_PG_NUM, EPA_WASTE_CODE

insert @recordsetname (recordsetname) values (@outputfile + '.' + @brs_outputfile)


if @debug = 1 print convert(varchar(30), getdate(), 121) +'   '+ 'Ending sp_export_query_to_text, ' + @template_name + ': ' + @tablename
insert EQ_Extract..BiennialDebugInfo (biennial_id, log_time, log_message) values (@newid, getdate(), 'Ending sp_export_query_to_text, ' + @template_name + ': ' + @tablename)
	
/*********************************
	FILE OUTPUT: WR3
**********************************/
IF @state_haz_waste_code > 0 BEGIN
	set @outputfile = 'WR3'	
	set @brs_outputfile = @brs_filename_pre	+ @outputfile + @brs_filename_suf
	
--	exec sp_biennial_report_output_extract @newid, @state, @outputfile, 'T'
	--exec sp_biennial_report_output_extract_OH 309, 'GM1', 'F'

	select 
		@tmp_desc = upper(@state) + ' Biennial ' + @outputfile + ' Export: ' 
			+ @tsdf_code + ' - '
			+ convert(varchar(10), @start_date, 110) + ' - ' 
			+ convert(varchar(12), @end_date, 110),
		@tmp_filename = upper(@state) + '-Biennial-' + @outputfile + ' ' 
			+ @tsdf_code + ' - '
			+ @from_to_file_date + ' - '
			+ @brs_outputfile + ' -.txt',
		@template_name = 'sp_biennial_' + upper(@state) + '_' + @outputfile + '.1',
		@tablename = 'SELECT HANDLER_ID + HZ_PG + SUB_PG_NUM + STATE_WASTE_CODE as [Report] FROM EQ_Extract..BiennialReportWork_WR3 WHERE biennial_id = ' + convert(varchar(20), @newid) + ' ORDER BY HANDLER_ID, HZ_PG, SUB_PG_NUM, STATE_WASTE_CODE '

	if @debug = 1 print convert(varchar(30), getdate(), 121) +'   '+ 'Starting sp_export_query_to_text, ' + @template_name + ': ' + @tablename
	insert EQ_Extract..BiennialDebugInfo (biennial_id, log_time, log_message) values (@newid, getdate(), 'Starting sp_export_query_to_text, ' + @template_name + ': ' + @tablename)

	/*
	exec plt_export.dbo.sp_export_query_to_text 
		@table_name	= @tablename,
		@template	= @template_name,
		@filename	= @tmp_filename,
		@header_lines_to_remove = 2,
		@added_by	= @user_code,
		@export_desc = @tmp_desc,
		@report_log_id = @report_log_id
	*/

	SELECT HANDLER_ID + HZ_PG + SUB_PG_NUM + STATE_WASTE_CODE as [Report] 
	FROM EQ_Extract..BiennialReportWork_WR3 
	WHERE biennial_id = @newid 
	ORDER BY HANDLER_ID, HZ_PG, SUB_PG_NUM, STATE_WASTE_CODE 

	insert @recordsetname (recordsetname) values (@outputfile + '.' + @brs_outputfile)

	if @debug = 1 print convert(varchar(30), getdate(), 121) +'   '+ 'Ending sp_export_query_to_text, ' + @template_name + ': ' + @tablename
	insert EQ_Extract..BiennialDebugInfo (biennial_id, log_time, log_message) values (@newid, getdate(), 'Ending sp_export_query_to_text, ' + @template_name + ': ' + @tablename)
		
END	
	
/*********************************
	FILE OUTPUT: PS
**********************************/
set @outputfile = 'PS'	
set @brs_outputfile = @brs_filename_pre	+ @outputfile + @brs_filename_suf

-- exec sp_biennial_report_output_extract @newid, @state, @outputfile, 'T'
--exec sp_biennial_report_output_extract 1110, 'OH', 'PS', 'T'

select 
	@tmp_desc = upper(@state) + ' Biennial ' + @outputfile + ' Export: ' 
		+ @tsdf_code + ' - '
		+ convert(varchar(10), @start_date, 110) + ' - ' 
		+ convert(varchar(12), @end_date, 110),
	@tmp_filename = upper(@state) + '-Biennial-' + @outputfile + ' ' 
		+ @tsdf_code + ' - '
		+ @from_to_file_date + ' - '
		+ @brs_outputfile + ' -.txt',
	@template_name = 'sp_biennial_' + upper(@state) + '_' + @outputfile + '.1',
	-- @tablename = ' SELECT convert(varchar(200), CONVERT(DECIMAL(18, 3), SUM(ISNULL(lbs_haz_estimated,0)))) + '' '' + ISNULL(management_code,''NULL'') as Report FROM EQ_Extract..BiennialReportSourceData src WHERE biennial_id = ' + convert(varchar(20), @newid) + ' group by management_code	'
	@tablename = ' SELECT convert(varchar(200), CONVERT(DECIMAL(18, 3), SUM(ISNULL(lbs_haz_estimated,0)))) + '' '' + ISNULL(management_code,''NULL'') as Report FROM EQ_Extract..BiennialReportSourceData src WHERE biennial_id = ' + convert(varchar(20), @newid) + CASE WHEN @state = 'OH' THEN ' AND trans_mode = ''I'' ' ELSE '' END + ' group by management_code	'

if @debug = 1 print convert(varchar(30), getdate(), 121) +'   '+ 'Starting sp_export_query_to_text, ' + @template_name + ': ' + @tablename
insert EQ_Extract..BiennialDebugInfo (biennial_id, log_time, log_message) values (@newid, getdate(), 'Starting sp_export_query_to_text, ' + @template_name + ': ' + @tablename)

/*
exec plt_export.dbo.sp_export_query_to_text 
	@table_name	= @tablename,
	@template	= @template_name,
	@filename	= @tmp_filename,
	@header_lines_to_remove = 2,
	@added_by	= @user_code,
	@export_desc = @tmp_desc,
	@report_log_id = @report_log_id
*/

SELECT convert(varchar(200), CONVERT(DECIMAL(18, 3)
	, SUM(ISNULL(lbs_haz_estimated,0)))) + ' ' 
	+ ISNULL(management_code,'NULL') as Report 
FROM EQ_Extract..BiennialReportSourceData src 
WHERE biennial_id = @newid
AND trans_mode = case when @state = 'OH' then 'I' ELSE trans_mode END
group by management_code	

insert @recordsetname (recordsetname) values (@outputfile + '.' + @brs_outputfile)


if @debug = 1 print convert(varchar(30), getdate(), 121) +'   '+ 'Ending sp_export_query_to_text, ' + @template_name + ': ' + @tablename
insert EQ_Extract..BiennialDebugInfo (biennial_id, log_time, log_message) values (@newid, getdate(), 'Ending sp_export_query_to_text, ' + @template_name + ': ' + @tablename)


/*********************************
	FILE OUTPUT: Worksheet GM
**********************************/
-- exec sp_biennial_report_worksheet_GM @newid, @state
--exec sp_biennial_report_worksheet_GM 1110, 'OH'

select 
	@tmp_desc = upper(@state) + ' Biennial GM Worksheet: ' 
		+ @tsdf_code + ' - '
		+ convert(varchar(10), @start_date, 110) + ' - ' 
		+ convert(varchar(12), @end_date, 110),
	@tmp_filename = upper(@state) + '-Biennial-GM-Worksheet ' 
		+ @tsdf_code + ' - '
		+ @from_to_file_date + '.xlsx',
	@template_name = 'sp_biennial_report_worksheet_GM.1',
	-- @tablename = 'SELECT DISTINCT x.biennial_id, x.hz_pg, sd.TRANS_MODE, sd.Company_id, sd.profit_ctr_id, sd.profit_ctr_epa_id, sd.receipt_id, sd.line_id, sd.container_id, sd.sequence_id, sd.treatment_id, sd.management_code, sd.lbs_haz_estimated AS LBS_HAZ, lbs_actual_match = CASE sd.lbs_haz_estimated WHEN sd.lbs_haz_actual THEN ''T'' ELSE ''F'' END, sd.manifest, sd.manifest_line_id, sd.approval_code, sd.EPA_form_code, sd.EPA_source_code, sd.waste_desc, sd.waste_density, sd.waste_consistency, sd.eq_generator_id, sd.generator_epa_id, sd.generator_name, sd.generator_address_1, sd.generator_address_2, sd.generator_address_3, sd.generator_address_4, sd.generator_address_5, sd.generator_city, sd.generator_state, sd.generator_zip_code, sd.generator_state_id, sd.transporter_EPA_ID, sd.transporter_name, sd.transporter_addr1, sd.transporter_addr2, sd.transporter_addr3, sd.transporter_city, sd.transporter_state, sd.transporter_zip_code, sd.TSDF_EPA_ID, sd.TSDF_name, sd.TSDF_addr1, sd.TSDF_addr2, sd.TSDF_addr3, sd.TSDF_city, sd.TSDF_state, sd.TSDF_zip_code FROM  EQ_Extract..BiennialReportWork_GM1 x INNER JOIN EQ_Extract..BiennialReportSourceData SD on x.biennial_id = sd.biennial_id and x.approval_code = sd.approval_code WHERE sd.biennial_id = ' + convert(varchar(20), @newid) + ' AND SD.TRANS_MODE = ''O'' '
	@tablename = 'SELECT DISTINCT sd.biennial_id, (select hz_pg from EQ_Extract..BiennialReportWork_GM1 x WHERE x.biennial_id = sd.biennial_id and x.approval_code = sd.approval_code and x.form_code = sd.epa_form_code and x.source_code = sd.epa_source_code and x.description = sd.waste_desc) as hz_pg, sd.TRANS_MODE, sd.Company_id, sd.profit_ctr_id, sd.profit_ctr_epa_id, sd.receipt_id, sd.line_id, sd.container_id, sd.sequence_id, sd.treatment_id, sd.management_code, sd.lbs_haz_estimated AS LBS_HAZ, lbs_actual_match = CASE sd.lbs_haz_estimated WHEN sd.lbs_haz_actual THEN ''T'' ELSE ''F'' END, sd.manifest, sd.manifest_line_id, sd.approval_code, sd.EPA_form_code, sd.EPA_source_code, sd.waste_desc, sd.waste_density, sd.waste_consistency, sd.eq_generator_id, sd.generator_epa_id, sd.generator_name, sd.generator_address_1, sd.generator_address_2, sd.generator_address_3, sd.generator_address_4, sd.generator_address_5, sd.generator_city, sd.generator_state, sd.generator_zip_code, sd.generator_state_id, sd.transporter_EPA_ID, sd.transporter_name, sd.transporter_addr1, sd.transporter_addr2, sd.transporter_addr3, sd.transporter_city, sd.transporter_state, sd.transporter_zip_code, sd.TSDF_EPA_ID, sd.TSDF_name, sd.TSDF_addr1, sd.TSDF_addr2, sd.TSDF_addr3, sd.TSDF_city, sd.TSDF_state, sd.TSDF_zip_code FROM  EQ_Extract..BiennialReportSourceData SD WHERE sd.biennial_id = ' + convert(varchar(20), @newid) + ' AND ((SD.TRANS_MODE = ''O'') OR (SD.TRANS_MODE = ''I'' AND SD.profit_ctr_epa_id = SD.generator_epa_id AND SD.generator_country = ''US'')) '
	
if @debug = 1 print convert(varchar(30), getdate(), 121) +'   '+ 'Starting sp_export_query_to_excel, ' + @template_name + ': ' + @tablename
insert EQ_Extract..BiennialDebugInfo (biennial_id, log_time, log_message) values (@newid, getdate(), 'Starting sp_export_query_to_excel, ' + @template_name + ': ' + @tablename)

/*
exec plt_export.dbo.sp_export_query_to_excel
	@table_name	= @tablename,
	@template	= @template_name,
	@filename	= @tmp_filename,
	@added_by	= @user_code,
	@export_desc = @tmp_desc,
	@report_log_id = @report_log_id,
	@debug = @tmp_debug
*/

SELECT DISTINCT sd.biennial_id, (select hz_pg 
	from EQ_Extract..BiennialReportWork_GM1 x 
	WHERE x.biennial_id = sd.biennial_id and x.approval_code = sd.approval_code 
		and x.form_code = sd.epa_form_code and x.source_code = sd.epa_source_code 
		and x.description = sd.waste_desc) as hz_pg
	, sd.TRANS_MODE, sd.Company_id, sd.profit_ctr_id, sd.profit_ctr_epa_id
	, sd.receipt_id, sd.line_id, sd.container_id, sd.sequence_id
	, sd.treatment_id, sd.management_code, sd.lbs_haz_estimated AS LBS_HAZ
	, lbs_actual_match = CASE sd.lbs_haz_estimated WHEN sd.lbs_haz_actual THEN 'T' ELSE 'F' END
	, sd.manifest, sd.manifest_line_id, sd.approval_code, sd.EPA_form_code
	, sd.EPA_source_code, sd.waste_desc, sd.waste_density, sd.waste_consistency
	, sd.eq_generator_id, sd.generator_epa_id, sd.generator_name
	, sd.generator_address_1, sd.generator_address_2, sd.generator_address_3
	, sd.generator_address_4, sd.generator_address_5, sd.generator_city
	, sd.generator_state, sd.generator_zip_code, sd.generator_state_id
	, sd.transporter_EPA_ID, sd.transporter_name, sd.transporter_addr1
	, sd.transporter_addr2, sd.transporter_addr3, sd.transporter_city
	, sd.transporter_state, sd.transporter_zip_code, sd.TSDF_EPA_ID
	, sd.TSDF_name, sd.TSDF_addr1, sd.TSDF_addr2, sd.TSDF_addr3
	, sd.TSDF_city, sd.TSDF_state, sd.TSDF_zip_code 
FROM  EQ_Extract..BiennialReportSourceData SD 
WHERE sd.biennial_id = @newid
AND ((SD.TRANS_MODE = 'O') OR (SD.TRANS_MODE = 'I' AND SD.profit_ctr_epa_id = SD.generator_epa_id AND SD.generator_country = 'US')) 

insert @recordsetname (recordsetname) values ('GM Worksheet')

if @debug = 1 print convert(varchar(30), getdate(), 121) +'   '+ 'Ending sp_export_query_to_excel, ' + @template_name + ': ' + @tablename
insert EQ_Extract..BiennialDebugInfo (biennial_id, log_time, log_message) values (@newid, getdate(), 'Ending sp_export_query_to_excel, ' + @template_name + ': ' + @tablename)

/*********************************
	FILE OUTPUT: Worksheet GM Wastecodes
**********************************/
-- exec sp_biennial_report_worksheet_GM_wastecodes @newid, @state
--exec sp_biennial_report_worksheet_GM_wastecodes 1110, 'OH'

select 
	@tmp_desc = upper(@state) + ' Biennial GM Waste Codes Worksheet: ' 
		+ @tsdf_code + ' - '
		+ convert(varchar(10), @start_date, 110) + ' - ' 
		+ convert(varchar(12), @end_date, 110),
	@tmp_filename = upper(@state) + '-Biennial-GM-WasteCodes-Worksheet ' 
		+ @tsdf_code + ' - '
		+ @from_to_file_date + '.xlsx',
	@template_name = 'sp_biennial_report_worksheet_GM_wastecodes.1',
	-- @tablename = 'SELECT distinct SW.biennial_id, x.hz_pg, SW.company_id, SW.profit_ctr_id, SW.receipt_id, SW.line_id, NULL as container_id, NULL as sequence_id, dbo.fn_receipt_waste_code_list_long(SW.company_id, SW.profit_ctr_id, SW.receipt_id, SW.line_id) as waste_code FROM EQ_Extract..BiennialReportWork_GM1 x INNER JOIN EQ_Extract..BiennialReportSourceData SD on x.biennial_id = sd.biennial_id and x.approval_code = sd.approval_code JOIN EQ_Extract..BiennialReportSourceWasteCode SW ON SD.biennial_id = SW.biennial_id AND SD.RECEIPT_ID = SW.RECEIPT_ID AND SD.LINE_ID = SW.LINE_ID AND SD.CONTAINER_ID = SW.CONTAINER_ID AND SD.SEQUENCE_ID = SW.SEQUENCE_ID AND SD.company_id = SW.company_id AND SD.profit_ctr_id = SW.profit_ctr_id WHERE SD.biennial_id = ' + convert(varchar(20), @newid) + ' AND SD.TRANS_MODE = ''O'' '
	-- @tablename = 'SELECT distinct SD.biennial_id, x.hz_pg, SD.company_id, SD.profit_ctr_id, SD.receipt_id, SD.line_id, NULL as container_id, NULL as sequence_id, (select SUBSTRING((SELECT '', '' + ltrim(rtrim(isnull(sw.waste_code, ''''))) FROM EQ_Extract..BiennialReportSourceWasteCode SW WHERE SD.biennial_id = SW.biennial_id AND SD.RECEIPT_ID = SW.RECEIPT_ID AND SD.LINE_ID = SW.LINE_ID AND SD.CONTAINER_ID = SW.CONTAINER_ID AND SD.SEQUENCE_ID = SW.SEQUENCE_ID AND SD.company_id = SW.company_id AND SD.profit_ctr_id = SW.profit_ctr_id ORDER BY SW.waste_code FOR XML Path('''')), 3, 20000)) as waste_code FROM EQ_Extract..BiennialReportWork_GM1 x INNER JOIN EQ_Extract..BiennialReportSourceData SD on x.biennial_id = sd.biennial_id and x.approval_code = sd.approval_code WHERE SD.biennial_id = ' + convert(varchar(20), @newid) + ' AND SD.TRANS_MODE = ''O'' '
	-- @tablename = 'SELECT distinct SD.biennial_id, (select hz_pg from EQ_Extract..BiennialReportWork_GM1 x WHERE x.biennial_id = sd.biennial_id and x.approval_code = sd.approval_code and x.form_code = sd.epa_form_code and x.source_code = sd.epa_source_code and x.description = sd.waste_desc) as hz_pg, SD.company_id, SD.profit_ctr_id, SD.receipt_id, SD.line_id, NULL as container_id, NULL as sequence_id, (select SUBSTRING((SELECT '', '' + ltrim(rtrim(isnull(sw.waste_code, ''''))) FROM EQ_Extract..BiennialReportSourceWasteCode SW WHERE SD.biennial_id = SW.biennial_id AND SD.RECEIPT_ID = SW.RECEIPT_ID AND SD.LINE_ID = SW.LINE_ID AND SD.CONTAINER_ID = SW.CONTAINER_ID AND SD.SEQUENCE_ID = SW.SEQUENCE_ID AND SD.company_id = SW.company_id AND SD.profit_ctr_id = SW.profit_ctr_id ORDER BY SW.waste_code FOR XML Path('''')), 3, 20000)) as waste_code FROM EQ_Extract..BiennialReportSourceData SD WHERE SD.biennial_id = ' + convert(varchar(20), @newid) + ' AND SD.TRANS_MODE = ''O'' '
	@tablename = 'SELECT distinct SD.biennial_id, (select hz_pg from EQ_Extract..BiennialReportWork_GM1 x WHERE x.biennial_id = sd.biennial_id and x.approval_code = sd.approval_code and x.form_code = sd.epa_form_code and x.source_code = sd.epa_source_code and x.description = sd.waste_desc) as hz_pg, SD.company_id, SD.profit_ctr_id, SD.receipt_id, SD.line_id, NULL as container_id, NULL as sequence_id, case when datalength((select SUBSTRING((SELECT '', '' + ltrim(rtrim(isnull(sw.waste_code, ''''))) FROM EQ_Extract..BiennialReportSourceWasteCode SW WHERE SD.biennial_id = SW.biennial_id AND SD.RECEIPT_ID = SW.RECEIPT_ID AND SD.LINE_ID = SW.LINE_ID AND SD.CONTAINER_ID = SW.CONTAINER_ID AND SD.SEQUENCE_ID = SW.SEQUENCE_ID AND SD.company_id = SW.company_id AND SD.profit_ctr_id = SW.profit_ctr_id ORDER BY SW.waste_code FOR XML Path('''')), 3, 20000))) > ' + convert(varchar(10), @max_excel_wastecode_len) + ' then left((select SUBSTRING((SELECT '', '' + ltrim(rtrim(isnull(sw.waste_code, ''''))) FROM EQ_Extract..BiennialReportSourceWasteCode SW WHERE SD.biennial_id = SW.biennial_id AND SD.RECEIPT_ID = SW.RECEIPT_ID AND SD.LINE_ID = SW.LINE_ID AND SD.CONTAINER_ID = SW.CONTAINER_ID AND SD.SEQUENCE_ID = SW.SEQUENCE_ID AND SD.company_id = SW.company_id AND SD.profit_ctr_id = SW.profit_ctr_id ORDER BY SW.waste_code FOR XML Path('''')), 3, 20000)), ' + convert(varchar(10), @max_excel_wastecode_len) + ') + '' ... MORE: See Receipt'' else (select SUBSTRING((SELECT '', '' + ltrim(rtrim(isnull(sw.waste_code, ''''))) FROM EQ_Extract..BiennialReportSourceWasteCode SW WHERE SD.biennial_id = SW.biennial_id AND SD.RECEIPT_ID = SW.RECEIPT_ID AND SD.LINE_ID = SW.LINE_ID AND SD.CONTAINER_ID = SW.CONTAINER_ID AND SD.SEQUENCE_ID = SW.SEQUENCE_ID AND SD.company_id = SW.company_id AND SD.profit_ctr_id = SW.profit_ctr_id ORDER BY SW.waste_code FOR XML Path('''')), 3, 20000)) end as waste_code FROM EQ_Extract..BiennialReportSourceData SD WHERE SD.biennial_id = ' + convert(varchar(20), @newid) + ' AND SD.TRANS_MODE = ''O'' '


if @debug = 1 print convert(varchar(30), getdate(), 121) +'   '+ 'Starting sp_export_query_to_excel, ' + @template_name + ': ' + @tablename
insert EQ_Extract..BiennialDebugInfo (biennial_id, log_time, log_message) values (@newid, getdate(), 'Starting sp_export_query_to_excel, ' + @template_name + ': ' + @tablename)

/*
exec plt_export.dbo.sp_export_query_to_excel
	@table_name	= @tablename,
	@template	= @template_name,
	@filename	= @tmp_filename,
	@added_by	= @user_code,
	@export_desc = @tmp_desc,
	@report_log_id = @report_log_id,
	@debug = @tmp_debug
*/

SELECT distinct SD.biennial_id
	, (select hz_pg from EQ_Extract..BiennialReportWork_GM1 x WHERE 
		x.biennial_id = sd.biennial_id and x.approval_code = sd.approval_code 
		and x.form_code = sd.epa_form_code and x.source_code = sd.epa_source_code 
		and x.description = sd.waste_desc) as hz_pg
	, SD.company_id, SD.profit_ctr_id, SD.receipt_id, SD.line_id
	, NULL as container_id, NULL as sequence_id
	, case when datalength((select SUBSTRING((SELECT ', ' + ltrim(rtrim(isnull(sw.waste_code, ''))) 
	FROM EQ_Extract..BiennialReportSourceWasteCode SW 
	WHERE SD.biennial_id = SW.biennial_id AND SD.RECEIPT_ID = SW.RECEIPT_ID 
	AND SD.LINE_ID = SW.LINE_ID AND SD.CONTAINER_ID = SW.CONTAINER_ID 
	AND SD.SEQUENCE_ID = SW.SEQUENCE_ID AND SD.company_id = SW.company_id 
	AND SD.profit_ctr_id = SW.profit_ctr_id 
	ORDER BY SW.waste_code FOR XML Path('')), 3, 20000))) > @max_excel_wastecode_len then 
		left((select SUBSTRING((SELECT ', ' + ltrim(rtrim(isnull(sw.waste_code, ''))) 
		FROM EQ_Extract..BiennialReportSourceWasteCode SW WHERE SD.biennial_id = SW.biennial_id 
		AND SD.RECEIPT_ID = SW.RECEIPT_ID AND SD.LINE_ID = SW.LINE_ID 
		AND SD.CONTAINER_ID = SW.CONTAINER_ID AND SD.SEQUENCE_ID = SW.SEQUENCE_ID 
		AND SD.company_id = SW.company_id AND SD.profit_ctr_id = SW.profit_ctr_id 
		ORDER BY SW.waste_code FOR XML Path('')), 3, 20000)), @max_excel_wastecode_len) 
		+ ' ... MORE: See Receipt' else (select SUBSTRING((SELECT ', ' 
			+ ltrim(rtrim(isnull(sw.waste_code, ''))) 
			FROM EQ_Extract..BiennialReportSourceWasteCode SW 
			WHERE SD.biennial_id = SW.biennial_id AND SD.RECEIPT_ID = SW.RECEIPT_ID 
			AND SD.LINE_ID = SW.LINE_ID AND SD.CONTAINER_ID = SW.CONTAINER_ID 
			AND SD.SEQUENCE_ID = SW.SEQUENCE_ID AND SD.company_id = SW.company_id 
			AND SD.profit_ctr_id = SW.profit_ctr_id ORDER BY SW.waste_code FOR XML Path('')), 3, 20000)) end as waste_code 
			FROM EQ_Extract..BiennialReportSourceData SD WHERE SD.biennial_id = @newid
			AND SD.TRANS_MODE = 'O' 

			insert @recordsetname (recordsetname) values ('GM WasteCodes Worksheet')

if @debug = 1 print convert(varchar(30), getdate(), 121) +'   '+ 'Ending sp_export_query_to_excel, ' + @template_name + ': ' + @tablename
insert EQ_Extract..BiennialDebugInfo (biennial_id, log_time, log_message) values (@newid, getdate(), 'Ending sp_export_query_to_excel, ' + @template_name + ': ' + @tablename)


/*********************************
	FILE OUTPUT: Worksheet WR
**********************************/
-- exec sp_biennial_report_worksheet_WR @newid, @state

select 
	@tmp_desc = upper(@state) + ' Biennial WR Worksheet: ' 
		+ @tsdf_code + ' - '
		+ convert(varchar(10), @start_date, 110) + ' - ' 
		+ convert(varchar(12), @end_date, 110),
	@tmp_filename = upper(@state) + '-Biennial-WR-Worksheet ' 
		+ @tsdf_code + ' - '
		+ @from_to_file_date + '.xlsx',
	@template_name = 'sp_biennial_report_worksheet_WR.1',
	-- @tablename = 'SELECT DISTINCT SD.biennial_id, x.hz_pg, TRANS_MODE ,Company_id ,profit_ctr_id ,profit_ctr_epa_id  ,receipt_id,line_id,container_id,sequence_id,treatment_id,management_code,lbs_haz_estimated AS LBS_HAZ,lbs_actual_match = CASE lbs_haz_estimated WHEN lbs_haz_actual THEN ''T'' ELSE ''F'' END,manifest,manifest_line_id,sd.approval_code,EPA_form_code ,EPA_source_code,waste_desc,waste_density,waste_consistency,SD.eq_generator_id,generator_epa_id,generator_name,generator_address_1 ,generator_address_2,generator_address_3 ,generator_address_4  ,generator_address_5,generator_city,generator_state,generator_zip_code,generator_state_id,transporter_EPA_ID,transporter_name ,transporter_addr1,transporter_addr2,transporter_addr3,transporter_city ,transporter_state ,transporter_zip_code,TSDF_EPA_ID ,TSDF_name,TSDF_addr1,TSDF_addr2,TSDF_addr3,TSDF_city,TSDF_state,TSDF_zip_code FROM EQ_Extract..BiennialReportWork_WR1 x JOIN EQ_Extract..BiennialReportSourceData SD on x.biennial_id = sd.biennial_id and x.approval_code = sd.approval_code and x.eq_generator_id = sd.eq_generator_id WHERE sd.biennial_id = ' + convert(varchar(20), @newid) + ' AND SD.TRANS_MODE = ''I'' '
	@tablename = 'SELECT DISTINCT SD.biennial_id, (select hz_pg from EQ_Extract..BiennialReportWork_WR1 x WHERE x.biennial_id = sd.biennial_id and x.approval_code = sd.approval_code and x.eq_generator_id = sd.eq_generator_id and x.management_method = sd.management_code) as hz_pg, TRANS_MODE ,Company_id ,profit_ctr_id ,profit_ctr_epa_id  ,receipt_id,line_id,container_id,sequence_id,treatment_id,management_code,lbs_haz_estimated AS LBS_HAZ,lbs_actual_match = CASE lbs_haz_estimated WHEN lbs_haz_actual THEN ''T'' ELSE ''F'' END,manifest,manifest_line_id,sd.approval_code,EPA_form_code ,EPA_source_code,waste_desc,waste_density,waste_consistency,SD.eq_generator_id,generator_epa_id,generator_name,generator_address_1 ,generator_address_2,generator_address_3 ,generator_address_4  ,generator_address_5,generator_city,generator_state,generator_zip_code,generator_state_id,transporter_EPA_ID,transporter_name ,transporter_addr1,transporter_addr2,transporter_addr3,transporter_city ,transporter_state ,transporter_zip_code,TSDF_EPA_ID ,TSDF_name,TSDF_addr1,TSDF_addr2,TSDF_addr3,TSDF_city,TSDF_state,TSDF_zip_code FROM EQ_Extract..BiennialReportSourceData SD WHERE sd.biennial_id = ' + convert(varchar(20), @newid) + ' AND SD.TRANS_MODE = ''I'' AND NOT (SD.profit_ctr_epa_id = SD.generator_epa_id	AND SD.generator_country = ''US'')'

if @debug = 1 print convert(varchar(30), getdate(), 121) +'   '+ 'Starting sp_export_query_to_excel, ' + @template_name + ': ' + @tablename
insert EQ_Extract..BiennialDebugInfo (biennial_id, log_time, log_message) values (@newid, getdate(), 'Starting sp_export_query_to_excel, ' + @template_name + ': ' + @tablename)

/*
exec plt_export.dbo.sp_export_query_to_excel
	@table_name	= @tablename,
	@template	= @template_name,
	@filename	= @tmp_filename,
	@added_by	= @user_code,
	@export_desc = @tmp_desc,
	@report_log_id = @report_log_id,
	@debug = @tmp_debug
*/

SELECT DISTINCT SD.biennial_id
	, (select hz_pg from EQ_Extract..BiennialReportWork_WR1 x 
		WHERE x.biennial_id = sd.biennial_id and x.approval_code = sd.approval_code 
		and x.eq_generator_id = sd.eq_generator_id and x.management_method = sd.management_code) as hz_pg
	, TRANS_MODE ,Company_id ,profit_ctr_id ,profit_ctr_epa_id  ,receipt_id,line_id,container_id
	,sequence_id,treatment_id,management_code,lbs_haz_estimated AS LBS_HAZ
	,lbs_actual_match = CASE lbs_haz_estimated WHEN lbs_haz_actual THEN 'T' ELSE 'F' END
	,manifest,manifest_line_id,sd.approval_code,EPA_form_code ,EPA_source_code
	,waste_desc,waste_density,waste_consistency,SD.eq_generator_id,generator_epa_id
	,generator_name,generator_address_1 ,generator_address_2,generator_address_3 
	,generator_address_4  ,generator_address_5,generator_city,generator_state
	,generator_zip_code,generator_state_id,transporter_EPA_ID,transporter_name 
	,transporter_addr1,transporter_addr2,transporter_addr3,transporter_city 
	,transporter_state ,transporter_zip_code,TSDF_EPA_ID ,TSDF_name,TSDF_addr1
	,TSDF_addr2,TSDF_addr3,TSDF_city,TSDF_state,TSDF_zip_code 
FROM EQ_Extract..BiennialReportSourceData SD 
WHERE sd.biennial_id = @newid
AND SD.TRANS_MODE = 'I' AND NOT (SD.profit_ctr_epa_id = SD.generator_epa_id	AND SD.generator_country = 'US')

insert @recordsetname (recordsetname) values ('WR Worksheet')

if @debug = 1 print convert(varchar(30), getdate(), 121) +'   '+ 'Ending sp_export_query_to_excel, ' + @template_name + ': ' + @tablename
insert EQ_Extract..BiennialDebugInfo (biennial_id, log_time, log_message) values (@newid, getdate(), 'Ending sp_export_query_to_excel, ' + @template_name + ': ' + @tablename)

/*********************************
	FILE OUTPUT: Worksheet WR Wastecodes
**********************************/
-- exec sp_biennial_report_worksheet_WR_wastecodes @newid, @state
--exec sp_biennial_report_worksheet_WR_wastecodes 1110, 'OH'

select 
	@tmp_desc = upper(@state) + ' Biennial WR Waste Codes Worksheet: ' 
		+ @tsdf_code + ' - '
		+ convert(varchar(10), @start_date, 110) + ' - ' 
		+ convert(varchar(12), @end_date, 110),
	@tmp_filename = upper(@state) + '-Biennial-WR-WasteCodes-Worksheet ' 
		+ @tsdf_code + ' - '
		+ @from_to_file_date + '.xlsx',
	@template_name = 'sp_biennial_report_worksheet_WR_wastecodes.1.1',
	-- @tablename = 'SELECT DISTINCT SW.biennial_id, x.hz_pg, SW.company_id, SW.profit_ctr_id, SW.receipt_id, SW.line_id, NULL as container_id, NULL as sequence_id, dbo.fn_receipt_waste_code_list_long(SW.company_id, SW.profit_ctr_id, SW.receipt_id, SW.line_id) as waste_code FROM EQ_Extract..BiennialReportWork_WR1 x JOIN EQ_Extract..BiennialReportSourceData SD on x.biennial_id = sd.biennial_id and x.approval_code = sd.approval_code and x.eq_generator_id = sd.eq_generator_id JOIN EQ_Extract..BiennialReportSourceWasteCode SW ON SD.biennial_id = SW.biennial_id AND SD.RECEIPT_ID = SW.RECEIPT_ID AND SD.LINE_ID = SW.LINE_ID AND SD.CONTAINER_ID = SW.CONTAINER_ID AND SD.SEQUENCE_ID = SW.SEQUENCE_ID AND SD.company_id = SW.company_id AND SD.profit_ctr_id = SW.profit_ctr_id WHERE SD.biennial_id = ' + convert(varchar(20), @newid) + ' AND SD.TRANS_MODE = ''I'' '
	-- @tablename = 'SELECT DISTINCT SD.biennial_id, x.hz_pg, SD.company_id, SD.profit_ctr_id, SD.receipt_id, SD.line_id, NULL as container_id, NULL as sequence_id, (select SUBSTRING((SELECT '', '' + ltrim(rtrim(isnull(sw.waste_code, ''''))) FROM EQ_Extract..BiennialReportSourceWasteCode SW WHERE SD.biennial_id = SW.biennial_id AND SD.RECEIPT_ID = SW.RECEIPT_ID AND SD.LINE_ID = SW.LINE_ID AND SD.CONTAINER_ID = SW.CONTAINER_ID AND SD.SEQUENCE_ID = SW.SEQUENCE_ID AND SD.company_id = SW.company_id AND SD.profit_ctr_id = SW.profit_ctr_id ORDER BY SW.waste_code FOR XML Path('''')), 3, 20000)) as waste_code FROM EQ_Extract..BiennialReportWork_WR1 x JOIN EQ_Extract..BiennialReportSourceData SD on x.biennial_id = sd.biennial_id and x.approval_code = sd.approval_code and x.eq_generator_id = sd.eq_generator_id WHERE SD.biennial_id = ' + convert(varchar(20), @newid) + ' AND SD.TRANS_MODE = ''I'' '
	-- @tablename = 'SELECT DISTINCT SD.biennial_id, (select hz_pg from EQ_Extract..BiennialReportWork_WR1 x WHERE x.biennial_id = sd.biennial_id and x.approval_code = sd.approval_code and x.eq_generator_id = sd.eq_generator_id and x.management_method = sd.management_code) as hz_pg, SD.company_id, SD.profit_ctr_id, SD.receipt_id, SD.line_id, NULL as container_id, NULL as sequence_id, (select SUBSTRING((SELECT '', '' + ltrim(rtrim(isnull(sw.waste_code, ''''))) FROM EQ_Extract..BiennialReportSourceWasteCode SW WHERE SD.biennial_id = SW.biennial_id AND SD.RECEIPT_ID = SW.RECEIPT_ID AND SD.LINE_ID = SW.LINE_ID AND SD.CONTAINER_ID = SW.CONTAINER_ID AND SD.SEQUENCE_ID = SW.SEQUENCE_ID AND SD.company_id = SW.company_id AND SD.profit_ctr_id = SW.profit_ctr_id ORDER BY SW.waste_code FOR XML Path('''')), 3, 20000)) as waste_code FROM EQ_Extract..BiennialReportSourceData SD WHERE SD.biennial_id = ' + convert(varchar(20), @newid) + ' AND SD.TRANS_MODE = ''I'' '
	@tablename = 'SELECT DISTINCT SD.biennial_id, (select hz_pg from EQ_Extract..BiennialReportWork_WR1 x WHERE x.biennial_id = sd.biennial_id and x.approval_code = sd.approval_code and x.eq_generator_id = sd.eq_generator_id and x.management_method = sd.management_code) as hz_pg, SD.company_id, SD.profit_ctr_id, SD.receipt_id, SD.line_id, NULL as container_id, NULL as sequence_id, CASE WHEN datalength(rtrim((select SUBSTRING((SELECT '', '' + ltrim(rtrim(isnull(sw.waste_code, ''''))) FROM EQ_Extract..BiennialReportSourceWasteCode SW WHERE SD.biennial_id = SW.biennial_id AND SD.RECEIPT_ID = SW.RECEIPT_ID AND SD.LINE_ID = SW.LINE_ID AND SD.CONTAINER_ID = SW.CONTAINER_ID AND SD.SEQUENCE_ID = SW.SEQUENCE_ID AND SD.company_id = SW.company_id AND SD.profit_ctr_id = SW.profit_ctr_id ORDER BY SW.waste_code FOR XML Path('''')), 3, 20000)))) > ' + convert(varchar(10), @max_excel_wastecode_len) + ' then LEFT((select SUBSTRING((SELECT '', '' + ltrim(rtrim(isnull(sw.waste_code, ''''))) FROM EQ_Extract..BiennialReportSourceWasteCode SW WHERE SD.biennial_id = SW.biennial_id AND SD.RECEIPT_ID = SW.RECEIPT_ID AND SD.LINE_ID = SW.LINE_ID AND SD.CONTAINER_ID = SW.CONTAINER_ID AND SD.SEQUENCE_ID = SW.SEQUENCE_ID AND SD.company_id = SW.company_id AND SD.profit_ctr_id = SW.profit_ctr_id ORDER BY SW.waste_code FOR XML Path('''')), 3, 20000)), ' + convert(varchar(10), @max_excel_wastecode_len) + ') + '' ... MORE: See Receipt'' else rtrim((select SUBSTRING((SELECT '', '' + ltrim(rtrim(isnull(sw.waste_code, ''''))) FROM EQ_Extract..BiennialReportSourceWasteCode SW WHERE SD.biennial_id = SW.biennial_id AND SD.RECEIPT_ID = SW.RECEIPT_ID AND SD.LINE_ID = SW.LINE_ID AND SD.CONTAINER_ID = SW.CONTAINER_ID AND SD.SEQUENCE_ID = SW.SEQUENCE_ID AND SD.company_id = SW.company_id AND SD.profit_ctr_id = SW.profit_ctr_id ORDER BY SW.waste_code FOR XML Path('''')), 3, 20000))) end as waste_code FROM EQ_Extract..BiennialReportSourceData SD WHERE SD.biennial_id = ' + convert(varchar(20), @newid) + ' AND SD.TRANS_MODE = ''I'' AND NOT (SD.profit_ctr_epa_id = SD.generator_epa_id AND SD.generator_country = ''US'') ' 

if @debug = 1 print convert(varchar(30), getdate(), 121) +'   '+ 'Starting sp_export_query_to_excel, ' + @template_name + ': ' + @tablename
insert EQ_Extract..BiennialDebugInfo (biennial_id, log_time, log_message) values (@newid, getdate(), 'Starting sp_export_query_to_excel, ' + @template_name + ': ' + @tablename)

/*	
exec plt_export.dbo.sp_export_query_to_excel
	@table_name	= @tablename,
	@template	= @template_name,
	@filename	= @tmp_filename,
	@added_by	= @user_code,
	@export_desc = @tmp_desc,
	@report_log_id = @report_log_id,
	@debug = @tmp_debug
*/

SELECT DISTINCT 
	SD.biennial_id, (select hz_pg from EQ_Extract..BiennialReportWork_WR1 x WHERE x.biennial_id = sd.biennial_id and x.approval_code = sd.approval_code and x.eq_generator_id = sd.eq_generator_id and x.management_method = sd.management_code) as hz_pg
	, SD.company_id, SD.profit_ctr_id, SD.receipt_id, SD.line_id, NULL as container_id
	, NULL as sequence_id
	, CASE WHEN datalength(rtrim((select SUBSTRING((SELECT ', ' + ltrim(rtrim(isnull(sw.waste_code, ''))) FROM EQ_Extract..BiennialReportSourceWasteCode SW WHERE SD.biennial_id = SW.biennial_id AND SD.RECEIPT_ID = SW.RECEIPT_ID AND SD.LINE_ID = SW.LINE_ID AND SD.CONTAINER_ID = SW.CONTAINER_ID AND SD.SEQUENCE_ID = SW.SEQUENCE_ID AND SD.company_id = SW.company_id AND SD.profit_ctr_id = SW.profit_ctr_id ORDER BY SW.waste_code FOR XML Path('')), 3, 20000)))) > @max_excel_wastecode_len 
		then LEFT((select SUBSTRING((SELECT ', ' + ltrim(rtrim(isnull(sw.waste_code, ''))) FROM EQ_Extract..BiennialReportSourceWasteCode SW WHERE SD.biennial_id = SW.biennial_id AND SD.RECEIPT_ID = SW.RECEIPT_ID AND SD.LINE_ID = SW.LINE_ID AND SD.CONTAINER_ID = SW.CONTAINER_ID AND SD.SEQUENCE_ID = SW.SEQUENCE_ID AND SD.company_id = SW.company_id AND SD.profit_ctr_id = SW.profit_ctr_id ORDER BY SW.waste_code FOR XML Path('')), 3, 20000)), @max_excel_wastecode_len) 
		+ ' ... MORE: See Receipt' else rtrim((select SUBSTRING((SELECT ', ' + ltrim(rtrim(isnull(sw.waste_code, ''))) FROM EQ_Extract..BiennialReportSourceWasteCode SW WHERE SD.biennial_id = SW.biennial_id AND SD.RECEIPT_ID = SW.RECEIPT_ID AND SD.LINE_ID = SW.LINE_ID AND SD.CONTAINER_ID = SW.CONTAINER_ID AND SD.SEQUENCE_ID = SW.SEQUENCE_ID AND SD.company_id = SW.company_id AND SD.profit_ctr_id = SW.profit_ctr_id ORDER BY SW.waste_code FOR XML Path('')), 3, 20000))) end as waste_code 
FROM EQ_Extract..BiennialReportSourceData SD WHERE SD.biennial_id = @newid
AND SD.TRANS_MODE = 'I' AND NOT (SD.profit_ctr_epa_id = SD.generator_epa_id AND SD.generator_country = 'US') 

insert @recordsetname (recordsetname) values ('WR WasteCodes Worksheet')

if @debug = 1 print convert(varchar(30), getdate(), 121) +'   '+ 'Ending sp_export_query_to_excel, ' + @template_name + ': ' + @tablename
insert EQ_Extract..BiennialDebugInfo (biennial_id, log_time, log_message) values (@newid, getdate(), 'Ending sp_export_query_to_excel, ' + @template_name + ': ' + @tablename)

if @debug = 1 print convert(varchar(30), getdate(), 121) +'   '+ 'Ending sp_eqip_biennial_output'
insert EQ_Extract..BiennialDebugInfo (biennial_id, log_time, log_message) values (@newid, getdate(), 'Ending sp_eqip_biennial_output')
	
SELECT  * FROM    @recordsetname

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_eqip_biennial_output] TO [EQWEB]

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_eqip_biennial_output] TO [COR_USER]

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_eqip_biennial_output] TO [EQAI]

