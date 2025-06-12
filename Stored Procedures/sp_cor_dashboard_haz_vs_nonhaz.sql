-- drop proc sp_cor_dashboard_haz_vs_nonhaz

go

create proc sp_cor_dashboard_haz_vs_nonhaz (
	  @web_userid		varchar(100)
	, @date_start	datetime = null
	, @date_end		datetime = null
	, @customer_id_list varchar(max)  =''/* Added 2019-07-23 by AA */
	, @generator_id_list varchar(max)  =''/* Added 2019-07-23 by AA */
)
as 
/* ********************************************************************
sp_cor_dashboard_haz_vs_nonhaz

	per dev Ops item 3477.  Returns RCRA Haz vs NonHaz waste totals

Samples:
sp_cor_dashboard_haz_vs_nonhaz
	@web_userid = 'jennifer.chopp'
	, @date_start = '1/1/2019'
	, @date_end = '1/1/2020'
	, @customer_id_list = '600300'
	, @generator_id_list
	
History:	
	2019-07-16	JPB	Created




SELECT  *  FROM    contact WHERE web_userid = 'nyswyn100'
SELECT  *  FROM  ContactCorReceiptBucket WHERE   contact_id = 200959
SELECT  *  FROM    contactxref WHERE contact_id = 185547
SELECT  *  FROM  ContactCorReceiptBucket WHERE receipt_date between '1/1/2019' and '1/1/2020'
	
******************************************************************** */

declare
	@i_web_userid				varchar(100)	= @web_userid
	, @i_date_start				datetime		= @date_start			
	, @i_date_end				datetime		= @date_end				
	, @contact_id	int
	, @i_customer_id_list	varchar(max) = isnull(@customer_id_list, '')
    , @i_generator_id_list	varchar(max) = isnull(@generator_id_list, '')

select top 1 @contact_id = contact_id from CORcontact where web_userid = @i_web_userid
    
if isnull(@i_date_start, '1/1/1999') = '1/1/1999' set @i_date_start = dateadd(yyyy, -1, getdate()) else set @i_date_start = convert(date, @i_date_start)
if isnull(@i_date_end, '1/1/1999') = '1/1/1999' set @i_date_end = getdate() else set @i_date_end = convert(date, @i_date_end)

declare @customer_ids table (
	customer_id	int
)
insert @customer_ids
select convert(int, row) from dbo.fn_splitxsvtext(',', 1, @i_customer_id_list)
where row is not null

declare @generator_ids table (
	generator_id	int
)
insert @generator_ids
select convert(int, row) from dbo.fn_splitxsvtext(',', 1, @i_generator_id_list)
where row is not null


select h.contact_id, year(isnull(r.pickup_date, r.receipt_date)) [year], month(isnull(r.pickup_date, r.receipt_date)) [month], r.haz_flag, round(sum(r.tons),2) tons
	, rank() over (order by sum(r.tons) desc) as [rank]
from ContactCORStatsReceiptTons r
join ContactCORReceiptBucket h
	on h.receipt_id = r.receipt_id
	and h.company_id = r.company_id
	and h.profit_ctr_id = r.profit_ctr_id
WHERE h.contact_id = @contact_id
and isnull(r.pickup_date, r.receipt_date) between @i_date_start and @i_date_end
and (
	@i_customer_id_list = ''
	or
	r.customer_id in (
		select customer_id from @customer_ids
	)
)
and (
	@i_generator_id_list = ''
	or
	r.generator_id in (
		select generator_id from @generator_ids
	)
)
GROUP BY h.contact_id, year(isnull(r.pickup_date, r.receipt_date)), month(isnull(r.pickup_date, r.receipt_date)), r.haz_flag
ORDER BY 	year(isnull(r.pickup_date, r.receipt_date)), month(isnull(r.pickup_date, r.receipt_date)), r.haz_flag desc, [rank]

RETURN 0
go


grant execute on sp_cor_dashboard_haz_vs_nonhaz to cor_user, eqweb, eqai
go
