CREATE PROCEDURE [dbo].[sp_rpt_batch_by_disposal_service_ob] 
	@company_id				int
,	@profit_ctr_id			int
,	@batch_location			varchar(15)
,	@batch_tracking_num		varchar(15)
,	@batch_cycle			int
AS
/*****************************************************************************
Filename:		L:\IT Apps\SQL-Deploy\Prod\NTSQL1\PLT_AI\Procedures\sp_rpt_batch_by_disposal_service_ob
PB Object(s):	r_batch_by_disposal_service_ob

This stored procedure is used on a nested datawindow for th Batch Information by Disposal Service Report.
It will take a batch as an input, and display any/all outbound receipts that are using the batch.

SELECT * FROM Receipt WHERE trans_mode = 'O'

07/23/2014 JDB	Created

sp_rpt_batch_by_disposal_service_ob 2, 0, 'A', '36523', 1
*****************************************************************************/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

SELECT ob.company_id
	, ob.profit_ctr_id
	, ob.location
	, ob.tracking_num
	, ob.cycle
	, ob.receipt_id AS ob_receipt_id
	, ob.line_id AS ob_line_id
	, ob.receipt_date AS ob_receipt_date
	, CASE ob.manifest_flag 
		WHEN 'M' THEN 'Manifest' 
		WHEN 'B' THEN 'BOL' 
		WHEN 'C' THEN 'Commingled'
		WHEN 'X' THEN 'Transfer'
		END AS manifest_type
	, ob.manifest
	, ob.quantity AS ob_quantity
	, ob.bill_unit_code AS ob_bill_unit_code
--INTO #tmp
FROM Receipt ob (NOLOCK) 
WHERE 1=1
AND ob.company_id = @company_id
AND ob.profit_ctr_id = @profit_ctr_id
AND ob.location = @batch_location
AND ob.tracking_num = @batch_tracking_num
AND ob.cycle = @batch_cycle

--DROP TABLE #tmp

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_batch_by_disposal_service_ob] TO [EQAI]
    AS [dbo];

