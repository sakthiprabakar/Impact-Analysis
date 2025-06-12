
create proc sp_phonelist_location_changerequest (
	@phone_list_location_id	int,
	@company_id			int,
	@profit_ctr_id		int,
	@name				varchar(50),
	@address_1			varchar(40),
	@address_2			varchar(40),
	@address_3			varchar(40),
	@city				varchar(50),
	@state				varchar(2),
	@zip_code			varchar(10),
	@phone				varchar(20),
	@toll_free_phone	varchar(20),
	@fax				varchar(20),
	@internal_phone		varchar(10),
	@short_name			varchar(10),
	@alias_name			varchar(40),
	@added_by			varchar(8),
	@ip_address			varchar(20),
	@debug				int = 0
)
as
/* ********************************************************************************************

sp_phonelist_location_changerequest 9, 3, 1, 'Wayne Disposal, Inc.', 
	'49350 North I-94 Service Drive', '', '', 'Belleville', 'MI', 
	'48111', '7346996201', '8005925489', '8005925329', '', 'EQWDI', 
	'wdi landfill', 'JONATHAN', 1
	
select * from PhoneListLocation where phone_list_location_id = 9

select top 40 * from message order by message_id desc

******************************************************************************************** */

	DECLARE 
		@body varchar(8000), 
		@changes varchar(7000), 
		@crlf varchar(5), 
		@crlf2 varchar(10)
		
	SELECT 
		@crlf = char(13) + char(10), 
		@crlf2 = @crlf + @crlf, 
		@body = 'Phone List Location data change request:' + @crlf2, 
		@changes = ''

	DECLARE 
		@db_company_id			int,
		@db_profit_ctr_id		int,
		@db_name				varchar(50),
		@db_address_1			varchar(40),
		@db_address_2			varchar(40),
		@db_address_3			varchar(40),
		@db_city				varchar(50),
		@db_state				varchar(2),
		@db_zip_code			varchar(10),
		@db_phone				varchar(20),
		@db_toll_free_phone		varchar(20),
		@db_fax					varchar(20),
		@db_internal_phone		varchar(10),
		@db_short_name			varchar(10),
		@db_alias_name			varchar(40),
		@message_id				int

	if @phone_list_location_id is not null begin

		select 
			@db_company_id		= company_id		,
			@db_profit_ctr_id	= profit_ctr_id		,
			@db_name			= name				,
			@db_address_1		= address_1			,
			@db_address_2		= address_2			,
			@db_address_3		= address_3			,
			@db_city			= city				,
			@db_state			= state				,
			@db_zip_code		= zip_code			,
			@db_phone			= phone				,
			@db_toll_free_phone	= toll_free_phone	,	
			@db_fax				= fax				,	
			@db_internal_phone	= internal_phone	,	
			@db_short_name		= short_name		,	
			@db_alias_name		= alias_name		
		from PhoneListLocation
		where phone_list_location_id = @phone_list_location_id
		
		SELECT 
			@db_phone = replace(replace(replace(replace(replace(isnull(@db_phone, ''), ' ', ''), '-', ''), '(', ''), ')', ''), '.', ''),
			@phone = replace(replace(replace(replace(replace(isnull(@phone, ''), ' ', ''), '-', ''), '(', ''), ')', ''), '.', ''),
			@db_toll_free_phone = replace(replace(replace(replace(replace(isnull(@db_toll_free_phone, ''), ' ', ''), '-', ''), '(', ''), ')', ''), '.', ''),
			@toll_free_phone = replace(replace(replace(replace(replace(isnull(@toll_free_phone, ''), ' ', ''), '-', ''), '(', ''), ')', ''), '.', ''),
			@db_fax = replace(replace(replace(replace(replace(isnull(@db_fax, ''), ' ', ''), '-', ''), '(', ''), ')', ''), '.', ''),
			@fax = replace(replace(replace(replace(replace(isnull(@fax, ''), ' ', ''), '-', ''), '(', ''), ')', ''), '.', '')

		set @body = @body + 'phone_list_location_id: ' + convert(varchar(10), @phone_list_location_id) + @crlf

		if isnull(@db_company_id, -999) <> isnull(@company_id, -999) set @changes = @changes + 'Company ID from ''' + isnull(convert(varchar(10), @db_company_id), '') + ''' to ''' + isnull(convert(varchar(10), @company_id), '') + ''',' + @crlf
		if isnull(@db_profit_ctr_id, -999) <> isnull(@profit_ctr_id, -999) set @changes = @changes + 'Profit Ctr ID from ''' + isnull(convert(varchar(10), @db_profit_ctr_id), '') + ''' to ''' + isnull(convert(varchar(10), @profit_ctr_id), '') + ''',' + @crlf
		if isnull(@db_name, '') <> isnull(@name, '') set @changes = @changes + 'Name from ''' + isnull(@db_name, '') + ''' to ''' + isnull(@name, '') + ''',' + @crlf
		if isnull(@db_address_1, '') <> isnull(@address_1, '') set @changes = @changes + 'Address 1 from ''' + isnull(@db_address_1, '') + ''' to ''' + isnull(@address_1, '') + ''',' + @crlf
		if isnull(@db_address_2, '') <> isnull(@address_2, '') set @changes = @changes + 'Address 2 from ''' + isnull(@db_address_2, '') + ''' to ''' + isnull(@address_2, '') + ''',' + @crlf
		if isnull(@db_address_3, '') <> isnull(@address_3, '') set @changes = @changes + 'Address 3 from ''' + isnull(@db_address_3, '') + ''' to ''' + isnull(@address_3, '') + ''',' + @crlf
		if isnull(@db_city, '') <> isnull(@city, '') set @changes = @changes + 'City from ''' + isnull(@db_city, '') + ''' to ''' + isnull(@city, '') + ''',' + @crlf
		if isnull(@db_state, '') <> isnull(@state, '') set @changes = @changes + 'State from ''' + isnull(@db_state, '') + ''' to ''' + isnull(@state, '') + ''',' + @crlf
		if isnull(@db_zip_code, '') <> isnull(@zip_code, '') set @changes = @changes + 'Zip Code from ''' + isnull(@db_zip_code, '') + ''' to ''' + isnull(@zip_code, '') + ''',' + @crlf
		if isnull(@db_phone, '') <> isnull(@phone, '') set @changes = @changes + 'Phone from ''' + isnull(@db_phone, '') + ''' to ''' + isnull(@phone, '') + ''',' + @crlf
		if isnull(@db_toll_free_phone, '') <> isnull(@toll_free_phone, '') set @changes = @changes + 'Toll Free Phone from ''' + isnull(@db_toll_free_phone, '') + ''' to ''' + isnull(@db_toll_free_phone, '') + ''',' + @crlf
		if isnull(@db_fax, '') <> isnull(@fax, '') set @changes = @changes + 'Fax from ''' + isnull(@db_fax, '') + ''' to ''' + isnull(@fax, '') + ''',' + @crlf
		if isnull(@db_internal_phone, '') <> isnull(@internal_phone, '') set @changes = @changes + 'Internal Phone from ''' + isnull(@db_internal_phone, '') + ''' to ''' + isnull(@internal_phone, '') + ''',' + @crlf
		if isnull(@db_short_name, '') <> isnull(@short_name, '') set @changes = @changes + 'Short Name from ''' + isnull(@db_short_name, '') + ''' to ''' + isnull(@short_name, '') + ''',' + @crlf
		if isnull(@db_alias_name, '') <> isnull(@alias_name, '') set @changes = @changes + 'Alias Name from ''' + isnull(@db_alias_name, '') + ''' to ''' + isnull(@alias_name, '') + ''',' + @crlf

		if @debug > 0 begin
			select 
				'debug info:' as debug,
				@db_company_id		  db_company_id	,	
				@db_profit_ctr_id	  db_profit_ctr_id	,
				@db_name			  db_name			,
				@db_address_1		  db_address_1		,
				@db_address_2		  db_address_2		,
				@db_address_3		  db_address_3		,
				@db_city			  db_city			,
				@db_state			  db_state			,
				@db_zip_code		  db_zip_code		,
				@db_phone			  db_phone			,
				@db_toll_free_phone	  db_toll_free_phone,	
				@db_fax				  db_fax			,	
				@db_internal_phone	  db_internal_phone	,
				@db_short_name		  db_short_name		,
				@db_alias_name		  db_alias_name
			union select
				'input info:' as debug,
				@company_id		  company_id	,	
				@profit_ctr_id	  profit_ctr_id	,
				@name			  name			,
				@address_1		  address_1		,
				@address_2		  address_2		,
				@address_3		  address_3		,
				@city			  city			,
				@state			  state			,
				@zip_code		  zip_code		,
				@phone			  phone			,
				@toll_free_phone	  toll_free_phone,	
				@fax				  fax			,	
				@internal_phone	  internal_phone	,
				@short_name		  short_name		,
				@alias_name		  alias_name
				
			select
				@body as body, 
				@changes as changes
			
		end
		

		if len(ltrim(@changes)) > 0 begin
		
			set @body = @body + @changes
			set @body = @body + @crlf + 'Requested by ' + isnull(@added_by, '')
			set @body = @body + @crlf + 'Requesting IP ' + isnull(@ip_address, '') + @crlf2
			

			EXEC @message_id = sp_sequence_next 'message.message_id'
		
			INSERT INTO Message (message_id, status, message_type, message_source, subject, message, html, added_by, date_added) 
				select 
					@message_id, 
					'N', 
					'E',
					'EQIP PhoneList', 
					'EQIP Phone Location Change Request: ' + isnull(@name, ''),
					@body, 
					null,
					@added_by,
					GetDate()

			INSERT INTO MessageAddress(message_id, address_type, email) Values
						   (@message_id, 'TO', 'itadmin@eqonline.com')

			INSERT INTO MessageAddress(message_id, address_type, name, company, email) Values
						   (@message_id, 'FROM', 'EQ Online', 'EQ', 'donotreply@eqonline.com')

		end
			
		
		
	end
		

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_phonelist_location_changerequest] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_phonelist_location_changerequest] TO [COR_USER]
    AS [dbo];


