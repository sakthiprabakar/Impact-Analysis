-- =============================================
-- Author:		Dinesh
-- Create date: 29th Jan, 2019
-- Description:	Get Nuclide List
-- EXEC sp_COR_GetNuclides
-- =============================================
CREATE PROCEDURE sp_COR_GetNuclides
	
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    -- Insert statements for procedure here
	-- CAST(CAST(A2CI  AS FLOAT) AS bigint)as A2CI
	SELECT NuclideId, Nuclide FROM NuclideRef
END
GO

grant execute on sp_COR_GetNuclides to eqweb
go
