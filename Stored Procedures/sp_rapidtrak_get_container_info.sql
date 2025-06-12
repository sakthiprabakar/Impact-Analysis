if exists (select 1 from sysobjects where type = 'P' and name = 'sp_rapidtrak_get_container_info')
	drop procedure sp_rapidtrak_get_container_info
go

create procedure sp_rapidtrak_get_container_info
	@container varchar(20)
as
--
-- 02/25/2022  rwb	Created
-- 10/06/2023  rwb	DO 73639 Added facility_description to result set
--
-- Receipt:			exec sp_rapidtrak_get_container_info '1406-65332-1-1'
--					exec sp_rapidtrak_get_container_info '4200-300065-1-1'
-- Stock container:	exec sp_rapidtrak_get_container_info 'DL-2200-057641'
--

declare @pos int,
		@pos2 int,
		@msg varchar(255),
		@company_id int,
		@profit_ctr_id int,
		@type char(1),
		@receipt_id int,
		@line_id int,
		@container_id int,

		@container_date datetime,
		@container_status varchar(15),
		@generator_name varchar(75)

set nocount on

-- validate arguments
if substring(@container,1,2) = 'P-'
begin
	set @msg = 'Container ''' + isnull(@container,'') + ''' is not a valid container'
	raiserror(@msg,16,1)
	return -1
end
else
	exec dbo.sp_rapidtrak_parse_container @container, @type out, @company_id out, @profit_ctr_id out, @receipt_id out, @line_id out, @container_id out

set nocount off

--different values for Receipt and Stock
if @type = 'R'
	select @container_date = r.receipt_date,
			@container_status = case r.fingerpr_status
									when 'A' then 'Accepted'
									when 'R' then 'Rejected'
									when 'W' then 'Waiting'
									when 'H' then 'Hold'
								else '' end,
			@generator_name = coalesce(g.generator_name,'')
	from Receipt r
	left outer join Generator g
		on g.generator_id = r.generator_id
	where r.receipt_id = @receipt_id
	and r.company_id = @company_id
	and r.profit_ctr_id = @profit_ctr_id
	and r.line_id = @line_id
else
	select @container_date = date_added,
			@container_status = case status
									when 'C' then 'Complete'
									when 'N' then 'Not Complete'
								else '' end,
			@generator_name = ''
	from Container
	where container_type = @type
	and receipt_id = @receipt_id
	and company_id = @company_id
	and profit_ctr_id = @profit_ctr_id
	and line_id = @line_id
	and container_id = @container_id

select distinct
	case @type when 'R' then 'Receipt Container' else 'Stock Container' end as container_type,
	convert(varchar(10),@container_date,101) as container_date,
	@container_status as container_status,
	c.staging_row,
	c.container_size,
	@generator_name as generator_name,
	cd.treatment_id,
	t.wastetype_category + ': ' + t.wastetype_description as treatment_waste_type,
	t.treatment_process_process as treatment_process,
	t.disposal_service_desc as treatment_disposal_service,
	case pc.print_facility_treatment_desc_on_container_labels_flag
		when 'T' then coalesce(td.facility_description,'')
		else ''
	end facility_description
from Container c
join ProfitCenter pc
	on pc.company_id = c.company_id
	and pc.profit_ctr_id = c.profit_ctr_id
left outer join ContainerDestination cd
	ON cd.company_id = c.company_id
	AND cd.profit_ctr_id = c.profit_ctr_id
	AND cd.receipt_id = c.receipt_id
	AND cd.line_id = c.line_id
	AND cd.container_id = c.container_id
	AND cd.container_type = c.container_type
left outer join Treatment t
	ON t.company_id = cd.company_id 
	AND t.profit_ctr_id = cd.profit_ctr_id
	AND t.treatment_id = cd.treatment_id
left outer join TreatmentDetail td
	ON td.company_id = cd.company_id 
	AND td.profit_ctr_id = cd.profit_ctr_id
	AND td.treatment_id = cd.treatment_id
where c.company_id = @company_id
and c.profit_ctr_id = @profit_ctr_id
and c.receipt_id = @receipt_id
and c.line_id = @line_id
and c.container_id = @container_id
and c.container_type = @type
go

grant execute on sp_rapidtrak_get_container_info to eqai
go
