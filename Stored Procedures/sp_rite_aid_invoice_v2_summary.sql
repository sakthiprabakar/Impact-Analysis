CREATE PROCEDURE sp_rite_aid_invoice_v2_summary (
	  @customer_id			int
	, @invoice_code_from	varchar(16)
	, @invoice_code_to		varchar(16)
	, @invoice_date_from	datetime
	, @invoice_date_to		datetime
)
AS
/*************************************************************************************************
Loads to : PLT_AI

09/07/2012 JDB	Created.  This SP returns data specifically designed for Rite Aid, with Stop Fees
				that include a certain amount of disposal in their pricing.
01/21/2013 JPB	Added #RCB table & population to handle effective-date logic for ResourceClassBundle

01/21/2013 JPB	Copied this to sp_rite_aid_invoice_v2_summary from sp_rite_aid_invoice
				Determined during the build for their new invoice that you just could. not. use.
				the existing sp because it returned the summary rows in the same recordset as the
				detail rows and you couldn't summarize just the detail parts because they were all
				lumped together. argh.
				
				So here we are.
				
02/14/2013 JPB	Bugfix: Summary should be reading from matching detail sp
07/08/2024 KS	Rally116985 - Modified service_desc_1 datatype to VARCHAR(100) for #tmpSummary table.

SELECT * FROM invoiceheader where customer_id = 14231 order by invoice_date desc
SELECT * FROM customer where cust_name like 'rite%aid%'

EXECUTE sp_rite_aid_invoice_v2_summary 14231, '40426421', '40426425', '1/1/12', '12/31/13'
EXECUTE sp_rite_aid_invoice_v2_summary 14231, '40439520', '40439520', '9/10/12', '9/11/13'

--EXECUTE sp_rite_aid_invoice_v2_summary 14232, '40402256', '40402256', '9/10/12', '9/11/12'
--EXECUTE sp_rite_aid_invoice_v2_summary 14232, '40402257', '40402257', '9/10/12', '9/11/12'
--EXECUTE sp_rite_aid_invoice_v2_summary 14232, '40402258', '40402258', '9/10/12', '9/11/12'
--EXECUTE sp_rite_aid_invoice_v2_summary 14232, '40402260', '40402260', '9/10/12', '9/11/12'

SELECT * FROM ResourceClassBundle

--SELECT * FROM WorkOrderDetail WHERE resource_class_code IN ('STOPFEECT','STOPFEECTP','STOPFEEMA','STOPFEEMAP','STOPFEEVT','STOPFEEVTP','STOPFEEMI','STOPFEEMIP','STOPFEEOH','STOPFEEOHP','STOPFEENJ','STOPFEENJP')
*************************************************************************************************/

CREATE TABLE #tmpSummary (
	invoice_id					int
	, revision_id				int
	, invoice_code				varchar(16)
	, invoice_date				datetime
	, due_date					datetime
	, remit_to					varchar(100)
	, phone_customer_service	varchar(14)
	, customer_id				int
	, cust_name					varchar(40)
	, addr1						varchar(40)
	, addr2						varchar(40)
	, addr3						varchar(40)
	, addr4						varchar(40)
	, addr5						varchar(40)
	, attention_name			varchar(40)
	, customer_po				varchar(20)
	, customer_release			varchar(20)
	, invoice_sequence			int
	, generator_id				int
	, EPA_ID					varchar(12)
	, generator_name			varchar(40)
	, generator_site_code		varchar(16)
	, generator_city			varchar(40)
	, generator_state			varchar(2)
	, billing_date				datetime
	, company_id				int
	, profit_ctr_id				int
	, company_name				varchar(35)
	, trans_source				char(1)
	, receipt_id				int
	, line_id					int
	, quantity					float
	, resource_class_code		varchar(15)
	, resource_description		varchar(100)
	, resource_unit_price		money
	, rx_overage				money
	, front_end_overage			money
	, rx_pounds					float
	, front_end_pounds			float
	, service_desc_1			varchar(100)
	, special_stop_fee			int
	, actual_extended_amt		money
	, stop_fee_from_quote		money
	, special_invoice_amt		money
	, diff						money
	, validation_message		varchar(255)
	)

insert #tmpSummary 
EXECUTE sp_rite_aid_invoice_v2_detail @customer_id, @invoice_code_from, @invoice_code_to, @invoice_date_from, @invoice_date_to

select
	invoice_id				
	, revision_id			
	, invoice_code			
	, invoice_date			
	, due_date				
	, remit_to				
	, phone_customer_service
	, customer_id			
	, cust_name				
	, addr1					
	, addr2					
	, addr3					
	, addr4					
	, addr5					
	, attention_name		
	, customer_po			
	, customer_release		
	, 1 as invoice_sequence		
	, NULL as generator_id			
	, NULL as EPA_ID				
	, NULL as generator_name		
	, NULL as generator_site_code	
	, NULL as generator_city		
	, NULL as generator_state		
	, NULL as billing_date			
	, NULL as company_id			
	, NULL as profit_ctr_id			
	, NULL as company_name			
	, NULL as trans_source			
	, NULL as receipt_id			
	, NULL as line_id				
	, NULL as quantity				
	, NULL as resource_class_code	
	, NULL as resource_description	
	, NULL as resource_unit_price	
	, NULL as rx_overage			
	, NULL as front_end_overage		
	, NULL as rx_pounds				
	, NULL as front_end_pounds		
	, convert(varchar(60), 'Invoice SubTotal') as service_desc_1
	, NULL as special_stop_fee		
	, NULL as actual_extended_amt	
	, NULL as stop_fee_from_quote	
	, SUM(special_invoice_amt) as special_invoice_amt
	, NULL as diff					
	, NULL as validation_message	
INTO #tmpSummaryOutput
FROM #tmpSummary
WHERE 
	service_desc_1 NOT LIKE '%Sales Tax'
GROUP BY
	invoice_id				
	, revision_id			
	, invoice_code			
	, invoice_date			
	, due_date				
	, remit_to				
	, phone_customer_service
	, customer_id			
	, cust_name				
	, addr1					
	, addr2					
	, addr3					
	, addr4					
	, addr5					
	, attention_name		
	, customer_po			
	, customer_release		

INSERT #tmpSummaryOutput
select
	invoice_id				
	, revision_id			
	, invoice_code			
	, invoice_date			
	, due_date				
	, remit_to				
	, phone_customer_service
	, customer_id			
	, cust_name				
	, addr1					
	, addr2					
	, addr3					
	, addr4					
	, addr5					
	, attention_name		
	, customer_po			
	, customer_release		
	, 2 as invoice_sequence		
	, NULL as generator_id			
	, NULL as EPA_ID				
	, NULL as generator_name		
	, NULL as generator_site_code	
	, NULL as generator_city		
	, NULL as generator_state		
	, NULL as billing_date			
	, NULL as company_id			
	, NULL as profit_ctr_id			
	, NULL as company_name			
	, NULL as trans_source			
	, NULL as receipt_id			
	, NULL as line_id				
	, NULL as quantity				
	, NULL as resource_class_code	
	, NULL as resource_description	
	, NULL as resource_unit_price	
	, NULL as rx_overage			
	, NULL as front_end_overage		
	, NULL as rx_pounds				
	, NULL as front_end_pounds		
	, service_desc_1
	, NULL as special_stop_fee		
	, NULL as actual_extended_amt	
	, NULL as stop_fee_from_quote	
	, SUM(special_invoice_amt)
	, NULL as diff					
	, NULL as validation_message	
FROM #tmpSummary
WHERE 
	service_desc_1 LIKE '%Sales Tax'
GROUP BY
	invoice_id				
	, revision_id			
	, invoice_code			
	, invoice_date			
	, due_date				
	, remit_to				
	, phone_customer_service
	, customer_id			
	, cust_name				
	, addr1					
	, addr2					
	, addr3					
	, addr4					
	, addr5					
	, attention_name		
	, customer_po			
	, customer_release		
	, service_desc_1

INSERT #tmpSummaryOutput
select
	invoice_id				
	, revision_id			
	, invoice_code			
	, invoice_date			
	, due_date				
	, remit_to				
	, phone_customer_service
	, customer_id			
	, cust_name				
	, addr1					
	, addr2					
	, addr3					
	, addr4					
	, addr5					
	, attention_name		
	, customer_po			
	, customer_release		
	, 3 as invoice_sequence		
	, NULL as generator_id			
	, NULL as EPA_ID				
	, NULL as generator_name		
	, NULL as generator_site_code	
	, NULL as generator_city		
	, NULL as generator_state		
	, NULL as billing_date			
	, NULL as company_id			
	, NULL as profit_ctr_id			
	, NULL as company_name			
	, NULL as trans_source			
	, NULL as receipt_id			
	, NULL as line_id				
	, NULL as quantity				
	, NULL as resource_class_code	
	, NULL as resource_description	
	, NULL as resource_unit_price	
	, NULL as rx_overage			
	, NULL as front_end_overage		
	, NULL as rx_pounds				
	, NULL as front_end_pounds		
	, 'Invoice Total' as service_desc_1
	, NULL as special_stop_fee		
	, NULL as actual_extended_amt	
	, NULL as stop_fee_from_quote	
	, SUM(special_invoice_amt)
	, NULL as diff					
	, NULL as validation_message	
FROM #tmpSummaryOutput
GROUP BY
	invoice_id				
	, revision_id			
	, invoice_code			
	, invoice_date			
	, due_date				
	, remit_to				
	, phone_customer_service
	, customer_id			
	, cust_name				
	, addr1					
	, addr2					
	, addr3					
	, addr4					
	, addr5					
	, attention_name		
	, customer_po			
	, customer_release		

SELECT * FROM #tmpSummaryOutput
ORDER BY invoice_id, invoice_sequence


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rite_aid_invoice_v2_summary] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rite_aid_invoice_v2_summary] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rite_aid_invoice_v2_summary] TO [EQAI]
    AS [dbo];

