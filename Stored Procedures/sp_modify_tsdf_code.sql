CREATE PROCEDURE sp_modify_tsdf_code
	@TSDF_code_old	varchar(15), 
	@TSDF_code_new	varchar(15), 
	@update_type	int
AS

SET NOCOUNT ON

PRINT '--------------------------------------------------------'
PRINT 'Renaming ' + @TSDF_code_old + ' to ' + @TSDF_code_new + ' in all tables on ' + DB_NAME()
PRINT '--------------------------------------------------------'

UPDATE ContainerDestination SET location = @TSDF_code_new,
	modified_by = 'SA-TSDF', 
	date_modified = GETDATE() 
WHERE location = @TSDF_code_old
AND location_type = 'O'
PRINT 'Updated ' + CONVERT(varchar(10), @@ROWCOUNT) + ' record(s) in ContainerDestination (location)'

UPDATE ManifestPrint SET TSDF_code = @TSDF_code_new
WHERE TSDF_code = @TSDF_code_old
PRINT 'Updated ' + CONVERT(varchar(10), @@ROWCOUNT) + ' record(s) in ManifestPrint'

UPDATE ManifestPrintDetail SET TSDF_code = @TSDF_code_new
WHERE TSDF_code = @TSDF_code_old
PRINT 'Updated ' + CONVERT(varchar(10), @@ROWCOUNT) + ' record(s) in ManifestPrintDetail'

UPDATE Receipt SET TSDF_code = @TSDF_code_new,
	modified_by = 'SA-TSDF', 
	date_modified = GETDATE() 
WHERE TSDF_code = @TSDF_code_old
PRINT 'Updated ' + CONVERT(varchar(10), @@ROWCOUNT) + ' record(s) in Receipt (TSDF_code)'

UPDATE Receipt SET location = @TSDF_code_new,
	modified_by = 'SA-TSDF', 
	date_modified = GETDATE() 
WHERE location = @TSDF_code_old
AND location_type = 'O'
PRINT 'Updated ' + CONVERT(varchar(10), @@ROWCOUNT) + ' record(s) in Receipt (location)'

UPDATE Schedule SET TSDF_code = @TSDF_code_new,
	modified_by = 'SA-TSDF', 
	date_modified = GETDATE() 
WHERE TSDF_code = @TSDF_code_old
PRINT 'Updated ' + CONVERT(varchar(10), @@ROWCOUNT) + ' record(s) in Schedule'

UPDATE WorkOrderDetail SET TSDF_code = @TSDF_code_new,
	modified_by = 'SA-TSDF', 
	date_modified = GETDATE() 
WHERE TSDF_code = @TSDF_code_old
PRINT 'Updated ' + CONVERT(varchar(10), @@ROWCOUNT) + ' record(s) in WorkOrderDetail'

UPDATE XMLTransactionDisp SET TSDF_code = @TSDF_code_new
WHERE TSDF_code = @TSDF_code_old
PRINT 'Updated ' + CONVERT(varchar(10), @@ROWCOUNT) + ' record(s) in XMLTransactionDisp'

UPDATE XMLValidateTSDF SET TSDF_code = @TSDF_code_new
WHERE TSDF_code = @TSDF_code_old
PRINT 'Updated ' + CONVERT(varchar(10), @@ROWCOUNT) + ' record(s) in XMLValidateTSDF'

UPDATE XMLValidateWasteStream SET TSDF_code = @TSDF_code_new
WHERE TSDF_code = @TSDF_code_old
PRINT 'Updated ' + CONVERT(varchar(10), @@ROWCOUNT) + ' record(s) in XMLValidateWasteStream'

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_modify_tsdf_code] TO [EQAI]
    AS [dbo];

