CREATE PROCEDURE [dbo].[sp_labpack_maa_inspection]
	@webuser_id nvarchar(100),
	@search VARCHAR(200) = '',
	@start_date	datetime,
	@end_date		datetime,
	@page int = 1,
	@perpage int = 10,
	@sort nvarchar(100) = 'first_name',
	@customer_id_list nvarchar(max) = '',
	@maa_id_list nvarchar(max) = ''
	
AS
-- =============================================
-- Author:		SENTHIL KUMAR
-- Create date: 10 Sep 2020
-- Description:	This procedure is used to select insepection for  webuser_id
-- Exec Stmt  : 

/*
	exec [dbo].[sp_labpack_maa_inspection]
	@webuser_id = 'nyswyn100',
	@search = '',
	@start_date	='2020-10-30',
	@end_date='2020-12-30'	,
	@page  = 1,
	@perpage  = 15,
	@sort = 'contact_id',
	@customer_id_list = '583,13212',
	@maa_id_list = ''
*/
-- =============================================
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

   -- Avoid query plan caching:
declare @i_web_userid		varchar(100) = @webuser_id
	, @i_start_date	datetime = convert(date,@start_date)
	, @i_end_date		datetime = convert(date, @end_date)
	, @i_search		varchar(max) = @search
	, @i_sort			varchar(20) = @sort
	, @i_page			bigint = @page
	, @i_perpage		bigint = @perpage
	, @i_customer_id_list	varchar(max) = isnull(@customer_id_list, '')
    , @i_maa_id_list	varchar(max) = isnull(@maa_id_list, '')

	
declare @customer table (
	customer_id	bigint
)

if @i_customer_id_list <> ''
insert @customer select convert(bigint, row)
from dbo.fn_SplitXsvText(',', 1, @i_customer_id_list)
where row is not null


declare @maa table (
	mainAccumulationArea_uid	bigint
)

if @i_maa_id_list <> ''
insert @maa select convert(bigint, row)
from dbo.fn_SplitXsvText(',', 1, @i_maa_id_list)
where row is not null


SELECT  maaInspection_uid,maaIns.mainAccumulationArea_uid,maa.Description, maaIns.customer_id,cst.cust_name,inspection_date,
--additional_observation,name,sign,sign_date,
maaIns.added_by,maaIns.date_added,
maaIns.modified_by,maaIns.date_modified,0 total_count,'MAA' type,dbo.fn_labpack_get_maa_score(maaInspection_uid) score into #tempMAAInspection FROM MAAInspection maaIns
LEFT JOIN customer cst on cst.customer_id=maaIns.customer_id
LEFT JOIN mainAccumulationArea maa on maa.mainAccumulationArea_uid=maaIns.mainAccumulationArea_uid
WHERE
1=1
	and 
	  (
        @i_customer_id_list = ''
        or
         (
			@i_customer_id_list <> ''
			and
			maaIns.customer_id in (select customer_id from @customer)
		 )				
	   )	   
	   and 
	  (
        @i_maa_id_list = ''
        or
         (
			@i_maa_id_list <> ''
			and
			maaIns.mainAccumulationArea_uid in (select mainAccumulationArea_uid from @maa)
		 )
	   )
	   and
	   (
	    @i_search = ''
		 or
		 (
			@i_search <> ''
			and
			(
			cst.cust_name like '%'+ @i_search +'%'
			or
			maa.Description like '%'+ @i_search +'%'
			)
		 )
		 )
	   AND convert(date, maaIns.inspection_date) BETWEEN @i_start_date AND @i_end_date

	   
		declare @maaInspectionCount int = (select count(1) from #tempMAAInspection)	
	   update #tempMAAInspection set total_count = @maaInspectionCount 

	   
Select * from #tempMAAInspection ORDER BY 1 OFFSET @perpage * (@page - 1) ROWS FETCH NEXT @perpage ROWS ONLY;

DROP TABLE #tempMAAInspection
END
