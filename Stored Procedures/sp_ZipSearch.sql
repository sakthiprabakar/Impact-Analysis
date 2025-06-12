
/***************************************************************************************
Searches for zipcodes in a @distance mile radius from a starting zip (or city/state)

10/1/2003 JPB	Created
Test Cmd Line: sp_ZipSearch '48184', '', '', 25
****************************************************************************************/
create procedure sp_ZipSearch
	@myZip varchar(10),
	@myCity varchar(40),
	@myState varchar(5),
	@distance int

AS
	IF LEN(@myZip) = 0
		SELECT @myZip = zipcode from zipcodes where city = @myCity and state = @myState
	 
	SELECT o.zipcode
	
	FROM zipcodes z,
	 zipcodes o,
	 zipcodes a
	
	WHERE z.zipcode = @myZip AND
	 z.zipcode =a.zipcode AND
	 (3956 * (2 * ASIN(SQRT(
	 POWER(SIN(((z.latitude-o.latitude)*0.017453293)/2),2) +
	 COS(z.latitude*0.017453293) *
	 COS(o.latitude*0.017453293) *
	 POWER(SIN(((z.longitude-o.longitude)*0.017453293)/2),2)
	 )))) < @distance 
	ORDER BY
	 (3956 * (2 * ASIN(SQRT(
	 POWER(SIN(((z.latitude-o.latitude)*0.017453293)/2),2) +
	 COS(z.latitude*0.017453293) *
	 COS(o.latitude*0.017453293) *
	 POWER(SIN(((z.longitude-o.longitude)*0.017453293)/2),2)
	 ))))


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_ZipSearch] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_ZipSearch] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_ZipSearch] TO [EQAI]
    AS [dbo];

