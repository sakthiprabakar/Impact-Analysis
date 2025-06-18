CREATE  PROCEDURE [dbo].[sp_receipt_import_header_insert] 
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
 *sp_receipt_import_header_insert
 *
 *This procedure inserts the Header (Import Tab) for Inbound Receipts
 *
 * 04/14/2025 Anukool - Rally #US146074 - Inbound Receipt > Add New "Import" Tab
 * 04/24/2025 Anukool - Rally #US146417 - Inbound Receipt > "Import" Tab > Additional/New Fields

EXEC sp_receipt_import_header_insert 'T', 'Test Document', 'KUMARAN2', '15 Apr 2025', '31', 21, 0, 2239900 
****************************************************************/
BEGIN
	UPDATE [dbo].[Receipt]
	SET movement_document = @movement_document
WHERE  company_id = @company_id 
	AND profit_ctr_id = @profit_ctr_id
	AND receipt_id = @receipt_id

	INSERT INTO [dbo].[ReceiptDiscrepancy]
		(
		company_id
		, profit_ctr_id 
		, receipt_id 
		, import_to_us_flag 
		, portofentry_uid
		, export_from_us_flag
		, discrepancy_qty_flag
		, discrepancy_type_flag
		, discrepancy_residue_flag
		, discrepancy_part_reject_flag
		, discrepancy_full_reject_flag
		, importer_tsdf_flag
		, importer_location_uid
		, added_by 
		, date_added
		, modified_by
		,date_modified
		) 
	VALUES 
		(
		@company_id 
		, @profit_ctr_id
		, @receipt_id
		, @import_to_us_flag
		, @portofentry_uid
		, 'F'
		, 'F'
		, 'F'
		, 'F'
		, 'F'
		, 'F'
		, @importer_tsdf_flag
		, @importer_location_uid
		, @modified_by
		, @date_modified
		, @modified_by
		, @date_modified
		)	
END	
GO

GRANT EXECUTE
    ON OBJECT::[dbo].[sp_receipt_import_header_insert] TO [EQAI]
GO
 


