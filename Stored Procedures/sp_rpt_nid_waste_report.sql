DROP PROCEDURE IF EXISTS dbo.sp_rpt_nid_waste_report
GO

CREATE PROCEDURE [dbo].sp_rpt_nid_waste_report (
	@company_id		 int
,	@profit_ctr_id	 int
,	@date_from		datetime
,	@date_to		datetime
,	@class			varchar(3)
)
AS
/*************************************************************************************************
Loads to : PLT_AI  select * from company

06.19.219	JXM  NEW
06.25.2019	JXM	 Remove unnecessary columns, calculate qty received in tons given total gallons
				 and pound conv from billunit table
06.26.2019  JXM	 Finally modifications to report, remove all fields that do not apply, and 
                 of subtotal and total. Recheck report format and confirm with teammates.
07/18/2019	MPM  DevOps 12161 - Rewrote this stored procedure.
03/03/2022	MPM	 DevOps 12175 - Added waste class as an input parameter. Also modified to return only
				 those receipts that have Texas state waste codes.

Purpose:   Display all inbound loads that were received over a period of time with 
		   Texas Class 1 waste codes, Texas Class 2 waste codes, or all waste codes.

PowerBuilder objects using:
	r_nid_waste_report

Testing procedure:
--sp_rpt_nid_waste_report 46, 0, '2019/01/01', '2019/01/31'
--sp_rpt_nid_waste_report 55, 0, '2019/01/24', '2019/06/24'

sp_rpt_nid_waste_report 46, 0, '2021/01/01', '2022/01/31', '1'

-TESTING MUTLIPLES for specific day
--sp_rpt_nid_waste_report 55, 0, '2019/01/02', '2019/08/02'

--select * from billunit where bill_unit_desc like '%Gallon Dru%' order by bill_unit_code
*************************************************************************************************/
select c.company_id
	 , c.company_name
	 , pc.profit_ctr_name
	 , pc.profit_ctr_name
	 , r.approval_code
  	 , wc.display_name
	 , r.manifest
	 , r.receipt_date 
	 , dbo.fn_receipt_weight_line(r.receipt_id, r.line_id, r.profit_ctr_id, r.company_id)/2000.0
	 , @class
from Receipt r
	join ReceiptWasteCode rwc 
		on rwc.company_id = r.company_id 
		and rwc.profit_ctr_id = r.profit_ctr_id 
		and rwc.receipt_id = r.receipt_id 
		and rwc.line_id = r.line_id
	join WasteCode wc 
		on wc.waste_code_uid = rwc.waste_code_uid
		AND wc.waste_code_origin = 'S'
		AND wc.state = 'TX'
	join Company c
		on c.company_id = @company_id
	join ProfitCenter pc
		on pc.company_id = @company_id
		and pc.profit_ctr_id = @profit_ctr_id
where r.company_id = @company_id
and r.profit_ctr_id = @profit_ctr_id
and r.receipt_date between @date_from and @date_to
and r.trans_mode = 'I' 
and r.trans_type = 'D'
and (@class = 'ALL' OR (@class = '1' AND wc.display_name like '%1') OR (@class = '2' AND wc.display_name like '%2'))
and r.receipt_status not in ('V', 'R')
and r.fingerpr_status not in ('V', 'R')
--and r.quantity > 0
order by r.approval_code, r.receipt_date, r.manifest, wc.display_name

GO

GRANT EXECUTE
	ON [dbo].[sp_rpt_nid_waste_report]
	TO [EQAI]
GO
