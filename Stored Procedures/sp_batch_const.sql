CREATE PROCEDURE sp_batch_const 
	@location		varchar(15), 
	@tracking_num	varchar(MAX),
	@company_id		int, 
	@profit_ctr_id	int,
	@cycle_in		int,
	@debug			int
AS
/****************
This SP retrieves the distinct set of constituents from assigned receipts

Filename:		L:\IT Apps\SQL-Deploy\Prod\NTSQL1\PLT_AI\Procedures\sp_batch_const.sql
PB Object(s):	None
SQL Object(s):	Called from sp_batch_recalc

06/06/2004 SCC	Created
11/16/2004 SCC	Modified for ContainerDestination Tracking. Changed #match_nonbulk to #match_container
12/21/2004 SCC	Replaced Stock formatting with function
04/14/2005 JDB	Added bill_unit_code for TSDFApproval
09/21/2005 SCC	Changed to use no-drill-down method for base containers
12/12/2008 KAM  Updated the SQL to include constituients for items in Stock containers.
01/28/2009 LJT  Removed Distinct from union because it is implied and it was making the queries go to 40sec from 1sec.
09/10/2009 JDB  Added join on container_id between ContainerDestination and ContainerConst.
				Updated to use new join syntax.
11/30/2010 SK	Added @company_id as input arg, added joins to company_id
				Moved to Plt_AI
06/10/2014 JDB	Updated to match the version of the same named SP (sp_batch_const) that is loaded to Plt_XX_AI,
				because we are eliminating those SPs on Plt_XX_AI.				
07/14/2014 SK	Added the missing company_id join			
08/01/2016 AM   Added #tmp_tracking_num temp table and necessary joins.
				
sp_batch_const '702', 'BATCH702', 21, 0, 1, 1
******************/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

IF @debug = 1 print 'called with @location: ' + @location + ' @tracking_num: ' + @tracking_num + ' cycle: ' + Convert(varchar(10), @cycle_in)

	CREATE TABLE #tmp_tracking_num (
		tracking_num		varchar (15)
	)
	INSERT #tmp_tracking_num
	SELECT row
	FROM dbo.fn_SplitXsvText(',', 1, @tracking_num)
	WHERE isnull(row,'') <> ''


-- Get the container constituents assigned to this batch
INSERT #tmp_const (location, tracking_num, cycle, const_id, UHC)
SELECT  @location, 
	#tmp_tracking_num.tracking_num,
	ContainerDestination.cycle, 
	ReceiptConstituent.const_id,
	ReceiptConstituent.UHC
FROM Receipt (NOLOCK)
INNER JOIN ContainerDestination (NOLOCK) ON Receipt.company_id = ContainerDestination.company_id
	AND Receipt.profit_ctr_id = ContainerDestination.profit_ctr_id
	AND Receipt.receipt_id = ContainerDestination.receipt_id
	AND Receipt.line_id = ContainerDestination.line_id
INNER JOIN ReceiptConstituent (NOLOCK) ON ContainerDestination.profit_ctr_id = ReceiptConstituent.profit_ctr_id
	AND ContainerDestination.company_id = ReceiptConstituent.company_id
	AND ContainerDestination.receipt_id = ReceiptConstituent.receipt_id
	AND ContainerDestination.line_id = ReceiptConstituent.line_id
INNER JOIN Constituents (NOLOCK) ON ReceiptConstituent.const_id = Constituents.const_id
	AND Constituents.const_desc <> 'NONE'
INNER JOIN #tmp_tracking_num ON #tmp_tracking_num.tracking_num = ContainerDestination.tracking_num OR 
  #tmp_tracking_num.tracking_num = 'ALL'
WHERE 1=1
AND Receipt.trans_type = 'D'
AND Receipt.trans_mode = 'I'
AND Receipt.receipt_status IN ('N','L','U','A')
AND Receipt.fingerpr_status = 'A'
AND ContainerDestination.status = 'C'
AND ContainerDestination.location = @location
AND (@tracking_num = 'ALL' OR ContainerDestination.tracking_num = #tmp_tracking_num.tracking_num )
AND ContainerDestination.profit_ctr_id = @profit_ctr_id
AND ContainerDestination.company_id = @company_id
AND ContainerDestination.cycle <= @cycle_in
AND ContainerDestination.container_type = 'R'
AND NOT EXISTS (SELECT 1 FROM ContainerConstituent
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
	ContainerConstituent.const_id,
	ContainerConstituent.UHC
FROM ContainerDestination (NOLOCK) 
JOIN ContainerConstituent (NOLOCK) ON ContainerDestination.profit_ctr_id = ContainerConstituent.profit_ctr_id
	AND ContainerDestination.company_id = ContainerConstituent.company_id
	AND ContainerDestination.receipt_id = ContainerConstituent.receipt_id
	AND ContainerDestination.line_id = ContainerConstituent.line_id
	AND ContainerDestination.container_type = ContainerConstituent.container_type
	AND ContainerDestination.container_id = ContainerConstituent.container_id
	AND ContainerDestination.sequence_id = ContainerConstituent.sequence_id
JOIN Constituents (NOLOCK) ON ContainerConstituent.const_id = Constituents.const_id
	AND Constituents.const_desc <> 'NONE'
INNER JOIN #tmp_tracking_num ON #tmp_tracking_num.tracking_num = ContainerDestination.tracking_num OR 
  #tmp_tracking_num.tracking_num = 'ALL'
WHERE ContainerDestination.status = 'C'
AND ContainerDestination.location = @location
AND (@tracking_num = 'ALL' OR ContainerDestination.tracking_num = #tmp_tracking_num.tracking_num )
AND ContainerDestination.profit_ctr_id = @profit_ctr_id
AND ContainerDestination.company_id = @company_id
AND ContainerDestination.cycle <= @cycle_in
--AND ContainerDestination.container_type = 'S'

IF @debug = 1 print 'SELECTING RESULTS'
IF @debug = 1 SELECT DISTINCT @company_id, @profit_ctr_id, @location, @tracking_num, cycle, const_id, UHC FROM #tmp_const

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_batch_const] TO [EQAI]
    AS [dbo];

