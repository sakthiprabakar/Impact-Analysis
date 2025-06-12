/***************************************************************************************
Retrieves contact Info for a Customer

09/15/2003 JPB	Created
11/15/2004 JPB  Changed Customercontact -> contact
07/07/2005	JPB	Added first_name/last_name changes

Test Cmd Line: spw_getcontacts_customer 1, 10, 2222, 0, 'data'
****************************************************************************************/
create procedure spw_getcontacts_customer
	@Page int,
	@RecsPerPage int,
	@Customer_ID	int,
	@Customer_Filter	int = 0,
	@Mode	varchar(15)
As

	SET NOCOUNT ON
	--Create a temporary table for companies
	CREATE TABLE #TempCompanies
	(
		Customer_ID	int
	)

	-- Fill it with this company's children id's (includes self)
	INSERT #TempCompanies (customer_ID)
		EXEC spw_parent_getchildren_ids @Customer_ID, 0

	if @Customer_Filter <> 0
		DELETE FROM #TempCompanies where Customer_ID <> @Customer_Filter

	--Create a temporary table for contacts
	CREATE TABLE #TempItems
	(
		NoteAutoID int IDENTITY,
		contact_id	int,
	)

	-- Insert the rows from the real table into the temp. table
	DECLARE @SearchSQL varchar(5000)
	INSERT INTO #TempItems (contact_id)
		SELECT distinct contact.contact_id
		from customer
		left outer join CustomerXcontact on (customer.customer_ID = CustomerXcontact.customer_ID and CustomerXcontact.status = 'A')
		left join contact on (CustomerXcontact.contact_ID = contact.contact_ID and customerxcontact.status = 'A')
		where customer.Customer_ID IN (select customer_ID from #TempCompanies)

	-- Find out the first and last record we want
	DECLARE @FirstRec int, @LastRec int
	SELECT @FirstRec = (@Page - 1) * @RecsPerPage
	SELECT @LastRec = (@Page * @RecsPerPage + 1)

	-- Turn NOCOUNT back OFF
	SET NOCOUNT OFF

	IF @mode = 'data'
	BEGIN
		SELECT @SearchSQL = 'SELECT
		customer.customer_ID, customer.cust_name,
		contact.contact_ID, contact.contact_status, contact.contact_type, contact.contact_company, contact.name, contact.salutation, contact.first_name, contact.middle_name, contact.last_name, contact.suffix, contact.title, contact.phone, contact.fax, contact.pager, contact.mobile, contact.comments, contact.email, contact.email_flag, contact.added_from_company, contact.modified_by, contact.date_added, contact.date_modified, contact.web_access_flag, contact.web_password, contact.contact_addr1, contact.contact_addr2, contact.contact_addr3, contact.contact_addr4, contact.contact_city, contact.contact_state, contact.contact_zip_code, contact.contact_country, contact.contact_personal_info, contact.contact_directions
		from #TempItems T (nolock), customer
		left outer join CustomerXcontact
			on customer.customer_ID = CustomerXcontact.customer_ID
		left join contact
			on CustomerXcontact.contact_ID = contact.contact_ID
		where contact.contact_id = T.contact_id
		and NoteAutoID > ' + convert(varchar(10), @FirstRec) + ' AND NoteAutoID < ' + convert(varchar(10), @LastRec) + '
		for xml auto '
		EXECUTE(@SearchSQL)
	END
	IF @mode = 'date-added'
	BEGIN
		SELECT max(contact.date_added)
		from #TempItems T (nolock), contact
		where contact.contact_id = T.contact_id
		and NoteAutoID > @FirstRec AND NoteAutoID < @LastRec
	END
	IF @mode = 'count'
	BEGIN
		SELECT count(*) from #TempItems
	END



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[spw_getcontacts_customer] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[spw_getcontacts_customer] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[spw_getcontacts_customer] TO [EQAI]
    AS [dbo];

