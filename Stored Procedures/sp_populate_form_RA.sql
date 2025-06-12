CREATE PROCEDURE sp_populate_form_RA
	@form_id		int,
	@profile_id		int,
	@added_by		varchar(60),
	@contact_id		int
AS
/***************************************************************************************
Populates FormRA tables with data from Profile
Loads to:	PLT_AI
Filename:	L:\Apps\SQL\EQAI\sp_populate_form_RA.sql
PB Object(s):	

06/28/2005 JDB	Created
06/26/2006 MK	Modified to use Profile tables
10/02/2007 WAC	Removed references to a database server
10/05/2007 JDB	Corrected bad join (needed to use ProfitCenter)
10/13/2011 SK	Moved to PLT_AI
				removed left outer join from customer to contact, invalid col: primary_contact_id
10/17/2011 SK	Rewrote the sp to populate all approval-facilities data for a selected profile.
				No longer needs company, profit_ctr_id, approval_code as input args.
				The approval-facilities data comes from ProfileQuoteApproval & go into FORMXApproval
04/05/2012 SK	Upodated  FormXApproval Info for new columns
05/23/2012 SK	Corrected to look at only active Profilelab records
08/09/2012 SK	Updated to insert null into FormXApproval.insurance_surcharge_percent & FormXApproval.ensr_exempt
				as this sp does not need to use them
08/21/2012 SK	Waste codes should be inserted into FormXWastecodes for every form
10/04/2012 SK	Updated to exclude inactive approvals	
04/17/2013 SK	Added Waste_code_UID to FormXWasteCode
07/24/2013 SK	Do not populate Generator.TAB into FormRA.tab
08/22/2013 SK	Changed the join on profile primary waste code to waste_code_uid
10/02/2013 SK	Changed to copy only active waste codes to the form from profile
02/28/2020 MPM	DevOps 14330 - Added column list to inserts. 
				
sp_populate_form_RA -888893, 194421, SK, 1
Select * from FormRA where form_id = - 888892
select * from FormXApproval where form_id = -888892
****************************************************************************************/
SET NOCOUNT ON

DECLARE	
	@revision_id	int,
	@status			char(1),
	@locked			char(1),
	@source			char(1),
	@approval_key	int,
	@contact_name	varchar(40),
	@current_form_version_id	int
	
SET @revision_id = 1
SET @status = 'A'
SET @locked = 'U'
SET @source = 'A'
SELECT @current_form_version_id = current_form_version FROM FormType WHERE form_type = 'RA'

SELECT @contact_name = name FROM Contact WHERE contact_ID = @contact_id AND contact_status = 'A'

INSERT INTO FormRA
(form_id, revision_id, form_version_id, customer_id, status, locked, source, approval_code, approval_key, company_id, profit_ctr_id, signing_name, signing_company, signing_title, 
	signing_date, date_created, date_modified, created_by, modified_by, approval_ots_flag, approval_waste_code, approval_ap_expiration_date, generator_generator_name, wastecode_waste_code_desc,
	approval_approval_desc, customer_cust_addr1, customer_cust_addr2, customer_cust_addr3, customer_cust_addr4, customer_cust_city, customer_cust_state, customer_cust_zip_code, customer_cust_name,
	contact_id, contact_name, customer_cust_fax, generator_id, generator_epa_id, profitcenter_profit_ctr_name, profitcenter_address_1, profitcenter_address_2, profitcenter_address_3,
	profitcenter_phone, profitcenter_fax, profitcenter_epa_id, rowguid, profile_id, TAB, benzene)
SELECT	@form_id,
	@revision_id,
	@current_form_version_id,
	Customer.customer_id, 
	@status,
	@locked,
	@source,
	--@approval_code, SK field moved to FormXApproval
	NULL,
	@profile_id as approval_key,
	--PQA.company_id, SK field moved to FormXApproval
	--@profit_ctr_id, SK field moved to FormXApproval
	NULL, NULL,
	NULL AS signing_name,
	NULL AS signing_company,
	NULL AS signing_title,
	NULL AS signing_date,
	GETDATE() AS date_created,
	GETDATE() AS date_modified,
	@added_by,
	@added_by,
	P.OTS_flag,
	P.waste_code,
	P.ap_expiration_date,
	Generator.generator_name,
	WasteCode.waste_code_desc, 
	P.approval_desc, 
	Customer.cust_addr1, 
	Customer.cust_addr2, 
	Customer.cust_addr3, 
	Customer.cust_addr4, 
	Customer.cust_city, 
	Customer.cust_state, 
	Customer.cust_zip_code, 
	Customer.cust_name, 
	@contact_id AS contact_id,
	Contact_name = @contact_name,
	Customer.cust_fax, 
	Generator.generator_id,
	Generator.EPA_ID,
	--ProfitCenter.profit_ctr_name, SK field moved to FormXApproval
	--ProfitCenter.address_1, SK field dropped
	--ProfitCenter.address_2, SK field dropped
	--ProfitCenter.address_3, SK field dropped
	--ProfitCenter.phone, SK field dropped
	--ProfitCenter.fax, SK field dropped
	--ProfitCenter.EPA_ID, SK field moved to FormXApproval
	NULL, NULL, NULL, NULL, NULL, NULL, NULL,
	NEWID(),
	P.profile_id,
	NULL,
	PL.benzene
FROM Profile P
INNER JOIN Customer 
	ON Customer.customer_id = P.customer_id
INNER JOIN Generator 
	ON P.generator_id = Generator.generator_id
INNER JOIN WasteCode 
	ON P.waste_code_uid = WasteCode.waste_code_uid
INNER JOIN ProfileLab PL
	ON PL.profile_id = P.profile_id	
	AND PL.type = 'A'
WHERE P.profile_id = @profile_id
	AND P.curr_status_code IN ('A','H','P')
GROUP BY Customer.customer_id,
	Generator.EPA_ID,
	Generator.generator_id, 
	Customer.cust_name, 
	Customer.cust_addr1, 
	Customer.cust_addr2, 
	Customer.cust_addr3, 
	Customer.cust_addr4, 
	Customer.cust_city, 
	Customer.cust_state, 
	Customer.cust_zip_code, 
	Customer.cust_fax, 
	Generator.EPA_ID,
	P.approval_desc, 
	WasteCode.waste_code_desc, 
	P.ap_expiration_date,
	P.waste_code,
	Generator.generator_name,
	P.OTS_flag,
	P.profile_id,
	Generator.TAB,
	PL.benzene
	
/******* Populate FormXApproval for this formID ****/
INSERT INTO FormXApproval
(form_type, form_id, revision_id, company_id, profit_ctr_id, profile_id, approval_code, profit_ctr_name, profit_ctr_EPA_ID, insurance_surcharge_percent, ensr_exempt, quotedetail_comment)
SELECT
	'RA',
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
	AND PQA.status = 'A'	

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
    ON OBJECT::[dbo].[sp_populate_form_RA] TO [EQAI]
    AS [dbo];

