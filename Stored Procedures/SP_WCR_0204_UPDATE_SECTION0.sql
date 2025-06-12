/***************************************************************************************
sp_wcr_0204_update_section0
Updates the fields in section 1 of the WCR.

Input:
	The WCR_ID to update
	The REV to update
	The Customer ID associated with this WCR
	The selected companies, as a string ("0221, 0301, 1200, 1408" etc)
	The Waste Common Name
	Logon of the calling process (customer id, eqai login name, etc)

Returns:
	Nothing

What it does:
	Updates the values of the WCR Record identified by wcr_id, rev, and customer_id.
	Regular update of fields except selected_companies.
	Loops over selected companies data to insert records in wcr_companies db.

02/26/2004 JPB	Created
****************************************************************************************/
CREATE PROCEDURE SP_WCR_0204_UPDATE_SECTION0 (
	@wcr_id int,
	@rev int,
	@customer_id int,
	@selected_companies varchar(1000),
	@waste_common_name varchar(50),
	@logon char(10))
AS
	set nocount on
	declare @separator_position int -- this is used to locate each separator character
	declare @array_value varchar(1000) -- this holds each array value as it is returned

	update wcr set
	waste_common_name = @waste_common_name,
	date_modified = getdate(),
	modified_by = @logon,
	active = 'T'
	where ((@customer_id is not null and customer_id = @customer_id) or (@customer_id is null and customer_id is null and logon = @logon))
	and wcr_id = @wcr_id
	and rev = @rev

	update wcr set
	active = 'F'
	where ((@customer_id is not null and customer_id = @customer_id) or (@customer_id is null and customer_id is null and logon = @logon))
	and wcr_id = @wcr_id
	and rev <> @rev

	set @selected_companies = @selected_companies + ','

	delete from wcr_companies
	where ((@customer_id is not null and customer_id = @customer_id) or (@customer_id is null and customer_id is null and logon = @logon))
	and wcr_id = @wcr_id
	and rev = @rev

	while patindex('%' + ',' + '%' , @selected_companies) <> 0
	begin

	 select @separator_position = patindex('%' + ',' + '%' , @selected_companies)
	 select @array_value = ltrim(rtrim(left(@selected_companies, @separator_position - 1)))

	 insert wcr_companies (wcr_id, rev, customer_id, wxc_co_pc, logon, date_added)
	 values (@wcr_id, @rev, @customer_id, rtrim(ltrim(@array_value)), @logon, getdate())

	 select @selected_companies = stuff(@selected_companies, 1, @separator_position, '')
	end
	set nocount off
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[SP_WCR_0204_UPDATE_SECTION0] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[SP_WCR_0204_UPDATE_SECTION0] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[SP_WCR_0204_UPDATE_SECTION0] TO [EQAI]
    AS [dbo];

