-- drop proc sp_cor_facility_list
go

create proc sp_cor_facility_list (
	@web_userid		varchar(100),
	@context		varchar(40) = null, 
		-- 'receipt', 'Schedule', 'Service' (same as schedule, really), 
		-- 'receipt service' (combination of receipt & work order facilities)
		-- 'approved profiles', 'expired profiles' (same as approved profiles)
	@customer_id_list varchar(max)='', /* Added 2019-08-05 by AA */
    @generator_id_list varchar(max)=''  /* Added 2019-08-05 by AA */
)
as 
/* *****************************************************
sp_cor_facility_list

Returns the list of USE facilities.

If the @context variable is null, just list them all
If the @context variable is non-null, return the list
	of facilities RELEVANT to the @web_userid of that
	@context type (i.e. the facilities for which they have
	receipts, or work orders, etc)

09/30/2019 MPM  DevOps 11564: Added logic to filter the result set
				using optional input parameters @customer_id_list and
				@generator_id_list.
07/14/2021 JPB  DO-16844 - added invoice_date not null requirement in receipt routines
	
SELECT  *  FROM    contact WHERE web_userid like '%cour%'	
exec sp_cor_facility_list 'nyswyn100'
exec sp_cor_facility_list 'nyswyn100', 'receipt'
exec sp_cor_facility_list 'nyswyn100', 'schedule'
exec sp_cor_facility_list 'courtney.cattell', 'receipt service'
exec sp_cor_facility_list 'keithjb36', 'receipt', '13396', '94817'
exec sp_cor_facility_list 'keithjb36', 'receipt', '', '94817'
exec sp_cor_facility_list 'keithjb36', 'receipt', '13396', ''

***************************************************** */


-- avoid query plan caching:
declare
    @i_web_userid			varchar(100) = @web_userid,
    @i_context			varchar(40) = @context,
    @i_contact_id			int,
    @i_customer_id_list	varchar(max) = isnull(@customer_id_list, ''),
    @i_generator_id_list	varchar(max) = isnull(@generator_id_list, '')

declare @customer table (
	customer_id	bigint
)

if @i_customer_id_list <> ''
insert @customer select convert(bigint, row)
from dbo.fn_SplitXsvText(',', 1, @i_customer_id_list)
where row is not null

declare @generator table (
	generator_id	bigint
)

if @i_generator_id_list <> ''
insert @generator select convert(bigint, row)
from dbo.fn_SplitXsvText(',', 1, @i_generator_id_list)
where row is not null

if isnull(@i_context, '') = '' set @i_context = ''

select @i_contact_id = contact_id from CORcontact where web_userid = @i_web_userid

	select distinct
	p.company_id
	, Profit_ctr_id = 
		case 
			when p.view_on_web = 'P' then p.profit_ctr_id
			when p.view_on_web = 'C' then (select min(profit_ctr_id) from profitcenter where company_id = p.company_id) end
			
	, Profit_ctr_Name = isnull( p.wcr_facility_name ,
		case
			when p.view_on_web = 'P' then p.profit_ctr_name
			when p.view_on_web = 'C' then company_name end
		)

	into #pc
	from profitcenter P
	inner join company C on p.company_id = c.company_id
	where
	p.status = 'A'
	and p.view_on_web in ('P',  'C')
	and c.view_on_web = 'T'

select top 1 * into #out from #pc where 1=0


if @i_context = '' 
	-- All, no filter 
	insert #out
	SELECT  pc.*  FROM    #pc pc


	if @i_context in ('approved profiles', 'expired profiles')
	-- FormFacility matching
	insert #out
	SELECT  distinct pc.*  
	FROM    #pc pc
	join ContactCORProfileBucket b
		on b.contact_id = @i_contact_id
	join ProfileQuoteApproval pqa
		on b.profile_id = pqa.profile_id
		and pc.company_id = pqa.company_id
		and pc.profit_ctr_id = pqa.profit_ctr_id
		and pqa.status = 'A'
	where 
		(
			@i_customer_id_list = ''
		    or
	       (
			@i_customer_id_list <> ''
			and
			b.customer_id in (select customer_id from @customer)
			)
		)
		and (
			@i_generator_id_list = ''
			or
			(
				@i_generator_id_list <> ''
				and
				b.generator_id in (select generator_id from @generator)
			)
		)
	and pc.company_id not in (44,45,46)

if @i_context in ('receipt', 'receipt schedule', 'receipt service')
	-- Receipts 
	insert #out
	SELECT  distinct pc.*  FROM    #pc pc
	join ContactCORReceiptBucket b 
		on b.contact_id = @i_contact_id
		and b.company_id = pc.company_id
		and b.profit_ctr_id = pc.profit_ctr_id
	where 
		(
			@i_customer_id_list = ''
		    or
	       (
			@i_customer_id_list <> ''
			and
			b.customer_id in (select customer_id from @customer)
			)
		)
		and (
			@i_generator_id_list = ''
			or
			(
				@i_generator_id_list <> ''
				and
				b.generator_id in (select generator_id from @generator)
			)
		)
		and b.invoice_date is not null -- never used with uninvoiced receipts.

if @i_context in ('service', 'schedule', 'receipt schedule', 'receipt service')
	-- Work Orders 
	insert #out
	SELECT  distinct pc.*  FROM    #pc pc
	join ContactCORWorkorderHeaderBucket b
		on b.contact_id = @i_contact_id
		and b.company_id = pc.company_id
		and b.profit_ctr_id = pc.profit_ctr_id
	where 1=1
		and (
			@i_customer_id_list = ''
		    or
	       (
			@i_customer_id_list <> ''
			and
			b.customer_id in (select customer_id from @customer)
			)
		)
		and (
			@i_generator_id_list = ''
			or
			(
				@i_generator_id_list <> ''
				and
				b.generator_id in (select generator_id from @generator)
			)
		)

select distinct 
convert(Varchar(2), upc.company_id) + '|' +convert(varchar(2), upc.profit_ctr_id) as copc
, wcr_facility_name name
, upc.description
from #out o
join ProfitCenter upc 
	on o.company_id = upc.company_id
	and o.profit_ctr_id = upc.profit_ctr_id
order by upc.wcr_facility_name
	

GO

GRANT EXECUTE ON sp_cor_facility_list to EQAI, Guest, COR_USER, eqweb
GO
