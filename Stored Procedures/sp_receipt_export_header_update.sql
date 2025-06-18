CREATE OR ALTER PROCEDURE [dbo].[sp_receipt_export_header_update] 
	@export_from_us_flag CHAR(1),            
    @date_leaving_us DATETIME,
    @modified_by VARCHAR(8),
	@date_modified DATETIME,
    @manifest_canada VARCHAR(40),		
    @portofentry_uid INT,
	@company_id INT,
	@profit_ctr_id INT,
    @receipt_id INT,
	@exporter_same_as_generator_flag CHAR(1),
	@exporter_location_uid INT,
	@transporter_sequence_id INT
AS 
/***********************************************************************************  
sp_receipt_export_header_update  
Loads to : PLT_AI    
Modifications:    
04/14/2025 Umesh Rally US146409 - Created     
    
-- For Checking if the trigger was created successfully  
EXECUTE sp_receipt_export_header_update 'F', '2025-04-14 09:03:21.487', 'yadavum', '2025-04-14 09:03:21.487', 'Testing1234', 330,21,0,2246629
***********************************************************************************/    
BEGIN
	UPDATE [dbo].[Receipt]
	SET manifest_canada = @manifest_canada,
		modified_by = @modified_by,   
		date_modified = @date_modified
	WHERE  company_id = @company_id 
		AND profit_ctr_id = @profit_ctr_id
		AND receipt_id = @receipt_id
		AND 1 = (CASE WHEN manifest_canada = @manifest_canada THEN 0 ELSE 1 END)

	UPDATE [dbo].[ReceiptDiscrepancy]
	SET    
		export_from_us_flag = @export_from_us_flag,            
		date_leaving_us = @date_leaving_us,
		modified_by = @modified_by,   
		date_modified = date_modified,		
		portofentry_uid = @portofentry_uid,
		exporter_same_as_generator_flag = @exporter_same_as_generator_flag,
		exporter_location_uid = @exporter_location_uid,
		transporter_sequence_id = @transporter_sequence_id
	WHERE  company_id = @company_id 
		AND profit_ctr_id = @profit_ctr_id
		AND receipt_id = @receipt_id
		AND 1 = CASE WHEN export_from_us_flag = @export_from_us_flag 
					AND date_leaving_us = @date_leaving_us 
					AND portofentry_uid = @portofentry_uid 
					AND exporter_same_as_generator_flag = @exporter_same_as_generator_flag
					AND exporter_location_uid = @exporter_location_uid
					AND transporter_sequence_id = @transporter_sequence_id THEN 0
				ELSE 1 
				END
END	
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_receipt_export_header_update] TO [EQAI]
GO
