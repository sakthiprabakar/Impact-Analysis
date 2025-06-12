
--/************************************************************
--Procedure	: sp_FormLDR_Update
--Database	: PLT_AI*
--Created		: 5-10-2004 - Jonathan Broome
--Description	: Updates any FormLDR records for the
--			  matching form_id + revision_id.
--************************************************************/
--Create Procedure sp_FormLDR_Update (
--@form_id						int,
--@revision_id					int,
--@group_id						int 			= NULL,
--@customer_id_from_form			int				= NULL,
--@customer_id					int				= NULL,
--@selected_companies				varchar(8000),
--@form_version					char(10)		= NULL,
--@app_id							varchar(20)		= NULL,
--@status							char(1),
--@locked							char(1),
--@signed_pin						char(10)		= NULL,
--@signing_name					varchar(40)		= NULL,
--@signing_company				varchar(40)		= NULL,
--@signing_title					varchar(40)		= NULL,
--@signing_date					datetime		= NULL,
--@username						char(10)		= NULL,
--@generator_name					varchar(40)		= NULL,
--@generator_epa_id				varchar(12)		= NULL,
--@generator_address1				varchar(40)		= NULL,
--@generator_city					varchar(40)		= NULL,
--@generator_state				varchar(2)		= NULL,
--@generator_zip					varchar(10)		= NULL,
--@state_manifest_no				varchar(20)		= NULL,
--@manifest_doc_no				varchar(20)		= NULL
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

--update FormLDR set
--	status							 = @status,
--	locked							 = @locked,
--	signed_pin						 = @signed_pin,
--	signing_name					 = @signing_name,
--	signing_company			    	 = @signing_company,
--	signing_title					 = @signing_title,
--	signing_date					 = @signing_date,
--	date_modified					 = GETDATE(),
--	modified_by				    	 = @username,
--	generator_name					 = @generator_name,
--	generator_epa_id				 = @generator_epa_id,
--	generator_address1				 = @generator_address1,
--	generator_city					 = @generator_city,
--	generator_state			    	 = @generator_state,
--	generator_zip					 = @generator_zip,
--	state_manifest_no				 = @state_manifest_no,
--	manifest_doc_no			    	 = @manifest_doc_no
--where
--	(form_id = @form_id and revision_id = @revision_id)
--	or (group_id = @group_id and @group_id is not null)

--set nocount off


--GO
--GRANT EXECUTE
--    ON OBJECT::[dbo].[sp_FormLDR_Update] TO [EQWEB]
--    AS [dbo];
--GO
--GRANT EXECUTE
--    ON OBJECT::[dbo].[sp_FormLDR_Update] TO [COR_USER]
--    AS [dbo];



--GO
--GRANT EXECUTE
--    ON OBJECT::[dbo].[sp_FormLDR_Update] TO [EQAI]
--    AS [dbo];

