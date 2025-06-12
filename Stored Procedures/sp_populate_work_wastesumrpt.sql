CREATE PROCEDURE sp_populate_work_wastesumrpt
	@company_id			int
,	@date_from 			datetime
,	@date_to 			datetime
,	@customer_type 		varchar(10)
,	@customer_id_from 	int
,	@customer_id_to 	int
,	@invoice_date_chk 	int
,	@user_id            varchar(8)
AS
/********************************************************************************
01/28/1999 SCC	Modified for bill_unit_code size change
07/02/1999 JDB	Replaced all instances of "ticket_date" with "invoice_date"
07/07/1999 JDB	Added "if" statements to accomodate new radio button selection
				in w_report_master_summary.  (Invoice Date or Service Date)
11/27/2002 JDB	Added trans_mode = 'I' to only count inbound receipts
12/05/2002 LJT	Added the inclusion of Workorder records they were dropped with
				inbound only
11/20/2003 JDB	Added ISNULL statements to the sums and quantity fields
11/20/2003 LJT	Corrected to use ticket_date on select portion of second set of
				selects
05/24/2004 SCC	Made report run by user ID
12/14/2004 JDB	Changed Ticket to Billing, ticket_month to line_month,
				ticket_year to line_year
11/24/2010 SK	copied from original sp: sp_populate_wastesumrpt on Plt_XX_AI 
				Added company_id as input arg, modified to run on Plt_AI
				populates Work_WasteSumRpt table on Plt_AI
10/22/2013 AM   Added Billing.waste_code_uid to poulate into work_WasteSumRpt table				
				
sp_populate_work_wastesumrpt 21, '01/01/2003', '03/01/2003', '%', 1, 999999, 1, 1486
********************************************************************************/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED


IF @customer_type = 'ALL'
BEGIN
	SET @customer_type = '%'
END

IF @invoice_date_chk = 1
BEGIN
	INSERT INTO work_WasteSumRpt (
		customer_id
	,	customer_name
	,	waste_code
	,	bill_unit_code
	,	line_month
	,	line_year
	,	profit_ctr_id
	,	profit_ctr_name
	,	company_id
	,	company_name
	,	quantity
	,	gross_price
	,	discount_dollars
	,	customer_type
	,	user_id	
	,   waste_code_uid ) 
	SELECT 
		Billing.customer_id
	,	Customer.cust_name
	,	Billing.waste_code
	,	Billing.bill_unit_code
	,	month = DATEPART(month, invoice_date)
	,	year = DATEPART(year, invoice_date)
	,	Billing.profit_ctr_id
	,	ProfitCenter.profit_ctr_name
	,	Billing.company_id
	,	Company.company_name
	,	quantity = ISNULL(SUM(Billing.quantity), 0.00)
	,	gross_price = ISNULL(SUM(ROUND(Billing.quantity * Billing.price, 2)), 0.00)
	,	discount_dollars = ISNULL(SUM(ROUND((Billing.quantity * Billing.price) * (discount_percent / 100), 2)), 0.00)
	,	Customer.customer_type
	,	@user_id
	,   Billing.waste_code_uid
	FROM Billing
	JOIN Company
		ON Company.company_id = Billing.company_id
	JOIN ProfitCenter
		ON ProfitCenter.company_ID = Billing.company_id
		AND ProfitCenter.profit_ctr_ID = Billing.profit_ctr_id
	JOIN Receipt
		ON Receipt.company_id = Billing.company_id
		AND Receipt.profit_ctr_id = Billing.profit_ctr_id
		AND Receipt.receipt_id = Billing.receipt_id
		AND Receipt.line_id = Billing.line_id
		AND Receipt.trans_mode = 'I'
	JOIN Customer
		ON Customer.customer_ID = Billing.customer_id
		AND Customer.customer_type LIKE @customer_type
	WHERE Billing.status_code = 'I'
		AND Billing.void_status = 'F'
		AND Billing.company_id = @company_id
		AND Billing.invoice_date BETWEEN @date_from AND @date_to
		AND Billing.customer_id BETWEEN @customer_id_from AND @customer_id_to
	GROUP BY 
		Billing.customer_id,
		Customer.Cust_Name,
		Billing.waste_code, 
		Billing.bill_unit_code,
		DATEPART(month, invoice_date), DATEPART(year, invoice_date),
		Billing.profit_ctr_id,
		ProfitCenter.profit_ctr_name,
		Billing.company_id,
		Company.company_name,
		Customer.customer_type,
	    Billing.waste_code_uid
	UNION
	
	SELECT 
		Billing.customer_id,
		Customer.cust_name,
		Billing.waste_code,
		Billing.bill_unit_code,
		month = DATEPART(month, invoice_date),
		year = DATEPART(year, invoice_date),
		Billing.profit_ctr_id,
		ProfitCenter.profit_ctr_name,
		Billing.company_id,
		Company.company_name,
		quantity = ISNULL(SUM(Billing.quantity), 0.00),   
		gross_price = ISNULL(SUM(ROUND(Billing.quantity * Billing.price, 2)), 0.00),
		discount_dollars = ISNULL(SUM(ROUND((Billing.quantity * Billing.price) * (discount_percent / 100), 2)), 0.00),
		Customer.customer_type,
		@user_id,   
		Billing.waste_code_uid
	FROM Billing
	JOIN Company
		ON Company.company_id = Billing.company_id
	JOIN ProfitCenter
		ON ProfitCenter.company_ID = Billing.company_id
		AND ProfitCenter.profit_ctr_ID = Billing.profit_ctr_id
	JOIN Customer
		ON Customer.customer_ID = Billing.customer_id
		AND Customer.customer_type LIKE @customer_type
	WHERE Billing.status_code = 'I'
		AND Billing.void_status = 'F'
		AND Billing.company_id = @company_id
		AND Billing.invoice_date BETWEEN @date_from AND @date_to
		AND Billing.customer_id BETWEEN @customer_id_from AND @customer_id_to
		AND Billing.trans_type = 'O'
	GROUP BY Billing.customer_id,
		Customer.cust_name,
		Billing.waste_code, 
		Billing.bill_unit_code,
		DATEPART(month, invoice_date), DATEPART(year, invoice_date),
		Billing.profit_ctr_id,
		ProfitCenter.profit_ctr_name,
		Billing.company_id,
		Company.company_name,
		Customer.customer_type,
	    Billing.waste_code_uid
	ORDER BY Billing.customer_id,
		Customer.cust_name,
		Billing.waste_code, 
		Billing.bill_unit_code,
		DATEPART(month, invoice_date),
		DATEPART(year, invoice_date),
		Billing.profit_ctr_id,
		ProfitCenter.profit_ctr_name,
		Billing.Company_id,
		Company.company_name,
		Customer.Customer_type,
	    Billing.waste_code_uid
END
ELSE
BEGIN
	INSERT INTO work_WasteSumRpt (
		customer_id
	,	customer_name
	,	waste_code
	,	bill_unit_code
	,	line_month
	,	line_year
	,	profit_ctr_id
	,	profit_ctr_name
	,	company_id
	,	company_name
	,	quantity
	,	gross_price
	,	discount_dollars
	,	customer_type
	,	user_id	
	,   waste_code_uid ) 
	SELECT 
		Billing.customer_id,
		Customer.Cust_Name,
		Billing.waste_code,
		Billing.bill_unit_code,
		month = DATEPART(month, billing_date),
		year = DATEPART(year, billing_date),
		Billing.profit_ctr_id,
		ProfitCenter.profit_ctr_name,
		Billing.Company_Id,
		Company.company_name,
		quantity = ISNULL(SUM(Billing.Quantity), 0.00),   
		gross_price = ISNULL(SUM(ROUND(Billing.quantity*Billing.price,2)), 0.00),
		discount_dollars = ISNULL(SUM(ROUND((Billing.quantity*Billing.price) * (discount_percent / 100),2)), 0.00),
		Customer.customer_type,
		@user_id,
		Billing.waste_code_uid
	FROM Billing
	JOIN Company
		ON Company.company_id = Billing.company_id
	JOIN ProfitCenter
		ON ProfitCenter.company_ID = Billing.company_id
		AND ProfitCenter.profit_ctr_ID = Billing.profit_ctr_id
	JOIN Receipt
		ON Receipt.company_id = Billing.company_id
		AND Receipt.profit_ctr_id = Billing.profit_ctr_id
		AND Receipt.receipt_id = Billing.receipt_id
		AND Receipt.line_id = Billing.line_id
		AND Receipt.trans_mode = 'I'
	JOIN Customer
		ON Customer.customer_ID = Billing.customer_id
		AND Customer.customer_type LIKE @customer_type
	WHERE Billing.status_code = 'I'
		AND Billing.void_status = 'F'
		AND Billing.company_id = @company_id
		AND Billing.billing_date BETWEEN @date_from AND @date_to
		AND Billing.customer_id BETWEEN @customer_id_from AND @customer_id_to
	GROUP BY Billing.customer_id,
		Customer.Cust_Name,
		Billing.waste_code, 
		Billing.bill_unit_code,
		DATEPART(month,billing_date), 
		DATEPART(year,billing_date),
		Billing.profit_ctr_id,
		ProfitCenter.profit_ctr_name,
		Billing.Company_id,
		Company.company_name,
		Customer.Customer_type,
	    Billing.waste_code_uid
	
	UNION
	
	SELECT 
		Billing.customer_id,
		Customer.Cust_Name,
		Billing.waste_code,
		Billing.bill_unit_code,
		month = DATEPART(month, billing_date),
		year = DATEPART(year, billing_date),
		Billing.profit_ctr_id,
		ProfitCenter.profit_ctr_name,
		Billing.Company_Id,
		Company.company_name,
		quantity = ISNULL(SUM(Billing.Quantity), 0.00),   
		gross_price = ISNULL(SUM(ROUND(Billing.quantity * Billing.price, 2)), 0.00),
		discount_dollars = ISNULL(SUM(ROUND((Billing.quantity * Billing.price) * (discount_percent / 100),2)), 0.00),
		Customer.customer_type,
		@user_id,
		Billing.waste_code_uid
	FROM Billing
	JOIN Company
		ON Company.company_id = Billing.company_id
	JOIN ProfitCenter
		ON ProfitCenter.company_ID = Billing.company_id
		AND ProfitCenter.profit_ctr_ID = Billing.profit_ctr_id
	JOIN Customer
		ON Customer.customer_ID = Billing.customer_id
		AND Customer.customer_type LIKE @customer_type
	WHERE Billing.status_code = 'I'
		AND Billing.void_status = 'F'
		AND Billing.company_id = @company_id
		AND Billing.billing_date BETWEEN @date_from AND @date_to
		AND Billing.customer_id BETWEEN @customer_id_from AND @customer_id_to
		AND Billing.trans_type = 'O'
	GROUP BY Billing.customer_id,
		Customer.Cust_Name,
		Billing.waste_code, 
		Billing.bill_unit_code,
		DATEPART(month,billing_date), 
		DATEPART(year,billing_date),
		Billing.profit_ctr_id,
		ProfitCenter.profit_ctr_name,
		Billing.Company_id,
		Company.company_name,
		Customer.Customer_type,
	    Billing.waste_code_uid
	ORDER BY Billing.customer_id,
		Customer.Cust_Name,
		Billing.waste_code, 
		Billing.bill_unit_code,
		DATEPART(month,billing_date),
		DATEPART(year,billing_date),
		Billing.profit_ctr_id,
		ProfitCenter.profit_ctr_name,
		Billing.Company_id,
		Company.company_name,
		Customer.Customer_type,
	    Billing.waste_code_uid
END

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_populate_work_wastesumrpt] TO [EQAI]
    AS [dbo];

