CREATE PROCEDURE sp_get_container_waste_codes
	@company_id		tinyint,
	@profit_ctr_id	int,
	@receipt_id		int,
	@line_id		int,
	@container_id	int,
	@sequence_id	int,
	@container_type char(1),	-- R (Receipt) or S (Stock)
	@distinct_flag	char(1),	-- T or F
	@return_self	int,		-- 1 (Yes) or 0 (No)
	@debug			int
AS
/***************************************************************************************
Loads to:		Plt_XX_AI

04/30/2010 KAM	Created
10/13/2011 JDB	Added missing join on sequence_id
04/26/2013 RB   Waste code conversion, added waste_code_uid
08/29/2013 RB	During waste code phase II, started reporting an "ambiguous column sequence_id"
		error. Also added display_name to result set
11/04/2013 SM   Corrected the joins to show only consolidated waste_codes
02/20/2014 AM   Copied from plt_xx_ai to plt_ai.
04/11/2014 RB	Receipt codes are now included in list of sources
07/16/2014 RB	During the removal of company databases, this procedure with changes made for Container
		processing was not moved over because a copy with the same name and parameters already
		existed (see 02/20/2014 comment). Deployed the version that was in Plt_XX_ai
08/05/2020 - AM DevOps:17045 - Adedd set transaction isolation level read uncommitted

sp_get_container_waste_codes 22,0,0,112709,112709,1,'S','F',0, 1
sp_get_container_waste_codes 22,0,0,125735,125735,1,'S','F',0, 1
****************************************************************************************/

set transaction isolation level read uncommitted

DECLARE @pos				int,
	@pos_hyphen				int,
	@pos_space				int,
	@process_count 			int,
	@record_count 			int,
	@waste_code 			varchar(4)

SET NOCOUNT ON
IF @debug = 1 SET NOCOUNT OFF

CREATE TABLE #tmp_waste 
	(receipt_id		int		NULL, 
	line_id			int		NULL, 
	container_type	char(1) NULL, 
	container_id	int		NULL, 
	waste_code		varchar(4)	NULL,
	sequence_id		int		NULL,
	waste_code_uid		int		NULL,
	display_name		varchar(10)	NULL)

IF @debug = 1 PRINT 'Container:  ' + CONVERT(varchar, @receipt_id) 
	+ '-' + CONVERT(varchar, @line_id) 
	+ '-' + CONVERT(varchar, @container_id)  
	+ '-' + CONVERT(varchar, @sequence_id) 

-- rb 03/07/2014 ContainerWasteCode should now contain all consolidated waste codes
INSERT #tmp_waste (receipt_id, line_id, container_type, container_id, waste_code, sequence_id, waste_code_uid,display_name )
------------------------------------------------------------------------------------------------------
-- Insert container waste codes, if any
------------------------------------------------------------------------------------------------------
/*SELECT cwc.source_receipt_id,
	cwc.source_line_id,
	cwc.container_type,
	cwc.source_container_id,
	wc.waste_code,
	cwc.source_sequence_id,
	cwc.waste_code_uid,
	wc.display_name
FROM ContainerWasteCode cwc (nolock)
INNER JOIN WasteCode wc (nolock) ON cwc.waste_code_uid = wc.waste_code_uid and wc.display_name <> 'NONE'
WHERE cwc.company_id = @company_id
AND cwc.profit_ctr_id = @profit_ctr_id
AND cwc.receipt_id = @receipt_id
AND cwc.line_id = @line_id
AND cwc.container_id = @container_id
--AND cwc.sequence_id = @sequence_id
AND cwc.container_type = @container_type
AND cwc.source_line_id is not null
union*/
select cwc.source_receipt_id,
		cwc.source_line_id,
		cwc.container_type,
		cwc.source_container_id,
		cwc.waste_code,
		cwc.source_sequence_id,
		cwc.waste_code_uid,
		wc.display_name
from ContainerWasteCode cwc
inner join WasteCode wc ON cwc.waste_code_uid = wc.waste_code_uid
where cwc.company_id = @company_id
and cwc.profit_ctr_id = @profit_ctr_id
and cwc.receipt_id = @receipt_id
and cwc.line_id = @line_id
and cwc.container_id = @container_id
--and cwc.sequence_id = @sequence_id
and source_receipt_id is not null
union
select cwc.receipt_id,
		cwc.line_id,
		cwc.container_type,
		cwc.container_id,
		cwc.waste_code,
		cwc.sequence_id,
		cwc.waste_code_uid,
		wc.display_name
from ContainerWasteCode cwc
inner join WasteCode wc ON cwc.waste_code_uid = wc.waste_code_uid
where cwc.company_id = @company_id
and cwc.profit_ctr_id = @profit_ctr_id
and cwc.receipt_id = @receipt_id
and cwc.line_id = @line_id
and cwc.container_id = @container_id
and cwc.sequence_id = @sequence_id
and source_receipt_id is null

/***
INSERT #tmp_waste (receipt_id, line_id, container_type, container_id, waste_code, sequence_id, waste_code_uid,display_name )
------------------------------------------------------------------------------------------------------
-- Insert container waste codes, if any
------------------------------------------------------------------------------------------------------
SELECT containers.receipt_id,
	containers.line_id,
	containers.container_type,
	containers.container_id,
	cwc.waste_code,
	containers.sequence_id,
	cwc.waste_code_uid,
	wc.display_name
FROM dbo.fn_container_source(@company_id, @profit_ctr_id, @receipt_id, @line_id, @container_id, @sequence_id, @return_self) containers 
INNER JOIN ContainerWasteCode cwc ON containers.destination_company_id = cwc.company_id
	AND containers.destination_profit_ctr_id = cwc.profit_ctr_id
	AND containers.receipt_id = cwc.source_receipt_id
	AND containers.line_id = cwc.source_line_id
	AND containers.container_id = cwc.source_container_id
	AND containers.sequence_id = cwc.source_sequence_id
INNER JOIN WasteCode wc ON cwc.waste_code_uid = wc.waste_code_uid

INSERT #tmp_waste (receipt_id, line_id, container_type, container_id, waste_code, sequence_id, waste_code_uid, display_name)
------------------------------------------------------------------------------------------------------
-- Insert receipt waste codes
------------------------------------------------------------------------------------------------------
SELECT  containers.receipt_id,
	containers.line_id,
	containers.container_type,
	containers.container_id,
	rwc.waste_code,
	containers.sequence_id,
	rwc.waste_code_uid,
	wc.display_name
FROM  dbo.fn_container_source(@company_id, @profit_ctr_id, @receipt_id, @line_id, @container_id, @sequence_id, @return_self) containers 
INNER JOIN ReceiptWasteCode rwc ON containers.company_id = rwc.company_id
	AND containers.profit_ctr_id = rwc.profit_ctr_id
	AND containers.receipt_id = rwc.receipt_id
	AND containers.line_id = rwc.line_id
INNER JOIN WasteCode wc ON rwc.waste_code_uid = wc.waste_code_uid
WHERE NOT EXISTS (SELECT 1 FROM #tmp_waste
	WHERE receipt_id = rwc.receipt_id
	AND line_id = rwc.line_id
	AND container_id = containers.container_id
	AND sequence_id = containers.sequence_id
	)
***/

/*
-- rb 02/11/2014 For stock containers with sequence_id > 1, include waste codes from sequence_id=1
if isnull(@container_type,'') = 'S' and isnull(@sequence_id,0) > 1
	insert #tmp_waste (receipt_id, line_id, container_type, container_id, waste_code, sequence_id, waste_code_uid, display_name)
	select distinct cwc.receipt_id,
	cwc.line_id,
	cwc.container_type,
	cwc.container_id,
	cwc.waste_code,
	cwc.sequence_id,
	cwc.waste_code_uid,
	wc.display_name
	from ContainerWasteCode cwc
	join WasteCode wc ON cwc.waste_code_uid = wc.waste_code_uid
	where cwc.company_id = @company_id
	and cwc.profit_ctr_id = @profit_ctr_id
	and cwc.receipt_id = @receipt_id
	and cwc.line_id = @line_id
	and cwc.container_id = @container_id
	and cwc.container_type = @container_type
	and cwc.sequence_id = 1
*/

IF @debug = 1 PRINT 'Selecting from #tmp_waste'
IF @debug = 1 SELECT * FROM #tmp_waste
IF @debug = 1 SELECT DISTINCT waste_code FROM #tmp_waste

IF @distinct_flag = 'F'
	SELECT distinct receipt_id,
		line_id,
		container_id,
		sequence_id,
		container_type,
		waste_code,
		waste_code_uid,
		display_name
	FROM #tmp_waste
ELSE
	SELECT DISTINCT NULL AS receipt_id,
		NULL AS line_id,
		NULL AS Container_id,
		NULL AS sequence_id,
		NULL AS container_type,
		waste_code,
		waste_code_uid,
		display_name
	FROM #tmp_waste

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_get_container_waste_codes] TO [EQAI]
    AS [dbo];

