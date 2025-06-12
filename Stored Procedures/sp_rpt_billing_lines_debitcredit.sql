CREATE PROCEDURE sp_rpt_billing_lines_debitcredit
	@company_id		int
,	@profit_ctr_id 	int
,	@date_from 		datetime
,	@date_to 		datetime
,	@cust_id_from	int
,	@cust_id_to		int
,	@epa_id			varchar(12)
AS
/***************************************************************************************
supports the Billing lines with debit/credit memos report

PB Object : r_billing_lines_debitcredit

11/11/2004 MK  Changed generator_code to EPA ID
12/09/2004 JDB Changed to sp_rpt_billing_lines_debitcredit; changed Ticket to Billing
11/02/2007 RG  revised for central invoicing adjustments tables
               also removed 'like' test and replaced with branch logic for speed
11/11/2010 SK  added company-profit center as input args
			   moved to Plt_AI

sp_rpt_billing_lines_debitcredit 0, -1, '01/01/2007', '12/31/2007', 1, 999999, 'GAD000609818'
sp_rpt_billing_lines_debitcredit 14, 4, '06/01/2010', '06/30/2010', 1, 999999, 'ALL'
****************************************************************************************/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

DECLARE	
	@ws_line_count		int,
	@ws_line_memo_count	int,
	@ws_memo_count		int,
	@company_name		varchar(35),
	@profit_ctr_name	varchar(50)

-- Get Company Name & Profit Center
IF @company_id = 0 
BEGIN
	SET @company_name = 'All Companies'
	SET @profit_ctr_name = 'All Profit Centers'
END
ELSE
BEGIN
	SELECT @company_name = company_name FROM Company WHERE company_id = @company_id
	IF @profit_ctr_id = -1
		SET @profit_ctr_name = 'All Profit Centers'
	ELSE
		SELECT @profit_ctr_name = profit_ctr_name FROM ProfitCenter WHERE company_id = @company_id AND profit_ctr_ID = @profit_ctr_id
END

IF @epa_id = 'ALL'
BEGIN
	SELECT @ws_line_count = ( SELECT COUNT(CONVERT(varchar(10), b.receipt_id) + '-' + CONVERT(varchar(4), b.line_id) + '-' + CONVERT(varchar(4), b.price_id))
								FROM Billing b
								WHERE ( @company_id = 0 OR b.company_id = @company_id )
									AND ( @company_id = 0 OR @profit_ctr_id = -1 OR b.profit_ctr_id = @profit_ctr_id )	
									AND b.billing_date BETWEEN @date_from AND @date_to
									AND b.status_code <> 'V'
									AND b.customer_id BETWEEN @cust_id_from AND @cust_id_to
							)
									
	SELECT @ws_line_memo_count = ( SELECT COUNT(CONVERT(varchar(10), b.receipt_id) + '-' + CONVERT(varchar(4), b.line_id) + '-' + CONVERT(varchar(4), b.price_id))
									FROM Billing b
									INNER JOIN AdjustmentDetail a 
										ON b.receipt_id = a.receipt_id
										AND b.line_id = a.line_id
										AND b.price_id = a.price_id
										AND b.company_id = a.company_id
										AND b.profit_ctr_id = a.profit_ctr_id
										AND b.trans_source = a.trans_source
									WHERE ( @company_id = 0 OR b.company_id = @company_id )
										AND ( @company_id = 0 OR @profit_ctr_id = -1 OR b.profit_ctr_id = @profit_ctr_id )
										AND b.billing_date BETWEEN @date_from AND @date_to
										AND b.status_code <> 'V'
										AND b.customer_id BETWEEN @cust_id_from AND @cust_id_to
	        					 )
		
	SELECT @ws_memo_count = ( SELECT DISTINCT COUNT(ah.adjustment_id)
								FROM AdjustmentHeader ah
								INNER JOIN AdjustmentDetail ad 
									ON ah.adjustment_id = ad.adjustment_id
								INNER JOIN Billing b 
									ON b.receipt_id = ad.receipt_id
									AND b.line_id = ad.line_id
									AND b.price_id = ad.price_id
									AND b.company_id = ad.company_id
									AND b.profit_ctr_id = ad.profit_ctr_id
									AND b.trans_source = ad.trans_source
								WHERE ( @company_id = 0 OR b.company_id = @company_id )
									AND ( @company_id = 0 OR @profit_ctr_id = -1 OR b.profit_ctr_id = @profit_ctr_id )
									AND b.billing_date BETWEEN @date_from AND @date_to
									AND b.status_code <> 'V'
									AND b.customer_id BETWEEN @cust_id_from AND @cust_id_to
	               			)
END

ELSE

BEGIN
	SELECT @ws_line_count = ( SELECT COUNT(CONVERT(varchar(10), b.receipt_id) + '-' + CONVERT(varchar(4), b.line_id) + '-' + CONVERT(varchar(4), b.price_id))
								FROM Billing b
								INNER JOIN Generatorlookup g 
									ON b.generator_id = g.generator_id
									AND g.EPA_ID = @epa_id 
								WHERE ( @company_id = 0 OR b.company_id = @company_id )
									AND ( @company_id = 0 OR @profit_ctr_id = -1 OR b.profit_ctr_id = @profit_ctr_id )	
									AND b.billing_date BETWEEN @date_from AND @date_to
									AND b.status_code <> 'V'
									AND b.customer_id BETWEEN @cust_id_from AND @cust_id_to
							)
							
	SELECT @ws_line_memo_count = ( SELECT COUNT(CONVERT(varchar(10), b.receipt_id) + '-' + CONVERT(varchar(4), b.line_id) + '-' + CONVERT(varchar(4), b.price_id))
									FROM Billing b
									INNER JOIN AdjustmentDetail a 
										ON b.receipt_id = a.receipt_id
										AND b.line_id = a.line_id
										AND b.price_id = a.price_id
										AND b.company_id = a.company_id
										AND b.profit_ctr_id = a.profit_ctr_id
										AND b.trans_source = a.trans_source
									INNER JOIN Generatorlookup g 
										ON b.generator_id = g.generator_id
										AND g.epa_id = @epa_id
									WHERE ( @company_id = 0 OR b.company_id = @company_id )
										AND ( @company_id = 0 OR @profit_ctr_id = -1 OR b.profit_ctr_id = @profit_ctr_id )	
										AND b.billing_date BETWEEN @date_from AND @date_to
										AND b.status_code <> 'V'
										AND b.customer_id BETWEEN @cust_id_from AND @cust_id_to
									)
			
	SELECT @ws_memo_count = ( SELECT DISTINCT COUNT(ah.adjustment_id)
								FROM AdjustmentHeader ah
								INNER JOIN AdjustmentDetail ad 
									ON ah.adjustment_id = ad.adjustment_id
								INNER JOIN Billing b 
									ON b.receipt_id = ad.receipt_id
									AND b.line_id = ad.line_id
									AND b.price_id = ad.price_id
									AND b.company_id = ad.company_id
									AND b.profit_ctr_id = ad.profit_ctr_id
									AND b.trans_source = ad.trans_source
								INNER JOIN Generatorlookup g 
									ON b.generator_id = g.generator_id
									AND g.EPA_ID = @epa_id
								WHERE ( @company_id = 0 OR b.company_id = @company_id )
									AND ( @company_id = 0 OR @profit_ctr_id = -1 OR b.profit_ctr_id = @profit_ctr_id )
									AND b.billing_date BETWEEN @date_from AND @date_to
									AND b.status_code <> 'V'
									AND b.customer_id BETWEEN @cust_id_from AND @cust_id_to
							)
END

-- now select results 
SELECT
	@company_id,
	@profit_ctr_id,
	@ws_line_count, 
	@ws_line_memo_count,
	@ws_memo_count,
	@company_name,
	@profit_ctr_name


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_billing_lines_debitcredit] TO [EQAI]
    AS [dbo];

