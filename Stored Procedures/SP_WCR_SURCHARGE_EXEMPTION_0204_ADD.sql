/***************************************************************************************
sp_wcr_surcharge_exemption_0204_add
Inserts Surcharge Exempt info

Input:
	The Location being sent to
	The Waste Type to update
	The Waste Common Name to update
	The Quantity and Units to update
	The Manifest number to update
	The Approval number to update
	The Reason this shipment is exempt
	Logon of the calling process (customer id, eqai login name, etc)

Returns:
	Nothing

What it does:
	Creates a new wcr_surcharge_exempt record

02/26/2004 JPB	Created
****************************************************************************************/
CREATE PROCEDURE SP_WCR_SURCHARGE_EXEMPTION_0204_ADD (
	@sr_location char(10),
	@sr_waste_type varchar(50),
	@sr_waste_common_name varchar(50),
	@sr_qty_units varchar(100),
	@sr_manifest varchar(20),
	@sr_approval varchar(20),
	@sr_exempt_reason varchar(15),
	@logon char(10))
AS
	set nocount on
	declare @int_sr_id int
	select @int_sr_id = isnull(max(sr_id) + 1,1) from wcr_surcharge_exempt

	insert wcr_surcharge_exempt
		(sr_id, sr_location, sr_waste_common_name, sr_qty_units, sr_manifest, sr_approval, sr_exempt_reason, logon, date_added, sr_version)
	values
		(@int_sr_id, @sr_location, @sr_waste_common_name, @sr_qty_units, @sr_manifest, @sr_approval, @sr_exempt_reason, @logon, getdate(), '0204')
	set nocount off
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[SP_WCR_SURCHARGE_EXEMPTION_0204_ADD] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[SP_WCR_SURCHARGE_EXEMPTION_0204_ADD] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[SP_WCR_SURCHARGE_EXEMPTION_0204_ADD] TO [EQAI]
    AS [dbo];

