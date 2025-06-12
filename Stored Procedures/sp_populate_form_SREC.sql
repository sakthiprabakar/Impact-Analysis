CREATE PROCEDURE sp_populate_form_SREC
	@form_id		int,
	@profile_id		int,
	@company_id		int,
	@profit_ctr_id	int,
	@added_by		varchar(60)
AS
/***************************************************************************************
Populates FormSREC tables with data from Profile
Loads to:	PLT_AI
Filename:	L:\Apps\SQL\EQAI\sp_populate_form_SREC.sql
PB Object(s):	

07/18/2005 JDB	Created
06/26/2006 MK	Modified to use Profile tables
10/02/2007 WAC	Removed references to the database server.
06/09/2008 KAM  Updated the procedure to allow for a null address for a Generator
10/13/2011 SK	Moved to plt_AI
10/17/2011 SK	Added Profile Waste Codes primary & secondary 
05/17/2012 SK	Waste codes should go into FormXWastecode
05/21/2012 SK	Added new fields in FormSREC qty_units_desc, disposal_date
05/25/2012 SK	Added WCR_ID & WCR_REV_ID
06/08/2012 SK   Corrected to use the srec_exempt_id from ProfileQuoteApproval
04/17/2013 SK	Added waste_code_UID to FormXWasteCode
10/02/2013 SK	Changed to copy only active waste codes to the form from profile
02/28/2020 MPM	DevOps 14330 - Added column list to inserts.  

sp_populate_form_SREC -378166, 24575, NULL, NULL, 'SK'
Delete from FormSREC where form_id = -378166
delete from FormXWastecode where form_id = -378166

Select MIN(Form_id) From FormSREC
****************************************************************************************/
DECLARE	
	@revision_id	int,
	@status			char(1),
	@locked			char(1),
	@approval_key	int,
	@source			char(1),
	@current_form_version_id	int,
	@approval_code	varchar(15)

SET NOCOUNT ON

SET @revision_id = 1
SET @status = 'A'
SET @locked = 'U'
SET @source = 'A'
SELECT @current_form_version_id = current_form_version FROM FormType WHERE form_type = 'SREC'


SELECT @approval_code = approval_code 
	FROM ProfileQuoteApproval 
	WHERE profile_id = @profile_id 
	AND company_id = @company_id
	AND profit_ctr_id = @profit_ctr_id 

INSERT INTO FormSREC
	(form_id, revision_id, form_version_id, customer_id_from_form, customer_id, app_id, status, locked, source, approval_code, approval_key, company_id, profit_ctr_id,
		signing_name, signing_company, signing_title, signing_date, date_created, date_modified, created_by, modified_by, exempt_id, waste_type, waste_common_name, manifest,
		cust_name, generator_name, EPA_ID, generator_id, gen_mail_addr1, gen_mail_addr2, gen_mail_addr3, gen_mail_addr4, gen_mail_addr5, gen_mail_city, gen_mail_state,
		gen_mail_zip_code, profitcenter_epa_id, profitcenter_profit_ctr_name, profitcenter_address_1, profitcenter_address_2, profitcenter_address_3, profitcenter_phone, 
		profitcenter_fax, rowguid, profile_id, qty_units_desc, disposal_date, wcr_id, wcr_rev_id)
SELECT	@form_id AS form_id,
	@revision_id AS revision_id,
	@current_form_version_id AS form_version_id,
	P.customer_id AS customer_id_from_form,
	P.customer_id AS customer_id,
	NULL AS app_id,
	@status AS status,
	@locked AS locked,
	@source AS source,
	PQA.approval_code,
	@profile_id as approval_key,
	PQA.company_id,
	@profit_ctr_id,
	NULL AS signing_name,
	NULL AS signing_company,
	NULL AS signing_title,
	NULL AS signing_date,
	GETDATE() AS date_created,
	GETDATE() AS date_modified,
	@added_by AS created_by,
	@added_by AS modified_by,
	PQA.srec_exempt_id AS exempt_id,
	NULL AS waste_type,
	P.approval_desc AS waste_common_name,
	NULL AS manifest,
	Customer.cust_name,
	Generator.generator_name,
	Generator.EPA_ID,
	P.generator_id,
	Generator.gen_mail_addr1 AS gen_mail_addr1,
	Generator.gen_mail_addr2 AS gen_mail_addr2,
	Generator.gen_mail_addr3 AS gen_mail_addr3,
	Generator.gen_mail_addr4 AS gen_mail_addr4,
		gen_mail_addr5 = RTrim(CASE WHEN P.generator_id = 0 THEN ''
									WHEN (Generator.gen_mail_city + ', ' + Generator.gen_mail_state + ' ' + IsNull(Generator.gen_mail_zip_code,'')) = ', ' THEN 'Missing Mailing City, State and Zip Code'
									ELSE (Generator.gen_mail_city + ', ' + Generator.gen_mail_state + ' ' + IsNull(Generator.gen_mail_zip_code,'')) END),
	Generator.gen_mail_city AS gen_mail_city,
	Generator.gen_mail_state AS gen_mail_state,
	Generator.gen_mail_zip_code AS gen_mail_zip_code,
	ProfitCenter.EPA_ID AS profitcenter_epa_id,
	ProfitCenter.profit_ctr_name AS profitcenter_profit_ctr_name,
	ProfitCenter.address_1 AS profitcenter_address_1,
	ProfitCenter.address_2 AS profitcenter_address_2,
	ProfitCenter.address_3 AS profitcenter_address_3,
	ProfitCenter.phone AS profitcenter_phone,
	ProfitCenter.fax AS profitcenter_fax,
	NEWID(),
	P.profile_id,
	NULL AS qty_units_desc,
	NULL AS disposal_date,
	NULL AS wcr_id,
	NULL AS wcr_rev_id
FROM Profile P
LEFT OUTER JOIN ProfileQuoteApproval PQA
	ON PQA.profile_id = P.profile_id
	AND PQA.approval_code = @approval_code 
	AND PQA.company_id = @company_id
	AND PQA.profit_ctr_id = @profit_ctr_id 
JOIN Customer
	ON Customer.customer_id  = P.customer_id
JOIN Generator
	ON Generator.generator_id = P.generator_id
LEFT OUTER JOIN ProfitCenter
	ON ProfitCenter.company_ID = PQA.company_id
	AND ProfitCenter.profit_ctr_ID = PQA.profit_ctr_id
WHERE P.profile_id = @profile_id
AND P.curr_status_code in ('A','H','P')

-- Populate FormXWasteCode
INSERT INTO FormXWasteCode
(form_id, revision_id, page_number, line_item, waste_code_uid, waste_code, specifier, lock_flag)
SELECT	@form_id AS form_id,
	@revision_id AS revision_id,
	NULL AS page_number,
	NULL AS line_item,
	PW.waste_code_uid,
	PW.waste_code AS waste_code,
	specifier = CASE PW.primary_flag WHEN 'T' THEN 'primary' ELSE 'secondary' END,
	'F'
FROM ProfileWasteCode PW
JOIN WasteCode W ON W.waste_code_uid = PW.waste_code_uid AND W.status = 'A'
WHERE PW.profile_id = @profile_id


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_populate_form_SREC] TO [EQAI]
    AS [dbo];

