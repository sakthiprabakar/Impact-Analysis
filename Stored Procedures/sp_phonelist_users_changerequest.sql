
create proc sp_phonelist_users_changerequest (
	@user_id		int,
	@first_name		varchar(20),
	@last_name		varchar(20),
	@title			varchar(100),
	@internal_phone	varchar(10), 
	@phone			varchar(20),
	@fax			varchar(20),
	@pager			varchar(20),
	@email			varchar(80), 
	@cell_phone		varchar(20),
	@added_by		varchar(8),
	@phone_list_location_id	int,
	@ip_address			varchar(20),
	@debug			int = 0
)
as
/* ********************************************************************************************

sp_phonelist_users_changerequest 627, 'Jonathan', 'Broome', 'Programmer Analyst', '8054', '7343298054', '7343298135', '', 'jonathan.broome@eqonline.com', '7345760182', 'JONATHAN', 34, 1

select phone, fax, * from users where user_id = 627

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
		@body = 'Phone List User data change request:' + @crlf2, 
		@changes = ''

	DECLARE 
		@db_first_name		varchar(20),
		@db_last_name		varchar(20),
		@db_title			varchar(100),
		@db_internal_phone	varchar(10), 
		@db_phone			varchar(20),
		@db_fax				varchar(20),
		@db_pager			varchar(20),
		@db_email			varchar(80), 
		@db_cell_phone		varchar(20),
		@db_phone_list_location_id	int,
		@message_id			int

	if @user_id is not null begin

		select @db_first_name = first_name,
			@db_last_name = last_name,
			@db_title = title,
			@db_internal_phone = internal_phone,
			@db_phone = phone,
			@db_fax = fax,
			@db_pager = pager,
			@db_email = email,
			@db_cell_phone = cell_phone,
			@db_phone_list_location_id = phone_list_location_id
		from users
		where user_id = @user_id
		
		SELECT 
			@db_phone = replace(replace(replace(replace(replace(isnull(@db_phone, ''), ' ', ''), '-', ''), '(', ''), ')', ''), '.', ''),
			@phone = replace(replace(replace(replace(replace(isnull(@phone, ''), ' ', ''), '-', ''), '(', ''), ')', ''), '.', ''),
			@db_fax = replace(replace(replace(replace(replace(isnull(@db_fax, ''), ' ', ''), '-', ''), '(', ''), ')', ''), '.', ''),
			@fax = replace(replace(replace(replace(replace(isnull(@fax, ''), ' ', ''), '-', ''), '(', ''), ')', ''), '.', ''),
			@db_pager = replace(replace(replace(replace(replace(isnull(@db_pager, ''), ' ', ''), '-', ''), '(', ''), ')', ''), '.', ''),
			@pager = replace(replace(replace(replace(replace(isnull(@pager, ''), ' ', ''), '-', ''), '(', ''), ')', ''), '.', ''),
			@db_cell_phone = replace(replace(replace(replace(replace(isnull(@db_cell_phone, ''), ' ', ''), '-', ''), '(', ''), ')', ''), '.', ''),
			@cell_phone = replace(replace(replace(replace(replace(isnull(@cell_phone, ''), ' ', ''), '-', ''), '(', ''), ')', ''), '.', '')

		IF @debug > 0 begin
			select @db_phone AS db_phone, @phone AS phone, @db_fax AS db_fax, @fax AS fax, @db_pager AS db_pager, @pager AS pager, @db_cell_phone AS db_cell_phone, @cell_phone AS cell_phone
		end

		
		set @body = @body + 'User_ID: ' + convert(varchar(10), @user_id) + @crlf

		if isnull(@db_first_name, '') <> isnull(@first_name, '') set @changes = @changes + 'First_Name from ''' + isnull(@db_first_name, '') + ''' to ''' + isnull(@first_name, '') + ''',' + @crlf
		if isnull(@db_last_name, '') <> isnull(@last_name, '') set @changes = @changes + 'Last_Name from ''' + isnull(@db_last_name, '') + ''' to ''' + isnull(@last_name, '') + ''',' + @crlf
		if isnull(@db_title, '') <> isnull(@title, '') set @changes = @changes + 'Title from ''' + isnull(@db_title, '') + ''' to ''' + isnull(@title, '') + ''',' + @crlf
		if isnull(@db_email, '') <> isnull(@email, '') set @changes = @changes + 'Email from ''' + isnull(@db_email, '') + ''' to ''' + isnull(@email, '') + ''',' + @crlf
		if isnull(@db_internal_phone, '') <> isnull(@internal_phone, '') set @changes = @changes + 'Internal Phone from ''' + isnull(@db_internal_phone, '') + ''' to ''' + isnull(@internal_phone, '') + ''',' + @crlf
		if isnull(@db_phone, '') <> isnull(@phone, '') set @changes = @changes + 'Phone from ''' + isnull(@db_phone, '') + ''' to ''' + isnull(@phone, '') + ''',' + @crlf
		if isnull(@db_fax, '') <> isnull(@fax, '') set @changes = @changes + 'Fax from ''' + isnull(@db_fax, '') + ''' to ''' + isnull(@fax, '') + ''',' + @crlf
		if isnull(@db_pager, '') <> isnull(@pager, '') set @changes = @changes + 'Pager from ''' + isnull(@db_pager, '') + ''' to ''' + isnull(@pager, '') + ''',' + @crlf
		if isnull(@db_cell_phone, '') <> isnull(@cell_phone, '') set @changes = @changes + 'Cell_Phone from ''' + isnull(@db_cell_phone, '') + ''' to ''' + isnull(@cell_phone, '') + ''',' + @crlf
		if isnull(@db_phone_list_location_id, -999) <> isnull(@phone_list_location_id, -999) 
			begin
				declare @phone_list_location_name varchar(50)
					, @db_phone_list_location_name varchar(50)

				select @db_phone_list_location_name = isnull(name, 'No Location Name!?') from PhoneListLocation where phone_list_location_id	= isnull(@db_phone_list_location_id, -999)
				select @phone_list_location_name = isnull(name, 'No Location Name!?') from PhoneListLocation where phone_list_location_id	= isnull(@phone_list_location_id, -999)

				set @changes = @changes + 'Phone_List_Location_ID from ' + isnull(convert(varchar(10), @db_phone_list_location_id), '') + '(' + @db_phone_list_location_name + ') to ' + isnull(convert(varchar(10), @phone_list_location_id), '') + ' (' + @phone_list_location_name + '),' + @crlf
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
					'EQIP Phone List Change Request: ' + isnull(@first_name, '') + ' ' + isnull(@last_name, ''),
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
    ON OBJECT::[dbo].[sp_phonelist_users_changerequest] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_phonelist_users_changerequest] TO [COR_USER]
    AS [dbo];


