CREATE proc [dbo].[sp_cor_GWA]
(
	@form_id nvarchar(100),
	@revision_id nvarchar(100)
)
as
SELECT 
               FormGWA.form_id,
               FormGWA.revision_id,
               customer_id_from_form,
               cast(FormGWA.customer_id as nvarchar(100)) as customer_id,
               app_id,
               FormGWA.status,
               locked,
               FormGWA.source,
               approval_key,
               signing_name,
               signing_company,
               signing_title,
               signing_date,
               FormGWA.date_created,
               FormGWA.date_modified,
               FormGWA.created_by,
               FormGWA.modified_by,
               FormGWA.generator_name,
               FormGWA.EPA_ID,
			   FormXApproval.approval_code,
               FormGWA.generator_id,
               generator_address1,
               FormGWA.cust_name,
               FormGWA.cust_addr1,
               FormGWA.gen_mail_addr1,
               FormGWA.gen_mail_addr2,
               FormGWA.gen_mail_addr3,
               FormGWA.gen_mail_addr4,
               FormGWA.gen_mail_addr5,
               FormGWA.gen_mail_city,
               FormGWA.gen_mail_state,
               FormGWA.gen_mail_zip_code,
               FormGWA.waste_code,
               inv_contact_name,
               inv_contact_phone,
               inv_contact_fax,
               tech_contact_name,
               tech_contact_phone,
               tech_contact_fax,
               waste_common_name,
               waste_code_comment,
               amendment,
               FormSignature.sign_name,
               FormSignature.sign_company,
               FormSignature.Date_Added,
               FormSignature.sign_email,
               FormGWA.profile_id,
               FormGWA.cust_fax,
               FormGWA.contact_id,
               case when FormGWA.contact_name is null then 'ENVIRONMENT MANAGER' ELSE '' end as contact_name,
               FormGWA.cust_addr2,
               FormGWA.cust_addr3,
               FormGWA.cust_addr4,
               FormGWA.cust_city,
               FormGWA.cust_state,
               FormGWA.cust_zip_code,
               FormGWA.ap_expiration_date,
               (CASE FormGWA.reapproval_profile_change WHEN 'RNPC' THEN 'T' ELSE 'F' END) AS rnpc,
               (CASE FormGWA.reapproval_profile_change WHEN 'RPC' THEN 'T' ELSE 'F' END) AS rpc,
               (CASE FormGWA.reapproval_profile_change WHEN 'PC' THEN 'T' ELSE 'F' END) AS pc,
               wastecodes = Convert(Text, dbo.fn_form_wastecodes_without_state(@form_id, @revision_id, 'ALL')),
               ProfileLab.benzene,
               FormGWA.TAB,
               Generator.TAB as generator_tab,
			   FormXApproval.profit_ctr_EPA_ID,
			   FormXApproval.profit_ctr_name
			  -- (select top 1 wcr_facility_name from plt_ai..profitcenter pct where pct.company_id = FormGWA.company_id and pct.profit_ctr_id = FormGWA.profit_ctr_id) as profit_ctr_name
FROM FormGWA
LEFT OUTER JOIN FormSignature
               ON FormGWA.form_id = FormSignature.form_id and FormGWA.revision_id = FormSignature.revision_id                
LEFT OUTER JOIN ProfileLab
               ON ProfileLab.profile_id = FormGWA.profile_id
               AND ProfileLab.type = 'A'
LEFT OUTER JOIN FormXApproval​
			   ON FormXApproval.form_id = FormGWA.form_id​ AND FormXApproval.revision_id = FormGWA.revision_id​
			   AND FormXApproval.profile_id = FormGWA.profile_id​ AND FormXApproval.form_type = 'GWA'​
LEFT OUTER JOIN Generator
               ON Generator.generator_id = FormGWA.generator_id
WHERE FormGWA.form_id = @form_id AND FormGWA.revision_id =@revision_id

GO

GRANT EXECUTE ON [dbo].[sp_cor_GWA] TO COR_USER;

GO





