
create procedure sp_mim_rpt_reassign_form_group
	@workorder_id int,
	@company_id int,
	@profit_ctr_id int
as
/**********************************************
 * Loads to Plt_ai
 * Brute-force generation of form_group (used to determine break-out of DEA-Form 41 and DEA-Form 222 reports)

 * 10/16/2014 RB	Created
 * 08/06/2020 MPM	DevOps 16869 - Modified because the new DEA Form 222 lists up to 20 items.
 **********************************************/
declare @form_group int,
		@count int,
		@tsdf varchar(40),
		@manifest varchar(15),
		@tsdf_appr varchar(60),
		@seq_id int,
		@sched_group varchar(2),
		@sub_seq_id int

set @form_group = 0

declare c_loop_dea cursor forward_only read_only for
select distinct wod.tsdf_code, wod.manifest, wod.tsdf_approval_code, wod.sequence_id,
		case when right(wdi.dea_schedule,1) = '2' then '2' else '3' end as sched_group
from workorderdetail wod, workorderdetailitem wdi
where wod.workorder_id = @workorder_id
and wod.company_id = @company_id
and wod.profit_ctr_id = @profit_ctr_id
and wod.resource_type = 'D'
and wod.workorder_id = wdi.workorder_id
and wod.company_id = wdi.company_id
and wod.profit_ctr_id = wdi.profit_ctr_id
and wod.sequence_id = wdi.sequence_id
and right(isnull(wdi.dea_schedule,''),1) in ('2','3','4','5')
order by wod.tsdf_code, wod.manifest, wod.tsdf_approval_code, sched_group

open c_loop_dea
fetch c_loop_dea into @tsdf, @manifest, @tsdf_appr, @seq_id, @sched_group

while @@FETCH_STATUS = 0
begin
	set @count = 0
	set @form_group = @form_group + 1

	if @sched_group = '2'
	begin
		declare c_loop_form_group cursor forward_only read_only for
		select wdi.sub_sequence_id
		from workorderdetail wod, workorderdetailitem wdi
		where wod.workorder_id = @workorder_id
		and wod.company_id = @company_id
		and wod.profit_ctr_id = @profit_ctr_id
		and wod.sequence_id = @seq_id
		and wod.resource_type = 'D'
		and wod.workorder_id = wdi.workorder_id
		and wod.company_id = wdi.company_id
		and wod.profit_ctr_id = wdi.profit_ctr_id
		and wod.sequence_id = wdi.sequence_id
		and right(isnull(wdi.dea_schedule,''),1) = '2'

		open c_loop_form_group
		fetch c_loop_form_group into @sub_seq_id

		while @@FETCH_STATUS = 0
		begin
			set @count = @count + 1
			-- MPM - 08/06/2020 - DevOps 16869 - The new DEA Form 222 lists up to 20 items
			if @count > 20
			begin
				set @form_group = @form_group + 1
				set @count = 1
			end

			update workorderdetailitem
			set form_group = @form_group
			where workorder_id = @workorder_id
			and company_id = @company_id
			and profit_ctr_id = @profit_ctr_id
			and sequence_id = @seq_id
			and sub_sequence_id = @sub_seq_id
			
			fetch c_loop_form_group into @sub_seq_id
		end

		close c_loop_form_group
		deallocate c_loop_form_group
	end
	else
	begin
		declare c_loop_form_group2 cursor for
		select wdi.sub_sequence_id
		from workorderdetail wod, workorderdetailitem wdi
		where wod.workorder_id = @workorder_id
		and wod.company_id = @company_id
		and wod.profit_ctr_id = @profit_ctr_id
		and wod.sequence_id = @seq_id
		and wod.resource_type = 'D'
		and wod.workorder_id = wdi.workorder_id
		and wod.company_id = wdi.company_id
		and wod.profit_ctr_id = wdi.profit_ctr_id
		and wod.sequence_id = wdi.sequence_id
		and right(isnull(wdi.dea_schedule,''),1) in ('3','4','5')
		
		open c_loop_form_group2
		fetch c_loop_form_group2 into @sub_seq_id

		while @@FETCH_STATUS = 0
		begin
			set @count = @count + 1

			if @count > 24
			begin
				set @form_group = @form_group + 1
				set @count = 1
			end

			update workorderdetailitem
			set form_group = @form_group
			where workorder_id = @workorder_id
			and company_id = @company_id
			and profit_ctr_id = @profit_ctr_id
			and sequence_id = @seq_id
			and sub_sequence_id = @sub_seq_id
			
			fetch c_loop_form_group2 into @sub_seq_id
		end

		close c_loop_form_group2
		deallocate c_loop_form_group2
	end

	fetch c_loop_dea into @tsdf, @manifest, @tsdf_appr, @seq_id, @sched_group
end

close c_loop_dea
deallocate c_loop_dea

return 0

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_mim_rpt_reassign_form_group] TO [EQAI]
    AS [dbo];

