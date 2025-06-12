-- =============================================
-- Author:		SENTHIL KUMAR
-- Create date: 02/18/2020
-- Description:	To fetch customer list based on labpack flag

-- EXEC sp_labpack_related_customer 'flo'
-- =============================================
CREATE PROCEDURE [dbo].[sp_labpack_related_customer]
	-- Add the parameters for the stored procedure here
	@search			varchar(100) = '',
	@sort			varchar(20) = '',
	@page			int = 1,
	@perpage		int = 200
	
AS
BEGIN

	SET NOCOUNT ON;
	
-- avoid query plan caching:
DECLARE @i_search		varchar(100) = isnull(@search, '')

    
	SELECT  customer_ID ,cust_name, customer_type ,cust_addr1 ,
	cust_addr2,cust_addr3,cust_city,cust_state,
	cust_zip_code,cust_country,cust_phone  FROM customer WHERE customer_id in(
	--SELECT DISTINCT(cus.customer_id) FROM WorkOrderHeader woh
	--LEFT JOIN customer cus ON woh.customer_ID= cus.customer_ID
	--WHERE trip_id IN(SELECT trip_id FROM tripheader WHERE lab_pack_flag ='T')) AND cust_status='A'
	select distinct(cus.customer_id) from WorkOrderHeader woh
	left join customer cus on woh.customer_ID= cus.customer_ID and  cust_status='A') 
	AND @i_search <> '' AND cust_name like '%' + @i_search + '%'

END
