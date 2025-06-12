/***************************************************************************************
sp_wcr_0204_composition_add
Adds Waste Composition records related to a specific WCR.

Input:
	The WCR_ID to update
	The REV to update
	The Customer ID associated with this WCR
	Composition Description
	Composition "From" Percentage
	Composition "To" Percentage
	Logon of the calling process (customer id, eqai login name, etc)

Returns:
	Nothing

What it does:
	Adds Waste Composition records related to a specific WCR identified by wcr_id, rev, and customer_id.

02/26/2004 JPB	Created
****************************************************************************************/
CREATE PROCEDURE SP_WCR_0204_COMPOSITION_ADD (
	@wcr_id int,
	@rev int,
	@customer_id int,
	@comp_description varchar(40),
	@comp_from_pct int,
	@comp_to_pct int,
	@logon char(10))
AS
	set nocount on
	declare @int_comp_id int

	select @int_comp_id = max(comp_id) + 1
	from wcr_composition

	if @int_comp_id is null
		set @int_comp_id = 1

	insert wcr_composition (comp_id, wcr_id, rev, customer_id, comp_description, comp_from_pct, comp_to_pct, logon, date_added)
	values (@int_comp_id, @wcr_id, @rev, @customer_id, @comp_description, @comp_from_pct, @comp_to_pct, @logon, getdate())
	set nocount off
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[SP_WCR_0204_COMPOSITION_ADD] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[SP_WCR_0204_COMPOSITION_ADD] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[SP_WCR_0204_COMPOSITION_ADD] TO [EQAI]
    AS [dbo];

