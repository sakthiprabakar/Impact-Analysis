CREATE PROCEDURE sp_container_match_waste_consolidated 
	@base_container varchar(15), 
	@base_container_id int, 
	@profit_ctr_id int, 
	@debug int,
	@company_id int
AS
/****************
This SP returns a list of receipt waste codes assigned to consolidated containers.  It is
called recursively until there are no more consolidated containers

Filename:	L:\Apps\SQL\EQAI\sp_container_match_waste_consolidated.sql
PB Object(s):	None
SQL Object(s):	Called from sp_container_entry_waste_codes
		Called from sp_stock_container_waste_codes
		Called from sp_work_report
		Calls sp_container_match_waste_consolidated (itself)

12/19/2003 SCC	Created
12/16/2004 SCC	Changed for Container Tracking
04/14/2005 JDB	Added bill_unit_code for TSDFApproval
08/27/2013 RWB	Added waste_code_uid and display_name to #waste results
07/02/2014 SM 	Moved to plt_ai
07/02/2014 SM added company_id

sp_container_match_waste_consolidated 'DL-00-000125', 125, 0, 1
******************/

DECLARE	@waste_code_count int

IF @debug = 1 print 'called with @base_container: ' + ISNULL(@base_container, 'NONE')

-- Get the waste codes assigned to containers consolidated into the base
SELECT DISTINCT
ContainerWasteCode.waste_code,
CASE WHEN ContainerDestination.container_type = 'S'
     THEN dbo.fn_container_stock(ContainerDestination.line_id, ContainerDestination.company_id,@profit_ctr_id)
     ELSE CONVERT(VARCHAR(15), ContainerDestination.receipt_id) + '-' + CONVERT(VARCHAR(15), ContainerDestination.line_id)
     END AS consolidation_tracking_num,
ContainerDestination.container_id AS consolidation_container_id,
ContainerDestination.sequence_id AS consolidation_sequence_id,
0 AS process_flag,
ContainerWasteCode.waste_code_uid,
WasteCode.display_name
INTO #consolidation_waste_codes
FROM ContainerWasteCode, ContainerDestination, WasteCode
WHERE ContainerWasteCode.receipt_id = ContainerDestination.receipt_id
AND ContainerWasteCode.line_id = ContainerDestination.line_id
AND ContainerWasteCode.container_id = ContainerDestination.container_id
AND ContainerWasteCode.sequence_id = ContainerDestination.sequence_id
AND ContainerWasteCode.container_type = ContainerDestination.container_type
AND ContainerWasteCode.profit_ctr_id = ContainerDestination.profit_ctr_id
AND ContainerWasteCode.company_id = ContainerDestination.company_id
AND ContainerWasteCode.waste_code_uid = WasteCode.waste_code_uid
AND ContainerDestination.base_tracking_num = @base_container 
AND (@base_container_id = 0 OR ContainerDestination.base_container_id = @base_container_id )

SET @waste_code_count = @@ROWCOUNT
IF @debug = 1 print 'waste_code_count = ' + CONVERT(varchar(10), @waste_code_count)
IF @debug = 1 print 'selecting from #consolidation_waste_codes'
IF @debug = 1 SELECT * FROM #consolidation_waste_codes

-- Store the waste codes in the parent table
IF @waste_code_count > 0
INSERT #waste (waste_code, container, container_id, sequence_id, waste_code_uid, display_name)
SELECT DISTINCT waste_code, consolidation_tracking_num, consolidation_container_id, consolidation_sequence_id, waste_code_uid, display_name
FROM #consolidation_waste_codes

-- Process each of these containers to see if they, too, were consolidations
WHILE @waste_code_count > 0
BEGIN
	-- Get a container
	SET ROWCOUNT 1
	SELECT @base_container = consolidation_tracking_num,
	       @base_container_id = consolidation_container_id
	FROM #consolidation_waste_codes WHERE process_flag = 0
	IF @debug = 1 print 'next @base_container: ' + ISNULL(@base_container, 'NONE')
	SET ROWCOUNT 0

	-- Now get the waste codes for containers consolidated into this container
	EXEC sp_container_match_waste_consolidated @base_container, @base_container_id, @profit_ctr_id, @debug

	-- Update the process flag
	SET ROWCOUNT 1
	UPDATE #consolidation_waste_codes SET process_flag = 1 WHERE process_flag = 0
	SET @waste_code_count = @waste_code_count - 1
	SET ROWCOUNT 0
	IF @debug = 1 print 'Bottom of Consolidation Loop. @waste_code_count: ' + convert(varchar(10), @waste_code_count)
END 

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_container_match_waste_consolidated] TO [EQAI]
    AS [dbo];

