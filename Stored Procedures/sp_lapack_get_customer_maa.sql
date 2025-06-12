CREATE PROCEDURE sp_lapack_get_customer_maa
	-- Add the parameters for the stored procedure here
	@customer_id_list VARCHAR(MAX) = ''
AS
-- =============================================
-- Author:		SENTHIL KUMAR
-- Create date: 12/15/2020
-- Description:	To fetch MAA by customer
-- EXEC sp_lapack_get_customer_maa '1312'
-- =============================================
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	 -- Avoid query plan caching:
	DECLARE @i_customer_id_list	VARCHAR(MAX) = ISNULL(@customer_id_list, '')
		
	DECLARE @customer TABLE (customer_id	BIGINT)
	IF @i_customer_id_list <> ''
	INSERT @customer SELECT CONVERT(BIGINT, ROW)
	FROM dbo.fn_SplitXsvText(',', 1, @i_customer_id_list)
	WHERE ROW IS NOT NULL

    SELECT x.*,cmaa.customer_id
	FROM MainAccumulationArea x
	JOIN CustomerMAABucket cmaa ON cmaa.mainAccumulationArea_uid =x.mainAccumulationArea_uid
	WHERE x.Status='A' and 
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
