
create proc sp_target_manifest_extract (
	@start datetime, 
	@stop datetime, -- No need for ' 23:59:59' - it's auto added below.
	@user_code varchar(10)
,	@permission_id	int
,	@report_log_id	int

)
as
/***************************************************************************
sp_target_manifest_extract

Automation of ...

	Target Manifest Export - HowTo:

	1. Update the @start and @stop datetime variables with appropriate values from the request (Evan Logan will provide them)
	2. Update the @current_TableName value with the current date as already formatted.
	3.	Update the @run_* variables:
		1.	First time: set the @run_generation and @run_validation values to 1.  Set @run_export to 0.
		2.	Run the whole script.
		3.	There should be either No validation issues selected out as results OR they should 
			have been acknowledged and accepted by Evan already.  
			If she did not communicate about any validation problems found, 
			copy the results to excel and email them to her for acknowledgement û 
			sheÆll tell you when itÆs ok to re-run this step, or proceed.
	4.	No Problems and/or Proceeding? Good.
	5.	Update the @run_* variables:
		1.	Second time: set the @run_generation and @run_validation values to 0.  Set @run_export to 1.
		2.	Run the whole script.
		3.	The end.  Evan will automatically get emails she needs
	6.	Log the run in "L:\IT Dept\Documentation\Applications\EQ Developed Apps\Extracts\Customer Extracts\steps and Log.xlsx"

Report, ReportParameter setup
SELECT * FROM Report where report_name like '%target%'
SELECT * FROM ReportXReportCriteria where report_id = 205

declare @r int
select @r = max(report_id) + 1 from report

insert Report (report_id, report_category_id, report_status, report_name, report_desc, report_dw, report_rdl_path, report_sp, report_print_orientation, available_EQAI, available_web, available_multicompany, sample_report_image_id, web_results_page, available_eqip)
values (@r, 19, 'A', 'Target Manifest Extract', 'Extracts manifest images for a service date range', null, null, 'sp_target_manifest_extract', null, 'F', 'F', 'F', 0, null, 'T')

insert ReportXReportCriteria
select @r, report_criteria_id, report_criteria_type, report_criteria_required_flag, report_criteria_default, procedure_param_order, display_order
from ReportXReportCriteria where report_id = 205


History:
	7/27/2014 JPB	Created.

Sample:
	sp_target_manifest_extract 
		@start		= '6/29/2014', 
		@stop		= '7/5/2014', -- No need for ' 23:59:59' - it's auto added below.
		@user_code	= 'jonathan'

***************************************************************************/

		
	DECLARE 
		@Current_TableName varchar(20) = '_' + 
			convert(varchar(4), datepart(yyyy, getdate())) + 
			'_' + 
			datename(MONTH, getdate()) + 
			'_' + 
			convert(varchar(2), datepart(D, getdate()))


	declare @debug int = 0, @timer_start datetime = getdate(), @timer_running datetime = getdate()

	if datepart(hh, @stop) = 0 set @stop = @stop + 0.99999

	begin

		-- print 'Generation...'
		
		declare @tsql varchar(max)
		set @tsql = '
		use eq_extract
		
		if object_id(''TargetManifestExport_TmpBuild'') is not null
			DROP TABLE TargetManifestExport_TmpBuild

		CREATE TABLE TargetManifestExport_TmpBuild (
			row_id				int			identity(1,1),
			po_number			varchar(20),
			location_number		varchar(8),
			service_date		datetime,
			manifest			varchar(20),
			vendor_name			varchar(20),
			vendor_number		varchar(20),
			filename			varchar(40),
			doctype				varchar(20),
			metadata_filename	varchar(40),
			eq_purchase_order	varchar(20),
			image_id			int,
			trans_source		char(1),
			receipt_id			int,	-- or workorderdetail.workorder_id
			company_id			int,
			profit_ctr_id		int,
			scan_status			char(1),
			scan_manifest		varchar(20),
			scan_page_number	int,
			date_added			datetime,
			added_by			varchar(20),
			from_date			datetime,
			to_date				datetime,
			billing_status		char(1)
		)

		GRANT ALL ON TargetManifestExport_TmpBuild TO EQAI
		'
		exec (@tsql)
		

		INSERT EQ_Extract..TargetManifestExport_TmpBuild
		-- WO (no EQ disposal) info
		SELECT distinct
		CASE WHEN CHARINDEX('BP', woh.purchase_order) <= 0 THEN 
			CASE WHEN IsNumeric(woh.purchase_order) = 1 THEN
				'BP' + woh.purchase_order 
			ELSE
				woh.purchase_order
			END
		ELSE 
			woh.purchase_order 
		END AS PO_Number
		, isnull(g.site_code, '') AS Location_Number
		, convert(varchar(20), coalesce(wos.date_act_arrive, woh.start_date), 101) as Service_Date
		, wod.manifest AS manifest
		, 'EQ' as Vendor_Name
		, '10183741' AS Vendor_Number
		, 'T' + RIGHT('0000' + isnull(g.site_code, ''), 4) + '_' + right('000000000000' + wod.manifest, 12) as Filename
		, 'HWManifest' as Doctype
		, 'UHWM_010183741_' 
			+ convert(varchar(4), datepart(yyyy, getdate())) 
			+ '-' 
			+ right('00' + convert(varchar(2), datepart(mm, getdate())), 2) 
			+ '-' 
			+ right('00' + convert(varchar(2), datepart(dd, getdate())), 2) 
			+ '_' 
			+ right('00' + convert(varchar(2), datepart(HH, getdate())), 2) 
			+ '-' 
			+ right('00' + convert(varchar(2), datepart(n, getdate())), 2) 
			+ '.xls'
		AS Metadata_Filename
		, woh.purchase_order
		, s.image_id
		, 'W'
		, woh.workorder_id
		, woh.company_id
		, woh.profit_ctr_id
		, s.status
		, s.manifest
		, s.page_number
		, getdate()
		, 'Jonathan'
		, @start
		, @stop
		, b.status_code
		from WorkOrderHeader woh (nolock)
		inner join WorkorderDetail wod (nolock)
			on woh.workorder_id = wod.workorder_id
			and woh.company_id = wod.company_id
			and woh.profit_ctr_id = wod.profit_ctr_id
		inner join generator g (nolock)
			on woh.generator_id = g.generator_id
		LEFT OUTER JOIN billing b (nolock)
			on woh.workorder_id = b.receipt_id
			and wod.resource_type = b.workorder_resource_type
			and wod.sequence_id = b.workorder_sequence_id
			and wod.company_id = b.company_id
			and wod.profit_ctr_id = b.profit_ctr_id
			and b.status_code = 'I'
			and b.trans_source = 'W'
		LEFT OUTER JOIN WorkOrderStop wos (nolock) 
			ON wos.workorder_id = woh.workorder_id
			and wos.company_id = woh.company_id
			and wos.profit_ctr_id = woh.profit_ctr_id
			and wos.stop_sequence_id = 1 /* this will change in the future when there is more than 1 stop per workorder */
		INNER JOIN plt_image..scan s (nolock)
			on woh.workorder_id = s.workorder_id
			and woh.company_id = s.company_id
			and woh.profit_ctr_id = s.profit_ctr_id
			and s.status = 'A'
			AND s.type_id in (1, 4, 28)
	--	LEFT OUTER JOIN TSDF t2  (nolock) 
	--		ON wod.tsdf_code = t2.tsdf_code
		where woh.customer_id = 12113
		and coalesce(wos.date_act_arrive, woh.start_date) between @start AND @stop
		AND wod.resource_type = 'D'
		-- AND NOT (wod.resource_type = 'D' AND isnull(t2.eq_flag, 'F') = 'T')
		AND woh.workorder_status IN ('A','C','D','N','P' /*,'X' */)
		-- AND wod.bill_rate NOT IN (-2)
		AND wod.bill_rate > 0 -- as of 2/29/2012, JPB
		-- AND g.site_code in ('2045','1778','1909','0694','2169')

		UNION

		-- Receipt Info:
		SELECT distinct
		CASE WHEN CHARINDEX('BP', r.purchase_order) <= 0 THEN 
			CASE WHEN IsNumeric(r.purchase_order) = 1 THEN
				'BP' + r.purchase_order 
			ELSE
				r.purchase_order
			END
		ELSE 
			r.purchase_order 
		END AS PO_Number
		, isnull(g.site_code, '') AS Location_Number
		, convert(varchar(20), coalesce(rt1.transporter_sign_date, wos.date_act_arrive, woh.start_date, r.receipt_date), 101) as Service_Date
		, r.manifest AS manifest
		, 'EQ' as Vendor_Name
		, '10183741' AS Vendor_Number
		, 'T' + RIGHT('0000' + isnull(g.site_code, ''), 4) + '_' + right('000000000000' + r.manifest, 12) as Filename
		, 'HWManifest' as Doctype
		, 'UHWM_010183741_' 
			+ convert(varchar(4), datepart(yyyy, getdate())) 
			+ '-' 
			+ right('00' + convert(varchar(2), datepart(mm, getdate())), 2) 
			+ '-' 
			+ right('00' + convert(varchar(2), datepart(dd, getdate())), 2) 
			+ '_' 
			+ right('00' + convert(varchar(2), datepart(HH, getdate())), 2) 
			+ '-' 
			+ right('00' + convert(varchar(2), datepart(n, getdate())), 2) 
			+ '.xls'
		AS Metadata_Filename
		, r.purchase_order
		, s.image_id
		, 'R'
		, r.receipt_id
		, r.company_id
		, r.profit_ctr_id
		, s.status
		, s.manifest
		, s.page_number
		, getdate()
		, 'Jonathan'
		, @start
		, @stop
		, b.status_code
		from Receipt r (nolock)
		inner join receiptprice rp (nolock)
			on r.receipt_id = rp.receipt_id
			and r.line_id = rp.line_id
			and r.company_id = rp.company_id
			and r.profit_ctr_id = rp.profit_ctr_id
			and (rp.print_on_invoice_flag = 'T'
			or rp.total_extended_amt > 0 )
		left outer join ReceiptTransporter rt1 (nolock)
			on r.receipt_id = rt1.receipt_id
			and r.company_id = rt1.company_id
			and r.profit_ctr_id = rt1.profit_ctr_id
			and rt1.transporter_sequence_id = 1
		inner join generator g (nolock)
			on r.generator_id = g.generator_id
		LEFT OUTER JOIN billing b (nolock)
			on r.receipt_id = b.receipt_id
			and r.line_id = b.line_id
			and rp.price_id = b.price_id
			and r.company_id = b.company_id
			and r.profit_ctr_id = b.profit_ctr_id
			and b.status_code = 'I'
			and b.trans_source = 'R'
		LEFT OUTER JOIN billinglinklookup bll (nolock)
			on r.receipt_id = bll.receipt_id
			and r.company_id = bll.company_id
			and r.profit_ctr_id = bll.profit_ctr_id
		left outer JOIN WorkOrderHeader woh (nolock)
			on bll.source_id = woh.workorder_id
			and bll.source_company_id = woh.company_id
			and bll.source_profit_ctr_id = woh.profit_ctr_id		
		LEFT OUTER JOIN WorkOrderStop wos (nolock) 
			ON wos.workorder_id = woh.workorder_id
			and wos.company_id = woh.company_id
			and wos.profit_ctr_id = woh.profit_ctr_id
			and wos.stop_sequence_id = 1 /* this will change in the future when there is more than 1 stop per workorder */
		INNER JOIN plt_image..scan s (nolock)
			on r.receipt_id = s.receipt_id
			and r.company_id = s.company_id
			and r.profit_ctr_id = s.profit_ctr_id
			and s.status = 'A'
			AND s.type_id in (1, 4, 28)
		where r.customer_id = 12113
		and coalesce(rt1.transporter_sign_date, wos.date_act_arrive, woh.start_date, r.receipt_date) between @start AND @stop
		AND r.receipt_status = 'A'
		and r.fingerpr_status = 'A'
		-- AND g.site_code in ('2045','1778','1909','0694','2169')

	if @debug > 0
		select 'Initial Import Finished', DATEDIFF(ms, @timer_running, getdate()) as last, DATEDIFF(ms, @timer_start, getdate()) as running
		set @timer_running = GETDATE()	
		
		-- Target-requested PO Number Reformat
		--  After the BP should be 12 digits, 0-padded from left.

		-- 1. Trim. Some start with spaces
			update EQ_Extract..TargetManifestExport_TmpBuild
				set po_number = ltrim(rtrim(po_number))

		-- 2. Update those that start with BP and are numeric afterward	
			update EQ_Extract..TargetManifestExport_TmpBuild set
				po_number = 'BP' + right('000000000000' + right(po_number, len(po_number)-2), 10)
			where left(po_number,2) = 'BP' and isnumeric(right(po_number, len(po_number)-2)) = 1

		-- 3. If there's no PO, use BP9999999999
			update EQ_Extract..TargetManifestExport_TmpBuild set
				po_number = 'BP9999999999'
			where ISNULL(po_number, '') = ''

	if @debug > 0
		select 'PO Updates Finished', DATEDIFF(ms, @timer_running, getdate()) as last, DATEDIFF(ms, @timer_start, getdate()) as running
		set @timer_running = GETDATE()	

		set @tsql = '
		use eq_extract
		
		if exists (select 1 from sysobjects where name = ''TargetManifestExport_TmpBuild_output'')
			drop table eq_Extract..TargetManifestExport_TmpBuild_output

		SELECT DISTINCT
			e.po_number as [PO Number],
			e.location_number as [Location Number],
			e.service_date as [Service Date],
			e.manifest as [Manifest Number],
			e.vendor_name as [Vendor Name],
			e.vendor_number as [Vendor Number],
			e.filename+''.pdf'' AS Filename,
			e.doctype as ''DocType''
		INTO eq_Extract..TargetManifestExport_TmpBuild_output
		FROM eq_extract..TargetManifestExport_TmpBuild e
		WHERE e.billing_status = ''I''
		'
		exec (@tsql)
		
	if @debug > 0
		select 'Build Target output', DATEDIFF(ms, @timer_running, getdate()) as last, DATEDIFF(ms, @timer_start, getdate()) as running
		set @timer_running = GETDATE()	

		set @tsql = '
		use eq_extract
		if exists (select 1 from sysobjects where name = ''TargetManifestExport' + @Current_TableName + ''') drop table TargetManifestExport' + @Current_TableName
		exec (@tsql)
		
		set @tsql = '
		use eq_extract
		if exists (select 1 from sysobjects where name = ''TargetManifestExport' + @Current_TableName + '_output'') drop table TargetManifestExport' + @Current_TableName+ '_output'
		exec (@tsql)

		set @tsql = '
		use eq_extract
		exec sp_rename TargetManifestExport_TmpBuild, TargetManifestExport' + @Current_TableName + ', ''object''
		'
		select @tsql
		exec (@tsql)

		set @tsql = '
		use eq_extract
		exec sp_rename TargetManifestExport_TmpBuild_output, TargetManifestExport' + @Current_TableName + '_output' + ', ''object''
		'
		exec (@tsql)

	if @debug > 0
		select 'Rename generic tables to date tables', DATEDIFF(ms, @timer_running, getdate()) as last, DATEDIFF(ms, @timer_start, getdate()) as running
		set @timer_running = GETDATE()	

		
	end -- @run_generation Generation section


	begin

		-- print 'Export...'

		-- select distinct filename from eq_extract..TargetManifestExport_2014_May_06 WHERE billing_status = 'I'

		declare 
			@image_export_id int, 
			@filecount int, 
			@imagecount int,
			@nsql nvarchar(1000)
			
		set @nsql = N'select @filecount = count(distinct filename) from eq_extract..TargetManifestExport' + @Current_TableName + ' WHERE billing_status = ''I'' '
		
		exec sp_executesql @nsql, N'@filecount int output', @filecount output

		set @nsql = N'select @imagecount = count(distinct image_id) from eq_extract..TargetManifestExport' + @Current_TableName + ' WHERE billing_status = ''I'' '
		
		exec sp_executesql @nsql, N'@imagecount int output', @imagecount output
			
		-- SQL for ImageExport:
		insert plt_export..EqipImageExportHeader (added_by, date_added, criteria, export_flag, image_count, file_count, report_log_id, export_start_date, export_end_date)
		values (@user_code, getdate(), 'Target Manifest Extract ' + convert(Varchar(10), @start, 120) + ' - ' + convert(varchar(10), @stop, 120), 'N', @imagecount, @filecount, null, null, null)
		select @image_export_id = @@identity

		set @nsql = 'insert plt_export..EqipImageExportDetail select ' + convert(varchar(20), @image_export_id) + ', image_id, filename, scan_page_number as page_number from eq_extract..TargetManifestExport' + @Current_TableName + ' WHERE billing_status = ''I'' '

		exec sp_executesql @nsql

	if @debug > 0
		select 'EQIPImageExportHeader output', DATEDIFF(ms, @timer_running, getdate()) as last, DATEDIFF(ms, @timer_start, getdate()) as running
		set @timer_running = GETDATE()	
		
		declare 
			  @report_id int
			--, @report_log_id int
			, @criteria_id int

		select top 1 @report_id = report_id from Report where report_name = 'ImageExportConsole.exe' and report_status = 'A'
		select top 1 @criteria_id = report_criteria_id FROM ReportXReportCriteria where report_id = @report_id

		-- EXEC @report_log_id = sp_sequence_next 'ReportLog.report_log_ID', 1

		exec sp_ReportLog_add @report_log_id, @report_id, @user_code
		exec sp_ReportLogParameter_add @report_log_id, @criteria_id, @image_export_id


	if @debug > 0
		select 'ReportLog output', DATEDIFF(ms, @timer_running, getdate()) as last, DATEDIFF(ms, @timer_start, getdate()) as running
		set @timer_running = GETDATE()	

		-- Want to do this, but it's not set up for prod yet.  Did it by hand below
		-- plt_export..sp_help sp_export_to_excel
		DECLARE @export_id int
			, @source varchar(100) = 'eq_Extract..TargetManifestExport' + @Current_TableName + '_output'
			, @name varchar(100) = 'Target Manifest Run (' + convert(varchar(12), @start, 101) + ' - ' + convert(varchar(12), @stop, 101) + ')'
			
		EXEC @export_id = plt_export..sp_export_to_excel @source, 'target manifest export', null, 'JONATHAN', @name, @report_log_id, @debug
		
	if @debug > 0
		select 'Excel Export output', DATEDIFF(ms, @timer_running, getdate()) as last, DATEDIFF(ms, @timer_start, getdate()) as running
		set @timer_running = GETDATE()	

		begin
			declare @message_id int
				, @subject varchar(100)
				, @textMessage varchar(500)
				, @htmlMessage varchar(500)
				, @user_email varchar(100)
				, @user_name varchar(100)
				
			select @user_email = email, @user_name = USER_NAME from users where user_code = @user_code
			select @subject = '"' + @name + '" Now available on EQIP'
			select @textMessage = 'The spreadsheet to accompany a Target manifest export run (' + convert(varchar(12), @start, 101) + ' - ' + convert(varchar(12), @stop, 101) + ') is now available to download on EQIP.'
			select @htmlMessage = @textMessage			
			
			EXEC @message_id = sp_message_insert @subject, @textMessage, @htmlMessage, 'EQIP', 'EQIP Equipment Sign-Out', NULL, NULL

			EXEC sp_messageAddress_insert @message_id, 'TO', @user_email, @user_name, 'EQ', NULL, NULL, NULL

			EXEC sp_messageAddress_insert @message_id, 'FROM', 'itadmin@eqonline.com', 'IT Admin', 'EQ', NULL, NULL, NULL

	if @debug > 0
		select 'Email notification sent', DATEDIFF(ms, @timer_running, getdate()) as last, DATEDIFF(ms, @timer_start, getdate()) as running
		set @timer_running = GETDATE()	

			
		end

	end -- @run_export Export section


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_target_manifest_extract] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_target_manifest_extract] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_target_manifest_extract] TO [EQAI]
    AS [dbo];

