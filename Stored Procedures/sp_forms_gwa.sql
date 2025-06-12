
CREATE PROCEDURE sp_forms_gwa 
	@amendment TEXT
	,@profChange VARCHAR(4)
	,@user VARCHAR(255)
	,@revision_id INT
	,@form_id INT
	,@debug INT = 0
	,@profile_id INT
	,@session_id VARCHAR(12)
	,@ip_address VARCHAR(40) = ''
	,@image_id INT = 0
	,@contact_id INT = 0
	,@copc_list VARCHAR(max) = ''
	,@file_location VARCHAR(255) = NULL
	,@tab FLOAT = NULL
AS
/*********************************************************************************
10/25/2011 CRG Changed SP to use FormXApproval instead of storing approval info in 
	the form table
10/14/2011 CRG	Created
05/02/2013 JPB	waste_code_uid added
07/23/2013 JPB	TAB added
11/19/2013 JPB	image_id default to 0 now... Also, removed the part of the sp using it.
				Added delete before insert
06/16/2023 Devops 65744 -- Nagaraj M Modified the input parameter @copc_list varchar(255) to @copc_list varchar(max)

sp_forms_gwa
*********************************************************************************/
CREATE TABLE #copc (
	company_id INT
	,profit_ctr_id INT
	)

INSERT #copc
SELECT RTRIM(LTRIM(SUBSTRING(row, 1, CHARINDEX('|', row) - 1))) company_id
	,RTRIM(LTRIM(SUBSTRING(row, CHARINDEX('|', row) + 1, LEN(row) - (CHARINDEX('|', row) - 1)))) profit_ctr_id
from dbo.fn_SplitXsvText(',', 0, @copc_list)
WHERE isnull(row, '') <> ''

IF EXISTS (SELECT * FROM [FormGWA] WHERE form_id = @form_id AND revision_id = @revision_id)
	DELETE FROM [FormGWA] WHERE form_id = @form_id AND revision_id = @revision_id

-- The same form_id could've been saved as an RA last time. Clear that, too.
IF EXISTS (SELECT * FROM [FormRA] WHERE form_id = @form_id AND revision_id = @revision_id)
	DELETE FROM [FormRA] WHERE form_id = @form_id AND revision_id = @revision_id

INSERT INTO [dbo].[FormGWA] (
	[form_id]
	,[revision_id]
	,[form_version_id]
	,[customer_id_from_form]
	,[customer_id]
	,[app_id]
	,[status]
	,[locked]
	,[source]
	,[approval_code]
	,[approval_key]
	,[company_id]
	,[profit_ctr_id]
	,[signing_name]
	,[signing_company]
	,[signing_title]
	,[signing_date]
	,[date_created]
	,[date_modified]
	,[created_by]
	,[modified_by]
	,[generator_name]
	,[EPA_ID]
	,[generator_id]
	,[generator_address1]
	,[cust_name]
	,[cust_addr1]
	,[inv_contact_name]
	,[inv_contact_phone]
	,[inv_contact_fax]
	,[tech_contact_name]
	,[tech_contact_phone]
	,[tech_contact_fax]
	,[waste_common_name]
	,[waste_code_comment]
	,[amendment]
	,[gen_mail_addr1]
	,[gen_mail_addr2]
	,[gen_mail_addr3]
	,[gen_mail_addr4]
	,[gen_mail_addr5]
	,[gen_mail_city]
	,[gen_mail_state]
	,[gen_mail_zip_code]
	,[profitcenter_epa_id]
	,[profitcenter_profit_ctr_name]
	,[profitcenter_address_1]
	,[profitcenter_address_2]
	,[profitcenter_address_3]
	,[profitcenter_phone]
	,[profitcenter_fax]
	,[waste_code]
	,[rowguid]
	,[profile_id]
	,[ap_expiration_date]
	,[cust_fax]
	,[Reapproval_Profile_change]
	,[TAB]
	)
SELECT @form_id --<form_id int>
	,@revision_id --<revision_id int>
	,current_form_version --<form_version_id int>
	,PROFILE.customer_id --<customer_id_from_form int>
	,PROFILE.customer_id --<customer_id int>
	,NULL --<app_id varchar(20)>
	,'A' --<status char(1)>
	,'U' --<locked char(1)>
	,'A' --<source char(1)>
	,NULL --<approval_code varchar(15)>
	,PROFILE.profile_id --<approval_key int>
	,NULL --<company_id int>
	,NULL --<profit_ctr_id int>
	,NULL --<signing_name varchar(40)>
	,NULL --<signing_company varchar(40)>
	,NULL --<signing_title varchar(40)>
	,NULL --<signing_date datetime>
	,GETDATE() --<date_created datetime>
	,GETDATE() --<date_modified datetime>
	,@user --<created_by varchar(60)>
	,@user --<modified_by varchar(60)>
	,Generator.generator_name --<generator_name varchar(40)>
	,Generator.EPA_ID --<EPA_ID varchar(12)>
	,PROFILE.generator_id --<generator_id int>
	,Generator.generator_address_1 --<generator_address1 varchar(40)>
	,Customer.cust_name --<cust_name varchar(40)>
	,Customer.cust_addr1 --<cust_addr1 varchar(40)>
	,NULL --<inv_contact_name varchar(40)>
	,NULL --<inv_contact_phone varchar(20)>
	,NULL --<inv_contact_fax varchar(10)>
	,NULL --<tech_contact_name varchar(40)>
	,NULL --<tech_contact_phone varchar(20)>
	,NULL --<tech_contact_fax varchar(10)>
	,PROFILE.approval_desc --<waste_common_name varchar(50)>
	,WasteCode.waste_code_desc --<waste_code_comment text>
	,@amendment --<amendment text>
	,Generator.gen_mail_addr1 --<gen_mail_addr1 varchar(40)>
	,Generator.gen_mail_addr2 --<gen_mail_addr2 varchar(40)>
	,Generator.gen_mail_addr3 --<gen_mail_addr3 varchar(40)>
	,Generator.gen_mail_addr4 --<gen_mail_addr4 varchar(40)>
	,Generator.gen_mail_addr5 --<gen_mail_addr5 varchar(40)>
	,Generator.gen_mail_city --<gen_mail_city varchar(40)>
	,Generator.gen_mail_state --<gen_mail_state varchar(2)>
	,Generator.gen_mail_zip_code --<gen_mail_zip_code varchar(15)>
	,NULL --<profitcenter_epa_id varchar(12)>
	,NULL --<profitcenter_profit_ctr_name varchar(50)>
	,NULL --<profitcenter_address_1 varchar(40)>
	,NULL --<profitcenter_address_2 varchar(40)>
	,NULL --<profitcenter_address_3 varchar(40)>
	,NULL --<profitcenter_phone varchar(14)>
	,NULL --<profitcenter_fax varchar(14)>
	,PROFILE.waste_code --<waste_code varchar(4)>
	,newid() --<rowguid uniqueidentifier>
	,PROFILE.profile_id --<profile_id int>
	,PROFILE.ap_expiration_date --<ap_expiration_date datetime>
	,customer.cust_fax --<cust_fax varchar(10)>
	,@profChange --<profChange VARCHAR(4)>
	,@TAB
FROM Profile  
	LEFT JOIN Generator on Profile.generator_id = generator.generator_id  
	LEFT JOIN Customer ON Profile.customer_id = Customer.Customer_id
	JOIN FormType ON FormType.form_type = 'gwa'
	JOIN WasteCode ON Profile.waste_code_uid = WasteCode.waste_code_uid
WHERE Profile.curr_status_code = 'A'  
	AND Profile.profile_id = @profile_id
			
IF EXISTS (SELECT * FROM [FormXWasteCode] WHERE form_id = @form_id AND revision_id = @revision_id)
	DELETE FROM [FormXWasteCode] WHERE form_id = @form_id AND revision_id = @revision_id

	INSERT INTO [Plt_AI].[dbo].[FormXWasteCode]
           ([form_id]
           ,[revision_id]
           ,[page_number]
           ,[line_item]
           ,[waste_code]
           ,[specifier]
           ,[waste_code_uid])
     SELECT
           @form_id			--(<form_id, int,>
           ,@revision_id	--,<revision_id, int,>
           ,1				--,<page_number, int,>
           ,1				--,<line_item, int,>
           ,waste_code		--,<waste_code, char(4),>
           ,'GWA'			--,<specifier, varchar(30),>)
           ,waste_code_uid
        FROM ProfileWasteCode
           WHERE profile_id = @profile_id

IF EXISTS (SELECT * FROM [FormXApproval] WHERE form_id = @form_id AND revision_id = @revision_id)
	DELETE FROM [FormXApproval] WHERE form_id = @form_id AND revision_id = @revision_id

INSERT INTO [dbo].[FormXApproval] (
	[form_type]
	,[form_id]
	,[revision_id]
	,[company_id]
	,[profit_ctr_id]
	,[profile_id]
	,[approval_code]
	,[profit_ctr_name]
	,[profit_ctr_EPA_ID]
	)
SELECT 'GWA' --<form_type, char(10),>
	,@form_id --<form_id, int,>
	,@revision_id --<revision_id, int,>
	,ProfitCenter.company_ID --<company_id, int,>
	,PQA.profit_ctr_id --<profit_ctr_id, int,>
	,PROFILE.profile_id --<profile_id, int,>
	,PQA.approval_code --<approval_code, varchar(15),>
	,ProfitCenter.profit_ctr_name --<profit_ctr_name, varchar(50),>
	,ProfitCenter.EPA_ID --<profit_ctr_EPA_ID, varchar(12),>
FROM PROFILE
		inner join ProfileQuoteApproval PQA on Profile.profile_id = PQA.profile_id
		inner join ProfitCenter on PQA.profit_ctr_id = ProfitCenter.profit_ctr_id and PQA.company_id = ProfitCenter.company_id 
WHERE profile.profile_id = @profile_id
		AND EXISTS(SELECT top 1 1 from #copc where #copc.company_id = PQA.company_id AND #copc.profit_ctr_id = PQA.profit_ctr_id)
		


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_forms_gwa] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_forms_gwa] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_forms_gwa] TO [EQAI]
    AS [dbo];

