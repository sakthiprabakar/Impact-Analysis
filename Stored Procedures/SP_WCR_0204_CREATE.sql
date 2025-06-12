/***************************************************************************************
sp_wcr_0204_create
Creates a new WCR record.

Input:
	Logon of the calling process (customer id, eqai login name, etc)
	Customer_ID to associate with this WCR
	in_WCR_ID (Optional) ID of the WCR to revise.  Null otherwise
	in_REV (Optional) ID of the revision to revise.  Null otherwise

Returns:
	The wcr_id of the new record - all the other SP's in this process must pass that id in.
	The rev of the new record - all other SP's in this process must pass that id in.

What it does:
	Creates a new WCR record and only populates the logon, customer_id, and audit info fields.
	If no in_wcr_id is given, it creates a new wcr_id for the record from a sequence.
	If a new/invalid in_wcr_id is given (not already in the table), it ignores the value like above.
	If an old in_wcr_id is given, and the id exists for the customer_id given:
		if no in_rev is given, then a new rev id is created for this wcr.
			The new wcr record created is prepopulated with the values of the wcr with the same
			customer_id and wcr_id and the previous rev value.
		if a new in_rev is given, it is ignored and treated as above.
		if an old in_rev is given, a new rev id is created for this wcr.
			The new wcr record created is prepopulated with the values of the wcr with the same
			customer_id/wcr_id/rev value.  The new rev value is max(rev) + 1 for this customer/wcr.

02/26/2004 JPB	Created
****************************************************************************************/
CREATE PROCEDURE SP_WCR_0204_CREATE (
	@logon char(10),
	@customer_id int,
	@in_wcr_id int = NULL,
	@in_rev int = NULL )
AS
	set nocount on
	declare @valid_wcr_id int
	declare @valid_rev int
	declare @new_wcr_id int
	declare @new_rev int

	select @valid_wcr_id = wcr_id
	from wcr
	where ((@customer_id is not null and customer_id = @customer_id) or (@customer_id is null and customer_id is null and logon = @logon))
	and wcr_id = @in_wcr_id

	select @valid_rev = rev
	from wcr
	where ((@customer_id is not null and customer_id = @customer_id) or (@customer_id is null and customer_id is null and logon = @logon))
	and wcr_id = @in_wcr_id
	and rev = @in_rev

	if @valid_wcr_id is null
		begin
			exec @new_wcr_id = sp_sequence_silent_next 'WCR.WCR_ID'
			set @new_rev = 1
		end
	else
		begin
			set @new_wcr_id = @valid_wcr_id
			select @new_rev = max(rev) + 1
			from wcr
			where ((@customer_id is not null and customer_id = @customer_id) or (@customer_id is null and customer_id is null and logon = @logon))
			and wcr_id = @new_wcr_id
		end

	if @new_rev = 1
		insert wcr (logon, wcr_id, rev, customer_id, wcr_version, active, date_added, added_by)
		values (@logon, @new_wcr_id, @new_rev, @customer_id, '0204', 'T', getdate(), @logon)
	else
		begin
			set rowcount 1
			select * into #wcr
			from wcr
			where ((@customer_id is not null and customer_id = @customer_id) or (@customer_id is null and customer_id is null and logon = @logon))
			and wcr_id = @valid_wcr_id
			and rev = @valid_rev

			set rowcount 0
			update #wcr set
			wcr_id = @new_wcr_id,
			rev = @new_rev,
			logon = @logon,
			date_added = getdate(),
			wcr_version = '0204',
			active = 'T',
			added_by = @logon

			insert wcr
			select * from #wcr
		end

	update wcr set
	active = 'F'
	where ((@customer_id is not null and customer_id = @customer_id) or (@customer_id is null and customer_id is null and logon = @logon))
	and wcr_id = @new_wcr_id
	and rev <> @new_rev

	set nocount off
	select @new_wcr_id as wcr_id, @new_rev as rev
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[SP_WCR_0204_CREATE] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[SP_WCR_0204_CREATE] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[SP_WCR_0204_CREATE] TO [EQAI]
    AS [dbo];

