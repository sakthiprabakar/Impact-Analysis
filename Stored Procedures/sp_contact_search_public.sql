
/************************************************************
Procedure    : sp_contact_search_public
Database     : PLT_AI*
Created      : Thu Feb 23 17:35:02 EST 2006 - Jonathan Broome
Description  : Searches for Contacts, returns all Contact fields

06/05/2006	JPB		Added status field, default to A.
05/09/2007	JPB		Updated for Central Invoicing: CustomerXCompany -> CustomerBilling(bp_id = 0)
12/04/2012  JPB		Added @ForContactID, saved as sp_contact_search_public, contacts may call this now

sp_contact_search_public 0, '681', '', '', '', '', '', '', '', '', '', ''
sp_contact_search_public 0, '96245', '', '', '', '', '', '', '', '', '', '', ''
sp_contact_search_public 0, '', 'tom', '', '', '', '', '', '', '', '', ''
sp_contact_search_public 0, '', 'tom', '', '', '', '', '', '', '', '', '2'
sp_contact_search_public 0, '', '', '', '', '', '', '', '', '', 'demo', ''
sp_contact_search_public 0, '', '', '', '', '', '', '', '', '888888, 2222, 3434', '', ''

sp_contact_search_public 0, @name='', @rowto=20, @GenIdList='38452'
sp_contact_search_public 0, @name='', @rowto=20, @CustIdList='888888'

select top 100 * from contactxref where type = 'G'

select * from generator where generator_name like 'abc elec%'

            parameters.Add("Name", text);
            parameters.Add("rowto", 20);
            parameters.Add("ContactIdList", null);
            parameters.Add("CustIdList", CustomerID);

sp_contact_search_public 0, @name='darin'

************************************************************/
Create Procedure sp_contact_search_public (
	@Debug			int = 0,
	@ContactIdList	varchar(max) = '',
	@Name			varchar(40) = '',
	@FirstName		varchar(20) = '',
	@LastName 		varchar(20) = '',
	@Title 			varchar(20) = '',
	@Email 			varchar(60) = '',
	@Phone 			varchar(20) = '',
	@Fax 			varchar(10) = '',
	@CustIdList		varchar(max) = '',
	@CustName		varchar(40) = '',
	@Territory		varchar(max) = '',
	@Status			char(1) = 'A',
	@userkey		varchar(255) = '',
	@rowfrom		int = -1,
	@rowto			int = -1,
	@GenIdList		varchar(max) = '',
	@ForContactID	int = 0	-- -1 for Associates, contact_id for contacts.  0 = nothing.
)
AS

declare	@insert	varchar(8000),
		@sql varchar(8000),
		@where varchar(8000),
		@sqlfinal varchar(8000),
		@intcount int,
		@order varchar(8000)


delete from work_ContactSearch where ins_date < getdate()-1

-- Check for a userkey. If it exists, we're re-accessing existing rows. If not, this is new.
if @userkey <> ''
begin
	select @userkey = case when exists (select userkey from work_ContactSearch where userkey = @userkey) then @userkey else '' end
end

	if @rowfrom = -1 set @rowfrom = 1
	if @rowto = -1 set @rowto = 20
	
	

if ISNULL(@userkey,'') = ''
begin
	set @userkey = newid()

	set @insert = 'insert work_ContactSearch (contact_id, ins_date, userkey, last_name, first_name) ' 
	set @sql = 'select contact_id, getdate(), ''' + @userkey + ''' as userkey, last_name, first_name '
	set @sql = @sql + 'from contact where 1=1'
	set @where = ''
	set @order = 'order by last_name, first_name '

	if len(@ContactIdList) > 0
		set @where = @where + 'and contact_id in (' + @contactIdList + ') '

	if len(@Name) > 0
		set @where = @where + 'and name like ''%' + Replace(@name, '''', '''''') + '%'' '

	if len(@FirstName) > 0
		set @where = @where + 'and first_name like ''%' + Replace(@FirstName, '''', '''''') + '%'' '

	if len(@LastName) > 0
		set @where = @where + 'and last_name like ''%' + Replace(@LastName, '''', '''''') + '%'' '

	if len(@Title) > 0
		set @where = @where + 'and title like ''%' + Replace(@Title, '''', '''''') + '%'' '

	if len(@Email) > 0
		set @where = @where + 'and Email like ''%' + Replace(@Email, '''', '''''') + '%'' '

	if len(@Phone) > 0
		set @where = @where + 'and Phone like ''%' + Replace(@Phone, '''', '''''') + '%'' '

	if len(@Fax) > 0
		set @where = @where + 'and Fax like ''%' + Replace(@Fax, '''', '''''') + '%'' '

	if len(@CustIdList) > 0
		set @where = @where + 'and contact_id in (select contact_id from contactxref where type=''C'' and customer_id in (' + Replace(@custIDList, '''', '''''') + ')) '

	if len(@GenIdList) > 0
		set @where = @where + 'and contact_id in (select contact_id from contactxref where type=''G'' and generator_id in (' + Replace(@GenIdList, '''', '''''') + ')) '

	if len(@CustName) > 0
		set @where = @where + 'and contact_id in (select contact_id from contactxref x inner join customer c on x.type=''C'' and x.customer_id = c.customer_id and c.cust_name like ''%' + Replace(@custName, '''', '''''') + '%'') '

	if len(@Territory) > 0
		set @where = @where + 'and contact_id in (select contact_id from contactxref x inner join customerbilling c on x.type=''C'' and x.customer_id = c.customer_id and c.billing_project_id = 0 and convert(int, c.territory_code) in (' + Replace(@Territory, '''', '''''') + ')) '

	if len(@Status) > 0
		set @where = @where + 'and contact_status = ''' + Replace(@Status, '''', '''''') + ''' '

	if @ForContactID = 0 set @where = @where + 'and 1=0 '
	if @ForContactID = -1 set @where = @where + 'and 1=1 '
	if @ForContactID > 0 set @where = @where + 	'and contact_id in (
				select c2.contact_id
				from contactxref c 
				inner join contactxref c2 on c.customer_id = c2.customer_id and c2.type = ''C'' and c2.status = ''A''
				where c.contact_id = ' + convert(varchar(20), @ForContactID) + '
				union
				select c2.contact_id 
				from contactxref c 
				inner join contactxref c2 on c.generator_id = c2.generator_id and c2.type = ''G'' and c2.status = ''A''
				where c.contact_id = ' + convert(varchar(20), @ForContactID) + '
				union
				select c3.contact_id
				from contactxref c 
				inner join contactxref c2 on c.customer_id = c2.customer_id and c2.type = ''C'' and c2.status = ''A''
				inner join customergenerator cg on c2.customer_id = cg.customer_id
				inner join contactxref c3 on cg.generator_id = c3.generator_id and c3.type = ''G'' and c3.status = ''A''
				where c.contact_id = ' + convert(varchar(20), @ForContactID) + '
			) '

	set @sqlfinal = @insert + @sql + @where + @order
		
	if @debug >= 1
		begin
			print @sqlfinal
			select @sqlfinal
		end

	-- Load the work_ContactSearch table with note_id's
	exec (@sqlfinal)

    declare @mindummy int
    select @mindummy = min(dummy) from work_ContactSearch where userkey = @userkey
    update work_ContactSearch set ins_row = (dummy - @mindummy + 1) where userkey = @userkey

end


-- Select out the info for the rows requested.
select 
	c.contact_ID, 
	c.contact_status, 
	c.contact_type, 
	c.contact_company, 
	c.name, 
	c.title, 
	c.phone, 
	c.fax, 
	c.pager, 
	c.mobile, 
	c.comments, 
	c.email, 
	c.email_flag, 
	c.added_from_company, 
	c.modified_by, 
	c.date_added, 
	c.date_modified, 
	c.web_password, 
	c.contact_addr1, 
	c.contact_addr2, 
	c.contact_addr3, 
	c.contact_addr4, 
	c.contact_city, 
	c.contact_state, 
	c.contact_zip_code, 
	c.contact_country, 
	c.comments, 
	c.contact_personal_info, 
	c.contact_directions, 
	c.salutation, 
	c.first_name, 
	c.middle_name, 
	c.last_name, 
	c.suffix, 
	case when exists (
		select cx.contact_id 
		from contactxref cx 
		where 
		cx.contact_id = c.contact_id 
		and cx.status = 'A' 
		and cx.web_access = 'A'
	) then 'T' else 'F' end as web_access, 
	x.userkey,
	(select count(*) from work_ContactSearch where userkey = @userkey) as record_count
from 
	contact c
	inner join work_ContactSearch x on c.contact_id = x.contact_id
where 1=1	
	AND x.userkey = @userkey
	and ins_row between 
			case when @rowfrom <> 0 then @rowfrom else 0 end
		and
			case when @rowto <> 0 then @rowto else 999999999 end
order by
	ins_row




GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_contact_search_public] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_contact_search_public] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_contact_search_public] TO [EQAI]
    AS [dbo];

