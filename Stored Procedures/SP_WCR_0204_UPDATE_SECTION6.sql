/***************************************************************************************
sp_wcr_0204_update_section6
Updates the fields in section 6 of the WCR.

Input:
	The WCR_ID to update
	The REV to update
	The Customer ID associated with this WCR
	exceed_ldr_standards
	meets_alt_soil_treatment_stds
	more_than_50_pct_debris
	oxidizer
	react_cyanide
	react_sulfide
	info_basis
	underlying_haz_constituents
	Logon of the calling process (customer id, eqai login name, etc)

Returns:
	Nothing

What it does:
	Updates the values of the WCR Record identified by wcr_id, rev, and customer_id.

02/26/2004 JPB	Created
****************************************************************************************/
CREATE PROCEDURE SP_WCR_0204_UPDATE_SECTION6 (
	@wcr_id int,
	@rev int,
	@customer_id int,
	@exceed_ldr_standards char(1),
	@meets_alt_soil_treatment_stds char(1),
	@more_than_50_pct_debris char(1),
	@oxidizer char(1),
	@react_cyanide char(1),
	@react_sulfide char(1),
	@info_basis char(10),
	@underlying_haz_constituents char(1),
	@logon char(10))
AS
	set nocount off
	update wcr set
	date_modified = getdate(),
	modified_by = @logon,
	active = 'T',
	exceed_ldr_standards = @exceed_ldr_standards,
	meets_alt_soil_treatment_stds = @meets_alt_soil_treatment_stds,
	more_than_50_pct_debris = @more_than_50_pct_debris,
	oxidizer = @oxidizer,
	react_cyanide = @react_cyanide,
	react_sulfide = @react_sulfide,
	info_basis = @info_basis,
	underlying_haz_constituents = @underlying_haz_constituents
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
    ON OBJECT::[dbo].[SP_WCR_0204_UPDATE_SECTION6] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[SP_WCR_0204_UPDATE_SECTION6] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[SP_WCR_0204_UPDATE_SECTION6] TO [EQAI]
    AS [dbo];

