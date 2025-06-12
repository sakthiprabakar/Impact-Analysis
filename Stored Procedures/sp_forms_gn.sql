
CREATE PROCEDURE sp_forms_gn
	@user varchar(255)
	,@revision_id int
	,@form_id int
	,@debug int = 0
	,@profile_id int
	,@session_id varchar(12)
	,@ip_address varchar(40) = ''
	,@image_id int = 0
	,@contact_id int = 0
	,@copc_list varchar(max) = ''
	,@file_location varchar(255) = NULL
	--,@generator_name varchar(255) = NULL
AS
/*********************************************************************************
Generates new gn pdf for viewing, no signing

05/02/2013 JPB	waste_code_uid column added
11/18/2013	JPB	Commented out the docproc call at the end.  That should get called separately.
				Also added image_id default of 0
11/18/2013	JPB	Added deletes ahead of the other tables' inserts
01/22/2016	JPB	Changed "Profile.approval_comments" to "Profile.comments_1" to match sp_rpt_generator_approval_notification
06/16/2023 Nagaraj M Modified the input parameter @copc_list varchar(255) to @copc_list varchar(max)

sp_forms_gn
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

IF EXISTS (SELECT * FROM [FormGN] WHERE form_id = @form_id AND revision_id = @revision_id)
	DELETE FROM [FormGN] WHERE form_id = @form_id AND revision_id = @revision_id

	INSERT INTO [Plt_AI].[dbo].[FormGN]
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
           ,[customer_cust_name]
           ,[customer_cust_fax]
           ,[generator_id]
           ,[generator_epa_id]
           ,[generator_gen_mail_name]
           ,[generator_gen_mail_address_1]
           ,[generator_gen_mail_address_2]
           ,[generator_gen_mail_address_3]
           ,[generator_gen_mail_address_4]
           ,[generator_gen_mail_address_5]
           ,[generator_gen_mail_city]
           ,[generator_gen_mail_state]
           ,[generator_gen_mail_zip_code]
           ,[generator_generator_contact]
           ,[approval_waste_code]
           ,[approval_approval_desc]
           ,[approval_comments_1]
           ,[approval_ap_expiration_date]
           ,[approval_ots_flag]
           ,[wastecode_waste_code_desc]
           ,[profitcenter_profit_ctr_name]
           ,[profitcenter_address_1]
           ,[profitcenter_address_2]
           ,[profitcenter_address_3]
           ,[profitcenter_phone]
           ,[profitcenter_fax]
           ,[profitcenter_epa_id]
           ,[secondary_waste_code]
           ,[rowguid]
           ,[profile_id]
           ,[generator_name])
     SELECT
			@form_id		--<form_id, int,>
			,@revision_id	--,<revision_id, int,>
			,FormType.current_form_version --,<form_version_id, int,>
			,Profile.customer_id	--,<customer_id, int,>
			,'A'	--,<status, char(1),>
			,'U'	--,<locked, char(1),>
			,'W'	--,<source, char(1),>
			,NULL	--,<approval_code, varchar(15),>
			,Profile.profile_id		--,<approval_key, int,>
			,NULL	--,[company_id]
			,NULL	--,[profit_ctr_id]
			,NULL	--,<signing_name, varchar(40),>
			,NULL	--,<signing_company, varchar(40),>
			,NULL	--,<signing_title, varchar(40),>
			,NULL	--,<signing_date, datetime,>
			,GETDATE()	--,<date_created, datetime,>
			,GETDATE()	--,<date_modified, datetime,>
			,@user	--,<created_by, varchar(60),>
			,@user	--,<modified_by, varchar(60),>
			,Customer.cust_name		--,<customer_cust_name, varchar(40),>
			,Customer.cust_fax		--,<customer_cust_fax, varchar(10),>
			,Profile.generator_id	--,<generator_id, int,>
			,Generator.EPA_ID		--,<generator_epa_id, varchar(12),>
			,CASE WHEN Isnull(Profile.generator_id, 0) = 0 THEN Customer.cust_name ELSE Generator.gen_mail_name END	--,<generator_gen_mail_name, varchar(40),>
			,CASE WHEN Isnull(Profile.generator_id, 0) = 0 THEN Customer.cust_addr1 ELSE Generator.gen_mail_addr1 END	--,<generator_gen_mail_address_1, varchar(40),>
			,CASE WHEN Isnull(Profile.generator_id, 0) = 0 THEN Customer.cust_addr2 ELSE Generator.gen_mail_addr2 END	--,<generator_gen_mail_address_2, varchar(40),>
			,CASE WHEN Isnull(Profile.generator_id, 0) = 0 THEN Customer.cust_addr3 ELSE Generator.gen_mail_addr3 END	--,<generator_gen_mail_address_3, varchar(40),>
			,CASE WHEN Isnull(Profile.generator_id, 0) = 0 THEN Customer.cust_addr4 ELSE Generator.gen_mail_addr4 END	--,<generator_gen_mail_address_4, varchar(40),>
			,CASE WHEN Isnull(Profile.generator_id, 0) = 0 THEN Customer.cust_addr5 ELSE Generator.gen_mail_addr5 END	--,<generator_gen_mail_address_5, varchar(40),>
			,CASE WHEN Isnull(Profile.generator_id, 0) = 0 THEN Customer.cust_city ELSE Generator.gen_mail_city END	--,<generator_gen_mail_city, varchar(40),>
			,CASE WHEN Isnull(Profile.generator_id, 0) = 0 THEN Customer.cust_state ELSE Generator.gen_mail_state END	--,<generator_gen_mail_state, varchar(2),>
			,CASE WHEN Isnull(Profile.generator_id, 0) = 0 THEN Customer.cust_zip_code ELSE Generator.gen_mail_zip_code END	--,<generator_gen_mail_zip_code, varchar(15),>
			,CASE WHEN Isnull(Profile.generator_id, 0) = 0 THEN (SELECT contact.NAME	--,<generator_generator_contact, varchar(40),>
															FROM ContactXRef cxr
															INNER JOIN contact ON contact.contact_id = cxr.contact_id
															WHERE cxr.primary_contact = 'T'
																AND cxr.customer_id = PROFILE.customer_id
															) 
													ELSE (SELECT contact.NAME	--,<generator_generator_contact, varchar(40),>
															FROM ContactXRef cxr
															INNER JOIN contact ON contact.contact_id = cxr.contact_id
															WHERE cxr.primary_contact = 'T'
																AND cxr.generator_id = PROFILE.generator_id
															) 
													END
			,Profile.waste_code		--,<approval_waste_code, varchar(4),>
			,Profile.approval_desc	--,<approval_approval_desc, varchar(50),>
			,Profile.comments_1	--,<approval_comments_1, text,>
			,Profile.ap_expiration_date	--,<approval_ap_expiration_date, datetime,>
			,Profile.OTS_flag	--,<approval_ots_flag, char(1),>
			,WasteCode.waste_code_desc	--,<wastecode_waste_code_desc, varchar(60),>
			,NULL	--,<profitcenter_profit_ctr_name, varchar(50),>
			,NULL	--,<profitcenter_address_1, varchar(40),>
			,NULL	--,<profitcenter_address_2, varchar(40),>
			,NULL	--,<profitcenter_address_3, varchar(40),>
			,NULL	--,<profitcenter_phone, varchar(14),>
			,NULL	--,<profitcenter_fax, varchar(14),>
			,NULL	--,<profitcenter_epa_id, varchar(12),>
			,NULL -- dbo.fn_sec_waste_code_list(@profile_id) --,<secondary_waste_code, text,>
			,Newid()	--,<rowguid, uniqueidentifier,>
			,@profile_id --,<profile_id, int,>
			,Generator.generator_name	--,<generator_name, varchar(40),>
           FROM PROFILE
			   LEFT JOIN Customer ON Profile.customer_id = Customer.customer_ID
			   LEFT JOIN Generator ON Profile.generator_id = Generator.generator_id
			   JOIN FormType ON FormType.form_type = 'GN'
			   LEFT JOIN WasteCode ON WasteCode.waste_code_uid = Profile.waste_code_uid
           WHERE profile_id = @profile_id

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
           ,'GN'			--,<specifier, varchar(30),>)
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
           ,[profit_ctr_EPA_ID])
     SELECT DISTINCT
           'GN'					--<form_type, char(10),>
           ,@form_id					--<form_id, int,>
           ,@revision_id			--<revision_id, int,>
           ,ProfitCenter.company_ID	--<company_id, int,>
           ,PQA.profit_ctr_id		--<profit_ctr_id, int,>
           ,Profile.profile_id		--<profile_id, int,>
           ,PQA.approval_code		--<approval_code, varchar(15),>
           ,ProfitCenter.profit_ctr_name		--<profit_ctr_name, varchar(50),>
           ,ProfitCenter.EPA_ID
    FROM Profile
		--join FormLDR on FormLDR.form_id = @form_id and revision_id = @revision_id
		inner join ProfileQuoteApproval PQA on Profile.profile_id = PQA.profile_id
		inner join ProfitCenter on PQA.profit_ctr_id = ProfitCenter.profit_ctr_id and PQA.company_id = ProfitCenter.company_id 
		--inner join  FormLDRDetail on FormLDRDetail.form_id = FormLDR.form_id AND  FormLDRDetail.revision_id = FormLDR.revision_id 
	WHERE 
		profile.profile_id = @profile_id
		AND EXISTS(SELECT top 1 1 from #copc where #copc.company_id = PQA.company_id AND #copc.profit_ctr_id = PQA.profit_ctr_id)
		
/*		

	DECLARE @temp_version int = (SELECT current_form_version FROM FormType where form_type = 'gn')
		,@temp_generator_id int = (SELECT generator_id FROM Profile where profile_id = @profile_id)
		
		EXEC Plt_Image..sp_DocProcessing_formview_insert
			@image_id			= @image_id,
			@report				= 'GN',
			@company_id			= NULL,
			@profit_ctr_id		= NULL,
			@form_id			= @form_id,
			@revision_id		= @revision_id,
			@form_version_id	= @temp_version,
			@approval_code		= NULL,
			@profile_id			= @profile_id,
			@file_location		= @file_location,
			@contact_id			= @contact_id,
			@server_flag		= 'S',
			@app_source			= 'WEB',
			@print_pdf			= 1,
			@ip_address			= @ip_address,
			@session_id			= @session_id,
			@added_by			= @user,
			@generator_id		= @temp_generator_id
*/			

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_forms_gn] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_forms_gn] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_forms_gn] TO [EQAI]
    AS [dbo];

