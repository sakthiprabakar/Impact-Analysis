	
create proc sp_Emanifest_Report_Billing (
	@facility_epaid_list	varchar(max) = ''
	, @date_start	datetime
	, @date_end		datetime
)
as
/* ***************************************************************************************
sp_Emanifest_Report_Billing

return AthenaStatus + Billing info for Signed records

select * from athena.athena.dbo.company

sp_Emanifest_Report_Billing 
	'ALD983177015,CAD097030993,FLD981932494,GAR000039776,IDD073114654,IDD073114654,ILD000666206,INR000125641,MID980991566,MIK939928313,MID000724831,MID074259565,MID060975844,MID048090633,NVT330010000,NVT330010000,OHD980568992,OKD000402396,PAD010154045,TXD069452340,TXD069452340'
	, '6/1/2018', '9/30/2018'

*************************************************************************************** */
-- declare @copc_list varchar(max) ='all', @date_start datetime = '6/1/2018', @date_end datetime = '9/30/2018'

if datepart(hh, @date_end) = 0 set @date_end = @date_end + 0.99999

-- Create & Populate #tmp_trans_copc
if object_id('tempdb..#epaidlist') is not null drop table #epaidlist;
CREATE TABLE #tmp_trans_copc (
	source_company_id varchar(10)
	, source_profit_ctr_id varchar(10)
)

IF LTRIM(RTRIM(ISNULL(@facility_epaid_list, ''))) in ('', 'ALL')
	INSERT #tmp_trans_copc
	SELECT distinct company_id, profit_ctr_id
	FROM Athena.athena.dbo.company
	where status = 'A'
ELSE
	INSERT #tmp_trans_copc
	SELECT distinct company_id, profit_ctr_id
	from dbo.fn_SplitXsvText(',', 1, @facility_epaid_list) x
	join Athena.athena.dbo.company c on c.epa_id = x.row
	WHERE isnull(row,'') <> ''

if object_id('tempdb..#as') is not null drop table #as;
select distinct a.source, a.source_id, a.source_company_id, a.source_profit_ctr_id, a.manifest, a.status, a.record_type, a.date_signed
into #as 
from 
#tmp_trans_copc pc inner join 
Athena.athena.dbo.AthenaStatus a
on a.source_company_id = pc.source_company_id and isnull(a.source_profit_ctr_id, '') = isnull(pc.source_profit_ctr_id, '')
where status in ('corrected', 'signed')
and date_signed between @date_start and @date_end

-- select * from #as

if object_id('tempdb..#emanifest_billed') is not null drop table #emanifest_billed;
SELECT  a.source, a.source_id, a.source_company_id, a.source_profit_ctr_id, a.manifest, a.record_type, a.status, a.date_signed
-- , sum(isnull(fee.federal_user_fee, 0)) as emanifest_fee
, (
	select top 1 federal_user_fee 
	from emanifestuserfee f 
	join eManifestSubmissionType ft on f.emanifest_submission_type_uid = ft.emanifest_submission_type_uid
	WHERE ft.submission_type_desc = replace(a.record_type, 'data+image send', 'Data + Image Upload')
) emanifest_fee
, b.invoice_code
, b.invoice_date
, sum(isnull(d.extended_amt,0)) as customer_charges
into #emanifest_billed
FROM    #as a
left join billingdetail d (nolock)
	on a.source = 'eqai'
	and a.source_id = convert(Varchar(20), d.receipt_id)
	and a.source_company_id = convert(Varchar(20), d.company_id)
	and a.source_profit_ctr_id = convert(Varchar(20), d.profit_ctr_id)
	and d.trans_source = 'R'
	and d.billing_type = 'Product'
	and d.product_id in (
		select product_id from product p (nolock)
		where p.product_code like 'FEE-EMAN%'
		and d.company_id = p.company_id and d.profit_ctr_id = p.profit_ctr_id
	)
left join billing b on d.billing_uid = b.billing_uid	
left join product p on d.product_id = p.product_id and d.company_id = p.company_id and d.profit_ctr_id = p.profit_ctr_id and isnull(emanifest_submission_type_uid, 0) <> 0
left join eManifestUserFee fee on p.emanifest_submission_type_uid = fee.emanifest_submission_type_uid
GROUP BY a.source, a.source_id, a.source_company_id, a.source_profit_ctr_id, a.manifest, a.record_type, a.status, a.date_signed, b.invoice_code, b.invoice_date

update #emanifest_billed
set invoice_code = ai.invoice_number
, invoice_date = ai.invoice_date
, customer_charges = ai.emanifest_charge
from #emanifest_billed b
join Athena.athena.dbo.Aesop_Invoice_Info ai
on b.source_id = ai.source_id
and b.source_company_id = ai.loc_code
and b.manifest = ai.cust_manifest_number
where b.source = 'aesop'


if object_id('tempdb..#double_sent') is not null drop table #double_sent;
SELECT  manifest, source, source_company_id, source_profit_ctr_id, min(source_id) min_source_id
into #double_sent
FROM    #emanifest_billed
group by manifest, source, source_company_id, source_profit_ctr_id having count(*) > 1


SELECT c.name, c.epa_id, b.source, b.source_id, b.source_company_id, b.source_profit_ctr_id, b.manifest, b.record_type, b.status, b.date_signed
, CASE WHEN d.min_source_id IS NULL THEN b.emanifest_fee ELSE
	CASE WHEN d.min_source_id = b.source_id THEN b.emanifest_fee
	 ELSE 0
	 END
	END AS emanifest_fee
, b.invoice_code
, b.invoice_date
, b.customer_charges
FROM    #emanifest_billed b
JOIN athena.athena.dbo.company c on b.source_company_id = c.company_id and b.source_profit_ctr_id = c.profit_ctr_id
left join #double_sent d 
	on b.manifest = d.manifest 
	and b.source_company_id = d.source_company_id
	and b.source_profit_ctr_id = d.source_profit_ctr_id
order by c.epa_id, c.name, b.source_company_id, b.source_profit_ctr_id, b.manifest


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_Emanifest_Report_Billing] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_Emanifest_Report_Billing] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_Emanifest_Report_Billing] TO [EQAI]
    AS [dbo];

