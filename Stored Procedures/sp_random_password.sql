/***************************************************************************************
Returns a random, unique password not already in the contact table

01/14/2005 JPB	Created
01/13/2006 JDB	Modified to replace ambiguous characters and return all CAPS passwords.
Loads on PLT_AI*
sp_random_password
****************************************************************************************/
CREATE PROCEDURE sp_random_password
AS
BEGIN
	DECLARE @password 	varchar(10), 
		@bitmap 	char(6), 
		@charmap 	varchar(29), 
		@len 		int,
		@ok 		int

	SET @password=''
	SET @bitmap = 'uaeioy'
	SET @charmap = 'bcdfghjkmnpqrstvwxz23456789'
	SET @ok = 1

	WHILE @ok = 1
	BEGIN
		SET @password=''
		SET @len = 10
		WHILE @len > 0
		BEGIN
			IF (@len%2) = 0
				SET @password = @password + SUBSTRING(@bitmap, CONVERT(int, ROUND(1 + (RAND() * (5)), 0)), 1)
			ELSE
				SET @password = @password + SUBSTRING(@charmap, CONVERT(int, ROUND(1 + (RAND() * (28)), 0)), 1)
			SET @len = @len - 1
		END
		SELECT @ok = COUNT(*) FROM Contact WHERE web_password = @password
	END

	SET @password = UPPER(@password)
	SET @password = REPLACE(@password, '0', 'Q')
	SET @password = REPLACE(@password, '1', 'V')
	SET @password = REPLACE(@password, '2', 'P')
	SET @password = REPLACE(@password, 'O', '4')
	SET @password = REPLACE(@password, 'I', 'Z')
	SET @password = REPLACE(@password, 'L', 'K')
	SELECT @password
END

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_random_password] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_random_password] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_random_password] TO [EQAI]
    AS [dbo];

