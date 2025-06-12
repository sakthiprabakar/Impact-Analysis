/***************************************************************************************
sp_wcr_0204_haz_waste_code_add
Updates the hazardous waste code info in a WCR

Input:
	The WCR_ID to update
	The REV to update
	The Customer ID associated with this WCR
	The Waste Code to updated
	If it's Below or Above regulatory level
	Its concentration (if above)
	Logon of the calling process (customer id, eqai login name, etc)

Returns:
	Nothing

What it does:
	Updates the values of the WCR Record identified by wcr_id, rev, and customer_id.

02/26/2004 JPB	Created
****************************************************************************************/
CREATE PROCEDURE SP_WCR_0204_HAZ_WASTE_CODE_ADD (
	@wcr_id int,
	@rev int,
	@customer_id int,
	@waste_code char(4),
	@below_above char(1),
	@concentration float,
	@logon char(10))
AS
	set nocount on
	declare @strSQL varchar(1000)

	set @strSQL = 'update wcr set date_modified = getdate(), modified_by = '''
		+ @logon + ''', active = ''T'', '
		+ @waste_code + ' = ''' + @below_above + ''', '
		+ @waste_code + '_concentration = ' + isnull(convert(varchar(20), @concentration), 'NULL')
		+ ' where '
		+ 'customer_id = ' + convert(varchar(20), @customer_id )
		+ ' and wcr_id = ' + convert(varchar(20), @wcr_id )
		+ ' and rev = ' + convert(varchar(20), @rev)
	-- print @strSQL
	exec(@strSQL)

	update wcr set
	active = 'F'
	where ((@customer_id is not null and customer_id = @customer_id) or (@customer_id is null and customer_id is null and logon = @logon))
	and wcr_id = @wcr_id
	and rev <> @rev
	set nocount off
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[SP_WCR_0204_HAZ_WASTE_CODE_ADD] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[SP_WCR_0204_HAZ_WASTE_CODE_ADD] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[SP_WCR_0204_HAZ_WASTE_CODE_ADD] TO [EQAI]
    AS [dbo];

