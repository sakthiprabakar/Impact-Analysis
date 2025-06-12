CREATE PROCEDURE [dbo].[sp_labpack_inspection_list]
	@webuser_id nvarchar(100),
	@type	varchar(max) = 'all',
	@search VARCHAR(200) = '',
	@start_date	datetime,
	@end_date		datetime,
	@page int = 1,
	@perpage int = 10,
	@sort nvarchar(100) = 'first_name',
	@customer_id_list nvarchar(max) = '',
	@maa_id_list nvarchar(max) = '',
	@saa_id_list nvarchar(max) = ''
AS
-- =============================================
-- Author:		Senthil Kumar
-- Create date: 12/21/2020
-- Description:	To Fetch MAA / SAA Inspection list
/*
exec [dbo].[sp_labpack_inspection_list]
	@webuser_id = 'lpxtestuser',
	@type='all',
	@search = '',
	@start_date	='2019-08-24',
	@end_date='2020-12-03'	,
	@page  = 1,
	@perpage  = 14,
	@sort = 'contact_id',
	@customer_id_list = '13212',
	@maa_id_list = '',
	@saa_id_list = '' 
*/
-- =============================================
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	DECLARE @Inspection TABLE(	
	Inspection_uid INT,
	AccumulationArea_uid INT,
	Description nvarchar(50),
	customer_id int,
	cust_name nvarchar(75),
	inspection_date datetime,
	added_by nvarchar(100),
	date_added datetime,
	modified_by nvarchar(100),
	date_modified datetime,
	total_count int,
	type nvarchar(3),
	score int)

	

	IF @type = 'all' 
	BEGIN
		INSERT @Inspection
		EXEC [dbo].[sp_labpack_maa_inspection] @webuser_id,@search,@start_date,@end_date,@page,999999999,@sort,@customer_id_list,@maa_id_list
		DECLARE @maaInspectionCount int = (select Top 1 total_count from @Inspection WHERE type='MAA')	

		INSERT @Inspection 
		EXEC [dbo].[sp_labpack_saa_inspection] @webuser_id,@search,@start_date,@end_date,@page,999999999,@sort,@customer_id_list,@maa_id_list,@saa_id_list
		DECLARE @saaInspectionCount int = (select Top 1 total_count from @Inspection WHERE type='SAA')	
	
		UPDATE @Inspection SET total_count= ISNULL(@saaInspectionCount,0)+ ISNULL(@maaInspectionCount,0)
	END
	ELSE IF  @type = 'maa' 
	BEGIN
		INSERT @Inspection
		EXEC [dbo].[sp_labpack_maa_inspection] @webuser_id,@search,@start_date,@end_date,@page,@perpage,@sort,@customer_id_list,@maa_id_list
	END
	ELSE IF   @type = 'saa' 
	BEGIN
		INSERT @Inspection
		EXEC [dbo].[sp_labpack_saa_inspection] @webuser_id,@search,@start_date,@end_date,@page,@perpage,@sort,@customer_id_list,@maa_id_list,@saa_id_list
	END

	SELECT * FROM @Inspection ORDER BY date_added DESC OFFSET @perpage * (@page - 1) ROWS FETCH NEXT @perpage ROWS ONLY;
END
