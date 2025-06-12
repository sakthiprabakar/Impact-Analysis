-- =============================================  
-- Author:  NAGOOR MEERAN  
-- Create date: 16-09-2020  
-- Description: To fetch SAA Inventory data   
-- EXEC sp_labpack_get_saacheckininventory '13212,15606'
-- =============================================  
CREATE PROCEDURE [dbo].[sp_labpack_get_saacheckininventory]  
 -- Add the parameters for the stored procedure here  
 @customer_id_list nvarchar(max) = ''
AS  
BEGIN  
set transaction isolation level read uncommitted
declare @customer table (    
 customer_id bigint    
)    
    
if @customer_id_list <> ''    
insert @customer select convert(bigint, row)    
from dbo.fn_SplitXsvText(',', 1, @customer_id_list)    
where row is not null  

 SELECT * INTO #tempSAACheckIn FROM  SAACheckIn WHERE 1=1    
 and     
   (    
        @customer_id_list = ''    
        or    
         (    
   @customer_id_list <> ''    
   and    
   customer_id in (select customer_id from @customer)    
   )        
    )       
 SELECT saac.saaCheckIn_uid,  
    saac.mainAccumulationArea_uid,  
    maa.mainAccumulationArea_code,  
    maa.Description maa_Description,  
    saac.satelliteAccumulationArea_uid,  
    saa.satelliteAccumulationArea_code,  
    saa.Description saa_Description,  
    saac.customer_id,  
    saac.generator_id,  
    saac.added_by,  
    SAACheckInInventory.saaCheckInInventory_uid,  
    ISNULL(SAACheckInInventory.department,'') department,  
    ISNULL(SAACheckInInventory.primary_waste_ingredient,'') primary_waste_ingredient,  
    ISNULL(SAACheckInInventory.other_ingredients,'') other_ingredients,  
    ISNULL(SAACheckInInventory.spent,'') spent,  
    ISNULL(CAST(SAACheckInInventory.quantity as varchar),'') quantity,  
    ISNULL(SAACheckInInventory.size,'') size,  
    ISNULL(SAACheckInInventory.phase,'') phase,  
	ISNULL(SAACheckInInventory.weight,'') weight,  
	ISNULL(SAACheckInInventory.amount,'') amount,  
	ISNULL(SAACheckInInventory.uom,'') uom,  
	ISNULL(SAACheckInInventory.weight_pounds,'') weight_pounds,  
    ISNULL(SAACheckInInventory.waste_type,'') waste_type,  
    ISNULL(SAACheckInInventory.process_code,'') process_code,  
    ISNULL(SAACheckInInventory.checkin_date,'') checkin_date,  	 
	ISNULL(SAACheckInInventory.lpcontainer,'') lpcontainer, 
    ISNULL(DATEDIFF(d, SAACheckInInventory.checkin_date,GETDATE() ),'') accumulation_days  
    
 from #tempSAACheckIn saac   
 JOIN  SAACheckInInventory as SAACheckInInventory  ON SAACheckInInventory.saaCheckIn_uid = saac.saaCheckIn_uid   
 LEFT JOIN MainAccumulationArea as maa  ON  maa.mainAccumulationArea_uid= saac.mainAccumulationArea_uid  
 LEFT JOIN SatelliteAccumulationArea as saa  ON  saa.satelliteAccumulationArea_uid= saac.satelliteAccumulationArea_uid  
 WHERE 1=1    
 and     
   (    
        @customer_id_list = ''    
        or    
         (    
   @customer_id_list <> ''    
   and    
   saac.customer_id in (select customer_id from @customer)    
   )        
    )     AND 
	SAACheckInInventory.ship_date IS NULL  ORDER BY SAACheckInInventory.process_code,saac.mainAccumulationArea_uid  
  
 
END  


