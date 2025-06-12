
--/************************************************************
--Procedure	: sp_FormGWA_Update
--Database	: PLT_AI*
--Created		: 5-10-2004 - Jonathan Broome
--Description	: Updates any FormGWA records for the
--			  matching form_id + revision_id.
--12/16/2004 JPB Modified to take Generator_id and EPA_ID
--07/08/2019	JPB	Cust_name: 40->75 / Generator_Name: 40->75
--************************************************************/
--Create Procedure sp_FormGWA_Update (
--@form_id						int,
--@revision_id					int,
--@group_id						int 			= NULL,
--@customer_id_from_form			int				= NULL,
--@customer_id					int				= NULL,
--@selected_companies				varchar(8000),
--@form_version					char(10) 		= NULL,
--@app_id							varchar(20)		= NULL,
--@status							char(1),
--@locked							char(1),
--@signed_pin						char(10) 		= NULL,
--@signing_name					varchar(40) 	= NULL,
--@signing_company				varchar(40) 	= NULL,
--@signing_title					varchar(40) 	= NULL,
--@signing_date					datetime 		= NULL,
--@username						char(10) 		= NULL,
--@approval						varchar(20) 	= NULL,
--@generator_name					varchar(75) 	= NULL,
--@epa_id							varchar(12) 	= NULL,
--@generator_id					int			 	= NULL,
--@generator_address1				varchar(75) 	= NULL,
--@cust_name						varchar(75) 	= NULL,
--@cust_addr1						varchar(75) 	= NULL,
--@inv_contact_name				varchar(40) 	= NULL,
--@inv_contact_phone				varchar(20) 	= NULL,
--@inv_contact_fax				varchar(10) 	= NULL,
--@tech_contact_name				varchar(40) 	= NULL,
--@tech_contact_phone				varchar(20) 	= NULL,
--@tech_contact_fax				varchar(10) 	= NULL,
--@waste_common_name				varchar(50) 	= NULL,
--@waste_code_comment				text			= NULL,
--@amendment						text 			= NULL
--)
--as

--DECLARE
--	@pos int,
--	@company_profitcenter varchar(30),
--	@tmp_list varchar(8000)

--set nocount on
--exec('sp_FormXProfitCenter_Delete ' + @form_id + ', ' + @revision_id)

--set @tmp_list = replace(@selected_companies, ' ', '')
--set @pos = 0

--WHILE datalength(@tmp_list) > 0
--BEGIN
--	select @pos = CHARINDEX(',', @tmp_list)
--	if @pos > 0
--	begin
--		select @company_profitcenter = SUBSTRING(@tmp_list, 1, @pos - 1)
--		select @tmp_list = SUBSTRING(@tmp_list, @pos + 1, datalength(@tmp_list) - @pos)
--	end
--	if @pos = 0
--	begin
--		select @company_profitcenter = @tmp_list
--		select @tmp_list = NULL
--	end
--	exec('sp_FormXProfitCenter_Insert ' + @form_id + ', ' + @revision_id + ', ''' + @company_profitcenter + '''')
--END
--set nocount off

--update FormGWA set
--	status							= @status,
--	locked							= @locked,
--	signed_pin						= @signed_pin,
--	signing_name					= @signing_name,
--	signing_company					= @signing_company,
--	signing_title					= @signing_title,
--	signing_date					= @signing_date,
--	date_modified					= GETDATE(),
--	modified_by						= @username,
--	approval						= @approval,
--	generator_name					= @generator_name,
--	epa_id							= @epa_id,
--	generator_id					= @generator_id,
--	generator_address1				= @generator_address1,
--	cust_name						= @cust_name,
--	cust_addr1						= @cust_addr1,
--	inv_contact_name				= @inv_contact_name,
--	inv_contact_phone				= @inv_contact_phone,
--	inv_contact_fax					= @inv_contact_fax,
--	tech_contact_name				= @tech_contact_name,
--	tech_contact_phone				= @tech_contact_phone,
--	tech_contact_fax				= @tech_contact_fax,
--	waste_common_name				= @waste_common_name,
--	waste_code_comment				= @waste_code_comment,
--	amendment						= @amendment
--where
--	(form_id = @form_id and revision_id = @revision_id)
--	or (group_id = @group_id and @group_id is not null)

--set nocount off


--GO
--GRANT EXECUTE
--    ON OBJECT::[dbo].[sp_FormGWA_Update] TO [EQWEB]
--    AS [dbo];
--GO
--GRANT EXECUTE
--    ON OBJECT::[dbo].[sp_FormGWA_Update] TO [COR_USER]
--    AS [dbo];



--GO
--GRANT EXECUTE
--    ON OBJECT::[dbo].[sp_FormGWA_Update] TO [EQAI]
--    AS [dbo];

