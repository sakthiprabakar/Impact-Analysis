drop proc if exists [sp_COR_reports_waste_received]
go

CREATE PROCEDURE [dbo].[sp_COR_reports_waste_received]
	@web_userid			varchar(100) = ''
	, @customer_id_list	varchar(max) = ''	-- Comma Separated Customer ID List - what customers to include
	, @generator_id_list	varchar(max) = ''	-- Comma Separated Generator ID List - what generators to include
	, @approval_code		varchar(max) = ''	-- Approval Code
	, @manifest			varchar(max) = ''	-- Manfiest Code
	, @date_start		datetime = null
	, @date_end			datetime = null
	, @date_specifier	varchar(20) = null	-- 'service' (default) or 'transaction'
AS
/* ***************************************************************************************************
sp_COR_reports_waste_received:

Returns the data for Waste Receipts.  The point of this is to COR-logic emulate the Online Services
	Waste Received report

LOAD TO PLT_AI*

SELECT  *  FROM    receipt where receipt_id = 50097 and company_id = 29

SELECT  * FROM    contact WHERE web_userid = 'akalinka'
SELECT  * FROM    ContactCORReceiptBucket WHERE  contact_id = 215094
SELECT  * FROM    ContactCORCustomerBucket WHERE  contact_id = 215094
	and isnull(pickup_date, receipt_date) between '1/1/2019' and '12/31/2019'
-- Amanda has no Receipt bucket rows in that date range (she only represents MSG customers)

SELECT  * FROM    ContactCORBiennialBucket WHERE  contact_id = 215094
	and isnull(pickup_date, receipt_date) between '1/1/2019' and '12/31/2019'
-- Does have plenty of Biennial Bucket rows tho - related through orig_customer_id

sp_COR_reports_waste_received 
	@web_userid			= 'akalinka'
	,@customer_id_list	= ''
	,@date_start			= '1/1/2019'
	,@date_end			= '12/31/2019'
	,@date_specifier = 'transaction'


04/07/2020 JPB	Created as a copy of sp_reports_waste_received
05/07/2021 JPB	Added af.pickup_date to output - DO-19971

	
*************************************************************************************************** */
/*
-- debugging
declare
	@web_userid			varchar(100) = 'court_c'
	, @customer_id_list	varchar(max) = ''	-- Comma Separated Customer ID List - what customers to include
	, @generator_id_list	varchar(max) = ''	-- Comma Separated Generator ID List - what generators to include
	, @approval_code		varchar(max) = ''	-- Approval Code
	, @manifest			varchar(max) = ''	-- Manfiest Code
	, @start_date			datetime = '12/1/2019'
	, @end_date			datetime = '12/31/2019'

*/
SET NOCOUNT ON
SET ANSI_WARNINGS OFF

DECLARE		
	@i_debug				int				= 0
	, @i_web_userid			varchar(100)	= isnull(@web_userid, '')
	, @i_customer_id_list	varchar(max)	= isnull(@customer_id_list, '')	-- Comma Separated Customer ID List - what customers to include
	, @i_generator_id_list	varchar(max)	= isnull(@generator_id_list, '')	-- Comma Separated Generator ID List - what generators to include
	, @i_approval_code		varchar(max)	= isnull(@approval_code, '')	-- Approval Code
	, @i_manifest			varchar(max)	= isnull(@manifest, '')	-- Manfiest Code
	, @i_date_start			datetime		= isnull(@date_start, dateadd(yyyy, -1, getdate()))	-- Start Date
	, @i_date_end			datetime		= isnull(@date_end, getdate())	-- End Date
	, @i_date_specifier		varchar(20) = isnull(@date_specifier, 'service')
	, @i_contact_id			int
	, @i_debug_time			datetime = getdate()

select top 1 @i_contact_id = contact_id from CORcontact where web_userid = @i_web_userid

if datepart(hh, @i_date_end) = 0 set @i_date_end = @i_date_end + 0.99999
if @i_date_specifier = '' set @i_date_specifier = 'service'

-- Handle text inputs into temp tables
	declare @customer_ids table (customer_id int)
	if @i_customer_id_list <> ''
	Insert @customer_ids (customer_id)
	select convert(int, row) 
	from dbo.fn_SplitXsvText(',', 1, @i_customer_id_list) 
	where row is not null

	declare @generator_ids table (generator_id int)
	if @i_generator_id_list <> ''
	Insert @generator_ids (generator_id)
	select convert(int, row) 
	from dbo.fn_SplitXsvText(',', 1, @i_generator_id_list) 
	where row is not null

	declare @approval_code_list table (approval_code varchar(20))
	if @i_approval_code <> ''
	Insert @approval_code_list (approval_code)
	select row
	from dbo.fn_SplitXsvText(',', 1, @i_approval_code) 
	where row is not null

	declare @manifest_list table (manifest varchar(20))
	if @i_manifest <> ''
	Insert @manifest_list (manifest)
	select row
	from dbo.fn_SplitXsvText(',', 1, @i_manifest) 
	where row is not null

	declare @foo table (
		contact_id		int
		, _table varchar(50)
		, receipt_id	int
		, line_id		int
		, company_id	int
		, profit_ctr_id	int
		, receipt_date	datetime
		, pickup_date	datetime
		, invoice_date	datetime
		, customer_id	int
		, orig_customer_id	int
		, generator_id	int
		, prices		bit
		, is_mine		bit
	)

	declare @foo2 table (
		contact_id		int
		, _table varchar(50)
		, receipt_id	int
		, line_id		int
		, company_id	int
		, profit_ctr_id	int
		, receipt_date	datetime
		, pickup_date	datetime
		, invoice_date	datetime
		, customer_id	int
		, orig_customer_id int
		, generator_id	int
		, prices		bit
		, is_mine		bit
	)

	insert @foo (
		contact_id		
		, _table
		, receipt_id	
		, line_id
		, company_id	
		, profit_ctr_id	
		, receipt_date	
		, pickup_date	
		, invoice_date	
		, customer_id	
		, generator_id	
		, prices		
		, is_mine
	)	
	select
		b.contact_id
		, 'ContactCORReceiptBucket'		
		, b.receipt_id	
		, r.line_id
		, b.company_id	
		, b.profit_ctr_id	
		, b.receipt_date	
		, b.pickup_date	
		, b.invoice_date	
		, b.customer_id	
		, b.generator_id	
		, b.prices
		, 1 is_mine -- because you have access to receipts via the bucket table (although you may be the generator)
	from ContactCORReceiptBucket b
	join receipt r
		on b.receipt_id = r.receipt_id
		and b.company_id = r.company_id
		and b.profit_ctr_id = r.profit_ctr_id
		AND r.trans_mode = 'I'
		AND r.trans_type = 'D'
		AND r.receipt_status = 'A'
		AND r.fingerpr_status = 'A'
	where b.contact_id = @i_contact_id
	and b.invoice_date is not null
	and (
		@i_date_specifier <> 'service'
		or (@i_date_specifier = 'service' and isnull(b.pickup_date, b.receipt_date) between @i_date_start and @i_date_end)
	)
	and (
		@i_date_specifier <> 'transaction'
		or (@i_date_specifier = 'transaction' and b.receipt_date between @i_date_start and @i_date_end)
	)
	and (
		@i_customer_id_list = ''
		or
		b.customer_id in (select customer_id from @customer_ids)
	)
	and (
		@i_generator_id_list = ''
		or
		b.generator_id in (select generator_id from @generator_ids)
	)
	and convert(varchar(2), b.company_id) + '-' + convert(varchar(2), b.profit_ctr_id)
	in (
		select
		convert(varchar(2), p.company_id) + '-' + convert(varchar(2), p.profit_ctr_id)
		from ProfitCenter p
		where
			isnull(p.view_on_web, 'F') <> 'F'
			AND isnull(p.view_waste_received_on_web, 'F') = 'T'
	)
	UNION
	select
		a.contact_id	
		, 'ContactCORBiennialBucket'	
		, a.receipt_id	
		, r.line_id
		, a.company_id	
		, a.profit_ctr_id	
		, a.receipt_date	
		, a.pickup_date	
		, a.invoice_date	
		, a.customer_id	
		, a.generator_id	
		, 0 as prices
		, 0 is_mine -- because you have access to receipts via the BIENNIAL bucket table
	from ContactCORBiennialBucket a
	join receipt r
		on a.receipt_id = r.receipt_id
		and a.company_id = r.company_id
		and a.profit_ctr_id = r.profit_ctr_id
		AND r.trans_mode = 'I'
		AND r.trans_type = 'D'
		AND r.receipt_status = 'A'
		AND r.fingerpr_status = 'A'
	where a.contact_id = @i_contact_id
	and a.invoice_date is not null
	and (
		@i_date_specifier <> 'service'
		or (@i_date_specifier = 'service' and isnull(a.pickup_date, a.receipt_date) between @i_date_start and @i_date_end)
	)
	and (
		@i_date_specifier <> 'transaction'
		or (@i_date_specifier = 'transaction' and a.receipt_date between @i_date_start and @i_date_end)
	)
	and not exists (
		select 1 from ContactCORReceiptBucket b
		where b.contact_id = a.contact_id
		and b.receipt_id = a.receipt_id
		and b.company_id = a.company_id
		and b.profit_ctr_id = a.profit_ctr_id
	)
	and (
		@i_customer_id_list = ''
		or
		a.customer_id in (select customer_id from @customer_ids)
		or
		exists (
			select 1 from ContactCORBiennialBucket bc
			join @customer_ids ci on bc.orig_customer_id_list like '%,' + convert(varchar(20),ci.customer_id) + '%,'
			WHERE bc.ContactCORBiennialBucket_uid = a.ContactCORBiennialBucket_uid
		)
	)
	and (
		@i_generator_id_list = ''
		or
		a.generator_id in (select generator_id from @generator_ids)
	)
	and convert(varchar(2), a.company_id) + '-' + convert(varchar(2), a.profit_ctr_id)
	in (
		select
		convert(varchar(2), p.company_id) + '-' + convert(varchar(2), p.profit_ctr_id)
		from ProfitCenter p
		where
			isnull(p.view_on_web, 'F') <> 'F'
			AND isnull(p.view_waste_received_on_web, 'F') = 'T'
	)

update @foo set orig_customer_id = p.orig_customer_id
from @foo a join receipt r on a.receipt_id = r.receipt_id
and a.line_id = r.line_id
and a.company_id = r.company_id
and a.profit_ctr_id = r.profit_ctr_id
join profile p on r.profile_id = p.profile_id
WHERE a.is_mine = 0

update @foo set is_mine = 1
from @foo a join (
	select customer_id 
	from ContactCORCustomerBucket
	where contact_id = @i_contact_id
	and (
		@i_customer_id_list = ''
		or
		customer_id in (select customer_id from @customer_ids)
	)
) b
	on b.customer_id = a.orig_customer_id
where a.is_mine = 0


	if @i_approval_code <> '' begin
		delete from @foo2
		insert @foo2
		select f.* from @foo f
			join receipt r 
			on f.receipt_id = r.receipt_id
			and f.line_id = r.line_id
			and f.company_id = r.company_id
			and f.profit_ctr_id = r.profit_ctr_id
			where
			r.approval_code in (select approval_code from @approval_code_list)
		delete from @foo
		insert @foo select * from @foo2
	end

	if @i_manifest <> '' begin
		delete from @foo2
		insert @foo2
		select f.* from @foo f
			join receipt r 
			on f.receipt_id = r.receipt_id
			and f.line_id = r.line_id
			and f.company_id = r.company_id
			and f.profit_ctr_id = r.profit_ctr_id
			where
			r.manifest in (select manifest from @manifest_list)
		delete from @foo
		insert @foo select * from @foo2
	end

	SET ANSI_WARNINGS ON
	SET NOCOUNT ON

	SELECT	
		Receipt.receipt_id,
		upc.name as facility_name,
		Customer.customer_id,
		Customer.cust_name,
		Customer.cust_addr1,
		Customer.cust_addr2,
		Customer.cust_addr3,
		Customer.cust_addr4,
		RTrim(
			CASE WHEN (cust_city + ', ' + cust_state + ' ' + IsNull(cust_zip_code,'')) IS NULL and af.is_mine = 1 
			THEN 'Missing City, State, and ZipCode' 
			ELSE (cust_city + ', ' + cust_state + ' ' + IsNull(cust_zip_code,'')) END) AS cust_addr5,

		Generator.generator_name,
		Generator.generator_city,
		Generator.generator_state,
		Generator.generator_country,
		Generator.EPA_ID,


		Receipt.receipt_date,
		Receipt.time_in,
		Receipt.time_out,

		transporter.Transporter_name,
		
		Receipt.line_id,
		case Receipt.trans_mode when 'I' then 'Inbound' when 'O' then 'Outbound' else trans_mode end as trans_mode,
		case Receipt.trans_type when 'D' then 'Disposal' when 'S' then 'Service' else trans_type end as trans_type,

		Receipt.manifest as [manifest/bol],
		Receipt.manifest_line as [manifest/bol line],

		isnull(case when Receipt.trans_type = 'D' then convert(varchar(255), p.approval_desc) else null end, Receipt.service_desc) description,
		case when Receipt.trans_type = 'D' then Receipt.approval_code else null end approval_code,
		case when isnull(case when Receipt.trans_type = 'D' then convert(varchar(255), p.approval_desc) else null end, Receipt.service_desc) = Receipt.service_desc then null else Receipt.service_desc end as service_description,
		Receipt.ref_line_id as [refers_to_line],

		bu.bill_unit_desc,
		
		Receipt.quantity,
		dbo.fn_receipt_weight_line(af.receipt_id, receipt.line_id, af.profit_ctr_id, af.company_id) as weight,

		case when af.prices = 0 then null else ReceiptPrice.price end price,
		case when af.prices = 0 then null else ReceiptPrice.sr_extended_amt end sr_extended_amt,

		case when af.prices = 0 then null else dbo.fn_surcharge_desc_AI(
			ReceiptPrice.Receipt_id, 
			ReceiptPrice.line_id, 
			ReceiptPrice.price_id, 
			ReceiptPrice.profit_ctr_id,
			ReceiptPrice.company_id) end AS surcharge_desc,

		--case when af.prices = 0 then null else dbo.fn_insr_amt_receipt_AI(
		--	Receipt.receipt_id, 
		--	Receipt.profit_ctr_id,
		--	Receipt.company_id) end AS receipt_insr_amt,

		case when af.prices = 0 then null else ReceiptPrice.waste_extended_amt end waste_extended_amt,
		case when af.prices = 0 then null else ReceiptPrice.total_extended_amt end total_extended_amt,
		af.pickup_date service_date
	FROM @foo  af
	INNER JOIN Receipt (nolock) ON 
		af.receipt_id = Receipt.receipt_id
		AND af.line_id = Receipt.line_id
		AND af.company_id = Receipt.company_id
		AND af.profit_ctr_id = Receipt.profit_ctr_id
		AND af.customer_id = Receipt.customer_id
	left outer join 
	(
			SELECT 
				pqa.approval_code, 
				p.curr_status_code,
				pqa.company_id,
				pqa.profit_ctr_id,
				p.approval_desc,
				p.profile_id
			FROM Profile p
			INNER JOIN ProfileQuoteApproval pqa ON p.profile_id = pqa.profile_id
			INNER JOIN ProfileLab pl ON p.profile_id = pl.profile_id
			WHERE 1=1
			AND p.curr_status_code = 'A'
			AND pl.type = 'A'
	) approval on (receipt.approval_code = approval.approval_code 
		AND Receipt.profit_ctr_id = approval.profit_ctr_id 
		AND Receipt.company_id = approval.company_id
		AND approval.curr_status_code = 'A'
	)
	LEFT OUTER JOIN Profile p ON approval.profile_id = p.profile_id AND p.curr_status_code = 'A'
	LEFT OUTER join Customer on Receipt.customer_id = Customer.customer_id and af.is_mine = 1
	LEFT OUTER JOIN Generator on Receipt.generator_id = Generator.generator_id
	join use_profitcenter upc on Receipt.profit_ctr_id = upc.profit_ctr_id
		and Receipt.company_id = upc.company_id
	left outer join ReceiptPrice on (
		Receipt.Receipt_id = ReceiptPrice.Receipt_id 
		and Receipt.Line_id = ReceiptPrice.Line_id 
		and Receipt.Profit_ctr_id = ReceiptPrice.Profit_ctr_id
		and Receipt.company_id = ReceiptPrice.company_id)
	left join Transporter
		on receipt.hauler = transporter.transporter_code
	left join BillUnit bu
		on receipt.bill_unit_code = bu.bill_unit_code
	WHERE
		1=1
		-- AND Receipt.receipt_id = @receipt_id_int
		-- AND Receipt.profit_ctr_id = @profit_ctr_id
		AND (receipt.fingerpr_status = 'A' AND receipt.receipt_status = 'A')
		order by Receipt.company_id, Receipt.profit_ctr_id, Receipt.receipt_id, Receipt.line_id


GO

GRANT EXECUTE
    ON OBJECT::[dbo].[sp_COR_reports_waste_received] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_COR_reports_waste_received] TO [COR_USER]
    AS [dbo];

GO

