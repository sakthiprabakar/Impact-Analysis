/********************
spw_MailingList:
Returns Fields to create a mailing list from customer/Contact.

LOAD TO PLT_AI

09/21/2004	JPB	Created
11/15/2004	JPB	Changed CustomerContact -> Contact
05/10/2006	JPB	Changed customerxcontact -> contactxref
10/10/2006	JPB	Added more select criteria
05/09/2007	JPB	Central Invoicing Conversion - Got rid of Company select options in the sql and converted customerxcontact -> Customerbilling
10/03/2007	WAC	Removed referenced to a database server.
08/21/2008  JPB Added @one_or_all parameter & query logic.
03/24/2011  JPB Changed the date_from/date_to, join/where, and #temp table methods.. Not outcome, just method - for speed.
06/20/2011	JPB Modified *mail_flag handling. Blank/Null/space now = True.

exec spw_MailingList null, null, null, '19', null, null, null, null, null, null, null, null, null, null, null, '1/1/2011', '3/22/2011', null, 'c', 'O', 0
exec spw_MailingList null, null, null, '19', null, null, null, null, null, null, null, null, null, null, null, '1/1/2011', '3/22/2011', null, 'c', 'O', 0
-- old: Ran over 10 minutes, then killed before results appeared.
-- new: 19 rows after 7s.

declare
	@company_list		varchar(max),
	@customer_id_list	varchar(max),
	@cust_name			varchar(40),
	@territory_list		varchar(max),
	@city				varchar(40),
	@state				varchar(max),
	@zip_from			varchar(10),
	@zip_to				varchar(10),
	@phone				varchar(20),
	@fax					varchar(20),
	@terms_code			varchar(max),
	@customer_type		varchar(max),
	@generator_flag		char(1),
	@designation			varchar(40),
	@category			varchar(40),
	@date_from			varchar(20),
	@date_to				varchar(20),
	@contact_name		varchar(40),
	@cust_type			char(1),		--'C'ustomer	or	'P'rospect
	@one_or_all			char(1), 		-- 'O'ne or 'A'll (One tries to get the primary contact, but if none, then the min active contact_id found)
	@debug				int

select 
	@debug = 0, 
	@territory_list = '1,2,3',
	@state = 'IN, OH',
	@cust_type = 'P'
	
exec spw_MailingList @company_list, @customer_id_list, @cust_name, @territory_list, @city, @state, 
	@zip_from, @zip_to, @phone, @fax, @terms_code, @customer_type, @generator_flag, 
	@designation, @category, @date_from, @date_to, @contact_name, @cust_type, @one_or_all, @debug 

**********************/

CREATE	PROCEDURE	spw_MailingList	(
	@company_list		varchar(max)	=	NULL,
	@customer_id_list	varchar(max)	=	NULL,
	@cust_name			varchar(40)		=	NULL,
	@territory_list		varchar(max)	=	NULL,
	@city				varchar(40)		=	NULL,
	@state				varchar(max)	=	NULL,
	@zip_from			varchar(10)		=	NULL,
	@zip_to				varchar(10)		=	NULL,
	@phone				varchar(20)		=	NULL,
	@fax					varchar(20)		=	NULL,
	@terms_code			varchar(max)	=	NULL,
	@customer_type		varchar(max)	=	NULL,
	@generator_flag		char(1)			=	NULL,
	@designation			varchar(40)		=	NULL,
	@category			varchar(40)		=	NULL,
	@date_from			varchar(20)		=	NULL,
	@date_to				varchar(20)		=	NULL,
	@contact_name		varchar(40)		=	NULL,
	@cust_type			char(1)			=	NULL,	--	'C'ustomer	or	'P'rospect
	@one_or_all			char(1)			= 	NULL,	-- 'O'ne or 'A'll (One tries to get the primary contact, but if none, then the min active contact_id found)
	@debug				int				=	0
	)
as
	set nocount on
		
	declare @sql varchar(max), @intCount int
	
	-- Split up/Store the company list:
	CREATE TABLE #tmp_database (
		database_name	varchar(60),
		company_id	int,
		profit_ctr_id	int,
		process_flag	int	)
	EXEC sp_reports_list_database @debug, @company_list
	
	-- Create holding tables for input lists
	CREATE TABLE #CustomerID	( customer_id	int	)
	CREATE TABLE #TerritoryCode	( territory_code	varchar(8)	)
	CREATE TABLE #State			( abbr	varchar(100) )
	CREATE TABLE #Terms			( terms_code	varchar(100) )
	CREATE TABLE #CustomerType	( customer_type	varchar(100) )

	-- Insert each list field into its table.
	IF LEN(@customer_id_list) > 0
		INSERT INTO #CustomerID SELECT row FROM dbo.fn_SplitXsvText(',', 1, @customer_id_list) WHERE isnull(row,'') <> ''
	
	IF LEN(@territory_list) > 0
		INSERT INTO #TerritoryCode SELECT right('00' + row, 2) FROM dbo.fn_SplitXsvText(',', 1, @territory_list) WHERE isnull(row,'') <> ''

	IF LEN(@state) > 0
		INSERT INTO #State SELECT row FROM dbo.fn_SplitXsvText(',', 1, @state) WHERE isnull(row,'') <> ''

	IF LEN(@Terms_code) > 0
		INSERT INTO #State SELECT row FROM dbo.fn_SplitXsvText(',', 1, @terms_code) WHERE isnull(row,'') <> ''

	IF LEN(@customer_type) > 0
		INSERT INTO #CustomerType SELECT row FROM dbo.fn_SplitXsvText(',', 1, @customer_type) WHERE isnull(row,'') <> ''
	
	set @sql = '
			select distinct
				c.customer_id,
				c.cust_name,
				co.name,
				case when isnull(nullif(nullif(co.email_flag, ''''), '' ''), ''T'') <> ''t'' then null else co.email end as email,
				c.cust_addr1,
				c.cust_addr2,
				c.cust_addr3,
				c.cust_addr4,
				c.cust_addr5,
				c.cust_city,
				c.cust_state,
				c.cust_zip_code,
				c.customer_id
			from
				customer c
				left outer join contactxref cxco on c.customer_id = cxco.customer_id and cxco.status = ''A'' 
				left outer join contact co on cxco.contact_id = co.contact_id and co.contact_status <> ''I''
				/* joins */
			where 1=1 '

	-- Cust Type (C or P)
	if isnull(@cust_type, '') = 'C'
			set @sql = @sql + ' and (c.customer_id  between 0 and 89999999 )'
	if isnull(@cust_type, '') = 'P'
			set @sql = @sql + ' and ( c.customer_id  > 90000000 or cust_prospect_flag = ''P'' ) '

	-- Customer ID
	IF LEN(@customer_id_list) > 0
		set @sql = replace(@sql, '/* joins */', 'inner join #customerid cid on c.customer_id = cid.customer_id /* joins */')
	
	-- Customer Name
	if @cust_name is not null and @cust_name <> ''
		set @sql = @sql + ' and ( c.cust_name like ''%' + replace(@cust_name, ' ', '%') + '%'' ) '

	-- Territory Code
	IF LEN(@territory_list) > 0 BEGIN
		SET @sql = replace(@sql, '/* joins */', 'inner join customerbilling cxc on c.customer_id = cxc.customer_id and cxc.billing_project_id = 0 inner join #TerritoryCode tc on cxc.territory_code = tc.territory_code /* joins */ ')
	END

	-- City		
	if LEN(@city) > 0
		set @sql = @sql + ' and ( c.cust_city like ''%' + replace(@city,' ','%') + '%'' ) '

	-- State
	if LEN(@state) > 0
		set @sql = replace(@sql, '/* joins */', 'inner join #State state on c.cust_state = state.abbr /* joins */ ')

	-- Zip From
	if LEN(@zip_from) > 0 
		if len(isnull(@zip_to, '')) <= 0
			set @sql = @sql + ' and ( c.cust_zip_code like ''%' + @zip_from + '%'' ) '
		else
			set @sql = @sql + ' and ( c.cust_zip_code >= ''' + @zip_from + ''' ) '
				
	-- Zip To
	if LEN(@zip_to) > 0
		if len(isnull(@zip_from, '')) <= 0
			set @sql = @sql + ' and ( c.cust_zip_code like ''%' + @zip_to + '%'' ) '
		else
			set @sql = @sql + ' and ( c.cust_zip_code <= ''' + @zip_to + ''' ) '
		
	-- Phone		
	if LEN(@phone) > 0
		set @sql = @sql + ' and ( c.cust_phone like ''%' + replace(@phone, ' ', '%') + '%'' ) '

	-- Fax		
	if LEN(@fax) > 0
		set @sql = @sql + ' and ( c.cust_fax like ''%' + replace(@fax, ' ', '%') + '%'' ) '
		
	-- Terms Code
	if LEN(@terms_code) > 0
		set @sql = replace(@sql, '/* joins */', 'inner join #Terms terms on c.terms_code = terms.terms_code /* joins */ ')

	-- Customer Type
	if LEN(@customer_type) > 0
		set @sql = replace(@sql, '/* joins */', 'inner join #CustomerType ctype on c.customer_type = ctype.customer_type /* joins */ ')

	-- Generator Flag		
	if LEN(@generator_flag) > 0
		set @sql = @sql + ' and ( c.generator_flag = ''' + @generator_flag + ''' ) '

	-- Designation		
	if LEN(@designation) > 0
		set @sql = @sql + ' and ( c.designation like ''%' + @designation + '%'' ) '
		
	-- Category		
	if LEN(@category) > 0
		set @sql = @sql + ' and ( c.cust_category like ''%' + @category + '%'' ) '

	-- Date From
	if LEN(@date_from) > 0
		set @sql = @sql + '
			AND EXISTS (
				SELECT 1 FROM invoiceheader ih WHERE ih.customer_id = c.customer_id and ih.invoice_date >= ''' + @date_from + ''' and c.cust_prospect_flag = ''C''
				UNION ALL
				SELECT 1 FROM customer c1 WHERE c1.customer_id = c.customer_id and c1.date_added >= ''' + @date_from + ''' and c.cust_prospect_flag <> ''C''
			)
		'
			

	-- Date To
	if LEN(@date_to) > 0
		set @sql = @sql + ' 
		AND EXISTS (
			SELECT 1 FROM invoiceheader ih WHERE ih.customer_id = c.customer_id and ih.invoice_date <= ''' + @date_to + ''' and c.cust_prospect_flag = ''C''
			UNION ALL
			SELECT 1 FROM customer c1 WHERE c1.customer_id = c.customer_id and c1.date_added <= ''' + @date_to + ''' and c.cust_prospect_flag <> ''C''
		)
	'		

	-- Contact Name	
	if LEN(@contact_name) > 0
		set @sql = @sql + ' and ( co.name like ''%' + replace(@contact_name, ' ', '%') + '%'' ) '
				
				
	set @sql = @sql + ' and isnull(nullif(nullif(c.mail_flag, ''''), '' ''), ''T'') = ''T'' '
	
	
	if LEN(@one_or_all) > 0
		if @one_or_all = 'O'
			set @sql = @sql + ' 
				and cxco.primary_contact = ''T'' 
				and EXISTS(
					select customer_id 
					from contactxref 
					where customer_id = c.customer_id
					and primary_contact = ''T'' 
					and type = ''C'' 
					and status = ''A'') 
					UNION ' + 
					@sql + ' 
					and cxco.contact_id = (
						select min(contact_id) 
						from contactxref 
						where customer_id = c.customer_id 
						and status = ''A'' 
						and type=''C'') 
					and not exists (
						select customer_id 
						from contactxref 
						where customer_id = c.customer_id 
						and primary_contact = ''T'' 
						and status = ''A'' 
						and type = ''C'')
					'

	
	set @sql = @sql + ' order by c.cust_name '
		
	if @debug > 0 select @sql as sql
		
	IF @debug < 10 exec(@sql)


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[spw_MailingList] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[spw_MailingList] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[spw_MailingList] TO [EQAI]
    AS [dbo];

