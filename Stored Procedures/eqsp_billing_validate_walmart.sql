CREATE PROCEDURE eqsp_billing_validate_walmart
	@debug			tinyint
AS
/***********************************************************************************
This procedure uses the table set up on 5-22-08 called WMProfilePricing to set
the Billing/Receipt price to the old price if pick-up date is before June 1st, 2008.
It will set the price to the new price if the pick-up date is June 1st or after.

Filename:	L:\Apps\SQL\Plt_AI\eqsp_billing_validate_walmart.sql
Load to plt_ai (NTSQL1)

05/30/2008 JDB	Created
06/05/2008 JDB	Modified to remove the billing project 24 from the original select.
				Also added update to billing table so that old receipts get their
				billing project set back to 24.
06/26/2008 JDB	Added support for updating billing project on work order billing lines.
				Also renamed #tmp_billing to #tmp_billing_receipt.
07/09/2008 JDB	Stopped using billing projects 257-260, and now we're back to 24.
07/21/2008 JDB	Stopped using the Billing table for source* fields, and changed to
				BillingLinkLookup table.

SELECT billing_project_id, * FROM Billing WHERE invoice_code = 'Preview_501055' 
SELECT billing_project_id, * FROM Billing WHERE receipt_id = 2781900 
SELECT * FROM Plt_22_AI..ReceiptAudit WHERE modified_by = 'SA-WMFIX' AND date_modified > '6/25/08' and column_name = 'price'
SELECT * FROM Plt_14_AI..WorkOrderAudit WHERE modified_by = 'SA-WMFIX' AND date_modified > '6/25/08' and column_name = 'billing_project_id'
SELECT * FROM Plt_22_AI..WorkOrderAudit WHERE modified_by = 'SA-WMFIX' AND date_modified > '6/25/08' and column_name = 'billing_project_id'
SELECT * FROM Plt_22_AI..ReceiptPrice WHERE receipt_id = 71241 
SELECT * FROM Plt_22_AI..Billing WHERE receipt_id = 71241 
SELECT * FROM WMProfilePricing
eqsp_billing_validate_walmart 1
***********************************************************************************/
DECLARE	@execute_sql	varchar(8000),
		@company_id		tinyint,
		@database		varchar(32),
		@cutoff_date	datetime

SET @cutoff_date = '6/1/2008 00:00'

--------------------------------------------------------
-- Populate temp biling table with receipt records
--------------------------------------------------------
SELECT b.company_id, 
	b.profit_ctr_id, 
	b.receipt_id, 
	b.line_id, 
	b.price_id, 
	b.billing_project_id, 
	b.reference_code,
	b.generator_id,
	g.generator_name,
	g.site_type,
	g.site_code,
	g.generator_state,
	b.profile_id, 
	b.approval_code, 
	wmpp.approval_code AS template_approval_code, 
	bl.source_company_id, 
	bl.source_profit_ctr_id, 
	bl.source_id, 
--	b.source_company_id, 
--	b.source_profit_ctr_id, 
--	b.source_id, 
	b.billing_date,
	CONVERT(datetime, NULL) AS pickup_date,
	b.bill_unit_code, 
	b.quantity, 
	b.price, 
	b.orig_extended_amt, 
	b.waste_extended_amt, 
	b.total_extended_amt, 
	wmpp.price_before_june_1_2008, 
	wmpp.price_after_june_1_2008,
	CONVERT(money, NULL) AS new_price,
	CONVERT(money, NULL) AS new_orig_extended_amt, 
	CONVERT(money, NULL) AS new_waste_extended_amt, 
	CONVERT(money, NULL) AS new_total_extended_amt
INTO #tmp_billing_receipt
FROM Billing b
INNER JOIN Generator g ON b.generator_id = g.generator_id
INNER JOIN WMProfilePricing wmpp ON wmpp.customer_id = b.customer_id
--	AND wmpp.billing_project_id = b.billing_project_id
	AND wmpp.company_id = b.company_id
	AND wmpp.profit_ctr_id = b.profit_ctr_id
	AND wmpp.bill_unit_code = b.bill_unit_code
	AND RIGHT(wmpp.approval_code, LEN(wmpp.approval_code) - 6) = RIGHT(ISNULL(b.approval_code, ''), LEN(b.approval_code) - 6)
LEFT OUTER JOIN BillingLinkLookup bl ON b.company_id = bl.company_id
	AND b.profit_ctr_id = bl.profit_ctr_id
	AND b.receipt_id = bl.receipt_id
WHERE 1=1
AND b.status_code IN ('S','H')
AND b.trans_source = 'R'
AND b.trans_type = 'D'
AND LEFT(b.approval_code, 2) = 'WM'
AND b.customer_id = 10673
--AND b.billing_project_id = 24


--------------------------------------------------------------
-- Loop through the companies/profit centers to get the 
-- pickup dates from the associated work orders
--------------------------------------------------------------
SELECT DISTINCT source_company_id, 0 AS processed
INTO #tmp_source_company_list
FROM #tmp_billing_receipt
WHERE source_company_id > 0

WHILE (SELECT COUNT(*) FROM #tmp_source_company_list WHERE processed = 0) > 0
BEGIN
	SELECT @company_id = MIN(source_company_id)
	FROM #tmp_source_company_list 
	WHERE processed = 0

	SELECT	@database = 'Plt_' + RIGHT('00' + CONVERT(char(2), @company_id), 2) + '_AI'

	SET @execute_sql = 'UPDATE #tmp_billing_receipt SET pickup_date = woh.start_date
	FROM #tmp_billing_receipt b
	INNER JOIN ' + @database + '.dbo.WorkOrderHeader woh ON b.source_company_id = woh.company_id
		AND b.source_profit_ctr_id = woh.profit_ctr_id
		AND b.source_id = woh.workorder_id'

--	IF @debug = 1 PRINT @execute_sql
	EXECUTE (@execute_sql)
		
	UPDATE #tmp_source_company_list SET processed = 1 WHERE source_company_id = @company_id
END

--------------------------------------------------------------
-- If the pickup date is missing, use receipt/billing date
--------------------------------------------------------------
UPDATE #tmp_billing_receipt 
	SET pickup_date = billing_date
WHERE pickup_date IS NULL

--------------------------------------------------------------
-- Update prices on records picked up before 6-1-2008
--------------------------------------------------------------
UPDATE #tmp_billing_receipt 
	SET new_price = price_before_june_1_2008,
	new_orig_extended_amt = quantity * price_before_june_1_2008,
	new_waste_extended_amt = quantity * price_before_june_1_2008,
	new_total_extended_amt = quantity * price_before_june_1_2008
WHERE 1=1
AND ISNULL(quantity, 0.00) > 0.00
AND pickup_date < @cutoff_date

--------------------------------------------------------------
-- Update prices on records picked up on or after 6-1-2008
--------------------------------------------------------------
UPDATE #tmp_billing_receipt 
	SET new_price = price_after_june_1_2008,
	new_orig_extended_amt = quantity * price_after_june_1_2008,
	new_waste_extended_amt = quantity * price_after_june_1_2008,
	new_total_extended_amt = quantity * price_after_june_1_2008
WHERE 1=1
AND ISNULL(quantity, 0.00) > 0.00
AND pickup_date >= @cutoff_date


--------------------------------------------------------------
-- Update billing project and reference code on records 
-- picked up on or after 6-1-2008
--------------------------------------------------------------
--		For receipts using these profiles, if they're on work orders picked up after June 1, 2008, 
--		update the billing project and reference code as appropriate based on the state of the generator (store).  
--		If they're on work orders picked up before June 1, 2008, leave them alone.  (This change to update billing 
--		would happen when finance validates billing records, at the same time we update the prices.)

UPDATE #tmp_billing_receipt 
	SET billing_project_id = 24,
	reference_code = ''
WHERE 1=1
AND approval_code LIKE 'WM%'
AND billing_project_id IN (257, 258, 259, 260)

--UPDATE #tmp_billing_receipt 
--	SET billing_project_id = 24,
--	reference_code = ''
--WHERE 1=1
--AND approval_code LIKE 'WM%'
--AND generator_state IN ('AL', 'GA', 'MS', 'TN',    'AR', 'FL', 'LA', 'TX')
--AND pickup_date < @cutoff_date
--
--UPDATE #tmp_billing_receipt 
--	SET billing_project_id = 258,
--	reference_code = 'WalmartGA0'
--WHERE 1=1
--AND generator_state IN ('AL', 'GA', 'MS', 'TN')
--AND approval_code LIKE 'WM%'
--AND pickup_date >= @cutoff_date
--
--UPDATE #tmp_billing_receipt 
--	SET billing_project_id = 259,
--	reference_code = 'WalmartFA0'
--WHERE 1=1
--AND generator_state IN ('AR', 'FL', 'LA', 'TX')
--AND approval_code LIKE 'WM%'
--AND pickup_date >= @cutoff_date




--------------------------------------------------------------
-- Loop through receipt companies now, and write ReceiptAudit
-- records, and update ReceiptPrice table
--------------------------------------------------------------
SELECT DISTINCT company_id, 0 AS processed
INTO #tmp_company_list
FROM #tmp_billing_receipt
WHERE company_id > 0

WHILE (SELECT COUNT(*) FROM #tmp_company_list WHERE processed = 0) > 0
BEGIN
	SELECT @company_id = MIN(company_id)
	FROM #tmp_company_list 
	WHERE processed = 0

	SELECT	@database = 'Plt_' + RIGHT('00' + CONVERT(char(2), @company_id), 2) + '_AI'

	----------------------------------------------------------------------------------------------------------------
	-- Write ReceiptAudit records first
	----------------------------------------------------------------------------------------------------------------

	-- If we're debugging, just select; otherwise write to ReceiptAudit
	IF @debug = 0
	BEGIN
		SET @execute_sql = 'INSERT INTO ' + @database + '.dbo.ReceiptAudit '
	END
	ELSE
	BEGIN
		SET @execute_sql = ''
	END

	-- Write ReceiptAudit record for ReceiptPrice.price field
	SET @execute_sql = @execute_sql + '
	SELECT b.company_id, 
		b.profit_ctr_id, 
		b.receipt_id, 
		b.line_id, 
		b.price_id, 
		''ReceiptPrice'',
		''price'',
		CONVERT(varchar(10), rp.price),
		CONVERT(varchar(10), b.new_price),
		NULL,
		''SA-WMFIX'',
		''BILL_VAL'',
		GETDATE()
	FROM ' + @database + '.dbo.ReceiptPrice rp
	INNER JOIN #tmp_billing_receipt b ON b.company_id = rp.company_id
		AND b.profit_ctr_id = rp.profit_ctr_id
		AND b.receipt_id = rp.receipt_id
		AND b.line_id = rp.line_id
		AND b.price_id = rp.price_id
		AND b.bill_unit_code = rp.bill_unit_code
	WHERE rp.price <> b.new_price'

	IF @debug = 1 PRINT '----------------------------------------------------------'
	IF @debug = 1 PRINT @execute_sql
	IF @debug = 1 PRINT '----------------------------------------------------------'
	EXECUTE (@execute_sql)



	-- If we're debugging, just select; otherwise write to ReceiptAudit
	IF @debug = 0
	BEGIN
		SET @execute_sql = 'INSERT INTO ' + @database + '.dbo.ReceiptAudit '
	END
	ELSE
	BEGIN
		SET @execute_sql = ''
	END

	-- Write ReceiptAudit record for ReceiptPrice.waste_extended_amt field
	SET @execute_sql = @execute_sql + '
	SELECT b.company_id, 
		b.profit_ctr_id, 
		b.receipt_id, 
		b.line_id, 
		b.price_id, 
		''ReceiptPrice'',
		''waste_extended_amt'',
		CONVERT(varchar(10), rp.waste_extended_amt),
		CONVERT(varchar(10), b.new_waste_extended_amt),
		NULL,
		''SA-WMFIX'',
		''BILL_VAL'',
		GETDATE()
	FROM ' + @database + '.dbo.ReceiptPrice rp
	INNER JOIN #tmp_billing_receipt b ON b.company_id = rp.company_id
		AND b.profit_ctr_id = rp.profit_ctr_id
		AND b.receipt_id = rp.receipt_id
		AND b.line_id = rp.line_id
		AND b.price_id = rp.price_id
		AND b.bill_unit_code = rp.bill_unit_code
	WHERE rp.waste_extended_amt <> b.new_waste_extended_amt'

	IF @debug = 1 PRINT '----------------------------------------------------------'
	IF @debug = 1 PRINT @execute_sql
	IF @debug = 1 PRINT '----------------------------------------------------------'
	EXECUTE (@execute_sql)


	
	-- If we're debugging, just select; otherwise write to ReceiptAudit
	IF @debug = 0
	BEGIN
		SET @execute_sql = 'INSERT INTO ' + @database + '.dbo.ReceiptAudit '
	END
	ELSE
	BEGIN
		SET @execute_sql = ''
	END

	-- Write ReceiptAudit record for ReceiptPrice.total_extended_amt field
	SET @execute_sql = @execute_sql + '
	SELECT b.company_id, 
		b.profit_ctr_id, 
		b.receipt_id, 
		b.line_id, 
		b.price_id, 
		''ReceiptPrice'',
		''total_extended_amt'',
		CONVERT(varchar(10), rp.total_extended_amt),
		CONVERT(varchar(10), b.new_total_extended_amt),
		NULL,
		''SA-WMFIX'',
		''BILL_VAL'',
		GETDATE()
	FROM ' + @database + '.dbo.ReceiptPrice rp
	INNER JOIN #tmp_billing_receipt b ON b.company_id = rp.company_id
		AND b.profit_ctr_id = rp.profit_ctr_id
		AND b.receipt_id = rp.receipt_id
		AND b.line_id = rp.line_id
		AND b.price_id = rp.price_id
		AND b.bill_unit_code = rp.bill_unit_code
	WHERE rp.total_extended_amt <> b.new_total_extended_amt'

	IF @debug = 1 PRINT '----------------------------------------------------------'
	IF @debug = 1 PRINT @execute_sql
	IF @debug = 1 PRINT '----------------------------------------------------------'
	EXECUTE (@execute_sql)


	
	-- If we're debugging, just select; otherwise write to ReceiptAudit
	IF @debug = 0
	BEGIN
		SET @execute_sql = 'INSERT INTO ' + @database + '.dbo.ReceiptAudit '
	END
	ELSE
	BEGIN
		SET @execute_sql = ''
	END

	-- Write ReceiptAudit record for Receipt.billing_project_id
	SET @execute_sql = @execute_sql + '
	SELECT b.company_id, 
		b.profit_ctr_id, 
		b.receipt_id, 
		b.line_id, 
		0, 
		''Receipt'',
		''billing_project_id'',
		CONVERT(varchar(10), r.billing_project_id),
		CONVERT(varchar(10), b.billing_project_id),
		NULL,
		''SA-WMFIX'',
		''BILL_VAL'',
		GETDATE()
	FROM ' + @database + '.dbo.Receipt r
	INNER JOIN #tmp_billing_receipt b ON b.company_id = r.company_id
		AND b.profit_ctr_id = r.profit_ctr_id
		AND b.receipt_id = r.receipt_id
		AND b.line_id = r.line_id
	WHERE r.billing_project_id <> b.billing_project_id'

	IF @debug = 1 PRINT '----------------------------------------------------------'
	IF @debug = 1 PRINT @execute_sql
	IF @debug = 1 PRINT '----------------------------------------------------------'
	EXECUTE (@execute_sql)


	----------------------------------------------------------------------------------------------------------------
	-- Update ReceiptPrice records second
	----------------------------------------------------------------------------------------------------------------
	-- If we're debugging, just select; otherwise update ReceiptPrice
	IF @debug = 0
	BEGIN
		SET @execute_sql = 'UPDATE ' + @database + '.dbo.ReceiptPrice SET price = b.new_price,
			waste_extended_amt = b.new_waste_extended_amt,
			total_extended_amt = b.new_total_extended_amt '
	END
	ELSE
	BEGIN
		SET @execute_sql = 'SELECT rp.company_id, rp.profit_ctr_id, 
			rp.receipt_id, rp.line_id, 
			rp.price_id, rp.bill_unit_code,
			rp.price, b.new_price,
			rp.waste_extended_amt, b.new_waste_extended_amt,
			rp.total_extended_amt, b.new_total_extended_amt '
	END

	SET @execute_sql = @execute_sql + '
		FROM ' + @database + '.dbo.ReceiptPrice rp
		INNER JOIN #tmp_billing_receipt b ON b.company_id = rp.company_id
			AND b.profit_ctr_id = rp.profit_ctr_id
			AND b.receipt_id = rp.receipt_id
			AND b.line_id = rp.line_id
			AND b.price_id = rp.price_id
			AND b.bill_unit_code = rp.bill_unit_code
		WHERE rp.price <> b.new_price'

	IF @debug = 1 PRINT '----------------------------------------------------------'
	IF @debug = 1 PRINT @execute_sql
	IF @debug = 1 PRINT '----------------------------------------------------------'
	EXECUTE (@execute_sql)


	----------------------------------------------------------------------------------------------------------------
	-- Update Receipt records third
	----------------------------------------------------------------------------------------------------------------
	-- If we're debugging, just select; otherwise update Receipt
	IF @debug = 0
	BEGIN
		SET @execute_sql = 'UPDATE ' + @database + '.dbo.Receipt SET billing_project_id = b.billing_project_id '
	END
	ELSE
	BEGIN
		SET @execute_sql = 'SELECT r.company_id, r.profit_ctr_id, 
			r.receipt_id, r.line_id, 
			r.billing_project_id, b.billing_project_id '
	END

	SET @execute_sql = @execute_sql + '
		FROM ' + @database + '.dbo.Receipt r
		INNER JOIN #tmp_billing_receipt b ON b.company_id = r.company_id
			AND b.profit_ctr_id = r.profit_ctr_id
			AND b.receipt_id = r.receipt_id
			AND b.line_id = r.line_id
		WHERE r.billing_project_id <> b.billing_project_id'

	IF @debug = 1 PRINT '----------------------------------------------------------'
	IF @debug = 1 PRINT @execute_sql
	IF @debug = 1 PRINT '----------------------------------------------------------'
	EXECUTE (@execute_sql)
		
	UPDATE #tmp_company_list SET processed = 1 WHERE company_id = @company_id
END




----------------------------------------------------------------------------------------------------------------
-- Update Billing records last
----------------------------------------------------------------------------------------------------------------
-- If we're debugging, just select; otherwise update Billing
IF @debug = 0
BEGIN
	SET @execute_sql = 'UPDATE Billing SET price = b.new_price,
		orig_extended_amt = b.new_orig_extended_amt,
		waste_extended_amt = b.new_waste_extended_amt,
		total_extended_amt = b.new_total_extended_amt,
		billing_project_id = b.billing_project_id,
		reference_code = b.reference_code '
END
ELSE
BEGIN
	SET @execute_sql = 'SELECT bi.invoice_code, bi.company_id, bi.profit_ctr_id, 
		bi.receipt_id, bi.line_id, bi.price_id, 
		bi.profile_id, bi.approval_code, bi.bill_unit_code,
		bi.price, b.new_price,
		bi.orig_extended_amt, b.new_orig_extended_amt,
		bi.waste_extended_amt, b.new_waste_extended_amt,
		bi.total_extended_amt, b.new_total_extended_amt,
		b.billing_project_id, b.reference_code '
END

SET @execute_sql = @execute_sql + '
	FROM Billing bi
	INNER JOIN #tmp_billing_receipt b ON b.company_id = bi.company_id
		AND b.profit_ctr_id = bi.profit_ctr_id
		AND b.receipt_id = bi.receipt_id
		AND b.line_id = bi.line_id
		AND b.price_id = bi.price_id
		AND b.bill_unit_code = bi.bill_unit_code
	WHERE bi.price <> b.new_price'

IF @debug = 1 PRINT '----------------------------------------------------------'
IF @debug = 1 PRINT @execute_sql
IF @debug = 1 PRINT '----------------------------------------------------------'
EXECUTE (@execute_sql)


--------------------------------------------------------
-- Populate temp biling table with work order records
--------------------------------------------------------
SELECT DISTINCT b.company_id, 
	b.profit_ctr_id, 
	b.receipt_id,
	b.invoice_id,
	b.invoice_code,
	b.billing_project_id, 
	b.reference_code,
	b.generator_id,
	g.generator_name,
	g.site_type,
	g.site_code,
	g.generator_state,
	b.billing_date AS pickup_date
INTO #tmp_billing_workorder
FROM Billing b
INNER JOIN Generator g ON b.generator_id = g.generator_id
WHERE 1=1
AND b.status_code IN ('S','H')
AND b.trans_source = 'W'
AND b.customer_id = 10673
--AND b.billing_date > '1/1/08'
AND b.billing_project_id IN (257, 258, 259, 260)
--AND ((b.billing_date <= '5/31/08' AND b.billing_project_id IN (258, 259))
--		OR (b.billing_date > '5/31/08' AND b.billing_project_id = 24))
ORDER BY b.billing_date, b.company_id, b.profit_ctr_id, b.receipt_id


--------------------------------------------------------------
-- Update billing project and reference code on records 
-- picked up on or after 6-1-2008
--------------------------------------------------------------
--		If the work order start date is on or after June 1, 2008, 
--		update the billing project and reference code as appropriate based on the state of the generator (store).  
--		If the work order start date is before June 1, 2008, leave them alone.  (This change to update billing 
--		would happen when finance validates billing records, at the same time we update the prices.)


UPDATE #tmp_billing_workorder 
	SET billing_project_id = 24,
	reference_code = ''
-- SELECT company_id, profit_ctr_id, receipt_id, pickup_date, billing_project_id, reference_code
FROM #tmp_billing_workorder
WHERE 1=1
AND billing_project_id IN (257, 258, 259, 260)


--UPDATE #tmp_billing_workorder 
--	SET billing_project_id = 24,
--	reference_code = ''
---- SELECT company_id, profit_ctr_id, receipt_id, pickup_date, billing_project_id, reference_code
--FROM #tmp_billing_workorder
--WHERE 1=1
--AND generator_state IN ('AL', 'GA', 'MS', 'TN',    'AR', 'FL', 'LA', 'TX')
--AND pickup_date < @cutoff_date
--
--UPDATE #tmp_billing_workorder 
--	SET billing_project_id = 258,
--	reference_code = 'WalmartGA0'
---- SELECT company_id, profit_ctr_id, receipt_id, pickup_date, billing_project_id, reference_code
--FROM #tmp_billing_workorder
--WHERE 1=1
--AND generator_state IN ('AL', 'GA', 'MS', 'TN')
--AND pickup_date >= @cutoff_date
--
--UPDATE #tmp_billing_workorder 
--	SET billing_project_id = 259,
--	reference_code = 'WalmartFA0'
---- SELECT company_id, profit_ctr_id, receipt_id, pickup_date, billing_project_id, reference_code
--FROM #tmp_billing_workorder
--WHERE 1=1
--AND generator_state IN ('AR', 'FL', 'LA', 'TX')
--AND pickup_date >= @cutoff_date




----------------------------------------------------------------
-- Loop through receipt companies now, and write WorkOrderAudit
-- records, and update WorkOrderHeader table
----------------------------------------------------------------
SELECT DISTINCT company_id, 0 AS processed
INTO #tmp_company_list_wo
FROM #tmp_billing_workorder
WHERE company_id > 0

WHILE (SELECT COUNT(*) FROM #tmp_company_list_wo WHERE processed = 0) > 0
BEGIN
	SELECT @company_id = MIN(company_id)
	FROM #tmp_company_list_wo 
	WHERE processed = 0

	SELECT	@database = 'Plt_' + RIGHT('00' + CONVERT(char(2), @company_id), 2) + '_AI'

	----------------------------------------------------------------------------------------------------------------
	-- Write WorkOrderAudit records first
	----------------------------------------------------------------------------------------------------------------
	-- If we're debugging, just select; otherwise write to WorkOrderAudit
	IF @debug = 0
	BEGIN
		SET @execute_sql = 'INSERT INTO ' + @database + '.dbo.WorkOrderAudit '
	END
	ELSE
	BEGIN
		SET @execute_sql = ''
	END

	-- Write WorkOrderAudit record for WorkOrderHeader.billing_project_id
	SET @execute_sql = @execute_sql + '
	SELECT DISTINCT b.company_id, 
		b.profit_ctr_id, 
		b.receipt_id AS workorder_id, 
		'''' AS resource_type,
		0 AS sequence_id, 
		''WorkOrderHeader'',
		''billing_project_id'',
		CONVERT(varchar(10), w.billing_project_id),
		CONVERT(varchar(10), b.billing_project_id),
		NULL,
		''SA-WMFIX'',
		GETDATE()
	FROM ' + @database + '.dbo.WorkOrderHeader w
	INNER JOIN #tmp_billing_workorder b ON b.company_id = w.company_id
		AND b.profit_ctr_id = w.profit_ctr_id
		AND b.receipt_id = w.workorder_id
	WHERE w.billing_project_id <> b.billing_project_id'

	IF @debug = 1 PRINT '----------------------------------------------------------'
	IF @debug = 1 PRINT @execute_sql
	IF @debug = 1 PRINT '----------------------------------------------------------'
	EXECUTE (@execute_sql)


	----------------------------------------------------------------------------------------------------------------
	-- Update WorkOrderHeader records next
	----------------------------------------------------------------------------------------------------------------
	-- If we're debugging, just select; otherwise update WorkOrderHeader
	IF @debug = 0
	BEGIN
		SET @execute_sql = 'UPDATE ' + @database + '.dbo.WorkOrderHeader SET billing_project_id = b.billing_project_id '
	END
	ELSE
	BEGIN
		SET @execute_sql = 'SELECT w.company_id, w.profit_ctr_id, w.workorder_id, 
			w.billing_project_id, b.billing_project_id '
	END

	SET @execute_sql = @execute_sql + '
		FROM ' + @database + '.dbo.WorkOrderHeader w
		INNER JOIN #tmp_billing_workorder b ON b.company_id = w.company_id
			AND b.profit_ctr_id = w.profit_ctr_id
			AND b.receipt_id = w.workorder_id
		WHERE w.billing_project_id <> b.billing_project_id'

	IF @debug = 1 PRINT '----------------------------------------------------------'
	IF @debug = 1 PRINT @execute_sql
	IF @debug = 1 PRINT '----------------------------------------------------------'
	EXECUTE (@execute_sql)
		
	UPDATE #tmp_company_list_wo SET processed = 1 WHERE company_id = @company_id
END




----------------------------------------------------------------------------------------------------------------
-- Update Billing records last
----------------------------------------------------------------------------------------------------------------
-- If we're debugging, just select; otherwise update Billing
IF @debug = 0
BEGIN
	SET @execute_sql = 'UPDATE Billing SET billing_project_id = b.billing_project_id,
		reference_code = b.reference_code '
END
ELSE
BEGIN
	SET @execute_sql = 'SELECT bi.invoice_code, bi.company_id, bi.profit_ctr_id, bi.receipt_id, 
		bi.billing_project_id, b.billing_project_id, b.reference_code '
END

SET @execute_sql = @execute_sql + '
	FROM Billing bi
	INNER JOIN #tmp_billing_workorder b ON b.company_id = bi.company_id
		AND b.profit_ctr_id = bi.profit_ctr_id
		AND b.receipt_id = bi.receipt_id
	WHERE 1=1
	AND bi.trans_source = ''W''
	AND bi.billing_project_id <> b.billing_project_id'

IF @debug = 1 PRINT '----------------------------------------------------------'
IF @debug = 1 PRINT @execute_sql
IF @debug = 1 PRINT '----------------------------------------------------------'
EXECUTE (@execute_sql)


DROP TABLE #tmp_billing_receipt
DROP TABLE #tmp_billing_workorder

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[eqsp_billing_validate_walmart] TO [EQAI]
    AS [dbo];

