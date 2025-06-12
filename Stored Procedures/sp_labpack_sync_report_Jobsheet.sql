GO
DROP PROCEDURE IF EXISTS sp_labpack_sync_report_Jobsheet 
GO

CREATE PROCEDURE [dbo].[sp_labpack_sync_report_Jobsheet]  
(  
   @Trip_Id int,
   @WorkOrder_Id  int,
   @Company_Id  int,
   @Profit_Ctr_Id  int,
   @Manifest_State char(2),
   @TSDF_code varchar(15),
   @Manifest varchar(15)
)  
  
AS  

/* ******************************************************************  
  
 Author  : Ranjini  
 Updated On : 11-Sep-2023  
 Type  : Store Procedure   
 Object Name : [dbo].[[sp_labpack_sync_report_Jobsheet]]  
  
 Description : Procedure to get Jobsheet report details
  
 Input  :  @Trip_Id int,
   @WorkOrder_Id  int,
   @Company_Id  int,
   @Profit_Ctr_Id  int,
   @Manifest_State char(2),
   @TSDF_code varchar(15),
   @Manifest varchar(15)
                  
 Execution Statement : EXEC sp_labpack_sync_report_jobsheet 126337,26901000,14,4,' H','EQPA',100
  
****************************************************************** */  
  
BEGIN  
  
Select
distinct 
  wod.workorder_id work_order_id,
  wod.company_id,  
  wod.profit_ctr_id,  
  wod.manifest,
  wod.date_added,
  wod.added_by,
  wod.date_modified,
  wod.modified_by,
  wom.manifest_state,
  c.cust_name,
  c.cust_addr1,
  c.cust_city,
  c.cust_state,
  c.cust_zip_code,
  c.cust_state,
  g.EPA_ID,
  g.generator_name,
  g.generator_address_1,
  g.generator_city,
  g.generator_state,
  g.generator_county,
  g.generator_zip_code,
  joh.job_notes,
  joh.truck_id,
  joc.comment,
  tsdf.TSDF_addr1,
  tsdf.TSDF_city,
  tsdf.TSDF_state,
  tsdf.TSDF_phone,
  jol.chemist_name,
  jol.dispatch_time,
  jol.onsite_time,
  jol.jobfinish_time,
  jol.est_return_time,
  case when wostp.decline_id = 5 then joh.otherinfo_text when wostp.decline_id != 5 then ' ' end as otherinfo_text,
  case when joh.is_change_auth_enabled = 1 then joh.auth_name when joh.is_change_auth_enabled = 0 then  ' ' end as auth_name
  
 from WorkOrderDetail wod  

 Left join WorkorderManifest wom on wom.WorkOrder_Id =wod.WorkOrder_Id and wom.Company_Id = wod.Company_Id and wom.Profit_Ctr_Id = wod.Profit_Ctr_Id and wom.manifest = wod.manifest
 join WorkorderHeader woh on woh.workorder_ID = wom.WorkOrder_Id and woh.company_id = wom.Company_Id and woh.profit_ctr_ID = wom.Profit_Ctr_Id
 join customer c on c.customer_id = woh.customer_id  
 join generator g on g.generator_id=woh.generator_id
 Left join LabPackJobSheet joh on joh.workorder_id = wod.workorder_ID and joh.company_id = wod.company_id and joh.profit_ctr_id = wod.profit_ctr_ID 
 join LabPackJobSheetXComments joc on joc.jobsheet_comment_uid = joh.jobsheet_uid 
 join TSDF tsdf on tsdf.TSDF_code = wod.TSDF_code
 join LabPackJobSheetXLabor jol on jol.jobsheet_uid = joh.jobsheet_uid
 join workorderstop wostp on wostp.workorder_id = wod.workorder_ID and wostp.company_id = wod.company_id and wostp.profit_ctr_id = wod.profit_ctr_ID 
 where woh.trip_id = @Trip_Id AND woh.WorkOrder_Id = @WorkOrder_Id AND woh.Company_Id = @Company_Id AND woh.Profit_Ctr_Id = @Profit_Ctr_Id AND wom.manifest_state = @Manifest_State AND wod.TSDF_code = @TSDF_code AND wom.manifest = @Manifest AND wod.resource_type='D' and wod.bill_rate=-1
   
 END  
GO

GO
GRANT EXECUTE ON [dbo].[sp_labpack_sync_report_Jobsheet] TO LPSERV;
GO
GRANT EXECUTE ON [dbo].[sp_labpack_sync_report_Jobsheet] TO COR_USER;
GO
GRANT EXECUTE ON [dbo].[sp_labpack_sync_report_Jobsheet] TO EQWEB;
GO
GRANT EXECUTE ON [dbo].[sp_labpack_sync_report_Jobsheet] TO EQAI;
GO