
drop proc if exists sp_reports_biennial_illinois
go

create procedure sp_reports_biennial_illinois
	@start_date datetime,
	@end_date datetime,
	@user_code varchar(20),
	@permission_id int,
	@report_log_id int = 0,
	@debug int = 0
as
/* *******************************************************************

sp_reports_biennial_illinois '01/01/2015', '12/31/2015', 'JONATHAN', 226, 367530
02/22/2012 SK Corrected the table name for EQ_temp..sp_biennial_report_output_worksheet_GM_IL
				in GM worksheet export to excel section

sp_reports_biennial_illinois '01/01/2023', '12/31/2023', 'JONATHAN', 226

******************************************************************* */
set nocount on

declare @newid int

--begin tran t1
-- populate the source table
exec sp_biennial_report_source null, '26|0', @start_date, @end_date, @user_code

-- 323
--exec sp_biennial_report_source null, '26|0', '01/01/2010', '01/05/2010', 'RICH_G'

-- get the biennial_id that was generated
SELECT @newid = MAX(biennial_id) FROM EQ_Extract.dbo.BiennialReportSourceData

if @debug > 0 SELECT 'NEW ID: ' + cast(@newid as varchar(20))

if @debug > 0 print convert(datetime, convert(varchar(20), @start_date, 101) + ' 00:00:00')
if @debug > 0 print convert(datetime, convert(varchar(20), @end_date, 101) + ' 23:59:59')

declare @from_to_file_date varchar(100) = convert(varchar(4), datepart(yyyy, @start_date)) + '-' + right('00' + convert(varchar(2), datepart(mm, @start_date)),2) + '-' + right('00' + convert(varchar(2), datepart(dd, @start_date)),2) + '-to-' + convert(varchar(4), datepart(yyyy, @end_date)) + '-'+ right('00' + convert(varchar(2), datepart(mm, @end_date)),2) + '-' + right('00' + convert(varchar(2), datepart(dd, @end_date)),2)
declare @tmp_filename varchar(100) = 'IL-Validation.csv',
	@tmp_desc varchar(255) = 'IL Biennial Validation Export: ' + convert(varchar(10), @start_date, 110) + ' - ' + convert(varchar(12), @end_date, 110)

declare @tmp_debug int, @query varchar(max)
set @tmp_debug = @debug

declare @recordsetname table (
	recordsetnumber	int identity(1,1),
	recordsetname varchar(50)
)

	delete from EQ_Extract..BiennialReportWork_IL_GM1 where biennial_id <> @newid
	delete from EQ_Extract..BiennialReportWork_IL_GM2 where biennial_id <> @newid
	delete from EQ_Extract..BiennialReportWork_IL_WR1 where biennial_id <> @newid
	delete from EQ_Extract..BiennialReportWork_IL_WR2 where biennial_id <> @newid

	-- populate work table data for this run
	exec sp_biennial_report_output_IL_GM @newid
	exec sp_biennial_report_output_IL_WR @newid


--if OBJECT_ID('eq_temp..sp_reports_biennial_validation') is not null drop table eq_temp..sp_reports_biennial_validation

/*********************************
	FILE OUTPUT: Validation
**********************************/

-- run the validation for this biennial run
exec sp_biennial_validate @newid

/*
exec plt_export.dbo.sp_export_to_excel
	@table_name	= 'eq_temp..sp_biennial_validate_TMP',
	@template	= 'sp_biennial_validate_IL.1',
	@filename	= @tmp_filename,
	@added_by	= @user_code,
	@export_desc = @tmp_desc,
	@report_log_id = @report_log_id,
	@debug = @tmp_debug
*/
set nocount off

select * from eq_temp..sp_biennial_validate_TMP WHERE  biennial_id = @newid

set nocount on

insert @recordsetname (recordsetname) values ('Validation')

if @debug > 0 print '======================================================='	
--sp_biennial_IL_WR1_comments.1
--sp_biennial_IL_WR2.1
--sp_biennial_IL_WR1.1
--sp_biennial_validate_IL.1
--sp_biennial_IL_WR1_comments.1


/*********************************
	FILE OUTPUT: GM1
**********************************/
-- exec sp_biennial_report_output_extract_IL @newid, 'GM1', 'T'
set @tmp_desc = 'IL Biennial GM1 Export ' + convert(varchar(10), @start_date, 110) + ' - ' + convert(varchar(12), @end_date, 110)
set @tmp_filename = 'IL-GM1.txt'
set @query = 'SELECT DISTINCT convert(varchar(290), EQ_Extract.dbo.fn_space_delimit(''12'', HANDLER_ID) +  EQ_Extract.dbo.fn_space_delimit(''5R'', HZ_PG) +  /* EQ_Extract.dbo.fn_space_delimit(''1'', HZ_PG) +  */ SPACE(3) + /* Filler1 */ EQ_Extract.dbo.fn_space_delimit(''10'', EQ_STATE_ID) +  EQ_Extract.dbo.fn_space_delimit(''4'', eq_extract.dbo.fn_get_IL_biennial_GM_waste_code (hz_pg_tmp, biennial_id, 1)) + EQ_Extract.dbo.fn_space_delimit(''4'', eq_extract.dbo.fn_get_IL_biennial_GM_waste_code (hz_pg_tmp, biennial_id, 2)) + EQ_Extract.dbo.fn_space_delimit(''4'', eq_extract.dbo.fn_get_IL_biennial_GM_waste_code (hz_pg_tmp, biennial_id, 3)) + EQ_Extract.dbo.fn_space_delimit(''4'', eq_extract.dbo.fn_get_IL_biennial_GM_waste_code (hz_pg_tmp, biennial_id, 4)) + EQ_Extract.dbo.fn_space_delimit(''4'', eq_extract.dbo.fn_get_IL_biennial_GM_waste_code (hz_pg_tmp, biennial_id, 5)) + EQ_Extract.dbo.fn_space_delimit(''3'', SOURCE_CODE) +  EQ_Extract.dbo.fn_space_delimit(''4'', ORIGIN_MANAGEMENT_METHOD) +  EQ_Extract.dbo.fn_space_delimit(''4'', FORM_CODE) +  EQ_Extract.dbo.fn_space_delimit(''1'', WASTE_MINIMIZATION_CODE) +  EQ_Extract.dbo.fn_space_delimit(''1'', UNIT_OF_MEASURE) +  REPLACE(EQ_Extract.dbo.fn_space_delimit(''4'', WST_DENSITY), '' '', ''0'') +  REPLACE(EQ_Extract.dbo.fn_space_delimit(''10R'', IO_TDR_QTY), '' '', ''0'') +  EQ_Extract.dbo.fn_space_delimit(''1'', ON_SITE_MANAGEMENT) +  SPACE(4) + /* ON_SITE_MANAGEMENT_METHOD_SITE_1 */ SPACE(10) + /* QTY_MANAGED_ON_SITE_1 */ SPACE(4) + /* ON_SITE_MANAGEMENT_METHOD_SITE_2 */ SPACE(10) + /* QTY_MANAGED_ON_SITE_2 */ EQ_Extract.dbo.fn_space_delimit(''1'', OFF_SITE_SHIPMENT) +  EQ_Extract.dbo.fn_space_delimit(''12'', SITE_1_US_EPAID_NUMBER) +  EQ_Extract.dbo.fn_space_delimit(''4'', SITE_1_MANAGEMENT_METHOD) +  REPLACE(EQ_Extract.dbo.fn_space_delimit(''10R'', SITE_1_TOTAL_QUANTITY_SHIPPED), '' '', ''0'') +  SPACE(12) + /* SITE_2_US_EPAID_NUMBER */ SPACE(4) + /* SITE_2_MANAGEMENT_METHOD */ SPACE(10) + /* SITE_2_TOTAL_QUANTITY_SHIPPED */ SPACE(12) + /* SITE_3_US_EPAID_NUMBER */ SPACE(4) + /* SITE_3_MANAGEMENT_METHOD */ SPACE(10) + /* SITE_3_TOTAL_QUANTITY_SHIPPED */ SPACE(12) + /* SITE_4_US_EPAID_NUMBER */ SPACE(4) + /* SITE_4_MANAGEMENT_METHOD */ SPACE(10) + /* SITE_4_TOTAL_QUANTITY_SHIPPED */ SPACE(12) +  /* SITE_5_US_EPAID_NUMBER */ SPACE(4) + /* SITE_5_MANAGEMENT_METHOD */ SPACE(10) + /* SITE_5_TOTAL_QUANTITY_SHIPPED */ ''N'' + /* COMMENTS_INDICATOR */ SPACE(1) + /* FILLER2 */ EQ_Extract.dbo.fn_space_delimit(''50'', DESCRIPTION)) as [Report] FROM EQ_Extract..BiennialReportWork_IL_GM1 where biennial_id =' + convert(varchar(20), @newid)
	
/*

exec plt_export.dbo.sp_export_query_to_text  
	@table_name	= @query,
	@template	= 'sp_biennial_IL_WR1.1',
	@filename	= @tmp_filename,
	@header_lines_to_remove = 2,
	@added_by	= @user_code,
	@export_desc = @tmp_desc,
	@report_log_id = @report_log_id,
	@debug = @tmp_debug
*/

set nocount off

SELECT DISTINCT 
	convert(varchar(290), EQ_Extract.dbo.fn_space_delimit('12', HANDLER_ID) 
	+  EQ_Extract.dbo.fn_space_delimit('5R', HZ_PG) 
	+  /* EQ_Extract.dbo.fn_space_delimit('1', HZ_PG) +  */ SPACE(3) + /* Filler1 */ EQ_Extract.dbo.fn_space_delimit('10', EQ_STATE_ID) 
	+  EQ_Extract.dbo.fn_space_delimit('4', eq_extract.dbo.fn_get_IL_biennial_GM_waste_code (hz_pg_tmp, biennial_id, 1)) 
	+ EQ_Extract.dbo.fn_space_delimit('4', eq_extract.dbo.fn_get_IL_biennial_GM_waste_code (hz_pg_tmp, biennial_id, 2)) 
	+ EQ_Extract.dbo.fn_space_delimit('4', eq_extract.dbo.fn_get_IL_biennial_GM_waste_code (hz_pg_tmp, biennial_id, 3)) 
	+ EQ_Extract.dbo.fn_space_delimit('4', eq_extract.dbo.fn_get_IL_biennial_GM_waste_code (hz_pg_tmp, biennial_id, 4)) 
	+ EQ_Extract.dbo.fn_space_delimit('4', eq_extract.dbo.fn_get_IL_biennial_GM_waste_code (hz_pg_tmp, biennial_id, 5)) 
	+ EQ_Extract.dbo.fn_space_delimit('3', SOURCE_CODE) 
	+  EQ_Extract.dbo.fn_space_delimit('4', ORIGIN_MANAGEMENT_METHOD) 
	+  EQ_Extract.dbo.fn_space_delimit('4', FORM_CODE) 
	+  EQ_Extract.dbo.fn_space_delimit('1', WASTE_MINIMIZATION_CODE) 
	+  EQ_Extract.dbo.fn_space_delimit('1', UNIT_OF_MEASURE) 
	+  REPLACE(EQ_Extract.dbo.fn_space_delimit('4', WST_DENSITY), ' ', '0') 
	+  REPLACE(EQ_Extract.dbo.fn_space_delimit('10R', IO_TDR_QTY), ' ', '0') 
	+  EQ_Extract.dbo.fn_space_delimit('1', ON_SITE_MANAGEMENT) 
	+  SPACE(4) 
	+ /* ON_SITE_MANAGEMENT_METHOD_SITE_1 */ SPACE(10) 
	+ /* QTY_MANAGED_ON_SITE_1 */ SPACE(4) 
	+ /* ON_SITE_MANAGEMENT_METHOD_SITE_2 */ SPACE(10) 
	+ /* QTY_MANAGED_ON_SITE_2 */ EQ_Extract.dbo.fn_space_delimit('1', OFF_SITE_SHIPMENT) 
	+  EQ_Extract.dbo.fn_space_delimit('12', SITE_1_US_EPAID_NUMBER) 
	+  EQ_Extract.dbo.fn_space_delimit('4', SITE_1_MANAGEMENT_METHOD) 
	+  REPLACE(EQ_Extract.dbo.fn_space_delimit('10R', SITE_1_TOTAL_QUANTITY_SHIPPED), ' ', '0') 
	+  SPACE(12) 
	+ /* SITE_2_US_EPAID_NUMBER */ SPACE(4) 
	+ /* SITE_2_MANAGEMENT_METHOD */ SPACE(10) 
	+ /* SITE_2_TOTAL_QUANTITY_SHIPPED */ SPACE(12) 
	+ /* SITE_3_US_EPAID_NUMBER */ SPACE(4) 
	+ /* SITE_3_MANAGEMENT_METHOD */ SPACE(10) 
	+ /* SITE_3_TOTAL_QUANTITY_SHIPPED */ SPACE(12) 
	+ /* SITE_4_US_EPAID_NUMBER */ SPACE(4) 
	+ /* SITE_4_MANAGEMENT_METHOD */ SPACE(10) 
	+ /* SITE_4_TOTAL_QUANTITY_SHIPPED */ SPACE(12) 
	+  /* SITE_5_US_EPAID_NUMBER */ SPACE(4) 
	+ /* SITE_5_MANAGEMENT_METHOD */ SPACE(10) 
	+ /* SITE_5_TOTAL_QUANTITY_SHIPPED */ 'N' 
	+ /* COMMENTS_INDICATOR */ SPACE(1) 
	+ /* FILLER2 */ EQ_Extract.dbo.fn_space_delimit('50', DESCRIPTION)) as [Report] 
	FROM EQ_Extract..BiennialReportWork_IL_GM1 where biennial_id = @newid

set nocount on

insert @recordsetname (recordsetname) values (@tmp_filename)


/*********************************
	FILE OUTPUT: WR1
**********************************/
exec sp_biennial_report_output_extract_IL @newid, 'WR1', 'T'
set @tmp_desc = 'IL Biennial WR1 Export ' + convert(varchar(10), @start_date, 110) + ' - ' + convert(varchar(12), @end_date, 110)
set @tmp_filename = 'IL-WR1.txt'

/*

exec plt_export.dbo.sp_export_to_text  
	@table_name	= 'eq_temp..sp_biennial_report_output_extract_IL_WR1',
	@template	= 'sp_biennial_IL_WR1.1',
	@filename	= @tmp_filename,
	@header_lines_to_remove = 2,
	@added_by	= @user_code,
	@export_desc = @tmp_desc,
	@report_log_id = @report_log_id,
	@debug = @tmp_debug
*/

set nocount off

SELECT  * FROM    eq_temp..sp_biennial_report_output_extract_IL_WR1

set nocount on

insert @recordsetname (recordsetname) values (@tmp_filename)

if @debug > 0 print '======================================================='	
	
/* there was no WR2 for Illinois 	
----/*********************************
----	FILE OUTPUT: WR2
----**********************************/
----exec sp_biennial_report_output_extract_IL @newid, 'WR2', 'T'
----set @tmp_desc = 'IL Biennial WR2 Export: ' + convert(varchar(10), @start_date, 110) + ' - ' + convert(varchar(12), @end_date, 110)
----set @tmp_filename = 'IL-Biennial-WR2 ' + @from_to_file_date + '.txt'

----exec plt_export.dbo.sp_export_to_text  
----	@table_name	= 'eq_temp..sp_biennial_report_output_extract_IL_WR2',
----	@template	= 'sp_biennial_IL_WR2.1',
----	@filename	= @tmp_filename,
----	@header_lines_to_remove = 2,
----	@added_by	= @user_code,
----	@export_desc = @tmp_desc,
----	@report_log_id = @report_log_id
*/

/*********************************
	FILE OUTPUT: COMMENTS
**********************************/
exec sp_biennial_report_output_extract_IL @newid, 'C', 'T'
set @tmp_desc = 'IL Biennial Comments Export: ' + convert(varchar(10), @start_date, 110) + ' - ' + convert(varchar(12), @end_date, 110)
--set @tmp_filename = 'IL-Biennial-WR1-Comment-' + @from_to_file_date + '.csv'
set @tmp_filename = 'IL-WR1-Comment.csv'

/*

exec plt_export.dbo.sp_export_to_excel
	@table_name	= 'eq_temp..sp_biennial_IL_WR1_comments',
	@template	= 'sp_biennial_IL_WR1_comments.1',
	@filename	= @tmp_filename,
	@added_by	= @user_code,
	@export_desc = @tmp_desc,
	@report_log_id = @report_log_id,
	@debug = @tmp_debug

*/

set nocount off

SELECT  * FROM    eq_temp..sp_biennial_IL_WR1_comments

set nocount on

insert @recordsetname (recordsetname) values (@tmp_filename)


if @debug > 0 print '======================================================='	

-- SELECT * FROM PLT_Export..Export

	
/*********************************
	FILE OUTPUT: WASTE RECEIVED (BY GENERATOR)
**********************************/
exec sp_bienneial_rpt_haz_waste_receive @newid, 'volume'
set @tmp_desc = 'IL Biennial Waste by Generator Worksheet: ' + convert(varchar(10), @start_date, 110) + ' - ' + convert(varchar(12), @end_date, 110)
--SET @tmp_desc = 'IL Biennial Waste by Generator Export'
set @tmp_filename = 'IL-Received-By-Generator.csv'

/*

exec plt_export.dbo.sp_export_to_excel
	@table_name	= 'eq_temp..sp_biennial_IL_WR_by_generator',
	@template	= 'sp_biennial_IL_WR_by_generator.2',
	@filename	= @tmp_filename,
	@added_by	= @user_code,
	@export_desc = @tmp_desc,
	@report_log_id = @report_log_id,
	@debug = @tmp_debug

*/

set nocount off

select * from eq_temp..sp_biennial_IL_WR_by_generator

set nocount on

insert @recordsetname (recordsetname) values (@tmp_filename)


if @debug > 0 print '======================================================='	
	
/*********************************
	FILE OUTPUT: WASTE RECEIVED WASTE CODE LOOKUP (BY GENERATOR)
**********************************/	
exec sp_bienneial_rpt_haz_waste_receive @newid, 'waste_code'
set @tmp_desc = 'IL Biennial Waste by Generator Waste Code Worksheet: ' + convert(varchar(10), @start_date, 110) + ' - ' + convert(varchar(12), @end_date, 110)
set @tmp_filename = 'IL-Received-By-Generator-Waste-Code-Lookup.csv'

/*

exec plt_export.dbo.sp_export_to_excel  
	@table_name	= 'eq_temp..sp_biennial_IL_WR_by_generator_waste_codes',
	@template	= 'sp_biennial_IL_WR_by_generator_waste_codes.1', /* same file, different sheet */
	@filename	= @tmp_filename,
	@added_by	= @user_code,
	@export_desc = @tmp_desc,
	@report_log_id = @report_log_id,
	@debug = @tmp_debug

*/

set nocount off

select * from eq_temp..sp_biennial_IL_WR_by_generator_waste_codes

set nocount on

insert @recordsetname (recordsetname) values (@tmp_filename)

if @debug > 0 print '======================================================='

DECLARE @template_name varchar(100),
	@tablename varchar(100)


/*********************************
	FILE OUTPUT: Worksheet GM
**********************************/
exec sp_biennial_report_worksheet_GM_IL @newid, 'IL'
--exec sp_biennial_report_worksheet_GM 1110, 'OH'

select 
	@tmp_desc = upper('IL') + ' Biennial GM Worksheet: ' 
		+ convert(varchar(10), @start_date, 110) + ' - ' 
		+ convert(varchar(12), @end_date, 110),
	--@tmp_filename = upper('IL') + '-Biennial-GM-Worksheet ' 
	--	+ @from_to_file_date + '.csv',
	@tmp_filename = upper('IL') + '-Biennial-GM-Worksheet.csv',
	@template_name = 'sp_biennial_report_worksheet_GM_IL.1',
	@tablename = 'eq_temp..sp_biennial_report_output_worksheet_GM_IL'

/*

exec plt_export.dbo.sp_export_to_excel
	@table_name	= @tablename,
	@template	= @template_name,
	@filename	= @tmp_filename,
	@added_by	= @user_code,
	@export_desc = @tmp_desc,
	@report_log_id = @report_log_id,
	@debug = @tmp_debug

*/

set nocount off

select * from eq_temp..sp_biennial_report_output_worksheet_GM_IL

set nocount on

insert @recordsetname (recordsetname) values (@tmp_filename)


/*********************************
	FILE OUTPUT: Worksheet GM Wastecodes
**********************************
exec sp_biennial_report_worksheet_GM_wastecodes @newid, 'IL'
--exec sp_biennial_report_worksheet_GM_wastecodes 1110, 'OH'

select 
	@tmp_desc = upper('IL') + ' Biennial GM Waste Codes Worksheet: ' 
		+ convert(varchar(10), @start_date, 110) + ' - ' 
		+ convert(varchar(12), @end_date, 110),
	@tmp_filename = upper('IL') + '-Biennial-GM-Wastecodes-Worksheet ' 
		+ @from_to_file_date + '.csv',
	@template_name = 'sp_biennial_report_worksheet_GM_wastecodes.1',
	@tablename = 'eq_temp..sp_biennial_report_worksheet_GM_wastecodes'

exec plt_export.dbo.sp_export_to_excel
	@table_name	= @tablename,
	@template	= @template_name,
	@filename	= @tmp_filename,
	@added_by	= @user_code,
	@export_desc = @tmp_desc,
	@report_log_id = @report_log_id,
	@debug = @tmp_debug
*/

/*********************************
	FILE OUTPUT: Worksheet WR
**********************************/
exec sp_biennial_report_worksheet_WR_IL @newid, 'IL'
--exec sp_biennial_report_worksheet_WR 1110, 'OH'

select 
	@tmp_desc = upper('IL') + ' Biennial WR Worksheet: ' 
		+ convert(varchar(10), @start_date, 110) + ' - ' 
		+ convert(varchar(12), @end_date, 110),
	--@tmp_filename = upper('IL') + '-Biennial-WR-Worksheet ' 
	--	+ @from_to_file_date + '.csv',
	@tmp_filename = upper('IL') + '-Biennial-WR-Worksheet.csv',
	@template_name = 'sp_biennial_report_worksheet_WR_IL.1',
	@tablename = 'eq_temp..sp_biennial_report_output_worksheet_WR_IL'

/*

exec plt_export.dbo.sp_export_to_excel
	@table_name	= @tablename,
	@template	= @template_name,
	@filename	= @tmp_filename,
	@added_by	= @user_code,
	@export_desc = @tmp_desc,
	@report_log_id = @report_log_id,
	@debug = @tmp_debug

*/

set nocount off

select * from eq_temp..sp_biennial_report_output_worksheet_WR_IL

set nocount on

insert @recordsetname (recordsetname) values (@tmp_filename)

/*********************************
	FILE OUTPUT: Worksheet WR Wastecodes
**********************************
exec sp_biennial_report_worksheet_WR_wastecodes @newid, 'IL'
--exec sp_biennial_report_worksheet_WR_wastecodes 1110, 'OH'

select 
	@tmp_desc = upper('IL') + ' Biennial WR Waste Codes Worksheet: ' 
		+ convert(varchar(10), @start_date, 110) + ' - ' 
		+ convert(varchar(12), @end_date, 110),
	@tmp_filename = upper('IL') + '-Biennial-WR-Wastecodes-Worksheet ' 
		+ @from_to_file_date + '.csv',
	@template_name = 'sp_biennial_report_worksheet_WR_wastecodes.1',
	@tablename = 'eq_temp..sp_biennial_report_worksheet_WR_wastecodes'
	
exec plt_export.dbo.sp_export_to_excel
	@table_name	= @tablename,
	@template	= @template_name,
	@filename	= @tmp_filename,
	@added_by	= @user_code,
	@export_desc = @tmp_desc,
	@report_log_id = @report_log_id,
	@debug = @tmp_debug
	
*/ 

set nocount off

SELECT  * FROM    @recordsetname

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_reports_biennial_illinois] TO [EQWEB]

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_reports_biennial_illinois] TO [COR_USER]


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_reports_biennial_illinois] TO [EQAI]

