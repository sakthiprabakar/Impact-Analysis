CREATE PROCEDURE [dbo].[sp_rpt_baseline_variance]
	@baseline_id int = NULL,
	@generator_id int = NULL,
	@start_date datetime = NULL,
	@end_Date datetime = NULL,
	@release_code varchar(20) = NULL,
	@purchase_order varchar(20) = NULL,
	@debug int = 0
/*
History:
	04/21/2010	RJG	Created
	05/14/2010	JPB Removed Billing joins.  Marked where EQ Disposal info would be needed in future.
	04/18/2011	RJG	Fixed WorkOrderDetailUnit joins.  Should get wod.quantity/bill_unit for NON-DISPOSAL
				and wodu.quantity / bill_unit for DISPOSAL
	
*/
AS
BEGIN	

if @debug > 0
begin
	print @start_date
	print @end_date
end

if (@start_date IS NULL AND @end_Date IS NULL) AND @release_code IS NULL AND @purchase_order IS NULL
BEGIN
	RAISERROR ('One of either @start_date & @end_date, @release_code, or @purchase_order must be filled in', -- Message text.
               16, -- Severity.
               1 -- State.
               );
	RETURN
END

/* 
	for EQ Disposal...
	Need to run a similar insert select for workorders inner joined to billing link lookup, inner joined to receipt.
	... when this runs, insert the workorder's workorder_id, company_id, profit_ctr_id to new fields in the #table
	... Then after that insert finishes, run the version below with a (and workorder_id not in #table) clause
	... To add the workorders that are not linked to the set that are.  Then report/work off that #table
*/

/* Grab NON Disposal Resource Type */
/* Grab NON Disposal Resource Type */
/* Grab NON Disposal Resource Type */


SELECT 
	DISTINCT 
	--woh.company_id,
	--woh.profit_ctr_id,
	--woh.workorder_id,
	bc.description as baseline_category_name,
	bc.baseline_category_id,
	brt.reporting_type,
	wod.bill_unit_code as invoice_unit,
	bd.time_period,
	bd.expected_amount,
	CAST(0 as float) as actual_amount
--SELECT *
INTO #result_data	
FROM   workorderheader woh 
        INNER JOIN BaselineHeader bh WITH (NOLOCK) ON 
			bh.customer_id = woh.customer_ID
		INNER JOIN BaselineDetail bd WITH(NOLOCK) ON 
			bh.baseline_id = bd.baseline_id
			AND bd.generator_id = woh.generator_id
		INNER JOIN BaselineReportingType brt WITH(NOLOCK)ON 
			bd.reporting_type_id = brt.reporting_type_id
		INNER JOIN BaselineCategory bc WITH(NOLOCK)ON 
			bc.baseline_category_id = bd.baseline_category_id
			AND bc.customer_id = bh.customer_id
		INNER JOIN Generator g WITH(NOLOCK)ON 
			g.generator_id = woh.generator_id
		INNER JOIN WorkorderDetail wod WITH (NOLOCK) ON
			woh.workorder_ID = wod.workorder_ID
			AND woh.company_id = wod.company_id
			AND woh.profit_ctr_ID = wod.profit_ctr_ID
			AND woh.workorder_status ='A' 
			AND woh.submitted_flag = 'T'
			AND wod.resource_type <> 'D' /* non disposal resources */
WHERE bh.baseline_id = @baseline_id
	AND woh.start_date BETWEEN @start_date AND @end_date
	AND woh.generator_id = @generator_id
--AND 1=0


UNION


/* Grab Disposal Resource Type */
/* Grab Disposal Resource Type */

SELECT 
	DISTINCT 
	--woh.company_id,
	--woh.profit_ctr_id,
	--woh.workorder_id,
	bc.description as baseline_category_name,
	bc.baseline_category_id,
	brt.reporting_type,
	wodu.bill_unit_code as invoice_unit,
	bd.time_period,
	bd.expected_amount,
	CAST(0 as float) as actual_amount
FROM   workorderheader woh 
        INNER JOIN BaselineHeader bh WITH (NOLOCK) ON 
			bh.customer_id = woh.customer_ID
		INNER JOIN BaselineDetail bd WITH(NOLOCK) ON 
			bh.baseline_id = bd.baseline_id
			AND bd.generator_id = woh.generator_id
		INNER JOIN BaselineReportingType brt WITH(NOLOCK)ON 
			bd.reporting_type_id = brt.reporting_type_id
		INNER JOIN BaselineCategory bc WITH(NOLOCK)ON 
			bc.baseline_category_id = bd.baseline_category_id
			AND bc.customer_id = bh.customer_id
		INNER JOIN Generator g WITH(NOLOCK)ON 
			g.generator_id = woh.generator_id
		INNER JOIN WorkorderDetail wod WITH (NOLOCK) ON
			woh.workorder_ID = wod.workorder_ID
			AND woh.company_id = wod.company_id
			AND woh.profit_ctr_ID = wod.profit_ctr_ID
			AND woh.workorder_status ='A' 
			AND woh.submitted_flag = 'T'
			and wod.resource_type = 'D'
		INNER JOIN WorkOrderDetailUnit wodu ON
			wod.company_id = wodu.company_id
			AND wod.profit_ctr_ID = wodu.profit_ctr_id
			AND wod.workorder_ID = wodu.workorder_id
			AND wod.sequence_id = wodu.sequence_id
			
WHERE bh.baseline_id = @baseline_id
	AND woh.start_date BETWEEN @start_date AND @end_date
	AND woh.generator_id = @generator_id
--ORDER BY woh.company_id,
--	woh.profit_ctr_id,
--	woh.workorder_id

	
IF @debug > 1
	SELECT '#result_data', * FROM #result_data


/** GRAB INFO FROM WorkOrderDetailUnit for DISPOSAL **/
SELECT DISTINCT
--wod.workorder_ID,
--wod.company_id,
--wod.profit_ctr_ID,
wodu.bill_unit_code as invoice_unit,
SUM(ISNULL(wodb.price,0) * coalesce(wodu.quantity,wod.quantity,0)) total_price, 
wodb.baseline_category_id,
bd.reporting_type_id
--, bc.description 
INTO #total_prices
FROM WorkorderHeader woh
	INNER JOIN WorkorderDetail wod ON
		wod.workorder_ID = woh.workorder_ID
		and wod.company_id = woh.company_id
		and wod.profit_ctr_ID = woh.profit_ctr_ID
		ANd woh.workorder_status = 'A'
		and woh.submitted_flag = 'T'
		and wod.resource_type = 'D'
	JOIN WorkOrderDetailUnit wodu ON
			wod.company_id = wodu.company_id
			AND wod.profit_ctr_ID = wodu.profit_ctr_id
			AND wod.workorder_ID = wodu.workorder_id
			AND wod.sequence_id = wodu.sequence_id	
	INNER JOIN WorkorderDetailBaseline wodb ON
		wodb.workorder_id = wod.workorder_ID
		AND wodb.company_id = wod.company_id
		and wodb.profit_ctr_id = wod.profit_ctr_ID
		and wodb.resource_type = wod.resource_type
		AND wodb.sequence_id = wod.sequence_ID
	INNER JOIN BaselineHeader bh ON
		bh.baseline_id = @baseline_id
	INNER JOIN BaselineDetail bd ON
		bd.baseline_id = bh.baseline_id
		--AND wod.bill_unit_code = bd.bill_unit_code
	INNER JOIN BaselineCategory bc ON
		bd.baseline_category_id = bc.baseline_category_id
		AND wodb.baseline_category_id = bc.baseline_category_id
WHERE 
	woh.start_date >= @start_date
	AND woh.start_date <= @end_date
	AND woh.generator_id = @generator_id
	--AND woh.workorder_id = 1621200
GROUP BY wodb.baseline_category_id, wodu.bill_unit_code, bd.reporting_type_id
--,wod.workorder_ID,
--wod.company_id,
--wod.profit_ctr_ID

UNION

/** GRAB INFO FROM WorkOrderDetailUnit for NON-DISPOSAL **/
SELECT DISTINCT
--wod.workorder_ID,
--wod.company_id,
--wod.profit_ctr_ID,
wod.bill_unit_code as invoice_unit,
SUM(ISNULL(wodb.price,0) * coalesce(wod.quantity_used, wod.quantity,0)) total_price, 
wodb.baseline_category_id,
bd.reporting_type_id
--, bc.description 
FROM WorkorderHeader woh
	INNER JOIN WorkorderDetail wod ON
		wod.workorder_ID = woh.workorder_ID
		and wod.company_id = woh.company_id
		and wod.profit_ctr_ID = woh.profit_ctr_ID
		ANd woh.workorder_status = 'A'
		and woh.submitted_flag = 'T'
		and wod.resource_type <> 'D'
	INNER JOIN WorkorderDetailBaseline wodb ON
		wodb.workorder_id = wod.workorder_ID
		AND wodb.company_id = wod.company_id
		and wodb.profit_ctr_id = wod.profit_ctr_ID
		and wodb.resource_type = wod.resource_type
		AND wodb.sequence_id = wod.sequence_ID
	INNER JOIN BaselineHeader bh ON
		bh.baseline_id = @baseline_id
	INNER JOIN BaselineDetail bd ON
		bd.baseline_id = bh.baseline_id
		--AND wod.bill_unit_code = bd.bill_unit_code
	INNER JOIN BaselineCategory bc ON
		bd.baseline_category_id = bc.baseline_category_id
		AND wodb.baseline_category_id = bc.baseline_category_id
WHERE 
	woh.start_date >= @start_date
	AND woh.start_date <= @end_date
	AND woh.generator_id = @generator_id
	--AND woh.workorder_id = 1621200
GROUP BY wodb.baseline_category_id, wod.bill_unit_code, bd.reporting_type_id
--,wod.workorder_ID,
--wod.company_id,
--wod.profit_ctr_ID


if @debug > 1
	SELECT * FROM #total_prices order by invoice_unit
	
SELECT tp.*, 
	brt.reporting_type, 
	bc.description as baseline_category_name, 
	bd.expected_amount,
	g.generator_id,
	g.EPA_ID,
	g.site_code,
	g.generator_name
FROM #total_prices tp
	INNER JOIN BaselineReportingType brt ON tp.reporting_type_id = brt.reporting_type_id
	INNER JOIN BaselineCategory bc ON tp.baseline_category_id = bc.baseline_category_id
	LEFT JOIN BaselineDetail bd ON bd.baseline_id = @baseline_id
		and bd.generator_id = @generator_id
	AND bd.generator_id = @generator_id
	AND bd.baseline_category_id = tp.baseline_category_id
	AND bd.bill_unit_code = tp.invoice_unit
	INNER JOIN Generator g ON g.generator_id = @generator_id
--order by tp.workorder_id,total_price
order by tp.baseline_category_id

END

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_baseline_variance] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_baseline_variance] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_baseline_variance] TO [EQAI]
    AS [dbo];

