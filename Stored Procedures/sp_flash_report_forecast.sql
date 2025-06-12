CREATE PROCEDURE sp_flash_report_forecast
	@company_ID		int
,	@profit_ctr_id	int
,	@date_from		datetime
,	@date_to		datetime
,	@cust_id_from	int
,	@cust_id_to		int
,	@territory_code	char(2)
,	@debug_flag		int = 0
AS
/*****************************************************************************************************
This SP summarizes the revenue from all stages of work orders.  Work Orders that have not yet
been priced are calculated as if they have been priced

Filename:	L:\Apps\SQL\EQAI\sp_flash_report_forecast.sql
PB Object(s):	None
SQL Object(s):	Called from sp_flash_report, sp_flash_report_detail,
		sp_flash_report_outstanding, sp_flash_report_problem,
		sp_flash_report_problem_only, sp_flash_report_problem_only_notes

11/27/2000 SCC	Created
06/15/2001 LJT	Added a dummy record to the #tmp_revenue just in case there were no detail lines to be priced. 
		The workorder wouldshow up with a total of 0.
06/03/2003 JDB	Added profit_ctr_id to TSDFApproval.
04/14/2005 JDB	Added bill_unit_code for TSDFApproval
07/17/2006 RG	revised for quoteheader qoutedetail
07/24/2006 RG   fixed issues wt tsdf approval view changes
03/27/2007 JDB	Fixed join between WorkOrderDetail and TSDFApproval for disposal calculations.
		Added "AND d.bill_rate > 0" to the WHERE clause for Disposal (formerly it was retrieving MAN Only,
		which is bill_rate = -1)
		Added support for Work Orders that use Profiles.
		Modified calculation to first get pricing from the work order line, then calculate from 
		either the resource class, TSDF Approval, or Profile.  See "CASE resource_type"
		and "COALESCE(d.price, pqd.price)".
04/16/2007 SCC	Changed to use workorderheader.submitted_flag and CustomerBilling.territory_code
04/06/2010 RJG	Changed WorkOrderQuoteDetail references to join against the "WorkOrderQuoteDetail" and have it use company_id as well as profit_ctr_id
09/21/2010 SK	Moved to run on Plt_AI, added input arg Company_ID
				Report runs for a non-zero company_id & profit_ctr_id combination
				Changed the joins to join to the selected company 
01/12/2012 SK	Changed to use the new WorkOrderTypeHeader.workorder_type_id (GL standardization project)

sp_flash_report_forecast 14, 0, '06-01-2006 00:00:00','06-30-2006 23:59:59', 1, 999999, '99', 0
*****************************************************************************************************/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

DECLARE 
	@wo_id				int,
	@wo_id_prev			int,
	@wo_count			int,
	@base_rate_quote_id	int, 
	@project_quote_id	int,
	@customer_quote_id	int,
	@project_code		varchar(15), 
	@customer_id		int,
	@detail_count		int,
	@fixed_price_total	money,
	@fixed_price_amount	money, 
	@fixed_price_count	int,
	@fixed_price_flag	char(1),
	@rowcount			int,
	@cust_discount		decimal(7,2)
 
-- Create a table to hold results of unpriced work order pricing forecasts
CREATE TABLE #tmp_price (
	bill_rate			float		NULL,
	quantity			float		NULL,
	resource_to_price	varchar(10)	NULL,
	group_code			varchar(10)	NULL,
	group_instance_id	int			NULL,
	price				money		NULL,
	priced_flag			int			NULL	)

-- SELECT the base rate quote for this profit_ctr in this company
SELECT @base_rate_quote_id= base_rate_quote_id
FROM profitcenter 
WHERE profit_ctr_id = @profit_ctr_id
AND company_ID = @company_ID

-- SELECT the header records for work in process
SELECT 	woh.workorder_id,
	woh.workorder_type_id,
	woh.workorder_status,
	woh.project_code, 
	woh.customer_id,
	woh.cust_discount,
	woh.end_date
INTO #tmp_wo
FROM WorkOrderHeader woh
INNER JOIN CustomerBilling cb 
	ON cb.customer_id = woh.customer_id
	AND cb.billing_project_id = ISNULL(woh.billing_project_id, 0)
	AND (@territory_code = '99' OR cb.territory_code = @territory_code)
WHERE woh.workorder_status IN ('N', 'C', 'D') 
	AND woh.end_date BETWEEN @date_from AND @date_to
	AND woh.customer_id BETWEEN @cust_id_from AND @cust_id_to
	AND woh.company_id = @company_id	
	AND woh.profit_ctr_id = @profit_ctr_id
	--AND (@territory_code = '99' OR cb.territory_code = @territory_code)
ORDER BY workorder_id

-- How many Work orders did we get?
SELECT @wo_count = @@ROWCOUNT
IF @debug_flag = 1 PRINT 'Selecting from #tmp_wo: Work order count ' + CONVERT(varchar(40), @wo_count)
IF @debug_flag = 1 SELECT * FROM #tmp_wo

-- Calculate prices for each work order in each company, profit_ctr combination
SELECT @wo_id_prev = 0
WHILE @wo_count > 0
BEGIN
	-- Get info on this work order
	SET ROWCOUNT 1
	SELECT 
		@wo_id			= workorder_id,
		@project_code	= project_code, 
		@customer_id	= customer_id,
		@cust_discount	= ROUND(cust_discount, 2)
	FROM #tmp_wo 
	WHERE workorder_id > @wo_id_prev

	SELECT @wo_count = @@ROWCOUNT
	SET ROWCOUNT 0
	IF @wo_count <= 0 GOTO DONE

	IF @debug_flag = 1 PRINT 'Work order ID ' + CONVERT(varchar(40), @wo_id)
	IF @debug_flag = 1 PRINT 'Customer ID: ' + CONVERT(varchar(40), @customer_id) + ' and discount: ' + CONVERT(varchar(30), @cust_discount)

	-- Get the quote ID for project_code
	IF @project_code IS NULL
	BEGIN
		SET @project_quote_id = 0
		SET @fixed_price_flag = 'F'
	END
	ELSE
		SELECT @project_quote_id = quote_id, @fixed_price_flag = fixed_price_flag 
		FROM WorkorderQuoteHeader
		WHERE project_code = @project_code
		AND quote_type = 'P'
		AND company_id = @company_id
		AND profit_ctr_id = @profit_ctr_id

	IF @debug_flag = 1 PRINT 'Project Quote: ' + CONVERT(varchar(40), @project_quote_id)

	---------------------------
	-- Fixed Price Workorder --
	---------------------------
	IF @fixed_price_flag = 'T'
	BEGIN
		-- Get the amounts already priced
		SELECT @fixed_price_total = SUM(woh.total_price), 
			@fixed_price_count = COUNT(woh.total_price)
		FROM WorkOrderHeader woh
		WHERE woh.quote_id = @project_quote_id
		AND woh.workorder_status IN ('A', 'P')
		AND woh.company_id = @company_ID
		AND woh.profit_ctr_ID = @profit_ctr_id

		IF @fixed_price_count = 0
			SELECT @fixed_price_amount = 0
		ELSE
			SELECT @fixed_price_amount = @fixed_price_total / @fixed_price_count

		-- If no Workorders have yet billed from the fixed price quote,
		-- get the entire fixed price amount from the quote
		IF @fixed_price_count = 0
		BEGIN
			SELECT @fixed_price_total = fixed_price
				FROM WorkorderQuoteHeader 
				WHERE quote_id = @project_quote_id
				AND company_id = @company_ID
				AND profit_ctr_id = @profit_ctr_id
			-- How many workorders are we processing under this project quote?
			SELECT @fixed_price_count = COUNT(*)
				FROM #tmp_wo 
				WHERE project_code = @project_code
			-- Divvy total amount between workorders to be processed here
			IF @fixed_price_count = 0
				SELECT @fixed_price_amount = @fixed_price_total
			ELSE
				SELECT @fixed_price_amount = @fixed_price_total / @fixed_price_count
		END
		
		IF @debug_flag = 1 PRINT 'fixed price total: ' + CONVERT(varchar(40), @fixed_price_total )
			+ ' fixed price count: ' + CONVERT(varchar(40), @fixed_price_count )
			+ ' fixed price amount: ' + CONVERT(varchar(40), @fixed_price_amount )

		-- Insert a record for the forecasted amount
		INSERT #tmp_revenue (
			revenue,
			workorder_status,
			account_desc, 
			customer_id,
			workorder_id,
			end_date,
			pricing_method,
			fixed_price,
			company_id,
			profit_ctr_id	)
		SELECT @fixed_price_amount, 
			workorder_status, 
			WOTH.account_desc, 
			customer_id, 
			workorder_id, 
			end_date, 
			'C', 
			'T',
			@company_ID,
			@profit_ctr_id
		FROM #tmp_wo
		JOIN WorkOrderTypeHeader WOTH
			ON WOTH.workorder_type_id = #tmp_wo.workorder_type_id
		--JOIN glaccount
		--	ON glaccount.account_class = 'O'
		--	AND glaccount.profit_ctr_id = @profit_ctr_id
		--	AND glaccount.company_id = @company_id
		--	AND glaccount.account_type = #tmp_wo.workorder_type
		WHERE #tmp_wo.workorder_id = @wo_id
		
	END

	------------------------------
	-- Regular Priced Workorder --
	------------------------------
	IF @fixed_price_flag = 'F'
	BEGIN

		-- Get the quote ID for customer
		SELECT @customer_quote_id = ISNULL(quote_id, 0)
		FROM WorkorderQuoteHeader 
		WHERE quote_id = @customer_id
		AND quote_type = 'C'
		AND company_id = @company_ID
		AND profit_ctr_id = @profit_ctr_id
		IF @@ROWCOUNT = 0 SELECT @customer_quote_id = 0
	
		IF @debug_flag = 1 PRINT 'Customer Quote: ' + CONVERT(varchar(40), @customer_quote_id)

		-- Delete any previously priced lines
		DELETE FROM #tmp_price

		-- Get Detail lines to forecast pricing.  Price based on resource class.
		-- The price is retrieved to pick any 'Other' detail line pricing
		INSERT #tmp_price 
		SELECT ISNULL(bill_rate, 0),
			ISNULL(quantity_used, 0), 
			resource_class_code,
			group_code,
			group_instance_id, 
			CASE resource_type 
				WHEN 'E' THEN ISNULL(price, 0)
				WHEN 'L' THEN ISNULL(price, 0)
				WHEN 'O' THEN ISNULL(price, 0)
				ELSE 0
				END AS price,
			0 AS priced_flag
			FROM WorkOrderDetail 
			WHERE workorder_id = @wo_id
			AND profit_ctr_id = @profit_ctr_id
			AND company_id = @company_ID
			AND group_instance_id = 0
			AND ISNULL(bill_rate, 0) > 0
		UNION ALL
		-- Include groups
		SELECT DISTINCT ISNULL(bill_rate, 0),
			ISNULL(quantity_used, 0), 
			resource_class_code,
			group_code,
			group_instance_id,
			0 AS price,
			0 AS priced_flag
			FROM WorkOrderDetail 
			WHERE workorder_id = @wo_id
			AND profit_ctr_id = @profit_ctr_id
			AND company_id = @company_ID
			AND resource_type = 'G'
			AND ISNULL(bill_rate, 0) > 0


		-- Price any groups at the highest bill rate of its group members
		UPDATE #tmp_price SET bill_rate = (SELECT MAX(ISNULL(bill_rate,0)) 
			FROM WorkOrderDetail 
			WHERE workorder_id = @wo_id
			AND profit_ctr_id = @profit_ctr_id
			AND company_id = @company_ID
			AND WorkOrderDetail.group_code = #tmp_price.group_code
			AND WorkOrderDetail.group_instance_id = #tmp_price.group_instance_id
			AND ISNULL(bill_rate, 0) > 0
			)
		WHERE #tmp_price.group_instance_id > 0

		IF @debug_flag = 1 SELECT * FROM #tmp_price
			
		-- Identify number of detail lines that need pricing
		SELECT @detail_count = COUNT(*) FROM #tmp_price WHERE price = 0
		IF @detail_count > 0
		BEGIN
			/* Try to price assigned resource from project - Doubletime */
			UPDATE #tmp_price SET price = qd.price_dt, priced_flag = 1
			FROM WorkorderQuoteDetail qd
			WHERE qd.quote_id = @project_quote_id 
			AND qd.resource_item_code = #tmp_price.resource_to_price
			AND qd.group_code = #tmp_price.group_code
			AND #tmp_price.bill_rate = 2
			AND #tmp_price.price = 0
			AND qd.company_id = @company_id
			AND qd.profit_ctr_id = @profit_ctr_id

			SELECT @rowcount = @@ROWCOUNT
			IF @debug_flag = 1 AND @rowcount > 0 PRINT 'Project priced ' + CONVERT(varchar(40), @rowcount) + ' rows (doubletime)'

			/* Try to price assigned resource from project - Overtime */
			UPDATE #tmp_price SET price = qd.price_ot, priced_flag = 1
			FROM WorkorderQuoteDetail qd
			WHERE qd.quote_id = @project_quote_id 
			AND qd.group_code = #tmp_price.group_code					
			AND qd.resource_item_code = #tmp_price.resource_to_price
			AND #tmp_price.bill_rate = 1.5
			AND #tmp_price.price = 0
			AND qd.company_id = @company_id
			AND qd.profit_ctr_id = @profit_ctr_id			

			SELECT @rowcount = @@ROWCOUNT
			IF @debug_flag = 1 AND @rowcount > 0 PRINT 'Project priced ' + CONVERT(varchar(40), @rowcount) + ' rows (time and a half)'

			/* Try to price assigned resource from project - Standard */
			UPDATE #tmp_price SET price = qd.price, priced_flag = 1
			FROM WorkorderQuoteDetail qd
			WHERE qd.quote_id = @project_quote_id 
			AND qd.group_code = #tmp_price.group_code					
			AND qd.resource_item_code = #tmp_price.resource_to_price
			AND #tmp_price.bill_rate = 1
			AND #tmp_price.price = 0
			AND qd.company_id = @company_id
			AND qd.profit_ctr_id = @profit_ctr_id			

			SELECT @rowcount = @@ROWCOUNT
			IF @debug_flag = 1 AND @rowcount > 0 PRINT 'Project priced ' + CONVERT(varchar(40), @rowcount) + ' rows'

			/* Try to price assigned resource from customer - Doubletime*/
			UPDATE #tmp_price SET price = qd.price_dt, priced_flag = 1
			FROM WorkorderQuoteDetail qd
			WHERE qd.quote_id = @customer_quote_id 
			AND qd.group_code = #tmp_price.group_code					
			AND qd.resource_item_code = #tmp_price.resource_to_price
			AND #tmp_price.bill_rate = 2
			AND #tmp_price.price = 0
			AND qd.company_id = @company_id
			AND qd.profit_ctr_id = @profit_ctr_id			

			SELECT @rowcount = @@ROWCOUNT
			IF @debug_flag = 1 AND @rowcount > 0 PRINT 'Customer priced ' + CONVERT(varchar(40), @rowcount) + ' rows (doubletime)'

			/* Try to price assigned resource from customer - Overtime */
			UPDATE #tmp_price SET price = qd.price_ot, priced_flag = 1
			FROM WorkorderQuoteDetail qd
			WHERE qd.quote_id = @customer_quote_id 
			AND qd.group_code = #tmp_price.group_code						
			AND qd.resource_item_code = #tmp_price.resource_to_price
			AND #tmp_price.bill_rate = 1.5
			AND #tmp_price.price = 0
			AND qd.company_id = @company_id
			AND qd.profit_ctr_id = @profit_ctr_id			

			SELECT @rowcount = @@ROWCOUNT
			IF @debug_flag = 1 AND @rowcount > 0 PRINT 'Customer priced ' + CONVERT(varchar(40), @rowcount) + ' rows (time and a half)'

			/* Try to price assigned resource from customer - Standard */
			UPDATE #tmp_price SET price = qd.price, priced_flag = 1
			FROM WorkorderQuoteDetail qd
			WHERE qd.quote_id = @customer_quote_id 
			AND qd.group_code = #tmp_price.group_code						
			AND qd.resource_item_code = #tmp_price.resource_to_price
			AND #tmp_price.bill_rate = 1
			AND #tmp_price.price = 0
			AND qd.company_id = @company_id
			AND qd.profit_ctr_id = @profit_ctr_id			

			SELECT @rowcount = @@ROWCOUNT
			IF @debug_flag = 1 AND @rowcount > 0 PRINT 'Customer priced ' + CONVERT(varchar(40), @rowcount) + ' rows (standard)'

			/* Try to price assigned resource from base - Doubletime */
			UPDATE #tmp_price SET price = qd.price_dt, priced_flag = 1
			FROM WorkorderQuoteDetail qd
			WHERE qd.quote_id = @base_rate_quote_id 
			AND qd.group_code = #tmp_price.group_code						
			AND qd.resource_item_code = #tmp_price.resource_to_price
			AND #tmp_price.bill_rate = 2
			AND #tmp_price.price = 0
			AND qd.company_id = @company_id
			AND qd.profit_ctr_id = @profit_ctr_id			

			SELECT @rowcount = @@ROWCOUNT
			IF @debug_flag = 1 AND @rowcount > 0 PRINT 'Base rate priced ' + CONVERT(varchar(40), @rowcount) + ' rows (Doubletime)'

			/* Try to price assigned resource from base - Overtime */
			UPDATE #tmp_price SET price = qd.price_ot, priced_flag = 1
			FROM WorkorderQuoteDetail qd
			WHERE qd.quote_id = @base_rate_quote_id 
			AND qd.group_code = #tmp_price.group_code						
			AND qd.resource_item_code = #tmp_price.resource_to_price
			AND #tmp_price.bill_rate = 1.5
			AND #tmp_price.price = 0
			AND qd.company_id = @company_id
			AND qd.profit_ctr_id = @profit_ctr_id			
			
			SELECT @rowcount = @@ROWCOUNT
			IF @debug_flag = 1 AND @rowcount > 0 PRINT 'Base rate priced ' + CONVERT(varchar(40), @rowcount) + ' rows (time and a half)'

			/* Try to price assigned resource from base - Standard */
			UPDATE #tmp_price SET price = qd.price, priced_flag = 1
			FROM WorkorderQuoteDetail qd
			WHERE qd.quote_id = @base_rate_quote_id 
			AND qd.group_code = #tmp_price.group_code						
			AND qd.resource_item_code = #tmp_price.resource_to_price
			AND #tmp_price.bill_rate = 1
			AND #tmp_price.price = 0
			AND qd.company_id = @company_id
			AND qd.profit_ctr_id = @profit_ctr_id			

			SELECT @rowcount = @@ROWCOUNT
			IF @debug_flag = 1 AND @rowcount > 0 print 'Base rate priced ' + CONVERT(varchar(40), @rowcount) + ' rows (Standard)'
		END
		
		IF @debug_flag = 1 print 'selecting priced detail lines'
		IF @debug_flag = 1 SELECT * FROM #tmp_price WHERE priced_flag = 1
		IF @debug_flag = 1 print 'selecting detail lines that were not priced'
		IF @debug_flag = 1 SELECT * FROM #tmp_price WHERE priced_flag = 0

		------------------------------------------------------------------------------
		-- Add a zero total record just in case no detail lines were assigned to this 
		-- workorder it would still show up on the report
		------------------------------------------------------------------------------
		INSERT #tmp_revenue (
			revenue,
			workorder_status,
			account_desc, 
			customer_id,
			workorder_id,
			end_date,
			pricing_method,
			fixed_price,
			company_id,
			profit_ctr_id	)
		SELECT 0,
			workorder_status,
			WOTH.account_desc,
			#tmp_wo.customer_id,
			#tmp_wo.workorder_id,
			#tmp_wo.end_date,
			'C',
			'F',
			@company_ID,
			@profit_ctr_id
		FROM  #tmp_wo
		JOIN WorkOrderTypeHeader WOTH
			ON WOTH.workorder_type_id = #tmp_wo.workorder_type_id
		--JOIN glaccount
		--	ON glaccount.account_class = 'O'
		--	AND glaccount.profit_ctr_id = @profit_ctr_id
		--	AND glaccount.company_id = @company_id
		--	AND glaccount.account_type = #tmp_wo.workorder_type
		WHERE #tmp_wo.workorder_id = @wo_id
		GROUP BY workorder_status,
			woth.account_desc,
			#tmp_wo.customer_id, 
			#tmp_wo.workorder_id, 
			#tmp_wo.end_date


		------------------------------------------------------------------------------
		-- Store detail results in revenue table
		------------------------------------------------------------------------------
		INSERT #tmp_revenue (
			revenue,
			workorder_status,
			account_desc, 
			customer_id,
			workorder_id,
			end_date,
			pricing_method,
			fixed_price,
			company_id,
			profit_ctr_id	)
		SELECT SUM((t.quantity * t.price) * ((100 - @cust_discount)/100)),
			workorder_status,
			woth.account_desc,
			#tmp_wo.customer_id,
			#tmp_wo.workorder_id,
			#tmp_wo.end_date,
			'C',
			'F',
			@company_id,
			@profit_ctr_id
		FROM #tmp_price t
		JOIN #tmp_wo
			ON #tmp_wo.workorder_id = @wo_id
		JOIN WorkOrderTypeHeader WOTH
			ON WOTH.workorder_type_id = #tmp_wo.workorder_type_id
		--JOIN glaccount
		--	ON glaccount.account_class = 'O'
		--	AND glaccount.profit_ctr_id = @profit_ctr_id
		--	AND glaccount.company_id = @company_id
		--	AND glaccount.account_type = #tmp_wo.workorder_type
		GROUP BY workorder_status, 
			woth.account_desc, 
			#tmp_wo.customer_id, 
			#tmp_wo.workorder_id, 
			#tmp_wo.end_date

		------------------------------------------------------------------------------
		-- Get the disposal prices (from TSDF approvals and Profiles)
		------------------------------------------------------------------------------
		INSERT #tmp_revenue(
			revenue,
			workorder_status,
			account_desc, 
			customer_id,
			workorder_id,
			end_date,
			pricing_method,
			fixed_price,
			company_id,
			profit_ctr_id	)
		SELECT SUM((d.bill_rate * ISNULL(d.quantity_used, 0) * COALESCE(d.price, tp.price)) * ((100 - @cust_discount)/100)),
			workorder_status,
			WOTH.account_desc,
			#tmp_wo.customer_id,
			#tmp_wo.workorder_id,
			#tmp_wo.end_date,
			'C',
			'F',
			@company_ID,
			@profit_ctr_id
		FROM WorkOrderDetail d
		INNER JOIN TSDFApprovalPrice tp 
			ON tp.tsdf_approval_id = d.tsdf_approval_id
			AND tp.bill_unit_code = d.bill_unit_code
			AND tp.company_id = d.company_id
			AND tp.profit_ctr_id = d.profit_ctr_id
		INNER JOIN TSDFApproval t 
			ON t.tsdf_approval_id = tp.tsdf_approval_id
			AND t.tsdf_approval_status = 'A'
	        AND t.company_id = tp.company_id
	        AND t.profit_ctr_id = tp.profit_ctr_id
		INNER JOIN TSDF 
			ON TSDF.TSDF_code = d.TSDF_code
			AND ISNULL(TSDF.eq_flag, 'F') = 'F' -- Get Work Orders using TSDF Approvals
		JOIN #tmp_wo
			ON #tmp_wo.workorder_id = d.workorder_id
		JOIN WorkOrderTypeHeader WOTH
			ON WOTH.workorder_type_id = #tmp_wo.workorder_type_id
		--JOIN GLAccount
		--	ON GLAccount.account_class = 'O' 
		--	AND GLAccount.account_type = #tmp_wo.workorder_type
		--	AND GLAccount.profit_ctr_id = @profit_ctr_id
		--	AND GLAccount.company_id = @company_ID
		WHERE d.workorder_id = @wo_id
			AND d.company_id = @company_ID
			AND d.profit_ctr_id = @profit_ctr_id
	       	AND d.resource_type = 'D'
			AND d.bill_rate > 0
		GROUP BY workorder_status,
			WOTH.account_desc,
			#tmp_wo.customer_id, 
			#tmp_wo.workorder_id,
			#tmp_wo.end_date
		UNION

		SELECT SUM((d.bill_rate * ISNULL(d.quantity_used, 0) * COALESCE(d.price, pqd.price)) * ((100 - @cust_discount)/100)),
			workorder_status,
			WOTH.account_desc,
			#tmp_wo.customer_id,
			#tmp_wo.workorder_id,
			#tmp_wo.end_date,
			'C',
			'F',
			@company_ID,
			@profit_ctr_id
		FROM WorkOrderDetail d
		INNER JOIN ProfileQuoteDetail pqd 
			ON pqd.profile_id = d.profile_id
			AND pqd.company_id = d.company_id
			AND pqd.profit_ctr_id = d.profit_ctr_id
			AND pqd.bill_unit_code = d.bill_unit_code
		INNER JOIN TSDF 
			ON TSDF.TSDF_code = d.TSDF_code
			AND ISNULL(TSDF.eq_flag, 'F') = 'T'		-- Get Work Orders using Profiles
		JOIN #tmp_wo
			ON #tmp_wo.workorder_id = d.workorder_id
		JOIN WorkOrderTypeHeader WOTH
			ON WOTH.workorder_type_id = #tmp_wo.workorder_type_id
		--JOIN GLAccount
		--	ON GLAccount.account_class = 'O' 
		--	AND GLAccount.account_type = #tmp_wo.workorder_type
		--	AND GLAccount.profit_ctr_id = @profit_ctr_id
		--	AND GLAccount.company_id = @company_ID
		WHERE d.workorder_id = @wo_id
			AND d.profit_ctr_id = @profit_ctr_id
	        AND d.company_id = @company_id
			AND d.resource_type = 'D'
			AND d.bill_rate > 0
		GROUP BY workorder_status,
			WOTH.account_desc,
			#tmp_wo.customer_id, 
			#tmp_wo.workorder_id,
			#tmp_wo.end_date

		IF @debug_flag = 1 PRINT 'These are the revenue records for workorder: ' + CONVERT(varchar(30),@wo_id)
		IF @debug_flag = 1 SELECT * FROM #tmp_revenue WHERE workorder_id = @wo_id

	END
	SELECT @wo_id_prev = @wo_id
END

DONE:

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_flash_report_forecast] TO [EQAI]
    AS [dbo];

