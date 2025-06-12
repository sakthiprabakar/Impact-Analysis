CREATE PROCEDURE [dbo].[sp_COR_Diposal_Facility]
	@search nvarchar(100) = ''
AS

/*
	
	Author		:	Dineshkumar.K
	Date		:	28 March 2020
	Object		:	Stored Procedure

	EXEC sp_COR_Diposal_Facility @seach

	EXEC sp_COR_Diposal_Facility ''

*/

BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    -- Insert statements for procedure here
	--Select * from (
	--SELECT 'USECOLOGYNV' as TSDF_code, 'US ECOLOGY NEVADA' as TSDF_name
	--UNION
	--SELECT 'USECOLOGYID' as TSDF_code, 'US ECOLOGY IDAHO' as TSDF_name
	--UNION
	--SELECT 'USECOLOGYTX' as TSDF_code, 'US ECOLOGY TEXAS' as TSDF_name
	--UNION
	--SELECT 'USECOLOGYMGN' as TSDF_code, 'US ECOLOGY MICHIGAN' as TSDF_name) a

	select tsdf_code as TSDF_code, use_shortname as TSDF_name from TSDF
			where tsdf_code IN ('USET', 'USEI', 'EQMDI','USNV')
END
GO

	GRANT EXECUTE ON [dbo].[sp_COR_Diposal_Facility] TO COR_USER;

GO
