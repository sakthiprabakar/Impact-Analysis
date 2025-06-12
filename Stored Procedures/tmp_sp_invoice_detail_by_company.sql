
create procedure tmp_sp_invoice_detail_by_company
	@start_date	datetime,
	@end_date	datetime,
	@company_id	int,
	@profit_ctr_id int
as

--SELECT * FROM ProfitCenter where status = 'A'
--order by company_id, profit_ctr_id


/* Receipts */
SELECT 
		copc.profit_ctr_name
       ,bd.company_id
       ,bd.profit_ctr_id	
       ,b.invoice_date	
		,bd.receipt_id
       ,bd.line_id
       ,bd.price_id
       ,case when bd.trans_source = 'R' then 'Receipt'
		when bd.trans_source = 'W' then 'Work Order'
		else bd.trans_source
		end as trans_source
       ,case when bd.trans_type = 'D' then 'Disposal'
		when bd.trans_type = 'S' then 'Service'
		when bd.trans_type = 'W' then 'Wash'
		else bd.trans_type
		end as trans_type
       ,c.customer_id
       ,c.cust_name
       ,bd.extended_amt       
FROM   Billing b
       INNER JOIN BillingDetail bd WITH(NOLOCK) ON bd.receipt_id = b.receipt_id
                                      AND bd.company_id = b.company_id
                                      AND bd.profit_ctr_id = b.profit_ctr_id
                                      AND b.line_id = bd.line_id
                                      AND b.price_id = bd.price_id
                                      AND b.trans_source = bd.trans_source
		INNER JOIN Customer c  WITH(NOLOCK) ON b.customer_id = c.customer_id  
		INNER JOIN InvoiceHeader ih WITH(NOLOCK)  ON b.invoice_id = ih.invoice_id
		INNER JOIN ProfitCenter copc WITH(NOLOCK)  ON bd.company_id = copc.company_ID
			and bd.profit_ctr_id = copc.profit_ctr_ID
WHERE  ih.invoice_date >= @start_date and ih.invoice_date <= @end_date
       AND bd.trans_source = 'R'
       --AND bd.trans_type = 'D'
       AND b.status_code = 'I' 
       and ih.status = 'I'
		and bd.company_id = @company_id
		and bd.profit_ctr_id = @profit_ctr_id

UNION 

/* Work Order Info */
SELECT copc.profit_ctr_name
       ,bd.company_id
       ,bd.profit_ctr_id
       ,ih.invoice_date
		,bd.receipt_id
       ,bd.line_id
       ,bd.price_id
       ,case when bd.trans_source = 'R' then 'Receipt'
		when bd.trans_source = 'W' then 'Work Order'
		else bd.trans_source
		end as trans_source,
		wot.account_desc
       ,c.customer_id
       ,c.cust_name
       ,bd.extended_amt       
FROM   WorkOrderHeader woh
       JOIN WorkOrderDetail wod  WITH(NOLOCK) ON woh.workorder_ID = wod.workorder_ID
                                   AND woh.company_id = wod.company_id
                                   AND woh.profit_ctr_ID = wod.profit_ctr_ID
       JOIN Billing b  WITH(NOLOCK) ON b.receipt_id = wod.workorder_id
                         AND b.company_id = wod.company_id
                         AND b.profit_ctr_id = wod.profit_ctr_id
                         AND b.workorder_sequence_id = wod.sequence_ID
                         AND b.workorder_resource_type = wod.resource_type
       INNER JOIN BillingDetail bd  WITH(NOLOCK) ON bd.receipt_id = b.receipt_id
                                      AND bd.company_id = b.company_id
                                      AND bd.profit_ctr_id = b.profit_ctr_id
                                      AND b.line_id = bd.line_id
                                      AND b.price_id = bd.price_id
                                      AND b.trans_source = bd.trans_source 
		INNER JOIN InvoiceHeader ih  WITH(NOLOCK) ON b.invoice_id = ih.invoice_id                                      
		INNER JOIN Customer c  WITH(NOLOCK) ON b.customer_id = c.customer_id
		INNER JOIN ProfitCenter copc  WITH(NOLOCK) ON bd.company_id = copc.company_ID
			and bd.profit_ctr_id = copc.profit_ctr_ID
		LEFT JOIN WorkOrderType wot ON wot.company_id = woh.company_id
			and wot.account_type = woh.workorder_type
			and wot.status = 'A'
	
where 1=1
and b.trans_source = 'W'
and b.status_code = 'I'
--and b.workorder_resource_type = 'D'
--and wod.resource_type ='D'
and ih.invoice_date >= @start_date and ih.invoice_date <= @end_date
and ih.status = 'I'
		and bd.company_id = @company_id
		and bd.profit_ctr_id = @profit_ctr_id


	
/*
I need the following set of information to help complete an analysis for the invoice timeliness inititive that is currently going

Two files dumped into excel

one covering all activity invoiced in 2010 and the other covering whatever was done through in 2011 - Jan through March

Both files needs to contain the follwing set of information

The invoiced receipt and work order lines number
Thedivision the work order or receipt line related to
 the dollar amount per the line that was invoiced
 the customer who was billed for that receipt or work order line.

Please inquire if this request isn't clear.. I need this information ASAP.. Ideally if you want to set up the report and do only 2011 and send it to me before doing 2010, that would be fine.

Thanks. 
*/



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[tmp_sp_invoice_detail_by_company] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[tmp_sp_invoice_detail_by_company] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[tmp_sp_invoice_detail_by_company] TO [EQAI]
    AS [dbo];

