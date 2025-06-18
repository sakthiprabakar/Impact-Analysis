CREATE OR ALTER PROCEDURE [dbo].[sp_receipt_export_header_insert] 
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
sp_receipt_export_header_insert  
Loads to : PLT_AI    
Modifications:    
04/14/2025 Umesh Rally US146409 - Created    
    
-- For Checking if the trigger was created successfully  
EXECUTE sp_receipt_export_header_insert 'F', '2025-04-14 09:03:21.487', 'yadavum', '2025-04-14 09:03:21.487', 'Testing123', 330,21,0,2246629
***********************************************************************************/    
BEGIN
	UPDATE [dbo].[Receipt]
	SET manifest_canada = @manifest_canada,
		modified_by = @modified_by,   
		date_modified = @date_modified
	WHERE  company_id = @company_id 
		AND profit_ctr_id = @profit_ctr_id
		AND receipt_id = @receipt_id

	INSERT INTO [dbo].[ReceiptDiscrepancy]
		(company_id, 
		profit_ctr_id, 
		receipt_id, 
		export_from_us_flag, 
		date_leaving_us, 
		portofentry_uid,
		exporter_same_as_generator_flag,
		exporter_location_uid,
		transporter_sequence_id,
		added_by, 
		date_added,
		modified_by,
		date_modified,
		discrepancy_qty_flag,
		discrepancy_type_flag,
		discrepancy_residue_flag,
		discrepancy_part_reject_flag,
		discrepancy_full_reject_flag,
		import_to_us_flag) 
	VALUES (@company_id, 
		@profit_ctr_id,
		@receipt_id,
		@export_from_us_flag,
		@date_leaving_us,
		@portofentry_uid,
		@exporter_same_as_generator_flag,
		@exporter_location_uid,
		@transporter_sequence_id,
		@modified_by,
		@date_modified,
		@modified_by,
		@date_modified,
		'F','F','F','F','F','F')	
END	
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_receipt_export_header_insert] TO [EQAI]
GO
