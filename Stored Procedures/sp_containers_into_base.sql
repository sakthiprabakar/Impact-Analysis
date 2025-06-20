USE [PLT_AI]
GO
/****** Object:  StoredProcedure [dbo].[sp_containers_into_base]    Script Date: 1/7/2025 3:48:34 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[sp_containers_into_base] 
 @company_id   int,
 @profit_ctr_id  int,
 @receipt_id   int,
 @line_id   int,
 @container_id  int, 
 @sequence_id  int, 
 @debug    int
AS
/*************************************************************************************
This SP returns a list of containers that were consolidated into the specified base container.

01/20/2004 SCC Created
11/16/2004 SCC Changed for Container Tracking.
09/22/2005 SCC Modified to use the no-drill-down method for identifying base containers
05/15/2009 KAM Update the procedure to not use the Containerwastecode table to find the containers
12/21/2009 JDB Removed ContainerWasteCode table to find the containers (really)
03/17/2010 JDB Changed to use the fn_container_source function.
06/10/2014 AM   Moved to Plt_AI and changed arguments to fn_container_stock 
01/19/2016 RWB Modified destination_container to reference receipt_id instead of destination_receipt_id
01/25/2022 AM DevOps:21400 - Added ob_profile_id and launch_profile columns.
03/12/2024 KA   US133692 -Added left join query to get profile_id and approval_code column from receipt table
				and commented sub query
02/14/2024	RK	US142149 - Modified the left outer join query back to a sub-query and added a similar sub-query
				for Approval Code
select * from dbo.fn_container_source(21, 0, 0, 6600, 6600, 1, 0)
select * from dbo.fn_container_source(21, 0, 655298, 2, 1, 1, 1)

sp_containers_into_base 21, 0, 0, 6600, 6600, 1, 0

***************************************************************************************/
SELECT DISTINCT
 CASE WHEN containers.container_type = 'S' THEN dbo.fn_container_stock(containers.line_id, containers.company_id, containers.profit_ctr_id)
   ELSE dbo.fn_container_receipt(containers.receipt_id, containers.line_id)
   END AS source_container,
 containers.container_type,
 containers.company_id AS company_id,
 containers.profit_ctr_id AS profit_ctr_id,
 containers.receipt_id AS receipt_id,
 containers.line_id AS line_id,
 containers.container_id AS container_id,
 containers.sequence_id AS sequence_id,
 ISNULL(cd.container_percent, 100) AS container_percent,
  CASE WHEN containers.receipt_id = 0 THEN dbo.fn_container_stock(containers.line_id, containers.company_id, containers.profit_ctr_id)
   ELSE dbo.fn_container_receipt(containers.receipt_id, containers.line_id)
   END AS destination_container,
 containers.destination_company_id,
 containers.destination_profit_ctr_id,
 containers.destination_receipt_id,
 containers.destination_line_id,
 containers.destination_container_id,
 containers.destination_sequence_id,
 containers.disposal_date,
 cd.ob_profile_id,
 '' as launch_profile,
 (SELECT distinct receipt.profile_id from receipt where receipt.company_id = @company_id 
  AND receipt.profit_ctr_id = @profit_ctr_id 
  AND receipt.receipt_id = containers.receipt_id and receipt.line_id = containers.line_id
  AND receipt.trans_mode = 'I' and receipt.trans_type = 'D') as profile_id,
  (SELECT distinct receipt.approval_code from receipt where receipt.company_id = @company_id 
  AND receipt.profit_ctr_id = @profit_ctr_id 
  AND receipt.receipt_id = containers.receipt_id and receipt.line_id = containers.line_id
  AND receipt.trans_mode = 'I' and receipt.trans_type = 'D') as approval_code
FROM dbo.fn_container_source(@company_id, @profit_ctr_id, @receipt_id, @line_id, @container_id, @sequence_id, 0) containers
INNER JOIN ContainerDestination cd ON containers.company_id = cd.company_id
 AND containers.profit_ctr_id = cd.profit_ctr_id
 AND containers.receipt_id = cd.receipt_id
 AND containers.line_id = cd.line_id
 AND containers.container_id = cd.container_id
 AND containers.sequence_id = cd.sequence_id
ORDER BY containers.disposal_date, source_container, containers.container_id, containers.sequence_id

GO

GRANT EXECUTE
    ON OBJECT::[dbo].[sp_containers_into_base] TO [EQAI]
    AS [dbo];