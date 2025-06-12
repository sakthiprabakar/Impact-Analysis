CREATE PROCEDURE sp_unmatched_waste_codes 
 	@inbound_container varchar(15),
 	@container_id int,
 	@sequence_id int, 
 	@profit_ctr_id int, 
 	@tsdf_code varchar(15),
 	@tsdf_approval_code varchar(40),
 	@waste_stream varchar(10),
	@bill_unit_code varchar(4),
 	@insert_results char(1),
 	@debug int,
	@company_id int
 AS
/****************
This SP returns a list of receipt waste codes assigned to inbound containers (non-bulk) 
that do not match TSDF approval waste codes.

Test Cmd Line:  sp_unmatched_waste_codes '623783-1', 2, 1, 0, 'SAFKLEENUT', '3564512-0001', 'PAINT RELATED MATERIALS', 'DM55', 'S', 1
Test Cmd Line:  sp_unmatched_waste_codes 'DL-2200-002114', 2114, 1, 0, 'MDI', '013004', 'ACID', 'DM55', 'S', 1
sp_unmatched_waste_codes '644380-1', 1, 1, 0, 'MDI', 'scctest', '', 'DM55', 'S', 1

02/04/2004 MGK Created
05/03/2004 SCC Use new waste code tables
12/22/2004 SCC Modified for Container Tracking
04/14/2005 JDB	NOT USED in PB or called from any other SP
		WILL BE DROPPED
08/29/2005 MK	Was/is used in Bar Code Scanning - Reimplemented
07/17/2006 SCC	Modified to use new TSDFApproval tables
07/23/2006 SCC	Modified to select from Profile for EQ facilities
08/27/2013 RWB	Added waste_code_uid and display_name to #waste_code
07/02/2014 SM 	Moved to plt_ai
07/02/2014 SM   Added company_id

******************/

 DECLARE 
@eq_flag char(1),
@eq_company_id int,
@eq_profit_ctr_id int,
@profile_id int

CREATE TABLE #waste_code (
	waste_code varchar(4) NULL,
	waste_code_uid int NULL,
	display_name varchar(10) NULL
)

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
	SELECT ProfileWasteCode.waste_code, ProfileWasteCode.waste_code_uid, WasteCode.display_name
	FROM ProfileWasteCode
	JOIN WasteCode on ProfileWasteCode.waste_code_uid = WasteCode.waste_code_uid
	WHERE profile_id = @profile_id

END

ELSE
BEGIN
	 -- These are the waste codes for this TSDF Approval
	INSERT #waste_code	
	SELECT TSDFApprovalWasteCode.waste_code, TSDFApprovalWasteCode.waste_code_uid, WasteCode.display_name
	 FROM TSDFApprovalWasteCode
		JOIN TSDFApproval ON (TSDFApprovalWasteCode.tsdf_approval_id = TSDFApproval.tsdf_approval_id)
			AND (TSDFApprovalWasteCode.company_id = TSDFApproval.company_id)
			AND (TSDFApprovalWasteCode.profit_ctr_id = TSDFApproval.profit_ctr_id)
		JOIN ProfitCenter ON (TSDFApprovalWasteCode.company_id = ProfitCenter.company_id)
			AND (TSDFApprovalWasteCode.profit_ctr_id = ProfitCenter.profit_ctr_id)
		JOIN WasteCode on TSDFApprovalWasteCode.waste_code_uid = WasteCode.waste_code_uid
	WHERE TSDFApproval.tsdf_code = @tsdf_code
	 AND TSDFApproval.tsdf_approval_code = @tsdf_approval_code
	 AND TSDFApproval.waste_stream = @waste_stream
	 AND TSDFApproval.profit_ctr_id = @profit_ctr_id
	 AND  TSDFApproval.company_id = @company_id
	AND TSDFApproval.company_id = ProfitCenter.company_id
END
 
 CREATE TABLE #match_container (
 	waste_code varchar(4) NULL,
 	container varchar(15) NULL,
 	container_id int NULL,
 	sequence_id int	NULL,
	waste_code_uid int NULL,
	display_name varchar(10) NULL )
 
 -- Call the non-bulk container match SP
 EXEC sp_container_match_waste @inbound_container, @container_id, @sequence_id, @profit_ctr_id, 
 	@tsdf_code, @tsdf_approval_code, @waste_stream, @bill_unit_code, @insert_results, @debug, @company_id
 
 -- RETURN WASTE CODES THAT DO NOT MATCH
 SELECT DISTINCT waste_code, waste_code_uid, display_name FROM #match_container WHERE waste_code NOT IN (SELECT waste_code FROM #waste_code)
 

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_unmatched_waste_codes] TO [EQAI]
    AS [dbo];

