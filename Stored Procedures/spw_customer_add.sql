/*

-- Commented 6/25/2019 - JPB - error deploying to misousqldev01, seems like deprecated code.

/-***************************************************************************************
Inserts Customer Information

09/15/2003 JPB	Created
Test Cmd Line: spw_customer_add 'cust_name', NULL, NULL, NULL, NULL, 'cust_addr1', 'cust_addr2', 'cust_addr3', 'cust_addr4', NULL, 'cust_city', 'ST', 'cust_zip_code', NULL, NULL, 'cust_phone', 'cust_fax', 'T', 'cust_directions', NULL, NULL, 'added_by', NULL, NULL, NULL, NULL, NULL, 'cust_category', 'cust_website', NULL, 'territory'
****************************************************************************************-/
create procedure spw_customer_add
	@cust_name varchar(40),
	@purchase_order varchar(20) = NULL,
	@release_code varchar(20) = NULL,
	@customer_type varchar(10) = NULL,
	@cert_flag char(1) = NULL,
	@cust_addr1 varchar(40) = NULL,
	@cust_addr2 varchar(40) = NULL,
	@cust_addr3 varchar(40) = NULL,
	@cust_addr4 varchar(40) = NULL,
	@cust_addr5 varchar(40) = NULL,
	@cust_city varchar(40) = NULL,
	@cust_state varchar(2) = NULL,
	@cust_zip_code varchar(15) = NULL,
	@cust_country varchar(40) = NULL,
	@cust_sic_code varchar(5) = NULL,
	@cust_phone varchar(10) = NULL,
	@cust_fax varchar(10) = NULL,
	@mail_flag char(1) = NULL,
	@cust_directions text = NULL,
	@invoice_flag char(1) = NULL,
	@terms_code varchar(8) = NULL,
	@added_by varchar(10) = NULL,
	@insurance_surcharge_flag char(1) = NULL,
	@designation char(1) = NULL,
	@generator_flag char(1) = NULL,
	@web_access_flag char(1) = NULL,
	@next_WCR int = NULL,
	@cust_category varchar(30) = NULL,
	@cust_website varchar(50) = NULL,
	@cust_prospect_flag char(1) = NULL,
	@territory varchar(8)
AS
	set nocount on
	declare @nextID int
	exec @nextID = sp_sequence_next 'Customer.Prospect_ID'

	insert into customer (customer_ID, cust_name, purchase_order, release_code, customer_type, cert_flag, cust_addr1, cust_addr2, cust_addr3, cust_addr4, cust_addr5, cust_city, cust_state, cust_zip_code, cust_country, cust_sic_code, cust_phone, cust_fax, mail_flag, cust_directions, invoice_flag, terms_code, added_by, modified_by, date_added, date_modified, insurance_surcharge_flag, designation, generator_flag, web_access_flag, next_WCR, cust_category, cust_website, cust_parent_ID, cust_prospect_flag, rowguid)
	values (@nextID, @cust_name, @purchase_order, @release_code, @customer_type, @cert_flag, @cust_addr1, @cust_addr2, @cust_addr3, @cust_addr4, @cust_addr5, @cust_city, @cust_state, @cust_zip_code, @cust_country, @cust_sic_code, @cust_phone, @cust_fax, @mail_flag, @cust_directions, @invoice_flag, @terms_code, @added_by, @added_by, GETDATE(), GETDATE(), @insurance_surcharge_flag, @designation, @generator_flag, @web_access_flag, @next_WCR, @cust_category, @cust_website, @nextID, @cust_prospect_flag, NEWID())

	insert into customerxcompany (customer_ID, company_ID, salesperson_code, territory_code, cust_discount, inv_break_code, project_inv_break_code, date_last_invoice, primary_contact_ID, rowguid) 
	values (@nextID, 0, NULL, @territory, NULL, NULL, NULL, NULL, NULL, NEWID())

	declare @newrgt int
	declare @newlft int
	select @newlft = max(rgt) + 1 from customertree
	set @newrgt = @newlft + 1

	insert into customertree (customer_id, lft, rgt, date_modified, modified_by, rowguid) 
	values (@nextID, @newlft, @newrgt, GETDATE(), @added_by, NEWID())

	insert into customertreework (customer_id, lft, rgt, date_modified, modified_by, rowguid) 
	values (@nextID, @newlft, @newrgt, GETDATE(), @added_by, NEWID())
	set nocount off
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[spw_customer_add] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[spw_customer_add] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[spw_customer_add] TO [EQAI]
    AS [dbo];

*/
