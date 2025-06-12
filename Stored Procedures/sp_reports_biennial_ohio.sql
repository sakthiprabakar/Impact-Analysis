drop proc if exists sp_reports_biennial_ohio
go

create procedure sp_reports_biennial_ohio
	@start_date datetime,
	@end_date datetime,
	@user_code varchar(20),
	@permission_id int,
	@report_log_id int,
	@debug int = 0
as

/*

SELECT MAX(biennial_id) FROM EQ_Extract.dbo.BiennialReportSourceData
exec sp_biennial_report_output_extract_OH 2836, 'OI', 'T'
exec sp_reports_biennial_ohio '1/1/2023', '1/31/2023 23:59', 'jonathan', 213, 0

*/

set nocount on

declare @newid int

--begin tran t1
-- populate the source table
exec sp_biennial_report_source null, '25|0', @start_date, @end_date, @user_code

-- get the biennial_id that was generated
SELECT @newid = MAX(biennial_id) FROM EQ_Extract.dbo.BiennialReportSourceData

if @debug > 1 print convert(datetime, convert(varchar(20), @start_date, 101) + ' 00:00:00')
if @debug > 1 print convert(datetime, convert(varchar(20), @end_date, 101) + ' 23:59:59')

declare @from_to_file_date varchar(100) = convert(varchar(4), datepart(yyyy, @start_date)) + '-' + right('00' + convert(varchar(2), datepart(mm, @start_date)),2) + '-' + right('00' + convert(varchar(2), datepart(dd, @start_date)),2) + '-to-' + convert(varchar(4), datepart(yyyy, @end_date)) + '-'+ right('00' + convert(varchar(2), datepart(mm, @end_date)),2) + '-' + right('00' + convert(varchar(2), datepart(dd, @end_date)),2)
declare @tmp_filename varchar(100) = 'OH-Biennial-Validation ' + @from_to_file_date + '.xls',
	@tmp_desc varchar(255) = 'OH Biennial Validation Export: ' + convert(varchar(10), @start_date, 110) + ' - ' + convert(varchar(12), @end_date, 110)

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
-- exec sp_biennial_validate @newid

/*
exec plt_export.dbo.sp_export_to_excel
	@table_name	= 'eq_temp..sp_biennial_validate_TMP',
	@template	= 'sp_biennial_validate_OH.1',
	@filename	= @tmp_filename,
	@added_by	= @user_code,
	@export_desc = @tmp_desc,
	@report_log_id = @report_log_id,
	@debug = @tmp_debug
*/





/*********************************
	FILE OUTPUT: GM1
**********************************/
	
exec sp_biennial_report_output_extract_OH @newid, 'Validation,GM1,GM2,GM4,OI,WR1,WR2,PS', 'T'


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_reports_biennial_ohio] TO [EQWEB]

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_reports_biennial_ohio] TO [COR_USER]


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_reports_biennial_ohio] TO [EQAI]

