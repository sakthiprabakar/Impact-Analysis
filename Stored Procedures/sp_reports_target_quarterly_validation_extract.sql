
create proc sp_reports_target_quarterly_validation_extract (
	-- @customer_id		int	= 12113					-- Target specific
	@start_date		datetime						-- Typically quarterly, but I guess you could run for any date.
	, @end_date		datetime
	--- , @state_list	varchar(max) = 'ALL'		-- State list isn't used in this sql
)
as
/* ****************************************************************************
sp_reports_target_quarterly_validation_extract

-- Target 2014-Q1 (OK, SC) Disposal Extract
-- According to Tracy we're not concerned at all with Workorder Disposal.
-- Beware if copying... Duplicating Line_Weight if there's more than 1 Billing Record.
-- Does not seem to happen in Targets dataset.
-- SK 01/10/2013 Modified to run for all states.

declare @customer_id int, @state_list varchar(max), @start_date datetime, @end_date datetime
select @customer_id = 12113, @state_list = 'ALL', @start_date = '01/01/2014 00:00', @end_date = '3/31/2014 23:59'

History
	4/22/2014	JPB	Created as an SP from the existing Extract script, which was nearly an SP,
					and substantially different in output that existing EQIP Target reports.
	8/22/2014	JPB	GEM:-29706 - Modify Validations: ___ Not-Submitted only true if > $0

Sample:

sp_reports_target_quarterly_validation_extract '3/1/2014', '3/31/2014'
	
**************************************************************************** */
-- Target 2014-Q1 disposal extract validations

-- Target specific:
declare @customer_id int = 12113

	if DATEPART(hh, @end_date) = 0 set @end_date = @end_date + 0.99999

		

	-- 0 weights:
	SELECT  distinct '0 weight' as problem, r.company_id, r.profit_ctr_id, r.receipt_id, r.line_id  
	FROM    receipt r
	INNER JOIN receiptprice rp on r.receipt_id = rp.receipt_id and r.line_id = rp.line_id and r.company_id = rp.company_id and r.profit_ctr_id = rp.profit_ctr_id
	INNER JOIN Generator g on r.generator_id = g.generator_id
	where r.customer_id = @customer_id
	and r.receipt_date between @start_date and @end_date
	and r.receipt_status <> 'V' and r.fingerpr_status <> 'V' and trans_type = 'D'
	and isnull(r.line_weight, 0) = 0


	-- not submitted:
	-- declare @customer_id int, @start_date datetime, @end_date datetime
	-- select @customer_id = 12113, @start_date = '1/1/2011 00:00', @end_date = '12/31/2011 23:59'


	union all 

	SELECT  distinct 'Not Submitted', r.company_id, r.profit_ctr_id, r.receipt_id, r.line_id  FROM    receipt r
	INNER JOIN receiptprice rp on r.receipt_id = rp.receipt_id and r.line_id = rp.line_id and r.company_id = rp.company_id and r.profit_ctr_id = rp.profit_ctr_id
		and (rp.total_extended_amt > 0 or rp.print_on_invoice_flag = 'T')
	INNER JOIN Generator g on r.generator_id = g.generator_id
	where r.customer_id = @customer_id
	and r.receipt_date between @start_date and @end_date
	and r.receipt_status <> 'V' and r.fingerpr_status <> 'V' and trans_type = 'D'
	and not exists (
		select 1 from billing where receipt_id = r.receipt_id and company_id = r.company_id and profit_ctr_id = r.profit_ctr_id and line_id = r.line_id and price_id = rp.price_id
	)

	-- submitted, not invoiced:
	-- declare @customer_id int, @start_date datetime, @end_date datetime
	-- select @customer_id = 12113, @start_date = '1/1/2011 00:00', @end_date = '12/31/2011 23:59'

	union all

	SELECT  distinct 'Submitted, Not Invoiced', r.company_id, r.profit_ctr_id, r.receipt_id, r.line_id  FROM    receipt r
	INNER JOIN receiptprice rp on r.receipt_id = rp.receipt_id and r.line_id = rp.line_id and r.company_id = rp.company_id and r.profit_ctr_id = rp.profit_ctr_id
	INNER JOIN Generator g on r.generator_id = g.generator_id
	where r.customer_id = @customer_id
	and r.receipt_date between @start_date and @end_date
	and r.receipt_status <> 'V' and r.fingerpr_status <> 'V' and trans_type = 'D'
	and exists (
		select 1 from billing where receipt_id = r.receipt_id and company_id = r.company_id and profit_ctr_id = r.profit_ctr_id and line_id = r.line_id and price_id = rp.price_id
	)
	and not exists (
		select 1 from billing where receipt_id = r.receipt_id and company_id = r.company_id and profit_ctr_id = r.profit_ctr_id and line_id = r.line_id and price_id = rp.price_id and status_code IN ('I')
	)

	order by problem, r.company_id, r.profit_ctr_id, r.receipt_id, r.line_id


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_reports_target_quarterly_validation_extract] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_reports_target_quarterly_validation_extract] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_reports_target_quarterly_validation_extract] TO [EQAI]
    AS [dbo];

