--CREATE PROCEDURE [dbo].[sp_rpt_baseline_cost_save]
--	@baseline_id int = NULL,
--	@generator_id int = NULL,
--	@start_date datetime = NULL,
--	@end_Date datetime = NULL,
--	@release_code varchar(20) = NULL,
--	@purchase_order varchar(20) = NULL,
--	@debug int = 0
--/*
--History:
--	04/21/2010	RJG	Created
--	05/14/2010	JPB Removed Billing joins.  Marked where EQ Disposal info would be needed in future.
	
--*/
--AS
--BEGIN

----SET @baseline_id = 20

--/*
--SELECT TOP 100 * FROM WorkorderDetail where TSDF_approval_code IS NOT NULL order by workorder_id desc

--SELECT TOP 5000 * FROM ProfileTracking WHERE time_in > '1/1/2010' order by time_in asc
--SELECT * FROM Profile WHERE profile_id = 348802
--SELECT * FROM ProfileQuoteHeader where profile_id = 348802
--SELECT * FROM ProfileQuoteDetail where profile_id = 348802
--SELECT * FROM ProfileQuoteApproval where profile_id = 348802
--SELECT TOP 10 * FROM TSDFApproval where tsdf_approval_code = 'WMHW02L'
--SELECT * FROM Profile WHERE profile_id = 327179

--exec sp_rpt_baseline_cost_save 20, 75223, '12/1/2009'

--*/

----SELECT TOP 10 tsdf_approval_code, profile_id, * FROM WorkorderDetail WHERE tsdf_approval_code is not null order by workorder_id desc

----declare @end_date datetime = NULL
----declare @start_date datetime = NULL

----if @month_startdate IS NOT NULL
----begin
----	SET @start_date = CAST(MONTH(@month_startdate) as varchar(20)) + '/1/' + cast(YEAR(@month_startdate) as varchar(20))
----	SET @end_date = DATEADD(SECOND, -1, DATEADD(MONTH, 1, @start_date))
----end

--if @debug > 0
--begin
--	print @start_date
--	print @end_date
--end

--if (@start_date IS NULL AND @end_Date IS NULL) AND @release_code IS NULL AND @purchase_order IS NULL
--BEGIN
--	RAISERROR ('One of either @start_date & @end_date, @release_code, or @purchase_order must be filled in', -- Message text.
--               16, -- Severity.
--               1 -- State.
--               );
--	RETURN
--END

--/* 
--	for EQ Disposal...
--	Need to run a similar select into for workorders inner joined to billing link lookup, inner joined to receipt.
--	... when this runs, insert the workorder's workorder_id, company_id, profit_ctr_id to new fields in the #table
--	... Then after that insert finishes, run the version below with a (and workorder_id not in #table) clause
--	... To add the workorders that are not linked to the set that are.  Then report/work off that #table
--*/

--SELECT
--	woh.generator_id,
--	g.EPA_ID,
--	g.generator_name,
--	g.site_code,
--	woh.workorder_ID,
--	wod.company_id,
--	wod.profit_ctr_id,
--	CASE
--		WHEN wod.resource_type = 'D' THEN dbo.fn_get_waste_description(wod.TSDF_code, wod.TSDF_approval_id, wod.profile_id, wod.company_id, wod.profit_ctr_ID)
--		WHEN wod.resource_type <> 'D' then wod.description
--		ELSE 'Unknown'
--	END as transaction_description,
--	dbo.fn_get_workorder_approval_code(wod.TSDF_code, wod.TSDF_approval_id, wod.profile_id, wod.company_id, wod.profit_ctr_ID) as approval_number,
--	wod.resource_type,
--	/* if no work order manifest receive date, use woh.start_date */
--	CASE WHEN EXISTS (SELECT MIN(wom.transporter_receive_date) FROM WorkorderManifest wom
--								WHERE wom.workorder_ID = woh.workorder_ID
--								AND wom.company_id = woh.company_id
--								AND wom.profit_ctr_ID = woh.profit_ctr_ID
--								HAVING MIN(wom.transporter_receive_date) IS NOT NULL)
--					THEN
--							(SELECT MIN(wom.transporter_receive_date) FROM WorkorderManifest wom
--								WHERE wom.workorder_ID = woh.workorder_ID
--								AND wom.company_id = woh.company_id
--								AND wom.profit_ctr_ID = woh.profit_ctr_ID
--								HAVING MIN(wom.transporter_receive_date) IS NOT NULL)
--		ELSE woh.start_date
--	END	as start_date,
--	wod.bill_unit_code,
--	wodb.price,
--	isnull(wod.quantity_used, wod.quantity) as quantity,
--	woh.release_code,
--	woh.purchase_order,
--	bc.baseline_category_id,
--	bd.expected_amount,
--	bd.time_period,
--	brt.reporting_type,
--	bc.description as baseline_category_name,
--	CAST(0 as float) as total_expected_amount,
--	ih.invoice_code
--INTO #result_data
--FROM   workorderheader woh
--        INNER JOIN WorkOrderDetail wod ON 1=1 -- 1=1 is for debugging
--			AND wod.workorder_id = woh.workorder_id
--            AND wod.company_id = woh.company_id
--            AND wod.profit_ctr_id = woh.profit_ctr_id
--            AND woh.workorder_status = 'A'
--            AND woh.submitted_flag = 'T'
--        INNER JOIN BaselineHeader bh ON  -- 1=1 is for debugging
--			bh.customer_id = woh.customer_ID
--		INNER JOIN BaselineDetail bd ON 1=1  -- 1=1 is for debugging
--			AND bh.baseline_id = bd.baseline_id
--			AND bd.generator_id = woh.generator_id
--		INNER JOIN BaselineReportingType brt ON 1=1 -- 1=1 is for debugging
--			AND bd.reporting_type_id = brt.reporting_type_id
--        INNER JOIN WorkorderDetailBaseline wodb ON 1=1 -- 1=1 is for debugging
--			 AND wodb.workorder_id = wod.workorder_ID
--			 AND wodb.company_id = wod.company_id
--			 AND wodb.profit_ctr_id = wod.profit_ctr_ID
--			 AND wodb.resource_type = wod.resource_type
--			 AND wodb.sequence_id = wod.sequence_ID
--			 AND wodb.baseline_category_id = bd.baseline_category_id
--			 AND wodb.company_id = woh.company_id
--			 AND wodb.profit_ctr_id = woh.profit_ctr_ID
--		INNER JOIN BaselineCategory bc ON 1=1 -- 1=1 is for debugging
--			AND bc.baseline_category_id = wodb.baseline_category_id
--			AND bc.customer_id = bh.customer_id
--		INNER JOIN Generator g ON 1=1  -- 1=1 is for debugging
--			AND g.generator_id = woh.generator_id
--		INNER JOIN Billing bill ON wod.workorder_ID = bill.receipt_id
--			AND bill.trans_source = 'W'
--			AND bill.company_id = wod.company_id
--			AND bill.profit_ctr_id = wod.profit_ctr_id
--		INNER JOIN InvoiceHeader ih ON bill.invoice_id = ih.invoice_id
--WHERE bh.baseline_id = @baseline_id
--	AND 1 =
--		CASE WHEN (@start_date IS NOT NULL AND @end_Date IS NOT NULL)
--				AND woh.start_date BETWEEN @start_date AND @end_date
--			THEN 1
--		WHEN @purchase_order IS NOT NULL
--			AND woh.purchase_order = @purchase_order
--			THEN 1
--		WHEN @release_code IS NOT NULL
--			AND woh.release_code = @release_code
--			THEN 1
--		END
--	AND woh.generator_id = bd.generator_id
--	AND woh.generator_id = @generator_id



--SELECT DISTINCT #result_data.baseline_category_id, #result_data.expected_amount INTO #distinct_category_amounts
--	FROM #result_data

--UPDATE #result_data SET total_expected_amount = (SELECT SUM(#distinct_category_amounts.expected_amount) FROM #distinct_category_amounts)

--SELECT * FROM #result_data

--END

--GO
--GRANT EXECUTE
--    ON OBJECT::[dbo].[sp_rpt_baseline_cost_save] TO [EQWEB]
--    AS [dbo];
--GO
--GRANT EXECUTE
--    ON OBJECT::[dbo].[sp_rpt_baseline_cost_save] TO [COR_USER]
--    AS [dbo];



--GO
--GRANT EXECUTE
--    ON OBJECT::[dbo].[sp_rpt_baseline_cost_save] TO [EQAI]
--    AS [dbo];

