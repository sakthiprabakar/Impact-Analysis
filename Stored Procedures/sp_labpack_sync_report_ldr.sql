GO
DROP PROCEDURE IF EXISTS sp_labpack_sync_report_ldr 
GO

CREATE PROCEDURE [dbo].[sp_labpack_sync_report_ldr]
(
   @Trip_Id INT,
   @WorkOrder_Id INT,
   @Company_Id INT,
   @Profit_Ctr_Id INT,
   @Manifest_State CHAR(2),
   @TSDF_code VARCHAR(15),
   @Manifest VARCHAR(15)
)

AS

/* ******************************************************************

 Author  : Ranjini
 Updated On : 11-Sep-2023
 Type  : Store Procedure
 Object Name : [dbo].[sp_labpack_sync_report_ldr]

 Description : Procedure to get LDR report details
 03/01/2024 Ranjini- DevOps 73074 Added LDR_id to get Ldr profile constituents.

 Input  :  @Trip_Id INT,
   @WorkOrder_Id  INT,
   @Company_Id  INT,
   @Profit_Ctr_Id  INT,
   @Manifest_State CHAR(2),
   @TSDF_code VARCHAR(15),
   @Manifest VARCHAR(15)

 Execution Statement : EXEC [plt_ai].[dbo].[sp_labpack_sync_report_ldr]   126337,26901000,14,4,'H','EQPA','100'

****************************************************************** */

BEGIN

    SELECT
        ROW_NUMBER() OVER(ORDER BY woh.workorder_id, woh.company_id, woh.profit_ctr_id,wod.date_added) AS ro,
        woh.workorder_id AS work_order_id,
        woh.customer_id,
        woh.generator_id,
        woh.company_id,
        woh.profit_ctr_id,
        wod.manifest,
        wod.date_added,
        wod.added_by,
        wod.date_modified,
        wod.modified_by,
        wom.manifest_state,
        wod.TSDF_approval_id,
        CASE WHEN p.Waste_Water_Flag = 'N' THEN 'NWW' WHEN p.Waste_Water_Flag = 'W' THEN 'WW' ELSE p.Waste_Water_Flag END AS Waste_Water_Flag,
        c.cust_name,
        g.EPA_ID,
        g.generator_name,
        p.profile_id,
        STUFF(
            (SELECT ',' + (SELECT TOP 1 waste_code FROM wastecode wc WHERE wc.waste_code_uid = wowc.waste_code_uid)
             FROM WorkOrderWasteCode wowc
             WHERE wowc.WorkOrder_Id = woh.WorkOrder_Id AND wowc.Company_Id = wod.Company_Id AND wowc.Profit_Ctr_Id = wod.Profit_Ctr_Id AND wowc.workorder_sequence_id = wod.sequence_ID
             FOR XML PATH('')), 1, 1, '') AS WasteCodes,
        CASE WHEN wod.profile_id IS NOT NULL THEN
            STUFF(
                (SELECT ',' + CAST((SELECT TOP 1 LDR_id FROM Constituents cs WHERE cs.const_id = PrCon.const_id) AS VARCHAR)
                 FROM ProfileConstituent PrCon
                 WHERE PrCon.profile_id = wod.profile_id
                 FOR XML PATH('')), 1, 1, '')
        ELSE
            STUFF(
                (SELECT ',' + CAST((SELECT TOP 1 LDR_id FROM Constituents cs WHERE cs.const_id = TsdfCon.const_id) AS VARCHAR)
                 FROM TSDFApprovalConstituent TsdfCon
                 WHERE TsdfCon.TSDF_approval_id = wod.TSDF_Approval_Id
                 FOR XML PATH('')), 1, 1, '')
        END AS constituents,
        CASE WHEN wod.profile_id IS NOT NULL THEN
            ISNULL(STUFF(
                (SELECT ',' + (SELECT TOP 1 short_desc FROM LDRSubcategory sc WHERE sc.subcategory_id = pldr.ldr_subcategory_id)
                 FROM ProfileLDRSubCategory pldr
                 WHERE pldr.profile_id = wod.profile_id
                 FOR XML PATH('')), 1, 1, ''), 'None')
        ELSE
            ISNULL(STUFF(
                (SELECT ',' + (SELECT TOP 1 short_desc FROM LDRSubcategory sc WHERE sc.subcategory_id = tldr.ldr_subcategory_id)
                 FROM TSDFApprovalLDRSubCategory tldr
                 WHERE tldr.TSDF_Approval_Id = wod.TSDF_Approval_Id
                 FOR XML PATH('')), 1, 1, ''), 'None')
        END AS categories,
        CASE WHEN wod.profile_id IS NOT NULL THEN
            (SELECT TOP 1 lp.LDR_flag FROM profile p1 (NOLOCK)
             LEFT JOIN LabPackProcessCode lp ON lp.process_code_uid = p1.process_code_uid
             WHERE p1.profile_id = p.created_from_template_profile_id)
        ELSE
            ''
        END AS LDR_flag
    FROM
        WorkOrderDetail wod
    JOIN
        WorkOrderHeader woh ON wod.WorkOrder_Id = woh.WorkOrder_Id AND woh.Company_Id = wod.Company_Id AND woh.Profit_Ctr_Id = wod.Profit_Ctr_Id
    LEFT JOIN
        WorkorderManifest wom ON wom.WorkOrder_Id = woh.WorkOrder_Id AND wom.Company_Id = woh.Company_Id AND wom.Profit_Ctr_Id = woh.Profit_Ctr_Id AND wom.manifest = wod.manifest
    JOIN
        customer c ON c.customer_id = woh.customer_id
    JOIN
        generator g ON g.generator_id = woh.generator_id
    JOIN
        profile p (NOLOCK) ON p.profile_id = wod.profile_id
    WHERE
        woh.trip_id = @Trip_Id AND woh.WorkOrder_Id = @WorkOrder_Id AND woh.Company_Id = @Company_Id AND woh.Profit_Ctr_Id = @Profit_Ctr_Id AND wom.manifest_state = @Manifest_State AND wod.TSDF_code = @TSDF_code AND wom.manifest = @Manifest AND wod.resource_type = 'D' AND wod.bill_rate = -1

END
GO

GO
GRANT EXECUTE ON [dbo].[sp_labpack_sync_report_ldr] TO LPSERV;
GO
GRANT EXECUTE ON [dbo].[sp_labpack_sync_report_ldr] TO COR_USER;
GO
GRANT EXECUTE ON [dbo].[sp_labpack_sync_report_ldr] TO EQWEB;
GO
GRANT EXECUTE ON [dbo].[sp_labpack_sync_report_ldr] TO EQAI;
GO