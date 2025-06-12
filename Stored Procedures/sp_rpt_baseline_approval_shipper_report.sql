--CREATE PROCEDURE [dbo].[sp_rpt_baseline_approval_shipper_report]
--	@generator_id int = NULL,
--	@start_date datetime = NULL,
--	@end_Date datetime = NULL,	
--	@release_code varchar(20) = NULL,
--	@purchase_order varchar(20) = NULL,
--	@debug int = 0
--/*
--History:
--	04/16/2010	RJG	Created
	
	
--Usage:	
--	exec sp_rpt_baseline_approval_shipper_report 34538, '09/1/2009'

--*/
--AS



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
--	The query below needs to be the 2nd part of a union between a first query that inner joins
--	BillingLinkLookup to Receipt To WorkorderHeader and gets the details for all Receipt-oriented lines
--	and the 2nd query (already here, just needs slight changes) then gets WorkorderDetail lines that
--	are *not* linked to a receipt
--*/
--SELECT 
--	bill.trans_source,
--	bill.company_id,
--	bill.profit_ctr_id,
--	bill.invoice_id,
--	woh.generator_id, 
--	g.EPA_ID,
--	g.generator_name, 
--	g.site_code,
--	woh.workorder_ID,
--	bill.manifest,
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
--	CASE 
--		WHEN wod.resource_type = 'D' THEN dbo.fn_get_waste_description(wod.TSDF_code, wod.TSDF_approval_id, wod.profile_id, wod.company_id, wod.profit_ctr_ID)
--		WHEN wod.resource_type <> 'D' then wod.description
--		ELSE 'Unknown'
--	END as transaction_description,
--	dbo.fn_get_workorder_approval_code(wod.TSDF_code, wod.TSDF_approval_id, wod.profile_id, wod.company_id, wod.profit_ctr_ID) as approval_number,
--	woh.start_date as service_date,
--	bill.bill_unit_code,
--	bill.quantity
--FROM   workorderheader woh 
--        INNER JOIN WorkOrderDetail wod 
--			ON wod.workorder_id = woh.workorder_id
--            AND wod.company_id = woh.company_id
--            AND wod.profit_ctr_id = woh.profit_ctr_id
--            AND woh.submitted_flag = 'T'
--            AND woh.workorder_status = 'A'
--            AND wod.resource_type = 'D'
--		INNER JOIN Billing bill ON wod.workorder_ID = bill.receipt_id
--			AND bill.trans_source = 'W'
--			AND bill.company_id = wod.company_id
--			AND bill.profit_ctr_id = wod.profit_ctr_ID
--			AND bill.workorder_resource_type = wod.resource_type
--			AND bill.workorder_sequence_id = wod.sequence_ID
--		INNER JOIN Generator g ON 
--			g.generator_id = woh.generator_id
--WHERE 1 = 
--		CASE WHEN (@start_date IS NOT NULL AND @end_Date IS NOT NULL)
--				AND woh.start_date BETWEEN @start_date AND @end_date
--		THEN 1
--		WHEN @purchase_order IS NOT NULL
--			AND bill.purchase_order = @purchase_order
--			THEN 1
--		WHEN @release_code IS NOT NULL
--			AND bill.release_code = @release_code
--			THEN 1
--		END
--	AND woh.generator_id = @generator_id

--GO
--GRANT EXECUTE
--    ON OBJECT::[dbo].[sp_rpt_baseline_approval_shipper_report] TO [EQWEB]
--    AS [dbo];
--GO
--GRANT EXECUTE
--    ON OBJECT::[dbo].[sp_rpt_baseline_approval_shipper_report] TO [COR_USER]
--    AS [dbo];



--GO
--GRANT EXECUTE
--    ON OBJECT::[dbo].[sp_rpt_baseline_approval_shipper_report] TO [EQAI]
--    AS [dbo];

