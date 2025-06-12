Drop Proc If Exists sp_emanifest_get_data
go

create proc sp_emanifest_get_data (
	@source_company_id		int 									/* company_id */
	, @source_profit_ctr_id 	int 									/* profit_ctr_id */
	, @source_table			varchar(40)								/* receipt, workorder, etc */
	, @source_id				int 									/* receipt_id, workorder_id, etc */
	, @manifest				varchar(20)								/* manifest # */
) as 
/******************************************************************************************
Retrieve Manifest header (anything that's not per-line) data

sp_emanifest_get_data	3, 0, 'receipt', 1158399, '002060114JJK'
sp_emanifest_get_data	2, 0, 'receipt', 533269, '013258567JJK'
sp_emanifest_get_data	21, 0, 'receipt', 1009480, '013139568JJK'
sp_emanifest_get_data	41, 0, 'receipt', 118305, '016839946JJK'
C:\Users\jonathan\source\Workspaces\EcolDevelop\ERP (CMMI)\Dragon (EQAI)\Development\DB_Plt_AI\DB_Plt_AI\dbo\Stored Procedures
SELECT * FROM receipt where receipt_id = 1158399 and company_id = 3
SELECT TOP 10 * FROM receiptdiscrepancy where discrepancy_part_reject_flag = 'T'
SELECT * FROM receiptdiscrepancy where receipt_id = 118318 and company_id = 41
SELECT  *  FROM    PortOfEntry WHERE portofentry_uid = 138

******************************************************************************************/

if @source_table = 'receipt' 
begin

	select distinct
	case when ReceiptDiscrepancy.discrepancy_full_reject_flag = 'T' 
		or ReceiptDiscrepancy.discrepancy_part_reject_flag = 'T'
		or ReceiptDiscrepancy.rejected_from_another_tsdf_flag = 'T' -- 7/29/2019: JPB
		then 'T' else 'F' end	rejection
	, ReceiptDiscrepancy.transporter_on_site_flag rejectionInfo_transporterOnSite /* T/F */
	, case when ReceiptDiscrepancy.discrepancy_full_reject_flag = 'T' 
		or ReceiptDiscrepancy.rejected_from_another_tsdf_flag = 'T'
		then 'FullReject' else case when ReceiptDiscrepancy.discrepancy_part_reject_flag = 'T' then 'PartialReject' else '' end	end rejectionInfo_rejectionType
	, case ReceiptDiscrepancy.alt_facility_type
		when 'G' then 'Generator'
		when 'A' then 'Tsdf'
		when 'O' then 'Tsdf' -- Original TSDF  7/29/2019: JPB
		else ReceiptDiscrepancy.alt_facility_type
		end rejectionInfo_alternateDesignatedFacilityType
/*
	, ReceiptDiscrepancy.alt_facility_epa_id	rejectionInfo_alternateDesignatedFacility_epaSiteId
	, ReceiptDiscrepancy.generator_id		rejectionInfo_alternateDesignatedFacility_generatorId
	, ReceiptDiscrepancy.alt_facility_code		rejectionInfo_alternateDesignatedFacility_tsdfcode
*/
	, t.tsdf_epa_id		rejectionInfo_alternateDesignatedFacility_epaSiteId
	, ReceiptDiscrepancy.generator_id		rejectionInfo_alternateDesignatedFacility_generatorId
	, t.tsdf_code		rejectionInfo_alternateDesignatedFacility_tsdfcode
	, null as rejectionInfo_alternateDesignatedFacility_order
	, ReceiptDiscrepancy.manifest_ref_number	rejectionInfo_newManifestTrackingNumbers
	, case when ReceiptDiscrepancy.receipt_id is not null then 'T' else 'F' end		discrepancy
	, ReceiptDiscrepancy.discrepancy_residue_flag	residue
	, ReceiptDiscrepancy.manifest_ref_number	residueNewManifestTrackingNumbers
	, case when exists (
		select 1 from ReceiptDiscrepancy rd
		WHERE rd.receipt_id = r.receipt_id and rd.company_id = r.company_id and rd.profit_ctr_id = r.profit_ctr_id
		and rd.import_to_us_flag = 'T') then 'T' else 'F' end	import
	, g.generator_name	importInfo_ImportGenerator_name
	, coalesce(g.gen_mail_addr1, g.generator_address_1)	importInfo_ImportGenerator_address
	, coalesce(g.gen_mail_city, g.generator_city) importInfo_ImportGenerator_city
	, c.epa_code	importInfo_ImportGenerator_country_code
	, coalesce(g.gen_mail_zip_code, g.generator_zip_code)	importInfo_ImportGenerator_postalCode
	, coalesce(g.gen_mail_state, g.generator_state)	importInfo_ImportGenerator_province
	, poi.epa_port_city_name		importInfo_ImportPortInfo_city
	, poi.epa_port_city_state		importInfo_ImportPortInfo_state_code
	, case when isnull(ReceiptDiscrepancy.alt_facility_type, 'T') = 'O' or ReceiptDiscrepancy.discrepancy_residue_flag = 'T' then 'T' else 'F' end	containsPreviousRejectOrResidue 

	-- , ReceiptDiscrepancy.manifest_ref_number	OriginalManifestTrackingNumbers -- We don't have a way to track this in EQAI, so giving empty string.
	-- 20231129 - I can't think of a way the above ReceiptDiscrepancy.manifest_ref_number would ever be the "original manifest number"
	-- so bumping it back to Receipt.manifest
	, r.manifest as OriginalManifestTrackingNumbers
	, rm.handling_instructions	handlingInstructions

	, case when isnull(ReceiptDiscrepancy.alt_facility_type, 'T') = 'O' then 'Tsdf' else '' end additionalInfo_newManifestDestination
	, ReceiptDiscrepancy.date_departed
	into #t
	from receipt r
		JOIN generator g (nolock) on r.generator_id = g.generator_id
		JOIN tsdf t (nolock) on r.company_id = t.eq_company and r.profit_ctr_id = t.eq_profit_ctr and t.tsdf_status = 'A'
		LEFT JOIN ReceiptDiscrepancy (nolock)
			on ReceiptDiscrepancy.receipt_id = r.receipt_id 
			and ReceiptDiscrepancy.company_id = r.company_id 
			and ReceiptDiscrepancy.profit_ctr_id = r.profit_ctr_id
			-- and isnull(ReceiptDiscrepancy.alt_facility_type, 'T') = 'O'
		left join Country c 
			on g.generator_country = c.country_code
		left join ReceiptManifest rm on r.receipt_id = rm.receipt_id and r.company_id = rm.company_id and r.profit_ctr_id = rm.profit_ctr_id
			and rm.page = 1 -- ???
		LEFT JOIN ReceiptDiscrepancy ReceiptDiscrepancyPOI (nolock)
			on ReceiptDiscrepancyPOI.receipt_id = r.receipt_id 
			and ReceiptDiscrepancyPOI.company_id = r.company_id 
			and ReceiptDiscrepancyPOI.profit_ctr_id = r.profit_ctr_id
		left join PortOfEntry poi
			on ReceiptDiscrepancyPOI.portofentry_uid = poi.portofentry_uid
		left join ReceiptTransporter rt1
			on rt1.receipt_id = r.receipt_id and rt1.company_id = r.company_id and rt1.profit_ctr_id = r.profit_ctr_id and rt1.transporter_sequence_id = 1
	where r.receipt_id = @source_id
	and r.company_id = @source_company_id
	and r.profit_ctr_id = @source_profit_ctr_id
	and @manifest in (r.manifest, ReceiptDiscrepancy.manifest_ref_number)
	and r.manifest_flag in ('M')
	and r.trans_type = 'D'
	
	select 
		rejection	
		, rejectionInfo_transporterOnSite	
		, rejectionInfo_rejectionType	
		, rejectionInfo_alternateDesignatedFacilityType	
		, rejectionInfo_alternateDesignatedFacility_epaSiteId	
		, rejectionInfo_alternateDesignatedFacility_generatorId	
		, rejectionInfo_alternateDesignatedFacility_tsdfcode	
		, row_number() over (order by rejectionInfo_alternateDesignatedFacility_epaSiteId) as rejectionInfo_alternateDesignatedFacility_order	
		, rejectionInfo_newManifestTrackingNumbers	
		, discrepancy	
		, residue	
		, residueNewManifestTrackingNumbers	
		, import	
		, importInfo_ImportGenerator_name	
		, importInfo_ImportGenerator_address	
		, importInfo_ImportGenerator_city	
		, importInfo_ImportGenerator_country_code	
		, importInfo_ImportGenerator_postalCode	
		, importInfo_ImportGenerator_province	
		, importInfo_ImportPortInfo_city	
		, importInfo_ImportPortInfo_state_code	
		, containsPreviousRejectOrResidue	
		, OriginalManifestTrackingNumbers	
		, handlingInstructions	
		, additionalInfo_newManifestDestination
		, date_departed
	from #t
	
end


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_emanifest_get_data] TO [ATHENA_SVC]


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_emanifest_get_data] TO [EQAI]

