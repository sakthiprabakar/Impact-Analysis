if exists (select 1 from sysobjects where type = 'P' and name = 'sp_ss_get_trip_waste_codes')
	drop procedure sp_ss_get_trip_waste_codes
go

create procedure sp_ss_get_trip_waste_codes
	@trip_id int,
	@trip_sequence_id int = 0
with recompile
as
declare @source_id int,
		@company_id int,
		@profit_center int,
		@line_id int,
		@orig_waste_code_uid int,
		@new_waste_code_uid int,
		@wastecode varchar(10),
		@generator_id int,
		@origin_state varchar(2),
		@destination_state varchar(2)

set transaction isolation level read uncommitted

CREATE TABLE #source_list (
	source_id int null
)

CREATE TABLE #manifest (
	source_id int null,
	source_line int null,
	manifest varchar(40) null,
	manifest_line char null,
	waste_code_uid int null,
	waste_code_state varchar(2) null,
	wastecode varchar(10) null,
	sequence_id int null
)

CREATE TABLE #work (
	source_id int
	, source_line int
	, waste_code_uid int
	, waste_code varchar(4)
	, display_name varchar(10)
	, waste_code_origin char(1)
	, state varchar(2)
	, source_sequence_id int
	, print_sequence_id int
)

select @company_id = company_id,
	@profit_center = profit_ctr_id
from TripHeader
where trip_id = @trip_id

insert #source_list
select workorder_id
from WorkOrderHeader
where trip_id = @trip_id
and (@trip_sequence_id = 0 or trip_sequence_id = @trip_sequence_id)

declare c_wc_workorder cursor forward_only read_only for
select distinct wd.workorder_id, wd.sequence_id
from #source_list s
join WorkOrderDetail wd
	on wd.company_id = @company_id
	and wd.profit_ctr_id = @profit_center
	and wd.workorder_id = s.source_id
	and wd.resource_type = 'D'
	and wd.bill_rate <> -2

open c_wc_workorder
fetch c_wc_workorder into @source_id, @line_id

while @@FETCH_STATUS = 0
begin
	SELECT @origin_state = ISNULL(g.generator_state, 'ZZ'),
		@destination_state = ISNULL(TSDF.TSDF_state, 'ZZ'),
		@generator_id = woh.generator_id
	FROM WorkOrderHeader woh
	JOIN Generator g ON g.generator_id = woh.generator_id
	JOIN WorkOrderDetail wod ON wod.company_id = woh.company_id
		AND wod.profit_ctr_id = woh.profit_ctr_id
		AND wod.workorder_id = woh.workorder_id
		AND wod.sequence_id = @line_id
		AND wod.resource_type = 'D'
	JOIN TSDF ON TSDF.TSDF_code = wod.TSDF_code
	WHERE woh.company_id = @company_id
	AND woh.profit_ctr_id = @profit_center
	AND woh.workorder_id = @source_id

	INSERT #work
	SELECT 
		@source_id
		, @line_id
		, wc.waste_code_uid
		, wowc.waste_code
		, wc.display_name
		, wc.waste_code_origin
		, UPPER(wc.state)
		, IsNull (wowc.sequence_id , 0 ) AS source_sequence_id
		, wowc.sequence_id AS print_sequence_id
	FROM WorkOrderWasteCode wowc
	INNER JOIN WasteCode wc ON wc.waste_code_uid = wowc.waste_code_uid
	LEFT OUTER JOIN WasteCodeXGenerator wcxg
		ON wcxg.generator_id = @generator_id
		AND wcxg.waste_code_uid = wowc.waste_code_uid
	WHERE wowc.company_id = @company_id
	AND wowc.profit_ctr_id = @profit_center
	AND wowc.workorder_id = @source_id
	AND wowc.workorder_sequence_id = @line_id
	AND wowc.sequence_id IS NOT NULL
	AND (
		-- Code is either a non-state code (Fed)
		ISNULL(wc.waste_code_origin, '') <> 'S'
		OR
		(
			-- Or it's a state code, belonging to the origin or destination state
			-- So we're excluding codes for other states here, on purpose.
			-- Neither the origin nor the destination state is TX
			ISNULL(wc.waste_code_origin, '') = 'S'
			AND
			ISNULL(wc.state, '') IN (@origin_state, @destination_state)
			AND
			NOT (@origin_state = 'TX' OR @destination_state = 'TX')
			
			OR
			(
				-- Or it's a state code, belonging to the origin or destination state
				-- Either the origin or the destination state is TX
					
				--	If the generator is in Texas 
				--		If the profile has an individual Texas code that matches the generator id on the transaction, use that code.
				--		Else, if the generator is in Texas and there is not a waste code on the profile that matches that generator id, use the CESQxxxx code, 
				--			or the UNIVxxxx code, whichever one is there.
				--  If the TSDF is in Texas 
				--		If the profile has an individual Texas code that matches the generator id on the transaction, use that code.
				--		Else, if the generator is not in Texas and there is not a waste code on the profile that matches that generator id, use the OUTSxxxx code.
					
				ISNULL(wc.waste_code_origin, '') = 'S'
				AND
				ISNULL(wc.state, '') IN (@origin_state, @destination_state)
				AND
				(@origin_state = 'TX' OR @destination_state = 'TX')
				AND 
				(
					wcxg.waste_code_uid IS NOT NULL
					OR wc.state <> 'TX'  --added 5/23/2018 for handling of Origin = TX and Destination <> TX to apply appropriate Destination state codes
					OR
					(
						wcxg.waste_code_uid IS NULL 
						AND @origin_state = 'TX'
						AND (LEFT(wc.display_name, 4) = 'CESQ' OR LEFT(wc.display_name, 4) = 'UNIV')
						AND NOT EXISTS 
							(SELECT 1 FROM
							WorkOrderWasteCode pwc
							INNER JOIN WasteCode wc ON pwc.waste_code_uid = wc.waste_code_uid
							AND NOT (wc.waste_code = 'NONE')
							LEFT OUTER JOIN WasteCodeXGenerator wcxg
							ON wcxg.generator_id = @generator_id
							AND wcxg.waste_code_uid = pwc.waste_code_uid
							WHERE 
							pwc.company_id = @company_id
							AND pwc.profit_ctr_id = @profit_center
							AND pwc.workorder_id = @source_id
							AND pwc.workorder_sequence_id = @line_id
							AND pwc.sequence_id IS NOT NULL							
							AND (
								-- It's a state code, belonging to the origin or destination state
								-- Either the origin or the destination state is TX
								ISNULL(wc.waste_code_origin, '') = 'S'
								AND
								ISNULL(wc.state, '') IN (@origin_state, @destination_state)
								AND
								(@origin_state = 'TX' OR @destination_state = 'TX')
								AND 
								(
								wcxg.waste_code_uid IS NOT NULL
								) 
							)	
						)
					)
					OR
					(
						wcxg.waste_code_uid IS NULL
						AND @origin_state <> 'TX'
						AND @destination_state = 'TX'
						AND LEFT(wc.display_name, 4) = 'OUTS'
						AND NOT EXISTS 
							(SELECT 1 FROM
							WorkOrderWasteCode pwc
							INNER JOIN WasteCode wc ON pwc.waste_code_uid = wc.waste_code_uid
							--AND wc.waste_code <> 'NONE'
							AND NOT (wc.waste_code = 'NONE')
							LEFT OUTER JOIN WasteCodeXGenerator wcxg
							ON wcxg.generator_id = @generator_id
							AND wcxg.waste_code_uid = pwc.waste_code_uid
							WHERE 
							pwc.company_id = @company_id
							AND pwc.profit_ctr_id = @profit_center
							AND pwc.workorder_id = @source_id
							AND pwc.workorder_sequence_id = @line_id
							AND pwc.sequence_id IS NOT NULL							
							AND (
								-- It's a state code, belonging to the origin or destination state
								-- Either the origin or the destination state is TX
								ISNULL(wc.waste_code_origin, '') = 'S'
								AND
								ISNULL(wc.state, '') IN (@origin_state, @destination_state)
								AND
								(@origin_state = 'TX' OR @destination_state = 'TX')
								AND 
								(
								wcxg.waste_code_uid IS NOT NULL

								) 
							)	
						)
					)
				)
			)
		)
	)

	insert #work
	SELECT
		@source_id
		, @line_id
		, wc.waste_code_uid
		, pwc.waste_code
		, wc.display_name
		, wc.waste_code_origin
		, UPPER(wc.state)
		, null AS source_sequence_id
		, null AS print_sequence_id
	FROM ProfileWasteCode pwc
	JOIN WorkOrderDetail wd
		ON wd.profile_id = pwc.profile_id
		AND wd.workorder_id = @source_id
		AND wd.company_id = @company_id
		AND wd.profit_ctr_id = @profit_center
		AND wd.sequence_id = @line_id
		AND wd.resource_type = 'D'
	JOIN WasteCode wc
		ON wc.waste_code_uid = pwc.waste_code_uid
		AND COALESCE(wc.state,'') = ''
	WHERE NOT EXISTS (select 1 from #work
						where #work.source_id = @source_id
						and #work.source_line = @line_id
						and #work.waste_code_uid = pwc.waste_code_uid)

	fetch c_wc_workorder into @source_id, @line_id
end
close c_wc_workorder
deallocate c_wc_workorder

declare c_tx cursor forward_only read_only for
select source_id, source_line, waste_code_uid, display_name
from #work
where state = 'TX'
and display_name like 'CESQ%'

open c_tx
fetch c_tx into @source_id, @line_id, @orig_waste_code_uid, @wastecode

while @@FETCH_STATUS = 0
begin
	select @generator_id = generator_id
	from WorkOrderHeader
	where workorder_id = @source_id
	and company_id = @company_id
	and profit_ctr_id = @profit_center

	set @new_waste_code_uid = null

	select @new_waste_code_uid = max(x.waste_code_uid)
	from WasteCodeXGenerator x
	join WasteCode wc
		on wc.waste_code_uid = x.waste_code_uid
		and left(wc.display_name,4) <> 'CESQ'
		and right(wc.display_name,4) = right(@wastecode,4)
	where x.generator_id = @generator_id

	if @new_waste_code_uid is not null
	begin
		update #work
		set waste_code_uid = @new_waste_code_uid,
			display_name = (select left(display_name,4) from WasteCode where waste_code_uid = @new_waste_code_uid) + right(@wastecode,4)
		where source_id = @source_id
		and source_line = @line_id
		and waste_code_uid = @orig_waste_code_uid
	end

	fetch c_tx into @source_id, @line_id, @orig_waste_code_uid, @wastecode
end

close c_tx
deallocate c_tx


select distinct wd.workorder_ID,
		wd.company_id,
		wd.profit_ctr_ID,
		wd.sequence_id wd_sequence_id,
		wd.profile_id approval_id,
		convert(char(1),'P') approval_type,
		pwc.waste_code_uid,
		pwc.primary_flag,
		w.print_sequence_id sequence_id,
		pwc.sequence_flag,
		wc.waste_code_origin,
		coalesce(wc.state,'') state,
		wc.haz_flag,
		wc.pcb_flag,
		coalesce(w.display_name,wc.display_name) display_name
into #t
from WorkOrderHeader wh with (index(idx_trip_id))
join WorkOrderDetail wd
	on wd.workorder_id = wh.workorder_ID
	and wd.company_id = wh.company_id
	and wd.profit_ctr_id = wh.profit_ctr_ID
	and wd.resource_type = 'D'
join #work w
	on w.source_id = wd.workorder_id
	and w.source_line = wd.sequence_id
join TSDF t
	on t.TSDF_code = wd.TSDF_code
	and coalesce(t.eq_flag,'') = 'T'
join ProfileWasteCode pwc
	on pwc.profile_id = wd.profile_id
	and pwc.waste_code_uid = w.waste_code_uid
join WasteCode wc
	on wc.waste_code_uid = pwc.waste_code_uid
where wh.trip_id = @trip_id
and wh.workorder_status <> 'V'
and (@trip_sequence_id = 0 or wh.trip_sequence_id = @trip_sequence_id)

insert #t
select distinct wd.workorder_ID,
		wd.company_id,
		wd.profit_ctr_ID,
		wd.sequence_id wd_sequence_id,
		wd.tsdf_approval_id approval_id,
		convert(char(1),'T') approval_type,
		twc.waste_code_uid,
		twc.primary_flag,
		w.print_sequence_id sequence_id,
		twc.sequence_flag,
		wc.waste_code_origin,
		coalesce(wc.state,'') state,
		wc.haz_flag,
		wc.pcb_flag,
		coalesce(w.display_name,wc.display_name) display_name
from WorkOrderHeader wh
join WorkOrderDetail wd
	on wd.workorder_id = wh.workorder_ID
	and wd.company_id = wh.company_id
	and wd.profit_ctr_id = wh.profit_ctr_ID
	and wd.resource_type = 'D'
join #work w
	on w.source_id = wd.workorder_id
	and w.source_line = wd.sequence_id
join TSDF t
	on t.TSDF_code = wd.TSDF_code
	and coalesce(t.eq_flag,'') <> 'T'
join TSDFApprovalWasteCode twc
	on twc.TSDF_approval_id = wd.TSDF_approval_id
	and twc.waste_code_uid = w.waste_code_uid
join WasteCode wc
	on wc.waste_code_uid = twc.waste_code_uid
where wh.trip_id = @trip_id
and wh.workorder_status <> 'V'
and (@trip_sequence_id = 0 or wh.trip_sequence_id = @trip_sequence_id)
order by wd.workorder_id, wd.sequence_id

select * from #t
order by workorder_id, wd_sequence_id, approval_type, approval_id, coalesce(sequence_id,9999), waste_code_uid

drop table #t
drop table #manifest
drop table #source_list
drop table #work
go

grant execute on sp_ss_get_trip_waste_codes to EQAI, TRIPSERV
go
