CREATE PROCEDURE sp_lapack_get_customer_saa
	-- Add the parameters for the stored procedure here
	@customer_id_list VARCHAR(MAX) = ''
AS
-- =============================================
-- Author:		SENTHIL KUMAR
-- Create date: 12/15/2020
-- Description:	To fetch SAA by customer
-- EXEC sp_lapack_get_customer_saa '13212,583'
-- =============================================
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    -- Insert statements for procedure here
	 -- Avoid query plan caching:
	DECLARE @i_customer_id_list	VARCHAR(MAX) = ISNULL(@customer_id_list, '')
		
	DECLARE @customer TABLE (customer_id	BIGINT)
	IF @i_customer_id_list <> ''
	INSERT @customer SELECT CONVERT(BIGINT, ROW)
	FROM dbo.fn_SplitXsvText(',', 1, @i_customer_id_list)
	WHERE ROW IS NOT NULL

    SELECT saa.*,maa.mainAccumulationArea_code,maa.description as maaDescription,cmaa.customer_id
	FROM SatelliteAccumulationArea saa
	JOIN MainAccumulationArea maa ON maa.mainAccumulationArea_uid =saa.mainAccumulationArea_uid and maa.Status='A'
	JOIN CustomerMAABucket cmaa ON cmaa.mainAccumulationArea_uid =maa.mainAccumulationArea_uid
	WHERE saa.Status='A' and 
	  (
        @i_customer_id_list = ''
        or
         (
			@i_customer_id_list <> ''
			and
			cmaa.customer_id in (select customer_id from @customer)
		 )				
	   )	
END
GO

