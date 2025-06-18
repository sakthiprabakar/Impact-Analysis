CREATE  PROCEDURE [dbo].[sp_receipt_import_header_update] 
	@import_to_us_flag CHAR(1),
	@movement_document VARCHAR(40),
	@modified_by VARCHAR(8), 
	@date_modified DATETIME,
	@portofentry_uid INT,
	@importer_location_uid INT,
	@importer_tsdf_flag CHAR(1),
   	@company_id INT,
	@profit_ctr_id INT,
    @receipt_id INT		
AS 

/***************************************************************
 *sp_receipt_import_header_update
 *
 *This procedure updates the Header (Import Tab) for Inbound Receipts
 *
 * 04/11/2025 Anukool - Rally #US146074 - Inbound Receipt > Add New "Import" Tab
 * 04/23/2025 Anukool - Rally #US146417 - Inbound Receipt > "Import" Tab > Additional/New Fields

EXEC sp_receipt_import_header_update 'T', '', 'Test Document', 'KUMARAN2', '15 Apr 2025', '31', 21, 0, 2239900
****************************************************************/

BEGIN

UPDATE [dbo].[ReceiptDiscrepancy]
		SET import_to_us_flag = @import_to_us_flag            
		, portofentry_uid = @portofentry_uid
		, importer_location_uid = @importer_location_uid
		, importer_tsdf_flag = @importer_tsdf_flag
		, modified_by = @modified_by  
		, date_modified = @date_modified
	WHERE  company_id = @company_id 
		AND profit_ctr_id = @profit_ctr_id
		AND receipt_id = @receipt_id
		AND 1 = CASE WHEN import_to_us_flag = @import_to_us_flag 
			AND importer_location_uid = @importer_location_uid 
			AND importer_tsdf_flag = @importer_tsdf_flag 
			AND portofentry_uid = @portofentry_uid THEN 0
		ELSE 1 
		END

	UPDATE [dbo].[Receipt]
		SET movement_document = @movement_document
		WHERE  company_id = @company_id 
		AND profit_ctr_id = @profit_ctr_id
		AND receipt_id = @receipt_id
		AND 1 = (CASE WHEN movement_document = @movement_document THEN 0 ELSE 1 END)
	
END	
GO

GRANT EXECUTE
    ON OBJECT::[dbo].[sp_receipt_import_header_update] TO [EQAI]
GO
 