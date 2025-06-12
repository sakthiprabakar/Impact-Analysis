
CREATE PROCEDURE [dbo].[sp_GeneratorLocation_select]
	@formId int,
	@revision_Id int
AS

/***********************************************************************************

	Author		: Dinesh
	Updated On	: 20-Dec-2018
	Type		: Store Procedure 
	Object Name	: [dbo].[sp_GeneratorLocation_select]

	Description	: 
                Procedure to get profile GeneratorLocation details 
				

	Input		:
				@form_id
				@revision_id
				
																
	Execution Statement	: EXEC [plt_ai].[dbo].[sp_GeneratorLocation_select] 893442,1

*************************************************************************************/
BEGIN
	--SELECT generator_id, generator_name ,generator_address1 ,generator_city ,generator_state ,generator_zip ,gen_mail_address1 ,gen_mail_city ,gen_mail_state ,gen_mail_zip ,tech_contact_name ,tech_contact_phone ,tech_cont_email ,EPA_ID ,NAICS_code ,state_id ,po_required ,inv_contact_name ,inv_contact_phone ,inv_contact_email ,cust_name ,cust_addr1 ,cust_city ,cust_state ,cust_zip from FormWCR  where form_id = @formId 

	--SELECT top 1 * from formwcr where form_id='43579'
	SELECT 
	formgl.form_id,
	formgl.revision_id,
	formgl.wcr_id,
	formgl.wcr_rev_id,
	formgl.locked, 
    formgl.generator_id,
   formgl.generator_name ,
   ISNULL(formgl.generator_address1,'') as generator_address1,
   ISNULL(formgl.generator_address2 , '') as generator_address2,
    ISNULL(formgl.generator_address3,'') as generator_address3, 
	ISNULL(formgl.generator_address4,'') as generator_address4,
	ISNULL(formgl.generator_city, '') as generator_city,
	ISNULL(formgl.generator_state, '') as generator_state ,
	 ISNULL(formgl.generator_zip,'') as generator_zip ,
	 ISNULL(formgl.generator_country,'') as generator_country,
	ISNULL(formgl.generator_phone, '') as generator_phone,
	ISNULL(formgl.gen_mail_address1,'') as gen_mail_address1,
	ISNULL(formgl.gen_mail_address2, '') as gen_mail_address2, 
	ISNULL(formgl.gen_mail_address3,'') as gen_mail_address3, 
	ISNULL(formgl.gen_mail_address4,'') as gen_mail_address4,
	ISNULL(formgl.gen_mail_city,'') as gen_mail_city ,
	ISNULL(formgl.gen_mail_state,'') as gen_mail_state ,
	ISNULL(formgl.gen_mail_zip,'') as gen_mail_zip ,
	ISNULL(formgl.gen_mail_country,'') as gen_mail_country,
	ISNULL(formgl.tech_contact_id,'') as tech_contact_id,
	ISNULL(formgl.tech_contact_name,'') as tech_contact_name ,
	ISNULL(formgl.tech_contact_phone,'') as tech_contact_phone ,
	ISNULL(formgl.tech_cont_email, '') as tech_cont_email,
	ISNULL(formgl.generator_type_ID,'') as generator_type_ID,
	ISNULL(formgl.EPA_ID,'') as EPA_ID,
	ISNULL(formgl.NAICS_code,'') as NAICS_code , 
	ISNULL((SELECT CONCAT(formgl.NAICS_code,' - ',[description]) FROM NAICSCode naics where naics.NAICS_code=formgl.NAICS_code),'') as description ,
	ISNULL(formgl.state_id,'') as state_id,
	ISNULL(formgl.state_id,'') as state_id ,ISNULL(formgl.po_required,'') as po_required,
	ISNULL(formgl.purchase_order,'') as purchase_order,
	ISNULL(formgl.customer_id, '') as customer_id, 
	ISNULL(formgl.cust_name,'') as cust_name,
	ISNULL(formgl.cust_addr1,'') as cust_addr1 ,
	ISNULL(formgl.cust_addr2,'') as cust_addr2,
	ISNULL(formgl.cust_addr3,'') as cust_addr3,
	ISNULL(formgl.cust_addr4,'') as cust_addr4,
	ISNULL(formgl.cust_city,'') as cust_city,
	ISNULL(formgl.cust_state,'') as cust_state ,
	ISNULL(formgl.cust_zip,'') as cust_zip,
	ISNULL(formgl.cust_country,'') as cust_country ,
	ISNULL(formgl.inv_contact_id,'') as inv_contact_id ,
	ISNULL(formgl.inv_contact_name,'') as inv_contact_name,
	ISNULL(formgl.inv_contact_phone,'') as inv_contact_phone ,	
	ISNULL(formgl.inv_contact_email,'') as inv_contact_email,
	ISNULL(formgl.certification_flag,'') as certification_flag,
	ISNULL(formgl.cert_physical_matches_profile,'') as cert_physical_matches_profile,
	fwcr.waste_common_name,
	formWastCode.waste_code_uid,
	fwcr.gen_process,
	fwcr.state_waste_code_flag,
	fwcr.RCRA_waste_code_flag,
	fwcr.info_basis_analysis,
	fwcr.info_basis_msds,
	fwcr.info_basis_knowledge,
	formsign.sign_name,
	formsign.sign_title,
	formsign.sign_company,
	formsign.date_added,
	formgl.created_by,
	formgl.date_created,
	formgl.modified_by,
	formgl.date_modified

from FormAddGeneratorLocation   formgl
OUTER APPLY(SELECT * FROM FormWCR fw WHERE fw.form_id = formgl.wcr_id AND fw.revision_id = formgl.wcr_rev_id) fwcr
OUTER APPLY(SELECT * FROM FormXWasteCode fwc WHERE fwc.form_id = formgl.wcr_id AND fwc.revision_id = formgl.wcr_rev_id ) formWastCode
OUTER APPLY(SELECT * FROM FormSignature fs WHERE fs.form_id = formgl.wcr_id AND fs.revision_id = formgl.wcr_rev_id ) formsign

	where formgl.wcr_id = @formId AND formgl.wcr_rev_id = @revision_Id
  FOR XML RAW ('GeneratorLocation'), ROOT ('ProfileModel'), ELEMENTS
END
GO


  GRANT EXEC ON [dbo].[sp_GeneratorLocation_select] TO COR_USER;
   GO
-- SELECT_SECTIONB
-- formgl.generator_name ,
	--ISNULL(formgl.generator_address1,'') as generator_address1, 
	--ISNULL(formgl.generator_address2 , '') as generator_address2,
	--ISNULL(formgl.generator_address3,'') as generator_address3, 
	--ISNULL(formgl.generator_address4,'') as generator_address4,
	--ISNULL(formgl.gen_mail_address1,'') as gen_mail_address1,
	--ISNULL(formgl.gen_mail_address2, '') as gen_mail_address2,
	--ISNULL(formgl.gen_mail_address3,'') as gen_mail_address3, 
	
	--ISNULL(formgl.EPA_ID,'') as EPA_ID,
	--ISNULL(formgl.tclp_total,'') as tclp_total , 
	--ISNULL(formgl.NAICS_code,'') as NAICS_code , 
	--ISNULL((SELECT CONCAT(NAICS_code,' - ',[description]) FROM NAICSCode naics where naics.NAICS_code=formgl.NAICS_code),'') as description,
