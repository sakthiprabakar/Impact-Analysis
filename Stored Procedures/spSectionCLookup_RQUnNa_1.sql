
CREATE PROCEDURE [dbo].[spSectionCLookup_RQUnNa]

@searchText varchar(200)=''
AS
BEGIN
IF(@searchText!='')
BEGIN

	-- RQ -UN/NA #
	SELECT DISTINCT UN_NA_flag, UN_NA_number,(UN_NA_Flag+ CONVERT(varchar(10), UN_NA_number) + ' - '+ DOT_Shipping_name) as DOT_Shipping_name FROM DOTShippingLookup WITH(NOLOCK) 
	WHERE  UN_NA_Flag+ CONVERT(varchar(10), UN_NA_number) LIKE '%'+@searchText+'%' OR DOT_Shipping_name LIKE '%'+@searchText+'%'
		   AND UN_NA_number IS NOT NULL 
	ORDER BY UN_NA_flag, UN_NA_number  
	
	 
END
END