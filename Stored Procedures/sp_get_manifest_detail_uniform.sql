DROP PROCEDURE IF EXISTS sp_get_manifest_detail_uniform
GO

CREATE PROCEDURE sp_get_manifest_detail_uniform
	@ra_source		varchar(20), 
	@ra_list		varchar(2000),
	@profit_center	int,
	@company_id		int,
	@generator_id	int = 0,
	@rejection_manifest_flag	char(1)
WITH RECOMPILE
AS
/***************************************************************************************
Returns manifest information for the manifest window
Requires: none
Loads on PLT_XX_AI

06/26/2006 RG	created
08/01/2006 SCC	Modified to pull shipping info from the WorkOrder disposal record, if it exists
09/03/2006 MK	Modified to check for line < 11 on workorderdetail
09/18/2006 RG	Modified to remove tsdfapproval.bill_unit_code
10/11/2006 RG	removed test for list_id greater than zero.
11/01/2006 RG	truncated dot shipping name to avoid datawindow error
06/16/2008 KAM	Updated to use the new fields that are being stored in the receipt table.
08/01/2008 KAM	Updated to use manifest_container_code from the Receipt table.
02/04/2009 RWB	Added TRIP source
03/09/2009 JPB	Added SET NOCOUNT ON (and off)
03/09/2009 RWB	Added trip_sequence_id to result set
04/06/2009 RWB  Added coalesce for WORKORDERDETAIL quantity field
04/08/2009 RWB  Added coalesce for WORKORDERDETAIL unit field
04/09/2009 RWB  Corrected the fix on 04/08/2009 to use BillUnit.manifest_unit instead of bill_unit_code in the coalesce
04/14/2009 RWB  Retrieve all TSDF approvals, regardless of status
04/28/2009 KAM	Cases the waste_code of NONE to '' so it would not display or print.
05/08/2009 JDB	Corrected change from 4/9/09 to NOT use the manifest_unit from the BillUnit table.
05/11/2009 JDB	Added ERG_suffix
08/12/2009 RWB  Exclude void WorkOrderDetail records with bill_rate = -2
10/13/2009 KAM  Added the retrieve of manifest_dot_sp_number
01/21/2010 JDB	Removed "AND WorkOrderDetail.profile_id IS NULL" when selecting lines from non-EQ TSDFs
09/01/2010 RWB	Integration of WorkOrderDetailUnit table, removed unused outer join to BillUnit table
02/23/2011 RWB  Need to round WorkOrderDetailUnit.quantity, can contain decimals
03/17/2011 RWB  Round Receipt quantity values as well
08/15/2013 RWB	Moved to Plt_ai, added company_id to jois, added check for Profile RQ Threshold
09/09/2013 RWB	Added empty bottle flags and factors to temp table and result set
04/07/2014 AM	Added display_name Instead of waste_code.
11/13/2014 SM	Modified rq_reportable_flag from status M to T
12/08/2014 RWB	Suddenly started lots of blocking, added SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
08/19/2015 SK	Added dot_sp_permit_text, print_dot_sp_flag
08/21/2015 SK	Added DOT_shipping_desc_label
08/24/2015 RWB	Added new function to determine default label type. Added optional @generator_id argument
                to support various generator selection from the Profile screen
06/22/2016 RWB	GEM:37001 RQ flag, threshold etc. is only looking at Profile/TSDFApproval...should coalesce WorkOrderDetail
08/12/2016 SK	Increased dot_sp_permit_text length to 255
03/26/2018 AM   Modified to get Treatmentdetail.management_code instead of Treatment.management_code
06/25/2018 MPM	GEM 51165 - Added @rejection_manifest_flag input parameter and associated logic.
06/17/2020 MPM	DevOps 16164, 16166, 16167 - Added DOT_waste_flag and DOT_shipping_desc_additional columns to result set.
11/16/2020 MPM	DevOps 17650/17651 - Modified the value returned for reportable_quantity_flag for work orders, and added
				RQ_threshold and BillUnit.pound_conv to the result set.
03/25/2022 MPM	DevOps 30390 - Added new column ManifestPrintDetail.class_7_additional_desc to the result set.
07/12/2023 MPM	DevOps 64576 - Modified for change to ManifestPrintDetail.manifest_line from CHAR(2) to CHAR(3).
09/06/2023 MPM	DevOps 64576 - Added trip_sequence_id to the "fill manifest" logic.

sp_get_manifest_detail_uniform 'TSDFAPPR', '21977',0,21, 0, 'F'
sp_get_manifest_detail_uniform 'WORKORDER', '26721100',6,14, 0, 'F'
sp_get_manifest_detail_uniform 'PROFILE', '343474',0,21, 0,'F'
sp_get_manifest_detail_uniform 'IRECEIPT', '31399',0,22, 0, 'F'
sp_get_manifest_detail_uniform 'ORECEIPT', 173552, 0, 12, 0, 'F'
exec sp_get_manifest_detail_uniform 'IRECEIPT', '29601', 1, 21, 0, 'T'
exec sp_get_manifest_detail_uniform 'IRECEIPT', '29601', 1, 21, 0, 'F'
exec sp_get_manifest_detail_uniform 'ORECEIPT', '2083118', 0, 21, 0, 'F'
****************************************************************************************/
SET NOCOUNT ON

DECLARE  @more_rows int,
         @list_id int,
         @start int,
         @end int,
         @lnth int,
		 @trip_sequence_id int
         
CREATE TABLE #source_list (
	source_id int null	)

CREATE TABLE #manifest (
	control_id int null,
	source varchar(10) null,
	source_id int null,
	trip_sequence_id int null,
	source_line int null,
	profit_center int null,
	manifest varchar(15) null, 
	manifest_line_id char(2) null,
	manifest_line char(3) null,
	manifest_page_num int null,
	DOT_shipping_desc char(1) null,
	additional_desc char(1) null,
	handling_additional_info char(1) null,
	DOT_shipping_name varchar(255) null,   
	hazmat_flag char(1) null,   
	hazmat_class varchar(15) null,   
	UN_NA_flag char(2) null,
	UN_NA_number int null,   
	packing_group varchar(3) null,
	ERG_number int null,
	ERG_suffix char(2) null,
	container_count float null,
	container_code varchar(15) null,
	quantity float null,
	manifest_wt_vol_unit varchar(15) null,   
	waste_code varchar(10) null,   -- Anitha changed from 4 to 10
	approval_code varchar(40) null,   
	secondary_waste_code varchar(50) null,   
	waste_desc varchar(50) null,   
	manifest_handling_code varchar(15) null,   
	hand_instruct varchar(255) null,
	generator_id int null,   
	tsdf_code varchar(15) null,   
	waste_stream varchar(20) null,
	expiration_date datetime null,
	continuation_flag char(1) null,   
	reportable_quantity_flag char(1) null,   
	RQ_reason varchar(50) null,
	sub_hazmat_class varchar(15) null,
	management_code varchar(4) null, 
	manifest_dot_sp_number varchar(20) Null,
	empty_bottle_flag char(1) null,
	residue_pounds_factor float null,
	residue_manifest_print_flag char(1) null,
	empty_bottle_count int null,
	dot_sp_permit_text	char(255)	null,
	print_dot_sp_flag	char(1)		Null,
	DOT_shipping_desc_label	varchar(max) NULL,
	default_label_type char(1) null,
	DOT_waste_flag char(1) null,
	DOT_shipping_desc_additional varchar(255) null,
	RQ_threshold int null,
	pound_conv float null,
	class_7_additional_desc varchar(100) null
)

SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

IF @rejection_manifest_flag IS NULL 
	SET @rejection_manifest_flag = 'F'
	
-- decode the source list for retirieval
-- load the source list table
IF LEN(@ra_list) > 0
BEGIN
	SELECT	@more_rows = 1,
		@start = 1
	WHILE @more_rows = 1
	BEGIN
		SELECT @end = CHARINDEX(',',@ra_list,@start)
		IF @end > 0 
		BEGIN
			SELECT @lnth = @end - @start
		  	SELECT @list_id = CONVERT(int,SUBSTRING(@ra_list,@start,@lnth))
			SELECT @start = @end + 1
			INSERT INTO #source_list VALUES (@list_id)
		END
		ELSE 
		BEGIN
			SELECT @lnth = LEN(@ra_list)
			SELECT @list_id = CONVERT(int,SUBSTRING(@ra_list,@start,@lnth))
			SELECT @more_rows = 0
			INSERT INTO #source_list VALUES (@list_id)
		END
	END
END

-- determine the source; each source has its own query
-- out bound Receipts
IF @ra_source = 'ORECEIPT'
BEGIN
	INSERT #manifest
	SELECT	0 AS print_control_id,   
		CONVERT(varchar(10), @ra_source) AS source, 
		Receipt.receipt_id AS source_id,   
		CONVERT(INT,NULL) AS trip_sequence_id,
		Receipt.line_id AS source_line_id,
		Receipt.profit_ctr_id,  
		ISNULL(Receipt.manifest, ''),
		Receipt.manifest_line_id,
		Right('000'+ Cast(Receipt.manifest_line as Varchar(3)),3)as manifest_line,
		Receipt.manifest_page_num,
		'' AS DOT_shipping_desc,
		'' AS additional_desc,
		'' AS handling_additional_info,
		Cast(Receipt.manifest_DOT_shipping_name as Varchar(255)) as dot_shipping_name,   
		Receipt.manifest_hazmat AS hazmat_flag,   
		Receipt.manifest_hazmat_class,   
		Receipt.manifest_UN_NA_flag,   
		Receipt.manifest_UN_NA_number,   
		Receipt.manifest_package_group AS packing_group,   
		Receipt.manifest_ERG_number,
		Receipt.manifest_ERG_suffix,
		Receipt.container_count,
		Receipt.manifest_container_code AS container_code,
		case when isnull(Receipt.manifest_quantity,0) > 0 and isnull(Receipt.manifest_quantity,0) < 1 then 1
			else ROUND(Receipt.manifest_quantity,0) end,
		Receipt.manifest_unit,   
		--Receipt.waste_code, 
		ISNULL((  select wastecode.display_name from wastecode where wastecode.waste_code_uid = receipt.waste_code_uid ),'NONE') as  waste_code, 
		ProfileQuoteApproval.approval_code AS approval_code,   
		CONVERT(varchar(50), '') AS secondary_waste_code,   
		COALESCE(Profile.manifest_waste_desc, Profile.approval_desc),
		Profile.manifest_handling_code,   
		Profile.manifest_hand_instruct,
		Receipt.generator_id AS generator_id,
		Receipt.TSDF_code AS tsdf_code,   
		'' AS waste_stream,
		Profile.ap_expiration_date AS expiration_date,
		Receipt.continuation_flag AS continuation_flag,   
		Receipt.manifest_rq_flag AS reportable_quantity_flag,   
		Receipt.manifest_rq_reason  AS RQ_reason,
		Receipt.manifest_sub_hazmat_class as sub_hazmat_class,
		Receipt.manifest_management_code as management_code,
		Receipt.manifest_dot_sp_number as manifest_dot_sp_number,
		Profile.empty_bottle_flag,
		Profile.residue_pounds_factor,
		Profile.residue_manifest_print_flag,
		(select round(isnull(sum(isnull(merchandise_quantity,0)),0),4)
				from ReceiptDetailItem
				where company_id = Receipt.company_id
				and profit_ctr_id = Receipt.profit_ctr_id
				and receipt_id = Receipt.receipt_id
				and line_id = Receipt.line_id
				and item_type_ind = 'ME')
		, Profile.dot_sp_permit_text
		, ProfileQuoteApproval.print_dot_sp_flag
		, '' AS DOT_shipping_desc_label
		, dbo.fn_get_label_default_type ('R', Receipt.receipt_id, Receipt.company_id, Receipt.profit_ctr_id, Receipt.line_id, 0)
		, Receipt.DOT_waste_flag 
		, Receipt.DOT_shipping_desc_additional 
		, Profile.RQ_threshold
		, BillUnit.pound_conv 
		, NULL AS class_7_additional_desc
	FROM Receipt
	JOIN ProfileQuoteApproval
		ON Receipt.OB_profile_id = ProfileQuoteApproval.profile_id
		AND Receipt.OB_profile_profit_ctr_ID = ProfileQuoteApproval.profit_ctr_ID
		AND Receipt.OB_profile_company_id = ProfileQuoteApproval.company_id
	JOIN Profile
		ON Profile.profile_id = ProfileQuoteApproval.profile_id
		AND Profile.curr_status_code = 'A'
	LEFT OUTER JOIN BillUnit
		ON BillUnit.manifest_unit = Receipt.manifest_unit
	WHERE Receipt.trans_mode = 'O'  
	AND Receipt.trans_type = 'D'  
	AND Receipt.manifest_flag IN ('M','C')
	AND Receipt.receipt_status IN ('N','L','U','A')  
	AND Receipt.receipt_ID IN ( SELECT source_id FROM #source_list )
	AND Receipt.profit_ctr_ID = @profit_center
	AND Receipt.company_ID = @company_id
UNION
	SELECT 0 AS print_control_id,   
		CONVERT(varchar(10), @ra_source) AS source, 
		Receipt.receipt_id AS source_id,   
		CONVERT(INT,NULL) AS trip_sequence_id,
		Receipt.line_id AS source_line_id,
		Receipt.profit_ctr_id,  
		ISNULL(Receipt.manifest, ''),
		Receipt.manifest_line_id,
		Right('000'+ Cast(Receipt.manifest_line as Varchar(3)),3)as manifest_line,
		Receipt.manifest_page_num,
		'' AS DOT_shipping_desc,
		'' AS additional_desc,
		'' AS handling_additional_info,
		cast(Receipt.manifest_DOT_shipping_name as varchar(255)) as dot_shipping_name,   
		Receipt.manifest_hazmat AS hazmat_flag,   
		Receipt.manifest_hazmat_class,   
		Receipt.manifest_UN_NA_flag,   
		Receipt.manifest_UN_NA_number,   
		Receipt.manifest_package_group AS packing_group,   
		Receipt.manifest_ERG_number,
		Receipt.manifest_ERG_suffix,
		Receipt.container_count,
		Receipt.manifest_container_code AS container_code,
		case when isnull(Receipt.manifest_quantity,0) > 0 and isnull(Receipt.manifest_quantity,0) < 1 then 1
			else ROUND(Receipt.manifest_quantity,0) end,
		Receipt.manifest_unit,   
		--Receipt.waste_code,   
		ISNULL((  select wastecode.display_name from wastecode where wastecode.waste_code_uid = receipt.waste_code_uid ),'NONE') as  waste_code, 
		Receipt.TSDF_approval_code AS approval_code,   
		CONVERT(varchar(50), '') AS secondary_waste_code, 
		TSDFapproval.waste_desc,   
		TSDFapproval.manifest_handling_code,   
		TSDFapproval.hand_instruct,
		Receipt.generator_id AS generator_id,
		TSDFapproval.TSDF_code AS tsdf_code,   
		TSDFapproval.waste_stream AS waste_stream,
		TSDFapproval.TSDF_approval_expire_date AS expiration_date,
		Receipt.continuation_flag AS continuation_flag,   
		Receipt.manifest_rq_flag AS reportable_quantity_flag,   
		Receipt.manifest_RQ_reason AS RQ_reason,
		Receipt.manifest_sub_hazmat_class as sub_hazmat_class,
		Receipt.manifest_management_code as management_code,
		Receipt.manifest_dot_sp_number as manifest_dot_sp_number,
		TSDFApproval.empty_bottle_flag,
		TSDFApproval.residue_pounds_factor,
		TSDFApproval.residue_manifest_print_flag,
		(select round(isnull(sum(isnull(merchandise_quantity,0)),0),4)
				from ReceiptDetailItem
				where company_id = Receipt.company_id
				and profit_ctr_id = Receipt.profit_ctr_id
				and receipt_id = Receipt.receipt_id
				and line_id = Receipt.line_id
				and item_type_ind = 'ME')
		, TSDFApproval.dot_sp_permit_text
		, TSDFApproval.print_dot_sp_flag
		, '' AS DOT_shipping_desc_label
		, dbo.fn_get_label_default_type ('R', Receipt.receipt_id, Receipt.company_id, Receipt.profit_ctr_id, Receipt.line_id, 0)
		, Receipt.DOT_waste_flag 
		, Receipt.DOT_shipping_desc_additional 
		, TSDFApproval.RQ_threshold
		, BillUnit.pound_conv 
		, NULL AS class_7_additional_desc
	FROM Receipt
	JOIN TSDFapproval 
		ON Receipt.TSDF_approval_id = TSDFapproval.TSDF_approval_id
		AND Receipt.profit_ctr_ID = TSDFapproval.profit_ctr_ID
		AND Receipt.company_id = TSDFApproval.company_id
	LEFT OUTER JOIN BillUnit
		ON BillUnit.manifest_unit = Receipt.manifest_unit
WHERE Receipt.trans_mode = 'O'  
	AND Receipt.trans_type = 'D'  
	AND Receipt.manifest_flag IN ('M','C')
	AND Receipt.receipt_status IN ('N','L','U','A')  
	AND Receipt.profile_id IS NULL 
	AND Receipt.receipt_ID IN ( SELECT source_id FROM #source_list )
	AND Receipt.profit_ctr_ID = @profit_center
	AND Receipt.company_ID = @company_id

	GOTO end_process
END


-- Inbound Receipts
IF @ra_source = 'IRECEIPT'
BEGIN
	INSERT #manifest
  	SELECT 0 AS print_control_id,   
		CONVERT(varchar(10), @ra_source) AS source, 
		Receipt.receipt_id AS source_id,   
		CONVERT(INT,NULL) AS trip_sequence_id,
		Receipt.line_id AS source_line_id,
		Receipt.profit_ctr_id,  
		Receipt.manifest, 
		Receipt.manifest_line_id,
		Right('000'+ Cast(Receipt.manifest_line as Varchar(3)),3)as manifest_line,
		Receipt.manifest_page_num,
		'' AS DOT_shipping_desc,
		'' AS additional_desc,
		'' AS handling_additional_info,
		cast(Receipt.manifest_DOT_shipping_name as Varchar(255)) AS dot_shipping_name,   
		Receipt.manifest_hazmat AS hazmat_flag,   
		Receipt.manifest_hazmat_class,   
		Receipt.manifest_UN_NA_flag,   
		Receipt.manifest_UN_NA_number,   
		Receipt.manifest_package_group AS packing_group,   
		Receipt.manifest_ERG_number,
		Receipt.manifest_ERG_suffix,
		Receipt.container_count,
		Receipt.manifest_container_code AS container_code,
		case when isnull(Receipt.manifest_quantity,0) > 0 and isnull(Receipt.manifest_quantity,0) < 1 then 1
			else ROUND(Receipt.manifest_quantity,0) end,
		Receipt.manifest_unit,   
		--Receipt.waste_code,   
		ISNULL((  select wastecode.display_name from wastecode where wastecode.waste_code_uid = receipt.waste_code_uid ),'NONE') as  waste_code, 
		ProfileQuoteApproval.approval_code AS approval_code,   
		CONVERT(varchar(50), '') AS secondary_waste_code,   
		Profile.approval_desc as waste_desc,   
		Profile.manifest_handling_code,   
		Profile.manifest_hand_instruct,
		CASE @rejection_manifest_flag 
			WHEN 'T' THEN 1 -- N/A generator
			ELSE Receipt.generator_id 
		END AS generator_id,
		Receipt.TSDF_code AS tsdf_code,   
		'' AS waste_stream,
		Profile.ap_expiration_date AS expiration_date,
		Receipt.continuation_flag AS continuation_flag,   
		Receipt.manifest_rq_flag AS reportable_quantity_flag,   
		Receipt.manifest_RQ_reason  AS RQ_reason,
		Receipt.manifest_sub_hazmat_class AS sub_hazmat_class,
		Receipt.manifest_management_code AS management_code,
		Receipt.manifest_dot_sp_number as manifest_dot_sp_number,
		Profile.empty_bottle_flag,
		Profile.residue_pounds_factor,
		Profile.residue_manifest_print_flag,
		(select round(isnull(sum(isnull(merchandise_quantity,0)),0),4)
				from ReceiptDetailItem
				where company_id = Receipt.company_id
				and profit_ctr_id = Receipt.profit_ctr_id
				and receipt_id = Receipt.receipt_id
				and line_id = Receipt.line_id
				and item_type_ind = 'ME')
		, Profile.dot_sp_permit_text
		, ProfileQuoteApproval.print_dot_sp_flag
		, '' AS DOT_shipping_desc_label
		, dbo.fn_get_label_default_type ('R', Receipt.receipt_id, Receipt.company_id, Receipt.profit_ctr_id, Receipt.line_id, 0)
		, Receipt.DOT_waste_flag 
		, Receipt.DOT_shipping_desc_additional 
		, Profile.RQ_threshold
		, BillUnit.pound_conv 
		, NULL AS class_7_additional_desc
	FROM Receipt
	INNER JOIN ProfileQuoteApproval ON (Receipt.profile_id = ProfileQuoteApproval.profile_id
		AND Receipt.profit_ctr_ID = ProfileQuoteApproval.profit_ctr_ID
		AND Receipt.company_id = ProfileQuoteApproval.company_id)
	INNER JOIN Profile ON Profile.profile_id = ProfileQuoteApproval.profile_id
--	INNER JOIN TreatmentAll ON (ProfileQuoteApproval.treatment_id = TreatmentAll.treatment_id
--		AND ProfileQuoteApproval.profit_ctr_id = TreatmentAll.profit_ctr_id
--		AND ProfileQuoteApproval.company_id = TreatmentAll.company_id)
	LEFT OUTER JOIN BillUnit
		ON BillUnit.manifest_unit = Receipt.manifest_unit
	WHERE Receipt.profit_ctr_ID = @profit_center
	AND Receipt.company_ID = @company_id
	AND Receipt.receipt_ID IN ( SELECT source_id FROM #source_list )
	AND Receipt.trans_mode = 'I'  
	AND Receipt.trans_type = 'D'  
	AND Receipt.manifest_flag IN ('M','C')
	AND ((Receipt.receipt_status IN ('N','L','U','A') AND @rejection_manifest_flag = 'F') OR 
	     (Receipt.fingerpr_status = 'R' AND @rejection_manifest_flag = 'T'))
	AND Profile.curr_status_code = 'A'

	GOTO end_process
END

-- workorders
IF @ra_source = 'WORKORDER'
BEGIN
	INSERT #manifest	
	SELECT 0 AS print_control_id,   
		-- rb, trip
		case when WorkOrderHeader.workorder_id <= -1000 then convert(varchar(10),'TRIP ' + convert(varchar(5),WorkOrderHeader.trip_id)) else CONVERT(varchar(10), @ra_source) end AS source, 
		WorkOrderHeader.workorder_id,
		WorkOrderHeader.trip_sequence_id as trip_sequence_id,
		Workorderdetail.sequence_id AS source_line_id,
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
		'' AS DOT_shipping_desc,
		'' AS additional_desc,
		'' AS handling_additional_info,
		left(COALESCE(WorkOrderDetail.DOT_shipping_name, Profile.DOT_shipping_name),255) as dot_shipping_name,  
		COALESCE(WorkOrderDetail.hazmat, Profile.hazmat) AS hazmat_flag,   
		COALESCE(WorkOrderDetail.hazmat_class, Profile.hazmat_class),   
		CASE WHEN COALESCE(WorkOrderDetail.UN_NA_flag, Profile.UN_NA_flag) = 'X' THEN ''
			ELSE COALESCE(WorkOrderDetail.UN_NA_flag, Profile.UN_NA_flag)
			END AS UN_NA_flag,
		COALESCE(WorkOrderDetail.UN_NA_number, Profile.UN_NA_number),   
		COALESCE(WorkOrderDetail.package_group, Profile.package_group) AS packing_group,   
		COALESCE(WorkOrderDetail.ERG_number, Profile.ERG_number),
		COALESCE(WorkOrderDetail.ERG_suffix, Profile.ERG_suffix),
		WorkOrderDetail.container_count,
		WorkOrderDetail.container_code AS container_code,
-- rb 09/01/2010 WorkOrderDetiailUnit table
--		COALESCE(WorkOrderDetail.manifest_quantity,WorkOrderDetail.quantity_used), -- rb 04/06/2009
-- rb 02/23/2011 need to round quantity since it can contain decimals
--		COALESCE(WorkOrderDetailUnit.quantity,WorkOrderDetail.quantity_used),
		case when isnull(COALESCE(WorkOrderDetailUnit.quantity,WorkOrderDetail.quantity_used),0) > 0 and
 		               isnull(COALESCE(WorkOrderDetailUnit.quantity,WorkOrderDetail.quantity_used),0) < 1 then 1
			else ROUND(COALESCE(WorkOrderDetailUnit.quantity,WorkOrderDetail.quantity_used),0) end,
		ISNULL(BillUnit.manifest_unit, '') AS manifest_unit,
		--COALESCE(NULL, Profile.waste_code),   
		COALESCE(NULL,(  select wastecode.display_name from wastecode where wastecode.waste_code_uid = profile.waste_code_uid ) ) as  waste_code, 
		COALESCE(WorkOrderDetail.TSDF_approval_code,ProfileQuoteApproval.approval_code) AS approval_code,   
		CONVERT(varchar(50), '') AS secondary_waste_code,   
		COALESCE(WorkOrderDetail.manifest_waste_desc,COALESCE(Profile.manifest_waste_desc, Profile.approval_desc)),   
		COALESCE(WorkOrderDetail.manifest_handling_code, Profile.manifest_handling_code),   
		COALESCE(WorkOrderDetail.manifest_hand_instruct, Profile.manifest_hand_instruct),
		WorkOrderHeader.generator_id AS generator_id,   
		WorkorderDetail.TSDF_code AS tsdf_code,   
		'' AS waste_stream,
		Profile.ap_expiration_date AS expiration_date,
		WorkOrderManifest.continuation_flag AS continuation_flag,
-- rb 08/15/2013 RQ Threshold on Profile definitition
		COALESCE(WorkOrderDetail.reportable_quantity_flag, Profile.reportable_quantity_flag) AS reportable_quantity_flag,   
--		case when COALESCE(WorkOrderDetail.reportable_quantity_flag,Profile.reportable_quantity_flag) = 'T' and
--					(isnull(Profile.rq_threshold,0) = 0 or isnull(WorkOrderDetailUnit.quantity,0) > isnull(Profile.rq_threshold,0)) then 'T' else 'F' end AS reportable_quantity_flag,   
		COALESCE(WorkOrderDetail.RQ_reason, Profile.Rq_reason) AS RQ_reason,
		COALESCE(WorkOrderDetail.subsidiary_haz_mat_class, Profile.subsidiary_haz_mat_class) AS sub_hazmat_class,
		COALESCE(WorkOrderDetail.management_code,Treatmentdetail.management_code) AS management_code,
		WorkOrderDetail.manifest_dot_sp_number,
		isnull(Profile.empty_bottle_flag,'F'),
		isnull(Profile.residue_pounds_factor,0),
		isnull(Profile.residue_manifest_print_flag,'F'),
		(select round(isnull(sum(isnull(merchandise_quantity,0)),0),4)
				from WorkOrderDetailItem
				where workorder_id = WorkOrderDetail.workorder_id
				and company_id = WorkOrderDetail.company_id
				and profit_ctr_id = WorkOrderDetail.profit_ctr_id
				and sequence_id = WorkOrderDetail.sequence_id
				and item_type_ind = 'ME')
		, Profile.dot_sp_permit_text
		, ProfileQuoteApproval.print_dot_sp_flag
		, '' AS DOT_shipping_desc_label
		, dbo.fn_get_label_default_type ('W', WorkOrderDetail.workorder_id, WorkOrderDetail.company_id, WorkOrderDetail.profit_ctr_id, WorkOrderDetail.sequence_id, 0)
		, COALESCE(WorkOrderDetail.DOT_waste_flag, Profile.DOT_waste_flag) AS DOT_waste_flag
		, COALESCE(WorkOrderDetail.DOT_shipping_desc_additional, Profile.DOT_shipping_desc_additional) AS DOT_shipping_desc_additional
		, Profile.RQ_threshold
		, BillUnit.pound_conv 
		, WorkOrderDetail.class_7_additional_desc
	FROM WorkOrderDetail join ProfileQuoteApproval on WorkOrderDetail.profile_id = ProfileQuoteApproval.profile_id
			AND ProfileQuoteApproval.company_id = WorkorderDetail.profile_company_id
			AND ProfileQuoteApproval.profit_ctr_id = WorkorderDetail.profile_profit_ctr_id
		Join Profile on Profile.profile_id = ProfileQuoteApproval.profile_id
		Join WorkOrderHeader on WorkOrderDetail.workorder_ID = WorkOrderHeader.workorder_ID  
			AND WorkOrderDetail.company_id = WorkOrderHeader.company_id
			AND WorkOrderDetail.profit_ctr_ID = WorkOrderHeader.profit_ctr_ID 
		Join WorkOrderManifest on WorkOrderDetail.workorder_ID = WorkOrderManifest.workorder_ID
			AND WorkOrderDetail.company_ID = WorkOrderManifest.company_ID
			AND WorkOrderDetail.profit_ctr_ID = WorkOrderManifest.profit_ctr_ID
			AND WorkOrderDetail.manifest = WorkOrderManifest.manifest
		Join Treatment on ProfileQuoteApproval.treatment_id = Treatment.treatment_id
			AND ProfileQuoteApproval.profit_ctr_id = Treatment.profit_ctr_id
			AND ProfileQuoteApproval.company_id = Treatment.company_id
		Join Treatmentdetail on ProfileQuoteApproval.treatment_id = Treatmentdetail.treatment_id
			AND ProfileQuoteApproval.profit_ctr_id = Treatmentdetail.profit_ctr_id
			AND ProfileQuoteApproval.company_id = Treatmentdetail.company_id
		Join TSDF on WorkOrderDetail.TSDF_code = TSDF.TSDF_code
			AND TSDF.EQ_flag = 'T'
		Left Outer Join WorkOrderDetailUnit on WorkOrderDetailUnit.workorder_ID = WorkOrderDetail.workorder_ID  
			AND WorkOrderDetailUnit.company_ID = WorkOrderDetail.company_ID  
			AND WorkOrderDetailUnit.profit_ctr_ID = WorkOrderDetail.profit_ctr_ID
			AND WorkOrderDetailUnit.sequence_ID = WorkOrderDetail.sequence_ID
			AND WorkOrderDetailUnit.manifest_flag = 'T'
		Left outer Join BillUnit on WorkorderDetailUnit.bill_unit_code = BillUnit.bill_unit_code
	WHERE WorkOrderDetail.Resource_type = 'D'
	AND Profile.curr_status_code = 'A'
	AND WorkOrderManifest.manifest_flag = 'T'
	AND WorkOrderDetail.workorder_ID IN ( SELECT source_id FROM #source_list )
	AND WorkOrderDetail.profit_ctr_ID = @profit_center
	AND WorkOrderDetail.company_ID = @company_id
	AND WorkOrderDetail.bill_rate <> -2 -- rb 08/12/2009
UNION
	SELECT 0 AS print_control_id,   
		-- rb, trip
		case when WorkOrderHeader.workorder_id <= -1000 then convert(varchar(10),'TRIP ' + convert(varchar(5),WorkOrderHeader.trip_id)) else CONVERT(varchar(10), @ra_source) end AS source, 
		WorkOrderHeader.workorder_id,
		WorkOrderHeader.trip_sequence_id as trip_sequence_id,
		WorkorderDetail.sequence_id AS source_line_id,
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
		'' AS DOT_shipping_desc,
		'' AS additional_desc,
		'' AS handling_additional_info,
		LEFT(COALESCE(WorkOrderDetail.DOT_shipping_name, TSDFapproval.DOT_shipping_name),255) AS dot_shipping_name,   
		COALESCE(WorkOrderDetail.hazmat, TSDFapproval.hazmat) AS hazmat_flag,   
		COALESCE(WorkOrderDetail.hazmat_class, TSDFapproval.hazmat_class),   
		CASE WHEN COALESCE(WorkOrderDetail.UN_NA_flag,TSDFapproval.UN_NA_flag) = 'X' THEN ''
			ELSE COALESCE(WorkOrderDetail.UN_NA_flag, TSDFApproval.UN_NA_flag)
			END AS UN_NA_flag,
		COALESCE(WorkOrderDetail.UN_NA_number, TSDFapproval.UN_NA_number),   
		COALESCE(WorkOrderDetail.package_group,TSDFapproval.package_group) AS packing_group,   
		COALESCE(WorkOrderDetail.ERG_number, TSDFapproval.ERG_number),   
		COALESCE(WorkOrderDetail.ERG_suffix, TSDFapproval.ERG_suffix),
		WorkOrderDetail.container_count,
		WorkOrderDetail.container_code AS container_code,
-- rb 09/01/2010 WorkOrderDetiailUnit table
--		COALESCE(WorkOrderDetail.manifest_quantity,WorkOrderDetail.quantity_used), -- rb 04/06/2009
-- rb 02/23/2011 need to round quantity since it can contain decimals
--		COALESCE(WorkOrderDetailUnit.quantity,WorkOrderDetail.quantity_used),
		case when isnull(COALESCE(WorkOrderDetailUnit.quantity,WorkOrderDetail.quantity_used),0) > 0 and
 		               isnull(COALESCE(WorkOrderDetailUnit.quantity,WorkOrderDetail.quantity_used),0) < 1 then 1
			else ROUND(COALESCE(WorkOrderDetailUnit.quantity,WorkOrderDetail.quantity_used),0) end,
		ISNULL(BillUnit.manifest_unit, '') AS manifest_unit,
		--COALESCE(NULL, TSDFapproval.waste_code),   
		COALESCE(NULL,(  select wastecode.display_name from wastecode where wastecode.waste_code_uid = TSDFapproval.waste_code_uid )) as  waste_code, 
		WorkOrderDetail.TSDF_approval_code AS approval_code,   
		CONVERT(varchar(50), '') AS secondary_waste_code,   
		COALESCE(WorkOrderDetail.manifest_waste_desc, TSDFapproval.waste_desc),   
		COALESCE(WorkOrderDetail.manifest_handling_code, TSDFapproval.manifest_handling_code),   
		COALESCE(WorkOrderDetail.manifest_hand_instruct, TSDFapproval.hand_instruct),
		WorkOrderHeader.generator_id AS generator_id,   
		TSDFapproval.TSDF_code AS tsdf_code,   
		TSDFapproval.waste_stream AS waste_stream,
		TSDFapproval.TSDF_approval_expire_date AS expiration_date,
		WorkOrderManifest.continuation_flag AS continuation_flag,
		COALESCE(WorkOrderDetail.reportable_quantity_flag, TSDFapproval.reportable_quantity_flag) AS reportable_quantity_flag,   
		COALESCE(WorkOrderDetail.RQ_reason, TSDFapproval.RQ_reason) AS RQ_reason,
		COALESCE(WorkOrderDetail.subsidiary_haz_mat_class, TSDFapproval.subsidiary_haz_mat_class) AS sub_hazmat_class,
		COALESCE(WorkOrderDetail.management_code, TSDFapproval.management_code) AS management_code,
		WorkOrderDetail.manifest_dot_sp_number,
		isnull(TSDFApproval.empty_bottle_flag,'F'),
		isnull(TSDFApproval.residue_pounds_factor,0),
		isnull(TSDFApproval.residue_manifest_print_flag,'F'),
		(select round(isnull(sum(isnull(merchandise_quantity,0)),0),4)
				from WorkOrderDetailItem
				where workorder_id = WorkOrderDetail.workorder_id
				and company_id = WorkOrderDetail.company_id
				and profit_ctr_id = WorkOrderDetail.profit_ctr_id
				and sequence_id = WorkOrderDetail.sequence_id
				and item_type_ind = 'ME')
		, TSDFapproval.dot_sp_permit_text
		, TSDFapproval.print_dot_sp_flag
		, '' AS DOT_shipping_desc_label
		, dbo.fn_get_label_default_type ('W', WorkOrderDetail.workorder_id, WorkOrderDetail.company_id, WorkOrderDetail.profit_ctr_id, WorkOrderDetail.sequence_id, 0)
		, COALESCE(WorkOrderDetail.DOT_waste_flag, TSDFapproval.DOT_waste_flag) AS DOT_waste_flag
		, COALESCE(WorkOrderDetail.DOT_shipping_desc_additional, TSDFapproval.DOT_shipping_desc_additional) AS DOT_shipping_desc_additional
		, TSDFApproval.RQ_threshold
		, BillUnit.pound_conv 
		, WorkOrderDetail.class_7_additional_desc
	FROM WorkOrderDetail join TSDFapproval on WorkOrderDetail.TSDF_approval_id = TSDFapproval.TSDF_approval_id
			AND WorkOrderDetail.company_ID = TSDFapproval.company_ID
			AND WorkOrderDetail.profit_ctr_ID = TSDFapproval.profit_ctr_ID
		Join WorkOrderHeader on WorkOrderDetail.workorder_ID = WorkOrderHeader.workorder_ID  
			AND WorkOrderDetail.company_ID = WorkOrderHeader.company_ID 
			AND WorkOrderDetail.profit_ctr_ID = WorkOrderHeader.profit_ctr_ID 
		Join WorkOrderManifest on WorkOrderDetail.workorder_ID = WorkOrderManifest.workorder_ID
			AND WorkOrderDetail.company_ID = WorkOrderManifest.company_ID
			AND WorkOrderDetail.profit_ctr_ID = WorkOrderManifest.profit_ctr_ID
			AND WorkOrderDetail.manifest = WorkOrderManifest.manifest
		Join TSDF on WorkOrderDetail.TSDF_code = TSDF.TSDF_code
		Left Outer Join WorkOrderDetailUnit on WorkOrderDetailUnit.workorder_ID = WorkOrderDetail.workorder_ID  
			AND WorkOrderDetailUnit.company_ID = WorkOrderDetail.company_ID  
			AND WorkOrderDetailUnit.profit_ctr_ID = WorkOrderDetail.profit_ctr_ID
			AND WorkOrderDetailUnit.sequence_ID = WorkOrderDetail.sequence_ID
			AND WorkOrderDetailUnit.manifest_flag = 'T'
		Left outer Join BillUnit 
			on WorkorderDetailUnit.bill_unit_code = BillUnit.bill_unit_code
	WHERE TSDFapproval.company_id = @company_id
	AND ISNULL(TSDF.EQ_flag, 'F') = 'F'
	AND WorkOrderDetail.Resource_type = 'D'
	AND WorkOrderManifest.manifest_flag = 'T' 
	AND WorkOrderDetail.workorder_ID IN ( SELECT source_id FROM #source_list )
	AND WorkOrderDetail.profit_ctr_ID = @profit_center 
	AND WorkOrderDetail.company_ID = @company_id
	AND WorkOrderDetail.bill_rate <> -2 -- rb 08/12/2009

	GOTO end_process
END

-- Profiles
IF @ra_source = 'PROFILE'
BEGIN
	INSERT #manifest	
	SELECT 0 AS print_control_id,   
		CONVERT(varchar(10), @ra_source) AS source, 
		Profile.profile_id AS source_id,
		CONVERT(INT,NULL) AS trip_sequence_id,
		0 AS source_line_id,
		ProfileQuoteApproval.profit_ctr_id,  
		'' AS manifest, 
		'01' AS manifest_line_id,
		'001' AS manifest_line,
		1 AS manifest_page_num,   
		'' AS DOT_shipping_desc,
		'' AS additional_desc,
		'' AS handling_additional_info,
		left(Profile.DOT_shipping_name,255) as dot_shipping_name,   
		Profile.hazmat AS hazmat_flag,   
		Profile.hazmat_class,   
		CASE WHEN Profile.UN_NA_flag = 'X' THEN ''
			ELSE Profile.UN_NA_flag
			END AS UN_NA_flag,   
		Profile.UN_NA_number,   
		Profile.package_group AS packing_group,   
		Profile.ERG_number,
		Profile.ERG_suffix,
		0 AS container_count,
		Profile.manifest_container_code AS container_code,
		0 AS quantity,
		Profile.manifest_wt_vol_unit,   
		--Profile.waste_code,   
       ISNULL((  select wastecode.display_name from wastecode where wastecode.waste_code_uid = profile.waste_code_uid ),'NONE') as  waste_code, 
		ProfileQuoteApproval.approval_code,   
		CONVERT(varchar(50), '') AS secondary_waste_code,   
		COALESCE(Profile.manifest_waste_desc, Profile.approval_desc),  
		Profile.manifest_handling_code,   
		Profile.manifest_hand_instruct,
		Profile.generator_id,
		CONVERT(varchar(15), '') AS tsdf_code,   
		CONVERT(varchar(10), '') AS waste_stream,
		Profile.ap_expiration_date AS expiration_date,
		'F' AS continuation_flag,   
		Profile.reportable_quantity_flag AS reportable_quantity_flag,   
		Profile.RQ_reason AS RQ_reason,
		Profile.subsidiary_haz_mat_class as sub_hazmat_class,
		Treatmentdetail.management_code  as management_code,
		Profile.manifest_dot_sp_number as manifest_dot_sp_number,
		Profile.empty_bottle_flag,
		Profile.residue_pounds_factor,
		Profile.residue_manifest_print_flag,
		0
		, Profile.dot_sp_permit_text
		, ProfileQuoteApproval.print_dot_sp_flag
		, '' AS DOT_shipping_desc_label
		, case when isnull(@generator_id,0) > 0 then dbo.fn_get_label_default_type ('P', Profile.profile_id, @company_id, @profit_center, 0, @generator_id)
			else dbo.fn_get_label_default_type ('P', Profile.profile_id, @company_id, @profit_center, 0, 0) end
		, Profile.DOT_waste_flag 
		, Profile.DOT_shipping_desc_additional 
		, Profile.RQ_threshold
		, BillUnit.pound_conv
		, NULL AS class_7_additional_desc
	FROM Profile
	JOIN ProfileQuoteApproval
		ON ProfileQuoteApproval.profile_id = Profile.profile_id
		AND ProfileQuoteApproval.company_id = @company_id
		AND ProfileQuoteApproval.profit_ctr_id = @profit_center
	JOIN Treatment
		ON ProfileQuoteApproval.treatment_id = Treatment.treatment_id
		AND ProfileQuoteApproval.profit_ctr_id = Treatment.profit_ctr_id
		AND ProfileQuoteApproval.company_id = Treatment.company_id
	JOIN Treatmentdetail
		ON ProfileQuoteApproval.treatment_id = Treatmentdetail.treatment_id
		AND ProfileQuoteApproval.profit_ctr_id = Treatmentdetail.profit_ctr_id
		AND ProfileQuoteApproval.company_id = Treatmentdetail.company_id
	LEFT OUTER JOIN BillUnit 
		ON BillUnit.manifest_unit = Profile.manifest_wt_vol_unit
	WHERE ProfileQuoteApproval.profit_ctr_id = @profit_center
	AND ProfileQuoteApproval.company_id = @company_id
	AND ProfileQuoteApproval.profile_id IN ( SELECT source_id FROM #source_list )
	AND Profile.curr_status_code = 'A'

	GOTO end_process
END

-- TSDF Approvals
IF @ra_source = 'TSDFAPPR'
BEGIN
	INSERT #manifest	
	SELECT 0 AS print_control_id,   
		CONVERT(varchar(10), @ra_source) AS source, 
		TSDFapproval.tsdf_approval_id AS source_id,
		CONVERT(INT,NULL) AS trip_sequence_id,
		0 AS source_line_id,   
		TSDFApproval.profit_ctr_id,  
		'' AS manifest, 
		'01' AS manifest_line_id,   
		'001' AS manifest_line,
		1 AS manifest_page_num,   
		'' AS DOT_shipping_desc,
		'' AS additional_desc,
		'' AS handling_additional_info,
		left(TSDFapproval.DOT_shipping_name,255) as dot_shipping_name,   
		TSDFapproval.hazmat AS hazmat_flag,   
		TSDFapproval.hazmat_class,   
		CASE WHEN TSDFapproval.UN_NA_flag = 'X' THEN ''
			ELSE TSDFapproval.UN_NA_flag
			END AS UN_NA_flag,   
		TSDFapproval.UN_NA_number,   
		TSDFapproval.package_group AS packing_group,   
		TSDFapproval.ERG_number,
		TSDFapproval.ERG_suffix,
		0 AS container_count,
		TSDFapproval.manifest_container_code AS container_code,
		0 AS quantity,
		TSDFapproval.manifest_wt_vol_unit,   
		--TSDFapproval.waste_code,   
		ISNULL((  select wastecode.display_name from wastecode where wastecode.waste_code_uid = TSDFApproval.waste_code_uid ),'NONE') as  waste_code, 
		TSDFapproval.TSDF_approval_code AS approval_code,   
		CONVERT(varchar(50), '') AS secondary_waste_code,   
		TSDFapproval.waste_desc,   
		TSDFapproval.manifest_handling_code,   
		TSDFapproval.hand_instruct,
		TSDFapproval.generator_id AS generator_id,  
		TSDFapproval.TSDF_code AS tsdf_code,
		TSDFapproval.waste_stream AS waste_stream,
		TSDFapproval.TSDF_approval_expire_date AS expiration_date,
		'F' AS continuation_flag,   
		TSDFapproval.reportable_quantity_flag AS reportable_quantity_flag,   
		TSDFapproval.RQ_reason AS RQ_reason,
		TSDFapproval.subsidiary_haz_mat_class as sub_hazmat_class,
		TSDFapproval.management_code as management_code,
		TSDFapproval.manifest_dot_sp_number as manifest_dot_sp_number,
		TSDFApproval.empty_bottle_flag,
		TSDFApproval.residue_pounds_factor,
		TSDFApproval.residue_manifest_print_flag,
		0
		, TSDFapproval.dot_sp_permit_text
		, TSDFapproval.print_dot_sp_flag
		, '' AS DOT_shipping_desc_label
		, dbo.fn_get_label_default_type ('T', TSDFApproval.tsdf_approval_id, @company_id, @profit_center, 0, 0)
		, TSDFapproval.DOT_waste_flag 
		, TSDFapproval.DOT_shipping_desc_additional 
		, TSDFApproval.RQ_threshold
		, BillUnit.pound_conv
		, NULL AS class_7_additional_desc
	FROM TSDFapproval  
	LEFT OUTER JOIN BillUnit
		ON BillUnit.manifest_unit = TSDFapproval.manifest_wt_vol_unit
	WHERE TSDFApproval.TSDF_approval_id IN ( SELECT source_id FROM #source_list )
--rb	AND TSDFApproval.TSDF_approval_status = 'A'
	AND TSDFApproval.profit_ctr_ID = @profit_center
	AND TSDFApproval.company_id = @company_id
	
	GOTO end_process
END

end_process:
-- dump the manifest table

Declare
@source_id		int,
@last_source_id	int,
@manifest		varchar(20),
@last_manifest	varchar(20),
@manifest_line	int,
@last_line		int,
@manifest_page	int,
@manifest_line_id	char(1),
@line			int

Set @last_line = 0

IF @rejection_manifest_flag = 'F' 
BEGIN
	-- MPM - 9/6/2023 - DevOps 64576 - Added trip_sequence_id to the "fill manifest" logic
	Declare fill_manifest cursor for
		Select source_id, manifest, Cast(manifest_line as int), trip_sequence_id
			From #manifest
			order by source_id, manifest, Cast(manifest_line as int) 
			
	Open fill_manifest
	Fetch Next from fill_manifest
	into @source_id, @manifest, @manifest_line, @trip_sequence_id

	While @@fetch_status = 0 
	Begin
		if (@source_id <> @last_source_id) or (@manifest <> @last_manifest)
			Set @last_line = 0

		If (@last_line + 1) < @manifest_line 
			Begin
				While @last_line + 1 < @manifest_line
					Begin
						Set @manifest_page = Cast(((@last_line + 1 - 4)/10) AS int) + 1
						Insert into #manifest (control_id, source, source_id, manifest, manifest_page_num, manifest_line, trip_sequence_id)
							Values(	0, @ra_source, @source_id, @manifest, @manifest_page, Right('000' + Cast((@last_line + 1) as varchar),3), @trip_sequence_id)
						
						Set @last_line = @last_line + 1	
					End
			End
		Set @last_line = @manifest_line	
		Set @last_manifest = @manifest
		Set @last_source_id = @source_id
		Fetch Next from fill_manifest
			into @source_id, @manifest, @manifest_line, @trip_sequence_id
	END 
	CLOSE fill_manifest
	DEALLOCATE fill_manifest
END
ELSE -- @rejection_manifest_flag = 'T'
BEGIN
	-- Because we're generating a rejection manifest, which shows only rejected line items, we'll probably need to 
	-- update manifest_page_num/manifest_line/manifest_line_id for all rejected line items in #manifest.
	
	-- Need to create an index on #manifest so that we can create an update cursor on it
	CREATE UNIQUE INDEX idx_manifest   
	ON #manifest (source, source_id, source_line)
	
	Declare update_manifest cursor for
		Select source_id, manifest
			From #manifest
			order by source_id, manifest, manifest_line
	for update of manifest_page_num, manifest_line, manifest_line_id
			
	Open update_manifest
	
	Fetch Next from update_manifest
	into @source_id, @manifest

	While @@fetch_status = 0 
	Begin
		if @source_id <> @last_source_id or @manifest <> @last_manifest or @last_source_id is null or @last_manifest is null
			Set @line = 1
					
		Set @manifest_page = CEILING((@line - 4)/10.0) + 1

		IF @line = 1 OR @line % 10 = 5
			SET @manifest_line_id = 'A'
		ELSE IF @line = 2 OR @line % 10 = 6
			SET @manifest_line_id = 'B'
		ELSE IF @line = 3 OR @line % 10 = 7
			SET @manifest_line_id = 'C'
		ELSE IF @line = 4 OR @line % 10 = 8
			SET @manifest_line_id = 'D'
		ELSE IF @line % 10 = 9
			SET @manifest_line_id = 'E'
		ELSE IF @line % 10 = 0
			SET @manifest_line_id = 'F'
		ELSE IF @line % 10 = 1
			SET @manifest_line_id = 'G'
		ELSE IF @line % 10 = 2
			SET @manifest_line_id = 'H'
		ELSE IF @line % 10 = 3
			SET @manifest_line_id = 'I'
		ELSE IF @line % 10 = 4
			SET @manifest_line_id = 'J'
			
		update #manifest 
			set manifest_page_num = @manifest_page,
			    manifest_line = RIGHT('000' + CONVERT(varchar(3),@line),3),
			    manifest_line_id = @manifest_line_id
		where current of update_manifest
		
		Set @line = @line + 1	
		Set @last_manifest = @manifest
		Set @last_source_id = @source_id
		
		Fetch Next from update_manifest
		into @source_id, @manifest
		
	END 
	CLOSE update_manifest
	DEALLOCATE update_manifest
END

SET NOCOUNT OFF

SELECT	control_id,
	source,
	source_id,
	trip_sequence_id,
	source_line,
	profit_center,
	manifest, 
	manifest_line_id,
	manifest_line,
	manifest_page_num,
	DOT_shipping_desc,
	additional_desc,
	handling_additional_info,
	DOT_shipping_name,   
	hazmat_flag,   
	hazmat_class,   
	UN_NA_flag,
	UN_NA_number,
	packing_group,
	ERG_number,
	ERG_suffix,
	container_count,
	container_code,
	quantity,
	manifest_wt_vol_unit,   
	Case waste_code
		When  'NONE' Then ''
		ELSE waste_code
	END,   
	approval_code,   
	secondary_waste_code,   
	waste_desc,   
	manifest_handling_code,   
	hand_instruct,
	generator_id,   
	tsdf_code,   
	waste_stream,
	expiration_date,
	continuation_flag,   
	reportable_quantity_flag,   
	RQ_reason,
	sub_hazmat_class,
	management_code,
	manifest_dot_sp_number,
	empty_bottle_flag,
	residue_pounds_factor,
	residue_manifest_print_flag,
	empty_bottle_count
	, dot_sp_permit_text
	, print_dot_sp_flag
	, DOT_shipping_desc_label
	, default_label_type
	, DOT_waste_flag 
	, DOT_shipping_desc_additional 
	, RQ_threshold
	, pound_conv
	, class_7_additional_desc
FROM #manifest
ORDER BY source_id, manifest, manifest_page_num, manifest_line_id
GO

GRANT EXECUTE
    ON OBJECT::[dbo].[sp_get_manifest_detail_uniform] TO [EQWEB];
GO

GRANT EXECUTE
    ON OBJECT::[dbo].[sp_get_manifest_detail_uniform] TO [COR_USER];
GO

GRANT EXECUTE
    ON OBJECT::[dbo].[sp_get_manifest_detail_uniform] TO [EQAI];


