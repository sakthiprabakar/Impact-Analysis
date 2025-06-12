CREATE PROCEDURE [dbo].[spSectionCLookup_RQUnNa]
	@searchText varchar(200)=''
AS
BEGIN

/*
EXEC [spSectionCLookup_RQUnNa] 'UN'
*/

IF(@searchText!='')
	BEGIN

		-- RQ -UN/NA #
		SELECT DISTINCT UN_NA_flag, UN_NA_number,
		--(UN_NA_Flag+ CONVERT(varchar(10), 
		-- UN_NA_number) + ' - '+ 
		DOT_Shipping_name as doT_shipping_name, 
		--(UN_NA_Flag+ CONVERT(varchar(10), UN_NA_number)) as [Description] 
		 ISNULL(UN_NA_flag, '') + right('0000' + isnull(convert(varchar(10), UN_NA_number), ''), 4) AS [Description],
		 hazmat_flag, hazmat_class, sub_hazmat_class,erG_number,erG_suffix, 
		 --case when LEN(packing_group) = 0 then 'N/A' else packing_group end 
		 packing_group
		FROM DOTShippingLookup WITH(NOLOCK) 
		WHERE 
		-- UN_NA_Flag+ CONVERT(varchar(10), UN_NA_number) LIKE '%'+@searchText+'%' OR DOT_Shipping_name LIKE '%'+@searchText+'%'
		UN_NA_Flag+ right('0000' + isnull(convert(varchar(10), UN_NA_number), ''), 4) LIKE '%'+@searchText+'%'
		 -- OR DOT_Shipping_name LIKE '%'+@searchText+'%'
		AND UN_NA_number IS NOT NULL 
		ORDER BY UN_NA_flag, UN_NA_number  		 
	END
END

GO

	GRANT EXEC ON [dbo].[spSectionCLookup_RQUnNa] TO COR_USER;

GO