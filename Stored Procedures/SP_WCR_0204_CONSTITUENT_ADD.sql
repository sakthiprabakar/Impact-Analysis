/***************************************************************************************
sp_wcr_0204_constituent_add
Adds Waste Constituent records related to a specific WCR.

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
	Adds Waste Constituent records related to a specific WCR identified by wcr_id, rev, and customer_id.

02/26/2004 JPB	Created
****************************************************************************************/
CREATE PROCEDURE SP_WCR_0204_CONSTITUENT_ADD (
	@wcr_id int,
	@rev int,
	@customer_id int,
	@const_desc varchar(50),
	@concentration float,
	@unit varchar(50),
	@uhc char(1),
	@logon char(10))
AS
	set nocount on
	declare @int_item_id int
	declare @const_id int

	select @int_item_id = max(item_id) + 1
	from wcrconstituents
	where ((@customer_id is not null and customer_id = @customer_id) or (@customer_id is null and customer_id is null and logon = @logon))
	and wcr_id = @wcr_id
	and rev = @rev

	if @int_item_id is null
		set @int_item_id = 1

	select @const_id = null

	insert wcrconstituents (logon, wcr_id, rev, item_id, customer_id, const_id, const_desc, concentration, unit, uhc, added_by, modified_by, date_added, date_modified)
	values (@logon, @wcr_id, @rev, @int_item_id, @customer_id, @const_id, @const_desc, @concentration, @unit, @uhc, @logon, null, getdate(), null)
	set nocount off
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[SP_WCR_0204_CONSTITUENT_ADD] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[SP_WCR_0204_CONSTITUENT_ADD] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[SP_WCR_0204_CONSTITUENT_ADD] TO [EQAI]
    AS [dbo];

