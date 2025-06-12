-- drop proc sp_cor_dashboard_haz_vs_nonhaz_detail

go

create proc sp_cor_dashboard_haz_vs_nonhaz_detail (
	  @web_userid		varchar(100)
	, @date_start	datetime = null
	, @date_end		datetime = null
	, @customer_id_list varchar(max)  =''/* Added 2019-07-23 by AA */
	, @generator_id_list varchar(max)  =''/* Added 2019-07-23 by AA */
)
as 
/* ********************************************************************
sp_cor_dashboard_haz_vs_nonhaz_detail

	per dev Ops item 3477.  Returns RCRA Haz vs NonHaz waste totals

Samples:
sp_cor_dashboard_haz_vs_nonhaz_detail
	@web_userid = 'akalinka'
	, @date_start = '1/1/2021'
	, @date_end = '4/1/2021'
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

/*
 On the Detail Tab: Display the 
 Month
 , Year
 , Receipt Date
 , Waste Stream Common Name
 , Approval Code
 , Hazardous or Non-Hazardous indicator
 , Profile ID
 , Date Picked Up
 , Generator EPA ID
 , Generator State ID
 , Generator ID
 , Generator Name
 , Generator City
 , Generator State
 , Generator Country
 , Generator Zip Code
 , Generator Site Type
 , Manifest Number
 , Manifest Page Number
 , Manifest Line Number
 , TSDF Name
 , TSDF City
 , TSDF State
 , TSDF Country
 , Manifest Quantity
 , Manifest Unit
 , Manifest Container Count
 , Manifest Container Code
 , Quantity converted to TONS
 
 sp_columns ContactCORStatsReceiptTons
 */
 
select 
h.contact_id
, year(isnull(s.pickup_date, s.receipt_date)) [year]
, month(isnull(s.pickup_date, s.receipt_date)) [month]
, s.receipt_date
, p.approval_desc
, s.approval_code
, s.haz_flag
, s.profile_id
, s.pickup_date
, g.epa_id
, g.state_id
, g.generator_id
, g.generator_name
, g.generator_city
, g.generator_state
, g.generator_country
, g.generator_zip_code
, g.site_type
, s.manifest
, s.manifest_page_num
, s.manifest_line
, t.tsdf_name
, t.tsdf_city
, t.tsdf_state
, t.tsdf_country_code
, s.manifest_quantity
, s.manifest_unit
, s.quantity
, s.manifest_container_code
, round(/*sum*/(s.tons),2) tons
from ContactCORStatsReceiptTons s
join ContactCORReceiptBucket h
	on h.receipt_id = s.receipt_id
	and h.company_id = s.company_id
	and h.profit_ctr_id = s.profit_ctr_id
join Receipt r
	on h.receipt_id = r.receipt_id
	and h.company_id = r.company_id
	and h.profit_ctr_id = r.profit_ctr_id
	and s.profile_id = r.profile_id
join profile p 
	on s.profile_id = p.profile_id
join generator g 
	on s.generator_id = g.generator_id
join tsdf t
	on s.company_id = t.eq_company
	and s.profit_ctr_id = t.eq_profit_ctr
	and t.eq_flag = 'T'
	and t.tsdf_status = 'A'
WHERE h.contact_id = @contact_id
and isnull(s.pickup_date, s.receipt_date) between @i_date_start and @i_date_end
and (
	@i_customer_id_list = ''
	or
	s.customer_id in (
		select customer_id from @customer_ids
	)
)
and (
	@i_generator_id_list = ''
	or
	s.generator_id in (
		select generator_id from @generator_ids
	)
)

/*
GROUP BY 
h.contact_id
, year(isnull(s.pickup_date, s.receipt_date))
, month(isnull(s.pickup_date, s.receipt_date))
, s.haz_flag
*/
ORDER BY 	
year(isnull(s.pickup_date, s.receipt_date))
, month(isnull(s.pickup_date, s.receipt_date))
, t.tsdf_name
, s.receipt_id
, r.line_id
RETURN 0
go


grant execute on sp_cor_dashboard_haz_vs_nonhaz_detail to cor_user
go
grant execute on sp_cor_dashboard_haz_vs_nonhaz_detail to eqweb
go
grant execute on sp_cor_dashboard_haz_vs_nonhaz_detail to eqai
go
