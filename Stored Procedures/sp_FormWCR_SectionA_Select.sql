CREATE PROCEDURE [dbo].[sp_FormWCR_SectionA_Select]
	@formId int,
	@revision_Id int
AS


/* ******************************************************************

	Updated By		: Dineshkumar
	Updated On		: 11th Feb 2019
	Type			: Stored Procedure
	Object Name		: [sp_FormWCR_SectionA_Select]


	Procedure to select Section A related fields 

inputs 
	
	@formId
	@revisionId
	


Samples:
 EXEC [sp_FormWCR_SectionA_Select] @formId,@revisionId
 EXEC [sp_FormWCR_SectionA_Select] 501693, 1

****************************************************************** */
BEGIN
	--SELECT generator_id, generator_name ,generator_address1 ,generator_city ,generator_state ,generator_zip ,gen_mail_address1 ,gen_mail_city ,gen_mail_state ,gen_mail_zip ,tech_contact_name ,tech_contact_phone ,tech_cont_email ,EPA_ID ,NAICS_code ,state_id ,po_required ,inv_contact_name ,inv_contact_phone ,inv_contact_email ,cust_name ,cust_addr1 ,cust_city ,cust_state ,cust_zip from FormWCR  where form_id = @formId 

	--SELECT top 1 * from formwcr where form_id='43579'
	DECLARE @section_status CHAR(1);
	SELECT @section_status =section_status FROM formsectionstatus WHERE form_id=@formId AND revision_id =@revision_Id  and section='SA'
	SELECT  generator_id, generator_name ,ISNULL(generator_address1,'') as generator_address1, ISNULL(generator_address2 , '') as generator_address2, ISNULL(generator_address3,'') as generator_address3, 
	ISNULL(generator_address4,'') as generator_address4,
	ISNULL(generator_city, '') as generator_city,
	ISNULL(generator_state, '') as generator_state , ISNULL(generator_zip,'') as generator_zip ,ISNULL(generator_country,'') as generator_country,
	ISNULL(generator_phone, '') as generator_phone,
	ISNULL(gen_mail_name, (select top 1 g.gen_mail_name from generator g where g.generator_id = formwcr.generator_id)) as gen_mail_name,
	ISNULL(gen_mail_address1,'') as gen_mail_address1,
	ISNULL(gen_mail_address2, '') as gen_mail_address2, ISNULL(gen_mail_address3,'') as gen_mail_address3, 
	ISNULL(gen_mail_address4,'') as gen_mail_address4,
	ISNULL(gen_mail_city,'') as gen_mail_city ,ISNULL(gen_mail_state,'') as gen_mail_state ,ISNULL(gen_mail_zip,'') as gen_mail_zip ,ISNULL(gen_mail_country,'') as gen_mail_country,
	ISNULL(tech_contact_name,'') as tech_contact_name ,ISNULL(tech_contact_phone,'') as tech_contact_phone , ISNULL(tech_cont_email, '') as tech_cont_email,
	ISNULL(generator_type_ID,'') as generator_type_ID,
	ISNULL(EPA_ID,'') as EPA_ID,
	ISNULL(CAST(formwcr.NAICS_code as nvarchar(100)),'') as NAICS_code, 
	case when EXISTS(SELECT * FROM NAICSCode naics where (naics.NAICS_code=formwcr.NAICS_code and formwcr.NAICS_code > 0) OR ISNULL(formwcr.NAICS_code, '') = '') then 1 else 0 end as IsValidNAICS,
	ISNULL((SELECT CONCAT(NAICS_code,' - ',[description]) FROM NAICSCode naics where naics.NAICS_code=formwcr.NAICS_code and formwcr.NAICS_code > 0),'') as description ,
	ISNULL(state_id,'') as state_id ,ISNULL(po_required,'') as po_required,
	ISNULL(purchase_order,'') as purchase_order,
	ISNULL(inv_contact_name,'') as inv_contact_name,ISNULL(inv_contact_phone,'') as inv_contact_phone ,	
	ISNULL(inv_contact_email,'') as inv_contact_email,
	ISNULL(customer_id, '') as customer_id, 
	ISNULL(cust_name,'') as cust_name,
	ISNULL(cust_addr1,'') as cust_addr1 ,ISNULL(cust_addr2,'') as cust_addr2, ISNULL(cust_addr3,'') as cust_addr3,
	ISNULL(cust_addr4,'') as cust_addr4, ISNULL(cust_city,'') as cust_city,
	ISNULL(cust_state,'') as cust_state , ISNULL(cust_zip,'') as cust_zip,
	ISNULL(cust_country,'') as cust_country ,
	ISNULL((SELECT TOP 1  ISNULL(logon.Email,'')   FROM COR_DB.dbo.LogonRequest logon WHERE formwcr.created_by=logon.Web_UserId),'') profileEmail
,@section_status AS IsCompleted
 from FormWCR   formwcr
	where form_id = @formId AND revision_id = @revision_Id
  FOR XML RAW ('SectionA'), ROOT ('ProfileModel'), ELEMENTS
END

GO

	GRANT EXEC ON [dbo].[sp_FormWCR_SectionA_Select] TO COR_USER;

GO
