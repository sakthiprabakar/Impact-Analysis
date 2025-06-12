CREATE PROCEDURE sp_batch_waste 
	@location		varchar(15), 
	@tracking_num	varchar(MAX), 
	@company_id		int,
	@profit_ctr_id	int,
	@cycle_in		int,
	@debug			int
AS
/****************
This SP retrieves the distinct set of waste codes from assigned receipts and transfers

Filename:		L:\IT Apps\SQL-Deploy\Prod\NTSQL1\PLT_AI\Procedures\sp_batch_waste.sql
PB Object(s):	None
SQL Object(s):	Called from sp_batch_recalc

06/06/2004 SCC	Created
11/16/2004 SCC	Modified for Container Tracking. Changed #match_nonbulk to #match_container
12/21/2004 SCC	Replaced Stock formatting with function
03/23/2005 MK	Modified to omit non-closed containers
04/14/2005 JDB	Added bill_unit_code for TSDFApproval
09/21/2005 SCC	Changed to use no-drill-down method for base containers
12/12/2008 KAM  Updated the SQL to include Stock container waste codes
01/28/2009 LJT  Removed Distinct from union because it is implied and it was making the queries go to 40sec from 1sec.
09/10/2009 JDB  Added join on container_id between ContainerDestination and ContainerWaste.
				Updated to use new join syntax.
11/30/2010 SK	Added @company_id as input arg, used ContainerWasteCode instead of ContainerWaste table
				moved to Plt_AI
04/25/2013 RB Added waste_code_uid for Waste Code conversion
06/10/2014 JDB	Updated to match the version of the same named SP (sp_batch_waste) that is loaded to Plt_XX_AI,
				because we are eliminating those SPs on Plt_XX_AI.	
07/14/2014 SK	Added the missing company_id join	
08/01/2016 AM   Added #tmp_tracking_num temp table and necessary joins.		

exec sp_batch_waste '701', '12417', 21, 0, 1, 1
******************/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

IF @debug = 1 print 'called with @location: ' + @location + ' @tracking_num: ' + @tracking_num + ' cycle: ' + CONVERT(varchar(10), @cycle_in)

-- Anitha 
	CREATE TABLE #tmp_tracking_num (
		tracking_num		varchar (15)
	)
	INSERT #tmp_tracking_num
	SELECT row
	from dbo.fn_SplitXsvText(',', 1, @tracking_num)
	WHERE isnull(row,'') <> ''
-- Anitha END

-- Get the container waste codes assigned to this batch
INSERT #tmp_waste (location, tracking_num, cycle, waste_code_uid, waste_code)
SELECT  @location, 
	#tmp_tracking_num.tracking_num,
	ContainerDestination.cycle, 
	ReceiptWasteCode.waste_code_uid,
	ReceiptWasteCode.waste_code
FROM Receipt (NOLOCK)
INNER JOIN ContainerDestination (NOLOCK) ON Receipt.company_id = ContainerDestination.company_id
	AND Receipt.profit_ctr_id = ContainerDestination.profit_ctr_id
	AND Receipt.receipt_id = ContainerDestination.receipt_id
	AND Receipt.line_id = ContainerDestination.line_id
INNER JOIN ReceiptWasteCode (NOLOCK) ON ContainerDestination.profit_ctr_id = ReceiptWasteCode.profit_ctr_id
	AND ContainerDestination.company_id = ReceiptWasteCode.company_id
	AND ContainerDestination.receipt_id = ReceiptWasteCode.receipt_id
	AND ContainerDestination.line_id = ReceiptWasteCode.line_id
INNER JOIN WasteCode (NOLOCK) ON ReceiptWasteCode.waste_code_uid = WasteCode.waste_code_uid
	AND WasteCode.display_name <> 'NONE'
JOIN #tmp_tracking_num ON #tmp_tracking_num.tracking_num = ContainerDestination.tracking_num OR
	 #tmp_tracking_num.tracking_num = 'ALL'
WHERE 1=1
AND Receipt.trans_type = 'D'
AND Receipt.trans_mode = 'I'
AND Receipt.receipt_status IN ('N','L','U','A')
AND Receipt.fingerpr_status = 'A'
AND ContainerDestination.status = 'C'
AND ContainerDestination.location = @location
AND ContainerDestination.tracking_num = #tmp_tracking_num.tracking_num 
AND (@tracking_num = 'ALL' OR ContainerDestination.tracking_num = #tmp_tracking_num.tracking_num  )
AND ContainerDestination.profit_ctr_id = @profit_ctr_id
AND ContainerDestination.company_id = @company_id
AND ContainerDestination.cycle <= @cycle_in
AND ContainerDestination.container_type = 'R'
AND NOT EXISTS (SELECT 1 FROM ContainerWasteCode
				WHERE company_id = ContainerDestination.company_id
				AND profit_ctr_id = ContainerDestination.profit_ctr_id
				AND container_type = ContainerDestination.container_type
				AND receipt_id = ContainerDestination.receipt_id
				AND line_id = ContainerDestination.line_id
				AND container_id = ContainerDestination.container_id
				AND sequence_id = ContainerDestination.sequence_id)
UNION

SELECT 
	@location, 
	#tmp_tracking_num.tracking_num,
	ContainerDestination.cycle, 
	ContainerWasteCode.waste_code_uid,
	ContainerWasteCode.waste_code
FROM ContainerDestination (NOLOCK)
join ContainerWasteCode (NOLOCK) ON	ContainerDestination.profit_ctr_id = ContainerWasteCode.profit_ctr_id
	AND ContainerDestination.company_id = ContainerWasteCode.company_id
	AND ContainerDestination.receipt_id = ContainerWasteCode.receipt_id
	AND ContainerDestination.line_id = ContainerWasteCode.line_id
	AND ContainerDestination.container_type = ContainerWasteCode.container_type
	AND ContainerDestination.container_id = ContainerWasteCode.container_id 
	AND ContainerDestination.sequence_id = ContainerWasteCode.sequence_id
JOIN WasteCode (NOLOCK)	ON ContainerWasteCode.waste_code_uid = WasteCode.waste_code_uid
	AND WasteCode.display_name <> 'NONE'
INNER JOIN #tmp_tracking_num ON #tmp_tracking_num.tracking_num = ContainerDestination.tracking_num OR
	 #tmp_tracking_num.tracking_num = 'ALL'
WHERE ContainerDestination.status = 'C'
AND ContainerDestination.location = @location
AND (@tracking_num = 'ALL' OR ContainerDestination.tracking_num = #tmp_tracking_num.tracking_num  )
AND ContainerDestination.profit_ctr_id = @profit_ctr_id
AND ContainerDestination.company_id = @company_id
AND ContainerDestination.cycle <= @cycle_in
--AND ContainerDestination.container_type = 'S'

IF @debug = 1 print 'SELECTING RESULTS'
IF @debug = 1 SELECT DISTINCT @company_id, @profit_ctr_id, @location, @tracking_num, cycle, waste_code FROM #tmp_waste

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_batch_waste] TO [EQAI]
    AS [dbo];

