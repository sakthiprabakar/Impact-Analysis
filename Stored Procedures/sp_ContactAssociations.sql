
create procedure sp_ContactAssociations
	@contact_id int
/*
	Purpose: Retrieve list of relevant information for a given contact_id (customers, generators, etc...)
	Usage: exec sp_ContactAssociations 114224
*/	
as
begin

/* Customers */
/* Customers */
/* Customers */
SELECT cust.* FROM ContactXRef x
	INNER JOIN Contact c ON x.contact_id = c.contact_ID
	INNER JOIN Customer cust ON x.customer_id = cust.customer_id
	WHERE 1=1
		AND c.contact_status = 'A'
		AND x.status = 'A'
		AND x.type = 'C'
		AND x.contact_id = @contact_id

/* Generators */
/* Generators */
/* Generators */
SELECT G.* FROM ContactXRef x
	INNER JOIN Contact c ON x.contact_id = c.contact_ID
	INNER JOIN Generator g ON x.generator_id = g.generator_id
	WHERE 1=1
		AND c.contact_status = 'A'
		AND x.status = 'A'
		AND x.type = 'G'
		AND x.contact_id = @contact_id

/* Profiles */
/* Profiles */
/* Profiles */
SELECT * FROM Profile where contact_id = @contact_id

/* Profiles */
/* Profiles */
/* Profiles */
SELECT * FROM Opp where contact_id = @contact_id

end

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_ContactAssociations] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_ContactAssociations] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_ContactAssociations] TO [EQAI]
    AS [dbo];

