USE PLT_AI

GO

	DROP PROC IF EXISTS sp_Subcategory_Lookup

GO

CREATE PROCEDURE [dbo].[sp_Subcategory_Lookup]
 
@searchText varchar(200)=''
AS


/* ******************************************************************
Subcategory Lookup

	Updated By:  Dineshkumar
	Updated On:  19 Oct 2022

inputs 
	
	searchText

Returns

ldr_subcategory_id
status
short_desc
long_desc


Samples:
EXEC [dbo].[sp_Subcategory_Lookup] '310'

****************************************************************** */

BEGIN

    SELECT  subcategory_id AS ldr_subcategory_id, status,SUBSTRING (short_desc ,1 , 4) waste_code , short_desc,long_desc FROM dbo.LDRSubcategory WITH(NOLOCK) 
    WHERE Status ='A' AND (ISNULL(@searchText, '') = '' OR (short_desc LIKE 'D%' AND short_desc LIKE '%' + @searchText + '%'))
  
END

GO

GRANT EXEC ON [dbo].[sp_Subcategory_Lookup] TO COR_USER;

GO