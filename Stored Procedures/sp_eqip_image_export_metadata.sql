
create procedure sp_eqip_image_export_metadata
	@export_id		int,
	@user_code		varchar(20),
	@permission_id	int,
	@report_log_id	int,
	@debug			int = 0
as

/* **************************************************************************************
sp_eqip_image_export_metadata

	Created to dump metadata from plt_export..EqipImageExportMeta to Excel

History:
	07/21/2015	JPB	Created
	
	---------------------------
	IMPORTANT !
	The queries MUST be in a single line or they fail.
	----------------------------
	
Example:

	exec sp_eqip_image_export_metadata 348, 'JONATHAN', 180, 331967, 0
	

************************************************************************************** */
if @debug > 0 select getdate(), 'Started'

	declare 
		@tmp_filename		varchar(100),
		@template_name		varchar(100),
		@tmp_desc			varchar(255),
		@tmp_debug			int = 0,
		@tablename			varchar(max),
		@file_date			varchar(40)
		
	set @file_date = convert(varchar(4), datepart(yyyy, getdate())) + '-' 
	+ right('00' + convert(varchar(2), datepart(mm, getdate())),2) + '-' 
	+ right('00' + convert(varchar(2), datepart(dd, getdate())),2) + '_'
	+ right('00' + convert(varchar(2), datepart(HH, getdate())),2) + '-' 
	+ right('00' + convert(varchar(2), datepart(n, getdate())),2) + '-' 
	+ right('00' + convert(varchar(2), datepart(ss, getdate())),2)

	select 
		@tmp_desc = 'Image Export Metafile',
		@tmp_filename = 'Image_Export_Metafile_' + @file_date + '_' + @user_code + '.xlsx',
		@template_name = 'Image_Export_Metafile.1',
		@tablename = 'SELECT site_code, generator_address, generator_city, generator_state, service_date, manifest, vendor, type_of_service, quantity, filename from plt_export..EqipImageExportMeta where export_id = ' + convert(varchar(20), @export_id)
		
	exec plt_export.dbo.sp_export_query_to_excel
		@table_name	= @tablename,
		@template	= @template_name,
		@filename	= @tmp_filename,
		@added_by	= @user_code,
		@export_desc = @tmp_desc,
		@report_log_id = @report_log_id,
		@debug = @tmp_debug


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_eqip_image_export_metadata] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_eqip_image_export_metadata] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_eqip_image_export_metadata] TO [EQAI]
    AS [dbo];

