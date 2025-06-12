CREATE PROCEDURE sp_batch_throughput
	@company_id			int
,	@profit_ctr_id		int
,	@date_from			datetime
,	@date_to			datetime
,	@location			varchar(15)
AS
/************************************************************************************************************  
 This SP shows the detail for the specified batch.
 
 PB object : r_batch_throughput
 
 Loaded to Plt_AI

 11/17/2017 JCG	Copied sp_batch_detail then made changes

************************************************************************************************************/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

DECLARE	
	@batch_location  	varchar(15)
,	@batch_trackingnum	varchar(15)
,	@batch_cycle		int
,	@batch_id			int
,	@processcount		int
,	@record_ID			int
,	@debug				int

DECLARE @batch_loc_trackingnum TABLE(
	batchID				int			NULL
,	location			varchar(15)	NULL
,	tracking_num		varchar(15)	NULL
,	cycle				int			NULL
,	process_flag		tinyint		NULL
,	record_id			int			identity
)

-- set debug mode here, don't forget to reset afterwards..
SET @debug = 0

-- Get distinct location, trackingnum
INSERT INTO @batch_loc_trackingnum
SELECT DISTINCT
	Batch.batch_id
,	Batch.location
,	Batch.tracking_num
,	MAX(Batch.cycle) as cycle
,	0 AS process_flag
FROM Batch
WHERE	(Batch.company_id = @company_id)	
	AND (Batch.profit_ctr_id = @profit_ctr_id)
	AND (@location = 'ALL' OR Batch.location = @location)
	AND (Batch.date_opened BETWEEN @date_from AND @date_to)
GROUP BY Batch.batch_id, Batch.location, Batch.tracking_num 
SET @processcount = @@ROWCOUNT

IF @debug = 1
BEGIN
	PRINT 'Select * from @batch_loc_trackingnum'
	Select * from @batch_loc_trackingnum
END 

-- Recalculate Batch Waste Codes and Constituents for all location and tracking nums
IF @processcount > 0
	BEGIN
		SELECT @record_ID = IsNull(MIN(record_id), 0) FROM @batch_loc_trackingnum WHERE process_flag = 0
		WHILE @record_ID <> 0
		BEGIN
			SELECT
				@batch_location		= location
			,	@batch_trackingnum	= tracking_num
			,	@batch_cycle		= cycle
			,	@batch_id			= batchID
			FROM @batch_loc_trackingnum WHERE record_id = @record_ID
			
			-- exec the child sp
			EXEC sp_batch_recalc @batch_id, @batch_location, @batch_trackingnum, @profit_ctr_id, @company_id, @batch_cycle, @debug
			
			-- update this record as processed
			UPDATE @batch_loc_trackingnum SET process_flag = 1 WHERE record_id = @record_ID
			-- move on to next
			SELECT @record_ID = IsNull(MIN(record_id), 0) FROM @batch_loc_trackingnum WHERE process_flag = 0
		END
	END

-- now select the results
SELECT DISTINCT 
	Batch.company_id
,	Batch.profit_ctr_id
,	Batch.location
,	Batch.tracking_num
,	Batch.cycle
,	Batch.status
,	Batch.date_opened
,	Batch.date_closed
,	Batch.comment
,	Batch.date_added
,	Batch.date_modified
,   Batch.created_by
,   Batch.modified_by
,	Batch.voided_by
,	Batch.void_reason
,	Company.company_name
,	ProfitCenter.profit_ctr_name
FROM Batch
JOIN Company
	ON Company.company_id = Batch.company_id
JOIN ProfitCenter
	ON ProfitCenter.company_ID = Batch.company_id
	AND ProfitCenter.profit_ctr_ID = Batch.profit_ctr_id
LEFT OUTER JOIN BatchEvent
	ON BatchEvent.location = Batch.location
	AND BatchEvent.company_id = Batch.company_id
	AND BatchEvent.tracking_num = Batch.tracking_num
	AND BatchEvent.profit_ctr_id = Batch.profit_ctr_id
LEFT OUTER JOIN BatchWasteCode
	ON BatchWasteCode.location = Batch.location
	AND BatchWasteCode.company_id = Batch.company_id
	AND BatchWasteCode.tracking_num = Batch.tracking_num
	AND BatchWasteCode.profit_ctr_id = Batch.profit_ctr_id
LEFT OUTER JOIN BatchConstituent
	ON BatchConstituent.location = Batch.location
	AND BatchConstituent.company_id = Batch.company_id
	AND BatchConstituent.tracking_num = Batch.tracking_num
	AND BatchConstituent.profit_ctr_id = Batch.profit_ctr_id
LEFT OUTER JOIN BatchTreatment
	ON BatchTreatment.location = Batch.location
	AND BatchTreatment.company_id = Batch.company_id
	AND BatchTreatment.tracking_num = Batch.tracking_num
	AND BatchTreatment.profit_ctr_id = Batch.profit_ctr_id
LEFT OUTER JOIN BatchLab
	ON BatchLab.location = Batch.location
	AND BatchLab.company_id = Batch.company_id
	AND BatchLab.tracking_num = Batch.tracking_num
	AND BatchLab.profit_ctr_id = Batch.profit_ctr_id
WHERE	(Batch.company_id = @company_id)	
	AND (Batch.profit_ctr_id = @profit_ctr_id)
	AND (@location = 'ALL' OR Batch.location = @location)
	AND (Batch.date_opened BETWEEN @date_from AND @date_to)


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_batch_throughput] TO [EQAI]
    AS [dbo];

