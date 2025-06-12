CREATE PROCEDURE [dbo].[sp_labpack_saa_inspection]
	@webuser_id nvarchar(100),
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
-- Author:		NAGOOR MEERAN
-- Create date: 10 Sep 2020
-- Description:	This procedure is used to select saainspection for  webuser_id
-- Exec Stmt  : 

/*
	exec [dbo].[sp_labpack_saa_inspection]
	@webuser_id = 'lpxtestuser',
	@search = '',
	@start_date	='2019-08-24',
	@end_date='2020-12-03'	,
	@page  = 1,
	@perpage  = 15,
	@sort = 'contact_id',
	@customer_id_list = '',
	@maa_id_list = '',
	@saa_id_list = ''
*/
-- =============================================
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

   -- Avoid query plan caching:
declare @i_web_userid		varchar(100) = @webuser_id
	, @i_start_date	datetime =  convert(date, @start_date)
	, @i_end_date		datetime = convert(date, @end_date)
	, @i_search		varchar(max) =  @search
	, @i_sort			varchar(20) = @sort
	, @i_page			bigint = @page
	, @i_perpage		bigint = @perpage
	, @i_customer_id_list	varchar(max) = isnull(@customer_id_list, '')
    , @i_maa_id_list	varchar(max) = isnull(@maa_id_list, '')
	, @i_saa_id_list	varchar(max) = isnull(@saa_id_list, '')
	
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

declare @saa table (
	satelliteAccumulationArea_uid	bigint
)

if @i_saa_id_list <> ''
insert @saa select convert(bigint, row)
from dbo.fn_SplitXsvText(',', 1, @i_saa_id_list)
where row is not null

SELECT  saaInspection_uid,saaIns.satelliteAccumulationArea_uid,saa.Description,saaIns.customer_id,cst.cust_name,inspection_date,saaIns.added_by,saaIns.date_added,
saaIns.modified_by,saaIns.date_modified,0 total_count,'SAA' type,dbo.fn_labpack_get_saa_score(saaInspection_uid) score  into #tempSAAInspection FROM SAAInspection saaIns
LEFT JOIN customer cst on cst.customer_id=saaIns.customer_id
LEFT JOIN satelliteAccumulationArea saa on saa.satelliteAccumulationArea_uid=saaIns.satelliteAccumulationArea_uid
WHERE
1=1
	and 
	  (
        @i_customer_id_list = ''
        or
         (
			@i_customer_id_list <> ''
			and
			saaIns.customer_id in (select customer_id from @customer)
		 )
	   )
	   and 
	  (
        @i_maa_id_list = ''
        or
         (
			@i_maa_id_list <> ''
			and
			saa.mainAccumulationArea_uid in (select mainAccumulationArea_uid from @maa)
		 )
	   )
	    and 
	  (
        @i_saa_id_list = ''
        or
         (
			@i_saa_id_list <> ''
			and
			saaIns.satelliteAccumulationArea_uid in (select satelliteAccumulationArea_uid from @saa)
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
			saa.Description like '%'+ @i_search +'%'			
			)
		 )
		 )
	   AND  convert(date, saaIns.inspection_date)  BETWEEN  @i_start_date AND @i_end_date

	   
		declare @saaInspectionCount int = (select count(1) from #tempSAAInspection)	
	   update #tempSAAInspection set total_count = @saaInspectionCount 

	   
Select * from #tempSAAInspection ORDER BY 1 OFFSET @perpage * (@page - 1) ROWS FETCH NEXT @perpage ROWS ONLY;

DROP TABLE #tempSAAInspection
END



