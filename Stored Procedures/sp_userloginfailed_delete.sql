CREATE OR ALTER PROCEDURE [dbo].[sp_userloginfailed_delete]
AS
/***************************************************************************************
Deletes data from the UserLoginFailed table for entries where the login attempt was > 1 week prior to the clean-up run date.

Loads to:		Plt_AI

12/09/2024 KS	Created

EXEC sp_userloginfailed_delete

****************************************************************************************/
BEGIN
	DELETE FROM dbo.UserLoginFailed
	WHERE login_date < DATEADD(week, -1, GETDATE())
	AND user_code IN(SELECT user_code FROM dbo.UserLoginFailed GROUP BY user_code HAVING COUNT(user_code) > 1)
END
GO

GRANT EXECUTE
    ON[dbo].[sp_userloginfailed_delete] TO [EQAI];
GO