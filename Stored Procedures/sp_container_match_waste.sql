CREATE PROCEDURE sp_container_match_waste 
	@source_container varchar(15),
	@source_container_id int,
	@source_sequence_id int,
	@profit_ctr_id int,
	@tsdf_code varchar(15),
	@tsdf_approval_code varchar(40),
	@waste_stream varchar(10),
	@tsdf_approval_bill_unit_code varchar(4),
	@select_or_insert_results char(1),
	@debug int,
	@company_id int
AS
/****************
This SP returns a list of container waste codes that do not match the waste code from the specified TSDF approval.

Filename:	L:\Apps\SQL\EQAI\sp_container_match_waste.sql
PB Object(s):	None
SQL Object(s):	Called from sp_batch_waste
		Called from sp_container_waste_outbound
		Called from sp_container_waste_to_base
		Calls sp_container_match_waste_consolidated

12/19/2003 SCC	Created
01/09/2004 SCC	Rewrote to accommodate barcoding, one container at a time and to search drum waste codes.
12/16/2004 SCC	Modified for Container Tracking. Changed #match_nonbulk to #match_container
04/14/2005 JDB	Added bill_unit_code for TSDFApproval
07/17/2006 SCC	Modified for new TSDFApproval tables and Profiles as TSDF approvals
08/27/2013 RWB	Add waste_code_uid and display_name to #waste results
07/02/2014 SM 	Moved to plt_ai
07/02/2014 SM 	Added company_id
05/10/2017 AM - 1.Remove deprecated SQL and replace with appropriate SQL syntax.(*= to LEFT OUTER JOIN etc.). 

sp_container_match_waste '14011301', 5, 0, 'EQRR', 'OIL DRUMS', 'OIL RECLAI', 'S', 1
sp_container_match_waste '14011401', 0, 0, 'EQRR', 'OIL DRUMS', 'OIL RECLAI', 'S', 1
sp_container_match_waste 'DL-00-000125', 125, 1, 0, 'EQRR', 'OIL DRUMS', 'OIL RECLAI', 'S', 1
sp_container_match_waste '30327-1', 2, 1, 0, 'EQRR', 'OIL DRUMS', 'OIL RECLAI', 'dm55','S', 1
******************/

DECLARE	@base_container varchar(15),
	@base_container_id int,
	@waste_code_count int,
	@source_container_type char(1),
	@pos int,
	@source_receipt_id int,
	@source_line_id int,
	@eq_flag char(1),
	@eq_company_id int,
	@eq_profit_ctr_id int,
	@profile_id int

CREATE TABLE #waste_code (
	waste_code varchar(4) NULL,
	waste_code_uid int NULL,
	display_name varchar(10) NULL
)


-- What kind of Source container, Stock drum or Receipt?
IF SUBSTRING(@source_container,1,3) = 'DL-' 
BEGIN
	SET @source_container_type = 'S'
	SET @source_receipt_id = 0
	SET @source_line_id = CONVERT(int, SUBSTRING(@source_container, LEN(@source_container) - 5, 6))
END
ELSE
BEGIN
	SET @source_container_type = 'R'
	SET @pos = CHARINDEX('-', @source_container, 1)
	SET @source_receipt_id = CONVERT(INT, SUBSTRING(@source_container, 1, @pos - 1)) 
	SET @source_line_id = CONVERT(INT, SUBSTRING(@source_container, @pos + 1, LEN(@source_container) - @pos))
END
IF @debug = 1 PRINT 'Source Container type: ' + @source_container_type + ' and Source receipt_id: ' + CONVERT(varchar(15), @source_receipt_id)+ ' and Source line_id: ' + convert(varchar(15), @source_line_id)

-- Find waste codes assigned to this container
SELECT DISTINCT 
ContainerWasteCode.waste_code, 
@source_container AS container,
ContainerDestination.container_id,
ContainerDestination.sequence_id,
ContainerWasteCode.waste_code_uid,
WasteCode.display_name
INTO #waste
FROM ContainerDestination, ContainerWasteCode, WasteCode
WHERE ContainerDestination.receipt_id = @source_receipt_id
AND ContainerDestination.line_id = @source_line_id
AND ContainerDestination.container_type = @source_container_type
AND ContainerDestination.profit_ctr_id = @profit_ctr_id
AND ContainerDestination.company_id = @company_id
AND (@source_container_id = 0 OR ContainerDestination.container_id = @source_container_id)
AND (@source_sequence_id = 0 OR ContainerDestination.sequence_id = @source_sequence_id)
AND ContainerDestination.receipt_id = ContainerWasteCode.receipt_id
AND ContainerDestination.line_id = ContainerWasteCode.line_id
AND ContainerDestination.container_id = ContainerWasteCode.container_id
AND ContainerDestination.sequence_id = ContainerWasteCode.sequence_id
AND ContainerDestination.container_type = ContainerWasteCode.container_type
AND ContainerDestination.profit_ctr_id = ContainerWasteCode.profit_ctr_id
AND ContainerDestination.company_id = ContainerWasteCode.company_id
AND ContainerWasteCode.waste_code_uid = WasteCode.waste_code_uid
AND ContainerWasteCode.waste_code_uid IS NOT NULL

SELECT @waste_code_count = COUNT(*) FROM #waste
IF @debug = 1 print 'Selecting after Container Waste Codes'
IF @debug = 1 SELECT * FROM #waste

-- If there were no assigned waste codes, get the receipt waste codes
INSERT #waste
SELECT 
RWC.waste_code,
@source_container,
ContainerDestination.container_id,
ContainerDestination.sequence_id,
RWC.waste_code_uid,
WC.display_name
FROM ContainerDestination
JOIN Receipt ON ContainerDestination.receipt_id = Receipt.receipt_id
	AND ContainerDestination.line_id = Receipt.line_id
	AND ContainerDestination.profit_ctr_id = Receipt.profit_ctr_id
	AND ContainerDestination.company_id = Receipt.company_id
	AND Receipt.trans_mode = 'I'
	AND Receipt.fingerpr_status = 'A'
LEFT OUTER JOIN ReceiptWasteCode RWC ON Receipt.receipt_id = RWC.receipt_id
	AND RWC.line_id = Receipt.line_id 
	AND RWC.profit_ctr_id = Receipt.profit_ctr_id 
	AND RWC.company_id =Receipt.company_id 
	AND RWC.waste_code_uid IS NOT NULL
LEFT OUTER JOIN WasteCode WC ON RWC.waste_code_uid = WC.waste_code_uid 
WHERE ContainerDestination.receipt_id = @source_receipt_id
AND ContainerDestination.line_id = @source_line_id
AND ContainerDestination.container_type = @source_container_type
AND ContainerDestination.profit_ctr_id = @profit_ctr_id
AND ContainerDestination.company_id = @company_id
AND (@source_container_id = 0 OR ContainerDestination.container_id = @source_container_id)
AND STR(@profit_ctr_id)+'-'+STR(ContainerDestination.receipt_id)+'-'+STR(ContainerDestination.line_id)+'-'+STR(ContainerDestination.container_ID)+'-'+STR(ContainerDestination.sequence_ID) NOT IN
 (SELECT STR(profit_ctr_id)+'-'+STR(receipt_id)+'-'+STR(line_id)+'-'+STR(container_ID)+'-'+STR(sequence_ID) FROM ContainerWasteCode)

SELECT @waste_code_count = COUNT(*) FROM #waste

IF @debug = 1 print 'Selecting after Receipt and RWC'
IF @debug = 1 SELECT * FROM #waste
	
-- If this is a base container (other containers were consolidated into this container)
-- find the waste codes for the consolidated containers
SET @base_container = @source_container
SET @base_container_id = @source_container_id

-- Get consolidation waste codes
IF @debug = 1 print 'Calling consolidated for @base_container: ' + ISNULL(@base_container,'NONE')
EXEC sp_container_match_waste_consolidated @base_container, @base_container_id, @profit_ctr_id, @debug, @company_id
IF @debug = 1 print 'Back from calling consolidated for @base_container: ' + ISNULL(@base_container,'NONE')

--------------------------
-- RETURN SELECT RESULTS
--------------------------
IF @select_or_insert_results = 'S'
BEGIN

-- Determine type of TSDF
SELECT @eq_flag = IsNull(eq_flag,'F'), @eq_company_id = eq_company, @eq_profit_ctr_id = eq_profit_ctr
FROM TSDF WHERE TSDF_code = @tsdf_code

IF @eq_flag = 'T'
BEGIN
	SELECT @profile_id = profile_id FROM ProfileQuoteApproval 
	WHERE approval_code = @tsdf_approval_code
	AND company_id = @eq_company_id
	AND profit_ctr_id = @eq_profit_ctr_id

	INSERT #waste_code	
	SELECT ProfileWasteCode.waste_code,
		ProfileWasteCode.waste_code_uid,
		WasteCode.display_name
	FROM ProfileWasteCode
	JOIN WasteCode on ProfileWasteCode.waste_code_uid = WasteCode.waste_code_uid
	WHERE profile_id = @profile_id

END

ELSE
BEGIN
	 -- These are the waste codes for this TSDF Approval
	INSERT #waste_code	
	SELECT TSDFApprovalWasteCode.waste_code,
		TSDFApprovalWasteCode.waste_code_uid,
		WasteCode.display_name
	FROM TSDFApprovalWasteCode
		JOIN TSDFApproval ON (TSDFApprovalWasteCode.tsdf_approval_id = TSDFApproval.tsdf_approval_id)
			AND (TSDFApprovalWasteCode.company_id = TSDFApproval.company_id)
			AND (TSDFApprovalWasteCode.profit_ctr_id = TSDFApproval.profit_ctr_id)
		JOIN TSDFApprovalPrice ON (TSDFApprovalWasteCode.tsdf_approval_id = TSDFApprovalPrice.tsdf_approval_id)
			AND (TSDFApprovalWasteCode.company_id = TSDFApprovalPrice.company_id)
			AND (TSDFApprovalWasteCode.profit_ctr_id = TSDFApprovalPrice.profit_ctr_id)
		JOIN WasteCode on TSDFApprovalWasteCode.waste_code_uid = WasteCode.waste_code_uid
	WHERE TSDFApproval.tsdf_code = @tsdf_code
	AND TSDFApproval.tsdf_approval_code = @tsdf_approval_code
	AND TSDFApproval.waste_stream = @waste_stream
	AND TSDFApprovalPrice.bill_unit_code = @tsdf_approval_bill_unit_code
	AND TSDFApproval.profit_ctr_id = @profit_ctr_id
	AND TSDFApproval.company_id = @company_id
END
 
IF @debug = 1 print 'Selecting from #waste'
IF @debug = 1 SELECT DISTINCT * FROM #waste

-- Return the waste codes on the containers that are not specified on the TSDF approval
SELECT DISTINCT waste_code, container, container_ID, waste_code_uid, display_name FROM #waste
WHERE waste_code_uid NOT IN (SELECT waste_code_uid FROM #waste_code)
ORDER BY waste_code, container, container_id

END

--------------------------
-- RETURN INSERT RESULTS
--------------------------
ELSE
	INSERT #match_container (waste_code, container, container_ID, sequence_id, waste_code_uid, display_name)
	SELECT DISTINCT waste_code, container, container_ID, sequence_id, waste_code_uid, display_name FROM #waste
	ORDER BY waste_code, container, container_id, sequence_id

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_container_match_waste] TO [EQAI]
    AS [dbo];

