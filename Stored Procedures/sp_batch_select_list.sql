
CREATE PROCEDURE sp_batch_select_list
	@company_id		int
,	@profit_ctr_id	int
AS
/***********************************************************************************************
This SP returns the list of batch IDs, locations, and date ranges per criteria

PB Object :     r_batch_select
05/23/2005 MK	Created
10/19/2010 SK	Added input argument company_id, 
				Moved to Plt_AI

sp_batch_select_list 14, 04
***********************************************************************************************/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED


SELECT DISTINCT
	Batch.location
,	Batch.tracking_num
,	MIN(disposal_date) AS min_date
,	MAX(disposal_date) AS max_date 
,	ProfitCenter.profit_ctr_name AS profit_center
INTO #batch_list
FROM Batch
JOIN ProfitCenter
	ON ProfitCenter.company_ID = Batch.company_id
	AND ProfitCenter.profit_ctr_ID = Batch.profit_ctr_id
LEFT OUTER JOIN ContainerDestination
	ON ContainerDestination.company_id = Batch.company_id
	AND ContainerDestination.profit_ctr_id = Batch.profit_ctr_id
	AND ContainerDestination.location = Batch.location
	AND ContainerDestination.tracking_num = Batch.tracking_num
	AND ContainerDestination.location_type = 'P'
WHERE Batch.company_id = @company_id
	AND Batch.profit_ctr_id = @profit_ctr_id
	AND Batch.location IS NOT NULL
	AND Batch.tracking_num IS NOT NULL
GROUP BY Batch.location, Batch.tracking_num, ProfitCenter.profit_ctr_name

-- Return results
SELECT DISTINCT
	location
,	tracking_num
,	MIN(min_date) AS date_from
,	MAX(max_date) AS date_to
,	profit_center
FROM #batch_list
GROUP BY location, tracking_num, profit_center
ORDER BY location, tracking_num, profit_center

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_batch_select_list] TO [EQAI]
    AS [dbo];

