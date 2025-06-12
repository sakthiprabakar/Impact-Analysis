
create proc sp_phonelist_location_update (
		@phone_list_location_id		int,
		@company_id			int,
		@profit_ctr_id		int,
		@name				varchar(50),
		@alias_name			varchar(40),
		@address_1			varchar(40),
		@address_2			varchar(40),
		@address_3			varchar(40),
		@city				varchar(50),
		@state				varchar(2),
		@zip_code			varchar(10),
		@internal_phone			varchar(10),
		@phone				varchar(20),
		@toll_free_phone	varchar(20),
		@fax				varchar(20),
		@short_name			varchar(10),
		@added_by			varchar(8)
)
as
	if @phone_list_location_id is not null begin
		update PhoneListLocation set 
			company_id			=@company_id		,
			profit_ctr_id		=@profit_ctr_id	,
			name				=@name			,
			alias_name			=@alias_name,
			address_1			=@address_1		,
			address_2			=@address_2		,
			address_3			=@address_3		,
			city				=@city			,
			state				=@state			,
			zip_code			=@zip_code		,
			internal_phone			=@internal_phone		,
			phone				=@phone			,
			toll_free_phone		=@toll_free_phone,
			fax					=@fax			,
			short_name			=@short_name	,	
			date_modified = getdate(),
			modified_by = @added_by
		where phone_list_location_id = @phone_list_location_id
	end
	else
	begin
		insert PhoneListLocation (
			company_id			,
			profit_ctr_id		,
			name				,
			alias_name,
			address_1			,
			address_2			,
			address_3			,
			city				,
			state				,
			zip_code			,
			internal_phone			,
			phone				,
			toll_free_phone		,
			fax					,
			short_name			,
			date_added,
			added_by,
			date_modified,
			modified_by
			)
		values (
			@company_id		,
			@profit_ctr_id	,
			@name			,
			@alias_name,
			@address_1		,
			@address_2		,
			@address_3		,
			@city			,
			@state			,
			@zip_code		,
			@internal_phone		,
			@phone			,
			@toll_free_phone,
			@fax			,
			@short_name		,
			getdate(),
			@added_by,
			getdate(),
			@added_by
			)
		end

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_phonelist_location_update] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_phonelist_location_update] TO [COR_USER]
    AS [dbo];


