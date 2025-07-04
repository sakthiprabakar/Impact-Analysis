use Plt_ai
go

alter procedure sp_d365_get_pma_labor
	@d365_pma_export_uid int
as
/*

03/24/2023 - rwb - Created
08/22/2023 - rwb - DO 71942 - Removed "and resource_status = 'A'" from joins to Resource table
02/01/2024 - rwb - SN CHG0069298 - Add companies 71 & 72, reference finance project category on the assigned class instead
05/16/2024 - rwb - SN RITM1234653 - When bill unit is DAY, send "8" as quantity
06/21/2024 - rwb - SN CHG0072360  - To support cross-company shared resources, join WorkOrderDetail and Resource on new resource_uid column
				    (was in TEST since June, deployed to prod January 2025)
10/02/2024 - rwb - SN CHG0075054 - Add company 68, incorporate cost_quantity for labor hours
04/08/2025 - rwb - SN CHG0080156 - Add 14-00 & all of 65, except 65-02
05/06/2025 - rwb - SN CHG0080423 - 14-00 has workorder_ids and D365 projects that end up exceeding the 40 character limit of DESCRIPTION. Increase to varchar(50)


exec sp_d365_get_pma_labor 45

*/
declare
	@w_id int, @c_id int, @p_id int, @user varchar(10),
	@prior_export_id int,
	@prior_posting_type varchar(5),
	@prior_posting_status char,
	@posting_type varchar(10),
	@version_id int,
	@line_offset int,
	@compare_dt datetime,
	@json varchar(max)

set transaction isolation level read uncommitted

set @user = left(replace(suser_name(),'(2)',''),10)

--posting type can be Full, Incremental, or Reversal
select @posting_type = posting_type,
	@compare_dt = case when company_id in (62, 63, 64)
						then '04/01/2023'
						when (company_id = 14 and profit_ctr_id = 0) or (company_id = 65 and profit_ctr_id <> 2)
						then '05/01/2025'
						else 
						case company_id
							when 68
							then '11/01/2024'
							when 71
							then '08/01/2024'
							when 72
							then '06/01/2024'
							else '06/01/2023'
						end
					end
from D365PMAExport
where d365_pma_export_uid = @d365_pma_export_uid


--Check for error on previous post, ignoring voids
--Void that export's version in history
select @prior_export_id = max(e2.d365_pma_export_uid)
from D365PMAExport e
join D365PMAExport e2
	on e2.resource_type = e.resource_type
	and e2.workorder_id = e.workorder_id
	and e2.company_id = e.company_id
	and e2.profit_ctr_id = e.profit_ctr_id
	and e2.status <> 'V'
	and e2.response_text <> 'Returned JSON was an empty string'
	and e2.d365_pma_export_uid < e.d365_pma_export_uid
where e.d365_pma_export_uid = @d365_pma_export_uid

if coalesce(@prior_export_id,0) > 0
begin
	select @w_id = workorder_id,
		@c_id = company_id,
		@p_id = profit_ctr_id,
		@prior_posting_type = posting_type,
		@prior_posting_status = status
	from D365PMAExport
	where d365_pma_export_uid = @prior_export_id

	if not (@posting_type = 'F'
			and exists (select 1 from D365PMAExport
						where d365_pma_export_uid = @d365_pma_export_uid - 1
						and workorder_id = @w_id
						and company_id = @c_id
						and profit_ctr_id = @p_id
						and resource_type = 'L'
						and posting_type = 'R'
						and status = 'C')
			)
		and coalesce(@prior_posting_status,'') = 'E' and @posting_type <> 'R'
	begin
		--void future export records
		update D365PMAExport
		set status = 'V', response_text = 'VOID: Prior post returned an error', modified_by = 'AX_SERVICE', date_modified = getdate()
		where resource_type = 'L'
		and workorder_id = @w_id
		and company_id = @c_id
		and profit_ctr_id = @p_id
		and d365_pma_export_uid >= @d365_pma_export_uid

		--void historical data for last version (but not for Reversals, they do not generate historical versions of data)
		if @prior_posting_type in ('I','F')
		begin
			select @version_id = max(version_id)
			from D365PMAExportHistoryL
			where workorder_id = @w_id
			and company_id = @c_id
			and profit_ctr_id = @p_id

			update D365PMAExportHistoryL
			set status = 'V'
			where workorder_id = @w_id
			and company_id = @c_id
			and profit_ctr_id = @p_id
			and version_id = @version_id
			and status = 'A'
		end
		else if @prior_posting_type = 'S'
		begin
			select @version_id = max(version_id)
			from D365PMAExportHistoryL
			where workorder_id = @w_id
			and company_id = @c_id
			and profit_ctr_id = @p_id

			update D365PMAExportHistoryL
			set status = 'A'
			where workorder_id = @w_id
			and company_id = @c_id
			and profit_ctr_id = @p_id
			and version_id = @version_id
			and status = 'V'
		end

		if @posting_type <> 'F'
		begin
			--insert new records for Reversal and Full
			insert D365PMAExport (workorder_id, company_id, profit_ctr_id, resource_type, posting_type, added_by, modified_by)
			values (@w_id, @c_id, @p_id, 'L', 'R', @user, @user)

			insert D365PMAExport (workorder_id, company_id, profit_ctr_id, resource_type, posting_type, added_by, modified_by)
			values (@w_id, @c_id, @p_id, 'L', 'F', @user, @user)
		end

		select 'V' json
		return 0
	end
end


--because the triggers avoid generating multiple Incremental records, immediately change the status
update D365PMAExport
set status = 'I', response_text = 'In process, JSON being created'
where d365_pma_export_uid = @d365_pma_export_uid

--If this was an incremental posting, and project or status were also changed at the same time so a full reversal is ahead,
--skip the incremental because the descriptions and projects get messed up in the reversal
if @posting_type in ('I','S')
	and exists (select 1
				from D365PMAExport e
				join D365PMAExport h
					on h.workorder_id = e.workorder_id
					and h.company_id = e.company_id
					and h.profit_ctr_id = e.profit_ctr_id
					and h.resource_type = e.resource_type
					and h.d365_pma_export_uid = @d365_pma_export_uid
				where e.d365_pma_export_uid > h.d365_pma_export_uid
				and e.posting_type in ('R','F')
				and e.status = 'N')
begin
	select '' as json
	return 0
end

--determine the max version_id
select @version_id = coalesce(max(version_id),0)
from D365PMAExportHistoryL h
join D365PMAExport x
	on x.workorder_id = h.workorder_id
	and x.company_id = h.company_id
	and x.profit_ctr_id = h.profit_ctr_id
	and x.d365_pma_export_uid = @d365_pma_export_uid

--Full or Incremental data set. Insert new version into history, then generate JSON from it
if @posting_type in ('F','I')
begin
	--if this is the first posting, make sure a record exists in D365ExpenseWorkOrderPost
	if not exists (select 1
					from D365PMAExportWorkOrderPost p
					join D365PMAExport x
						on x.workorder_id = p.workorder_id
						and x.company_id = p.company_id
						and x.profit_ctr_id = p.profit_ctr_id
						and x.d365_pma_export_uid = @d365_pma_export_uid)

		insert D365PMAExportWorkOrderPost (workorder_id, company_id, profit_ctr_id, last_post_dt_es, last_post_dt_l)
		select workorder_id, company_id, profit_ctr_id, '01/01/2000', '01/01/2000'
		from D365PMAExport
		where d365_pma_export_uid = @d365_pma_export_uid

	--FOR JSON PATH does not allow the SQL to contain a UNION,
	--so to handle the case of generating individual reversals we'll need 2 inserts into a temp table
	create table #t (
		SOURCEAPP varchar(20) not null,
		SOURCEID int not null,
		DESCRIPTION varchar(50) not null,
		ACCOUNTCOMPANY varchar(20) not null,
		LINENUMBER int not null,
		CATEGORY varchar(40) not null,
		COSTPRICE numeric(12,4) not null,
		CURRENCYID varchar(10) not null,
		TEXT varchar(60) not null,
		HOURS numeric(12,4) not null,
		LINEPROPERTY varchar(20) not null,
		PROJECTDATE varchar(20) not null,
		PROJECTID varchar(20) not null,
		RESOURCECATEGORYID varchar(40) not null,
		RESOURCEID varchar(20) not null,
		VOUCHERDATE varchar(40) not null,
	)

	--If incremental, generate reversals for any *modified* records
	if @posting_type = 'I'
		insert #t
		select
			xh.SOURCEAPP,
			@d365_pma_export_uid,
			left(xh.DESCRIPTION,charindex('|',xh.DESCRIPTION,charindex('|',xh.DESCRIPTION) + 1)) + ' ' + convert(varchar(10),@d365_pma_export_uid) DESCRIPTION,
			xh.ACCOUNTCOMPANY,
			ROW_NUMBER() OVER(ORDER BY wod.sequence_id) LINENUMBER,
			xh.CATEGORY,
			xh.COSTPRICE,
			xh.CURRENCYID,
			xh.TEXT,
			xh.HOURS * -1.0 HOURS,
			xh.LINEPROPERTY,
			xh.PROJECTDATE,
			xh.PROJECTID,
			xh.RESOURCECATEGORYID,
			xh.RESOURCEID,
			xh.VOUCHERDATE
		from D365PMAExportHistoryL xh
		join D365PMAExport x
			on x.workorder_id = xh.workorder_id
			and x.company_id = xh.company_id
			and x.profit_ctr_id = xh.profit_ctr_id
			and x.d365_pma_export_uid = @d365_pma_export_uid
		join D365PMAExportWorkOrderPost p
			on p.workorder_id = xh.workorder_id
			and p.company_id = xh.company_id
			and p.profit_ctr_id = xh.profit_ctr_id
		join WorkOrderHeader woh
			on woh.workorder_id = xh.workorder_id
			and woh.company_id = xh.company_id
			and woh.profit_ctr_id = xh.profit_ctr_id
		join WorkOrderDetail wod
			on wod.workorder_ID = xh.workorder_ID
			and wod.company_id = xh.company_id
			and wod.profit_ctr_ID = xh.profit_ctr_ID
			and wod.sequence_id = xh.sequence_id
			and wod.resource_type = xh.resource_type
			and wod.date_modified > p.last_post_dt_l
		left outer join Resource r
			on r.resource_code = wod.resource_assigned
			and r.company_id = wod.company_id
		left outer join ProfitCenter pc_r
			on pc_r.company_id = r.company_id
			and pc_r.profit_ctr_id = r.default_profit_ctr_id
		left outer join Users u_r
			on u_r.user_id = r.user_id
		where xh.version_id = (select max(version_id)
								from D365PMAExportHistoryL
								where workorder_id = wod.workorder_id
								and company_id = wod.company_id
								and profit_ctr_id = wod.profit_ctr_id
								and sequence_id = wod.sequence_id
								and resource_type = wod.resource_type
								and status = 'A')
		and xh.status = 'A'
		and coalesce(xh.COSTPRICE,0) <> 0
		and coalesce(xh.HOURS,0) <> 0
		--The following was added to try to reduce # of transactions when a large number
		--of workorderdetail records get date_modified updated, but 3 key PMA fields weren't modified
		and (coalesce(case wod.bill_rate when 1.5 then 'OT' when 2 then 'DT' else 'ST' end,'') <> coalesce(right(xh.CATEGORY,2),'') or
			coalesce(wod.cost,0) <> coalesce(xh.COSTPRICE,0) or
			coalesce(wod.cost_quantity,0) <> coalesce(xh.HOURS,0) or
			coalesce(wod.date_service,woh.start_date) <> coalesce(xh.PROJECTDATE,'01/01/2000') or
			case when coalesce(wod.prevailing_wage_code,'') = '' then 'Team member' else wod.prevailing_wage_code end <> coalesce(xh.RESOURCECATEGORYID,'') or
			coalesce('WO ' + right('0' + convert(varchar(10),woh.company_id),2) + '-' + right('0' + convert(varchar(10),woh.profit_ctr_id),2) + '-' + convert(varchar(15),woh.workorder_id)
			+ ' | ' + wod.resource_type + convert(varchar(10),wod.sequence_id)
			+ case when coalesce(u_r.employee_id,'') = '' then '' else ' | ' + coalesce(u_r.employee_id,'') end
			+ ' | ' + coalesce(wod.cost_class,''),'') <> coalesce(xh.TEXT,'')
			)

	--insert a new version of data
	set @version_id = coalesce(@version_id,0) + 1

	select @line_offset = max(LINENUMBER) from #t

	insert D365PMAExportHistoryL
	select wod.workorder_id, wod.company_id, wod.profit_ctr_id, wod.sequence_id, wod.resource_type, @version_id, 'A',
		'EQAI' SOURCEAPP,
		'WO ' + right('0' + convert(varchar(10),woh.company_id),2) + '-' + right('0' + convert(varchar(10),woh.profit_ctr_id),2) + '-' + convert(varchar(15),woh.workorder_id)
			+ ' | ' + woh.AX_Dimension_5_Part_1 + case when coalesce(woh.AX_Dimension_5_Part_2,'') = '' then '' else '.' + woh.AX_Dimension_5_Part_2 end
			+ ' | ' + convert(varchar(10),@d365_pma_export_uid) DESCRIPTION,
		coalesce(pc.AX_Dimension_1,'') ACCOUNTCOMPANY,
		ROW_NUMBER() OVER(ORDER BY wod.sequence_id) LINENUMBER,
		fpc.category_id + case wod.bill_rate when 1.5 then ' OT' when 2 then ' DT' else ' ST' end CATEGORY,
		wod.cost COSTPRICE,
		coalesce(wod.currency_code,'USD') CURRENCYID,
		'WO ' + right('0' + convert(varchar(10),woh.company_id),2) + '-' + right('0' + convert(varchar(10),woh.profit_ctr_id),2) + '-' + convert(varchar(15),woh.workorder_id)
			+ ' | ' + wod.resource_type + convert(varchar(10),wod.sequence_id)
			+ case when coalesce(u_r.employee_id,'') = '' then '' else ' | ' + coalesce(u_r.employee_id,'') end
			+ ' | ' + coalesce(wod.cost_class,'') TEXT,
		convert(numeric(12,4), case wod.bill_unit_code
								when 'DAY' then 8.0 * coalesce(nullif(wod.cost_quantity,0),wod.quantity_used)
								when 'WEEK' then 40.0 * coalesce(nullif(wod.cost_quantity,0),wod.quantity_used)
								when 'MTH' then 172.0 * coalesce(nullif(wod.cost_quantity,0),wod.quantity_used)
								else coalesce(nullif(wod.cost_quantity,0),wod.quantity_used) end) HOURS,
		'NON-CHARGE' LINEPROPERTY,
		convert(varchar(10),case when wod.date_service is null then woh.start_date else wod.date_service end,120) PROJECTDATE,
		woh.AX_Dimension_5_Part_1 + case when coalesce(woh.AX_Dimension_5_Part_2,'') = '' then '' else '.' + woh.AX_Dimension_5_Part_2 end PROJECTID,
		case when coalesce(wod.prevailing_wage_code,'') = '' then 'Team member' else wod.prevailing_wage_code end RESOURCECATEGORYID,
		coalesce(u_r.employee_id,'') RESOURCEID,
		convert(varchar(10),case when wod.date_service is null then woh.start_date else wod.date_service end,120) VOUCHERDATE,
		'AX_SERVICE', getdate(), 'AX_SERVICE', getdate()
	from WorkOrderHeader woh
	join D365PMAExport x
		on x.workorder_id = woh.workorder_id
		and x.company_id = woh.company_id
		and x.profit_ctr_id = woh.profit_ctr_id
		and x.d365_pma_export_uid = @d365_pma_export_uid
	join D365PMAExportWorkOrderPost p
		on p.workorder_id = woh.workorder_id
		and p.company_id = woh.company_id
		and p.profit_ctr_id = woh.profit_ctr_id
	join WorkOrderDetail wod
		on woh.company_id = wod.company_id
		and woh.profit_ctr_ID = wod.profit_ctr_ID
		and woh.workorder_ID = wod.workorder_ID
		and coalesce(wod.cost,0) > 0
		and coalesce(wod.cost_quantity,0) > 0
		and coalesce(wod.cost_class,'') <> ''
		and coalesce(wod.date_service,woh.start_date) >= @compare_dt
		and wod.date_modified > case @posting_type when 'F' then '01/01/2000' else coalesce(p.last_post_dt_l,'01/01/2000') end
	join ResourceClassHeader rch
		on rch.resource_class_code = wod.cost_class
	join FinanceProjectCategory fpc
		on fpc.finance_project_category_id = rch.finance_project_category_id
		and fpc.finance_project_category_id = 3 --L
	join ProfitCenter pc
		on pc.company_id = woh.company_id
		and pc.profit_ctr_id = woh.profit_ctr_id
	left outer join Resource r
		on r.resource_uid = wod.resource_uid
	--	on r.resource_code = wod.resource_assigned
	--	and r.company_id = wod.company_id
	left outer join ProfitCenter pc_r
		on pc_r.company_id = r.company_id
		and pc_r.profit_ctr_id = r.default_profit_ctr_id
	left outer join Users u_r
		on u_r.user_id = r.user_id
	--The following was added to try to reduce # of transactions when a large number
	--of workorderdetail records get date_modified updated, but 3 key PMA fields weren't modified
	left outer join D365PMAExportHistoryL xh
		on xh.workorder_id = wod.workorder_id
		and xh.company_id = wod.company_id
		and xh.profit_ctr_id = wod.profit_ctr_id
		and xh.sequence_id = wod.sequence_id
		and xh.resource_type = wod.resource_type
		and xh.version_id = (select max(version_id)
							from D365PMAExportHistoryL
							where workorder_id = wod.workorder_id
							and company_id = wod.company_id
							and profit_ctr_id = wod.profit_ctr_id
							and sequence_id = wod.sequence_id
							and resource_type = wod.resource_type
							and status = 'A')
	where @posting_type = 'F' or
		(coalesce(case wod.bill_rate when 1.5 then 'OT' when 2 then 'DT' else 'ST' end,'') <> coalesce(right(xh.CATEGORY,2),'') or
		coalesce(wod.cost,0) <> coalesce(xh.COSTPRICE,0) or
		coalesce(wod.cost_quantity,0) <> coalesce(xh.HOURS,0) or
		coalesce(wod.date_service,woh.start_date) <> coalesce(xh.PROJECTDATE,'01/01/2000') or
		case when coalesce(wod.prevailing_wage_code,'') = '' then 'Team member' else wod.prevailing_wage_code end <> coalesce(xh.RESOURCECATEGORYID,'') or
		coalesce('WO ' + right('0' + convert(varchar(10),woh.company_id),2) + '-' + right('0' + convert(varchar(10),woh.profit_ctr_id),2) + '-' + convert(varchar(15),woh.workorder_id)
		+ ' | ' + wod.resource_type + convert(varchar(10),wod.sequence_id)
		+ case when coalesce(u_r.employee_id,'') = '' then '' else ' | ' + coalesce(u_r.employee_id,'') end
		+ ' | ' + coalesce(wod.cost_class,''),'') <> coalesce(xh.TEXT,'')
		)

	--add new records to temp table
	insert #t
	select
		xh.SOURCEAPP,
		@d365_pma_export_uid,
		xh.DESCRIPTION,
		xh.ACCOUNTCOMPANY,
		xh.LINENUMBER + coalesce(@line_offset,0),
		xh.CATEGORY,
		xh.COSTPRICE,
		xh.CURRENCYID,
		xh.TEXT,
		xh.HOURS,
		xh.LINEPROPERTY,
		xh.PROJECTDATE,
		xh.PROJECTID,
		xh.RESOURCECATEGORYID,
		xh.RESOURCEID,
		xh.VOUCHERDATE
	from D365PMAExportHistoryL xh
	join D365PMAExport x
		on x.workorder_id = xh.workorder_id
		and x.company_id = xh.company_id
		and x.profit_ctr_id = xh.profit_ctr_id
		and x.d365_pma_export_uid = @d365_pma_export_uid
	where xh.version_id = @version_id
	and xh.status = 'A'
	and coalesce(xh.COSTPRICE,0) <> 0
	and coalesce(xh.HOURS,0) <> 0

	--generate JSON
	set @json = (
	select * from #t
	for JSON PATH
	)

	--for Full and Incremental, update last posting date
	update D365PMAExportWorkOrderPost
	set last_post_dt_l = getdate()
	from D365PMAExportWorkOrderPost p
	join D365PMAExport x
		on x.workorder_id = p.workorder_id
		and x.company_id = p.company_id
		and x.profit_ctr_id = p.profit_ctr_id
		and x.d365_pma_export_uid = @d365_pma_export_uid
end

else if @posting_type = 'R'
begin
	set @json = (
	select
		xh.SOURCEAPP,
		@d365_pma_export_uid SOURCEID,
		left(xh.DESCRIPTION,charindex('|',xh.DESCRIPTION,charindex('|',xh.DESCRIPTION) + 1)) + ' ' + convert(varchar(10),@d365_pma_export_uid) DESCRIPTION,
		xh.ACCOUNTCOMPANY,
		ROW_NUMBER() OVER(ORDER BY xh.sequence_id) LINENUMBER,
		xh.CATEGORY,
		xh.COSTPRICE,
		xh.CURRENCYID,
		xh.TEXT,
		xh.HOURS * -1.0 HOURS,
		xh.LINEPROPERTY,
		xh.PROJECTDATE,
		xh.PROJECTID,
		xh.RESOURCECATEGORYID,
		xh.RESOURCEID,
		xh.VOUCHERDATE
	from D365PMAExportHistoryL xh
	join D365PMAExport x
		on x.workorder_id = xh.workorder_id
		and x.company_id = xh.company_id
		and x.profit_ctr_id = xh.profit_ctr_id
		and x.d365_pma_export_uid = @d365_pma_export_uid
	where xh.version_id = (select max(version_id)
							from D365PMAExportHistoryL
							where workorder_id = xh.workorder_id
							and company_id = xh.company_id
							and profit_ctr_id = xh.profit_ctr_id
							and resource_type = xh.resource_type
							and sequence_id = xh.sequence_id)
	and xh.status = 'A'
	and coalesce(xh.COSTPRICE,0) <> 0
	and coalesce(xh.HOURS,0) <> 0
	for JSON PATH
	)
end

--single reversal
else if @posting_type = 'S'
begin
	select @version_id = max(xh.version_id)
	from D365PMAExportHistoryL xh
	join D365PMAExport x
		on x.workorder_id = xh.workorder_id
		and x.company_id = xh.company_id
		and x.profit_ctr_id = xh.profit_ctr_id
		and x.deleted_or_voided_sequence_id = xh.sequence_id
		and x.deleted_or_voided_resource_type = xh.resource_type
		and x.d365_pma_export_uid = @d365_pma_export_uid

	set @json = (
	select
		xh.SOURCEAPP,
		@d365_pma_export_uid SOURCEID,
		left(xh.DESCRIPTION,charindex('|',xh.DESCRIPTION,charindex('|',xh.DESCRIPTION) + 1)) + ' ' + convert(varchar(10),@d365_pma_export_uid) DESCRIPTION,
		xh.ACCOUNTCOMPANY,
		1 LINENUMBER,
		xh.CATEGORY,
		xh.COSTPRICE,
		xh.CURRENCYID,
		xh.TEXT,
		xh.HOURS * -1.0 HOURS,
		xh.LINEPROPERTY,
		xh.PROJECTDATE,
		xh.PROJECTID,
		xh.RESOURCECATEGORYID,
		xh.RESOURCEID,
		xh.VOUCHERDATE
	from D365PMAExportHistoryL xh
	join D365PMAExport x
		on x.workorder_id = xh.workorder_id
		and x.company_id = xh.company_id
		and x.profit_ctr_id = xh.profit_ctr_id
		and x.deleted_or_voided_sequence_id = xh.sequence_id
		and x.deleted_or_voided_resource_type = xh.resource_type
		and x.d365_pma_export_uid = @d365_pma_export_uid
	where xh.version_id = @version_id
	and xh.status = 'A'
	and coalesce(xh.COSTPRICE,0) <> 0
	and coalesce(xh.HOURS,0) <> 0
	FOR JSON PATH
	)

	update D365PMAExportHistoryL
	set status = 'V'
	from D365PMAExportHistoryL xh
	join D365PMAExport x
		on x.workorder_id = xh.workorder_id
		and x.company_id = xh.company_id
		and x.profit_ctr_id = xh.profit_ctr_id
		and x.deleted_or_voided_sequence_id = xh.sequence_id
		and x.deleted_or_voided_resource_type = xh.resource_type
		and x.d365_pma_export_uid = @d365_pma_export_uid
	where xh.status = 'A'
end

--return JSON
select coalesce(@json,'') as json
go
