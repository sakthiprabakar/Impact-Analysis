DROP PROCEDURE IF EXISTS sp_rpt_open_transactions_with_notes
GO

CREATE PROCEDURE [dbo].[sp_rpt_open_transactions_with_notes]
               @company_id      int
,              @profit_ctr_id   int
,              @date_from       datetime
,              @date_to         datetime
AS
/***********************************************************************************
This SP returns workorders on open, with their notes (if any)

PB Object(s):       r_open_transactions_with_notes

08/23/2017  AM  Created on Plt_AI
02/14/2018  MPM Widened #FlashWork.customer_type to varchar(20).
02/28/2018  AM  EQAI-48594 - Added note_subject to result set.
03/19/2018  AM  EQAI-48439 - Added group by to #un_invoiced_receipts_workorders to avoid duplicate rows.
07/08/2019  JPB Cust_name: 40->75 / Generator_Name: 40->75
02/20/2020  AM  DevOps:14516 - Added cursor to insert all available notes for receipt and workorders
09/03/2020  AM  DevOps:14516 - Adde  receipt_stats and billing_status    to result set.
11/10/2020  MPM DevOps 17889 - Added Manage Engine WorkOrderHeader.ticket_number to #FlashWork.
04/26/2021  AM  DevOps:18722 - Added generator_id, generator_name, epa_id and ticket number to result set. Also getting the max note id
06/30/2021  GDE DevOps 29483 - Open Transactions with Notes Report Update
04/10/2023  MPM DevOps 64115 - Added column cust_category to #Flashwork.
04/19/2023  MPM DevOps 64115 - Modified the call to sp_rpt_flash_calc because an input parameter was recently added to it.
05/12/2023  Dipankar DevOps 64585 - Optimized Code, avoided uses of temp table #un_invoiced_receipts_workorders1
07/05/2023  Dipankar DevOps 65982 - Optimized Code, using new temp table #Note
07/31/2024 AM	DevOps:94051 - Modified approval_desc datatype 60 to VARCHAR(100) for #FlashWork table.

exec sp_rpt_open_transactions_with_notes 14 ,14, '6/01/17', '8/20/17'
exec sp_rpt_open_transactions_with_notes 26 ,0, '11/01/2017','11/04/2017'
exec sp_rpt_open_transactions_with_notes 21 ,1, '1/08/2018','1/14/2018'
execute dbo.sp_rpt_open_transactions_with_notes 3,0,'7/3/2020','10/29/2020'
execute dbo.sp_rpt_open_transactions_with_notes 42,0,'10/1/2019','1/17/2020' 
execute dbo.sp_rpt_open_transactions_with_notes 42,0,'1/1/2020','1/17/2021' 
***********************************************************************************/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
declare 
     @note_id  int ,
    @note_date datetime,
    @note  varchar(5000),
    @note_subject varchar(50),
    @ret_company_id int,
    @ret_profit_ctr_id int,
    @inv_cust_name varchar(100),
    @inv_cust_id  int,
    @receipt_id int,
    @trans_date datetime,
    @trans_status char(1),
    @bill_status_code char(1),
    @trans_source   char(1),
    @billing_project_id int,
    @company_profit varchar(10),
    @submitted_flag  char(1),
    @invoice_code    varchar(16),
    @waste_accepted_flag  char(1),
	@ticket_number	int,
	@generator_id int,
	@generator_name varchar(75),
	@epa_id varchar(12),
	@count int -- #Dipankar

BEGIN
	-- Setup table
	CREATE TABLE #un_invoiced_receipts_workorders (
				   cust_name   varchar(100)  NULL,
				   customer_id  int   NULL,    
				   customer_service_Rep   varchar(40)  NULL,
				   billing_project_id  int   NULL,
				   receipt_id   int  NULL,
				   --extended_amt  float    NULL,
				   trans_date   datetime  NULL,
				   trans_status   char(1)  NULL,
				   billing_status_code  char(1)  NULL,
				   company_id    int   NULL,
				   profit_ctr_id   int   NULL,
				   company_name  varchar(100) NULL,
				   profit_ctr_name  varchar(40) NULL,           
					note_id   int NULL,
					note_date datetime     NULL,
					note   text  null,
				   trans_source  char(2)  NULL,
				   note_subject  varchar(100) NULL,
				   submitted_flag   char(1),
				   invoice_code varchar(16),
				   invoice_id  int NULL,
				   generator_id   int   NULL,  
				   generator_name varchar(75)   NULL,   
				   epa_id varchar(12) NULL,
				   ticket_number  int NULL,
				   waste_accepted_flag    char(1)  NULL -- Added for #64585
	)

	/* -- Commented for #64585
	CREATE TABLE #un_invoiced_receipts_workorders1 (
				   cust_name  varchar(100)  NULL,
				   customer_id  int  NULL,    
				   customer_service_Rep   varchar(40) NULL,
				   billing_project_id    int    NULL,
				   receipt_id   int   NULL,
				   trans_date datetime  NULL,
				   trans_status   char(1) NULL,
				   billing_status_code  char(1)  NULL,
				   company_id  int NULL,
				   profit_ctr_id  int NULL,
				   company_name varchar(100) NULL,         
					note_id  int NULL,
					note_date  datetime NULL,
					note  text null,
				   trans_source   char(2)  NULL,
				   note_subject varchar(100) NULL,
				   submitted_flag char(1),
				   invoice_code    varchar(16),
				   invoice_id    int NULL,
				   waste_accepted_flag    char(1)  NULL,
				   receipt_stats   varchar(20),
				   billing_status  varchar(20),
				   generator_id  int NULL,  
				   generator_name varchar(75) NULL,   
				   epa_id  varchar(12) NULL,
				   ticket_number int NULL
	)
	*/

	CREATE TABLE #FlashWork (

				   --            Header info:
								  company_id int NULL,
								  profit_ctr_id int  NULL,
								  trans_source  char(2) NULL,    --               Receipt,               Workorder,         Workorder-Receipt,         etc
								  receipt_id   int   NULL,               --            Receipt/Workorder          ID
								  trans_type   char(1) NULL,    --               Receipt trans      type       (O/I)
								  link_flag    char(1)  NULL,    --  if R/WO, is this linked to a WO/R? T/F
								  linked_record  varchar(255) NULL,    -- if R, list of WO's linked to (prob. just 1, but multiple poss.)
								  workorder_type  varchar(40) NULL,    --               WorkOrderType.account_desc
								  trans_status    char(1)  NULL,    --               Receipt or           Workorder          Status
								  status_description    varchar(40) NULL,           --  Billing/Transaction Status (Invoiced, Billing Validated, Accepted, etc)
								  trans_date    datetime  NULL,    --               Receipt Date      or           Workorder          End        Date
								  pickup_date   datetime  NULL,    --  Receipt Pickup Date or Workorder Pickup Date (transporter 1 sign date either way)
								  submitted_flag char(1)  NULL,    --               Submitted            Flag
								  date_submitted  datetime NULL,    --  Submitted Date
								  submitted_by  varchar(10)  NULL,    --  Submitted By
								  billing_status_code  char(1)  NULL,    --  Billing Status Code
								  territory_code  varchar(8)  NULL,    --            Billing               Project  Territory              code
								  billing_project_id  int    NULL,    --               Billing    project  ID
								  billing_project_name  varchar(40) NULL,    --            Billing               Project  Name
								  invoice_flag  char(1)  NULL,    --  'T'/'F' (Invoiced/Not Invoiced)
								  invoice_code  varchar(16)  NULL,    --               Invoice  Code      (if           invoiced)
								  invoice_date  datetime   NULL,    --               Invoice  Date      (if           invoiced)
								  invoice_month int   NULL,    --               Invoice  Date      month
								  invoice_year  int  NULL,    --               Invoice  Date      year
								  customer_id   int  NULL,               --            Customer            ID           on          Receipt/Workorder
								  cust_name    varchar(75) NULL,    --               Customer            Name
								  customer_type  varchar(20) NULL,    --  Customer Type
								  cust_category     varchar(30) NULL,	--	Customer Category

				   --            Detail info:
								  line_id  int  NULL,               --            Receipt line         id
								  price_id  int  NULL,               --            Receipt line         price      id
								  ref_line_id  int NULL,               --            Billing    reference            line_id   (which   line         does      this         refer      to?)
								  workorder_sequence_id  varchar(15)  NULL,    --               Workorder          sequence             id
								  workorder_resource_item   varchar(15)  NULL,    --               Workorder          Resource             Item
								  workorder_resource_type   varchar(15)  NULL,    --               Workorder          Resource             Type
								  Workorder_resource_category   Varchar(40)  NULL,    --            Workorder               Resource             Category
								  quantity   float  NULL,    --               Receipt/Workorder          Quantity
								  billing_type     varchar(20)  NULL,    --               'Energy',              'Insurance',         'Salestax'             etc.
								  dist_flag  char(1)   NULL,    --               'D', 'N' (Distributed/Not Distributed -- if the dist co/pc is diff from native co/pc, this is D)
								  dist_company_id   int  NULL,               --            Distribution         Company             ID           (which   company             receives               the         revenue)
								  dist_profit_ctr_id int NULL,    --               Distribution         Profit     Ctr          ID           (which   profitcenter        receives               the               revenue)
								  gl_account_code    varchar(12) NULL,    --               GL          Account               for          the         revenue
								  gl_native_code  varchar(5) NULL,    --            GL Native code (first 5 characters)
								  gl_dept_code   varchar(3)  NULL,    --            GL Dept (last 3 characters)
								  extended_amt   float   NULL,    --               Revenue              amt
								  generator_id   int    NULL,    --               Generator           ID
								  generator_name  varchar(75)   NULL,    --               Generator           Name
								  epa_id     varchar(12)  NULL,    --               Generator           EPA        ID
								  treatment_id   int  NULL,    --               Treatment           ID
								  treatment_desc varchar(32)  NULL,    --               Treatment's        treatment_desc
								  treatment_process_id   int  NULL,    --               Treatment's        treatment_process_id
								  treatment_process  varchar(30) NULL,    --               Treatment's        treatment_process          (desc)
								  disposal_service_id   int   NULL,    --               Treatment's        disposal_service_id
								  disposal_service_desc  varchar(20)   NULL,    --            Treatment's               disposal_service_desc
								  wastetype_id    int   NULL,    --               Treatment's        wastetype_id
								  wastetype_category  varchar(40) NULL,    --               Treatment's        wastetype           category
								  wastetype_description  varchar(60)  NULL,    --            Treatment's               wastetype           description
								  bill_unit_code  varchar(4) NULL,    --            Unit
								  waste_code  varchar(4)  NULL,    --               Waste   Code
								  profile_id  int NULL,               --            Profile_id
								  quote_id   int     NULL,               --            Quote    ID
								  product_id     int  NULL,               --            BillingDetail        product_id,         for          id'ing     fees,      etc.
								  product_code  varchar(15) NULL,    -- Product Code
								  approval_code   varchar(40)  NULL,    --               Approval              Code
								  approval_desc    varchar(100) NULL,
								  TSDF_code     Varchar(15)   NULL,    --               TSDF      Code
								  TSDF_EQ_FLAG   Char(1) NULL,    --            TSDF:               Is            this         an           EQ          tsdf?
								  fixed_price_flag char(1) NULL,    --            Fixed      Price               Flag
								  pricing_method    char(1) NULL,    --               Calculated,          Actual,  etc.
								  quantity_flag  char(1) NULL,    --            T               =             has         quantities,           F             =             no          quantities,           so           0               used.
								  JDE_BU   varchar(7)  NULL,    -- JDE Busines Unite
								  JDE_object varchar(5)  NULL,    -- JDE Object

								  AX_MainAccount                                                           varchar(20)         NULL,    -- AX_MainAccount              -- All these AX fields are usually not to allow NULLs
								  AX_Dimension_1                                                           varchar(20)         NULL,    -- AX_legal_entity  -- But in un-billed work they're not populated yet.
								  AX_Dimension_2                                                           varchar(20)         NULL,    -- AX_business_unit
								  AX_Dimension_3                                                           varchar(20) NULL,           -- AX_department
								  AX_Dimension_4                                                           varchar(20)         NULL,    -- AX_line_of_business
								  AX_Dimension_5_Part_1                              varchar(20) NULL,           -- AX_project (technically, AX_Dimension_"6" is displayed before "5")
								  AX_Dimension_5_Part_2                              varchar(9)            NULL,    -- AX_subproject (technically, AX_Dimension_"6" is displayed before "5")
								  AX_Dimension_6                                                           varchar(20)         NULL,    -- AX_advanced_rule (technically, AX_Dimension_"6" is displayed before "5")
                              
								  first_invoice_date                                          datetime              NULL,    -- Date of first invoice
                              
								  waste_code_uid                                                            int                                        NULL,
								  reference_code              varchar (32) NULL,
								  job_type                                                                          char(1)                 NULL,                   -- Base or Event (B/E)
								  purchase_order                                              varchar (20) NULL,
								  release_code                                                   varchar (20) NULL,
									ticket_number				int			NULL	-- WorkOrderHeader.ticket_number, for a work order, or for a receipt's linked work order
				   )
	SET  @company_profit = 'ALL' 

	IF @company_id = 0 AND @profit_ctr_id = -1
		SET  @company_profit = 'ALL'    

	  IF @company_id > 0 AND @profit_ctr_id <> -1
		SET  @company_profit = CONVERT(varchar(2), (@company_id))  + '|' + CONVERT(varchar(2), @profit_ctr_id )   

	EXEC sp_rpt_flash_calc @company_profit, @date_from, @date_to, 0, 999999, '*Any*', '*Any*', 'N', 'R,W,O', 'D', 'A', 0

	-- print 'SUCCESS -1'

	INSERT INTO #un_invoiced_receipts_workorders 
	SELECT 
		#FlashWork.cust_name
	,   #FlashWork.customer_id
	,              NULL
	,              #FlashWork.billing_project_id
	,              #FlashWork.receipt_id
	--,   #FlashWork.extended_amt
	,              #FlashWork.trans_date
	,              #FlashWork.trans_status
	,              #FlashWork.billing_status_code
	,              #FlashWork.company_id 
	,              #FlashWork.profit_ctr_id
	,   NULL
	,              NULL
	,              NULL 
	,              NULL
	,              NULL
	,   #FlashWork.trans_source
	,   NULL
	,  #FlashWork.submitted_flag
	,  #FlashWork.invoice_code
	,  null
	,  #FlashWork.generator_id
	,  #FlashWork.generator_name
	,  #FlashWork.epa_id
	,  #FlashWork.ticket_number
	,  NULL -- #64585
	FROM #FlashWork 
	GROUP BY
	#FlashWork.cust_name
	,   #FlashWork.customer_id
	,              #FlashWork.billing_project_id
	,              #FlashWork.receipt_id
	,              #FlashWork.trans_date
	,              #FlashWork.trans_status
	,              #FlashWork.billing_status_code
	,              #FlashWork.company_id 
	,              #FlashWork.profit_ctr_id
	,   #FlashWork.trans_source
	,  #FlashWork.submitted_flag
	,  #FlashWork.invoice_code
	,  #FlashWork.generator_id
	,  #FlashWork.generator_name
	,  #FlashWork.epa_id 
	,  #FlashWork.ticket_number

	-- print 'SUCCESS 0'
	--select getdate () from company where company_id = 21

	  /* -- Commented for #64585
	  DECLARE open_cursor CURSOR FOR
								  SELECT Note.note_id,Note.note_date,Note.note,Note.subject,#un_invoiced_receipts_workorders.billing_project_id,#un_invoiced_receipts_workorders.company_id,#un_invoiced_receipts_workorders.profit_ctr_id,
								  #un_invoiced_receipts_workorders.cust_name,#un_invoiced_receipts_workorders.customer_ID,#un_invoiced_receipts_workorders.receipt_id,
								  #un_invoiced_receipts_workorders.trans_date,#un_invoiced_receipts_workorders.trans_status,#un_invoiced_receipts_workorders.billing_status_code,
								  #un_invoiced_receipts_workorders.trans_source,#un_invoiced_receipts_workorders.submitted_flag,#un_invoiced_receipts_workorders.invoice_code,#un_invoiced_receipts_workorders.ticket_number,
								  #un_invoiced_receipts_workorders.generator_id,#un_invoiced_receipts_workorders.generator_name,#un_invoiced_receipts_workorders.epa_id
								  FROM  #un_invoiced_receipts_workorders
						 INNER JOIN NOTE  
												 ON ( #un_invoiced_receipts_workorders.receipt_id = Note.receipt_id OR #un_invoiced_receipts_workorders.receipt_id = Note.workorder_id )
												 AND #un_invoiced_receipts_workorders.company_id = Note.company_id
												 AND #un_invoiced_receipts_workorders.profit_ctr_id = Note.profit_ctr_id
												 --AND (#un_invoiced_receipts_workorders.line_id = (SELECT TOP 1 line_id FROM #un_invoiced_receipts_workorders r2 WHERE r2.receipt_id = Note.receipt_id)
												 --  OR #un_invoiced_receipts_workorders.line_id = (SELECT TOP 1 line_id FROM #un_invoiced_receipts_workorders r2 WHERE r2.receipt_id = Note.workorder_id)
												   --)
								  WHERE Note.note_source in ('Workorder', 'Receipt','')
								  AND Note.note_type <> 'AUDIT'
								  AND ( @company_id = 0 OR #un_invoiced_receipts_workorders.company_id = @company_id )
								  AND (@company_id = 0 OR @profit_ctr_id = -1 OR #un_invoiced_receipts_workorders.profit_ctr_id = @profit_ctr_id )



								  OPEN open_cursor
								  FETCH NEXT FROM open_cursor INTO @note_id,@note_date,@note,@note_subject,@billing_project_id,@ret_company_id,@ret_profit_ctr_id,@inv_cust_name,
									  @inv_cust_id,@receipt_id,@trans_date,@trans_status,@bill_status_code,@trans_source,@submitted_flag,@invoice_code,@ticket_number,@generator_id,@generator_name,@epa_id
                                                                                          
								  WHILE @@FETCH_STATUS = 0
                       
								  BEGIN
												 insert into #un_invoiced_receipts_workorders1 values( @inv_cust_name,@inv_cust_id,'',@billing_project_id,@receipt_id,@trans_date,@trans_status,@bill_status_code,@ret_company_id
																							  ,@ret_profit_ctr_id, '' ,@note_id,@note_date,@note,@trans_source, @note_subject, @submitted_flag, @invoice_code, null,@waste_accepted_flag, null,null,@generator_id,@generator_name,@epa_id,@ticket_number)
												 -- get next adjustment
												 FETCH NEXT FROM open_cursor  INTO @note_id,@note_date,@note,@note_subject,@billing_project_id,@ret_company_id,@ret_profit_ctr_id,@inv_cust_name,@inv_cust_id,@receipt_id,@trans_date,@trans_status,
																											 @bill_status_code,@trans_source,@submitted_flag,@invoice_code,@ticket_number,@generator_id,@generator_name,@epa_id
								  END       
								  CLOSE open_cursor
								  DEALLOCATE open_cursor 

	UPDATE #un_invoiced_receipts_workorders
	  SET #un_invoiced_receipts_workorders.note_id = ( SELECT max(n.note_id)
												FROM Note n
												WHERE n.note_source in ('Workorder', 'Receipt','')
												 AND n.note_type <> 'AUDIT'
												 AND n.company_id = note.company_id
												 AND n.profit_ctr_id = Note.profit_ctr_id
												 AND ( n.workorder_id = Note.workorder_id OR n.Receipt_id = Note.workorder_id  ) ) -- Note.note_id 
	   ,  #un_invoiced_receipts_workorders.note_date = Note.note_date
	   ,  #un_invoiced_receipts_workorders.note = Note.note
	   ,  #un_invoiced_receipts_workorders.note_subject = Note.subject
	FROM Note
	JOIN #un_invoiced_receipts_workorders 
				   ON ( #un_invoiced_receipts_workorders.receipt_id = Note.receipt_id OR #un_invoiced_receipts_workorders.receipt_id = Note.workorder_id )
				   AND #un_invoiced_receipts_workorders.company_id = Note.company_id
				   AND #un_invoiced_receipts_workorders.profit_ctr_id = Note.profit_ctr_id
	WHERE Note.note_source in ('Workorder', 'Receipt','')
	AND Note.note_type <> 'AUDIT'	 */ -- #64585
	
	-- #64582 - Added
	SELECT	Note.company_id, 
			Note.profit_ctr_id, 
			Note.note_id, 
			Note.note,
			Note.note_date,
			Note.note_source, 
			Note.note_type, 
			Note.subject, 
			#un_invoiced_receipts_workorders.receipt_id
	INTO	#Note
	FROM	Note	
	INNER JOIN #un_invoiced_receipts_workorders 
	ON ( #un_invoiced_receipts_workorders.receipt_id = Note.receipt_id OR #un_invoiced_receipts_workorders.receipt_id = Note.workorder_id )
		 AND #un_invoiced_receipts_workorders.company_id = Note.company_id
		 AND #un_invoiced_receipts_workorders.profit_ctr_id = Note.profit_ctr_id
	WHERE Note.note_source in ('Workorder', 'Receipt','')
	AND Note.note_type <> 'AUDIT'
	AND Note.note_id = ( SELECT max(n.note_id) 
						 FROM Note n
						 WHERE n.note_source	= Note.note_source 
						 AND   n.note_type		= Note.note_type
						 AND   n.company_id		= Note.company_id
						 AND   n.profit_ctr_id	= Note.profit_ctr_id
						 AND ( n.workorder_id	= #un_invoiced_receipts_workorders.receipt_id OR n.receipt_id = #un_invoiced_receipts_workorders.receipt_id))

                             
    -- #64582 - Commented 
	/*
	UPDATE #un_invoiced_receipts_workorders
	SET #un_invoiced_receipts_workorders.note_id =  Note.note_id 
	   ,  #un_invoiced_receipts_workorders.note_date = Note.note_date
	   ,  #un_invoiced_receipts_workorders.note = Note.note
	   ,  #un_invoiced_receipts_workorders.note_subject = Note.subject
	FROM #un_invoiced_receipts_workorders
	INNER JOIN Note 
				   ON ( #un_invoiced_receipts_workorders.receipt_id = Note.receipt_id OR #un_invoiced_receipts_workorders.receipt_id = Note.workorder_id )
				   AND #un_invoiced_receipts_workorders.company_id = Note.company_id
				   AND #un_invoiced_receipts_workorders.profit_ctr_id = Note.profit_ctr_id
	WHERE Note.note_source in ('Workorder', 'Receipt','')
	AND Note.note_type <> 'AUDIT'
	AND Note.note_id = ( SELECT max(n.note_id) 
						 FROM Note n
						 WHERE n.note_source = Note.note_source 
						 AND n.note_type = Note.note_type
						 AND n.company_id = note.company_id
						 AND n.profit_ctr_id = Note.profit_ctr_id
						 AND ( n.workorder_id = Note.workorder_id OR n.Receipt_id = Note.workorder_id  ) )
	AND ( @company_id = 0 OR #un_invoiced_receipts_workorders.company_id = @company_id )
	AND ( @company_id = 0 OR @profit_ctr_id = -1 OR #un_invoiced_receipts_workorders.profit_ctr_id = @profit_ctr_id )
	*/

	-- #64582 - Added 
	UPDATE	#un_invoiced_receipts_workorders
	SET		#un_invoiced_receipts_workorders.note_id		= #Note.note_id,
			#un_invoiced_receipts_workorders.note_date		= #Note.note_date,
			#un_invoiced_receipts_workorders.note			= #Note.note,
			#un_invoiced_receipts_workorders.note_subject	= #Note.subject
	FROM	#un_invoiced_receipts_workorders
	INNER JOIN #Note 
		ON (#un_invoiced_receipts_workorders.receipt_id		= #Note.receipt_id
		AND #un_invoiced_receipts_workorders.company_id		= #Note.company_id
		AND #un_invoiced_receipts_workorders.profit_ctr_id	= #Note.profit_ctr_id)
	AND	  (@company_id = 0 OR #un_invoiced_receipts_workorders.company_id = @company_id)
	AND	  (@company_id = 0 OR @profit_ctr_id = -1 OR #un_invoiced_receipts_workorders.profit_ctr_id = @profit_ctr_id)

	-- print 'SUCCESS 1'

	UPDATE	#un_invoiced_receipts_workorders
	SET		customer_service_Rep = csr.user_name,
			billing_project_id = 0,
			company_name = Company.company_name,
			invoice_id = IH.invoice_id,
			generator_id = NULL,  
			generator_name = NULL,   
			epa_id = NULL
	FROM	#un_invoiced_receipts_workorders
			JOIN Customer C ON C.customer_ID = #un_invoiced_receipts_workorders.customer_id
			JOIN Company ON #un_invoiced_receipts_workorders.company_id = Company.company_id 
			LEFT OUTER JOIN invoiceheader IH on IH.invoice_code = #un_invoiced_receipts_workorders.invoice_code
			LEFT OUTER JOIN Customerbilling CB ON  CB.customer_ID = #un_invoiced_receipts_workorders.customer_id
			AND #un_invoiced_receipts_workorders.billing_project_id = CB.billing_project_id
			LEFT OUTER JOIN Region ON CB.region_id = Region.region_id
			LEFT OUTER JOIN usersxeqcontact csrx on CB.customer_service_id = csrx.type_id
			AND csrx.eqcontact_type = 'CSR'
			LEFT OUTER JOIN Users csr on csrx.user_code = csr.user_code
	WHERE ( @company_id = 0 OR #un_invoiced_receipts_workorders.company_id = @company_id )
	AND (@company_id = 0 OR @profit_ctr_id = -1 OR #un_invoiced_receipts_workorders.profit_ctr_id = @profit_ctr_id )
	AND #un_invoiced_receipts_workorders.note_id Is NULL

	-- print 'SUCCESS 2'

	UPDATE un set un.waste_accepted_flag = receipt.waste_accepted_flag
	FROM #un_invoiced_receipts_workorders un  
	join receipt  on un.company_id = receipt.company_id
	and un.profit_ctr_id = receipt.profit_ctr_id
	and un.receipt_id = receipt.receipt_id 

    -- print 'SUCCESS 3'

	-- #64582 - Modified to use #Note instead of Note Table
	DELETE FROM #un_invoiced_receipts_workorders
	WHERE NOT EXISTS (SELECT 1 FROM #un_invoiced_receipts_workorders
					JOIN Customer C ON C.customer_ID = #un_invoiced_receipts_workorders.customer_id
					JOIN Company ON #un_invoiced_receipts_workorders.company_id = Company.company_id 
					LEFT OUTER JOIN invoiceheader IH on IH.invoice_code = #un_invoiced_receipts_workorders.invoice_code
					LEFT OUTER JOIN Customerbilling CB ON  CB.customer_ID = #un_invoiced_receipts_workorders.customer_id
					AND #un_invoiced_receipts_workorders.billing_project_id = CB.billing_project_id
					LEFT OUTER JOIN Region ON CB.region_id = Region.region_id
					LEFT OUTER JOIN usersxeqcontact csrx on CB.customer_service_id = csrx.type_id
					AND csrx.eqcontact_type = 'CSR'
					LEFT OUTER JOIN Users csr on csrx.user_code = csr.user_code
					WHERE ( @company_id = 0 OR #un_invoiced_receipts_workorders.company_id = @company_id )
					AND (@company_id = 0 OR @profit_ctr_id = -1 OR #un_invoiced_receipts_workorders.profit_ctr_id = @profit_ctr_id )
					AND #un_invoiced_receipts_workorders.note_id Is NULL)
	AND NOT EXISTS (SELECT 1 FROM  #un_invoiced_receipts_workorders
					INNER JOIN #Note  
					ON (#un_invoiced_receipts_workorders.receipt_id		= #Note.receipt_id)
					AND #un_invoiced_receipts_workorders.company_id		= #Note.company_id
					AND #un_invoiced_receipts_workorders.profit_ctr_id	= #Note.profit_ctr_id
					WHERE (@company_id = 0 OR #un_invoiced_receipts_workorders.company_id = @company_id)
					AND   (@company_id = 0 OR @profit_ctr_id = -1 OR #un_invoiced_receipts_workorders.profit_ctr_id = @profit_ctr_id))
	
	/*
	AND NOT EXISTS (SELECT 1 FROM  #un_invoiced_receipts_workorders
					INNER JOIN NOTE  
					ON ( #un_invoiced_receipts_workorders.receipt_id = Note.receipt_id OR #un_invoiced_receipts_workorders.receipt_id = Note.workorder_id )
					AND #un_invoiced_receipts_workorders.company_id = Note.company_id
					AND #un_invoiced_receipts_workorders.profit_ctr_id = Note.profit_ctr_id
					WHERE Note.note_source in ('Workorder', 'Receipt','')
					AND Note.note_type <> 'AUDIT'
					AND ( @company_id = 0 OR #un_invoiced_receipts_workorders.company_id = @company_id )
					AND (@company_id = 0 OR @profit_ctr_id = -1 OR #un_invoiced_receipts_workorders.profit_ctr_id = @profit_ctr_id ))
	*/
	
	-- print 'SUCCESS 4'

    /*
	insert into #un_invoiced_receipts_workorders1
	  SELECT 
		 #un_invoiced_receipts_workorders.cust_name,
				   #un_invoiced_receipts_workorders.customer_ID,             
				   csr.user_name as customer_service_Rep,
				   0,
				   receipt_id           ,
				   trans_date,
				   trans_status,
				   billing_status_code,
				   #un_invoiced_receipts_workorders.company_id,
				   #un_invoiced_receipts_workorders.profit_ctr_id,             
				   Company.company_name,
				   note_id,
		 note_date,
		 note,
		 trans_source,
		 note_subject,
				   #un_invoiced_receipts_workorders.submitted_flag,
				   #un_invoiced_receipts_workorders.invoice_code,
				   IH.invoice_id,
				   Null,
				   Null,
				   Null,
				   #un_invoiced_receipts_workorders.generator_id,
				   #un_invoiced_receipts_workorders.generator_name,
				   #un_invoiced_receipts_workorders.epa_id,
				   #un_invoiced_receipts_workorders.ticket_number
	FROM #un_invoiced_receipts_workorders
	JOIN Customer C ON C.customer_ID = #un_invoiced_receipts_workorders.customer_id
	JOIN Company ON #un_invoiced_receipts_workorders.company_id = Company.company_id 
	--JOIN ProfitCenter P ON #un_invoiced_receipts_workorders.profit_ctr_id = p.profit_ctr_ID
	LEFT OUTER JOIN invoiceheader IH on IH.invoice_code = #un_invoiced_receipts_workorders.invoice_code
	LEFT OUTER JOIN Customerbilling CB ON  CB.customer_ID = #un_invoiced_receipts_workorders.customer_id
	   AND #un_invoiced_receipts_workorders.billing_project_id = CB.billing_project_id
	LEFT OUTER JOIN Region ON CB.region_id = Region.region_id
	LEFT OUTER JOIN usersxeqcontact csrx on CB.customer_service_id = csrx.type_id
			  AND csrx.eqcontact_type = 'CSR'
	LEFT OUTER JOIN Users csr on csrx.user_code = csr.user_code
	WHERE ( @company_id = 0 OR #un_invoiced_receipts_workorders.company_id = @company_id )
				   AND (@company_id = 0 OR @profit_ctr_id = -1 OR #un_invoiced_receipts_workorders.profit_ctr_id = @profit_ctr_id )
				   AND #un_invoiced_receipts_workorders.note_id Is NULL

	UPDATE un set un.waste_accepted_flag = receipt.waste_accepted_flag
	FROM #un_invoiced_receipts_workorders1 un  
	join receipt  on un.company_id = receipt.company_id
	and un.profit_ctr_id = receipt.profit_ctr_id
	and un.receipt_id = receipt.receipt_id 
	
	SELECT 
		#un_invoiced_receipts_workorders1.cust_name,
				   #un_invoiced_receipts_workorders1.customer_ID,           
				   #un_invoiced_receipts_workorders1.customer_service_Rep,
				   #un_invoiced_receipts_workorders1.receipt_id  ,
				   --sum (extended_amt ) as extended_amt,
				   --extended_amt,
				   #un_invoiced_receipts_workorders1.trans_date,
				   #un_invoiced_receipts_workorders1.trans_status,
				   #un_invoiced_receipts_workorders1.billing_status_code,
				   #un_invoiced_receipts_workorders1.company_id,
				   #un_invoiced_receipts_workorders1.profit_ctr_id,           
				   #un_invoiced_receipts_workorders1.company_name,
				   #un_invoiced_receipts_workorders1.note_id,
				 #un_invoiced_receipts_workorders1.note_date,
				 #un_invoiced_receipts_workorders1.note,
				 #un_invoiced_receipts_workorders1.trans_source,
				 #un_invoiced_receipts_workorders1.note_subject,
				   #un_invoiced_receipts_workorders1.submitted_flag,
				   #un_invoiced_receipts_workorders1.invoice_code,
				   #un_invoiced_receipts_workorders1.invoice_id,
				   #un_invoiced_receipts_workorders1.waste_accepted_flag,
				   Case   
					   WHEN #un_invoiced_receipts_workorders1.submitted_flag = 'T' THEN 'Submitted'
								  WHEN #un_invoiced_receipts_workorders1.trans_status = 'N' OR ISNULL(#un_invoiced_receipts_workorders1.trans_status,'N') = 'N' THEN 'New'
								  WHEN #un_invoiced_receipts_workorders1.trans_status = 'M'THEN 'Manual'
								  WHEN #un_invoiced_receipts_workorders1.trans_status = 'H'THEN 'Hold'
								  WHEN #un_invoiced_receipts_workorders1.trans_status = 'L' THEN 'In the Lab'
								  WHEN #un_invoiced_receipts_workorders1.trans_status = 'U' AND  #un_invoiced_receipts_workorders1.waste_accepted_flag  = 'T'THEN 'Waste Accepted' --ELSE 'Unloading'
					   WHEN #un_invoiced_receipts_workorders1.trans_status = 'V'THEN 'Void'
								  WHEN #un_invoiced_receipts_workorders1.trans_status = 'T'THEN 'In-Transit'
								  WHEN #un_invoiced_receipts_workorders1.trans_status = 'R'THEN 'Rejected'
								  WHEN #un_invoiced_receipts_workorders1.trans_status = 'A'THEN 'Accepted'
				   END ,
				   CASE 
					 WHEN  #un_invoiced_receipts_workorders1.billing_status_code = 'N' AND #un_invoiced_receipts_workorders1.invoice_code like 'Preview_%' THEN 'New- Preview Invoice'
					 WHEN  #un_invoiced_receipts_workorders1.billing_status_code = 'N' AND IsNull (#un_invoiced_receipts_workorders1.invoice_code, 'N') = 'N' THEN 'New- Not invoiced'
					 WHEN  #un_invoiced_receipts_workorders1.billing_status_code = 'H' AND IsNull (#un_invoiced_receipts_workorders1.invoice_code, 'H') = 'H' THEN 'On Hold-Not Invoiced'
					 WHEN  #un_invoiced_receipts_workorders1.billing_status_code = 'I' AND IsNull (#un_invoiced_receipts_workorders1.invoice_code, 'I') = 'I' THEN 'Invoiced'
					 WHEN  #un_invoiced_receipts_workorders1.billing_status_code = 'S' AND IsNull (#un_invoiced_receipts_workorders1.invoice_code, 'S') = 'S' THEN 'Submitted-Not Invoiced'
					 WHEN #un_invoiced_receipts_workorders1.billing_status_code = 'V' AND IsNull (#un_invoiced_receipts_workorders1.invoice_code, 'V') = 'V' THEN 'Voided-Not Invoiced'
				   END ,
				   #un_invoiced_receipts_workorders1.generator_id,
				   #un_invoiced_receipts_workorders1.generator_name,
				   #un_invoiced_receipts_workorders1.epa_id,
				   #un_invoiced_receipts_workorders1.ticket_number
				   FROM #un_invoiced_receipts_workorders1
				   WHERE #un_invoiced_receipts_workorders1.note_id = ( SELECT max(n.note_id)
								FROM Note n
								WHERE n.note_source in ('Workorder', 'Receipt','')
							   AND n.note_type <> 'AUDIT'
							   AND n.company_id = #un_invoiced_receipts_workorders1.company_id
							   AND n.profit_ctr_id = #un_invoiced_receipts_workorders1.profit_ctr_id
							   AND ( n.workorder_id = #un_invoiced_receipts_workorders1.receipt_id OR n.Receipt_id = #un_invoiced_receipts_workorders1.receipt_id  ) )
				   ORDER BY
	   #un_invoiced_receipts_workorders1.company_id
	,   #un_invoiced_receipts_workorders1.profit_ctr_id
	,   #un_invoiced_receipts_workorders1.receipt_id 
	*/

	-- #64582 - Modified to use #Note instead of Note Table
	SELECT  #un_invoiced_receipts_workorders.cust_name,
			#un_invoiced_receipts_workorders.customer_ID,           
			#un_invoiced_receipts_workorders.customer_service_Rep,
			#un_invoiced_receipts_workorders.receipt_id  ,
			#un_invoiced_receipts_workorders.trans_date,
			#un_invoiced_receipts_workorders.trans_status,
			#un_invoiced_receipts_workorders.billing_status_code,
			#un_invoiced_receipts_workorders.company_id,
			#un_invoiced_receipts_workorders.profit_ctr_id,           
			#un_invoiced_receipts_workorders.company_name,
			#un_invoiced_receipts_workorders.note_id,
			#un_invoiced_receipts_workorders.note_date,
			#un_invoiced_receipts_workorders.note,
			#un_invoiced_receipts_workorders.trans_source,
			#un_invoiced_receipts_workorders.note_subject,
			#un_invoiced_receipts_workorders.submitted_flag,
			#un_invoiced_receipts_workorders.invoice_code,
			#un_invoiced_receipts_workorders.invoice_id,
			#un_invoiced_receipts_workorders.waste_accepted_flag,
			Case	WHEN #un_invoiced_receipts_workorders.submitted_flag = 'T' THEN 'Submitted'
					WHEN #un_invoiced_receipts_workorders.trans_status = 'N' OR ISNULL(#un_invoiced_receipts_workorders.trans_status,'N') = 'N' THEN 'New'
					WHEN #un_invoiced_receipts_workorders.trans_status = 'M'THEN 'Manual'
					WHEN #un_invoiced_receipts_workorders.trans_status = 'H'THEN 'Hold'
					WHEN #un_invoiced_receipts_workorders.trans_status = 'L' THEN 'In the Lab'
					WHEN #un_invoiced_receipts_workorders.trans_status = 'U' AND  #un_invoiced_receipts_workorders.waste_accepted_flag  = 'T'THEN 'Waste Accepted' --ELSE 'Unloading'
					WHEN #un_invoiced_receipts_workorders.trans_status = 'V'THEN 'Void'
					WHEN #un_invoiced_receipts_workorders.trans_status = 'T'THEN 'In-Transit'
					WHEN #un_invoiced_receipts_workorders.trans_status = 'R'THEN 'Rejected'
					WHEN #un_invoiced_receipts_workorders.trans_status = 'A'THEN 'Accepted' END ,
			CASE	WHEN  #un_invoiced_receipts_workorders.billing_status_code = 'N' AND #un_invoiced_receipts_workorders.invoice_code like 'Preview_%' THEN 'New- Preview Invoice'
					WHEN  #un_invoiced_receipts_workorders.billing_status_code = 'N' AND IsNull (#un_invoiced_receipts_workorders.invoice_code, 'N') = 'N' THEN 'New- Not invoiced'
					WHEN  #un_invoiced_receipts_workorders.billing_status_code = 'H' AND IsNull (#un_invoiced_receipts_workorders.invoice_code, 'H') = 'H' THEN 'On Hold-Not Invoiced'
					WHEN  #un_invoiced_receipts_workorders.billing_status_code = 'I' AND IsNull (#un_invoiced_receipts_workorders.invoice_code, 'I') = 'I' THEN 'Invoiced'
					WHEN  #un_invoiced_receipts_workorders.billing_status_code = 'S' AND IsNull (#un_invoiced_receipts_workorders.invoice_code, 'S') = 'S' THEN 'Submitted-Not Invoiced'
					WHEN #un_invoiced_receipts_workorders.billing_status_code = 'V' AND IsNull (#un_invoiced_receipts_workorders.invoice_code, 'V') = 'V' THEN 'Voided-Not Invoiced' END ,
			#un_invoiced_receipts_workorders.generator_id,
			#un_invoiced_receipts_workorders.generator_name,
			#un_invoiced_receipts_workorders.epa_id,
			#un_invoiced_receipts_workorders.ticket_number
			FROM #un_invoiced_receipts_workorders
			WHERE #un_invoiced_receipts_workorders.note_id = (  SELECT	max(n.note_id)
																FROM	#Note n
																WHERE	n.company_id	= #un_invoiced_receipts_workorders.company_id
																AND		n.profit_ctr_id = #un_invoiced_receipts_workorders.profit_ctr_id
																AND		n.receipt_id	= #un_invoiced_receipts_workorders.receipt_id )
			/*WHERE #un_invoiced_receipts_workorders.note_id = (  SELECT max(n.note_id)
																FROM Note n
																WHERE n.note_source in ('Workorder', 'Receipt','')
																AND n.note_type <> 'AUDIT'
																AND n.company_id = #un_invoiced_receipts_workorders.company_id
																AND n.profit_ctr_id = #un_invoiced_receipts_workorders.profit_ctr_id
																AND ( n.workorder_id = #un_invoiced_receipts_workorders.receipt_id OR n.Receipt_id = #un_invoiced_receipts_workorders.receipt_id))*/
			ORDER BY	#un_invoiced_receipts_workorders.company_id, 
						#un_invoiced_receipts_workorders.profit_ctr_id,
						#un_invoiced_receipts_workorders.receipt_id 

	-- print 'SUCCESS 5'

	drop table #FlashWork
	-- drop table #un_invoiced_receipts_workorders1 -- Commented for #64585
	drop table #un_invoiced_receipts_workorders
	drop table #Note -- #64582 - Added
END -- Dipankar


GO 

GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_open_transactions_with_notes] TO [EQAI];

	GO