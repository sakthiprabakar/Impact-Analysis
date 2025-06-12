DROP PROCEDURE IF EXISTS sp_get_bol_transporters 
GO

CREATE PROCEDURE sp_get_bol_transporters 
	@source				varchar(20),
	@source_id			int,
	@company_id			int,
	@profit_ctr_id		int,
	@manifest			varchar(15),
	@trip_sequence_id	int
AS
/***********************************************************************************
PB Object(s):	d_bol_transporter_signature

08/07/2018 MPM	Created on Plt_AI
03/02/2022 MPM	DevOps 30109 - Modified so that transporter info displays even when
				quantities are null.

exec sp_get_bol_transporters 'WORKORDER', 1985500, 21, 0, '321654654JJK', null
exec sp_get_bol_transporters 'WORKORDER', 1985500, 21, 0, '030021323JJK', null
exec sp_get_bol_transporters 'WORKORDER', 21973400, 14, 6, '015845911JJK', null

***********************************************************************************/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

DECLARE @row_count	int

create table #results (
	transporter_name		varchar(40)		NULL,
	transporter_EPA_ID		varchar(15)		NULL,
	transporter_sequence_id	int				NULL,
	transporter_sign_name	varchar(40)		NULL,
	transporter_sign_date	datetime		NULL,
	first_sort				int				NULL
)

insert into #results
select	
		t.transporter_name,
		t.transporter_EPA_ID,
		wot.transporter_sequence_id,
		wot.transporter_sign_name,
		wot.transporter_sign_date,
		1
from WorkorderHeader woh
inner join WorkOrderDetail wod
	on woh.workorder_ID = wod.workorder_ID
	and woh.company_id = wod.company_id
	and woh.profit_ctr_ID = wod.profit_ctr_ID
	and wod.resource_type = 'D'
inner join Profile p
	on wod.profile_id = p.profile_id
inner join ProfileQuoteApproval pqa
	on wod.profile_id = pqa.profile_id
	and wod.profile_company_id = pqa.company_id
	and wod.profile_profit_ctr_id = pqa.profit_ctr_id
left outer join WorkOrderDetailUnit wodu
	on wod.workorder_ID = wodu.workorder_ID  
	and wod.company_ID = wodu.company_ID  
	and wod.profit_ctr_ID = wodu.profit_ctr_ID
	and wod.sequence_ID = wodu.sequence_ID
	and isnull(wodu.manifest_flag,'F') = 'T'
left outer join WorkOrderTransporter wot
	on wot.company_ID = woh.company_ID
	and wot.profit_ctr_ID = woh.profit_ctr_ID
	and wot.workorder_ID = woh.workorder_ID
	and wot.manifest = wod.manifest
left outer join Transporter t
	on t.transporter_code = wot.transporter_code
where 'WORKORDER' = @source
and woh.workorder_id = @source_id
and woh.company_id = @company_id
and woh.profit_ctr_id = @profit_ctr_id
and wod.manifest = @manifest
--and isnull(COALESCE(case when wodu.quantity = 0 then null else wodu.quantity end,wod.quantity_used),0) > 0
union
select	
		t.transporter_name,
		t.transporter_EPA_ID,
		wot.transporter_sequence_id,
		wot.transporter_sign_name,
		wot.transporter_sign_date,
		1
from WorkorderHeader woh
inner join WorkOrderDetail wod
	on woh.workorder_ID = wod.workorder_ID
	and woh.company_id = wod.company_id
	and woh.profit_ctr_ID = wod.profit_ctr_ID
	and wod.resource_type = 'D'
inner join TSDFApproval ta
	on wod.TSDF_approval_id = ta.TSDF_approval_id
	and wod.profit_ctr_ID = ta.profit_ctr_ID
	and wod.company_id = ta.company_id
left outer join WorkOrderDetailUnit wodu
	on wod.workorder_ID = wodu.workorder_ID 
	and wod.company_ID = wodu.company_ID  
	and wod.profit_ctr_ID = wodu.profit_ctr_ID
	and wod.sequence_ID = wodu.sequence_ID
	and isnull(wodu.manifest_flag,'F') = 'T'
left outer join WorkOrderTransporter wot
	on wot.company_ID = woh.company_ID
	and wot.profit_ctr_ID = woh.profit_ctr_ID
	and wot.workorder_ID = woh.workorder_ID
	and wot.manifest = wod.manifest
left outer join Transporter t
	on t.transporter_code = wot.transporter_code
where 'WORKORDER' = @source
and woh.workorder_id = @source_id
and woh.company_id = @company_id
and woh.profit_ctr_id = @profit_ctr_id
and wod.manifest = @manifest
--and isnull(COALESCE(case when wodu.quantity = 0 then null else wodu.quantity end,wod.quantity_used),0) > 0
union
select	
		t.transporter_name,
		t.transporter_EPA_ID,
		wot.transporter_sequence_id,
		wot.transporter_sign_name,
		wot.transporter_sign_date,
		1
from WorkorderHeader woh
inner join WorkOrderDetail wod
	on woh.workorder_ID = wod.workorder_ID
	and woh.company_id = wod.company_id
	and woh.profit_ctr_ID = wod.profit_ctr_ID
	and wod.resource_type = 'D'
inner join Profile p
	on wod.profile_id = p.profile_id
inner join ProfileQuoteApproval pqa
	on wod.profile_id = pqa.profile_id
	and wod.profile_company_id = pqa.company_id
	and wod.profile_profit_ctr_id = pqa.profit_ctr_id
left outer join WorkOrderDetailUnit wodu
	on wod.workorder_ID = wodu.workorder_ID  
	and wod.company_ID = wodu.company_ID  
	and wod.profit_ctr_ID = wodu.profit_ctr_ID
	and wod.sequence_ID = wodu.sequence_ID
	and isnull(wodu.manifest_flag,'F') = 'T'
left outer join WorkOrderTransporter wot
	on wot.company_ID = woh.company_ID
	and wot.profit_ctr_ID = woh.profit_ctr_ID
	and wot.workorder_ID = woh.workorder_ID
	and wot.manifest = wod.manifest
left outer join Transporter t
	on t.transporter_code = wot.transporter_code
where 'TRIP' = @source
and woh.trip_id = @source_id
and woh.trip_sequence_id = @trip_sequence_id
and woh.company_id = @company_id
and woh.profit_ctr_id = @profit_ctr_id
and wod.manifest = @manifest
--and isnull(COALESCE(case when wodu.quantity = 0 then null else wodu.quantity end,wod.quantity_used),0) > 0
union
select	
		t.transporter_name,
		t.transporter_EPA_ID,
		wot.transporter_sequence_id,
		wot.transporter_sign_name,
		wot.transporter_sign_date,
		1
from WorkorderHeader woh
inner join WorkOrderDetail wod
	on woh.workorder_ID = wod.workorder_ID
	and woh.company_id = wod.company_id
	and woh.profit_ctr_ID = wod.profit_ctr_ID
	and wod.resource_type = 'D'
inner join TSDFApproval ta
	on wod.TSDF_approval_id = ta.TSDF_approval_id
	and wod.profit_ctr_ID = ta.profit_ctr_ID
	and wod.company_id = ta.company_id
left outer join WorkOrderDetailUnit wodu
	on wod.workorder_ID = wodu.workorder_ID 
	and wod.company_ID = wodu.company_ID  
	and wod.profit_ctr_ID = wodu.profit_ctr_ID
	and wod.sequence_ID = wodu.sequence_ID
	and isnull(wodu.manifest_flag,'F') = 'T'
left outer join WorkOrderTransporter wot
	on wot.company_ID = woh.company_ID
	and wot.profit_ctr_ID = woh.profit_ctr_ID
	and wot.workorder_ID = woh.workorder_ID
	and wot.manifest = wod.manifest
left outer join Transporter t
	on t.transporter_code = wot.transporter_code
where 'TRIP' = @source
and woh.trip_id = @source_id
and woh.trip_sequence_id = @trip_sequence_id
and woh.company_id = @company_id
and woh.profit_ctr_id = @profit_ctr_id
and wod.manifest = @manifest
--and isnull(COALESCE(case when wodu.quantity = 0 then null else wodu.quantity end,wod.quantity_used),0) > 0
union
select  
		rt.transporter_name,
		rt.transporter_EPA_ID,
		rt.transporter_sequence_id,
		rt.transporter_sign_name,
		rt.transporter_sign_date,
		1
from Receipt r
inner join ProfileQuoteApproval pqa
      on r.OB_profile_id = pqa.profile_id
      and r.OB_profile_company_id = pqa.company_id
      and r.OB_profile_profit_ctr_id = pqa.profit_ctr_id
inner join Profile p
      on pqa.profile_id = p.profile_id
left outer join ReceiptTransporter rt
	on rt.company_ID = r.company_ID
	and rt.profit_ctr_ID = r.profit_ctr_ID
	and rt.receipt_id = r.receipt_id
where 'ORECEIPT' = @source
and r.receipt_id =  @source_id
and r.company_id = @company_id
and r.profit_ctr_id = @profit_ctr_id
and r.manifest = @manifest
--and isnull(r.quantity,0) > 0
and r.trans_type = 'D'
and r.trans_mode = 'O'
and r.manifest_flag = 'B'
union
select  
		rt.transporter_name,
		rt.transporter_EPA_ID,
		rt.transporter_sequence_id,
		rt.transporter_sign_name,
		rt.transporter_sign_date,
		1
from Receipt r
inner join TSDFApproval ta
      on r.TSDF_approval_id = ta.TSDF_approval_id
      and r.profit_ctr_ID = ta.profit_ctr_ID
      and r.company_id = ta.company_id
left outer join ReceiptTransporter rt
	on rt.company_ID = r.company_ID
	and rt.profit_ctr_ID = r.profit_ctr_ID
	and rt.receipt_id = r.receipt_id
where 'ORECEIPT' = @source
and r.receipt_id =  @source_id
and r.company_id = @company_id
and r.profit_ctr_id = @profit_ctr_id
and r.manifest = @manifest
--and isnull(r.quantity,0) > 0
and r.trans_type = 'D'
and r.trans_mode = 'O'
and r.manifest_flag = 'B'

-- Get the row count.  If there are less than 2 rows, insert enough "blank" rows to make a total of 2 rows.

select @row_count = COUNT(*) from #results

if @row_count = 0
begin
	insert into #results
	select null, null, null, null, null, 2
	
	insert into #results
	select null, null, null, null, null, 2
end
else if @row_count = 1
begin
	insert into #results
	select null, null, null, null, null, 2
end

-- Return results
select	transporter_name,
	transporter_EPA_ID,
	transporter_sequence_id,
	transporter_sign_name,
	transporter_sign_date	
from #results
order by first_sort, transporter_sequence_id  


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_get_bol_transporters] TO [EQAI]
    AS [dbo];

