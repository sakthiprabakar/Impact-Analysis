CREATE PROCEDURE [dbo].[sp_Cor_BulkRenewal_Report]
(
    @form_id nvarchar(max)
	
	
	
)
as

/* ******************************************************************

	Updated By		: Prabhu
	Updated On		: 22nd Nov 2021
	Type			: Stored Procedure
	Object Name		: [sp_Cor_BulkRenewal_Report]


	Procedure to Bulk Renewal Documents

inputs 
	
	@form_id
	


Samples:
 EXEC [sp_Cor_BulkRenewal_Report] @form_id
 EXEC [sp_Cor_BulkRenewal_Report] '592577-1,512342-1,512201-1'
****************************************************************** */

	declare @form_id_list table (
		form_id nvarchar(30)
	)

		
insert @form_id_list
select row
from dbo.fn_SplitXsvText(',', 1, replace(@form_id, ' ', ','))
 Create  table #temptable
  (
  form_id nvarchar(30),
  revision_id nvarchar(30)
  )

;WITH Splitted
AS (
SELECT CAST('<x>' + REPLACE(form_id, '-', '</x><x>') + '</x>' AS XML) AS Parts
FROM @form_id_list
)
insert into #temptable(form_id,revision_id)
SELECT Parts.value(N'/x[1]', 'varchar(50)') AS form_id
,Parts.value(N'/x[2]', 'varchar(50)') AS revision_id

FROM Splitted;



  SELECT	   FormRA.form_id,
               FormRA.revision_id,
     	       FormRA.profile_id,
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
				FormRA.tab,
               FormRA.benzene,
			  --wastecodes = Convert(Text, dbo.fn_form_wastecodes_without_state(@form_id, @revision_id, 'ALL')),
               Generator.tab as generator_tab,
			   Approval_approval_desc,
               Approval_ap_expiration_date,
               FormXApproval.company_id,
               FormXApproval.profit_ctr_id,
               FormXApproval.approval_code,
               FormXApproval.profit_ctr_name,
               FormXApproval.profit_ctr_EPA_ID,
             (SELECT STUFF(REPLACE((SELECT DISTINCT '#!' + LTRIM(RTRIM(f.approval_code)) AS 'data()' FROM FormXApproval f WHERE f.form_id = FormRA.form_id AND f.revision_id = FormRA.revision_id AND f.profile_id = FormRA.profile_id AND f.form_type = 'RA' 
			  FOR XML PATH('')),' #!',', '), 1, 2, '')) as approvals_list
			  from #temptable tt join
 FormRA on FormRA.form_id = tt.form_id and FormRA.revision_id = tt.revision_id
LEFT OUTER JOIN FormSignature
               ON FormSignature.form_id = FormRA.form_id
               AND FormSignature.revision_id = FormRA.revision_id
LEFT OUTER JOIN Contact
               ON Contact.contact_id = FormRA.contact_id
LEFT OUTER JOIN Generator
               ON Generator.generator_id = FormRA.generator_id
LEFT OUTER JOIN FormXApproval
               ON FormXApproval.form_id = FormRA.form_id AND FormXApproval.revision_id = FormRA.revision_id


			  GO

	GRANT EXECUTE ON [dbo].[sp_Cor_BulkRenewal_Report] TO COR_USER;

          GO	
			   

		