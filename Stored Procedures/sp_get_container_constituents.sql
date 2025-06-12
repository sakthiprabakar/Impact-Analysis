CREATE PROCEDURE sp_get_container_constituents
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
10/17/2011 JDB	Added missing join on sequence_id
11/04/2013 SM	Fixed join condition to show consolidated constituents only
03/20/2014 RB	Now ignore @sequence_id, return all for entire container (argument should be removed)
06/10/2014 AM  Moved procedure to Plt_AI. Dropping from Plt_XX_AI.
08/05/2020 AM  DevOps:17044 - Adedd set transaction isolation level read uncommitted
sp_get_container_constituents  21,0,0,6600,6600,1,'S','T',0
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

CREATE TABLE #tmp_const 
	(receipt_id		int		NULL, 
	line_id			int		NULL, 
	container_type	char(1) NULL, 
	container_id	int		NULL, 
	const_id		int		NULL,
	UHC				char(1) NULL,
	sequence_id		int		NULL)

IF @debug = 1 PRINT 'Container:  ' + CONVERT(varchar, @receipt_id) 
	+ '-' + CONVERT(varchar, @line_id) 
	+ '-' + CONVERT(varchar, @container_id)  
	+ '-' + CONVERT(varchar, @sequence_id) 

-- rb 03/07/2014 ContainerConstituent should now contain all consolidated containers
INSERT #tmp_const (receipt_id, line_id, container_type, container_id, const_id, UHC, sequence_id)
------------------------------------------------------------------------------------------------------
-- Insert container constituents, if any
------------------------------------------------------------------------------------------------------
/*SELECT cc.source_receipt_id,
	cc.source_line_id,
	cc.container_type,
	cc.source_container_id,
	cc.const_id,
	cc.UHC,
	cc.source_sequence_id
FROM ContainerConstituent cc (nolock)
JOIN Constituents c (nolock) on cc.const_id = c.const_id and c.const_desc <> 'NONE'
WHERE cc.company_id = @company_id
AND cc.profit_ctr_id = @profit_ctr_id
AND cc.receipt_id = @receipt_id
AND cc.line_id = @line_id
AND cc.container_id = @container_id
--AND sequence_id = @sequence_id
AND cc.container_type = @container_type
AND cc.source_line_id is not null
union*/
select cc.source_receipt_id,
		cc.source_line_id,
		cc.container_type,
		cc.source_container_id,
		cc.const_id,
		cc.UHC,
		cc.source_sequence_id
from ContainerConstituent cc (nolock)
inner join Constituents c (nolock) ON cc.const_id = c.const_id
where cc.company_id = @company_id
and cc.profit_ctr_id = @profit_ctr_id
and cc.receipt_id = @receipt_id
and cc.line_id = @line_id
and cc.container_id = @container_id
--and cc.sequence_id = @sequence_id
and source_receipt_id is not null
union
select cc.receipt_id,
		cc.line_id,
		cc.container_type,
		cc.container_id,
		cc.const_id,
		cc.UHC,
		cc.sequence_id
from ContainerConstituent cc (nolock)
inner join Constituents c (nolock) ON cc.const_id = c.const_id
where cc.company_id = @company_id
and cc.profit_ctr_id = @profit_ctr_id
and cc.receipt_id = @receipt_id
and cc.line_id = @line_id
and cc.container_id = @container_id
and cc.sequence_id = @sequence_id
and source_receipt_id is null

/***
INSERT #tmp_const (receipt_id, line_id, container_type, container_id, const_id, UHC, sequence_id)
------------------------------------------------------------------------------------------------------
-- Insert container constituents, if any
------------------------------------------------------------------------------------------------------
SELECT containers.receipt_id,
	containers.line_id,
	containers.container_type,
	containers.container_id,
	cc.const_id,
	cc.UHC,
	containers.sequence_id
FROM  dbo.fn_container_source(@company_id, @profit_ctr_id, @receipt_id, @line_id, @container_id, @sequence_id, @return_self) containers 
INNER JOIN ContainerConstituent cc ON containers.destination_company_id = cc.company_id
	AND containers.destination_profit_ctr_id = cc.profit_ctr_id
	AND containers.receipt_id = cc.source_receipt_id
	AND containers.line_id = cc.source_line_id
	AND containers.container_id = cc.source_container_id
	AND containers.sequence_id = cc.source_sequence_id
--UNION

INSERT #tmp_const (receipt_id, line_id, container_type, container_id, const_id, UHC, sequence_id)
------------------------------------------------------------------------------------------------------
-- Insert Receipt Constituents
------------------------------------------------------------------------------------------------------
SELECT  containers.receipt_id,
	containers.line_id,
	containers.container_type,
	containers.container_id,
	rc.const_id,
	rc.UHC,
	containers.sequence_id
FROM  dbo.fn_container_source(@company_id, @profit_ctr_id, @receipt_id, @line_id, @container_id, @sequence_id, @return_self) containers 
INNER JOIN ReceiptConstituent rc ON containers.company_id = rc.company_id
	AND containers.profit_ctr_id = rc.profit_ctr_id
	AND containers.receipt_id = rc.receipt_id
	AND containers.line_id = rc.line_id
WHERE NOT EXISTS (SELECT 1 FROM #tmp_const 
	WHERE receipt_id = rc.receipt_id
	AND line_id = rc.line_id
	AND container_id = containers.container_id
	AND sequence_id = containers.sequence_id
	)
***/

/*
-- rb 02/11/2014 For stock containers with sequence_id > 1, include waste codes from sequence_id=1
if isnull(@container_type,'') = 'S' and isnull(@sequence_id,0) > 1
	insert #tmp_const
	select distinct cc.receipt_id,
		cc.line_id,
		@container_type,
		cc.container_id,
		cc.const_id,
		cc.UHC,
		cc.sequence_id
	from ContainerConstituent cc
	where cc.company_id = @company_id
	and cc.profit_ctr_id = @profit_ctr_id
	and cc.receipt_id = @receipt_id
	and cc.line_id = @line_id
	and cc.container_id = @container_id
	and cc.container_type = @container_type
	and cc.sequence_id = 1
*/

IF @debug = 1 PRINT 'Selecting from #tmp_const'
IF @debug = 1 SELECT * FROM #tmp_const
IF @debug = 1 SELECT distinct const_id FROM #tmp_const

IF @distinct_flag = 'F' 
	SELECT distinct receipt_id,
		line_id, 
		container_id,
		sequence_id,
		container_type,
		#tmp_const.const_id,
		Constituents.const_desc,
		UHC,
		ldr_id
	FROM #tmp_const
	JOIN Constituents ON #tmp_const.const_id = Constituents.const_id
ELSE
	SELECT DISTINCT  NULL AS receipt_id, 
		NULL AS Line_id, 
		NULL AS container_id, 
		NULL AS sequence_id, 
		NULL AS container_type, 
		#tmp_const.const_id,
		Constituents.const_desc,
		UHC,
		ldr_id 
	FROM #tmp_const 
	JOIN Constituents ON #tmp_const.const_id = Constituents.const_id

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_get_container_constituents] TO [EQAI]
    AS [dbo];

