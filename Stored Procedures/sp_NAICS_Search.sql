
-- =============================================
-- Author:		Dinesh
-- Create date:  10-Dec-2018
-- Description:	This procedure is used to NAICS Search 
/* 
	DECLARE @SearchNAICs NVARCHAR(100)= 'Wheat Farming'
	EXEC sp_NAICS_Search @SearchNAICs
*/
-- =============================================
CREATE PROCEDURE [dbo].[sp_NAICS_Search]
	-- Add the parameters for the stored procedure here
	@SearchNAICs VARCHAR(150)
AS
/* ******************************************************************

To search NAICS code

inputs 
	
	SearchNAICs

Returns

	NAICS_code
	description
	added_by

Samples:
 EXEC sp_NAICS_Search 'Wheat Farming'

****************************************************************** */
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;    
		SELECT NAICS_code,CONCAT(NAICS_code,' - ',description) as description,added_by,modified_by,date_modified FROM dbo.NAICSCode WHERE NAICS_code LIKE '%' + @SearchNAICs +'%' OR [description] LIKE '%'+ @SearchNAICs + '%'

		
END

GO 

GRANT EXEC ON [dbo].[sp_NAICS_Search] TO COR_USER;

GO
