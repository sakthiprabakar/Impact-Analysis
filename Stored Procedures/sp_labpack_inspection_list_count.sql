CREATE PROCEDURE [dbo].[sp_labpack_inspection_list_count] 
	@webuser_id nvarchar(100),
	@search VARCHAR(200) = '',
	@type	varchar(max) = 'all',
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
-- Author:		SENTHIL KUMAR
-- Create date: 12/21/2020
-- Description:	To Fetch MAA / SAA Inspection list count
/*
exec [dbo].[sp_labpack_inspection_list_count]
	@webuser_id = 'lpxtestuser',
	@search = 'main',
	@start_date	='2019-08-24',
	@end_date='2020-12-03'	,
	@page  = 1,
	@perpage  = 100,
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



SET @perpage  = 999999999
DECLARE @all_count INT, @maa_count INT, @saa_count INT

		INSERT @Inspection
		EXEC [dbo].[sp_labpack_maa_inspection] @webuser_id,@search,@start_date,@end_date,@page,999999999,@sort,@customer_id_list,@maa_id_list
		SET @maa_count  = ISNULL((select Top 1 total_count from @Inspection WHERE type='MAA'),0)	

		INSERT @Inspection 
		EXEC [dbo].[sp_labpack_saa_inspection] @webuser_id,@search,@start_date,@end_date,@page,999999999,@sort,@customer_id_list,@maa_id_list,@saa_id_list
		SET @saa_count  = ISNULL((select Top 1 total_count from @Inspection WHERE type='SAA'),0)	

		SET @all_count = @saa_count+@maa_count

		SELECT @all_count all_count,@maa_count maa_count,@saa_count saa_count
END
