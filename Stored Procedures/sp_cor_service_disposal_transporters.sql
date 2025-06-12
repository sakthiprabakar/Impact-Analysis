-- drop proc sp_cor_service_disposal_transporters
go

create procedure sp_cor_service_disposal_transporters (
	@web_userid			varchar(100)
	, @workorder_id		int
	, @company_id		int
    , @profit_ctr_id	int
    , @manifest			varchar(15)
    , @customer_id_list varchar(max) =''  /* Added 2019-07-17 by AA */
    , @generator_id_list varchar(max) =''  /* Added 2019-07-17 by AA */
) as

/* *******************************************************************
sp_cor_service_disposal_transporters

 10/16/2019  DevOps:11604 - AM - Added customer_id and generator_id temp tables and added receipt join.

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



exec sp_cor_service_disposal_transporters
	@web_userid = 'dcrozier@riteaid.com'
	, @workorder_id = 21374000
	, @company_id = 14
	, @profit_ctr_id = 0
	, @manifest = '015178284 JJK'


exec sp_cor_service_disposal_transporters
	@web_userid = 'nyswyn125'
	, @workorder_id = 3005200
	, @company_id = 14
	, @profit_ctr_id = 17
	, @manifest = '017216667JJK'
	, @customer_id_list = ''-- '14231'
	, @generator_id_list = '' --'116235'

******************************************************************* */
-- Avoid query plan caching:
declare
	@i_web_userid		varchar(100) = @web_userid
	, @i_workorder_id	int = @workorder_id
	, @i_company_id		int = @company_id
    , @i_profit_ctr_id	int = @profit_ctr_id
    , @i_manifest		varchar(15) = @manifest
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
		prices		bit NOT NULL
	)
	
insert @foo
SELECT  
		x.workorder_id,
		x.company_id,
		x.profit_ctr_id,
		x.start_date,
		x.prices
FROM    ContactCORWorkorderHeaderBucket x (nolock)
join CORcontact c (nolock) on x.contact_id = c.contact_id and c.web_userid = @i_web_userid
WHERE
	x.workorder_id = @i_workorder_id
	and x.company_id = @i_company_id
	and x.profit_ctr_id = @i_profit_ctr_id

	select
		w.manifest
		, w.transporter_sequence_id
		, t.transporter_name
		, t.transporter_addr1
		, t.transporter_addr2
		, t.transporter_addr3
		, t.transporter_city
		, t.transporter_state
		, t.transporter_zip_code
		, t.transporter_country
		, t.transporter_epa_id
		, w.transporter_sign_name
		, w.transporter_sign_date
		, w.transporter_license_nbr
	from @foo z 
	join workorderdetail d (nolock) on z.workorder_id = d.workorder_id and z.company_id = d.company_id and z.profit_ctr_id = d.profit_ctr_id and d.resource_type = 'D'
	join workorderheader wh (nolock) on wh.workorder_id = d.workorder_id and wh.company_id = d.company_id and wh.profit_ctr_id = d.profit_ctr_id 
	join workordermanifest m (nolock) on z.workorder_id = d.workorder_id and z.company_id = d.company_id and z.profit_ctr_id = d.profit_ctr_id and d.resource_type = 'D' and d.manifest = m.manifest
	join workordertransporter w (nolock) on z.workorder_id = w.workorder_id and z.company_id = w.company_id and z.profit_ctr_id = w.profit_ctr_id and d.resource_type = 'D' and d.manifest = w.manifest
	join transporter t (nolock) on w.transporter_code = t.transporter_code
	WHERE isnull(@i_manifest, d.manifest) = d.manifest
	and  (
			@i_customer_id_list = ''
			or
			 (
				@i_customer_id_list <> ''
				and
				wh.customer_id in (select customer_id from @customer_list)
			 )
		   )
		 and
		 (
			@i_generator_id_list = ''
			or
			(
				@i_generator_id_list <> ''
				and
			 wh.Generator_id in (select generator_id from @generator_list)
			)
		  )
	order by d.manifest, w.transporter_sequence_id
	    
return 0
go

grant execute on sp_cor_service_disposal_transporters to eqai, eqweb, COR_USER
go
