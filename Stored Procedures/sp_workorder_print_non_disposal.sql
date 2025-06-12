
CREATE PROCEDURE sp_workorder_print_non_disposal (
	@workorder_id		int,
	@company_id			int,
	@profit_ctr_id		int,
	@resource_type		char(1))
AS

--  Created on 11/3/2010 BY KAM - Used in teh printing of the workorder
--  Dipankar - 8/29/2023 - #65187 - The corresponding DW need not data in 2-Columns, modifying logic to add just one more row
--  Load to PLT_AI
--  sp_workorder_print_non_disposal 13061000,14,0,'O'

Declare @rows	integer,
		@new_rows integer
		
  SELECT WorkOrderDetail.workorder_ID,   
         WorkOrderDetail.profit_ctr_ID,   
         WorkOrderDetail.resource_type,   
         WorkOrderDetail.sequence_ID,   
         WorkOrderDetail.resource_class_code,   
         WorkOrderDetail.description,   
         WorkOrderDetail.bill_unit_code,   
         WorkOrderDetail.quantity,   
         WorkOrderDetail.quantity_used,
			IsNull(WorkOrderDetail.billing_sequence_id,0) as billing_sequence_id,
			Workorderdetail.resource_assigned
	Into #wo_detail_lines    
    FROM WorkOrderDetail
   WHERE ( WorkOrderDetail.workorder_ID = @workorder_id ) AND  
         ( WorkOrderDetail.profit_ctr_ID = @profit_ctr_id ) AND  
         (WorkOrderDetail.resource_type = @resource_type )  AND
			 ( WorkOrderDetail.company_ID = @company_id )
			 
	Set @rows = @@rowcount
	
	-- Set @new_rows = (@rows % 2) + 2
	Set @new_rows = 1
	
	If (@new_rows + @rows) < 4 
		Set @new_rows = (4 - (@new_rows + @rows))
	
	While @new_rows > 0
	 Begin
		Insert Into #wo_detail_lines Values (0,0,@resource_type,99999,' ' ,NULL,NULL,NULL,NULL,0,NULL)
	 	Set @new_rows = @new_rows - 1
	 End
		 	
	Select * from #wo_detail_lines order by sequence_id	

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_workorder_print_non_disposal] TO [EQAI]
    AS [dbo];

