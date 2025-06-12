use Plt_ai
go

if exists (select 1 from sysobjects where type = 'P' and name = 'sp_ss_get_trip_tsdf_approvals')
	drop procedure sp_ss_get_trip_tsdf_approvals
go

create procedure sp_ss_get_trip_tsdf_approvals
	@trip_id int,
	@trip_sequence_id int = 0
with recompile
as
/**************

 01/10/2020 rwb Created
 04/29/2021 rwb ADO 17520 - query needs to reference TSDFApprovalConstituent.UHC instead of Constituents.UHC_flag
 05/19/2021 rwb ADO 20860 - the call to dbo.fn_get_label_default_type needs to pass WO info instead of TSDF Approval
 03/20/2023 rwb ADO 63176 - add TSDFApproval.comments to the result set

 exec sp_ss_get_trip_tsdf_approvals 119493

 **************/

declare @id int,
		@last_id int,
		@const_id int,
		@sub varchar(100),
		@subcategory varchar(4096)

set transaction isolation level read uncommitted

set nocount on

create table #profile_uhc_const (
	tsdf_approval_id int,
	uhc_const varchar(4096)
)

create table #m (
workorder_id int not null,
company_id int not null,
profit_ctr_id int not null,
sequence_id int not null,
bill_unit_code varchar(4) not null,
manifest_flag char(1) null,
billing_flag char(1) null,
added_by varchar(10) null,
date_added datetime null,
modified_by varchar(10) null,
date_modified datetime null
)

-- codes defined in WorkOrderDetailUnit
insert #m
select distinct wodu.workorder_id, wodu.company_id, wodu.profit_ctr_id, wodu.sequence_id,
		wodu.size, isnull(wodu.manifest_flag,'F'), isnull(wodu.billing_flag,'F'), 
		wod.added_by, wod.date_added, wod.modified_by, wod.date_modified
from WorkOrderDetailUnit wodu
join WorkOrderDetail wod
	on wodu.workorder_id = wod.workorder_ID
	and wodu.company_id = wod.company_id
	and wodu.profit_ctr_id = wod.profit_ctr_id
	and wodu.sequence_id = wod.sequence_id
	and wod.resource_type = 'D'
join WorkOrderHeader woh
	on wod.workorder_id = woh.workorder_id
	and wod.company_id = woh.company_id
	and wod.profit_ctr_id = woh.profit_ctr_id
--	and woh.workorder_status <> 'V'
	and woh.trip_id = @trip_id

-- codes not defined in WorkOrderDetailUnit (TSDFApproval)
insert #m
select distinct wod.workorder_id, wod.company_id, wod.profit_ctr_id, wod.sequence_id,
		tap.bill_unit_code, 'F', 'T', 'SA', GETDATE(), 'SA', GETDATE()
from WorkOrderDetail wod
join TSDF t
	on t.TSDF_code = wod.TSDF_code
	and ISNULL(t.eq_flag, 'F') = 'F'
join TSDFApproval ta
	on ta.tsdf_approval_id = wod.tsdf_approval_id
	and ta.TSDF_approval_status = 'A'
join TSDFApprovalPrice tap
	on tap.tsdf_approval_id = ta.tsdf_approval_id
	and tap.record_type = 'D'
where wod.workorder_id in (select workorder_id from WorkOrderHeader where trip_id = @trip_id /*and workorder_status <> 'V'*/)
and wod.company_id = (select company_id from TripHeader where trip_id = @trip_id)
and wod.profit_ctr_id = (select profit_ctr_id from TripHeader where trip_id = @trip_id)
and wod.resource_type = 'D'
and not exists (select 1 from #m
				where workorder_id = wod.workorder_ID
				and company_id = wod.company_id
				and profit_ctr_id = wod.profit_ctr_id
				and sequence_id = wod.sequence_ID
				and bill_unit_code = tap.bill_unit_code)

-- Fix for GEM 48441
update #m
   set manifest_flag = 'T'
from #m m
where bill_unit_code = 'LBS'
and not exists (select 1 from #m
                        where workorder_id = m.workorder_id
                        and company_id = m.company_id
                        and profit_ctr_id = m.profit_ctr_id
                        and sequence_id = m.sequence_id
                        and manifest_flag = 'T')


declare c_const cursor for
select distinct wod.TSDF_approval_id, tc.const_id, c.const_desc
from WorkOrderDetail wod
join WorkOrderHeader woh
	on woh.workorder_id = wod.workorder_id
	and woh.company_id = wod.company_id
	and woh.profit_ctr_id = wod.profit_ctr_id
	and woh.trip_id = @trip_id
	and (@trip_sequence_id = 0 or woh.trip_sequence_id = @trip_sequence_id)
join TSDFApprovalConstituent tc
	on tc.TSDF_approval_id = wod.TSDF_approval_id
	and tc.UHC = 'T'
join Constituents c
	on c.const_id = tc.const_id
where wod.resource_type = 'D'
order by wod.TSDF_approval_id, tc.const_id

open c_const
fetch c_const into @id, @const_id, @sub

while @@fetch_status = 0
begin
	if @id = isnull(@last_id,0)
		set @subcategory = @subcategory + ', ' + convert(varchar(10),@const_id) + ' - ' + @sub

	else
	begin
        if isnull(@last_id,0) > 0
       		insert #profile_uhc_const values (@last_id, isnull(@subcategory,''))

        set @subcategory = convert(varchar(10),@const_id) + ' - ' + @sub
		set @last_id = @id
	end
 
    fetch c_const into @id, @const_id, @sub
end

close c_const
deallocate c_const

if coalesce(@last_id,0) > 0
	insert #profile_uhc_const values (@last_id, isnull(@subcategory,''))

set nocount off

------

select wh.workorder_id,
		wh.company_id,
		wh.profit_ctr_ID,
		wd.sequence_ID,
		wd.TSDF_approval_id,
		coalesce(wd.TSDF_code,'') TSDF_code,
		coalesce(wd.manifest,'') manifest,
		case ltrim(wm.manifest_state) when 'H' then 'HAZ' else case when th.use_manifest_haz_only_flag = 'B' then 'BOL' else 'NONHAZ' end end manifest_type,
		coalesce(ta.TSDF_approval_code,'') TSDF_approval_code,
		coalesce(wd.description,'') description,
		coalesce(wd.reportable_quantity_flag,'') reportable_quantity_flag,
		coalesce(wd.RQ_reason,'') RQ_reason,
		coalesce(wd.UN_NA_flag,'') UN_NA_FLAG,
		wd.UN_NA_number,
		coalesce(wd.DOT_shipping_name,'') DOT_shipping_name,
		coalesce(wd.hazmat_class,'') hazmat_class,
		coalesce(wd.subsidiary_haz_mat_class,'') subsidiary_haz_mat_class,
		coalesce(ta.print_dot_sp_flag,'') DOT_sp_permit_flag,
		coalesce(ta.dot_sp_permit_text,'') dot_sp_permit_text,
		wd.ERG_number,
		coalesce(wd.ERG_suffix,'') ERG_suffix,
		coalesce(wdu.bill_unit_code,'') bill_unit_code,
		coalesce(ta.LDR_required,'F') ldr_required_flag,
		coalesce(wd.hazmat,'F') hazmat_flag,
		coalesce(wd.package_group,'') package_group,
		dbo.fn_get_label_default_type('W', wd.workorder_id, wd.company_id, wd.profit_ctr_id, wd.sequence_id, wh.generator_id) label_type,
		t.TSDF_name,
		t.TSDF_EPA_ID,
		--03/27/2023 In TEST starting this morning, the following function call ends up generating the following error:
		--Internal error: An expression services limit has been reached. Please look for potentially complex expressions in your query, and try to simplify them.
		--Note that the error only happens when executed in this stored procedure... pulling the SQL out and executing in MSSMS works fine
		--dbo.fn_address_concatenated(t.TSDF_addr1, t.TSDF_addr2, t.TSDF_addr3, '', t.TSDF_city, t.TSDF_state, t.TSDF_zip_code, t.TSDF_country_code) TSDF_address,
		case coalesce(ltrim(rtrim(t.TSDF_addr1)),'') when '' then '' else coalesce(ltrim(rtrim(t.TSDF_addr1)),'') + char(10) end
		+ case coalesce(ltrim(rtrim(t.TSDF_addr2)),'') when '' then '' else coalesce(ltrim(rtrim(t.TSDF_addr2)),'') + char(10) end
		+ case coalesce(ltrim(rtrim(t.TSDF_addr3)),'') when '' then '' else coalesce(ltrim(rtrim(t.TSDF_addr3)),'') + char(10) end
		+ case coalesce(ltrim(rtrim(t.TSDF_city)),'') when '' then '' else coalesce(ltrim(rtrim(t.TSDF_city)),'') end
		+ case coalesce(ltrim(rtrim(t.TSDF_state)),'') when '' then '' else ', ' + coalesce(ltrim(rtrim(t.TSDF_state)),'') end
		+ case coalesce(ltrim(rtrim(t.TSDF_zip_code)),'') when '' then '' else ' ' + coalesce(ltrim(rtrim(t.TSDF_zip_code)),'') end
		+ case coalesce(ltrim(rtrim(t.TSDF_country_code)),'') when '' then '' WHEN 'US' THEN ' USA' WHEN 'Canada' THEN ' CAN' WHEN 'CA' THEN ' CAN' WHEN 'IN' THEN ' IND' WHEN 'CH' THEN ' CHE' ELSE ' ' + coalesce(ltrim(rtrim(t.TSDF_country_code)),'') END
		TSDF_address,
		coalesce(t.TSDF_phone,'') TSDF_phone,
		coalesce(wd.management_code,'') management_code,
		coalesce(wdu.manifest_flag,'F') manifest_flag,
		coalesce(wdu.billing_flag,'F') billing_flag,
		case when charindex('SOLID',isnull(upper(ta.consistency),'')) > 0 and charindex('LIQUID',isnull(upper(ta.consistency),'')) > 0 then 'Solid, Liquid'
			when charindex('SOLID',isnull(upper(ta.consistency),'')) > 0 then 'Solid'
			when charindex('LIQUID',isnull(upper(ta.consistency),'')) > 0 then 'Liquid' else '' end as physical_state,
		coalesce(nullif(substring(/*case when isnull(pl.ignitability_lt_90,'') = 'T' or isnull(pl.ignitability_90_139,'') = 'T' then ', Flammable' else '' end 
		+*/ case when exists (select 1 from WorkOrderWasteCode wwc join WasteCode wc on wwc.waste_code_uid = wc.waste_code_uid and (wc.display_name between 'D004' and 'D043' or wc.display_name like 'F%' or wc.display_name like 'K%') where wwc.workorder_id = wd.workorder_id and wwc.company_id = wd.company_id and wwc.profit_ctr_id = wd.profit_ctr_id and wwc.workorder_sequence_id = wd.sequence_id) then ', Toxic' else '' end
		+ case when exists (select 1 from WorkOrderWasteCode wwc join WasteCode wc on wwc.waste_code_uid = wc.waste_code_uid and wc.display_name = 'D002' where wwc.workorder_id = wd.workorder_id and wwc.company_id = wd.company_id and wwc.profit_ctr_id = wd.profit_ctr_id and wwc.workorder_sequence_id = wd.sequence_id) then ', Corrosive' else '' end
		+ case when exists (select 1 from WorkOrderWasteCode wwc join WasteCode wc on wwc.waste_code_uid = wc.waste_code_uid and wc.display_name = 'D003' where wwc.workorder_id = wd.workorder_id and wwc.company_id = wd.company_id and wwc.profit_ctr_id = wd.profit_ctr_id and wwc.workorder_sequence_id = wd.sequence_id) then ', Reactive' else '' end
		+ case when exists (select 1 from WorkOrderWasteCode wwc join WasteCode wc on wwc.waste_code_uid = wc.waste_code_uid and (wc.display_name like 'P%' or wc.display_name like 'U%') where wwc.workorder_id = wd.workorder_id and wwc.company_id = wd.company_id and wwc.profit_ctr_id = wd.profit_ctr_id and wwc.workorder_sequence_id = wd.sequence_id) then ', Other: Accutely Hazardous' else '' end
		+ case isnull(wd.hazmat_class,'') when '5.1' then ', Other: Oxidizer' else '' end
		+ case isnull(wd.hazmat_class,'') when '5.2' then ', Other: Organic Peroxide' else '' end,3,255),''),'Other') as hazardous_properties,
		CASE WHEN ta.waste_water_flag = 'W' THEN 'WW' ELSE 'NWW' END AS ww_flag,
		coalesce(ta.LDR_subcategory,'') AS LDR_subcategory,
		coalesce(CASE ldr.waste_managed_flag WHEN 'S' 
			THEN REPLACE(
					REPLACE(
						REPLACE(
							CONVERT(varchar(2000), ldr.underlined_text), 
							'|contains_listed:DOES:DOES NOT|', ldr.contains_listed), 
						'|exhibits_characteristic:DOES:DOES NOT|', ldr.exhibits_characteristic), 
					'|soil_treatment_standards:IS SUBJECT TO:COMPLIES WITH|', ldr.soil_treatment_standards)
			ELSE ldr.underlined_text
			END,'') AS underlined_text,
		coalesce(ldr.regular_text,'') regular_text,
		coalesce(tuc.uhc_const,'') uhc_const,
		coalesce(t.TSDF_state,'') TSDF_state,
		coalesce(ta.RQ_threshold,0.0) RQ_threshold,
		coalesce(tdr_1.permit_license_registration,'') TSDF_dea_permit_line_1,
		coalesce(tdr_2.permit_license_registration,'') TSDF_dea_permit_line_2,
		coalesce(ta.empty_bottle_flag,'F') empty_bottle_flag,
		coalesce(convert(numeric(10,10),ta.residue_pounds_factor),0.0) empty_bottle_residue_factor,
		coalesce(ta.empty_bottle_count_manifest_print_flag,'F') empty_bottle_manifest_print_flag,
		coalesce(ta.residue_manifest_print_flag,'F') empty_bottle_residue_manifest_print_flag,
		coalesce(ta.hand_instruct,'') manifest_hand_instruct,
		coalesce(ta.manifest_message,'') manifest_message,
		coalesce(t.DEA_ID,'') tsdf_DEA_ID,
		coalesce(wd.container_code,ta.manifest_container_code,'') container_code,
		case when wd.bill_rate = -2 then 'F' else 'T' end shipped_status,
		coalesce(wd.DOT_shipping_desc_additional,ta.DOT_shipping_desc_additional,'') DOT_shipping_desc_additional,
		coalesce(ta.comments,'') approval_comments
from TripHeader th
join WorkOrderHeader wh
	on wh.trip_id = th.trip_id
--	and wh.workorder_status <> 'V'
join WorkOrderDetail wd
	on wd.workorder_id = wh.workorder_ID
	and wd.company_id = wh.company_id
	and wd.profit_ctr_id = wh.profit_ctr_ID
	and wd.resource_type = 'D'
join WorkorderManifest wm
	on wm.workorder_id = wd.workorder_ID
	and wm.company_id = wd.company_id
	and wm.profit_ctr_id = wd.profit_ctr_ID
	and wm.manifest = wd.manifest
join #m wdu
	on wdu.workorder_id = wd.workorder_ID
	and wdu.company_id = wd.company_id
	and wdu.profit_ctr_id = wd.profit_ctr_ID
	and wdu.sequence_id = wd.sequence_ID
join TSDF t
	on t.TSDF_code = wd.TSDF_code
	and coalesce(t.eq_flag,'') <> 'T'
join TSDFApproval ta
	on ta.TSDF_approval_id = wd.TSDF_approval_id
	and ta.company_id = wd.company_id
	and ta.profit_ctr_id = wd.profit_ctr_ID
join Generator g
	on g.generator_id = wh.generator_id
left outer join LDRWasteManaged ldr
	on ta.waste_managed_id = ldr.waste_managed_id
	and ldr.version = (select max(version) from LDRWasteManaged where waste_managed_id = ta.waste_managed_id)
left outer join #profile_uhc_const tuc
	on tuc.tsdf_approval_id = wd.TSDF_approval_id
left outer join TSDFDEARegistration tdr_1
	on tdr_1.TSDF_code = wd.TSDF_code
	and tdr_1.state_abbr = g.generator_state
	and tdr_1.sequence_id = 1
left outer join TSDFDEARegistration tdr_2
	on tdr_2.TSDF_code = wd.TSDF_code
	and tdr_2.state_abbr = g.generator_state
	and tdr_2.sequence_id = 2
where th.trip_id = @trip_id
and (@trip_sequence_id = 0 or wh.trip_sequence_id = @trip_sequence_id)
order by wh.trip_sequence_id, wd.TSDF_code, wd.manifest, wd.sequence_id

drop table #m
go

grant execute on sp_ss_get_trip_tsdf_approvals to EQAI, TRIPSERV
go
