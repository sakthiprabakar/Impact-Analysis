
CREATE PROCEDURE sp_forms_srec
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
	,@manifest varchar(20)
	,@exempt_id int
	,@copc_list varchar(255) = ''
	,@volume varchar(255) = NULL
	,@date_of_disposal varchar(255) = NULL
AS
/*********************************************************************************
10/25/2011 CRG Changed SP to use FormXApproval instead of storing approval info in 
	the form table
10/14/2011 CRG	Created
05/02/2013 JPB	waste_code_uid column added

sp_forms_srec
*********************************************************************************/
declare @company_id int, @profit_center int

IF LEN(@copc_list) > 0
BEGIN
    SELECT 
      @company_id = RTRIM(LTRIM(SUBSTRING(@copc_list, 1, CHARINDEX('|',@copc_list) - 1))) ,
      @profit_center = RTRIM(LTRIM(SUBSTRING(@copc_list, CHARINDEX('|',@copc_list) + 1, LEN(@copc_list) - (CHARINDEX('|',@copc_list)-1))))
END
ELSE
BEGIN
	SELECT @company_id = -99999999
		,@profit_center = -9999999
END

INSERT INTO [Plt_AI].[dbo].[FormSREC]
           ([form_id]
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
           ,[exempt_id]
           ,[waste_type]
           ,[waste_common_name]
           ,[manifest]
           ,[cust_name]
           ,[generator_name]
           ,[EPA_ID]
           ,[generator_id]
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
           ,[rowguid]
           ,[profile_id]
           ,[qty_units_desc]
           ,[disposal_date])
           --,[primary_waste_code]
           --,[secondary_waste_code])
     SELECT
		@form_id			--(<form_id, int,>
		,@revision_id		--,<revision_id, int,>
		,current_form_version --,<form_version_id, int,>
		,NULL --,<customer_id_from_form, int,>
		,Profile.customer_id--,<customer_id, int,>
		,NULL	--,<app_id, varchar(20),>
		,'A'	--,<status, char(1),>
		,'U'	--,<locked, char(1),>
		,'W'	--,<source, char(1),>
		,pqa.approval_code	--,<approval_code, varchar(15),>
		,Profile.profile_id	--,<approval_key, int,>
		,@company_id	--,<company_id, int,>
		,@profit_center	--,<profit_ctr_id, int,>
		,NULL	--,<signing_name, varchar(40),>
		,NULL	--,<signing_company, varchar(40),>
		,NULL	--,<signing_title, varchar(40),>
		,NULL	--,<signing_date, datetime,>
        ,GETDATE()		--,<date_created, datetime,>
        ,GETDATE()		--,<date_modified, datetime,>
        ,@user			--,<created_by, varchar(60),>
        ,@user			--,<modified_by, varchar(60),>
        ,@exempt_id		--,<exempt_id, int,>
        ,''				--,<waste_type, varchar(50),>
        ,Profile.approval_desc   --,<waste_common_name, varchar(50),>
		,@manifest	--,<manifest, varchar(20),>
		,Customer.cust_name		--,<cust_name, varchar(40),>
		,Generator.generator_name	--,<generator_name, varchar(40),>
		,Generator.EPA_ID	--,<EPA_ID, varchar(12),>
		,Profile.generator_id	--,<generator_id, int,>
		,Generator.gen_mail_addr1	--,<gen_mail_addr1, varchar(40),>
		,Generator.gen_mail_addr2	--,<gen_mail_addr2, varchar(40),>
		,Generator.gen_mail_addr3	--,<gen_mail_addr3, varchar(40),>
		,Generator.gen_mail_addr4	--,<gen_mail_addr4, varchar(40),>
		,RTrim(CASE WHEN (Generator.gen_mail_city + ', ' + Generator.gen_mail_state + ' ' + IsNull(Generator.gen_mail_zip_code,'')) IS NULL THEN 'Missing Mailing City, State, and ZipCode' 	ELSE (Generator.gen_mail_city + ', ' + Generator.gen_mail_state + ' ' + IsNull(Generator.gen_mail_zip_code,'')) END) --,<gen_mail_addr5, varchar(40),>
		,Generator.gen_mail_city	--,<gen_mail_city, varchar(40),>
		,Generator.gen_mail_state	--,<gen_mail_state, varchar(2),>
		,Generator.gen_mail_zip_code --,<gen_mail_zip_code, varchar(15),>
		,pc.EPA_ID	--,<profitcenter_epa_id, varchar(12),>
		,pc.profit_ctr_name	--,<profitcenter_profit_ctr_name, varchar(50),>
		,pc.address_1	--,<profitcenter_address_1, varchar(40),>
		,pc.address_2	--,<profitcenter_address_2, varchar(40),>
		,pc.address_3	--,<profitcenter_address_3, varchar(40),>
		,pc.phone	--,<profitcenter_phone, varchar(14),>
		,pc.fax	--,<profitcenter_fax, varchar(14),>
		,newid()	--,<rowguid, uniqueidentifier,>
		,Profile.profile_id		--,<profile_id, int,>
		--,Profile.waste_code		--,<primary_waste_code, varchar(4),>
		--,dbo.fn_sec_waste_code_list(Profile.Profile_id) --,<secondary_waste_code, varchar,>)
		,@volume
		,@date_of_disposal
	FROM Profile  
		inner join Customer on profile.customer_id = customer.customer_id  
		inner join Generator on profile.generator_id = generator.generator_id  
		inner join FormType on FormType.form_type = 'srec'
		left join ProfitCenter pc on pc.company_ID = @company_id AND pc.profit_ctr_ID = @profit_center 
		LEFT JOIN ProfileQuoteApproval pqa on pqa.company_id = @company_id AND pqa.profit_ctr_id = @profit_center AND pqa.profile_id = @profile_id
	WHERE 1=1
			AND Profile.curr_status_code = 'A'  
			AND Profile.profile_id = @profile_id

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
           ,'SREC'			--,<specifier, varchar(30),>)
           ,waste_code_uid
        FROM ProfileWasteCode
           WHERE profile_id = @profile_id


	DECLARE @temp_version int = (SELECT current_form_version FROM FormType where form_type = 'CC')
		,@temp_generator_id int = (SELECT generator_id FROM Profile where profile_id = @profile_id)
		
		EXEC Plt_Image..sp_DocProcessing_formview_insert
			@image_id			= @image_id,
			@report				= 'SREC',
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
    ON OBJECT::[dbo].[sp_forms_srec] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_forms_srec] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_forms_srec] TO [EQAI]
    AS [dbo];

