CREATE PROCEDURE sp_wastecodes_trans_fees 
	@company_id			int
    , @profit_ctr_id	int
    , @workorder_id		int
    , @sequence_id		int 
AS
/***********************************************************************
Load to:		Plt_AI
PB Object(s):	d_trans_fees_waste_codes_5		(directly)
				r_transporter_fee_ma_worksheet	(indirectly)
				r_transporter_fee_ri_worksheet	(indirectly)

10/06/2006 XXX	Created.
10/29/2013 JDB	Modified to use the WorkOrderWasteCode table instead of
				the ProfileWasteCode and TSDFApprovalWasteCode tables.
				This required changing the parameters to use the work
				order line instead of Profile or TSDFApproval ID.
***********************************************************************/

--if @source_type = 'TA'
--begin 
--    SELECT wastecode.display_name as waste_code  
--    FROM TSDFApprovalWasteCode 
--   Join wastecode ON wastecode.waste_code_uid = TSDFApprovalWasteCode.waste_code_uid
--   WHERE TSDFApprovalWasteCode.tsdf_approval_id = @source_id
--     AND TSDFApprovalWasteCode.profit_ctr_id = @profit_ctr_id
--     and TSDFApprovalWasteCode.company_id = @company_id
--end

--if @source_type = 'P'
--begin 
--    SELECT wastecode.display_name as waste_code  
--    FROM ProfileWasteCode
--Join wastecode ON wastecode.waste_code_uid = ProfileWasteCode.waste_code_uid
--      WHERE ProfileWasteCode.profile_id = @source_id
--end

SELECT wc.display_name AS waste_code  
FROM WorkOrderWasteCode wowc
JOIN WasteCode wc ON wc.waste_code_uid = wowc.waste_code_uid
WHERE wowc.company_id = @company_id
AND wowc.profit_ctr_id = @profit_ctr_id
AND wowc.workorder_id = @workorder_id
AND wowc.workorder_sequence_id = @sequence_id
ORDER BY ISNULL(wowc.sequence_id, 9999), wc.display_name

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_wastecodes_trans_fees] TO [EQAI]
    AS [dbo];

