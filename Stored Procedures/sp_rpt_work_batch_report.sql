CREATE PROCEDURE sp_rpt_work_batch_report
	@report_source	varchar(10),
	@company_id		tinyint,
	@profit_ctr_id	int,
	@user_id		varchar(8),
	@debug			int
AS
/***************************************************************************************
Filename:		L:\Apps\SQL-Deploy\Prod\NTSQL1\PLT_XX_AI\Procedures\sp_rpt_work_batch_report.sql
Loads to:		Plt_XX_AI
PB Object(s):	None
SQL Object(s):	Called from sp_rpt_work_batch_container_inventory

09/XX/2002 SCC	Created
12/11/2002 JDB	Modified to get the receipt.location if the Container.location is NULL
03/08/2004 SCC	Added lab status
03/11/2004 SCC	Added treatment and container size
05/05/2004 MK	Select actual container_id in first select and added container weight for all
06/03/2004 SCC	Added Container.status = 'N' to omit reporting on completely consolidated containers
06/15/2004 SCC	Retrieves into work tables
10/28/2004 JDB	Updated @container_list calc to store ranges as 1-4 instead of 1, 2, 3, 4.
		It was taking up way too much space.  We then had to create another table
		work_container_inventory_container_2 to store the containers separately because
		they wanted to see each container number individually.
12/13/2004 MK	Modified ticket_id, drum references, DrumHeader, and DrumDetail
01/05/2005 SCC	Modified for Container Tracking
03/14/2005 SCC	Modified for common handling for both Container Inventory and Batch reports
09/22/2005 SCC	Modified for no-drill-down base containers
09/27/2005 SCC	Added back only UHC constituents
01/18/2007 SCC	Grouping by waste codes and grouping by constituents is handled the same but a
		group identifier is now stored in the work tables instead of the actual values
		used to do the grouping
01/23/2007 SCC	Each container was being single-grouped because the sort id was incremented each
		time the group value was stored.  Fixed to post-process the group sorts to assign
		a sort ID to distinct groups
03/17/2009 KAM  Updated to collect the information for the combined Batch/container report
03/25/2010 JDB	Changed to use the fn_container_source function.
11/30/2010 SK	Changed to use the @company_id arg, moved to Plt_AI
04/17/2013 RB   Added waste_code_uid to waste code related tables

sp_rpt_work_batch_report 'CONTAINER', 21, 0, 'JASON_B', 1
****************************************************************************************/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

DECLARE @const_id 			int,
	@container 				varchar(15),
	@container_prev 		varchar(15),
	@container_list 		varchar(2000),
	@container_list_right	varchar(5),
	@container_list_reverse	varchar(2000),
	@pos					int,
	@pos_hyphen				int,
	@pos_space				int,
	@base_container_count 	int,
	@container_type 		char(1),
	@process_count 			int,
	@profit_center 			varchar(2),
	@receipt_id 			int,
	@record_count 			int,
	@group_sort 			varchar(2000),
	@group_sort_id			int,
	@container_id 			int,
	@container_id_prev 		int,
	@line_id 				int,
	@sequence_id 			int,
	@sequence_id_prev 		int,
	@UHC 					char(1),
	@waste_code 			varchar(4),
	@treatment_id			int,
	@treatment_id_prev		int

SET NOCOUNT ON
IF @debug = 1 SET NOCOUNT OFF

------------------------------------------------------------------------------------------------------
-- Get waste codes for each container that does NOT have something consolidated into it.
------------------------------------------------------------------------------------------------------
INSERT #tmp_waste (receipt_id, line_id, container_type, container_id, sequence_id, waste_code, process_flag, waste_code_uid)
SELECT #tmp.receipt_id,
	#tmp.line_id,
	#tmp.container_type,
	#tmp.container_id,
	#tmp.sequence_id,
	cwc.waste_code,
	0 AS process_flag,
	cwc.waste_code_uid
FROM #tmp
INNER JOIN ContainerWasteCode cwc 
	ON #tmp.profit_ctr_id = cwc.profit_ctr_id
	AND #tmp.company_id = cwc.company_id
	AND #tmp.receipt_id = cwc.receipt_id
	AND #tmp.line_id = cwc.line_id
	AND #tmp.container_id = cwc.container_id
	AND #tmp.sequence_id = cwc.sequence_id
WHERE #tmp.container_type = 'S'
AND NOT EXISTS (SELECT 1 FROM ContainerDestination
				WHERE ContainerDestination.base_tracking_num = 'DL-' + 
					RIGHT('00' + CONVERT(varchar(2), #tmp.company_id), 2) +
					RIGHT('00' + CONVERT(varchar(2), #tmp.profit_ctr_id), 2) +
					'-' + RIGHT('000000' + CONVERT(varchar(6), #tmp.container_id), 6)
				AND ContainerDestination.base_container_id = #tmp.container_id
				AND ContainerDestination.base_sequence_id = #tmp.sequence_id
				)

UNION

SELECT #tmp.receipt_id,
	#tmp.line_id,
	#tmp.container_type,
	#tmp.container_id,
	#tmp.sequence_id,
	rwc.waste_code,
	0 AS process_flag,
	rwc.waste_code_uid
FROM #tmp
INNER JOIN ReceiptWasteCode rwc 
	ON #tmp.profit_ctr_id = rwc.profit_ctr_id
	AND #tmp.company_id = rwc.company_id
	AND #tmp.receipt_id = rwc.receipt_id
	AND #tmp.line_id = rwc.line_id
WHERE container_type = 'R'
	AND NOT EXISTS (SELECT 1 FROM ContainerDestination
					WHERE ContainerDestination.base_tracking_num = CONVERT(varchar(10), #tmp.receipt_id) +
							'-' + CONVERT(varchar(10), #tmp.line_id)
					AND ContainerDestination.base_container_id = #tmp.container_id
					AND ContainerDestination.base_sequence_id = #tmp.sequence_id
					)


------------------------------------------------------------------------------------------------------
-- Get constituents for each container that does NOT have something consolidated into it.
------------------------------------------------------------------------------------------------------
INSERT #tmp_const (receipt_id, line_id, container_type, container_id, sequence_id, const_id, UHC, process_flag)
SELECT #tmp.receipt_id, 
	#tmp.line_id, 
	#tmp.container_type, 
	#tmp.container_id, 
	#tmp.sequence_id, 
	CC.const_id, 
	CC.UHC, 
	0 AS process_flag 
FROM #tmp
INNER JOIN ContainerConstituent CC 
	ON #tmp.profit_ctr_id = CC.profit_ctr_id
	AND #tmp.company_id = CC.company_id
	AND #tmp.receipt_id = CC.receipt_id
	AND #tmp.line_id = CC.line_id
	AND #tmp.container_id = CC.container_id
	AND #tmp.sequence_id = CC.sequence_id
WHERE #tmp.container_type = 'S'
AND NOT EXISTS (SELECT 1 FROM ContainerDestination
				WHERE ContainerDestination.base_tracking_num = 'DL-' + 
					RIGHT('00' + CONVERT(varchar(2), #tmp.company_id), 2) +
					RIGHT('00' + CONVERT(varchar(2), #tmp.profit_ctr_id), 2) +
					'-' + RIGHT('000000' + CONVERT(varchar(6), #tmp.container_id), 6)
				AND ContainerDestination.base_container_id = #tmp.container_id
				AND ContainerDestination.base_sequence_id = #tmp.sequence_id
				)

UNION

SELECT #tmp.receipt_id, 
	#tmp.line_id, 
	#tmp.container_type, 
	#tmp.container_id, 
	#tmp.sequence_id, 
	rc.const_id, 
	rc.UHC, 
	0 AS process_flag 
FROM #tmp
INNER JOIN ReceiptConstituent rc 
	ON #tmp.profit_ctr_id = rc.profit_ctr_id
	AND #tmp.company_id = rc.company_id
	AND #tmp.receipt_id = rc.receipt_id
	AND #tmp.line_id = rc.line_id
WHERE container_type = 'R'
	AND NOT EXISTS (SELECT 1 FROM ContainerDestination
					WHERE ContainerDestination.base_tracking_num = CONVERT(varchar(10), #tmp.receipt_id) +
							'-' + CONVERT(varchar(10), #tmp.line_id)
					AND ContainerDestination.base_container_id = #tmp.container_id
					AND ContainerDestination.base_sequence_id = #tmp.sequence_id
					)



---- Get distinct set of waste codes
--INSERT #tmp_waste (receipt_id, line_id, container_type, container_id, sequence_id, treatment_id, waste_code, process_flag)
--SELECT DISTINCT
--	#tmp.receipt_id,
--	#tmp.line_id,
--	#tmp.container_type,
--	#tmp.container_id,
--	#tmp.sequence_id,
--	#tmp.treatment_id,
--	CW.waste_code,
--	0 AS process_flag
--FROM #tmp, ContainerWasteCode CW
--WHERE #tmp.receipt_id = CW.receipt_id
--	AND #tmp.line_id = CW.line_id
--	AND #tmp.container_id = CW.container_id
--	AND #tmp.sequence_id = CW.sequence_id
--	AND #tmp.profit_ctr_id = CW.profit_ctr_id
--        and isnull(#tmp.waste_flag, 'F') = 'T'
--union
--SELECT DISTINCT
--	#tmp.receipt_id,
--	#tmp.line_id,
--	#tmp.container_type,
--	#tmp.container_id,
--	#tmp.sequence_id,
--	#tmp.treatment_id,
--	RWC.waste_code,
--	0 AS process_flag
--FROM #tmp, ReceiptWasteCode RWC
--WHERE #tmp.receipt_id = RWC.receipt_id
--	AND #tmp.line_id = RWC.line_id
--	AND #tmp.profit_ctr_id = RWC.profit_ctr_id
--        and isnull(#tmp.waste_flag, 'F') = 'F'
--ORDER BY #tmp.receipt_id, #tmp.line_id, #tmp.container_type, #tmp.treatment_id, #tmp.container_id, #tmp.sequence_id, CW.waste_code

-- SELECT DISTINCT
-- 	#tmp.receipt_id,
-- 	#tmp.line_id,
-- 	#tmp.container_type,
-- 	#tmp.container_id,
-- 	#tmp.sequence_id,
-- 	CW.waste_code,
-- 	0 AS process_flag
-- FROM #tmp, ContainerWaste CW
-- WHERE #tmp.receipt_id = CW.receipt_id
-- 	AND #tmp.line_id = CW.line_id
-- 	AND #tmp.container_id = CW.container_id
-- 	AND #tmp.sequence_id = CW.sequence_id
-- 	AND #tmp.profit_ctr_id = CW.profit_ctr_id
-- ORDER BY #tmp.receipt_id, #tmp.line_id, #tmp.container_type, #tmp.container_id, #tmp.sequence_id, CW.waste_code





------------------------------------------------------------------------------------------------------
-- Define and open a cursor to get each container that has something consolidated into it.
------------------------------------------------------------------------------------------------------
DECLARE consolidation CURSOR FOR 
	SELECT profit_ctr_id,
		receipt_id,
		line_id,
		container_id,
		sequence_id
	FROM #tmp
	WHERE 1=1
	AND container_type = 'S'
	AND EXISTS (SELECT 1 FROM ContainerDestination
				WHERE ContainerDestination.base_tracking_num = 'DL-' + 
					RIGHT('00' + CONVERT(varchar(2), company_id), 2) +
					RIGHT('00' + CONVERT(varchar(2), #tmp.profit_ctr_id), 2) +
					'-' + RIGHT('000000' + CONVERT(varchar(6), #tmp.container_id), 6)
				AND ContainerDestination.base_container_id = #tmp.container_id
				AND ContainerDestination.base_sequence_id = #tmp.sequence_id
				)
	
	UNION
	
	SELECT profit_ctr_id,
		receipt_id,
		line_id,
		container_id,
		sequence_id
	FROM #tmp
	WHERE 1=1
	AND container_type = 'R'
	AND EXISTS (SELECT 1 FROM ContainerDestination
				WHERE ContainerDestination.base_tracking_num = CONVERT(varchar(10), #tmp.receipt_id) +
						'-' + CONVERT(varchar(10), #tmp.line_id)
				AND ContainerDestination.base_container_id = #tmp.container_id
				AND ContainerDestination.base_sequence_id = #tmp.sequence_id
				)

	OPEN consolidation 

	FETCH consolidation 
	INTO @profit_ctr_id,
		@receipt_id,
		@line_id,
		@container_id,
		@sequence_id

	WHILE @@FETCH_STATUS = 0 
	BEGIN 
		IF @debug = 1 PRINT 'Container:  ' + CONVERT(VARCHAR,@receipt_id) 
			+ '-' + CONVERT(VARCHAR,@line_id) 
			+ '-' + CONVERT(VARCHAR,@container_id)  
			+ '-' + CONVERT(VARCHAR,@sequence_id) 

		INSERT #tmp_waste (receipt_id, line_id, container_type, container_id, sequence_id, waste_code, process_flag, waste_code_uid)
		------------------------------------------------------------------------------------------------------
		-- Insert container waste codes, if any
		------------------------------------------------------------------------------------------------------
		SELECT #tmp.receipt_id,
			#tmp.line_id,
			#tmp.container_type,
			#tmp.container_id,
			#tmp.sequence_id,
			cwc.waste_code,
			0 AS process_flag,
			cwc.waste_code_uid
			--containers.receipt_id,
			--containers.line_id,
			--containers.container_type,
			--containers.container_id,
			--containers.sequence_id,
			--containers.destination_receipt_id,
			--containers.destination_line_id,
			--containers.destination_container_id,
			--containers.destination_sequence_id
		FROM #tmp
		INNER JOIN dbo.fn_container_source(@company_id, @profit_ctr_id, @receipt_id, @line_id, @container_id, @sequence_id, 1) containers 
			ON #tmp.profit_ctr_id = containers.destination_profit_ctr_id
			AND #tmp.company_id = containers.destination_company_id
			AND #tmp.receipt_id = containers.destination_receipt_id
			AND #tmp.line_id = containers.destination_line_id
			AND #tmp.container_id = containers.destination_container_id
			AND #tmp.sequence_id = containers.destination_sequence_id
		INNER JOIN ContainerWasteCode cwc
			ON containers.company_id = cwc.company_id
			AND containers.profit_ctr_id = cwc.profit_ctr_id
			AND containers.receipt_id = cwc.receipt_id
			AND containers.line_id = cwc.line_id
			AND containers.container_id = cwc.container_id
		
		UNION
		
		------------------------------------------------------------------------------------------------------
		-- Insert receipt waste codes
		------------------------------------------------------------------------------------------------------
		SELECT #tmp.receipt_id,
			#tmp.line_id,
			#tmp.container_type,
			#tmp.container_id,
			#tmp.sequence_id,
			rwc.waste_code,
			0 AS process_flag,
			rwc.waste_code_uid
			--containers.receipt_id,
			--containers.line_id,
			--containers.container_type,
			--containers.container_id,
			--containers.sequence_id,
			--containers.destination_receipt_id,
			--containers.destination_line_id,
			--containers.destination_container_id,
			--containers.destination_sequence_id
		FROM #tmp
		INNER JOIN dbo.fn_container_source(@company_id, @profit_ctr_id, @receipt_id, @line_id, @container_id, @sequence_id, 1) containers 
			ON #tmp.profit_ctr_id = containers.destination_profit_ctr_id
			AND #tmp.company_id = containers.destination_company_id
			AND #tmp.receipt_id = containers.destination_receipt_id
			AND #tmp.line_id = containers.destination_line_id
			AND #tmp.container_id = containers.destination_container_id
			AND #tmp.sequence_id = containers.destination_sequence_id
		INNER JOIN ReceiptWasteCode rwc 
			ON containers.company_id = rwc.company_id
			AND containers.profit_ctr_id = rwc.profit_ctr_id
			AND containers.receipt_id = rwc.receipt_id
			AND containers.line_id = rwc.line_id
		WHERE NOT EXISTS (SELECT 1 FROM ContainerWasteCode cwc
							WHERE containers.company_id = cwc.company_id
								AND containers.profit_ctr_id = cwc.profit_ctr_id
								AND containers.receipt_id = cwc.receipt_id
								AND containers.line_id = cwc.line_id
								AND containers.container_id = cwc.container_id
							)


		INSERT #tmp_const (receipt_id, line_id, container_type, container_id, sequence_id, const_id, UHC, process_flag)
		------------------------------------------------------------------------------------------------------
		-- Insert container constituents, if any
		------------------------------------------------------------------------------------------------------
		SELECT #tmp.receipt_id, 
			#tmp.line_id, 
			#tmp.container_type, 
			#tmp.container_id, 
			#tmp.sequence_id, 
			CC.const_id, 
			CC.UHC, 
			0 AS process_flag 
			--containers.receipt_id,
			--containers.line_id,
			--containers.container_type,
			--containers.container_id,
			--containers.sequence_id,
			--containers.destination_receipt_id,
			--containers.destination_line_id,
			--containers.destination_container_id,
			--containers.destination_sequence_id
		FROM #tmp
		INNER JOIN dbo.fn_container_source(@company_id, @profit_ctr_id, @receipt_id, @line_id, @container_id, @sequence_id, 1) containers 
			ON #tmp.profit_ctr_id = containers.destination_profit_ctr_id
			AND #tmp.company_id = containers.destination_company_id
			AND #tmp.receipt_id = containers.destination_receipt_id
			AND #tmp.line_id = containers.destination_line_id
			AND #tmp.container_id = containers.destination_container_id
			AND #tmp.sequence_id = containers.destination_sequence_id
		INNER JOIN ContainerConstituent CC
			ON containers.company_id = CC.company_id
			AND containers.profit_ctr_id = CC.profit_ctr_id
			AND containers.receipt_id = CC.receipt_id
			AND containers.line_id = CC.line_id
			AND containers.container_id = CC.container_id
		AND (@report_source = 'INVENTORY' OR (@report_source = 'BATCH' AND ISNULL(CC.UHC, 'U') = 'T'))

		UNION

		SELECT #tmp.receipt_id, 
			#tmp.line_id, 
			#tmp.container_type, 
			#tmp.container_id, 
			#tmp.sequence_id, 
			rc.const_id, 
			rc.UHC, 
			0 AS process_flag 
			--containers.receipt_id,
			--containers.line_id,
			--containers.container_type,
			--containers.container_id,
			--containers.sequence_id,
			--containers.destination_receipt_id,
			--containers.destination_line_id,
			--containers.destination_container_id,
			--containers.destination_sequence_id
		FROM #tmp
		INNER JOIN dbo.fn_container_source(@company_id, @profit_ctr_id, @receipt_id, @line_id, @container_id, @sequence_id, 1) containers 
			ON #tmp.profit_ctr_id = containers.destination_profit_ctr_id
			AND #tmp.company_id = containers.destination_company_id
			AND #tmp.receipt_id = containers.destination_receipt_id
			AND #tmp.line_id = containers.destination_line_id
			AND #tmp.container_id = containers.destination_container_id
			AND #tmp.sequence_id = containers.destination_sequence_id
		INNER JOIN ReceiptConstituent rc 
			ON containers.company_id = rc.company_id
			AND containers.profit_ctr_id = rc.profit_ctr_id
			AND containers.receipt_id = rc.receipt_id
			AND containers.line_id = rc.line_id
		WHERE NOT EXISTS (SELECT 1 FROM ContainerConstituent cc
							WHERE containers.company_id = cc.company_id
								AND containers.profit_ctr_id = cc.profit_ctr_id
								AND containers.receipt_id = cc.receipt_id
								AND containers.line_id = cc.line_id
								AND containers.container_id = cc.container_id
							)
		AND (@report_source = 'INVENTORY' OR (@report_source = 'BATCH' AND IsNull(RC.UHC,'U') = 'T'))


		
		-----------------------------------------------------
		-- Go to next row 
		-----------------------------------------------------
		FETCH consolidation 
		INTO @profit_ctr_id,
			@receipt_id,
			@line_id,
			@container_id,
			@sequence_id
	END 

CLOSE consolidation 
DEALLOCATE consolidation 


IF @debug = 1 PRINT 'Selecting from #tmp_waste'
IF @debug = 1 SELECT * FROM #tmp_waste

------------------------------------------------------------------------------------------------------
-- Set the group sort for waste codes
------------------------------------------------------------------------------------------------------
SET @container_prev = ''
SET @container_id_prev = 0
SET @sequence_id_prev = 0
SET @treatment_id_prev = 0
SET @group_sort = ''
SET @container_list = ''
SELECT @process_count = COUNT(*) FROM #tmp_waste

WHILE @process_count > 0
BEGIN
	SET ROWCOUNT 1
	SELECT @receipt_id = receipt_id, @line_id = line_id, @container_id = container_id, @treatment_id = treatment_id,
		@sequence_id = sequence_id, @waste_code = waste_code, @container_type = container_type 
		FROM #tmp_waste WHERE process_flag = 0
	IF @container_type = 'S'
		SELECT @container = dbo.fn_container_stock(@line_id, @company_id, @profit_ctr_id)
	ELSE
		SET @container = dbo.fn_container_receipt(@receipt_id, @line_id)
	IF @debug = 1 PRINT 'NEXT WASTE: container: ' + @container + ' container_id: ' + CONVERT(varchar(10), @container_id) + ' sequence_id: ' + CONVERT(varchar(10), @sequence_id) + ' group_sort: ' + @group_sort
	SET ROWCOUNT 0

	-- Store group sort from previous - we're at the sequence_id level
	IF (@container <> @container_prev AND @container_prev <> '')
		OR (@container = @container_prev AND @container_id <> @container_id_prev AND @container_id_prev > 0)
		OR (@container = @container_prev AND @container_id = @container_id_prev  AND @sequence_id <> @sequence_id_prev AND @sequence_id_prev > 0 )
		OR (@container = @container_prev AND @container_id = @container_id_prev  AND @sequence_id = @sequence_id_prev AND @treatment_id <> @treatment_id_prev and @treatment_id_prev > 0 )		
	BEGIN
		IF @debug = 1 PRINT 'WASTE: @container: ' + @container_prev + ' container_id: ' + CONVERT(varchar(10), @container_id_prev) + ' sequence_id: ' + CONVERT(varchar(10), @sequence_id_prev) + ' group_sort: ' + @group_sort
		
		-- Store Group
		UPDATE #tmp SET group_waste = @group_sort
		WHERE #tmp.container = @container_prev
		AND #tmp.container_id = @container_id_prev
		AND #tmp.sequence_id = @sequence_id_prev
		AND #tmp.treatment_id = @treatment_id_prev

		SET @group_sort = ''

		IF @treatment_id <> @treatment_id_prev or @container <> @container_prev 
		BEGIN
			UPDATE #tmp SET group_container = @container_list 
				WHERE #tmp.container = @container_prev AND #tmp.sequence_id = @sequence_id_prev AND #tmp.treatment_id = @treatment_id_prev
			
			IF @report_source = 'INVENTORY'
			BEGIN
				UPDATE work_ContainerOverflow SET group_container = @container_list 
				WHERE container = @container_prev
			END
			
			SET @container_id_prev = 0
			SET @treatment_id_prev = 0
			SET @container_list = ''
		END
	END

	IF @group_sort = ''
		SET @group_sort = @waste_code
	ELSE
		SET @group_sort = @group_sort + ',' + @waste_code


	IF @treatment_id <> @treatment_id_prev OR @container_id <> @container_id_prev
	-----------------------------
	-- OLD WAY:
	-----------------------------
	-- 	BEGIN
	-- 		IF @container_list = ''
	-- 			SET @container_list = CONVERT(varchar(10), @container_id)
	-- 		ELSE
	-- 			SET @container_list = @container_list + ', ' + CONVERT(varchar(10), @container_id)
	-- 	END


	-----------------------------
	-- NEW WAY:
	-----------------------------
	-- The purpose of this section is to build the list of containers using hyphens when the 
	-- containers are in consecutive order, such as 1-10 means containers 1 through 10.
	-- Previously the code would write this as 1, 2, 3, 4, 5, 6, 7, 8, 9, 10.  This took up
	-- too much space (only 255 is allowed in PB).
	BEGIN
		IF @report_source = 'INVENTORY'
		BEGIN
			INSERT INTO work_ContainerOverflow (
				company_id,
				profit_ctr_id,
				container_type,
				container,
				receipt_id,
				line_id,
				container_id,
				sequence_id,
				user_id )
			VALUES (
				@company_id,
				@profit_ctr_id,
				@container_type,
				@container,
				@receipt_id,
				@line_id,
				@container_id,
				@sequence_id,
				@user_id )
		END

		SET @container_list_reverse = REVERSE(@container_list)
		SET @pos_space = CHARINDEX(' ', @container_list_reverse)
		SET @pos_hyphen = CHARINDEX('-', @container_list_reverse)
		IF @debug = 1 PRINT ''
		IF @debug = 1 PRINT 'CONTAINER LIST:  ' + @container_list
		IF @debug = 1 PRINT 'CONTAINER LIST REVERSE:  ' + @container_list_reverse
		IF @debug = 1 PRINT '@pos_space:  ' + CONVERT(varchar(10), @pos_space)
		IF @debug = 1 PRINT '@pos_hyphen:  ' + CONVERT(varchar(10), @pos_hyphen)
		IF @pos_space = 0 AND @pos_hyphen = 0 SET @pos = 0
		IF @pos_space > 0 AND @pos_hyphen = 0 SET @pos = @pos_space
		IF @pos_hyphen > 0 AND @pos_space = 0 SET @pos = @pos_hyphen
		IF @pos_space > 0 AND @pos_hyphen > 0 AND @pos_space < @pos_hyphen SET @pos = @pos_space
		IF @pos_hyphen > 0 AND @pos_space > 0 AND @pos_hyphen < @pos_space SET @pos = @pos_hyphen
		IF @debug = 1 PRINT '@pos:  ' + CONVERT(varchar(10), @pos)
		
		IF @container_list = ''
		BEGIN
			SET @container_list = CONVERT(varchar(10), @container_id)
		END
		ELSE
		BEGIN
			IF @pos > 0
			BEGIN
				SET @container_list_right = REVERSE(LEFT(@container_list_reverse, @pos - 1))
				IF @debug = 1 PRINT 'CONTAINER LIST RIGHT:  ' + @container_list_right				
				IF @pos = @pos_space
				BEGIN
					IF CONVERT(int, @container_list_right) = @container_id - 1
						SET @container_list = @container_list + '-' + CONVERT(varchar(10), @container_id)
					ELSE
						SET @container_list = @container_list + ', ' + CONVERT(varchar(10), @container_id)
				END
				ELSE	-- @pos = @pos_hyphen
				BEGIN
					IF CONVERT(int, @container_list_right) = @container_id - 1
						SET @container_list = REVERSE(RIGHT(@container_list_reverse, LEN(@container_list_reverse) - @pos + 1)) + CONVERT(varchar(10), @container_id)
					ELSE
						SET @container_list = @container_list + ', ' + CONVERT(varchar(10), @container_id)
				END
			END

			ELSE
			BEGIN
				IF CONVERT(int, @container_list) = @container_id - 1
				BEGIN
					SET @container_list = @container_list + '-' + CONVERT(varchar(10), @container_id)
				END
				ELSE
				BEGIN
					SET @container_list = @container_list + ', ' + CONVERT(varchar(10), @container_id)
 				END
			END
		END
	END

	IF LEN(@container_list) > 250 SET @container_list = LEFT(@container_list, 250) + ' MORE'
	IF @debug = 1 PRINT 'FINAL @container_list:  ' + @container_list

	SET @container_prev = @container
	SET @container_id_prev = @container_id
	SET @treatment_id_prev = @treatment_id
	SET @sequence_id_prev = @sequence_id
	SET @process_count = @process_count - 1
	SET ROWCOUNT 1
	UPDATE #tmp_waste SET process_flag = 1 WHERE process_flag = 0
	SET ROWCOUNT 0
END

-- Update the last one
UPDATE #tmp SET group_waste = @group_sort 
WHERE #tmp.container = @container_prev 
AND #tmp.container_id = @container_id_prev 
AND #tmp.treatment_id = @treatment_id_prev

UPDATE #tmp SET group_container = @container_list 
WHERE #tmp.container = @container_prev 
AND #tmp.treatment_id = @treatment_id_prev

IF @report_source = 'INVENTORY'
BEGIN
	UPDATE work_ContainerOverflow SET group_container = @container_list WHERE container = @container_prev
END

IF @debug = 1 PRINT 'Last line_id:  ' + @container_prev + '   Group_sort:  ' + @group_sort

-- Set the group sort ID for waste
SELECT DISTINCT group_waste, 0 AS group_sort_id
INTO #tmp_waste_sort
FROM #tmp

SET @group_sort_id = 0
UPDATE #tmp_waste_sort SET @group_sort_id = group_sort_id = @group_sort_id + 1

-- Update with new sort ID
UPDATE #tmp SET group_waste = #tmp_waste_sort.group_sort_id 
FROM #tmp
INNER JOIN #tmp_waste_sort ON #tmp.group_waste = #tmp_waste_sort.group_waste


---- Get distinct set of constituents
--INSERT #tmp_const (receipt_id, line_id, container_type, container_id, sequence_id, const_id, UHC, process_flag)
--SELECT DISTINCT 
--#tmp.receipt_id, 
--#tmp.line_id, 
--#tmp.container_type, 
--#tmp.container_id, 
--#tmp.sequence_id, 
--CC.const_id, 
--CC.UHC, 
--0 as process_flag 
--FROM #tmp, ContainerConstituent CC
--WHERE #tmp.receipt_id = CC.receipt_id
--	AND #tmp.line_id = CC.line_id
--	AND #tmp.container_id = CC.container_id
--	AND #tmp.sequence_id = CC.sequence_id
--	AND #tmp.profit_ctr_id = CC.profit_ctr_id
--        and isnull(#tmp.const_flag, 'F') = 'T'
--	AND (@report_source = 'CONTAINER' OR @report_source = 'INVENTORY' OR (@report_source = 'BATCH' AND IsNull(CC.UHC,'U') = 'T'))
--union
--SELECT DISTINCT 
--#tmp.receipt_id, 
--#tmp.line_id, 
--#tmp.container_type, 
--#tmp.container_id, 
--#tmp.sequence_id, 
--RC.const_id, 
--RC.UHC, 
--0 as process_flag 
--FROM #tmp, ReceiptConstituent RC
--WHERE #tmp.receipt_id = RC.receipt_id
--	AND #tmp.line_id = RC.line_id
--	AND #tmp.profit_ctr_id = RC.profit_ctr_id
--        and isnull(#tmp.waste_flag, 'F') = 'F'
--	AND (@report_source = 'CONTAINER' OR @report_source = 'INVENTORY' OR (@report_source = 'BATCH' AND IsNull(RC.UHC,'U') = 'T'))
--ORDER BY #tmp.receipt_id, #tmp.line_id, #tmp.container_type, #tmp.container_id, #tmp.sequence_id, CC.const_id, CC.UHC


-- SELECT DISTINCT 
-- #tmp.receipt_id, 
-- #tmp.line_id, 
-- #tmp.container_type, 
-- #tmp.container_id, 
-- #tmp.sequence_id, 
-- CC.const_id, 
-- CC.UHC, 
-- 0 as process_flag 
-- FROM #tmp, ContainerConst CC
-- WHERE #tmp.receipt_id = CC.receipt_id
-- 	AND #tmp.line_id = CC.line_id
-- 	AND #tmp.container_id = CC.container_id
-- 	AND #tmp.sequence_id = CC.sequence_id
-- 	AND #tmp.profit_ctr_id = CC.profit_ctr_id
-- 	AND (@report_source = 'CONTAINER' OR (@report_source = 'BATCH' AND IsNull(CC.UHC,'U') = 'T'))
-- ORDER BY #tmp.receipt_id, #tmp.line_id, #tmp.container_type, #tmp.container_id, #tmp.sequence_id, CC.const_id, CC.UHC


IF @debug = 1 PRINT 'Selecting from #tmp_const'
IF @debug = 1 SELECT * FROM #tmp_const

------------------------------------------------------------------------------------------------------
-- Set the group sort for constituents
------------------------------------------------------------------------------------------------------
SET @container_prev = ''
SET @container_id_prev = 0
SET @sequence_id_prev = 0
SET @group_sort = ''
SELECT @process_count = COUNT(*) FROM #tmp_const

WHILE @process_count > 0
BEGIN
	SET ROWCOUNT 1
	SELECT @receipt_id = receipt_id, @line_id = line_id, @container_id = container_id, @sequence_id = sequence_id, 
		@container_type = container_type, @const_id = const_id, @UHC = UHC FROM #tmp_const WHERE process_flag = 0
	IF @container_type = 'S'
		SELECT @container = dbo.fn_container_stock(@line_id, @company_id, @profit_ctr_id)
	ELSE
		SELECT @container = CONVERT(varchar(15), @receipt_id) + '-' + CONVERT(varchar(15), @line_id)
	SET ROWCOUNT 0

	-- Store group sort from previous
	IF (@container <> @container_prev AND @container_prev <> '')
		OR (@container = @container_prev AND @container_id <> @container_id_prev AND @container_id_prev > 0)
		OR (@container = @container_prev AND @container_id = @container_id_prev  AND @sequence_id <> @sequence_id_prev AND @sequence_id_prev > 0 )
	BEGIN
		IF @debug = 1 PRINT 'CONST:  container: ' + @container_prev + '   Group_sort:  ' + @group_sort
		UPDATE #tmp SET group_const = @group_sort 
		WHERE #tmp.container = @container_prev
		AND #tmp.container_id = @container_id_prev
		AND #tmp.sequence_id = @sequence_id_prev
		SET @group_sort = ''
	END

	IF @group_sort = ''
		SET @group_sort = CONVERT(varchar(10),@const_id)
	ELSE
		SET @group_sort = @group_sort + ',' + CONVERT(varchar(10),@const_id)

	SET @container_prev = @container
	SET @container_id_prev = @container_id
	SET @sequence_id_prev = @sequence_id
	SET @process_count = @process_count - 1
	SET ROWCOUNT 1
	UPDATE #tmp_const SET process_flag = 1 WHERE process_flag = 0
	SET ROWCOUNT 0
END

-- Update the last one
UPDATE #tmp SET group_const = @group_sort 
WHERE #tmp.container = @container_prev
AND #tmp.container_id = @container_id_prev

IF @debug = 1 PRINT 'Last container: ' + @container_prev + '   Group_sort:  ' + @group_sort

-- Set the group sort ID for const
SELECT DISTINCT group_const, 0 AS group_sort_id
INTO #tmp_const_sort
FROM #tmp

SET @group_sort_id = 0
UPDATE #tmp_const_sort SET @group_sort_id = group_sort_id = @group_sort_id + 1

-- Update with new sort ID
UPDATE #tmp SET group_const = #tmp_const_sort.group_sort_id 
FROM #tmp, #tmp_const_sort
WHERE #tmp.group_const = #tmp_const_sort.group_const

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_work_batch_report] TO [EQAI]
    AS [dbo];

