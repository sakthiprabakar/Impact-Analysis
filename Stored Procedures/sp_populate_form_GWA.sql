CREATE PROCEDURE sp_populate_form_GWA
	@form_id			int,
	@profile_id			int,
	@added_by			varchar(60),
	@contact_id			int
AS
/***************************************************************************************
Populates FormGWA tables with data from Profile
Loads to:	PLT_AI
Filename:	L:\Apps\SQL\EQAI\sp_populate_form_GWA.sql
PB Object(s):	

07/07/2005 JDB	Created
06/26/2006 MK	Modified to use Profile tables
10/02/2007 WAC	Removed references to a database server.
06/09/2008 KAM  Updated the procedure to allow for a null address for a Generator
10/13/2011 SK	Moved to Plt_AI
				Added new fields : ap_expiration_date, cust_fax
10/17/2011 SK	Rewrote the sp to populate all approval-facilities data for a selected profile.
				No longer needs company, profit_ctr_id, approval_code as input args.
				The approval-facilities data comes from ProfileQuoteApproval & go into FORMXApproval
04/05/2012 SK	Updated  FormXApproval Info for new columns
				Added missing cols for gen contact & gen mail name
08/09/2012 SK	Updated for the new field reapproval_profile_change		
08/21/2012 SK	Waste codes should be inserted into FormXWastecodes for every form		
08/22/2012 SK	Fixed the contact info
10/22/2012 SK	Changed to have Outer Join to the Waste Code, create a form anyway .
04/17/2013 SK	Added waste_code_UID to FormXWasteCode
07/24/2013 SK	Added TAB to populate FormGWA, Do NOT put the Generator.TAB in it
08/22/2013 SK	Primary waste code on Profile joins to WasteCode. This was changed to join on waste_code_uid
10/02/2013 SK	Changed to copy only active waste codes to the form from profile
02/28/2020 MPM	DevOps 14330 - Added column list to inserts. 

select * from FormXWastecode where form_id = 0
Select * from FormXApproval where form_type = 'GWA' and form_id = 0

sp_populate_form_GWA 0, 343472, SK
sp_columns FormGWA
****************************************************************************************/
DECLARE	
	@revision_id	int,
	@status			char(1),
	@locked			char(1),
	@approval_key	int,
	@source			char(1),
	@contact_name	varchar(40),
	@current_form_version_id	int

SET NOCOUNT ON

SET @revision_id = 1
SET @status = 'A'
SET @locked = 'U'
SET @source = 'A'
SELECT @current_form_version_id = current_form_version FROM FormType WHERE form_type = 'GWA'

SELECT @contact_name = name FROM Contact WHERE contact_ID = @contact_id AND contact_status = 'A'

INSERT INTO FormGWA
(form_id, revision_id, form_version_id, customer_id_from_form, customer_id, app_id, status, locked, source, approval_code, approval_key, company_id, profit_ctr_id, signing_name, signing_company, signing_title,
	signing_date, date_created, date_modified, created_by, modified_by, generator_name, EPA_ID, generator_id, generator_address1, cust_name, cust_addr1, inv_contact_name, inv_contact_phone, inv_contact_fax,
	tech_contact_name, tech_contact_phone, tech_contact_fax, waste_common_name, waste_code_comment, amendment, gen_mail_addr1, gen_mail_addr2, gen_mail_addr3, gen_mail_addr4, gen_mail_addr5, gen_mail_city,
	gen_mail_state, gen_mail_zip_code, profitcenter_epa_id, profitcenter_profit_ctr_name, profitcenter_address_1, profitcenter_address_2, profitcenter_address_3, profitcenter_phone, profitcenter_fax, waste_code,
	secondary_waste_code_list, rowguid, profile_id, ap_expiration_date, cust_fax, reapproval_profile_change, contact_id, contact_name, cust_addr2, cust_addr3, cust_addr4, cust_city, cust_state, cust_zip_code,
	TAB)
SELECT	@form_id AS form_id,
	@revision_id AS revision_id,
	@current_form_version_id AS form_version_id,
	P.customer_id AS customer_id_from_form,
	P.customer_id AS customer_id,
	NULL AS app_id,
	@status AS status,
	@locked AS locked,
	@source AS source,
	--PQA.approval_code, SK field moved to FormXApproval
	NULL,
	@profile_id as approval_key,
	--PQA.company_id,  SK field moved to FormXApproval
	-- @profit_ctr_id, SK field moved to FormXApproval
	NULL, NULL,
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
	P.generator_id,
	Generator.generator_address_1,
	Customer.cust_name,
	Customer.cust_addr1,
	NULL AS inv_contact_name,
	NULL AS inv_contact_phone,
	NULL AS inv_contact_fax,
	NULL AS tech_contact_name,
	NULL AS tech_contact_phone,
	NULL AS tech_contact_fax,
	P.approval_desc AS waste_common_name,
	WasteCode.waste_code_desc AS waste_code_comment,
	NULL AS amendment,
	Generator.gen_mail_addr1 AS gen_mail_addr1,
	Generator.gen_mail_addr2 AS gen_mail_addr2,
	Generator.gen_mail_addr3 AS gen_mail_addr3,
	Generator.gen_mail_addr4 AS gen_mail_addr4,
	gen_mail_addr5 = RTrim(CASE 	WHEN P.generator_id = 0 THEN '' 
											WHEN (Generator.gen_mail_city + ', ' + Generator.gen_mail_state + ' ' + IsNull(Generator.gen_mail_zip_code,'')) = ', ' THEN 'Missing Mailing City, State and Zip Code'
											ELSE (Generator.gen_mail_city + ', ' + Generator.gen_mail_state + ' ' + IsNull(Generator.gen_mail_zip_code,'')) END),
	Generator.gen_mail_city AS gen_mail_city,
	Generator.gen_mail_state AS gen_mail_state,
	Generator.gen_mail_zip_code AS gen_mail_zip_code,
	--ProfitCenter.EPA_ID AS profitcenter_epa_id, SK field moved to FormXApproval
	--ProfitCenter.profit_ctr_name AS profitcenter_profit_ctr_name, SK field moved to FormXApproval
	--ProfitCenter.address_1 AS profitcenter_address_1,	SK field dropped
	--ProfitCenter.address_2 AS profitcenter_address_2, SK field dropped
	--ProfitCenter.address_3 AS profitcenter_address_3, SK field dropped
	--ProfitCenter.phone AS profitcenter_phone,			SK field dropped
	--ProfitCenter.fax AS profitcenter_fax,				SK field dropped
	NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
	--P.waste_code AS waste_code, Moved to formXwastecode
	--secondary_waste_code_list = dbo.fn_sec_waste_code_list(@profile_id),
	NEWID(),
	@profile_id,
	P.ap_expiration_date,
	Customer.cust_fax,
	'PC' AS reapproval_profile_change,
	@contact_id AS contact_id,
	Contact_name = @contact_name,
	Customer.cust_addr2, 
	Customer.cust_addr3, 
	Customer.cust_addr4, 
	Customer.cust_city, 
	Customer.cust_state, 
	Customer.cust_zip_code,
	NULL
FROM Profile P
JOIN Customer
	ON Customer.customer_id = P.customer_id
JOIN Generator
	ON Generator.generator_id = P.generator_id
LEFT OUTER JOIN WasteCode
	ON WasteCode.waste_code_uid = P.waste_code_uid
WHERE P.profile_id = @profile_id
	AND P.curr_status_code in ('A','H','P')
	
	
/******* Populate FormXApproval for this formID ****/
INSERT INTO FormXApproval
(form_type, form_id, revision_id, company_id, profit_ctr_id, profile_id, approval_code, profit_ctr_name, profit_ctr_EPA_ID, insurance_surcharge_percent, ensr_exempt, quotedetail_comment)
SELECT
	'GWA',
	@form_id,
	@revision_id,
	PQA.company_id,
	PQA.profit_ctr_id,
	@profile_id,
	PQA.approval_code,
	ProfitCenter.profit_ctr_name,
	ProfitCenter.EPA_ID,
	NULL,
	NULL,
	NULL
FROM ProfileQuoteApproval PQA
JOIN ProfitCenter
	ON ProfitCenter.company_ID = PQA.company_id
	AND ProfitCenter.profit_ctr_ID = PQA.profit_ctr_id
WHERE PQA.profile_id = @profile_id	

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
    ON OBJECT::[dbo].[sp_populate_form_GWA] TO [EQAI]
    AS [dbo];

