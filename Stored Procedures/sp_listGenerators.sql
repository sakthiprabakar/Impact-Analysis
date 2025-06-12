
Create Procedure sp_listGenerators (
	@perm_id 		int, 
	@contact_id 	int,
	@default 		varchar(8000) = '',
	@gen_name 		varchar(20) = '',
	@gen_epa_id 	varchar(20) = '',
	@site_code		varchar(40) = ''
)
/* ***********************************************************
Procedure    : sp_listGenerators
Database     : EQWeb* 
Created      : Wed Nov 15 15:08:44 EST 2006 - Jonathan Broome
Filename     : L:\Apps\SQL\
Description  : SQL for listing generators for a specific page & contact
 from the website

History:
	11/15/2006 - JPB - Created
	
	04/13/2009 - JPB
		Added @site_code input
		Removed @mode (_dev, _test, _prod) handling/embedding.
		Rewrote for clarity
	10/28/2013 - JPB
		The args passed into sp_generator_list_by_customer_list were wrong. Fixed.
	11/20/2013	JPB	Modified to accomodate new field in sp_generator_list_by_customer_list

Examples:
	sp_listGenerators 2, 100913 -- walmart contact
	sp_listGenerators 2, 10914 -- generator.demo@eqonline.com
	sp_listGenerators 2, 10914, '', '', 'mid'
	sp_listGenerators 6, 10913, '38452,38214,45'
	sp_listGenerators 6, 100913, '', 'ABC'
	sp_listGenerators 3, 10913 -- 30318099

*********************************************************** */
AS
	set nocount on

	declare @sql			varchar(8000)
	

-- Break @default values into a temp table...
	create table #default (generator_id int)
	create index idx1 on #default (generator_id)
	insert #default select convert(int, row) from dbo.fn_SplitXsvText(',', 1, @default) where isnull(row, '') <> ''	
	
-- Re-use the sp_generator_list_by_customer_list sp from .
	create table #pre (
		customer_id 		int,
		generator_id		int,
		generator_name		varchar(40),
		epa_id				varchar(12),
		generator_address_1	varchar(40),
		generator_city		varchar(40),
		generator_state		varchar(2),
		generator_zip_code	varchar(15),
		site_code			varchar(16),
		site_type			varchar(40),
		ord_gs				varchar(2),
		ord_gc				varchar(40),
		generator_address	VARCHAR(200),
		emergency_phone_number VARCHAR(10),
		gen_mail_city		VARCHAR(40),
		gen_mail_state		VARCHAR(2),
		gen_mail_zip_code	VARCHAR(15),
		gen_mail_address	VARCHAR(200),
		tab					float
	)

	insert #pre
	exec ('sp_generator_list_by_customer_list '''', ''AND'', '''', ''' + @gen_name + ''', ''' + @gen_epa_id + ''', ''' + @contact_id + ''', '''', '''', ''' + @site_code + '''')
	
-- Now filter the #pre results by the other inputs to sp_listGenerators
	set @sql = '	
		select distinct
			p.generator_id,
			p.generator_name, 
			p.generator_address_1,
			p.generator_city,
			p.generator_state,
			p.generator_zip_code,
			p.epa_id,
			p.site_code
		from #pre p
	'

	if (select count(*) from #default) > 0 
		set @sql = @sql + 'inner join #default d on p.generator_id = d.generator_id 
		'
	
	set @sql = @sql + '
		order by p.generator_name '

set nocount off

--	select @execute_sql as sql_stmt
	exec(@sql)
	

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_listGenerators] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_listGenerators] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_listGenerators] TO [EQAI]
    AS [dbo];

