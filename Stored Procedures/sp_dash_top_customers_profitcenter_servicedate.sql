
CREATE PROCEDURE sp_dash_top_customers_profitcenter_servicedate (
	@num_returned		int = 100,
	@minimum_dollars	float = 1.00,
	@inv_start_date		datetime,
	@inv_end_date		datetime,
	@serv_start_date	datetime,
	@serv_end_date		datetime
)
AS
/************************************************************
Procedure    : sp_dash_top_customers_profitcenter_servicedate
Database     : PLT_AI
Created      : March 2, 2016 - Jonathan Broome
Description  : Returns the top @num_returned customers billed across all companies
	with more than @minimum_dollars in activity with invoice-date between @inv_start_date and @inv_end_date,
	and service-date between @serv_start_date and @serv_end_date
	grouped by company and profit_ctr_id

03/02/2016 - JPB Created as a copy of sp_dash_top_customers_profitcenter

exec sp_dash_top_customers_profitcenter_servicedate 25, 1000, '7/1/2015', '7/31/2015', '7/1/2015', '7/31/2015' -- 487
exec sp_dash_top_customers_profitcenter_servicedate 25, 1000, '1/1/2015', '12/31/2015', '7/1/2015', '7/30/2015' -- 487

************************************************************/


	select
		x.company_id,
		x.profit_ctr_id,
		x.profit_ctr_name,
		x.customer_id,
		x.cust_name,
		x.customer_type,
		x.total
		, x._rank
	FROM (
		SELECT
			b.company_id,
			b.profit_ctr_id,
			profitcenter.profit_ctr_name,
			b.customer_id,
			c.cust_name,
			c.customer_type,
			SUM(d.extended_amt) total,
			dense_rank() over (partition by b.company_id, b.profit_ctr_id order by SUM(d.extended_amt)  desc) _rank
		FROM
			BILLING b (nolock)
			INNER JOIN BILLINGDETAIL d (nolock) ON b.billing_uid = d.billing_uid
			INNER JOIN CUSTOMER c (nolock) ON b.customer_id = c.customer_id 
			INNER JOIN PROFITCENTER profitcenter (nolock) ON b.company_id = profitcenter.company_id and b.profit_ctr_id = profitcenter.profit_ctr_id
		WHERE
			b.invoice_date BETWEEN @inv_start_date AND @inv_end_date + 0.99999
			AND profitcenter.status = 'A'
			AND b.status_code = 'I'
			AND b.void_status = 'F'
			AND c.customer_type <> 'IC'
			AND EXISTS (
				SELECT 1 from BILLINGCOMMENT bc (nolock) 
				WHERE b.company_id = bc.company_id
				and b.profit_ctr_id = bc.profit_ctr_id
				and b.receipt_id = bc.receipt_id
				and b.trans_source = bc.trans_source
				AND bc.service_date BETWEEN @serv_start_date AND @serv_end_date + 0.99999
			)
		GROUP BY 
			b.company_id,
			b.profit_ctr_id,
			profitcenter.profit_ctr_name,
			b.customer_id,
			c.cust_name,
			c.customer_type
		HAVING sum(d.extended_amt) >= @minimum_dollars
	) x
	where x._rank <= @num_returned
	ORDER BY 
		x.company_id,
		x.profit_ctr_id,
		x._rank
	

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_dash_top_customers_profitcenter_servicedate] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_dash_top_customers_profitcenter_servicedate] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_dash_top_customers_profitcenter_servicedate] TO [EQAI]
    AS [dbo];

