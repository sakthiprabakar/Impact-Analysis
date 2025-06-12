
create procedure sp_ax_sync_customer_update
	@ax_customer_id varchar(20),
	@customer_group char(1),
	@customer_name varchar(100),
	@physical_address_1 varchar(40),
	@physical_address_2 varchar(40),
	@physical_address_3 varchar(40),
	@physical_address_4 varchar(40),
	@physical_city varchar(60),
	@physical_state varchar(10),
	@physical_zip_code varchar(10),
	@physical_country varchar(10),
	@billing_name varchar(60),
	@billing_address_1 varchar(40),
	@billing_address_2 varchar(40),
	@billing_address_3 varchar(40),
	@billing_address_4 varchar(40),
	@billing_city varchar(60),
	@billing_state varchar(10),
	@billing_zip_code varchar(10),
	@billing_country varchar(10),
	@phone_number varchar(255),
	@fax_number varchar(255),
	@credit_limit numeric(32,16),
	@terms_code varchar(10),
	@naics_code varchar(10),
	@naics_desc varchar(255),
	@customer_type varchar(20),
	@customer_website varchar(255),
	@invoice_customer_id varchar(20),
	@sub_customers varchar(max),
	@hold_status int
as

declare @error_msg varchar(255),
		@sql varchar(max),
		@curr_status char(1),
		@curr_term varchar(10),
		@before varchar(10),
		@after varchar(10),
		@prior_term varchar(10)

begin transaction

if exists (select 1 from Customer where ax_customer_id = @ax_customer_id)
begin
	if coalesce(@customer_type,'') <> ''
		and not exists (select 1 from CustomerType where customer_type = @customer_type)
	begin
		insert CustomerType (customer_type, added_by, date_added, modified_by, date_modified)
		values (@customer_type, 'AX', getdate(), 'AX', getdate())


		if @@ERROR <> 0
		begin
			set @error_msg = 'ERROR: Could not insert into CustomerType for AX Customer: ' + @ax_customer_id
			goto ON_ERROR
		end

		update CustomerType
		set JDE_customer_type = right('00' + convert(varchar(10),customertype_uid),3)
		where customer_type = @customer_type

		if @@ERROR <> 0
		begin
			set @error_msg = 'ERROR: Could not update CustomerType for AX Customer: ' + @ax_customer_id
			goto ON_ERROR
		end
	end

	select *
	into #c
	from Customer
	where ax_customer_id = @ax_customer_id

	if @@ERROR <> 0
	begin
		set @error_msg = 'ERROR: Could not create temp table of original values for AX customer: ' + @ax_customer_id
		goto ON_ERROR
	end

	select @curr_status = isnull(cust_status,'I'),
			@curr_term = isnull(terms_code,'')
	from Customer
	where ax_customer_ID = @ax_customer_id

	if @hold_status not in (1,2) and @curr_status = 'A' and @curr_term = 'NOADMIT'
	begin
		select @before = ca.before_value,
			@after = ca.after_value
		from CustomerAudit ca
		join #c
			on #c.customer_id = ca.customer_id
		where ca.column_name = 'terms_code'
		and ca.date_modified = (select max(date_modified)
								from CustomerAudit
								where customer_id = ca.customer_id
								and column_name = ca.column_name
								and date_modified < getdate())
		if @@ERROR <> 0
		begin
			set @error_msg = 'ERROR: Could not query CustomerAudit for AX customer: ' + @ax_customer_id
			goto ON_ERROR
		end

		set @prior_term = nullif(ltrim(rtrim(@after)),'')
		if isnull(@prior_term,'NOADMIT') = 'NOADMIT'
			set @prior_term = nullif(ltrim(rtrim(@before)),'')
		if isnull(@prior_term,'NOADMIT') = 'NOADMIT'
			set @prior_term = 'N30'
	end

	update Customer
	set eq_flag = @customer_group,
		cust_name = left(ltrim(@customer_name),40),
		cust_addr1 = @physical_address_1,
		cust_addr2 = @physical_address_2,
		cust_addr3 = @physical_address_3,
		cust_addr4 = @physical_address_4,
		cust_addr5 = null,
		cust_city = @physical_city,
		cust_state = @physical_state,
		cust_zip_code = @physical_zip_code,
		cust_country = @physical_country,
		cust_phone = @phone_number,
		cust_fax = @fax_number,
		credit_limit = @credit_limit,
		cust_naics_code = @naics_code,
		customer_type = @customer_type,
		cust_website = @customer_website,
		terms_code = case when @hold_status in (1,2) then 'NOADMIT'
						when isnull(@prior_term,'') <> '' then @prior_term
						else terms_code end,
		ax_invoice_customer_id = @invoice_customer_id,
		modified_by = 'AX',
		date_modified = getdate()
	where ax_customer_id = @ax_customer_id

	if @@ERROR <> 0
	begin
		set @error_msg = 'ERROR: Error occurred when updating the Customer table for AX customer: ' + @ax_customer_id
		goto ON_ERROR
	end

	-- Audits
	insert CustomerAudit
	select c.customer_id, 'Customer', 'eq_flag', #c.eq_flag, c.eq_flag, 'AX Customer Sync', 'AX', 'AX', getdate(), NEWID()
	from Customer c
	join #c
		on #c.customer_id = c.customer_id
		and isnull(#c.eq_flag,'') <> isnull(c.eq_flag,'')

	if @@ERROR <> 0
	begin
		set @error_msg = 'ERROR: Error occurred when inserting eq_flag CustomerAudit record for AX customer: ' + @ax_customer_id
		goto ON_ERROR
	end

	insert CustomerAudit
	select c.customer_id, 'Customer', 'cust_name', #c.cust_name, c.cust_name, 'AX Customer Sync', 'AX', 'AX', getdate(), NEWID()
	from Customer c
	join #c
		on #c.customer_id = c.customer_id
		and isnull(#c.cust_name,'') <> isnull(c.cust_name,'')

	if @@ERROR <> 0
	begin
		set @error_msg = 'ERROR: Error occurred when inserting cust_name CustomerAudit record for AX customer: ' + @ax_customer_id
		goto ON_ERROR
	end

	insert CustomerAudit
	select c.customer_id, 'Customer', 'cust_addr1', #c.cust_addr1, c.cust_addr1, 'AX Customer Sync', 'AX', 'AX', getdate(), NEWID()
	from Customer c
	join #c
		on #c.customer_id = c.customer_id
		and isnull(#c.cust_addr1,'') <> isnull(c.cust_addr1,'')

	if @@ERROR <> 0
	begin
		set @error_msg = 'ERROR: Error occurred when inserting cust_addr1 CustomerAudit record for AX customer: ' + @ax_customer_id
		goto ON_ERROR
	end

	insert CustomerAudit
	select c.customer_id, 'Customer', 'cust_addr2', #c.cust_addr2, c.cust_addr2, 'AX Customer Sync', 'AX', 'AX', getdate(), NEWID()
	from Customer c
	join #c
		on #c.customer_id = c.customer_id
		and isnull(#c.cust_addr2,'') <> isnull(c.cust_addr2,'')

	if @@ERROR <> 0
	begin
		set @error_msg = 'ERROR: Error occurred when inserting cust_addr2 CustomerAudit record for AX customer: ' + @ax_customer_id
		goto ON_ERROR
	end

	insert CustomerAudit
	select c.customer_id, 'Customer', 'cust_addr3', #c.cust_addr3, c.cust_addr3, 'AX Customer Sync', 'AX', 'AX', getdate(), NEWID()
	from Customer c
	join #c
		on #c.customer_id = c.customer_id
		and isnull(#c.cust_addr3,'') <> isnull(c.cust_addr3,'')

	if @@ERROR <> 0
	begin
		set @error_msg = 'ERROR: Error occurred when inserting cust_addr3 CustomerAudit record for AX customer: ' + @ax_customer_id
		goto ON_ERROR
	end

	insert CustomerAudit
	select c.customer_id, 'Customer', 'cust_addr4', #c.cust_addr4, c.cust_addr4, 'AX Customer Sync', 'AX', 'AX', getdate(), NEWID()
	from Customer c
	join #c
		on #c.customer_id = c.customer_id
		and isnull(#c.cust_addr4,'') <> isnull(c.cust_addr4,'')

	if @@ERROR <> 0
	begin
		set @error_msg = 'ERROR: Error occurred when inserting cust_addr4 CustomerAudit record for AX customer: ' + @ax_customer_id
		goto ON_ERROR
	end

	insert CustomerAudit
	select c.customer_id, 'Customer', 'cust_addr5', #c.cust_addr5, c.cust_addr5, 'AX Customer Sync', 'AX', 'AX', getdate(), NEWID()
	from Customer c
	join #c
		on #c.customer_id = c.customer_id
		and isnull(#c.cust_addr5,'') <> isnull(c.cust_addr5,'')

	if @@ERROR <> 0
	begin
		set @error_msg = 'ERROR: Error occurred when inserting cust_addr5 CustomerAudit record for AX customer: ' + @ax_customer_id
		goto ON_ERROR
	end

	insert CustomerAudit
	select c.customer_id, 'Customer', 'cust_city', #c.cust_city, c.cust_city, 'AX Customer Sync', 'AX', 'AX', getdate(), NEWID()
	from Customer c
	join #c
		on #c.customer_id = c.customer_id
		and isnull(#c.cust_city,'') <> isnull(c.cust_city,'')

	if @@ERROR <> 0
	begin
		set @error_msg = 'ERROR: Error occurred when inserting cust_city CustomerAudit record for AX customer: ' + @ax_customer_id
		goto ON_ERROR
	end

	insert CustomerAudit
	select c.customer_id, 'Customer', 'cust_state', #c.cust_state, c.cust_state, 'AX Customer Sync', 'AX', 'AX', getdate(), NEWID()
	from Customer c
	join #c
		on #c.customer_id = c.customer_id
		and isnull(#c.cust_state,'') <> isnull(c.cust_state,'')

	if @@ERROR <> 0
	begin
		set @error_msg = 'ERROR: Error occurred when inserting cust_state CustomerAudit record for AX customer: ' + @ax_customer_id
		goto ON_ERROR
	end

	insert CustomerAudit
	select c.customer_id, 'Customer', 'cust_zip_code', #c.cust_zip_code, c.cust_zip_code, 'AX Customer Sync', 'AX', 'AX', getdate(), NEWID()
	from Customer c
	join #c
		on #c.customer_id = c.customer_id
		and isnull(#c.cust_zip_code,'') <> isnull(c.cust_zip_code,'')

	if @@ERROR <> 0
	begin
		set @error_msg = 'ERROR: Error occurred when inserting cust_zip_code CustomerAudit record for AX customer: ' + @ax_customer_id
		goto ON_ERROR
	end

	insert CustomerAudit
	select c.customer_id, 'Customer', 'cust_country', #c.cust_country, c.cust_country, 'AX Customer Sync', 'AX', 'AX', getdate(), NEWID()
	from Customer c
	join #c
		on #c.customer_id = c.customer_id
		and isnull(#c.cust_country,'') <> isnull(c.cust_country,'')

	if @@ERROR <> 0
	begin
		set @error_msg = 'ERROR: Error occurred when inserting cust_country CustomerAudit record for AX customer: ' + @ax_customer_id
		goto ON_ERROR
	end

	insert CustomerAudit
	select c.customer_id, 'Customer', 'cust_phone', #c.cust_phone, c.cust_phone, 'AX Customer Sync', 'AX', 'AX', getdate(), NEWID()
	from Customer c
	join #c
		on #c.customer_id = c.customer_id
		and isnull(#c.cust_phone,'') <> isnull(c.cust_phone,'')

	if @@ERROR <> 0
	begin
		set @error_msg = 'ERROR: Error occurred when inserting cust_phone CustomerAudit record for AX customer: ' + @ax_customer_id
		goto ON_ERROR
	end

	insert CustomerAudit
	select c.customer_id, 'Customer', 'cust_fax', #c.cust_fax, c.cust_fax, 'AX Customer Sync', 'AX', 'AX', getdate(), NEWID()
	from Customer c
	join #c
		on #c.customer_id = c.customer_id
		and isnull(#c.cust_fax,'') <> isnull(c.cust_fax,'')

	if @@ERROR <> 0
	begin
		set @error_msg = 'ERROR: Error occurred when inserting cust_fax CustomerAudit record for AX customer: ' + @ax_customer_id
		goto ON_ERROR
	end

	insert CustomerAudit
	select c.customer_id, 'Customer', 'credit_limit', convert(varchar(15),#c.credit_limit), convert(varchar(15),c.credit_limit), 'AX Customer Sync', 'AX', 'AX', getdate(), NEWID()
	from Customer c
	join #c
		on #c.customer_id = c.customer_id
		and isnull(#c.credit_limit,0) <> isnull(c.credit_limit,0)

	if @@ERROR <> 0
	begin
		set @error_msg = 'ERROR: Error occurred when inserting credit_limit CustomerAudit record for AX customer: ' + @ax_customer_id
		goto ON_ERROR
	end

	insert CustomerAudit
	select c.customer_id, 'Customer', 'cust_naics_code', #c.cust_naics_code, c.cust_naics_code, 'AX Customer Sync', 'AX', 'AX', getdate(), NEWID()
	from Customer c
	join #c
		on #c.customer_id = c.customer_id
		and isnull(#c.cust_naics_code,'') <> isnull(c.cust_naics_code,'')

	if @@ERROR <> 0
	begin
		set @error_msg = 'ERROR: Error occurred when inserting cust_naics_code CustomerAudit record for AX customer: ' + @ax_customer_id
		goto ON_ERROR
	end

	insert CustomerAudit
	select c.customer_id, 'Customer', 'customer_type', #c.customer_type, c.customer_type, 'AX Customer Sync', 'AX', 'AX', getdate(), NEWID()
	from Customer c
	join #c
		on #c.customer_id = c.customer_id
		and isnull(#c.customer_type,'') <> isnull(c.customer_type,'')

	if @@ERROR <> 0
	begin
		set @error_msg = 'ERROR: Error occurred when inserting customer_type CustomerAudit record for AX customer: ' + @ax_customer_id
		goto ON_ERROR
	end

	insert CustomerAudit
	select c.customer_id, 'Customer', 'cust_website', #c.cust_website, c.cust_website, 'AX Customer Sync', 'AX', 'AX', getdate(), NEWID()
	from Customer c
	join #c
		on #c.customer_id = c.customer_id
		and isnull(#c.cust_website,'') <> isnull(c.cust_website,'')

	if @@ERROR <> 0
	begin
		set @error_msg = 'ERROR: Error occurred when inserting cust_website CustomerAudit record for AX customer: ' + @ax_customer_id
		goto ON_ERROR
	end

	insert CustomerAudit
	select c.customer_id, 'Customer', 'terms_code', #c.terms_code, c.terms_code, 'AX Customer Sync', 'AX', 'AX', getdate(), NEWID()
	from Customer c
	join #c
		on #c.customer_id = c.customer_id
		and isnull(#c.terms_code,'') <> isnull(c.terms_code,'')

	if @@ERROR <> 0
	begin
		set @error_msg = 'ERROR: Error occurred when inserting cust_website CustomerAudit record for AX customer: ' + @ax_customer_id
		goto ON_ERROR
	end

	insert CustomerAudit
	select c.customer_id, 'Customer', 'ax_invoice_customer_id', #c.ax_invoice_customer_id, c.ax_invoice_customer_id, 'AX Customer Sync', 'AX', 'AX', getdate(), NEWID()
	from Customer c
	join #c
		on #c.customer_id = c.customer_id
		and isnull(#c.ax_invoice_customer_id,'') <> isnull(c.ax_invoice_customer_id,'')

	if @@ERROR <> 0
	begin
		set @error_msg = 'ERROR: Error occurred when inserting ax_invoice_customer_id CustomerAudit record for AX customer: ' + @ax_customer_id
		goto ON_ERROR
	end
end

if @sub_customers is not null and DATALENGTH(@sub_customers) > 0
begin
	select * into #cs from Customer where 1=0
	set @sql = 'insert #cs select * from Customer where ax_customer_id in (' + @sub_customers + ')'
	exec (@sql)

	if @@ERROR <> 0
	begin
		set @error_msg = 'ERROR: Could not create temp table of original sub-customer values for AX customer: ' + @ax_customer_id
		goto ON_ERROR
	end

	set @sql = 'update Customer'
	+ ' set bill_to_cust_name = ''' + left(ltrim(isnull(replace(@billing_name,'''',''''''),'')),40) + ''','
	+ '	bill_to_addr1 = ''' + isnull(replace(@billing_address_1,'''',''''''),'') + ''','
	+ '	bill_to_addr2 = ''' + isnull(replace(@billing_address_2,'''',''''''),'') + ''','
	+ '	bill_to_addr3 = ''' + isnull(replace(@billing_address_3,'''',''''''),'') + ''','
	+ '	bill_to_addr4 = ''' + isnull(replace(@billing_address_4,'''',''''''),'') + ''','
	+ '	bill_to_addr5 = null,'
	+ '	bill_to_city = ''' + isnull(replace(@billing_city,'''',''''''),'') + ''','
	+ '	bill_to_state = ''' + isnull(replace(@billing_state,'''',''''''),'') + ''','
	+ '	bill_to_zip_code = ''' + isnull(replace(@billing_zip_code,'''',''''''),'') + ''','
	+ '	bill_to_country = ''' + isnull(replace(@billing_country,'''',''''''),'') + ''','
	+ '	modified_by = ''AX'','
	+ '	date_modified = getdate()'
	+ ' where ax_customer_id in (' + @sub_customers + ')'

	exec(@sql)

	if @@ERROR <> 0
	begin
		set @error_msg = 'ERROR: Could not update invoice address for sub-customers of AX customer: ' + @ax_customer_id
		goto ON_ERROR
	end

	--Audits
	insert CustomerAudit
	select c.customer_id, 'Customer', 'bill_to_cust_name', #cs.bill_to_cust_name, c.bill_to_cust_name, 'AX Customer Sync', 'AX', 'AX', getdate(), NEWID()
	from Customer c
	join #cs
		on #cs.customer_id = c.customer_id
		and isnull(#cs.bill_to_cust_name,'') <> isnull(c.bill_to_cust_name,'')

	if @@ERROR <> 0
	begin
		set @error_msg = 'ERROR: Error occurred when inserting sub-customer bill_to_cust_name CustomerAudit record for AX customer: ' + @ax_customer_id
		goto ON_ERROR
	end

	insert CustomerAudit
	select c.customer_id, 'Customer', 'bill_to_addr1', #cs.bill_to_addr1, c.bill_to_addr1, 'AX Customer Sync', 'AX', 'AX', getdate(), NEWID()
	from Customer c
	join #cs
		on #cs.customer_id = c.customer_id
		and isnull(#cs.bill_to_addr1,'') <> isnull(c.bill_to_addr1,'')

	if @@ERROR <> 0
	begin
		set @error_msg = 'ERROR: Error occurred when inserting sub-customer bill_to_addr1 CustomerAudit record for AX customer: ' + @ax_customer_id
		goto ON_ERROR
	end

	insert CustomerAudit
	select c.customer_id, 'Customer', 'bill_to_addr2', #cs.bill_to_addr2, c.bill_to_addr2, 'AX Customer Sync', 'AX', 'AX', getdate(), NEWID()
	from Customer c
	join #cs
		on #cs.customer_id = c.customer_id
		and isnull(#cs.bill_to_addr2,'') <> isnull(c.bill_to_addr2,'')

	if @@ERROR <> 0
	begin
		set @error_msg = 'ERROR: Error occurred when inserting sub-customer bill_to_addr2 CustomerAudit record for AX customer: ' + @ax_customer_id
		goto ON_ERROR
	end

	insert CustomerAudit
	select c.customer_id, 'Customer', 'bill_to_addr3', #cs.bill_to_addr3, c.bill_to_addr3, 'AX Customer Sync', 'AX', 'AX', getdate(), NEWID()
	from Customer c
	join #cs
		on #cs.customer_id = c.customer_id
		and isnull(#cs.bill_to_addr3,'') <> isnull(c.bill_to_addr3,'')

	if @@ERROR <> 0
	begin
		set @error_msg = 'ERROR: Error occurred when inserting sub-customer bill_to_addr3 CustomerAudit record for AX customer: ' + @ax_customer_id
		goto ON_ERROR
	end

	insert CustomerAudit
	select c.customer_id, 'Customer', 'bill_to_addr4', #cs.bill_to_addr4, c.bill_to_addr4, 'AX Customer Sync', 'AX', 'AX', getdate(), NEWID()
	from Customer c
	join #cs
		on #cs.customer_id = c.customer_id
		and isnull(#cs.bill_to_addr4,'') <> isnull(c.bill_to_addr4,'')

	if @@ERROR <> 0
	begin
		set @error_msg = 'ERROR: Error occurred when inserting sub-customer bill_to_addr4 CustomerAudit record for AX customer: ' + @ax_customer_id
		goto ON_ERROR
	end

	insert CustomerAudit
	select c.customer_id, 'Customer', 'bill_to_addr5', #cs.bill_to_addr5, c.bill_to_addr5, 'AX Customer Sync', 'AX', 'AX', getdate(), NEWID()
	from Customer c
	join #cs
		on #cs.customer_id = c.customer_id
		and isnull(#cs.bill_to_addr5,'') <> isnull(c.bill_to_addr5,'')

	if @@ERROR <> 0
	begin
		set @error_msg = 'ERROR: Error occurred when inserting sub-customer bill_to_addr5 CustomerAudit record for AX customer: ' + @ax_customer_id
		goto ON_ERROR
	end

	insert CustomerAudit
	select c.customer_id, 'Customer', 'bill_to_city', #cs.bill_to_city, c.bill_to_city, 'AX Customer Sync', 'AX', 'AX', getdate(), NEWID()
	from Customer c
	join #cs
		on #cs.customer_id = c.customer_id
		and isnull(#cs.bill_to_city,'') <> isnull(c.bill_to_city,'')

	if @@ERROR <> 0
	begin
		set @error_msg = 'ERROR: Error occurred when inserting sub-customer bill_to_city CustomerAudit record for AX customer: ' + @ax_customer_id
		goto ON_ERROR
	end

	insert CustomerAudit
	select c.customer_id, 'Customer', 'bill_to_state', #cs.bill_to_state, c.bill_to_state, 'AX Customer Sync', 'AX', 'AX', getdate(), NEWID()
	from Customer c
	join #cs
		on #cs.customer_id = c.customer_id
		and isnull(#cs.bill_to_state,'') <> isnull(c.bill_to_state,'')

	if @@ERROR <> 0
	begin
		set @error_msg = 'ERROR: Error occurred when inserting sub-customer bill_to_state CustomerAudit record for AX customer: ' + @ax_customer_id
		goto ON_ERROR
	end

	insert CustomerAudit
	select c.customer_id, 'Customer', 'bill_to_zip_code', #cs.bill_to_zip_code, c.bill_to_zip_code, 'AX Customer Sync', 'AX', 'AX', getdate(), NEWID()
	from Customer c
	join #cs
		on #cs.customer_id = c.customer_id
		and isnull(#cs.bill_to_zip_code,'') <> isnull(c.bill_to_zip_code,'')

	if @@ERROR <> 0
	begin
		set @error_msg = 'ERROR: Error occurred when inserting sub-customer bill_to_zip_code CustomerAudit record for AX customer: ' + @ax_customer_id
		goto ON_ERROR
	end

	insert CustomerAudit
	select c.customer_id, 'Customer', 'bill_to_country', #cs.bill_to_country, c.bill_to_country, 'AX Customer Sync', 'AX', 'AX', getdate(), NEWID()
	from Customer c
	join #cs
		on #cs.customer_id = c.customer_id
		and isnull(#cs.bill_to_country,'') <> isnull(c.bill_to_country,'')

	if @@ERROR <> 0
	begin
		set @error_msg = 'ERROR: Error occurred when inserting sub-customer bill_to_country CustomerAudit record for AX customer: ' + @ax_customer_id
		goto ON_ERROR
	end
end

-----------
ON_SUCCESS:
-----------
commit transaction
return 0

------------
ON_ERROR:
------------
rollback transaction

raiserror(@error_msg,16,1)
return -1

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_ax_sync_customer_update] TO [AX_SERVICE]
    AS [dbo];


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_ax_sync_customer_update] TO [EQAI]
    AS [dbo];

