/***************************************************************************************
sp_wcr_0204_update_section1
Updates the fields in section 1 of the WCR.

Input:
	@wcr_id int,
	@rev int,
	@customer_id int,
	@sic_code int,
	@generator_code varchar(12),
	@generator_name varchar(40),
	@generator_address1 varchar(40),
	@generator_city varchar(40),
	@generator_state varchar(40),
	@generator_zip varchar(10),
	@generator_county_name varchar(40),
	@gen_mail_address1 varchar(40),
	@gen_mail_city varchar(40),
	@gen_mail_state varchar(2),
	@gen_mail_zip varchar(10),
	@generator_contact varchar(40),
	@generator_contact_title varchar(20),
	@generator_phone varchar(20),
	@generator_fax varchar(10),
	@cust_name varchar(40),
	@cust_addr1 varchar(40),
	@cust_city varchar(40),
	@cust_state varchar(2),
	@cust_zip varchar(10),
	@cust_country varchar(50),
	@inv_contact_name varchar(40),
	@inv_contact_phone varchar(20),
	@inv_contact_fax varchar(10),
	@tech_contact_name varchar(40),
	@tech_contact_phone varchar(20),
	@tech_contact_fax varchar(10),
	@tech_contact_mobile varchar(10),
	@tech_contact_pager varchar(10),
	@tech_cont_email varchar(50),
	@logon char(10))

Returns:
	Nothing

What it does:
	Updates the values of the WCR Record identified by wcr_id, rev, and customer_id.
	Regular update of fields except selected_companies.
	Loops over selected companies data to insert records in wcr_companies db.

02/26/2004 JPB	Created
****************************************************************************************/
CREATE PROCEDURE SP_WCR_0204_UPDATE_SECTION1 (
	@wcr_id int,
	@rev int,
	@customer_id int,
	@sic_code int,
	@generator_code varchar(12),
	@generator_name varchar(40),
	@generator_address1 varchar(40),
	@generator_city varchar(40),
	@generator_state varchar(40),
	@generator_zip varchar(10),
	@generator_county_name varchar(40),
	@gen_mail_address1 varchar(40),
	@gen_mail_city varchar(40),
	@gen_mail_state varchar(2),
	@gen_mail_zip varchar(10),
	@generator_contact varchar(40),
	@generator_contact_title varchar(20),
	@generator_phone varchar(20),
	@generator_fax varchar(10),
	@cust_name varchar(40),
	@cust_addr1 varchar(40),
	@cust_city varchar(40),
	@cust_state varchar(2),
	@cust_zip varchar(10),
	@cust_country varchar(50),
	@inv_contact_name varchar(40),
	@inv_contact_phone varchar(20),
	@inv_contact_fax varchar(10),
	@tech_contact_name varchar(40),
	@tech_contact_phone varchar(20),
	@tech_contact_fax varchar(10),
	@tech_contact_mobile varchar(10),
	@tech_contact_pager varchar(10),
	@tech_cont_email varchar(50),
	@logon char(10))
AS
	set nocount on
	declare @county_id int

	select @county_id = county_code
	from county
	where state = @generator_state
	and county_name = @generator_county_name

	update wcr set
	date_modified = getdate(),
	modified_by = @logon,
	sic_code = @sic_code,
	generator_code = @generator_code,
	generator_name = @generator_name,
	generator_address1 = @generator_address1,
	generator_city = @generator_city,
	generator_state = @generator_state,
	generator_zip = @generator_zip,
	generator_county = @county_id,
	generator_county_id = @county_id,
	generator_county_name = @generator_county_name,
	gen_mail_address1 = @gen_mail_address1,
	gen_mail_city = @gen_mail_city,
	gen_mail_state = @gen_mail_state,
	gen_mail_zip = @gen_mail_zip,
	generator_contact = @generator_contact,
	generator_contact_title = @generator_contact_title,
	generator_phone = @generator_phone,
	generator_fax = @generator_fax,
	cust_name = @cust_name,
	cust_addr1 = @cust_addr1,
	cust_city = @cust_city,
	cust_state = @cust_state,
	cust_zip = @cust_zip,
	cust_country = @cust_country,
	inv_contact_name = @inv_contact_name,
	inv_contact_phone = @inv_contact_phone,
	inv_contact_fax = @inv_contact_fax,
	tech_contact_name = @tech_contact_name,
	tech_contact_phone = @tech_contact_phone,
	tech_contact_fax = @tech_contact_fax,
	tech_contact_mobile = @tech_contact_mobile,
	tech_contact_pager = @tech_contact_pager,
	tech_cont_email = @tech_cont_email,
	active = 'T'
	where ((@customer_id is not null and customer_id = @customer_id) or (@customer_id is null and customer_id is null and logon = @logon))
	and wcr_id = @wcr_id
	and rev = @rev

	update wcr set
	active = 'F'
	where ((@customer_id is not null and customer_id = @customer_id) or (@customer_id is null and customer_id is null and logon = @logon))
	and wcr_id = @wcr_id
	and rev <> @rev
	set nocount off
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[SP_WCR_0204_UPDATE_SECTION1] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[SP_WCR_0204_UPDATE_SECTION1] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[SP_WCR_0204_UPDATE_SECTION1] TO [EQAI]
    AS [dbo];

