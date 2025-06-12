--DROP PROCEDURE sp_rpt_labor_util_by_station_id
--GO
CREATE PROCEDURE [dbo].[sp_rpt_labor_util_by_station_id] 
	@company_id				int
,	@profit_ctr_id			int
,	@wo_end_date_from		datetime
,	@wo_end_date_to			datetime
,	@station_id				varchar(20)
,   @resource_assigned		varchar(20)
,	@customer_id_list		varchar(200) = null
,	@reference_code			varchar(32)  null
AS
/*****************************************************************************
Filename:		L:\IT Apps\SQL-Deploy\Prod\NTSQL1\PLT_AI\Procedures\sp_rpt_labor_util_by_station_id
PB Object(s):	r_batch_by_disposal_service, r_batch_by_disposal_service_summary

08/11/2014 JDB	Created
10/4/2018 AM - EQAI-54809 - Added @resource_assigned.
07/23/2020 MPM	DevOps 15813 - Modified so that this report can be run for all companies 
				and/or all profit centers; also added @customer_id_list as an optional 
				input parameter; added customer name and ID to the result set.
05/16/2022 GDE DevOps 39128 Labor Utilization by Station ID Report > Add 'Project #' Column
10/30/2022 gde Reports - Reference Code Usage
04/05/2023 AM - DevOps:62859 - Added employee_ID

SELECT * FROM WorkOrderStop WHERE company_id = 14 AND profit_ctr_id = 15 AND station_id IS NOT NULL
SELECT * FROM WorkOrderStop WHERE company_id = 14 AND profit_ctr_id = 15 AND station_id IS NULL


sp_rpt_labor_util_by_station_id 14, 15, '8/1/14', '8/1/14', '75-03003-000','ALL',NULL, '75-03003-000'
sp_rpt_labor_util_by_station_id 14, 15, '5/1/14', '5/31/14', ''
sp_rpt_labor_util_by_station_id 2, 0, '1/1/13', '1/31/13', NULL
sp_rpt_labor_util_by_station_id 2, 0, '1/1/13', '1/31/13', 'EQWDI'
sp_rpt_labor_util_by_station_id 14, 15, '8/1/14', '8/1/14', '75-03003-000','CEDRIC HA'
sp_rpt_labor_util_by_station_id 14, 15, '8/1/14', '8/1/14', '75-03003-000','ALL'
*****************************************************************************/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

IF @station_id IS NULL
	SET @station_id = ''
	
IF @resource_assigned IS NULL 
    SET @resource_assigned = 'ALL'

IF @resource_assigned = '' 
    SET @resource_assigned = 'ALL'  
   
 IF @customer_id_list IS NULL
	SET @customer_id_list = 'ALL'
	
-- Customer IDs:
create table #customer_ids (customer_id int)
if datalength((@customer_id_list)) > 0 and @customer_id_list <> 'ALL'
begin
    Insert #customer_ids
    select convert(int, row)
    from dbo.fn_SplitXsvText(',', 0, @customer_id_list)
    where isnull(row, '') <> ''
end

SELECT 
	woh.company_id
	, woh.profit_ctr_ID
	, pc.profit_ctr_name
	, ISNULL(NULLIF(wos.station_id, ''), 'N/A') AS station_id
	, woh.workorder_id
	, woh.start_date
	, woh.end_date
	, wod.resource_class_code
	, wod.group_code
	, resource_assigned
	, r.description
	, quantity_used AS quantity
	, wod.bill_unit_code
	, wod.price
	, wod.bill_rate
	, CASE WHEN wod.bill_rate < 1 THEN 0.00
		ELSE CASE WHEN wod.extended_price = 0 THEN ROUND(ISNULL(wod.quantity_used, 0) * ISNULL(wod.price, 0.00), 2) 
			ELSE ROUND(ISNULL(wod.extended_price, 0.00), 2)
			END
		END AS extended_price
	, c.customer_id
	, c.cust_name
	, CONCAT(woh.AX_Dimension_5_Part_1, (Case when  woh.AX_Dimension_5_Part_2 is null OR woh.AX_Dimension_5_Part_2='' then '' else '-' end) , woh.AX_Dimension_5_Part_2) AS D365_project_id
	, woh.reference_code
	, U.employee_ID
FROM WorkOrderHeader woh (NOLOCK)
JOIN WorkOrderDetail wod (NOLOCK) ON woh.company_id = wod.company_id
	AND woh.profit_ctr_id = wod.profit_ctr_id
	AND	woh.workorder_id = wod.workorder_id
	AND wod.resource_type = 'L'
	--AND wod.bill_rate > 0
JOIN ProfitCenter pc (NOLOCK) ON pc.company_ID = woh.company_id
	AND pc.profit_ctr_id = woh.profit_ctr_id
JOIN WorkOrderStop wos (NOLOCK) ON woh.company_id = wos.company_id
	AND woh.profit_ctr_id = wos.profit_ctr_id
	AND	woh.workorder_id = wos.workorder_id
	AND wos.stop_sequence_id = 1
	AND (wos.station_id = @station_id OR @station_id = '')
LEFT OUTER JOIN Resource r (NOLOCK) ON r.company_id = wod.company_id
	AND r.resource_code = wod.resource_assigned
LEFT OUTER JOIN Users u on r.User_id = u.User_id
JOIN Customer c (NOLOCK)
	ON c.customer_id = woh.customer_id
	AND (c.customer_ID in (select customer_id from #customer_ids) OR @customer_id_list = 'ALL')
WHERE woh.workorder_status IN ('C', 'A')
	AND woh.end_date BETWEEN @wo_end_date_from AND @wo_end_date_to
	AND (@company_id = 0 OR woh.company_id = @company_id)
	AND (@profit_Ctr_id = -1 OR woh.profit_ctr_id = @profit_ctr_id)
	AND (@resource_assigned = 'ALL' OR wod.resource_assigned = ISNULL(@resource_assigned,wod.resource_assigned)
	AND (isnull(@reference_code, '') = '' or woh.reference_code = @reference_code )	)
ORDER BY woh.company_id
	, woh.profit_ctr_id
	, ISNULL(NULLIF(wos.station_id, ''), 'N/A')
	, woh.end_date
	, woh.workorder_id
	, resource_assigned
	, wod.resource_class_code
	, wod.group_code
	, wod.bill_unit_code
	, price
	, woh.reference_code
	, u.employee_id
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_labor_util_by_station_id] TO [EQAI] ;
    --AS dbo;
GO