/***************************************************************************************
Returns notes by Customer or Contact ID, with filters.

09/15/2003 JPB	Created
11/15/2004 JPB  Changed CustomerContact -> Contact

Test Cmd Line: spw_getnotes 1, 10, NULL, 2222, NULL, '', '', '', '', '', '', '', '', 'F', 'customernote.contact_date desc', 'data'
****************************************************************************************/
create procedure spw_getnotes
	@page int,
	@recsperpage int,
	@parent_ID	int,
	@customer_ID	int,
	@contact_ID	int,
	@note_type	varchar(15),
	@date_start	varchar(25),
	@date_stop	varchar(25),
	@status	varchar(30),
	@note_ID	int,
	@recipient	varchar(30),
	@cc	varchar(30),
	@action_type varchar(20),
	@audit	char(1),
	@orderby varchar(100),
	@mode	varchar(15)
as
	
	set nocount on
	
	if @customer_ID is not null
	begin
		--create a temporary table for companies
		create table #tempcompanies
		(
			customer_ID	int
		)
		
		-- fill it with this company's children id's (includes self)
		insert #tempcompanies (customer_ID) 
			exec spw_parent_getchildren_IDs @customer_ID, 0
	end
	
	--create a temporary table
	create table #tempitems
	(
		noteautoid int identity,
		note_ID	int,
	)
	
	-- insert the rows from the real table into the temp. table
	declare @searchsql varchar(5000)
	select @searchsql = 'insert into #tempitems (note_ID) 
		select customernote.note_ID
		from customernote, customerxcontact, customer 
		where 1=1 '
	
	if @customer_ID is not null
		select @searchsql = @searchsql +
		'and customer.customer_ID in (select customer_ID from #tempcompanies)
		 and customernote.customer_ID = customer.customer_ID 
		 and customernote.contact_ID *= customerxcontact.contact_ID '
	else if @contact_ID is not null
		select @searchsql = @searchsql +
		'and customerxcontact.contact_ID = ' + convert(varchar(10), @contact_ID) + ' 
		 and customernote.customer_ID = customer.customer_ID 
		 and customernote.contact_ID = customerxcontact.contact_ID '
	
	if len(ltrim(rtrim(@note_type))) > 0
	begin
		select @searchsql = @searchsql +
		'and (customernote.note_type = ''' + @note_type + ''' '
	
		if @audit = 't'
			select @searchsql = @searchsql +
			'or customernote.note_type = ''audit'' '
	
		select @searchsql = @searchsql +
		') '
	end
	
	if @audit != 't'
		select @searchsql = @searchsql + ' and customernote.note_type <> ''audit'' '
	
	if len(ltrim(rtrim(@status))) > 0
		select @searchsql = @searchsql + ' and customernote.status in (' + @status + ') '
	
	if @note_ID > 0
		select @searchsql = @searchsql + ' and customernote.note_ID = ' + convert(varchar(10), @note_ID) + ' '
	
	if len(ltrim(rtrim(@recipient))) > 0
		select @searchsql = @searchsql + ' and customernote.recipient like ''%' + @recipient + '%'' '
	
	if len(ltrim(rtrim(@cc))) > 0
		select @searchsql = @searchsql + ' and customernote.cc_list like ''%' + @cc + '%'' '
	
	if len(ltrim(rtrim(@action_type))) > 0
		if @action_type = 'any'
			select @searchsql = @searchsql + ' and customernote.action_type is not null '
		else
			select @searchsql = @searchsql + ' and customernote.action_type = ''' + @action_type + ''' '
	
	select @searchsql = @searchsql +
		' and customernote.contact_date >= ''' + @date_start + ''' 
		 and customernote.contact_date <= ''' + @date_stop + ''' '
	
	select @searchsql = @searchsql +
		'order by ' + @orderby + ' '
	
	
	-- print @searchsql
	execute(@searchsql)
	
	-- find out the first and last record we want
	declare @firstrec int, @lastrec int
	select @firstrec = (@page - 1) * @recsperpage
	select @lastrec = (@page * @recsperpage + 1)
	
	-- turn nocount back off
	set nocount off
	
	if @mode = 'data'
	begin
		select @searchsql = 'select 
			customer.customer_ID, customer.cust_name, 
			contact.contact_ID, contact.name, 
			customernote.customer_id, customernote.note_ID, customernote.note,customernote.contact_date, customernote.note_type, customernote.added_from_company, customernote.modified_by, customernote.date_added, customernote.date_modified, customernote.contact_ID, customernote.status, customernote.added_by, customernote.subject, customernote.recipient, customernote.send_email_date, customernote.cc_list, customernote.note_group_ID, customernote.action_type,
			(select min(contact_date) from customernote a where a.note_group_ID = customernote.note_group_ID and a.status=''O'') as min_date,
			(select top 1 contact_date from customernote a where a.note_group_id = customernote.note_group_ID and a.status=''O'' and a.contact_date > (select min(contact_date) from customernote a where a.note_group_ID = customernote.note_group_ID and a.status=''O'') order by a.contact_date asc) as second_date,
			(select max(contact_date) from customernote a where a.note_group_ID = customernote.note_group_ID) as max_date,
			customernotedetail.detail_ID, customernotedetail.customer_ID, customernotedetail.note_ID, customernotedetail.note, customernotedetail.date_added, customernotedetail.added_by, customernotedetail.audit
			from customer, contact, customernote, customernotedetail, #tempitems t (nolock)
			where customernote.note_ID = t.note_ID
			and t.noteautoid > ' + convert(varchar(10), @firstrec) + ' and t.noteautoid < ' + convert(varchar(10), @lastrec) + '
			and customernote.customer_ID = customer.customer_ID
			and customernote.contact_ID *= contact.contact_ID
			and customernote.note_ID *= customernotedetail.note_ID
			order by ' + @orderby + '
			for xml auto '
		-- print @searchsql
		execute(@searchsql)
	end
	
	if @mode = 'date-added'
		select max(customernotedetail.date_added)
			from #tempitems t (nolock), customernotedetail
			where customernotedetail.note_ID = t.note_ID
			and noteautoid > @firstrec and noteautoid < @lastrec
	
	if @mode = 'count'
		select count(*) from #tempitems
	


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[spw_getnotes] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[spw_getnotes] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[spw_getnotes] TO [EQAI]
    AS [dbo];

