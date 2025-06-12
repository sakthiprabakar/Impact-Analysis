CREATE PROCEDURE [dbo].[spSectionCLookup_ProperShippingName]

@searchText varchar(200)=''
AS


/***********************************************************************************

	Author		: Dinesh
	Updated On	: 25-Feb-2019
	Type		: Store Procedure 
	Object Name	: [dbo].[spSectionCLookup_ProperShippingName]

	Description	: 
                Procedure to get Shipping name
				

	Input		:
				@searchText
				
																
	Execution Statement	: EXEC spSectionCLookup_ProperShippingName 'Propylene'

*************************************************************************************/

	BEGIN

	IF(@searchText!='')
	BEGIN
		SELECT LEFT(DOT_shipping_name+'[see', CHARINDEX('[see',DOT_shipping_name+'[see')-1) AS DOT_shipping_name, hazmat_flag, hazmat_class, sub_hazmat_class, UN_NA_flag, 
		--case when len(packing_group) > 0 then packing_group else'N/A' end as 
		packing_group, UN_NA_number,
		--ISNULL(UN_NA_flag,'')+CAST(ISNULL(UN_NA_number,'')AS VARCHAR) AS [Description] ,
		 ISNULL(UN_NA_flag, '') + right('0000' + isnull(convert(varchar(10), UN_NA_number), ''), 4) AS [Description],
		ERG_number, ERG_suffix FROM DOTShippingLookup WITH(NOLOCK) 
		WHERE DOT_shipping_name LIKE '%'+@searchText+'%'
	 
	END
END

GO

	GRANT EXEC ON [dbo].[spSectionCLookup_ProperShippingName] TO COR_USER;

GO