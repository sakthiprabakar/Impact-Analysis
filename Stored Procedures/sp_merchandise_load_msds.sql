
create procedure dbo.sp_merchandise_load_msds
	@merchandise_load_id int
as
/***************************************************************************************
 this procedure inserts uploaded binary MSDS PDFs and images into Scan / ScanImage tables
 
 loads to Plt_ai

 11/20/2008 - rb created
 
****************************************************************************************/

declare @file_path varchar(255),
	@item_number varchar(255),
	@item_description varchar(255),
	@item_extension varchar(255),
	@rec_count int,

	@image_id int,
	@load_user varchar(30),
	@load_date datetime,
	@scan_type_id int,
	@doc_name varchar(255),
	@current_scan_db varchar(30),
	@sql varchar(4096),

	@records_loaded int,
	@warning_count int,
	@error_count int,
	@msg_seq_no int

set nocount on

select @load_user = 'sa-' + convert(varchar(10), @merchandise_load_id),
	@load_date = getdate(),
	@records_loaded = 0,
	@warning_count = 0,
	@error_count = 0,
	@msg_seq_no = 0

-- get current scan db
select @current_scan_db = current_database
from Plt_image.dbo.ScanCurrentDB

-- save files as scan type MSDS
select @scan_type_id = type_id
from Plt_image.dbo.ScanDocumentType
where scan_type = 'merchandise'
and document_type = 'MSDS'

---
--- MSDS SCAN IMAGES
---
declare c_loop cursor for
select file_path,
	item_number,
	item_description,
	item_extension
from dbo.MerchandiseLoadMSDS
where merchandise_load_id = @merchandise_load_id
for read only

open c_loop
fetch c_loop
into @file_path,
	@item_number,
	@item_description,
	@item_extension

while @@FETCH_STATUS = 0
begin
	-- Look for Scan with description beginning with UPC code
	-- If one doesn't exist, insert a new record
	-- When processing spreadsheet data, pull from Scan table
	select @image_id = null

	select @rec_count = count(*)
	from Plt_image.dbo.Scan
	where type_id = @scan_type_id
	and document_name like 'DOC' + @item_number + '_%'

	if @rec_count <> 0
	begin
		select @msg_seq_no = @msg_seq_no + 1,
			@warning_count = @warning_count + 1
		insert dbo.MerchandiseLoadMsg
		values (@merchandise_load_id, @msg_seq_no, 'W',
			convert(varchar(10),@rec_count) + ' matches found for MSDS item number ' + @item_number + ' in Scan.')
		goto NEXT_MSDS
	end

	exec @image_id = dbo.sp_sequence_next 'ScanImage.image_id'
	if @image_id is null
	begin
		print 'Error - Could not allocate a new image_id.'
		goto NEXT_MSDS
	end

	select @sql = 'insert ' + @current_scan_db + '.dbo.ScanImage' +
			' select ' + convert(varchar(10),@image_id) + ', msds_contents' +
			' from dbo.MerchandiseLoadMSDS' +
			' where merchandise_load_id = ' + convert(varchar(10),@merchandise_load_id) +
			' and file_path = ''' + replace(@file_path,'''','''''') + ''''

	begin transaction
	exec (@sql)

	if @@error <> 0
	begin
		rollback transaction
		select @msg_seq_no = @msg_seq_no + 1,
			@error_count = @error_count + 1
		insert dbo.MerchandiseLoadMsg
		values (@merchandise_load_id, @msg_seq_no, 'E',
			'MSDS item number ' + @item_number + ' could not be inserted into ScanImage.')
		goto NEXT_MSDS
	end

	select @doc_name = 'DOC' + @item_number + '_' + convert(varchar(10),@image_id) + '.' + @item_extension

	insert Plt_image.dbo.Scan (image_id, document_source, type_id, status, document_name,
				description, image_resolution, scan_file, form_type, file_type, app_source,
				upload_date, date_added, date_modified, added_by, modified_by,
				merchandise_id)
	values (@image_id, 'merchandise', @scan_type_id, 'A', @doc_name,
		@item_description, 100, @file_path, 'ATTACH', @item_extension, 'EQAI',
		@load_date, @load_date, @load_date, @load_user, @load_user,
		(@merchandise_load_id * -1)) -- so we can track orphaned uploads to merchandise_load_id

	if @@error <> 0
	begin
		rollback transaction
		select @msg_seq_no = @msg_seq_no + 1,
			@error_count = @error_count + 1
		insert dbo.MerchandiseLoadMsg
		values (@merchandise_load_id, @msg_seq_no, 'E',
			'MSDS item number ' + @item_number + ' could not be inserted into Scan.')
		goto NEXT_MSDS
	end

	-- COMMIT
	commit transaction
	select @records_loaded = @records_loaded + 1

NEXT_MSDS:
	fetch c_loop
	into @file_path,
		@item_number,
		@item_description,
		@item_extension
end

close c_loop
deallocate c_loop

update dbo.MerchandiseLoad
set records_loaded = @records_loaded,
    warning_count = @warning_count,
    error_count = @error_count
where merchandise_load_id = @merchandise_load_id

set nocount off
return 0

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_merchandise_load_msds] TO [EQAI]
    AS [dbo];

