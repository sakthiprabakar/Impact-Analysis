/***************************************************************************************
sp_wcr_0204_update_section7
Updates the fields in section 7 of the WCR.

Input:
	The WCR_ID to update
	The REV to update
	The Customer ID associated with this WCR
	michigan_non_haz
	michigan_non_haz_waste_codes
	universal
	recyclable_commodity
	recoverable_petroleum_product
	used_oil
	Logon of the calling process (customer id, eqai login name, etc)

Returns:
	Nothing

What it does:
	Updates the values of the WCR Record identified by wcr_id, rev, and customer_id.

02/26/2004 JPB	Created
****************************************************************************************/
CREATE PROCEDURE SP_WCR_0204_UPDATE_SECTION7 (
	@wcr_id int,
	@rev int,
	@customer_id int,
	@michigan_non_haz char(1),
	@michigan_non_haz_waste_codes varchar(100),
	@universal char(1),
	@recyclable_commodity char(1),
	@recoverable_petroleum_product char(1),
	@used_oil char(1),
	@logon char(10))
AS
	set nocount off
	update wcr set
	date_modified = getdate(),
	modified_by = @logon,
	active = 'T',
	michigan_non_haz = @michigan_non_haz ,
	michigan_non_haz_waste_codes = @michigan_non_haz_waste_codes ,
	universal = @universal ,
	recyclable_commodity = @recyclable_commodity ,
	recoverable_petroleum_product = @recoverable_petroleum_product ,
	used_oil = @used_oil
	where ((@customer_id is not null and customer_id = @customer_id) or (@customer_id is null and customer_id is null and logon = @logon))
	and wcr_id = @wcr_id
	and rev = @rev

	update wcr set
	active = 'F'
	where ((@customer_id is not null and customer_id = @customer_id) or (@customer_id is null and customer_id is null and logon = @logon))
	and wcr_id = @wcr_id
	and rev <> @rev
	set nocount on
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[SP_WCR_0204_UPDATE_SECTION7] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[SP_WCR_0204_UPDATE_SECTION7] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[SP_WCR_0204_UPDATE_SECTION7] TO [EQAI]
    AS [dbo];

