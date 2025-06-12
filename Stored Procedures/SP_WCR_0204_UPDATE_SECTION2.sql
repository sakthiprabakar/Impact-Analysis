/***************************************************************************************
sp_wcr_0204_update_section2
Updates the fields in section 2 of the WCR.

Input:
	The WCR_ID to update
	The REV to update
	The Customer ID associated with this WCR
	volume varchar(20),
	frequency varchar(20),
	dot_shipping_name varchar(130),
	surcharge_exempt char(1),
	pack_bulk_solid_yard char(1),
	pack_bulk_solid_ton char(1),
	pack_bulk_liquid char(1),
	pack_totes char(1),
	pack_totes_size varchar(30),
	pack_cy_box char(1),
	pack_drum char(1),
	pack_other char(1),
	pack_other_desc varchar(15),
	Logon of the calling process (customer id, eqai login name, etc)

Returns:
	Nothing

What it does:
	Updates the values of the WCR Record identified by wcr_id, rev, and customer_id.

02/26/2004 JPB	Created
****************************************************************************************/
CREATE PROCEDURE SP_WCR_0204_UPDATE_SECTION2 (
	@wcr_id int,
	@rev int,
	@customer_id int,
	@volume varchar(20),
	@frequency varchar(20),
	@dot_shipping_name varchar(130),
	@surcharge_exempt char(1),
	@pack_bulk_solid_yard char(1),
	@pack_bulk_solid_ton char(1),
	@pack_bulk_liquid char(1),
	@pack_totes char(1),
	@pack_totes_size varchar(30),
	@pack_cy_box char(1),
	@pack_drum char(1),
	@pack_other char(1),
	@pack_other_desc varchar(15),
	@logon char (10))
AS
	set nocount on
	update wcr set
	date_modified = getdate(),
	modified_by = @logon,
	active = 'T',
	volume = @volume,
	frequency = @frequency,
	dot_shipping_name = @dot_shipping_name,
	surcharge_exempt = @surcharge_exempt,
	pack_bulk_solid_yard = @pack_bulk_solid_yard,
	pack_bulk_solid_ton = @pack_bulk_solid_ton,
	pack_bulk_liquid = @pack_bulk_liquid,
	pack_totes = @pack_totes,
	pack_totes_size = @pack_totes_size,
	pack_cy_box = @pack_cy_box,
	pack_drum = @pack_drum,
	pack_other = @pack_other,
	pack_other_desc = @pack_other_desc
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
    ON OBJECT::[dbo].[SP_WCR_0204_UPDATE_SECTION2] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[SP_WCR_0204_UPDATE_SECTION2] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[SP_WCR_0204_UPDATE_SECTION2] TO [EQAI]
    AS [dbo];

