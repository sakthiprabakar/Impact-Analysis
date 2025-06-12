CREATE PROCEDURE sp_rpt_invoice_summary (
	  @customer_id			int
	, @invoice_code_from	varchar(16)
	, @invoice_code_to		varchar(16)
	, @invoice_date_from	datetime
	, @invoice_date_to		datetime
)
AS
/*************************************************************************************************
Loads to : PLT_AI

06/03/2015 SK	Created.  This SP returns data currently requested for the Kroger Invoice format with Stop Fees
				that include a certain amount of disposal in their pricing. Forward looking this would be 
				generic for all retail customers
06/16/2015 SK	version 2 : Added Remit to Address 1 and Address 2 fields for the payable information				
06/23/2015 AM   Added dba_name logic to get multiple company names for given invoice and revision id. 
07/15/2015 AM   Added generator_region_code field from generator for given invoice and revision id.
07/20/2015 AM   Added max service date for each invoice 
SELECT * FROM invoiceheader where customer_id = 15940 order by invoice_date desc
SELECT * FROM customer where cust_name like 'kroger%'

EXECUTE sp_rpt_invoice_summary 15940, '144588', '144590', NULL, NULL
*************************************************************************************************/
set transaction isolation level read uncommitted

CREATE TABLE #companies (
	company_id	int		NULL,
	co_name		varchar(50)	NULL 	)

DECLARE @companies	varchar(4000),
        @co_name	varchar(50),
        @cnt		int,
        @last		int,
	    @company_cnt	int,
	    @max_service_date datetime,
	    @invoice_id int
	    
CREATE TABLE #InvoiceSummary (
	invoice_id					int
	, revision_id				int
	, invoice_code				varchar(16)
	, invoice_date				datetime
	, due_date					datetime
	, remit_to					varchar(100)
	, address_1					varchar(100)
	, address_2					varchar(100)
	, phone_customer_service	varchar(14)
	, customer_id				int
	, cust_name					varchar(40)
	, attention_name			varchar(40)
	, customer_po				varchar(20)
	, customer_release			varchar(20)
	, addr1						varchar(40)
	, addr2						varchar(40)
	, addr3						varchar(40)
	, addr4						varchar(40)
	, addr5						varchar(40)
	, city						varchar(40)
	, state						varchar(2)
	, zip_code					varchar(15)
	, attention_phone			varchar(30)
	, subtotal_amt				money
	, total_amt_sales_tax		money
	, total_amt_due				money
	, dba_name				    varchar(4000)
	, generator_region_code		varchar(40)
	, service_date			    datetime
	)
	
INSERT INTO #InvoiceSummary
SELECT
	invoice_id				
	, revision_id			
	, invoice_code			
	, invoice_date			
	, due_date				
	, Company.remit_to	
	, Company.address_1
	, Company.address_2			
	, Company.phone_customer_service
	, customer_id			
	, cust_name	
	, attention_name	
	, customer_po
	, customer_release			
	, addr1					
	, addr2					
	, addr3					
	, addr4					
	, addr5	
	, city
	, state
	, zip_code				
	, attention_phone	
	, subtotal_amt = total_amt_due - total_amt_sales_tax
	, total_amt_sales_tax
	, total_amt_due	
	, '' as dba_name
	, '' as generator_region_code
	, null as service_date
FROM InvoiceHeader IH
JOIN Company ON Company.company_id = 1
WHERE IH.customer_id = @customer_id
AND ((@invoice_code_from IS NULL AND @invoice_code_to IS NULL) OR IH.invoice_code BETWEEN @invoice_code_from AND @invoice_code_to)
AND ((@invoice_date_from IS NULL AND @invoice_date_to IS NULL) OR IH.invoice_date BETWEEN @invoice_date_from AND @invoice_date_to)
AND IH.status = 'I'
ORDER BY invoice_id, revision_id
--COMPUTE SUM(total_amt_due)

INSERT INTO #companies 
SELECT DISTINCT InvoiceDetail.company_id, Company.dba_name 
FROM #InvoiceSummary 
INNER JOIN InvoiceDetail 
        ON InvoiceDetail.invoice_id = #InvoiceSummary.invoice_id 
        AND InvoiceDetail.revision_id = #InvoiceSummary.revision_id  
INNER JOIN Company ON InvoiceDetail.company_id = Company.company_id 

SELECT @company_cnt = COUNT(*) FROM #companies

DECLARE invoice_comapny_name CURSOR FOR SELECT co_name FROM #companies
OPEN invoice_comapny_name

FETCH invoice_comapny_name INTO @co_name 
SELECT @cnt = 0
WHILE @@FETCH_STATUS = 0
BEGIN
	SELECT @cnt = @cnt + 1
	IF @cnt = 1 
	BEGIN 
		SELECT @companies = @co_name
	END
	ELSE
	BEGIN
		SELECT @companies = @companies + '; ' + @co_name
	END 
	FETCH invoice_comapny_name INTO @co_name
END

CLOSE invoice_comapny_name
DEALLOCATE invoice_comapny_name

-- update generator region code
update #InvoiceSummary
set generator_region_code = g.generator_region_code
from #InvoiceSummary
INNER JOIN Invoicedetail id
	ON id.invoice_id = #InvoiceSummary.invoice_id  
	AND id.revision_id = #InvoiceSummary.revision_id
INNER JOIN Generator G
	ON G.generator_id = id.generator_id
	
-- update service date for each invoice
DECLARE cur_invoice_id CURSOR FOR SELECT invoice_id FROM #InvoiceSummary
OPEN cur_invoice_id

FETCH cur_invoice_id into @invoice_id  

WHILE @@FETCH_STATUS = 0
BEGIN

SELECT @max_service_date = max ( Coalesce( WOS.date_act_arrive , wh.start_date)  ) 
FROM  WorkOrderStop WOS
JOIN WorkorderHeader wh 
   ON wh.workorder_id = WOS.workorder_id
   AND WOS.company_id = wh.company_id
   AND WOS.profit_ctr_id = wh.profit_ctr_id 
JOIN Billing B
   ON b.receipt_id = wh.workorder_id
   AND b.company_id = wh.company_id
   AND b.profit_ctr_id = wh.profit_ctr_id
   AND b.trans_source = 'W' 
   AND b.invoice_id = @invoice_id
   
   UPDATE #InvoiceSummary
   SET Service_date = @max_service_date
   WHERE #InvoiceSummary.invoice_id = @invoice_id
 
FETCH cur_invoice_id INTO @invoice_id
END

CLOSE cur_invoice_id
DEALLOCATE cur_invoice_id
  	
IF @cnt > 1 
BEGIN 
      SELECT @companies = REVERSE(@companies)
      SELECT @last =  CHARINDEX(';',@companies,1)
      SELECT @companies = STUFF(@companies,@last,1,REVERSE(' and'))
      SELECT @companies = REVERSE(@companies)
END

--update #InvoiceSummary
--set #InvoiceSummary.dba_name = @companies

SELECT
	invoice_id				
	, revision_id			
	, invoice_code			
	, invoice_date			
	, due_date				
	, remit_to	
	, address_1
	, address_2			
	, phone_customer_service
	, customer_id			
	, cust_name	
	, attention_name	
	, customer_po
	, customer_release			
	, addr1					
	, addr2					
	, addr3					
	, addr4					
	, addr5	
	, city
	, state
	, zip_code				
	, attention_phone	
	, subtotal_amt = total_amt_due - total_amt_sales_tax
	, total_amt_sales_tax
	, total_amt_due	
	, @companies as dba_name
	, generator_region_code
	, Service_date
FROM #InvoiceSummary
 
--SELECT * FROM #InvoiceSummary
--ORDER BY invoice_id, revision_id


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_invoice_summary] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_invoice_summary] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_invoice_summary] TO [EQAI]
    AS [dbo];

