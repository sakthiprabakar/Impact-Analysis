CREATE PROCEDURE sp_rpt_receipt_pcb_control_sheet 
	@company_id		 int
,	@profit_ctr_id	 int
,	@receipt_id		 int
AS
/***********************************************************************************
PB Object(s):	r_receipt_pcb_control_sheet

03/29/2018 MPM	Created on Plt_AI

exec sp_rpt_receipt_pcb_control_sheet 3, 0, 1276350
exec sp_rpt_receipt_pcb_control_sheet 3, 0, 1276342
exec sp_rpt_receipt_pcb_control_sheet 3, 0, 1276280

***********************************************************************************/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

DECLARE @row_count	int,
		@cnt		int,
		@blanks		int

create table #results (
	manifest				varchar(15)		NULL,
	EPA_ID					varchar(12)		NULL,
	generator_name			varchar(40)		NULL,
	generator_address_1		varchar(40)		NULL,
	generator_address_2		varchar(40)		NULL,
	generator_city			varchar(40)		NULL,
	generator_state			char(2)			NULL,
	generator_zip_code		varchar(15)		NULL,
	receipt					varchar(16)		NULL,
	receipt_date			datetime		NULL,
	approval_code			varchar(15)		NULL,
	quantity				int				NULL,
	manifest_container_code	varchar(15)		NULL,
	waste_desc				varchar(100)	NULL,
	drained_or_full			varchar(3)		NULL,
	manufacturer			varchar(20)		NULL,
	manifest_line			int				NULL,
	container_id			varchar(20)		NULL,
	kVA_rating				decimal(7,2)	NULL,
	weight					float			NULL,
	dielectric_volume		varchar(20)		NULL,
	pcb_ppm					varchar(20)		NULL,
	storage_start_date		datetime		NULL,
	absorbents_added		varchar(3)		NULL,
	generator_id			int				NULL,
	line_id					int				NULL,
	sequence_id				int				NULL,
	first_sort				int				NULL
)

insert into #results
select 
		r.manifest,
		g.EPA_ID,
		g.generator_name,
		g.generator_address_1,
		g.generator_address_2,
		g.generator_city,
		g.generator_state,
		g.generator_zip_code,
		right('0' + convert(varchar(10),r.company_id),2) + '-' + right('0' + convert(varchar(10),r.profit_ctr_id),2)
					+ '-' + convert(varchar(10),r.receipt_id),
		r.receipt_date,
		r.approval_code, 
		1, 
		r.manifest_container_code, 
		rp.waste_desc, 
		rp.drained_or_full, 
		rp.manufacturer,
		r.manifest_line, 
		rp.container_id, 
		rp.kVA_rating,
		rp.weight, 
		rp.dielectric_volume, 
		rp.pcb_ppm, 
		rp.storage_start_date, 
		case isnull(rp.absorbents_added_flag, 'F') when 'T' then 'Yes' else 'No' end,
		g.generator_id,
		rp.line_id,
		rp.sequence_id,
		1 as first_sort
	from receipt r 
	join generator g
		on g.generator_id = r.generator_id
	join receiptpcb rp 
		on r.company_id = rp.company_id 
		and r.profit_ctr_id = rp.profit_ctr_id 
		and r.receipt_id = rp.receipt_id 
		and r.line_id = rp.line_id
	join profilelab pl 
		on r.profile_id = pl.profile_id 
		and pl.type = 'A'
	where 
		r.company_id = @company_id
		and r.profit_ctr_id = @profit_ctr_id 
		and r.receipt_id = @receipt_id
		and r.receipt_status not in ('V', 'R')
		and r.trans_mode = 'I'
		and r.fingerpr_status not in ('V', 'R')

-- Get the row count.
-- If there are 11 or less rows, insert enough "blank" lines to make a total of 11 rows.
-- If there are more than 11 rows, add 10 "blank" lines.

select @row_count = COUNT(*) from #results

if @row_count > 0 and @row_count <= 11
	set @blanks = 11 - @row_count
else
	if @row_count > 11
		set @blanks = 10
		
if @row_count > 0
begin
	set @cnt = 0

	WHILE @cnt < @blanks
	BEGIN
		insert into #results
		select top 1
				r.manifest,
				g.EPA_ID,
				g.generator_name,
				g.generator_address_1,
				g.generator_address_2,
				g.generator_city,
				g.generator_state,
				g.generator_zip_code,
				right('0' + convert(varchar(10),r.company_id),2) + '-' + right('0' + convert(varchar(10),r.profit_ctr_id),2)
							+ '-' + convert(varchar(10),r.receipt_id),
				r.receipt_date,
				null, 
				null, 
				null, 
				null, 
				null, 
				null,
				null, 
				null, 
				null,
				null, 
				null, 
				null, 
				null, 
				null,
				g.generator_id,
				null,
				null,
				2
			from receipt r 
			join generator g
				on g.generator_id = r.generator_id
			where 
				r.company_id = @company_id
				and r.profit_ctr_id = @profit_ctr_id 
				and r.receipt_id = @receipt_id
				and r.receipt_status not in ('V', 'R')
				and r.trans_mode = 'I'
				and r.fingerpr_status not in ('V', 'R')

	   SET @cnt = @cnt + 1
	END
end

-- Return results
select	manifest,
		EPA_ID,
		generator_name,
		generator_address_1,
		generator_address_2,
		generator_city,
		generator_state,
		generator_zip_code,
		receipt,
		receipt_date,
		approval_code, 
		quantity, 
		manifest_container_code, 
		waste_desc, 
		drained_or_full, 
		manufacturer,
		manifest_line, 
		container_id, 
		kVA_rating,
		weight, 
		dielectric_volume, 
		pcb_ppm, 
		storage_start_date, 
		absorbents_added,
		generator_id
from #results
	order by first_sort, line_id, sequence_id  


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_receipt_pcb_control_sheet] TO [EQAI]
    AS [dbo];

