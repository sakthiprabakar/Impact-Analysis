CREATE PROCEDURE sp_work_report
	@report_source	varchar(10),
	@company_id		tinyint,
	@profit_ctr_id	int,
	@user_id		varchar(8),
	@debug			int
WITH RECOMPILE
AS
/***************************************************************************************
Filename:		L:\Apps\SQL-Deploy\Prod\NTSQL1\PLT_XX_AI\Procedures\sp_work_report.sql
Loads to:		Plt_XX_AI
PB Object(s):	None
SQL Object(s):	Called from sp_work_batch				@report_source = 'BATCH'
				Called from sp_work_container_inventory	@report_source = 'INVENTORY'

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
03/25/2010 JDB	Changed to use the fn_container_source function.
				Added @company_id as input parameter.
11/30/2010 SK	Added joins to company_id, moved to Plt_AI
04/16/2013 RB   Added waste_code_uid to waste code related tables
12/04/2015 RB	This procedure was still traversing up consolidated receipts/containers, but it shouldn't.
				If receipts have been consolidated, they all exist in ContainerWasteCode/ContainerConstituent
01/19/2018 AM   Added WITH RECOMPILE to sp to run report faster.

sp_work_report 'CONTAINER', 21, 0, 'SA', 1
sp_work_report 'BATCH', 21, 0, 'SA', 1
SELECT * FROM dbo.fn_container_source(21,0,0,1194,1194,1,1)
SELECT * FROM dbo.fn_container_source(21,0,0,12,2,1,1)
****************************************************************************************/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

DECLARE 
	@const_id 				int,
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
	@waste_code 			varchar(4)

SET NOCOUNT ON
IF @debug = 1 SET NOCOUNT OFF

------------------------------------------------------------------------------------------------------
-- Pull waste codes from ContainerWasteCode for those that have been consolidated into
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
	ON #tmp.container_type = cwc.container_type
	AND #tmp.profit_ctr_id = cwc.profit_ctr_id
	AND #tmp.company_id = cwc.company_id
	AND #tmp.receipt_id = cwc.receipt_id
	AND #tmp.line_id = cwc.line_id
	AND #tmp.container_id = cwc.container_id
	AND #tmp.sequence_id = cwc.sequence_id

------------------------------------------------------------------------------------------------------
-- Pull waste codes from ReceiptWasteCode for those that have not been consolidated into
------------------------------------------------------------------------------------------------------
INSERT #tmp_waste (receipt_id, line_id, container_type, container_id, sequence_id, waste_code, process_flag, waste_code_uid)
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
WHERE #tmp.container_type = 'R'
AND NOT EXISTS (SELECT 1 FROM ContainerWasteCode cwc 
				WHERE #tmp.container_type = cwc.container_type
				AND #tmp.profit_ctr_id = cwc.profit_ctr_id
				AND #tmp.company_id = cwc.company_id
				AND #tmp.receipt_id = cwc.receipt_id
				AND #tmp.line_id = cwc.line_id
				AND #tmp.container_id = cwc.container_id
				AND #tmp.sequence_id = cwc.sequence_id
				)


------------------------------------------------------------------------------------------------------
-- Pull constituents from ContainerConstituent for those that have been consolidated into
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
	ON #tmp.container_type = CC.container_type
	AND #tmp.profit_ctr_id = CC.profit_ctr_id
	AND #tmp.company_id = CC.company_id
	AND #tmp.receipt_id = CC.receipt_id
	AND #tmp.line_id = CC.line_id
	AND #tmp.container_id = CC.container_id
	AND #tmp.sequence_id = CC.sequence_id
WHERE (@report_source = 'INVENTORY' OR (@report_source = 'BATCH' AND ISNULL(CC.UHC, 'U') = 'T'))


------------------------------------------------------------------------------------------------------
-- Pull constituents from ReceiptConstituent for those that have not been consolidated into
------------------------------------------------------------------------------------------------------
INSERT #tmp_const (receipt_id, line_id, container_type, container_id, sequence_id, const_id, UHC, process_flag)
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
WHERE #tmp.container_type = 'R'
AND (@report_source = 'INVENTORY' OR (@report_source = 'BATCH' AND IsNull(rc.UHC,'U') = 'T'))
AND NOT EXISTS (SELECT 1 FROM ContainerConstituent CC 
				WHERE #tmp.container_type = CC.container_type
				AND #tmp.profit_ctr_id = CC.profit_ctr_id
				AND #tmp.company_id = CC.company_id
				AND #tmp.receipt_id = CC.receipt_id
				AND #tmp.line_id = CC.line_id
				AND #tmp.container_id = CC.container_id
				AND #tmp.sequence_id = CC.sequence_id
				)

IF @debug = 1 PRINT 'Selecting from #tmp_waste'
IF @debug = 1 SELECT * FROM #tmp_waste

------------------------------------------------------------------------------------------------------
-- Set the group sort for waste codes
------------------------------------------------------------------------------------------------------
SET @container_prev = ''
SET @container_id_prev = 0
SET @sequence_id_prev = 0
SET @group_sort = ''
SET @container_list = ''
SELECT @process_count = COUNT(*) FROM #tmp_waste

WHILE @process_count > 0
BEGIN
	SET ROWCOUNT 1
	SELECT @receipt_id = receipt_id, @line_id = line_id, @container_id = container_id, 
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
		
	BEGIN
		IF @debug = 1 PRINT 'WASTE: @container: ' + @container_prev + ' container_id: ' + CONVERT(varchar(10), @container_id_prev) + ' sequence_id: ' + CONVERT(varchar(10), @sequence_id_prev) + ' group_sort: ' + @group_sort
		
		-- Store Group
		UPDATE #tmp SET group_waste = @group_sort
		WHERE #tmp.container = @container_prev
		AND #tmp.container_id = @container_id_prev
		AND #tmp.sequence_id = @sequence_id_prev
		SET @group_sort = ''

		IF @container <> @container_prev 
		BEGIN
			UPDATE #tmp SET group_container = @container_list 
				WHERE #tmp.container = @container_prev AND #tmp.sequence_id = @sequence_id_prev
			IF @report_source = 'INVENTORY'
				UPDATE work_ContainerOverflow SET group_container = @container_list 
				WHERE container = @container_prev
			ELSE IF @report_source = 'BATCH'
				UPDATE work_BatchOverflow SET group_container = @container_list 
				WHERE container = @container_prev
			SET @container_id_prev = 0
			SET @container_list = ''
		END
	END

	IF @group_sort = ''
		SET @group_sort = @waste_code
	ELSE
		SET @group_sort = @group_sort + ',' + @waste_code


	IF @container_id <> @container_id_prev
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

		ELSE IF @report_source = 'BATCH'
			INSERT INTO work_BatchOverflow (
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

UPDATE #tmp SET group_container = @container_list WHERE #tmp.container = @container_prev
IF @report_source = 'INVENTORY'
	UPDATE work_ContainerOverflow SET group_container = @container_list WHERE container = @container_prev
ELSE IF @report_source = 'BATCH'
	UPDATE work_BatchOverflow SET group_container = @container_list WHERE container = @container_prev

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





IF @debug = 1 print 'Selecting from #tmp_const'
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
FROM #tmp
JOIN #tmp_const_sort ON #tmp.group_const = #tmp_const_sort.group_const

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_work_report] TO [EQAI]
    AS [dbo];

