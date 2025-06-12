
create procedure dbo.sp_merchandise_load_link_msds
	@merchandise_load_id int
as
/***************************************************************************************
 this procedure links loaded Excel spreadshets with ScanImages loaded with same UPC code

 loads to Plt_ai
 
 11/25/2008 - rb created
 
****************************************************************************************/

declare @image_id int,
	@customer_item_number varchar(255),
	@consumer_pack_upc varchar(255),
	
	@load_user varchar(30),
	@load_date datetime,
	@merchandise_id int,
	
	@scan_type_msds_id int,

	@rec_count int,
	@msg_seq_no int,
	@warning_count int,
	@error_count int

set nocount on

select @load_user = 'sa-' + convert(varchar(10), @merchandise_load_id),
	@load_date = getdate(),
	@warning_count = 0,
	@error_count = 0

-- find starting message sequence no
select @msg_seq_no = max(seq_no)
from dbo.MerchandiseLoadMsg
where merchandise_load_id = @merchandise_load_id

select @scan_type_msds_id = type_id
from Plt_image.dbo.ScanDocumentType
where scan_type = 'merchandise'
and document_type = 'MSDS'

-- LOOP
declare c_loop cursor for
select mlx.customer_unique_item_number,
	mlx.consumer_pack_upc,
	mc.merchandise_id
from dbo.MerchandiseLoadXLS mlx,
     dbo.MerchandiseCode mc
where mlx.merchandise_load_id = @merchandise_load_id
and mlx.consumer_pack_upc = mc.merchandise_code
and mc.code_type = 'U'
for read only

open c_loop

fetch c_loop
into @customer_item_number,
	@consumer_pack_upc,
	@merchandise_id

while @@FETCH_STATUS = 0
begin

	-- look for a document link
	select @image_id = null

	select @rec_count = count(*)
	from Plt_image.dbo.Scan
	where type_id = @scan_type_msds_id
	and merchandise_id is not null
	and document_name like 'DOC' + @consumer_pack_upc + '_%'

	if @rec_count > 1
	begin
		select @msg_seq_no = @msg_seq_no + 1,
			@warning_count = @warning_count + 1
		insert dbo.MerchandiseLoadMsg
		values (@merchandise_load_id, @msg_seq_no, 'W',
			convert(varchar(10),@rec_count) + ' matches found for MSDS item number ' + @consumer_pack_upc + ' in Scan.')
	end

	set rowcount 1
	select @image_id = image_id
	from Plt_image.dbo.Scan
	where type_id = @scan_type_msds_id
	and merchandise_id is not null
	and document_name like 'DOC' + @consumer_pack_upc + '_%'
	order by image_id desc
	set rowcount 0

	if @image_id is not null
	begin
		begin transaction

		update Plt_image.dbo.Scan
		set merchandise_id = @merchandise_id
		where image_id = @image_id

		if @@error <> 0
		begin
			rollback transaction
			select @msg_seq_no = @msg_seq_no + 1,
				@error_count = @error_count + 1
			insert dbo.MerchandiseLoadMsg
			values (@merchandise_load_id, @msg_seq_no, 'E',
				'Item # ' + @customer_item_number + ' could not update Scan table with merchandise_id.')
			goto NEXT_MERCHANDISE
		end

		commit transaction
	end

NEXT_MERCHANDISE:
	fetch c_loop
	into @customer_item_number,
		@consumer_pack_upc,
		@merchandise_id
end

close c_loop
deallocate c_loop

update dbo.MerchandiseLoad
set warning_count = isnull(warning_count,0) + @warning_count,
    error_count = isnull(error_count,0) + @error_count
where merchandise_load_id = @merchandise_load_id

set nocount off

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_merchandise_load_link_msds] TO [EQAI]
    AS [dbo];

