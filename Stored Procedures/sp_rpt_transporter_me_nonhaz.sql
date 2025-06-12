DROP PROCEDURE IF EXISTS sp_rpt_transporter_me_nonhaz 
GO

CREATE PROCEDURE sp_rpt_transporter_me_nonhaz 
	@date_from		datetime
,	@date_to		datetime
,	@customer_id_from	int
,	@customer_id_to		int
,	@manifest_from		varchar(15)
,	@manifest_to		varchar(15)
,	@EPA_ID			varchar(15)
,	@work_order_status	char(1)
AS
/***********************************************************************
Non-Hazardous Waste Transporter Report - Maine

Filename:	L:\Apps\SQL\EQAI\sp_rpt_transporter_me_nonhaz.sql
PB Object(s):	r_transporter_me_nonhaz

12/20/2004 JDB	Created
04/07/2005 JDB	Added bill_unit_code for TSDFApproval
04/12/2006 MK	Removed profit_ctr_id = @profit_ctr_id from where clause to 
				pull one report for the whole facility
08/10/2006 RG   revised for tsdfapproval and profile changes
11/12/2006 RG   changed tsdf flag on profile side of union to true
11/12/2007 RG   revised for workorder status.  submitted work orders are now 
                status of A and submitted_flag of T
02/02/2009 JDB	Changed the Profile-Generator join on generator_id to a 
				WorkOrderHeader-Generator join because of the VARIOUS generator.
04/08/2010 RJG	Added join criterias to WorkOrderDetail: 
				1) wod.bill_unit_code = rc.bill_unit_code
				2) wod.profit_ctr_id = rc.profit_ctr_id
04/28/2010 JDB	Fixed join from 4/8/10 on ResourceClass. 
07/16/2010 KAM	Updated the SQL to not include voided workorderdetail rows
11/16/2010 SK	added company_id as input arg for Plt_AI, replaced where clause with joins, 
				runs only for a valid company
02/08/2011 SK	Changed to run for all companies(removed companyid/pc as input args)
				Result set changed to not return company/profit center name
				Changed to run by user selected EPA ID & not transporter code
				Replaced use of ResourceClass Category with resourceclass code.
04/26/2011 RJG	Added (missing) WorkOrderTransporter joins where appropriate
04/26/2011 RJG	Added ISOLATION LEVEL statement at the top
05/01/2017 MPM	Added "Work Order Status" as a retrieval argument.  Work Order Status will be either C (Completed, Accepted or Submitted)
				or S (Submitted Only).
09/27/2023 MPM	DevOps 72790 - Removed join to ResourceClass table in the first part of the UNION to improve performance.
				
sp_rpt_transporter_me_nonhaz '1/1/2017', '4/30/2017', 1, 999999, '0', 'zzz', 'MAD084814136', 'C'
***********************************************************************/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

SELECT DISTINCT
	t.Transporter_name,
	t.Transporter_addr1,
	t.Transporter_addr2,
	t.Transporter_city,
	t.Transporter_state,
	t.Transporter_zip_code,
	ta.waste_desc,
	SUM(wod.quantity_used) AS quantity_used,
	wod.bill_unit_code,
	b.pound_conv,
	SUM(wod.quantity_used * b.pound_conv) AS total_pounds
FROM WorkorderManifest wom
INNER JOIN WorkOrderDetail wod
	ON wod.workorder_ID = wom.workorder_ID
	AND wod.profit_ctr_ID = wom.profit_ctr_ID
	AND wod.company_id = wom.company_id
	AND wod.manifest = wom.manifest
	AND wod.resource_type = 'D'
	AND wod.bill_rate >= -1
INNER JOIN WorkorderHeader woh
	ON woh.workorder_ID = wod.workorder_ID
	AND woh.profit_ctr_ID = wod.profit_ctr_ID
	AND woh.company_id = wod.company_id
	AND (woh.workorder_status in ('A','C') OR woh.submitted_flag = 'T')
	AND (woh.submitted_flag = 'T' OR @work_order_status = 'C')
	AND woh.customer_id BETWEEN @customer_id_from AND @customer_id_to
	AND woh.start_date BETWEEN @date_from AND @date_to
INNER JOIN TSDFApproval ta
	ON ta.TSDF_approval_id = wod.TSDF_approval_id
	AND ta.profit_ctr_ID = wod.profit_ctr_ID
	AND ta.company_id = wod.company_id
	AND ta.TSDF_approval_status = 'A'
INNER JOIN TSDFApprovalPrice tap
	ON tap.TSDF_approval_id = ta.TSDF_approval_id
	AND tap.profit_ctr_ID = ta.profit_ctr_ID
	AND tap.company_id = ta.company_id
	AND tap.record_type = 'R'
	AND tap.resource_class_code = 'FEEMECAT'
INNER JOIN Billunit b
	ON b.bill_unit_code = tap.bill_unit_code
INNER JOIN Transporter t
	--ON t.transporter_code =  wom.transporter_code_1
	ON t.transporter_EPA_ID = @EPA_ID
	AND t.eq_flag = 'T'
INNER JOIN WorkOrderTransporter wot1
	ON wot1.company_id = wom.company_id
	AND wot1.profit_ctr_id = wom.profit_ctr_ID
	AND wot1.workorder_id = wom.workorder_ID
	AND wot1.manifest = wom.manifest
	AND wot1.transporter_code = t.transporter_code
	AND wot1.transporter_sequence_id = 1
INNER JOIN Generator g
	ON g.generator_id = ta.generator_id
INNER JOIN TSDF
	ON TSDF.TSDF_code = wod.TSDF_code
	AND ISNULL(TSDF.eq_flag,'F') = 'F'
WHERE (g.generator_state = 'ME' OR TSDF.TSDF_state = 'ME')
	--AND wom.transporter_code_1 = 'EQNE'
	AND wom.manifest BETWEEN @manifest_from AND @manifest_to
GROUP BY waste_desc,
	wod.bill_unit_code,
	b.pound_conv,
	t.Transporter_name,
	t.Transporter_addr1,
	t.Transporter_addr2,
	t.Transporter_city,
	t.Transporter_state,
	t.Transporter_zip_code
	
UNION

SELECT DISTINCT
	t.Transporter_name,
	t.Transporter_addr1,
	t.Transporter_addr2,
	t.Transporter_city,
	t.Transporter_state,
	t.Transporter_zip_code,
	p.approval_desc,
	SUM(wod.quantity_used) AS quantity_used,
	wod.bill_unit_code,
	b.pound_conv,
	SUM(wod.quantity_used * b.pound_conv) AS total_pounds
FROM WorkOrderManifest wom
INNER JOIN WorkOrderDetail wod 
	ON wod.workorder_ID = wom.workorder_ID
	AND wod.profit_ctr_ID = wom.profit_ctr_ID
	AND wod.company_id = wom.company_id
	AND wod.manifest = wom.manifest
	AND wod.resource_type = 'D'
	AND wod.bill_rate >= -1
INNER JOIN WorkOrderHeader woh 
	ON wod.workorder_ID = woh.workorder_ID
	AND wod.profit_ctr_ID = woh.profit_ctr_ID
	AND woh.company_id = wod.company_id
	AND (woh.workorder_status in ('A','C') OR woh.submitted_flag = 'T')
	AND (woh.submitted_flag = 'T' OR @work_order_status = 'C')
	AND woh.customer_id BETWEEN @customer_id_from AND @customer_id_to
	AND woh.start_date BETWEEN @date_from AND @date_to
INNER JOIN ProfileQuoteDetail pqd 
	ON wod.profile_company_id = pqd.company_id
	AND wod.profile_profit_ctr_id = pqd.profit_ctr_id
	AND wod.profile_id = pqd.profile_id
	AND pqd.record_type = 'R'
INNER JOIN Profile p 
	ON pqd.profile_id = p.profile_id
	AND p.curr_status_code = 'A'
INNER JOIN ResourceClass rc 
	ON pqd.resource_class_code = rc.resource_class_code
	AND pqd.bill_unit_code = rc.bill_unit_code
	--AND rc.company_id = pqd.company_id
	--AND rc.profit_ctr_id = pqd.profit_ctr_id
	--AND rc.category = 'REPORTMENH'
	AND rc.resource_class_code = 'FEEMECAT'
INNER JOIN BillUnit b 
	ON pqd.bill_unit_code = b.bill_unit_code
INNER JOIN Transporter t 
	--ON wom.transporter_code_1 = t.transporter_code
	ON t.transporter_EPA_ID = @EPA_ID
	AND t.eq_flag = 'T'
INNER JOIN WorkOrderTransporter wot1
	ON wot1.company_id = wom.company_id
	AND wot1.profit_ctr_id = wom.profit_ctr_ID
	AND wot1.workorder_id = wom.workorder_ID
	AND wot1.manifest = wom.manifest
	AND wot1.transporter_code = t.transporter_code
	AND wot1.transporter_sequence_id = 1		
INNER JOIN Generator g 
	ON woh.generator_id = g.generator_id
INNER JOIN TSDF 
	ON TSDF.TSDF_code = wod.TSDF_code
	AND ISNULL(TSDF.eq_flag,'F') = 'T'
WHERE (g.generator_state = 'ME' OR TSDF.TSDF_state = 'ME')
	--AND wom.transporter_code_1 = 'EQNE'
	AND wom.manifest BETWEEN @manifest_from AND @manifest_to
GROUP BY approval_desc,
	wod.bill_unit_code,
	b.pound_conv,
	t.Transporter_name,
	t.Transporter_addr1,
	t.Transporter_addr2,
	t.Transporter_city,
	t.Transporter_state,
	t.Transporter_zip_code
ORDER BY ta.waste_desc

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_transporter_me_nonhaz] TO [EQAI];
GO

