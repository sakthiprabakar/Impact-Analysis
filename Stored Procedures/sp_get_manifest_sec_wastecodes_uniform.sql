
CREATE PROCEDURE sp_get_manifest_sec_wastecodes_uniform (
	@ra_source		varchar(15),
	@ra_list		varchar(2000),
	@profit_center	int,
	@company_id		int,
	@generator_id	int = NULL,
	@tsdf_code	varchar(15) = NULL,
	@rejection_manifest_flag char(1) )
AS
/***************************************************************************************
Returns manifest information for the manifest window
Requires: none
Loads on PLT_XX_AI
PB Object(s):	d_manifest_source_sec_waste_code

06/26/2006 rg	created
01/19/2009 rb	Modified workorder retrieval to exclude state waste codes that are not
				the generator state nor the TSDF state.
02/11/2009 rb	Modified Profile and TSDFApproval retrievals to do the same as 1/19/2009 workorder change.
04/10/2009 rb	Changed source_id argument to source_list argument to increase WORKORDER performance.
				Removed @manifest varchar(15), @source_line, @manifest_page_num int,
				@manifest_line char(2) arguments
04/15/2009 rb	Inbound receipt was not pulling in secondary wastecodes, was coded to pull in outbound
04/28/2009 KAM  remove the selection of 'None' from printing on the manifest and labels
04/30/2009 KAM  returned all of the waste codes not just the ones that are not the primary
08/12/2009 RWB  Exclude void WorkOrderDetail records with bill_rate = -2
09/18/2009 JDB	Added optional parameter for @generator_id, so that users printing manifests from the
				profile can choose a generator if the profile generator is VARIOUS.  This SP will now
				get the correct waste codes (based on generator state) for this case.
10/16/2009 KAM  Update the temp table manifest field to be the length of 40
10/25/2009 JDB	Fixed join between WorkorderHeader and WorkorderDetail when source is WORKORDER
				It was not joining on company and profit center.
03/18/2011 RWB	Replace workorder section to reference WorkOrderWasteCode instead of Profile/TSDF waste code tables		
08/09/2013 AM	Moved from Plt_xx_ai to Plt_ai
08/13/2013 RWB	Use new function f_tbl_manifest_waste_codes to get the top 6 for Profiles and TSDFApprovals.
				Add optional @tsdf_code parameter to support changing TSDF on the Manifest Builder screen.
				Existing temp table already defined wastecode as varchar(10)...will now place display_name in there
09/27/2013 RWB	For Workorders, "resource_type='D'" was not in the where clause so it was poosible to print duplicate waste
		codes if a non-disposal WorkOrderDetail record existed with the same sequence_id as a disposal record
07/24/2018 MPM	GEM 51165 - Added @rejection_manifest_flag input parameter and associated logic.

sp_get_manifest_sec_wastecodes_uniform 'TSDFAPPR', '628,12,14','',0,''
sp_get_manifest_sec_wastecodes_uniform 'PROFILE', 333333, 0, 21
sp_get_manifest_sec_wastecodes_uniform 'PROFILE', 333333, 0, 21, 0
sp_get_manifest_sec_wastecodes_uniform 'PROFILE', 333333, 0, 21, 79611
sp_get_manifest_sec_wastecodes_uniform 'PROFILE', 374557, 0, 14, 96167
sp_get_manifest_sec_wastecodes_uniform 'WORKORDER','1894900',6,14
sp_get_manifest_sec_wastecodes_uniform 'IRECEIPT','2005446',0,21, 1, NULL, 'T'

****************************************************************************************/

SET NOCOUNT ON

DECLARE  @more_rows int,
         @list_id int,
         @start int,
         @end int,
         @lnth int,
         @arg_generator_id int,
         @arg_tsdf_code varchar(15),
         @source_id int,
         @approval_code varchar(40),
         @line_id int,
         @source_type varchar(20),
         @manifest_page_num int,
		@default_line int,
		@line_char varchar(2)

CREATE TABLE #source_list (
	source_id int null,
	default_page int null,
	default_line char(2) null	)

CREATE TABLE #manifest ( source_id int null,
	source_line int null,
	source_code varchar(40) null, -- DO NOT CHANGE THIS TO 15, IT NEEDS TO BE 40
	profit_center int null,
	manifest varchar(40) null,
	manifest_line char null,
	wastecode varchar(10) null,
	sequence_id int null )
		
-- decode the source list for retrieval
-- load the source list table
IF LEN(@ra_list) > 0
BEGIN
	SELECT	@more_rows = 1,
		@start = 1
	WHILE @more_rows = 1
	BEGIN
		set @default_line = isnull(@default_line,0) + 1
		if @default_line > 4
			set @line_char = CHAR (64 + ((16 - @default_line) % 10))
		else
			set @line_char = CHAR (64 + @default_line)

		if @line_char = 'A'
			set @manifest_page_num = ISNULL(@manifest_page_num,0) + 1

		SELECT @end = CHARINDEX(',',@ra_list,@start)
		IF @end > 0 
		BEGIN
			SELECT @lnth = @end - @start
		  	SELECT @list_id = CONVERT(int,SUBSTRING(@ra_list,@start,@lnth))
			SELECT @start = @end + 1
			INSERT INTO #source_list VALUES (@list_id, @manifest_page_num, CONVERT(varchar(2),@default_line))
		END
		ELSE 
		BEGIN
			SELECT @lnth = LEN(@ra_list)
			SELECT @list_id = CONVERT(int,SUBSTRING(@ra_list,@start,@lnth))
			SELECT @more_rows = 0
			INSERT INTO #source_list VALUES (@list_id, @manifest_page_num, CONVERT(varchar(2),@default_line))
		END
	END
END

-- determine the source each source has its own query

/*** rb 08/21/2013 Now that a table-valued function returns waste codes, we need to use cursors. Process all 3 receipt cases with one cursor
-- Outbound Receipts
if @ra_source = 'ORECEIPT'
begin
	insert #manifest
	SELECT Receipt.receipt_id AS source_id,
		Receipt.line_id AS source_line,
		CONVERT(varchar(40), '') AS source_code,
		Receipt.profit_ctr_id,
		Receipt.manifest, 
		Receipt.manifest_line_id AS manifest_line,   
		WasteCode.display_name,
		ReceiptWasteCode.sequence_id  
	FROM Receipt, ReceiptWasteCode, WasteCode
	WHERE Receipt.receipt_id = ReceiptWasteCode.receipt_id
		AND Receipt.line_ID = ReceiptWasteCode.line_ID
		AND Receipt.profit_ctr_ID = ReceiptWasteCode.profit_ctr_ID
		AND Receipt.trans_mode = 'O'  
		AND Receipt.trans_type = 'D'  
		AND Receipt.manifest_flag IN ('M','C')
		AND Receipt.receipt_status IN ('N','L','U','A')  
		AND Receipt.receipt_id IN ( SELECT source_id FROM #source_list )
		AND Receipt.company_id = @company_id
		AND Receipt.profit_ctr_ID = @profit_center	
		AND ReceiptWasteCode.waste_code <> 'NONE'	
		AND ReceiptWasteCode.waste_code_uid = WasteCode.waste_code_uid

goto end_process
end

-- Inbound Receipts
if @ra_source = 'IRECEIPT'
begin
	insert #manifest
	SELECT Receipt.receipt_id AS source_id,
		Receipt.line_id AS source_line,
		CONVERT(varchar(40), '') AS source_code,
		Receipt.profit_ctr_id,
		Receipt.manifest, 
		Receipt.manifest_line_id AS manifest_line,   
		WasteCode.display_name,
				ReceiptWasteCode.sequence_id  
	FROM Receipt, ReceiptWasteCode, WasteCode
	WHERE Receipt.receipt_id = ReceiptWasteCode.receipt_id
		AND Receipt.line_ID = ReceiptWasteCode.line_ID
		AND Receipt.company_id = ReceiptWasteCode.company_id
		AND Receipt.profit_ctr_ID = ReceiptWasteCode.profit_ctr_ID
--km	AND ReceiptWasteCode.primary_flag = 'F'
		AND Receipt.trans_mode = 'I'  
		AND Receipt.trans_type = 'D'  
		AND Receipt.manifest_flag IN ('M','C')
		AND Receipt.receipt_status IN ('N','L','U','A')  
		AND Receipt.receipt_id IN ( SELECT source_id FROM #source_list )
		AND Receipt.company_id = @company_id
		AND Receipt.profit_ctr_ID = @profit_center		
		AND ReceiptWasteCode.waste_code <> 'NONE'
		AND ReceiptWasteCode.waste_code_uid = WasteCode.waste_code_uid

goto end_process
end

-- Receipts
if @ra_source = 'RECEIPT'
begin
	insert #manifest
	SELECT Receipt.receipt_id AS source_id,
		Receipt.line_id AS source_line,
		CONVERT(varchar(40), '') AS source_code,
		Receipt.profit_ctr_id,
		Receipt.manifest, 
		Receipt.manifest_line_id AS manifest_line,   
		WasteCode.display_name,
				ReceiptWasteCode.sequence_id  
	FROM Receipt, ReceiptWasteCode, WasteCode
	WHERE Receipt.receipt_id = ReceiptWasteCode.receipt_id
		AND Receipt.line_ID = ReceiptWasteCode.line_ID
		AND Receipt.profit_ctr_ID = ReceiptWasteCode.profit_ctr_ID
--km	AND ReceiptWasteCode.primary_flag = 'F'
		AND Receipt.trans_mode = 'O'  
		AND Receipt.trans_type = 'D'  
		AND Receipt.manifest_flag IN ('M','C')
		AND Receipt.receipt_status IN ('N','L','U','A')  
		AND Receipt.receipt_id IN ( SELECT source_id FROM #source_list )
		AND Receipt.company_id = @company_id
		AND Receipt.profit_ctr_ID = @profit_center
		AND ReceiptWasteCode.waste_code <> 'NONE'
		AND ReceiptWasteCode.waste_code_uid = WasteCode.waste_code_uid

	goto end_process
end
***/
if @ra_source in ('ORECEIPT','IRECEIPT','RECEIPT')
begin
	declare c_wc_receipt cursor forward_only read_only for
	select distinct case when @ra_source in ('ORECEIPT','RECEIPT') then 'Outbound Receipt' else 'Inbound Receipt' end, r.receipt_id, r.line_id
	from #source_list s
	join Receipt r
		on r.company_id = @company_id
		and r.profit_ctr_id = @profit_center
		and r.receipt_id = s.source_id
		and r.trans_mode = case when @ra_source in ('ORECEIPT','RECEIPT') then 'O' else 'I' end
		and r.trans_type = 'D'
		and r.manifest_flag IN ('M','C')
		AND ((r.receipt_status IN ('N','L','U','A') AND @rejection_manifest_flag = 'F') OR 
			(r.fingerpr_status = 'R' AND @rejection_manifest_flag = 'T' AND @ra_source = 'IRECEIPT'))

	open c_wc_receipt
	fetch c_wc_receipt into @source_type, @source_id, @line_id

	while @@FETCH_STATUS = 0
	begin
		insert #manifest
		select r.receipt_id AS source_id,
			r.line_id AS source_line,
			CONVERT(varchar(40), '') AS source_code,
			r.profit_ctr_id,
			r.manifest, 
			r.manifest_line_id AS manifest_line,   
			f.display_name,
			f.print_sequence_id 
		from Receipt r
		cross apply dbo.fn_tbl_manifest_waste_codes_receipt_wo (@source_type, @company_id, @profit_center, @source_id, @line_id) f
		where r.company_id = @company_id
		and r.profit_ctr_id = @profit_center
		and r.receipt_id = @source_id
		and r.line_id = @line_id
		and ISNULL(f.print_sequence_id,0) between 1 and 6
		and f.display_name <> 'NONE'

		fetch c_wc_receipt into @source_type, @source_id, @line_id
	end
	close c_wc_receipt
	deallocate c_wc_receipt

	goto end_process
end

-- workorders
if @ra_source = 'WORKORDER'
begin
/*** rb 08/21/2013 Now that a table-valued function returns waste codes, we need to use cursors.
		INSERT #manifest
		SELECT WorkorderDetail.workorder_id AS source_id,
			WorkOrderDetail.sequence_id AS source_line,
			CONVERT(varchar(40), '') AS source_code,
			WorkOrderDetail.profit_ctr_id,
			WorkOrderDetail.manifest,
			WorkOrderDetail.manifest_line_id AS manifest_line,
			wc.display_name,
			WorkOrderWasteCode.sequence_id 
		FROM WorkOrderWasteCode, WorkOrderDetail, WasteCode wc, WorkOrderHeader wh, Generator g, TSDF t
		WHERE	WorkOrderDetail.workorder_id = WorkOrderWasteCode.workorder_id
			AND WorkOrderDetail.workorder_id = WorkOrderWasteCode.workorder_id
			AND WorkOrderDetail.company_id = WorkOrderWasteCode.company_id
			AND WorkOrderDetail.profit_ctr_id = WorkOrderWasteCode.profit_ctr_id
			AND WorkOrderDetail.sequence_id = WorkOrderWasteCode.workorder_sequence_id
			AND isnull(WorkOrderWasteCode.sequence_id,0) > 0
			AND WorkOrderDetail.workorder_id IN ( SELECT source_id FROM #source_list )
			AND WorkOrderDetail.company_id = @company_id
			AND WorkOrderDetail.profit_ctr_id = @profit_center
			AND WorkOrderDetail.resource_type = 'D' 
			AND WorkOrderWasteCode.waste_code_uid = wc.waste_code_uid
			AND WorkOrderDetail.company_id = wh.company_id
			AND WorkOrderDetail.profit_ctr_id = wh.profit_ctr_id
			AND WorkOrderDetail.workorder_id = wh.workorder_id
			AND wh.generator_id = g.generator_id
			AND WorkOrderDetail.TSDF_code = t.TSDF_code
			AND (wc.waste_code_origin in ('E', 'F') or
				(wc.waste_code_origin = 'S' and wc.state in (g.generator_state, t.TSDF_state)))
		AND WorkOrderWasteCode.waste_code <> 'NONE'
		AND WorkOrderDetail.bill_rate <> -2
***/
	declare c_wc_workorder cursor forward_only read_only for
	select distinct 'Work Order', wd.workorder_id, wd.sequence_id
	from #source_list s
	join WorkOrderDetail wd
		on wd.company_id = @company_id
		and wd.profit_ctr_id = @profit_center
		and wd.workorder_id = s.source_id
		and wd.resource_type = 'D'
		and wd.bill_rate <> -2

	open c_wc_workorder
	fetch c_wc_workorder into @source_type, @source_id, @line_id

	while @@FETCH_STATUS = 0
	begin
		insert #manifest
		select wd.workorder_id AS source_id,
			wd.sequence_id AS source_line,
			CONVERT(varchar(40), '') AS source_code,
			wd.profit_ctr_id,
			wd.manifest, 
			wd.manifest_line_id AS manifest_line,   
			f.display_name,
			f.print_sequence_id 
		from WorkorderDetail wd
		cross apply dbo.fn_tbl_manifest_waste_codes_receipt_wo (@source_type, @company_id, @profit_center, @source_id, @line_id) f
		where wd.company_id = @company_id
		and wd.profit_ctr_id = @profit_center
		and wd.workorder_id = @source_id
		and wd.sequence_id = @line_id
		and wd.resource_type = 'D'
		and ISNULL(f.print_sequence_id,0) between 1 and 6
		and f.display_name <> 'NONE'

		fetch c_wc_workorder into @source_type, @source_id, @line_id
	end
	close c_wc_workorder
	deallocate c_wc_workorder

	goto end_process
end


-- Profiles
IF @ra_source = 'PROFILE'
BEGIN
/*** rb 08/13/2013 New table-valued function to compute Top 6 waste codes
	IF @generator_id IS NULL
	BEGIN
		-- First insert-select is when the parameter @generator_id is null (no generator sent in)
		INSERT #manifest
		SELECT 0 AS source_id,
			0 AS source_line,
			ProfileQuoteApproval.approval_code AS source_code,
			ProfileQuoteApproval.profit_ctr_id,
			ProfileQuoteApproval.approval_code AS manifest,
			'A' AS manifest_line,
			ProfileWasteCode.waste_code,
			ProfileWasteCode.sequence_id  
		FROM ProfileQuoteApproval
		INNER JOIN ProfileWasteCode ON ProfileQuoteApproval.profile_id = ProfileWasteCode.profile_id
		INNER JOIN Profile ON ProfileQuoteApproval.profile_id = Profile.profile_id
			AND Profile.curr_status_code = 'A'
		INNER JOIN Generator ON Profile.generator_id = Generator.generator_id
		INNER JOIN TSDF ON ProfileQuoteApproval.company_id = TSDF.eq_company
			AND ProfileQuoteApproval.profit_ctr_id = TSDF.eq_profit_ctr
			AND TSDF.eq_flag = 'T'
			AND TSDF.TSDF_status = 'A'
		INNER JOIN WasteCode ON ProfileWasteCode.waste_code = WasteCode.waste_code
		WHERE 1=1
			AND ProfileQuoteApproval.company_id = @company_id
			AND ProfileQuoteApproval.profit_ctr_id = @profit_center
			AND ProfileQuoteApproval.profile_id IN (SELECT source_id FROM #source_list)
			AND (WasteCode.waste_code_origin IN ('E', 'F') 
				OR (WasteCode.waste_code_origin = 'S' AND WasteCode.state IN (Generator.generator_state, TSDF.TSDF_state)))
			AND profileWasteCode.waste_code <> 'NONE'
			AND @generator_id IS NULL
		
	END
	ELSE
	BEGIN
	
		-- Second insert-select  gets waste codes not from profile.generator_id, but from @generator_id
		INSERT #manifest
		SELECT 0 AS source_id,
			0 AS source_line,
			ProfileQuoteApproval.approval_code AS source_code,
			ProfileQuoteApproval.profit_ctr_id,
			ProfileQuoteApproval.approval_code AS manifest,
			'A' AS manifest_line,
			ProfileWasteCode.waste_code,
			ProfileWasteCode.sequence_id  
		FROM ProfileQuoteApproval
		INNER JOIN ProfileWasteCode ON ProfileQuoteApproval.profile_id = ProfileWasteCode.profile_id
		INNER JOIN Profile ON ProfileQuoteApproval.profile_id = Profile.profile_id
			AND Profile.curr_status_code = 'A'
		INNER JOIN Generator ON Generator.generator_id = @generator_id
		INNER JOIN TSDF ON ProfileQuoteApproval.company_id = TSDF.eq_company
			AND ProfileQuoteApproval.profit_ctr_id = TSDF.eq_profit_ctr
			AND TSDF.eq_flag = 'T'
			AND TSDF.TSDF_status = 'A'
		INNER JOIN WasteCode ON ProfileWasteCode.waste_code = WasteCode.waste_code
		WHERE 1=1
			AND ProfileQuoteApproval.company_id = @company_id
			AND ProfileQuoteApproval.profit_ctr_id = @profit_center
			AND ProfileQuoteApproval.profile_id IN (SELECT source_id FROM #source_list)
			AND (WasteCode.waste_code_origin IN ('E', 'F') 
				OR (WasteCode.waste_code_origin = 'S' AND WasteCode.state IN (Generator.generator_state, TSDF.TSDF_state)))
			AND profileWasteCode.waste_code <> 'NONE'
			AND @generator_id IS NOT NULL
	END
***/
	declare c_prof cursor read_only forward_only for
	select pqa.profile_id, s.default_line, pqa.approval_code, isnull(@generator_id,p.generator_id), isnull(@tsdf_code,t.tsdf_code)
	from #source_list s
	join Profile p (nolock)
		on s.source_id = p.profile_id
		and p.curr_status_code = 'A'
	join ProfileQuoteApproval pqa (nolock)
		on p.profile_id = pqa.profile_id
		and pqa.company_id = @company_id
		and pqa.profit_ctr_id = @profit_center
	join TSDF t (nolock)
		on pqa.company_id = t.eq_company
		and pqa.profit_ctr_id = t.eq_profit_ctr
		and t.eq_flag = 'T'
		and t.TSDF_status = 'A'

	open c_prof
	fetch c_prof into @source_id, @line_char, @approval_code, @arg_generator_id, @arg_tsdf_code
	
	while @@FETCH_STATUS = 0
	begin
		INSERT #manifest
		SELECT @source_id AS source_id,
			convert(int,@line_char) AS source_line,
			@approval_code AS source_code,
			@profit_center AS profit_ctr_id,
			'MANIFEST_1' AS manifest,
			case when @line_char in ('1','2','3','4') then CHAR (64 + convert(int,@line_char)) else CHAR (64 + ((16 - convert(int,@line_char)) % 10)) end AS manifest_line,
			display_name,
			print_sequence_id
		FROM dbo.fn_tbl_manifest_waste_codes ('Profile', @source_id, @arg_generator_id, @arg_tsdf_code)
		WHERE ISNULL(print_sequence_id,0) between 1 and 6
		AND display_name <> 'NONE'

		fetch c_prof into @source_id, @line_char, @approval_code, @arg_generator_id, @arg_tsdf_code
	end
	close c_prof
	deallocate c_prof

	GOTO end_process
END

-- TSDF Approvals

IF @ra_source = 'TSDFAPPR'
BEGIN
/*** rb 08/13/2013 New table-valued function to compute Top 6 waste codes
	INSERT #manifest
	SELECT 0 AS source_id,
		0 AS source_line,
		TSDFApproval.TSDF_approval_code AS source_code,
		TSDFApproval.profit_ctr_id,
		TSDFApproval.TSDF_approval_code AS manifest,
		'A' AS manifest_line,
		TSDFApprovalWasteCode.waste_code,
				TSDFApprovalWasteCode.sequence_id  
	FROM TSDFApproval,
		 TSDFApprovalWasteCode,
		Generator, TSDF, WasteCode
	WHERE   TSDFApproval.TSDF_approval_id = TSDFApprovalWasteCode.TSDF_approval_id
		AND TSDFApproval.profit_ctr_id  = TSDFApprovalWasteCode.profit_ctr_id
		AND TSDFApproval.company_id = TSDFApprovalWasteCode.company_id
--km	AND TSDFApprovalWasteCode.primary_flag = 'F'
		AND TSDFApproval.TSDF_approval_id IN ( SELECT source_id FROM #source_list )
--rb		AND TSDFApproval.TSDF_approval_status = 'A'
		AND TSDFApproval.profit_ctr_id = @profit_center
		AND TSDFApproval.company_id = @company_id
		-- rb, added below
		AND TSDFApproval.generator_id = Generator.generator_id
		AND TSDFApprovalWasteCode.company_id = @company_id
		AND TSDFApprovalWasteCode.waste_code = WasteCode.waste_code
		AND TSDFApproval.TSDF_code = TSDF.TSDF_code
		AND TSDF.TSDF_status = 'A'
		AND (WasteCode.waste_code_origin in ('E', 'F') or
			(WasteCode.waste_code_origin = 'S' and WasteCode.state in (Generator.generator_state, TSDF.TSDF_state)))
		AND TSDFApprovalWasteCode.waste_code <> 'NONE'
***/
	declare c_tsdf cursor read_only forward_only for
	select a.TSDF_approval_id, s.default_line, a.TSDF_approval_code, isnull(@generator_id,a.generator_id), isnull(@tsdf_code,t.tsdf_code)
	from #source_list s
	join TSDFApproval a (nolock)
		on s.source_id = a.TSDF_approval_id
		and a.company_id = @company_id
		and a.profit_ctr_id = @profit_center
		and a.TSDF_approval_status = 'A'
	join TSDF t (nolock)
		on a.TSDF_code = t.TSDF_code
		and t.TSDF_status = 'A'

	open c_tsdf
	fetch c_tsdf into @source_id, @line_char, @approval_code, @arg_generator_id, @arg_tsdf_code
	
	while @@FETCH_STATUS = 0
	begin
		INSERT #manifest
		SELECT @source_id AS source_id,
			convert(int,@line_char) AS source_line,
			@approval_code AS source_code,
			@profit_center AS profit_ctr_id,
			'MANIFEST_1' AS manifest,
			case when @line_char in ('1','2','3','4') then CHAR (64 + convert(int,@line_char)) else CHAR (64 + ((16 - convert(int,@line_char)) % 10)) end AS manifest_line,
			display_name,
			print_sequence_id
		FROM dbo.fn_tbl_manifest_waste_codes ('TSDFApproval', @source_id, @arg_generator_id, @arg_tsdf_code)
		WHERE ISNULL(print_sequence_id,0) between 1 and 6
		AND display_name <> 'NONE'

		fetch c_tsdf into @source_id, @line_char, @approval_code, @arg_generator_id, @arg_tsdf_code
	end
	close c_tsdf
	deallocate c_tsdf

	goto end_process
end


end_process:

SET NOCOUNT OFF

-- dump the manifest table
select  source_id ,
	source_line ,
	source_code ,
	profit_center ,
	manifest ,
	manifest_line,
	wastecode,
	IsNull(sequence_id,999) 
from #manifest
order by sequence_id

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_get_manifest_sec_wastecodes_uniform] TO [EQAI]
    AS [dbo];

