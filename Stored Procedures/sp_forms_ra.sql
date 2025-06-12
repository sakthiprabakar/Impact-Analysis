
CREATE PROCEDURE sp_forms_ra
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
	,@copc_list VARCHAR(255) = ''
	,@file_location VARCHAR(255) = NULL
	,@tab FLOAT = NULL
AS
/*********************************************************************************
Generates new ra pdf for view and signing

05/02/2013 JPB	waste_code_uid column added
11/19/2013 JPB	image_id default to 0 now... Also, removed the part of the sp using it.
				Added delete before insert

sp_forms_ra
*********************************************************************************/
	
	
create table #copc(
	company_id int,
	profit_ctr_id int
)

INSERT #copc 
    SELECT 
      RTRIM(LTRIM(SUBSTRING(row, 1, CHARINDEX('|',row) - 1))) company_id,
      RTRIM(LTRIM(SUBSTRING(row, CHARINDEX('|',row) + 1, LEN(row) - (CHARINDEX('|',row)-1)))) profit_ctr_id
    from dbo.fn_SplitXsvText(',', 0, @copc_list) 
    where isnull(row, '') <> ''     

IF EXISTS (SELECT * FROM [FormRA] WHERE form_id = @form_id AND revision_id = @revision_id)
	DELETE FROM [FormRA] WHERE form_id = @form_id AND revision_id = @revision_id

-- The same form_id could've been saved as an GWA last time. Clear that, too.
IF EXISTS (SELECT * FROM [FormGWA] WHERE form_id = @form_id AND revision_id = @revision_id)
	DELETE FROM [FormGWA] WHERE form_id = @form_id AND revision_id = @revision_id

	INSERT INTO [Plt_AI].[dbo].[FormRA]
           ([form_id]
           ,[revision_id]
           ,[form_version_id]
           ,[customer_id]
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
           ,[approval_ots_flag]
           ,[approval_waste_code]
           ,[approval_ap_expiration_date]
           ,[generator_generator_name]
           ,[wastecode_waste_code_desc]
           ,[approval_approval_desc]
           ,[customer_cust_addr1]
           ,[customer_cust_addr2]
           ,[customer_cust_addr3]
           ,[customer_cust_addr4]
           ,[customer_cust_city]
           ,[customer_cust_state]
           ,[customer_cust_zip_code]
           ,[customer_cust_name]
           ,[contact_id]
           ,[contact_name]
           ,[customer_cust_fax]
           ,[generator_id]
           ,[generator_epa_id]
           ,[profitcenter_profit_ctr_name]
           ,[profitcenter_address_1]
           ,[profitcenter_address_2]
           ,[profitcenter_address_3]
           ,[profitcenter_phone]
           ,[profitcenter_fax]
           ,[profitcenter_epa_id]
           ,[rowguid]
           ,[profile_id]
           ,[TAB]
           ,[benzene]
           )
		SELECT
			@form_id	--(<form_id, int,>
			,@revision_id	--,<revision_id, int,>
			,FormType.current_form_version	--,<form_version_id, int,>
			,p.customer_id	--,<customer_id, int,>
			,'A'	--,<status, char(1),>
			,'U'	--,<locked, char(1),>
			,'W'	--,<source, char(1),>
			,NULL	--,<approval_code, varchar(15),>
			,p.profile_id	--,<approval_key, int,>
			,NULL	--,<company_id, int,>
			,NULL	--,<profit_ctr_id, int,>
			,NULL		--,<signing_name, varchar(40),>
			,NULL		--,<signing_company, varchar(40),>
			,NULL		--,<signing_title, varchar(40),>
			,NULL		--,<signing_date, datetime,>
			,GETDATE()	--,<date_created, datetime,>
			,GETDATE()	--,<date_modified, datetime,>
			,@user	--,<created_by, varchar(60),>
			,@user	--,<modified_by, varchar(60),>
			,p.OTS_flag	--,<approval_ots_flag, varchar(1),>
			,p.waste_code	--,<approval_waste_code, varchar(4),>
			,p.ap_expiration_date	--,<approval_ap_expiration_date, datetime,>
			,g.generator_name	--,<generator_generator_name, varchar(40),>
			,WasteCode.waste_code_desc	--,<wastecode_waste_code_desc, varchar(60),>
			,p.approval_desc	--,<approval_approval_desc, varchar(50),>
			,c.cust_addr1	--,<customer_cust_addr1, varchar(40),>
			,c.cust_addr2	--,<customer_cust_addr2, varchar(40),>
			,c.cust_addr3	--,<customer_cust_addr3, varchar(40),>
			,c.cust_addr4	--,<customer_cust_addr4, varchar(40),>
			,c.cust_city	--,<customer_cust_city, varchar(40),>
			,c.cust_state	--,<customer_cust_state, varchar(2),>
			,c.cust_zip_code	--,<customer_cust_zip_code, varchar(15),>
			,c.cust_name	--,<customer_cust_name, varchar(40),>
			,Contact.contact_ID	--,<contact_id, int,>
			,Contact.name	--,<contact_name, varchar(40),>
			,c.cust_fax	--,<customer_cust_fax, varchar(10),>
			,g.generator_id	--,<generator_id, int,>
			,g.EPA_ID	--,<generator_epa_id, varchar(12),>
			,NULL	--,<profitcenter_profit_ctr_name, varchar(50),>
			,NULL		--,<profitcenter_address_1, varchar(40),>
			,NULL		--,<profitcenter_address_2, varchar(40),>
			,NULL		--,<profitcenter_address_3, varchar(40),>
			,NULL		--,<profitcenter_phone, varchar(14),>
			,NULL		--,<profitcenter_fax, varchar(14),>
			,NULL		--,<profitcenter_epa_id, varchar(12),>
			,NEWID()	--,<rowguid, uniqueidentifier,>
			,@profile_id	--,<profile_id, int,>
			,@tab	--,<TAB, float,>
			,pl.benzene	--,<benzene, float,>
           FROM PROFILE p
			   LEFT JOIN Customer c ON p.customer_id = c.customer_ID
			   LEFT JOIN ContactXRef ON p.customer_id = ContactXRef.customer_id AND ContactXRef.primary_contact = 'T'
			   LEFT JOIN Contact ON Contact.contact_ID = ContactXRef.contact_id
			   LEFT JOIN Generator g ON p.generator_id = g.generator_id
			   JOIN FormType ON FormType.form_type = 'RA'
			   LEFT JOIN WasteCode ON WasteCode.waste_code_uid = p.waste_code_uid
			   LEFT JOIN ProfileLab pl on p.profile_id = pl.profile_id and pl.type = 'A'
           WHERE p.profile_id = @profile_id

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
           ,'RA'			--,<specifier, varchar(30),>)
           ,waste_code_uid
        FROM ProfileWasteCode
           WHERE profile_id = @profile_id

IF EXISTS (SELECT * FROM [FormXApproval] WHERE form_id = @form_id AND revision_id = @revision_id)
	DELETE FROM [FormXApproval] WHERE form_id = @form_id AND revision_id = @revision_id

INSERT INTO [dbo].[FormXApproval]
           ([form_type]
           ,[form_id]
           ,[revision_id]
           ,[company_id]
           ,[profit_ctr_id]
           ,[profile_id]
           ,[approval_code]
           ,[profit_ctr_name]
           ,[profit_ctr_EPA_ID]
           ,[insurance_surcharge_percent]
           ,[ensr_exempt])
     SELECT DISTINCT
           'RA'					--<form_type, char(10),>
           ,@form_id					--<form_id, int,>
           ,@revision_id			--<revision_id, int,>
           ,ProfitCenter.company_ID	--<company_id, int,>
           ,PQA.profit_ctr_id		--<profit_ctr_id, int,>
           ,Profile.profile_id		--<profile_id, int,>
           ,PQA.approval_code		--<approval_code, varchar(15),>
           ,ProfitCenter.profit_ctr_name		--<profit_ctr_name, varchar(50),>
           ,ProfitCenter.EPA_ID		--<profit_ctr_EPA_ID, varchar(12),>
           ,NULL	--<insurance_surcharge_percent, char(1),>
           ,NULL		--<ensr_exempt, char(1),>
    FROM Profile
		--join FormLDR on FormLDR.form_id = @form_id and revision_id = @revision_id
		inner join ProfileQuoteApproval PQA on Profile.profile_id = PQA.profile_id
		inner join ProfitCenter on PQA.profit_ctr_id = ProfitCenter.profit_ctr_id and PQA.company_id = ProfitCenter.company_id 
		--inner join  FormLDRDetail on FormLDRDetail.form_id = FormLDR.form_id AND  FormLDRDetail.revision_id = FormLDR.revision_id 
	WHERE 
		profile.profile_id = @profile_id
		AND EXISTS(SELECT top 1 1 from #copc where #copc.company_id = PQA.company_id AND #copc.profit_ctr_id = PQA.profit_ctr_id)
		

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_forms_ra] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_forms_ra] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_forms_ra] TO [EQAI]
    AS [dbo];

