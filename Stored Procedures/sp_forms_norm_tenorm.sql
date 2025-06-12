
CREATE PROCEDURE sp_forms_norm_tenorm
	@user varchar(255)
	,@revision_id int
	,@form_id int 
	,@debug int = 0
	,@profile_id int
	,@session_id varchar(12)
	,@ip_address varchar(40) = ''
	,@image_id int
	,@contact_id int = 0
	,@file_location varchar(255) = NULL
	,@NORM char(1) = NULL
	,@TENORM char(1) = NULL
	,@disposal_restriction_exempt char(1) = NULL
	,@nuclear_reg_state_license char(1) = NULL
	,@disposal_facility_code varchar(10) = NULL
	,@waste_process varchar(1000) = NULL
	,@volume float = NULL
	,@unit varchar(8) = NULL
	,@unit_other varchar(100) = NULL
	,@shipping_dates varchar(255) = NULL
	,@copc_list varchar(MAX) = NULL
AS
/*********************************************************************************
sp_forms_norm_tenorm

Populates a NORM/TENORM form from parameters

3/1/2011 CRG - Created

sp_sequence_next 'Form.form_id'			
exec sp_sequence_next 'ScanImage.image_id'

exec sp_forms_norm_tenorm
	@user = 'JONATHAN'
	,@revision_id = 1
	,@form_id = 194719 
	,@debug = 0
	,@profile_id = 343472
	,@session_id = '1234567890'
	,@ip_address  = '1.1.1.1'
	,@image_id = 5319060
	,@contact_id = 0
	,@file_location = '\\web01test\eqai\pdf'
	,@NORM = 'Y'
	,@TENORM = 'N'
	,@disposal_restriction_exempt = 'Y'
	,@nuclear_reg_state_license = 'N'
	,@disposal_facility_code = NULL
	,@waste_process = 'la la la al '
	,@volume  = 6789
	,@unit = 'DM55'
	,@unit_other = 'BiG Stuff'
	,@shipping_dates = '1/1/2013'
	,@copc_list = NULL

		EXEC Plt_Image..sp_DocProcessing_formview_insert
			@image_id			= @image_id,
			@report				= 'normtenorm',
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

	
*********************************************************************************/

INSERT INTO [dbo].[FormNORMTENORM]
   ([form_id]
   ,[revision_id]
   ,[version_id]
   ,[status]
   ,[locked]
   ,[source]
   ,[company_id]
   ,[profit_ctr_id]
   ,[profile_id]
   ,[approval_code]
   ,[generator_id]
   ,[generator_epa_id]
   ,[generator_name]
   ,[generator_address_1]
   ,[generator_address_2]
   ,[generator_address_3]
   ,[generator_address_4]
   ,[generator_address_5]
   ,[generator_city]
   ,[generator_state]
   ,[generator_zip_code]
   ,[site_name]
   ,[gen_mail_addr1]
   ,[gen_mail_addr2]
   ,[gen_mail_addr3]
   ,[gen_mail_addr4]
   ,[gen_mail_addr5]
   ,[gen_mail_city]
   ,[gen_mail_state]
   ,[gen_mail_zip]
   ,[NORM]
   ,[TENORM]
   ,[disposal_restriction_exempt]
   ,[nuclear_reg_state_license]
   ,[waste_process]
   ,[unit_other]
   ,[shipping_dates]
   ,[signing_name]
   ,[signing_company]
   ,[signing_title]
   ,[signing_date]
   ,[date_created]
   ,[date_modified]
   ,[created_by]
   ,[modified_by])
SELECT
   @form_id
   ,@revision_id
   ,FormType.current_form_version
   ,'A' 
   ,'U' 
   ,'W'
   ,NULL
   ,NULL
   ,Profile.profile_id
   ,NULL
   ,Profile.generator_id
   ,Generator.EPA_ID
   ,Generator.generator_name
   ,Generator.generator_address_1
   ,Generator.generator_address_2
   ,Generator.generator_address_3
   ,Generator.generator_address_4
   ,Generator.generator_address_5
   ,Generator.generator_city
   ,Generator.generator_state
   ,Generator.generator_state
   ,Generator.generator_zip_code
   ,generator.gen_mail_addr1
   ,generator.gen_mail_addr2
   ,generator.gen_mail_addr3
   ,generator.gen_mail_addr4
   ,generator.gen_mail_addr5
   ,generator.gen_mail_city
   ,generator.gen_mail_state
   ,generator.gen_mail_zip_code
   ,@NORM
   ,@TENORM
   ,@disposal_restriction_exempt
   ,@nuclear_reg_state_license
   ,@waste_process
   ,@unit_other
   ,@shipping_dates
   ,NULL
   ,NULL
   ,NULL
   ,NULL
   ,GETDATE()
   ,GETDATE()
   ,@user
   ,@user
  FROM Profile  
		--inner join ProfileQuoteApproval PQA on Profile.profile_id = PQA.profile_id 
		--inner join Customer on profile.customer_id = customer.customer_id  
		inner join Generator on profile.generator_id = generator.generator_id  
		--inner join ProfitCenter on PQA.profit_ctr_id = ProfitCenter.profit_ctr_id and PQA.company_id = ProfitCenter.company_id  
		inner join FormType on FormType.form_type = 'normtenorm'
	WHERE 1=1
			AND Profile.curr_status_code = 'A'  
			AND Profile.profile_id = @profile_id
	
	CREATE TABLE #copc (
	company_id INT
	,profit_ctr_id INT
	)

	INSERT #copc
	SELECT RTRIM(LTRIM(SUBSTRING(row, 1, CHARINDEX('|', row) - 1))) company_id
		,RTRIM(LTRIM(SUBSTRING(row, CHARINDEX('|', row) + 1, LEN(row) - (CHARINDEX('|', row) - 1)))) profit_ctr_id
	from dbo.fn_SplitXsvText(',', 0, @copc_list)
	WHERE isnull(row, '') <> ''


	--formxapproval
	INSERT INTO [Plt_AI].[dbo].[FormXApproval]
           ([form_type]
           ,[form_id]
           ,[revision_id]
           ,[company_id]
           ,[profit_ctr_id]
           ,[profile_id]
           ,[approval_code]
           ,[profit_ctr_name]
           ,[profit_ctr_EPA_ID])
     SELECT
           'normtenorm'		--form_type, char(10)
           ,@form_id		--form_id, int
           ,@revision_id	--revision_id, int
           ,pc.company_ID	--company_id, int
           ,pc.profit_ctr_ID	--profit_ctr_id, int
           ,@profile_id		--profile_id, int
           ,NULL			--approval_code, varchar(15)
           ,pc.profit_ctr_name	--profit_ctr_name, varchar(50)
           ,pc.EPA_ID		--profit_ctr_EPA_ID, varchar(12)
	FROM FormFacility f
		INNER JOIN ProfitCenter pc ON f.company_id = pc.company_ID AND f.profit_ctr_id = pc.profit_ctr_ID
		INNER JOIN #copc ON #copc.company_id = pc.company_ID AND #copc.profit_ctr_id = pc.profit_ctr_ID
	WHERE f.norm_applicable_flag = 'T'
		AND f.version = (SELECT MAX(version) FROM FormFacility)
		
	DECLARE @temp_version int = (SELECT current_form_version FROM FormType where form_type = 'normtenorm')
		,@temp_generator_id int = (SELECT generator_id FROM Profile where profile_id = @profile_id)
		
		EXEC Plt_Image..sp_DocProcessing_formview_insert
			@image_id			= @image_id,
			@report				= 'normtenorm',
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
		

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_forms_norm_tenorm] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_forms_norm_tenorm] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_forms_norm_tenorm] TO [EQAI]
    AS [dbo];

