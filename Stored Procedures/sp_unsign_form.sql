/**************************************************************************************
sp_unsign_form 4093, 1, 0
sp_unsign_form 4098, 1, 0
sp_unsign_form 4191, 1, 0
sp_unsign_form 4193, 1, 0
sp_unsign_form 4202, 2, 0
sp_unsign_form 4204, 1, 0
sp_unsign_form 4205, 1, 0
sp_unsign_form 4206, 1, 0
sp_unsign_form 4219, 1, 0
sp_unsign_form 4257, 1, 0
sp_unsign_form 4258, 1, 0
sp_unsign_form 4222, 1, 0

select * from formwcr where customer_id IN (888885, 888886, 888887) order by form_id
SELECT form_id, link_type, url_id FROM Link WHERE url_id IN ('383571409444240', '414622449259214', '359668944432194', '002717963242043', '942151467982199')
**************************************************************************************/
CREATE PROCEDURE sp_unsign_form
	@form_id	int,
	@revision_id	int,
	@debug		int

AS
DECLARE	@form_type	varchar(10),
	@locked		char(1),
	@sql		varchar(8000),
	@image_id	int,
	@scan_server	varchar(20),
	@scan_db	varchar(20)

IF @debug = 1
BEGIN
    PRINT '                                                               /*******************\'
    PRINT '                                                               |   DEBUG MODE ON   |'
    PRINT '                                                               |  NO DATA CHANGED  |'
    PRINT '                                                               \*******************/'
    PRINT ''
END


------------------------------------------------------
-- Get form type from FormHeader
------------------------------------------------------
SELECT 	@form_type = UPPER(type),
	@locked = locked FROM FormHeader WHERE form_id = @form_id AND revision_id = @revision_id

IF @debug = 1
BEGIN
PRINT '@form_id:  ' + CONVERT(varchar(10), @form_id)
PRINT '@revision_id:  ' + CONVERT(varchar(10), @revision_id)
PRINT '@form_type:  ' + @form_type
PRINT '@locked:  ' + @locked
PRINT ''
END

IF @locked = 'L' OR @locked = 'M'
BEGIN
    PRINT '/*****************************************************************************/'
    PRINT 'Form ' + CONVERT(varchar(10), @form_id) + '-' + CONVERT(varchar(10), @revision_id) + ' is signed.'
    PRINT 'It will now be un-signed.'
    PRINT '/*****************************************************************************/'
    PRINT ''
END
ELSE
BEGIN
    PRINT '/*****************************************************************************/'
    PRINT 'Form ' + CONVERT(varchar(10), @form_id) + '-' + CONVERT(varchar(10), @revision_id) + ' is not signed.'
    PRINT '/*****************************************************************************/'
    GOTO BOTTOM
END


SELECT locked, * FROM FormHeader WHERE form_id = @form_id AND revision_id = @revision_id
SELECT locked, * FROM FormHeaderDistinct WHERE form_id = @form_id AND revision_id = @revision_id

------------------------------------------------------
-- UPDATE FormXX table to set back to unsigned.
------------------------------------------------------
PRINT 'Updating Form' + @form_type + ' table'
PRINT ''
SET @sql = 'UPDATE Form' + @form_type + ' SET locked = ''U'',
	signing_name = NULL,
	signing_company = NULL,
	signing_title = NULL,
	signing_date = NULL
	WHERE form_id = ' + CONVERT(varchar(10), @form_id) + ' AND revision_id = ' + CONVERT(varchar(10), @revision_id)
PRINT '@sql:  ' + @sql
IF @debug = 0
    EXEC (@sql)


------------------------------------------------------
-- DELETE from FormSignature
------------------------------------------------------
PRINT 'Deleting from FormSignature'
PRINT ''
IF @debug = 0
    DELETE FROM FormSignature WHERE form_id = @form_id AND revision_id = @revision_id


------------------------------------------------------
-- Get image ID from Scan
------------------------------------------------------
-- SELECT * FROM plt_image..Scan
PRINT 'Selecting from plt_image..Scan'
PRINT ''
SELECT @image_id = image_id FROM plt_image..Scan WHERE form_id = @form_id AND revision_id = @revision_id AND file_type = 'PDF'


------------------------------------------------------
-- Get server and database from ScanXDatabase
------------------------------------------------------
-- SELECT * FROM plt_image..ScanXDatabase
PRINT 'Selecting from plt_image..ScanXDatabase'
PRINT ''
SELECT @scan_server = scan_server, @scan_db = scan_database FROM plt_image..ScanXDatabase WHERE image_id = @image_id


------------------------------------------------------
-- DELETE from Scan
------------------------------------------------------
PRINT 'Deleting from Scan'
PRINT ''
IF @debug = 0
    DELETE FROM plt_image..Scan WHERE form_id = @form_id AND revision_id = @revision_id AND file_type = 'PDF'


------------------------------------------------------
-- DELETE from ScanImage
------------------------------------------------------
SET @sql = 'DELETE FROM ' + @scan_server + '.' + @scan_db + '.dbo.ScanImage WHERE image_id = ' + CONVERT(varchar(10), @image_id)
PRINT '@sql:  ' + @sql

IF @debug = 0
    EXEC (@sql)
BOTTOM:

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_unsign_form] TO [EQAI]
    AS [dbo];

