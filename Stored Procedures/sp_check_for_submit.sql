DROP PROCEDURE IF EXISTS sp_check_for_submit
GO

CREATE PROCEDURE sp_check_for_submit ( 
	@receipt_id int , 
	@profit_ctr_id int, 
	@company_id int, 
	@trans_source char(1)
	)
AS
/***************************************************************************************
LOAD to Plt_AI

Filename:		L:\IT Apps\SQL-Deploy\Prod\NTSQL1\Plt_AI\Procedures\sp_check_for_submit.sql
PB Object(s):	w_receipt, w_workorder, w_popup_billing_submit

11/21/2007 RG	Created
01/22/2008 WAC	Don't want fixed price $0 workorders to get submitted to the billing table 
		regardless of the status of any related workorder line.  In addition, the users
		create non-fixed price workorders with $0 price line items that have a non-zero
		cost.  Since the introduction of central invoicing these workorders are generating
		$0 invoices, however, $0 invoices were not being generated prior to central invoicing.
		This procedure now prevents this type of workorder from generating billing records in
		the same manner as $0 fixed price workorders.
02/19/2011 JDB	Updated to account for WorkOrderDetailUnit records.
06/30/2011 SK	Allow $0 workorders which are not fixed price, but have print to invoice lines
				to be submitted to billing.
				Also if a work order has no print on invoice lines but has a billing link, then allow it to
				be submitted.
08/05/2011 SK	Uncommented the line to check print on invoice flag in WorkOrderDetail		
08/12/2011 SK	Added link_required_flag value to determine if WO should be submitted to Billing	
08/23/2011 JDB/SK	Updated the queries for work orders to take into account the extended_price and bill_rate
					fields, similar to the way the sp_billing_submit procedure works.
06/10/2014 JDB	Moved from Plt_XX_AI to Plt_AI.
11/16/2021 MPM	DevOps 28058 - Added logic for the new profit center "prevent WO billing" flag.
06/17/2022 MPM	DevOps 41806 - If WOH.submitted_flag is being set to 'T', then:
					1. If there are already one or more rows in WorkOrderTracking, set the time_out
						and business_minutes on the latest tracking row.
					2. Add a 'COMP' row to the WorkOrderTracking table.
					3. Set tracking_days and tracking_bus_days on WorkOrderHeader.
					4. Update tracking_id and tracking_contact on WorkOrderHeader.
07/18/2022 AGC  DevOps 46839 prevent inserting null tracking_id into WorkOrderTracking table by initializing @curr_tracking_id to zero.
11/26/2024 Sailaja Rally #US127391 - EQAI Tracking feature addition in Inbound Receipt Screen - 11/26/2024
12/4/2024 Sailaja - Rally #US127391 - EQAI Tracking feature addition in Inbound Receipt Screen - Added trans_mode as 'I' to be applicable only for Inbound receipts

sp_check_for_submit 13921400 , 0, 14, 'W'
sp_check_for_submit 2816207, 01, 15, 'W'
****************************************************************************************/
DECLARE 
	@billing_link_id		int
,	@fixed_price			char(1)
,	@invoice_count			int
,	@invoice_count_2		int
,	@link_reqd_flag			char(1)
,	@status					varchar(30)
,	@sum_extended_price		money
,	@sum_extended_price_2	money
,	@total_price			money
,	@user_id				varchar(30)
,	@curr_tracking_id		int = 0
,	@curr_tracking_contact	varchar(10)
,	@tracking_days			int
,	@tracking_bus_days		int
,	@submit_date			datetime
,	@error_value			int
,	@min_time_in			datetime
,	@business_minutes		int
,	@trans_mode				char(1)

SELECT @submit_date = GETDATE()

-- workorder
IF @trans_source = 'W'
BEGIN

-- are there any workorder detail records that will be printing on the invoice?
--  (sp_billing_submit only selects workorder details where print_on_invoice_flag = 'T')
SELECT	@invoice_count = COUNT(*),
	@sum_extended_price = SUM(ISNULL(extended_price, 0))
FROM WorkorderDetail 
JOIN ProfitCenter
	ON ProfitCenter.company_ID = WorkOrderDetail.company_id
	AND ProfitCenter.profit_ctr_id = WorkOrderDetail.profit_ctr_ID
	AND ISNULL(ProfitCenter.prevent_work_order_billing_flag, 'F') = 'F'
WHERE WorkorderDetail.workorder_id = @receipt_id
AND WorkorderDetail.profit_ctr_id = @profit_ctr_id
AND WorkorderDetail.company_id = @company_id
AND ISNULL(WorkorderDetail.print_on_invoice_flag, 'F') = 'T'
AND WorkorderDetail.bill_rate >= 0
AND WorkorderDetail.resource_type <> 'D'

IF @invoice_count IS NULL SET @invoice_count = 0
IF @sum_extended_price IS NULL SET @sum_extended_price = 0.00

--PRINT 'invoice_count:  ' + CONVERT(varchar(10), @invoice_count)
--PRINT 'extended_price:  ' + CONVERT(varchar(10), @sum_extended_price)

--------------------------------------------------------------------------------------------------------
-- Now we must also get the workorderdetailunit records with prices so that we can submit work orders
-- with ONLY disposal on them.  
--
-- EQAI 6.0 deploy 2/19/11 JDB
--------------------------------------------------------------------------------------------------------
SELECT	@invoice_count_2 = COUNT(*),
	@sum_extended_price_2 = SUM(ISNULL(WorkOrderDetailUnit.extended_price, 0))
FROM WorkOrderDetailUnit
INNER JOIN WorkOrderDetail ON WorkOrderDetail.company_id = WorkOrderDetailUnit.company_id
	AND WorkOrderDetail.profit_ctr_id = WorkOrderDetailUnit.profit_ctr_id
	AND WorkOrderDetail.workorder_ID = WorkOrderDetailUnit.workorder_ID
	AND WorkOrderDetail.sequence_ID = WorkOrderDetailUnit.sequence_id
	AND WorkOrderDetail.resource_type = 'D'
	--AND WorkOrderDetail.print_on_invoice_flag = 'T'
JOIN ProfitCenter
	ON ProfitCenter.company_ID = WorkOrderDetail.company_id
	AND ProfitCenter.profit_ctr_id = WorkOrderDetail.profit_ctr_ID
	AND ISNULL(ProfitCenter.prevent_work_order_billing_flag, 'F') = 'F'
WHERE WorkOrderDetailUnit.workorder_id = @receipt_id
AND WorkOrderDetailUnit.profit_ctr_id = @profit_ctr_id
AND WorkOrderDetailUnit.company_id = @company_id
AND WorkOrderDetailUnit.billing_flag = 'T'
AND ((WorkOrderDetailUnit.extended_price > 0 AND WorkorderDetail.bill_rate > 0)
	OR (WorkOrderDetailUnit.extended_price = 0 AND ISNULL(WorkorderDetail.print_on_invoice_flag, 'F') = 'T' AND WorkorderDetail.bill_rate >= 0))



IF @invoice_count_2 IS NULL SET @invoice_count_2 = 0
IF @sum_extended_price_2 IS NULL SET @sum_extended_price_2 = 0.00

SELECT @invoice_count = @invoice_count + @invoice_count_2
SELECT @sum_extended_price = @sum_extended_price + @sum_extended_price_2

--PRINT 'invoice_count:  ' + CONVERT(varchar(10), @invoice_count)
--PRINT 'extended_price:  ' + CONVERT(varchar(10), @sum_extended_price)

--  Fetch the deciding parameters
SELECT	@fixed_price = fixed_price_flag, 
	@total_price = total_price,
	@billing_link_id = billing_link_id
FROM workorderheader 
WHERE workorder_id = @receipt_id
AND   profit_ctr_id = @profit_ctr_id
AND   company_id = @company_id

-- fixed price workorders are a special case
IF @fixed_price = 'T' 
BEGIN
    IF @total_price = 0
	BEGIN
		-- it doesn't matter how many lines on a fixed price workorder have been flagged
		-- to print on the invoice, if the fixed price PO is for 0 dollars then we DO NOT
		-- want it in the billing table
		select @invoice_count = 0
	END
    ELSE
	BEGIN
		-- This fixed price workorder is for a non-zero amount.  Might not have any lines
		-- that print on the invoice so lets make sure that we set the invoice_count to 
		-- a positive number since we DO want this workorder to find its way to the billing
		-- table
		SELECT @invoice_count = 1
	END
END
ELSE
-- this is not a fixed price workorder
IF @invoice_count = 0 AND @billing_link_id IS NOT NULL
BEGIN
	-- make sure the link is not exempt
	SELECT @link_reqd_flag = link_required_flag
	FROM BillingLinkLookup 
	WHERE billing_link_id = @billing_link_id
	AND company_id = @company_id
	AND profit_ctr_id = @profit_ctr_id
	
	-- Even if there are no print-on-invoice lines on this work order, submit it to billing because it
	-- has a billing link ID
	IF @link_reqd_flag <> 'E' SELECT @invoice_count = 1
END
--else
--begin
-- --   if IsNull(@sum_extended_price,0) = 0 and @billing_link_id IS NULL
--	--begin
--	--	-- total extended_price for all detail records marked for printing on the invoice
--	--	-- equals 0, which of course produces a $0 invoice.  The users use the workorder system
--	--	-- for some kind of costing purposes and create line items for $0 price.  They don't 
--	--	-- want these $0 priced workorders to generate invoices, so stop the invoice creation
--	--	-- in the same manner that we stop a $0 fixed price workorder.
--	--	-- IF the billing_link_id is NOT NULL then the user has this workorder linked with other
--	--	-- transactions so we want to let this transaction through to billing so that all linked
--	--	-- transactions can be invoiced.
--	--	select @invoice_count = 0
--	--end
--end

if @invoice_count = 0 
begin
	-- there is nothing for this workorder that will need to go to the billing table so ...

	-- get logged in userid so we'll have something for the submitted_by field
	set @user_id = SYSTEM_USER
	if Right(@user_id,3) = '(2)'
	begin
		-- remove the '(2)' from the end of the user id
		SET @user_id = Substring(@user_id, 1, Len(@user_id) -3)
	end

	-- set the submit status here since sp_billing_submit will NOT be executed for this WO

	/* DevOps 41806 - If WOH.submitted_flag is being set to 'T', then:
					1. If there are already one or more rows in WorkOrderTracking, set the time_out
						and business_minutes on the latest tracking row.
					2. Add a 'COMP' row to the WorkOrderTracking table.
					3. Set tracking_days and tracking_bus_days on WorkOrderHeader.
					4. Update tracking_id and tracking_contact on WorkOrderHeader.
	*/
	
	IF EXISTS (SELECT 1
	FROM WorkOrderTracking t
	WHERE t.company_id = @company_id
	AND t.profit_ctr_id = @profit_ctr_id
	AND t.workorder_id = @receipt_id)
	BEGIN
		SELECT @curr_tracking_id = MAX(tracking_id)
		FROM WorkOrderTracking t
		WHERE t.company_id = @company_id
		AND t.profit_ctr_id = @profit_ctr_id
		AND t.workorder_id = @receipt_id

		SELECT @curr_tracking_contact = tracking_contact
		FROM WorkOrderTracking t
		WHERE t.company_id = @company_id
		AND t.profit_ctr_id = @profit_ctr_id
		AND t.workorder_id = @receipt_id
		AND t.tracking_id = @curr_tracking_id

		SELECT @min_time_in = MIN(time_in)
		FROM WorkOrderTracking
		WHERE company_id = @company_id
		AND profit_ctr_id = @profit_ctr_id
		AND workorder_id = @receipt_id

		SELECT @business_minutes = dbo.fn_business_minutes(time_in, @submit_date)
		FROM WorkOrderTracking
		WHERE company_id = @company_id
		AND profit_ctr_id = @profit_ctr_id
		AND workorder_id = @receipt_id
		AND tracking_id = @curr_tracking_id

		UPDATE WorkOrderTracking
		SET time_out = @submit_date,
			business_minutes = @business_minutes,
			modified_by = @user_id,
			date_modified = @submit_date
		WHERE company_id = @company_id
			AND profit_ctr_id = @profit_ctr_id
			AND workorder_id = @receipt_id	
			AND tracking_id = @curr_tracking_id

		SELECT @error_value = @@ERROR

		IF @error_value <> 0
		BEGIN
			-- Raise an error and return
			RAISERROR ('Error updating WorkOrderTracking.', 16, 1)
			RETURN
		END

		-- Write audit record for the update of WorkOrderTracking.business_minutes
		INSERT WorkOrderAudit (company_id, profit_ctr_id, workorder_id, resource_type, sequence_id, table_name, column_name, before_value, after_value, audit_reference, modified_by, date_modified)
		VALUES (@company_id, @profit_ctr_id, @receipt_id, '', 0, 'WorkOrderTracking', 'business_minutes', '(blank)', CAST(@business_minutes AS VARCHAR(255)), 'tracking_id = ' + CAST(@curr_tracking_id AS VARCHAR(255)) + ' updated', @user_id, @submit_date)

		SELECT @error_value = @@ERROR
		
		IF @error_value <> 0
		BEGIN		
			-- Raise an error and return
			RAISERROR ('Error inserting WorkOrderAudit record for update of WorkOrderTracking.business_minutes.', 16, 1)
			RETURN
		END

		-- Write audit record for the update of WorkOrderTracking.time_out
		INSERT WorkOrderAudit (company_id, profit_ctr_id, workorder_id, resource_type, sequence_id, table_name, column_name, before_value, after_value, audit_reference, modified_by, date_modified)
		VALUES (@company_id, @profit_ctr_id, @receipt_id, '', 0, 'WorkOrderTracking', 'time_out', '(blank)', CAST(@submit_date AS VARCHAR(255)), 'tracking_id = ' + CAST(@curr_tracking_id AS VARCHAR(255)) + ' updated', @user_id, @submit_date)

		SELECT @error_value = @@ERROR
		
		IF @error_value <> 0
		BEGIN		
			-- Raise an error and return
			RAISERROR ('Error inserting WorkOrderAudit record for update of WorkOrderTracking.time_out.', 16, 1)
			RETURN
		END
	END

	INSERT INTO WorkOrderTracking (company_id, profit_ctr_id, workorder_id, tracking_id, tracking_status, time_in, time_out, comment, business_minutes, added_by, date_added, modified_by, date_modified)
	VALUES (@company_id, @profit_ctr_id, @receipt_id, @curr_tracking_id + 1, 'COMP', @submit_date, @submit_date, 'Completed', 0, @user_id, @submit_date, @user_id, @submit_date)

	SELECT @error_value = @@ERROR
		
	IF @error_value <> 0
	BEGIN		
		-- Raise an error and return
		RAISERROR ('Error inserting WorkOrderTracking record.', 16, 1)
		RETURN
	END

	-- Write an audit record for the insert into WorkOrderTracking
	INSERT WorkOrderAudit (company_id, profit_ctr_id, workorder_id, resource_type, sequence_id, table_name, column_name, before_value, after_value, audit_reference, modified_by, date_modified)
	VALUES (@company_id, @profit_ctr_id, @receipt_id, '', 0, 'WorkOrderTracking', 'All', '(no record)', '(new record added)', '''Completed'' tracking record added', @user_id, @submit_date)

	SELECT @error_value = @@ERROR
		
	IF @error_value <> 0
	BEGIN		
		-- Raise an error and return
		RAISERROR ('Error inserting WorkOrderAudit record for insert into WorkOrderTracking.', 16, 1)
		RETURN
	END

	update workorderheader
	set workorder_status = 'A', 
		submitted_flag = 'T', 
		date_submitted = GETDATE(), 
		submitted_by = @user_id,
		tracking_id = @curr_tracking_id + 1,
		tracking_days = CASE WHEN @min_time_in IS NOT NULL THEN DATEDIFF(dd, @min_time_in, @submit_date) ELSE NULL END,
		tracking_bus_days = CASE WHEN @min_time_in IS NOT NULL THEN dbo.fn_business_days(@min_time_in, @submit_date) ELSE NULL END,
		tracking_contact = NULL
        where workorder_id = @receipt_id
		and profit_ctr_id = @profit_ctr_id
		and company_id = @company_id

	IF @@ROWCOUNT <= 0 
	BEGIN 
		SELECT @invoice_count = -1
	END

END
GOTO finish
END


--- receipt
if @trans_source = 'R'
begin

select @invoice_count = count(*) from receiptprice 
where receipt_id = @receipt_id
and   profit_ctr_id = @profit_ctr_id
and   company_id = @company_id
and   print_on_invoice_flag = 'T'

if @invoice_count = 0 
begin
	-- Sailaja - Rally #US127391 - EQAI Tracking feature addition in Inbound Receipt Screen - 11/26/2024 - Start
		set @user_id = SYSTEM_USER
		if Right(@user_id,3) = '(2)'
		begin
			SET @user_id = Substring(@user_id, 1, Len(@user_id) -3)
		end

		SELECT DISTINCT @trans_mode = trans_mode 
		FROM Receipt
		where receipt_id = @receipt_id
		and   profit_ctr_id = @profit_ctr_id
		and   company_id = @company_id

		IF @trans_mode = 'I'
		Begin			
			/* If Receipt.submitted_flag is being set to 'T', then:
							1. If there are already one or more rows in ReceiptTracking, set the time_out
								and business_minutes on the latest tracking row.
							2. Add a 'COMP' row to the ReceiptTracking table.
							3. Set tracking_days and tracking_bus_days on Receipt.
							4. Update tracking_id and tracking_contact on Receipt.
			*/
		
			IF EXISTS (SELECT 1
			FROM ReceiptTracking t
			WHERE t.company_id = @company_id
			AND t.profit_ctr_id = @profit_ctr_id
			AND t.receipt_id = @receipt_id)
			BEGIN
				SELECT @curr_tracking_id = MAX(tracking_id)
				FROM ReceiptTracking t
				WHERE t.company_id = @company_id
				AND t.profit_ctr_id = @profit_ctr_id
				AND t.receipt_id = @receipt_id

				SELECT @curr_tracking_contact = tracking_contact
				FROM ReceiptTracking t
				WHERE t.company_id = @company_id
				AND t.profit_ctr_id = @profit_ctr_id
				AND t.receipt_id = @receipt_id
				AND t.tracking_id = @curr_tracking_id

				SELECT @min_time_in = MIN(time_in)
				FROM ReceiptTracking
				WHERE company_id = @company_id
				AND profit_ctr_id = @profit_ctr_id
				AND receipt_id = @receipt_id

				SELECT @business_minutes = dbo.fn_business_minutes(time_in, @submit_date)
				FROM ReceiptTracking
				WHERE company_id = @company_id
				AND profit_ctr_id = @profit_ctr_id
				AND receipt_id = @receipt_id
				AND tracking_id = @curr_tracking_id

				UPDATE ReceiptTracking
				SET time_out = @submit_date,
					business_minutes = @business_minutes,
					modified_by = @user_id,
					date_modified = @submit_date
				WHERE company_id = @company_id
					AND profit_ctr_id = @profit_ctr_id
					AND receipt_id = @receipt_id	
					AND tracking_id = @curr_tracking_id

				SELECT @error_value = @@ERROR

				IF @error_value <> 0
				BEGIN
					-- Raise an error and return
					RAISERROR ('Error updating ReceiptTracking.', 16, 1)
					RETURN
				END
	
				-- Write audit record for the update of ReceiptTracking.business_minutes
				INSERT ReceiptAudit (company_id, profit_ctr_id, receipt_id, line_id, price_id, table_name, column_name, 
							before_value, after_value, audit_reference, modified_by, modified_from, date_modified)
				VALUES (@company_id, @profit_ctr_id, @receipt_id, 0, 0, 'ReceiptTracking', 'business_minutes', '(blank)',
						CAST(@business_minutes AS VARCHAR(255)),'tracking_id = ' + CAST(@curr_tracking_id AS VARCHAR(255)) + ' updated', @user_id, 'SB', @submit_date)
					
				SELECT @error_value = @@ERROR
			
				IF @error_value <> 0
				BEGIN		
					-- Raise an error and return
					RAISERROR ('Error inserting ReceiptAudit record for update of ReceiptTracking.business_minutes.', 16, 1)
					RETURN
				END

				-- Write audit record for the update of ReceiptTracking.time_out
			
				INSERT ReceiptAudit (company_id, profit_ctr_id, receipt_id, line_id, price_id, table_name, column_name, 
								before_value, after_value, audit_reference, modified_by, modified_from, date_modified)
				VALUES (@company_id, @profit_ctr_id, @receipt_id, 0, 0, 'ReceiptTracking', 'time_out', '(blank)', CAST(@submit_date AS VARCHAR(255)),
					'tracking_id = ' + CAST(@curr_tracking_id AS VARCHAR(255)) + ' updated', @user_id, 'SB', @submit_date)
				
				SELECT @error_value = @@ERROR
			
				IF @error_value <> 0
				BEGIN		
					-- Raise an error and return
					RAISERROR ('Error inserting ReceiptAudit record for update of ReceiptTracking.time_out.', 16, 1)
					RETURN
				END
			END

			INSERT INTO ReceiptTracking (company_id, profit_ctr_id, receipt_id, tracking_id, tracking_status, time_in, time_out, comment, business_minutes, added_by, date_added, modified_by, date_modified)
			VALUES (@company_id, @profit_ctr_id, @receipt_id, @curr_tracking_id + 1, 'COMP', @submit_date, @submit_date, 'Completed', 0, @user_id, @submit_date, @user_id, @submit_date)

			SELECT @error_value = @@ERROR
			
			IF @error_value <> 0
			BEGIN		
				-- Raise an error and return
				RAISERROR ('Error inserting ReceiptTracking record.', 16, 1)
				RETURN
			END

			-- Write an audit record for the insert into ReceiptTracking
			INSERT ReceiptAudit (company_id, profit_ctr_id, receipt_id, line_id, price_id, table_name, column_name,
								before_value, after_value, audit_reference, modified_by, modified_from, date_modified)
			VALUES (@company_id, @profit_ctr_id, @receipt_id, 0, 0, 'ReceiptTracking', 'All', '(no record)', '(new record added)',
					'''Completed'' tracking record added', @user_id, 'SB', @submit_date)
				
			SELECT @error_value = @@ERROR
			
			IF @error_value <> 0
			BEGIN		
				-- Raise an error and return
				RAISERROR ('Error inserting ReceiptAudit record for insert into ReceiptTracking.', 16, 1)
				RETURN
			END
		END
	-- Sailaja - Rally #US127391 - EQAI Tracking feature addition in Inbound Receipt Screen - 11/26/2024 - End
	-- Added updating tracking_id, tracking_days, tracking_bus_days and tracking_contact in Receipt table
	update receipt
	set submitted_flag = 'T', date_submitted = GetDate(), submitted_by = @user_id,
		tracking_id = @curr_tracking_id + 1,
		tracking_days = CASE WHEN @min_time_in IS NOT NULL THEN DATEDIFF(dd, @min_time_in, @submit_date) ELSE NULL END,
		tracking_bus_days = CASE WHEN @min_time_in IS NOT NULL THEN dbo.fn_business_days(@min_time_in, @submit_date) ELSE NULL END,
		tracking_contact = NULL
        where receipt_id = @receipt_id
	and   profit_ctr_id = @profit_ctr_id
	and   company_id = @company_id

	IF @@ROWCOUNT <= 0 
	BEGIN 
		SELECT @invoice_count = -1
	END

END
END

finish:
SELECT @invoice_count AS invoice_count

GO

GRANT EXECUTE
    ON OBJECT::[dbo].[sp_check_for_submit] TO [EQAI]
GO