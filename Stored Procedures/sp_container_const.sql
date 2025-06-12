/****************
This SP returns the list of constituents contained in the specified container
Results can be Selected or Inserted into a table declared in a Stored Procedure wrapper (Parent)

Filename:	L:\Apps\SQL\EQAI\sp_container_const.sql
PB Object(s):	None
SQL Object(s):	None

09/18/2005 SCC Created
07/06/2014 SM	Moved to plt_ai

sp_container_const '601701-1', 1, 1, 0, 'S', 1

******************/
CREATE PROCEDURE sp_container_const 
	@container varchar(15), 
	@container_id int, 
	@sequence_id int,
	@profit_ctr_id int,
	@company_id int,
	@select_or_insert char(1),
	@debug int
AS

DECLARE 
@container_receipt_id int,
@container_line_id int,
@pos int

-- What kind of container, Stock or Receipt?
IF SUBSTRING(@container,1,3) = 'DL-' 
BEGIN
	SET @container_receipt_id = 0
	SET @container_line_id = CONVERT(int, SUBSTRING(@container, LEN(@container) - 5, 6))
END
ELSE
BEGIN
	SET @pos = CHARINDEX('-', @container, 1)
	IF @pos > 0
	BEGIN
		SET @container_receipt_id = CONVERT(INT, SUBSTRING(@container, 1, @pos - 1)) 
		SET @container_line_id = CONVERT(INT, SUBSTRING(@container, @pos + 1, LEN(@container) - @pos))
	END
END
IF @debug = 1 PRINT 'Container receipt_id: ' + CONVERT(varchar(15), @container_receipt_id)+ ' and Container line_id: ' + convert(varchar(15), @container_line_id)

-- Find const codes assigned to this container
SELECT DISTINCT 
ContainerConst.const_id, 
ContainerConst.UHC, 
ContainerConst.receipt_id,
ContainerConst.line_id,
ContainerConst.container_id,
ContainerConst.sequence_id,
ContainerConst.source
INTO #const
FROM ContainerConst
WHERE ContainerConst.receipt_id = @container_receipt_id
AND ContainerConst.line_id = @container_line_id
AND ContainerConst.profit_ctr_id = @profit_ctr_id
AND ContainerConst.company_id = @company_id
AND (@container_id = 0 OR ContainerConst.container_id = @container_id)
AND (@sequence_id = 0 OR ContainerConst.sequence_id = @sequence_id)

IF @debug = 1 print 'Selecting from #const'
IF @debug = 1 SELECT * FROM #const order by const_id, receipt_id, line_id, container_id, sequence_id

-- RETURN const CODES 
-- IF @select_or_insert = 'S'
	SELECT DISTINCT const_id, UHC FROM #const
	ORDER BY const_id
-- ELSE
-- 	INSERT #tmp_const (const_id, UHC)
-- 	SELECT DISTINCT const_id, UHC FROM #const
-- 	ORDER BY const_id


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_container_const] TO [EQAI]
    AS [dbo];

