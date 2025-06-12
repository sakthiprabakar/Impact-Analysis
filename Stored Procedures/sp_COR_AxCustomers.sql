-- drop proc sp_COR_AxCustomers
go

CREATE PROCEDURE [dbo].[sp_COR_AxCustomers]
		@web_UserId NVARCHAR(60)
AS
/* ******************************************************************
-- Author:		Senthil Kumar
-- Create date: 28 th Feb 2019
-- Description:	To Get AX customer details based on current contact

Input: 
	
	@web_UserId

Samples:
 EXEC [sp_COR_AxCustomers] @web_UserId
 EXEC [sp_COR_AxCustomers] 'nyswyn100'

****************************************************************** */
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	SELECT * FROM [dbo].[Customer] 
	WHERE customer_id IN (SELECT customer_id FROM [dbo].[ContactCORCustomerBucket] 
	WHERE contact_id IN(SELECT contact_id FROM CORcontact WHERE web_userid=@web_UserId))
	
END

			 
GO
GRANT EXECUTE ON [dbo].[sp_COR_AxCustomers] TO COR_USER;
GO