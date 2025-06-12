CREATE PROCEDURE sp_update_billing_reference_code 
	@debug		int = 0
AS 
/***************************************************************************************************
LOAD TO PLT_AI

Filename: L:\IT Apps\SourceCode\Control\SQL\Prod\NTSQL1\PLT_AI\sp_update_billing_reference_code.sql
PB Object(s): None

11/21/2014 JDB	Created.  Copied from sp_update_profile_statistics
02/11/2015 JDB	Modified SELECT and UPDATE statements to join directly instead of using a sub-select.
				Also set transaction isolation level to READ UNCOMMITTED.

sp_update_billing_reference_code 1
***************************************************************************************************/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

DECLARE @date_to_check	datetime = '11/20/2014'
        
IF @debug > 0
BEGIN
	-- These are the Billing records that will be updated.
	PRINT 'These are the Billing records that will be updated.'
	
	SELECT b.company_id
		, b.profit_ctr_id
		, b.receipt_id
		, billing_reference_code = b.reference_code
		, woh.reference_code
	FROM Billing b (NOLOCK)
	JOIN WorkOrderHeader woh (NOLOCK) ON woh.company_id = b.company_id
		AND woh.profit_ctr_id = b.profit_ctr_id 
		AND woh.workorder_id = b.receipt_id 
		AND woh.date_modified > @date_to_check
		AND ISNULL(woh.reference_code, '') <> ISNULL(b.reference_code, '')
	WHERE 1=1
	AND b.trans_source = 'W' 
END


UPDATE Billing 
SET reference_code = ISNULL(woh.reference_code, '')
FROM Billing b
JOIN WorkOrderHeader woh ON woh.company_id = b.company_id
	AND woh.profit_ctr_id = b.profit_ctr_id 
	AND woh.workorder_id = b.receipt_id 
	AND woh.date_modified > @date_to_check
	AND ISNULL(woh.reference_code, '') <> ISNULL(b.reference_code, '')
WHERE 1=1
AND b.trans_source = 'W' 

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_update_billing_reference_code] TO [EQAI]
    AS [dbo];

