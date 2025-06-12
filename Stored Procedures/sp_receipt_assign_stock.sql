DROP PROCEDURE IF EXISTS sp_receipt_assign_stock 
GO

CREATE PROCEDURE sp_receipt_assign_stock 
	@outbound_receipt_id	int 
,	@outbound_line_id		int 
,	@company_id				int
,	@profit_ctr_id			int
,	@location				varchar(15) 
,	@staging_row			varchar(5)
AS
/****************************************************************************************************************
12/27/2004 SCC	Changed for Container Tracking
09/27/2005 SCC	Changed to send preassigned TSDF Approval code
05/07/2012 RWB	Set transaction isolation level to eliminate blocking issues, remove temp table
09/24/2012 JDB	Moved SP from Plt_XX_AI to Plt_AI in order to try to speed it up by not needing views.
				Added @company_id as a parameter.
				Removed the "container" computed field, and added company_id and profit_ctr_id to Select list.
12/13/2013 RWB	Added status = 'N' to where clauses (completed and voided containers should not be retrieved)
12/12/2018 MPM	GEM 57546 - Added trip_id to result set.
12/01/2021	MPM	DevOps 22014 - Modified to return containers with null or blank location_type.
02/21/2022	MPM DevOps 29881 - Added Container.manifest_container and Container.container_size to the result set.

sp_receipt_assign_stock 32160, 1, 0, 'ALL', 'ALL'
sp_helptext fn_container_stock
****************************************************************************************************************/					

SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

-- Include Stock Containers that match this outbound Receipt Line
SELECT DISTINCT 
0 AS include,
--dbo.fn_container_stock(ContainerDestination.line_id, ContainerDestination.company_id, ContainerDestination.profit_ctr_id) AS Container,
ContainerDestination.container_percent,
ContainerDestination.company_id, 
ContainerDestination.profit_ctr_id,
ContainerDestination.receipt_id, 
ContainerDestination.line_id,
ContainerDestination.container_id,
ContainerDestination.sequence_id,
ContainerDestination.container_type,
ContainerDestination.status,
ContainerDestination.Location, 
Container.staging_row, 
ContainerDestination.TSDF_approval_code AS approval_code,
CONVERT(varchar(15),'') AS manifest,
CONVERT(varchar(60),'') AS generator,
'F' AS bulk_flag,
Container.date_added as receipt_date,
ContainerDestination.waste_stream,
Container.trip_id,
Container.manifest_container,
Container.container_size
FROM ContainerDestination
JOIN Container ON ContainerDestination.company_id = Container.company_id
	AND ContainerDestination.profit_ctr_id = Container.profit_ctr_id
	AND ContainerDestination.receipt_id = Container.receipt_id
	AND ContainerDestination.line_id = Container.line_id
	AND ContainerDestination.container_type = Container.container_type
	AND Container.status = 'N'
WHERE 1=1
AND ContainerDestination.company_id = @company_id
AND ContainerDestination.profit_ctr_id = @profit_ctr_id
AND ContainerDestination.container_type = 'S'
AND ISNULL(ContainerDestination.location_type, '') IN ('O','U', '')
AND ContainerDestination.tracking_num = dbo.fn_container_receipt(@outbound_receipt_id, @outbound_line_id)
AND (@location = 'ALL' OR (ContainerDestination.location IS NOT NULL AND ContainerDestination.location = @location))
AND (@staging_row = 'ALL' OR (Container.staging_row IS NOT NULL AND Container.staging_row = @staging_row))
AND ContainerDestination.status = 'N'

UNION ALL

-- Include Stock Containers without a tracking number
SELECT DISTINCT 
0 AS include,
--dbo.fn_container_stock(ContainerDestination.line_id, ContainerDestination.company_id, ContainerDestination.profit_ctr_id) AS Container,
ContainerDestination.container_percent,
ContainerDestination.company_id, 
ContainerDestination.profit_ctr_id,
ContainerDestination.receipt_id, 
ContainerDestination.line_id,
ContainerDestination.container_id,
ContainerDestination.sequence_id,
ContainerDestination.container_type,
ContainerDestination.status,
ContainerDestination.Location, 
Container.staging_row, 
ContainerDestination.TSDF_approval_code AS approval_code,
CONVERT(varchar(15),'') AS manifest,
CONVERT(varchar(60),'') AS generator,
'F' AS bulk_flag,
Container.date_added AS receipt_date,
ContainerDestination.waste_stream,
Container.trip_id,
Container.manifest_container,
Container.container_size
FROM ContainerDestination
JOIN Container ON ContainerDestination.company_id = Container.company_id
	AND ContainerDestination.profit_ctr_id = Container.profit_ctr_id
	AND ContainerDestination.receipt_id = Container.receipt_id
	AND ContainerDestination.line_id = Container.line_id
	AND ContainerDestination.container_type = Container.container_type
	AND Container.status = 'N'
WHERE 1=1
AND ContainerDestination.company_id = @company_id
AND ContainerDestination.profit_ctr_id = @profit_ctr_id
AND ContainerDestination.container_type = 'S'
AND ISNULL(ContainerDestination.location_type, '') IN ('O','U', '')
AND ISNULL(ContainerDestination.tracking_num,'') = '' 
AND (@location = 'ALL' OR (ContainerDestination.location IS NOT NULL AND ContainerDestination.location = @location))
AND (@staging_row = 'ALL' OR (Container.staging_row IS NOT NULL AND Container.staging_row = @staging_row))
AND ContainerDestination.status = 'N'

ORDER BY ContainerDestination.company_id, ContainerDestination.profit_ctr_id, ContainerDestination.line_id
GO

GRANT EXECUTE
    ON OBJECT::[dbo].[sp_receipt_assign_stock] TO [EQAI]
    AS [dbo];
GO

