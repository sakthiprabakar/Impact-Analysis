drop proc if exists sp_cor_receipt_weight_ticket
go

create proc [dbo].[sp_cor_receipt_weight_ticket] (
	@receipt_id_list	varchar(max),
	@company_id			int,
	@profit_ctr_id		int

) as
/* *********************************************************************
sp_cor_receipt_weight_ticket

returns data for a weight ticket for n receipts in the same company, profit center

sp_cor_receipt_weight_ticket 
	@receipt_id_list	='2145184 ',
	@company_id			=21,
	@profit_ctr_id		=0
	
********************************************************************* */


declare @ra_company_id int = isnull(@company_id, 0)
, @ra_profit_ctr_id int = isnull(@profit_ctr_id, 0)

declare @ra_receipt_id_list table (receipt_id int)

insert @ra_receipt_id_list
select row from dbo.fn_SplitXsvtext(',',1,@receipt_id_list)
where row is not null

SELECT Receipt.receipt_id,
Receipt.customer_id,
Customer.cust_addr1,
Customer.cust_addr2,
Customer.cust_addr3,
Customer.cust_addr4,
RTrim(CASE WHEN (cust_city + ', ' + cust_state + ' ' + IsNull(cust_zip_code,'')) IS NULL THEN 'Missing City, State, and ZipCode'
ELSE (cust_city + ', ' + cust_state + ' ' + IsNull(cust_zip_code,'')) END) AS cust_addr5,
Receipt.date_added,          
Receipt.manifest,          
Receipt.hauler,          
Receipt.approval_code,          
ReceiptPrice.bill_unit_code,          
ReceiptPrice.bill_quantity,          
Receipt.gross_weight,          
Receipt.tare_weight,          
Receipt.net_weight,          
ReceiptPrice.quote_price,          
ReceiptPrice.price,
ReceiptPrice.waste_extended_amt,
ReceiptPrice.total_extended_amt,
Receipt.cash_received,          
Receipt.lab_comments,          
Receipt.company_id,          
Receipt.profit_ctr_id,          
Receipt.receipt_status,          
Receipt.time_out,          
Receipt.tender_type,          
Receipt.trans_type,          
Receipt.service_desc,          
Receipt.waste_code,          
ReceiptPrice.sr_type,          
ReceiptPrice.sr_price,          
ReceiptPrice.sr_extended_amt,          
Receipt.line_id,          
Receipt.manifest_comment,          
Receipt.time_in,          
Receipt.trans_mode, 
Receipt.bulk_flag, 
Customer.cust_name,          
Receipt.receipt_date,
Receipt.manifest_page_num,
Receipt.manifest_line,
Customer.terms_code,
ProfitCenter.profit_ctr_name,
ProfitCenter.address_1,
ProfitCenter.address_2,
ProfitCenter.address_3,
Company.company_name,
Receipt.tsdf_approval_code,
Receipt.waste_stream,
Profile.approval_desc,
insr_amt = dbo.fn_insr_amt_receipt(Receipt.receipt_id, Receipt.profit_ctr_id, Receipt.company_id),
ensr_amt = dbo.fn_ensr_amt_receipt(Receipt.receipt_id, Receipt.profit_ctr_id, Receipt.company_id),
surcharge_desc = dbo.fn_surcharge_desc(ReceiptPrice.receipt_id, ReceiptPrice.line_id, ReceiptPrice.price_id, ReceiptPrice.profit_ctr_id, Receipt.company_id),
Generator.EPA_ID,
Receipt.manifest_flag,
Receipt.ref_line_id,
Customer.currency_code,
TSDF.TSDF_country_code,
Customer.cust_country,
Receipt.truck_code,
Transporter.transporter_name,
Transporter.transporter_EPA_ID,
TSDF.TSDF_name,
TSDF.TSDF_addr1,
TSDF.TSDF_addr2,
TSDF.TSDF_addr3,
TSDF.TSDF_city,
TSDF.TSDF_state,
TSDF.TSDF_zip_code,
Generator.generator_ID,
Generator.generator_name,
  Generator.generator_address_1,
Generator.generator_address_2,
Generator.generator_address_3,
Generator.generator_address_4,
Generator.generator_address_5,
Generator.generator_city,
  Generator.generator_state,
  Generator.generator_zip_code,
  Generator.generator_country,
  gen_count = dbo.fn_get_receipt_generator(Receipt.receipt_id,Receipt.company_id,Receipt.profit_ctr_id)
FROM Receipt (nolock)
JOIN ReceiptPrice (nolock) 
ON (Receipt.company_id = ReceiptPrice.company_id)
	AND (Receipt.profit_ctr_id = ReceiptPrice.profit_ctr_id)
	AND (Receipt.receipt_id = ReceiptPrice.receipt_id)
	AND (Receipt.line_id = ReceiptPrice.line_id)
JOIN Company  (nolock) ON (Receipt.company_id = Company.company_id)
JOIN ProfitCenter  (nolock)
	ON (Receipt.company_id = ProfitCenter.company_id)
	AND (Receipt.profit_ctr_id = ProfitCenter.profit_ctr_id)
JOIN Customer  (nolock) ON (Receipt.customer_id = Customer.customer_id)
LEFT OUTER JOIN Generator  (nolock) ON (Receipt.generator_id = Generator.generator_id)
LEFT OUTER JOIN ProfileQuoteApproval  (nolock) 
	ON (Receipt.company_id = ProfileQuoteApproval.company_id)
	AND (Receipt.profit_ctr_id = ProfileQuoteApproval.profit_ctr_id)
	AND (Receipt.approval_code = ProfileQuoteApproval.approval_code)
LEFT OUTER JOIN Profile  (nolock) ON (ProfileQuoteApproval.profile_id = Profile.profile_id)
LEFT OUTER JOIN TSDF (nolock)
	ON TSDF.eq_company = Receipt.company_id
	AND TSDF.eq_profit_ctr = Receipt.profit_ctr_id
	AND TSDF.TSDF_status = 'A'
LEFT OUTER JOIN Transporter  (nolock) ON Transporter.transporter_code = Receipt.hauler
WHERE 
	Receipt.receipt_id IN (select receipt_id from @ra_receipt_id_list)
	AND Receipt.profit_ctr_id = @ra_profit_ctr_id
    AND Receipt.company_id = @ra_company_id
	AND (receipt.fingerpr_status = 'A' /*OR receipt.receipt_status = 'V'*/)
	AND Receipt.trans_type = 'D'
	AND Receipt.receipt_status NOT IN ('V', 'R')

go

grant execute on sp_cor_receipt_weight_ticket to eqweb, cor_user
go

