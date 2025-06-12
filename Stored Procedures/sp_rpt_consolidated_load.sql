
create procedure sp_rpt_consolidated_load
    @trip_id int,
    @tsdf_code varchar(15)
as
-- 11/23/2015 RWB	Created
-- 01/19/2016 RWB	Added container weight column
-- 04/27/2016 RWB	Added waste description(s)
-- 10/25/2016 MPM	GEM 39822 - Include new TSDF Approval field with the approval number 
-- 10/26/2016 MPM	GEM 39822 - Changed the format of the new TSDF Approval field to [AESOP profile ID]-[AESOP waste stream]
-- 11/1/2016  MPM	GEM 39822 - Changed the format of the new TSDF Approval field back to [AESOP waste stream]-[AESOP profile ID]
-- 12/15/2016 MPM	GEM 40866 - Changed to include approvals that are manifested in units other than pounds (e.g., kilograms, 
--					tons, yards) as well as pounds. 
-- 05/29/2018 MPM	GEM 48342 - Modified to build a list of consolidated_dot_shipping_desc values and return the list to be displayed on the cover sheet.
/*
sp_rpt_consolidated_load 16885, 'EQDET'
sp_rpt_consolidated_load 16885, 'EQINDY'
sp_rpt_consolidated_load 44444, 'USECOLOGYNV'
sp_rpt_consolidated_load 36307, 'USECOLOGYNV'
sp_rpt_consolidated_load 24338, 'EQWDI'
sp_rpt_consolidated_load 57384, 'SIEMENS-CA'
*/
declare @tsdf_name varchar(40),
        @profit_ctr_name varchar(60),
        @trailer_number varchar(10),
        @driver_name varchar(50),
        @transporter_list varchar(255),
        @transporter_code varchar(15),
        @transporter_epa_list varchar(255),
        @transporter_epa varchar(15),
        @approval_code varchar(40),
        @approval_list varchar(1024),
        @description varchar(100),
        @description_list varchar(4096),
        @ccid int,
        @AESOP_waste_stream varchar(9),
        @AESOP_profile_id int,
        @consolidated_DOT_shipping_desc varchar(325),
        @consolidated_DOT_shipping_desc_list varchar(4096)

create table #work (
    approval_code varchar(40) not null,
    description varchar(100) not null,
    consolidated_container_id int not null,
    container_size varchar(4) not null,
    container_type varchar(2) not null,
    consolidated_dot_shipping_desc varchar(325) not null,
    AESOP_waste_stream varchar(9) null,
    AESOP_profile_id int null
)

create table #results (
    consolidated_container_id int not null,
    consolidated_dot_shipping_desc_list varchar(4096) null,
    approval_list varchar(1024) null,
    description_list varchar(4096) null,
    container_size varchar(255) null,
    container_type varchar(255) null,
    count_rollup int null
)

-- TSDF name
select @tsdf_name = tsdf_name
from TSDF
where tsdf_code = @tsdf_code

-- trip info
select @profit_ctr_name = right('00' + convert(varchar(6),th.company_id),2) + '-' + right('00' + convert(varchar(6),th.profit_ctr_id),2) + ' ' + pc.profit_ctr_name,
    @trailer_number = th.trailer_number,
    @driver_name = case when isnull(ltrim(rtrim(th.driver_name)),'') = '' then '' else ltrim(rtrim(th.driver_name)) + ' / ' end + 'Trip ID: ' + convert(varchar(7),@trip_id)
from TripHeader th
join ProfitCenter pc
    on th.company_id = pc.company_id
    and th.profit_ctr_id = pc.profit_ctr_id
where th.trip_id = @trip_id

-- build list of transporters
declare c_trans cursor for
select distinct wt.transporter_code, t.transporter_epa_id
from workordertransporter wt
join transporter t
    on wt.transporter_code = t.transporter_code
join workorderdetail wd
    on wt.workorder_id = wd.workorder_id
    and wt.company_id = wd.company_id
    and wt.profit_ctr_id = wd.profit_ctr_id
    and wd.resource_type = 'D'
    and wd.bill_rate > -2
    and wt.manifest = wd.manifest
    and wd.tsdf_code = @tsdf_code
join workorderheader wh
    on wd.workorder_id = wh.workorder_id
    and wd.company_id = wh.company_id
    and wd.profit_ctr_id = wh.profit_ctr_id
    and wh.trip_id = @trip_id

open c_trans
fetch c_trans into @transporter_code, @transporter_epa

while @@FETCH_STATUS = 0
begin
    if isnull(@transporter_list,'') <> ''
        set @transporter_list = @transporter_list + ', '
    set @transporter_list = isnull(@transporter_list,'') + @transporter_code

    if isnull(@transporter_epa_list,'') <> ''
        set @transporter_epa_list = @transporter_epa_list + ', '
    set @transporter_epa_list = isnull(@transporter_epa_list,'') + @transporter_epa

    fetch c_trans into @transporter_code, @transporter_epa
end

close c_trans
deallocate c_trans

-- create working set of data, from both profiles and tsdf approvals
insert #work
select isnull(ltrim(rtrim(wd.tsdf_approval_code)),''),
	isnull(ltrim(rtrim(wd.description)),''),
	wdc.consolidated_container_id,
	isnull(wdc.container_size,''),
	isnull(wdc.container_type,''),
        dbo.fn_consolidated_shipping_desc (wd.un_na_flag, wd.un_na_number, wd.dot_shipping_name, wd.hazmat_class, wd.subsidiary_haz_mat_class, wd.package_group,
                                        wd.reportable_quantity_flag, wd.erg_number, wd.erg_suffix, pqa.print_dot_sp_flag, wd.manifest_dot_sp_number),
    null,
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
where wh.trip_id = @trip_id
and wh.workorder_status <> 'V'

insert #work
select isnull(ltrim(rtrim(wd.tsdf_approval_code)),''),
	isnull(ltrim(rtrim(wd.description)),''),
	wdc.consolidated_container_id,
	isnull(wdc.container_size,''),
	isnull(wdc.container_type,''),
        dbo.fn_consolidated_shipping_desc (wd.un_na_flag, wd.un_na_number, wd.dot_shipping_name, wd.hazmat_class, wd.subsidiary_haz_mat_class, wd.package_group,
                                        wd.reportable_quantity_flag, wd.erg_number,wd.erg_suffix, ta.print_dot_sp_flag, wd.manifest_dot_sp_number),
    ta.AESOP_waste_stream,
    ta.AESOP_profile_ID
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
where wh.trip_id = @trip_id
and wh.workorder_status <> 'V'

-- loop through work table by distinct CCID
declare c_work cursor for
select distinct consolidated_container_id
from #work

open c_work
fetch c_work into @ccid

while @@FETCH_STATUS = 0
begin
    --get list of approvals
    set @approval_list = ''

    declare c_approvals cursor for
    select distinct approval_code, AESOP_waste_stream, AESOP_profile_id
    from #work
    where consolidated_container_id = @ccid
    order by approval_code

    open c_approvals
    fetch c_approvals into @approval_code, @AESOP_waste_stream, @AESOP_profile_id

    while @@FETCH_STATUS = 0
    begin
        if isnull(@approval_list,'') <> ''
            set @approval_list = @approval_list + ', '
        set @approval_list = @approval_list + @approval_code
        
        -- MPM 10/25/16 - GEM 39822 - Include new TSDF Approval field with the approval number
        if @AESOP_waste_stream is not null and @AESOP_waste_stream > '' and @AESOP_profile_id is not null and @AESOP_profile_id > 0
			set @approval_list = @approval_list + ' (' + @AESOP_waste_stream + '-' + convert(varchar(5), @AESOP_profile_id) + ')'

        fetch c_approvals into @approval_code, @AESOP_waste_stream, @AESOP_profile_id
    end

    close c_approvals
    deallocate c_approvals

    --get a list of approval descriptions
    set @description_list = ''

    declare c_descriptions cursor for
    select distinct description
    from #work
    where consolidated_container_id = @ccid
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

    -- add rows to report
    insert #results
    select distinct consolidated_container_id, @consolidated_DOT_shipping_desc_list, @approval_list, @description_list, container_size, container_type, 1
    from #work
    where consolidated_container_id = @ccid

    fetch c_work into @ccid
end

close c_work
deallocate c_work

-- return report
select @tsdf_name as tsdf_name,
        @transporter_list as transporter_list,
        @transporter_epa_list as transporter_epa_list,
        @profit_ctr_name as profit_ctr_name,
        @trailer_number as trailer_number,
        @driver_name as driver_name,
        r.consolidated_container_id,
        r.consolidated_dot_shipping_desc_list,
        r.approval_list,
        r.description_list,
        r.container_size,
        r.container_type,
        r.count_rollup,
        round(sum(isnull(wdu.quantity,0) * (wdc.percentage / 100.0)),2) as container_quantity,
        wdu.size as container_unit
from #results r
join WorkOrderHeader wh
    on wh.trip_id = @trip_id
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
group by r.consolidated_container_id,
    r.consolidated_dot_shipping_desc_list,
    r.approval_list,
    r.description_list,
    r.container_size,
    r.container_type,
    r.count_rollup,
    wdu.size 
order by r.consolidated_container_id

return 0

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_consolidated_load] TO [EQAI]
    AS [dbo];

