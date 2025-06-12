
create procedure [dbo].[sp_rpt_consolidated_load_multiple_trips]
    @tsdf_code varchar(15),
    @trip_ids varchar(100)	-- this is either a single trip ID, in a string, or it is a comma-delimited string of multiple trip ID's
as

-- 10/25/2016 MPM	Created for GEM 39821.  Created from sp_rpt_consolidated_load.
-- 12/15/2016 MPM	GEM 40866 - Changed to include approvals that are manifested in units other than pounds (e.g., kilograms, 
--					tons, yards) as well as pounds. 
-- 10/05/2017 AM    GEM 46074 - Added lab_review_req field to result set.
-- 01/16/2018 AM    GEM:47746 - Report Center - Added consolidation group to Consolidated load Container list report. 
--								SQL Deploy (sp_rpt_consolidated_load_multiple_trips). AM 
-- 01/19/2018 MPM	GEM 47858 - Added treatment process; removed profit center name.
-- 05/29/2018 MPM	GEM 48342 - Modified to build a list of consolidated_dot_shipping_desc values and return the list to be displayed on the cover sheet.
-- 08/31/2023 Subhrajyoti - Devops#58108 - Consolidated Load Container List report - add column for the outbound approval
/*
sp_rpt_consolidated_load_multiple_trips 'USECOLOGYNV', 'fff,44444,44445' 
sp_rpt_consolidated_load_multiple_trips 'EQOK', '42383,44444,44445' 
sp_rpt_consolidated_load_multiple_trips 'EQINDY', '16885' 
sp_rpt_consolidated_load_multiple_trips 'EQINDY', '16885' 
sp_rpt_consolidated_load_multiple_trips 'SIEMENS-CA', '57384, 57382' 

*/

declare @trip_id int,
		@tsdf_name varchar(40),
        @profit_ctr_name varchar(60),
        @approval_code varchar(40),
        @approval_list varchar(1024),
		@outbound_approval_list varchar(1024), -- Devops#58108
        @description varchar(100),
        @description_list varchar(4096),
        @ccid int,
        @AESOP_waste_stream varchar(9),
        @AESOP_profile_id int,
        @i int,
        @list_item varchar(100),
        @consolidation_group varchar(2),
        @consolidation_group_flag varchar(1),
        @consolidated_DOT_shipping_desc varchar(325),
        @consolidated_DOT_shipping_desc_list varchar(4096)
         
        
create table #trips (
	trip_id int not null,
	profit_ctr_name varchar(60) null
)

create table #work (
    trip_id int not null,
    approval_code varchar(40) not null,
	outbound_approval_code Varchar(40) null, -- Devops#58108
    description varchar(100) not null,
    consolidated_container_id int not null,
    container_size varchar(4) not null,
    container_type varchar(2) not null,
    consolidated_dot_shipping_desc varchar(325) not null,
    AESOP_waste_stream varchar(9) null,
    AESOP_profile_id int null,
    lab_review_req varchar (3) null,
    destination_container_id int null,
    eq_company int null,
    eq_profit_ctr int null,
    consolidation_group varchar(2) null,
    consolidation_group_flag varchar(1) null, 
    treatment_process varchar(30) null
)

create table #results (
	trip_id int not null,
    consolidated_container_id int not null,
    consolidated_dot_shipping_desc_list varchar(4096) null,
    approval_list varchar(1024) null,
    description_list varchar(4096) null,
    container_size varchar(255) null,
    container_type varchar(255) null,
    count_rollup int null,
    lab_review_req varchar (3) null,
    destination_container_id int null,
    eq_company int null,
    eq_profit_ctr int null,
    consolidation_group varchar(2) null,
    consolidation_group_flag varchar(1) null,
    treatment_process varchar(30) null,
	outbound_approval_list varchar(1024) null -- Devops#58108
)

-- TSDF name
select @tsdf_name = tsdf_name
from TSDF
where tsdf_code = @tsdf_code

-- Extract the trip ID's from the @trip_ids input parameter and insert them into the #trip_ids table
set @i = 1
select @list_item = dbo.fn_get_list_item(',', 1, @trip_ids, @i)
 
while @list_item > '' 
begin
    if IsNumeric(@list_item) = 1
    begin
		select @trip_id = CONVERT(int, @list_item)
		insert into #trips (trip_id) select @trip_id
		set @i = @i + 1
		select @list_item = dbo.fn_get_list_item(',', 1, @trip_ids, @i)
	end
	else
	begin
		set @i = @i + 1
		select @list_item = dbo.fn_get_list_item(',', 1, @trip_ids, @i)
		continue
	end
end
	
-- create working set of data, from both profiles and tsdf approvals
insert #work
select wh.trip_id,
	isnull(ltrim(rtrim(wd.tsdf_approval_code)),''),
	isnull(ltrim(rtrim(ta.tsdf_approval_code)),''), -- Devops#58108
	isnull(ltrim(rtrim(wd.description)),''),
	wdc.consolidated_container_id,
	isnull(wdc.container_size,''),
	isnull(wdc.container_type,''),
        dbo.fn_consolidated_shipping_desc (wd.un_na_flag, wd.un_na_number, wd.dot_shipping_name, wd.hazmat_class, wd.subsidiary_haz_mat_class, wd.package_group,
                                        wd.reportable_quantity_flag, wd.erg_number, wd.erg_suffix, pqa.print_dot_sp_flag, wd.manifest_dot_sp_number),
    null,
    null,
    CASE WHEN pqa.fingerprint_type = 'NONE' THEN 'No'
      ELSE 'Yes'
       END  AS lab_review_req,
    wdc.destination_container_id ,
    t.eq_company ,
    t.eq_profit_ctr,
    ProfileConsolidationGroup.consolidation_group,
	ProfitCenter.consolidation_group_flag,
	t2.treatment_process_process
from workorderheader wh
join workorderdetail wd
    on wh.workorder_id = wd.workorder_id
    and wh.company_id = wd.company_id
    and wh.profit_ctr_id = wd.profit_ctr_id
    and wd.resource_type = 'D'
    and wd.bill_rate > -2
    and wd.tsdf_code = @tsdf_code
join tsdf t
    on wd.tsdf_code = t.tsdf_code
    and isnull(t.eq_flag,'F') = 'T'
join profilequoteapproval pqa
    on wd.profile_id = pqa.profile_id
    and wd.profile_company_id = pqa.company_id
    and wd.profile_profit_ctr_id = pqa.profit_ctr_id
join workorderdetailcc wdc
    on wd.workorder_id = wdc.workorder_id
    and wd.company_id = wdc.company_id
    and wd.profit_ctr_id = wdc.profit_ctr_id
    and wd.sequence_id = wdc.sequence_id
    and isnull(wdc.consolidated_container_id,0) > 0
join ProfitCenter on	ProfitCenter.company_id = t.eq_company  
	and ProfitCenter.profit_ctr_id = t.eq_profit_ctr
join Treatment t2
	on t2.company_id = pqa.company_id
	and t2.profit_ctr_id = pqa.profit_ctr_id
	and t2.treatment_id = pqa.treatment_id
left outer join ProfileConsolidationGroup on ProfileConsolidationGroup.consolidation_group_uid = pqa.consolidation_group_uid 
left outer join tsdfapproval ta on ta.TSDF_approval_id = pqa.ob_tsdf_approval_id -- Devops#58108
where wh.trip_id in (select trip_id from #trips)
and wh.workorder_status <> 'V'

insert #work
select wh.trip_id,
	isnull(ltrim(rtrim(wd.tsdf_approval_code)),''),
	null,
	isnull(ltrim(rtrim(wd.description)),''),
	wdc.consolidated_container_id,
	isnull(wdc.container_size,''),
	isnull(wdc.container_type,''),
        dbo.fn_consolidated_shipping_desc (wd.un_na_flag, wd.un_na_number, wd.dot_shipping_name, wd.hazmat_class, wd.subsidiary_haz_mat_class, wd.package_group,
                                        wd.reportable_quantity_flag, wd.erg_number,wd.erg_suffix, ta.print_dot_sp_flag, wd.manifest_dot_sp_number),
    ta.AESOP_waste_stream,
    ta.AESOP_profile_ID,
    '' AS lab_review_req,
    wdc.destination_container_id ,
    t.eq_company ,
    t.eq_profit_ctr,
    '' as consolidation_group,
	ProfitCenter.consolidation_group_flag,
	null
from workorderheader wh
join workorderdetail wd
    on wh.workorder_id = wd.workorder_id
    and wh.company_id = wd.company_id
    and wh.profit_ctr_id = wd.profit_ctr_id
    and wd.resource_type = 'D'
    and wd.bill_rate > -2
    and wd.tsdf_code = @tsdf_code
join tsdf t
    on wd.tsdf_code = t.tsdf_code
    and isnull(t.eq_flag,'F') <> 'T'
join tsdfapproval ta
    on wd.tsdf_approval_id = ta.tsdf_approval_id
join workorderdetailcc wdc
    on wd.workorder_id = wdc.workorder_id
    and wd.company_id = wdc.company_id
    and wd.profit_ctr_id = wdc.profit_ctr_id
    and wd.sequence_id = wdc.sequence_id
    and isnull(wdc.consolidated_container_id,0) > 0
join ProfitCenter on	ProfitCenter.company_id = t.eq_company  
	and ProfitCenter.profit_ctr_id = t.eq_profit_ctr
where wh.trip_id in (select trip_id from #trips)
and wh.workorder_status <> 'V'
--select * from #work
--return
-- loop through work table by distinct trip id, CCID
declare c_work cursor for
select distinct trip_id, consolidated_container_id
from #work

open c_work
fetch c_work into @trip_id, @ccid

while @@FETCH_STATUS = 0
begin
    --get list of approvals
    set @approval_list = ''

    declare c_approvals cursor for
    select distinct approval_code, AESOP_waste_stream, AESOP_profile_id,consolidation_group,consolidation_group_flag
    from #work
    where consolidated_container_id = @ccid
    and trip_id = @trip_id
    order by approval_code

    open c_approvals
    fetch c_approvals into @approval_code, @AESOP_waste_stream, @AESOP_profile_id,@consolidation_group,@consolidation_group_flag

    while @@FETCH_STATUS = 0
    begin
        if isnull(@approval_list,'') <> ''
            set @approval_list = @approval_list + ', '
        set @approval_list = @approval_list + @approval_code
        
        -- MPM 10/25/16 - GEM 39822 - Include new TSDF Approval field with the approval number
        if @AESOP_waste_stream is not null and @AESOP_waste_stream > '' and @AESOP_profile_id is not null and @AESOP_profile_id > 0
			set @approval_list = @approval_list + ' (' + @AESOP_waste_stream + '-' + convert(varchar(5), @AESOP_profile_id) + ')'

        fetch c_approvals into @approval_code, @AESOP_waste_stream, @AESOP_profile_id,@consolidation_group,@consolidation_group_flag
    end

    close c_approvals
    deallocate c_approvals

    --get a list of approval descriptions
    set @description_list = ''

    declare c_descriptions cursor for
    select distinct description
    from #work
    where consolidated_container_id = @ccid
    and trip_id = @trip_id
    order by description

    open c_descriptions
    fetch c_descriptions into @description

    while @@FETCH_STATUS = 0
    begin
        if isnull(@description_list,'') <> ''
            set @description_list = @description_list + ', '
        set @description_list = @description_list + @description

        fetch c_descriptions into @description
    end

    close c_descriptions
    deallocate c_descriptions

    --get a list of consolidated DOT shipping descriptions
    set @consolidated_DOT_shipping_desc_list = ''

    declare c_DOT_shipping_desc cursor for
    select distinct consolidated_dot_shipping_desc
    from #work
    where consolidated_container_id = @ccid
    order by consolidated_dot_shipping_desc

    open c_DOT_shipping_desc
    fetch c_DOT_shipping_desc into @consolidated_DOT_shipping_desc

    while @@FETCH_STATUS = 0
    begin
        if isnull(@consolidated_DOT_shipping_desc_list,'') <> ''
            set @consolidated_DOT_shipping_desc_list = @consolidated_DOT_shipping_desc_list + CHAR(13) + CHAR(10) --', '
        set @consolidated_DOT_shipping_desc_list = @consolidated_DOT_shipping_desc_list + @consolidated_DOT_shipping_desc

        fetch c_DOT_shipping_desc into @consolidated_DOT_shipping_desc
    end

    close c_DOT_shipping_desc
    deallocate c_DOT_shipping_desc

	-- Begin - Devops#58108 
	Set @outbound_approval_list = ''
	declare c_outbound_approvals cursor for
    select distinct outbound_approval_code
    from #work
    where consolidated_container_id = @ccid
    and trip_id = @trip_id
    order by outbound_approval_code

    open c_outbound_approvals
    fetch c_outbound_approvals into @approval_code

    while @@FETCH_STATUS = 0
    begin
        if isnull(@outbound_approval_list,'') <> ''
            set @outbound_approval_list = @outbound_approval_list + ', '
        set @outbound_approval_list = @outbound_approval_list + @approval_code


        fetch c_outbound_approvals into @approval_code
    end
	close c_outbound_approvals
	deallocate c_outbound_approvals
	-- End - Devops#58108 
    -- add rows to report
    insert #results
    select distinct trip_id, consolidated_container_id, @consolidated_dot_shipping_desc_list, @approval_list, @description_list, container_size, container_type, 1, lab_review_req, destination_container_id ,eq_company ,eq_profit_ctr,consolidation_group,consolidation_group_flag, treatment_process,@outbound_approval_list
    from #work
    where consolidated_container_id = @ccid
    and trip_id = @trip_id

    fetch c_work into @trip_id, @ccid
end

close c_work
deallocate c_work

update #trips
set profit_ctr_name = right('00' + convert(varchar(6),th.company_id),2) + '-' + right('00' + convert(varchar(6),th.profit_ctr_id),2) + ' ' --+ pc.profit_ctr_name
from TripHeader th
join ProfitCenter pc
    on th.company_id = pc.company_id
    and th.profit_ctr_id = pc.profit_ctr_id
where th.trip_id = #trips.trip_id

-- return report
select r.trip_id as trip_id,
		@tsdf_name as tsdf_name,
        t.profit_ctr_name as profit_ctr_name,
        r.consolidated_container_id,
        r.consolidated_dot_shipping_desc_list,
        r.approval_list, 
        r.description_list,
        r.container_size,
        r.container_type,
        r.count_rollup,
        round(sum(isnull(wdu.quantity,0) * (wdc.percentage / 100.0)),2) as container_quantity,
        wdu.size as container_unit,
        r.lab_review_req,
        r.destination_container_id ,
		r.eq_company , 
		r.eq_profit_ctr,
		r.consolidation_group,
		r.consolidation_group_flag,
		r.treatment_process,
		r.outbound_approval_list --Devops#58108
from #results r
join WorkOrderHeader wh
    on wh.trip_id = r.trip_id
    and wh.workorder_status <> 'V'
join WorkOrderDetail wd
    on wd.workorder_id = wh.workorder_id
    and wd.company_id = wh.company_id
    and wd.profit_ctr_id = wh.profit_ctr_id
    and wd.resource_type = 'D'
    and wd.bill_rate > -2
    and wd.tsdf_code = @tsdf_code
join WorkOrderDetailCC wdc
    on wdc.workorder_id = wd.workorder_id
    and wdc.company_id = wd.company_id
    and wdc.profit_ctr_id = wd.profit_ctr_id
    and wdc.sequence_id = wd.sequence_id
    and wdc.consolidated_container_id = r.consolidated_container_id
join WorkOrderDetailUnit wdu
    on wdu.workorder_id = wd.workorder_id
    and wdu.company_id = wd.company_id
    and wdu.profit_ctr_id = wd.profit_ctr_id
    and wdu.sequence_id = wd.sequence_id
    and wdu.size in (select bill_unit_code from BillUnit where manifest_unit is not null)
    and wdu.manifest_flag = 'T'
join #trips t
	on t.trip_id = r.trip_id
group by r.trip_id, t.profit_ctr_name,
	r.consolidated_container_id,
    r.consolidated_dot_shipping_desc_list,
    r.approval_list,
    r.description_list,
    r.container_size,
    r.container_type,
    r.count_rollup,
    wdu.size,
    r.lab_review_req,
    r.destination_container_id ,
	r.eq_company ,
	r.eq_profit_ctr,
	r.consolidation_group,
    r.consolidation_group_flag,
    r.treatment_process,
	r.outbound_approval_list -- Devops#58108
order by r.trip_id, r.consolidated_container_id

drop table #trips
drop table #results
drop table #work

return 0

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_consolidated_load_multiple_trips] TO [EQAI]
    AS [dbo];

