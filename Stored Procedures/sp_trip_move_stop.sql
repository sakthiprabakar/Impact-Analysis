CREATE PROCEDURE sp_trip_move_stop( 
	@company_id    		int, 
	@profit_ctr_id 		int, 
	@workorder_ID       int,
	@trip_id 			int,
	@void_flag			Char(1),
	@user				VarChar(10),
	@old_trip_id		int,
	@type				char(1),
	@dest_trip_type NVARCHAR(5),
	@sequence_id INT) 
AS 
/*******************************************************************************************
12/XX/2010 KAM	Created
02/21/2012 RWB  Update the modified_by fields
10/08/2015 RWB	If moving to a trip that is not a template, update workorder_status to 'N'
02/12/2024 Kamendra - DevOps 43025 - Added two new arguments @dest_trip_type and @sequence_id.
			We are assigning @next_seq value based on the @dest_trip_type.

sp_trip_move_stop 14, 0, 13870800, 5762, 'F', 'JASON_B', 5761, 'S', 'new', 1
*******************************************************************************************/
DECLARE
@max_id		int,
@next_id	int,
@next_workorder_id int,
@next_seq	int

--  Get Rows to Copy into Temp Tables
Select * into #WOH
	from WorkorderHeader 
	where workorder_ID = @workorder_id and
		 company_id = @company_id and
		 profit_ctr_ID = @profit_ctr_id
		 
Select * into #WOD
	from WorkorderDetail 
	where workorder_ID = @workorder_id and
		 company_id = @company_id and
		 profit_ctr_ID = @profit_ctr_id
	
Select * into #WOM
	 from Workordermanifest 
	where workorder_ID = @workorder_id and
		 company_id = @company_id and
		 profit_ctr_ID = @profit_ctr_id	
	
Select * into #WOS
	 from WorkorderStop 
	where workorder_ID = @workorder_id and
		 company_id = @company_id and
		 profit_ctr_ID = @profit_ctr_id	
	
Select * into #WOT
	 from WorkorderTransporter 
	where workorder_ID = @workorder_id and
		 company_id = @company_id and
		 profit_ctr_ID = @profit_ctr_id
	
Select * into #WOWC
	 from WorkorderWasteCode 
	where workorder_ID = @workorder_id and
		 company_id = @company_id and
		 profit_ctr_ID = @profit_ctr_id	
	
Select * into #WOCC
	 from WorkorderdetailCC 
	where workorder_ID = @workorder_id and
		 company_id = @company_id and
		 profit_ctr_ID = @profit_ctr_id
	
Select * into #WODU
	 from WorkorderdetailUnit 
	where workorder_ID = @workorder_id and
		 company_id = @company_id and
		 profit_ctr_ID = @profit_ctr_id
	
Select * into #WODI
	 from WorkOrderDetailItem 
	where workorder_ID = @workorder_id and
		 company_id = @company_id and
		 profit_ctr_ID = @profit_ctr_id	
	
Select * into #WOTQ
	 from TripQuestion 
	where workorder_ID = @workorder_id and
		 company_id = @company_id and
		 profit_ctr_ID = @profit_ctr_id	
		 

-- Get the next available workorder number
Set @next_id = (SELECT next_workorder_id 
				FROM ProfitCenter
				WHERE	profit_ctr_id = @profit_ctr_id and 
						company_id = @company_id)

IF IsNull(@next_id,0) = 0
	Begin
		Set @next_workorder_id = 100
	End
ELSE
	Begin
		Set @next_workorder_id = (@next_id * 100)
	End
		
UPDATE ProfitCenter 
	SET next_workorder_id = @next_id + 1
	WHERE profit_ctr_id = @profit_ctr_id and
			company_id = @company_id
				
IF @dest_trip_type = 'new'
	BEGIN
		SET @next_seq = @sequence_id
	END	
ELSE
	BEGIN       
		SELECT @next_seq = COALESCE(MAX(trip_sequence_id) + 1, 1)  
		FROM WorkorderHeader  
		WHERE trip_id = @trip_id
	END


--Update the Temp Tables
-- rb 02/21/2012 Update the modified_by fields
Update #WOH Set workorder_ID = @next_workorder_id, modified_by=@user, date_modified=getdate()
Update #WOH Set Trip_ID = @trip_id, trip_sequence_id = @next_seq
if @type = 'T'
	update #WOH Set workorder_status = 'X'
-- rb 10/08/2015
else
	update #WOH Set workorder_status = 'N'

	
Update #WOH Set field_requested_action = 'R'	
	
Update #WOD Set workorder_ID = @next_workorder_id, modified_by=@user, date_modified=getdate()		 
Update #WOM Set workorder_ID = @next_workorder_id, modified_by=@user, date_modified=getdate()
Update #WOS Set workorder_ID = @next_workorder_id, modified_by=@user, date_modified=getdate()
Update #WOT Set workorder_ID = @next_workorder_id, modified_by=@user, date_modified=getdate()
Update #WOWC Set workorder_ID = @next_workorder_id
Update #WOCC Set workorder_ID = @next_workorder_id, modified_by=@user, date_modified=getdate()
Update #WODU Set workorder_ID = @next_workorder_id, modified_by=@user, date_modified=getdate()
Update #WODI Set workorder_ID = @next_workorder_id, modified_by=@user, date_modified=getdate()
Update #WOTQ Set workorder_ID = @next_workorder_id, modified_by=@user, date_modified=getdate()

If @void_flag = 'T'
	Begin
		Update workorderHeader set workorder_status	= 'V',
		field_requested_action = 'D'
			where workorder_ID = @workorder_id and
					 company_id = @company_id and
					 profit_ctr_ID = @profit_ctr_id
					 
		Update WorkorderDetail Set bill_rate = -2
			where workorder_ID = @workorder_id and
					 company_id = @company_id and
					 profit_ctr_ID = @profit_ctr_id and
					 resource_type = 'D'
	 End

-- copy the rows back into the main table	

Insert into WorkorderHeader
	Select * from  #WOH
	
 INSERT INTO WorkOrderAudit VALUES (
	@company_id,
	@profit_ctr_id,
	@workorder_id,
	'',
	0,
	'WorkOrderHeader',
	'trip_id',
	@old_trip_id,
	@trip_id,
	'Work Order moved',
	@user,
	GETDATE() )
			 
Insert into WorkorderDetail
	Select * from  #WOD
	
Insert into Workordermanifest  
	Select * from  #WOM
	
Insert into  WorkorderStop 
	Select * from  #WOS

Insert into  WorkorderTransporter 
	Select * from  #WOT

Insert into  WorkorderWasteCode 
	Select * from #WOWC 
	
Insert into  WorkorderdetailCC 
	Select * from  #WOCC
	
Insert into  WorkorderdetailUnit 
	Select * from  #WODU
	
Insert into  WorkOrderDetailItem 
	Select * from  #WODI
	
Insert into  TripQuestion 
	Select * from  #WOTQ


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_trip_move_stop] TO [EQAI]
    AS [dbo];

