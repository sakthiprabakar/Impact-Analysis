create procedure [dbo].[sp_merchandise_load_dea_rcra]
	@merchandise_load_id int,
	@dea_only_flag char(1)
as
/***************************************************************************************
 this procedure translates loaded Excel spreadshets into Merchandise-related table entries

 loads to Plt_ai
 
 01/08/2010 - rb created
****************************************************************************************/

declare @customer_id int,
	@customer_item_number varchar(255),
	@consumer_pack_upc varchar(255),
	@ndc_number varchar(255),
	@merchandise_desc varchar(255),
	@ORMD_ind varchar(255),
	@hazardous_ind varchar(255),
	@aerosol_ind varchar(255),
	@flammable_ind varchar(255),
	@product_category varchar(255),
	@RCRA_waste_code_1 varchar(255),
	@state_waste_code varchar(255),
	@state_waste_code_2 varchar(255),
	@special_handling varchar(255),
	@pharmaceutical_flag char(1),
	@pharmaceutical_type char(3),
	@RCRA_haz_flag char(1),
	@product_use_id int,
	@idx int,

	@load_user varchar(30),
	@load_date datetime,
	@merchandise_id int,
	@merchandise_type_id int,
	@merchandise_status char(1),

	@category_id int,

	@rec_count int,
	@msg_seq_no int,
	@records_loaded int,
	@warning_count int,
	@error_count int

set nocount on

select @load_user = 'sa-' + convert(varchar(10), @merchandise_load_id),
	@load_date = getdate(),
	@records_loaded = 0,
	@warning_count = 0,
	@error_count = 0,
	@msg_seq_no = 0

select @customer_id = customer_id
from dbo.MerchandiseLoad
where merchandise_load_id = @merchandise_load_id

select @merchandise_type_id = merchandise_type_id
from dbo.MerchandiseType
where merchandise_type_desc = 'Merchandise'

select @product_use_id = product_use_id
from dbo.ProductUse
where product_use_desc = 'Pharmaceutical'

select @pharmaceutical_flag = 'T',
		@pharmaceutical_type = 'DEA'
		
declare c_loop cursor for
select ltrim(rtrim(customer_unique_item_number)),
	ltrim(rtrim(ndc_number)),
	ltrim(rtrim(merchandise_desc)),
	ltrim(rtrim(product_category)),
	ltrim(rtrim(RCRA_waste_code_1)),
	ltrim(rtrim(state_waste_code)),
	ltrim(rtrim(special_handling)) -- DEA Schedule stuffed in there
from dbo.MerchandiseLoadXLS
where merchandise_load_id = @merchandise_load_id
order by ltrim(rtrim(merchandise_desc)) asc
for read only

open c_loop

fetch c_loop
into @customer_item_number,
	@ndc_number,
	@merchandise_desc,
	@product_category,
	@RCRA_waste_code_1,
	@state_waste_code,
	@special_handling

while @@FETCH_STATUS = 0
begin
	if datalength(isnull(@ndc_number,'')) > 0 and
	   datalength(isnull(@customer_item_number,'')) > 0
	begin
		if exists (select 1
			from MerchandiseCode mc, MerchandiseCode mn
			where mc.code_type = 'C'
			and mc.merchandise_code = @customer_item_number
			and mc.customer_id = @customer_id
			and mc.merchandise_id = mn.merchandise_id
			and mn.code_type = 'N'
			and mn.merchandise_code = @ndc_number)
		begin
			select @msg_seq_no = @msg_seq_no + 1,
				@warning_count = @warning_count + 1
			begin transaction
			insert dbo.MerchandiseLoadMsg
			values (@merchandise_load_id, @msg_seq_no, 'W',
				'Item # ' + @customer_item_number + ' NDC code ' + @consumer_pack_upc + ' already exists: not loaded into database.')
			commit transaction
			goto NEXT_MERCHANDISE
		end
	end


	-- determine if category exists
	select @category_id = null
	select @category_id = mc.category_id
	from dbo.MerchandiseLoadCategoryMap mlcp, dbo.MerchandiseCategory mc, dbo.MerchandiseCategoryCustomer mcc
	where mlcp.spreadsheet_description = @product_category
	and mlcp.load_description = mc.category_desc
	and mc.category_id = mcc.category_id
	and mcc.customer_id = @customer_id

	if @category_id is null and @product_category is not null
		select @category_id = category_id
		from dbo.MerchandiseCategory
		where category_desc = @product_category

	-- Merchandise Status
	-- if DEA Only then Approved, if DEA and RCRA then New
	if @dea_only_flag = 'T'
		select @merchandise_status = 'A',
				@RCRA_haz_flag = 'F'
	-- else, status is 'New'
	else
		select @merchandise_status = 'N',
				@RCRA_haz_flag = 'T'

	-- allocate new merchandise_id
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

	-- 12/02/2008 RB - THESE INDICATORS HAVE NOT BEEN VALIDATED, HARDCODE TO 'U'
		select @hazardous_ind = 'U',
				@flammable_ind = 'U',
				@aerosol_ind = 'U'

	begin transaction

	-- insert Merchandise
	insert dbo.Merchandise (merchandise_id, merchandise_desc, merchandise_status, merchandise_type_id, category_id,
				odor_ind, product_use_id, ORMD_ind, RCRA_haz_flag, RCRA_flammable_ind, aerosol_ind,
				special_handling, flash_pt, ph_range, entry_route, acute_exposure_eye,
				acute_exposure_skin, acute_exposure_inhalation, acute_exposure_ingestion,
				water_soluble, stability, incompatibility_flag, hazardous_polymerization,
				hazmat_flag, rq_flag, pharmaceutical_flag, pharmaceutical_type, DEA_schedule,
				added_by, date_added, modified_by, date_modified)
	values (@merchandise_id, @merchandise_desc, @merchandise_status, @merchandise_type_id, @category_id,
		'F', @product_use_id, case @ORMD_ind when 'Y' then 'T' else 'F' end, @RCRA_haz_flag, @flammable_ind, @aerosol_ind,
		null, 'N/A', 'N/A', 'N/A', 'F', 'F', 'F', 'F',
		'N', 'F', 'F', 'F', 'F', 'F', @pharmaceutical_flag, @pharmaceutical_type, @special_handling,
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


	-- insert MerchandiseCode
	-- Customer code
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

	-- insert MerchandiseWaste
	if datalength(isnull(@RCRA_waste_code_1,'')) > 0
	begin
		insert dbo.MerchandiseWasteCode (merchandise_id, waste_code,
						added_by, date_added, modified_by, date_modified)
		values (@merchandise_id, @RCRA_waste_code_1,
			@load_user, @load_date, @load_user, @load_date)
		if @@error <> 0
		begin
			rollback transaction
			select @msg_seq_no = @msg_seq_no + 1,
				@error_count = @error_count + 1
			insert dbo.MerchandiseLoadMsg
			values (@merchandise_load_id, @msg_seq_no, 'E',
				'Item # ' + @customer_item_number + ' could not insert ' + @RCRA_waste_code_1 + ' into MerchandiseWasteCode.')
			goto NEXT_MERCHANDISE
		end
	end
	if datalength(isnull(@state_waste_code,'')) > 0
	begin
		select @idx = charindex(',',@state_waste_code)
		if @idx > 0
		begin
			select @state_waste_code_2 = ltrim(rtrim(substring(@state_waste_code,@idx+1,datalength(@state_waste_code)-@idx)))
			select @state_waste_code = ltrim(rtrim(substring(@state_waste_code,1,@idx-1)))
		end
		else
			select @state_waste_code_2 = null
				
		insert dbo.MerchandiseWasteCode (merchandise_id, waste_code,
						added_by, date_added, modified_by, date_modified)
		values (@merchandise_id, @state_waste_code,
			@load_user, @load_date, @load_user, @load_date)
		if @@error <> 0
		begin
			rollback transaction
			select @msg_seq_no = @msg_seq_no + 1,
				@error_count = @error_count + 1
			insert dbo.MerchandiseLoadMsg
			values (@merchandise_load_id, @msg_seq_no, 'E',
				'Item # ' + @customer_item_number + ' could not insert ' + @state_waste_code + ' into MerchandiseWasteCode.')
			goto NEXT_MERCHANDISE
		end

		if DATALENGTH(ISNULL(@state_waste_code_2,'')) > 0
		begin
			insert dbo.MerchandiseWasteCode (merchandise_id, waste_code,
							added_by, date_added, modified_by, date_modified)
			values (@merchandise_id, @state_waste_code_2,
				@load_user, @load_date, @load_user, @load_date)
			if @@error <> 0
			begin
				rollback transaction
				select @msg_seq_no = @msg_seq_no + 1,
					@error_count = @error_count + 1
				insert dbo.MerchandiseLoadMsg
				values (@merchandise_load_id, @msg_seq_no, 'E',
					'Item # ' + @customer_item_number + ' could not insert ' + @state_waste_code_2 + ' into MerchandiseWasteCode.')
				goto NEXT_MERCHANDISE
			end
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
		@ORMD_ind = null,
		@hazardous_ind = null,
		@aerosol_ind = null,
		@flammable_ind = null,
		@product_category = null,
		@RCRA_waste_code_1 = null,
		@state_waste_code = null,
		@state_waste_code_2 = null,
		@special_handling = null

	fetch c_loop
	into @customer_item_number,
		@ndc_number,
		@merchandise_desc,
		@product_category,
		@RCRA_waste_code_1,
		@state_waste_code,
		@special_handling
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
    ON OBJECT::[dbo].[sp_merchandise_load_dea_rcra] TO [EQAI]
    AS [dbo];

