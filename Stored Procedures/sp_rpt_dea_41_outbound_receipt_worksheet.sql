
create procedure sp_rpt_dea_41_outbound_receipt_worksheet
	@company_id int,
	@profit_ctr_id int,
	@receipt_id int
as
-- 12/09/2015 rb Created
declare @unprocessed_count int,
		@container_type char(1),
		@r_id int,
		@l_id int,
		@tracking_num varchar(15)

create table #upstream (
	container_type char(1),
	company_id int,
	profit_ctr_id int,
	receipt_id int,
	line_id int,
	container_id int,
	sequence_id int,
	tracking_num varchar(15),
	processed_flag int
)

create table #stage (
	container_type char(1),
	company_id int,
	profit_ctr_id int,
	receipt_id int,
	line_id int,
	container_id int,
	sequence_id int,
	tracking_num varchar(15),
	processed_flag int
)

create table #processed (
	container_type char(1),
	receipt_id int,
	line_id int
)

set transaction isolation level read uncommitted

--initialize work table with inbounds linked to the outbound receipt
insert #upstream
select container_type, company_id, profit_ctr_id, receipt_id, line_id, container_id, sequence_id,
		convert(varchar(10),receipt_id) + '-' + convert(varchar(10),line_id), 0
from ContainerDestination
where container_type = 'R'
and company_id = @company_id
and profit_ctr_id = @profit_ctr_id
and tracking_num like convert(varchar(10),@receipt_id) + '-%'
union
select container_type, company_id, profit_ctr_id, receipt_id, line_id, container_id, sequence_id,
		dbo.fn_container_stock (line_id, @company_id, @profit_ctr_id), 0
from ContainerDestination
where container_type = 'S'
and company_id = @company_id
and profit_ctr_id = @profit_ctr_id
and tracking_num like convert(varchar(10),@receipt_id) + '-%'

--loop while there are records to process
select @unprocessed_count = count(*)
from #upstream
where processed_flag = 0

while @unprocessed_count > 0
begin
	--pull more upstreams into staging table
	declare c_loop cursor forward_only read_only for
	select container_type, receipt_id, line_id
	from #upstream
	where processed_flag = 0
	
	open c_loop
	fetch c_loop into @container_type, @r_id, @l_id
	
	while @@FETCH_STATUS = 0
	begin
		-- check against #processed table, to avoid falling into endless loop when circular reference exists
		if exists (select 1 from #processed
					where container_type = @container_type
					and receipt_id = @r_id
					and line_id = @l_id)
			goto NEXT_FETCH

		if @container_type = 'R'
			set @tracking_num = convert(varchar(10),@r_id) + '-' + convert(varchar(10),@l_id)
		else
			set @tracking_num = dbo.fn_container_stock (@l_id, @company_id, @profit_ctr_id)

		insert #stage
		select container_type, company_id, profit_ctr_id, receipt_id, line_id, container_id, sequence_id,
				convert(varchar(10),receipt_id) + '-' + convert(varchar(10),line_id), 0
		from ContainerDestination
		where container_type = 'R'
			and company_id = @company_id
			and profit_ctr_id = @profit_ctr_id
			and base_tracking_num = @tracking_num

		insert #stage
		select container_type, company_id, profit_ctr_id, receipt_id, line_id, container_id, sequence_id,
				dbo.fn_container_stock(line_id, company_id, profit_ctr_id), 0
		from ContainerDestination
		where container_type = 'S'
			and company_id = @company_id
			and profit_ctr_id = @profit_ctr_id
			and base_tracking_num = @tracking_num

		insert #processed values (@container_type, @r_id, @l_id)

		NEXT_FETCH:
		fetch c_loop into @container_type, @r_id, @l_id
	end
	
	close c_loop
	deallocate c_loop

	--set the processed flag
	update #upstream set processed_flag = 1
	where processed_flag = 0

	--copy staging table to upstream, and clear staging table
	insert #upstream
	select * from #stage	

	truncate table #stage

	--see if there are more records to process
	select @unprocessed_count = count(*)
	from #upstream
	where processed_flag = 0
end

-- select distinct list of valid receipt/line info into #stage
insert #stage
select distinct u.container_type, u.company_id, u.profit_ctr_id, u.receipt_id, u.line_id, 0, 0, '', 0
from #upstream u
join Receipt r
	on r.company_id = u.company_id
	and r.profit_ctr_id = u.profit_ctr_id
	and r.receipt_id = u.receipt_id
	and r.line_id = u.line_id
	and r.receipt_status <> 'V'
where u.container_type = 'R'

--return results
select convert(varchar(4), ROW_NUMBER() OVER(ORDER BY rdi.merchandise_code, rdi.receipt_id, rdi.line_id, rdi.sub_sequence_id)) + '.' as row_num,
	left(rdi.merchandise_code,5) + '-' + substring(rdi.merchandise_code,6,4) + '-' + right(rdi.merchandise_code,2) as merchandise_code,
	rdi.manual_entry_desc,
	case when isnull(ltrim(m.strength),'') = '' and isnull(ltrim(m.unit),'') = '' then 'N/A' else isnull(ltrim(rtrim(m.strength)),'') + ' ' + isnull(ltrim(rtrim(m.unit)),'') end as strength,
	case when isnull(ltrim(dt.description),'') = '' then 'N/A' else ltrim(rtrim(dt.description)) end as form,
	m.package_size,
	case when rdi.merchandise_quantity is null then 'N/A' else convert(varchar(10),rdi.merchandise_quantity) end as merchandise_quantity,
	case when isnull(ltrim(rdi.contents),'') = '' and isnull(ltrim(dt.description),'') = '' then 'N/A' else isnull(ltrim(rtrim(rdi.contents)),'') + ' ' + isnull(ltrim(rtrim(dt.description)),'') end as total_destroyed,
	RIGHT('0' + convert(varchar(2),s.company_id),2) + '-' + RIGHT('0' + convert(varchar(2),s.profit_ctr_id),2)
	+ '-' + convert(varchar(10),s.receipt_id) + '-' + CONVERT(varchar(10),s.line_id) as inbound_receipt
from #stage s
join ReceiptDetailItem rdi
	on rdi.company_id = s.company_id
	and rdi.profit_ctr_id = s.profit_ctr_id
	and rdi.receipt_id = s.receipt_id
	and rdi.line_id = s.line_id
	and rdi.item_type_ind = 'ME'
	and rdi.DEA_schedule in ('2','02','3','03','4','04','5','05')
join Merchandise m
	on m.merchandise_id = rdi.merchandise_id
left outer join DosageType dt
	on dt.dosage_type_id = rdi.dosage_type_id
order by rdi.merchandise_code, rdi.receipt_id, rdi.line_id, rdi.sub_sequence_id

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_dea_41_outbound_receipt_worksheet] TO [EQAI]
    AS [dbo];

