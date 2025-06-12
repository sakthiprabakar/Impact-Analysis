
create proc sp_phonelist_item_update (
	@item_id		int,
	@name			varchar(40),
	@alias_name		varchar(40),
	@internal_phone	varchar(10), 
	@phone			varchar(20),
	@fax			varchar(20),
	@added_by		varchar(8),
	@phone_list_location_id	int
)
as
	if @item_id is not null begin
		update PhoneListItem set 
			name = @name,
			alias_name = @alias_name,
			internal_phone = @internal_phone, 
			phone = @phone, 
			fax = @fax, 
			date_modified = getdate(),
			modified_by = @added_by,
			phone_list_location_id = @phone_list_location_id
		where item_id = @item_id
	end
	else
	begin
		insert PhoneListItem (
			name, 
			alias_name,
			internal_phone, 
			phone,
			fax,
			date_added,
			added_by,
			date_modified,
			modified_by,
			phone_list_location_id
			)
		values (
			@name, 
			@alias_name,
			@internal_phone, 
			@phone,
			@fax,
			getdate(),
			@added_by,
			getdate(),
			@added_by,
			@phone_list_location_id
			)
		end


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_phonelist_item_update] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_phonelist_item_update] TO [COR_USER]
    AS [dbo];


