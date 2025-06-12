Drop Proc If Exists sp_reports_annual_illinois_nonhaz
go

create procedure sp_reports_annual_illinois_nonhaz
	@start_date datetime,
	@end_date datetime,
	@user_code varchar(20),
	@permission_id int,
	@report_log_id int = null,
	@debug int = 0
as
/* *******************************************************************

sp_reports_annual_illinois_nonhaz '04/01/2011', '04/30/2011', 'JONATHAN', 226, 80729
02/22/2012 SK Corrected the table name for EQ_temp..sp_biennial_report_output_worksheet_GM_IL
				in GM worksheet export to excel section

sp_reports_annual_illinois_nonhaz '01/01/2012', '12/31/2012', 'JONATHAN', 263, 153887, 1
sp_reports_annual_illinois_nonhaz '01/01/2012', '12/31/2012', 'JONATHAN', 263, 153914, 1

sp_reports_annual_illinois_nonhaz '01/01/2023', '12/31/2023', 'JONATHAN', 263

******************************************************************* */
declare @newid int

set nocount on

create table #biennialid (biennial_id int)
--begin tran t1
-- populate the source table
insert #biennialid exec sp_reports_annual_illinois_nonhaz_source null, '26|0', @start_date, @end_date, @user_code

select @newid = biennial_id from #biennialid

-- 323
--exec sp_reports_annual_illinois_nonhaz_source null, '26|0', '01/01/2010', '01/05/2010', 'RICH_G'

-- get the biennial_id that was generated
if @newid is null
	SELECT @newid = MAX(biennial_id) FROM EQ_Extract..ILAnnualNonHazReport

if @debug > 0 SELECT 'NEW ID: ' + cast(@newid as varchar(20))

if @debug > 0 print convert(datetime, convert(varchar(20), @start_date, 101) + ' 00:00:00')
if @debug > 0 print convert(datetime, convert(varchar(20), @end_date, 101) + ' 23:59:59')

declare @from_to_file_date varchar(100) = convert(varchar(4), datepart(yyyy, @start_date)) + '-' + right('00' + convert(varchar(2), datepart(mm, @start_date)),2) + '-' + right('00' + convert(varchar(2), datepart(dd, @start_date)),2) + '-to-' + convert(varchar(4), datepart(yyyy, @end_date)) + '-'+ right('00' + convert(varchar(2), datepart(mm, @end_date)),2) + '-' + right('00' + convert(varchar(2), datepart(dd, @end_date)),2)
declare @tmp_filename varchar(100) = 'IL-Validation.xls',
	@tmp_desc varchar(255) = 'IL Annual NonHaz Validation Export: ' + convert(varchar(10), @start_date, 110) + ' - ' + convert(varchar(12), @end_date, 110)

declare @tmp_debug int
set @tmp_debug = @debug

declare @recordsetname table (
	recordsetnumber	int identity(1,1),
	recordsetname varchar(50)
)


--if OBJECT_ID('eq_temp..sp_reports_biennial_validation') is not null drop table eq_temp..sp_reports_biennial_validation

/*********************************
	FILE OUTPUT: Validation
**********************************/

-- run the validation for this biennial run
-- 2024-01-18 running this does nothing.  The sp_reports_annual_illinois_nonhaz_source call above puts data in a different table
--   than this one reads from. So it finds nothing.  So its commented.
-- exec sp_biennial_validate @newid

-- set nocount off

/*
exec plt_export.dbo.sp_export_to_excel
	@table_name	= 'eq_temp..sp_biennial_validate_TMP',
	@template	= 'sp_biennial_validate_IL.1',
	@filename	= @tmp_filename,
	@added_by	= @user_code,
	@export_desc = @tmp_desc,
	@report_log_id = @report_log_id,
	@debug = @tmp_debug

select * from eq_temp..sp_biennial_validate_TMP where biennial_id = @newid

set nocount on

insert @recordsetname (recordsetname) values ('Validation')

set nocount off
*/


if @debug > 0 print '======================================================='	
--sp_biennial_IL_WR1_comments.1
--sp_biennial_IL_WR2.1
--sp_biennial_IL_WR1.1
--sp_biennial_validate_IL.1
--sp_biennial_IL_WR1_comments.1

declare @tablename varchar(255),
	@template_name varchar(255)

/*********************************
	FILE OUTPUT: Report
**********************************/
exec sp_annual_nonhaz_report_output_extract_IL @newid, 'REPORT'

select 
	@tmp_desc		= 'IL Annual NonHaz Report Export ' 
						+ convert(varchar(10), @start_date, 110) + ' - ' + convert(varchar(12), @end_date, 110),
	@tmp_filename	= 'IL-NonHaz-Report-'
						+ @from_to_file_date + '.xlsx',
	@tablename		= 'eq_temp..sp_annual_nonhaz_report_output_extract_IL',
	@template_name	= 'sp_annual_nonhaz_report_output_extract_IL.report.1'

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

SELECT  * FROM    eq_temp..sp_annual_nonhaz_report_output_extract_IL 

set nocount on


insert @recordsetname (recordsetname) values ('Report-Export')




/*********************************
	FILE OUTPUT: Haulers
**********************************/
exec sp_annual_nonhaz_report_output_extract_IL @newid, 'HAULERS'
set @tmp_desc = 'IL Annual NonHaz Haulers Export ' + convert(varchar(10), @start_date, 110) + ' - ' + convert(varchar(12), @end_date, 110)
set @tmp_filename = 'IL-NonHaz-Haulers.txt'

select 
	@tmp_desc		= 'IL Annual NonHaz Haulers Export ' 
						+ convert(varchar(10), @start_date, 110) + ' - ' + convert(varchar(12), @end_date, 110),
	@tmp_filename	= 'IL-NonHaz-Haulers-' + @from_to_file_date + '.xlsx',
	@tablename		= 'eq_temp..sp_annual_nonhaz_report_output_hauler_IL',
	@template_name	= 'sp_annual_nonhaz_report_output_extract_IL.haulers.1'

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

SELECT  * FROM    eq_temp..sp_annual_nonhaz_report_output_hauler_IL

set nocount on


insert @recordsetname (recordsetname) values ('Haulers-Export')

	
if @debug > 0 print '======================================================='	
	


/*********************************
	FILE OUTPUT: Worksheet Report
**********************************/
exec sp_annual_nonhaz_report_output_extract_worksheet_IL @newid, 'REPORT'
--exec sp_annual_nonhaz_report_output_extract_worksheet_IL 1110, 'OH'

select 
	@tmp_desc = upper('IL') + ' Annual NonHaz Report Worksheet: ' 
		+ convert(varchar(10), @start_date, 110) + ' - ' 
		+ convert(varchar(12), @end_date, 110),
	@tmp_filename = 'IL-Annual-NonHaz-Report-Worksheet ' 
		+ @from_to_file_date + '.xls',
	@template_name = 'sp_annual_nonhaz_report_output_extract_worksheet_IL.report.1',
	@tablename = 'eq_temp..sp_annual_nonhaz_report_output_extract_worksheet_IL'

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


SELECT  * FROM    eq_temp..sp_annual_nonhaz_report_output_extract_worksheet_IL

set nocount on


insert @recordsetname (recordsetname) values ('Report-Worksheet')


/*********************************
	FILE OUTPUT: Worksheet Haulers
**********************************/
exec sp_annual_nonhaz_report_output_extract_worksheet_IL @newid, 'HAULERS'
--exec sp_biennial_report_worksheet_WR 1110, 'OH'

select 
	@tmp_desc = upper('IL') + ' Annual NonHaz Hauler Worksheet: ' 
		+ convert(varchar(10), @start_date, 110) + ' - ' 
		+ convert(varchar(12), @end_date, 110),
	@tmp_filename = upper('IL') + '-Annual-NonHaz-Hauler-Worksheet ' 
		+ @from_to_file_date + '.xls',
	@template_name = 'sp_annual_nonhaz_report_output_extract_worksheet_IL.1',
	@tablename = 'eq_temp..sp_annual_nonhaz_report_output_hauler_worksheet_IL'

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
insert @recordsetname (recordsetname) values ('Hauler-Worksheet')

set nocount off

SELECT  * FROM    eq_temp..sp_annual_nonhaz_report_output_hauler_worksheet_IL

SELECT  * FROM    @recordsetname

GO

GRANT EXECUTE
    ON OBJECT::[dbo].[sp_reports_annual_illinois_nonhaz] TO [EQWEB]

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_reports_annual_illinois_nonhaz] TO [COR_USER]

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_reports_annual_illinois_nonhaz] TO [EQAI]
