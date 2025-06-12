/***************************************************************************************
sp_wcr_0204_update_section4
Updates the fields in section 4 of the WCR.

Input:
	The WCR_ID to update
	The REV to update
	The Customer ID associated with this WCR
	gen_process - The Generating Process text field
	Logon of the calling process (customer id, eqai login name, etc)

Returns:
	Nothing

What it does:
	Updates the values of the WCR Record identified by wcr_id, rev, and customer_id.

02/26/2004 JPB	Created
****************************************************************************************/
CREATE PROCEDURE SP_WCR_0204_UPDATE_SECTION4 (
	@wcr_id int,
	@rev int,
	@customer_id int,
	@gen_process text,
	@logon char(10))
AS
	set nocount on
	update wcr set
	date_modified = getdate(),
	modified_by = @logon,
	active = 'T',
	gen_process = @gen_process
	where ((@customer_id is not null and customer_id = @customer_id) or (@customer_id is null and customer_id is null and logon = @logon))
	and wcr_id = @wcr_id
	and rev = @rev

	update wcr set
	active = 'F'
	where ((@customer_id is not null and customer_id = @customer_id) or (@customer_id is null and customer_id is null and logon = @logon))
	and wcr_id = @wcr_id
	and rev <> @rev
	set nocount off
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[SP_WCR_0204_UPDATE_SECTION4] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[SP_WCR_0204_UPDATE_SECTION4] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[SP_WCR_0204_UPDATE_SECTION4] TO [EQAI]
    AS [dbo];

