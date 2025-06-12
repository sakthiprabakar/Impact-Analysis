
create procedure sp_rpt_opportunity_win_v_loss
	@permission_id int,
	@user_id int,
	@user_code				varchar(20),
	--@est_start_date_1		datetime = NULL,
	--@est_start_date_2		datetime = NULL,
	--@est_end_date_1			datetime = NULL,
	--@est_end_date_2			datetime = NULL,
	@act_start_date_1		datetime = NULL,
	@act_start_date_2		datetime = NULL
	--@act_end_date_1			datetime = NULL,
	--@act_end_date_2			datetime = NULL,
	--@mod_start_date			datetime = NULL,
	--@mod_end_date			datetime = NULL

AS
BEGIN

--SET @est_start_date_1		= cast(convert(varchar(10),@est_start_date_1,101) as datetime)
--SET @est_start_date_2		= cast(convert(varchar(10),@est_start_date_2,101) + ' 23:59:59' as datetime)
--SET @est_end_date_1			= cast(convert(varchar(10),@est_end_date_1,101) as datetime)
--SET @est_end_date_2			= cast(convert(varchar(10),@est_end_date_2,101)  + ' 23:59:59' as datetime)
SET @act_start_date_1		= cast(convert(varchar(10),@act_start_date_1,101) as datetime)
SET @act_start_date_2		= cast(convert(varchar(10),@act_start_date_2,101) + ' 23:59:59' as datetime)
--SET @act_end_date_1			= cast(convert(varchar(10),@act_end_date_1,101) as datetime)
--SET @act_end_date_2			= cast(convert(varchar(10),@act_end_date_2,101) + ' 23:59:59' as datetime)
--SET @mod_start_date			= cast(convert(varchar(10),@mod_start_date,101) as datetime)
--SET @mod_end_date			= cast(convert(varchar(10),@mod_end_date,101) + ' 23:59:59' as datetime)


declare @search_sql varchar(max) = ''
declare @where varchar(max) = ''



/* Create "Tally" table(Ref: http://www.sqlservercentral.com/articles/T-SQL/62867/) */
SELECT TOP 100 IDENTITY(int,1,1) as number
	INTO #tally 
	FROM master.dbo.syscolumns sc1,	master.dbo.syscolumns sc2

SELECT * INTO #biz_month FROM 
(

select @act_start_date_1 as report_month
	UNION
select dateadd(month, t.number, @act_start_date_1) as report_month
	from #tally t
	where dateadd(month, t.number, @act_start_date_1) < @act_start_date_2
) t

SELECT 
	month(biz.report_month) as report_month,
	year(biz.report_month) as report_year,
	biz.report_month as report_period,
	o.est_revenue,
	o.status
	/*
	isnull(actual_start_date, est_start_date) as start_date,
	isnull(actual_end_date, est_end_date) as end_date,	
	o.Opp_id,
	o.customer_id,
	c.cust_name,
	o.territory_code,
	t.territory_desc,
	r.region_desc,
	o.Opp_name,
	o.opp_city,
	o.opp_state,
	o.opp_county,
	o.opp_country,
	o.loss_comments,
	o.loss_reason,
	o.description,
	o.service_type,
	--jobtype.description as job_type,
	salestype.description as salestype,
	servicetype.description as servicetype,
	
	s.description as status_text,
	o.generator_name,
	
	o.probability,

	o.date_modified,
	mu.user_name as modified_by,
	o.region_id,
	o.nam_id,
	nam.user_name as nam_user_name
	*/
INTO #win_v_loss	
from 
	Opp o
	right join #biz_month biz ON month(isnull(actual_start_date, est_start_date)) = month(biz.report_month)
		and year(isnull(actual_start_date, est_start_date)) = year(biz.report_month)
	left outer join OppStatusLookup s on o.status = s.code and s.type = 'Opp'
	left outer join contact on o.contact_id = contact.contact_id
	left outer join OppSalesType salestype on o.sales_type = salestype.code
	left outer join OppServiceType servicetype on o.service_type = servicetype.code
	left outer join Users mu on o.modified_by = mu.user_code
	left outer join Users omu on o.opp_manager = omu.user_code
	left outer join UsersXEQContact uxeq on o.nam_id = uxeq.type_id and uxeq.eqcontact_type = 'nam'
	left outer join Users nam on uxeq.user_code = nam.user_code
	left outer join Region r on o.region_id = r.region_id
	left outer join territory t on o.territory_code = t.territory_code
	LEFT JOIN Customer c ON o.customer_id = c.customer_id
WHERE 1=1	
	and @act_start_date_1 is not null and o.est_start_date >= @act_start_date_1 and o.est_start_date <= @act_start_date_2

--AND 1 = 
--	CASE WHEN @est_start_date_1 is not null and o.est_start_date >= @est_start_date_1 and o.est_start_date <= @est_start_date_2 then 1
--	WHEN @est_end_date_1 is not null and o.est_start_date >= @est_end_date_1 and o.est_start_date <= @est_end_date_2 then 1
--	WHEN @act_start_date_1 is not null and o.est_start_date >= @act_start_date_1 and o.est_start_date <= @act_start_date_2 then 1
--	WHEN @act_end_date_1 is not null and o.est_start_date >= @act_end_date_1 and o.est_start_date <= @act_end_date_2 then 1
--	WHEN @est_start_date_1 is not null and o.est_start_date >= @est_start_date_1 and o.est_start_date <= @est_start_date_2 then 1
--	ELSE 0
--	END
AND status IN ('L','W')


SELECT MONTH(b.invoice_date) AS [month]
       ,YEAR(b.invoice_date) AS [year]
       ,SUM(IsNull(bd.extended_amt, 0.000)) AS [amount]
INTO   #actual_revenue
FROM   Billing b
       JOIN BillingDetail bd ON bd.company_id = b.company_id
                                AND bd.profit_ctr_id = b.profit_ctr_id
                                AND bd.receipt_id = b.receipt_id
                                AND bd.line_id = b.line_id
                                AND bd.price_id = b.price_id
                                AND bd.trans_type = b.trans_type
                                AND bd.trans_source = b.trans_source
WHERE  b.invoice_date BETWEEN @act_start_date_1 AND @act_start_date_2
       AND b.status_code = 'I'
GROUP  BY MONTH(b.invoice_date)
          ,YEAR(b.invoice_date) 


SELECT report_month, report_year, wvl.report_period,
	win_est_revenue = ISNULL((SELECT sum(est_revenue) FROM #win_v_loss win where status = 'W' and report_month = wvl.report_month and report_year = wvl.report_year),0),
	loss_est_revenue = ISNULL((SELECT sum(est_revenue) FROM #win_v_loss loss where status = 'L' and report_month = wvl.report_month and report_year = wvl.report_year),0),
	actl_revenue = ISNULL((select [amount] from #actual_revenue where [month]=wvl.report_month and [year] = wvl.report_year),0)
FROM #win_v_loss wvl
group by report_year, report_month,report_period

END


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_opportunity_win_v_loss] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_opportunity_win_v_loss] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_opportunity_win_v_loss] TO [EQAI]
    AS [dbo];

