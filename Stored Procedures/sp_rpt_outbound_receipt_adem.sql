CREATE PROCEDURE sp_rpt_outbound_receipt_adem
	@company_id			int
,	@profit_ctr_id		int
,	@date_from			datetime
,	@date_to			datetime
,	@customer_id_from	int
,	@customer_id_to		int
AS
/***************************************************************************************
PB Object: r_outbound_receipt_adem

10/22/2014	SM	Created. Thhis report is for EQ Alabama. Report shows all outbound receipts
				from a company and profit center with the stock containers/Receipts/Batch 
				went in an outbound receipt
07/08/2019	JPB	Cust_name: 40->75 / Generator_Name: 40->75

sp_rpt_outbound_receipt_adem 32, 0, '07/01/2014','07/31/2014', 1, 999999

****************************************************************************************/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
DECLARE
	@cur_company_id				int,
	@cur_profit_ctr_id			int,
		@cur_receipt_id			int,
		@cur_line_id			int,
		@cur_container_id		int,
		@output					varchar(8000),
		@cur_outbound_type		char(1)
		
CREATE TABLE #work_Adem1 (
	receipt_id int,
		 line_id int,
		Container_id int,
		sequence_id int,
		 container_type char(1),
		waste_code char(10),
		waste_code_uid int,
		display_name varchar(10) )
		
CREATE TABLE #work_Adem (
	outbound_type   char(1)
,	company_id		int
,	profit_ctr_id	int
,   profit_ctr_name varchar(40)
,	receipt_date    Datetime
,	manifest		varchar(15)
,	ob_receipt_id		int
,	ob_line_id			int
,	container_id		int
,	receipt_line		varchar(40)
,	bill_qty			float
,	bill_unit_code		varchar(4)
,	waste_code_list		varchar(8000)
,	customer_id			int
,	cust_name			varchar(75)
,   generator_id		int
,	EPA_ID				varchar(12)
,   generator_name		Varchar(75)
,	ib_receipt_id		int
,	ib_line_id			int
)
-- To get all the receipts went into an outbound receipt.
INSERT INTO #work_adem
SELECT  
	'R' as outbound_type
,	Receipt_OB.company_id
,	Receipt_OB.profit_ctr_id
,	ProfitCenter.profit_ctr_name
,	Receipt_OB.receipt_date
,	Receipt_OB.manifest as outbound_manifest
,	Receipt_ob.receipt_id
,	Receipt_ob.line_id
,	containerdestination.container_id
,	dbo.fn_container_receipt(Receipt_IB.receipt_id, Receipt_IB.line_id) as receipt_line
,	1
,	ReceiptPrice.bill_unit_code
,	' ' as waste_code_list --= dbo.fn_receipt_waste_code_list ( Receipt_ib.company_id,Receipt_ib.profit_ctr_id,Receipt_ib.receipt_id,Receipt_ib.line_id)
,	Receipt_ob.customer_id
,	Customer.cust_name
,   Generator.generator_id 
,	Generator.EPA_ID 
,   Generator.generator_name
,	Receipt_ib.receipt_id
,	Receipt_ib.line_id
FROM Receipt Receipt_OB
JOIN Company
	ON Company.company_id = Receipt_OB.company_id
JOIN ProfitCenter
	ON ProfitCenter.company_ID = Receipt_OB.company_id
	AND ProfitCenter.profit_ctr_ID = Receipt_OB.profit_ctr_id
JOIN Receipt Receipt_IB
	ON 	Receipt_IB.company_id = Receipt_OB.company_id
	AND Receipt_IB.profit_ctr_ID = Receipt_OB.profit_ctr_id
	AND Receipt_IB.trans_mode = 'I'
	AND Receipt_IB.trans_type = 'D'
LEFT OUTER JOIN Customer
	ON Customer.customer_ID = Receipt_IB.customer_id
JOIN ContainerDestination
	ON ContainerDestination.company_id = Receipt_OB.company_id
	AND ContainerDestination.profit_ctr_id = Receipt_OB.profit_ctr_id
	AND ContainerDestination.receipt_id = Receipt_IB.receipt_id
	AND ContainerDestination.line_id = Receipt_IB.line_id
	AND ContainerDestination.tracking_num = dbo.fn_container_receipt(Receipt_OB.receipt_id, Receipt_OB.line_id)
	AND ContainerDestination.container_type = 'R'
JOIN ReceiptPrice
	ON ReceiptPrice.company_id = Receipt_ib.company_id
	AND ReceiptPrice.profit_ctr_id = Receipt_ib.profit_ctr_id
	AND ReceiptPrice.receipt_id = Receipt_ib.receipt_id
	AND ReceiptPrice.line_id = Receipt_ib.line_id
LEFT OUTER JOIN Generator
	ON Generator.generator_id = Receipt_IB.generator_id
WHERE	(@company_id = 0 OR Receipt_ob.company_id = @company_id)	
	AND (@company_id = 0 OR @profit_ctr_id = -1 OR Receipt_ob.profit_ctr_id = @profit_ctr_id)
	AND Receipt_ob.receipt_date BETWEEN @date_from AND @date_to
	AND Receipt_ob.customer_id BETWEEN @customer_id_from AND @customer_id_to
	AND Receipt_ob.trans_mode = 'O'
	AND Receipt_ob.receipt_status = 'A'
	AND Receipt_ob.fingerpr_status = 'A'
	AND Receipt_ob.trans_type = 'D'
 
UNION ALL
-- To get all stock containers went on to an outbound receipt
SELECT  
	'S' as outbound_type
,	Receipt_OB.company_id
,	Receipt_OB.profit_ctr_id
,	ProfitCenter.profit_ctr_name
,	Receipt_OB.receipt_date
,	Receipt_OB.manifest as outbound_manifest
,	Receipt_ob.receipt_id
,	Receipt_ob.line_id
,	containerdestination.container_id
,	receipt_line = dbo.fn_container_stock(ContainerDestination.line_id, ContainerDestination.company_id, ContainerDestination.profit_ctr_id)
,	1 as bill_quantity
,	'DM55'
,	' ' as waste_code_list --= dbo.fn_receipt_waste_code_list ( Receipt_ob.company_id,Receipt_ob.profit_ctr_id,Receipt_ob.receipt_id,Receipt_ob.line_id)
,	0
,	' '
,   0 
,	'  '
,   ' '
,	0
,	0
FROM Receipt Receipt_OB
JOIN Company
	ON Company.company_id = Receipt_OB.company_id
JOIN ProfitCenter
	ON ProfitCenter.company_ID = Receipt_OB.company_id
	AND ProfitCenter.profit_ctr_ID = Receipt_OB.profit_ctr_id
JOIN ContainerDestination
	ON ContainerDestination.company_id = Receipt_OB.company_id
	AND ContainerDestination.profit_ctr_id = Receipt_OB.profit_ctr_id
	AND ContainerDestination.tracking_num = dbo.fn_container_receipt(Receipt_OB.receipt_id, Receipt_OB.line_id)
	AND ContainerDestination.container_type = 'S'
WHERE	(@company_id = 0 OR Receipt_ob.company_id = @company_id)	
	AND (@company_id = 0 OR @profit_ctr_id = -1 OR Receipt_ob.profit_ctr_id = @profit_ctr_id)
	AND Receipt_ob.receipt_date BETWEEN @date_from AND @date_to
	AND Receipt_ob.customer_id BETWEEN @customer_id_from AND @customer_id_to
	AND Receipt_ob.trans_mode = 'O'
	AND Receipt_ob.receipt_status = 'A'
	AND Receipt_ob.fingerpr_status = 'A'
	AND Receipt_ob.trans_type = 'D'
	
UNION ALL
-- To get all the receipts/stock containers went on to an outbound receipts from a batch
SELECT 
	'B' as outbound_type
,	Receipt_OB.company_id
,	Receipt_OB.profit_ctr_id
,	ProfitCenter.profit_ctr_name
,	Receipt_OB.receipt_date
,	Receipt_OB.manifest as outbound_manifest
,	Receipt_ob.receipt_id
,	Receipt_ob.line_id
,	containerdestination.container_id
,	receipt_line = CONVERT(varchar(10), ContainerDestination.receipt_id) + '-' + CONVERT(varchar(5), ContainerDestination.line_id) --dbo.fn_container_stock(ContainerDestination.receipt_id, ContainerDestination.company_id, ContainerDestination.profit_ctr_id)
,	1
,	ReceiptPrice.bill_unit_code
,	' ' as waste_code_list --= dbo.fn_receipt_waste_code_list ( Receipt_ob.company_id,Receipt_ob.profit_ctr_id,ContainerDestination.receipt_id,ContainerDestination.line_id)
,	Receipt_ob.customer_id
,	Customer.cust_name
,   Generator.generator_id 
,	Generator.EPA_ID 
,   Generator.generator_name
,	ContainerDestination.receipt_id
,	ContainerDestination.line_id
FROM Receipt Receipt_OB
LEFT OUTER JOIN Generator
	ON Generator.generator_id = Receipt_OB.generator_id

JOIN Company
	ON Company.company_id = Receipt_OB.company_id
JOIN ProfitCenter
	ON ProfitCenter.company_ID = Receipt_OB.company_id
	AND ProfitCenter.profit_ctr_ID = Receipt_OB.profit_ctr_id
JOIN ContainerDestination
	ON ContainerDestination.company_id = Receipt_OB.company_id
	AND ContainerDestination.profit_ctr_id = Receipt_OB.profit_ctr_id
	AND ContainerDestination.location = Receipt_OB.location
	AND ContainerDestination.cycle = Receipt_OB.cycle
	AND ContainerDestination.tracking_num = Receipt_OB.tracking_num
LEFT OUTER JOIN Customer
	ON Customer.customer_ID = Receipt_ob.customer_id
JOIN ReceiptPrice
	ON ReceiptPrice.company_id = Receipt_OB.company_id
	AND ReceiptPrice.profit_ctr_id = Receipt_OB.profit_ctr_id
	AND ReceiptPrice.receipt_id = containerdestination.receipt_id
	AND ReceiptPrice.line_id = containerdestination.line_id
WHERE	(@company_id = 0 OR Receipt_ob.company_id = @company_id)	
	AND (@company_id = 0 OR @profit_ctr_id = -1 OR Receipt_ob.profit_ctr_id = @profit_ctr_id)
	AND Receipt_ob.receipt_date BETWEEN @date_from AND @date_to
	AND Receipt_ob.customer_id BETWEEN @customer_id_from AND @customer_id_to
	AND Receipt_ob.trans_mode = 'O'
	AND Receipt_ob.receipt_status = 'A'
	AND Receipt_ob.fingerpr_status = 'A'
	AND Receipt_ob.trans_type = 'D'
	
order by 7,8

DECLARE cur_Adem CURSOR FOR 
	SELECT company_id,
		profit_ctr_id,
		ib_receipt_id,
		ib_line_id,
		container_id,
		outbound_type
	FROM #work_adem   
	
	OPEN cur_Adem 

	FETCH cur_Adem 
	INTO  @cur_company_id,
		@cur_profit_ctr_id,
		@cur_receipt_id,
		@cur_line_id,
		@cur_container_id,
		@cur_outbound_type
	-- need to put if conditions for S, B and R
	WHILE @@FETCH_STATUS = 0 
	BEGIN
		SET @output = ''
		delete from #work_adem1
		-- To get list of weste codes from a stock container
		IF @cur_outbound_type = 'S' 
		Begin
			Insert  into #work_adem1
			EXEC dbo.sp_get_container_waste_codes @cur_company_id,@cur_profit_ctr_id,0,@cur_container_id,@cur_container_id,1,'S','T',0, 0
		END
		-- To get list of waste codes from a Receipt
		IF @cur_outbound_type <> 'S'
		BEGIN
			Insert  into #work_adem1
			EXEC dbo.sp_get_container_waste_codes @cur_company_id,@cur_profit_ctr_id,0,@cur_line_id,@cur_container_id,1,'R','T',0, 0
		END	
		SELECT  @output = CASE WHEN isnull(@output, '') = '' THEN display_name	ELSE COALESCE(@output + ', ', '') + display_name END
		FROM #work_adem1 
		
		-- In case of a 100% consolidation need to get the waste codes from receipt
		IF @output = ''
		BEGIN
				select @output = dbo.fn_receipt_waste_code_list(@cur_company_id, @cur_profit_ctr_id,@cur_receipt_id, @cur_line_id)
		END 
		
		update #work_adem set waste_Code_list = @output 
		where container_id = @cur_container_id 
		and ib_receipt_id = @cur_receipt_id
		and ib_line_id = @cur_line_id
	
		FETCH cur_Adem 
		INTO  @cur_company_id,
		@cur_profit_ctr_id,
		@cur_receipt_id,
		@cur_line_id,
		@cur_container_id,
		@cur_outbound_type

	END
CLOSE cur_Adem 
DEALLOCATE cur_Adem

select company_id		
,	profit_ctr_id	
,   profit_ctr_name 
,	receipt_date    
,	manifest		
,	ob_receipt_id		
,	ob_line_id			
,	receipt_line		
,	sum(bill_qty)	as bill_qty		
,	bill_unit_code		
,	waste_code_list		
,	customer_id			
,	cust_name			
,   generator_id		
,	EPA_ID				
,   generator_name	
 From #work_adem
 group by
 	company_id		
,	profit_ctr_id	
,   profit_ctr_name 
,	receipt_date    
,	manifest		
,	ob_receipt_id		
,	ob_line_id			
,	receipt_line		
,	bill_unit_code		
,	waste_code_list		
,	customer_id			
,	cust_name			
,   generator_id		
,	EPA_ID				
,   generator_name
order by 6,7

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_outbound_receipt_adem] TO [EQAI]
    AS [dbo];

