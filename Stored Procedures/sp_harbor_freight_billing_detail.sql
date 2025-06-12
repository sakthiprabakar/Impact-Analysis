
create proc sp_harbor_freight_billing_detail (
	@invoice_code	varchar(20)
)
as
/* *********************************************************************************
sp_harbor_freight_billing_detail

	Selects the data and groups it for a Harbor Freight formatted invoice on EQIP

History:
	2014-12-16	JPB	Created
	2017-11-29	JPB	GEM-45214 - add workorder_id and receipt_id to output, CSV receipt_id list if necessary.
						Turns out workorder_id could have multiple #'s too, also CSV.

Sample:
	sp_harbor_freight_billing_detail '370974'
	
	SELECT top 5* FROM invoiceheader where customer_id = 15551 order by invoice_date desc

********************************************************************************* */
SELECT 
	b.invoice_date
	, (
		select top 1
			case b1.trans_source
				when 'R' then (select max(date_act_arrive) from workorderstop s inner join billinglinklookup l on s.workorder_id = l.source_id and s.company_id = l.source_company_id and s.profit_ctr_id = l.source_profit_ctr_id where l.receipt_id = b1.receipt_id and l.company_id = b1.company_id and l.profit_ctr_id = b1.profit_ctr_id)
				when 'W' then (select max(date_act_arrive) from workorderstop s where s.workorder_id = b1.receipt_id and s.company_id = b1.company_id and s.profit_ctr_id = b1.profit_ctr_id)
				else null
			end as service_date
		from billing b1
		where b1.invoice_id = b.invoice_id
		and b1.generator_id = b.generator_id
	) as service_date
	,right('0000' + g.site_code, 4) as site_code
	,i.invoice_code
	, ltrim(rtrim(substring(
		(
		select distinct ', ' + convert(varchar(20), b2.receipt_id )
		from billing b2
		WHERE b2.invoice_id = b.invoice_id and b2.generator_id = b.generator_id
		and b2.trans_source = 'W'
		for xml path('')
		)
		, 2, 20000))) as workorder_id
	, ltrim(rtrim(substring(
		(
		select distinct ', ' + convert(varchar(20), b3.receipt_id )
		from billing b3
		WHERE b3.invoice_id = b.invoice_id and b3.generator_id = b.generator_id
		and b3.trans_source = 'R'
		for xml path('')
		)
		, 2, 20000))) as receipt_id
	,sum(case when bd.billing_type like '%tax%' then 0 else bd.extended_amt end) as store_subtotal
	,sum(case when bd.billing_type like '%tax%' then bd.extended_amt else 0 end) as tax
	,sum(bd.extended_amt) as store_total
FROM billing b
inner join invoiceheader i on b.invoice_id = i.invoice_id
left join generator g on b.generator_id = g.generator_id
inner join billingdetail bd on b.billing_uid = bd.billing_uid
where i.invoice_code = @invoice_code
group by
	b.invoice_date
	, b.invoice_id
	, b.generator_id
	, g.site_code
	, i.invoice_code
order by 
	g.site_code


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_harbor_freight_billing_detail] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_harbor_freight_billing_detail] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_harbor_freight_billing_detail] TO [EQAI]
    AS [dbo];

