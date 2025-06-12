
CREATE PROCEDURE [dbo].[sp_add_receipt_to_athena_queue] (
	@company_id		int,
	@profit_ctr_id	int,
	@receipt_id		int )
AS
/***************************************************************************************
Adds a receipt to the Athena queue

07/31/2018 MPM	Created
09/05/2018 MPM	GEM 54060 - Uncommented the commented-out code which adds the receipt to the
				Athena queue.
09/25/2018 MPM	GEM 54692 - Added @receipt_date to call to sp_AthenaQueue_Add; also removed logic
				that would prevent this from happening if receipt_status = 'U'.
08/06/2019 MPM	Samanage 11237 - Modified when a receipt is put into the Athena queue; now, 
				we'll put it in the queue when saving the receipt if the receipt status is 
				Unloading, Rejected or Accepted.  An additional check for all generator, TSDF and transporter 
				signatures and signature dates being populated is done in the Receipt window, and 
				if any of these signatures or dates aren't populated, this stored procedure is not called. 

Returns:
	0	if receipt was successfully added to the Athena queue
	< 0	if some error occurred
	> 0	if receipt was not added to the Athena queue, but no error occurred

sp_add_receipt_to_athena_queue 21, 1, 29601
sp_add_receipt_to_athena_queue 21, 0, 2005475

****************************************************************************************/
SET NOCOUNT ON

DECLARE	
	@return_code				int,
	@return_msg					varchar(300),
	@waste_accepted_flag		char(1),
	@manifest					varchar(15),
	@receipt_status				char(1),
	@count						int,
	@emanifest_submission_type	int,
	@s_receipt_id				varchar(10),
	@s_co						varchar(3),
	@s_pc						varchar(3),
	@receipt_date				datetime
	
SET @return_code = 0
SET @return_msg = ''

IF @return_code = 0
BEGIN
	SELECT @count = COUNT(DISTINCT manifest)
	FROM Receipt
	WHERE company_id = @company_id
	AND profit_ctr_id = @profit_ctr_id
	AND receipt_id = @receipt_id

	IF @count > 1 
	BEGIN
		SET @return_code = -2
		SET @return_msg = 'Receipt has more than one distinct manifest value over its lines.'
	END
END

IF @return_code = 0
BEGIN
	SELECT @count = COUNT(DISTINCT receipt_status)
	FROM Receipt
	WHERE company_id = @company_id
	AND profit_ctr_id = @profit_ctr_id
	AND receipt_id = @receipt_id

	IF @count > 1 
	BEGIN
		SET @return_code = -3
		SET @return_msg = 'Receipt has more than one distinct receipt_status value over its lines.'
	END
END

IF @return_code = 0
BEGIN
	SELECT @count = COUNT(DISTINCT receipt_date)
	FROM Receipt
	WHERE company_id = @company_id
	AND profit_ctr_id = @profit_ctr_id
	AND receipt_id = @receipt_id

	IF @count > 1 
	BEGIN
		SET @return_code = -5
		SET @return_msg = 'Receipt has more than one distinct receipt_date value over its lines.'
	END
END

IF @return_code = 0
BEGIN
	SELECT TOP 1  
		@manifest = manifest,
		@receipt_status = receipt_status,
		@receipt_date = receipt_date
	FROM Receipt
	WHERE company_id = @company_id
	AND profit_ctr_id = @profit_ctr_id
	AND receipt_id = @receipt_id
	
	IF @receipt_status IN ('U', 'R', 'A')
	BEGIN
		SELECT @emanifest_submission_type = dbo.fn_IsEmanifestRequired(@company_id, @profit_ctr_id, 'receipt', @receipt_id, @manifest)
		IF @emanifest_submission_type > 0
		BEGIN
			SET @s_receipt_id = CONVERT(VARCHAR(10), @receipt_id)
			SET @s_co = CONVERT(VARCHAR(3), @company_id)
			SET @s_pc = CONVERT(VARCHAR(3), @profit_ctr_id)
			
			EXEC Athena.Athena.dbo.sp_AthenaQueue_Add
				@source = 'eqai',
				@source_table = 'receipt',
				@source_id = @s_receipt_id,
				@source_company_id = @s_co,
				@source_profit_ctr_id = @s_pc,
				@manifest = @manifest,
				@record_type = 'data+image send',
				@receipt_date = @receipt_date
				
			-- Check if receipt was added to the Athena queue
			SELECT @count = COUNT(*)
			FROM Athena.Athena.dbo.AthenaQueue
			WHERE source = 'eqai'
			AND source_table = 'receipt'
			AND source_id = @s_receipt_id
			AND source_company_id = @s_co
			AND source_profit_ctr_id = @s_pc
			AND manifest = @manifest
			AND record_type = 'data+image send'
	
			IF @count < 1
			BEGIN
				SET @return_code = -4
				SET @return_msg = 'Failed to add receipt to the e-Manifest queue.'
			END
			ELSE
			BEGIN
				SET @return_msg = 'Successfully added receipt to the e-Manifest queue.'
			END
		END
		ELSE
		BEGIN
			SET @return_code = 1
			SET @return_msg = 'Receipt does not need to be added to the e-Manifest queue.'
		END
	END
	ELSE
	BEGIN
		SET @return_code = 3
		SET @return_msg = 'Receipt was not added to the e-Manifest queue because @receipt_status is not in (''U'', ''R'', ''A'').'
	END
END

SET NOCOUNT OFF

SELECT	@return_code, @return_msg


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_add_receipt_to_athena_queue] TO [EQAI]
    AS [dbo];

