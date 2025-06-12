-- =============================================
-- Author:		SENTHIL KUMAR
-- Create date: 25-08-2020
-- Description:	To fetch SAA CheckIn data
-- EXEC sp_labpack_get_saacheckin 886111,NULL,NULL,NULL
-- =============================================
CREATE PROCEDURE [dbo].[sp_labpack_get_saacheckin]
	-- Add the parameters for the stored procedure here
	@customer_id int,
	@mainAccumulationArea_uid int,
	@satelliteAccumulationArea_uid int,
	@generator_id int,
	@workOrder_id int
AS
BEGIN
	set transaction isolation level read uncommitted
	SELECT * INTO #tempSAACheckIn FROM  SAACheckIn WHERE processed_flag = 'F' AND customer_id=@customer_id  
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
				ISNULL(SAACheckInInventory.ship_date,'') ship_date,
				ISNULL(SAACheckInInventory.lpcontainer,'') lpcontainer
		
	from #tempSAACheckIn saac 
	JOIN  SAACheckInInventory as SAACheckInInventory  ON SAACheckInInventory.saaCheckIn_uid = saac.saaCheckIn_uid 
	LEFT JOIN MainAccumulationArea as maa  ON  maa.mainAccumulationArea_uid= saac.mainAccumulationArea_uid
	LEFT JOIN SatelliteAccumulationArea as saa  ON  saa.satelliteAccumulationArea_uid= saac.satelliteAccumulationArea_uid
	WHERE saac.processed_flag = 'F' AND saac.customer_id=@customer_id AND(@mainAccumulationArea_uid=0 OR saac.mainAccumulationArea_uid=@mainAccumulationArea_uid) AND (@satelliteAccumulationArea_uid=0 OR saac.satelliteAccumulationArea_uid=@satelliteAccumulationArea_uid) AND 
	(@generator_id=0 OR saac.generator_id=@generator_id)   ORDER BY SAACheckInInventory.process_code,saac.mainAccumulationArea_uid
	
	UPDATE 	SAACheckIn SET processed_flag='T',workorder_id = @workOrder_id FROM 
    SAACheckIn checkin
    INNER JOIN #tempSAACheckIn tempCheckIn
        ON checkin.saaCheckIn_uid = tempCheckIn.saaCheckIn_uid 
END
