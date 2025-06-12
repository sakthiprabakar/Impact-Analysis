CREATE PROCEDURE [dbo].[sp_COR_Contact_Details]
	@web_userid nvarchar(60) = ''
AS
-- =============================================
-- Author:		Sathiya
-- Create date: 12th Feb, 2020
-- Description:	<Description,,>
-- EXEC sp_COR_Contact_Details 'nyswyn100'
-- EXEC sp_COR_Contact_Details 'anand.manickam@optisolbusiness.com'
-- =============================================
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    select web_userid as UserName,email as EmailAddress,first_name as FirstName,last_name as LastName from Plt_Ai..Contact
	 where 
	  (web_userid = @web_userid OR email = @web_userid) AND web_access_flag='T' AND contact_status = 'A'
	

END

go

	grant execute on sp_COR_Contact_Details to COR_USER;

go
