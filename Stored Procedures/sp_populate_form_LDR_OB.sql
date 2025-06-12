drop procedure if exists dbo.sp_populate_form_ldr_ob
go

CREATE PROCEDURE dbo.sp_populate_form_LDR_OB
	@form_id		int,
	@receipt_id 	int,
	@company_id		INT,
	@profit_ctr_id	int,
	@manifest		varchar(30),
	@added_by		varchar(60),
	@lines_to_include	varchar(100) = ''
AS
/***************************************************************************************
Populates FormLDR tables with data from outbound receipt
Load to PLt_AI
Filename:	L:\Apps\SQL\EQAI\sp_populate_form_LDR_OB.sql
PB Object(s):	
03/15/2018 - AM - New creation for OB Receipt LDR.
07/03/2019 MPM	Samanage 12511 - Added column list to inserts and also corrected the 
				insert into FormXWasteCode for EQ TSDF's.
10/20/2022 MPM	DevOps 42183 - Replaced calls to fn_tbl_manifest_waste_codes with calls to 
				fn_tbl_mainfest_waste_codes_receipt_wo, so that only the waste codes on a 
				receipt line that are selected (i.e., the checkbox is checked) are included on the 
				"Waste Codes:" section of the LDR.
11/18/2022 MPM	DevOps 42183 - Reverted the changes made under 42183.

sp_populate_form_LDR_OB 10617554, 586, 14, 9, null, 'ANITHA_M', '1,2,3'
sp_populate_form_LDR_OB -991152, 2036218 , 21, 0, null, 'MARTHA_M', '1'

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

-- Populate FormLDR
INSERT INTO FormLDR
	(form_id, revision_id, form_version_id, customer_id_from_form, customer_id, app_id, status, locked, source, company_id, profit_ctr_id, signing_name, signing_company, signing_title, signing_date,
		date_created, date_modified, created_by, modified_by, generator_name, generator_EPA_ID, generator_address1, generator_city, generator_state, generator_zip,
		state_manifest_no, manifest_doc_no, generator_id, generator_address2, generator_address3, generator_address4, generator_address5, profitcenter_epa_id,
		profitcenter_profit_ctr_name, profitcenter_address_1, profitcenter_address_2, profitcenter_address_3, profitcenter_phone, profitcenter_fax, rowguid,
		wcr_id, wcr_rev_id)
SELECT Distinct	@form_id AS form_id,
	@revision_id AS revision_id,
	@current_form_version_id AS form_version_id,
	Receipt.customer_id AS customer_id_from_form,
	Receipt.customer_id AS customer_id,
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
	Receipt.manifest, -- manifest_doc_no will store the manifest
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
	cast(cast(0 as binary) as uniqueidentifier),
	NULL,
	NULL
FROM Receipt
JOIN dbo.ProfitCenter 
	ON ProfitCenter.profit_ctr_id = Receipt.profit_ctr_id
	AND ProfitCenter.company_ID = Receipt.company_id
LEFT OUTER JOIN Generator
	ON  Receipt.generator_id = Generator.generator_id
LEFT OUTER JOIN Customer
	ON  Receipt.customer_id = Customer.customer_id	
WHERE Receipt.receipt_id = @receipt_id
AND Receipt.profit_ctr_id = @profit_ctr_id
AND Receipt.company_id = @company_id
--AND Receipt.manifest = @manifest
AND Receipt.trans_mode = 'O'
AND Receipt.trans_type = 'D'

-- Get TSDF code
SELECT @tsdf_code = TSDF_code
FROM Receipt 
WHERE Receipt.trans_type = 'D'
AND Receipt.trans_mode = 'O'
AND Receipt.receipt_id = @receipt_id
AND Receipt.profit_ctr_id = @profit_ctr_id
AND Receipt.company_id = @company_id
--AND Receipt.manifest = @manifest
GROUP BY TSDF_code

-- Get EQ company/profit center
SELECT	@tsdf_company = eq_company,
	@tsdf_profit_ctr_id = eq_profit_ctr,
	@eq_flag = IsNull(eq_flag,'F')
FROM TSDF
WHERE TSDF_code = @tsdf_code


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
    ,       Receipt.manifest_page_num AS page_number
    ,       Receipt.manifest_line AS manifest_line_item
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
	FROM Receipt
	JOIN #Tmp ON Receipt.line_id = #Tmp.LineNum
	JOIN Profile P
		ON Receipt.ob_profile_id = P.profile_id
	JOIN ProfileQuoteApproval PQA
		ON Receipt.OB_profile_company_ID = PQA.company_id
		AND Receipt.OB_profile_profit_ctr_id = PQA.profit_ctr_id
 		AND Receipt.OB_profile_ID = PQA.profile_id
 		AND PQA.status = 'A'
	--LEFT OUTER JOIN LDRSubcategory
	--	ON LDRSubcategory.short_desc = P.LDR_subcategory
	WHERE Receipt.receipt_id = @receipt_id
	AND Receipt.profit_ctr_id = @profit_ctr_id
	AND Receipt.company_id = @company_id
	AND Receipt.manifest_line = #Tmp.LineNum 
	--AND Receipt.manifest = @manifest
	AND Receipt.trans_mode = 'O'
	AND Receipt.trans_type = 'D'

	-- Populate FormXConstituent
	INSERT INTO FormXConstituent
		(form_id, revision_id, page_number, line_item, const_id, const_desc, concentration, min_concentration, unit, uhc, specifier)
	SELECT	@form_id AS form_id,
		@revision_id AS revision_id,
		Receipt.manifest_page_num AS page_number,
		Receipt.manifest_line AS manifest_line_item,
		ProfileConstituent.const_id AS const_id,
		Constituents.const_desc AS const_desc,
		ProfileConstituent.concentration AS concentration,
		ProfileConstituent.min_concentration AS min_concentration,
		ProfileConstituent.unit AS unit,
		ProfileConstituent.UHC AS UHC,
		'LDR-WO' AS specifier
	FROM ProfileConstituent, ProfileQuoteApproval PQA, Constituents, Receipt
	WHERE Receipt.OB_profile_ID = ProfileConstituent.profile_id
 	AND Receipt.OB_profile_company_ID = PQA.company_id
	AND Receipt.OB_profile_profit_ctr_id = PQA.profit_ctr_id
 	AND ProfileConstituent.profile_id = PQA.profile_id
	AND ProfileConstituent.const_id = Constituents.const_id
	AND ProfileConstituent.UHC = 'T'
	AND PQA.status = 'A'
--	AND PQA.LDR_req_flag = 'T'
	AND Receipt.receipt_id = @receipt_id
	AND Receipt.profit_ctr_id = @profit_ctr_id
	AND Receipt.company_id = @company_id
	--AND Receipt.manifest = @manifest
	AND Receipt.trans_mode = 'O'
	AND Receipt.trans_type = 'D'
	
 begin		
	declare c_receipt cursor read_only forward_only for
	SELECT p.profile_id ,
	       p.generator_id,
	       receipt.manifest_line
	FROM receipt
	JOIN #Tmp ON receipt.line_id = #Tmp.LineNum
	JOIN Profile P
		ON receipt.OB_profile_ID = P.profile_id
	JOIN ProfileQuoteApproval PQA
		ON receipt.OB_profile_company_ID = PQA.company_id
		AND receipt.OB_profile_profit_ctr_id = PQA.profit_ctr_id
 		AND P.profile_id = PQA.profile_id
 		AND PQA.status = 'A'
	WHERE Receipt.receipt_id = @receipt_id
	AND Receipt.profit_ctr_id = @profit_ctr_id
	AND Receipt.company_id = @company_id
	--AND Receipt.manifest = @manifest
	AND Receipt.manifest_line = #Tmp.LineNum
	AND Receipt.trans_mode = 'O'
	AND Receipt.trans_type = 'D'
	
	open c_receipt
    fetch c_receipt into @profile_id, @generator_id, @wod_manifest_line

	while @@FETCH_STATUS = 0
	begin
	
		INSERT INTO FormXWasteCode
           (form_id
           ,revision_id
           ,page_number
           ,line_item
           ,waste_code
           ,specifier
           ,waste_code_uid)
		SELECT	@form_id AS form_id,
			@revision_id AS revision_id,
			Receipt.manifest_page_num AS page_number,
			--wod.manifest_line AS manifest_line_item,
			@wod_manifest_line,
			f.waste_code AS waste_code,
			'LDR-OB' AS specifier,
			f.waste_code_uid
		from Receipt,
			dbo.fn_tbl_manifest_waste_codes ('profile', @profile_id, @generator_id , @tsdf_code) f
			where Receipt.receipt_id = @receipt_id
			AND Receipt.profit_ctr_id = @profit_ctr_id
			AND Receipt.company_id = @company_id
			--AND Receipt.manifest = @manifest
			AND Receipt.trans_mode = 'O'
			AND Receipt.trans_type = 'D'
			AND Receipt.manifest_line = @wod_manifest_line
			AND ISNULL(f.use_for_storage,0) = 1
			AND f.display_name <> 'NONE'
			
	   fetch c_receipt into @profile_id, @generator_id, @wod_manifest_line
    end
   close c_receipt
   deallocate c_receipt 
end	
	-- Populate FormLDRSubcategory
	INSERT INTO FormLDRSubcategory (form_id, revision_id, page_number, manifest_line_item, ldr_subcategory_id)
	SELECT	@form_id AS form_id,
		@revision_id AS revision_id,
		Receipt.manifest_page_num AS page_number,
		Receipt.manifest_line AS manifest_line_item,
		ProfileLDRSubcategory.ldr_subcategory_id
	FROM ProfileLDRSubcategory, ProfileQuoteApproval PQA, Receipt
	WHERE Receipt.OB_profile_ID = ProfileLDRSubcategory.profile_id
 	AND Receipt.OB_profile_company_ID = PQA.company_id
	AND Receipt.OB_profile_profit_ctr_id = PQA.profit_ctr_id
 	AND ProfileLDRSubcategory.profile_id = PQA.profile_id
	AND PQA.status = 'A'
	AND Receipt.receipt_id = @receipt_id
	AND Receipt.profit_ctr_id = @profit_ctr_id
	AND Receipt.company_id = @company_id
	--AND Receipt.manifest = @manifest
	AND Receipt.trans_mode = 'O'
	AND Receipt.trans_type = 'D'
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
		Receipt.manifest_page_num AS page_number,
		Receipt.manifest_line AS manifest_line_item,
		CASE WHEN TSDFApproval.waste_water_flag = 'W' THEN 'WW' ELSE 'NWW' END AS ww_or_nww,
		TSDFApproval.LDR_subcategory AS subcategory,
		TSDFApproval.waste_managed_id AS manage_id,
		TSDFApproval.TSDF_approval_code,
		NULL AS approval_key,
		@company_id ,
		@profit_ctr_id,
		TSDFApproval.TSDF_approval_id
	FROM Receipt
	JOIN #Tmp ON Receipt.line_id = #Tmp.LineNum
	JOIN TSDFApproval
		ON Receipt.TSDF_approval_id = TSDFApproval.TSDF_approval_id
		AND Receipt.profit_ctr_id = TSDFApproval.profit_ctr_id
		AND Receipt.company_id = TSDFApproval.company_id
		AND TSDFApproval.TSDF_Approval_status = 'A'
	JOIN TSDF
		ON TSDFApproval.TSDF_code = TSDF.TSDF_code
		AND IsNull(TSDF.eq_flag,'F') = 'F'
	LEFT OUTER JOIN LDRSubcategory
		ON LDRSubcategory.short_desc = TSDFApproval.LDR_subcategory
	WHERE Receipt.receipt_id = @receipt_id
	AND Receipt.profit_ctr_id = @profit_ctr_id
	AND Receipt.company_id = @company_id
	--AND Receipt.manifest = @manifest
	AND Receipt.manifest_line = #Tmp.LineNum
	AND Receipt.trans_mode = 'O'
	AND Receipt.trans_type = 'D'
	
	-- Populate FormXConstituent
	INSERT INTO FormXConstituent
	 	(form_id, revision_id, page_number, line_item, const_id, const_desc, concentration, min_concentration, unit, uhc, specifier)
	SELECT	@form_id AS form_id,
		@revision_id AS revision_id,
		Receipt.manifest_page_num AS page_number,
		Receipt.manifest_line AS manifest_line_item,
		TSDFApprovalConstituent.const_id AS const_id,
		Constituents.const_desc AS const_desc,
		TSDFApprovalConstituent.concentration AS concentration,
		TSDFApprovalConstituent.concentration AS min_concentration,
		TSDFApprovalConstituent.unit AS unit,
		TSDFApprovalConstituent.UHC AS UHC,
		'LDR-OB' AS specifier
	FROM TSDFApproval, TSDFApprovalConstituent, Constituents, Receipt
	WHERE TSDFApprovalConstituent.TSDF_approval_id = TSDFApproval.TSDF_approval_id
	AND Receipt.TSDF_approval_id = TSDFApproval.TSDF_approval_id
	AND Receipt.profit_ctr_id = TSDFApproval.profit_ctr_id
	AND Receipt.company_id = TSDFApproval.company_id
	AND TSDFApprovalConstituent.const_id = Constituents.const_id
	AND TSDFApprovalConstituent.UHC = 'T'
	AND TSDFApproval.TSDF_Approval_status = 'A'
--	AND TSDFapproval.LDR_required = 'T'
	AND Receipt.receipt_id = @receipt_id
	AND Receipt.profit_ctr_id = @profit_ctr_id
	AND Receipt.company_id = @company_id
	--AND Receipt.manifest = @manifest
	AND Receipt.trans_mode = 'O'
	AND Receipt.trans_type = 'D'
	
 begin	
	declare c_receipt_2 cursor read_only forward_only for
   
	    SELECT TSDFApproval.tsdf_approval_id ,
	           r.generator_id,
	           r.manifest_line
	    FROM TSDFApproval 
	INNER JOIN Receipt r ON TSDFApproval.TSDF_approval_id = r.TSDF_approval_id
		AND TSDFApproval.profit_ctr_id = r.profit_ctr_id
		AND TSDFApproval.company_id = r.company_id
   	WHERE TSDFApproval.TSDF_Approval_status = 'A'
	AND r.receipt_id = @receipt_id
	AND r.profit_ctr_id = @profit_ctr_id
	AND r.company_id = @company_id
	--AND r.manifest = @manifest
	AND r.trans_mode = 'O'
	AND r.trans_type = 'D'
	
	open c_receipt_2
    fetch c_receipt_2 into @tsdf_approval_id, @generator_id, @wod_manifest_line
	
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
			r.manifest_page_num AS page_number,
			--wod.manifest_line AS manifest_line_item,
			@wod_manifest_line,
			f.waste_code_uid,
			f.waste_code AS waste_code,
			'LDR-OB' AS specifier
		from receipt r,
			dbo.fn_tbl_manifest_waste_codes ('tsdfapproval', @tsdf_approval_id, @generator_id , @tsdf_code) f
			where r.receipt_id = @receipt_id
			AND r.profit_ctr_id = @profit_ctr_id
			AND r.company_id = @company_id
			--AND r.manifest = @manifest
			AND r.trans_mode = 'O'
			AND r.trans_type = 'D'
		    AND r.manifest_line = @wod_manifest_line
			AND ISNULL(f.use_for_storage,0) = 1
			AND f.display_name <> 'NONE'
			
	  fetch c_receipt_2 into @tsdf_approval_id, @generator_id, @wod_manifest_line
    end
   close c_receipt_2
   deallocate c_receipt_2 
 end 	
	
	-- Populate FormLDRSubcategory
	INSERT INTO FormLDRSubcategory (form_id, revision_id, page_number, manifest_line_item, ldr_subcategory_id)
	SELECT	@form_id AS form_id,
		@revision_id AS revision_id,
		Receipt.manifest_page_num AS page_number,
		Receipt.manifest_line AS manifest_line_item,
		LDRSubcategory.subcategory_id
	FROM Receipt
	INNER JOIN TSDFApproval
		ON TSDFApproval.TSDF_approval_id = Receipt.TSDF_approval_id
		AND TSDFApproval.profit_ctr_id = Receipt.profit_ctr_id
		AND TSDFApproval.company_id = Receipt.company_id
		AND TSDFApproval.TSDF_Approval_status = 'A'
	INNER JOIN TSDFApprovalLDRSubcategory
		ON TSDFApprovalLDRSubcategory.tsdf_approval_id = Receipt.TSDF_approval_id
	INNER JOIN LDRSubcategory
		ON LDRSubcategory.subcategory_id = TSDFApprovalLDRSubcategory.ldr_subcategory_id
	WHERE Receipt.receipt_id = @receipt_id
	AND Receipt.profit_ctr_id = @profit_ctr_id
	AND Receipt.company_id = @company_id
	--AND Receipt.manifest = @manifest
	AND Receipt.trans_mode = 'O'
	AND Receipt.trans_type = 'D'
	
END

DROP TABLE #Tmp

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_populate_form_LDR_OB] TO [EQAI]

