-- drop proc sp_eqip_Costco_Invoice_Detail
go

create proc sp_eqip_Costco_Invoice_Detail (
	@invoice_code_list	varchar(max)
)
as
/* ************************************************************************************
sp_eqip_Costco_Invoice_Detail

1/31/2020 Created
3/30/2020 Added Invoice Status, Project Name, removed 'I' status requirement, added max revision_id requirement.

SELECT  *  FROM    invoiceheader where customer_id = 601113 and invoice_date > '12/1/2019'
SELECT  *  FROM    invoicedetail WHERE invoice_id = 1486219 and line_id = 1
SELECT  *  FROM    billing WHERE invoice_code = '528375' and line_id = 1
SELECT  *  FROM    billing where receipt_id = 604036 and company_id = 44 and line_id = 1 and price_id = 1
SELECT  *  FROM    billingdetail where billing_uid = 11128984

SELECT  TOP 10 *  FROM    billingcomment

SELECT  *  FROM    invoicedetail WHERE invoice_id = 1486219 and qty_ordered = 270

SELECT  *  FROM    billing WHERE receipt_id = 604036 and company_id = 44 and line_id = 9
SELECT  *  FROM    billingdetail where billing_uid = 11128992

SELECT  *  FROM    invoiceheader WHERE invoice_id = 1554597

************************************************************************************ */


-- debuggery:
-- declare @invoice_code_list varchar(max) = 'Preview_1554597'

declare @invoicecode table (
	invoice_code varchar(16)
)

insert @invoicecode
select row from dbo.fn_SplitXsvText(',',1,@invoice_code_list)
where row is not null

select 
	ih.invoice_code as [INVOICE #]
	, case ih.status 
		when 'H' then 'Hold'
		when 'I' then 'Invoiced'
		when 'O' then 'Obsolete'
		when 'V' then 'Void'
	end as [INVOICE STATUS]
	, cb.project_name as [PROJECT NAME]
	, convert(varchar(10), bc.service_date, 101) as [SHIPMENT DATE]
	, convert(varchar(10), ih.due_date, 101) as [DUE DATE]
	, g.generator_region_code as [REGION]
	, g.generator_state as [STATE]
	, g.site_code as [LOC #]
	, g.generator_name as [LOCATION NAME]
	, id.line_desc_1 as [WASTE DESCRIPTION]
	, id.qty_ordered as [QTY]
	, id.bill_unit_code as [UNIT OF MEASURE]
	, convert(money, b.price 
		-	
		sum(
		case when p.regulated_fee = 'T' then bd.extended_amt / b.quantity else 0 end
		)) as [COST ($)]
 	, convert(money, (
 		b.price 
		-	
		sum(
		case when p.regulated_fee = 'T' then bd.extended_amt / b.quantity else 0 end
		)
	) * b.quantity) as [TOTAL COST ($)]
 	, convert(money, sum(
		case when p.regulated_fee = 'T' then bd.extended_amt else 0 end / b.quantity
	)) as [TAX ($)]
	, convert(money, sum(
		case when p.regulated_fee = 'T' then bd.extended_amt else 0 end
	)) as [TOTAL TAX ($)]
	, id.extended_amt as [FINAL ($)]
	, id.billing_date
	, id.line_id
from invoiceheader ih
join invoicedetail id on ih.invoice_id = id.invoice_id and ih.revision_id = id.revision_id
join customerbilling cb on ih.customer_id = cb.customer_id and id.billing_project_id = cb.billing_project_id
join generator g on id.generator_id = g.generator_id
left join billunit bu on id.bill_unit_code = bu.bill_unit_code
left join billing b
	on b.receipt_id = id.receipt_id
	and b.line_id = id.line_id
	and b.price_id = id.price_id
	and b.company_id = id.company_id
	and b.profit_ctr_id = id.profit_ctr_id
left join billingdetail bd
	on bd.billing_uid = b.billing_uid
left join product p
	on bd.product_id = p.product_id
	-- and bd.company_id = p.company_id
	-- and bd.profit_ctr_id = p.profit_ctr_id
	and bd.billing_type = 'Product'
left join billingcomment bc
	on bc.receipt_id = id.receipt_id
	and bc.company_id = id.company_id
	and bc.profit_ctr_id = id.profit_ctr_id
WHERE ih.invoice_code in (select invoice_code from @invoicecode)
and ih.customer_id = 601113 -- restrict this craziness to Costco
and ih.revision_id = (select max(revision_id) from invoiceheader where invoice_id = ih.invoice_id)
--and ih.status = 'I'
and isnull(id.ref_line_id, 0) = 0
GROUP BY 
	ih.invoice_code -- as [INVOICE #]
	, ih.status
	, cb.project_name
	, convert(varchar(10), bc.service_date, 101) -- as [SHIPMENT DATE]
	, convert(varchar(10), ih.due_date, 101) --as [DUE DATE]
	, g.generator_region_code --as [REGION]
	, g.generator_state --as [STATE]
	, g.site_code --as [LOC #]
	, g.generator_name --as [LOCATION NAME]
	, id.billing_date
	, id.line_id
	, id.line_desc_1 --as [WASTE DESCRIPTION]
	, id.qty_ordered --as [QTY]
	, id.bill_unit_code --as [UNIT OF MEASURE]
	, b.price
	, b.quantity
	, id.extended_amt --as [FINAL ($)]
	, b.billing_uid
ORDER BY 
	ih.invoice_code -- as invoice_description
	, g.site_code
	, id.billing_date
	, id.line_id
	, id.line_desc_1


go

grant execute on sp_eqip_Costco_Invoice_Detail to EQAI
go
grant execute on sp_eqip_Costco_Invoice_Detail to eqweb
go
grant execute on sp_eqip_Costco_Invoice_Detail to cor_user
go
