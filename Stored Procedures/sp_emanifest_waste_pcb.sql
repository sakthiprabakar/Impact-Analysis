create proc sp_emanifest_waste_pcb (
	@source_company_id		int 									/* company_id */
	, @source_profit_ctr_id 	int 									/* profit_ctr_id */
	, @source_table			varchar(40)								/* receipt, workorder, etc */
	, @source_id				int 									/* receipt_id, workorder_id, etc */
	, @manifest				varchar(20)								/* manifest # */
	, @manifest_line		varchar(20)								/* manifest line # */
) as 
/******************************************************************************************
Retrieve List of PCBs to populate on a manifest line

sp_emanifest_waste_pcb	3, 0, 'receipt', 1295421, '019092366JJK', '1'
exec sp_emanifest_waste_pcb '3', '0', 'receipt', '1295421', '019092366JJK', '1'

SELECT * FROM receiptpcb WHERE receipt_id =  1295421 and company_id = 3
SELECT manifest_line, * FROM receipt WHERE receipt_id =  1295421 and company_id = 3 and line_id = 1

******************************************************************************************/

if @source_table = 'receipt' 
begin

	
	-- Now to retrieve manifest info for #req related data

	select 

	EpaPcbLoadType.code pcbInfo_loadType_code
	, ReceiptPCB.container_id	pcbInfo_articleContainerId
	, ReceiptPCB.storage_start_date	pcbInfo_dateOfRemoval
	, ReceiptPCB.weight	pcbInfo_weight
	, ReceiptPCB.waste_desc	pcbInfo_wasteType
	, ReceiptPCB.waste_desc	pcbInfo_bulkIdentity

	from receipt r (nolock)
		JOIN ReceiptPCB (nolock) 
			on ReceiptPCB.receipt_id = r.receipt_id and ReceiptPCB.line_id = r.line_id 
			and ReceiptPCB.company_id = r.company_id and ReceiptPCB.profit_ctr_id = r.profit_ctr_id
		JOIN EpaPcbLoadType (nolock) on ReceiptPcb.load_type_uid = EpaPcbLoadType.loadtype_uid
	where r.trans_mode = 'I'
	and r.trans_type = 'D'
	and r.receipt_id = @source_id
	and r.company_id = @source_company_id
	and r.profit_ctr_id = @source_profit_ctr_id
	and r.manifest = @manifest
	and r.manifest_line = @manifest_line
	order by sequence_id
		
end


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_emanifest_waste_pcb] TO [ATHENA_SVC]
    AS [dbo];


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_emanifest_waste_pcb] TO [EQAI]
    AS [dbo];

