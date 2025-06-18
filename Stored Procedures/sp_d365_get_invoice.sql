use Plt_ai
go

alter procedure [dbo].[sp_d365_get_invoice]
               @invoice_code varchar(10),
               @status char(1) = 'I',
               @accounting_date date = null
WITH RECOMPILE
as
/***************************************************************
Loads to:   Plt_AI

Called by D365InvoicePostSvcDragon to retrieve invoice data

exec dbo.sp_d365_get_invoice '949999'
exec dbo.sp_d365_get_invoice '9499998'
exec dbo.sp_d365_get_invoice '949788R02'
exec dbo.sp_d365_get_invoice '9497889R02'
exec dbo.sp_d365_get_invoice '9470549R03'

09/17/2019 RWB	Created
01/08/2020 RWB	This was developed to send only non-zero lines, but after some invoices with zero lines failed, I learned that we should be sending zero-valued lines.
01/08/2020 RWB	There is validation in D365 that does not allow zero amounts, so this is going back to the original version
10/06/2020 RWB	Added LINEITEMNUMBER to returned JSON
12/03/2020 RWB  Added INTEGRATIONKEY to returned JSON
09/08/2022 RWB  New JSON format to support multiple projects per invoice
10/18/2022 RWB	DO 49316 INVOICECOMPANY should now just be max LE, support multiple projects (--modified)
12/15/2022 RWB	DO 60167 Need to adjust logic previously deployed to take main account into account (--v2 modified)
08/23/2023 RWB  DO 71991 There was some hard-coding assuming 6 character root invoice_codes, modified to accomodate more
02/02/2024 RWB	DO 78521 Default currency_code to USD if all spaces
09/06/2024 RWB  Only create credit memos / reversals for monetary adjustments
01/22/2025 RWB  SN CHG0077693 Bug fix for revisions >= 3 generating incorrect CM code for prior monetary revisions

****************************************************************/
declare @max numeric (12,4), @le varchar(5), @bu varchar(5), @invoice_rev varchar(10), @json_rev varchar(max), @json_cur varchar(max), @json varchar(max),
        @multiplier int, @acct_date date, @invoice_id int, @revision_id int, @cm_revision_id int, @ax_header_uid int, @idx int

set transaction isolation level read uncommitted
set nocount on

--determine invoice_id
select @invoice_id = invoice_id
from AXInvoiceHeader
where ECOLINVOICEID = @invoice_code

--if we're searching for Completed, this is a reversal for prior version
set @multiplier = case @status when 'C' then -1 else 1 end

--if this is an adjustment, we need to generate reversal for prior revision
if @status <> 'C' and charindex('R',@invoice_code,1) > 0
begin
	set @idx = charindex('R',@invoice_code,1)

	if right(@invoice_code,2) = '02'
    begin
        set @cm_revision_id = 1
		set @invoice_rev = substring(@invoice_code,1,len(@invoice_code)-3)
    end
	else
    begin
		--set @invoice_rev = left(@invoice_code,@idx) + right('0' + convert(varchar(2),convert(int,right(@invoice_code,2)) - 1),2)
        select @cm_revision_id = max(revision_id)
        from InvoiceHeader ih
        where invoice_id = @invoice_id
        and revision_id < convert(int,right(@invoice_code,2))
        and coalesce(non_monetary_adj_flag,'F') <> 'T'
        and exists (select 1
                    from AXInvoiceExport e
                    join AXInvoiceHeader h
                        on h.axinvoiceheader_uid = e.axinvoiceheader_uid
                        and h.invoice_id = ih.invoice_id
                        and h.revision_id = ih.revision_id
                    where e.status = 'C'
                    )

        if coalesce(@cm_revision_id,0) = 1
		    set @invoice_rev = substring(@invoice_code,1,len(@invoice_code)-3)
        else
            set @invoice_rev = left(@invoice_code,@idx) + right('0' + convert(varchar(2),@cm_revision_id),2)
    end

    if coalesce(@cm_revision_id,0) > 0
    begin
        select @acct_date = convert(date,max(l.ACCOUNTINGDISTRIBUTION_ACCOUNTINGDATE))
        from AXInvoiceExport e
        join AXInvoiceHeader h
            on h.axinvoiceheader_uid = e.axinvoiceheader_uid
            and h.ECOLINVOICEID = @invoice_code
        join AXInvoiceLine l
            on l.axinvoiceheader_uid = h.axinvoiceheader_uid
        where e.status = @status

        create table #json (json varchar(max))

        insert #json
        exec dbo.sp_d365_get_invoice @invoice_rev, 'C', @acct_date

        select @json_rev = replace(substring(json,1,len(json)-1),':"' + @invoice_rev + '"', ':"' + @invoice_rev + 'CM"') + ']<reversalend>[' from #json

        drop table #json
    end
end

--if the invoice doesn't exist in the export tables, create records (copied from sp_ExportInvoices)
if not exists (select 1 from AXInvoiceHeader where ECOLINVOICEID = @invoice_code)
begin
	if charindex('R',@invoice_code,1) > 0
		set @revision_id = convert(int,right(@invoice_code,2))
	else
		set @revision_id = 1
		
	INSERT AXInvoiceHeader (invoice_id, revision_id, customer_id, ECOLINVOICEID, ORDERACCOUNT, CURRENCYCODE,
							INVOICEDATE, DUEDATE, DEFAULTDIMENSION, POSTINGPROFILE, INVOICEACCOUNT, PURCHORDERFORMNUM,
							CUSTOMERREF, PAYMENT, PAYMMODE, CASHDISCCODE, ECOLADJUSTMENTID, ECOLORIGINALINVOICEID,
							added_by, date_added, modified_by, date_modified)
	SELECT ih.invoice_id
		,  ih.revision_id
		,  ih.customer_id AS customer_id
		,  @invoice_code AS ECOLINVOICEID
		,  c.ax_customer_id AS ORDERACCOUNT
		,  ih.currency_code as CURRENCYCODE
		,  ih.invoice_date AS INVOICEDATE
		,  ih.due_date AS  DUEDATE
		,  '' AS DEFAULTDIMENSION
		,  'Default' AS POSTINGPROFILE
		,  c.ax_invoice_customer_id  AS INVOICEACCOUNT
		, (SELECT 
		  CASE WHEN 
		       ( SELECT count(Distinct isnull(nullif(purchase_order,''),'None'))
			     FROM InvoiceDetail 
			     WHERE invoice_id = ih.invoice_id
		         AND revision_id = 1) > 1 then 'Multiple'
		  ELSE ( SELECT Distinct isnull(nullif(purchase_order,''),'None')
		         FROM InvoiceDetail 
				 WHERE invoice_id = ih.invoice_id
		         AND revision_id = 1) END ) AS PURCHORDERFORMNUM
		,  ih.customer_release AS CUSTOMERREF
		,  at.AX_payment_term_id AS PAYMENT
		,  'CHK' AS PAYMMODE
		,  at.AX_cash_discount_code AS CASHDISCCODE
		,  case when @revision_id > 1 then @invoice_code else NULL end AS ECOLADJUSTMENTID
		--,  case when @revision_id > 1 then left(@invoice_code,6) + case when @revision_id = 2 then '' else right('0' + convert(varchar(2),@revision_id-1),2) end else NULL end AS ECOLORIGINALINVOICEID
		,  case when @revision_id > 1 then left(@invoice_code,charindex('R',@invoice_code,1)-1) + case when @revision_id = 2 then '' else 'R' + right('0' + convert(varchar(2),@revision_id-1),2) end else NULL end AS ECOLORIGINALINVOICEID
		,  'D365' AS added_by
		,  GETDATE() AS date_added
		,  'D365' AS modified_by
		,  GETDATE() AS date_modified
	FROM InvoiceHeader ih
	JOIN Customer c
		ON c.customer_id = ih.customer_id
	LEFT OUTER JOIN ARTerms at
		ON at.terms_code = ih.terms_code
	WHERE ih.invoice_code = left(@invoice_code,6)
	AND ih.revision_id = @revision_id

	set @ax_header_uid = @@IDENTITY
			     				     
	INSERT AXInvoiceLine (axinvoiceheader_uid, company_id, profit_ctr_id, CUSTINVOICELINE_LINENUM,
							CUSTINVOICELINE_DESCRIPTION, CUSTINVOICELINE_QUANTITY, CUSTINVOICELINE_UNITPRICE,
							CUSTINVOICELINE_AMOUNTCUR, CUSTINVOICELINE_PROJID, CUSTINVOICELINE_ECOLSOURCESYSTEM,
							CUSTINVOICELINE_ECOLSOURCETRANSACTIONTYPE, CUSTINVOICELINE_ECOLSOURCECOMPANY,
							CUSTINVOICELINE_ECOLSOURCEPROFITCENTER, CUSTINVOICELINE_ECOLSOURCETRANSACTIONID,
							CUSTINVOICELINE_ECOLMANIFEST, CUSTINVOICELINE_ECOLWASTESTREAM, CUSTINVOICELINE_LEDGERDIMENSION,
							CUSTINVOICELINE_PROJCATEGORYID, ACCOUNTINGDISTRIBUTION_ACCOUNTINGDATE,
							ACCOUNTINGDISTRIBUTION_LEDGERDIMENSION, ACCOUNTINGDISTRIBUTION_TRANSACTIONCURRENCYAMOUNT,
							added_by, date_added, modified_by, date_modified, currency_code)
	SELECT @ax_header_uid
		,  id.company_id
		,  id.profit_ctr_id
		,DENSE_RANK() OVER (ORDER BY ibd.company_id, ibd.profit_ctr_id, ibd.trans_source, ibd.receipt_id ,id.line_id, id.price_id) AS CUSTINVOICELINE_LINENUM
		,  id.line_desc_1  AS CUSTINVOICELINE_DESCRIPTION
		,  id.qty_ordered  AS CUSTINVOICELINE_QUANTITY 
		,CUSTINVOICELINE_UNITPRICE = (SELECT SUM (id2.unit_price) FROM InvoiceDetail id2
										WHERE ibd.invoice_id = id2.invoice_id
										AND ibd.revision_id = id2.revision_id
										AND id.company_id = id2.company_id
										AND id.profit_ctr_id = id2.profit_ctr_id
										AND ibd.trans_source = id2.trans_source
										AND id.receipt_id = id2.receipt_id 
										AND id.line_id = id2.line_id
										AND id.price_id = id2.price_id)
		, CUSTINVOICELINE_AMOUNTCUR = (SELECT SUM (ibd1.extended_amt) FROM InvoiceBillingDetail ibd1
						WHERE ibd.invoice_id = ibd1.invoice_id
						AND ibd.revision_id = ibd1.revision_id
						AND ibd.trans_source = ibd1.trans_source     
						AND id.receipt_id = ibd1.receipt_id 
						AND id.line_id = ibd1.line_id
						AND id.price_id = ibd1.price_id       
						AND id.company_id = ibd1.company_id
						AND id.profit_ctr_id = ibd1.profit_ctr_id) 
		,  dbo.fn_get_workorder_AX_dim5_project (ibd.company_id,ibd.profit_ctr_id,ibd.receipt_id ) AS	CUSTINVOICELINE_PROJID		
		,  'EQAI' AS CUSTINVOICELINE_ECOLSOURCESYSTEM	
		,   CASE ibd.trans_source 
			WHEN 'R' THEN 'Receipt'
			WHEN 'W' THEN 'Work Order'
			WHEN 'O' THEN 'Retail Order'
			ELSE ''
			END AS CUSTINVOICELINE_ECOLSOURCETRANSACTIONTYPE
		,  ibd.company_id AS CUSTINVOICELINE_ECOLSOURCECOMPANY	
		,  ibd.profit_ctr_id AS CUSTINVOICELINE_ECOLSOURCEPROFITCENTER	
		,  ibd.receipt_id AS CUSTINVOICELINE_ECOLSOURCETRANSACTIONID
		,  CASE ibd.trans_source 
			WHEN 'R' THEN b.manifest
			WHEN 'W' THEN dbo.fn_get_workorder_min_manifest (ibd.receipt_id, ibd.company_id, ibd.profit_ctr_id) 
			ELSE ''  
			END AS CUSTINVOICELINE_ECOLMANIFEST		
		,  id.approval_code AS CUSTINVOICELINE_ECOLWASTESTREAM		
		,  99999 AS	CUSTINVOICELINE_LEDGERDIMENSION		
		,  CASE WHEN dbo.fn_get_workorder_AX_dim5_project (ibd.company_id,ibd.profit_ctr_id,ibd.receipt_id ) <> '' THEN 'FTI IMPORT'
		   ELSE '' END  AS CUSTINVOICELINE_PROJCATEGORYID		
		, ih.applied_date  AS ACCOUNTINGDISTRIBUTION_ACCOUNTINGDATE
		,  CASE len(rtrim(ibd.AX_Dimension_5_Part_2))
		   WHEN  0 THEN
			   ibd.AX_MainAccount + '-' + ibd.AX_Dimension_1 + '-' + ibd.AX_Dimension_2 + '-' + ibd.AX_Dimension_3 + '-' +
			   ibd.AX_Dimension_4 + '-' + ibd.AX_Dimension_6 + '-' + ibd.AX_Dimension_5_Part_1
		   ELSE
			   ibd.AX_MainAccount + '-' + ibd.AX_Dimension_1 + '-' +
			   ibd.AX_Dimension_2 + '-' + ibd.AX_Dimension_3 + '-' +
			   ibd.AX_Dimension_4 + '-' + ibd.AX_Dimension_6 +  '-' +
			   ibd.AX_Dimension_5_Part_1 + '.' + ibd.AX_Dimension_5_Part_2   END AS ACCOUNTINGDISTRIBUTION_LEDGERDIMENSION	
		,  SUM(ibd.extended_amt) AS ACCOUNTINGDISTRIBUTION_TRANSACTIONCURRENCYAMOUNT
		,  'D365' AS added_by
		,  GETDATE() AS date_added
		,  'D365' AS modified_by
		,  GETDATE() AS date_modified
		,  ih.currency_code 
	FROM AXInvoiceHeader aih
	JOIN InvoiceHeader ih ON ih.invoice_id = aih.invoice_id
		AND ih.revision_id = aih.revision_id
	JOIN InvoiceBillingDetail ibd ON ibd.invoice_id = ih.invoice_id
		AND ibd.revision_id = ih.revision_id
	JOIN InvoiceDetail id ON id.invoice_id = ih.invoice_id
		AND id.revision_id = ih.revision_id
		AND id.receipt_id = ibd.receipt_id 
		AND id.line_id = ibd.line_id
		AND id.price_id = ibd.price_id
		AND id.company_id = ibd.company_id
		AND id.profit_ctr_id = ibd.profit_ctr_id
		AND id.location_code <> 'EQAI-TAX'
		AND id.location_code <> 'EQAI-SR'
	JOIN Customer c ON c.customer_id = ih.customer_id
	LEFT OUTER JOIN Billing b ON id.company_id = b.company_id
		AND id.profit_ctr_id = b.profit_ctr_id
		AND id.receipt_id = b.receipt_id
		AND id.line_id = b.line_id
		AND id.price_id = b.price_id
		AND b.trans_source = 'R'
	LEFT OUTER JOIN ARTerms at ON at.terms_code = ih.terms_code
	WHERE aih.axinvoiceheader_uid = @ax_header_uid
	GROUP BY ih.invoice_id
		  ,ih.invoice_code
		  ,ibd.revision_id
		  ,ibd.invoice_id 
		  ,ih.invoice_date
		  ,ibd.company_id
		  ,ibd.profit_ctr_id
		  ,ih.customer_id
		  ,c.ax_customer_id
		  ,c.ax_invoice_customer_id 
		  ,ibd.trans_source
		  ,ibd.receipt_id
		  ,b.manifest
		  ,ih.applied_date 
		  ,ih.due_date
		  ,ih.customer_po
		  ,ih.customer_release
		  ,ih.currency_code
		  ,at.AX_payment_term_id
		  ,id.line_id 
		  ,at.AX_cash_discount_code
		  ,id.line_desc_1
		  ,id.qty_ordered
		  ,id.receipt_id 
		  ,id.line_id
		  ,id.company_id 
		  ,id.profit_ctr_id   
		  ,id.unit_price
		  ,id.approval_code
		  ,id.price_id 
		  ,ibd.AX_MainAccount
		  ,ibd.AX_Dimension_1
		  ,ibd.AX_Dimension_2
		  ,ibd.AX_Dimension_3
		  ,ibd.AX_Dimension_4
		  ,ibd.AX_Dimension_6
		  ,ibd.AX_Dimension_5_Part_1
		  ,ibd.AX_Dimension_5_Part_2
	order By ih.customer_id,ibd.company_id,ibd.profit_ctr_id,ibd.trans_source,ibd.receipt_id 

	insert AXInvoiceExport (axinvoiceheader_uid, status, response_text, added_by, date_added, modified_by, date_modified)
	values (@ax_header_uid, 'C', 'SUCCESS: Fake export record for old invoice', 'D365', GETDATE(), 'D365', GETDATE())
end

--rollup by legal entity to determine max LE
select SUBSTRING(l.ACCOUNTINGDISTRIBUTION_LEDGERDIMENSION,7,3) as legal_entity, SUM(l.ACCOUNTINGDISTRIBUTION_TRANSACTIONCURRENCYAMOUNT) as total
into #rollup_le
from AXInvoiceExport e
join AXInvoiceHeader h
	on h.axinvoiceheader_uid = e.axinvoiceheader_uid
	and h.ECOLINVOICEID = @invoice_code
join AXInvoiceLine l
	on l.axinvoiceheader_uid = h.axinvoiceheader_uid
where e.status = @status
group by SUBSTRING(l.ACCOUNTINGDISTRIBUTION_LEDGERDIMENSION,7,3)

select @max = MAX(total) from #rollup_le
select @le = MIN(legal_entity) from #rollup_le where total = @max


--rollup by business unit to determine max BU
select SUBSTRING(l.ACCOUNTINGDISTRIBUTION_LEDGERDIMENSION,11,4) + '0' as business_unit, SUM(l.ACCOUNTINGDISTRIBUTION_TRANSACTIONCURRENCYAMOUNT) as total
into #rollup_bu
from AXInvoiceExport e
join AXInvoiceHeader h
	on h.axinvoiceheader_uid = e.axinvoiceheader_uid
	and h.ECOLINVOICEID = @invoice_code
join AXInvoiceLine l
	on l.axinvoiceheader_uid = h.axinvoiceheader_uid
where e.status = @status
and @le = case when COALESCE(l.CUSTINVOICELINE_PROJID,'') <> '' then SUBSTRING(l.CUSTINVOICELINE_PROJID,2,3) else SUBSTRING(l.ACCOUNTINGDISTRIBUTION_LEDGERDIMENSION,7,3) end
group by SUBSTRING(l.ACCOUNTINGDISTRIBUTION_LEDGERDIMENSION,11,4) + '0'

select @max = MAX(total) from #rollup_bu
select @bu = MIN(business_unit) from #rollup_bu where total = @max

drop table #rollup_bu
drop table #rollup_le

set @json_cur = (
select
	'Dragon' [ECOLSOURCE],
	@le [INVOICECOMPANY],
	'' [INTEGRATIONKEY],
	h.ECOLINVOICEID [ECOLINVOICEID],
	h.ORDERACCOUNT [ORDERACCOUNT],
	case COALESCE(TRIM(h.CURRENCYCODE),'') when '' then 'USD' else TRIM(h.CURRENCYCODE) end [CURRENCYCODE],
	CONVERT(date,h.INVOICEDATE) [INVOICEDATE],

	--doc says this needs to change, but this matches the description 
--	case when COALESCE(l.CUSTINVOICELINE_PROJID,'') <> '' then @le else SUBSTRING(l.ACCOUNTINGDISTRIBUTION_LEDGERDIMENSION,7,3) end [ECOLSOURCECOMPANY],
	SUBSTRING(l.ACCOUNTINGDISTRIBUTION_LEDGERDIMENSION,7,3) [ECOLSOURCECOMPANY],

	case when @accounting_date is null then CONVERT(date,l.ACCOUNTINGDISTRIBUTION_ACCOUNTINGDATE) else @accounting_date end [ACCOUNTINGDATE],
	COALESCE(h.CASHDISCCODE,'') [CASHDISCCODE],
	CONVERT(date,h.DUEDATE) [DUEDATE],
	h.PAYMENT [PAYMENT],
	h.PAYMMODE [PAYMMODE],
	h.POSTINGPROFILE [POSTINGPROFILE],

	--v2 modified
	case when convert(int,left(l.ACCOUNTINGDISTRIBUTION_LEDGERDIMENSION,5)) < 60000
		then ''
		else
		case when COALESCE(l.CUSTINVOICELINE_PROJID,'') <> '' then SUBSTRING(l.ACCOUNTINGDISTRIBUTION_LEDGERDIMENSION,1,5) + 'Fee' else '' end
	end [PROJCATEGORYID],

	--v2 modified
	case when convert(int,left(l.ACCOUNTINGDISTRIBUTION_LEDGERDIMENSION,5)) < 60000
		then ''
		else COALESCE(l.CUSTINVOICELINE_PROJID,'')
	end [PROJID],

	--v2 modified
	case when l.ACCOUNTINGDISTRIBUTION_LEDGERDIMENSION like '%-P%' and left(l.ACCOUNTINGDISTRIBUTION_LEDGERDIMENSION,1) = '6'
		then dbo.fn_convert_AX_gl_account_to_D365('60998' + SUBSTRING(l.ACCOUNTINGDISTRIBUTION_LEDGERDIMENSION,6,LEN(l.ACCOUNTINGDISTRIBUTION_LEDGERDIMENSION) - 5))
		else dbo.fn_convert_AX_gl_account_to_D365(l.ACCOUNTINGDISTRIBUTION_LEDGERDIMENSION)
	end [LEDGERDIMENSION],

	@bu + '---' ORDERACCOUNTDIMENSION,

	--v2 modified
	case when convert(int,left(l.ACCOUNTINGDISTRIBUTION_LEDGERDIMENSION,5)) < 60000
		then ''
		else
		case when COALESCE(l.CUSTINVOICELINE_PROJID,'') = '' then '' else SUBSTRING(dbo.fn_convert_AX_gl_account_to_D365(l.ACCOUNTINGDISTRIBUTION_LEDGERDIMENSION),7,LEN(dbo.fn_convert_AX_gl_account_to_D365(l.ACCOUNTINGDISTRIBUTION_LEDGERDIMENSION)) - 6) end
	end PROJACCOUNTDIMENSION,

	CONVERT(numeric(12,4),SUM(ACCOUNTINGDISTRIBUTION_TRANSACTIONCURRENCYAMOUNT * @multiplier)) [TRANSACTIONCURRENCYAMOUNT],

	--v2 modified
	ROW_NUMBER() OVER(ORDER BY
	case when l.ACCOUNTINGDISTRIBUTION_LEDGERDIMENSION like '%-P%' and left(l.ACCOUNTINGDISTRIBUTION_LEDGERDIMENSION,1) = '6'
		then dbo.fn_convert_AX_gl_account_to_D365('60998' + SUBSTRING(l.ACCOUNTINGDISTRIBUTION_LEDGERDIMENSION,6,LEN(l.ACCOUNTINGDISTRIBUTION_LEDGERDIMENSION) - 5))
		else dbo.fn_convert_AX_gl_account_to_D365(l.ACCOUNTINGDISTRIBUTION_LEDGERDIMENSION)
	end) + 1 LINEITEMNUMBER
from AXInvoiceExport e
join AXInvoiceHeader h
	on h.axinvoiceheader_uid = e.axinvoiceheader_uid
	and h.ECOLINVOICEID = @invoice_code
join AXInvoiceLine l
	on l.axinvoiceheader_uid = h.axinvoiceheader_uid
where e.status = @status
group by
	l.CUSTINVOICELINE_ECOLSOURCECOMPANY,
	h.ECOLINVOICEID,
	h.ORDERACCOUNT,
	case COALESCE(TRIM(h.CURRENCYCODE),'') when '' then 'USD' else TRIM(h.CURRENCYCODE) end,
	CONVERT(date,h.INVOICEDATE),
	SUBSTRING(l.ACCOUNTINGDISTRIBUTION_LEDGERDIMENSION,7,3),
	CONVERT(date,l.ACCOUNTINGDISTRIBUTION_ACCOUNTINGDATE),
	COALESCE(h.CASHDISCCODE,''),
	CONVERT(date,h.DUEDATE),
	h.PAYMENT,
	h.PAYMMODE,
	h.POSTINGPROFILE,

	--v2 modified
	case when convert(int,left(l.ACCOUNTINGDISTRIBUTION_LEDGERDIMENSION,5)) < 60000
		then ''
		else
		case when COALESCE(l.CUSTINVOICELINE_PROJID,'') <> '' then SUBSTRING(l.ACCOUNTINGDISTRIBUTION_LEDGERDIMENSION,1,5) + 'Fee' else '' end
	end,

	--v2 modified
	case when convert(int,left(l.ACCOUNTINGDISTRIBUTION_LEDGERDIMENSION,5)) < 60000
		then ''
		else COALESCE(l.CUSTINVOICELINE_PROJID,'')
	end,

	--v2 modified
	case when l.ACCOUNTINGDISTRIBUTION_LEDGERDIMENSION like '%-P%' and left(l.ACCOUNTINGDISTRIBUTION_LEDGERDIMENSION,1) = '6'
		then dbo.fn_convert_AX_gl_account_to_D365('60998' + SUBSTRING(l.ACCOUNTINGDISTRIBUTION_LEDGERDIMENSION,6,LEN(l.ACCOUNTINGDISTRIBUTION_LEDGERDIMENSION) - 5))
		else dbo.fn_convert_AX_gl_account_to_D365(l.ACCOUNTINGDISTRIBUTION_LEDGERDIMENSION)
	end,

	--v2 modified
	case when convert(int,left(l.ACCOUNTINGDISTRIBUTION_LEDGERDIMENSION,5)) < 60000
		then ''
		else
		case when COALESCE(l.CUSTINVOICELINE_PROJID,'') = '' then '' else SUBSTRING(dbo.fn_convert_AX_gl_account_to_D365(l.ACCOUNTINGDISTRIBUTION_LEDGERDIMENSION),7,LEN(dbo.fn_convert_AX_gl_account_to_D365(l.ACCOUNTINGDISTRIBUTION_LEDGERDIMENSION)) - 6) end
	end
having CONVERT(numeric(12,4),SUM(ACCOUNTINGDISTRIBUTION_TRANSACTIONCURRENCYAMOUNT * @multiplier)) <> 0
order by
	l.CUSTINVOICELINE_ECOLSOURCECOMPANY,
	
	--v2 modified
	case when convert(int,left(l.ACCOUNTINGDISTRIBUTION_LEDGERDIMENSION,5)) < 60000
		then ''
		else COALESCE(l.CUSTINVOICELINE_PROJID,'')
	end,

	--v2 modified
	case when convert(int,left(l.ACCOUNTINGDISTRIBUTION_LEDGERDIMENSION,5)) < 60000
		then ''
		else
		case when COALESCE(l.CUSTINVOICELINE_PROJID,'') <> '' then SUBSTRING(l.ACCOUNTINGDISTRIBUTION_LEDGERDIMENSION,1,5) + 'Fee' else '' end
	end,

	--v2 modified
	case when l.ACCOUNTINGDISTRIBUTION_LEDGERDIMENSION like '%-P%' and left(l.ACCOUNTINGDISTRIBUTION_LEDGERDIMENSION,1) = '6'
		then dbo.fn_convert_AX_gl_account_to_D365('60998' + SUBSTRING(l.ACCOUNTINGDISTRIBUTION_LEDGERDIMENSION,6,LEN(l.ACCOUNTINGDISTRIBUTION_LEDGERDIMENSION) - 5))
		else dbo.fn_convert_AX_gl_account_to_D365(l.ACCOUNTINGDISTRIBUTION_LEDGERDIMENSION)
	end

FOR JSON PATH
)

if coalesce(@json_rev,'') = ''
	set @json = @json_cur
else
	set @json = @json_rev + coalesce(substring(@json_cur,2,len(@json_cur)-1),'')

select @json as json
set nocount off
go
