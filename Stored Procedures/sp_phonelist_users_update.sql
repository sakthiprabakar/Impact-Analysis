
create proc sp_phonelist_users_update (
	@user_id		int,
	@first_name		varchar(20),
	@last_name		varchar(20),
	@alias_name		varchar(40),
	@title			varchar(100),
	@addr1			varchar(40),
	@addr2			varchar(40),
	@addr3			varchar(40),
	@internal_phone	varchar(10), 
	@phone			varchar(20),
	@fax			varchar(20),
	@pager			varchar(20),
	@email			varchar(80), 
	@cell_phone		varchar(20),
	@pic_url		varchar(300),
	@added_by		varchar(8),
	@phone_list_location_id	int
)
as
	if @user_id is not null begin
		update users set 
			user_name = isnull(@first_name + ' ', '') + isnull(@last_name, ''),
			first_name = @first_name,
			last_name = @last_name,
			alias_name = @alias_name,
			title = @title,
			addr1 = @addr1, 
			addr2 = @addr2, 
			addr3 = @addr3, 
			internal_phone = @internal_phone, 
			phone = @phone, 
			fax = @fax, 
			pager = @pager, 
			email = @email, 
			cell_phone = @cell_phone, 
			pic_url = @pic_url,
			date_modified = getdate(),
			modified_by = @added_by,
			phone_list_location_id = @phone_list_location_id
		where user_id = @user_id
	end
	else
	begin
		declare @next_user_id int
		select @next_user_id = max(isnull(user_id,0))+1 from users
		insert users (
			user_id, 
			group_id,
			phone_list_flag,
			user_code, 
			user_name,
			first_name, 
			last_name, 
			alias_name,
			title, 
			addr1,
			addr2,
			addr3,
			internal_phone, 
			phone,
			fax,
			pager, 
			email, 
			cell_phone, 
			pic_url,
			date_added,
			added_by,
			date_modified,
			modified_by,
			rowguid,
			b2b_Access,
			b2b_remote_access,
			login_updated,
			phone_list_location_id
			)
		values (
			@next_user_id,
			-1,
			'A',
			'x' + right('0000000' + convert(Varchar(20), @next_user_id), 7), 
			isnull(@first_name + ' ', '') + isnull(@last_name, ''),
			@first_name, 
			@last_name, 
			@alias_name,
			@title, 
			@addr1,
			@addr2,
			@addr3,
			@internal_phone, 
			@phone,
			@fax,
			@pager, 
			@email, 
			@cell_phone, 
			@pic_url,
			getdate(),
			@added_by,
			getdate(),
			@added_by,
			newid(),
			'F',
			'F',
			null,
			@phone_list_location_id
			)
		end
		

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_phonelist_users_update] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_phonelist_users_update] TO [COR_USER]
    AS [dbo];


