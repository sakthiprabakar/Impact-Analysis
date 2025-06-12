-- drop proc sp_cor_dashboard_top_waste_streams_detail
go

CREATE PROCEDURE sp_cor_dashboard_top_waste_streams_detail (
	@web_userid		varchar(100)
	, @limit		int = 10
	, @measure		varchar(20) = 'volume' -- or 'spend'
	, @date_start	datetime = null
	, @date_end		datetime = null
	, @period			varchar(2) = null /* WW, MM, QQ or YY: Forces @date fields to be ignored for current period dates */
	, @haz_flag		char(1) = 'A' /* 'A'll or 'H'az or 'N'on-haz */
	, @customer_id_list varchar(max)=''  /* Added 2019-07-15 by AA */
    , @generator_id_list varchar(max)=''  /* Added 2019-07-15 by AA */

	, @order	char(1) = 'T'  /* 'T'op (default) or 'B'ottom) */
	, @workorder_type varchar(40) = '' /* leave blank/null to ignore this filter 
		otherwise require an exact match to workorder_type 
		Courtney's use case is 'Retail Product Offering'
		*/
) 
AS
BEGIN
/* **************************************************************
sp_cor_dashboard_top_waste_streams_detail

10/03/2019 MPM  DevOps 11562: Added logic to filter the result set
				using optional input parameter @generator_id_list.

Outputs the Top @limit Waste Streams measured by @measure
over whole stats availability range (1 year at time of creation)

 sp_cor_dashboard_top_waste_streams_detail 
	@web_userid		= 'nyswyn100'
	, @limit = 5
	, @measure = 'spend'
	
 sp_cor_dashboard_top_waste_streams
	@web_userid		= 'nyswyn100'
	, @limit = 5
	, @measure = 'spend'
	, @date_start = '1/1/2019'
	, @date_end = '5/03/2019'
	, @period = null 
	, @customer_id_list =''  /* Added 2019-07-15 by AA */
    , @generator_id_list =''  /* Added 2019-07-15 by AA */

 sp_cor_dashboard_top_waste_streams_detail 
	@web_userid		= 'nyswyn100'
	, @limit = 5
	, @measure = 'spend'
	, @date_start = '1/1/2019'
	, @date_end = '5/03/2022'
	, @period = null 
	, @customer_id_list =''  /* Added 2019-07-15 by AA */
    , @generator_id_list =''  /* Added 2019-07-15 by AA */



waste_stream                   total_tons  total_spend  _row
------------------------------ ----------- ------------ ----
NON-REGULATED WASTE            4212.35     2145400.28   1
Lith Ion Batt cont. in equip   47.63       815057.62    2
ELECTRONIC WASTE               555.67      743791.94    3
TOXIC LIQUID LOOSEPACK         120.23      642946.98    4
OTC SUPPLEMENTS AND COSMETICS  67.37       367868.69    5

sp_cor_dashboard_top_waste_streams_detail 
	@web_userid	 = 'court_c'
	, @limit = 10
	, @measure = 'spend'
	, @date_start = '1/1/2018'
	, @date_end = '10/03/2019'
	, @period = null 
	, @customer_id_list = '15622'  
--    , @generator_id_list = '123056, 123057, 123058'

 sp_cor_dashboard_top_waste_streams
	@web_userid		= 'court_c'
	, @limit = 10
	, @measure = 'spend'
	, @date_start = '12/1/2019'
	, @date_end = '12/31/2019'
	, @period = null 
	, @customer_id_list ='15940'  /* Added 2019-07-15 by AA */
    , @generator_id_list =''  /* Added 2019-07-15 by AA */

waste_stream						total_weight	pct_weight	weight_unit	total_spend	pct_spend	currency_code
SP-KROHW07- NICOTINE				0.18			2.39		Tons		1140.75		34.49		USD
SP-KROHWECIG E-cig w/ Li-ion Batt	0.15			1.99		Tons		968.50		29.28		USD
SP-KROHW02S - FLAMMABLE SOLIDS		0.18			2.39		Tons		612.50		18.52		USD
Coffee Flavor Rinse Water			6.99			92.83		Tons		419.00		12.67		USD
SP-KROUW03 - LITHIUM ION BATTERIES	0.02			0.27		Tons		141.00		4.26		USD

 sp_cor_dashboard_top_waste_streams_detail 
	@web_userid		= 'court_c'
	, @limit = 10
	, @measure = 'spend'
	, @date_start = '12/1/2019'
	, @date_end = '12/31/2019'
	, @period = null 
	, @customer_id_list ='15940'  /* Added 2019-07-15 by AA */
    , @generator_id_list =''  /* Added 2019-07-15 by AA */


************************************************************** */

declare
	@i_web_userid		varchar(100)	= @web_userid
	, @i_limit			int				= isnull(@limit, 10)
	, @i_measure		varchar(20)		= isnull(@measure, 'volume')
	, @i_date_start		datetime		= convert(date, @date_start)
	, @i_date_end		datetime		= convert(date, @date_end)
	, @i_period					varchar(2)		= @period
	, @contact_id	int
    , @i_generator_id_list	varchar(max) = isnull(@generator_id_list, '')
    , @i_customer_id_list	varchar(max) = isnull(@customer_id_list, '')
    , @i_haz_flag		char(1) = isnull(@haz_flag, 'A')
	, @i_order	char(1) = isnull(nullif(@order, ''), 'T')
	, @i_workorder_type varchar(40) = isnull(nullif(@workorder_type, ''), '')

select top 1 @contact_id = contact_id from CORcontact where web_userid = @i_web_userid
    
if isnull(@i_date_start, '1/1/1999') = '1/1/1999' set @i_date_start = dateadd(yyyy, -1, getdate())
if isnull(@i_date_end, '1/1/1999') = '1/1/1999' set @i_date_end = getdate()
if datepart(hh, @i_date_end) = 0 set @i_date_end = @i_date_end + 0.99999
if @i_haz_flag not in ('A', 'H', 'N') set @i_haz_flag = 'A'

--select @contact_id, @i_date_start, @i_date_end

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

if isnull(@i_period, '') <> ''
	select @i_date_start = dbo.fn_FirstOrLastDateOfPeriod(0, @period, 'top_waste_streams')
		, @i_date_end = dbo.fn_FirstOrLastDateOfPeriod(1, @period, 'top_waste_streams')

/*
ContactCORStatsGeneratorTotal doesn't have real dates. It has _month and _year
so we have to translate the date ranges entered into a list of month+year to include
*/

declare @time table (
	m_date datetime
);

	
WITH CTE AS
(
	SELECT @i_date_start AS cte_start_date
	UNION ALL
	SELECT DATEADD(DAY, 1, cte_start_date)
	FROM CTE
	WHERE DATEADD(DAY, 1, cte_start_date) <= @i_date_end   
)
insert @time
SELECT convert(date,cte_start_date)
FROM CTE
  OPTION (MAXRECURSION 0)

--SELECT  *  FROM    @time

-- Now just join against @time in the same query above?

declare @foo table (
	waste_stream	varchar(50)
	, total_tons	decimal(10,2)
	, total_spend	money
	, currency		char(3)
	, _row			int
)

declare @bar table (
	waste_stream	varchar(50)
	, total_tons	decimal(10,2)
	, total_spend	money
	, currency		char(3)
	, _row			int
)
insert @foo
select waste_stream, convert(decimal(10,2),total_tons) total_tons, total_spend, currency_code, _row
 from (
	SELECT  *
		, _row = dense_rank() over (order by
			case when @i_measure = 'volume' then total_tons end desc,
			case when @i_measure = 'spend' then total_spend end desc
		)
	FROM (
		select contact_id, waste_stream
			, sum(total_pounds / 2000.00) as total_tons
			, sum(total_spend) as total_spend
			, isnull(currency_code, 'USD') currency_code
		FROM ContactCORStatsGeneratorTotal c
		JOIN @time t
			on c._date = t.m_date
		WHERE contact_id = @contact_id
		and
		(
			@i_customer_id_list = ''
			or
			(
				@i_customer_id_list <> ''
				and
				c.customer_id in (select customer_id from @customer)
			)
		)		
		and
		(
			@i_generator_id_list = ''
			or
			(
				@i_generator_id_list <> ''
				and
				c.generator_id in (select generator_id from @generator)
			)
		)		
		and
		(
			@i_workorder_type = ''
			or
			(
				@i_workorder_type <> ''
				and
				c.workorder_type = @i_workorder_type
			)
		)		
		and haz_flag = case @i_haz_flag when 'A' then haz_flag when 'H' then 'T' when 'N' then 'F' else haz_flag end
		GROUP BY contact_id, waste_stream, isnull(currency_code, 'USD')
	) y
) x


if @order = 'B' begin
	insert @bar select 
	waste_stream	
	, total_tons	
	, total_spend	
	, currency	
	, _new_row = dense_rank() over (order by _row desc)
	from @foo
	
	delete from @foo
	insert @foo select * from @bar 
end

declare @all_tons decimal(10,2), @all_spend money
select @all_tons = sum(total_tons) 
	, @all_spend = sum(total_spend)
from @foo

select 
	f.waste_stream
	, c._date as service_date
	--, coalesce(rb.pickup_date, wb.service_date) service_date
	, c.total_pounds
	, convert(decimal(10,2),(c.total_pounds / 2000.00)) total_tons
	, c.total_spend
	, c.currency_code
	, g.generator_id
	, g.generator_name
	, g.site_code
	, g.epa_id
	, g.state_id
	, g.generator_city
	, g.generator_state
	, g.generator_zip_code
	, g.generator_country
	, g.site_type
--	, c.*
	, tsdf.tsdf_name
	, tsdf.tsdf_city
	, tsdf.tsdf_state
	, tsdf.tsdf_country_code
	, coalesce(pqar.approval_code, pqaw.approval_code, ta.tsdf_approval_code) approval_code
	, coalesce(pqar.profile_id, pqaw.profile_id, ta.tsdf_approval_id) profile_id
	, coalesce(r.manifest,d.manifest) manifest
	, coalesce(r.manifest_page_num, d.manifest_page_num) manifest_page_num
	, coalesce(r.manifest_line, d.manifest_line) manifest_line
	, coalesce(r.quantity, d.quantity_used) manifest_qty
	, coalesce(r.manifest_unit, d.manifest_wt_vol_unit) manifest_unit
	, coalesce(r.container_count, d.container_count) manifest_container_count
	, coalesce(r.manifest_container_code, d.container_code) manifest_container_code
	, case c.haz_flag when 't' then 'Haz' when 'f' then 'Non-Haz' end Haz_Flag
	, ds.disposal_service_desc
	, _row
from @foo f
join ContactCORStatsGeneratorTotal c on f.waste_stream = c.waste_stream
join generator g on c.generator_id = g.generator_id
JOIN @time t
	on c._date = t.m_date
LEFT JOIN disposalservice ds
	on c.disposal_service_id = ds.disposal_service_id
left join receipt r
	on c.source_table = 'Receipt'
	and c.source_company_id = r.company_id
	and c.source_profit_ctr_id = r.profit_ctr_id
	and c.source_id = r.receipt_id
	and c.source_line_id = r.line_id
left join workorderdetail d
	on c.source_table = 'Workorder'
	and c.source_company_id = d.company_id
	and c.source_profit_ctr_id = d.profit_ctr_id
	and c.source_id = d.workorder_id
	and d.resource_type = 'D'
	and c.source_line_id = d.sequence_id
left join profilequoteapproval pqar
	on r.profile_id = pqar.profile_id
	and r.company_id = pqar.company_id
	and r.profit_ctr_id = pqar.profit_ctr_id
LEFT JOIN profilequoteapproval pqaw
	on d.profile_id = pqaw.profile_id
	and d.profile_company_id = pqaw.company_id
	and d.profile_profit_ctr_id = pqaw.profit_ctr_id
left join tsdfapproval ta
	on d.tsdf_approval_id = ta.tsdf_approval_id
left join TSDF tsdfr
	on r.company_id = tsdfr.eq_company
	and r.profit_ctr_id = tsdfr.eq_profit_ctr
	and tsdfr.tsdf_status = 'A'
LEFT JOIN TSDF tsdfw
	on d.tsdf_code = tsdfw.tsdf_code
	and tsdfw.tsdf_status = 'A'
left join TSDF tsdf
	on tsdf.tsdf_code = coalesce(tsdfr.tsdf_code, tsdfw.tsdf_code)
	and tsdf.tsdf_status = 'A'
left join ContactCORReceiptBucket rb
	on c.contact_id = rb.contact_id
	and c.source_id = rb.receipt_id
	and c.source_company_id = rb.company_id
	and c.source_profit_ctr_id = rb.profit_ctr_id
	and c.source_table = 'Receipt'
left join ContactCORWorkorderHeaderBucket wb
	on c.contact_id = wb.contact_id
	and c.source_id = wb.workorder_id
	and c.source_company_id = wb.company_id
	and c.source_profit_ctr_id = wb.profit_ctr_id
	and c.source_table = 'Workorder'
WHERE c.contact_id = @contact_id
and
(
	@i_customer_id_list = ''
	or
	(
		@i_customer_id_list <> ''
		and
		c.customer_id in (select customer_id from @customer)
	)
)		
and
(
	@i_generator_id_list = ''
	or
	(
		@i_generator_id_list <> ''
		and
		c.generator_id in (select generator_id from @generator)
	)
)		
		and
		(
			@i_workorder_type = ''
			or
			(
				@i_workorder_type <> ''
				and
				c.workorder_type = @i_workorder_type
			)
		)		

and c.haz_flag = case @i_haz_flag when 'A' then c.haz_flag when 'H' then 'T' when 'N' then 'F' else c.haz_flag end
order by f._row



return 0
END

GO

GRANT EXEC ON sp_cor_dashboard_top_waste_streams_detail TO EQAI;
GO
GRANT EXEC ON sp_cor_dashboard_top_waste_streams_detail TO EQWEB;
GO
GRANT EXEC ON sp_cor_dashboard_top_waste_streams_detail TO COR_USER;
GO
