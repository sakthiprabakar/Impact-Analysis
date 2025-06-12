/***************************************************************************************
sp_WCR_ADDENDUM_0204_create
Creates a WCR addendum.

Input:
	The WCR_ID to addend
	The REV to addend
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
	Creates a WCR Addendum Record

02/26/2004 JPB	Created
****************************************************************************************/
CREATE PROCEDURE SP_WCR_ADDENDUM_0204_CREATE
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
	@logon char(10)
AS
	set nocount on
	declare @wws_id int
	select @wws_id = isnull(max(wws_id) + 1, 1) from wcr_addendum
	
	insert wcr_addendum
	(wws_id, wcr_id, rev, customer_id, wws_generator_name, wws_waste_common_name, wws_info_basis, wws_method_8240, wws_method_8270, wws_method_8080, wws_method_8150, wws_used_oil, wws_oil_mixed, wws_oil_mixed_codes, wws_halogen_gt_1000, wws_halogen_source, wws_halogen_source_desc, wws_other_desc, wws_wcr_version, wws_created_by, wws_date_added)
	values
	(@wws_id, @wcr_id, @rev, @customer_id, @wws_generator_name, @wws_waste_common_name, @wws_info_basis, @wws_method_8240, @wws_method_8270, @wws_method_8080, @wws_method_8150, @wws_used_oil, @wws_oil_mixed, @wws_oil_mixed_codes, @wws_halogen_gt_1000, @wws_halogen_source, @wws_halogen_source_desc, @wws_other_desc, '0204', @logon, GETDATE())

	if @wcr_id is not null
	begin
		update wcr set
		modified_by = @logon,
		active = 'T'
		where ((@customer_id is not null and customer_id = @customer_id) or (@customer_id is null and customer_id is null and logon = @logon))
		and wcr_id = @wcr_id
		and rev = @rev
	
		update wcr set
		active = 'F'
		where ((@customer_id is not null and customer_id = @customer_id) or (@customer_id is null and customer_id is null and logon = @logon))
		and wcr_id = @wcr_id
		and rev <> @rev
	end
	set nocount off
	select @wws_id as wws_id
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[SP_WCR_ADDENDUM_0204_CREATE] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[SP_WCR_ADDENDUM_0204_CREATE] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[SP_WCR_ADDENDUM_0204_CREATE] TO [EQAI]
    AS [dbo];

