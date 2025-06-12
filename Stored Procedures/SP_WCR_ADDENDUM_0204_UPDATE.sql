/***************************************************************************************
sp_WCR_ADDENDUM_0204_update
Updates the fields in the WCR addendum.

Input:
	The WCR ADDENDUM RECORD to update
	The WCR_ID to update
	The REV to update
	The Customer ID associated with this WCR
	wws_generator_name varchar(40),
	wws_waste_common_name varchar(50),
	wws_info_basis varchar (10),
	wws_total_organic_actual float,
	wws_method_8240 char (1),
	wws_method_8270 char (1),
	wws_method_8080 char (1),
	wws_method_8150 char (1),
	wws_used_oil char (1),
	wws_oil_mixed char (1),
	wws_oil_mixed_codes varchar (100),
	wws_halogen_gt_1000 char (1),
	wws_halogen_source char (10),
	wws_halogen_source_desc text,
	wws_other_desc text,
	Logon of the calling process (customer id, eqai login name, etc)

Returns:
	Nothing

What it does:
	Updates the values of the WCR Addendum Record

02/26/2004 JPB	Created
****************************************************************************************/
CREATE PROCEDURE SP_WCR_ADDENDUM_0204_UPDATE 
	@wws_id int,
	@wcr_id int,
	@rev int,
	@customer_id int,
	@wws_generator_name varchar(40),
	@wws_waste_common_name varchar(50),
	@wws_info_basis varchar (10),
	@wws_total_organic_actual float,
	@wws_method_8240 char (1),
	@wws_method_8270 char (1),
	@wws_method_8080 char (1),
	@wws_method_8150 char (1),
	@wws_used_oil char (1),
	@wws_oil_mixed char (1),
	@wws_oil_mixed_codes varchar (100),
	@wws_halogen_gt_1000 char (1),
	@wws_halogen_source char (10),
	@wws_halogen_source_desc text,
	@wws_other_desc text,
	@wws_signed_pin char(10),
	@wws_cust_name varchar(40),
	@wws_signing_name varchar(40),
	@wws_signing_date datetime,
	@logon char(10)
AS
	set nocount on
	update wcr_addendum set
	wws_waste_common_name = @wws_waste_common_name,
	wws_info_basis = @wws_info_basis,
	wws_total_organic_actual = @wws_total_organic_actual,
	wws_method_8240 = @wws_method_8240,
	wws_method_8270 = @wws_method_8270,
	wws_method_8080 = @wws_method_8080,
	wws_method_8150 = @wws_method_8150,
	wws_oil_mixed = @wws_oil_mixed,
	wws_oil_mixed_codes = @wws_oil_mixed_codes,
	wws_halogen_gt_1000 = @wws_halogen_gt_1000,
	wws_halogen_source = @wws_halogen_source,
	wws_halogen_source_desc = @wws_halogen_source_desc,
	wws_other_desc = @wws_other_desc,
	wws_signed_pin = @wws_signed_pin ,
	wws_cust_name = @wws_cust_name,
	wws_signing_name = @wws_signing_name,
	wws_signing_date = @wws_signing_date
	where 
	wws_id = @wws_id

	set nocount off
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[SP_WCR_ADDENDUM_0204_UPDATE] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[SP_WCR_ADDENDUM_0204_UPDATE] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[SP_WCR_ADDENDUM_0204_UPDATE] TO [EQAI]
    AS [dbo];

