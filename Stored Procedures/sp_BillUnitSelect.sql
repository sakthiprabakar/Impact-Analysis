create procedure [dbo].[sp_BillUnitSelect]
	@bill_unit_code varchar(4) = null
as 
begin

SELECT bill_unit_code,
       bill_unit_desc,
       disposal_flag,
       tran_flag,
       service_flag,
       project_flag,
       gal_conv,
       yard_conv,
       kg_conv,
       pound_conv,
       gm_bill_unit_code,
       date_added,
       date_modified,
       modified_by,
       sched_conv_bulk,
       container_flag,
       mdeq_uom,
       manifest_unit,
       rowguid
FROM   BillUnit 
	where bill_unit_code = ISNULL(@bill_unit_code, bill_unit_code)
	order by bill_unit_desc, bill_unit_code



end

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_BillUnitSelect] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_BillUnitSelect] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_BillUnitSelect] TO [EQAI]
    AS [dbo];

