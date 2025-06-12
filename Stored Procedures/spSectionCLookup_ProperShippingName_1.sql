
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
				
																
	Execution Statement	: EXEC spSectionCLookup_ProperShippingName 'M'

*************************************************************************************/

BEGIN

IF(@searchText!='')
BEGIN
	SELECT DOT_shipping_name, hazmat_flag, hazmat_class, sub_hazmat_class, UN_NA_flag,  packing_group, 

	ISNULL(UN_NA_flag,'')+CAST(ISNULL(UN_NA_number,'')AS VARCHAR) AS UN_NA_number ,
	ERG_number, ERG_suffix FROM DOTShippingLookup WITH(NOLOCK) 
	WHERE DOT_shipping_name LIKE '%'+@searchText+'%'
	 
END
END

GO

	GRANT EXEC ON [dbo].[spSectionCLookup_ProperShippingName] TO COR_USER;

GO