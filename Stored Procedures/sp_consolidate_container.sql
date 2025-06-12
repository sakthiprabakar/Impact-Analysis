
create procedure sp_consolidate_container
	@base_container	varchar(20),
	@base_sequence_id int,
	@container varchar(20),
	@container_sequence_id int,
	@consolidate_percent int,
	@consolidate_waste_codes varchar(4096),
	@remove_waste_codes varchar(4096),
	@consolidate_constituents varchar(4096),
	@remove_constituents varchar(4096),
	@user_id varchar(10),
	@modified_from varchar(10),
	@process_treatment_id int = null,
	@process_location varchar(15) = null,
	@process_tracking_num varchar(15) = null,
	@process_cycle int = null,
	@disposal_date datetime = null,
	@debug int = 0
as
/***************************************************************************************
Loads to:		Plt_XX_AI

04/16/2014 RB	Created - Single code base to Consolidate and Process containers, shared by EQAI and EQBP
05/27/2014 RB	Bug with process...when finalizing, transform blank arguments for WasteCode and Constituent to (ALL)
05/27/2014 RB	Added @disposal_date argument...this was originall written to use getdate()
06/19/2014 SM	Moved to PLT_AI
****************************************************************************************/

declare @initial_tran_count int,
		@sql varchar(max),
		@msg varchar(4096),
		@err int,
		@rc int,
		@pos int,
		@pos2 int,
		@base_company_id int,
		@base_profit_ctr_id int,
		@base_type char(1),
		@base_receipt_id int,
		@base_line_id int,
		@base_container_id int,
		@base_status char(1),
		@base_size varchar(15),
		@base_description varchar(30),
		@location_type char(1),
		@container_percent int,
		@base_tracking_num varchar(15),
		@container_company_id int,
		@container_profit_ctr_id int,
		@container_type char(1),
		@container_receipt_id int,
		@container_line_id int,
		@container_container_id int,
		@new_container_sequence_id int,
		@is_referencing_receipt_records int,
		@waste_flag char(1),
		@const_flag char(1),
		@waste_code_uid int,
		@const_id int,
		@container_id int,
		@w_validation_ok int,
		@c_validation_ok int,
		@msg_temp varchar(255),
		@audit_dt datetime

set nocount on

-- validate arguments
if substring(@base_container,1,2) = 'P-'
begin
	set @base_type = 'P'
	set @base_company_id = convert(int, substring(@base_container, 3, 2))
	set @base_profit_ctr_id = convert(int, substring(@base_container, 5, 2))
	set @base_sequence_id = isnull(@base_sequence_id,1)
	set @location_type = 'P'
end

else if substring(@base_container,1,3) = 'DL-' 
begin
	set @base_type = 'S'
	set @base_company_id = convert(int, substring(@base_container, 4, 2))
	set @base_profit_ctr_id = convert(int, substring(@base_container, 6, 2))
	set @base_receipt_id = 0
	set @base_line_id = convert(int, substring(@base_container, 9, 6))
	set @base_container_id = @base_line_id
	
	set @base_tracking_num = @base_container
	set @location_type = 'C'
end

else
begin
	set @base_type = 'R'
	set @base_company_id = convert(int, substring(@base_container, 1, 2))
	set @base_profit_ctr_id = convert(int, substring(@base_container, 3, 2))

	set @pos = charindex('-', @base_container, 6)
	if @pos < 1 return -1

	set @base_receipt_id = convert(int, substring(@base_container, 6, @pos - 6))
	
	set @pos2 = charindex('-', @base_container, @pos + 1)
	if @pos2 < 1 return -1

	set @base_line_id = convert(int, substring(@base_container, @pos + 1, @pos2 - @pos - 1))
	set @base_container_id = convert(int, substring(@base_container, @pos2 + 1, 3))

	set @base_tracking_num = convert(varchar(10),@base_receipt_id) + '-' + convert(varchar(10),@base_line_id)
	set @location_type = 'C'
end

if @debug = 1 print '@base_type=' + isnull(@base_type,'null')
if @debug = 1 print '@base_company_id=' + isnull(convert(varchar(10),@base_company_id),'null')
if @debug = 1 print '@base_profit_ctr_id=' + isnull(convert(varchar(10),@base_profit_ctr_id),'null')
if @debug = 1 print '@base_receipt_id=' + isnull(convert(varchar(10),@base_receipt_id),'null')
if @debug = 1 print '@base_line_id=' + isnull(convert(varchar(10),@base_line_id),'null')
if @debug = 1 print '@base_container_id=' + isnull(convert(varchar(10),@base_container_id),'null')
if @debug = 1 print '@base_tracking_num=' + isnull(@base_tracking_num,'null')
if @debug = 1 print '@location_type=' + isnull(@location_type,'null')
if @debug = 1 print '@process_location=' + isnull(@process_location,'null')
if @debug = 1 print '@process_tracking_num=' + isnull(convert(varchar(10),@process_cycle),'null')

-- parse argument for container type and IDs
if substring(@container,1,3) = 'DL-' 
begin
	set @container_type = 'S'
	set @container_company_id = convert(int, substring(@container, 4, 2))
	set @container_profit_ctr_id = convert(int, substring(@container, 6, 2))
	set @container_receipt_id = 0
	set @container_line_id = convert(int, substring(@container, 9, 6))
	set @container_container_id = @container_line_id
end

else
begin
	set @container_type = 'R'
	set @container_company_id = convert(int, substring(@container, 1, 2))
	set @container_profit_ctr_id = convert(int, substring(@container, 3, 2))

	set @pos = charindex('-', @container, 6)
	if @pos < 1 return -1

	set @container_receipt_id = convert(int, substring(@container, 6, @pos - 6))
	
	set @pos2 = charindex('-', @container, @pos + 1)
	if @pos2 < 1 return -1

	set @container_line_id = convert(int, substring(@container, @pos + 1, @pos2 - @pos - 1))
	set @container_container_id = convert(int, substring(@container, @pos2 + 1, 3))
end
if @debug = 1 print '@container_type=' + isnull(@container_type,'null')
if @debug = 1 print '@container_company_id=' + isnull(convert(varchar(10),@container_company_id),'null')
if @debug = 1 print '@container_profit_ctr_id=' + isnull(convert(varchar(10),@container_profit_ctr_id),'null')
if @debug = 1 print '@container_receipt_id=' + isnull(convert(varchar(10),@container_receipt_id),'null')
if @debug = 1 print '@container_line_id=' + isnull(convert(varchar(10),@container_line_id),'null')
if @debug = 1 print '@container_container_id=' + isnull(convert(varchar(10),@container_container_id),'null')

-- record initial @@trancount
set @initial_tran_count = @@TRANCOUNT
if @debug = 1 print '@initial_tran_count=' + convert(varchar(10),@initial_tran_count)

set @audit_dt = GETDATE()

-- if a ContainerDestination record does not exist for base container, insert one
if @location_type <> 'P'
	and not exists (select 1 from ContainerDestination
					where company_id = @base_company_id
					and profit_ctr_id = @base_profit_ctr_id
					and container_type = @base_type
					and receipt_id = @base_receipt_id
					and line_id = @base_line_id
					and container_id = @base_container_id
					and sequence_id = @base_sequence_id)
begin				
	if @debug = 1 print 'ContainerDestination record did not exist for base container...creating one'

	insert ContainerDestination (company_id, profit_ctr_id, container_type, receipt_id, line_id, container_id, sequence_id, container_percent,
								location_type, waste_flag, const_flag, date_added, date_modified, created_by, modified_by, status, modified_from)
	values (@base_company_id, @base_profit_ctr_id, @base_type, @base_receipt_id, @base_line_id, @base_container_id, @base_sequence_id, 0,
			'U', 'F', 'F', @audit_dt, @audit_dt, @user_id, @user_id, 'N', @modified_from)

	-- check for error
	select @err = @@ERROR
	if @err <> 0
	begin
		set @msg = 'Error #' + convert(varchar(10),@err) + ': inserting ContainerDestination record for base container'
		goto ON_ERROR
	end

	-- audit
	insert ContainerAudit (company_id, profit_ctr_id, container_type, receipt_id, line_id, container_id, sequence_id, column_name, before_value, after_value, date_modified, modified_by, modified_from, table_name)
	values (@base_company_id, @base_profit_ctr_id, @base_type, @base_receipt_id, @base_line_id, @base_container_id, @base_sequence_id, 'location_type', '(inserted)', 'U', @audit_dt, @user_id, @modified_from, 'ContainerDestination')

	-- check for error
	select @err = @@ERROR
	if @err <> 0
	begin
		set @msg = 'Error #' + convert(varchar(10),@err) + ': inserting ContainerAudit record for ContainerDestination base container'
		goto ON_ERROR
	end
end

-- if base container treatment_id is not set, set it to what is on the container
if @location_type <> 'P'
	and exists (select 1 from ContainerDestination
				where company_id = @base_company_id
				and profit_ctr_id = @base_profit_ctr_id
				and container_type = @base_type
				and receipt_id = @base_receipt_id
				and line_id = @base_line_id
				and container_id = @base_line_id
				and sequence_id = @base_sequence_id
				and isnull(treatment_id,0) = 0)
begin
	if @debug = 1 print 'Treatment ID not set on base container''s ContainerDestination record...setting to treatment on the container'

	update ContainerDestination
	set treatment_id = cd2.treatment_id,
		modified_by = @user_id,
		date_modified = @audit_dt,
		modified_from = @modified_from
	from ContainerDestination
	join ContainerDestination cd2 (nolock)
		on cd2.company_id = @container_company_id
		and cd2.profit_ctr_id = @container_profit_ctr_id
		and cd2.container_type = @container_type
		and cd2.receipt_id = @container_receipt_id
		and cd2.line_id = @container_line_id
		and cd2.container_id = @container_container_id
		and cd2.sequence_id = @container_sequence_id
	where ContainerDestination.company_id = @base_company_id
	and ContainerDestination.profit_ctr_id = @base_profit_ctr_id
	and ContainerDestination.container_type = @base_type
	and ContainerDestination.receipt_id = @base_receipt_id
	and ContainerDestination.line_id = @base_line_id
	and ContainerDestination.container_id = @base_container_id
	and ContainerDestination.sequence_id = @base_sequence_id

	-- check for error
	select @err = @@ERROR
	if @err <> 0
	begin
		set @msg = 'Error #' + convert(varchar(10),@err) + ': updating ContainerDestination.treatment_id for base container'
		goto ON_ERROR
	end

	-- no audit...update trigger on ContainerDestination generates an audit record
end

-- query container attributes
select @base_status = status,
		@base_size = container_size,
		@base_description = description
from Container (nolock)
where company_id = @base_company_id
and profit_ctr_id = @base_profit_ctr_id
and container_type = @base_type
and receipt_id = @base_receipt_id
and line_id = @base_line_id
and container_id = @base_container_id
if @debug = 1 print '@base_status=' + isnull(convert(varchar(10),@base_status),'null')
if @debug = 1 print '@base_size=' + isnull(convert(varchar(10),@base_size),'null')
if @debug = 1 print '@base_description=' + isnull(convert(varchar(10),@base_description),'null')

select @container_percent = isnull(container_percent,0),
		@waste_flag = isnull(waste_flag,'F'),
		@const_flag = ISNULL(const_flag,'F')
from ContainerDestination (nolock)
where company_id = @container_company_id
and profit_ctr_id = @container_profit_ctr_id
and container_type = @container_type
and receipt_id = @container_receipt_id
and line_id = @container_line_id
and container_id = @container_container_id
and sequence_id = @container_sequence_id
if @debug = 1 print '@container_percent=' + isnull(convert(varchar(10),@container_percent),'null') + ' ---> ' + isnull(convert(varchar(10),@container_percent - @consolidate_percent),'null')
if @debug = 1 print '@waste_flag=' + isnull(@waste_flag,'null') + ', @const_flag=' + isnull(@const_flag,'null')

-- if @disposal_date argument passed in as null, set to current date
if @disposal_date is null
	set @disposal_date = convert(datetime,convert(varchar(10),getdate(),101))
if @debug = 1 print '@dispoal_date=' + isnull(convert(varchar(10),@disposal_date,101),'null')

-- update existing ContainerDestination record based on whether or not it has been completed
if @container_percent = @consolidate_percent
begin
	if @debug = 1 print 'Consolidation will complete the container...updating Container and ContainerDestination status to ''' + @location_type + ''''
	
	-- audit ContainerDestination
	insert ContainerAudit (company_id, profit_ctr_id, container_type, receipt_id, line_id, container_id, sequence_id, column_name, before_value, after_value, date_modified, modified_by, modified_from, table_name)
	select @container_company_id, @container_profit_ctr_id, @container_type, @container_receipt_id, @container_line_id, @container_container_id, @container_sequence_id, 'location_type', isnull(location_type,''), isnull(@location_type,''), @audit_dt, @user_id, @modified_from, 'ContainerDestination'
	from ContainerDestination (nolock)
	where company_id = @container_company_id
	and profit_ctr_id = @container_profit_ctr_id
	and container_type = @container_type
	and receipt_id = @container_receipt_id
	and line_id = @container_line_id
	and container_id = @container_container_id
	and sequence_id = @container_sequence_id
	and isnull(location_type,'') <> isnull(@location_type,'')
	union
	select @container_company_id, @container_profit_ctr_id, @container_type, @container_receipt_id, @container_line_id, @container_container_id, @container_sequence_id, 'location', isnull(location,''), isnull(@process_location,''), @audit_dt, @user_id, @modified_from, 'ContainerDestination'
	from ContainerDestination (nolock)
	where company_id = @container_company_id
	and profit_ctr_id = @container_profit_ctr_id
	and container_type = @container_type
	and receipt_id = @container_receipt_id
	and line_id = @container_line_id
	and container_id = @container_container_id
	and sequence_id = @container_sequence_id
	and isnull(location,'') <> isnull(@process_location,'')
	and @location_type = 'P'
	union
	select @container_company_id, @container_profit_ctr_id, @container_type, @container_receipt_id, @container_line_id, @container_container_id, @container_sequence_id, 'tracking_num', isnull(tracking_num,''), isnull(@process_tracking_num,''), @audit_dt, @user_id, @modified_from, 'ContainerDestination'
	from ContainerDestination (nolock)
	where company_id = @container_company_id
	and profit_ctr_id = @container_profit_ctr_id
	and container_type = @container_type
	and receipt_id = @container_receipt_id
	and line_id = @container_line_id
	and container_id = @container_container_id
	and sequence_id = @container_sequence_id
	and isnull(tracking_num,'') <> isnull(@process_tracking_num,'')
	and @location_type = 'P'
	union
	select @container_company_id, @container_profit_ctr_id, @container_type, @container_receipt_id, @container_line_id, @container_container_id, @container_sequence_id, 'cycle', isnull(convert(varchar(10),cycle),''), isnull(convert(varchar(10),@process_cycle),''), @audit_dt, @user_id, @modified_from, 'ContainerDestination'
	from ContainerDestination (nolock)
	where company_id = @container_company_id
	and profit_ctr_id = @container_profit_ctr_id
	and container_type = @container_type
	and receipt_id = @container_receipt_id
	and line_id = @container_line_id
	and container_id = @container_container_id
	and sequence_id = @container_sequence_id
	and isnull(convert(varchar(10),cycle),'') <> isnull(convert(varchar(10),@process_cycle),'')
	and @location_type = 'P'
	union
	select @container_company_id, @container_profit_ctr_id, @container_type, @container_receipt_id, @container_line_id, @container_container_id, @container_sequence_id, 'disposal_date', isnull(convert(varchar(10),disposal_date,101),''), isnull(convert(varchar(10),@disposal_date,101),''), @audit_dt, @user_id, @modified_from, 'ContainerDestination'
	from ContainerDestination (nolock)
	where company_id = @container_company_id
	and profit_ctr_id = @container_profit_ctr_id
	and container_type = @container_type
	and receipt_id = @container_receipt_id
	and line_id = @container_line_id
	and container_id = @container_container_id
	and sequence_id = @container_sequence_id
	and isnull(convert(varchar(10),disposal_date,101),'') <> isnull(convert(varchar(10),@disposal_date,101),'')
	union
	select @container_company_id, @container_profit_ctr_id, @container_type, @container_receipt_id, @container_line_id, @container_container_id, @container_sequence_id, 'base_tracking_num', isnull(base_tracking_num,''), isnull(@base_tracking_num,''), @audit_dt, @user_id, @modified_from, 'ContainerDestination'
	from ContainerDestination (nolock)
	where company_id = @container_company_id
	and profit_ctr_id = @container_profit_ctr_id
	and container_type = @container_type
	and receipt_id = @container_receipt_id
	and line_id = @container_line_id
	and container_id = @container_container_id
	and sequence_id = @container_sequence_id
	and isnull(base_tracking_num,'') <> isnull(@base_tracking_num,'')
	union
	select @container_company_id, @container_profit_ctr_id, @container_type, @container_receipt_id, @container_line_id, @container_container_id, @container_sequence_id, 'base_container_id', isnull(convert(varchar(10),base_container_id),''), isnull(convert(varchar(10),@base_container_id),''), @audit_dt, @user_id, @modified_from, 'ContainerDestination'
	from ContainerDestination (nolock)
	where company_id = @container_company_id
	and profit_ctr_id = @container_profit_ctr_id
	and container_type = @container_type
	and receipt_id = @container_receipt_id
	and line_id = @container_line_id
	and container_id = @container_container_id
	and sequence_id = @container_sequence_id
	and isnull(convert(varchar(10),base_container_id),'') <> isnull(convert(varchar(10),@base_container_id),'')
	union
	select @container_company_id, @container_profit_ctr_id, @container_type, @container_receipt_id, @container_line_id, @container_container_id, @container_sequence_id, 'base_sequence_id', isnull(convert(varchar(10),base_sequence_id),''), isnull(convert(varchar(10),@base_sequence_id),''), @audit_dt, @user_id, @modified_from, 'ContainerDestination'
	from ContainerDestination (nolock)
	where company_id = @container_company_id
	and profit_ctr_id = @container_profit_ctr_id
	and container_type = @container_type
	and receipt_id = @container_receipt_id
	and line_id = @container_line_id
	and container_id = @container_container_id
	and sequence_id = @container_sequence_id
	and isnull(convert(varchar(10),base_sequence_id),'') <> isnull(convert(varchar(10),@base_sequence_id),'')
	union
	select @container_company_id, @container_profit_ctr_id, @container_type, @container_receipt_id, @container_line_id, @container_container_id, @container_sequence_id, 'status', isnull(status,''), 'C', @audit_dt, @user_id, @modified_from, 'ContainerDestination'
	from ContainerDestination (nolock)
	where company_id = @container_company_id
	and profit_ctr_id = @container_profit_ctr_id
	and container_type = @container_type
	and receipt_id = @container_receipt_id
	and line_id = @container_line_id
	and container_id = @container_container_id
	and sequence_id = @container_sequence_id
	and isnull(status,'') <> 'C'
	union
	select @container_company_id, @container_profit_ctr_id, @container_type, @container_receipt_id, @container_line_id, @container_container_id, @container_sequence_id, 'treatment_id', isnull(convert(varchar(10),treatment_id),''), convert(varchar(10),@process_treatment_id), @audit_dt, @user_id, @modified_from, 'ContainerDestination'
	from ContainerDestination (nolock)
	where company_id = @container_company_id
	and profit_ctr_id = @container_profit_ctr_id
	and container_type = @container_type
	and receipt_id = @container_receipt_id
	and line_id = @container_line_id
	and container_id = @container_container_id
	and sequence_id = @container_sequence_id
	and @location_type = 'P'
	and @process_treatment_id is not null
	and isnull(convert(varchar(10),treatment_id),'') <> isnull(convert(varchar(10),@process_treatment_id),'')

	-- check for error
	select @err = @@ERROR
	if @err <> 0
	begin
		set @msg = 'Error #' + convert(varchar(10),@err) + ': inserting ContainerAudit records for ContainerDestination container'
		goto ON_ERROR
	end

	update ContainerDestination
	set location_type = @location_type,
		location = @process_location,
		tracking_num = @process_tracking_num,
		cycle = @process_cycle,
		disposal_date = @disposal_date,
		base_tracking_num = @base_tracking_num,
		base_container_id = @base_container_id,
		base_sequence_id = @base_sequence_id,
		status = 'C',
		date_modified = @audit_dt,
		modified_by = @user_id,
		modified_from = @modified_from,
		treatment_id = case when @location_type = 'P' and @process_treatment_id is not null then @process_treatment_id else treatment_id end
	where company_id = @container_company_id
	and profit_ctr_id = @container_profit_ctr_id
	and container_type = @container_type
	and receipt_id = @container_receipt_id
	and line_id = @container_line_id
	and container_id = @container_container_id
	and sequence_id = @container_sequence_id

	-- check for error
	select @err = @@ERROR
	if @err <> 0
	begin
		set @msg = 'Error #' + convert(varchar(10),@err) + ': updating ContainerDestination record to Complete'
		goto ON_ERROR
	end

	-- audit Container
	insert ContainerAudit (company_id, profit_ctr_id, container_type, receipt_id, line_id, container_id, sequence_id, column_name, before_value, after_value, date_modified, modified_by, modified_from, table_name)
	select @container_company_id, @container_profit_ctr_id, @container_type, @container_receipt_id, @container_line_id, @container_container_id, @container_sequence_id, 'status', isnull(status,''), 'C', @audit_dt, @user_id, @modified_from, 'Container'
	from ContainerDestination (nolock)
	where company_id = @container_company_id
	and profit_ctr_id = @container_profit_ctr_id
	and container_type = @container_type
	and receipt_id = @container_receipt_id
	and line_id = @container_line_id
	and container_id = @container_container_id
	and sequence_id = @container_sequence_id
	and isnull(status,'') <> 'C'

	-- check for error
	select @err = @@ERROR
	if @err <> 0
	begin
		set @msg = 'Error #' + convert(varchar(10),@err) + ': inserting ContainerAudit records for Container container'
		goto ON_ERROR
	end

	update Container
	set status = 'C',
		date_modified = @audit_dt,
		modified_by = @user_id
	where company_id = @container_company_id
	and profit_ctr_id = @container_profit_ctr_id
	and container_type = @container_type
	and receipt_id = @container_receipt_id
	and line_id = @container_line_id
	and container_id = @container_container_id

	-- check for error
	select @err = @@ERROR
	if @err <> 0
	begin
		set @msg = 'Error #' + convert(varchar(10),@err) + ': updating Container record to Complete'
		goto ON_ERROR
	end

	-- existing record will become completed container
	set @new_container_sequence_id = @base_sequence_id
	if @debug = 1 print '@new_container_sequence_id=' + isnull(convert(varchar(10),@new_container_sequence_id),'null')


	-- rb 05/27/2014 Safeguard...when completing remaining container and arguments are blank, "(ALL)" is implied
	if isnull(ltrim(rtrim(@consolidate_waste_codes)),'') = ''
		set @consolidate_waste_codes = '(ALL)'
	if isnull(ltrim(rtrim(@consolidate_constituents)),'') = ''
		set @consolidate_constituents = '(ALL)'
end

else
begin
	if @debug = 1 print 'Partial consolidation...updating ContainerDestination.container_percent etc.'
	
	-- audit ContainerDestination
	insert ContainerAudit (company_id, profit_ctr_id, container_type, receipt_id, line_id, container_id, sequence_id, column_name, before_value, after_value, date_modified, modified_by, modified_from, table_name)
	values (@container_company_id, @container_profit_ctr_id, @container_type, @container_receipt_id, @container_line_id, @container_container_id, @container_sequence_id, 'container_percent', isnull(convert(varchar(10),@container_percent),''), isnull(convert(varchar(10),@container_percent - @consolidate_percent),''), @audit_dt, @user_id, @modified_from, 'ContainerDestination')

	-- check for error
	select @err = @@ERROR
	if @err <> 0
	begin
		set @msg = 'Error #' + convert(varchar(10),@err) + ': inserting ContainerAudit for ContainerDestination container percent'
		goto ON_ERROR
	end

	update ContainerDestination
	set container_percent = @container_percent - @consolidate_percent,
		date_modified = @audit_dt,
		modified_by = @user_id,
		modified_from = @modified_from
	where company_id = @container_company_id
	and profit_ctr_id = @container_profit_ctr_id
	and container_type = @container_type
	and receipt_id = @container_receipt_id
	and line_id = @container_line_id
	and container_id = @container_container_id
	and sequence_id = @container_sequence_id

	-- check for error
	select @err = @@ERROR
	if @err <> 0
	begin
		set @msg = 'Error #' + convert(varchar(10),@err) + ': updating ContainerDestination record percent'
		goto ON_ERROR
	end

	-- determine new ContainerDestination sequence_id
	select @new_container_sequence_id = max(sequence_id)
	from ContainerDestination
	where company_id = @container_company_id
	and profit_ctr_id = @container_profit_ctr_id
	and container_type = @container_type
	and receipt_id = @container_receipt_id
	and line_id = @container_line_id
	and container_id = @container_container_id

	set @new_container_sequence_id = isnull(@new_container_sequence_id,0) + 1
	if @debug = 1 print '@new_container_sequence_id=' + isnull(convert(varchar(10),@new_container_sequence_id),'null')

	if @debug = 1 print 'Inserting new ContainerDestination record for container'
	
	insert ContainerDestination (company_id, profit_ctr_id, container_type, receipt_id, line_id, container_id, sequence_id, container_percent,
								treatment_id, location_type, location, tracking_num, cycle, disposal_date, base_tracking_num, base_container_id,
								waste_flag, const_flag, status, date_added, date_modified, created_by, modified_by, modified_from, base_sequence_id)
	select company_id, profit_ctr_id, container_type, receipt_id, line_id, container_id, @new_container_sequence_id, @consolidate_percent,
			case when @location_type = 'P' and @process_treatment_id is not null then @process_treatment_id else treatment_id end,
			@location_type, @process_location, @process_tracking_num, @process_cycle, @disposal_date, @base_tracking_num, @base_container_id,
			'F', 'F', 'C', @audit_dt, @audit_dt, @user_id, @user_id, @modified_from, @base_sequence_id
	from ContainerDestination
	where company_id = @container_company_id
	and profit_ctr_id = @container_profit_ctr_id
	and container_type = @container_type
	and receipt_id = @container_receipt_id
	and line_id = @container_line_id
	and container_id = @container_container_id
	and sequence_id = @container_sequence_id
	
	-- check for error
	select @err = @@ERROR
	if @err <> 0
	begin
		set @msg = 'Error #' + convert(varchar(10),@err) + ': inserting ContainerDestination record partial container consolidation'
		goto ON_ERROR
	end

	-- audit (was a union for single error-check, but we don't want to insert empty values)
	insert ContainerAudit (company_id, profit_ctr_id, container_type, receipt_id, line_id, container_id, sequence_id, column_name, before_value, after_value, date_modified, modified_by, modified_from, table_name)
	select @container_company_id, @container_profit_ctr_id, @container_type, @container_receipt_id, @container_line_id, @container_container_id, @new_container_sequence_id, 'container_percent', '(inserted)', isnull(convert(varchar(10),@consolidate_percent),''), @audit_dt, @user_id, @modified_from, 'ContainerDestination'

	if isnull(@location_type,'') <> ''
		insert ContainerAudit (company_id, profit_ctr_id, container_type, receipt_id, line_id, container_id, sequence_id, column_name, before_value, after_value, date_modified, modified_by, modified_from, table_name)
		select @container_company_id, @container_profit_ctr_id, @container_type, @container_receipt_id, @container_line_id, @container_container_id, @new_container_sequence_id, 'location_type', '(inserted)', isnull(@location_type,''), @audit_dt, @user_id, @modified_from, 'ContainerDestination'

	if isnull(@process_location,'') <> ''
		insert ContainerAudit (company_id, profit_ctr_id, container_type, receipt_id, line_id, container_id, sequence_id, column_name, before_value, after_value, date_modified, modified_by, modified_from, table_name)
		select @container_company_id, @container_profit_ctr_id, @container_type, @container_receipt_id, @container_line_id, @container_container_id, @new_container_sequence_id, 'location', '(inserted)', isnull(@process_location,''), @audit_dt, @user_id, @modified_from, 'ContainerDestination'

	if isnull(@process_tracking_num,'') <> ''
		insert ContainerAudit (company_id, profit_ctr_id, container_type, receipt_id, line_id, container_id, sequence_id, column_name, before_value, after_value, date_modified, modified_by, modified_from, table_name)
		select @container_company_id, @container_profit_ctr_id, @container_type, @container_receipt_id, @container_line_id, @container_container_id, @new_container_sequence_id, 'tracking_num', '(inserted)', isnull(@process_tracking_num,''), @audit_dt, @user_id, @modified_from, 'ContainerDestination'

	if isnull(convert(varchar(10),@process_cycle),'') <> ''
		insert ContainerAudit (company_id, profit_ctr_id, container_type, receipt_id, line_id, container_id, sequence_id, column_name, before_value, after_value, date_modified, modified_by, modified_from, table_name)
		select @container_company_id, @container_profit_ctr_id, @container_type, @container_receipt_id, @container_line_id, @container_container_id, @new_container_sequence_id, 'cycle', '(inserted)', isnull(convert(varchar(10),@process_cycle),''), @audit_dt, @user_id, @modified_from, 'ContainerDestination'

	if isnull(convert(varchar(10),@disposal_date,101),'') <> ''
		insert ContainerAudit (company_id, profit_ctr_id, container_type, receipt_id, line_id, container_id, sequence_id, column_name, before_value, after_value, date_modified, modified_by, modified_from, table_name)
		select @container_company_id, @container_profit_ctr_id, @container_type, @container_receipt_id, @container_line_id, @container_container_id, @new_container_sequence_id, 'disposal_date', '(inserted)', isnull(convert(varchar(10),@disposal_date,101),''), @audit_dt, @user_id, @modified_from, 'ContainerDestination'

	if isnull(@base_tracking_num,'') <> ''
		insert ContainerAudit (company_id, profit_ctr_id, container_type, receipt_id, line_id, container_id, sequence_id, column_name, before_value, after_value, date_modified, modified_by, modified_from, table_name)
		select @container_company_id, @container_profit_ctr_id, @container_type, @container_receipt_id, @container_line_id, @container_container_id, @new_container_sequence_id, 'base_tracking_num', '(inserted)', isnull(@base_tracking_num,''), @audit_dt, @user_id, @modified_from, 'ContainerDestination'

	if isnull(convert(varchar(10),@base_container_id),'') <> ''
		insert ContainerAudit (company_id, profit_ctr_id, container_type, receipt_id, line_id, container_id, sequence_id, column_name, before_value, after_value, date_modified, modified_by, modified_from, table_name)
		select @container_company_id, @container_profit_ctr_id, @container_type, @container_receipt_id, @container_line_id, @container_container_id, @new_container_sequence_id, 'base_container_id', '(inserted)', isnull(convert(varchar(10),@base_container_id),''), @audit_dt, @user_id, @modified_from, 'ContainerDestination'

	if isnull(convert(varchar(10),@base_sequence_id),'') <> ''
		insert ContainerAudit (company_id, profit_ctr_id, container_type, receipt_id, line_id, container_id, sequence_id, column_name, before_value, after_value, date_modified, modified_by, modified_from, table_name)
		select @container_company_id, @container_profit_ctr_id, @container_type, @container_receipt_id, @container_line_id, @container_container_id, @new_container_sequence_id, 'base_sequence_id', '(inserted)', isnull(convert(varchar(10),@base_sequence_id),''), @audit_dt, @user_id, @modified_from, 'ContainerDestination'

	insert ContainerAudit (company_id, profit_ctr_id, container_type, receipt_id, line_id, container_id, sequence_id, column_name, before_value, after_value, date_modified, modified_by, modified_from, table_name)
	select @container_company_id, @container_profit_ctr_id, @container_type, @container_receipt_id, @container_line_id, @container_container_id, @new_container_sequence_id, 'status', '(inserted)', 'C', @audit_dt, @user_id, @modified_from, 'ContainerDestination'
	
	-- check for error
	select @err = @@ERROR
	if @err <> 0
	begin
		set @msg = 'Error #' + convert(varchar(10),@err) + ': inserting ContainerAudit records for ContainerDestination new container sequence'
		goto ON_ERROR
	end
end

if @debug = 1 print '@consolidate_waste_codes=' + isnull(@consolidate_waste_codes,'null')
if @debug = 1 print '@remove_waste_codes=' + isnull(@remove_waste_codes,'null')
if @debug = 1 print '@consolidate_constituents=' + isnull(@consolidate_constituents,'null')
if @debug = 1 print '@remove_constituents=' + isnull(@remove_constituents,'null')

-- if base container is still referencing receipt waste codes, copy them over to ContainerWasteCode
if @location_type <> 'P'
	and not exists (select 1 from ContainerWasteCode
					where company_id = @base_company_id
					and profit_ctr_id = @base_profit_ctr_id
					and container_type = @base_type
					and receipt_id = @base_receipt_id
					and line_id = @base_line_id
					and container_id = @base_container_id
					and sequence_id = @base_sequence_id)
begin
	insert ContainerWasteCode (company_id, profit_ctr_id, container_type, receipt_id, line_id, container_id, sequence_id, waste_code_uid,
								waste_code, date_added, created_by, source_receipt_id, source_line_id, source_container_id, source_sequence_id)
	select distinct company_id, profit_ctr_id, @base_type, receipt_id, line_id, @base_container_id, @base_sequence_id, waste_code_uid,
					waste_code, @audit_dt, @user_id, null, null, null, null
	from ReceiptWasteCode
	where company_id = @base_company_id
	and profit_ctr_id = @base_profit_ctr_id
	and receipt_id = @base_receipt_id
	and line_id = @base_line_id

	-- check for error
	select @err = @@ERROR
	if @err <> 0
	begin
		set @msg = 'Error #' + convert(varchar(10),@err) + ': inserting ContainerWasteCode records for base container from ReceiptWasteCode'
		goto ON_ERROR
	end
end

-- determine if referencing receipt waste codes
if exists (select 1 from ContainerWasteCode
			where company_id = @container_company_id
			and profit_ctr_id = @container_profit_ctr_id
			and container_type = @container_type
			and receipt_id = @container_receipt_id
			and line_id = @container_line_id
			and container_id = @container_container_id
			and sequence_id = @container_sequence_id)
	set @is_referencing_receipt_records = 0
else
	set @is_referencing_receipt_records = 1
if @debug = 1 print '@is_referencing_receipt_records (waste codes)=' + isnull(convert(varchar(10),@is_referencing_receipt_records),'null')

-- add selected waste codes
if @location_type <> 'P' and isnull(ltrim(rtrim(@consolidate_waste_codes)),'') <> ''
begin
	set @sql = 'insert ContainerWasteCode (company_id, profit_ctr_id, container_type, receipt_id, line_id, container_id, sequence_id, waste_code_uid, '
			+ 'waste_code, date_added, created_by, source_receipt_id, source_line_id, source_container_id, source_sequence_id) '
			+ 'select distinct ' + convert(varchar(10),@base_company_id) + ', ' + convert(varchar(10),@base_profit_ctr_id) + ', ''' + @base_type + ''', '
			+ convert(varchar(10),@base_receipt_id) + ', ' + convert(varchar(10),@base_line_id)
			+ ', ' + convert(varchar(10),@base_container_id) + ', ' + convert(varchar(10),@base_sequence_id)
			+ ', waste_code_uid, waste_code, ''' + convert(varchar(30),@audit_dt,121) + ''', ''' + @user_id + ''''
			+ ', receipt_id, line_id, ' + convert(varchar(10),@container_container_id) + ', ' + convert(varchar(10),@new_container_sequence_id)

	if @is_referencing_receipt_records = 0
		
		set @sql = @sql + ' from ContainerWasteCode'
						+ ' where company_id = ' + convert(varchar(10),@container_company_id)
						+ ' and profit_ctr_id = ' + convert(varchar(10),@container_profit_ctr_id)
						+ ' and container_type = ''' + @container_type + ''''
						+ ' and receipt_id = ' + convert(varchar(10),@container_receipt_id)
						+ ' and line_id = ' + convert(varchar(10),@container_line_id)
						+ ' and container_id = ' + convert(varchar(10),@container_container_id)
						+ ' and sequence_id = ' + convert(varchar(10),@container_sequence_id)
	else
		set @sql = @sql + ' from ReceiptWasteCode'
						+ ' where company_id = ' + convert(varchar(10),@container_company_id)
						+ ' and profit_ctr_id = ' + convert(varchar(10),@container_profit_ctr_id)
						+ ' and receipt_id = ' + convert(varchar(10),@container_receipt_id)
						+ ' and line_id = ' + convert(varchar(10),@container_line_id)

	if @consolidate_waste_codes <> '(ALL)'
		set @sql = @sql + ' and waste_code_uid in (' + @consolidate_waste_codes + ')'

	if @debug = 1 print 'sql to insert ContainerWasteCode records:'
	if @debug = 1 print isnull(@sql,'null')

	execute(@sql)

	-- check for error
	select @err = @@ERROR
	if @err <> 0
	begin
		set @msg = 'Error #' + convert(varchar(10),@err) + ': inserting ContainerWasteCode records'
		goto ON_ERROR
	end
	
	-- audit
	insert ContainerAudit (company_id, profit_ctr_id, container_type, receipt_id, line_id, container_id, sequence_id, column_name, before_value, after_value, date_modified, modified_by, modified_from, table_name)
	select @base_company_id, @base_profit_ctr_id, @base_type, @base_receipt_id, @base_line_id, @base_container_id, @base_sequence_id, 'waste_code', '(inserted)', wc.display_name + ' (' + CONVERT(varchar(10),cwc.waste_code_uid) + ')', @audit_dt, @user_id, @modified_from, 'ContainerWasteCode'
	from ContainerWasteCode cwc (nolock)
	join WasteCode wc (nolock) on cwc.waste_code_uid = wc.waste_code_uid
	where cwc.company_id = @base_company_id
	and cwc.profit_ctr_id = @base_profit_ctr_id
	and cwc.container_type = @base_type
	and cwc.receipt_id = @base_receipt_id
	and cwc.line_id = @base_line_id
	and cwc.container_id = @base_container_id
	and cwc.sequence_id = @base_sequence_id
	and cwc.date_added = @audit_dt
	and cwc.created_by = @user_id

	-- check for error
	select @err = @@ERROR
	if @err <> 0
	begin
		set @msg = 'Error #' + convert(varchar(10),@err) + ': audit inserting ContainerWasteCode records'
		goto ON_ERROR
	end
end

-- rb 03/31/2014
if isnull(@new_container_sequence_id,0) > @container_sequence_id or isnull(@is_referencing_receipt_records,0) = 1
begin
	set @sql = 'insert ContainerWasteCode (company_id, profit_ctr_id, container_type, receipt_id, line_id, container_id, sequence_id, waste_code_uid, '
			+ 'waste_code, date_added, created_by, source_receipt_id, source_line_id, source_container_id, source_sequence_id) '
			+ 'select distinct ' + convert(varchar(10),@container_company_id) + ', ' + convert(varchar(10),@container_profit_ctr_id) + ', ''' + @container_type + ''''
			+ ', ' + convert(varchar(10),@container_receipt_id) + ', ' + convert(varchar(10),@container_line_id) + ', ' + convert(varchar(10),@container_container_id)
			+ ', ' + convert(varchar(10),@new_container_sequence_id) + ', waste_code_uid, waste_code, ''' + convert(varchar(30),@audit_dt,121) + ''', ''' + @user_id + ''', '
			+ case when isnull(@is_referencing_receipt_records,0) = 1 then 'null, null, null, null'
			  else 'source_receipt_id, source_line_id, source_container_id, source_sequence_id' end

	if isnull(@is_referencing_receipt_records,0) = 0
		set @sql = @sql + ' from ContainerWasteCode'
						+ ' where company_id = ' + convert(varchar(10),@container_company_id)
						+ ' and profit_ctr_id = ' + convert(varchar(10),@container_profit_ctr_id)
						+ ' and container_type = ''' + @container_type + ''''
						+ ' and receipt_id = ' + convert(varchar(10),@container_receipt_id)
						+ ' and line_id = ' + convert(varchar(10),@container_line_id)
						+ ' and container_id = ' + convert(varchar(10),@container_container_id)
						+ ' and sequence_id = ' + convert(varchar(10),@container_sequence_id)
	else
		set @sql = @sql + ' from ReceiptWasteCode'
						+ ' where company_id = ' + convert(varchar(10),@container_company_id)
						+ ' and profit_ctr_id = ' + convert(varchar(10),@container_profit_ctr_id)
						+ ' and receipt_id = ' + convert(varchar(10),@container_receipt_id)
						+ ' and line_id = ' + convert(varchar(10),@container_line_id)

	if isnull(@consolidate_waste_codes,'') <> '(ALL)'
	begin
		if isnull(ltrim(rtrim(@consolidate_waste_codes)),'') = ''
			select @sql = @sql + ' and waste_code_uid = ' + convert(varchar(10),waste_code_uid)
			from WasteCode (nolock)
			where display_name = 'NONE'
		else
			set @sql = @sql + ' and waste_code_uid in (' + @consolidate_waste_codes + ')'
	end

	if @debug = 1 print 'sql to insert new sequence ContainerWasteCode records:'
	if @debug = 1 print isnull(@sql,'null')

	execute(@sql)

	-- check for error
	select @err = @@ERROR
	if @err <> 0
	begin
		set @msg = 'Error #' + convert(varchar(10),@err) + ': inserting new sequence ContainerWasteCode records'
		goto ON_ERROR
	end
end

-- remove selected waste codes
if isnull(ltrim(rtrim(@remove_waste_codes)),'') <> ''
begin
	set @waste_flag = 'T'
	set @sql = ''

	-- if referencing Receipt records and anything was marked for removal, ContainerWasteCode needs to be populated
	if isnull(@is_referencing_receipt_records,0) = 1
	begin
		set @sql = 'insert ContainerWasteCode (company_id, profit_ctr_id, container_type, receipt_id, line_id, container_id, sequence_id, waste_code_uid, '
				+ 'waste_code, date_added, created_by) '
				+ 'select distinct company_id, profit_ctr_id, ''' + @container_type + ''', receipt_id, line_id, ' + convert(varchar(10),@container_container_id)
				+ ', ' + convert(varchar(10),@container_sequence_id) + ', waste_code_uid, waste_code, ''' + convert(varchar(30),@audit_dt,121) + ''', ''' + @user_id + ''''
				+ ' from ReceiptWasteCode'
				+ ' where company_id = ' + convert(varchar(10),@container_company_id)
				+ ' and profit_ctr_id = ' + convert(varchar(10),@container_profit_ctr_id)
				+ ' and receipt_id = ' + convert(varchar(10),@container_receipt_id)
				+ ' and line_id = ' + convert(varchar(10),@container_line_id)
				+ ' and waste_code_uid not in (' + @remove_waste_codes + ')'

		if @debug = 1 print 'sql to populate ContainerWasteCode records from receipt:'
		if @debug = 1 print isnull(@sql,'null')

		execute(@sql)
		
		-- check for error
		select @err = @@ERROR
		if @err <> 0
		begin
			set @msg = 'Error #' + convert(varchar(10),@err) + ': populating ContainerWasteCode records from receipt'
			goto ON_ERROR
		end
	end

	-- audit
	set @sql = 'insert ContainerAudit (company_id, profit_ctr_id, container_type, receipt_id, line_id, container_id, sequence_id, column_name, before_value, after_value, date_modified, modified_by, modified_from, table_name)'
			+ ' select cwc.company_id, cwc.profit_ctr_id, cwc.container_type, cwc.receipt_id, cwc.line_id, cwc.container_id, cwc.sequence_id, ''waste_code'', wc.display_name + '' ('' + CONVERT(varchar(10),cwc.waste_code_uid) + '')'', ''(deleted)'''
			+ ', ''' + convert(varchar(30),@audit_dt,121) + ''''
			+ ', ''' + @user_id + ''''
			+ ', ''' + @modified_from + ''''
			+ ', ''ContainerWasteCode'''
			+ ' from ContainerWasteCode cwc (nolock)'
			+ ' join WasteCode wc (nolock) on cwc.waste_code_uid = wc.waste_code_uid'
			+ ' where cwc.company_id = ' + convert(varchar(10),@container_company_id)
			+ ' and cwc.profit_ctr_id = ' + convert(varchar(10),@container_profit_ctr_id)
			+ ' and cwc.container_type = ''' + @container_type + ''''
			+ ' and cwc.receipt_id = ' + convert(varchar(10),@container_receipt_id)
			+ ' and cwc.line_id = ' + convert(varchar(10),@container_line_id)
			+ ' and cwc.container_id = ' + convert(varchar(10),@container_container_id)
			+ ' and cwc.sequence_id = ' + convert(varchar(10),@container_sequence_id)

	if ltrim(rtrim(@remove_waste_codes)) <> '(ALL)'
		set @sql = @sql + ' and cwc.waste_code_uid in (' + @remove_waste_codes + ')'

	if @debug = 1 print 'sql to audit removal of ContainerWasteCode records from receipt:'
	if @debug = 1 print isnull(@sql,'null')

	execute(@sql)
	
	-- check for error
	select @err = @@ERROR
	if @err <> 0
	begin
		set @msg = 'Error #' + convert(varchar(10),@err) + ': audit removing ContainerWasteCode records'
		goto ON_ERROR
	end

	-- remove
	set @sql = 'delete ContainerWasteCode'
			+ ' where company_id = ' + convert(varchar(10),@container_company_id)
			+ ' and profit_ctr_id = ' + convert(varchar(10),@container_profit_ctr_id)
			+ ' and container_type = ''' + @container_type + ''''
			+ ' and receipt_id = ' + convert(varchar(10),@container_receipt_id)
			+ ' and line_id = ' + convert(varchar(10),@container_line_id)
			+ ' and container_id = ' + convert(varchar(10),@container_container_id)
			+ ' and sequence_id = ' + convert(varchar(10),@container_sequence_id)
	
	if ltrim(rtrim(@remove_waste_codes)) <> '(ALL)'
		set @sql = @sql + ' and waste_code_uid in (' + @remove_waste_codes + ')'

	if @debug = 1 print 'sql to remove ContainerWasteCode records:'
	if @debug = 1 print isnull(@sql,'null')

	execute(@sql)
	
	-- check for error
	select @err = @@ERROR
	if @err <> 0
	begin
		set @msg = 'Error #' + convert(varchar(10),@err) + ': deleting ContainerWasteCode records'
		goto ON_ERROR
	end
	
	-- if there are no waste codes left on the container, insert NONE
	if not exists (select 1 from ContainerWasteCode
				where company_id = @container_company_id
				and profit_ctr_id = @container_profit_ctr_id
				and container_type = @container_type
				and receipt_id = @container_receipt_id
				and line_id = @container_line_id
				and container_id = @container_container_id
				and sequence_id = @container_sequence_id)
	begin
		insert ContainerWasteCode (profit_ctr_id, container_type, receipt_id, line_id, container_id, sequence_id, waste_code_uid, waste_code, date_added, created_by, company_id)
		select @container_profit_ctr_id, @container_type, @container_receipt_id, @container_line_id, @container_container_id, @container_sequence_id,
				waste_code_uid, waste_code, @audit_dt, @user_id, @container_company_id
		from WasteCode (nolock)
		where waste_code = 'NONE'

		-- check for error
		select @err = @@ERROR
		if @err <> 0
		begin
			set @msg = 'Error #' + convert(varchar(10),@err) + ': inserting ''NONE'' into ContainerWasteCode table'
			goto ON_ERROR
		end
	end
end

-- if base container is still referencing receipt constituents, copy them over to ContainerConstituent
if @location_type <> 'P' and
	not exists (select 1 from ContainerConstituent
				where company_id = @base_company_id
				and profit_ctr_id = @base_profit_ctr_id
				and container_type = @base_type
				and receipt_id = @base_receipt_id
				and line_id = @base_line_id
				and container_id = @base_container_id
				and sequence_id = @base_sequence_id)
begin
	insert ContainerConstituent (company_id, profit_ctr_id, container_type, receipt_id, line_id, container_id, sequence_id, const_id,
								UHC, date_added, created_by, source_receipt_id, source_line_id, source_container_id, source_sequence_id)
	select distinct company_id, profit_ctr_id, @base_type, receipt_id, line_id, @base_container_id, @base_sequence_id, const_id,
					UHC, @audit_dt, @user_id, null, null, null, null
	from ReceiptConstituent
	where company_id = @base_company_id
	and profit_ctr_id = @base_profit_ctr_id
	and receipt_id = @base_receipt_id
	and line_id = @base_line_id

	-- check for error
	select @err = @@ERROR
	if @err <> 0
	begin
		set @msg = 'Error #' + convert(varchar(10),@err) + ': inserting ContainerConstituent records for base container from ReceiptConstituent'
		goto ON_ERROR
	end
end

-- determine if referencing receipt constituents
if exists (select 1 from ContainerConstituent
			where company_id = @container_company_id
			and profit_ctr_id = @container_profit_ctr_id
			and container_type = @container_type
			and receipt_id = @container_receipt_id
			and line_id = @container_line_id
			and container_id = @container_container_id
			and sequence_id = @container_sequence_id)

		set @is_referencing_receipt_records = 0
else
		set @is_referencing_receipt_records = 1
if @debug = 1 print '@is_referencing_receipt_records (constituents)=' + isnull(convert(varchar(10),@is_referencing_receipt_records),'null')

-- add selected constituents
if @location_type <> 'P' and isnull(ltrim(rtrim(@consolidate_constituents)),'') <> ''
begin
	set @sql = 'insert ContainerConstituent (company_id, profit_ctr_id, container_type, receipt_id, line_id, container_id, sequence_id, const_id, '
			+ 'UHC, date_added, created_by, source_receipt_id, source_line_id, source_container_id, source_sequence_id) '
			+ 'select distinct ' + convert(varchar(10),@base_company_id) + ', ' + convert(varchar(10),@base_profit_ctr_id) + ', ''' + @base_type + ''''
			+ ', ' + convert(varchar(10),@base_receipt_id) + ', ' + convert(varchar(10),@base_line_id) + ', ' + convert(varchar(10),@base_container_id)
			+ ', ' + convert(varchar(10),@base_sequence_id) + ', const_id, UHC, ''' + convert(varchar(30),@audit_dt,121) + ''', ''' + @user_id + ''''
			+ ', receipt_id, line_id, ' + convert(varchar(10),@container_container_id) + ', ' + convert(varchar(10),@new_container_sequence_id)

	if @is_referencing_receipt_records = 0

		set @sql = @sql + ' from ContainerConstituent c'
						+ ' where company_id = ' + convert(varchar(10),@container_company_id)
						+ ' and profit_ctr_id = ' + convert(varchar(10),@container_profit_ctr_id)
						+ ' and container_type = ''' + @container_type + ''''
						+ ' and receipt_id = ' + convert(varchar(10),@container_receipt_id)
						+ ' and line_id = ' + convert(varchar(10),@container_line_id)
						+ ' and container_id = ' + convert(varchar(10),@container_container_id)
						+ ' and sequence_id = ' + convert(varchar(10),@container_sequence_id)
						+ ' and uhc = (select max(uhc) from ContainerConstituent'
						+ ' where company_id = ' + convert(varchar(10),@container_company_id)
						+ ' and profit_ctr_id = ' + convert(varchar(10),@container_profit_ctr_id)
						+ ' and container_type = ''' + @container_type + ''''
						+ ' and receipt_id = ' + convert(varchar(10),@container_receipt_id)
						+ ' and line_id = ' + convert(varchar(10),@container_line_id)
						+ ' and container_id = ' + convert(varchar(10),@container_container_id)
						+ ' and sequence_id = ' + convert(varchar(10),@container_sequence_id)
						+ ' and const_id = c.const_id)'
	else
		set @sql = @sql + ' from ReceiptConstituent c'
						+ ' where company_id = ' + convert(varchar(10),@container_company_id)
						+ ' and profit_ctr_id = ' + convert(varchar(10),@container_profit_ctr_id)
						+ ' and receipt_id = ' + convert(varchar(10),@container_receipt_id)
						+ ' and line_id = ' + convert(varchar(10),@container_line_id)

	if isnull(@consolidate_constituents,'') <> '(ALL)'
		set @sql = @sql + ' and const_id in (' + @consolidate_constituents + ')'

	if @debug = 1 print 'sql to insert ContainerConstituent records:'
	if @debug = 1 print isnull(@sql,'null')

	execute(@sql)

	-- check for error
	select @err = @@ERROR
	if @err <> 0
	begin
		set @msg = 'Error #' + convert(varchar(10),@err) + ': inserting ContainerConstituent records'
		goto ON_ERROR
	end

	-- audit
	insert ContainerAudit (company_id, profit_ctr_id, container_type, receipt_id, line_id, container_id, sequence_id, column_name, before_value, after_value, date_modified, modified_by, modified_from, table_name)
	select @base_company_id, @base_profit_ctr_id, @base_type, @base_receipt_id, @base_line_id, @base_container_id, @base_sequence_id, 'constituent', '(inserted)', c.const_desc + ' (' + CONVERT(varchar(10),cc.const_id) + ')', @audit_dt, @user_id, @modified_from, 'ContainerConstituent'
	from ContainerConstituent cc (nolock)
	join Constituents c (nolock) on cc.const_id = c.const_id
	where cc.company_id = @base_company_id
	and cc.profit_ctr_id = @base_profit_ctr_id
	and cc.container_type = @base_type
	and cc.receipt_id = @base_receipt_id
	and cc.line_id = @base_line_id
	and cc.container_id = @base_container_id
	and cc.sequence_id = @base_sequence_id
	and cc.date_added = @audit_dt
	and cc.created_by = @user_id

	-- check for error
	select @err = @@ERROR
	if @err <> 0
	begin
		set @msg = 'Error #' + convert(varchar(10),@err) + ': audit inserting ContainerConstituent records'
		goto ON_ERROR
	end
end

-- rb 03/31/2014
if isnull(@new_container_sequence_id,0) > @container_sequence_id or isnull(@is_referencing_receipt_records,0) = 1
begin
	set @sql = 'insert ContainerConstituent (company_id, profit_ctr_id, container_type, receipt_id, line_id, container_id, sequence_id, const_id, '
			+ 'UHC, date_added, created_by, source_receipt_id, source_line_id, source_container_id, source_sequence_id) '
			+ 'select distinct ' + convert(varchar(10),@container_company_id) + ', ' + convert(varchar(10),@container_profit_ctr_id) + ', ''' + @container_type + ''''
			+ ', ' + convert(varchar(10),@container_receipt_id) + ', ' + convert(varchar(10),@container_line_id) + ', ' + convert(varchar(10),@container_container_id)
			+ ', ' + convert(varchar(10),@new_container_sequence_id) + ', const_id, UHC, ''' + convert(varchar(30),@audit_dt,121) + ''', ''' + @user_id + ''', '
			+ case when isnull(@is_referencing_receipt_records,0) = 1 then 'null, null, null, null'
			  else 'source_receipt_id, source_line_id, source_container_id, source_sequence_id' end

	if isnull(@is_referencing_receipt_records,0) = 0
		set @sql = @sql + ' from ContainerConstituent c'
						+ ' where company_id = ' + convert(varchar(10),@container_company_id)
						+ ' and profit_ctr_id = ' + convert(varchar(10),@container_profit_ctr_id)
						+ ' and container_type = ''' + @container_type + ''''
						+ ' and receipt_id = ' + convert(varchar(10),@container_receipt_id)
						+ ' and line_id = ' + convert(varchar(10),@container_line_id)
						+ ' and container_id = ' + convert(varchar(10),@container_container_id)
						+ ' and sequence_id = ' + convert(varchar(10),@container_sequence_id)
						+ ' and uhc = (select max(uhc) from ContainerConstituent'
						+ ' where company_id = ' + convert(varchar(10),@container_company_id)
						+ ' and profit_ctr_id = ' + convert(varchar(10),@container_profit_ctr_id)
						+ ' and container_type = ''' + @container_type + ''''
						+ ' and receipt_id = ' + convert(varchar(10),@container_receipt_id)
						+ ' and line_id = ' + convert(varchar(10),@container_line_id)
						+ ' and container_id = ' + convert(varchar(10),@container_container_id)
						+ ' and sequence_id = ' + convert(varchar(10),@container_sequence_id)
						+ ' and const_id = c.const_id)'
	else
		set @sql = @sql + ' from ReceiptConstituent'
						+ ' where company_id = ' + convert(varchar(10),@container_company_id)
						+ ' and profit_ctr_id = ' + convert(varchar(10),@container_profit_ctr_id)
						+ ' and receipt_id = ' + convert(varchar(10),@container_receipt_id)
						+ ' and line_id = ' + convert(varchar(10),@container_line_id)

	if isnull(@consolidate_constituents,'') <> '(ALL)'
	begin
		if isnull(ltrim(rtrim(@consolidate_constituents)),'') = ''
			select @sql = @sql + ' and const_id = ' + convert(varchar(10),const_id)
			from Constituents (nolock)
			where const_desc = 'NONE'
		else
			set @sql = @sql + ' and const_id in (' + @consolidate_constituents + ')'
	end

	if @debug = 1 print 'sql to insert new sequence ContainerConstituent records:'
	if @debug = 1 print isnull(@sql,'null')

	execute(@sql)

	-- check for error
	select @err = @@ERROR
	if @err <> 0
	begin
		set @msg = 'Error #' + convert(varchar(10),@err) + ': inserting new sequence ContainerConstituent records'
		goto ON_ERROR
	end
end

-- remove selected constituents
if isnull(ltrim(rtrim(@remove_constituents)),'') <> ''
begin
	set @const_flag = 'T'
	set @sql = ''

	-- if referencing Receipt records and anything was marked for removal, ContainerConstituent needs to be populated
	if isnull(@is_referencing_receipt_records,0) = 1
	begin
		set @sql = 'insert ContainerConstituent (company_id, profit_ctr_id, container_type, receipt_id, line_id, container_id, sequence_id, const_id, '
				+ 'uhc, date_added, created_by) '
				+ 'select distinct company_id, profit_ctr_id, ''' + @container_type + ''', receipt_id, line_id, ' + convert(varchar(10),@container_container_id)
				+ ', ' + convert(varchar(10),@container_sequence_id) + ', const_id, uhc, ''' + convert(varchar(30),@audit_dt,121) + ''', ''' + @user_id + ''''
				+ ' from ReceiptConstituent'
				+ ' where company_id = ' + convert(varchar(10),@container_company_id)
				+ ' and profit_ctr_id = ' + convert(varchar(10),@container_profit_ctr_id)
				+ ' and receipt_id = ' + convert(varchar(10),@container_receipt_id)
				+ ' and line_id = ' + convert(varchar(10),@container_line_id)

		if @debug = 1 print 'sql to populate ContainerConstituent records from receipt:'
		if @debug = 1 print isnull(@sql,'null')

		execute(@sql)
		
		-- check for error
		select @err = @@ERROR
		if @err <> 0
		begin
			set @msg = 'Error #' + convert(varchar(10),@err) + ': deleting ContainerConstituent records'
			goto ON_ERROR
		end
	end

	-- audit
	set @sql = 'insert ContainerAudit (company_id, profit_ctr_id, container_type, receipt_id, line_id, container_id, sequence_id, column_name, before_value, after_value, date_modified, modified_by, modified_from, table_name)'
			+ ' select cc.company_id, cc.profit_ctr_id, cc.container_type, cc.receipt_id, cc.line_id, cc.container_id, cc.sequence_id, ''constituent'', c.const_desc + '' ('' + convert(varchar(10),cc.const_id) + '')'', ''(deleted)'''
			+ ', ''' + convert(varchar(30),@audit_dt,121) + ''''
			+ ', ''' + @user_id + ''''
			+ ', ''' + @modified_from + ''''
			+ ', ''ContainerConstituent'''
			+ ' from ContainerConstituent cc (nolock)'
			+ ' join Constituents c (nolock) on cc.const_id = c.const_id'
			+ ' where cc.company_id = ' + convert(varchar(10),@container_company_id)
			+ ' and cc.profit_ctr_id = ' + convert(varchar(10),@container_profit_ctr_id)
			+ ' and cc.container_type = ''' + @container_type + ''''
			+ ' and cc.receipt_id = ' + convert(varchar(10),@container_receipt_id)
			+ ' and cc.line_id = ' + convert(varchar(10),@container_line_id)
			+ ' and cc.container_id = ' + convert(varchar(10),@container_container_id)
			+ ' and cc.sequence_id = ' + convert(varchar(10),@container_sequence_id)

	if ltrim(rtrim(@remove_waste_codes)) <> '(ALL)'
		set @sql = @sql + ' and cc.const_id in (' + @remove_constituents + ')'

	if @debug = 1 print 'sql to audit removal from ContainerConstituent:'
	if @debug = 1 print isnull(@sql,'null')

	execute(@sql)
	
	-- check for error
	select @err = @@ERROR
	if @err <> 0
	begin
		set @msg = 'Error #' + convert(varchar(10),@err) + ': audit removing ContainerConstituent records'
		goto ON_ERROR
	end

	-- delete from ContainerConstituent
	set @sql = 'delete ContainerConstituent'
			+ ' where company_id = ' + convert(varchar(10),@container_company_id)
			+ ' and profit_ctr_id = ' + convert(varchar(10),@container_profit_ctr_id)
			+ ' and container_type = ''' + @container_type + ''''
			+ ' and receipt_id = ' + convert(varchar(10),@container_receipt_id)
			+ ' and line_id = ' + convert(varchar(10),@container_line_id)
			+ ' and container_id = ' + convert(varchar(10),@container_container_id)
			+ ' and sequence_id = ' + convert(varchar(10),@container_sequence_id)

	if ltrim(rtrim(@remove_constituents)) <> '(ALL)'
		set @sql = @sql + ' and const_id in (' + @remove_constituents + ')'

	if @debug = 1 print 'sql to remove ContainerConstituent records:'
	if @debug = 1 print isnull(@sql,'null')

	execute(@sql)
	
	-- check for error
	select @err = @@ERROR
	if @err <> 0
	begin
		set @msg = 'Error #' + convert(varchar(10),@err) + ': deleting ContainerConstituent records'
		goto ON_ERROR
	end

	-- if there are no constituents left on the container, insert NONE
	if not exists (select 1 from ContainerConstituent
					where company_id = @container_company_id
					and profit_ctr_id = @container_profit_ctr_id
					and container_type = @container_type
					and receipt_id = @container_receipt_id
					and line_id = @container_line_id
					and container_id = @container_container_id
					and sequence_id = @container_sequence_id)
	begin
		insert ContainerConstituent (profit_ctr_id, container_type, receipt_id, line_id, container_id, sequence_id, const_id, UHC, date_added, created_by, company_id)
		select @container_profit_ctr_id, @container_type, @container_receipt_id, @container_line_id, @container_container_id, @container_sequence_id,
				const_id, 'F', @audit_dt, @user_id, @container_company_id
		from Constituents (nolock)
		where const_desc = 'NONE'

		-- check for error
		select @err = @@ERROR
		if @err <> 0
		begin
			set @msg = 'Error #' + convert(varchar(10),@err) + ': inserting ''NONE'' into ContainerConstituent table'
			goto ON_ERROR
		end
	end
end


-- Manage more NONEs
if (isnull(@new_container_sequence_id,0) > isnull(@container_sequence_id,0) or @container_percent = @consolidate_percent)
	and not exists (select 1 from ContainerWasteCode
				where company_id = @container_company_id
				and profit_ctr_id = @container_profit_ctr_id
				and container_type = @container_type
				and receipt_id = @container_receipt_id
				and line_id = @container_line_id
				and container_id = @container_container_id
				and sequence_id = @new_container_sequence_id)
begin
	insert ContainerWasteCode (profit_ctr_id, container_type, receipt_id, line_id, container_id, sequence_id, waste_code_uid, waste_code, date_added, created_by, company_id)
	select @container_profit_ctr_id, @container_type, @container_receipt_id, @container_line_id, @container_container_id, @new_container_sequence_id,
			waste_code_uid, waste_code, @audit_dt, @user_id, @container_company_id
	from WasteCode (nolock)
	where display_name = 'NONE'

	-- check for error
	select @err = @@ERROR
	if @err <> 0
	begin
		set @msg = 'Error #' + convert(varchar(10),@err) + ': inserting ''NONE'' into ContainerWasteCode table'
		goto ON_ERROR
	end
end

if (isnull(@new_container_sequence_id,0) > isnull(@container_sequence_id,0) or @container_percent = @consolidate_percent)
	and not exists (select 1 from ContainerConstituent
				where company_id = @container_company_id
				and profit_ctr_id = @container_profit_ctr_id
				and container_type = @container_type
				and receipt_id = @container_receipt_id
				and line_id = @container_line_id
				and container_id = @container_container_id
				and sequence_id = @new_container_sequence_id)
begin
	insert ContainerConstituent (profit_ctr_id, container_type, receipt_id, line_id, container_id, sequence_id, const_id, UHC, date_added, created_by, company_id)
	select @container_profit_ctr_id, @container_type, @container_receipt_id, @container_line_id, @container_container_id, @new_container_sequence_id,
			const_id, 'F', @audit_dt, @user_id, @container_company_id
	from Constituents (nolock)
	where const_desc = 'NONE'

	-- check for error
	select @err = @@ERROR
	if @err <> 0
	begin
		set @msg = 'Error #' + convert(varchar(10),@err) + ': inserting ''NONE'' into ContainerConstituent table'
		goto ON_ERROR
	end
end

if exists (select 1 from ContainerWasteCode cwc
			join WasteCode wc on cwc.waste_code_uid = wc.waste_code_uid
			and wc.display_name <> 'NONE'
			where cwc.company_id = @base_company_id
			and cwc.profit_ctr_id = @base_profit_ctr_id
			and cwc.container_type = @base_type
			and cwc.receipt_id = @base_receipt_id
			and cwc.line_id = @base_line_id
			and cwc.container_id = @base_container_id
			and cwc.sequence_id = @base_sequence_id)
begin
	delete ContainerWasteCode
	from ContainerWasteCode cwc
	join WasteCode wc on cwc.waste_code_uid = wc.waste_code_uid
			and wc.display_name = 'NONE'
		where cwc.company_id = @base_company_id
		and cwc.profit_ctr_id = @base_profit_ctr_id
		and cwc.container_type = @base_type
		and cwc.receipt_id = @base_receipt_id
		and cwc.line_id = @base_line_id
		and cwc.container_id = @base_container_id
		and cwc.sequence_id = @base_sequence_id

	-- check for error
	select @err = @@ERROR
	if @err <> 0
	begin
		set @msg = 'Error #' + convert(varchar(10),@err) + ': deleting extraneous ''NONE'' from ContainerWasteCode table'
		goto ON_ERROR
	end
end	

if exists (select 1 from ContainerConstituent cc
			join Constituents c on cc.const_id = c.const_id
			and c.const_desc <> 'NONE'
			where cc.company_id = @base_company_id
			and cc.profit_ctr_id = @base_profit_ctr_id
			and cc.container_type = @base_type
			and cc.receipt_id = @base_receipt_id
			and cc.line_id = @base_line_id
			and cc.container_id = @base_container_id
			and cc.sequence_id = @base_sequence_id)
begin
	delete ContainerConstituent
	from ContainerConstituent cc
	join Constituents c on cc.const_id = c.const_id
		and c.const_desc = 'NONE'
	where cc.company_id = @base_company_id
	and cc.profit_ctr_id = @base_profit_ctr_id
	and cc.container_type = @base_type
	and cc.receipt_id = @base_receipt_id
	and cc.line_id = @base_line_id
	and cc.container_id = @base_container_id
	and cc.sequence_id = @base_sequence_id

	-- check for error
	select @err = @@ERROR
	if @err <> 0
	begin
		set @msg = 'Error #' + convert(varchar(10),@err) + ': deleting extraneous ''NONE'' from ContainerConstituent table'
		goto ON_ERROR
	end
end	

-- validate that all receipt waste codes and constituents are accounted for
if @container_type = 'R'
begin
	-- #1. waste code validation
	set @w_validation_ok = 0

	create table #wc_validation (
		waste_code_uid int,
		assigned_count int
	)

	if @debug = 1 print 'Validate receipt waste codes:'
/*	if @debug = 1
		select distinct waste_code_uid
		from ReceiptWasteCode rwc (nolock)
		where company_id = @container_company_id
		and profit_ctr_id = @container_profit_ctr_id
		and receipt_id = @container_receipt_id
		and line_id = @container_line_id
*/
	if @debug = 1 print 'against container waste codes:'
/*	if @debug = 1
		select distinct container_id, sequence_id
		from ContainerDestination cd (nolock)
		where company_id = @container_company_id
		and profit_ctr_id = @container_profit_ctr_id
		and receipt_id = @container_receipt_id
		and line_id = @container_line_id
		and container_type = @container_type
*/
	declare c_wc cursor read_only forward_only for
	select distinct rwc.waste_code_uid
	from ReceiptWasteCode rwc (nolock)
	join WasteCode wc (nolock)
		on rwc.waste_code_uid = wc.waste_code_uid
		and wc.display_name <> 'NONE'
	where rwc.company_id = @container_company_id
	and rwc.profit_ctr_id = @container_profit_ctr_id
	and rwc.receipt_id = @container_receipt_id
	and rwc.line_id = @container_line_id
	
	open c_wc
	fetch c_wc into @waste_code_uid
	
	while @@FETCH_STATUS = 0
	begin
		insert #wc_validation values (@waste_code_uid, 0)

		declare c_container cursor read_only forward_only for
		select distinct container_id, sequence_id
		from ContainerDestination cd (nolock)
		where company_id = @container_company_id
		and profit_ctr_id = @container_profit_ctr_id
		and receipt_id = @container_receipt_id
		and line_id = @container_line_id
		and container_type = @container_type

		open c_container
		fetch c_container into @container_id, @container_sequence_id
		
		while @@FETCH_STATUS = 0
		begin
			-- if no records exist in ContainerWasteCode for at least one container, then it inherits all ReceiptWasteCodes and all is OK
			if not exists (select 1 from ContainerWasteCode
							where company_id = @container_company_id
							and profit_ctr_id = @container_profit_ctr_id
							and receipt_id = @container_receipt_id
							and line_id = @container_line_id
							and container_type = @container_type
							and container_id = @container_id
							and sequence_id = @container_sequence_id)

				set @w_validation_ok = 1

			if exists (select 1 from ContainerWasteCode
						where company_id = @container_company_id
						and profit_ctr_id = @container_profit_ctr_id
						and receipt_id = @container_receipt_id
						and line_id = @container_line_id
						and container_type = @container_type
						and container_id = @container_id
						and sequence_id = @container_sequence_id
						and waste_code_uid = @waste_code_uid)
			begin
				update #wc_validation
				set assigned_count = ISNULL(assigned_count,0) + 1
				where waste_code_uid = @waste_code_uid
			end

			fetch c_container into @container_id, @container_sequence_id
		end
		
		close c_container
		deallocate c_container

		fetch c_wc into @waste_code_uid
	end
	
	close c_wc
	deallocate c_wc

	-- #2. constituent validation
	set @c_validation_ok = 0

	create table #const_validation (
		const_id int,
		assigned_count int
	)

	declare c_const cursor read_only forward_only for
	select distinct rc.const_id
	from ReceiptConstituent rc (nolock)
	join Constituents c (nolock)
		on rc.const_id = c.const_id
		and c.const_desc <> 'NONE'
	where rc.company_id = @container_company_id
	and rc.profit_ctr_id = @container_profit_ctr_id
	and rc.receipt_id = @container_receipt_id
	and rc.line_id = @container_line_id
	
	open c_const
	fetch c_const into @const_id
	
	while @@FETCH_STATUS = 0
	begin
		insert #const_validation values (@const_id, 0)

		declare c_container cursor read_only forward_only for
		select distinct container_id, sequence_id
		from ContainerDestination cd (nolock)
		where company_id = @container_company_id
		and profit_ctr_id = @container_profit_ctr_id
		and receipt_id = @container_receipt_id
		and line_id = @container_line_id
		and container_type = @container_type

		open c_container
		fetch c_container into @container_id, @container_sequence_id
		
		while @@FETCH_STATUS = 0
		begin
			-- if no records exist in ContainerConstituent for at least one container, then it inherits all ReceiptConstituents and all is OK
			if not exists (select 1 from ContainerConstituent
							where company_id = @container_company_id
							and profit_ctr_id = @container_profit_ctr_id
							and receipt_id = @container_receipt_id
							and line_id = @container_line_id
							and container_type = @container_type
							and container_id = @container_id
							and sequence_id = @container_sequence_id)

				set @c_validation_ok = 1

			if exists (select 1 from ContainerConstituent
						where company_id = @container_company_id
						and profit_ctr_id = @container_profit_ctr_id
						and receipt_id = @container_receipt_id
						and line_id = @container_line_id
						and container_type = @container_type
						and container_id = @container_id
						and sequence_id = @container_sequence_id
						and const_id = @const_id)
			begin
				update #const_validation
				set assigned_count = isnull(assigned_count,0) + 1
				where const_id = @const_id
			end

			fetch c_container into @container_id, @container_sequence_id
		end
		
		close c_container
		deallocate c_container

		fetch c_const into @const_id
	end
	
	close c_const
	deallocate c_const
	
	-- #3. if there are any unassigned waste codes or constituents, build an error message
	set @msg = ''
	if isnull(@w_validation_ok,0) = 0
	begin
		if exists (select 1 from #wc_validation where assigned_count = 0)
		begin
			if @debug = 1 select * from #wc_validation
			if @debug = 1 select * from ContainerWasteCode where company_id = @container_company_id and profit_ctr_id = @container_profit_ctr_id and receipt_id = @container_receipt_id and line_id = @container_line_id and container_type = @container_type

			set @msg = 'ERROR: Cannot perform consolidation.' + CHAR(13) + CHAR(10) + CHAR(13) + CHAR(10) + 'The following waste codes would be left unassigned:'
			declare c_wc_msg cursor read_only forward_only for
			select wc.display_name
			from #wc_validation #v
			join WasteCode wc on #v.waste_code_uid = wc.waste_code_uid
			where #v.assigned_count = 0
			
			open c_wc_msg
			fetch c_wc_msg into @msg_temp
			
			while @@FETCH_STATUS = 0
			begin
				if RIGHT(@msg,1) = ':'
					set @msg = @msg + CHAR(13) + CHAR(10)
				else
					set @msg = @msg + ','
				
				set @msg = @msg + @msg_temp
				
				fetch c_wc_msg into @msg_temp
			end
			
			close c_wc_msg
			deallocate c_wc_msg
		end
	end

	if isnull(@c_validation_ok,0) = 0
	begin
		if exists (select 1 from #const_validation where assigned_count = 0)
		begin
			if @debug = 1 select * from #const_validation
			if @debug = 1 select * from ContainerWasteCode where company_id = @container_company_id and profit_ctr_id = @container_profit_ctr_id and receipt_id = @container_receipt_id and line_id = @container_line_id and container_type = @container_type

			if isnull(@msg,'') = ''
				set @msg = 'ERROR: Cannot perform consolidation. The following constituents would be left unassigned:'
			else
				set @msg = @msg + CHAR(13) + CHAR(10) + CHAR(13) + CHAR(10) + 'The following constituents would be left unassigned:'
			
			declare c_const_msg cursor read_only forward_only for
			select c.const_desc
			from #const_validation #v
			join Constituents c on #v.const_id = c.const_id
			where #v.assigned_count = 0
			
			open c_const_msg
			fetch c_const_msg into @msg_temp
			
			while @@FETCH_STATUS = 0
			begin
				if RIGHT(@msg,1) = ':'
					set @msg = @msg + CHAR(13) + CHAR(10)
				else
					set @msg = @msg + ','
				
				set @msg = @msg + @msg_temp

				fetch c_const_msg into @msg_temp
			end
			
			close c_const_msg
			deallocate c_const_msg
		end
	end
	
	-- if a message was built, that means there are unassigned waste codes and/or constituents
	if isnull(@msg,'') <> ''
		goto ON_ERROR
end

-- audit...because @audit_dt was used for all additions, waste codes and constituents can be generated from single select statements
if @location_type <> 'P'
begin
	insert ContainerAudit (company_id, profit_ctr_id, container_type, receipt_id, line_id, container_id, sequence_id, column_name, before_value, after_value, date_modified, modified_by, modified_from, table_name)
	select cwc.company_id, cwc.profit_ctr_id, cwc.container_type, cwc.receipt_id, cwc.line_id, cwc.container_id, cwc.sequence_id, 'waste_code', '(inserted)', wc.display_name + ' (' + convert(varchar(10),cwc.waste_code_uid) + ')', @audit_dt, @user_id, @modified_from, 'ContainerWasteCode'
	from ContainerWasteCode cwc (nolock)
	join WasteCode wc (nolock) on cwc.waste_code_uid = wc.waste_code_uid
	where cwc.company_id = @base_company_id
	and cwc.profit_ctr_id = @base_profit_ctr_id
	and cwc.receipt_id = @base_receipt_id
	and cwc.line_id = @base_line_id
	and cwc.container_id = @base_container_id
	and cwc.sequence_id = @base_sequence_id
	and cwc.container_type = @base_type
	and cwc.date_added = @audit_dt
	and cwc.created_by = @user_id
	
	-- check for error
	select @err = @@ERROR
	if @err <> 0
	begin
		set @msg = 'Error #' + convert(varchar(10),@err) + ': inserting ContainerAudit for base ContainerWasteCode records'
		goto ON_ERROR
	end
end

insert ContainerAudit (company_id, profit_ctr_id, container_type, receipt_id, line_id, container_id, sequence_id, column_name, before_value, after_value, date_modified, modified_by, modified_from, table_name)
select cwc.company_id, cwc.profit_ctr_id, cwc.container_type, cwc.receipt_id, cwc.line_id, cwc.container_id, cwc.sequence_id, 'waste_code', '(inserted)', wc.display_name + ' (' + convert(varchar(10),cwc.waste_code_uid) + ')', @audit_dt, @user_id, @modified_from, 'ContainerWasteCode'
from ContainerWasteCode cwc (nolock)
join WasteCode wc (nolock) on cwc.waste_code_uid = wc.waste_code_uid
where cwc.company_id = @container_company_id
and cwc.profit_ctr_id = @container_profit_ctr_id
and cwc.receipt_id = @container_receipt_id
and cwc.line_id = @container_line_id
and cwc.container_id = @container_container_id
and cwc.sequence_id = @container_sequence_id
and cwc.container_type = @container_type
and cwc.date_added = @audit_dt
and cwc.created_by = @user_id

-- check for error
select @err = @@ERROR
if @err <> 0
begin
	set @msg = 'Error #' + convert(varchar(10),@err) + ': inserting ContainerAudit for container ContainerWasteCode records'
	goto ON_ERROR
end

insert ContainerAudit (company_id, profit_ctr_id, container_type, receipt_id, line_id, container_id, sequence_id, column_name, before_value, after_value, date_modified, modified_by, modified_from, table_name)
select cwc.company_id, cwc.profit_ctr_id, cwc.container_type, cwc.receipt_id, cwc.line_id, cwc.container_id, cwc.sequence_id, 'waste_code', '(inserted)', wc.display_name + ' (' + convert(varchar(10),cwc.waste_code_uid) + ')', @audit_dt, @user_id, @modified_from, 'ContainerWasteCode'
from ContainerWasteCode cwc (nolock)
join WasteCode wc (nolock) on cwc.waste_code_uid = wc.waste_code_uid
where cwc.company_id = @container_company_id
and cwc.profit_ctr_id = @container_profit_ctr_id
and cwc.receipt_id = @container_receipt_id
and cwc.line_id = @container_line_id
and cwc.container_id = @container_container_id
and cwc.sequence_id = isnull(@new_container_sequence_id,0)
and cwc.container_type = @container_type
and cwc.date_added = @audit_dt
and cwc.created_by = @user_id

-- check for error
select @err = @@ERROR
if @err <> 0
begin
	set @msg = 'Error #' + convert(varchar(10),@err) + ': inserting ContainerAudit for container new sequence ContainerWasteCode records'
	goto ON_ERROR
end

if @location_type <> 'P'
begin
	insert ContainerAudit (company_id, profit_ctr_id, container_type, receipt_id, line_id, container_id, sequence_id, column_name, before_value, after_value, date_modified, modified_by, modified_from, table_name)
	select cc.company_id, cc.profit_ctr_id, cc.container_type, cc.receipt_id, cc.line_id, cc.container_id, cc.sequence_id, 'constituent', '(inserted)', c.const_desc + ' (' + convert(varchar(10),cc.const_id) + ')', @audit_dt, @user_id, @modified_from, 'ContainerConstituent'
	from ContainerConstituent cc (nolock)
	join Constituents c (nolock) on cc.const_id = c.const_id
	where cc.company_id = @base_company_id
	and cc.profit_ctr_id = @base_profit_ctr_id
	and cc.receipt_id = @base_receipt_id
	and cc.line_id = @base_line_id
	and cc.container_id = @base_container_id
	and cc.sequence_id = @base_sequence_id
	and cc.container_type = @base_type
	and cc.date_added = @audit_dt
	and cc.created_by = @user_id

	-- check for error
	select @err = @@ERROR
	if @err <> 0
	begin
		set @msg = 'Error #' + convert(varchar(10),@err) + ': inserting ContainerAudit for base ContainerConstituent records'
		goto ON_ERROR
	end
end

insert ContainerAudit (company_id, profit_ctr_id, container_type, receipt_id, line_id, container_id, sequence_id, column_name, before_value, after_value, date_modified, modified_by, modified_from, table_name)
select cc.company_id, cc.profit_ctr_id, cc.container_type, cc.receipt_id, cc.line_id, cc.container_id, cc.sequence_id, 'constituent', '(inserted)', c.const_desc + ' (' + convert(varchar(10),cc.const_id) + ')', @audit_dt, @user_id, @modified_from, 'ContainerConstituent'
from ContainerConstituent cc (nolock)
join Constituents c (nolock) on cc.const_id = c.const_id
where cc.company_id = @container_company_id
and cc.profit_ctr_id = @container_profit_ctr_id
and cc.receipt_id = @container_receipt_id
and cc.line_id = @container_line_id
and cc.container_id = @container_container_id
and cc.sequence_id = @container_sequence_id
and cc.container_type = @container_type
and cc.date_added = @audit_dt
and cc.created_by = @user_id

-- check for error
select @err = @@ERROR
if @err <> 0
begin
	set @msg = 'Error #' + convert(varchar(10),@err) + ': inserting ContainerAudit for container ContainerConstituent records'
	goto ON_ERROR
end

insert ContainerAudit (company_id, profit_ctr_id, container_type, receipt_id, line_id, container_id, sequence_id, column_name, before_value, after_value, date_modified, modified_by, modified_from, table_name)
select cc.company_id, cc.profit_ctr_id, cc.container_type, cc.receipt_id, cc.line_id, cc.container_id, cc.sequence_id, 'constituent', '(inserted)', c.const_desc + ' (' + convert(varchar(10),cc.const_id) + ')', @audit_dt, @user_id, @modified_from, 'ContainerConstituent'
from ContainerConstituent cc (nolock)
join Constituents c (nolock) on cc.const_id = c.const_id
where cc.company_id = @container_company_id
and cc.profit_ctr_id = @container_profit_ctr_id
and cc.receipt_id = @container_receipt_id
and cc.line_id = @container_line_id
and cc.container_id = @container_container_id
and cc.sequence_id = isnull(@new_container_sequence_id,0)
and cc.container_type = @container_type
and cc.date_added = @audit_dt
and cc.created_by = @user_id

-- check for error
select @err = @@ERROR
if @err <> 0
begin
	set @msg = 'Error #' + convert(varchar(10),@err) + ': inserting ContainerAudit for container new sequence ContainerConstituent records'
	goto ON_ERROR
end

------------------------------------
-- SUCCESS
if @debug = 1 print 'SUCCESS'

if @@TRANCOUNT > @initial_tran_count
	commit transaction
return 0

-------------------------------------
-- ERROR
ON_ERROR:
if @debug = 1 print 'ON_ERROR:'
if @debug = 1 print isnull(@msg,'null')

if @@TRANCOUNT > @initial_tran_count
	rollback transaction

raiserror(@msg,16,1)
return -1
-------------------------------------

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_consolidate_container] TO [EQAI]
    AS [dbo];

