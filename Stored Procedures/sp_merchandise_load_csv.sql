
create procedure dbo.sp_merchandise_load_csv
	@merchandise_load_id int
as
/***************************************************************************************
 this procedure translates loaded CSV spreadshets into Merchandise-related table entries

 loads to Plt_ai
 
 05/29/2009 - rb created, different format from XLS that has lots of duplicates
****************************************************************************************/

declare @customer_id int,
	@customer_item_number varchar(255),
	@consumer_pack_upc varchar(255),
	@ndc_number varchar(255),
	@merchandise_desc varchar(255),
	@hazardous_ind varchar(255),
	@aerosol_ind varchar(255),
	@flammable_ind varchar(255),
	@product_category varchar(255),
	@manufacturer_id int,

	@load_user varchar(30),
	@load_date datetime,
	@merchandise_id int,
	@merchandise_type_id int,
	@merchandise_status char(1),

	@rec_count int,
	@msg_seq_no int,
	@records_loaded int,
	@warning_count int,
	@error_count int,

	@insert_new_merchandise int,
	@insert_customer_code int,
	@insert_upc_code int,
	@insert_manufacturer int

set nocount on

select @load_user = 'sa-' + convert(varchar(10), @merchandise_load_id),
	@load_date = getdate(),
	@records_loaded = 0,
	@warning_count = 0,
	@error_count = 0,
	@msg_seq_no = 0,
	@merchandise_status = 'N' -- default to new


select @customer_id = customer_id
from dbo.MerchandiseLoad
where merchandise_load_id = @merchandise_load_id


select @merchandise_type_id = merchandise_type_id
from dbo.MerchandiseType
where merchandise_type_desc = 'Merchandise'


declare c_loop cursor for
select ltrim(rtrim(customer_unique_item_number)),
	ltrim(rtrim(consumer_pack_upc)),
	ltrim(rtrim(ndc_number)),
	ltrim(rtrim(merchandise_desc)),
	ltrim(rtrim(hazardous_ind)),
	ltrim(rtrim(aerosol_ind)),
	ltrim(rtrim(flammable_ind)),
	ltrim(rtrim(product_category)) -- temporarily use this for Manufacturer
from dbo.MerchandiseLoadXLS
where merchandise_load_id = @merchandise_load_id
order by ltrim(rtrim(merchandise_desc)) asc
for read only

open c_loop

fetch c_loop
into @customer_item_number,
	@consumer_pack_upc,
	@ndc_number,
	@merchandise_desc,
	@hazardous_ind,
	@aerosol_ind,
	@flammable_ind,
	@product_category -- temporarily use this for Manufacturer

while @@FETCH_STATUS = 0
begin
	-- if an item exists with both the same Customer Code and UPC, consider it a dup
	if datalength(isnull(@consumer_pack_upc,'')) > 0 and
	   datalength(isnull(@customer_item_number,'')) > 0
	begin
		if exists (select 1
			from MerchandiseCode mc, MerchandiseCode mu
			where mc.merchandise_id = mu.merchandise_id
			and mc.code_type = 'C'
			and mc.customer_id = @customer_id
			and mc.merchandise_code = @customer_item_number
			and mu.code_type = 'U'
			and mu.merchandise_code = @consumer_pack_upc)
		begin
			select @msg_seq_no = @msg_seq_no + 1,
				@warning_count = @warning_count + 1
			begin transaction
			insert dbo.MerchandiseLoadMsg
			values (@merchandise_load_id, @msg_seq_no, 'W',
				'Item # ' + @customer_item_number + ', UPC code ' + @consumer_pack_upc + ' already exists: not loaded into database.')
			commit transaction
			goto NEXT_MERCHANDISE
		end
	end


	select @merchandise_id = null,
		@manufacturer_id = null,
		@insert_new_merchandise = 1,
		@insert_customer_code = 0,
		@insert_upc_code = 0,
		@insert_manufacturer = 0

	-- if an item exists with same Customer code and description, reuse the merchandise_id
	select @merchandise_id = m.merchandise_id
	from Merchandise m, MerchandiseCode mc
	where ltrim(rtrim(merchandise_desc)) = @merchandise_desc
	and m.merchandise_id = mc.merchandise_id
	and mc.code_type = 'C'
	and mc.customer_id = @customer_id
	and mc.merchandise_code = @customer_item_number

	-- if no item with same Customer code and description, check for same UPC and description
	if @merchandise_id is null
	begin
		select @insert_customer_code = 1

		select @merchandise_id = m.merchandise_id
		from Merchandise m, MerchandiseCode mc
		where ltrim(rtrim(merchandise_desc)) = @merchandise_desc
		and m.merchandise_id = mc.merchandise_id
		and mc.code_type = 'U'
		and mc.merchandise_code = @consumer_pack_upc

		if @merchandise_id is null
			select @insert_upc_code = 1
		else
			select @insert_new_merchandise = 0
	end
	else
		select @insert_new_merchandise = 0,
			@insert_upc_code = 1

	-- if inserting a new Merchandise record, allocate new merchandise_id
	if @merchandise_id is null
		exec @merchandise_id = dbo.sp_sequence_next 'Merchandise.merchandise_id', 0

	if @merchandise_id is null
	begin
		select @msg_seq_no = @msg_seq_no + 1,
			@error_count = @error_count + 1
		insert dbo.MerchandiseLoadMsg
		values (@merchandise_load_id, @msg_seq_no, 'E',
			'Could not allocate new merchandise_id.')
		goto NEXT_MERCHANDISE
	end


	-- 05/28/2009 RB - codes were included, only hardcode to U  if not set
	if datalength(isnull(@hazardous_ind,'')) < 1
		select @hazardous_ind = 'U'
	if datalength(isnull(@flammable_ind,'')) < 1
		select @flammable_ind = 'U'
	if datalength(isnull(@aerosol_ind,'')) < 1
		select @aerosol_ind = 'U'


	-- 09/03/2009 RB - see if manufacturer needs to be inserted
	if datalength(isnull(@product_category,'')) > 0
	begin
		select @manufacturer_id = manufacturer_id
		from Manufacturer
		where manufacturer_name = @product_category -- temp until manufacturer added to table

		if @manufacturer_id is null
		begin
			exec @manufacturer_id = dbo.sp_sequence_next 'Manufacturer.manufacturer_id', 0

			select @insert_manufacturer = 1
		end
	end

	-- BEGIN TRANSACTION
	begin transaction

	-- insert Merchandise
	if @insert_new_merchandise = 1
	begin
		insert dbo.Merchandise (merchandise_id, merchandise_desc, merchandise_status, merchandise_type_id,
					manufacturer_id, odor_ind, ORMD_ind, RCRA_haz_flag, RCRA_flammable_ind, aerosol_ind,
					special_handling, flash_pt, ph_range, entry_route, acute_exposure_eye,
					acute_exposure_skin, acute_exposure_inhalation, acute_exposure_ingestion,
					water_soluble, stability, incompatibility_flag, hazardous_polymerization,
					hazmat_flag, rq_flag, pharmaceutical_flag,
					added_by, date_added, modified_by, date_modified)
		values (@merchandise_id, @merchandise_desc, @merchandise_status, @merchandise_type_id, @manufacturer_id,
			'F', 'F', @hazardous_ind, @flammable_ind, @aerosol_ind,
			null, 'N/A', 'N/A', 'N/A', 'F', 'F', 'F', 'F', 'N', 'F', 'F', 'F', 'F', 'F', 'F',
			@load_user, @load_date, @load_user, @load_date)
		if @@error <> 0
		begin
			rollback transaction
			select @msg_seq_no = @msg_seq_no + 1,
				@error_count = @error_count + 1
			insert dbo.MerchandiseLoadMsg
			values (@merchandise_load_id, @msg_seq_no, 'E',
				'Item # ' + @customer_item_number + ' could not be inserted into Merchandise.')
			goto NEXT_MERCHANDISE
		end
	end


	-- insert MerchandiseCode
	-- Customer code
	if @insert_customer_code = 1
	begin
		insert dbo.MerchandiseCode (merchandise_id, customer_id, merchandise_code, code_type,
						added_by, date_added, modified_by, date_modified)
		values (@merchandise_id, @customer_id, @customer_item_number, 'C',
			@load_user, @load_date, @load_user, @load_date)

		if @@error <> 0
		begin
			rollback transaction
			select @msg_seq_no = @msg_seq_no + 1,
				@error_count = @error_count + 1
			insert dbo.MerchandiseLoadMsg
			values (@merchandise_load_id, @msg_seq_no, 'E',
				'Item # ' + @customer_item_number + ' could not be inserted into MerchandiseCode as a Customer Code.')
			goto NEXT_MERCHANDISE
		end
	end

	-- UPC
	if @insert_upc_code = 1
	begin
		insert dbo.MerchandiseCode (merchandise_id, customer_id, merchandise_code, code_type,
						added_by, date_added, modified_by, date_modified)
		values (@merchandise_id, null, @consumer_pack_upc, 'U',
			@load_user, @load_date, @load_user, @load_date)

		if @@error <> 0
		begin
			rollback transaction
			select @msg_seq_no = @msg_seq_no + 1,
				@error_count = @error_count + 1
			insert dbo.MerchandiseLoadMsg
			values (@merchandise_load_id, @msg_seq_no, 'E',
				'Item # ' + @customer_item_number + ' UPC ' + @consumer_pack_upc + ' could not be inserted into MerchandiseCode.')
			goto NEXT_MERCHANDISE
		end
	end

	-- NDC code
	if datalength(isnull(@ndc_number,'')) > 0
	begin
		insert dbo.MerchandiseCode (merchandise_id, customer_id, merchandise_code, code_type,
						added_by, date_added, modified_by, date_modified)
		values (@merchandise_id, null, @ndc_number, 'N',
			@load_user, @load_date, @load_user, @load_date)

		if @@error <> 0
		begin
			rollback transaction
			select @msg_seq_no = @msg_seq_no + 1,
				@error_count = @error_count + 1
			insert dbo.MerchandiseLoadMsg
			values (@merchandise_load_id, @msg_seq_no, 'E',
				'Item # ' + @customer_item_number + ' could not be inserted into MerchandiseCode as a Customer Code.')
			goto NEXT_MERCHANDISE
		end
	end


	-- Manufacturer
	-- 09/03/2009 - temporarily use product_category for manufacturer
	if @insert_manufacturer = 1
	begin
		insert dbo.Manufacturer (manufacturer_id, manufacturer_name, added_by, date_added, modified_by, date_modified)
		values (@manufacturer_id, @product_category, @load_user, @load_date, @load_user, @load_date)

		if @@error <> 0
		begin
			rollback transaction
			select @msg_seq_no = @msg_seq_no + 1,
				@error_count = @error_count + 1
			insert dbo.MerchandiseLoadMsg
			values (@merchandise_load_id, @msg_seq_no, 'E',
				'Manufacturer ' + @product_category + ' could not be inserted into Manufacturer table.')
			goto NEXT_MERCHANDISE
		end
	end


	-- COMMIT
	commit transaction
	select @records_loaded = @records_loaded + 1

NEXT_MERCHANDISE:
	select @customer_item_number = null,
		@consumer_pack_upc = null,
		@ndc_number = null,
		@merchandise_desc = null,
		@hazardous_ind = null,
		@aerosol_ind = null,
		@flammable_ind = null

	fetch c_loop
	into @customer_item_number,
		@consumer_pack_upc,
		@ndc_number,
		@merchandise_desc,
		@hazardous_ind,
		@aerosol_ind,
		@flammable_ind,
		@product_category
end

close c_loop
deallocate c_loop

update dbo.MerchandiseLoad
set records_loaded = @records_loaded,
    warning_count = @warning_count,
    error_count = @error_count
where merchandise_load_id = @merchandise_load_id

set nocount off

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_merchandise_load_csv] TO [EQAI]
    AS [dbo];

