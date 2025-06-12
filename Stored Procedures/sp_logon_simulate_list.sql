Create Procedure sp_logon_simulate_list (
	@first_name		varchar(20) = '',
	@last_name		varchar(20) = '',
	@email			varchar(60) = '',
	@cust_name		varchar(75) = '',
	@customer_id		varchar(40) = '',
	@generator_name	varchar(75) = '',
	@generator_id	varchar(40) = '',
	@epa_id			varchar(40) = '',
	@sort 			varchar(20) = '',
	@limit			varchar(20) = '20'
)
AS
/************************************************************
Procedure    : sp_logon_simulate_list
Database     : plt_ai* 
Created      : Wed Dec 20 11:22:56 EST 2006 - Jonathan Broome
Filename     : L:\Apps\SQL\
Description  : Returns the list of logons to simulate
	Returns 2 recordsets - 1 of just the list of names, 2nd
	is the list of customers/generators for names with lte 10

07/08/2019	JPB	Cust_name: 40->75 / Generator_Name: 40->75

sp_logon_simulate_list '', '', 'wal-mart', '', '', '', '', '', ''
sp_logon_simulate_list '', '', 'wal-mart', '', '', '', '', '', 'email'
sp_logon_simulate_list '', '', '', '', '888888', '', '', '', ''
sp_logon_simulate_list '', 'demo', '', '', '', '', '', '', ''
sp_logon_simulate_list '', '', '', '', '', '', '', '', ''

drop table jpb_temp1
************************************************************/
SET NOCOUNT ON

declare @sql varchar(8000), 
	@where varchar(8000), 
	@group varchar(8000), 
	@order varchar(8000),
	@build varchar(8000)
	
select @sql = '', @where = '', @group = '', @order = '', @build = ''

create table #tmp1 (
	tid				int not null identity,
	contact_id		int,
	name			varchar(40),
	first_name		varchar(20),
	last_name		varchar(20),
	email			varchar(40),
	cust_count		int,
	gen_count		int,
	src				int )

create table #tmp2 (
	tid				int not null identity,
	contact_id		int,
	type			char(1),
	name			varchar(40),
	first_name		varchar(20),
	last_name		varchar(20),
	email			varchar(40),
	customer_id		int,
	generator_id	int,
	epa_id			varchar(12),
	cust_name		varchar(75),
	generator_name	varchar(75),
	o1				varchar(12),
	o2				varchar(12),
	src				int )

create table #tmp3 (
	tid				int not null identity,
	contact_id		int,
	type			char(1),
	name			varchar(40),
	first_name		varchar(20),
	last_name		varchar(20),
	email			varchar(40),
	customer_id		int,
	generator_id	int,
	epa_id			varchar(12),
	cust_name		varchar(75),
	generator_name	varchar(75),
	o1				varchar(12),
	o2				varchar(12),
	src				int )

set @sql = 'insert #tmp1 select distinct c.contact_id, c.name, c.first_name, c.last_name, c.email,
	sum(case when x.type = ''C'' then 1 else 0 end) as cust_count, sum(case when x.type = ''G'' then 1 else 0 end) as gen_count,
	1 as src
	from contact c 
	inner join contactxref x on c.contact_id = x.contact_id and x.status=''A'' and x.web_access=''A'' 
	left outer join customer cu on x.customer_id = cu.customer_id and x.type = ''C'' 
	left outer join generator g on x.generator_id = g.generator_id and x.type = ''G'' '

set @where = 'where 1=1 '
if @first_name <> '' set @where = @where + ' and c.first_name like /**/''' + replace(@first_name, '''', '''''') + '%'' '
if @last_name <> '' set @where = @where + ' and c.last_name like /**/''' + replace(@last_name, '''', '''''') + '%'' '
if @email <> '' set @where = @where + ' and c.email like /**/''' + replace(@email, '''', '''''') + '%'' '
if @cust_name <> '' set @where = @where + ' and cu.cust_name like /**/''' + replace(@cust_name, '''', '''''') + '%'' '
if @customer_id <> '' set @where = @where + ' and cu.customer_id in (' + replace(@customer_id, '''', '''''') + ') '
if @generator_name <> '' set @where = @where + ' and g.generator_name like /**/''' + replace(@generator_name, '''', '''''') + '%'' '
if @generator_id <> '' set @where = @where + ' and g.generator_id in (' + replace(@generator_id , '''', '''''')+ ') '
if @epa_id <> '' set @where = @where + ' and g.epa_id like /**/''' + replace(@epa_id, '''', '''''') + '%'' '
set @where = @where + ' and c.contact_status = ''A'' and c.web_password is not null '

set @group = 'group by c.contact_id, c.name, c.first_name, c.last_name, c.email '

set @order = ' order by src, c.last_name, c.first_name, c.email, c.contact_id '
if @sort = 'last_name' set @order = ' order by c.last_name, c.first_name, c.email, c.contact_id '
if @sort = 'first_name' set @order = ' order by c.first_name, c.last_name, c.email, c.contact_id '
if @sort = 'cust_name' set @order = ' order by cu.cust_name, g.generator_name '
if @sort = 'customer_id' set @order = ' order by x.customer_id, g.epa_id '
if @sort = 'email' set @order = ' order by c.email, c.last_name, c.first_name, c.contact_id '

set @build = @sql + @where + @group
if charindex('/**/', @where) > 0 
	set @build = @build + 
		' union ' + 
		replace(replace(@sql, '1 as src', '2 as src'), 'insert #tmp1', '') + 
		replace(@where, '/**/''', '''%') + 
		' and c.contact_id not in (
			select distinct c.contact_id from contact c 
			inner join contactxref x on c.contact_id = x.contact_id and x.status=''A'' and x.web_access=''A'' 
			left outer join customer cu on x.customer_id = cu.customer_id and x.type = ''C'' 
			left outer join generator g on x.generator_id = g.generator_id and x.type = ''G'' '
			+ @where +
		') ' +
		@group
set @build = @build + @order
exec(@build)

-- Need to delete duplicates from the #tmp1 table.
-- create index idx_tmp1 on #tmp1 (tid, contact_id)
-- delete from #tmp1 where tid in (select a.tid from #tmp1 a, #tmp1 b where a.contact_id = b.contact_id and a.tid > b.tid)

select @sql = '', @where = '', @group = '', @order = '', @build = ''

set @sql = 'insert #tmp2 (contact_id, type, name, first_name, last_name, email, customer_id, generator_id, epa_id, cust_name, generator_name, o1, o2, src ) 
	select distinct c.contact_id, upper(x.type), c.name, c.first_name, c.last_name, c.email, x.customer_id, 
	x.generator_id, g.epa_id, cu.cust_name, g.generator_name, isnull(x.customer_id, 9999998) as o1, 
	isnull(g.epa_id, 9999999) as o2, 
	1 as src 
	from contact c 
	inner join #tmp1 t1 on c.contact_id = t1.contact_id 
	inner join contactxref x on c.contact_id = x.contact_id and x.status=''A'' and x.web_access=''A'' 
	left outer join customer cu on x.customer_id = cu.customer_id 
	left outer join generator g on x.generator_id = g.generator_id '

set @where = 'where 1=1 '
if @first_name <> '' set @where = @where + ' and c.first_name like /**/''' + replace(@first_name, '''', '''''') + '%'' '
if @last_name <> '' set @where = @where + ' and c.last_name like /**/''' + replace(@last_name, '''', '''''') + '%'' '
if @email <> '' set @where = @where + ' and c.email like /**/''' + replace(@email, '''', '''''')+ '%'' '
if @cust_name <> '' set @where = @where + ' and cu.cust_name like /**/''' + replace(@cust_name, '''', '''''') + '%'' '
if @customer_id <> '' set @where = @where + ' and cu.customer_id in (' + replace(@customer_id, '''', '''''') + ') '
if @generator_name <> '' set @where = @where + ' and g.generator_name like /**/''' + replace(@generator_name, '''', '''''') + '%'' '
if @generator_id <> '' set @where = @where + ' and g.generator_id in (' + replace(@generator_id, '''', '''''') + ') '
if @epa_id <> '' set @where = @where + ' and g.epa_id like /**/''' + replace(@epa_id, '''', '''''') + '%'' '
set @where = @where + ' and c.contact_status = ''A'' and c.web_password is not null and c.contact_id not in (select contact_id from #tmp2 where type=x.type and contact_id=c.contact_id and (customer_id=cu.customer_id or generator_id=g.generator_id))'

set @group = 'group by c.contact_id, x.type, c.name, c.first_name, c.last_name, c.email, x.customer_id, 
	x.generator_id, g.epa_id, cu.cust_name, g.generator_name, isnull(x.customer_id, 9999998), 
	isnull(g.epa_id, 9999999), t1.cust_count, t1.gen_count 
	having (t1.cust_count <= ' + @limit + ' and x.type = ''C'') '

set @order = ' order by c.contact_id, upper(x.type), x.customer_id, g.epa_id '

set @build = @sql + @where + @group
if charindex('/**/', @where) > 0 
	set @build = @build + 
		' union ' + 
		replace(replace(@sql, '1 as src', '2 as src'), 'insert #tmp2 (contact_id, type, name, first_name, last_name, email, customer_id, generator_id, epa_id, cust_name, generator_name, o1, o2, src )', '') + 
		replace(@where, '/**/''', '''%') + 
		@group
set @build = @build + 
	' union ' +
	replace(
	replace(@build, 
		'having (t1.cust_count <= ' + @limit + ' and x.type = ''C'')', 'having (t1.gen_count <= ' + @limit + ' and x.type = ''G'')'),
	'insert #tmp2 (contact_id, type, name, first_name, last_name, email, customer_id, generator_id, epa_id, cust_name, generator_name, o1, o2, src )',
	'') +
	@order
exec(@build)

-- Need to delete duplicates from the #tmp2 table.
-- create index idx_tmp2 on #tmp2 (tid, contact_id, customer_id, generator_id)
delete from #tmp2 where tid in (select a.tid from #tmp2 a, #tmp2 b where a.contact_id = b.contact_id and ((a.customer_id = b.customer_id and a.customer_id is not null) or (a.generator_id = b.generator_id and a.generator_id is not null)) and a.tid < b.tid)

-- renumber rows in tmp2 to tmp3
insert #tmp3 (contact_id, type, name, first_name, last_name, email, customer_id, generator_id, epa_id, cust_name, generator_name, o1, o2, src)
select contact_id, type, name, first_name, last_name, email, customer_id, generator_id, epa_id, cust_name, generator_name, o1, o2, src
from #tmp2 order by tid

set nocount off

select *, 
	(select min(tid) from #tmp3 where contact_id = #tmp1.contact_id and type='C') as Cstart, 
	(select min(tid) from #tmp3 where contact_id = #tmp1.contact_id and type='G') as Gstart 
from #tmp1 order by tid

select * from #tmp3 order by tid

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_logon_simulate_list] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_logon_simulate_list] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_logon_simulate_list] TO [EQAI]
    AS [dbo];

