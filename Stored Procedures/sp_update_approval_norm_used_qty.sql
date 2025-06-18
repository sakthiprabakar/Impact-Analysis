CREATE OR ALTER PROCEDURE [dbo].[sp_update_approval_norm_used_qty]
	@company_id					INT,
	@profit_ctr_id				INT,
	@receipt_id					INT,
	@modified_by				VARCHAR(100),
	@debug						INT = 0

AS
BEGIN
/***************************************************************************************
This stored procedure updates the used_quantity and/or the status of rows in the
ProfileQuoteApprovalNormThreshold (PQANT) table. This happens when a receipt is moved to 
"Waste Accepted" status, and the receipt has disposal lines in which the approval and 
bill unit match the approval and bill unit of an active row (or rows) in PQANT.

This stored procedure is called from near the end of wf_save of w_receipt, after the 
receipt has been moved to "Waste Accepted" status.

Date		Who		Comment
----		---		-------
05/23/2025 	MPM		Rally US139909 - Created.
05/28/2025	MPM		Rally US139909 - Modification to the final check before doing updates.

****************************************************************************************/

	DECLARE 
		@return_msg					VARCHAR(500) = 'OK',
		@approval_code				VARCHAR(15),
		@bill_unit_code				VARCHAR(4),
		@sequence_id				INT,
		@threshold_quantity			FLOAT,
		@threshold_percent			INT,
		@used_quantity				FLOAT,
		@remaining_quantity			FLOAT,
		@updated_used_quantity		FLOAT,
		@receipt_quantity			FLOAT,
		@overage_quantity			FLOAT = 0,
		@comparison_quantity		FLOAT,
		@profile_id					INT,
		@now 						DATETIME
		
	-- Insert all approval_code/bill_unit_code combinations on the receipt into a temp table, with the sum of the bill quantity for each combination,
	-- because it's very possible that the receipt contains 2 or more lines/rows for each combination.
	SELECT 
		approval_code, 
		bill_unit_code, 
		SUM(quantity) AS receipt_quantity
	INTO #receipt
	FROM Receipt
	WHERE company_id = @company_id
	AND profit_ctr_id = @profit_ctr_id
	AND receipt_id = @receipt_id
	AND trans_type = 'D' -- disposal
	AND receipt_status NOT IN ('V', 'R') -- line isn't voided or rejected
	GROUP BY approval_code, bill_unit_code
	
	-- Insert relevant ProfileQuoteApprovalNormThreshold info into a temp table, together with a column for updated_used_quantity that will be updated later in this proc
	SELECT  
		p.profile_id,
		p.approval_code, 
		p.container_size, 
		p.sequence_id, 
		p.threshold_quantity, 
		p.threshold_percent, 
		CONVERT(FLOAT, p.used_qty) AS used_quantity,
		p.threshold_quantity * p.threshold_percent/100.0 - p.used_qty AS remaining_quantity,
		CONVERT(FLOAT, 0) AS updated_used_quantity
	INTO #pqant  
	FROM ProfileQuoteApprovalNormThreshold p 
	JOIN #receipt r 
		ON r.approval_code = p.approval_code
		AND r.bill_unit_code = p.container_size
	WHERE p.status = 'A'
	AND p.company_id = @company_id
	AND p.profit_ctr_id = @profit_ctr_id

	-- Create unique index on #pqant so that we can update it in the cursor
	CREATE UNIQUE INDEX idx_pqant
	ON #pqant (approval_code, container_size, sequence_id)
		
	-- Declare a cursor to loop through #receipt rows
	DECLARE receipt_cursor CURSOR 
	FOR SELECT approval_code, bill_unit_code, receipt_quantity
	FROM #receipt r
	
	OPEN receipt_cursor
	
	FETCH NEXT FROM receipt_cursor INTO @approval_code, @bill_unit_code, @receipt_quantity
	
	WHILE @@FETCH_STATUS = 0
	BEGIN

		IF @debug=1
			SELECT '@approval_code = ' + @approval_code + ', @bill_unit_code = ' + @bill_unit_code + ', @receipt_quantity = ' + cast( @receipt_quantity AS VARCHAR(20))

		-- Declare a cursor to loop through #pqant rows for the outer cursor's approval/bill unit combination.
		DECLARE pqant_cursor CURSOR 
		FOR 
		SELECT sequence_id, threshold_quantity, threshold_percent, used_quantity, remaining_quantity, updated_used_quantity
		FROM #pqant 
		WHERE approval_code = @approval_code
		AND container_size = @bill_unit_code
		ORDER BY sequence_id
		FOR UPDATE OF updated_used_quantity
			
		OPEN pqant_cursor
	
		FETCH NEXT FROM pqant_cursor
		INTO @sequence_id, @threshold_quantity, @threshold_percent, @used_quantity, @remaining_quantity, @updated_used_quantity
	
		WHILE @@FETCH_STATUS = 0
		BEGIN
		
			if @debug=1
				select '@sequence_id = ' + cast(@sequence_id AS VARCHAR(20)) + 
					', @threshold_quantity = ' + cast(@threshold_quantity AS VARCHAR(20)) + 
					', @threshold_percent = ' + cast(@threshold_percent AS VARCHAR(20)) + 
					', @used_quantity = ' + cast(@used_quantity AS VARCHAR(20)) + 
					', @remaining_quantity = ' + cast(@remaining_quantity AS VARCHAR(20)) +
					', @updated_used_quantity = ' + cast(@updated_used_quantity AS VARCHAR(20)) 
				
			-- Check if there is an "overage quantity" from the previous cursor row. If so, use that for "comparison quantity"; 
			-- else, use "receipt quantity" from the outer cursor for "comparison quantity".
			IF @overage_quantity > 0
				SET @comparison_quantity = @overage_quantity
			ELSE
				SET @comparison_quantity = @receipt_quantity

			IF @debug=1
			BEGIN
				SELECT '@overage_quantity = ' + cast(@overage_quantity AS VARCHAR(20)) 
				SELECT '@receipt_quantity = ' + cast(@receipt_quantity AS VARCHAR(20)) 
				SELECT '@comparison_quantity = ' + cast(@comparison_quantity AS VARCHAR(20)) 
			END
			-- If @comparison_quantity <= @remaining_quantity on this PQANT row, we need to update updated_used_qty on this row.
			IF @comparison_quantity <= @remaining_quantity
			BEGIN
				IF @debug=1
				BEGIN
					SELECT 'a. before #pqant update'
					SELECT * FROM #pqant
				END

				UPDATE #pqant 
					SET updated_used_quantity = @used_quantity + @comparison_quantity
				WHERE CURRENT OF pqant_cursor

				IF @debug=1
				BEGIN
					SELECT 'a. after #pqant update'
					SELECT * FROM #pqant
				END
			END 
			
			-- If @comparison_quantity > @remaining_quantity on this PQANT row, we need to update updated_used_qty on this row to be the "max" it could be, 
			-- which is @threshold_quantity * @threshold_percent/100.0, and we also need to update @overage_quantity to 0.
			IF @comparison_quantity > @remaining_quantity
			BEGIN
				IF @debug=1
				BEGIN
					SELECT 'b. before #pqant update'
					SELECT * FROM #pqant
				END 

				UPDATE #pqant 
					SET updated_used_quantity = @threshold_quantity * @threshold_percent/100.0
				WHERE CURRENT OF pqant_cursor		

				IF @debug=1
				BEGIN
					SELECT 'b. after #pqant update'
					SELECT * FROM #pqant
				END
				
				SET @overage_quantity = @comparison_quantity - @remaining_quantity

				IF @debug=1
					SELECT '@overage_quantity = ' + cast(@overage_quantity AS VARCHAR(20)) 
				END
			
			FETCH NEXT FROM pqant_cursor
			INTO @sequence_id, @threshold_quantity, @threshold_percent, @used_quantity, @remaining_quantity, @updated_used_quantity

		END
		
		CLOSE pqant_cursor
		DEALLOCATE pqant_cursor
		
		-- Zero out @overage_quantity before we get a new outer cursor row
		SET @overage_quantity = 0

		IF @debug=1
			SELECT 'zeroing out @overage_quantity'
		
		FETCH NEXT FROM receipt_cursor INTO @approval_code, @bill_unit_code, @receipt_quantity

	END
	
	CLOSE receipt_cursor
	DEALLOCATE receipt_cursor
	

	IF @debug=1
	BEGIN
		SELECT * FROM #receipt
		SELECT * FROM #pqant
	END
	
	-- Before updating ProfileQuoteApprovalNormThreshold from #pqant, check to make sure that there is enough remaining NORM threshold quantity for each
	-- approval/bill unit combination to cover the receipt bill quantity for each approval/bill unit combination.  
	-- This check shouldn't ever fail because this condition should be caught at validation time, which is before we get to this point.
	IF EXISTS(
		SELECT 1 
		FROM #receipt r
		JOIN #pqant p
		ON r.approval_code = p.approval_code
		AND r.bill_unit_code = p.container_size
		GROUP BY p.approval_code, p.container_size, r.receipt_quantity
		HAVING r.receipt_quantity > SUM(p.remaining_quantity)
	)
	BEGIN
		SET @return_msg = 'ERROR: Unable to update table ProfileQuoteApprovalNormThreshold because there isn''t enough remaining NORM threshold quantity for at least one approval/bill unit combination.'
	END
	ELSE 
	BEGIN
	
		SET @now = GETDATE()
		
		-- Insert rows into ProfileAudit table before we update ProfileQuoteApprovalNormThreshold
		-- The following insert is for changes to ProfileQuoteApprovalNormThreshold.used_qty
		INSERT INTO ProfileAudit (profile_id, table_name, column_name, before_value, after_value, audit_reference, modified_by, date_modified)
		SELECT 
			profile_id, 
			'ProfileQuoteApprovalNormThreshold', 
			'used_qty', 
			used_quantity, 
			updated_used_quantity, 
			'Approval ' + approval_code + 
			', bill unit ' + container_size +
			', seq ID ' + CONVERT(VARCHAR(4), sequence_id) + 
			' for facility ' + CONVERT(VARCHAR(3), @company_id) + ' / ' + CONVERT(VARCHAR(3), @profit_ctr_id),
			@modified_by, 
			@now
		FROM #pqant 
		WHERE updated_used_quantity <> used_quantity

		-- The following insert is for changes to ProfileQuoteApprovalNormThreshold.status (row is marked Inactive after row is "used up")
		INSERT INTO ProfileAudit (profile_id, table_name, column_name, before_value, after_value, audit_reference, modified_by, date_modified)
		SELECT 
			profile_id, 
			'ProfileQuoteApprovalNormThreshold', 
			'status', 
			'A', 
			'I', 
			'Approval ' + approval_code + 
			', bill unit ' + container_size +
			', seq ID ' + CONVERT(VARCHAR(4), sequence_id) + 
			' for facility ' + CONVERT(VARCHAR(3), @company_id) + ' / ' + CONVERT(VARCHAR(3), @profit_ctr_id),
			@modified_by, 
			@now
		FROM #pqant 
		WHERE updated_used_quantity <> used_quantity
		AND updated_used_quantity = remaining_quantity
		
		-- Update ProfileQuoteApprovalNormThreshold from #pqant.
		-- ProfileQuoteApprovalNormThreshold.status will be updated to 'I' if the calculated remaining quantity - updated used quantity = 0.
		UPDATE ProfileQuoteApprovalNormThreshold
		SET 
			used_qty = p2.updated_used_quantity,
			modified_by = @modified_by,
			date_modified = @now,
			status = CASE WHEN p2.threshold_quantity * p2.threshold_percent/100.0 - p2.updated_used_quantity = 0 THEN 'I' ELSE p1.status END 
		FROM ProfileQuoteApprovalNormThreshold p1 
		JOIN #pqant p2
			ON p1.company_id = @company_id
			AND p1.profit_ctr_id = @profit_ctr_id
			AND p1.approval_code = p2.approval_code
			AND p1.container_size = p2.container_size
			AND p1.sequence_id = p2.sequence_id
			WHERE ISNULL(p1.used_qty, 0) <> p2.updated_used_quantity

	END
	
	SELECT @return_msg

END
GO

GRANT EXECUTE
    ON OBJECT::[dbo].[sp_update_approval_norm_used_qty] TO [EQAI];
GO
