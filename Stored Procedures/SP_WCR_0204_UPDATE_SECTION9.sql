/***************************************************************************************
sp_wcr_0204_update_section9
Updates the fields in section 9 of the WCR.

Input:
	The WCR_ID to update
	The REV to update
	The Customer ID associated with this WCR
	ccvocgr500
	benzene
	neshap_sic
	tab_gr_10
	avg_h20_gr_10
	tab
	benzene_gr_1
	benzene_concentration
	benzene_unit
	Logon of the calling process (customer id, eqai login name, etc)

Returns:
	Nothing

What it does:
	Updates the values of the WCR Record identified by wcr_id, rev, and customer_id.

02/26/2004 JPB	Created
****************************************************************************************/
CREATE PROCEDURE SP_WCR_0204_UPDATE_SECTION9 (
	@wcr_id int,
	@rev int,
	@customer_id int,
	@ccvocgr500 char(1),
	@benzene char(1),
	@neshap_sic char(1),
	@tab_gr_10 char(1),
	@avg_h20_gr_10 char(1),
	@tab float,
	@benzene_gr_1 char(1),
	@benzene_concentration float,
	@benzene_unit char(10),
	@logon char(10))
AS
	set nocount off
	update wcr set
	date_modified = getdate(),
	modified_by = @logon,
	active = 'T',
	ccvocgr500 = @ccvocgr500 ,
	benzene = @benzene ,
	neshap_sic = @neshap_sic ,
	tab_gr_10 = @tab_gr_10 ,
	avg_h20_gr_10 = @avg_h20_gr_10 ,
	tab = @tab ,
	benzene_gr_1 = @benzene_gr_1 ,
	benzene_concentration = @benzene_concentration ,
	benzene_unit = @benzene_unit
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
    ON OBJECT::[dbo].[SP_WCR_0204_UPDATE_SECTION9] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[SP_WCR_0204_UPDATE_SECTION9] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[SP_WCR_0204_UPDATE_SECTION9] TO [EQAI]
    AS [dbo];

