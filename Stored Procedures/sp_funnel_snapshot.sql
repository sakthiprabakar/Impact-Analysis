/***************************************************************************************
Returns Funnel Info for a Snapshot Report

Null Territory = All Territories
Valid Status Codes:
NULL - All
L - Lost
W - Won
O - Open
C - Closed (Completed, Void, etc)

11/03/2003 JPB	Created
11/15/2004 JPB  Changed CustomerContact -> Contact
05/09/2007 JPB  Central Invoicing conversion: CustomerXCompany -> CustomerBilling

Test Cmd Line: sp_funnel_snapshot '17', 'P'
Test Cmd Line: sp_funnel_snapshot NULL, NULL
****************************************************************************************/
create procedure sp_funnel_snapshot
	@territory_code	varchar(8),
	@status char(1),
	@start_date datetime = NULL,
	@end_date datetime = NULL
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
	((f.probability * 0.01) * f.est_revenue) as projected_income,
	x.territory_code,
	f.customer_id
	from CustomerFunnel f 
		inner join customer c on f.customer_id = c.customer_id
		inner join funnelstatus s on f.status = s.status_code
		inner join funnelprobability p on f.probability = p.probability
		inner join customerbilling x on (f.customer_id = x.customer_id and x.billing_project_id = 0 and
		(
			(x.territory_code = @territory_code) 
			or 
			(1=1 and (@territory_code = '' or @territory_code is NULL))
		) )
		left outer join Contact cn on f.contact_id = cn.contact_id

	where (( (@status <> '' and @status is not NULL and (
			(@status = 'L' and f.status in ('L', 'X'))
			or
			(@status = 'W' and f.status in ('W', 'C'))
			or
			(@status = 'O' and f.status in ('N', 'P', 'T'))
			or
			(@status = 'C' and f.status in ('C', 'L', 'X', 'V', 'O', 'W'))
		))
		or
			(@status = '' or @status is NULL)
		)
		and (
			(@start_date is null or @end_date is null)
			or
			(@start_date is not null and @end_date is not null 
				and (
					(est_start_date between @start_date and @end_date or est_end_date between @start_date and @end_date)
					or
					(@start_date between est_start_date and est_end_date or @end_date between est_start_date and est_end_date)
				)
			)
		)
		)
		order by x.territory_code, f.probability desc

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_funnel_snapshot] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_funnel_snapshot] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_funnel_snapshot] TO [EQAI]
    AS [dbo];

