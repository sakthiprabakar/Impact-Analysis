USE [PLT_AI]
GO

DROP PROCEDURE IF EXISTS [dbo].[sp_cor_RA]

GO

CREATE PROCEDURE [dbo].[sp_cor_RA]
(
	@form_id nvarchar(100),
	@revision_id nvarchar(100)
)
AS

/* ******************************************************************

	Updated By		: Prabhu
	Updated On		: 14th Aug 2020
	Type			: Stored Procedure
	Object Name		: [sp_cor_RA]


	Procedure to Reapproval Notice related fields 

inputs 
	
	@formId
	@revisionId
	


Samples:
 EXEC [sp_cor_RA] @formId,@revisionId
 EXEC [sp_cor_RA] 507972, 1
****************************************************************** */
BEGIN

  SELECT
		       FormRA.form_id,
               FormRA.revision_id,
               customer_id,
               Customer_cust_name,
               Customer_cust_addr1,
               Customer_cust_addr2,
               Customer_cust_addr3,
               Customer_cust_addr4,
               Customer_cust_city,
               Customer_cust_state,
               Customer_cust_zip_code,
               Customer_cust_fax,
               Generator_EPA_ID,
               WasteCode_waste_code_desc,
               Contact_name,
               Approval_waste_code,
               Generator_generator_name,
               FormSignature.Sign_Name,
               FormSignature.Sign_Company,
               FormSignature.Date_Added,
               FormRA.generator_id,
               locked,
               FormRA.contact_id,
               Contact.fax,
               FormSignature.sign_email,
               FormRA.profile_id,
               FormRA.tab,
               FormRA.benzene,
			   wastecodes = Convert(Text, dbo.fn_form_wastecodes_without_state(@form_id, @revision_id, 'ALL')),
               Generator.tab as generator_tab,
			   Approval_approval_desc,
               Approval_ap_expiration_date,
               FormXApproval.company_id,
               FormXApproval.profit_ctr_id,
               FormXApproval.approval_code,
               FormXApproval.profit_ctr_name,
               FormXApproval.profit_ctr_EPA_ID,
            (SELECT STUFF(REPLACE((SELECT DISTINCT '#!' + LTRIM(RTRIM(f.approval_code)) AS 'data()' FROM FormXApproval f WHERE f.form_id = FormRA.form_id AND f.revision_id = FormRA.revision_id AND f.profile_id = FormRA.profile_id AND f.form_type = 'RA' FOR XML PATH('')),' #!',', '), 1, 2, '')) as approvals_list
FROM FormRA
LEFT OUTER JOIN FormSignature
               ON FormSignature.form_id = FormRA.form_id
               AND FormSignature.revision_id = FormRA.revision_id
LEFT OUTER JOIN Contact
               ON Contact.contact_id = FormRA.contact_id
LEFT OUTER JOIN Generator
               ON Generator.generator_id = FormRA.generator_id
LEFT OUTER JOIN FormXApproval
               ON FormXApproval.form_id = FormRA.form_id AND FormXApproval.revision_id = FormRA.revision_id
               AND FormXApproval.profile_id = FormRA.profile_id AND FormXApproval.form_type = 'RA'
			   WHERE FormRA.Form_id =  @form_id  AND FormRA.Revision_id =  @revision_id


END	

GO
GRANT EXECUTE on [dbo].[sp_cor_RA] to COR_USER
GO
GRANT EXECUTE on [dbo].[sp_cor_RA] to EQWEB
GO
GRANT EXECUTE on [dbo].[sp_cor_RA]  to EQAI
