CREATE PROCEDURE sp_rpt_receipt_flash 
       @company_id          int
,      @profit_ctr_id       int
,      @date_from           datetime
,      @date_to             datetime
,      @cust_id_from int
,      @cust_id_to          int
AS
/*****************************************************************************************
This sp runs for the Inbound Receiving report 'Waste Receipt Flash Report'

PB Object(s): r_receipt_flash

12/17/2010 SK Created new on Plt_AI

sp_rpt_receipt_flash 22, 0, '01-01-2008','01-31-2008', 1, 999999

SG - Devops # 80869 - Receipt Report Issue - Eliminate the receipts which are Submitted but not exists in Billing table.
******************************************************************************************/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

SELECT DISTINCT
       Receipt.receipt_id
,      CASE WHEN ISNULL(Receipt.submitted_flag, 'F') = 'T' THEN 'X'
              ELSE Receipt.receipt_status
       END AS receipt_receipt_status
,      NULL AS billing_status_code
,      Receipt.company_id
,      Receipt.profit_ctr_id
,      Receipt.customer_id
,      Customer.cust_name
,      MAX(Generator.EPA_ID) AS EPA_ID
,      MAX(Generator.generator_name) AS generator_name
,      SUM(ISNULL(ReceiptPrice.waste_extended_amt, 0)) AS waste_extended_amt
,      SUM(ISNULL(ReceiptPrice.sr_extended_amt, 0)) AS sr_extended_amt
,      SUM(ISNULL(ReceiptPrice.total_extended_amt, 0)) AS total_extended_amt
,      Receipt.receipt_date
,      Company.company_name
,      ProfitCenter.profit_ctr_name
FROM Receipt
JOIN Company
       ON Company.company_id = Receipt.company_id
JOIN ProfitCenter
       ON ProfitCenter.company_ID = Receipt.company_id
       AND ProfitCenter.profit_ctr_ID = Receipt.profit_ctr_id
INNER JOIN ReceiptPrice 
       ON Receipt.company_id = ReceiptPrice.company_id
       AND Receipt.profit_ctr_id = ReceiptPrice.profit_ctr_id
       AND Receipt.receipt_id = ReceiptPrice.receipt_id
       AND Receipt.line_id = ReceiptPrice.line_id
       AND ReceiptPrice.print_on_invoice_flag = 'T'
LEFT OUTER JOIN Generator 
       ON Receipt.generator_id = Generator.generator_id
LEFT OUTER JOIN Customer 
       ON Receipt.customer_id = Customer.customer_id
WHERE Receipt.receipt_date BETWEEN @date_from AND @date_to
       AND ( @company_id = 0 OR Receipt.company_id = @company_id)
       AND ( @company_id = 0 OR @profit_ctr_id = -1 OR Receipt.profit_ctr_id = @profit_ctr_id )
       AND Receipt.customer_id BETWEEN @cust_id_from AND @cust_id_to
       AND Receipt.trans_mode = 'I'
       AND ( Receipt.receipt_status IN ('N', 'L', 'U', 'M')
                OR Receipt.receipt_status = 'A' AND NOT EXISTS ( SELECT 1 FROM Billing 
                                                                                                   WHERE Receipt.company_id = Billing.company_id
                                                                                                       AND Receipt.profit_ctr_id = Billing.profit_ctr_id
                                                                                                       AND Receipt.receipt_id = Billing.receipt_id
                                                                                                       AND Receipt.line_id = Billing.line_id)
           )
	   AND NOT (Receipt.submitted_flag = 'T' 
	   AND NOT Exists (Select 1 From Billing 
                 WHERE Receipt.company_id = Billing.company_id  
                 AND Receipt.profit_ctr_id = Billing.profit_ctr_id  
                 AND Receipt.receipt_id = Billing.receipt_id  
                 AND Receipt.line_id = Billing.line_id
				 ))
       AND Receipt.fingerpr_status IN ('W', 'H', 'A')
GROUP BY 
       CASE WHEN ISNULL(Receipt.submitted_flag, 'F') = 'T' THEN 'X'
              ELSE Receipt.receipt_status END
,      Receipt.company_id
,      Receipt.profit_ctr_id
,      Customer.cust_name
,      Receipt.customer_id
,      Receipt.receipt_id
,      Receipt.receipt_date
,      Company.company_name
,      ProfitCenter.profit_ctr_name
UNION

SELECT DISTINCT
       Receipt.receipt_id
,      CASE WHEN ISNULL(Receipt.submitted_flag, 'F') = 'T' THEN 'X'
              ELSE Receipt.receipt_status
       END AS receipt_receipt_status
,      Billing.status_code AS billing_status_code
,      Receipt.company_id
,      Receipt.profit_ctr_id
,      Receipt.customer_id
,      Customer.cust_name
,      MAX(Generator.EPA_ID) AS EPA_ID
,      MAX(Generator.generator_name) AS generator_name
,      SUM(ISNULL(ReceiptPrice.waste_extended_amt, 0)) AS waste_extended_amt
,      SUM(ISNULL(ReceiptPrice.sr_extended_amt, 0)) AS sr_extended_amt
,      SUM(ISNULL(ReceiptPrice.total_extended_amt, 0)) AS total_extended_amt
,      Receipt.receipt_date
,      Company.company_name
,      ProfitCenter.profit_ctr_name
FROM Receipt
JOIN Company
       ON Company.company_id = Receipt.company_id
JOIN ProfitCenter
       ON ProfitCenter.company_ID = Receipt.company_id
       AND ProfitCenter.profit_ctr_ID = Receipt.profit_ctr_id
INNER JOIN ReceiptPrice 
       ON Receipt.company_id = ReceiptPrice.company_id
       AND Receipt.profit_ctr_id = ReceiptPrice.profit_ctr_id
       AND Receipt.receipt_id = ReceiptPrice.receipt_id
       AND Receipt.line_id = ReceiptPrice.line_id
       AND ReceiptPrice.print_on_invoice_flag = 'T'
INNER JOIN Billing 
       ON ReceiptPrice.company_id = Billing.company_id
       AND ReceiptPrice.profit_ctr_id = Billing.profit_ctr_id
       AND ReceiptPrice.receipt_id = Billing.receipt_id
       AND ReceiptPrice.line_id = Billing.line_id
       AND ReceiptPrice.price_id = Billing.price_id
       AND Billing.trans_source = 'R'
       AND Billing.status_code <> 'I'
LEFT OUTER JOIN Generator 
       ON Receipt.generator_id = Generator.generator_id
LEFT OUTER JOIN Customer 
       ON Receipt.customer_id = Customer.customer_id
WHERE Receipt.receipt_date BETWEEN @date_from AND @date_to
       AND ( @company_id = 0 OR Receipt.company_id = @company_id)
       AND ( @company_id = 0 OR @profit_ctr_id = -1 OR Receipt.profit_ctr_id = @profit_ctr_id )
       AND Receipt.customer_id BETWEEN @cust_id_from AND @cust_id_to
       AND Receipt.trans_mode = 'I'
       AND Receipt.receipt_status IN ('A')
       AND Receipt.fingerpr_status IN ('W', 'H', 'A')
GROUP BY 
       CASE WHEN ISNULL(Receipt.submitted_flag, 'F') = 'T' THEN 'X'
              ELSE Receipt.receipt_status END
,      Billing.status_code
,      Receipt.company_id
,      Receipt.profit_ctr_id
,      Customer.cust_name
,      Receipt.customer_id
,      Receipt.receipt_id
,      Receipt.receipt_date
,      Company.company_name
,      ProfitCenter.profit_ctr_name
UNION -- ADDED by OE , DevOps:11270 DevOps:11448 - EQAI:Report Center>Receipt Flash Report - change stored procedure to included records that contain null customer ID
SELECT DISTINCT
	Receipt.receipt_id
,	CASE WHEN ISNULL(Receipt.submitted_flag, 'F') = 'T' THEN 'X'
		 ELSE Receipt.receipt_status
	END AS receipt_receipt_status
,	NULL AS billing_status_code
,	Receipt.company_id
,	Receipt.profit_ctr_id
,	Receipt.customer_id
,	Customer.cust_name
,	MAX(Generator.EPA_ID) AS EPA_ID
,	MAX(Generator.generator_name) AS generator_name
,	SUM(0) AS waste_extended_amt
,	SUM(  0) AS sr_extended_amt
,	SUM( 0) AS total_extended_amt
,	Receipt.receipt_date
,	Company.company_name
,	ProfitCenter.profit_ctr_name
FROM Receipt
JOIN Company
	ON Company.company_id = Receipt.company_id
JOIN ProfitCenter
	ON ProfitCenter.company_ID = Receipt.company_id
	AND ProfitCenter.profit_ctr_ID = Receipt.profit_ctr_id
LEFT OUTER JOIN Generator 
	ON Receipt.generator_id = Generator.generator_id
LEFT OUTER JOIN Customer 
	ON Receipt.customer_id = Customer.customer_id
WHERE 
--Receipt.receipt_id = 2056827 and
Receipt.receipt_date BETWEEN @date_from AND @date_to
     AND ( @company_id = 0 OR Receipt.company_id = @company_id)
       AND ( @company_id = 0 OR @profit_ctr_id = -1 OR Receipt.profit_ctr_id = @profit_ctr_id )
       AND 	 isnull(Receipt.customer_id, @cust_id_from) BETWEEN @cust_id_from AND @cust_id_to
	AND Receipt.trans_mode = 'I'
	AND ( Receipt.receipt_status IN ('N', 'L', 'U', 'M')
		  OR Receipt.receipt_status = 'A' AND NOT EXISTS ( SELECT 1 FROM Billing 
														   WHERE Receipt.company_id = Billing.company_id
															AND Receipt.profit_ctr_id = Billing.profit_ctr_id
															AND Receipt.receipt_id = Billing.receipt_id
															AND Receipt.line_id = Billing.line_id)
	    )
	AND NOT (Receipt.submitted_flag = 'T' 
    AND NOT Exists (Select 1 From Billing 
                 WHERE Receipt.company_id = Billing.company_id  
                 AND Receipt.profit_ctr_id = Billing.profit_ctr_id  
                 AND Receipt.receipt_id = Billing.receipt_id  
                 AND Receipt.line_id = Billing.line_id
				 ))
	AND (Receipt.fingerpr_status IN ('W', 'H', 'A') or Receipt.fingerpr_status is null)
GROUP BY 
	CASE WHEN ISNULL(Receipt.submitted_flag, 'F') = 'T' THEN 'X'
		 ELSE Receipt.receipt_status END
,	Receipt.company_id
,	Receipt.profit_ctr_id
,	Customer.cust_name
,	Receipt.customer_id
,	Receipt.receipt_id
,	Receipt.receipt_date
,	Company.company_name
,	ProfitCenter.profit_ctr_name

GO
GRANT EXECUTE ON [dbo].[sp_rpt_receipt_flash] TO [EQAI]
  

 

	 