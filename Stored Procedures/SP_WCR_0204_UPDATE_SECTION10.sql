/***************************************************************************************
sp_wcr_0204_update_section10
Updates the fields in section 10 of the WCR.

Input:
	The WCR_ID to update
	The REV to update
	The Customer ID associated with this WCR
	fuel_blending
	btu_per_lb
	pct_chlorides
	pct_moisture
	pct_solids
	intended_for_reclamation
	Logon of the calling process (customer id, eqai login name, etc)

Returns:
	Nothing

What it does:
	Updates the values of the WCR Record identified by wcr_id, rev, and customer_id.

02/26/2004 JPB	Created
****************************************************************************************/
CREATE PROCEDURE SP_WCR_0204_UPDATE_SECTION10 (
	@wcr_id int,
	@rev int,
	@customer_id int,
	@fuel_blending char(1),
	@btu_per_lb int,
	@pct_chlorides float,
	@pct_moisture float,
	@pct_solids float,
	@intended_for_reclamation char(1),
	@logon char(10))
AS
	set nocount off
	update wcr set
	date_modified = getdate(),
	modified_by = @logon,
	active = 'T',
	fuel_blending = @fuel_blending ,
	btu_per_lb  = @btu_per_lb  ,
	pct_chlorides = @pct_chlorides ,
	pct_moisture = @pct_moisture ,
	pct_solids = @pct_solids ,
	intended_for_reclamation = @intended_for_reclamation
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
    ON OBJECT::[dbo].[SP_WCR_0204_UPDATE_SECTION10] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[SP_WCR_0204_UPDATE_SECTION10] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[SP_WCR_0204_UPDATE_SECTION10] TO [EQAI]
    AS [dbo];

