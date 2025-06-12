CREATE PROCEDURE sp_base_rate_quote 
	@company_id		int
AS
/****************
This SP runs for the Report-  Base Rate Quote

PB Object(s):	r_base_quote_detail

12/07/2010 SK Created on Plt_AI

exec sp_base_rate_quote 21
******************/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

  
SELECT DISTINCT 
	BaseQuotePrintCategory.description
,	WorkorderQuoteDetail.resource_item_code
,	WorkorderQuoteDetail.resource_type
,	WorkorderQuoteDetail.bill_unit_code
,	WorkorderQuoteDetail.price
,	WorkorderQuoteDetail.price_OT
,	WorkorderQuoteDetail.price_DT
,	ResourceClass.description
,	BaseQuotePrintCategory.record_id
,	BaseQuotePrintCategory.sort_id
,	WorkorderQuoteDetail.quote_id
FROM WorkorderQuoteDetail 
INNER JOIN ResourceClass 
	ON ResourceClass.bill_unit_code = WorkorderQuoteDetail.bill_unit_code 
    AND ResourceClass.resource_class_code  = WorkorderQuoteDetail.resource_item_code
    AND ResourceClass.company_id = WorkorderQuoteDetail.company_id
    AND ResourceClass.base_quote_print_flag = 'T' 
INNER JOIN WorkorderQuoteHeader
	ON WorkorderQuoteHeader.quote_id = WorkorderQuoteDetail.quote_id
    AND WorkorderQuoteHeader.company_id = WorkorderQuoteDetail.company_id
    AND WorkorderQuoteHeader.quote_type = 'B'
INNER JOIN BaseQuotePrintCategory 
	ON BaseQuotePrintCategory.record_id = ResourceClass.base_quote_print_category
WHERE WorkorderQuoteDetail.company_id = @company_id
	AND WorkorderQuoteDetail.group_code = '' 
	
UNION

SELECT DISTINCT 
	BaseQuotePrintCategory.description
,	WorkorderQuoteDetail.resource_item_code
,	WorkorderQuoteDetail.resource_type
,	WorkorderQuoteDetail.bill_unit_code
,	WorkorderQuoteDetail.price
,	WorkorderQuoteDetail.price_OT
,	WorkorderQuoteDetail.price_DT
,	ResourceGroup.description
,	BaseQuotePrintCategory.record_id
,	BaseQuotePrintCategory.sort_id
,	WorkorderQuoteDetail.quote_id
FROM WorkorderQuoteDetail
INNER JOIN ResourceGroup
	ON ResourceGroup.resource_group_code = WorkorderQuoteDetail.group_code
	AND ResourceGroup.company_id = WorkorderQuoteDetail.company_id
    AND WorkorderQuoteDetail.resource_type = 'G'
    AND ResourceGroup.base_quote_print_flag = 'T' 
	AND ResourceGroup.sequence_id = 0 
INNER JOIN WorkorderQuoteHeader
	ON WorkorderQuoteHeader.quote_id = WorkorderQuoteDetail.quote_id
    AND WorkorderQuoteHeader.company_id = WorkorderQuoteDetail.company_id 
    AND WorkorderQuoteHeader.quote_type = 'B'
INNER JOIN BaseQuotePrintCategory 
	ON BaseQuotePrintCategory.record_id = ResourceGroup.base_quote_print_category
WHERE WorkorderQuoteDetail.company_id = @company_id

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_base_rate_quote] TO [EQAI]
    AS [dbo];

