
CREATE PROCEDURE sp_workorder_import
	@workorder_import_id int
AS
/***************************************************************************************
 this procedure imports a spreadsheet into Workorder tables
 (WorkOrderHeader, WorkOrderDetail, WorkOrderManifest, WorkOrderDetailUnit,
  WorkOrderTransporter, WorkOrderAudit)

 loads to Plt_ai

 @workorder_import_option values:
			1 - create one workorder per generator
			2 - add detail lines to existing workorder_id
 
 12/16/2010 - rb created
 01/06/2011 - km added inserts into WorkOrderDetailUnit and WorkOrderTransporter
 01/07/2011 - rb modifed error handling for WorkOrderDetailUnit and WorkOrderTransporter
 10/27/2015 - rb rewrite for use by MSG
 03/24/2016 - rb allow optional start/end date, and pre-selected prices/price_sources
				 when multiples exist. Populate cost_source with user_id
 06/21/2016 - rb GEM:38065 populate Billing Project and Purchase Order from quote
 11/04/2016 - MM GEM 40189 - Set WorkOrderHeader.fixed_price_flag to 
				 WorkOrderQuoteHeader.fixed_price_flag or F on import
 11/17/2016 - MM GEM 40319 - Allow optional transporter_code, which is then inserted with 
				 each manifest in the WorkOrderTransporter table.  
				 Set WorkOrderDetail.container_count field if the approval that is being 
				 linked to the disposal line is set as bulk.
			     Corrected the setting of WorkOrderDetail.bill_rate when disposal lines 
			     for disposal not to USE facilities.
			     Corrected cost that is imported when importing disposal lines.
 01/17/2017 - MM GEM 41392 - Modified insert into WorkOrderHeader so that AX dimension 
                 fields are populated with empty strings, since nulls are not allowed.
 02/02/2017 - MM GEM 41718 - Modified inserts into WorkOrderDetailUnit by rounding extended_cost
				 and extended_price to 2 decimal places.	
			     
****************************************************************************************/

DECLARE	@customer_id int,
	@generator_id int,
	@quote_id int,
	@start_date datetime,
	@end_date datetime,
	@workorder_type_id int,
	@workorder_id int,
	@company_id int,
	@profit_ctr_id int,

	@sequence_id int,
	@resource_type char(1),

	@resource_class_code varchar(10),
	@profile_id int,
	@tsdf_approval_id int,
	@description varchar(100),
	@service_type varchar(20),
	@common_name varchar(80),
	@resource_cost money,
	@disposal_cost money,
	@units_tons money,
	@manifest varchar(15),
	@date_delivered datetime,
	@override_price money,
	@override_price_source varchar(15),
	
	@manifest_page_num int,
	@manifest_line_id char(1),
	@import_desc varchar(255),
	@result_idx int,
	@ipos int,
	@import_error int,

	@msg varchar(255),
	@import_user varchar(13),
	@import_date datetime,
	@count int,
	@workorder_status char(1),
	@submitted_flag char(1),
	@urgency_flag char(1),
	@manifest_line int,
	@manifest_flag char(1),
	@manifest_state char(2),
	@bill_unit_code varchar(4),
	@price_source varchar(15),
	@price money,
	@total_cost money,
	@total_price money,
	@row int,
	@fixed_price_flag char(1),
	@transporter_code varchar(15)

-- results table, to inform what happened
create table #results (
	result_seq_id int not null,
	result_msg varchar(255) not null)

set @import_error = 0

-- DEFAULTS
select @import_error = 0,
		@workorder_status = 'N',
		@submitted_flag = 'F',
		@urgency_flag = 'R',
		@manifest_flag = 'T',
		@manifest_state = '  ',
		@bill_unit_code = 'EACH',
		@import_user = SUSER_NAME(),
		@import_date = GETDATE(),
		@fixed_price_flag = 'F'

-- trim appended number off
select @ipos = charindex ('(',@import_user,1)
if @ipos > 1
	select @import_user = LEFT(@import_user,@ipos - 1)

-- query for key IDs
select @customer_id = wi.customer_id,
		@generator_id = wi.generator_id,
		@quote_id = wi.quote_id,
		@start_date = wi.start_date,
		@end_date = wi.end_date,
		@workorder_type_id = wi.workorder_type_id,
		@workorder_id = wi.workorder_id,
		@company_id = wi.company_id,
		@profit_ctr_id = wi.profit_ctr_id,
		@import_desc = wit.template_desc + ' - ' + convert(varchar(10),@workorder_import_id),
		@transporter_code = wi.transporter_code
from WorkOrderImport wi
join WorkOrderImportTemplate wit
	on wi.workorder_import_template_id = wit.workorder_import_template_id
where wi.workorder_import_id = @workorder_import_id

-- begin transaction
begin transaction

-- declare cursor loop
declare c_loop cursor forward_only read_only for
select isnull(ltrim(rtrim(resource_class_code)),''),
	isnull(profile_id,0),
	isnull(tsdf_approval_id,0),
	isnull(ltrim(rtrim(description)),''),
	isnull(ltrim(rtrim(service_type)),''),
	isnull(ltrim(rtrim(common_name)),''),
	isnull(resource_cost,0),
	isnull(disposal_cost,0),
	isnull(units_tons,0),
	isnull(ltrim(rtrim(manifest)),''),
	date_delivered,
	override_resource_price,
	override_resource_price_source
from WorkOrderImportDetail
where workorder_import_id = @workorder_import_id
order by sequence_id

open c_loop
fetch c_loop into
	@resource_class_code,
	@profile_id,
	@tsdf_approval_id,
	@description,
	@service_type,
	@common_name,
	@resource_cost,
	@disposal_cost,
	@units_tons,
	@manifest,
	@date_delivered,
	@override_price,
	@override_price_source

-- loop
while @@FETCH_STATUS = 0
begin
	set @row = isnull(@row,0) + 1

	-- determine resource_type
	if @resource_class_code <> '' and @profile_id < 1 and @tsdf_approval_id < 1
		set @resource_type = 'O'
	else if @resource_class_code = '' and (@profile_id > 0 or @tsdf_approval_id > 0)
		set @resource_type = 'D'
	
	if isnull(@resource_type,'') = ''
	begin
		set @import_error = 1
		set @msg = 'ERROR: Row #' + convert(varchar(10),@row) + ': Resource type could not be determined...Resource Class or Approval ID required'

		-- log error message
		set @result_idx = isnull(@result_idx,0) + 1
		insert #results values (@result_idx, @msg)
	end

	-- validate resource_class
	if @resource_type = 'O'
	begin
		if not exists (select 1 from ResourceClassHeader
						where resource_class_code = @resource_class_code
						and status = 'A')
		begin
			set @import_error = 1
			set @msg = 'ERROR: Row #' + convert(varchar(10),@row) + ' Resource class ''' + @resource_class_code + ''' is not valid'

			-- log error message
			set @result_idx = ISNULL(@result_idx,0) + 1
			insert #results values (@result_idx, @msg)
		end
		else
		begin
			if not exists (select 1 from ResourceClassDetail
							where company_id = @company_id
							and profit_ctr_id = @profit_ctr_id
							and resource_class_code = @resource_class_code
							and status = 'A')
			begin
				set @import_error = 1
				set @msg = 'ERROR: Row #' + convert(varchar(10),@row) + ' Resource class ''' + @resource_class_code + ''' is not valid for '
							+ right('0' + convert(varchar(2),@company_id),2) + '-' + right('0' + convert(varchar(2),@profit_ctr_id),2)

				-- log error message
				set @result_idx = ISNULL(@result_idx,0) + 1
				insert #results values (@result_idx, @msg)
			end
		end
	end

	-- validate approval id
	if @resource_type = 'D'
	begin
		if @profile_id > 0
		begin
			if not exists (select 1 from Profile
							where profile_id = @profile_id)
			begin
				set @import_error = 1
				set @msg = 'ERROR: Row #' + convert(varchar(10),@row) + ': Profile ID ''' + convert(varchar(10),@profile_id) + ''' is not valid'

				-- log error message
				select @result_idx = ISNULL(@result_idx,0) + 1
				insert #results values (@result_idx, @msg)
			end
			else
			begin
				if not exists (select 1 from ProfileQuoteApproval
								where profile_id = @profile_id
								and company_id = @company_id
								and profit_ctr_id = @profit_ctr_id)
				begin
					set @import_error = 1
					set @msg = 'ERROR: Row #' + convert(varchar(10),@row) + ': Profile ID ''' + convert(varchar(10),@profile_id) + ''' is not valid for '
							+ right('0' + convert(varchar(2),@company_id),2) + '-' + right('0' + convert(varchar(2),@profit_ctr_id),2)

				-- log error message
				select @result_idx = ISNULL(@result_idx,0) + 1
				insert #results values (@result_idx, @msg)
				end
			end
		end
		else
		begin
			if not exists (select 1 from TSDFApproval
							where tsdf_approval_id = @tsdf_approval_id)
			begin
				set @import_error = 1
				set @msg = 'ERROR: Row #' + convert(varchar(10),@row) + ': TSDF Approval ID ''' + convert(varchar(10),@tsdf_approval_id) + ''' is not valid'

				-- log error message
				select @result_idx = ISNULL(@result_idx,0) + 1
				insert #results values (@result_idx, @msg)
			end
			else
			begin
				if not exists (select 1 from TSDFApproval
								where tsdf_approval_id = @tsdf_approval_id
								and company_id = @company_id
								and profit_ctr_id = @profit_ctr_id)
				begin
					set @import_error = 1
					set @msg = 'ERROR: Row #' + convert(varchar(10),@row) + ': TSDF Approval ID ''' + convert(varchar(10),@tsdf_approval_id) + ''' is not valid for '
							+ right('0' + convert(varchar(2),@company_id),2) + '-' + right('0' + convert(varchar(2),@profit_ctr_id),2)

					-- log error message
					select @result_idx = ISNULL(@result_idx,0) + 1
					insert #results values (@result_idx, @msg)
				end
			end
		end
	end

	-- if no validation errors
	if @import_error = 0
	begin
		if @resource_type = 'D'
		begin
			select @sequence_id = max(sequence_id)
			from WorkOrderDetail
			where workorder_id = @workorder_id
			and company_id = @company_id
			and profit_ctr_id = @profit_ctr_id
			and resource_type = 'D'
			
			set @sequence_id = isnull(@sequence_id,0) + 1

			set @manifest_page_num = null
			set @manifest_line = null
			if @manifest <> ''
			begin
				select @manifest_line = max(manifest_line)
				from WorkOrderDetail
				where workorder_id = @workorder_id
				and company_id = @company_id
				and profit_ctr_id = @profit_ctr_id
				and manifest = @manifest

				set @manifest_line = isnull(@manifest_line,0) + 1
				set @manifest_page_num = case when (@manifest_line) between 1 and 4 then 1 else ((@manifest_line + 5) / 10) + 1 end
			end

			if @profile_id > 0
			begin
				insert WorkOrderDetail (workorder_id, company_id, profit_ctr_id, resource_type, sequence_id, 
										description, description_2, priced_flag, TSDF_code, TSDF_approval_code, manifest,
										manifest_page_num, manifest_line, profile_id, profile_company_id, profile_profit_ctr_id, bill_rate, 
										DOT_shipping_name, manifest_hand_instruct, manifest_waste_desc, management_code,
										reportable_quantity_flag, RQ_reason, hazmat, hazmat_class, subsidiary_haz_mat_class,
										UN_NA_flag, UN_NA_number, package_group, ERG_number, ERG_suffix,
										manifest_handling_code, manifest_dot_sp_number, billing_sequence_id,
										added_by, date_added, modified_by, date_modified)
				select @workorder_id, @company_id, @profit_ctr_id, @resource_type, @sequence_id,
						p.approval_desc, @service_type + ' - ' + @common_name, 1, t.tsdf_code, pqa.approval_code, nullif(@manifest,''),
						@manifest_page_num, @manifest_line, @profile_id, @company_id, @profit_ctr_id, -1,
						p.DOT_shipping_name, p.manifest_hand_instruct, isnull(p.manifest_waste_desc,p.approval_desc), tr.management_code,
						p.reportable_quantity_flag, p.RQ_reason, p.hazmat, p.hazmat_class, p.subsidiary_haz_mat_class,
						p.UN_NA_flag, p.UN_NA_number, p.package_group, p.ERG_number, p.ERG_suffix,
						p.manifest_handling_code, p.manifest_dot_sp_number, @sequence_id,
						@import_user, @import_date, @import_user, @import_date
				from ProfileQuoteApproval pqa
				join Profile p
					on pqa.profile_id = p.profile_id
				join TSDF t
					on t.eq_company = @company_id
					and t.eq_profit_ctr = @profit_ctr_id
					and isnull(t.tsdf_status,'') = 'A'
				join Treatment tr
					on pqa.treatment_id = tr.treatment_id
					and pqa.company_id = tr.company_id
					and pqa.profit_ctr_id = tr.profit_ctr_id
				where pqa.profile_id = @profile_id
				and pqa.company_id = @company_id
				and pqa.profit_ctr_id = @profit_ctr_id

				if @@error <> 0
				begin
					close c_loop
					deallocate c_loop
					set @msg = 'ERROR: Could not insert record into WorkOrderDetail'
					goto ON_ERROR
				end
			end
			else
			begin
				insert WorkOrderDetail (workorder_id, company_id, profit_ctr_id, resource_type, sequence_id, waste_stream,
										description, description_2, priced_flag, TSDF_code, TSDF_approval_code, manifest,
										manifest_page_num, manifest_line, tsdf_approval_id, bill_rate,
										DOT_shipping_name, manifest_hand_instruct, manifest_waste_desc, management_code,
										reportable_quantity_flag, RQ_reason, hazmat, hazmat_class, subsidiary_haz_mat_class,
										UN_NA_flag, UN_NA_number, package_group, ERG_number, ERG_suffix,
										manifest_handling_code, manifest_dot_sp_number, billing_sequence_id,
										added_by, date_added, modified_by, date_modified, container_count)
				select @workorder_id, @company_id, @profit_ctr_id, @resource_type, @sequence_id, ta.waste_stream,
						ta.waste_desc, @service_type + ' - ' + @common_name, 1, ta.tsdf_code, ta.tsdf_approval_code, nullif(@manifest,''),
						@manifest_page_num, @manifest_line, @tsdf_approval_id, tap.bill_rate,
						ta.DOT_shipping_name, ta.hand_instruct, ta.waste_desc, ta.management_code,
						ta.reportable_quantity_flag, ta.RQ_reason, ta.hazmat, ta.hazmat_class, ta.subsidiary_haz_mat_class,
						ta.UN_NA_flag, ta.UN_NA_number, ta.package_group, ta.ERG_number, ta.ERG_suffix,
						ta.manifest_handling_code, ta.manifest_dot_sp_number, @sequence_id,
						@import_user, @import_date, @import_user, @import_date, CASE ta.bulk_flag WHEN 'T' THEN 1 ELSE null END
				from TSDFApproval ta
				join TSDFApprovalPrice tap
				on tap.TSDF_approval_id = ta.TSDF_approval_id
				and tap.company_id = ta.company_id
				and tap.profit_ctr_id = ta.profit_ctr_id
				AND tap.record_type = 'D'
				AND tap.status = 'A'
				where ta.tsdf_approval_id = @tsdf_approval_id
				and ta.company_id = @company_id
				and ta.profit_ctr_id = @profit_ctr_id

				if @@error <> 0
				begin
					close c_loop
					deallocate c_loop
					set @msg = 'ERROR: Could not insert record into WorkOrderDetail'
					goto ON_ERROR
				end
			end

			--Insert a NONE waste code
			insert WorkOrderWasteCode (company_id, profit_ctr_id, workorder_id, workorder_sequence_id,
										waste_code_uid, waste_code, sequence_id, added_by, date_added)
			values (@company_id, @profit_ctr_id, @workorder_id, @sequence_id, 751, 'NONE', 1, @import_user, @import_date)

			if @@error <> 0
			begin
				close c_loop
				deallocate c_loop
				set @msg = 'ERROR: Could not insert record into WorkOrderWasteCode'
				goto ON_ERROR
			end

			--Potentially insert into units table
			if isnull(@units_tons,0) > 0
			begin
				if @profile_id > 0
					insert WorkOrderDetailUnit (workorder_id, company_id, profit_ctr_id, sequence_id, size, bill_unit_code, quantity,
												manifest_flag, billing_flag, priced_flag, 
												cost, extended_cost, price, extended_price,
												price_source, cost_source, added_by, date_added, modified_by, date_modified)
					select @workorder_id, @company_id, @profit_ctr_id, @sequence_id, 'TONS', 'TONS', @units_tons,
							'T', 'T', 0, 
							@disposal_cost, round(@disposal_cost * @units_tons, 2), pqd.price, round(@units_tons * pqd.price, 2),
							case when isnull(pqd.price,0) > 0 then wd.tsdf_approval_code else null end, @import_user, @import_user, @import_date, @import_user, @import_date
					from WorkOrderDetail wd
					join ProfileQuoteDetail pqd
						on wd.profile_id = pqd.profile_id
						and wd.profile_company_id = pqd.company_id
						and wd.profile_profit_ctr_id = pqd.profit_ctr_id
						and pqd. bill_unit_code = 'TONS'
						and pqd.status = 'A'
					where wd.workorder_id = @workorder_id
					and wd.company_id = @company_id
					and wd.profit_ctr_id = @profit_ctr_id
					and wd.sequence_id = @sequence_id
				else
					insert WorkOrderDetailUnit (workorder_id, company_id, profit_ctr_id, sequence_id, size, bill_unit_code, quantity,
												manifest_flag, billing_flag, priced_flag, 
												cost, extended_cost, price, extended_price,
												price_source, cost_source, added_by, date_added, modified_by, date_modified)
					select @workorder_id, @company_id, @profit_ctr_id, @sequence_id, 'TONS', 'TONS', @units_tons,
							'T', 'T', 0, 
							@disposal_cost, round(@disposal_cost * @units_tons, 2), tad.price, round(@units_tons * tad.price, 2),
							case when isnull(tad.price,0) > 0 then 'TDA - ' + convert(varchar(10),tad.tsdf_approval_id) else null end,
							@import_user, @import_user, @import_date, @import_user, @import_date
					from WorkOrderDetail wd
					join TSDFApprovalPrice tad
						on wd.tsdf_approval_id = tad.tsdf_approval_id
						and tad. bill_unit_code = 'TONS'
						and tad.status = 'A'
					where wd.workorder_id = @workorder_id
					and wd.company_id = @company_id
					and wd.profit_ctr_id = @profit_ctr_id
					and wd.sequence_id = @sequence_id

				if @@error <> 0
				begin
					close c_loop
					deallocate c_loop
					set @msg = 'ERROR: Could not insert record into WorkOrderDetailUnit for TONS'
					goto ON_ERROR
				end

				--print_on_invoice_flag
				update WorkOrderDetail
				set print_on_invoice_flag = case when isnull(wdu.extended_price,0) > 0 then 'T' else 'F' end
				from WorkOrderDetail wd
				join WorkOrderDetailUnit wdu
					on wdu.workorder_id = wd.workorder_id
					and wdu.company_id = wd.company_id
					and wdu.profit_ctr_id = wd.profit_ctr_id
					and wdu.sequence_id = wd.sequence_id
					and wdu.bill_unit_code = 'TONS'
				where wd.workorder_id = @workorder_id
				and wd.company_id = @company_id
				and wd.profit_ctr_id = @profit_ctr_id
				and wd.sequence_id = @sequence_id

				if @@error <> 0
				begin
					close c_loop
					deallocate c_loop
					set @msg = 'ERROR: Could not update print_on_invoice_flag for WorkOrderDetail TONS amount'
					goto ON_ERROR
				end
			end
		end
		else if @resource_type = 'O'
		begin
			select @sequence_id = max(sequence_id)
			from WorkOrderDetail
			where workorder_id = @workorder_id
			and company_id = @company_id
			and profit_ctr_id = @profit_ctr_id
			and resource_type = 'O'
			
			set @sequence_id = isnull(@sequence_id,0) + 1

			set @price = 0
			set @price_source = null

			-- override_price is set if there were multiple prices available...user pre-selected one
			if @override_price is not null

				select @price = @override_price,
						@price_source = @override_price_source

			else if isnull(@quote_id,0) > 0 and
				exists (select 1
						from WorkOrderQuoteHeader wqh
						join WorkOrderQuoteDetail wqd
							on wqh.quote_id = wqd.quote_id
							and wqd.company_id = @company_id
							and wqd.profit_ctr_id = @profit_ctr_id
							and wqd.resource_item_code = @resource_class_code
						where wqh.quote_id = @quote_id
						and wqh.curr_status_code = 'A'
						and wqh.quote_type in ('C','P')
						)
				select @price = isnull(wqd.price,0),
						@price_source = case when isnull(wqd.price,0) > 0 then wqh.project_code else null end
				from WorkOrderQuoteHeader wqh
				join WorkOrderQuoteDetail wqd
					on wqd.quote_id = wqh.quote_id
					and wqd.company_id = @company_id
					and wqd.profit_ctr_id = @profit_ctr_id
					and wqd.bill_unit_code = @bill_unit_code
					and wqd.resource_type = @resource_type
					and wqd.resource_item_code = @resource_class_code
				where wqh.quote_id = @quote_id
				and wqh.curr_status_code = 'A'
				and wqh.quote_type in ('C','P')

			else if exists (select 1
						from WorkOrderQuoteHeader wqh
						join WorkOrderQuoteDetail wqd
							on wqh.quote_id = wqd.quote_id
							and wqd.company_id = @company_id
							and wqd.profit_ctr_id = @profit_ctr_id
							and wqd.resource_item_code = @resource_class_code
						where wqh.customer_id = @customer_id
						and wqh.curr_status_code = 'A'
						and wqh.quote_type = 'C'
						)
				select @price = isnull(wqd.price,0),
						@price_source = case when isnull(wqd.price,0) > 0 then 'Cust Rate' else null end
				from WorkOrderQuoteHeader wqh
				join WorkOrderQuoteDetail wqd
					on wqh.quote_id = wqd.quote_id
					and wqd.company_id = @company_id
					and wqd.profit_ctr_id = @profit_ctr_id
					and wqd.resource_item_code = @resource_class_code
				where wqh.customer_id = @customer_id
				and wqh.curr_status_code = 'A'
				and wqh.quote_type = 'C'

			else
				select @price = isnull(price,0),
						@price_source = case when isnull(price,0) > 0 then 'Cust Rate' else null end
				from WorkOrderQuoteDetail
				where quote_id = 1
				and company_id = @company_id
				and profit_ctr_id = @profit_ctr_id
				and bill_unit_code = @bill_unit_code
				and resource_type = @resource_type
				and resource_item_code = @resource_class_code

			insert WorkOrderDetail (workorder_id, company_id, profit_ctr_id, resource_type, sequence_id, resource_class_code,
									quantity, quantity_used, cost, price, extended_cost, extended_price, description, description_2, bill_rate,
									price_source, cost_class, priced_flag, bill_unit_code, billing_sequence_id, print_on_invoice_flag,
									added_by, date_added, modified_by, date_modified)
			select @workorder_id, @company_id, @profit_ctr_id, @resource_type, @sequence_id, @resource_class_code,
					1, 1, @resource_cost, @price, @resource_cost, @price, @description, @service_type + ' - ' + @common_name, case when @price > 0 then 1 else 0 end,
					@price_source, @import_user, 1, rcd.bill_unit_code, @sequence_id, case when isnull(@price,0) > 0 then 'T' else 'F' end,
					@import_user, @import_date, @import_user, @import_date
			from ResourceClassDetail rcd
			where rcd.company_id = @company_id
			and rcd.profit_ctr_id = @profit_ctr_id
			and rcd.resource_class_code = @resource_class_code
			and rcd.status = 'A'
			and rcd.bill_unit_code = @bill_unit_code
			
			if @@error <> 0
			begin
				close c_loop
				deallocate c_loop
				set @msg = 'ERROR: Could not insert record into WorkOrderDetail'
				goto ON_ERROR
			end
		end
		
		-- insert WorkOrderManifest if necessary
		if @resource_type = 'D' and @manifest <> '' and
			not exists (select 1 from WorkorderManifest
						where workorder_ID = @workorder_id
						and company_id = @company_id
						and profit_ctr_ID = @profit_ctr_id
						and manifest = @manifest)
		begin
			insert WorkOrderManifest (workorder_ID, company_id, profit_ctr_ID, manifest, manifest_flag, EQ_flag,
										manifest_state, date_delivered, date_added, modified_by, date_modified)
			values (@workorder_id, @company_id, @profit_ctr_id, @manifest, @manifest_flag, case when @profile_id > 0 then 'T' else 'F' end,
					@manifest_state, @date_delivered, @import_date, @import_user, @import_date)

			if @@error <> 0
			begin
				close c_loop
				deallocate c_loop
				set @msg = 'ERROR: Could not insert record into WorkOrderManifest'
				goto ON_ERROR
			end
		end
	end
	
    -- If @transporter_code is populated, insert into WorkOrderTransporter
    if @transporter_code is not null and @manifest <> '' and @resource_type = 'D' and
		not exists (select 1 from WorkOrderTransporter
		            where workorder_id = @workorder_id
                    and company_id = @company_id
					and profit_ctr_ID = @profit_ctr_id
					and manifest = @manifest)    
	begin
		insert WorkOrderTransporter (company_id, profit_ctr_ID, workorder_ID, manifest, transporter_sequence_id, transporter_code,
									 transporter_sign_date, added_by, date_added, modified_by, date_modified)
		values (@company_id, @profit_ctr_id, @workorder_id, @manifest, 1, @transporter_code, @date_delivered,
				@import_user, @import_date, @import_user, @import_date)

		if @@error <> 0
		begin
			close c_loop
			deallocate c_loop
			set @msg = 'ERROR: Could not insert record into WorkOrderTransporter'
			goto ON_ERROR
		end
    end

	-- fetch next record
	fetch c_loop into
		@resource_class_code,
		@profile_id,
		@tsdf_approval_id,
		@description,
		@service_type,
		@common_name,
		@resource_cost,
		@disposal_cost,
		@units_tons,
		@manifest,
		@date_delivered,
		@override_price,
		@override_price_source
end

close c_loop
deallocate c_loop

-- insert WorkOrderHeader if necessary
if @import_error = 0 and
	not exists (select 1 from WorkOrderHeader
				where workorder_id = @workorder_id
				and company_id = @company_id
				and profit_ctr_id = @profit_ctr_id)
begin
	select @total_cost = sum(isnull(extended_cost,0))
	from WorkOrderDetail
	where workorder_id = @workorder_id
	and company_id = @company_id
	and profit_ctr_id = @profit_ctr_id
	and isnull(bill_rate,0) >= 0

	select @total_price = sum(isnull(extended_price,0))
	from WorkOrderDetail
	where workorder_id = @workorder_id
	and company_id = @company_id
	and profit_ctr_id = @profit_ctr_id
	and isnull(bill_rate,0) > 0

	if isnull(@quote_id,0) > 0
		insert WorkOrderHeader (workorder_ID, company_id, profit_ctr_ID, revision, workorder_status, quote_id, billing_project_id, purchase_order,
								workorder_type_id, submitted_flag, customer_ID, generator_id, description,
								urgency_flag, project_code, project_name, project_location, total_cost, total_price, priced_flag,
								start_date, end_date, created_by, date_added, modified_by, date_modified, fixed_price_flag,
								AX_Dimension_5_Part_1, AX_Dimension_5_Part_2)
		select	@workorder_id, @company_id, @profit_ctr_id, 0, @workorder_status, @quote_id, billing_project_id, purchase_order,
				@workorder_type_id, @submitted_flag, @customer_id, @generator_id, @import_desc,
				@urgency_flag, project_code, project_name, project_location, @total_cost, @total_price, 1,
				@start_date, @end_date, @import_user, @import_date, @import_user, @import_date, ISNULL(fixed_price_flag, 'F'),
				'',''
		from WorkOrderQuoteHeader
		where quote_id = @quote_id
		and curr_status_code = 'A'
	else
		insert WorkOrderHeader (workorder_ID, company_id, profit_ctr_ID, revision, workorder_status,
								workorder_type_id, submitted_flag, customer_ID, generator_id, description,
								urgency_flag, total_cost, total_price, priced_flag, start_date, end_date,
								created_by, date_added, modified_by, date_modified, fixed_price_flag,
								AX_Dimension_5_Part_1, AX_Dimension_5_Part_2)
		values (@workorder_id, @company_id, @profit_ctr_id, 0, @workorder_status,
				@workorder_type_id, @submitted_flag, @customer_id, @generator_id, @import_desc,
				@urgency_flag, @total_cost, @total_price, 1, @start_date, @end_date,
				@import_user, @import_date, @import_user, @import_date, @fixed_price_flag,
				'','')
	
	if @@error <> 0
	begin
		set @msg = 'ERROR: Could not insert record into WorkOrderHeader'
		goto ON_ERROR
	end

	insert WorkOrderStop (workorder_id, company_id, profit_ctr_id, stop_sequence_id, est_time_amt, est_time_unit, waste_flag, decline_id,
							added_by, date_added, modified_by, date_modified)
	values (@workorder_id, @company_id, @profit_ctr_id, 1, 1, 'D', 'T', 1, @import_user, @import_date, @import_user, @import_date)

	if @@error <> 0
	begin
		set @msg = 'ERROR: Could not insert record into WorkOrderStop'
		goto ON_ERROR
	end

	insert WorkOrderAudit (company_id, profit_ctr_id, workorder_id, resource_type,
							sequence_id, table_name, column_name, before_value, after_value,
							audit_reference, modified_by, date_modified)
	values (@company_id, @profit_ctr_id, @workorder_id, '', 0, 'WorkOrderHeader',
			'All', '(no record)', '(new record added)', null, @import_user, @import_date)
				
	if @@error <> 0
	begin
		set @msg = 'ERROR: Could not insert record into WorkOrderAudit for WorkOrderHeader'
		goto ON_ERROR
	end

	set @msg = 'Workorder ' + right('0' + convert(varchar(2),@company_id),2) + '-' + right('0' + convert(varchar(2),@profit_ctr_id),2)
				+ '-' + convert(varchar(10),@workorder_id) + ' successfully imported.'
	select @result_idx = ISNULL(@result_idx,0) + 1
	insert #results values (@result_idx, @msg)
end

if @import_error = 0
begin
	insert WorkOrderAudit (company_id, profit_ctr_id, workorder_id, resource_type,
							sequence_id, table_name, column_name, before_value, after_value,
							audit_reference, modified_by, date_modified)
	select @company_id, @profit_ctr_id, @workorder_id, resource_type, sequence_id, 'WorkOrderDetail',
			'All', '(no record)', convert(varchar(10),sequence_id) + '. ' + case resource_type when 'D' then tsdf_approval_code else resource_class_code end, null, @import_user, @import_date
	from WorkOrderDetail
	where workorder_id = @workorder_id
	and company_id = @company_id
	and profit_ctr_id = @profit_ctr_id
	order by resource_type, sequence_id

	if @@error <> 0
	begin
		set @msg = 'ERROR: Could not insert record into WorkOrderAudit for WorkOrderDetail'
		goto ON_ERROR
	end

	if exists (select 1 from WorkOrderDetail
				where workorder_id = @workorder_id and company_id = @company_id and profit_ctr_id = @profit_ctr_id and resource_type = 'D')
	begin
		select @result_idx = ISNULL(@result_idx,0) + 1
		insert #results values (@result_idx, '')
		insert #results values (@result_idx, 'Disposal records imported:')

		select @result_idx = ISNULL(@result_idx,0) + 1
		insert #results
		select @result_idx, '   ' + convert(varchar(3),sequence_id) + '. ' + tsdf_approval_code
		from WorkOrderDetail
		where workorder_id = @workorder_id and company_id = @company_id and profit_ctr_id = @profit_ctr_id and resource_type = 'D'
		order by sequence_id
	end

	if exists (select 1 from WorkOrderDetail
				where workorder_id = @workorder_id and company_id = @company_id and profit_ctr_id = @profit_ctr_id and resource_type = 'O')
	begin
		select @result_idx = ISNULL(@result_idx,0) + 1
		insert #results values (@result_idx, '')
		insert #results values (@result_idx, 'Other records imported:')

		select @result_idx = ISNULL(@result_idx,0) + 1
		insert #results
		select @result_idx, '   ' + convert(varchar(3),sequence_id) + '. ' + resource_class_code
		from WorkOrderDetail
		where workorder_id = @workorder_id and company_id = @company_id and profit_ctr_id = @profit_ctr_id and resource_type = 'O'
		order by sequence_id
	end
end

-----------
ON_SUCCESS:
-----------
commit transaction

select result_msg
from #results
order by result_seq_id

drop table #results
return 0

---------
ON_ERROR:
---------
rollback transaction
select @msg as result_msg
return 0

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_workorder_import] TO PUBLIC
    AS [dbo];


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_workorder_import] TO [EQAI]
    AS [dbo];

