CREATE PROCEDURE [dbo].[sp_Countries]
	-- Add the parameters for the stored procedure here
	
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    select country_code, country_name from country where status = 'A'
	
END



 GO

GRANT EXECUTE ON [dbo].[sp_Countries] TO COR_USER;

GO