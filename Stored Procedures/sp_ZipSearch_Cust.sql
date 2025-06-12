
/***************************************************************************************
Returns Customer Info for customers in zipcodes in a @distance mile radius from a starting zip (or city/state)

10/1/2003 JPB	Created
Test Cmd Line: sp_ZipSearch_Cust '48184', '', '', 25
****************************************************************************************/
create procedure sp_ZipSearch_Cust
	@myZip varchar(10),
	@myCity varchar(40),
	@myState varchar(5),
	@distance int

AS
	IF LEN(@myZip) = 0
		SELECT @myZip = zipcode from zipcodes where city like @myCity + '%' and state = @myState
	 
	SELECT customer.customer_id, customer.cust_name, customer.cust_city, customer.cust_state, customer.cust_zip_code,
	 (3956 * (2 * ASIN(SQRT(
	 POWER(SIN(((z.latitude-o.latitude)*0.017453293)/2),2) +
	 COS(z.latitude*0.017453293) *
	 COS(o.latitude*0.017453293) *
	 POWER(SIN(((z.longitude-o.longitude)*0.017453293)/2),2)
	 )))) dist
	
	FROM zipcodes z,
	 zipcodes o,
	 zipcodes a,
	 customer
	
	WHERE z.zipcode = @myZip AND
	 z.zipcode =a.zipcode AND
	 (3956 * (2 * ASIN(SQRT(
	 POWER(SIN(((z.latitude-o.latitude)*0.017453293)/2),2) +
	 COS(z.latitude*0.017453293) *
	 COS(o.latitude*0.017453293) *
	 POWER(SIN(((z.longitude-o.longitude)*0.017453293)/2),2)
	 )))) < @distance 
	 AND customer.cust_zip_code = o.zipcode
	ORDER BY dist, customer.cust_name


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_ZipSearch_Cust] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_ZipSearch_Cust] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_ZipSearch_Cust] TO [EQAI]
    AS [dbo];

