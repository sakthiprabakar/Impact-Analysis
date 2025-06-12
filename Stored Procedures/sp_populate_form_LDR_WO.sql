-- drop procedure sp_populate_form_ldr_wo
go

CREATE PROCEDURE sp_populate_form_LDR_WO
	@form_id		int,
	@workorder_id	int,
	@company_id		INT,
	@profit_ctr_id	int,
	@manifest		varchar(30),
	@added_by		varchar(60),
	@lines_to_include	varchar(100) = ''
AS
/***************************************************************************************
Populates FormLDR tables with data from work order
Load to PLt_AI
Filename:	L:\Apps\SQL\EQAI\sp_populate_form_LDR_WO.sql
PB Object(s):	

11/8/2005 JDB	Created
01/05/2006 MK	Allow full approval length (from 15 to 40)
08/01/2006 MK	Modified LDR for Workorders
09/06/2006 MK	Modified to allow LDR for any disposal workorder
09/14/2006 MK	Modified to use line number args
06/07/2007 JDB	Fixed incorrect join to TSDFApprovalWasteCode when populating FormXWasteCode
10/02/2007 WAC	Removed references to a database server
06/09/2008 KAM  Updated the procedure to allow for a null address for a Generator
03/15/2011 RWB  Modified manifest line number to numeric version,
                Removed rowguid column from inserts
03/16/2011 RWB  Changed @lines_to_include argument to reference sequence_id instead of billing_sequence_id
05/16/2012 SK	Moved to Plt_AI & made identical to sp_populate_form_ldr
08/07/2012 SK	Modified for FormLDRSubcategory
10/18/2012 SK	FormLDR.state_manifest_no is an obsolete field, going away. Use FormLDR.manifest_doc_no to store the WorkOrderManifest.manifest
12/05/2012 JDB	Removed the subcategory_id field from being inserted into FormLDRDetail, because this field does not exist in the table.
01/24/2013 SK	Added the missing Insert into FormLDRSubcategory for LDRs with TSDFApprovals
04/17/2013 SK	Added waste_code_UID to FormXWasteCode
10/02/2013 SK	Changed to copy only active waste codes to the form from profile
10/24/2013 AM   Modified code to insert data into FormXWasteCode from function instead of ProfileWasteCode
12/09/2013 AM   Fixed code to print waste codes correctly for multiple approvals
12/12/2013 AM   Fixed code to send tsdfapproval for non-EQ fecilities to get correct wastecodes from fn_tbl_manifest_waste_codes.
12/13/2013 AM   Fixed code to send tsdf_approval_id for non-EQ fecilities to get correct wastecodes from fn_tbl_manifest_waste_codes.
02/26/2015 SK	Fixed to populate the new 'FormXConstituent.min_concentration' field from ProfileConstituent and TSDFApprovalConstituent
02/23/2018 AM	Added TSDFApprovalLDRSubcategory join to FormLDRSubcategory for TSDFApprovals.
07/03/2019 MPM	Samanage 12511 - Added column list to inserts.  

sp_populate_form_LDR_WO -378104, 1186400, 21, 0, '008258011JJK', 'SA', '1,2'
****************************************************************************************/
DECLARE @revision_id INT
,   @status CHAR(1)
,   @locked CHAR(1)
,   @source CHAR(1)
,   @current_form_version_id INT
,   @tsdf_code VARCHAR(20)
,   @tsdf_company INT
,   @tsdf_profit_ctr_id INT
,   @eq_flag CHAR(1)
,   @Pos INT
,   @linenum INT
,	@profile_id INT 
,	@generator_id INT
,	@wod_manifest_line INT
,   @tsdf_approval_id INT

SET NOCOUNT ON

CREATE TABLE #Tmp
(
	LineNum int
)

SET @revision_id = 1
SET @status = 'A'
SET @locked = 'U'
SET @source = 'A'
SELECT @current_form_version_id = current_form_version FROM FormType WHERE form_type = 'LDR'
  
-- Populate FormLDR
INSERT INTO FormLDR
	(form_id, revision_id, form_version_id, customer_id_from_form, customer_id, app_id, status, locked, source, company_id, profit_ctr_id, signing_name, signing_company, signing_title, signing_date,
		date_created, date_modified, created_by, modified_by, generator_name, generator_EPA_ID, generator_address1, generator_city, generator_state, generator_zip,
		state_manifest_no, manifest_doc_no, generator_id, generator_address2, generator_address3, generator_address4, generator_address5, profitcenter_epa_id,
		profitcenter_profit_ctr_name, profitcenter_address_1, profitcenter_address_2, profitcenter_address_3, profitcenter_phone, profitcenter_fax, rowguid,
		wcr_id, wcr_rev_id)
SELECT	@form_id AS form_id,
	@revision_id AS revision_id,
	@current_form_version_id AS form_version_id,
	WorkorderHeader.customer_id AS customer_id_from_form,
	WorkorderHeader.customer_id AS customer_id,
	NULL AS app_id,
	@status AS status,
	@locked AS locked,
	@source AS source,
	ProfitCenter.company_id,
	@profit_ctr_id,
	NULL AS signing_name,
	NULL AS signing_company,
	NULL AS signing_title,
	NULL AS signing_date,
	GETDATE() AS date_created,
	GETDATE() AS date_modified,
	@added_by AS created_by,
	@added_by AS modified_by,
	Generator.generator_name,
	Generator.EPA_ID,
	Generator.generator_address_1,
	Generator.generator_city,
	Generator.generator_state,
	Generator.generator_zip_code,
	'',	--state_manifest_no field not being used anymore
	--WorkorderManifest.gen_manifest_doc_number,
	WorkorderManifest.manifest, -- manifest_doc_no will store the manifest
	Generator.generator_id,
	Generator.generator_address_2,
	Generator.generator_address_3,
	Generator.generator_address_4,
	generator_address_5 = RTrim(CASE WHEN Generator.Generator_id = 0 THEN ''
												WHEN (Generator.generator_city + ', ' + Generator.generator_state + ' ' + IsNull(Generator.generator_zip_code,'')) = ', ' THEN 'Missing Mailing City, State and Zip Code'
												ELSE (Generator.generator_city + ', ' + Generator.generator_state + ' ' + IsNull(Generator.generator_zip_code,'')) END),
	ProfitCenter.EPA_ID AS profitcenter_epa_id,
	ProfitCenter.profit_ctr_name AS profitcenter_profit_ctr_name,
	ProfitCenter.address_1 AS profitcenter_address_1,
	ProfitCenter.address_2 AS profitcenter_address_2,
	ProfitCenter.address_3 AS profitcenter_address_3,
	ProfitCenter.phone AS profitcenter_phone,
	ProfitCenter.fax AS profitcenter_fax,
	NEWID(),
	NULL,
	NULL
FROM WorkorderManifest
JOIN dbo.ProfitCenter 
	ON ProfitCenter.profit_ctr_id = WorkorderManifest.profit_ctr_id
	AND ProfitCenter.company_ID = WorkorderManifest.company_id
JOIN WorkOrderHeader
	ON WorkorderHeader.workorder_id = WorkorderManifest.workorder_id
	AND WorkorderHeader.profit_ctr_id = WorkorderManifest.profit_ctr_id
	AND WorkorderHeader.company_id = WorkorderManifest.company_id
LEFT OUTER JOIN Generator
	ON  WorkorderHeader.generator_id = Generator.generator_id
LEFT OUTER JOIN Customer
	ON  WorkorderHeader.customer_id = Customer.customer_id	
WHERE WorkorderManifest.workorder_id = @workorder_id
AND WorkorderManifest.profit_ctr_id = @profit_ctr_id
AND WorkorderManifest.company_id = @company_id
AND WorkorderManifest.manifest = @manifest

-- Get TSDF code
SELECT @tsdf_code = TSDF_code
FROM WorkorderDetail 
WHERE WorkorderDetail.resource_type = 'D'
AND WorkorderDetail.workorder_id = @workorder_id
AND WorkorderDetail.profit_ctr_id = @profit_ctr_id 
AND WorkorderDetail.company_id = @company_id 
AND WorkorderDetail.manifest = @manifest
GROUP BY TSDF_code

-- Get EQ company/profit center
SELECT	@tsdf_company = eq_company,
	@tsdf_profit_ctr_id = eq_profit_ctr,
	@eq_flag = IsNull(eq_flag,'F')
FROM TSDF
WHERE TSDF_code = @tsdf_code


SET @lines_to_include = LTRIM(RTRIM(@lines_to_include))+ ','
SET @Pos = CHARINDEX(',', @lines_to_include, 1)

IF REPLACE(@lines_to_include, ',', '') <> ''
BEGIN
	WHILE @Pos > 0
	BEGIN
		SET @linenum = LTRIM(RTRIM(LEFT(@lines_to_include, @Pos - 1)))
		IF @linenum <> ''
		BEGIN
			INSERT INTO #Tmp (LineNum) VALUES (CAST(@linenum AS int)) 
		END
		SET @lines_to_include = RIGHT(@lines_to_include, LEN(@lines_to_include) - @Pos)
		SET @Pos = CHARINDEX(',', @lines_to_include, 1)

	END
END	

IF IsNull(@eq_flag,'F') = 'T' 
-- Use Profit Center info for this EQ facility
BEGIN
	UPDATE FormLDR SET profitcenter_epa_id = ProfitCenter.EPA_ID,
		profitcenter_profit_ctr_name = ProfitCenter.profit_ctr_name,
		profitcenter_address_1 = ProfitCenter.address_1,
		profitcenter_address_2 = ProfitCenter.address_2,
		profitcenter_address_3 = ProfitCenter.address_3,
		profitcenter_phone = ProfitCenter.phone,
		profitcenter_fax = ProfitCenter.fax
	FROM ProfitCenter ProfitCenter
	WHERE ProfitCenter.company_id = @tsdf_company
	AND ProfitCenter.profit_ctr_id = @tsdf_profit_ctr_id
	AND form_id = @form_id
	AND revision_id = @revision_id

	-- Populate FormLDRDetail
	INSERT INTO FormLDRDetail
		(form_id, revision_id, form_version_id, page_number, manifest_line_item, ww_or_nww, subcategory, manage_id,approval_code, approval_key,
			company_id, profit_ctr_id, profile_id)
    SELECT  @form_id AS form_id
    ,       @revision_id AS revision_id
    ,       @current_form_version_id AS form_version_id
    ,       WorkorderDetail.manifest_page_num AS page_number
    ,       WorkorderDetail.manifest_line AS manifest_line_item
    ,       CASE WHEN P.waste_water_flag = 'W' THEN 'WW'
                 ELSE 'NWW'
            END AS ww_or_nww
    ,       P.LDR_subcategory AS subcategory
    ,       P.waste_managed_id AS manage_id
    ,       PQA.approval_code
    ,       NULL AS approval_key
    ,       @company_id
    ,       @profit_ctr_id
    ,       P.profile_id
	FROM WorkorderDetail
	JOIN #Tmp ON WorkorderDetail.sequence_id = #Tmp.LineNum
	JOIN Profile P
		ON WorkorderDetail.profile_id = P.profile_id
	JOIN ProfileQuoteApproval PQA
		ON WorkorderDetail.profile_company_id = PQA.company_id
		AND WorkorderDetail.profile_profit_ctr_id = PQA.profit_ctr_id
 		AND P.profile_id = PQA.profile_id
 		AND PQA.status = 'A'
	--LEFT OUTER JOIN LDRSubcategory
	--	ON LDRSubcategory.short_desc = P.LDR_subcategory
	WHERE WorkorderDetail.resource_type = 'D'
	AND WorkorderDetail.workorder_id = @workorder_id
	AND WorkorderDetail.profit_ctr_id = @profit_ctr_id 
	AND WorkorderDetail.company_id = @company_id 
	AND WorkorderDetail.manifest = @manifest

	-- Populate FormXConstituent
	INSERT INTO FormXConstituent
		(form_id, revision_id, page_number, line_item, const_id, const_desc, concentration, min_concentration, unit, uhc, specifier)
	SELECT	@form_id AS form_id,
		@revision_id AS revision_id,
		WorkorderDetail.manifest_page_num AS page_number,
		WorkorderDetail.manifest_line AS manifest_line_item,
		ProfileConstituent.const_id AS const_id,
		Constituents.const_desc AS const_desc,
		ProfileConstituent.concentration AS concentration,
		ProfileConstituent.min_concentration AS min_concentration,
		ProfileConstituent.unit AS unit,
		ProfileConstituent.UHC AS UHC,
		'LDR-WO' AS specifier
	FROM ProfileConstituent, ProfileQuoteApproval PQA, Constituents, WorkorderDetail
	WHERE WorkorderDetail.profile_id = ProfileConstituent.profile_id
 	AND WorkorderDetail.profile_company_id = PQA.company_id
	AND WorkorderDetail.profile_profit_ctr_id = PQA.profit_ctr_id
 	AND ProfileConstituent.profile_id = PQA.profile_id
	AND ProfileConstituent.const_id = Constituents.const_id
	AND ProfileConstituent.UHC = 'T'
	AND PQA.status = 'A'
--	AND PQA.LDR_req_flag = 'T'
	AND WorkorderDetail.resource_type = 'D'
	AND WorkorderDetail.workorder_id = @workorder_id
	AND WorkorderDetail.profit_ctr_id = @profit_ctr_id 
	AND WorkorderDetail.company_id = @company_id 
	AND WorkorderDetail.manifest = @manifest
	
	
	-- Populate FormXWasteCode
	/*INSERT INTO FormXWasteCode
	SELECT	@form_id AS form_id,
		@revision_id AS revision_id,
		WorkorderDetail.manifest_page_num AS page_number,
		WorkorderDetail.manifest_line AS manifest_line_item,
		ProfileWasteCode.waste_code_uid,
		ProfileWasteCode.waste_code AS waste_code,
		'LDR-WO' AS specifier
	FROM ProfileWasteCode, ProfileQuoteApproval PQA, WorkorderDetail, WasteCode
	WHERE WorkorderDetail.profile_id = ProfileWasteCode.profile_id
 	AND WorkorderDetail.profile_company_id = PQA.company_id
	AND WorkorderDetail.profile_profit_ctr_id = PQA.profit_ctr_id
 	AND ProfileWasteCode.profile_id = PQA.profile_id
	AND PQA.status = 'A'
	AND WasteCode.waste_code_uid = ProfileWasteCode.waste_code_uid
	AND WasteCode.status = 'A'
--	AND PQA.LDR_req_flag = 'T'
	AND WorkorderDetail.resource_type = 'D'
	AND WorkorderDetail.workorder_id = @workorder_id
	AND WorkorderDetail.profit_ctr_id = @profit_ctr_id 
	AND WorkorderDetail.company_id = @company_id 
	AND WorkorderDetail.manifest = @manifest */
	
 begin		
	declare c_workorder_detail cursor read_only forward_only for
	SELECT p.profile_id ,
	       p.generator_id,
	       WorkorderDetail.manifest_line
	FROM WorkorderDetail
	JOIN #Tmp ON WorkorderDetail.sequence_id = #Tmp.LineNum
	JOIN Profile P
		ON WorkorderDetail.profile_id = P.profile_id
	JOIN ProfileQuoteApproval PQA
		ON WorkorderDetail.profile_company_id = PQA.company_id
		AND WorkorderDetail.profile_profit_ctr_id = PQA.profit_ctr_id
 		AND P.profile_id = PQA.profile_id
 		AND PQA.status = 'A'
	WHERE WorkorderDetail.resource_type = 'D'
	AND WorkorderDetail.workorder_id = @workorder_id
	AND WorkorderDetail.profit_ctr_id = @profit_ctr_id 
	AND WorkorderDetail.company_id = @company_id 
	AND WorkorderDetail.manifest = @manifest
	
	open c_workorder_detail
    fetch c_workorder_detail into @profile_id, @generator_id, @wod_manifest_line
	
	while @@FETCH_STATUS = 0
	begin
	
		INSERT INTO FormXWasteCode
           (form_id
           ,revision_id
           ,page_number
           ,line_item
           ,waste_code_uid
           ,waste_code
           ,specifier)
		SELECT	@form_id AS form_id,
			@revision_id AS revision_id,
			wod.manifest_page_num AS page_number,
			--wod.manifest_line AS manifest_line_item,
			@wod_manifest_line,
			f.waste_code_uid,
			f.waste_code AS waste_code,
			'LDR-WO' AS specifier
		from WorkorderDetail wod,
			dbo.fn_tbl_manifest_waste_codes ('profile', @profile_id, @generator_id , @tsdf_code) f
			where  wod.resource_type = 'D'
			AND wod.workorder_id = @workorder_id
			AND wod.profit_ctr_id = @profit_ctr_id 
			AND wod.company_id = @company_id 
			AND wod.manifest = @manifest
			AND wod.manifest_line = @wod_manifest_line
			AND ISNULL(f.use_for_storage,0) = 1
			AND f.display_name <> 'NONE'
			
	   fetch c_workorder_detail into @profile_id, @generator_id, @wod_manifest_line
    end
   close c_workorder_detail
   deallocate c_workorder_detail
end	
	-- Populate FormLDRSubcategory
	INSERT INTO FormLDRSubcategory (form_id, revision_id, page_number, manifest_line_item, ldr_subcategory_id)
	SELECT	@form_id AS form_id,
		@revision_id AS revision_id,
		WorkorderDetail.manifest_page_num AS page_number,
		WorkorderDetail.manifest_line AS manifest_line_item,
		ProfileLDRSubcategory.ldr_subcategory_id
	FROM ProfileLDRSubcategory, ProfileQuoteApproval PQA, WorkorderDetail
	WHERE WorkorderDetail.profile_id = ProfileLDRSubcategory.profile_id
 	AND WorkorderDetail.profile_company_id = PQA.company_id
	AND WorkorderDetail.profile_profit_ctr_id = PQA.profit_ctr_id
 	AND ProfileLDRSubcategory.profile_id = PQA.profile_id
	AND PQA.status = 'A'
	AND WorkorderDetail.resource_type = 'D'
	AND WorkorderDetail.workorder_id = @workorder_id
	AND WorkorderDetail.profit_ctr_id = @profit_ctr_id 
	AND WorkorderDetail.company_id = @company_id 
	AND WorkorderDetail.manifest = @manifest
END

ELSE
-- Use TSDF info for this non-EQ facility
BEGIN
	UPDATE FormLDR SET profitcenter_epa_id = TSDF.TSDF_EPA_ID,
		profitcenter_profit_ctr_name = TSDF.TSDF_name,
		profitcenter_address_1 = TSDF.TSDF_addr1,
		profitcenter_address_2 = TSDF.TSDF_addr2,
		profitcenter_address_3 = ISNULL(TSDF.TSDF_city, '') + ', ' + ISNULL(TSDF.TSDF_state, '') + '  ' + ISNULL(TSDF.TSDF_zip_code, ''),
		profitcenter_phone = TSDF.TSDF_phone,
		profitcenter_fax = TSDF.TSDF_fax
	FROM TSDF
	WHERE TSDF.TSDF_code = @tsdf_code
	AND form_id = @form_id
	AND revision_id = @revision_id

	-- Populate FormLDRDetail
	INSERT INTO FormLDRDetail
		(form_id, revision_id, form_version_id, page_number, manifest_line_item, ww_or_nww, subcategory, manage_id,approval_code, approval_key,
			company_id, profit_ctr_id, profile_id)
	SELECT	@form_id AS form_id,
		@revision_id AS revision_id,
		@current_form_version_id AS form_version_id,
		WorkorderDetail.manifest_page_num AS page_number,
		WorkorderDetail.manifest_line AS manifest_line_item,
		CASE WHEN TSDFApproval.waste_water_flag = 'W' THEN 'WW' ELSE 'NWW' END AS ww_or_nww,
		TSDFApproval.LDR_subcategory AS subcategory,
		TSDFApproval.waste_managed_id AS manage_id,
		TSDFApproval.TSDF_approval_code,
		NULL AS approval_key,
		@company_id ,
		@profit_ctr_id,
		TSDFApproval.TSDF_approval_id
	FROM WorkOrderDetail
	JOIN #Tmp ON WorkorderDetail.sequence_id = #Tmp.LineNum
	JOIN TSDFApproval
		ON WorkorderDetail.TSDF_approval_id = TSDFApproval.TSDF_approval_id
		AND WorkorderDetail.profit_ctr_id = TSDFApproval.profit_ctr_id
		AND WorkorderDetail.company_id = TSDFApproval.company_id
		AND TSDFApproval.TSDF_Approval_status = 'A'
	JOIN TSDF
		ON TSDFApproval.TSDF_code = TSDF.TSDF_code
		AND IsNull(TSDF.eq_flag,'F') = 'F'
	LEFT OUTER JOIN LDRSubcategory
		ON LDRSubcategory.short_desc = TSDFApproval.LDR_subcategory
	WHERE WorkorderDetail.resource_type = 'D'
	AND WorkorderDetail.workorder_id = @workorder_id
	AND WorkorderDetail.profit_ctr_id = @profit_ctr_id 
	AND WorkorderDetail.company_id = @company_id
	AND WorkorderDetail.manifest = @manifest
	
	-- Populate FormXConstituent
	INSERT INTO FormXConstituent
		(form_id, revision_id, page_number, line_item, const_id, const_desc, concentration, min_concentration, unit, uhc, specifier)
	SELECT	@form_id AS form_id,
		@revision_id AS revision_id,
		WorkorderDetail.manifest_page_num AS page_number,
		WorkorderDetail.manifest_line AS manifest_line_item,
		TSDFApprovalConstituent.const_id AS const_id,
		Constituents.const_desc AS const_desc,
		TSDFApprovalConstituent.concentration AS concentration,
		TSDFApprovalConstituent.concentration AS min_concentration,
		TSDFApprovalConstituent.unit AS unit,
		TSDFApprovalConstituent.UHC AS UHC,
		'LDR-WO' AS specifier
	FROM TSDFApproval, TSDFApprovalConstituent, Constituents, WorkorderDetail
	WHERE TSDFApprovalConstituent.TSDF_approval_id = TSDFApproval.TSDF_approval_id
	AND WorkorderDetail.TSDF_approval_id = TSDFApproval.TSDF_approval_id
	AND WorkorderDetail.profit_ctr_id = TSDFApproval.profit_ctr_id
	AND WorkorderDetail.company_id = TSDFApproval.company_id
	AND TSDFApprovalConstituent.const_id = Constituents.const_id
	AND TSDFApprovalConstituent.UHC = 'T'
	AND TSDFApproval.TSDF_Approval_status = 'A'
--	AND TSDFapproval.LDR_required = 'T'
	AND WorkorderDetail.resource_type = 'D'
	AND WorkorderDetail.workorder_id = @workorder_id
	AND WorkorderDetail.profit_ctr_id = @profit_ctr_id 
	AND WorkorderDetail.company_id = @company_id
	AND WorkorderDetail.manifest = @manifest
	
	
	-- Populate FormXWasteCode
	/* INSERT INTO FormXWasteCode
	SELECT	@form_id AS form_id,
		@revision_id AS revision_id,
		WorkorderDetail.manifest_page_num AS page_number,
		WorkorderDetail.manifest_line AS manifest_line_item,
		TSDFApprovalWasteCode.waste_code_uid,
		TSDFApprovalWasteCode.waste_code AS waste_code,
		'LDR-WO' AS specifier	
	FROM TSDFApproval
	INNER JOIN TSDFApprovalWasteCode ON TSDFApproval.TSDF_approval_id = TSDFApprovalWasteCode.TSDF_approval_id
	INNER JOIN WasteCode ON WasteCode.waste_code_uid = TSDFApprovalWasteCode.waste_code_uid
	AND WasteCode.status = 'A'
	INNER JOIN WorkorderDetail ON TSDFApproval.TSDF_approval_id = WorkorderDetail.TSDF_approval_id
		AND TSDFApproval.profit_ctr_id = WorkorderDetail.profit_ctr_id
		AND TSDFApproval.company_id = WorkorderDetail.company_id
	WHERE TSDFApproval.TSDF_Approval_status = 'A'
--	AND TSDFApproval.LDR_required = 'T'
	AND WorkorderDetail.resource_type = 'D'
	AND WorkorderDetail.workorder_id = @workorder_id
	AND WorkorderDetail.profit_ctr_id = @profit_ctr_id
	AND WorkorderDetail.company_id = @company_id 
	AND WorkorderDetail.manifest = @manifest */
 begin	
	declare c_workorder_detail_2 cursor read_only forward_only for
   
	    SELECT TSDFApproval.tsdf_approval_id ,
	           WorkorderHeader.generator_id,
	           WorkorderDetail.manifest_line
	    FROM TSDFApproval 
	INNER JOIN WorkorderDetail ON TSDFApproval.TSDF_approval_id = WorkorderDetail.TSDF_approval_id
		AND TSDFApproval.profit_ctr_id = WorkorderDetail.profit_ctr_id
		AND TSDFApproval.company_id = WorkorderDetail.company_id
    INNER JOIN WorkorderHeader ON WorkorderDetail.workorder_id = WorkorderHeader.workorder_id
    	AND TSDFApproval.profit_ctr_id = WorkorderHeader.profit_ctr_id
		AND TSDFApproval.company_id = WorkorderHeader.company_id
	WHERE TSDFApproval.TSDF_Approval_status = 'A'
	AND WorkorderDetail.resource_type = 'D'
	AND WorkorderDetail.workorder_id =  @workorder_id
	AND WorkorderDetail.profit_ctr_id = @profit_ctr_id
	AND WorkorderDetail.company_id = @company_id 
	AND WorkorderDetail.manifest = @manifest
	
	open c_workorder_detail_2
    fetch c_workorder_detail_2 into @tsdf_approval_id, @generator_id, @wod_manifest_line
	
	while @@FETCH_STATUS = 0
	begin
		INSERT INTO FormXWasteCode
           (form_id
           ,revision_id
           ,page_number
           ,line_item
           ,waste_code_uid
           ,waste_code
           ,specifier)
		SELECT	@form_id AS form_id,
			@revision_id AS revision_id,
			wod.manifest_page_num AS page_number,
			--wod.manifest_line AS manifest_line_item,
			@wod_manifest_line,
			f.waste_code_uid,
			f.waste_code AS waste_code,
			'LDR-WO' AS specifier
		from WorkorderDetail wod,
			dbo.fn_tbl_manifest_waste_codes ('tsdfapproval', @tsdf_approval_id, @generator_id , @tsdf_code) f
			where  wod.resource_type = 'D'
			AND wod.workorder_id = @workorder_id
			AND wod.profit_ctr_id = @profit_ctr_id 
			AND wod.company_id = @company_id 
			AND wod.manifest = @manifest
		    AND wod.manifest_line = @wod_manifest_line
			AND ISNULL(f.use_for_storage,0) = 1
			AND f.display_name <> 'NONE'
			
	  fetch c_workorder_detail_2 into @tsdf_approval_id, @generator_id, @wod_manifest_line
    end
   close c_workorder_detail_2
   deallocate c_workorder_detail_2
 end 	
	
	-- Populate FormLDRSubcategory
	INSERT INTO FormLDRSubcategory (form_id, revision_id, page_number, manifest_line_item, ldr_subcategory_id)
	SELECT	@form_id AS form_id,
		@revision_id AS revision_id,
		WorkorderDetail.manifest_page_num AS page_number,
		WorkorderDetail.manifest_line AS manifest_line_item,
		LDRSubcategory.subcategory_id
	FROM WorkorderDetail
	INNER JOIN TSDFApproval
		ON TSDFApproval.TSDF_approval_id = WorkorderDetail.TSDF_approval_id
		AND TSDFApproval.profit_ctr_id = WorkorderDetail.profit_ctr_id
		AND TSDFApproval.company_id = WorkorderDetail.company_id
		AND TSDFApproval.TSDF_Approval_status = 'A'
	INNER JOIN TSDFApprovalLDRSubcategory
		ON TSDFApprovalLDRSubcategory.tsdf_approval_id = WorkorderDetail.TSDF_approval_id
	INNER JOIN LDRSubcategory
		ON LDRSubcategory.subcategory_id = TSDFApprovalLDRSubcategory.ldr_subcategory_id
	WHERE WorkorderDetail.workorder_id = @workorder_id
	AND WorkorderDetail.profit_ctr_id = @profit_ctr_id
	AND WorkorderDetail.company_id = @company_id 
	AND WorkorderDetail.manifest = @manifest
	AND WorkorderDetail.resource_type = 'D'
	
END

DROP TABLE #Tmp

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_populate_form_LDR_WO] TO [EQAI]

