
/***************************************************************************************
retrieves customer and related eq company info

09/15/2003 jpb	created
test cmd line: spw_getcustomers_audits_by_customer 1, 10, 2222, 'data'
****************************************************************************************/
create procedure spw_getcustomers_audits_by_customer
	@page int,
	@recsperpage int,
	@customer_ID	int,
	@mode	varchar(15)
as

	set nocount on
	--create a temporary table
	create table #tempitems
	(
		noteautoID int IDentity,
		customer_ID	int,
	)
	
	-- insert the rows from the real table into the temp. table
	declare @searchsql varchar(5000)
	insert #tempitems (customer_ID) 
		exec spw_parent_getchildren_IDs @customer_ID, 0
	
	
	-- find out the first and last record we want
	declare @firstrec int, @lastrec int
	select @firstrec = (@page - 1) * @recsperpage
	select @lastrec = (@page * @recsperpage + 1)
	
	-- turn nocount back off
	set nocount off
	
	if @mode = 'data'
	begin
		select @searchsql = 'select
		customer.customer_ID, customer.cust_name, customer.purchase_order, customer.release_code, customer.customer_type, customer.cert_flag, customer.cust_addr1, customer.cust_addr2, customer.cust_addr3, customer.cust_addr4, customer.cust_addr5, customer.cust_city, customer.cust_state, customer.cust_zip_code, customer.cust_country, customer.cust_sic_code, customer.cust_phone, customer.cust_fax, customer.mail_flag, customer.cust_directions, customer.invoice_flag, customer.terms_code, customer.added_by, customer.modified_by, customer.date_added, customer.date_modified, customer.insurance_surcharge_flag, customer.designation, customer.generator_flag, customer.web_access_flag, customer.next_WCR, customer.cust_category, customer.cust_website, customer.cust_parent_ID, customer.cust_prospect_flag,
		customernote.customer_id, customernote.note_ID, customernote.note, customernote.contact_date, customernote.note_type, customernote.added_from_company, customernote.modified_by, customernote.date_added, customernote.date_modified, customernote.contact_ID, customernote.status, customernote.added_by, customernote.subject, customernote.recipient, customernote.send_email_date, customernote.cc_list, customernote.note_group_ID, customernote.action_type, customernote.contact_type
		from #tempitems t (nolock), customer 
		left outer join customernote
			on customer.customer_ID = customernote.customer_ID
			and (customernote.note_type is null or customernote.note_type = ''audit'')
			and (customernote.contact_type is null or customernote.contact_type = ''audit'')
		where customer.customer_ID = t.customer_ID
		and noteautoID > ' + convert(varchar(10), @firstrec) + ' and noteautoID < ' + convert(varchar(10), @lastrec) + ' 
		order by t.noteautoID, customernote.contact_date desc
		for xml auto '
		execute(@searchsql)
	end
	if @mode = 'date-added'
	begin
		select max(customer.date_added)
		from #tempitems t (nolock), customer
		where customer.customer_ID = t.customer_ID
		and noteautoID > @firstrec and noteautoID < @lastrec
	end
	if @mode = 'count'
	begin
		select count(*) from #tempitems
	end


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[spw_getcustomers_audits_by_customer] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[spw_getcustomers_audits_by_customer] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[spw_getcustomers_audits_by_customer] TO [EQAI]
    AS [dbo];

