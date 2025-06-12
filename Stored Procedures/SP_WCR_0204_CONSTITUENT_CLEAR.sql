/***************************************************************************************
sp_wcr_0204_constituent_clear
Removes all Waste Constituent records related to a specific WCR.

Input:
	The WCR_ID to update
	The REV to update
	The Customer ID associated with this WCR

Returns:
	Nothing

What it does:
	Removes all Waste Constituent records related to a specific WCR identified by wcr_id, rev, and customer_id.

02/26/2004 JPB	Created
****************************************************************************************/
CREATE PROCEDURE SP_WCR_0204_CONSTITUENT_CLEAR (
	@wcr_id int,
	@rev int,
	@customer_id int)
AS
	set nocount on
	delete from wcrconstituents
	where ((@customer_id is not null and customer_id = @customer_id) or (@customer_id is null and customer_id is null))
	and wcr_id = @wcr_id
	and rev = @rev
	set nocount off
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[SP_WCR_0204_CONSTITUENT_CLEAR] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[SP_WCR_0204_CONSTITUENT_CLEAR] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[SP_WCR_0204_CONSTITUENT_CLEAR] TO [EQAI]
    AS [dbo];

