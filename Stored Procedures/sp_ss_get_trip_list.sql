USE [PLT_AI]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE [dbo].[sp_ss_get_trip_list] 
(
	@compare_date VARCHAR(20) = 'incremental'
)
AS
--
/* 

12/23/2020 rwb Created
07/25/2023 rwb DO 69430 Include trip_status='V' as well, so voided trips get pushed. And stop pushing modified completed stops.
03/18/2024 KS DevOps 76899 - This is a performance updated done by adding a LOOP hint to both of the dbo.WorkOrderDetailUnit 
							 table JOINs in the procedure. 
exec sp_ss_get_trip_list
exec sp_ss_get_trip_list '2023-06-01'

*/

SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

SELECT DISTINCT 
	th.trip_id, 
	th.trip_pass_code, 
	wh.trip_sequence_id
FROM TripHeader th
INNER JOIN WorkOrderHeader wh WITH (INDEX = idx_trip_id)
	ON wh.trip_id = th.trip_id
	AND COALESCE(wh.field_requested_action,'') <> 'D'
	AND wh.workorder_status = 'V'
	AND wh.field_upload_date IS NULL
INNER JOIN TripConnectLogStop tcl
	ON tcl.trip_id = wh.trip_id
	AND tcl.trip_sequence_id = wh.trip_sequence_id
WHERE th.trip_status = 'V'
AND COALESCE(th.technical_equipment_type,'') = 'T'
AND wh.date_modified > tcl.last_download_date
AND th.date_modified > '07/28/2023' -- to avoid sending prior voids

UNION

SELECT DISTINCT 
	th.trip_id, 
	th.trip_pass_code, 
	wh.trip_sequence_id
FROM TripHeader th
INNER JOIN WorkOrderHeader wh WITH (INDEX = idx_trip_id)
	ON wh.trip_id = th.trip_id
	AND COALESCE(wh.field_requested_action,'') <> 'D'
	AND wh.field_upload_date IS NULL
INNER JOIN Customer c
	ON c.customer_id = wh.customer_id
INNER JOIN Generator g
	ON g.generator_id = wh.generator_id
LEFT OUTER JOIN TripConnectLogStop tcl
	ON tcl.trip_id = wh.trip_id
	AND tcl.trip_sequence_id = wh.trip_sequence_id
LEFT OUTER JOIN WorkOrderDetail wd
	ON wd.workorder_id = wh.workorder_id
	AND wd.company_id = wh.company_id
	AND wd.profit_ctr_id = wh.profit_ctr_id
	AND wd.resource_type = 'D'
	AND COALESCE(wd.field_requested_action,'') <> 'D'
LEFT LOOP JOIN WorkOrderDetailUnit wdu WITH (INDEX=WorkOrderDetailUnit_cui)
	ON wdu.workorder_id = wd.workorder_id
	AND wdu.company_id = wd.company_id
	AND wdu.profit_ctr_id = wd.profit_ctr_id
	AND wdu.sequence_id = wd.sequence_id
LEFT OUTER JOIN TripQuestion tq
	ON tq.workorder_id = wh.workorder_id
	AND tq.company_id = wh.company_id
	AND tq.profit_ctr_id = wh.profit_ctr_id
WHERE th.trip_status = 'D'
AND th.field_initial_connect_date IS NOT NULL
AND COALESCE(th.technical_equipment_type,'') = 'T'
AND (
	wh.date_added > CASE 
		WHEN @compare_date = 'incremental'
			THEN COALESCE(tcl.last_download_date,'2020-01-01')
		ELSE @compare_date 
		END OR wh.date_modified > CASE 
		WHEN @compare_date = 'incremental'
			THEN COALESCE(tcl.last_download_date,'2020-01-01')
		ELSE @compare_date 
		END OR c.date_modified > CASE 
		WHEN @compare_date = 'incremental'
			THEN COALESCE(tcl.last_download_date,'2020-01-01')
		ELSE @compare_date 
		END OR g.date_modified > CASE 
		WHEN @compare_date = 'incremental'
			THEN COALESCE(tcl.last_download_date,'2020-01-01')
		ELSE @compare_date
		END OR wd.date_added > CASE 
		WHEN @compare_date = 'incremental'
			THEN COALESCE(tcl.last_download_date,'2020-01-01')
		ELSE @compare_date 
		END OR wd.date_modified > CASE 
		WHEN @compare_date = 'incremental'
			THEN COALESCE(tcl.last_download_date,'2020-01-01')
		ELSE @compare_date 
		END OR wdu.date_added > CASE 
		WHEN @compare_date = 'incremental'
			THEN COALESCE(tcl.last_download_date,'2020-01-01')
		ELSE @compare_date 
		END OR wdu.date_modified > CASE 
		WHEN @compare_date = 'incremental'
			THEN COALESCE(tcl.last_download_date,'2020-01-01')
		ELSE @compare_date 
		END OR tq.date_added > CASE 
		WHEN @compare_date = 'incremental'
			THEN COALESCE(tcl.last_download_date,'2020-01-01')
		ELSE @compare_date 
		END OR tq.date_modified > CASE 
		WHEN @compare_date = 'incremental'
			THEN COALESCE(tcl.last_download_date,'2020-01-01')
		ELSE @compare_date 
		END
	)
	
UNION
SELECT DISTINCT 
	th.trip_id, 
	th.trip_pass_code, 
	0
FROM TripHeader th
INNER JOIN WorkOrderHeader wh WITH (INDEX = idx_trip_id)
	ON wh.trip_id = th.trip_id
	AND wh.workorder_status <> 'V'
	AND COALESCE(wh.field_requested_action,'') <> 'D'
	AND wh.field_upload_date is null
INNER JOIN Customer c
	ON c.customer_id = wh.customer_id
INNER JOIN Generator g
	ON g.generator_id = wh.generator_id
LEFT OUTER JOIN TripConnectLogStop tcl
	ON tcl.trip_id = wh.trip_id
	AND tcl.trip_sequence_id = wh.trip_sequence_id
LEFT OUTER JOIN WorkOrderDetail wd
	ON wd.workorder_id = wh.workorder_id
	AND wd.company_id = wh.company_id
	AND wd.profit_ctr_id = wh.profit_ctr_id
	AND wd.resource_type = 'D'
	AND COALESCE(wd.field_requested_action,'') <> 'D'
LEFT LOOP JOIN WorkOrderDetailUnit wdu with (index=WorkOrderDetailUnit_cui)
	ON wdu.workorder_id = wd.workorder_id
	AND wdu.company_id = wd.company_id
	AND wdu.profit_ctr_id = wd.profit_ctr_id
	AND wdu.sequence_id = wd.sequence_id
LEFT OUTER JOIN TripQuestion tq
	ON tq.workorder_id = wh.workorder_id
	AND tq.company_id = wh.company_id
	AND tq.profit_ctr_id = wh.profit_ctr_id
WHERE th.trip_status = 'D'
AND th.field_initial_connect_date is null
AND COALESCE(th.technical_equipment_type,'') = 'T'
AND (
	wh.date_added > CASE 
		WHEN @compare_date = 'incremental'
			THEN COALESCE(tcl.last_download_date,'2020-01-01')
		ELSE @compare_date 
		END OR wh.date_modified > CASE 
		WHEN @compare_date = 'incremental'
			THEN COALESCE(tcl.last_download_date,'2020-01-01')
		ELSE @compare_date 
		END OR c.date_modified > CASE 
		WHEN @compare_date = 'incremental'
			THEN COALESCE(tcl.last_download_date,'2020-01-01')
		ELSE @compare_date 
		END OR g.date_modified > CASE 
		WHEN @compare_date = 'incremental'
			THEN COALESCE(tcl.last_download_date,'2020-01-01')
		ELSE @compare_date 
		END OR wd.date_added > CASE 
		WHEN @compare_date = 'incremental'
			THEN COALESCE(tcl.last_download_date,'2020-01-01')
		ELSE @compare_date 
		END OR wd.date_modified > CASE 
		WHEN @compare_date = 'incremental'
			THEN COALESCE(tcl.last_download_date,'2020-01-01')
		ELSE @compare_date 
		END OR wdu.date_added > CASE 
		WHEN @compare_date = 'incremental'
			THEN COALESCE(tcl.last_download_date,'2020-01-01')
		ELSE @compare_date 
		END OR wdu.date_modified > CASE 
		WHEN @compare_date = 'incremental'
			THEN COALESCE(tcl.last_download_date,'2020-01-01')
		ELSE @compare_date 
		END OR tq.date_added > CASE 
		WHEN @compare_date = 'incremental'
			THEN COALESCE(tcl.last_download_date,'2020-01-01')
		ELSE @compare_date 
		END OR tq.date_modified > CASE 
		WHEN @compare_date = 'incremental'
			THEN COALESCE(tcl.last_download_date,'2020-01-01')
		ELSE @compare_date 
		END
	)
ORDER BY th.trip_id, 
	wh.trip_sequence_id
GO

GRANT EXECUTE on sp_ss_get_trip_list to EQAI, TRIPSERV
GO
