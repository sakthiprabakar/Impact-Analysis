/***************************************************************************************
Returns Funnel Info for a Report

10/08/2003 JPB	Created
11/15/2004 JPB  Changed CustomerContact -> Contact

Test Cmd Line: sp_funnel_report '17', '2003-10-01', '2003-10-07', 'N'
****************************************************************************************/
create procedure sp_funnel_report
	@territory_code	varchar(8),
	@start_date datetime,
	@stop_date datetime,
	@status char(1)
as	
	select 
	(select top 1 status_date from funneldates d where d.funnel_id = f.funnel_id and d.status='N' order by status_date desc) as date_new,
	s.status_text,
	(select top 1 status_date from funneldates d where d.funnel_id = f.funnel_id and d.status=f.status order by status_date desc) as status_date,
	f.project_name,
	c.cust_name,
	cn.name,
	f.description,
	dbo.fn_funnel_company_list(funnel_id) as eq_company_profit_ctr, 
	case when f.direct_flag = 'T' then 'Customer Generator Direct' else 'Non - Direct' END as customer_type ,
	f.generator_name,
	case when f.job_type = 'E' then 'Event' else 'Base' END as job_type,
	f.project_type,
	f.quantity,
	f.price,
	f.bill_unit_code,
	f.number_of_intervals,
	f.project_interval,
	f.est_start_date,
	f.est_end_date,
	f.est_revenue,
	f.probability, p.description, 
	((f.probability * 0.01) * f.est_revenue) as projected_income
	from CustomerFunnel f 
		inner join customer c on f.customer_id = c.customer_id
		inner join funnelstatus s on f.status = s.status_code
		inner join funnelprobability p on f.probability = p.probability
		inner join customerxcompany x on (f.customer_id = x.customer_id and ((x.territory_code = @territory_code) or (1=1 and @territory_code = '')) and x.company_id = (select min(company_id) from customerxcompany where customerxcompany.customer_id = f.customer_id))
		left outer join Contact cn on f.contact_id = cn.contact_id
	where ( @status = 'N' and (select top 1 status_date from funneldates d where d.status = 'N' and d.funnel_id = f.funnel_id order by status_date desc) between @start_date and @stop_date and f.status not in ('L', 'C', 'O', 'V', 'X'))
		or ( @status = 'W' and (select top 1 status_date from funneldates d where d.status = 'W' and d.funnel_id = f.funnel_id order by status_date desc) between @start_date and @stop_date and f.status not in ('L', 'C', 'O', 'V', 'X'))
		or ( @status = 'P' and (select top 1 status_date from funneldates d where d.status = 'P' and d.funnel_id = f.funnel_id order by status_date desc) between @start_date and @stop_date and f.status not in ('L', 'C', 'O', 'V', 'X'))
		or ( @status = 'T' and (select top 1 status_date from funneldates d where d.status = 'T' and d.funnel_id = f.funnel_id order by status_date desc) between @start_date and @stop_date and f.status not in ('L', 'C', 'O', 'V', 'X'))
		or ( @status = 'L' and (select top 1 status_date from funneldates d where d.status = 'L' and d.funnel_id = f.funnel_id order by status_date desc) between @start_date and @stop_date and f.status not in ('N', 'W', 'P', 'T', 'V', 'C', 'X'))
		or ( @status = 'V' and (select top 1 status_date from funneldates d where d.status = 'V' and d.funnel_id = f.funnel_id order by status_date desc) between @start_date and @stop_date and f.status not in ('N', 'W', 'P', 'T', 'L', 'C', 'X'))
		or ( @status = 'O' and (select top 1 status_date from funneldates d where d.status = 'O' and d.funnel_id = f.funnel_id order by status_date desc) between @start_date and @stop_date and f.status not in ('N', 'W', 'P', 'T', 'L', 'V', 'C', 'X'))
		or ( @status = 'C' and (select top 1 status_date from funneldates d where d.status = 'C' and d.funnel_id = f.funnel_id order by status_date desc) between @start_date and @stop_date and f.status not in ('N', 'W', 'P', 'T', 'L', 'V', 'X'))
		or ( @status = 'X' and (select top 1 status_date from funneldates d where d.status = 'X' and d.funnel_id = f.funnel_id order by status_date desc) between @start_date and @stop_date and f.status not in ('N', 'W', 'P', 'T', 'V', 'C', 'L'))

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_funnel_report] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_funnel_report] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_funnel_report] TO [EQAI]
    AS [dbo];

