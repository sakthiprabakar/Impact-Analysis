
/************************************************************
Procedure    : sp_Invoice_Export
Database     : PLT_Image
Created      : Feb 07 2008 - Jonathan Broome
Description  : Populates an ImageExport table with information to be
	used in exporting images from InvoiceImage to filesystem and issues
	the user a "key" number to use when running the export script.

	INPUT:
		1. SQL Statement to run (must return only the image_id's to export)
		2. EQAI Logon Name (who's running this?)
		
	OUTPUT:
		1. A 14-digit time-stamp key that the Image Dump program
		will require that tells it which set of images to export.
	
sp_Invoice_Export 

************************************************************/
Create Procedure sp_Invoice_Export (
	@stmt			varchar(8000),
	@user_code		varchar(10)
)
AS

/*
Logic:

Declare a key for this run (date based, not unfriendly)
Check for the ImageExport table.  If it exists, perform housekeeping.  If it does not exist, create it.

*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @runtime datetime, @userkey varchar(20)
	set @runtime = getdate()
	set @userkey = convert(varchar(4), datepart(yyyy, @runtime)) +
		RIGHT('00' + convert(varchar(2), datepart(mm, @runtime)), 2) + 
		RIGHT('00' + convert(varchar(2), datepart(dd, @runtime)), 2) +
		RIGHT('00' + convert(varchar(2), datepart(hh, @runtime)), 2) +
		RIGHT('00' + convert(varchar(2), datepart(mi, @runtime)), 2) +
		RIGHT('00' + convert(varchar(2), datepart(ss, @runtime)), 2)
	
	IF NOT EXISTS (SELECT * FROM plt_image.dbo.sysobjects WHERE Name = 'ImageExport' AND xtype = 'U') BEGIN
		CREATE TABLE ImageExport (
			row_id INT NOT NULL IDENTITY,
			image_id INT NOT NULL,
			file_type VARCHAR(10),
			filename VARCHAR(250),
			process_flag INT,
			userkey VARCHAR(20) not null,
			date_added datetime,
			added_by varchar(10),
			page_number INT null
		)
		GRANT ALL ON ImageExport TO Public
	END
	ELSE -- Housekeeping:
		DELETE FROM ImageExport where date_added < dateadd(dd, -7, @runtime)

	CREATE TABLE #ImageExport (
		image_id INT,
		filename varchar(250) null,
		page_number int null
	)
	
	if charindex('page_number', @stmt) > 0
		EXEC( ' Insert #ImageExport select distinct image_id, filename, page_number from ( ' + @stmt + ' ) x')
	ELSE
		EXEC( ' Insert #ImageExport select distinct image_id, filename, null from ( ' + @stmt + ' ) x')
	
	update #ImageExport set filename = 'image_id_' + convert(varchar(50), image_id) where filename is null
	
	INSERT ImageExport (image_id, file_type, filename, process_flag, userkey, date_added, added_by, page_number)
	SELECT t.image_id, 'PDF', filename, 0, @userkey, @runtime, @user_code, t.page_number
	FROM #ImageExport t
	INNER JOIN InvoiceImage s on t.image_id = s.image_id
	ORDER BY filename, t.page_number
	
	SET NOCOUNT OFF
	
	Select @userkey as UserKey, count(*) as Images from ImageExport where userkey = @userkey


	SELECT t.image_id, s.file_type, filename, 0, @userkey, @runtime, @user_code, t.page_number
	FROM #ImageExport t
	INNER JOIN InvoiceImage s on t.image_id = s.image_id
	ORDER BY filename, t.page_number
END
GO

GRANT EXEC ON [dbo].[sp_Invoice_Export] TO COR_USER;
GO

