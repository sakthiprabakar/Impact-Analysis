
CREATE PROCEDURE sp_rpt_stock_container
	@company_id		int
,	@profit_ctr_id 	int
,	@date_from 		datetime
,	@date_to 		datetime
,	@location		varchar(15)
,	@staging_row	varchar(5)
,	@base_container	int
AS
/***************************************************************************************
02/20/2004 SCC	Created
12/13/2004 MK	Modified ticket_id, drum references, DrumHeader, and DrumDetail
01/26/2005 SCC	Modified for Container Tracking
10/28/2010 SK	added Company_id as input arg, added joins to company_id
				Moved to Plt_AI

sp_rpt_stock_container 14, 4, '2010-06-01', '2010-06-30', 'ALL', 'ALL', -99999

****************************************************************************************/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED


DECLARE	@stock_container_count	int

SELECT DISTINCT 
	dbo.fn_container_stock(ContainerDestination.line_id, ContainerDestination.company_id, ContainerDestination.profit_ctr_id) AS base_container
,	Container.date_added AS date_created
,	ContainerDestination.status AS base_status
,	ContainerDestination.company_id
,	ContainerDestination.profit_ctr_id
INTO #stock_container
FROM ContainerDestination
JOIN Container
	ON Container.receipt_id = ContainerDestination.receipt_id
	AND Container.line_id = ContainerDestination.line_id
	AND Container.company_id = ContainerDestination.company_id
	AND Container.profit_ctr_id = ContainerDestination.profit_ctr_id
	AND Container.container_type = ContainerDestination.container_type
	AND Container.date_added BETWEEN @date_from and @date_to
	AND (@staging_row = 'ALL' OR Container.staging_row = @staging_row)
WHERE	( @company_id = 0 OR ContainerDestination.company_id = @company_id )
	AND ( @company_id = 0 OR @profit_ctr_id = -1 OR ContainerDestination.profit_ctr_id = @profit_ctr_id )
	AND (@location = 'ALL' OR ContainerDestination.location = @location)
	AND (@base_container = -99999 OR ContainerDestination.container_id = @base_container)
	AND ContainerDestination.container_type = 'S'

SELECT @stock_container_count = COUNT(*) FROM #stock_container

-- Retrieve the list of containers that were poured into these base containers
SELECT DISTINCT
	#stock_container.base_container
,	#stock_container.date_created
,	CASE WHEN container_type = 'R' THEN CONVERT(varchar(15),DC.receipt_id) + '-' + CONVERT(varchar(5),DC.line_id) 
		 ELSE dbo.fn_container_stock(DC.line_id, DC.company_id, DC.profit_ctr_id)
	END AS source_container
,	DC.container_id AS source_container_id
,	@stock_container_count AS stock_container_count
,	#stock_container.base_status
,	#stock_container.company_id
,	#stock_container.profit_ctr_id
,	Company.company_name
,	ProfitCenter.profit_ctr_name
FROM #stock_container
JOIN Company
	ON Company.company_id = #stock_container.company_id
JOIN ProfitCenter
	ON ProfitCenter.company_id = #stock_container.company_id
	AND ProfitCenter.profit_ctr_id = #stock_container.profit_ctr_id
LEFT OUTER JOIN ContainerDestination DC
	ON DC.company_id = #stock_container.company_id
	AND DC.profit_ctr_id = #stock_container.profit_ctr_id
	AND DC.base_tracking_num = #stock_container.base_container
ORDER BY 
	#stock_container.base_container
,	#stock_container.date_created
,	source_container
,	DC.container_id

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_stock_container] TO [EQAI]
    AS [dbo];

