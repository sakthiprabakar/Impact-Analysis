CREATE PROCEDURE sp_container_fingerprint_populate
	@base_company_id	int,
	@base_profit_ctr_id int,
	@base_receipt_id int,
	@base_line_id int,
	@base_container_id int
AS
/****************
This SP controls populating historical data to store waste codes and constituents with base containers

07/21/2009 KAM	Created
08/19/2015 RWB	This was never migrated from Plt_XX_ai, and barcode scanner has been display false errors

sp_container_fingerprint 21,0,727,4
******************/
SET NOCOUNT ON

DECLARE	@base_sequence_id int,
		@base_container_type char(1),
		@debug int,
		@profit_ctr_id int,
		@tracking_num varchar(15),
		@base_tracking_num VarChar(15),
		@stock_company_id	int,
		@stock_profit_ctr_id int,
		@stock_receipt_id int,
		@stock_line_id int,
		@stock_container_id int,
		@rowcount	int


-- Initialize
IF @base_receipt_id = 0 
	BEGIN
		SET @base_tracking_num = 'DL-' + RIGHT('00' + CAST(@base_company_id AS varchar),2)+ RIGHT('00' + CAST(@base_profit_ctr_id AS varchar),2)+ '-' +RIGHT('000000' + CAST(@base_line_id AS varchar),6)
		SET @base_container_id = @base_line_id
	END
ELSE
	BEGIN
		SET @base_tracking_num = CAST(@base_receipt_id AS Varchar) + '-' + CAST(@base_line_id AS varchar)
		SET @base_container_id = @base_container_id
	END
-- Print 'Base Tracking Num ' + @base_tracking_num
-- print 'Base Container ID ' + cast(@base_container_id as varchar)

SET @rowcount = (SELECT COUNT(*) FROM #included_in_base WHERE  company_id = @base_company_id AND
																					profit_ctr_id = @base_profit_ctr_id AND
																					receipt_id = @base_receipt_id AND
																					line_id = @base_line_id AND
																					container_id = @base_container_id)

-- PRINT 'Check for Processed Rowcount ' + cast(@ROWCOUNT as varchar(10))
IF @rowcount > 0
 	RETURN

INSERT INTO #included_in_base(company_id,profit_ctr_id, receipt_id, line_id,container_id) 
VALUES(@base_company_id,
@base_profit_ctr_id,
@base_receipt_id,
@base_line_id,
@base_container_id)

-- print  'Insert Error ' + cast(@@ERROR as varchar(10))

-- Print 'Base Tracking Num ' + @base_tracking_num
-- print 'Base Container ID ' + cast(@base_container_id as varchar)

DECLARE stock CURSOR LOCAL FOR
	SELECT DISTINCT
	company_id,
	profit_ctr_id,
	receipt_id,
	line_id,
	container_id
	FROM ContainerDestination
	WHERE base_tracking_num = @base_tracking_num AND
	base_container_id = @base_container_id AND
	sequence_id = (SELECT MAX(sequence_id) 
		FROM containerdestination 
		WHERE base_tracking_num = @base_tracking_num 
		AND	base_container_id = @base_container_id)

Open Stock

-- Print 'Cursor Rows ' + cast(@@cursor_rows as varchar(10))

Fetch Stock into
	@stock_company_id,
	@stock_profit_ctr_id,
	@stock_receipt_id,
	@stock_line_id,
	@stock_container_id

WHILE @@fetch_status = 0
		BEGIN
			EXEC sp_container_fingerprint_populate @stock_company_id, @stock_profit_ctr_id, @stock_receipt_id, @stock_line_id, @stock_container_id
		
			FETCH stock INTO
			@stock_company_id,
			@stock_profit_ctr_id,
			@stock_receipt_id,
			@stock_line_id,
			@stock_container_id
		END

CLOSE stock
DEALLOCATE stock

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_container_fingerprint_populate] TO [EQAI]
    AS [dbo];

