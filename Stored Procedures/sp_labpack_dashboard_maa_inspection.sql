CREATE PROCEDURE sp_labpack_dashboard_maa_inspection 
	-- Add the parameters for the stored procedure here
	@customer_id_list VARCHAR(MAX) = '',
	@start_date	datetime,
	@end_date	datetime
AS
-- =============================================
-- Author:		SENTHIL KUMAR
-- Create date: 12/21/2020
-- Description:	To fetch MAA Inspection details
-- EXEC sp_labpack_dashboard_maa_inspection '583,13212','12/21/2019','12/21/2020'
-- =============================================
BEGIN
	SET NOCOUNT ON;
	 -- Avoid query plan caching:
	DECLARE @i_customer_id_list	VARCHAR(MAX) = ISNULL(@customer_id_list, '')
	, @i_start_date	datetime = convert(date,@start_date)
	, @i_end_date		datetime = convert(date, @end_date)
		
	DECLARE @customer TABLE (customer_id	BIGINT)
	IF @i_customer_id_list <> ''
	INSERT @customer SELECT CONVERT(BIGINT, ROW)
	FROM dbo.fn_SplitXsvText(',', 1, @i_customer_id_list)
	WHERE ROW IS NOT NULL
    
	SELECT convert(DATE,maa.Inspection_Date) DateAdded, count(*) Count FROM Maainspection maa 
	WHERE convert(DATE, maa.Inspection_Date) >= @i_start_date AND CONVERT(DATE, maa.Inspection_Date) <= @i_end_date
	AND (@i_customer_id_list = '' OR (@i_customer_id_list <> '' AND maa.customer_id IN (SELECT customer_id FROM @customer)))	
	GROUP BY  CONVERT(DATE, maa.Inspection_Date)
END
GO

