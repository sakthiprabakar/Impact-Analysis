
--/************************************************************
--Procedure	: sp_FormSREC_Update
--Database	: PLT_AI*
--Created		: 5-10-2004 - Jonathan Broome
--Description	: Updates any FormSREC records for the
--			  matching form_id + revision_id.
--************************************************************/
--Create Procedure sp_FormSREC_Update (
--@form_id						int,
--@revision_id					int,
--@group_id						int				= NULL,
--@customer_id_from_form			int				= NULL,
--@customer_id					char(10),
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
--@exempt_reason					varchar(15)		= NULL,
--@waste_type						varchar(50) 	= NULL,
--@waste_common_name				varchar(50) 	= NULL,
--@qty_units						varchar(100)	= NULL,
--@manifest						varchar(20) 	= NULL,
--@approval						varchar(20) 	= NULL
--)
--as

--DECLARE
--	@pos int,
--	@company_profitcenter varchar(30),
--	@tmp_list varchar(8000)

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

--update FormSREC set
--	status							= @status,
--	locked							= @locked,
--	signed_pin						= @signed_pin,
--	signing_name					= @signing_name,
--	signing_company					= @signing_company,
--	signing_title					= @signing_title,
--	signing_date					= @signing_date,
--	date_modified					= GETDATE(),
--	modified_by						= @username,
--	exempt_reason					= @exempt_reason,
--	waste_type						= @waste_type,
--	waste_common_name				= @waste_common_name,
--	qty_units						= @qty_units,
--	manifest						= @manifest,
--	approval						= @approval

--where
--	(form_id = @form_id and revision_id = @revision_id)
--	or (group_id = @group_id and @group_id is not null)

--set nocount off


--GO
--GRANT EXECUTE
--    ON OBJECT::[dbo].[sp_FormSREC_Update] TO [EQWEB]
--    AS [dbo];
--GO
--GRANT EXECUTE
--    ON OBJECT::[dbo].[sp_FormSREC_Update] TO [COR_USER]
--    AS [dbo];



--GO
--GRANT EXECUTE
--    ON OBJECT::[dbo].[sp_FormSREC_Update] TO [EQAI]
--    AS [dbo];

