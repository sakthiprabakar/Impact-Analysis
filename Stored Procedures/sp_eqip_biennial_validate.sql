Drop proc If Exists sp_eqip_biennial_validate
go

create procedure sp_eqip_biennial_validate
	@copc			varchar(20),
	@start_date		datetime,
	@end_date		datetime,
	@user_code		varchar(20),
	@permission_id	int,
	@report_log_id	int = null,
	@debug			int = 0
as

/* **************************************************************************************
sp_eqip_biennial_validate

	Created to separate the build/validate process into a report site users could run
	as needed without building the whole validation.

History:
	02/08/2012	JPB	Created
	
Example:

	declare @report_log_id int
	exec @report_log_id = sp_sequence_next 'ReportLog.report_log_ID'
	select @report_log_id
	insert ReportLog select 0, 0, 'Customer Extracts', 'Biennial Validation', null, null, null, null, null, 'JONATHAN', GETDATE(), @report_log_id, null, null, null, null, null, null, null

	exec sp_eqip_biennial_validate '2|0', '1/1/2023', '1/31/2023 23:59', 'JONATHAN', 236, 1, 0
	
	
************************************************************************************** */
if @debug > 0 select getdate(), 'Started'

declare @newid int

set nocount on
-- populate the source table
exec sp_biennial_report_source null, @copc, @start_date, @end_date, @user_code

set nocount off

if @debug > 0 select getdate(), 'Finished sp_biennial_report_source'

-- get the biennial_id that was generated
SELECT @newid = MAX(biennial_id) FROM EQ_Extract.dbo.BiennialReportSourceData where convert(varchar(2), company_id) + '|' + convert(varchar(2), profit_ctr_id) = @copc

declare @from_to_file_date varchar(100) = convert(varchar(4), datepart(yyyy, @start_date)) + '-' + right('00' + convert(varchar(2), datepart(mm, @start_date)),2) + '-' + right('00' + convert(varchar(2), datepart(dd, @start_date)),2) + '-to-' + convert(varchar(4), datepart(yyyy, @end_date)) + '-'+ right('00' + convert(varchar(2), datepart(mm, @end_date)),2) + '-' + right('00' + convert(varchar(2), datepart(dd, @end_date)),2)
declare @tmp_filename varchar(100) = 'Biennial-Validation ' + @from_to_file_date + '.xls',
	@tmp_desc varchar(255) = 'Biennial Validation Export: ' + convert(varchar(10), @start_date, 110) + ' - ' + convert(varchar(12), @end_date, 110)

declare @tmp_debug int
set @tmp_debug = @debug


/*********************************
	FILE OUTPUT: Validation
**********************************/

-- run the validation for this biennial run
exec sp_biennial_validate @newid

if @debug > 0 select getdate(), 'Finished sp_biennial_validate'

/*
2023-12-27 - JPB.  Nope, just straight select now

-- Export validation to excel
exec plt_export.dbo.sp_export_to_excel
	@table_name	= 'eq_temp..sp_biennial_validate_TMP',
	@template	= 'sp_biennial_validate.1',
	@filename	= @tmp_filename,
	@added_by	= @user_code,
	@export_desc = @tmp_desc,
	@report_log_id = @report_log_id,
	@debug = @tmp_debug

*/

-- select distinct * from eq_temp..sp_biennial_validate_TMP where biennial_id = @newid

if @debug > 0 select getdate(), 'Finished excel export'


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_eqip_biennial_validate] TO [EQWEB]

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_eqip_biennial_validate] TO [COR_USER]




GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_eqip_biennial_validate] TO [EQAI]

GO

