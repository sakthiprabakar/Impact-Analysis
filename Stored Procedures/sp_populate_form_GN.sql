CREATE PROCEDURE sp_populate_form_GN
	@form_id		int,
	@profile_id		int,
	@generator_id	int,
	@added_by		varchar(60)
AS
/***************************************************************************************
Populates FormGN & FormXApproval table with data from Profile & ProfileQuoteApproval
Loads to:	PLT_AI

06/28/2005 JDB	Created
03/15/2006 RG	Removed join to WasteCode on profit_ctr_id
06/26/2006 MK	Modified to use Profile tables
10/02/2007 WAV	Removed references to a database server.
04/07/2009 KAM  Updated to accept generator_id
10/13/2011 SK	Moved to PLT_AI
10/14/2011 SK	Rewrote the sp to populate all approval-facilities data for a selected profile.
				No longer needs company, profit_ctr_id, approval_code as input args.
				The approval-facilities data comes from ProfileQuoteApproval & go into FORMXApproval
03/22/2012 SK	Fixed the generator_contact to pull from contactxref(was always being inserted as '')
04/05/2012 SK	Upodated  FormXApproval Info for new columns & to only add active approvals
08/09/2012 SK	Updated to insert NULL into FormXApproval.insurance_surcharge_percent & FormXApproval.ensr_exempt
				as this form does not use them
08/21/2012 SK	Waste codes should be inserted into FormXWastecodes for every form
09/21/2012 SK	Show customer mailing adress information if generator is various
04/17/2013 SK	Added waste_code_UID to FormXWasteCode
08/22/2013 SK	Changed the join on Profile.waste_code to Profile.waste_code_uid
10/02/2013 SK	Changed to copy only active waste codes to the form from profile
02/28/2020 MPM	DevOps 14330 - Added column list to inserts. 

sp_populate_form_GN -888889, 194421, 0, SK
Select * from FormGN where form_id = -888889
Select * from FormXApproval where form_id = -888889
customer_id = 1125
select * from contactXref where generator_id = 23635
****************************************************************************************/
DECLARE	
	@revision_id	int,
	@locked			char(1),
	@status			char(1),
	@source			char(1),
	@current_form_version_id	int

SET NOCOUNT ON

SET @revision_id = 1
SET @status = 'A'
SET @locked = 'U'
SET @source = 'A'
SELECT @current_form_version_id = current_form_version FROM FormType WHERE form_type = 'GN'

IF IsNull(@generator_id ,0) = 0
BEGIN
	INSERT INTO FormGN
	(form_id, revision_id, form_version_id, customer_id, status, locked, source, approval_code, approval_key, company_id, profit_ctr_id, signing_name, signing_company, signing_title, 
		signing_date, date_created, date_modified, created_by, modified_by, customer_cust_name, customer_cust_fax, generator_id, generator_epa_id, generator_gen_mail_name, generator_gen_mail_address_1,
		generator_gen_mail_address_2, generator_gen_mail_address_3, generator_gen_mail_address_4, generator_gen_mail_address_5, generator_gen_mail_city, generator_gen_mail_state, generator_gen_mail_zip_code,
		generator_generator_contact, approval_waste_code, approval_approval_desc, approval_comments_1, approval_ap_expiration_date, approval_ots_flag, wastecode_waste_code_desc, profitcenter_profit_ctr_name,
		profitcenter_address_1, profitcenter_address_2, profitcenter_address_3, profitcenter_phone, profitcenter_fax, profitcenter_epa_id, secondary_waste_code, rowguid, profile_id, generator_name)	
	SELECT	
		@form_id,
		@revision_id,
		@current_form_version_id,
		P.customer_id,
		@status,
		@locked,
		@source,
		--@approval_code, SK field moved to FormXApproval
		NULL,
		@profile_id as approval_key,
		--	PQA.company_id, SK field moved to FormXApproval
		--PQA.profit_ctr_id, SK field moved to FormXApproval
		NULL, NULL,
		NULL AS signing_name,
		NULL AS signing_company,
		NULL AS signing_title,
		NULL AS signing_date,
		GETDATE() AS date_created,
		GETDATE() AS date_modified,
		@added_by AS created_by,
		@added_by AS modified_by,
		Customer.cust_name, 
		Customer.cust_fax,  
		Generator.generator_id,
		Generator.EPA_ID,
		Customer.cust_name,
		Customer.cust_addr1,
		Customer.cust_addr2,
		Customer.cust_addr3,
		Customer.cust_addr4,
		Customer.cust_addr5,
		Customer.cust_city,
		Customer.cust_state,
		Customer.cust_zip_code,
		--Generator.gen_mail_name,
		--Generator.gen_mail_addr1, 
		--Generator.gen_mail_addr2, 
		--Generator.gen_mail_addr3, 
		--Generator.gen_mail_addr4, 
		--Generator.gen_mail_addr5, 
		--Generator.gen_mail_city,
		--Generator.gen_mail_state,
		--Generator.gen_mail_zip_code,
		Contact.Name as generator_contact, 	--'' as generator_contact, 
		P.waste_code,
		P.approval_desc,  
		P.comments_1,
		P.ap_expiration_date,
		P.OTS_flag, 
		WasteCode.waste_code_desc, 
		-- ProfitCenter.profit_ctr_name, SK field moved to FormXApproval
		--ProfitCenter.address_1,	SK field dropped
		--ProfitCenter.address_2,	SK field dropped
		--ProfitCenter.address_3,	SK field dropped
		--ProfitCenter.phone,		SK field dropped
		--ProfitCenter.fax,			SK field dropped
		--ProfitCenter.EPA_ID,		SK field moved to FormXApproval
		NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
		-- secondary_waste_code = dbo.fn_sec_waste_code_list(@profile_id), moved to FormXWasteCode
		NEWID(),
		@profile_id,
		Generator.generator_name
	FROM Profile P
	JOIN Customer
		ON Customer.customer_id = P.customer_id
	JOIN Generator
		ON Generator.generator_id = P.generator_id
	JOIN WasteCode
		ON WasteCode.waste_code_uid = P.waste_code_uid
	LEFT OUTER JOIN ContactXRef
		ON ContactXRef.customer_id = P.customer_id
		AND ContactXRef.primary_contact = 'T'
	LEFT OUTER JOIN Contact
		ON Contact.contact_id = ContactXRef.contact_id
	WHERE P.profile_id = @profile_id
		AND P.curr_status_code in ('A','H','P')
	ORDER BY Customer.customer_id, Generator.generator_id
END
ELSE
BEGIN
	INSERT INTO FormGN
	(form_id, revision_id, form_version_id, customer_id, status, locked, source, approval_code, approval_key, company_id, profit_ctr_id, signing_name, signing_company, signing_title, 
		signing_date, date_created, date_modified, created_by, modified_by, customer_cust_name, customer_cust_fax, generator_id, generator_epa_id, generator_gen_mail_name, generator_gen_mail_address_1,
		generator_gen_mail_address_2, generator_gen_mail_address_3, generator_gen_mail_address_4, generator_gen_mail_address_5, generator_gen_mail_city, generator_gen_mail_state, generator_gen_mail_zip_code,
		generator_generator_contact, approval_waste_code, approval_approval_desc, approval_comments_1, approval_ap_expiration_date, approval_ots_flag, wastecode_waste_code_desc, profitcenter_profit_ctr_name,
		profitcenter_address_1, profitcenter_address_2, profitcenter_address_3, profitcenter_phone, profitcenter_fax, profitcenter_epa_id, secondary_waste_code, rowguid, profile_id, generator_name)	
	SELECT	
		@form_id,
		@revision_id,
		@current_form_version_id,
		P.customer_id,
		@status,
		@locked,
		@source,
		--@approval_code,	SK field moved to FormXApproval
		NULL,
		@profile_id as approval_key,
		--PQA.company_id,	SK field moved to FormXApproval
		--@profit_ctr_id,	SK field moved to FormXApproval
		NULL, NULL,
		NULL AS signing_name,
		NULL AS signing_company,
		NULL AS signing_title,
		NULL AS signing_date,
		GETDATE() AS date_created,
		GETDATE() AS date_modified,
		@added_by AS created_by,
		@added_by AS modified_by,
		Customer.cust_name, 
		Customer.cust_fax,  
		Generator.generator_id,
		Generator.EPA_ID,
		Generator.gen_mail_name,
		Generator.gen_mail_addr1, 
		Generator.gen_mail_addr2, 
		Generator.gen_mail_addr3, 
		Generator.gen_mail_addr4, 
		Generator.gen_mail_addr5, 
		Generator.gen_mail_city,
		Generator.gen_mail_state,
		Generator.gen_mail_zip_code,
		Contact.name,
		--'' as generator_contact, 
		P.waste_code, 
		P.approval_desc,  
		P.comments_1,
		P.ap_expiration_date,
		P.OTS_flag, 
		WasteCode.waste_code_desc, 
		--ProfitCenter.profit_ctr_name,	SK field moved to FormXApproval
		--ProfitCenter.address_1,		SK field dropped
		--ProfitCenter.address_2,		SK field dropped
		--ProfitCenter.address_3,		SK field dropped
		--ProfitCenter.phone,			SK field dropped
		--ProfitCenter.fax,				SK field dropped
		--ProfitCenter.EPA_ID,			SK field moved to FormXApproval
		NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
		-- secondary_waste_code = dbo.fn_sec_waste_code_list(@profile_id),SK field moved to FormXWasteCode
		NEWID(),
		@profile_id,
		Generator.generator_name
	FROM Profile P
	JOIN Customer
		ON Customer.customer_id = P.customer_id
	JOIN Generator
		ON Generator.generator_id = @generator_id
	JOIN WasteCode
		ON WasteCode.waste_code_uid = P.waste_code_uid
	LEFT OUTER JOIN ContactXRef
		ON ContactXRef.generator_id = Generator.generator_id
		AND ContactXRef.primary_contact = 'T'
	LEFT OUTER JOIN Contact
		ON Contact.contact_id = ContactXRef.contact_id
	WHERE P.profile_id = @profile_id
		AND P.curr_status_code in ('A','H','P')
	ORDER BY Customer.customer_id, Generator.generator_id
END

/******* Populate FormXApproval for this formID ****/
INSERT INTO FormXApproval
(form_type, form_id, revision_id, company_id, profit_ctr_id, profile_id, approval_code, profit_ctr_name, profit_ctr_EPA_ID, insurance_surcharge_percent, ensr_exempt, quotedetail_comment)
SELECT
	'GN',
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

/******* Populate FormXWasteCode for this formID ****/
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
    ON OBJECT::[dbo].[sp_populate_form_GN] TO [EQAI]
    AS [dbo];
