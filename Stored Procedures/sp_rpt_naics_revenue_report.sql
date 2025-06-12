
CREATE PROCEDURE sp_rpt_naics_revenue_report
		@date_from			datetime	-- recognized revenue date range start
    ,	@date_to			datetime	-- recognized revenue date range end
    ,	@copc_list			varchar(max) -- facilities to include
    ,	@cust_id_from		int			-- customer range start
	,	@cust_id_to			int			-- customer range end
	,	@customer_type_list	varchar(max)	-- customer type values to filter with.
    ,	@debug				int
AS
/*********************************************************************************************
sp_rpt_naics_revenue_report

	ôSIC NAICS Revenue Reportö 

Sample:
	EXEC dbo.sp_rpt_naics_revenue_report
                @date_from      = '12/1/2014'
                , @date_to      = '12/31/2014'
                , @copc_list	= 'ALL'
				, @cust_id_from = 1
				, @cust_id_to	= 999999
				, @customer_Type_list = '*Any*, #IC, FOUL'
                , @debug        = 0

Recommended Index (speed went from 40s to 10s):
	CREATE NONCLUSTERED INDEX [idx_billing_status_date]
	ON [dbo].[Billing] ([status_code],[invoice_date])
	INCLUDE ([billing_uid],[company_id],[profit_ctr_id],[customer_id],[generator_id],[void_status])

History:

	02/23/2014	JPB	Created
	03/18/2015	SK	Modified according to the new design document at: 
		"L:\IT Dept\Projects\CommissioNAICS Reports 2015\Design Specification SIC NAICS Revenue Report.docx"
	09/17/2015	JPB	Added @customer_type_list input and logic.
	07/25/2018	JPB	Notified of problem in customer_type logic - *Any* wasn't working if in a list.
					Revised join logic to handle nulls, revised *any* logic to handle lists.
					Revised size of #customer_type column
	10/17/2018  JPB GEM-55881 - The "*Any*" handling was doubling up data for customers without a customer_type
					culprit was a double insert of both '' and null in the input list table.  They were
					evaluated as the same later, creating cartesian doubling.
	

Notes:
-- Changes to make
3/3 Conf. Call with Juli at Boise
- Don't need Summary Reports, Just Generator Detail
+ Add Customer fields to Generator detail
+ Add TONS wherever possible
+ Add profile
+ Add subservice categories from product & resources around 1st week of April.
+ Add ES or FIS if available
+ Add Sales Type (Base or Event) (job type from Billing Project?)
+ Wants to base this on the date revenue is recognized, not invoice date as current.  Need to talk with Sarah Maclean to see how this relates to Accrual/Deferral.
== Maybe just report what's been disposed according to the deferral process' inventory "family tree" logic.



*********************************************************************************************/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

declare @starttime datetime = getdate(), @splittime datetime = getdate()

if datepart(hh, @date_to) = 0 set @date_to = @date_to + 0.99999

 --Get the copc list into tmp_copc
CREATE TABLE #tmp_copc ([company_id] int, profit_ctr_id int)
IF isnull(@copc_list, '') IN ('', 'ALL')
	INSERT #tmp_copc
	SELECT ProfitCenter.company_ID,	ProfitCenter.profit_ctr_ID FROM ProfitCenter WHERE status = 'A'
ELSE
	INSERT #tmp_copc
	SELECT 
		RTRIM(LTRIM(SUBSTRING(row, 1, CHARINDEX('|',row) - 1))) AS company_id,
		RTRIM(LTRIM(SUBSTRING(row, CHARINDEX('|',row) + 1, LEN(row) - (CHARINDEX('|',row)-1)))) AS profit_ctr_id
	from dbo.fn_SplitXsvText(',', 0, @copc_list) WHERE isnull(row, '') <> ''

CREATE TABLE #customer_type (
	customer_type		varchar(20)
)

--rb 04/10/2015
if ISNULL(@customer_type_list,'') like '%*Any*%'
begin
	insert #customer_type
	select customer_type from CustomerType

	insert #customer_type values (null)
end

set @customer_type_list = replace(@customer_type_list, '*Any*', '')
if ISNULL(@customer_type_list, '') <> ''
	insert #customer_type
	select CONVERT(varchar(20), row)
	from dbo.fn_SplitXsvText(',', 1, @customer_type_list)
	where row is not null

		
IF @debug = 1 print 'Time through #tmp_copc fill: ' + convert(Varchar(20), datediff(ms, @starttime, @splittime))		
IF @debug = 1 set @splittime = getdate()
IF @debug = 1 print 'Total Time : ' + convert(Varchar(20), datediff(ms, @starttime, getdate()))		
IF @debug = 1 print 'SELECT * FROM #tmp_copc'
IF @debug = 1 SELECT * FROM #tmp_copc

-- Create RevenueWork
--CREATE TABLE #RevenueWork (
--		--	Header info:
--		company_id					int			NULL,
--		profit_ctr_id				int			NULL,
--		trans_source				char(2)		NULL,	--	Receipt,	Workorder,	Workorder-Receipt,	etc
--		receipt_id					int			NULL,	--	Receipt/Workorder	ID
--		trans_type					char(1)		NULL,	--	Receipt	trans	type	(O/I)
--		billing_project_id			int			NULL,	--	Billing	project	ID
--		customer_id					int			NULL,	--	Customer	ID	on	Receipt/Workorder

--		--	Detail info:
--		line_id						int			NULL,	--	Receipt	line	id
--		price_id					int			NULL,	--	Receipt	line	price	id
--		ref_line_id					int			NULL,	--	Billing	reference	line_id	(which	line	does	this	refer	to?)
--		workorder_sequence_id		varchar(15)	NULL,	--	Workorder	sequence	id
--		workorder_resource_item		varchar(15)	NULL,	--	Workorder	Resource	Item
--		workorder_resource_type		varchar(15)	NULL,	--	Workorder	Resource	Type
--		Workorder_resource_category	Varchar(40)	NULL,	--	Workorder	Resource	Category
--		quantity					float		NULL,	--	Receipt/Workorder	Quantity
--		billing_type				varchar(20)	NULL,	--	'Energy',	'Insurance',	'Salestax'	etc.
--		dist_flag					char(1)		NULL,	--	'D', 'N' (Distributed/Not Distributed -- if the dist co/pc is diff from native co/pc, this is D)
--		dist_company_id				int			NULL,	--	Distribution	Company	ID	(which	company	receives	the	revenue)
--		dist_profit_ctr_id			int			NULL,	--	Distribution	Profit	Ctr	ID	(which	profitcenter	receives	the	revenue)
--		extended_amt				float		NULL,	--	Revenue	amt
--		generator_id				int			NULL,	--	Generator	ID
--		treatment_id				int			NULL,	--	Treatment	ID
--		bill_unit_code				varchar(4)	NULL,	--	Unit
--		profile_id					int			NULL,	--	Profile_id
--		quote_id					int			NULL,	--	Quote	ID
--		product_id					int			NULL,	--	BillingDetail	product_id,	for	id'ing	fees,	etc.
--        job_type                    char(1)     NULL,	--  Job type - base or event.
--		servicecategory_uid			int			NULL,	-- 3/11/2015 - Adding service category & business segment.
--		service_category_description varchar(50) NULL,
--		-- Need service_category_code
--		businesssegment_uid			int			NULL,
--		business_segment_code		varchar(10) NULL,
--		pounds						float NULL,
--		percent_disposed			float NULL
--		-- Need revenue_date as one of - CDS.final_disposal_date/Service Date/WO.End date/retail order order_date
--	)

--create index idx_tmp 
--	on #RevenueWork (trans_source, company_id, profit_ctr_id, receipt_id, line_id, workorder_resource_type, workorder_sequence_id)

-- Create Output table

--	Execute Recognized revenue calc for the given criteria
--EXEC sp_rpt_recognized_revenue_calc @copc_list, @date_from, @date_to, @cust_id_from, @cust_id_to, @debug

SELECT DISTINCT
	RW.company_id
,	RW.profit_ctr_id
,	Isnull(PC.profit_ctr_name, '') AS profit_ctr_name
,	year(RW.revenue_recognized_date) AS revenue_year
,	datepart(qq, RW.revenue_recognized_date) AS revenue_quarter
--,	Industry (Customer.cust_category ?? )
,	RW.customer_id
,	Isnull(C.cust_name, '') AS cust_name
,	RW.customer_id + 70000000 AS JDE_Customer_ID
,	Isnull(C.cust_sic_code, '') AS cust_sic_code
,	Isnull(C.cust_naics_code, '') AS cust_naics_code
,	Isnull(C.customer_type, '') AS Customer_Type
,	RW.generator_id
,	G.EPA_ID
,	Isnull(G.generator_name, '') AS generator_name
,	Isnull(G.sic_code, '') AS gen_sic_code
,	Isnull(G.NAICS_code, '') AS gen_naics_code
,	RW.profile_id
,	Isnull(PQA.approval_code, '') AS approval_code
,	T.Treatment_ID
,	Isnull(T.wastetype_category, '') AS wastetype_category
,	Isnull(T.wastetype_description, '') AS wastetype_description
,	Isnull(T.treatment_process_process, '') AS treatment_process
,	Isnull(T.disposal_service_desc, '') AS disposal_service_desc
,	CASE WHEN Isnull(RW.job_type, '') = 'E' THEN 'Event'
		 WHEN Isnull(RW.job_type, '') = 'B' THEN 'Base'
		 WHEN ISnull(RW.job_type, '') = '' THEN ''
		 END AS job_type
--,	RW.bill_unit_code
--,	CASE BU.container_flag WHEN 'T' THEN 'Drum' WHEN 'F' THEN 'Bulk' ELSE '' END AS process_group
,	RW.business_segment_code
,	SUM(IsNull(RW.pounds, 0.00))/2000 AS container_wt_tons
,	SUM(CASE RW.service_category_code WHEN 'F' THEN IsNull(RW.extended_amt, 0.00) ELSE 0 END) AS total_Taxes_Surcharges_Fees
,	SUM(CASE RW.service_category_code WHEN 'D' THEN IsNull(RW.extended_amt, 0.00) ELSE 0 END) AS total_Disposal
,	SUM(CASE RW.service_category_code WHEN 'T' THEN IsNull(RW.extended_amt, 0.00) ELSE 0 END) AS total_Trans
,	SUM(CASE RW.service_category_code WHEN 'E' THEN IsNull(RW.extended_amt, 0.00) ELSE 0 END) AS total_EIR
,	SUM(CASE RW.service_category_code WHEN 'S' THEN IsNull(RW.extended_amt, 0.00) ELSE 0 END) AS total_Services
,	SUM(CASE RW.service_category_code WHEN 'O' THEN IsNull(RW.extended_amt, 0.00) ELSE 0 END) AS total_Other
FROM RecognizedRevenue RW
JOIN #tmp_copc
	ON #tmp_copc.company_id = RW.company_id
	AND #tmp_copc.profit_ctr_id = RW.profit_ctr_id
JOIN ProfitCenter PC (nolock)
	ON PC.company_id = RW.company_id
	AND PC.profit_ctr_id = RW.profit_ctr_id
JOIN Customer C (nolock)
	ON C.customer_id = RW.customer_id
LEFT OUTER JOIN Generator G (nolock)
	ON G.generator_id = RW.generator_id
LEFT OUTER JOIN Profile P (nolock)
	ON P.profile_id = RW.profile_id
LEFT OUTER JOIN ProfileQuoteApproval PQA (nolock)
	ON PQA.profile_id = RW.profile_id
	AND PQA.company_id = RW.company_id
	AND PQA.profit_ctr_id = RW.profit_ctr_id
LEFT OUTER JOIN Treatment T
	ON T.treatment_id = PQA.treatment_id
	AND T.company_id = PQA.company_id
	AND T.profit_ctr_id = PQA.profit_ctr_id
--LEFT OUTER JOIN BillUnit BU
--	ON BU.bill_unit_code = RW.bill_unit_code
JOIN #Customer_type ct
	ON ltrim(rtrim(isnull(ct.customer_type, ''))) = ltrim(rtrim(isnull(c.customer_type, '')))
WHERE RW.customer_id BETWEEN @cust_id_from AND @cust_id_to
AND RW.revenue_recognized_date BETWEEN @date_from AND @date_to
GROUP BY 
	RW.company_id
,	RW.profit_ctr_id
,	Isnull(PC.profit_ctr_name, '')
,	year(RW.revenue_recognized_date)
,	datepart(qq, RW.revenue_recognized_date)
--,	Industry (Customer.cust_category ?? )
,	RW.customer_id
,	Isnull(C.cust_name, '')
,	Isnull(C.cust_sic_code, '')
,	Isnull(C.cust_naics_code, '')
,	Isnull(C.customer_type, '')
,	RW.generator_id
,	G.EPA_ID
,	Isnull(G.generator_name, '')
,	Isnull(G.sic_code, '')
,	Isnull(G.NAICS_code, '')
,	RW.profile_id
,	Isnull(PQA.approval_code, '')
,	T.treatment_ID
,	Isnull(T.wastetype_category, '')
,	Isnull(T.wastetype_description, '')
,	Isnull(T.treatment_process_process, '')
,	Isnull(T.disposal_service_desc, '')
,	Isnull(RW.job_type, '')
--,	RW.bill_unit_code
--,	BU.container_flag
,	RW.business_segment_code
ORDER BY RW.company_id, RW.profit_ctr_id, Isnull(C.cust_name, ''), Isnull(G.generator_name, ''), Isnull(PQA.approval_code, '')

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_naics_revenue_report] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_naics_revenue_report] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_naics_revenue_report] TO [EQAI]
    AS [dbo];

