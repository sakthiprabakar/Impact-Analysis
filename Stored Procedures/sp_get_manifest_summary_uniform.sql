DROP PROCEDURE IF EXISTS [dbo].[sp_get_manifest_summary_uniform] 
GO

CREATE PROCEDURE [dbo].[sp_get_manifest_summary_uniform] (
	@ra_source	varchar(20), 
	@ra_list	varchar(2000),
	@profit_center	int,
	@company_id	int,
	@rejection_manifest_flag	char(1) )
WITH RECOMPILE
AS
/***************************************************************************************
Returns manifest infromation for the manifest window
Requires: none
Loads on PLT_XX_AI

06/26/2006 RG	Created
09/08/2006 JDB	Added waste_desc into @instructions concatenation
10/11/2006 RG	removed test for negative list_ids
06/16/2008 KAM	Updated for the new fields in the Receipt Table
02/04/2009 RWB	Added TRIP source
03/09/2009 JPB	Added SET NOCOUNT ON (and OFF)
04/10/2009 RWB	Modified end of proc to produce summaries for all source_ids (it used to just retrieve one source_id at a time).
                Bug fix, ignore TSDF Approval Status (when they are made inactive, view manifest crashes)
05/11/2009 JDB	Added ERG_suffix
08/11/2009 RWB	Exclude void WorkOrderDetail records with bill_rate = -2
10/14/2009 KAM  Increase the size of the handling instructions to text
10/15/2009 JDB	Removed ERG number and suffix (moving to section 9 of manifest);
				Removed leading spaces from @instructions before inserting into #manifest table
08/20/2010 KAM  Removed reference to dropped field WorkOrderDetail.waste_code
02/24/2011 RWB  Sort order was using manifest_line_id instead of manifest_line
03/07/2012 RWB	A WorkOrderDetail record with a null manifest, page and line put the EndProcess section into an infinite loop
08/19/2013 RWB	Moved to Plt_ai, added manifest_message for Section 14, pulling from Profile and/or TSDFApproval
09/09/2014 SM	Fixed issue of profile manifest printing order.
12/08/2014 RWB	Suddenly started lots of blocking, added SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
04/27/2016 RWB	GEM:37151 Append trip information if printed from Trip or Workorder screen (if associated with a trip)
04/28/2016 RWB	GEM:36317 Flag to print empty bottle counts now on Profile and TSDFApproval tables
05/02/2016 RWB	GEM:36318 Flag to print actual manifest weights
06/22/2016 RWB	GEM:37132 Profile Section 14 messages should print on the page that contains the approvals
10/20/2016 MPM	GEM:39820 - Appended AESOP profile ID and AESOP waste stream to the handling instructions only if the source is TSDFApproval
06/25/2018 MPM	GEM 51165 - Added @rejection_manifest_flag input parameter and associated logic.
07/08/2021 MPM	DevOps 21572 - Modified trip info, added work order and receipt info.
07/12/2023 MPM	DevOps 64576 - Modified for change to ManifestPrintDetail.manifest_line from CHAR(2) to CHAR(3).
09/12/2024 Sailaja	Rally# US120551 - Included D365 Project on printed manifest in case of WORKORDER source.


sp_get_manifest_summary_uniform 'PROFILE', '155780',0,21
sp_get_manifest_summary_uniform 'IRECEIPT', '640458',0,21
sp_get_manifest_summary_uniform 'ORECEIPT', '30244',0, 22
sp_get_manifest_summary_uniform 'WORKORDER', '11753900',0,14
sp_get_manifest_summary_uniform 'TSDFAPPR', '22126',0,21
sp_get_manifest_summary_uniform 'IRECEIPT', '29601',1,21, 'T'

****************************************************************************************/
SET NOCOUNT ON

DECLARE	@more_rows int,
	@list_id int,
	@start int,
	@end int,
	@lnth int,
	@CARRIAGE_RETURN char(2),
	@control_id int,
	@source varchar(10),
	@source_id int,
	@source_line int,
	@profit_ctr_id int,
	@manifest varchar(15), 
	@manifest_line_id char(1),
	@manifest_line char(3) ,
	@manifest_page_num int ,
	@packing_group varchar(3),
	@ERG_number int,
	@ERG_suffix char(2),
	@waste_code varchar(4),   
	@approval_code varchar(40),   
	@waste_desc varchar(50),   
	@manifest_handling_code varchar(15),   
	@hand_instruct varchar(255),
	@waste_stream varchar(20),
	@continuation_flag char(1),
	@SEPARATOR	char(3),
	@pageno		int,
	@hold_page	int,
	@linecnt	int,
	@hold_manifest	varchar(15),
	@instructions	varchar(8000),
	@err_msg	varchar(60),
	@count		int,
	@manifest_message varchar(255),
	@empty_bottle_flag char(1),
	@empty_bottle_count_manifest_print_flag char(1),
	@residue_pounds_factor float,
	@residue_manifest_print_flag char(1),
	@manifest_actual_wt_flag char(1),
	@manifest_actual_wt numeric(18,6),
	@empty_bottle_count int,
	@default_line int,
	@line_char char,
	@r varchar(10),
	@i int,
	@AESOP_profile_id int,
	@AESOP_waste_stream varchar(9),
	@rejection_contact_name varchar(40)

CREATE TABLE #source_list (
	source_id int null,
	default_page int null,
	default_line char(2) null	)
					 
CREATE TABLE #manifest (
	control_id int null,
	source varchar(10) null,
	source_id int null,
	source_code varchar(40) null,
	profit_center int null,
	num_pages int null,
	manifest varchar(15) null,
	continuation_flag    char(1)     null,
	handling_instructions text   null	)

CREATE TABLE #waste_info (
	control_id int null,
	source varchar(10) null,
	source_id int null,
	source_line int null,
	profit_center int null,
	manifest varchar(15) null, 
	manifest_line_id char(2) null,
	manifest_line char(3) null,
	manifest_page_num int null,
	packing_group varchar(3) null,   
	ERG_number int null,
	ERG_suffix char(2) null,
	waste_code varchar(4) null,   
	approval_code varchar(40) null,   
	waste_desc varchar(50) null,   
	manifest_handling_code varchar(15) null,   
	hand_instruct varchar(255) null,
	waste_stream varchar(20) null,
	continuation_flag char(1) null,
	manifest_message varchar(255) null,
	empty_bottle_flag char(1) null,
	empty_bottle_count_manifest_print_flag char(1) null,
	residue_pounds_factor float null,
	residue_manifest_print_flag char(1) null,
	manifest_actual_wt_flag char(1),
	manifest_actual_wt numeric(18,6),
	empty_bottle_count int null,
	AESOP_profile_id int null,
	AESOP_waste_stream varchar(9) null )

SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

-- decode the source list for retirieval
SELECT @CARRIAGE_RETURN = CHAR(13) + CHAR(10)
SELECT @SEPARATOR = SPACE(2)


-- load the source list table
IF LEN(@ra_list) > 0
BEGIN
	SELECT @more_rows = 1,
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
			--INSERT INTO #source_list VALUES (@list_id, @manifest_page_num, @line_char)
			IF @default_line > 9
				INSERT INTO #source_list VALUES (@list_id, @manifest_page_num, CONVERT(char(2),@default_line) )
			Else
				INSERT INTO #source_list VALUES (@list_id, @manifest_page_num, '0' + CONVERT(char(1),@default_line) )
			
		END
		ELSE 
		BEGIN
			SELECT @lnth = LEN(@ra_list)
			SELECT @list_id = CONVERT(int,SUBSTRING(@ra_list,@start,@lnth))
			SELECT @more_rows = 0
			--INSERT INTO #source_list VALUES (@list_id, @manifest_page_num, @line_char)
			IF @default_line > 9
				INSERT INTO #source_list VALUES (@list_id, @manifest_page_num, CONVERT(char(2),@default_line) )
			Else
				INSERT INTO #source_list VALUES (@list_id, @manifest_page_num, '0' + CONVERT(char(1),@default_line) )
		END
	END
END 
-- determine the source; each source has its own query
-- out bound Receipts
IF @ra_source = 'ORECEIPT'
BEGIN
	INSERT #waste_info	
	SELECT 0 AS print_control_id,   
		CONVERT(varchar(10), @ra_source) AS source, 
		Receipt.receipt_id AS source_id,   
		Receipt.line_id AS source_line_id,
		Receipt.profit_ctr_id,  
		ISNULL(Receipt.manifest, ''),
		Receipt.manifest_line_id,
		Receipt.manifest_line_id AS manifest_line,   
		Receipt.manifest_page_num,
		Receipt.manifest_package_group AS packing_group,   
		Receipt.manifest_ERG_number,
		ISNULL(Receipt.manifest_ERG_suffix, '') AS ERG_suffix,
		Receipt.waste_code,   
		ProfileQuoteApproval.approval_code AS approval_code,   
		COALESCE(Profile.manifest_waste_desc, Profile.approval_desc) AS waste_desc,   
		Profile.manifest_handling_code,   
		Profile.manifest_hand_instruct,
		'' AS waste_stream,
		Receipt.continuation_flag AS continuation_flag,
		Profile.manifest_message,
		Profile.empty_bottle_flag,
		Profile.empty_bottle_count_manifest_print_flag,
		Profile.residue_pounds_factor,
		Profile.residue_manifest_print_flag,
		Profile.manifest_actual_wt_flag,
		Receipt.line_weight,
		(select round(isnull(sum(isnull(merchandise_quantity,0)),0),4)
				from ReceiptDetailItem
				where company_id = Receipt.company_id
				and profit_ctr_id = Receipt.profit_ctr_id
				and receipt_id = Receipt.receipt_id
				and line_id = Receipt.line_id
				and item_type_ind = 'ME'),
	    null,
	    null
	FROM Receipt,   
		Profile,
		ProfileQuoteApproval
	WHERE Receipt.OB_profile_id = ProfileQuoteApproval.profile_id
	AND Receipt.OB_profile_profit_ctr_ID = ProfileQuoteApproval.profit_ctr_ID
	AND Receipt.OB_profile_company_id = ProfileQuoteApproval.company_id
	AND Profile.profile_id = ProfileQuoteApproval.profile_id
	AND Receipt.trans_mode = 'O'  
	AND Receipt.trans_type = 'D'  
	AND Receipt.manifest_flag IN ('M','C')
	AND Receipt.receipt_status IN ('N','L','U','A')  
	AND Profile.curr_status_code = 'A'
	AND Receipt.receipt_ID IN ( SELECT source_id FROM #source_list )
	AND Receipt.company_ID = @company_id
	AND Receipt.profit_ctr_ID = @profit_center

UNION
	SELECT 0 AS print_control_id,   
		CONVERT(varchar(10), @ra_source) AS source, 
		Receipt.receipt_id AS source_id,   
		Receipt.line_id AS source_line_id,
		Receipt.profit_ctr_id,
		ISNULL(Receipt.manifest, ''),
		Receipt.manifest_line_id,
		Receipt.manifest_line_id AS manifest_line,   
		Receipt.manifest_page_num,
		Receipt.manifest_package_group AS packing_group,   
		Receipt.manifest_ERG_number,
		ISNULL(Receipt.manifest_ERG_suffix, '') AS ERG_suffix,
		Receipt.waste_code,   
		Receipt.TSDF_approval_code AS approval_code,   
		TSDFapproval.waste_desc,   
		TSDFapproval.manifest_handling_code,   
		TSDFapproval.hand_instruct,
		TSDFapproval.waste_stream AS waste_stream,
		Receipt.continuation_flag AS continuation_flag,
		TSDFApproval.manifest_message,
		TSDFApproval.empty_bottle_flag,
		TSDFApproval.empty_bottle_count_manifest_print_flag,
		TSDFApproval.residue_pounds_factor,
		TSDFApproval.residue_manifest_print_flag,
		TSDFApproval.manifest_actual_wt_flag,
		Receipt.line_weight,
		(select round(isnull(sum(isnull(merchandise_quantity,0)),0),4)
				from ReceiptDetailItem
				where company_id = Receipt.company_id
				and profit_ctr_id = Receipt.profit_ctr_id
				and receipt_id = Receipt.receipt_id
				and line_id = Receipt.line_id
				and item_type_ind = 'ME'),
		null,
		null	   
	FROM Receipt,   
		TSDFApproval
	WHERE Receipt.TSDF_approval_id = TSDFapproval.TSDF_approval_id
	AND Receipt.company_id = TSDFApproval.company_id
	AND Receipt.profit_ctr_ID = TSDFapproval.profit_ctr_id
	AND Receipt.trans_mode = 'O'  
	AND Receipt.trans_type = 'D'  
	AND Receipt.manifest_flag IN ('M','C')
	AND Receipt.receipt_status IN ('N','L','U','A')  
--rb	AND TSDFapproval.TSDF_approval_status = 'A'
	AND Receipt.profile_id IS NULL 
	AND Receipt.receipt_ID IN ( SELECT source_id FROM #source_list )
	AND Receipt.company_ID = @company_id
	AND Receipt.profit_ctr_ID = @profit_center

	GOTO EndProcess
END


-- Inbound Receipts
IF @ra_source = 'IRECEIPT'
BEGIN
	INSERT #waste_info	
	SELECT 0 AS print_control_id,   
		CONVERT(varchar(10), @ra_source) AS source, 
		Receipt.receipt_id AS source_id,   
		Receipt.line_id AS source_line_id,
		Receipt.profit_ctr_id,  
		Receipt.manifest, 
		Receipt.manifest_line_id,
		Receipt.manifest_line_id AS manifest_line,   
		Receipt.manifest_page_num,
		Receipt.manifest_package_group AS packing_group,   
		Receipt.manifest_ERG_number,
		ISNULL(Receipt.manifest_ERG_suffix, '') AS ERG_suffix,
		Receipt.waste_code,   
		ProfileQuoteApproval.approval_code AS approval_code,   
		COALESCE(Profile.manifest_waste_desc, Profile.approval_desc) AS waste_desc,   
		Profile.manifest_handling_code,   
		Profile.manifest_hand_instruct,
		'' AS waste_stream,
		Receipt.continuation_flag AS continuation_flag,
		Profile.manifest_message,
		Profile.empty_bottle_flag,
		Profile.empty_bottle_count_manifest_print_flag,
		Profile.residue_pounds_factor,
		Profile.residue_manifest_print_flag,
		Profile.manifest_actual_wt_flag,
		Receipt.line_weight,
		(select round(isnull(sum(isnull(merchandise_quantity,0)),0),4)
				from ReceiptDetailItem
				where company_id = Receipt.company_id
				and profit_ctr_id = Receipt.profit_ctr_id
				and receipt_id = Receipt.receipt_id
				and line_id = Receipt.line_id
				and item_type_ind = 'ME'),
		null,
		null	   
	FROM Receipt
	INNER JOIN ProfileQuoteApproval ON (Receipt.profile_id = ProfileQuoteApproval.profile_id
		AND Receipt.company_id = ProfileQuoteApproval.company_id
		AND Receipt.profit_ctr_ID = ProfileQuoteApproval.profit_ctr_ID)
	INNER JOIN Profile ON Profile.profile_id = ProfileQuoteApproval.profile_id
	WHERE Receipt.profit_ctr_ID = @profit_center
	AND Receipt.company_ID = @company_id
	AND Receipt.receipt_ID IN ( SELECT source_id FROM #source_list )
	AND Receipt.trans_mode = 'I'  
	AND Receipt.trans_type = 'D'  
	AND Receipt.manifest_flag IN ('M','C')
	AND ((Receipt.receipt_status IN ('N','L','U','A') AND @rejection_manifest_flag = 'F') OR 
	     (Receipt.fingerpr_status = 'R' AND @rejection_manifest_flag = 'T'))
	AND Profile.curr_status_code = 'A'

	GOTO EndProcess
END


-- Work Orders
IF @ra_source = 'WORKORDER'
BEGIN
	INSERT #waste_info
	SELECT DISTINCT 0 AS print_control_id,   
		-- rb, trip
		case when WorkOrderHeader.workorder_id <= -1000 then convert(varchar(10),'TRIP ' + convert(varchar(5),WorkOrderHeader.trip_id)) else CONVERT(varchar(10), @ra_source) end AS source, 
		WorkOrderHeader.workorder_id,
		0 AS source_line_id,
		WorkOrderDetail.profit_ctr_id,  
		WorkOrderDetail.manifest, 
		CASE WorkOrderDetail.manifest_line_id
			WHEN 'A' THEN '01'
			WHEN 'B' THEN '02'
			WHEN 'C' THEN '03'
			WHEN 'D' THEN '04'
			WHEN 'E' THEN '05'
			WHEN 'F' THEN '06'
			WHEN 'G' THEN '07'
			WHEN 'H' THEN '08'
			WHEN 'I' THEN '09' 
			WHEN 'J' THEN '10'
			END AS manifest_line_id,
		CASE WHEN WorkOrderDetail.manifest_line > 0 AND WorkOrderDetail.manifest_line < 10
			THEN '00' + CONVERT(char(1), WorkOrderDetail.manifest_line)
			WHEN WorkOrderDetail.manifest_line > 0 AND WorkOrderDetail.manifest_line < 100
			THEN '0' + CONVERT(char(2), WorkOrderDetail.manifest_line)
			ELSE CONVERT(char(3), WorkOrderDetail.manifest_line)
			END AS manifest_line,
		WorkOrderDetail.manifest_page_num,
		COALESCE(WorkOrderDetail.package_group, Profile.package_group) AS packing_group,
		COALESCE(WorkOrderDetail.ERG_number, Profile.ERG_number),
		ISNULL(COALESCE(WorkOrderDetail.ERG_suffix, Profile.ERG_suffix), '') AS ERG_suffix,
		Profile.waste_code,   
		COALESCE(WorkOrderDetail.TSDF_approval_code,ProfileQuoteApproval.approval_code) AS approval_code,   
		COALESCE(WorkOrderDetail.manifest_waste_desc,COALESCE(Profile.manifest_waste_desc, Profile.approval_desc)) AS waste_desc,   
		COALESCE(WorkOrderDetail.manifest_handling_code, Profile.manifest_handling_code),   
		COALESCE(WorkOrderDetail.manifest_hand_instruct, Profile.manifest_hand_instruct),
		'' AS waste_stream,
		WorkOrderManifest.continuation_flag AS continuation_flag,
		Profile.manifest_message,
		isnull(Profile.empty_bottle_flag,'F'),
		isnull(Profile.empty_bottle_count_manifest_print_flag,'F'),
		isnull(Profile.residue_pounds_factor,0),
		isnull(Profile.residue_manifest_print_flag,'F'),
		isnull(Profile.manifest_actual_wt_flag,'F'),
		(select quantity from WorkOrderDetailUnit
			where workorder_id = WorkOrderDetail.workorder_id
			and company_id = WorkOrderDetail.company_id
			and profit_ctr_id = WorkOrderDetail.profit_ctr_id
			and sequence_id = WorkOrderDetail.sequence_id
			and bill_unit_code = 'LBS'),
		(select round(isnull(sum(isnull(merchandise_quantity,0)),0),4)
				from WorkOrderDetailItem
				where workorder_id = WorkOrderDetail.workorder_id
				and company_id = WorkOrderDetail.company_id
				and profit_ctr_id = WorkOrderDetail.profit_ctr_id
				and sequence_id = WorkOrderDetail.sequence_id
				and item_type_ind = 'ME'),
		null,
		null	   
	FROM WorkOrderDetail,
		Profile,
		ProfileQuoteApproval,
		WorkOrderHeader,
		WorkOrderManifest
	WHERE WorkOrderDetail.profile_id = ProfileQuoteApproval.profile_id
	AND Profile.profile_id = ProfileQuoteApproval.profile_id
	AND ProfileQuoteApproval.company_id = WorkorderDetail.profile_company_id
	AND ProfileQuoteApproval.profit_ctr_id = WorkorderDetail.profile_profit_ctr_id
	AND WorkOrderDetail.workorder_ID = WorkOrderHeader.workorder_ID  
	AND WorkOrderDetail.company_ID = WorkOrderHeader.company_ID  
	AND WorkOrderDetail.profit_ctr_ID = WorkOrderHeader.profit_ctr_ID  
	AND WorkOrderDetail.workorder_ID = WorkOrderManifest.workorder_ID
	AND WorkOrderDetail.company_ID = WorkOrderManifest.company_ID
	AND WorkOrderDetail.profit_ctr_ID = WorkOrderManifest.profit_ctr_ID
	AND WorkOrderDetail.manifest = WorkOrderManifest.manifest
	AND WorkOrderDetail.Resource_type = 'D'
	AND Profile.curr_status_code = 'A'
	AND WorkOrderManifest.manifest_flag = 'T'
	AND WorkOrderDetail.workorder_ID IN ( SELECT source_id FROM #source_list )
	AND WorkOrderDetail.company_ID = @company_id
	AND WorkOrderDetail.profit_ctr_ID = @profit_center
	AND WorkOrderDetail.bill_rate <> -2 -- rb 08/12/2009
UNION
	SELECT DISTINCT 0 AS print_control_id,   
		-- rb, trip
		case when WorkOrderHeader.workorder_id <= -1000 then convert(varchar(10),'TRIP ' + convert(varchar(5),WorkOrderHeader.trip_id)) else CONVERT(varchar(10), @ra_source) end AS source, 
		WorkOrderHeader.workorder_id,
		0 AS source_line_id,
		WorkOrderDetail.profit_ctr_id,  
		WorkOrderDetail.manifest, 
		CASE WorkOrderDetail.manifest_line_id
			WHEN 'A' THEN '01'
			WHEN 'B' THEN '02'
			WHEN 'C' THEN '03'
			WHEN 'D' THEN '04'
			WHEN 'E' THEN '05'
			WHEN 'F' THEN '06'
			WHEN 'G' THEN '07'
			WHEN 'H' THEN '08'
			WHEN 'I' THEN '09' 
			WHEN 'J' THEN '10'
			END AS manifest_line_id,
		CASE WHEN WorkOrderDetail.manifest_line > 0 AND WorkOrderDetail.manifest_line < 10
			THEN '00' + CONVERT(char(1), WorkOrderDetail.manifest_line)
			WHEN WorkOrderDetail.manifest_line > 0 AND WorkOrderDetail.manifest_line < 100
			THEN '0' + CONVERT(char(2), WorkOrderDetail.manifest_line)
			ELSE CONVERT(char(3), WorkOrderDetail.manifest_line)
			END AS manifest_line,
		WorkOrderDetail.manifest_page_num,
		COALESCE(WorkOrderDetail.package_group,TSDFapproval.package_group) AS packing_group,   
		COALESCE(WorkOrderDetail.ERG_number, TSDFapproval.ERG_number),
		ISNULL(COALESCE(WorkOrderDetail.ERG_suffix, TSDFapproval.ERG_suffix), '') AS ERG_suffix,
		TSDFapproval.waste_code,   
		WorkOrderDetail.TSDF_approval_code AS approval_code,   
		COALESCE(WorkOrderDetail.manifest_waste_desc, TSDFapproval.waste_desc) AS waste_desc,   
		COALESCE(WorkOrderDetail.manifest_handling_code, TSDFapproval.manifest_handling_code),   
		COALESCE(WorkOrderDetail.manifest_hand_instruct, TSDFapproval.hand_instruct),
		TSDFapproval.waste_stream AS waste_stream,
		WorkOrderManifest.continuation_flag AS continuation_flag,
		TSDFApproval.manifest_message,
		isnull(TSDFApproval.empty_bottle_flag,'F'),
		isnull(TSDFApproval.empty_bottle_count_manifest_print_flag,'F'),
		isnull(TSDFApproval.residue_pounds_factor,0),
		isnull(TSDFApproval.residue_manifest_print_flag,'F'),
		isnull(TSDFApproval.manifest_actual_wt_flag,'F'),
		(select quantity from WorkOrderDetailUnit
			where workorder_id = WorkOrderDetail.workorder_id
			and company_id = WorkOrderDetail.company_id
			and profit_ctr_id = WorkOrderDetail.profit_ctr_id
			and sequence_id = WorkOrderDetail.sequence_id
			and bill_unit_code = 'LBS'),
		(select round(isnull(sum(isnull(merchandise_quantity,0)),0),4)
				from WorkOrderDetailItem
				where workorder_id = WorkOrderDetail.workorder_id
				and company_id = WorkOrderDetail.company_id
				and profit_ctr_id = WorkOrderDetail.profit_ctr_id
				and sequence_id = WorkOrderDetail.sequence_id
				and item_type_ind = 'ME'),
		null,
		null		   
	FROM WorkOrderDetail,
		TSDFapproval,
		WorkOrderHeader,
		WorkOrderManifest
	WHERE WorkOrderDetail.TSDF_approval_id = TSDFapproval.TSDF_approval_id
	AND WorkOrderDetail.profit_ctr_ID = TSDFapproval.profit_ctr_ID
	AND TSDFapproval.company_id = @company_id
	AND TSDFapproval.profit_ctr_id = @profit_center
	AND WorkOrderDetail.workorder_ID = WorkOrderHeader.workorder_ID  
	AND WorkOrderDetail.company_ID = WorkOrderHeader.company_ID  
	AND WorkOrderDetail.profit_ctr_ID = WorkOrderHeader.profit_ctr_ID  
	AND WorkOrderDetail.workorder_ID = WorkOrderManifest.workorder_ID
	AND WorkOrderDetail.company_ID = WorkOrderManifest.company_ID
	AND WorkOrderDetail.profit_ctr_ID = WorkOrderManifest.profit_ctr_ID
	AND WorkOrderDetail.manifest = WorkOrderManifest.manifest
	AND WorkOrderDetail.Resource_type = 'D'
--rb	AND TSDFapproval.TSDF_approval_status = 'A'
	AND WorkOrderManifest.manifest_flag = 'T'
	AND WorkOrderDetail.profile_id IS NULL 
	AND WorkOrderDetail.workorder_ID IN ( SELECT source_id FROM #source_list )
	AND WorkOrderDetail.company_ID = @company_id
	AND WorkOrderDetail.profit_ctr_ID = @profit_center
	AND WorkOrderDetail.bill_rate <> -2 -- rb 08/12/2009

	GOTO EndProcess
END

-- Profiles
IF @ra_source = 'PROFILE'
BEGIN
	INSERT #waste_info	
	SELECT 0 AS print_control_id,   
		CONVERT(varchar(10), @ra_source) AS source, 
		Profile.profile_id AS source_id,
		0 AS source_line_id,
		ProfileQuoteApproval.profit_ctr_id,  
		' ' AS manifest, 
		#source_list.default_line AS manifest_line_id,
		CONVERT(varchar(3),#source_list.default_line) AS manifest_line,   
	--	CONVERT(varchar(2),@default_line) AS manifest_line, 
		#source_list.default_page AS manifest_page_num,   
		Profile.package_group AS packing_group,   
		Profile.ERG_number,   
		ISNULL(Profile.ERG_suffix, '') AS ERG_suffix,
		Profile.waste_code,   
		ProfileQuoteApproval.approval_code,   
		COALESCE(Profile.manifest_waste_desc, Profile.approval_desc) AS waste_desc,   
		Profile.manifest_handling_code,   
		Profile.manifest_hand_instruct,
		CONVERT(varchar(10), '') AS waste_stream,
		'F' AS continuation_flag,
		Profile.manifest_message,
		Profile.empty_bottle_flag,
		Profile.empty_bottle_count_manifest_print_flag,
		Profile.residue_pounds_factor,
		Profile.residue_manifest_print_flag,
		Profile.manifest_actual_wt_flag,
		0,
		0,
		null,
		null		   
	FROM Profile, ProfileQuoteApproval, #source_list
	WHERE ProfileQuoteApproval.profile_id = Profile.profile_id
	AND ProfileQuoteApproval.company_id = @company_id
	AND ProfileQuoteApproval.profit_ctr_id = @profit_center
	AND ProfileQuoteApproval.profile_id = #source_list.source_id
	AND Profile.curr_status_code = 'A'

	GOTO EndProcess
END

-- TSDF Approvals
IF @ra_source = 'TSDFAPPR'
BEGIN
	INSERT #waste_info	
	SELECT 0 AS print_control_id,   
		CONVERT(varchar(10), @ra_source) AS source, 
		TSDFapproval.tsdf_approval_id AS source_id,
		0 AS source_line_id,   
		TSDFApproval.profit_ctr_id,  
		' ' AS manifest, 
		#source_list.default_line AS manifest_line_id,
		CONVERT(varchar(3),#source_list.default_line) AS manifest_line,   
		--CONVERT(varchar(2),@default_line) AS manifest_line,   
		#source_list.default_page AS manifest_page_num,   
		TSDFapproval.package_group AS packing_group,   
		TSDFapproval.ERG_number,
		ISNULL(TSDFapproval.ERG_suffix, '') AS ERG_suffix,
		TSDFapproval.waste_code,   
		TSDFapproval.TSDF_approval_code AS approval_code,   
		TSDFapproval.waste_desc AS waste_desc,   
		TSDFapproval.manifest_handling_code,   
		TSDFapproval.hand_instruct,
		TSDFapproval.waste_stream AS waste_stream,
		'F' AS continuation_flag,
		TSDFApproval.manifest_message,
		TSDFApproval.empty_bottle_flag,
		TSDFApproval.empty_bottle_count_manifest_print_flag,
		TSDFApproval.residue_pounds_factor,
		TSDFApproval.residue_manifest_print_flag,
		TSDFApproval.manifest_actual_wt_flag,
		0,
		0,
		TSDFApproval.AESOP_profile_ID,
		TSDFApproval.AESOP_waste_stream		   
	FROM TSDFapproval, #source_list
	WHERE TSDFApproval.TSDF_approval_id = #source_list.source_id
--rb	AND TSDFApproval.TSDF_approval_status = 'A'
	AND TSDFApproval.profit_ctr_ID = @profit_center
	AND TSDFApproval.company_id = @company_id
	
	GOTO EndProcess
END

-------------------------------------------
EndProcess:
-------------------------------------------
SELECT @count = COUNT(*) FROM #waste_info
IF @count <= 0
BEGIN
	RAISERROR('No rows found in #waste_info table',16,1)
        RETURN
END

-- rb 09/20/2013 For Profiles and TSDFApprovals, if multiples, we need to build one summary string
if (@ra_source = 'PROFILE' or @ra_source = 'TSDFAPPR') and (select COUNT(*) from #source_list) > 1
	update #waste_info set source_id = 0

-- rb 10/10/2009 Workorder performance boost, now called only once per manifest by allowing multiple source_ids passed in
declare c_source_id cursor for
select distinct source_id 
from #waste_info
for read only

open c_source_id
fetch next from c_source_id into @source_id

while @@FETCH_STATUS = 0
begin

	-- now summarize by page
	-- declare cursor
	DECLARE manifest_line CURSOR FOR
	SELECT  control_id,
        	source,
--rb      		source_id,
	    	source_line,
   		profit_center,
   		manifest,
		manifest_line_id,
		manifest_line,
		manifest_page_num,
		packing_group,
		ERG_number,
		ISNULL(ERG_suffix, '') AS ERG_suffix,
		waste_code,
		approval_code,
		waste_desc,
		manifest_handling_code,
		hand_instruct,
		waste_stream,
		continuation_flag,
		manifest_message,
		isnull(empty_bottle_flag,'F'),
		isnull(empty_bottle_count_manifest_print_flag,'F'),
		isnull(residue_pounds_factor,0),
		isnull(residue_manifest_print_flag,'F'),
		isnull(manifest_actual_wt_flag,'F'),
		isnull(manifest_actual_wt,0),
		isnull(empty_bottle_count,0),
		AESOP_profile_id,
		AESOP_waste_stream

	FROM #waste_info
	where source_id = @source_id
	ORDER BY manifest, manifest_page_num, manifest_line -- rb 02/24/2011 manifest_line_id

	-- open cursor
	OPEN manifest_line
	IF @@ERROR <> 0 
	BEGIN
		RAISERROR('Could not open cursor for manifest summary',16,1)
       	 RETURN
	END

	-- prime for loop
	FETCH NEXT FROM manifest_line
	INTO	@control_id,
        @source,
--rb	@source_id,
    	@source_line,
   		@profit_ctr_id,
   		@manifest,
		@manifest_line_id,
		@manifest_line,
		@manifest_page_num,
		@packing_group,
		@ERG_number,
		@ERG_suffix,
		@waste_code,
		@approval_code,
		@waste_desc,
		@manifest_handling_code,
		@hand_instruct,
		@waste_stream,
		@continuation_flag,
		@manifest_message,
		@empty_bottle_flag,
		@empty_bottle_count_manifest_print_flag,
		@residue_pounds_factor,
		@residue_manifest_print_flag,
		@manifest_actual_wt_flag,
		@manifest_actual_wt,
		@empty_bottle_count,
		@AESOP_profile_id,
		@AESOP_waste_stream

	IF @@FETCH_STATUS <> 0 
	BEGIN
		IF @@FETCH_STATUS = -1 SET @err_msg = 'FETCH statement failed or the row was beyond the result set.'
		IF @@FETCH_STATUS = -2 SET @err_msg = 'Row fetched is missing.'
	
		RAISERROR ( @err_msg, 16, 1)
		RETURN
	END

	SELECT	@hold_page = 1,
		@hold_manifest = @manifest,
		@linecnt = 1,
		@pageno = 1,
		@instructions = ''

	WHILE @@FETCH_STATUS = 0
	BEGIN
		-- rb 03/07/2012 A WorkOrderDetail record with a null manifest, page and line put this into an infinite loop
		IF @manifest is null or @manifest_page_num is null
		BEGIN
			CLOSE manifest_line
			DEALLOCATE manifest_line
			CLOSE c_source_id
			DEALLOCATE c_source_id
			RAISERROR ('Manifest Number or Page Number is NULL...cannot generate manifest summary.', 16, 1)
			RETURN
		END

		WHILE @hold_manifest = @manifest AND @@FETCH_STATUS = 0
		BEGIN
			WHILE @hold_page = @manifest_page_num AND @hold_manifest = @manifest AND @@FETCH_STATUS = 0	--New
			BEGIN
				-- Add approval_code
				SET @instructions = @instructions + @SEPARATOR 
					+ CONVERT(varchar(3),@linecnt) + '. ' 
					+ @approval_code

				-- Add waste_desc
				IF @waste_desc IS NOT NULL AND @waste_desc > ''
				BEGIN
					SET @instructions = @instructions + ' / ' + ISNULL(@waste_desc, '')
				END

				---- Add ERG_number
				--IF ISNULL(@ERG_number, 0) > 0
				--BEGIN
				--	SET @instructions = @instructions + ' / ERG #' + CONVERT(char(3), @ERG_number) + @ERG_suffix
				--END

				-- Add hand_instruct
				IF @hand_instruct IS NOT NULL AND @hand_instruct > ''
				BEGIN
					SET @instructions = @instructions + ' / ' + ISNULL(@hand_instruct, '')
				END 

				-- rb 04/28/2016 GEM:36317 Allow empty bottle approval to print both count and residue
				if @empty_bottle_flag = 'T' and (@empty_bottle_count_manifest_print_flag = 'T' or @residue_manifest_print_flag = 'T') and @empty_bottle_count > 0
				begin
					if @empty_bottle_count_manifest_print_flag = 'T'
						set @instructions = @instructions + ', Bottle Count: ' + convert(varchar(10),@empty_bottle_count)

					if @residue_manifest_print_flag = 'T'
						set @instructions = @instructions + ', Residue lbs: '
								+ convert(varchar(10), Round (convert(numeric(8,4),@empty_bottle_count * @residue_pounds_factor), 4))
				end

				-- rb 05/02/2016 GEM:36318 Print actual weight
				if @manifest_actual_wt_flag = 'T' and @manifest_actual_wt <> 0
				begin
					set @instructions = @instructions + ', Wt: ' +
								+ convert(varchar(10), Round (convert(numeric(10,2),@manifest_actual_wt), 2))
				end
				
				if @AESOP_profile_id IS NOT NULL AND @AESOP_waste_stream IS NOT NULL AND @AESOP_waste_stream > ''
				BEGIN
				   SET @instructions = @instructions + ' / ' + @AESOP_waste_stream + '-' + convert(varchar(5), @AESOP_profile_id)
				END

				SELECT @linecnt = @linecnt + 1
				FETCH NEXT FROM manifest_line
				INTO 	@control_id,
					@source,
--rb					@source_id,
					@source_line,
					@profit_ctr_id,
					@manifest, 
					@manifest_line_id,
					@manifest_line,
					@manifest_page_num,
					@packing_group,
					@ERG_number,
					@ERG_suffix,
					@waste_code,
					@approval_code,
					@waste_desc,   
					@manifest_handling_code,   
					@hand_instruct,
					@waste_stream,
					@continuation_flag,
					@manifest_message,
					@empty_bottle_flag,
					@empty_bottle_count_manifest_print_flag,
					@residue_pounds_factor,
					@residue_manifest_print_flag,
					@manifest_actual_wt_flag,
					@manifest_actual_wt,
					@empty_bottle_count,
					@AESOP_profile_id,
					@AESOP_waste_stream

			END	-- WHILE @hold_page = @pageno AND @hold_manifest = @manifest AND @@fetch_status = 0

	        IF @hold_page > 1 
			BEGIN
				SELECT @continuation_flag = 'T'
			END
			ELSE
			BEGIN
				SELECT @continuation_flag = 'F'
			END

			-- write page summary to #manifest
			INSERT #manifest VALUES ( @control_id,
				@source,
				@source_id,
				NULL,	--@approval_code,
				@profit_ctr_id,
				@hold_page,
				@hold_manifest,
				@continuation_flag,
				LTRIM(@instructions))
                
			IF @@ERROR <> 0 
			BEGIN 
				RAISERROR('Unable to build summary line for manifest',16,1)
				RETURN
			END

			SELECT @hold_page = @manifest_page_num,		-- New
				@instructions = ''

		END	-- WHILE @hold_manifest = @manifest AND @@FETCH_STATUS = 0

		-- new manifest write out summary from previous manifest rest values and continue
		SELECT @hold_page = 1,
		@hold_manifest = @manifest,
		@linecnt = 1,
		@instructions = ''

	END	-- WHILE @@FETCH_STATUS = 0

	-- close cursor
	CLOSE manifest_line
	DEALLOCATE manifest_line


	-- rb 04/10/2009, outer-most loop through source_ids
	fetch next from c_source_id into @source_id
end

close c_source_id
deallocate c_sourcE_id

/* All Profile manifest messages will be appended to Box 14 on Page 1
-- Anitha start
	SELECT @hold_page = MAX(num_pages) 
	FROM #manifest

	SELECT @instructions = handling_instructions 
	FROM #manifest
	WHERE num_pages = @hold_page

	DECLARE c_message_text cursor for
	SELECT Distinct manifest_message
	FROM #waste_info
	WHERE source_id = @source_id
	AND manifest_print_message_flag = 'T'
	 for read only

	OPEN c_message_text
	fetch next from c_message_text into @manifest_message

     while @@FETCH_STATUS = 0

 BEGIN
	-- Hazardous Waste Manifest for section 14
	BEGIN 
	 SET @instructions =  @instructions  + ' / ' + ISNULL(@manifest_message,'') 
	END 
	 fetch next from c_message_text into @manifest_message

		UPDATE #manifest
		SET handling_instructions = LTRIM(@instructions)
		WHERE source_id = @source_id and num_pages = @hold_page 
 END
 
close c_message_text
deallocate c_message_text
--- Anitha end 
*/

-- rb 06/22/2016 Now loop through all pages, and get all messages per page
declare c_message_text cursor read_only forward_only for
select distinct source_id, manifest, num_pages
from #manifest

open c_message_text
fetch c_message_text into @source_id, @manifest, @manifest_page_num

while @@FETCH_STATUS = 0
begin
	SELECT @instructions = handling_instructions 
	FROM #manifest
	WHERE source_id = @source_id
	AND manifest = @manifest
	AND num_pages = @manifest_page_num

	declare c_message_text2 cursor read_only forward_only for
	select distinct ltrim(rtrim(manifest_message))
	from #waste_info
	where source_id = @source_id
	and manifest = @manifest
	and manifest_page_num = @manifest_page_num
	and isnull(ltrim(rtrim(manifest_message)),'') <> ''

	open c_message_text2
	fetch c_message_text2 into @manifest_message

	while @@FETCH_STATUS = 0
	begin
		SET @instructions =  @instructions  + ' / ' + @manifest_message

		fetch c_message_text2 into @manifest_message
	end
	close c_message_text2
	deallocate c_message_text2

	UPDATE #manifest
	SET handling_instructions = LTRIM(@instructions)
	WHERE source_id = @source_id
	and manifest = @manifest
	and num_pages = @manifest_page_num

	fetch c_message_text into @source_id, @manifest, @manifest_page_num
end
close c_message_text
deallocate c_message_text

--rb 04/21/2016 GEM:37151
-- MPM - 7/8/2021 - DevOps 21572 - Added work order and receipt info
-- Sailaja - 09/12/2024 - Rally# US120551 - Include D365 Project on printed manifest when source is WORKORDER
if @ra_source = 'WORKORDER'
begin
	update #manifest
	set handling_instructions = isnull(cast (handling_instructions as varchar(max)),'') 
								+ cast (' ['
								+ CASE WHEN wh.trip_id IS NOT NULL 
									THEN 'T:' + 
									+ right('0' + convert(varchar(2),wh.company_id),2) + '.'
									+ right('0' + convert(varchar(2),wh.profit_ctr_id),2) + '.'
									+ convert(varchar(10),wh.trip_id) + '.'
									+ convert(varchar(10),isnull(wh.trip_sequence_id,0)) + '   '
									ELSE ''
									END
								+ 'W:'
								+ right('0' + convert(varchar(2),wh.company_id),2) + '.'
								+ right('0' + convert(varchar(2),wh.profit_ctr_id),2) + '.'
								+ convert(varchar(12),wh.workorder_id)
								+ ']' as varchar(max))
								+ CASE WHEN (Len(wh.ax_dimension_5_part_1) > 0 AND Len(wh.ax_dimension_5_part_2) > 0) 
									THEN ' [' + wh.ax_dimension_5_part_1 + '-' +  wh.ax_dimension_5_part_2 + ']'
									WHEN Len(wh.ax_dimension_5_part_1) > 0
									THEN ' [' + wh.ax_dimension_5_part_1 + ']'
									ELSE ''
									END
	from #manifest m
	join WorkOrderHeader wh
		on wh.workorder_ID = m.source_id
		and wh.company_id = @company_id
		and wh.profit_ctr_ID = @profit_ctr_id
	where m.source = 'WORKORDER'
	and m.num_pages = 1
end

if @ra_source = 'ORECEIPT'
begin
	update #manifest
	set handling_instructions = isnull(cast (handling_instructions as varchar(max)),'') 
								+ cast (' [OB:'
								+ right('0' + convert(varchar(2),r.company_id),2) + '.'
								+ right('0' + convert(varchar(2),r.profit_ctr_id),2) + '.'
								+ convert(varchar(12),r.receipt_id)
								+ ']' as varchar(max))
	from #manifest m
	join Receipt r
		on r.receipt_ID = m.source_id
		and r.company_id = @company_id
		and r.profit_ctr_ID = @profit_ctr_id
	where m.source = 'ORECEIPT'
	and m.num_pages = 1
end

if @ra_source = 'IRECEIPT'
begin
	update #manifest
	set handling_instructions = isnull(cast (handling_instructions as varchar(max)),'') 
								+ cast (' ['
								+ CASE WHEN rh.trip_id IS NOT NULL 
									THEN 'T:' + 
									+ right('0' + convert(varchar(2),th.company_id),2) + '.'
									+ right('0' + convert(varchar(2),th.profit_ctr_id),2) + '.'
									+ convert(varchar(10),rh.trip_id) + '.'
									+ convert(varchar(10),isnull(rh.trip_sequence_id,0)) + '   '
									ELSE ''
									END
								+ 'IB:'
								+ right('0' + convert(varchar(2),rh.company_id),2) + '.'
								+ right('0' + convert(varchar(2),rh.profit_ctr_id),2) + '.'
								+ convert(varchar(12),rh.receipt_id)
								+ ']' as varchar(max))
	from #manifest m
	join ReceiptHeader rh
		on rh.receipt_ID = m.source_id
		and rh.company_id = @company_id
		and rh.profit_ctr_ID = @profit_ctr_id
	left outer join TripHeader th
		on th.trip_id = rh.trip_id
	where m.source = 'IRECEIPT'
	and m.num_pages = 1
end

-- MPM - GEM 51165 - Changes for inbound receipt rejection manifest
if @ra_source = 'IRECEIPT' AND @rejection_manifest_flag = 'T'
begin
	update #manifest
	   set handling_instructions = cast('Rejected due to non-conforming wastes per ' + rd.rejection_contact_name as varchar(max))
	  from #manifest m
	  join ReceiptDiscrepancy rd
	    on rd.receipt_ID = m.source_id
	   and rd.company_id = @company_id
	   and rd.profit_ctr_ID = @profit_ctr_id	 
     where m.source = 'IRECEIPT'
       and LEN(rd.rejection_contact_name) > 0
end

-- dump table
SET NOCOUNT OFF

SELECT	control_id,
	source,
	source_id,
	source_code,
	profit_center,
	num_pages,
	manifest,
	continuation_flag,
	handling_instructions
FROM #manifest
ORDER BY manifest
GO

GRANT EXECUTE
    ON OBJECT::[dbo].[sp_get_manifest_summary_uniform] TO [EQWEB];
GO

GRANT EXECUTE
    ON OBJECT::[dbo].[sp_get_manifest_summary_uniform] TO [COR_USER];
GO

GRANT EXECUTE
    ON OBJECT::[dbo].[sp_get_manifest_summary_uniform] TO [EQAI];
GO
