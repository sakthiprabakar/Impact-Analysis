GO
DROP PROCEDURE IF EXISTS sp_labpack_sync_report_workorder 
GO

CREATE PROCEDURE [dbo].[sp_labpack_sync_report_workorder]
(
   @Trip_Id INT,
   @WorkOrder_Id INT,
   @Company_Id INT,
   @Profit_Ctr_Id INT
)

AS

/* ******************************************************************

 Author  : Ranjini
 Updated On : 11-Sep-2023
 Type  : Store Procedure
 Object Name : [dbo].[sp_labpack_sync_report_workorder]

 Description : Procedure to get workorder details

 Input  :  @LdrBuilder_id

 Execution Statement : EXEC [plt_ai].[dbo].[sp_labpack_sync_report_workorder]  126337,26901000,14,4

****************************************************************** */

BEGIN

    SELECT DISTINCT
        wom.workorder_id,
        wom.manifest_state,
        wod.TSDF_code,
        wom.manifest,
        wom.company_id,
        wom.profit_ctr_id
    FROM
        WorkorderManifest wom
	JOIN
        Workorderheader woh ON woh.WorkOrder_Id = wom.WorkOrder_Id AND woh.Company_Id = wom.Company_Id
        AND woh.Profit_Ctr_Id = wom.Profit_Ctr_Id
    JOIN
        WorkorderDetail wod ON wod.WorkOrder_Id = wom.WorkOrder_Id AND wod.Company_Id = wom.Company_Id
        AND wod.Profit_Ctr_Id = wom.Profit_Ctr_Id AND wod.manifest = wom.manifest
    WHERE
        woh.trip_id = @Trip_Id AND wom.WorkOrder_Id = @WorkOrder_Id AND wom.Company_Id = @Company_Id AND wom.Profit_Ctr_Id = @Profit_Ctr_Id
        AND wod.bill_rate = -1 AND wod.resource_type = 'D'
END
GO

GO
GRANT EXECUTE ON [dbo].[sp_labpack_sync_report_workorder]] TO LPSERV;
GO
GRANT EXECUTE ON [dbo].[sp_labpack_sync_report_workorder] TO COR_USER;
GO
GRANT EXECUTE ON [dbo].[sp_labpack_sync_report_workorder] TO EQWEB;
GO
GRANT EXECUTE ON [dbo].[sp_labpack_sync_report_workorder] TO EQAI;
GO