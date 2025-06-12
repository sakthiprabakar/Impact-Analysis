/***************************************************************************************
sp_wcr_0204_update_section5
Updates the fields in section 5 of the WCR.

Input:
	The WCR_ID to update
	The REV to update
	The Customer ID associated with this WCR
	rcra_listed
	rcra_listed_waste_codes
	rcra_characteristic
	rcra_characteristic_waste_code
	state_waste_code_flag
	state_waste_codes
	wastewater_treatment
	Logon of the calling process (customer id, eqai login name, etc)

Returns:
	Nothing

What it does:
	Updates the values of the WCR Record identified by wcr_id, rev, and customer_id.

02/26/2004 JPB	Created
****************************************************************************************/
CREATE PROCEDURE SP_WCR_0204_UPDATE_SECTION5 (
	@wcr_id int,
	@rev int,
	@customer_id int,
	@rcra_listed char(1),
	@rcra_listed_waste_codes varchar(100),
	@rcra_characteristic char(1),
	@rcra_characteristic_waste_code varchar(100),
	@state_waste_code_flag char(1),
	@state_waste_codes varchar(100),
	@wastewater_treatment char(1),
	@logon char(10))
AS
	set nocount off
	update wcr set
	date_modified = getdate(),
	modified_by = @logon,
	active = 'T',
	rcra_listed = @rcra_listed,
	rcra_listed_waste_codes = @rcra_listed_waste_codes,
	rcra_characteristic = @rcra_characteristic,
	rcra_characteristic_waste_code = @rcra_characteristic_waste_code,
	state_waste_code_flag = @state_waste_code_flag,
	state_waste_codes = @state_waste_codes,
	wastewater_treatment = @wastewater_treatment
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
    ON OBJECT::[dbo].[SP_WCR_0204_UPDATE_SECTION5] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[SP_WCR_0204_UPDATE_SECTION5] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[SP_WCR_0204_UPDATE_SECTION5] TO [EQAI]
    AS [dbo];

