
create procedure dbo.sp_merchandise_load_xls
	@merchandise_load_id int
as
/***************************************************************************************
 this procedure translates loaded Excel spreadshets into Merchandise-related table entries

 loads to Plt_ai
 
 11/20/2008 - rb created
 05/28/2009 - rb remove insistence that customer code and upc code is unique...but ignore
                 adding new records that have both that are the same
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
	@RCRA_waste_code_2 varchar(255),
	@RCRA_waste_code_3 varchar(255),
	@state_waste_code varchar(255),
	@UHC_1 varchar(255),
	@UHC_2 varchar(255),
	@UHC_3 varchar(255),
	@special_handling varchar(255),
	@const_id int,

	@load_user varchar(30),
	@load_date datetime,
	@merchandise_id int,
	@merchandise_type_id int,
	@merchandise_status char(1),

	@category_id int,
	@scan_type_msds_id int,

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

select @scan_type_msds_id = type_id
from Plt_image.dbo.ScanDocumentType
where scan_type = 'merchandise'
and document_type = 'MSDS'

select @merchandise_type_id = merchandise_type_id
from dbo.MerchandiseType
where merchandise_type_desc = 'Merchandise'


declare c_loop cursor for
select ltrim(rtrim(customer_unique_item_number)),
	ltrim(rtrim(consumer_pack_upc)),
	ltrim(rtrim(ndc_number)),
	ltrim(rtrim(merchandise_desc)),
	ltrim(rtrim(ORMD_ind)),
	ltrim(rtrim(hazardous_ind)),
	ltrim(rtrim(aerosol_ind)),
	ltrim(rtrim(flammable_ind)),
	ltrim(rtrim(product_category)),
	ltrim(rtrim(RCRA_waste_code_1)),
	ltrim(rtrim(RCRA_waste_code_2)),
	ltrim(rtrim(RCRA_waste_code_3)),
	ltrim(rtrim(state_waste_code)),
	ltrim(rtrim(UHC_1)),
	ltrim(rtrim(UHC_2)),
	ltrim(rtrim(UHC_3)),
	ltrim(rtrim(special_handling))
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
	@ORMD_ind,
	@hazardous_ind,
	@aerosol_ind,
	@flammable_ind,
	@product_category,
	@RCRA_waste_code_1,
	@RCRA_waste_code_2,
	@RCRA_waste_code_3,
	@state_waste_code,
	@UHC_1,
	@UHC_2,
	@UHC_3,
	@special_handling

while @@FETCH_STATUS = 0
begin
	/*** 05/28/2009 - rb - allow duplicates, just not combination of the two
	-- check if UPC code exists...skip if it does
	if datalength(isnull(ltrim(@consumer_pack_upc),'')) > 0
	begin
		if exists (select 1 from dbo.MerchandiseCode
			where code_type = 'U'
			and merchandise_code = @consumer_pack_upc)
		begin
			select @msg_seq_no = @msg_seq_no + 1,
				@warning_count = @warning_count + 1
			insert dbo.MerchandiseLoadMsg
			values (@merchandise_load_id, @msg_seq_no, 'W',
				'Item # ' + @customer_item_number + ' UPC code ' + @consumer_pack_upc + ' already exists in MerchandiseCode: not loaded into database.')
			goto NEXT_MERCHANDISE
		end
	end
	else
	begin
		select @msg_seq_no = @msg_seq_no + 1,
			@warning_count = @warning_count + 1
		insert dbo.MerchandiseLoadMsg
		values (@merchandise_load_id, @msg_seq_no, 'W',
			'Item with empty UPC code added to database.')
	end

	-- check if Customer Code exists...skip if it does
	if datalength(isnull(ltrim(@customer_item_number),'')) > 0
	begin
		if exists (select 1 from dbo.MerchandiseCode
			where code_type = 'C'
			and merchandise_code = @customer_item_number
			and customer_id = @customer_id)
		begin
			select @msg_seq_no = @msg_seq_no + 1,
				@warning_count = @warning_count + 1
			insert dbo.MerchandiseLoadMsg
			values (@merchandise_load_id, @msg_seq_no, 'W',
				'Item # ' + @customer_item_number + ' already exists in MerchandiseCode for customer ' + convert(varchar(10),@customer_id) + ': not loaded into database.')
			goto NEXT_MERCHANDISE
		end
	end
	else
	begin
		select @msg_seq_no = @msg_seq_no + 1,
			@warning_count = @warning_count + 1
		insert dbo.MerchandiseLoadMsg
		values (@merchandise_load_id, @msg_seq_no, 'W',
			'Item with empty Customer code added to database.')
	end
	***/
	if datalength(isnull(@consumer_pack_upc,'')) > 0 and
	   datalength(isnull(@customer_item_number,'')) > 0
	begin
		if exists (select 1
			from MerchandiseCode mc, MerchandiseCode mu
			where mc.code_type = 'C'
			and mc.merchandise_code = @customer_item_number
			and mc.customer_id = @customer_id
			and mc.merchandise_id = mu.merchandise_id
			and mu.code_type = 'U'
			and mu.merchandise_code = @consumer_pack_upc)
		begin
			select @msg_seq_no = @msg_seq_no + 1,
				@warning_count = @warning_count + 1
			begin transaction
			insert dbo.MerchandiseLoadMsg
			values (@merchandise_load_id, @msg_seq_no, 'W',
				'Item # ' + @customer_item_number + ' UPC code ' + @consumer_pack_upc + ' already exists: not loaded into database.')
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
		select @category_id = mc.category_id
		from dbo.MerchandiseLoadCategoryMap mlcp, dbo.MerchandiseCategory mc
		where mlcp.spreadsheet_description = @product_category
		and mlcp.load_description = mc.category_desc

	-- Merchandise Status
	-- if Product Category and Disposition specified, status is Approved
		-- currently, not a way to determine disposition

	-- else, if Product Category specified, status is Needs Review
	if (@category_id is not null)
		select @merchandise_status = 'R'

	-- else, status is 'New'
	else
		select @merchandise_status = 'N'


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

	-- 05/28/2009 RB - codes were included, only hardcode to U  if not set
	-- 12/02/2008 RB - THESE INDICATORS HAVE NOT BEEN VALIDATED, HARDCODE TO 'U'
	if datalength(isnull(@hazardous_ind,'')) < 1
		select @hazardous_ind = 'U'
	if datalength(isnull(@flammable_ind,'')) < 1
		select @flammable_ind = 'U'
	if datalength(isnull(@aerosol_ind,'')) < 1
		select @aerosol_ind = 'U'

	begin transaction

	-- insert Merchandise
	insert dbo.Merchandise (merchandise_id, merchandise_desc, merchandise_status, merchandise_type_id,
				odor_ind, ORMD_ind, RCRA_haz_flag, RCRA_flammable_ind, aerosol_ind,
				special_handling, flash_pt, ph_range, entry_route, acute_exposure_eye,
				acute_exposure_skin, acute_exposure_inhalation, acute_exposure_ingestion,
				water_soluble, stability, incompatibility_flag, hazardous_polymerization,
				hazmat_flag, rq_flag, pharmaceutical_flag,
				added_by, date_added, modified_by, date_modified)
	values (@merchandise_id, @merchandise_desc, @merchandise_status, @merchandise_type_id, 'F',
		case @ORMD_ind when 'Y' then 'T' else 'F' end, @hazardous_ind, @flammable_ind, @aerosol_ind,
		@special_handling, 'N/A', 'N/A', 'N/A', 'F', 'F', 'F', 'F',
		'N', 'F', 'F', 'F', 'F', 'F', 'F',
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

	-- insert MerchandiseCategory
	if datalength(isnull(@product_category,'')) > 0
	begin
		-- @category_id was selected at top of loop to determine merchandise_status
		if @category_id is null
		begin
			select @msg_seq_no = @msg_seq_no + 1,
				@warning_count = @warning_count + 1
			insert dbo.MerchandiseLoadMsg
			values (@merchandise_load_id, @msg_seq_no, 'W',
				'Category ' + @product_category + ' for item # ' + @customer_item_number + ' could not be found in MerchandiseLoad_category.')
		end
		else
		begin
			insert dbo.MerchandiseCategoryXMerchandise (merchandise_id, category_id,
						added_by, date_added, modified_by, date_modified)
			values (@merchandise_id, @category_id, @load_user, @load_date, @load_user, @load_date)

			if @@error <> 0
			begin
				rollback transaction
				select @msg_seq_no = @msg_seq_no + 1,
					@error_count = @error_count + 1
				insert dbo.MerchandiseLoadMsg
					values (@merchandise_load_id, @msg_seq_no, 'E',
						'Category ' + @product_category + ' for item # ' + @customer_item_number + ' could not be inserted into MerchandiseCategory.')
				goto NEXT_MERCHANDISE
			end
		end
	end

	-- insert MerchandiseCode
	-- UPC
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
	if datalength(isnull(@RCRA_waste_code_2,'')) > 0
	begin
		insert dbo.MerchandiseWasteCode (merchandise_id, waste_code,
						added_by, date_added, modified_by, date_modified)
		values (@merchandise_id, @RCRA_waste_code_2,
			@load_user, @load_date, @load_user, @load_date)
		if @@error <> 0
		begin
			rollback transaction
			select @msg_seq_no = @msg_seq_no + 1,
				@error_count = @error_count + 1
			insert dbo.MerchandiseLoadMsg
			values (@merchandise_load_id, @msg_seq_no, 'E',
				'Item # ' + @customer_item_number + ' could not insert ' + @RCRA_waste_code_2 + ' into MerchandiseWasteCode.')
			goto NEXT_MERCHANDISE
		end
	end
	if datalength(isnull(@RCRA_waste_code_3,'')) > 0
	begin
		insert dbo.MerchandiseWasteCode (merchandise_id, waste_code,
						added_by, date_added, modified_by, date_modified)
		values (@merchandise_id, @RCRA_waste_code_3,
			@load_user, @load_date, @load_user, @load_date)
		if @@error <> 0
		begin
			rollback transaction
			select @msg_seq_no = @msg_seq_no + 1,
				@error_count = @error_count + 1
			insert dbo.MerchandiseLoadMsg
			values (@merchandise_load_id, @msg_seq_no, 'E',
				'Item # ' + @customer_item_number + ' could not insert ' + @RCRA_waste_code_3 + ' into MerchandiseWasteCode.')
			goto NEXT_MERCHANDISE
		end
	end
	if datalength(isnull(@state_waste_code,'')) > 0
	begin
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
	end

	-- insert MerchandiseConstituent
	if datalength(isnull(@UHC_1,'')) > 0
	begin
		select @const_id = null
		select @const_id = const_id
		from dbo.Constituents
		where const_desc = @UHC_1

		if @const_id is null
		begin
			select @msg_seq_no = @msg_seq_no + 1,
				@warning_count = @warning_count + 1
			insert dbo.MerchandiseLoadMsg
			values (@merchandise_load_id, @msg_seq_no, 'W',
				'Constituent ' + @UHC_1 + ' for item # ' + @customer_item_number + ' could not be found in Constituents.')
		end
		else
		begin
			insert dbo.MerchandiseConstituent (merchandise_id, const_id,
							added_by, date_added, modified_by, date_modified)
			values (@merchandise_id, @const_id,
				@load_user, @load_date, @load_user, @load_date)
			if @@error <> 0
			begin
				rollback transaction
				select @msg_seq_no = @msg_seq_no + 1,
					@error_count = @error_count + 1
				insert dbo.MerchandiseLoadMsg
				values (@merchandise_load_id, @msg_seq_no, 'E',
					'Item # ' + @customer_item_number + ' could not insert ' + @UHC_1 + ' into MerchandiseConstituent.')
				goto NEXT_MERCHANDISE
			end
		end
	end
	if datalength(isnull(@UHC_2,'')) > 0
	begin
		select @const_id = null
		select @const_id = const_id
		from dbo.Constituents
		where const_desc = @UHC_2

		if @const_id is null
		begin
			select @msg_seq_no = @msg_seq_no + 1,
				@warning_count = @warning_count + 1
			insert dbo.MerchandiseLoadMsg
			values (@merchandise_load_id, @msg_seq_no, 'W',
				'Constituent ' + @UHC_2 + ' for item # ' + @customer_item_number + ' could not be found in Constituents.')
		end
		else
		begin
			insert dbo.MerchandiseConstituent (merchandise_id, const_id,
							added_by, date_added, modified_by, date_modified)
			values (@merchandise_id, @const_id,
				@load_user, @load_date, @load_user, @load_date)
			if @@error <> 0
			begin
				rollback transaction
				select @msg_seq_no = @msg_seq_no + 1,
					@error_count = @error_count + 1
				insert dbo.MerchandiseLoadMsg
				values (@merchandise_load_id, @msg_seq_no, 'E',
					'Item # ' + @customer_item_number + ' could not insert ' + @UHC_2 + ' into MerchandiseConstituent.')
				goto NEXT_MERCHANDISE
			end
		end
	end
	if datalength(isnull(@UHC_3,'')) > 0
	begin
		select @const_id = null
		select @const_id = const_id
		from dbo.Constituents
		where const_desc = @UHC_3

		if @const_id is null
		begin
			select @msg_seq_no = @msg_seq_no + 1,
				@warning_count = @warning_count + 1
			insert dbo.MerchandiseLoadMsg
			values (@merchandise_load_id, @msg_seq_no, 'W',
				'Constituent ' + @UHC_3 + ' for item # ' + @customer_item_number + ' could not be found in Constituents.')
		end
		else
		begin
			insert dbo.MerchandiseConstituent (merchandise_id, const_id,
							added_by, date_added, modified_by, date_modified)
			values (@merchandise_id, @const_id,
				@load_user, @load_date, @load_user, @load_date)
			if @@error <> 0
			begin
				rollback transaction
				select @msg_seq_no = @msg_seq_no + 1,
					@error_count = @error_count + 1
				insert dbo.MerchandiseLoadMsg
				values (@merchandise_load_id, @msg_seq_no, 'E',
					'Item # ' + @customer_item_number + ' could not insert ' + @UHC_3 + ' into MerchandiseConstituent.')
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
		@RCRA_waste_code_2 = null,
		@RCRA_waste_code_3 = null,
		@state_waste_code = null,
		@UHC_1 = null,
		@UHC_2 = null,
		@UHC_3 = null,
		@special_handling = null

	fetch c_loop
	into @customer_item_number,
		@consumer_pack_upc,
		@ndc_number,
		@merchandise_desc,
		@ORMD_ind,
		@hazardous_ind,
		@aerosol_ind,
		@flammable_ind,
		@product_category,
		@RCRA_waste_code_1,
		@RCRA_waste_code_2,
		@RCRA_waste_code_3,
		@state_waste_code,
		@UHC_1,
		@UHC_2,
		@UHC_3,
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
    ON OBJECT::[dbo].[sp_merchandise_load_xls] TO [EQAI]
    AS [dbo];

