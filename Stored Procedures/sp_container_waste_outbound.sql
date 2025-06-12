CREATE PROCEDURE sp_container_waste_outbound 
	@outbound_receipt_id int, 
	@outbound_line_id int, 
	@profit_ctr_id int, 
	@company_id	int,
	@debug int
WITH RECOMPILE
AS
/****************
This SP returns a list of waste codes assigned to inbound containers for the specified outbound receipt.

Filename:	L:\IT Apps\SQL-Deploy\Prod\NTSQL1\PLT_XX_AI\Procedures\sp_container_waste_outbound.sql
PB Object(s):	d_receipt_container_waste
SQL Object(s):	

03/18/2005 SCC	Created  - replaces the old sp_container_match_waste_outbound
04/14/2005 JDB	Added bill_unit_code for TSDFApproval
08/07/2006 SCC	Replaced a join to the ContainerWaste view to tables with specific receipt references
		improved query time from 1.21 to .001
08/27/2013 RWB	Added waste_code_uid and display_name to result set
09/03/2013 JDB	Add logic to exclude state waste codes from the inbound set if those waste code(s)
				are not from the state of the Outbound Receipt's generator or TSDF.
06/23/2014 SK	Added company_id and made changes to move to plt_AI				
11/17/2014 RWB	Unioned ReceiptWasteCode table needs to check for existence of ContainerWasteCode records
05/20/2015 RWB  Added "read uncommitted" because it was found to be blocking people when it was suspended
11/22/2016 RWB	Create with recompile (happened before, one day it starts using the wrong index and takes a minute to run)
05/30/2018 MPM	GEM 50913 - Modified to skip the Texas state codes that are on inbound containers when validating for the outbound.

sp_container_waste_outbound 616374, 1, 0, 1
sp_container_waste_outbound 625077, 1, 0, 1
sp_container_waste_outbound 625077, 2, 0, 1
sp_container_waste_outbound 625077, 3, 0, 1
sp_container_waste_outbound 931773, 1, 0, 1
sp_container_waste_outbound 931773, 1, 0, 21, 1

******************/
DECLARE @tracking_num		varchar(15)
		, @generator_id		int
		, @generator_state	char(2)
		, @TSDF_code		varchar(15)
		, @TSDF_state		char(2)

SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

SELECT @tracking_num = dbo.fn_container_receipt(@outbound_receipt_id, @outbound_line_id)

-- Get generator state and TSDF state from the Outbound Receipt line
SELECT @generator_id = r.generator_id
	, @generator_state = g.generator_state
	, @TSDF_code = r.TSDF_code
	, @TSDF_state = t.TSDF_state
FROM Receipt r
JOIN Generator g ON g.generator_id = r.generator_id
JOIN TSDF t ON t.TSDF_code = r.TSDF_code
WHERE 1=1
AND r.profit_ctr_id = @profit_ctr_id
AND r.company_id = @company_id
AND r.receipt_id = @outbound_receipt_id
AND r.line_id = @outbound_line_id


-- Get all the waste codes assigned to the containers assigned to the outbound receipt
SELECT DISTINCT 
ContainerWasteCode.waste_code,
container = 
	CASE WHEN ContainerDestination.container_type = 'R'
	THEN dbo.fn_container_receipt(ContainerDestination.receipt_id, ContainerDestination.line_id)
	ELSE dbo.fn_container_stock(ContainerDestination.line_id, ContainerDestination.company_id, ContainerDestination.profit_ctr_id)
	END,
ContainerDestination.container_id,
ContainerWasteCode.waste_code_uid,
WasteCode.display_name
FROM ContainerDestination 
JOIN ContainerWasteCode ON ContainerWasteCode.profit_ctr_id = ContainerDestination.profit_ctr_id
	AND ContainerWasteCode.company_id = ContainerDestination.company_id
	AND ContainerWasteCode.receipt_id = ContainerDestination.receipt_id
	AND ContainerWasteCode.line_id = ContainerDestination.line_id
	AND ContainerWasteCode.container_id = ContainerDestination.container_id
	AND ContainerWasteCode.sequence_id = ContainerDestination.sequence_id
JOIN WasteCode ON ContainerWasteCode.waste_code_uid = WasteCode.waste_code_uid
	AND ((WasteCode.waste_code_origin <> 'S')
		OR (WasteCode.waste_code_origin = 'S' AND WasteCode.state IN (@generator_state, @TSDF_state) AND WasteCode.state <> 'TX'
		)
	)
	AND WasteCode.status = 'A'
WHERE ContainerDestination.profit_ctr_id = @profit_ctr_id
AND ContainerDestination.company_id = @company_id
AND ContainerDestination.location_type = 'O'
AND ContainerDestination.tracking_num = @tracking_num

UNION ALL

-- OR receipt waste codes when no Container waste codes are assigned
SELECT 
ReceiptWasteCode.waste_code,
container = 
	CASE WHEN ContainerDestination.container_type = 'R'
	THEN dbo.fn_container_receipt(ContainerDestination.receipt_id, ContainerDestination.line_id)
	ELSE dbo.fn_container_stock(ContainerDestination.line_id, ContainerDestination.company_id, ContainerDestination.profit_ctr_id)
	END,
ContainerDestination.container_id,
ReceiptWasteCode.waste_code_uid,
WasteCode.display_name
FROM ContainerDestination 
JOIN Receipt ON Receipt.profit_ctr_id = ContainerDestination.profit_ctr_id
	AND Receipt.company_id = ContainerDestination.company_id
	AND Receipt.receipt_id = ContainerDestination.receipt_id
	AND Receipt.line_id = ContainerDestination.line_id
	AND Receipt.trans_mode = 'I'
	AND Receipt.trans_type = 'D'
	AND Receipt.fingerpr_status NOT IN ('V','R')
	AND Receipt.receipt_status NOT IN ('V','R')
JOIN ReceiptWasteCode ON ReceiptWasteCode.profit_ctr_id = ContainerDestination.profit_ctr_id
	AND ReceiptWasteCode.company_id = ContainerDestination.company_id
	AND ReceiptWasteCode.receipt_id = ContainerDestination.receipt_id
	AND ReceiptWasteCode.line_id = ContainerDestination.line_id
	AND ReceiptWasteCode.waste_code IS NOT NULL
JOIN WasteCode ON ReceiptWasteCode.waste_code_uid = WasteCode.waste_code_uid
	AND ((WasteCode.waste_code_origin <> 'S')
		OR (WasteCode.waste_code_origin = 'S' AND WasteCode.state IN (@generator_state, @TSDF_state) AND WasteCode.state <> 'TX'
		)
	)
	AND WasteCode.status = 'A'
WHERE ContainerDestination.profit_ctr_id = @profit_ctr_id
AND ContainerDestination.company_id = @company_id
AND ContainerDestination.location_type = 'O'
AND ContainerDestination.tracking_num = @tracking_num
AND NOT EXISTS (select 1 from ContainerWasteCode
				where profit_ctr_id = ContainerDestination.profit_ctr_id
				and company_id = ContainerDestination.company_id
				and receipt_id = ContainerDestination.receipt_id
				and line_id = ContainerDestination.line_id
				and container_id = ContainerDestination.container_id
				and sequence_id = ContainerDestination.sequence_id)

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_container_waste_outbound] TO [EQAI]
    AS [dbo];

