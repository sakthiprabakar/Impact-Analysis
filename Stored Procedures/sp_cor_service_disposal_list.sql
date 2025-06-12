-- drop proc sp_cor_service_disposal_list
go
create procedure sp_cor_service_disposal_list (
	@web_userid			varchar(100)
	, @workorder_id		int
	, @company_id		int
    , @profit_ctr_id	int
	, @customer_id_list varchar(max)=''  /* Added 2019-07-17 by AA */
    , @generator_id_list varchar(max)=''  /* Added 2019-07-17 by AA */
) as

/* *******************************************************************
sp_cor_service_disposal_list

 10/16/2019  DevOps:11609 - AM - Added customer_id and generator_id temp tables and added receipt join.
 07/20/2021  DO:16578 - Added manifest line count to output

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


exec sp_cor_service_disposal_list
	@web_userid = 'dcrozier@riteaid.com'
	, @workorder_id = 21374000
	, @company_id = 14
	, @profit_ctr_id = 0

	exec sp_cor_service_disposal_list
	@web_userid = 'nyswyn125'
	, @workorder_id = 3005200
	, @company_id = 14
	, @profit_ctr_id = 17

	exec sp_cor_service_disposal_list
	@web_userid = 'all_customers'
	, @workorder_id = 3005200
	, @company_id = 14
	, @profit_ctr_id = 17
	, @customer_id_list = '14231'
	, @generator_id_list =  '116235'

	
******************************************************************* */
-- Avoid query plan caching:
declare
	@i_web_userid		varchar(100) = @web_userid
	, @i_workorder_id	int = @workorder_id
	, @i_company_id		int = @company_id
    , @i_profit_ctr_id	int = @profit_ctr_id
    , @i_customer_id_list	varchar(max) = isnull(@customer_id_list, '')
    , @i_generator_id_list	varchar(max) = isnull(@generator_id_list, '')

declare @customer_list table (
	customer_id	bigint
)

if @i_customer_id_list <> ''
insert @customer_list select convert(bigint, row)
from dbo.fn_SplitXsvText(',', 1, @i_customer_id_list)
where row is not null

declare @generator_list table (
	generator_id	bigint
)

if @i_generator_id_list <> ''
insert @generator_list select convert(bigint, row)
from dbo.fn_SplitXsvText(',', 1, @i_generator_id_list)
where row is not null

declare @foo table (
		workorder_id	int NOT NULL,
		company_id	int NOT NULL,
		profit_ctr_id  int NOT NULL,
		start_date datetime NULL,
		service_date datetime NULL,
		prices		bit NOT NULL,
		invoice_date datetime NULL
	)
	
insert @foo
SELECT  
		x.workorder_id,
		x.company_id,
		x.profit_ctr_id,
		x.start_date,
		x.service_date,
		x.prices
		, x.invoice_date
FROM    ContactCORWorkorderHeaderBucket x (nolock) 
join CORcontact c (nolock) on x.contact_id = c.contact_id and c.web_userid = @i_web_userid
WHERE
	x.workorder_id = @i_workorder_id
	and x.company_id = @i_company_id
	and x.profit_ctr_id = @i_profit_ctr_id


	select distinct
		case isnull(m.manifest_flag, '') when 'T' then 'Manifest' else 'BOL' end as manifest_bol
		, m.manifest
		, case isnull(m.manifest_flag, '') when 'T' then case isnull(m.manifest_state, 'N') when 'H' then 'Haz' else 'Non-Haz' end else null end as manifest_type
		, case when upc.company_id is not null then upc.name else t.tsdf_name end tsdf_name
		, case when upc.company_id is not null then upc.address_1 else t.tsdf_addr1 end  tsdf_address_1
		, case when upc.company_id is not null then upc.address_2 else t.tsdf_addr2 end  tsdf_address_2
		, case when upc.company_id is not null then upc.address_3 else t.tsdf_addr3 end  tsdf_address_3
		, case when upc.company_id is not null then upc.city else t.tsdf_city end  tsdf_city
		, case when upc.company_id is not null then upc.state else t.tsdf_state end  tsdf_state
		, case when upc.company_id is not null then upc.zip_code else t.tsdf_zip_code end  tsdf_zip_code
		, case when upc.company_id is not null then upc.country_code else t.tsdf_country_code end  tsdf_country_code
		, case when upc.company_id is not null then upc.epa_id else t.tsdf_epa_id end  tsdf_epa_id
		, case when upc.company_id is not null then upc.phone else t.tsdf_phone end tsdf_phone
		, m.generator_sign_name
		, m.generator_sign_date
		, case when z.invoice_date is null then 'F' else 'T' end as invoiced_flag
		, z.service_date
		, w.purchase_order
		, w.release_code
		
		, (
			select count (distinct manifest + convert(varchar(3),manifest_line))
			from workorderdetail dc
			WHERE 
			dc.workorder_id = z.workorder_id 
			and dc.company_id = z.company_id 
			and dc.profit_ctr_id = z.profit_ctr_id 
			and dc.resource_type = 'D'
			and dc.manifest not like '%manifest%'
			and dc.bill_rate > -2
		) manifest_line_count
	from @foo z 
	join workorderdetail d (nolock) on z.workorder_id = d.workorder_id and z.company_id = d.company_id and z.profit_ctr_id = d.profit_ctr_id and d.resource_type = 'D' and d.bill_rate > -2
	join workorderheader w (nolock) on w.workorder_id = d.workorder_id and w.company_id = d.company_id and w.profit_ctr_id = d.profit_ctr_id 
	join workordermanifest m (nolock) on z.workorder_id = m.workorder_id and z.company_id = m.company_id and z.profit_ctr_id = m.profit_ctr_id and m.manifest = d.manifest
	join tsdf t (nolock) on d.tsdf_code = t.tsdf_code
	left join USE_ProfitCenter upc on t.eq_flag = 'T' and t.eq_company = upc.company_id and t.eq_profit_ctr = upc.profit_ctr_id
	WHERE  	  (
			@i_customer_id_list = ''
			or
			 (
				@i_customer_id_list <> ''
				and
				w.customer_id in (select customer_id from @customer_list)
			 )
		   )
		 and
		 (
			@i_generator_id_list = ''
			or
			(
				@i_generator_id_list <> ''
				and
			 w.Generator_id in (select generator_id from @generator_list)
			)
		  )
	order by m.manifest
	    
return 0
go

grant execute on sp_cor_service_disposal_list to eqai, eqweb, COR_USER
go



