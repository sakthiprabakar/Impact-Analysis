/***************************************************************************************
sp_wcr_amendment_0204_update
Updates the fields in a WCR Amendment.

Input:
	The selected companies, as a string ("0221, 0301, 1200, 1408" etc)
	The Approval Number
	The Waste Code(s)
	generator_name
	generator_code
	generator_address1
	cust_name
	cust_addr1
	inv_contact_name
	inv_contact_phone
	inv_contact_fax
	tech_contact_name
	tech_contact_phone
	tech_contact_fax
	waste_common_name
	amendment
	Logon of the calling process (customer id, eqai login name, etc)

Returns:
	Nothing

What it does:
	Updates the values of the WCR Amendment Record

02/26/2004 JPB	Created
****************************************************************************************/
CREATE PROCEDURE SP_WCR_AMENDMENT_0204_UPDATE
	@gwa_id int,
	@selected_companies varchar(1000),
	@approval varchar(20),
	@waste_codes varchar(100),
	@generator_name varchar(40),
	@generator_code varchar(12),
	@generator_address1 varchar(40),
	@cust_name varchar(40),
	@cust_addr1 varchar(40),
	@inv_contact_name varchar(40),
	@inv_contact_phone varchar(20),
	@inv_contact_fax varchar(10),
	@tech_contact_name varchar(40),
	@tech_contact_phone varchar(20),
	@tech_contact_fax varchar(10),
	@waste_common_name varchar(50),
	@amendment text,
	@signed_pin char(10),
	@signing_name varchar(40),
	@signing_date datetime,
	@logon char(10)
AS
	set nocount on
	declare @separator_position int -- this is used to locate each separator character
	declare @array_value varchar(1000) -- this holds each array value as it is returned
	update wcr_amendment set
		gwa_approval = @approval,
		gwa_waste_codes = @waste_codes,
		gwa_generator_name = @generator_name,
		gwa_generator_code = @generator_code,
		gwa_generator_address1 = @generator_address1,
		gwa_cust_name = @cust_name,
		gwa_cust_addr1 = @cust_addr1,
		gwa_inv_contact_name = @inv_contact_name,
		gwa_inv_contact_phone = @inv_contact_phone,
		gwa_inv_contact_fax = @inv_contact_fax,
		gwa_tech_contact_name = @tech_contact_name,
		gwa_tech_contact_phone = @tech_contact_phone,
		gwa_tech_contact_fax = @tech_contact_fax,
		gwa_waste_common_name = @waste_common_name,
		gwa_amendment = @amendment,
		gwa_signed_pin = @signed_pin,
		gwa_signing_name = @signing_name,
		gwa_signing_date = @signing_date,
		gwa_logon = @logon 
	where
		gwa_id = @gwa_id

	delete from wcr_amendment_companies where gwa_id = @gwa_id
	
	set @selected_companies = @selected_companies + ','

	while patindex('%' + ',' + '%' , @selected_companies) <> 0
	begin

	 select @separator_position = patindex('%' + ',' + '%' , @selected_companies)
	 select @array_value = ltrim(rtrim(left(@selected_companies, @separator_position - 1)))

	 insert wcr_amendment_companies (gwa_id, waxc_co_pc, logon, date_added)
	 values (@gwa_id, rtrim(ltrim(@array_value)), @logon, getdate())

	 select @selected_companies = stuff(@selected_companies, 1, @separator_position, '')
	end


	set nocount off
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[SP_WCR_AMENDMENT_0204_UPDATE] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[SP_WCR_AMENDMENT_0204_UPDATE] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[SP_WCR_AMENDMENT_0204_UPDATE] TO [EQAI]
    AS [dbo];

