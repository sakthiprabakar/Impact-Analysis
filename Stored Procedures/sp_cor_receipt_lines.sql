-- drop procedure sp_cor_receipt_lines
go

create procedure sp_cor_receipt_lines (
	@web_userid			varchar(100)
	, @receipt_id		int
	, @company_id		int
    , @profit_ctr_id	int
	, @customer_id_list varchar(max)=''  /* Added 2019-07-17 by AA */
    , @generator_id_list varchar(max)=''  /* Added 2019-07-17 by AA */
) as

/* *******************************************************************
sp_cor_receipt_lines

Description
	Provides a listing of all receipt disposal lines

		For a receipt, the following information should appear on the screen: 
		Receipt Header Information: 
			Transaction Type (Receipt or Work Order), 
			US Ecology facility, 
			Transaction ID, 
			Customer Name, 
			Customer ID, 
			Generator Name, 
			Generator EPA ID, 
			Generator ID, 
		
			If Receipt.manifest_flag = 'M' or 'C': 
				Manifest Number, 
				Manifest Form Type (Haz or Non-Haz), 
				
			If Receipt.manifest_flag = 'B': 
				BOL number, 
				
			Receipt Date, 
			Receipt Time In, 
			Receipt Time Out 
		
		For each receipt disposal line: 
			Manifest Page Number, 
			Manifest Line Number, 
			Manifest Approval Code, 
			Approval Waste Common Name, 
			Manifest Quantity, 
			Manifest Unit, 
			Manifest Container Count, 
			Manifest Container Code. 
			{If we are showing 	pricing, we may need to add more, here}
			 
		For each receipt service line: 
			Receipt line item description, 
			Receipt line item quantity, 
			Receipt line item unit of measure. 
			{If we are showing pricing, we may need to add more, here} 
		
		For each receipt, the user should be able to: 
			1) View the Printable Receipt Document 
			2) View any Scanned documents that are linked to the receipt and marked 
				as 'T' for the View on Web status 
			3) Upload any documentation to the receipt 
			4) Save the Receipt detail lines to Excel. 


exec sp_cor_receipt_lines
	@web_userid = 'jamie.huens@wal-mart.com'
	, @receipt_id = 78400
	, @company_id = 22
	, @profit_ctr_id = 0
	


******************************************************************* */
-- Avoid query plan caching:
declare
	@i_web_userid			varchar(100) = @web_userid
	, @i_receipt_id		int = @receipt_id
	, @i_company_id		int = @company_id
    , @i_profit_ctr_id	int = @profit_ctr_id

declare @foo table (
		receipt_id	int NOT NULL,
		company_id	int NOT NULL,
		profit_ctr_id  int NOT NULL,
		receipt_date datetime NULL,
		prices		bit NOT NULL
	)
	
insert @foo
SELECT  
		x.receipt_id,
		x.company_id,
		x.profit_ctr_id,
		x.receipt_date,
		x.prices
FROM    ContactCORReceiptBucket x (nolock) 
join CORcontact c (nolock) on x.contact_id = c.contact_id and c.web_userid = @i_web_userid
WHERE
	x.receipt_id = @i_receipt_id
	and x.company_id = @i_company_id
	and x.profit_ctr_id = @i_profit_ctr_id

	select
		r.trans_type
		, r.service_desc
		, r.manifest
		, upc.name tsdf_name
		, upc.address_1
		, upc.address_2
		, upc.address_3
		, upc.epa_id
		, r.receipt_date
		, r.manifest_page_num
		, r.manifest_line
		, r.approval_code
		, p.approval_desc
		, r.manifest_quantity
		, r.manifest_unit
		, r.container_count					
		, r.manifest_container_code			

		, b.quantity
		, bu.bill_unit_desc
		, case when z.prices = 1 then b.total_extended_amt else null end as line_total_price
		, case when z.prices = 1 then b.currency_code else null end as currency_code
		, r.purchase_order
		, r.release as release_code
	from @foo z 
	join receipt r (nolock) on z.receipt_id = r.receipt_id and z.company_id = r.company_id and z.profit_ctr_id = r.profit_ctr_id and r.trans_mode = 'I'
	join billing b (nolock) on r.receipt_id = b.receipt_id and r.line_id = b.line_id and r.company_id = b.company_id and r.profit_ctr_id = b.profit_ctr_id and b.trans_source = 'R' and b.status_code = 'I'
	join billunit bu (nolock) on b.bill_unit_code = bu.bill_unit_code
	left join profile p (nolock) on r.profile_id = p.profile_id
	left join USE_ProfitCenter upc on z.company_id = upc.company_id and z.profit_ctr_id = upc.profit_ctr_id

	order by r.line_id, manifest_page_num, manifest_line, b.line_id, b.price_id
	    
return 0
go

grant execute on sp_cor_receipt_lines to eqai, eqweb
go
