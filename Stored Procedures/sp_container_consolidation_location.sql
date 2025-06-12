CREATE PROCEDURE sp_container_consolidation_location
	@receipt_id			int,
	@line_id			int,
	@container_id		int,
	@sequence_id		int,
	@manifest_in		varchar(15),
	@base_container		varchar(15), 
	@base_container_id	int, 
	@profit_ctr_id		int,
	@company_id         int,
	@container_weight	decimal(10,3), 
	@debug				int
AS
/****************************************************************
This SP returns a list of locations for consolidated containers.  It is
called recursively until there are no more consolidated containers

01/06/2005 SCC	Created
09/27/2005 SCC	Added join to base container ID
02/08/2006 MK	Added container weight parameter to use inbound container weight on final record 
08/16/2010 JDB	Added new DEA Receipt fields for EQ Oklahoma.  Updated joins to new syntax.  
				Changed manifest line from letter to number.
06/23/2014  AM  Moved to plt_ai and added company_id 
08/04/2015  SK	Added processed_flag to #container_locations, 
				Modified query to avoid a full scan of receipt table in section to fetch manifest_out info. Report run time reduced from 18 mins to seconds!
11/20/2023	Kamendra Devops #72666
				Added a check so that recursive call doesn't go into a infinite loop.
10/09/2024	Sailaja Rally # DE35384 Included cycle in select for #tmp_base
				Update statement to include manifest_out for location type 'P' 

sp_container_consolidation_location '130475', 1, 1, 1, 'manifest', 'DL-2200-057641', 57641,0,21,1, 1
****************************************************************/
DECLARE @base_container_type char(1),
	@base_receipt_id int,
	@base_line_id int,
	@consolidation_count int,
	@pos int,
	@container_locations_duplicate_check int

-- IF @debug = 1 print 'called with @base_container: ' + IsNull(@base_container, 'NONE')

-- What kind of container, Stock or Receipt?
IF SUBSTRING(@base_container,1,3) = 'DL-'
BEGIN
	SET @base_container_type = 'S'
	SET @base_receipt_id = 0
	SET @base_line_id = CONVERT(int, SUBSTRING(@base_container, LEN(@base_container) - 5, 6))
END
ELSE
BEGIN
	SET @base_container_type = 'R'
	SET @pos = CHARINDEX('-', @base_container, 1)
	SET @base_receipt_id = CONVERT(INT, SUBSTRING(@base_container, 1, @pos - 1)) 
	SET @base_line_id = CONVERT(INT, SUBSTRING(@base_container, @pos + 1, LEN(@base_container) - @pos))
END

-- Get the destinations for this base
SELECT DISTINCT
	@base_container AS container,
	ContainerDestination.company_id,
	ContainerDestination.receipt_id,
	ContainerDestination.line_id,
	ContainerDestination.container_id,
	ContainerDestination.sequence_id,
	ISNULL(ContainerDestination.location_type,'U') AS location_type,
	ISNULL(ContainerDestination.location,'') AS location,
	ISNULL(ContainerDestination.tracking_num,'') AS tracking_num,
	ISNULL(ContainerDestination.base_tracking_num,'') AS base_tracking_num,
	ISNULL(ContainerDestination.base_container_id,0) AS base_container_id,
	ContainerDestination.profit_ctr_id,
	ContainerDestination.status,
	ContainerDestination.treatment_id,
	ContainerDestination.disposal_date,
	Container.container_weight,
	CONVERT(varchar(15),'') AS manifest_out,
	CONVERT(int,NULL) AS manifest_line_id_out,
	CONVERT(int,NULL) AS manifest_page_num_out,
	0 AS process_flag,
	ISNULL(ContainerDestination.cycle,0) AS cycle  --Rally # DE35384
INTO #tmp_base
FROM ContainerDestination
INNER JOIN Container ON ContainerDestination.company_id = Container.company_id
	AND ContainerDestination.profit_ctr_id = Container.profit_ctr_id
	AND ContainerDestination.receipt_id = Container.receipt_id
	AND ContainerDestination.line_id = Container.line_id
	AND ContainerDestination.container_id = Container.container_id
	AND ContainerDestination.container_type = Container.container_type
WHERE ContainerDestination.receipt_id = @base_receipt_id
AND ContainerDestination.line_id = @base_line_id
AND ContainerDestination.container_type = @base_container_type
AND ContainerDestination.profit_ctr_id = @profit_ctr_id
AND ContainerDestination.company_id =  @company_id
AND Container.container_id = @base_container_id

IF @debug = 1 print 'Select * from #tmp_base'
IF @debug = 1 SELECT * FROM #tmp_base

--SET @pos = CHARINDEX('-', @base_container, 1)
--	SET @base_receipt_id = CONVERT(INT, SUBSTRING(@base_container, 1, @pos - 1)) 
--	SET @base_line_id = CONVERT(INT, SUBSTRING(@base_container, @pos + 1, LEN(@base_container) - @pos))
	
-- Get the outbound manifest info 
UPDATE #tmp_base SET 
	manifest_out = Receipt.manifest,
	manifest_line_id_out = Receipt.manifest_line,
	manifest_page_num_out = Receipt.manifest_page_num
FROM Receipt
WHERE 
--Receipt.receipt_id = Convert(INT, Isnull(SUBSTRING(Isnull(#tmp_base.tracking_num, ''), 1, (CHARINDEX('-', Isnull(#tmp_base.tracking_num, ''), 1))-1), ''))
--AND Receipt.line_id = CONVERT(INT, Isnull(SUBSTRING(Isnull(#tmp_base.tracking_num, ''), (CHARINDEX('-', Isnull(#tmp_base.tracking_num, ''), 1)) + 1, LEN(Isnull(#tmp_base.tracking_num, '')) - (CHARINDEX('-', Isnull(#tmp_base.tracking_num, ''), 1))), ''))
#tmp_base.tracking_num = (CONVERT(varchar(15), Receipt.receipt_id) + '-' + CONVERT(varchar(15), Receipt.line_id))
AND #tmp_base.location_type = 'O'
AND Receipt.trans_mode = 'O'
AND Receipt.trans_type = 'D'
AND Receipt.profit_ctr_id = @profit_ctr_id
AND Receipt.company_id = @company_id

--Sailaja Rally # DE35384 - Updating manifest_out for location type as P based on tracking_num of receipt table
UPDATE #tmp_base SET 
	manifest_out = Receipt.manifest,
	manifest_line_id_out = Receipt.manifest_line,
	manifest_page_num_out = Receipt.manifest_page_num
FROM Receipt
WHERE #tmp_base.tracking_num = Receipt.tracking_num
AND #tmp_base.location_type = 'P'
AND #tmp_base.location = Receipt.location
AND #tmp_base.profit_ctr_id = Receipt.profit_ctr_id
AND #tmp_base.company_id = Receipt.company_id
AND #tmp_base.cycle = IsNull(Receipt.cycle, 0)
AND Receipt.trans_type = 'D'
AND Receipt.trans_mode = 'O'

SELECT CONVERT(varchar(15),@receipt_id) + '-' + CONVERT(varchar(15), @line_id) AS container,  
 #tmp_base.company_id,  
 #tmp_base.profit_ctr_id,  
 @receipt_id AS receipt_id,  
 @line_id AS line_id,  
 @container_id AS container_id,  
 @sequence_id AS sequence_id,  
 @manifest_in AS manifest_in,  
 #tmp_base.location_type,  
 #tmp_base.location,  
 #tmp_base.tracking_num,  
 #tmp_base.base_tracking_num,  
 #tmp_base.base_container_id,  
 #tmp_base.treatment_id,  
 #tmp_base.disposal_date,  
 @container_weight AS container_weight,  
 #tmp_base.manifest_out,  
 #tmp_base.manifest_line_id_out,  
 #tmp_base.manifest_page_num_out,  
 #tmp_base.container AS secondary_container,  
 #tmp_base.container_id AS secondary_container_id,  
 #tmp_base.sequence_id AS secondary_sequence_id,  
 #tmp_base.status AS container_status,  
 CASE WHEN #tmp_base.status = 'C' THEN 1 ELSE 0 END AS include,  
 0  AS processed_flag
INTO #container_locations_duplicate_check
FROM #tmp_base
WHERE #tmp_base.location_type IN ('P','O')

/* We want to make sure that we are not inserting the duplicate record again, this is to terminal the recursive call.
   Devops #72666 - This one is having an issue where this recursive call was going into infinite loop.
*/
SELECT @container_locations_duplicate_check = COUNT(1) 
FROM #container_locations CONLOC 
INNER JOIN #container_locations_duplicate_check CONLOCCHK
ON  CONLOC.container = CONLOCCHK.container
AND CONLOC.company_id = CONLOCCHK.company_id
AND CONLOC.profit_ctr_id = CONLOCCHK.profit_ctr_id													
AND CONLOC.receipt_id = CONLOCCHK.receipt_id
AND CONLOC.line_id = CONLOCCHK.line_id
AND CONLOC.container_id = CONLOCCHK.container_id
AND CONLOC.sequence_id = CONLOCCHK.sequence_id
AND CONLOC.manifest_in = CONLOCCHK.manifest_in													
AND CONLOC.location_type = CONLOCCHK.location_type
AND CONLOC.location = CONLOCCHK.location
AND CONLOC.tracking_num = CONLOCCHK.tracking_num
AND CONLOC.base_tracking_num = CONLOCCHK.base_tracking_num
AND CONLOC.base_container_id = CONLOCCHK.base_container_id
AND CONLOC.treatment_id = CONLOCCHK.treatment_id
AND CONLOC.disposal_date = CONLOCCHK.disposal_date
AND CONLOC.container_weight = CONLOCCHK.container_weight	
AND CONLOC.manifest_out = CONLOCCHK.manifest_out	
AND CONLOC.manifest_line_id_out = CONLOCCHK.manifest_line_id_out	
AND CONLOC.manifest_page_num_out = CONLOCCHK.manifest_page_num_out													
AND CONLOC.secondary_container = CONLOCCHK.secondary_container
AND CONLOC.secondary_container_id = CONLOCCHK.secondary_container_id
AND CONLOC.secondary_sequence_id = CONLOCCHK.secondary_sequence_id													
AND CONLOC.container_status = CONLOCCHK.container_status
AND CONLOC.include = CONLOCCHK.include
WHERE CONLOCCHK.location_type IN ('P','O')
													
IF @container_locations_duplicate_check = 0
BEGIN
	-- Store the destinations that are outbound and process
	INSERT #container_locations (container, company_id, profit_ctr_id, receipt_id, line_id, 
		container_id, sequence_id, manifest_in,	location_type, location, tracking_num, base_tracking_num, 
		base_container_id, treatment_id, disposal_date, container_weight, manifest_out, 
		manifest_line_id_out, manifest_page_num_out, secondary_container, secondary_container_id, 
		secondary_sequence_id, container_status, include, processed_flag)
	SELECT CONVERT(varchar(15),@receipt_id) + '-' + CONVERT(varchar(15), @line_id) AS container,
		#tmp_base.company_id,
		#tmp_base.profit_ctr_id,
		@receipt_id,
		@line_id,
		@container_id,
		@sequence_id,
		@manifest_in,
		#tmp_base.location_type,
		#tmp_base.location,
		#tmp_base.tracking_num,
		#tmp_base.base_tracking_num,
		#tmp_base.base_container_id,
		#tmp_base.treatment_id,
		#tmp_base.disposal_date,
		@container_weight,
		#tmp_base.manifest_out,
		#tmp_base.manifest_line_id_out,
		#tmp_base.manifest_page_num_out,
		#tmp_base.container,
		#tmp_base.container_id,
		#tmp_base.sequence_id,
		#tmp_base.status,
		CASE WHEN #tmp_base.status = 'C' THEN 1 ELSE 0 END AS include,
		0
	FROM #tmp_base
	WHERE #tmp_base.location_type IN ('P','O')

	--IF @receipt_id = 37522 and @line_id = 1 and @container_id = 1
	--Begin
	-- IF @debug = 1 print 'selecting from #container_locations'
	-- IF @debug = 1 select * from #container_locations where receipt_id = 37522 and line_id = 1 and container_id = 1
	--end

	-- IF @debug = 1 print 'selecting from #container_locations'
	-- IF @debug = 1 select * from #container_locations

	-- How many consolidated containers to process?
	SELECT @consolidation_count = count(*) FROM #tmp_base WHERE location_type = 'C'
	WHILE @consolidation_count > 0
	BEGIN
		-- Get a container
		SET ROWCOUNT 1
		SELECT @base_container = base_tracking_num,
			   @base_container_id = base_container_id
		FROM #tmp_base WHERE process_flag = 0 AND location_type = 'C'
		IF @debug = 1 print 'next @base_container: ' + IsNull(@base_container, 'NONE')
		SET ROWCOUNT 0

		-- Now get the waste codes for containers consolidated into this container
		EXEC sp_container_consolidation_location @receipt_id, @line_id, @container_id, @sequence_id, @manifest_in,
			@base_container, @base_container_id, @profit_ctr_id, @company_id, @container_weight, @debug

		-- Update the process flag
		SET ROWCOUNT 1
		UPDATE #tmp_base SET process_flag = 1 WHERE process_flag = 0 AND location_type = 'C'
		SET @consolidation_count = @consolidation_count - 1
		SET ROWCOUNT 0
		IF @debug = 1 print 'Bottom of Consolidation Loop. @consolidation_count: ' + convert(varchar(10), @consolidation_count)
	END 
END

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_container_consolidation_location] TO [EQAI];