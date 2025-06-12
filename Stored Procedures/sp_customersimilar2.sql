/***************************************************************************************
Returns customers with similar names to an input name.

10/1/2003 JPB	Created
9/25/2007 JPB	Points at sp_customersimilar

****************************************************************************************/
create procedure sp_customersimilar2
	@name varchar(40),
	@city varchar(40) = '',
	@state varchar(2) = '',
	@zip varchar(15) = ''
AS

	exec sp_customersimilar @name, @city, @state, @zip
	

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_customersimilar2] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_customersimilar2] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_customersimilar2] TO [EQAI]
    AS [dbo];

