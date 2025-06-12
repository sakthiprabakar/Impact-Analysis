-- drop proc sp_populate_form_LDR
GO

CREATE PROCEDURE sp_populate_form_LDR
       @form_id             int,
       @profile_id          int,
       @company_id          int,
       @profit_ctr_id       int,
--     @db_type             varchar(10),
       @added_by            varchar(60)
AS
/***************************************************************************************
Populates FormLDR tables with data from Profile 
Not used by Profile Document Creation
Load to PLT_AI
Filename:     L:\Apps\SQL\EQAI\sp_populate_form_LDR.sql
PB Object(s): 

07/18/2005 JDB       Created
06/26/2006 MK Modified to use Profile tables
10/02/2007 WAC       Removed references to a database server.
06/09/2008 KAM  Updated the procedure to allow for a null address for a Generator
03/15/2011 RWB  Modified manifest line number to numeric version,
                Removed rowguid column from inserts
04/05/2012 SK Moved to PLT_AI
08/07/2012 SK Modified for FormLDRSubcategory
04/17/2013 SK Added waste_code_UID to FormXWasteCode population
10/02/2013 SK Changed to copy only active waste codes to the form from profile
10/24/2013 AM   Modified code to insert data into FormXWasteCode from function instead of ProfileWasteCode 
08/20/2014 SM Modified code to insert waste_code instead of waste_code_uid in FormXwastecode table
01/26/2015 AM   Added new min_concentration field to FormXConstituent.
07/03/2019 MPM	Samanage 12511 - Added column list to inserts.  

sp_populate_form_LDR -7442, 193043, 21, 0, 'test', 'MARILYN'
****************************************************************************************/
DECLARE       @revision_id  int,
       @status              char(1),
       @locked              char(1),
       @approval_key int,
       @source              char(1),
       @generator_id int,
       @customer_id  int,
       @current_form_version_id   int,
       @approval_code             varchar(15),
    @tsdf_code      varchar(15)
    
SET NOCOUNT ON

SET @revision_id = 1
SET @status = 'A'
SET @locked = 'U'
SET @source = 'A'
SELECT @current_form_version_id = current_form_version FROM FormType WHERE form_type = 'LDR'

SELECT @approval_code = approval_code 
       FROM ProfileQuoteApproval 
       WHERE profile_id = @profile_id 
       AND company_id = @company_id
       AND profit_ctr_id = @profit_ctr_id 

SELECT @generator_id = generator_id,
       @customer_id = customer_id
FROM Profile
WHERE profile_id = @profile_id
AND curr_status_code IN ('A', 'H', 'P')


-- Populate FormLDR
INSERT INTO FormLDR
	(form_id, revision_id, form_version_id, customer_id_from_form, customer_id, app_id, status, locked, source, company_id, profit_ctr_id, signing_name, signing_company, signing_title, signing_date,
		date_created, date_modified, created_by, modified_by, generator_name, generator_EPA_ID, generator_address1, generator_city, generator_state, generator_zip,
		state_manifest_no, manifest_doc_no, generator_id, generator_address2, generator_address3, generator_address4, generator_address5, profitcenter_epa_id,
		profitcenter_profit_ctr_name, profitcenter_address_1, profitcenter_address_2, profitcenter_address_3, profitcenter_phone, profitcenter_fax, rowguid,
		wcr_id, wcr_rev_id)
SELECT @form_id AS form_id,
       @revision_id AS revision_id,
       @current_form_version_id AS form_version_id,
       @customer_id AS customer_id_from_form,
       @customer_id AS customer_id,
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
       NULL AS state_manifest_no,
       NULL AS manifest_doc_no,
       Generator.generator_id,
       Generator.generator_address_2,
       Generator.generator_address_3,
       Generator.generator_address_4,
       generator_address_5 = RTrim(CASE WHEN Generator.generator_id = 0 THEN ''
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
FROM Generator, ProfitCenter
WHERE ProfitCenter.profit_ctr_id = @profit_ctr_id
AND ProfitCenter.company_ID = @company_id
AND Generator.generator_id = @generator_id

-- Populate FormLDRDetail
INSERT INTO FormLDRDetail
	(form_id, revision_id, form_version_id, page_number, manifest_line_item, ww_or_nww, subcategory, manage_id,approval_code, approval_key,
		company_id, profit_ctr_id, profile_id)
SELECT @form_id AS form_id,
       @revision_id AS revision_id,
       @current_form_version_id AS form_version_id,
       1 AS page_number,
       1 AS manifest_line_item,
       CASE WHEN P.waste_water_flag = 'W' THEN 'WW' ELSE 'NWW' END AS ww_or_nww,
       P.LDR_subcategory AS subcategory,
       P.waste_managed_id AS manage_id,
       @approval_code,
       @profile_id as approval_key,
       PQA.company_id,
       @profit_ctr_id,
       P.profile_id
       --LDRSubcategory.subcategory_id
FROM Profile P
JOIN ProfileQuoteApproval PQA
       ON P.profile_id = PQA.profile_id
       AND PQA.approval_code = @approval_code 
       AND PQA.company_id = @company_id
       AND PQA.profit_ctr_id = @profit_ctr_id
--LEFT OUTER JOIN LDRSubcategory
--     ON LDRSubcategory.short_desc = P.LDR_subcategory
WHERE P.profile_id = @profile_id
AND P.curr_status_code in ('A','H','P')

-- Populate FormXConstituent
INSERT INTO FormXConstituent
	(form_id, revision_id, page_number, line_item, const_id, const_desc, concentration, min_concentration, unit, uhc, specifier)
SELECT @form_id AS form_id,
       @revision_id AS revision_id,
       1 AS page_number,
       1 AS line_item,
       PC.const_id AS const_id,
       Constituents.const_desc AS const_desc,
       PC.concentration AS concentration,
       PC.min_concentration AS min_concentration,
       PC.unit AS unit,
       PC.UHC AS UHC,
       'LDR' AS specifier 
FROM ProfileConstituent PC, Constituents
WHERE PC.const_id = Constituents.const_id
AND PC.profile_id = @profile_id
AND PC.UHC = 'T'


-- Populate FormXWasteCode
-- modify to select only federal & state waste codes
--INSERT INTO FormXWasteCode
--SELECT      @form_id AS form_id,
       --@revision_id AS revision_id,
       --1 AS page_number,
--     1 AS line_item,
       --PW.waste_code_uid,
       --PW.waste_code AS waste_code,
       --'LDR' AS specifier
--FROM ProfileWasteCode PW
--JOIN WasteCode W ON W.waste_code_uid = PW.waste_code_uid AND W.status = 'A'
--WHERE PW.profile_id = @profile_id

-- Insert data from function to avoid state waste codes which are not applicable
  SELECT @tsdf_code = tsdf_code
         FROM  TSDF
         WHERE eq_company = @company_id 
          AND eq_profit_ctr = @profit_ctr_id
          AND eq_flag = 'T' and TSDF_status = 'A'
              
   INSERT INTO FormXWasteCode
           (form_id
           ,revision_id
           ,page_number
           ,line_item
           ,waste_code
           ,specifier
           ,waste_code_uid)
     SELECT
          @form_id AS form_id,
          @revision_id AS revision_id,
          1 AS page_number,
          1 AS line_item,
          ws.waste_code as waste_code,
          'LDR'AS specifier,
          ft.waste_code_uid AS waste_code_uid
       FROM dbo.fn_tbl_manifest_waste_codes('profile',@profile_id, @generator_id ,@tsdf_code) ft, wastecode ws
      WHERE ISNULL(use_for_storage,0) = 1
              AND ft.display_name <> 'NONE'   
              AND ft.waste_code_uid = ws.waste_code_uid  
              
-- Populate FormLDRSubcategory
INSERT INTO FormLDRSubcategory (form_id, revision_id, page_number, manifest_line_item, ldr_subcategory_id)
SELECT @form_id AS form_id,
       @revision_id AS revision_id,
       1 AS page_number,
       1 AS line_item,
       PLS.ldr_subcategory_id
FROM ProfileLDRSubcategory PLS
WHERE PLS.profile_id = @profile_id
GO

GRANT EXECUTE
    ON OBJECT::[dbo].[sp_populate_form_LDR] TO [EQAI]
    AS [dbo];
