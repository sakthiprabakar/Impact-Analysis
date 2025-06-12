CREATE PROCEDURE [dbo].[sp_COR_RadioactiveTSDFLookup] 	
@search	nvarchar(100) = ''
AS

-- =============================================
/*

	 Author			: Dineshkumar
	 Create date	: 3rd April,2019
	 Description	: Radioactive TSDF Lookup

	 Input:
		@search

	Exec Stmt:
			EXEC sp_COR_RadioactiveTSDFLookup @search

			EXEC sp_COR_RadioactiveTSDFLookup
			EXEC sp_COR_RadioactiveTSDFLookup 'GLR RECYCLING'
			EXEC sp_COR_RadioactiveTSDFLookup 'ILD980700751'

*/
-- =============================================

BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	SELECT * FROM TSDF WHERE TSDF_status = 'A' AND 
	(ISNULL(@search,'') = '' OR TSDF_code like '%'+ @search + '%' OR TSDF_name like '%'+ @search + '%'
	OR TSDF_EPA_ID like '%'+ @search + '%')
   
END
GRANT EXECUTE ON [dbo].[sp_COR_RadioactiveTSDFLookup] TO COR_USER;

GO