
create proc sp_emanifest_waste (
	@source_company_id		int 									/* company_id */
	, @source_profit_ctr_id 	int 									/* profit_ctr_id */
	, @source_table			varchar(40)								/* receipt, workorder, etc */
	, @source_id				int 									/* receipt_id, workorder_id, etc */
	, @manifest				varchar(20)								/* manifest # */
) as 
/******************************************************************************************
Retrieve Handler list of sources + id + order ordinal per emanifest source

sp_emanifest_waste	27, 0, 'receipt', 139322, '018350895JJK' -- 7 haz
sp_emanifest_waste	3, 0, 'receipt', 1242837, '012004124JJK' -- 1 haz
sp_emanifest_waste	2, 0, 'receipt', 550709, '013968726JJK' -- 7 haz, 1 nonhaz: DOT Info missing 5/31
sp_emanifest_waste	21, 0, 'receipt', 1103768, '013721895JJK' -- No lines to send, on purpose for testing
sp_emanifest_waste	3, 0, 'receipt', 1297178, '009773055FLE'
sp_emanifest_waste	21, 1, 'receipt', 28679, '017864623JJK'
sp_emanifest_waste 21, 0, 'receipt', 2007880, '003079433GBF' -- No lines to send, on purpose for testing

sp_emanifest_waste	25, 0, 'receipt', 97620, '011179022FLE'

SELECT  *  FROM    receipt WHERE receipt_id = 328409 and line_id = 1 and company_id = 42

SELECT  *  FROM    wastecode where display_name = '352'

SELECT * FROM receiptpcb WHERE receipt_id =  1295421 and company_id = 3

SELECT hazmat, *  FROM    profile WHERE profile_id = 598731

SELECT manifest, * FROM receipt where receipt_id = 1295314 and company_id = 3
SELECT TOP 10 * FROM ReceiptPcb ORDER BY date_added desc
SELECT * FROM profile WHERE profile_id in (220182, 263349, 338541, 436452)

SELECT * FROM Emanifest
select r.line_id, 
substring((select ',' + wc.display_name from receiptwastecode rwc join wastecode wc on rwc.waste_code_uid = wc.waste_code_uid
WHERE rwc.receipt_id = r.receipt_id and rwc.line_id = r.line_id and rwc.company_id = r.company_id and rwc.profit_ctr_id = r.profit_ctr_id
and wc.waste_code_origin = 'F' and wc.status = 'A' for xml path ('')), 2, 20000)
from receipt r where receipt_id = 139322 and company_id = 27 and profit_ctr_id = 0
'D001,D010,F003'

select * from receiptwastecode where receipt_id = 139322 and company_id = 27 and profit_ctr_id = 0
select top 300 * from receipt WHERE submitted_flag = 'T' and manifest_flag = 'M' and manifest_hazmat = 'T' order by receipt_date desc
SELECT * FROM wastecode where waste_code_uid in (572, 751, 1363)

sp_emanifest_waste 22, 0, 'receipt', 218165

SELECT isnull(r.manifest_un_na_flag, '') ,
		isnull(convert(varchar(20), r.manifest_un_na_number), '')
		, * FROM receipt r WHERE receipt_id = 218165 and company_id = 22
		
SELECT * FROM profile WHERE profile_id = 469025		

SELECT * FROM EQAI_EPA_PCBLoadType_jpb

******************************************************************************************/

-- borrowed from sp_biennial_report_source
DECLARE @waste_density varchar(6) = '8.3453'
	, @water_density float = 8.34543


if @source_table = 'receipt' 
begin

	/* First: Only submit required manifests:
		Voluntary manifests have no fed/state haz waste codes, no pcbs, and are not in/from Illinois
		The rest are mandatory
		You DO submit all lines on a manifest, even if some are non-haz
		But you don't submit a manifest if it's only got voluntary info on it.
	*/
	
	/* Hazardous Waste Code Present */
	select distinct 
	r.company_id
	, r.profit_ctr_id
	, r.receipt_id
	into #req
	from receipt r
	where r.receipt_id = @source_id
	and r.company_id = @source_company_id
	and r.profit_ctr_id = @source_profit_ctr_id
	and r.manifest = @manifest
	and dbo.fn_IsEmanifestRequired(r.company_id, r.profit_ctr_id, @source_table, r.receipt_id, @manifest) >= 0
	and exists ( /* Only manifests initiated on/after 6/30/18 */ select top 1 1 from ReceiptManifest where receipt_id = @source_id and company_id = @source_company_id and profit_ctr_id = @source_profit_ctr_id and isnull(generator_sign_date, '1/1/1980') >= '6/30/2018')	
	
	-- now #req has key field info for required source that matches the input criteria
	
	-- Now to retrieve manifest info for #req related data

	select 
	r.manifest_hazmat	dotHazardous -- This is box 9a
	
	, r.manifest_dot_shipping_name		dotInformation_properShippingName_code
	, r.manifest_rq_flag				dotInformation_rqIndicator
	, r.manifest_rq_reason				dotInformation_rqDescription
	, ltrim(rtrim(case when isnull(r.manifest_un_na_flag, '') = 'X' then '' else isnull(r.manifest_un_na_flag, '') end + 
		case when 
		-- official NOID list;
			convert(varchar(max), r.manifest_dot_shipping_name) LIKE 'Batteries, dry, sealed, n.o.s.%' 
			OR 
			convert(varchar(max), r.manifest_dot_shipping_name) LIKE 'Cartridges power device (used to project fastening devices)%'
			OR 
			convert(varchar(max), r.manifest_dot_shipping_name) LIKE 'Cartridges, small arms%'
			OR 
			convert(varchar(max), r.manifest_dot_shipping_name) LIKE 'Consumer commodity%'
			OR 
			convert(varchar(max), r.manifest_dot_shipping_name) LIKE 'Lighters, new or empty, purged of all residual fuel and vapors%'
		then 'NOID' else 
			case when 
				right(isnull('0000' + convert(varchar(20), r.manifest_un_na_number), ''), 4)
				= '0000' then 'NOID'
			else
				right(isnull('0000' + convert(varchar(20), r.manifest_un_na_number), ''), 4)
			end
		end)) idNumber_code
	, r.manifest_package_group		packingGroup_code
	, r.manifest_hazmat_class			hazardClass_code

/*
	, dbo.fn_manifest_dot_description('P', r.profile_id)	printedDotInformation
	-- Problem: Above reads profile info, which may have changed. Receipt copies are source of truth.
	-- So below we re-enact the function's logic:
*/	
	
	, printedDotInformation = 
		ltrim(rtrim(replace(replace(replace(replace(
		case when isnull(r.manifest_RQ_flag, '') = 'T' then 'RQ, ' else '' end
		+
		case when isnull(r.manifest_un_na_flag, '') = 'X' then '' else isnull(r.manifest_un_na_flag, '') end
		+
		case when isnull(r.manifest_UN_NA_number, 0) = 0 then '' else right('0000' + convert(varchar(20), r.manifest_UN_NA_number), 4) end
		+
		case when
			(
			case when isnull(r.manifest_un_na_flag, '') = 'X' then '' else isnull(r.manifest_un_na_flag, '') end
			+
			case when isnull(r.manifest_UN_NA_number, 0) = 0 then '' else right('0000' + convert(varchar(20), r.manifest_UN_NA_number), 4) end
			)
			<> '' then ', ' else ''
		end
		+
		isnull(convert(varchar(max), r.manifest_DOT_shipping_name), '')
		+
		case when isnull(r.manifest_hazmat_class, '') = '' then '' else ', ' + isnull(r.manifest_hazmat_class, '') end
		+
		case when isnull(r.manifest_sub_hazmat_class, '') = '' then '' else '(' + isnull(r.manifest_sub_hazmat_class, '') + ')' end
		+
		case when isnull(r.manifest_package_group, '') = '' then '' else ', PG' + isnull(r.manifest_package_group, '') end
		+
		case when isnull(r.manifest_RQ_reason, '') = '' then '' else ', ' + isnull(r.manifest_RQ_reason, '') end
		+
		case when isnull(CONVERT(Varchar(20), r.manifest_ERG_number), '') + isnull(r.manifest_ERG_suffix, '') = '' then '' else ', ERG#' + isnull(CONVERT(Varchar(20), r.manifest_ERG_number), '') + isnull(r.manifest_ERG_suffix, '') end
		+
		case when isnull(r.manifest_dot_sp_number, '') = '' then '' else ', DOT-SP ' + isnull(r.manifest_dot_sp_number, '') end
		, char(10), ' '), char(13), ' '), '  ', ' '), ',,', ',')))
	, r.manifest_erg_number				emergencyGuideNumber_code

	-- borrowed from sp_biennial_report_source
	,  IsNull(COALESCE(wastetype.category+' '+coalesce(wastetype.biennial_description, wastetype.description), profile.approval_desc),'') wasteDescription

	, r.container_count					quantity_containerNumber
	, r.manifest_container_code			quantity_containerType_code
	, r.manifest_quantity				quantity_quantity
	, r.manifest_unit					quantity_unitOfMeasurement_code

	, case when isnull(r.manifest_unit, '') in ('G', 'L', 'N')
		then COALESCE(
			case when isnull(profileLab.specific_gravity,0) <> 0 then profileLab.specific_gravity * @water_density else null end
			, case when isnull(profileLab.density, 0) <> 0 then profileLab.density else null end
			, @waste_density
			) 
		else null end brinfo_density

	, case when isnull(r.manifest_unit, '') in ('G', 'L', 'N')
		then '1'
		else null end brinfo_densityUnitOfMeasurement
	
	, profile.EPA_form_code		brinfo_formCode_code
	, profile.EPA_source_code	brinfo_sourceCode_code
	
	, 'T'	br
	
	, substring((select ',' + wc.display_name from receiptwastecode rwc join wastecode wc on rwc.waste_code_uid = wc.waste_code_uid
		WHERE rwc.receipt_id = r.receipt_id and rwc.line_id = r.line_id and rwc.company_id = r.company_id and rwc.profit_ctr_id = r.profit_ctr_id
		and wc.waste_code_origin = 'F' and wc.status = 'A' and wc.haz_flag = 'T' for xml path ('')), 2, 20000)	hazardousWaste_federalWasteCodes
	, substring((select ',' + wc.display_name from receiptwastecode rwc join wastecode wc on rwc.waste_code_uid = wc.waste_code_uid
		WHERE rwc.receipt_id = r.receipt_id and rwc.line_id = r.line_id and rwc.company_id = r.company_id and rwc.profit_ctr_id = r.profit_ctr_id
		and wc.waste_code_origin = 'S' and wc.state = tsdf.tsdf_state and wc.state not in ('TX', 'PA') and wc.status = 'A' for xml path ('')), 2, 20000)	hazardousWaste_tsdfStateWasteCodes
	, substring((select ',' + wc.display_name from receiptwastecode rwc join wastecode wc on rwc.waste_code_uid = wc.waste_code_uid
		WHERE rwc.receipt_id = r.receipt_id and rwc.line_id = r.line_id and rwc.company_id = r.company_id and rwc.profit_ctr_id = r.profit_ctr_id
		and wc.waste_code_origin = 'S' and wc.state = 'TX' and wc.status = 'A' and wc.display_name not in ('NHNI', 'Exempt') for xml path ('')), 2, 20000)	hazardousWaste_txWasteCodes
	, substring((select ',' + wc.display_name from receiptwastecode rwc join wastecode wc on rwc.waste_code_uid = wc.waste_code_uid
		WHERE rwc.receipt_id = r.receipt_id and rwc.line_id = r.line_id and rwc.company_id = r.company_id and rwc.profit_ctr_id = r.profit_ctr_id
		and wc.waste_code_origin = 'S' and wc.state = g.generator_state and wc.state not in ('TX', 'PA') and wc.status = 'A' for xml path ('')), 2, 20000)	hazardousWaste_generatorStateWasteCodes
	, '' hazardousWaste_generatorTxWasteCodes
		/*
		hazardousWaste_generatorTxWasteCodes was combined with hazardousWaste_tsdfTxWasteCodes for the single field: hazardousWaste_txWasteCodes
		But the results of this sp are read out by field number, not name, so the blank field now stays to preserve numbering.
		was:
		substring((select ',' + wc.display_name from receiptwastecode rwc join wastecode wc on rwc.waste_code_uid = wc.waste_code_uid
		WHERE rwc.receipt_id = r.receipt_id and rwc.line_id = r.line_id and rwc.company_id = r.company_id and rwc.profit_ctr_id = r.profit_ctr_id
		and wc.waste_code_origin = 'S' and wc.state = g.generator_state and wc.state = 'TX' and wc.status = 'A' for xml path ('')), 2, 20000)
		
		
		As of 5/28/2018 this is no longer required, but keeping because results are retrieved by column #
		*/ 
	, '' manifest_management_code -- deprecated instance
	
	, case when exists (	
		select top 1 1
		FROM ReceiptPCB (nolock) 
		WHERE ReceiptPCB.receipt_id = r.receipt_id 
		and ReceiptPCB.line_id = r.line_id 
		and ReceiptPCB.company_id = r.company_id 
		and ReceiptPCB.profit_ctr_id = r.profit_ctr_id
	) then 'T' else 'F' end pcb
/*
	, EpaPcbLoadType.code pcbInfo_loadType_code
	, ReceiptPCB.container_id	pcbInfo_articleContainerId
	, ReceiptPCB.storage_start_date	pcbInfo_dateOfRemoval
	, ReceiptPCB.weight	pcbInfo_weight
	, ReceiptPCB.waste_desc	pcbInfo_wasteType
	, ReceiptPCB.waste_desc	pcbInfo_bulkIdentity
*/	
	, null pcbInfo_loadType_code
	, null	pcbInfo_articleContainerId
	, null	pcbInfo_dateOfRemoval
	, null	pcbInfo_weight
	, null	pcbInfo_wasteType
	, null	pcbInfo_bulkIdentity
	
	, ReceiptDiscrepancy.discrepancy_qty_flag	discrepancyResidueInfo_wasteQuantity
	, ReceiptDiscrepancy.discrepancy_type_flag	discrepancyResidueInfo_discrepancyWasteType
	, ReceiptDiscrepancy.discrepancy_description	discrepancyResidueInfo_discrepancyComments
	, ReceiptDiscrepancy.discrepancy_residue_flag	discrepancyResidueInfo_residue
	, ReceiptDiscrepancy.discrepancy_description	discrepancyResidueInfo_residueComments

	, case when ltrim(rtrim(isnull(r.manifest_management_code, 'NONE'))) in ('', 'NONE', 'LIW') then 
		(select isnull(management_code, '') from profilequoteapproval pqa join treatmentdetail td on pqa.treatment_id = td.treatment_id and pqa.company_id = td.company_id and pqa.profit_ctr_id = td.profit_ctr_id
		WHERE pqa.profile_id = r.profile_id and pqa.company_id = r.company_id and pqa.profit_ctr_id = r.profit_ctr_id)
	else isnull(r.manifest_management_code, 'NONE') end managementMethod
	
	, r.consent	AdditionalInfo_consentNumber
	, r.manifest_line	lineNumber
	, epaWaste = 
		case when exists (
			select top 1 1 from receiptwastecode rwc join wastecode wc on rwc.waste_code_uid = wc.waste_code_uid
			WHERE rwc.receipt_id = r.receipt_id and rwc.line_id = r.line_id and rwc.company_id = r.company_id and rwc.profit_ctr_id = r.profit_ctr_id
			and wc.status = 'A' and wc.haz_flag = 'T' and not (wc.state = 'MI' and wc.waste_type_code = 'P')) then 'T' else 'F' end
		/*
		
		Latest incarnation:
		6/6/2018 - EPA: "If the waste has a federal or state hazardous code, epaWaste = true."
		select * from wastecode WHERE state = 'MI' and haz_flag = 'T' and waste_type_code = 'P'

		*/

	-- These fields aren't required output, just extra handy pieces for debugging
	, r.manifest, r.receipt_id, r.line_id, r.company_id, r.profit_ctr_id, r.profile_id

	into #w
	from #req req
		JOIN receipt r on req.receipt_id = r.receipt_id and req.company_id = r.company_id and req.profit_ctr_id = r.profit_ctr_id
			-- and r.fingerpr_status = 'A' and r.receipt_status = 'A'
		JOIN Profile  (nolock) ON (r.profile_id = Profile.Profile_id)
		JOIN WasteType (nolock)  ON (Profile.wastetype_id = WasteType.wastetype_id)
		JOIN ProfileLab (nolock) ON r.profile_id = ProfileLab.profile_id
			AND ProfileLab.type = 'A'
		join TSDF (nolock) ON r.company_id = tsdf.eq_company and r.profit_ctr_id = tsdf.eq_profit_ctr and tsdf.tsdf_status = 'A'
		JOIN generator g (nolock) on r.generator_id = g.generator_id
		/*
		LEFT JOIN ReceiptPCB (nolock) 
			on ReceiptPCB.receipt_id = r.receipt_id and ReceiptPCB.line_id = r.line_id 
			and ReceiptPCB.company_id = r.company_id and ReceiptPCB.profit_ctr_id = r.profit_ctr_id
		LEFT JOIN EpaPcbLoadType (nolock) on ReceiptPcb.load_type_uid = EpaPcbLoadType.loadtype_uid
		*/
		LEFT JOIN ReceiptDiscrepancy (nolock)
			on ReceiptDiscrepancy.receipt_id = r.receipt_id 
			and ReceiptDiscrepancy.company_id = r.company_id and ReceiptDiscrepancy.profit_ctr_id = r.profit_ctr_id
			and ReceiptDiscrepancy.alt_facility_type is not null
	where r.trans_mode = 'I'
	-- and r.trans_type = 'D'
	and r.manifest = @manifest
	and r.manifest_flag in ('M') -- manifest (bond)
	and isnull(r.manifest_form_type, 'H') = 'H' -- hazardous (james bond)
	and r.trans_type = 'D'
	and r.receipt_status not in ('V', 'R')
	and r.fingerpr_status not in ('V', 'R')
	order by r.manifest_line
	
	update #w set printedDotInformation = left(printedDotInformation, len(printedDotInformation)-1)
	where right(printedDotInformation, 1) = ','
	
	-- update #w set managementMethod = null where managementMethod = 'NONE'
	
	select * from #w order by lineNumber
	
end


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_emanifest_waste] TO [ATHENA_SVC]
    AS [dbo];


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_emanifest_waste] TO [EQAI]
    AS [dbo];

