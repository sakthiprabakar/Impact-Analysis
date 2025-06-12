CREATE PROCEDURE [dbo].[sp_rpt_generator_approval_notification]
	@company_id		int
,	@profit_ctr_id	int
,	@profiles		varchar(max)
,	@debug			tinyint
,	@record_type	tinyint
AS
/***************************************************************************************
This sp runs for the Report -> Forms -> Generator Approval Notification
Loads to:		PLT_AI
PB Object(s):	d_rpt_generator_approval

10/27/2011 SK	Created
07/12/2121 DZ   changed generator comments field from approval_comments to comments_1
08/14/2012 SK	Fixed the Generator Contact Name fetch
08/22/2012 SK	Fixed the clause for various generators
				added record_type to distinguish between 1letter for various approvals vs multiple letters for various approvals
11/21/2012 SK	Corrected. "Various" approvals meant Generator set to VARIOUS.
06/23/2016 RB	@profiles argument was varchar(255), any more than about 36 profile_ids were being truncated
05/15/2017 MPM	Corrected bad joins on waste_code between Profile and WasteCode tables.
09/10/2019 AGC  DevOps 10373 added generator locations

sp_rpt_generator_approval_notification 21, 00, '343472, 343473, 343474',0, 2


****************************************************************************************/
SET NOCOUNT ON

CREATE TABLE #tmp_profiles (profile_id	int NULL)
EXEC sp_list @debug, @profiles, 'NUMBER', '#tmp_profiles'

IF @record_type = 1 -- Multiple letters for generator set to VARIOUS
BEGIN
	SELECT
		Profile.profile_id	
	,	Customer.customer_id
	,	Customer.cust_name
	,	Contact.name AS Contact_name
	,	Generator.generator_id
	,	Generator.site_type
	,	Generator.generator_name
	,	Generator.EPA_ID
	,	Generator.gen_mail_name
	,	Generator.gen_mail_addr1
	,	Generator.gen_mail_addr2
	,	Generator.gen_mail_addr3
	,	Generator.gen_mail_addr4
	,	Generator.gen_mail_addr5
	,	Generator.gen_mail_city
	,	Generator.gen_mail_state
	,	Generator.gen_mail_zip_code
	,	WasteCode.waste_code_desc
	,	Profile.approval_desc
	,	NULL, NULL
	--,	Profile.waste_code
	--,	secondary_wastecodes = dbo.fn_sec_waste_code_list(Profile.profile_id)
	--,	ProfileQuoteApproval.approval_code
	--,	ProfileQuoteApproval.company_id
	--,	ProfileQuoteApproval.profit_ctr_id
	,	Profile.ap_expiration_date
	--,	ProfitCenter.profit_ctr_name
	--,	ProfitCenter.EPA_ID AS profit_ctr_epa_ID
	--,	Profile.approval_comments
	,	Profile.comments_1
	,	Profile.OTS_flag
	FROM Profile
	--INNER JOIN ProfileQuoteApproval
	--	ON ProfileQuoteApproval.profile_id = Profile.profile_id
	INNER JOIN Customer
		ON Customer.customer_ID = Profile.customer_id
	INNER JOIN WasteCode
		ON WasteCode.waste_code_uid = Profile.waste_code_uid	
	--INNER JOIN ProfitCenter
	--	ON ProfitCenter.company_ID = ProfileQuoteApproval.company_id
	--	AND ProfitCenter.profit_ctr_ID = ProfileQuoteApproval.profit_ctr_id	
	INNER JOIN Generator
		ON ( (Profile.generator_id > 0 AND Generator.generator_id = Profile.generator_id)
			OR (Profile.generator_id = 0 
						 AND (Select count(*) from ProfileGeneratorSiteType where ProfileGeneratorSiteType.profile_id = profile.profile_id) = 0
						 AND (Select count(*) from ProfileGeneratorLocation where ProfileGeneratorLocation.profile_id = profile.profile_id) = 0
						 AND Generator.generator_id  IN (SELECT generator_id FROM CustomerGenerator WHERE customer_ID = Profile.customer_id)
				)
 			OR (Profile.generator_id = 0 
 						 AND (Select count(*) from ProfileGeneratorLocation where profile_id = profile.profile_id) > 0
 						 AND Generator.generator_id IN (SELECT CustomerGenerator.generator_id FROM CustomerGenerator 
 														WHERE CustomerGenerator.customer_ID = Profile.customer_id 
 														and CustomerGenerator.generator_id in (Select generator_id from ProfileGeneratorLocation 
 																					where ProfileGeneratorLocation.profile_id = Profile.profile_id)
 														)
 				)
 			OR (Profile.generator_id = 0 
 						 AND (Select count(*) from ProfileGeneratorSiteType where profile_id = profile.profile_id) > 0
 						 AND Generator.generator_id IN (SELECT CustomerGenerator.generator_id FROM CustomerGenerator 
 														Full outer Join Generator on CustomerGenerator.generator_id = Generator.generator_id 
 														WHERE customer_ID = Profile.customer_id 
 														and Generator.site_type in (Select site_type from ProfileGeneratorSiteType 
 																					where ProfileGeneratorSiteType.profile_id = Profile.profile_id)
 														)
 				)
 			)
	LEFT OUTER JOIN ContactXRef
			ON ContactXRef.generator_id = Generator.generator_id
			AND ContactXRef.primary_contact = 'T'
	LEFT OUTER JOIN Contact
			ON Contact.contact_id = ContactXRef.contact_id
	WHERE Profile.profile_id IN (Select profile_id FROM #tmp_profiles )
		AND Profile.ap_expiration_date >= GETDATE()
	ORDER BY Customer.customer_id, Generator.generator_id
END

IF @record_type = 2 -- one letter for various approvals
BEGIN
	SELECT
		Profile.profile_id	
	,	Customer.customer_id
	,	Customer.cust_name
	,	Contact.name AS Contact_name
	,	Generator.generator_id
	,	Generator.site_type
	,	Generator.generator_name
	,	Generator.EPA_ID
	,	Generator.gen_mail_name
	,	Generator.gen_mail_addr1
	,	Generator.gen_mail_addr2
	,	Generator.gen_mail_addr3
	,	Generator.gen_mail_addr4
	,	Generator.gen_mail_addr5
	,	Generator.gen_mail_city
	,	Generator.gen_mail_state
	,	Generator.gen_mail_zip_code
	,	WasteCode.waste_code_desc
	,	Profile.approval_desc
	,	NULL, NULL
	--,	Profile.waste_code
	--,	secondary_wastecodes = dbo.fn_sec_waste_code_list(Profile.profile_id)
	--,	ProfileQuoteApproval.approval_code
	--,	ProfileQuoteApproval.company_id
	--,	ProfileQuoteApproval.profit_ctr_id
	,	Profile.ap_expiration_date
	--,	ProfitCenter.profit_ctr_name
	--,	ProfitCenter.EPA_ID AS profit_ctr_epa_ID
	--,	Profile.approval_comments
	,	Profile.comments_1
	,	Profile.OTS_flag
	FROM Profile
	--INNER JOIN ProfileQuoteApproval
	--	ON ProfileQuoteApproval.profile_id = Profile.profile_id
	INNER JOIN Customer
		ON Customer.customer_ID = Profile.customer_id
	INNER JOIN WasteCode
		ON WasteCode.waste_code_uid = Profile.waste_code_uid	
	--INNER JOIN ProfitCenter
	--	ON ProfitCenter.company_ID = ProfileQuoteApproval.company_id
	--	AND ProfitCenter.profit_ctr_ID = ProfileQuoteApproval.profit_ctr_id	
	INNER JOIN Generator
		ON Generator.generator_id = Profile.generator_id
	LEFT OUTER JOIN ContactXRef
			ON ContactXRef.generator_id = Generator.generator_id
			AND ContactXRef.primary_contact = 'T'
	LEFT OUTER JOIN Contact
			ON Contact.contact_id = ContactXRef.contact_id
	WHERE Profile.profile_id IN (Select profile_id FROM #tmp_profiles )
		AND Profile.ap_expiration_date >= GETDATE()
	ORDER BY Customer.customer_id, Generator.generator_id
END




GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_generator_approval_notification] TO [EQAI]
    AS [dbo];

