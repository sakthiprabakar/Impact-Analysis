CREATE PROCEDURE [dbo].[sp_rpt_baseline_invoice_preview_report_by_approval]
	@baseline_id int = NULL,
	@generator_id int = NULL,
	@start_date datetime = NULL,
	@end_date datetime = NULL,
	@release_code varchar(20) = NULL,
	@purchase_order varchar(20) = NULL,
	@debug int = 0
/*
History:
	04/22/2010	RJG	Created
	05/14/2010	JPB Removed Billing joins.  Marked where EQ Disposal info would be needed in future.
	11/04/2010	RJG	Replaced soon-to-be obsolete columns on WorkOrderDetail with WorkOrderDetailUnit
	
exec sp_rpt_baseline_invoice_preview_report_by_approval 7, 88005, '01/01/2010', NULL, null, 0

*/
AS

SET NOCOUNT ON

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


SELECT 
	woh.generator_id, 
	g.EPA_ID,
	g.generator_name, 
	g.site_code,
	woh.workorder_ID,
	wod.company_id,
	wod.profit_ctr_id,
	dbo.fn_get_waste_description(wod.TSDF_code, wod.TSDF_approval_id, wod.profile_id, wod.company_id, wod.profit_ctr_ID) as transaction_description,
	dbo.fn_get_workorder_approval_code(wod.TSDF_code, wod.TSDF_approval_id, wod.profile_id, wod.company_id, wod.profit_ctr_ID) as approval_number,
	wod.resource_type,
	--woh.start_date as service_date, 
	wodu.bill_unit_code,
	wodb.price,
	isnull(wodu.quantity, wod.quantity) as quantity,
	woh.release_code,
	woh.purchase_order,
	bc.baseline_category_id,
	bd.expected_amount,
	bd.time_period,
	brt.reporting_type,
	bc.description as baseline_category_name,
	wodu.price as work_order_price
	--CAST(0 as float) as total_expected_amount
INTO #result_data
FROM   workorderheader woh 
        INNER JOIN WorkOrderDetail wod ON 1=1 -- 1=1 is for debugging
			AND wod.workorder_id = woh.workorder_id
            AND wod.company_id = woh.company_id
            AND wod.profit_ctr_id = woh.profit_ctr_id
            AND wod.resource_type = 'D'
            AND woh.workorder_status = 'A'
            AND woh.submitted_flag = 'T'
		INNER JOIN WorkOrderDetailUnit wodu ON
			wod.workorder_id = wodu.workorder_id
			AND wod.company_id = wodu.company_id
			AND wod.profit_ctr_id = wodu.profit_ctr_id
			AND wod.sequence_id = wodu.sequence_id
			AND wodu.billing_flag = 'T'			             
        INNER JOIN BaselineHeader bh ON  -- 1=1 is for debugging
			bh.customer_id = woh.customer_ID
		INNER JOIN BaselineDetail bd ON 1=1  -- 1=1 is for debugging
			AND bh.baseline_id = bd.baseline_id
			AND bd.generator_id = woh.generator_id
		INNER JOIN BaselineReportingType brt ON 1=1 -- 1=1 is for debugging
			AND bd.reporting_type_id = brt.reporting_type_id
        INNER JOIN WorkorderDetailBaseline wodb ON 1=1 -- 1=1 is for debugging
			 AND wodb.workorder_id = wod.workorder_ID
			 AND wodb.company_id = wod.company_id
			 AND wodb.profit_ctr_id = wod.profit_ctr_ID
			 AND wodb.resource_type = wod.resource_type
			 AND wodb.sequence_id = wod.sequence_ID
			 AND wodb.baseline_category_id = bd.baseline_category_id
			 AND wodb.company_id = woh.company_id
			 AND wodb.profit_ctr_id = woh.profit_ctr_ID
		INNER JOIN BaselineCategory bc ON 1=1 -- 1=1 is for debugging
			AND bc.baseline_category_id = wodb.baseline_category_id	
			AND bc.customer_id = bh.customer_id
		INNER JOIN Generator g ON 1=1  -- 1=1 is for debugging
			AND g.generator_id = woh.generator_id
WHERE bh.baseline_id = @baseline_id
	AND 1 = 
		CASE WHEN (@start_date IS NOT NULL AND @end_Date IS NOT NULL)
				AND woh.start_date BETWEEN @start_date AND @end_date
			THEN 1
		WHEN @purchase_order IS NOT NULL
			AND woh.purchase_order = @purchase_order
			THEN 1
		WHEN @release_code IS NOT NULL
			AND woh.release_code = @release_code
			THEN 1
		END
	AND woh.generator_id = bd.generator_id
	AND woh.generator_id = @generator_id
	
UNION
/* Handle Non-Disposal Types */
SELECT 
	woh.generator_id, 
	g.EPA_ID,
	g.generator_name, 
	g.site_code,
	woh.workorder_ID,
	wod.company_id,
	wod.profit_ctr_id,
	wod.description as transaction_description,
	dbo.fn_get_workorder_approval_code(wod.TSDF_code, wod.TSDF_approval_id, wod.profile_id, wod.company_id, wod.profit_ctr_ID) as approval_number,
	wod.resource_type,
	--woh.start_date as service_date, 
	wod.bill_unit_code,
	wodb.price,
	(wod.quantity) as quantity,
	woh.release_code,
	woh.purchase_order,
	bc.baseline_category_id,
	bd.expected_amount,
	bd.time_period,
	brt.reporting_type,
	bc.description as baseline_category_name,
	wod.price as work_order_price 
	--CAST(0 as float) as total_expected_amount

FROM   workorderheader woh 
        INNER JOIN WorkOrderDetail wod ON 1=1 -- 1=1 is for debugging
			AND wod.workorder_id = woh.workorder_id
            AND wod.company_id = woh.company_id
            AND wod.profit_ctr_id = woh.profit_ctr_id
            AND woh.workorder_status = 'A'
            AND woh.submitted_flag = 'T'
            AND wod.resource_type <> 'D'
        INNER JOIN BaselineHeader bh ON  -- 1=1 is for debugging
			bh.customer_id = woh.customer_ID
		INNER JOIN BaselineDetail bd ON 1=1  -- 1=1 is for debugging
			AND bh.baseline_id = bd.baseline_id
			AND bd.generator_id = woh.generator_id
		INNER JOIN BaselineReportingType brt ON 1=1 -- 1=1 is for debugging
			AND bd.reporting_type_id = brt.reporting_type_id
        INNER JOIN WorkorderDetailBaseline wodb ON 1=1 -- 1=1 is for debugging
			 AND wodb.workorder_id = wod.workorder_ID
			 AND wodb.company_id = wod.company_id
			 AND wodb.profit_ctr_id = wod.profit_ctr_ID
			 AND wodb.resource_type = wod.resource_type
			 AND wodb.sequence_id = wod.sequence_ID
			 AND wodb.baseline_category_id = bd.baseline_category_id
			 AND wodb.company_id = woh.company_id
			 AND wodb.profit_ctr_id = woh.profit_ctr_ID
		INNER JOIN BaselineCategory bc ON 1=1 -- 1=1 is for debugging
			AND bc.baseline_category_id = wodb.baseline_category_id	
			AND bc.customer_id = bh.customer_id
		INNER JOIN Generator g ON 1=1  -- 1=1 is for debugging
			AND g.generator_id = woh.generator_id
WHERE bh.baseline_id = @baseline_id
	AND 1 = 
		CASE WHEN (@start_date IS NOT NULL AND @end_Date IS NOT NULL)
				AND woh.start_date BETWEEN @start_date AND @end_date
			THEN 1
		WHEN @purchase_order IS NOT NULL
			AND woh.purchase_order = @purchase_order
			THEN 1
		WHEN @release_code IS NOT NULL
			AND woh.release_code = @release_code
			THEN 1
		END
	AND woh.generator_id = bd.generator_id
	AND woh.generator_id = @generator_id	



--SELECT DISTINCT #result_data.baseline_category_id, #result_data.expected_amount INTO #distinct_category_amounts
--	FROM #result_data

--UPDATE #result_data SET total_expected_amount = (SELECT SUM(#distinct_category_amounts.expected_amount) FROM #distinct_category_amounts)

SELECT * FROM #result_data

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_baseline_invoice_preview_report_by_approval] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_baseline_invoice_preview_report_by_approval] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_baseline_invoice_preview_report_by_approval] TO [EQAI]
    AS [dbo];

