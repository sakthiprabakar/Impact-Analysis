

CREATE PROCEDURE [dbo].[sp_Cor_CustomerIDSearch] 
	-- Add the parameters for the stored procedure here
	@web_userid varchar(100), 
	@customer_search varchar(40)
AS
/* ===================================================================================================
  Author       : Sathiq
  Created date : 21-Dec-2018
  Decription   : Listing Customer details based on customer_search input

  Listing customers details like customer_id, cust_name ,address etc based on customer_search input
  
  Input
   web_userid
   customer_search

  Output
   customer_id, cust_name, cust_addr1, cust_addr2, cust_addr3, cust_city, cust_state, cust_zip_code, cust_country

  Notes:
   Inputs customer_search --> can pass empty or Search key
						if pass empty, returns all the customer related to contact id,
						else return all customer details
  Sample:

	Exec [dbo].[sp_Cor_CustomerIDSearch]  'RMU3261028@AOL.COM', ''
======================================================================================================*/
BEGIN
	
select * from Cor_db..CustomerName where customer_id in (select * from dbo.fn_COR_CustomerID_Search(@web_userid, @customer_search))
	
END

GO

GRANT EXECUTE ON [dbo].[sp_Cor_CustomerIDSearch] TO COR_USER;

GO