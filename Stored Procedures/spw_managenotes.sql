/***************************************************************************************
Returns notes in manage mode - runs a passed in query (the top-level manage query) and then filters it.

09/15/2003 JPB	Created
11/15/2004 JPB  Changed CustomerContact -> Contact

test cmd line: spw_managenotes 'SELECT customer.customer_ID, customer.cust_name, customer.cust_city, customer.cust_state, customer.cust_category, contact.contact_ID, contact.name, customernote.* from customer left outer join customerxcontact on (customer.customer_ID = customerxcontact.customer_ID) left outer join contact on (customerxcontact.contact_ID = contact.contact_ID) left outer join customernote on (customer.customer_ID = customernote.customer_ID and customernote.note_type <> ''audit'') where ( ( customernote.recipient like ''%jonathan%'' or customernote.cc_list like ''%jonathan%'') ) 
****************************************************************************************/
create procedure spw_managenotes
	@query varchar(7500),
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
	-- create a temporary note holder table
		create table #tmpnotes (
			customer_ID int, 
			note_ID int,
			contact_date datetime,
			note_type varchar(15),
			added_from_company int,
			modified_by varchar(10),
			date_added datetime,
			date_modified datetime,
			contact_ID int,
			status char(1),
			added_by varchar(10),
			subject varchar(50),
			recipient varchar(255),
			send_email_date datetime,
			cc_list varchar(255),
			action_type varchar(20) 
		)
	
	-- fill the note holding table
	declare @searchsql varchar(5000)
	
	SELECT @SearchSQL = 'insert into #tmpNotes SELECT distinct customernote.customer_ID, customernote.note_ID, customernote.contact_date, customernote.note_type, customernote.added_from_company, customernote.modified_by, customernote.date_added, customernote.date_modified, customernote.contact_ID, customernote.status, customernote.added_by, customernote.subject, customernote.recipient, customernote.send_email_date, customernote.cc_list, customernote.action_type '
	SELECT @SearchSQL = @SearchSQL + SUBSTRING(@query, PATINDEX('%from%', @query), 5000)
	
	-- SELECT @SearchSQL = 'insert into #tmpNotes ' + replace(@query, 'SELECT customer.customer_ID, customer.cust_name, contact.contact_ID, contact.name, customernote.*', 'SELECT distinct customernote.customer_ID, customernote.note_ID, customernote.contact_date, customernote.note_type, customernote.added_from_company, customernote.modified_by, customernote.date_added, customernote.date_modified, customernote.contact_ID, customernote.status, customernote.added_by, customernote.subject, customernote.recipient, customernote.send_email_date, customernote.cc_list, customernote.action_type ')
	-- SELECT @SearchSQL
	-- return
	EXECUTE(@SearchSQL)
	
	-- select * from #tmpnotes
	
	--create a temporary numbering table
	create table #tempitems
	(
		noteautoid int identity,
		note_ID	int,
	)
	
	-- insert the rows from the real table into the temp. table
	select @searchsql = 'insert into #tempitems (note_ID) 
		select note_ID 
		from #tmpnotes where 1=1 '
	
	if @customer_ID is not null
		select @searchsql = @searchsql +
		'and customer_ID = ' + convert(varchar(10), @customer_ID) + ' '
	else if @contact_ID is not null
		select @searchsql = @searchsql +
		'and contact_ID = ' + convert(varchar(10), @contact_ID) + ' '
	
	if len(ltrim(rtrim(@note_type))) > 0
	begin
		select @searchsql = @searchsql +
		'and (isnull(note_type, '''') = ''' + @note_type + ''' '
	
		if @audit = 't'
			select @searchsql = @searchsql +
			'or isnull(note_type, '''') = ''audit'' '
	
		select @searchsql = @searchsql +
		') '
	end
	
	if @audit != 't'
		select @searchsql = @searchsql + ' and isnull(note_type, '''') <> ''audit'' '
	
	if len(ltrim(rtrim(@status))) > 0
		select @searchsql = @searchsql + ' and status in (' + @status + ') '
	
	if @note_ID > 0
		select @searchsql = @searchsql + ' and note_ID = ' + convert(varchar(10), @note_ID) + ' '
	
	if len(ltrim(rtrim(@recipient))) > 0
		select @searchsql = @searchsql + ' and recipient like ''%' + @recipient + '%'' '
	
	if len(ltrim(rtrim(@cc))) > 0
		select @searchsql = @searchsql + ' and cc_list like ''%' + @cc + '%'' '
	
	if len(ltrim(rtrim(@action_type))) > 0
		if @action_type = 'any'
			select @searchsql = @searchsql + ' and action_type is not null '
		else
			select @searchsql = @searchsql + ' and action_type = ''' + @action_type + ''' '
	
	select @searchsql = @searchsql +
		' and contact_date >= ''' + @date_start + ''' 
		 and contact_date <= ''' + @date_stop + ''' '
	
	select @searchsql = @searchsql +
		'order by ' + replace(replace(replace(replace(@orderby, 'parent.', ''), 'customer.', ''), 'contact.', ''), 'customernote.', '') + ' '
	
	-- select @searchsql
	execute(@searchsql)
	-- select count(*) as tempitems_count from #tempitems
	
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
		execute(@searchsql)
	end
	
	if @mode = 'date-added'
		select max(customernotedetail.date_added)
			from #tempitems t (nolock), customernotedetail
			where customernotedetail.note_ID = t.note_ID
			and noteautoid > @firstrec and noteautoid < @lastrec
	
	if @mode = 'count'
		select count(*) as dcount from #tempitems



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[spw_managenotes] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[spw_managenotes] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[spw_managenotes] TO [EQAI]
    AS [dbo];

