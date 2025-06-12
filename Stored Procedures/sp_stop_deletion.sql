USE PLT_AI
GO
CREATE OR ALTER PROCEDURE sp_stop_deletion
@user_id Varchar(10),
@trip_id Int,
@Workorder_id Int,
@Company_id Int,
@Prfit_ctr_id Int
AS
/***********************************************************************          
This procedure deletes the trip link with workorder when the trip is deleted in w_trip.         
          
This sp is loaded to Plt_AI.          
          
09/12/2024 Subhrajyoti Created          
***********************************************************************/        
DECLARE
@workorder_status Char(1),
@submitted_flag Char(1),
@submitted_flag_changed Char(1) = 'F'

BEGIN
		
		SELECT @workorder_status = workorder_status,@submitted_flag = submitted_flag
		FROM WorkorderHeader
		WHERE workorder_id = @Workorder_id 
		AND company_id = @Company_id
		AND profit_ctr_id = @Prfit_ctr_id

		UPDATE WorkorderHeader
		SET workorder_status = 'V',
			trip_id = NULL
		WHERE workorder_id = @Workorder_id 
		AND company_id = @Company_id
		AND profit_ctr_id = @Prfit_ctr_id

 

		INSERT INTO WorkorderAudit (Company_id,profit_ctr_id,Workorder_id,resource_type, sequence_id, table_name,column_name,before_value,after_value,modified_by,date_modified) 
		VALUES (@Company_id,@Prfit_ctr_id,@Workorder_id,'O',1,'WorkorderHeader','workorder_status',@workorder_status,'V',@user_id,GETDATE())

		INSERT INTO WorkorderAudit (Company_id,profit_ctr_id,Workorder_id,resource_type, sequence_id, table_name,column_name,before_value,after_value,modified_by,date_modified) 
		VALUES (@Company_id,@Prfit_ctr_id,@Workorder_id,'O',1,'WorkorderHeader','trip_id',@trip_id,NULL,@user_id,GETDATE())


END
GO 
GRANT EXECUTE ON sp_stop_deletion TO EQAI

GO