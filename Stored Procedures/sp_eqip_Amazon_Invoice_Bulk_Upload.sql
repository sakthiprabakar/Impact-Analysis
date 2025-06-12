-- 
drop proc if exists sp_eqip_Amazon_Invoice_Bulk_Upload
go

create proc sp_eqip_Amazon_Invoice_Bulk_Upload (
	@invoice_code_list	varchar(max) /* CSV and/or Ranges i.e.: 1,2, 3-5 ,8 */
)
as
/* ************************************************************************************
sp_eqip_Amazon_Invoice_Bulk_Upload

1/31/2020 The Amazon customer account requires invoices be submitted through their
	PayeeCentral web application.  Initial request on this was for an EDI formatted
	invoice but Amazon offered an alternative spec as well, which this report targets

SELECT  *  FROM    invoiceheader where customer_id = 15622 and invoice_date > '12/1/2019' ORDER BY invoice_date desc

SELECT  b.invoice_code  
FROM    billing b join billingdetail bd on b.billing_uid = bd.billing_uid
WHERE b.customer_id = 15622
and bd.billing_type like '%tax%'
order by invoice_date desc


SELECT  *  FROM    invoiceheader where invoice_code = '560255'

SELECT  bd.*  FROM    billing b join billingdetail bd on b.billing_uid = bd.billing_uid
WHERE b.invoice_code = '560255'

SELECT  *  FROM    product WHERE product_id in (1378, 1379)

ER invoices : 573649 and 578971
Service credits : 573645 and 582241

sp_eqip_Amazon_Invoice_Bulk_Upload @invoice_code_list = '573805, 573806, 573807, 573809, 573810, 573811, 576522'
sp_eqip_Amazon_Invoice_Bulk_Upload @invoice_code_list = '573805, 573806,573807-576522'
sp_eqip_Amazon_Invoice_Bulk_Upload @invoice_code_list = '573805'
sp_eqip_Amazon_Invoice_Bulk_Upload @invoice_code_list = '618535-618614'

-- Dev 5/10/2023
sp_eqip_Amazon_Invoice_Bulk_Upload @invoice_code_list = '909169, 909170, 909171, 909172, 909173, 909174, 909175, 909176, 909177, 909178, 909179, 909180, 909181, 909182, 909183, 909184, 909185, 909186, 909187, 909188'

SELECT  * FROM    invoiceheader where invoice_code = '610001'
SELECT  * FROM    invoicedetail where invoice_id = 1574562 and receipt_id = 2097675


SELECT  * FROM    invoiceheader WHERE invoice_code = '572122'
SELECT  * FROM    invoicedetail where invoice_id = 1531431 and revision_id = 1 -- and line_id = 6
SELECT  bd.* FROM    billing b join billingdetail bd on b.billing_uid = bd.billing_uid 
WHERE b.invoice_code = '572122'  
and b.line_id = 6

sp_eqip_Amazon_Invoice_Bulk_Upload @invoice_code_list = '528958, 528959, 528960, 529350, 529351, 529352, 529353, 529354, 529355'
SELECT  *  FROM    sysobjects where name like '%xsv%'

select bu.bill_unit_desc, count(*), max(ih.invoice_date) from invoiceheader ih join invoicedetail id on ih.invoice_id = id.invoice_id and ih.revision_id = id.revision_id
join billunit bu on id.bill_unit_code = bu.bill_unit_code
WHERE ih.customer_id = 15622
GROUP BY b
ORDER BY bill_unit_desc

Notes 4/20
	Use 'EACH' as unit?
	Use UOM?
	Maybe maintain a mapping of ours|theirs terms (Week|Weekly) etc
	
Notes 4/27
	Code the top 20 into a table in the SP
	Anything else gets converted to 'Each' in the export
	The original unit should get added into the line description text		

Notes 4/1/2021

	generator.market_code will have  #nn number suffix to strip.

	ER pickups only have 1 PO, so line number should always be 1
	So when the billing project says Emergency Response, always use 1 as po line number

	When there's no generator market code (or it's blank) set the po line number to 1
	
	When there's no # in a number, charindex() returns 0, then -1 yields an invalid input for left().
		So we'll always append a # to the end.

	declare @a varchar(20) = 'PO-12345#1000#'
	select @a, charindex('#', @a)
	,left(@a, charindex('#', @a)-1)


	sp_eqip_Amazon_Invoice_Bulk_Upload @invoice_code_list = '676149,676150,675384,675385,675433,670999,667223,666537,665316,665352,662536,664018,664039,,664163,660962,661318'
	
	
	************************************************************************************ */
	
	
	/*
	From: Jonathan Broome 
	Sent: Friday, June 5, 2020 5:55 PM
	To: Mara Poe <Mara.Poe@usecology.com>; Amazon Mailbox <amazon@usecology.com>
	Cc: Jeffrey Smith <Jeff.Smith@usecology.com>; 
		Paul Kalinka (Paul.Kalinka@usecology.com) <Paul.Kalinka@usecology.com>
	Subject: RE: Amazon Bulk Invoice Call Notes
	
	I’ve come across something hard to reconcile for Amazon… 
	Our line charge X tax rate =/= Our tax charge.
	
	This is because taxes are charged by multiple facilities and added together.
	
	Paul: Amazon wants an excel list version of our invoice, listing line items 
	they’re charged for, where Tax Percent and Tax Total are just cells on on 
	each service/disposal excel line.  Our Invoices list Taxes as a separate 
	line item instead, so I’m having to do some hoop-jumping to accomplish the 
	required format.
	
	Say we have a line (invoice 572122, receipt 27-0:158775-6-1) where the line 
	net total comes to $67.00
	The next invoice line (Taxes) has an amount of $4.62.  The Tax rate charged 
	was 6.35%
	
	67 x 0.0635 = 4.2545  … NOT 4.62.
	
	Where does 4.62 come from?  Well that tax was charged on 4 separate 
	component parts of the total spread across both 27-0 and 15-0, and 
	added all together.
	
	I suspect Amazon’s validation will reject the spreadsheet because the 
	math won’t add up correctly.  
	They already reject it when Qty X Unit Cost =/= line total.
	
	Have we had to reconcile or explain to them previously, or for 
	anyone else?  How do I list these fields in a way they’ll accept? 
	
	•	Quantity  (50)
	•	Unit Price (1.34)
	•	Line Net Amount (67)
	•	Tax Rate (6.35)
	•	Tax Total (4.62)
	
	Jonathan
	
	
	Paul's response (summarized):
	
		Yes, it's probably wrong.  Try it anyway.



2023-05-10 JPB	DO-65422 - Reversing history now - Request for taxes to reappear at the line level.



SELECT  id.* 
FROM    invoiceheader ih
join invoicedetail id on ih.invoice_id = id.invoice_id
and ih.revision_id = id.revision_id
WHERE ih.invoice_code = '572122'
and id.company_id = 27
and id.receipt_id = 158775
and id.line_id = 6
-- 1

*/

/*
-- debuggery:
-- declare @invoice_code_list varchar(max) = '562203, 562204, 562205, 562206, 562207, 562208, 562209, 562210, 562211, 564739, 564740'
-- declare @invoice_code_list varchar(max) = '572122'
declare @invoice_code_list varchar(max) = '618535-618614'
-- Spiffy range handling for inputs like '1030086-1030087,1031128-1031129,1031614-1031615,1031986'
*/
/*
-- encapsulated in fn_parseRanges...

	declare @tbl TABLE (
		rangeStart    varchar(max) NOT NULL,
		rangeEnd      varchar(max) NOT NULL
		-- ,    PRIMARY KEY CLUSTERED (rangeStart, rangeEnd)
	)

	declare @range varchar(max) = @invoice_code_list;

    WITH ranges ([range], remain)
    AS (
        --- This is the anchor of the recursive CTE:
        SELECT
            CAST(NULL AS varchar(max)) AS [range],
            @range AS remain
        UNION ALL
        SELECT
            --- This is the first remaining range:
            CAST(LEFT(remain, CHARINDEX(',', remain+',')-1)
                AS varchar(max)) AS [range],
            --- This is the remainder of the string:
            SUBSTRING(remain, CHARINDEX(',', remain+',')+1,
                LEN(remain)) AS remain
        FROM ranges
        WHERE remain!='')

    --- Output each range into @tbl:
    INSERT INTO @tbl (rangeStart, rangeEnd)
    SELECT DISTINCT
        --- The start of the range:
        LEFT([range], CHARINDEX('-', [range]+'-')-1),
        --- ... and the end of the range:
        SUBSTRING([range], CHARINDEX('-', [range])+1,
            LEN([range]))
    FROM ranges
    WHERE [range]!='';


6/15/2023 2 problems spotted
	1. Haz/Perp Surcharges were repeating the tax amt from the line they refer to.
	2. E/I/R fees not included in any line output.


	1. Haz/Perp.. find some:

		SELECT  * FROM    invoiceheader ih 
		where customer_id = 15622
		and status = 'I'
		and exists (select 1 from invoicedetail where invoice_id = ih.invoice_id and line_desc_1 = 'Hazardous Surcharge Pound')
		and exists (select 1 from invoicedetail where invoice_id = ih.invoice_id and line_desc_1 = 'NY Sales Tax - Monroe County')
		and exists (select 1 from invoicedetail where invoice_id = ih.invoice_id and line_desc_1 = 'Perpetual Care Pound')
		ORDER BY invoice_date desc

		What detail in the invoicedetail line for such a "fee" is identifiable?
		SELECT  * FROM    invoicedetail where company_id = 21 and profit_ctr_id = 0 and receipt_id = 2231600 and line_id = 1 and price_id = 1
		--well, location_code = 'EQAI-SR' but not really anything else.

						select distinct bd.* -- avg(applied_percent)
						from billing b (nolock) join billingdetail bd (nolock) on b.billing_uid = bd.billing_uid
						where 
						bd.receipt_id = 2231600 -- id.receipt_id
						and bd.line_id = 1 -- id.line_id
						and bd.price_id = 1 -- id.price_id
						and bd.company_id = 21 -- id.company_id
						and bd.profit_ctr_id = 0 -- id.profit_ctr_id
						-- and bd.billing_type like '%tax%'
						-- and id.extended_amt > 0

	2. E/I/R fees... 
		SELECT  total_amt_energy, * FROM    InvoiceHeader where invoice_code = '917901'
		SELECT  * FROM    InvoiceDetail where invoice_id = 1921680
		SELECT  * FROM    InvoiceBillingDetail where invoice_id = 1921680
			and billing_type like '%energy%'
			-- 2.990000

		SELECT  * FROM    product where product_id = 1370

		select distinct -- id.*--, 
		id.sequence_id,
		b.*,
		bd.* -- avg(applied_percent)
		from invoiceheader ih
		join invoicedetail id
			on ih.invoice_id = id.invoice_id and ih.revision_id = ih.revision_id
		join billing b (nolock) 
		on b.receipt_id = id.receipt_id
		and b.line_id = id.line_id
		and b.price_id = id.price_id
		and b.company_id = id.company_id
		and b.profit_ctr_id = id.profit_ctr_id
		join billingdetail bd (nolock) 
		on b.billing_uid = bd.billing_uid
		where ih.invoice_code = '917901'
		ORDER BY id.sequence_id


	500.390000
	546.790000
	546.790000

	465.360000
	40.150000
	505.510000

	861.990000
	68.990000
	930.980000

	917844
	2441.470000
	213.630000
	2655.100000

7/23/2023 Changes to
	1. First Attachment Name (invoice code, revision).pdf
	2. First Attachment Description - hard coded
	3. Invoice Description
	4. PO Line Number

sp_eqip_Amazon_Invoice_Bulk_Upload 
	@invoice_code_list	= '917288, 917287, 917286'

*/

set nocount on

-- Note, the parseRanges function REALLY doesn't like spaces in its list.
set @invoice_code_list = replace(@invoice_code_list, ' ', ',')
-- Ha, removed spaces.

declare @invoicecode table (
	invoice_code varchar(16)
	, transaction_list	varchar(max)
	, min_time_in	datetime
	, max_time_out	datetime
	, po_number		varchar(20)
)

insert @invoicecode (invoice_code)
SELECT ih.invoice_code
from InvoiceHeader ih
join dbo.fn_parseRanges(@invoice_code_list) ranges
on ih.invoice_code between ranges.rangeStart and ranges.rangeEnd
WHERE customer_id = 15622
and status = 'I'

update @invoicecode
set transaction_list =
	substring(
		(
			select distinct ', ' + convert(varchar(2), company_id) + '-' + convert(varchar(2), profit_ctr_id)
			+ ' ' + trans_source + ':' + convert(varchar(20), receipt_id)
			from invoiceheader ih (nolock)
			join invoicedetail id (nolock) on ih.invoice_id = id.invoice_id and ih.revision_id = id.revision_id
			where ih.invoice_code = ic.invoice_code
			order by ', ' + convert(varchar(2), company_id) + '-' + convert(varchar(2), profit_ctr_id)
			+ ' ' + trans_source + ':' + convert(varchar(20), receipt_id)
			for xml path, TYPE).value('.[1]','nvarchar(max)'

		)
	, 2, 20000)
from @invoicecode ic

update @invoicecode
set min_time_in = x.min_time_in
, max_time_out = x.max_time_out
, po_number = x.min_po_number
from @invoicecode ic
join (
select ic.invoice_code, min(id.time_in) min_time_in, max(id.time_out) max_time_out, min(id.purchase_order) min_po_number
from @invoicecode ic
join invoiceheader ih on ic.invoice_code = ih.invoice_code and ih.status = 'I'
join invoicedetail id on ih.invoice_id = id.invoice_id and ih.revision_id = id.revision_id
GROUP BY ic.invoice_code
) x
on ic.invoice_code = x.invoice_code


declare @MostCommonUnits table (
	bill_unit_code		varchar(4),
	amazon_unit_code			varchar(20)
)

insert @MostCommonUnits
	select 'LBS', null union
	select 'EACH', null union
	select 'TONS', null union
	select 'DM55', 'DRUM' union
	select 'DM05', 'DRUM' union
	select 'LOAD', null union
	select 'HOUR', null union
	select 'DM30', 'DRUM' union
	select 'UNIT', null union
	select 'BOX', null union
	select 'DAY', null union
	select 'CYSM', 'CYLINDER' union
	select 'DM15', 'DRUM' union
	select 'BAG', null union
	select 'MILE', null union
	select 'DM20', 'DRUM' union
	select 'BALE', null union
	select 'GAL', null union
	select 'DM10', 'DRUM' union
	select 'CYMD', 'CYLINDER'


declare @i_desc table (
	invoice_code varchar(16)
	, transaction_list	varchar(max)
	, t_len			int
	, invoice_id	int
	, revision_id	int
	, sequence_id	int
	, trans_source	char(1)
	, company_id	int
	, profit_ctr_id	int
	, receipt_id	int
	, line_id		int
	, price_id		int
	, transaction_id	varchar(max)
	, id_len		int
	, description	varchar(max)
	, d_len			int
)

insert @i_desc
select
	ic.invoice_code
	, ic.transaction_list
	, len(ic.transaction_list)
	, id.invoice_id
	, id.revision_id
	, id.sequence_id
	, id.trans_source
	, id.company_id
	, id.profit_ctr_id
	, id.receipt_id
	, id.line_id
	, id.price_id
	, '  | Line ' + convert(varchar(10), id.line_id) + 
			+ ' - '
			+ convert(varchar(2), id.company_id) + '-' + convert(varchar(2), id.profit_ctr_id)
				+ ' ' + id.trans_source + ':' + convert(varchar(20), id.receipt_id)
				+ '-' + convert(varchar(5), id.line_id) + '-' + convert(varchar(5), id.price_id)
			+ case when isnull(id.ref_line_id, 0) > 0 then ' (refers to '
				+ convert(varchar(2), id.company_id) + '-' + convert(varchar(2), id.profit_ctr_id)
					+ ' ' + id.trans_source + ':' + convert(varchar(20), id.receipt_id)
					+ '-' + convert(varchar(5), id.ref_line_id) + '-' + convert(varchar(5), id.price_id)
				+ ')'
				else '' end
			+ isnull(' | bill unit: ' + id.bill_unit_code, '')
	, 0
	, ltrim(rtrim(isnull(id.line_desc_1, '') + ' ' + isnull(id.line_desc_2, ''))) 
	, 0
from @invoicecode ic
join invoiceheader ih (nolock) on ic.invoice_code = ih.invoice_code
join invoicedetail id (nolock) on ih.invoice_id = id.invoice_id and ih.revision_id = id.revision_id
WHERE ih.status = 'I'

update @i_desc
set id_len = len(transaction_id)
	, d_len = len(description)
	
/*	
SELECT  * FROM    @i_desc
ORDER BY 
	invoice_id
	, revision_id
	, sequence_id
	, trans_source
	, company_id
	, profit_ctr_id
	, receipt_id
	, line_id
	, price_id
*/

--- sp_columns invoiceheader
--- sp_columns invoicedetail

set nocount off

select  
dense_rank() over (order by [Invoice Number]) as [Sequence Number]
, *
FROM (
	select
--	dense_rank() over (order by ih.invoice_code) as [Sequence Number]
	ih.invoice_code as [Invoice Number]
	, coalesce(
		(select top 1 PO_description from CustomerBillingPO where customer_id = ih.customer_id and billing_project_id = id.billing_project_id
			and purchase_order = id.purchase_order
		)
		, ltrim(left(isnull(com.comment_1, '') , 256 - (len(isnull(com.comment_1, '') ) + icd.t_len)) + '  ' + ic.transaction_list)
		)
		as [Invoice Description]
	, convert(varchar(10), ih.invoice_date, 101) as [Invoice Date]
	, convert(varchar(10), ic.min_time_in, 101) as [Service Period Start Date]
	, convert(varchar(10), ic.max_time_out, 101) as [Service Period End Date]
	, convert(varchar(10), id.time_in, 101) as [Date of Supply]
	, ih.currency_code as [Invoice Currency]
	, ih.total_amt_due as [Invoice Total Amount]
	, c.cust_name as [Bill to Entity Name]
	, 'US' as [Bill To Address Country/Region Code]
	, left(cust_country, 2) as [Ship To Address Country/Region Code]
	, 'US Ecology, Inc' as [Payee Entity Name]
	, 'US' as [Payee Address Country/Region Code]
	, 'STANDARD' as [Invoice Type]
	, '' as [Reference Invoice Number]
	, 'ITEM' as [Line Type]
	, 'SERVICES' as [Line Category]
	-- , id.purchase_order as [PO Number]
	, [PO Number] = case when (bp.project_name like '%Emergency Response%' or bp.project_name like '%ER Response%') then id.purchase_order
		else
			left(isnull(nullif(id.purchase_order,''),'1')+'#', charindex('#', isnull(nullif(id.purchase_order,''),'1')+'#')-1)
		end
	, ltrim(left(icd.description, 256-(icd.d_len + icd.id_len))) + icd.transaction_id	as [Line Description]
	, [Amazon PO Line Number] = case when (bp.project_name like '%Emergency Response%' or bp.project_name like '%ER Response%') then 1
		else
			coalesce(
				(select top 1 Release from CustomerBillingPO where customer_id = ih.customer_id and billing_project_id = id.billing_project_id and purchase_order = id.purchase_order)
				,(left(isnull(nullif(g.generator_market_code,''),'1')+'#', charindex('#', isnull(nullif(g.generator_market_code,''),'1')+'#')-1))
			)
		end
	, '' as [Vendor Part Number]
	, id.qty_ordered as [Invoiced Quantity]
	, case when bu.bill_unit_code in (select bill_unit_code from @MostCommonUnits)
		then
			isnull(mcu.amazon_unit_code, bu.bill_unit_desc )
		else 'Each'
		end as [Unit of Measure]
	, id.unit_price as [Unit Price]	
	, id.extended_amt  as [Line Net Amount]
		--- , sum(case when bd.billing_type not like '%tax%' then bd.extended_amt else 0 end) as [Line Net Amount]
		
		-- when these are 0, convert them to null and report NO in is_tax_applicable.
		-- when these are non-0, is_tax_applicable should be YES
		
		, isnull(nullif(
				format(
					(
						select avg(applied_percent)
						from billing b (nolock) join billingdetail bd (nolock) on b.billing_uid = bd.billing_uid
						where 
						bd.receipt_id = id.receipt_id
						and bd.line_id = id.line_id
						and bd.price_id = id.price_id
						and bd.company_id = id.company_id
						and bd.profit_ctr_id = id.profit_ctr_id
						and bd.billing_type like '%tax%'
						and id.extended_amt > 0
						and ltrim(left(icd.description, 256-(icd.d_len + icd.id_len))) + icd.transaction_id not like 'Hazardous Surcharge Pound%'
						and ltrim(left(icd.description, 256-(icd.d_len + icd.id_len))) + icd.transaction_id not like 'Perpetual Care Pound%'
					)
					, 'N')
				, '0.00'), '') as [Line Tax Percentage]
		/*
		, case when sum(case when bd.billing_type like '%tax%' then bd.extended_amt else 0 end) > 0 then 
			isnull(nullif(
				format(
					((sum(case when bd.billing_type like '%tax%' then bd.extended_amt else 0 end) / sum(case when bd.billing_type not like '%tax%' then bd.extended_amt else 0 end) ) * 100)
					, 'N')
				, '0.00'), '') 
		else '' 
		end as [Line Tax Percentage]
		*/


		, isnull(nullif(
			format(
				(
					select sum(extended_amt)
					from invoicedetail bd (nolock) 
					where 
					bd.invoice_id = id.invoice_id
					and bd.revision_id = id.revision_id
					and bd.receipt_id = id.receipt_id
					and bd.line_id = id.line_id
					and bd.price_id = id.price_id
					and bd.company_id = id.company_id
					and bd.profit_ctr_id = id.profit_ctr_id
					and bd.location_code like '%tax%'
					and bd.extended_amt > 0
						and ltrim(left(icd.description, 256-(icd.d_len + icd.id_len))) + icd.transaction_id not like 'Hazardous Surcharge Pound%'
						and ltrim(left(icd.description, 256-(icd.d_len + icd.id_len))) + icd.transaction_id not like 'Perpetual Care Pound%'
				)
			, 'N')
			, '0.00'), '') as [Line Tax Amount]

		/*
		, case when sum(case when bd.billing_type like '%tax%' then bd.extended_amt else 0 end) > 0 then 
			isnull(nullif(
				format(sum(case when bd.billing_type like '%tax%' then bd.extended_amt else 0 end), 'N')
				, '0.00'), '') 
		else ''
		end as [Line Tax Amount]
		*/

		, case when exists (
			select top 1 1 
			from billingdetail bd (nolock) 
			where bd.receipt_id = id.receipt_id
			and bd.line_id = id.line_id
			and bd.price_id = id.price_id
			and bd.company_id = id.company_id
			and bd.profit_ctr_id = id.profit_ctr_id
			and bd.billing_type like '%tax%'
			and bd.extended_amt > 0
						and ltrim(left(icd.description, 256-(icd.d_len + icd.id_len))) + icd.transaction_id not like 'Hazardous Surcharge Pound%'
						and ltrim(left(icd.description, 256-(icd.d_len + icd.id_len))) + icd.transaction_id not like 'Perpetual Care Pound%'
			) then
				'YES' 
			else 
				'NO' 
			end as [Is Tax Applicable]
			, 'Invoice-' + ih.invoice_code + '-' + RIGHT('00' + convert(varchar(3), ih.revision_id),2) + '.pdf' as [First Attachment Name]
			, 'Invoice PDF' as [First Attachment Description]

	/*
	, case when sum(case when bd.billing_type like '%tax%' then bd.extended_amt else 0 end) > 0 then 'YES' else 'NO' end as [Is Tax Applicable]
	*/
	--, ih.invoice_id
	--, ih.revision_id


-- Additional debug info not part of Amazon spec:
	, id.sequence_id
--	,bd.billing_type
	, id.trans_source
	,id.company_id
	,id.profit_ctr_id
	,id.receipt_id
	,id.line_id
	,id.price_id

	
from @invoicecode ic
join invoiceheader ih (nolock) on ic.invoice_code = ih.invoice_code
join invoicedetail id (nolock) on ih.invoice_id = id.invoice_id and ih.revision_id = id.revision_id
	and id.location_code not like '%tax%'
left join invoicecomment com (nolock) on ih.invoice_id = com.invoice_id and ih.revision_id = com.revision_id
	and id.company_id = com.company_id
	and id.profit_ctr_id = com.profit_ctr_id
	and id.trans_source = com.trans_source
	and id.receipt_id  = com.receipt_id
join @i_desc icd on id.invoice_id = icd.invoice_id and id.revision_id = icd.revision_id
	and id.sequence_id = icd.sequence_id
	and id.trans_source = icd.trans_source
	and id.company_id = icd.company_id
	and id.profit_ctr_id = icd.profit_ctr_id
	and id.receipt_id = icd.receipt_id
	and id.line_id = icd.line_id
	and id.price_id = icd.price_id
join customer c (nolock) on ih.customer_id = c.customer_id
join generator g (nolock) on id.generator_id = g.generator_id
left join billunit bu (nolock) on id.bill_unit_code = bu.bill_unit_code
LEFT JOIN @MostCommonUnits mcu
	on bu.bill_unit_code = mcu.bill_unit_code
left join customerbilling bp (nolock)
	on ih.customer_id = bp.customer_id
	and id.billing_project_id = bp.billing_project_id
WHERE ih.status = 'I'
--and bd.billing_type not in ('State-Haz', 'State-Perp')
GROUP BY 
	-- rank() over (order by ih.invoice_code, id.sequence_id) as sequence_number
	id.invoice_id
	, id.revision_id
	, id.sequence_id
	, ih.invoice_code -- as invoice_number
	, ih.revision_id
	, ih.customer_id
	, id.billing_project_id, id.purchase_order
	, bp.project_name
	, g.generator_market_code
	, id.purchase_order
	, ltrim(left(isnull(com.comment_1, '') , 256 - (len(isnull(com.comment_1, '') ) + icd.t_len)) + '  ' + ic.transaction_list) -- as invoice_description
	, convert(varchar(10), ih.invoice_date, 101) -- as invoice_date
	, convert(varchar(10), ic.min_time_in, 101) -- as service_period_start_date
	, convert(varchar(10), ic.max_time_out, 101) -- as service_period_end_date
	, convert(varchar(10), id.time_in, 101) -- as date_of_supply
	, ih.currency_code -- as invoice_currency
	, ih.total_amt_due -- as invoice_total_amount
	, c.cust_name -- as bill_to_entity_name
	-- , 'US' -- as bill_to_country_code
	, left(cust_country, 2) -- as ship_to_address_country_code
	--, 'US Ecology, Inc' -- as payee_entity_name
	--, 'US' -- as payee_address_country_code
	--, 'STANDARD' -- as invoice_type
	--, '' -- as reference_invoice_number
	--, 'ITEM' -- as line_type
	--, 'SERVICE' -- as line_category
	--, id.purchase_order -- as po_number
	, case when (bp.project_name like '%Emergency Response%' or bp.project_name like '%ER Response%') then id.purchase_order
		else
			left(isnull(nullif(id.purchase_order,''),'1')+'#', charindex('#', isnull(nullif(id.purchase_order,''),'1')+'#')-1)
		end
	, ltrim(left(icd.description, 256-(icd.d_len + icd.id_len))) + icd.transaction_id -- as line_description
	, case when (bp.project_name like '%Emergency Response%' or bp.project_name like '%ER Response%') then 1
		else
			left(isnull(nullif(g.generator_market_code,''),'1')+'#', charindex('#', isnull(nullif(g.generator_market_code,''),'1')+'#')-1)
		end
	-- , '' -- as vendor_part_number
	, id.qty_ordered -- as invoiced_quantity
	, bu.bill_unit_code
	, isnull(mcu.amazon_unit_code, bu.bill_unit_desc )-- as unit_of_measure
	, id.unit_price -- as unit_price	
	, id.extended_amt  -- as [Line Net Amount]
	-- , sum(case when bd.billing_type not like '%tax%' then bd.extended_amt else 0 end) as line_net_amount
	-- , (sum(case when bd.billing_type like '%tax%' then bd.extended_amt else 0 end) / sum(case when bd.billing_type not like '%tax%' then bd.extended_amt else 0 end) ) * 100 as line_tax_percentage
	-- , sum(case when bd.billing_type like '%tax%' then bd.extended_amt else 0 end) as line_tax_amount
	-- , case when sum(case when bd.billing_type like '%tax%' then bd.extended_amt else 0 end) > 0 then 'YES' else 'NO' end as is_tax_applicable
	--, ih.invoice_id
	--, ih.revision_id
	,id.trans_source
	,id.company_id
	,id.profit_ctr_id
	,id.receipt_id
	,id.line_id
	,id.price_id

	UNION ALL

select
--	dense_rank() over (order by ih.invoice_code) as [Sequence Number]
	ih.invoice_code as [Invoice Number]
	, coalesce(
		(select top 1 PO_description from CustomerBillingPO where customer_id = ih.customer_id and billing_project_id = id.billing_project_id
			and purchase_order = id.purchase_order
		)
		, ltrim(left(isnull(com.comment_1, '') , 256 - (len(isnull(com.comment_1, '') ) + icd.t_len)) + '  ' + ic.transaction_list)
		)
		as [Invoice Description]
	, convert(varchar(10), ih.invoice_date, 101) as [Invoice Date]
	, convert(varchar(10), ic.min_time_in, 101) as [Service Period Start Date]
	, convert(varchar(10), ic.max_time_out, 101) as [Service Period End Date]
	, convert(varchar(10), id.time_in, 101) as [Date of Supply]
	, ih.currency_code as [Invoice Currency]
	, ih.total_amt_due as [Invoice Total Amount]
	, c.cust_name as [Bill to Entity Name]
	, 'US' as [Bill To Address Country/Region Code]
	, left(cust_country, 2) as [Ship To Address Country/Region Code]
	, 'US Ecology, Inc' as [Payee Entity Name]
	, 'US' as [Payee Address Country/Region Code]
	, 'STANDARD' as [Invoice Type]
	, '' as [Reference Invoice Number]
	, 'ITEM' as [Line Type]
	, 'SERVICES' as [Line Category]
	-- , id.purchase_order as [PO Number]
	, [PO Number] = case when (bp.project_name like '%Emergency Response%' or bp.project_name like '%ER Response%') then id.purchase_order
		else
			left(isnull(nullif(id.purchase_order,''),'1')+'#', charindex('#', isnull(nullif(id.purchase_order,''),'1')+'#')-1)
		end
	, ltrim(left(p.description, 256-(icd.d_len + icd.id_len))) + icd.transaction_id	as [Line Description]
	, [Amazon PO Line Number] = case when (bp.project_name like '%Emergency Response%' or bp.project_name like '%ER Response%') then 1
		else
			coalesce(
				(select top 1 Release from CustomerBillingPO where customer_id = ih.customer_id and billing_project_id = id.billing_project_id and purchase_order = id.purchase_order)
				,(left(isnull(nullif(g.generator_market_code,''),'1')+'#', charindex('#', isnull(nullif(g.generator_market_code,''),'1')+'#')-1))
			)
		end
	, '' as [Vendor Part Number]
	, 1 as [Invoiced Quantity]
	, 'Each' as [Unit of Measure]
	, sum(ibd.extended_amt) as [Unit Price]	
	, sum(ibd.extended_amt) as [Line Net Amount]
		--- , sum(case when bd.billing_type not like '%tax%' then bd.extended_amt else 0 end) as [Line Net Amount]
		
		-- when these are 0, convert them to null and report NO in is_tax_applicable.
		-- when these are non-0, is_tax_applicable should be YES
		
		, '' as [Line Tax Percentage]
		/*
		, case when sum(case when bd.billing_type like '%tax%' then bd.extended_amt else 0 end) > 0 then 
			isnull(nullif(
				format(
					((sum(case when bd.billing_type like '%tax%' then bd.extended_amt else 0 end) / sum(case when bd.billing_type not like '%tax%' then bd.extended_amt else 0 end) ) * 100)
					, 'N')
				, '0.00'), '') 
		else '' 
		end as [Line Tax Percentage]
		*/


		, '' as [Line Tax Amount]

		/*
		, case when sum(case when bd.billing_type like '%tax%' then bd.extended_amt else 0 end) > 0 then 
			isnull(nullif(
				format(sum(case when bd.billing_type like '%tax%' then bd.extended_amt else 0 end), 'N')
				, '0.00'), '') 
		else ''
		end as [Line Tax Amount]
		*/

		, 'NO' as [Is Tax Applicable]
		, 'Invoice-' + ih.invoice_code + '-' + RIGHT('00' + convert(varchar(3), ih.revision_id),2) + '.pdf' as [First Attachment Name]
		, 'Invoice PDF' as [First Attachment Description]


	/*
	, case when sum(case when bd.billing_type like '%tax%' then bd.extended_amt else 0 end) > 0 then 'YES' else 'NO' end as [Is Tax Applicable]
	*/
	--, ih.invoice_id
	--, ih.revision_id


-- Additional debug info not part of Amazon spec:
--	,bd.billing_type
	, id.sequence_id
	, id.trans_source
	,id.company_id
	,id.profit_ctr_id
	,id.receipt_id
	,id.line_id
	,999999 price_id
	-- , ibd.billing_type
	-- , ibd.product_id

		--SELECT  * FROM    InvoiceDetail where invoice_id = 1921680
		--SELECT  * FROM    InvoiceBillingDetail where invoice_id = 1921680
		--	and billing_type like '%energy%'
		--select distinct billing_type from BillingDetail ORDER BY  billing_type
	
from @invoicecode ic
join invoiceheader ih (nolock) on ic.invoice_code = ih.invoice_code
join invoicedetail id (nolock) on ih.invoice_id = id.invoice_id and ih.revision_id = id.revision_id
	and id.location_code not like '%tax%'
join InvoiceBillingDetail ibd (nolock)
	on ibd.invoice_id = ih.invoice_id and ibd.revision_id = ih.revision_id
	and ibd.receipt_id = id.receipt_id
	and ibd.line_id = id.line_id
	and ibd.price_id = id.price_id
	and ibd.company_id = id.company_id
	and ibd.profit_ctr_id = id.profit_ctr_id
	and ibd.billing_type not in ('Disposal', 'Product', 'Retail', 'SalesTax', 'State-Haz', 'State-Perp', 'Wash', 'WorkOrder')
-- Energy
-- Insurance
join product p on ibd.product_id = p.product_id and ibd.company_id = p.company_ID and ibd.profit_ctr_id = p.profit_ctr_ID
left join invoicecomment com (nolock) on ih.invoice_id = com.invoice_id and ih.revision_id = com.revision_id
	and id.company_id = com.company_id
	and id.profit_ctr_id = com.profit_ctr_id
	and id.trans_source = com.trans_source
	and id.receipt_id  = com.receipt_id
join @i_desc icd on id.invoice_id = icd.invoice_id and id.revision_id = icd.revision_id
	and id.sequence_id = icd.sequence_id
	and id.trans_source = icd.trans_source
	and id.company_id = icd.company_id
	and id.profit_ctr_id = icd.profit_ctr_id
	and id.receipt_id = icd.receipt_id
	and id.line_id = icd.line_id
	and id.price_id = icd.price_id
join customer c (nolock) on ih.customer_id = c.customer_id
join generator g (nolock) on id.generator_id = g.generator_id
left join billunit bu (nolock) on id.bill_unit_code = bu.bill_unit_code
LEFT JOIN @MostCommonUnits mcu
	on bu.bill_unit_code = mcu.bill_unit_code
left join customerbilling bp (nolock)
	on ih.customer_id = bp.customer_id
	and id.billing_project_id = bp.billing_project_id
WHERE ih.status = 'I'
--and bd.billing_type not in ('State-Haz', 'State-Perp')
GROUP BY 
	-- rank() over (order by ih.invoice_code, id.sequence_id) as sequence_number
	id.invoice_id
	, id.revision_id
	, id.sequence_id
	, ih.invoice_code -- as invoice_number
	, ih.revision_id
	, ih.customer_id
	, id.billing_project_id
	, bp.project_name
	, g.generator_market_code
	, id.purchase_order
	, ltrim(left(isnull(com.comment_1, '') , 256 - (len(isnull(com.comment_1, '') ) + icd.t_len)) + '  ' + ic.transaction_list) -- as invoice_description
	, convert(varchar(10), ih.invoice_date, 101) -- as invoice_date
	, convert(varchar(10), ic.min_time_in, 101) -- as service_period_start_date
	, convert(varchar(10), ic.max_time_out, 101) -- as service_period_end_date
	, convert(varchar(10), id.time_in, 101) -- as date_of_supply
	, ih.currency_code -- as invoice_currency
	, ih.total_amt_due -- as invoice_total_amount
	, c.cust_name -- as bill_to_entity_name
	-- , 'US' -- as bill_to_country_code
	, left(cust_country, 2) -- as ship_to_address_country_code
	--, 'US Ecology, Inc' -- as payee_entity_name
	--, 'US' -- as payee_address_country_code
	--, 'STANDARD' -- as invoice_type
	--, '' -- as reference_invoice_number
	--, 'ITEM' -- as line_type
	--, 'SERVICE' -- as line_category
	--, id.purchase_order -- as po_number
	, case when (bp.project_name like '%Emergency Response%' or bp.project_name like '%ER Response%') then id.purchase_order
		else
			left(isnull(nullif(id.purchase_order,''),'1')+'#', charindex('#', isnull(nullif(id.purchase_order,''),'1')+'#')-1)
		end
	, ltrim(left(p.description, 256-(icd.d_len + icd.id_len))) + icd.transaction_id -- as line_description
	, case when (bp.project_name like '%Emergency Response%' or bp.project_name like '%ER Response%') then 1
		else
			left(isnull(nullif(g.generator_market_code,''),'1')+'#', charindex('#', isnull(nullif(g.generator_market_code,''),'1')+'#')-1)
		end
	-- , '' -- as vendor_part_number
	, id.qty_ordered -- as invoiced_quantity
	, bu.bill_unit_code
	, isnull(mcu.amazon_unit_code, bu.bill_unit_desc )-- as unit_of_measure
	, id.unit_price -- as unit_price	
	, id.extended_amt  -- as [Line Net Amount]
	-- , sum(case when bd.billing_type not like '%tax%' then bd.extended_amt else 0 end) as line_net_amount
	-- , (sum(case when bd.billing_type like '%tax%' then bd.extended_amt else 0 end) / sum(case when bd.billing_type not like '%tax%' then bd.extended_amt else 0 end) ) * 100 as line_tax_percentage
	-- , sum(case when bd.billing_type like '%tax%' then bd.extended_amt else 0 end) as line_tax_amount
	-- , case when sum(case when bd.billing_type like '%tax%' then bd.extended_amt else 0 end) > 0 then 'YES' else 'NO' end as is_tax_applicable
	--, ih.invoice_id
	--, ih.revision_id
	,id.trans_source
	,id.company_id
	,id.profit_ctr_id
	,id.receipt_id
	,id.line_id
	,id.price_id


) sources
	
ORDER BY 
	[Invoice Number] -- as invoice_description
	-- , id.sequence_id
	, trans_source
	, sequence_id
	, line_id
	, price_id
	--,id.company_id
	--,id.profit_ctr_id
	--,id.receipt_id
	--,id.line_id
	--,id.price_id


go

grant execute on sp_eqip_Amazon_Invoice_Bulk_Upload to eqai
go
grant execute on sp_eqip_Amazon_Invoice_Bulk_Upload to eqweb
go
grant execute on sp_eqip_Amazon_Invoice_Bulk_Upload to cor_user
go


