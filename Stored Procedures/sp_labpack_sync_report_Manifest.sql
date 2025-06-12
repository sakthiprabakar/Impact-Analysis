GO
DROP PROCEDURE IF EXISTS sp_labpack_sync_report_Manifest 
GO

CREATE PROCEDURE [dbo].[sp_labpack_sync_report_Manifest]  
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
 Updated On : 01-12-2023  
 Type  : Store Procedure  
 Object Name : [dbo].[sp_labpack_sync_report_Manifest] 
 Description : Procedure to get Manifest report details  

 27/12/2023 Ranjini- DevOps 73074 added to get Manifest report details 
 29/12/2023 Ranjini- DevOps 73074 Changed Manifest report details tsdf and generator phonenumber format.
 30/12/2023 Ranjini- DevOps 73074 Added Manifest report details tsdf details.
 03/01/2024 Ranjini- DevOps 73074 Added Manifest report details tsdf details.
  
 Input  :  @Trip_Id INT,  
   @WorkOrder_Id  INT,  
   @Company_Id  INT,  
   @Profit_Ctr_Id  INT,  
   @Manifest_State CHAR(2),  
   @TSDF_code VARCHAR(15),  
   @Manifest VARCHAR(15)  
  
 Execution Statement : EXEC [plt_ai].[dbo].[sp_labpack_sync_report_Manifest] 126400,26907300,14,4,' H','EQPA','100'
 
  
****************************************************************** */  

BEGIN

    SELECT
        ROW_NUMBER() OVER (ORDER BY woh.workorder_id, woh.company_id, woh.profit_ctr_id) AS ro,
        woh.workorder_id AS work_order_id,
        woh.company_id,
        woh.profit_ctr_id,
        wod.date_added,
        wod.added_by,
        wod.date_modified,
        wod.modified_by,
        g.EPA_ID,
        g.gen_mail_name,
        g.gen_mail_addr1,
        g.gen_mail_addr2,
        g.gen_mail_city,
        g.gen_mail_zip_code,
        '(' + SUBSTRING(g.generator_phone, 1, 3) + ')' + ' ' + SUBSTRING(g.generator_phone, 4, 3) + '-' + SUBSTRING(g.generator_phone, 7, LEN(g.generator_phone) - 6) AS generator_phone,
		g.generator_address_1,
        g.generator_city,
        g.generator_state,
        g.generator_zip_code,
        t.transporter_name,
        t.transporter_EPA_ID,
        tsdf.TSDF_name,
        tsdf.TSDF_addr1,
        tsdf.TSDF_city,
	tsdf.TSDF_state,
		 '(' + SUBSTRING(tsdf.TSDF_phone, 1, 3) + ')' + ' ' + SUBSTRING(tsdf.TSDF_phone, 4, 3) + '-' + SUBSTRING(tsdf.TSDF_phone, 7, LEN(tsdf.TSDF_phone) - 6) AS TSDF_phone,
		tsdf.TSDF_EPA_ID,
		tsdf.TSDF_zip_code,
        wod.manifest,
        FORMAT(wod.container_count, '000') AS container_count,
        wod.container_code,
        woditm.manual_entry_desc,
        b.manifest_unit,
        FORMAT(woditm.pounds, '00000') AS pounds,
        joh.truck_id,
        CASE WHEN joh.HHW_name = 'Yes' THEN 'HHW excluded per 40 CFR 261.4(b)(1)' WHEN joh.HHW_name = 'No' THEN ' ' END AS HHW_name,
		(SELECT CONCAT('[T:',woh.company_id,'.',woh.profit_ctr_id,'.',woh.trip_id,'.',woh.trip_sequence_id,'   ','W:',woh.company_id,'.',woh.profit_ctr_id,'.',woh.workorder_id,']')) AS WorkTrip,
        (SELECT CONCAT(wod.UN_NA_flag, wod.UN_NA_Number, ',', wod.DOT_shipping_name,'(',wod.DOT_shipping_desc_additional,')',',',wod.hazmat_class, ',', 'PG ', wod.package_group, ' ',',',CASE 
      WHEN wod.RQ_reason IS NOT NULL AND wod.RQ_reason <> '' THEN CONCAT('RQ(', wod.RQ_reason, ')', ',') 
      ELSE '' 
    END,
    wod.manifest_dot_sp_number, ' ERG No. ', wod.ERG_number)) AS UNNA_Description,
        STUFF((
                  SELECT DISTINCT TOP 6 ' ' + wowc.waste_code
                  FROM workorderwastecode wowc
                  WHERE wowc.workorder_id = wod.workorder_id AND wod.company_id = wowc.company_id AND wod.profit_ctr_id = wowc.profit_ctr_id AND wod.sequence_id = wowc.workorder_sequence_id
                  FOR XML PATH('')
              ), 1, 1, '') AS waste_codes
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
        TSDF tsdf ON tsdf.TSDF_code = wod.TSDF_code
    JOIN
        WorkOrderTransporter wot ON wot.workorder_id = wod.workorder_ID AND wot.company_id = wod.company_id AND wot.profit_ctr_id = wod.profit_ctr_ID AND wot.manifest = wod.manifest
    JOIN
        Transporter t ON t.transporter_code = wot.transporter_code
    JOIN
        profile p (NOLOCK) ON p.profile_id = wod.profile_id
    JOIN
        WorkOrderDetailItem woditm ON woditm.workorder_id = wod.workorder_id AND woditm.company_id = wod.company_id AND woditm.profit_ctr_id = wod.profit_ctr_id AND woditm.sequence_id = wod.sequence_id AND woditm.sub_sequence_id = 0
    JOIN
        Billunit b ON b.bill_unit_code = p.bill_unit_code
    JOIN
        LabPackJobSheet joh ON joh.workorder_id = wod.workorder_id AND joh.company_id = wod.company_id AND joh.profit_ctr_id = wod.profit_ctr_id
    WHERE
        woh.trip_id = @Trip_Id AND woh.WorkOrder_Id = @WorkOrder_Id AND woh.Company_Id = @Company_Id AND woh.Profit_Ctr_Id = @Profit_Ctr_Id AND wom.manifest_state = @Manifest_State AND wod.TSDF_code = @TSDF_code AND wom.manifest = @Manifest AND wod.resource_type = 'D' AND wod.bill_rate = -1
END
GO

GO
GRANT EXECUTE ON [dbo].[sp_labpack_sync_report_Manifest] TO LPSERV;
GO
GRANT EXECUTE ON [dbo].[sp_labpack_sync_report_Manifest] TO COR_USER;
GO
GRANT EXECUTE ON [dbo].[sp_labpack_sync_report_Manifest] TO EQWEB;
GO
GRANT EXECUTE ON [dbo].[sp_labpack_sync_report_Manifest] TO EQAI;
GO
