Create Procedure sp_shipping_address_list (
	@contact_id		int,
	@name			varchar(20) = '',
	@epa_id			varchar(20) = '',
	@city			varchar(40) = '',
	@state			varchar(40) = ''
)
as
/************************************************************
Procedure	: sp_shipping_address_list
Database	: PLT_AI*
Created		: 04/07/2008 - Jonathan Broome
Description	: Lists addresses for all customers/generators/past orders for a contact; searchable.


sp_shipping_address_list 10913

sp_shipping_address_list 6926
sp_shipping_address_list null

************************************************************/

	SET NOCOUNT ON

	declare @sql varchar(4000)
	
	create table #tmp (
		customer_id		int,
		generator_id	int,
		name			varchar(40),
		epa_id			varchar(20),
		addr1			varchar(40),
		addr2			varchar(40),
		city			varchar(40),
		state			varchar(2),
		zip_code		varchar(15),
		query_sort		int
	)


	if @contact_id is null and len(isnull(@name, '')) + len(isnull(@epa_id, '')) + len(isnull(@city, '')) + len(isnull(@state, '')) = 0
		return

	/* CustomerGenerator Contact-Customer->Generator relationship: */
	set @sql = '
	insert #tmp
	select distinct 
		null as customer_id, 
		g.generator_id, 
		g.generator_name as name, 
		g.epa_id, 
		g.generator_address_1 as addr1, 
		g.generator_address_2 as addr2, 
		g.generator_city as city, 
		g.generator_state as state, 
		g.generator_zip_code as zip_code,
		3 as query_sort
	from generator g 
		inner join customergenerator cg on g.generator_id = cg.generator_id
		inner join contactxref cx on cg.customer_id = cx.customer_id and cx.type = ''C'' and cx.status = ''A'' and cx.web_access = ''A''
		inner join eqweb..accessxperms axp on cx.customer_id = axp.account_id and cx.type = axp.record_type and cx.contact_id = axp.contact_id
		inner join eqweb..Permissions p on axp.perm_id = p.perm_id and p.perm_name = ''Bill To EQ Account'' 
	where 1=1 
	and g.status = ''A''
	'
	
	if @contact_id is not null set @sql = replace(@sql, '1=1', 'cx.contact_id = ' + convert(varchar(20), @contact_id))
	if @name <> '' set @sql = @sql + 'and generator_name like ''%' + @name + '%'' '
	if @epa_id <> '' set @sql = @sql + 'and epa_id like ''%' + @epa_id + '%'' '
	if @city <> '' set @sql = @sql + 'and generator_city like ''%' + @city + '%'' '
	if @state <> '' set @sql = @sql + 'and generator_state like ''%' + @state + '%'' '
	
	exec(@sql)


	/* Direct Contact-Customer relationship: */
	set @sql = '
	insert #tmp
	select distinct 
		c.customer_id, 
		null as generator_id, 
		c.cust_name as name, 
		null as epa_id, 
		c.cust_addr1 as addr1,
		c.cust_addr2 as addr2, 
		c.cust_city as city, 
		c.cust_state as state, 
		c.cust_zip_code as zip_code,
		1 as query_sort
	from customer c 
		inner join contactxref cx on c.customer_id = cx.customer_id and cx.type = ''C'' and cx.status = ''A'' and cx.web_access = ''A''
		inner join eqweb..accessxperms axp on cx.customer_id = axp.account_id and cx.type = axp.record_type and cx.contact_id = axp.contact_id
		inner join eqweb..Permissions p on axp.perm_id = p.perm_id and p.perm_name = ''Bill To EQ Account'' 
	where 1=1
		and isnull(c.cust_addr1, '''') + '' '' + 
			isnull(c.cust_city, '''') + '' '' +
			isnull(c.cust_state, '''') + '' '' + 
			isnull(c.cust_zip_code, '''') 
		not in (
			select isnull(addr1, '''') + '' '' + 
				isnull(city, '''') + '' '' +
				isnull(state, '''') + '' '' + 
				isnull(zip_code, '''') 
			from #tmp
		)
		and cust_status = ''A''
		'
	if @contact_id is not null set @sql = replace(@sql, '1=1', 'cx.contact_id = ' + convert(varchar(20), @contact_id))
	if @name <> '' set @sql = @sql + 'and cust_name like ''%' + @name + '%'' '
	if @city <> '' set @sql = @sql + 'and cust_city like ''%' + @city + '%'' '
	if @state <> '' set @sql = @sql + 'and cust_state like ''%' + @state + '%'' '

	exec(@sql)

			
	/* Direct Contact-Generator relationship: */
	set @sql = '
	insert #tmp
	select distinct 
		null as customer_id, 
		g.generator_id, 
		g.generator_name as name, 
		g.epa_id, 
		g.generator_address_1 as addr1, 
		g.generator_address_2 as addr2, 
		g.generator_city as city, 
		g.generator_state as state, 
		g.generator_zip_code as zip_code,
		2 as query_sort
	from generator g 
		inner join contactxref cx on g.generator_id = cx.generator_id and cx.type = ''G'' and cx.status = ''A'' and cx.web_access = ''A''
		inner join eqweb..accessxperms axp on cx.generator_id = axp.account_id and cx.type = axp.record_type and cx.contact_id = axp.contact_id
		inner join eqweb..Permissions p on axp.perm_id = p.perm_id and p.perm_name = ''Bill To EQ Account'' 
	where 1=1
		and isnull(g.generator_address_1, '''') + '' '' + 
			isnull(g.generator_city, '''') + '' '' +
			isnull(g.generator_state, '''') + '' '' + 
			isnull(g.generator_zip_code, '''') 
		not in (
			select isnull(addr1, '''') + '' '' + 
				isnull(city, '''') + '' '' +
				isnull(state, '''') + '' '' + 
				isnull(zip_code, '''') 
			from #tmp
		)
		and g.status = ''A''
		'
	if @contact_id is not null set @sql = replace(@sql, '1=1', 'cx.contact_id = ' + convert(varchar(20), @contact_id))
	if @name <> '' set @sql = @sql + 'and generator_name like ''%' + @name + '%'' '
	if @epa_id <> '' set @sql = @sql + 'and epa_id like ''%' + @epa_id + '%'' '
	if @city <> '' set @sql = @sql + 'and generator_city like ''%' + @city + '%'' '
	if @state <> '' set @sql = @sql + 'and generator_state like ''%' + @state + '%'' '

	exec(@sql)

	if (select count(*) from #tmp) = 0 begin
		/* Past Orders for the contact if none were found yet: */
		set @sql = '
		insert #tmp
		select distinct 
			customer_id, 
			generator_id, 
			ship_cust_name as name, 
			null as epa_id, 
			ship_addr1 as addr1, 
			ship_addr2 as addr2, 
			ship_city as city, 
			ship_state as state, 
			ship_zip_code as zip_code,
			4 as query_sort
		from OrderHeader
		where contact_id = ' + convert(varchar(20), @contact_id) + ' '
		if @name <> '' set @sql = @sql + 'and ship_cust_name like ''%' + @name + '%'' '
		if @city <> '' set @sql = @sql + 'and ship_city like ''%' + @city + '%'' '
		if @state <> '' set @sql = @sql + 'and ship_state like ''%' + @state + '%'' '
	
		exec(@sql)
	end

	set nocount on

	set @sql = 'select customer_id, generator_id, name, epa_id, addr1, addr2, city, state, zip_code from #tmp where 1=1 '
	set @sql = @sql + 'order by state, city, name '

	exec(@sql)


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_shipping_address_list] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_shipping_address_list] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_shipping_address_list] TO [EQAI]
    AS [dbo];

