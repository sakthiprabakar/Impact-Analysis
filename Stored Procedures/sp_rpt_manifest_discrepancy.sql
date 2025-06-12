CREATE PROCEDURE sp_rpt_manifest_discrepancy 
	@company_id		int
,	@profit_ctr_id	int
,	@date_from		datetime
,	@date_to		datetime
,	@cust_id_from	int
,	@cust_id_to		int
AS
/*****************************************************************************************
PB Object(s):	r_manifest_discrepancy

12/14/2010 SK Created new on Plt_AI

sp_rpt_manifest_discrepancy 0, -1, '01-01-2006','01-31-2006', 1, 999999
******************************************************************************************/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

 SELECT 
	WorkOrderDetail.workorder_ID
,	WorkOrderDetail.company_id
,	WorkOrderDetail.profit_ctr_ID
,	WorkOrderDetail.manifest
,	WorkOrderDetail.manifest_line
,	Workordermanifest.discrepancy_desc
,	Workordermanifest.discrepancy_resolution
,	Workordermanifest.discrepancy_resolution_date  
,	Company.company_name
,	ProfitCenter.profit_ctr_name
FROM WorkOrderDetail
JOIN Company
	ON Company.company_id = WorkOrderDetail.company_id
JOIN ProfitCenter
	ON ProfitCenter.company_ID = WorkOrderDetail.company_id
	AND ProfitCenter.profit_ctr_ID = WorkOrderDetail.profit_ctr_id
JOIN WorkOrderHeader
	ON WorkOrderHeader.workorder_ID = WorkOrderDetail.workorder_ID
	AND Workorderheader.profit_ctr_id = WorkOrderDetail.profit_ctr_id
	AND Workorderheader.company_id = WorkOrderDetail.company_id
	AND WorkOrderHeader.workorder_status NOT IN ( 'V', 'T' )
	AND WorkOrderHeader.end_date BETWEEN @date_from AND @date_to
	AND workorderheader.customer_id BETWEEN @cust_id_from AND @cust_id_to
JOIN WorkOrderManifest
	ON WorkOrderManifest.company_id = WorkOrderDetail.company_id
	AND WorkOrderManifest.profit_ctr_ID = WorkOrderDetail.profit_ctr_id
	AND WorkOrderManifest.workorder_ID = WorkOrderDetail.workorder_ID
	AND WorkOrderManifest.manifest = WorkOrderDetail.manifest
	AND WorkOrderManifest.discrepancy_flag = 'T'
WHERE ( @company_id = 0 OR WorkOrderDetail.company_id = @company_id)
	AND ( @company_id = 0 OR @profit_ctr_id = -1 OR WorkOrderDetail.profit_ctr_id = @profit_ctr_id )
	AND WorkOrderDetail.resource_type = 'D' 

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_manifest_discrepancy] TO [EQAI]
    AS [dbo];

