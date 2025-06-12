
CREATE PROCEDURE sp_rpt_batch_reagents_loc_track_summary_report
	@company_id		int
,	@profit_ctr_id 	int
,	@date_from		datetime
,	@date_to		datetime
AS
/***************************************************************************************
r_batch_reag_loc_track_summary_report

05/2/2018 AM	Created

sp_rpt_batch_reagents_loc_track_summary_report 45, 0,  '1/1/2018', '3/1/2018'

****************************************************************************************/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
DECLARE 
	@debug 			int

--Batch Reagents Used - Summary by batch location and tracking number
select b.location as location, 
	   b.tracking_num as tracking_num, 
	   be.reagent_desc as reagent_desc, 
	   sum(be.quantity)as sum_quantity, 
	   be.unit as unit, 
	   bu.pound_conv as pound_conv,
	   (sum(be.quantity) * bu.pound_conv) as sum_total
from batch b
join BatchEvent be
	on b.batch_id = be.batch_id
		and b.company_id = be.company_id
		and b.profit_ctr_id = be.profit_ctr_id
		and b.location = be.location
		and b.tracking_num = be.tracking_num
join BillUnit bu
	on be.unit = bu.bill_unit_code
where 
	be.event_type = 'R'
	and b.company_id = @company_id
	and b.profit_ctr_id = @profit_ctr_id
	and b.date_opened between @date_from AND @date_to
	and b.status <> 'V'
group by b.location, b.tracking_num, be.reagent_desc, be.unit, bu.pound_conv
order by b.location, b.tracking_num, be.reagent_desc


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_batch_reagents_loc_track_summary_report] TO [EQAI]
    AS [dbo];

