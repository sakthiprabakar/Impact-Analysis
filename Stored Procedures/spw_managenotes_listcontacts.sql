/***************************************************************************************
Returns a list of contacts referenced in notes in manage mode - runs a passed in query (the top-level manage query) and then filters it.

09/15/2003 jpb	created
11/15/2004 JPB  Changed CustomerContact -> Contact

test cmd line: spw_managenotes 'select customer.customer_ID, customer.cust_name, contact.contact_ID, contact.name, customernote.* from customer left outer join customerxcontact on (customer.customer_ID = customerxcontact.customer_ID) left outer join contact on (customerxcontact.contact_ID = contact.contact_ID) left outer join customernote on (customer.customer_ID = customernote.customer_ID and customernote.note_type <> ''audit'') where ( ( customernote.recipient like ''%jonathan%'' or customernote.cc_list like ''%jonathan%'') ) /* |data||data||data|customernote.recipient#c#string#c# like ''%[x]%'' #c#jonathan#c# or #c#1#r#customernote.cc_list#c#string#c# like ''%[x]%'' #c#jonathan#c# end #c#1#r#|data| */ ', 1, 10, null, null, null, 'reminder', '1/1/1900 00:00:00.000', '9/19/2003 23:59:59.998', '''o'', ''''', 0, '', '', '', 'f', 'contact_date desc'
****************************************************************************************/
create procedure spw_managenotes_listcontacts
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
	@orderby varchar(100)
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
	-- select @searchsql
	-- return
	execute(@searchsql)
	
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
		'and (note_type = ''' + @note_type + ''' '
	
		if @audit = 't'
			select @searchsql = @searchsql +
			'or note_type = ''audit'' '
	
		select @searchsql = @searchsql +
		') '
	end
	
	if @audit != 't'
		select @searchsql = @searchsql + ' and note_type <> ''audit'' '
	
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
	
		select @searchsql = 'select distinct 
			contact.contact_ID,
			CASE WHEN customer.customer_id <= 999999 THEN
			RIGHT(''000000'' + convert(varchar(8), customer.customer_id),6) + '' - '' + contact.name
			ELSE
			convert(varchar(8), customer.customer_id) + '' - '' + contact.name
			END
			from customer, customerxcontact, contact, customernote, #tempitems t (nolock)
			where customernote.note_ID = t.note_ID
			and t.noteautoid > ' + convert(varchar(10), @firstrec) + ' and t.noteautoid < ' + convert(varchar(10), @lastrec) + '
			and customernote.customer_ID = customer.customer_ID
			and customer.customer_ID = customerxcontact.customer_ID
			and customerxcontact.contact_ID = contact.contact_ID '
		execute(@searchsql)



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[spw_managenotes_listcontacts] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[spw_managenotes_listcontacts] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[spw_managenotes_listcontacts] TO [EQAI]
    AS [dbo];

