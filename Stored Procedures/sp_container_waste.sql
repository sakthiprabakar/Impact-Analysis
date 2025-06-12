CREATE PROCEDURE sp_container_waste 
	@container varchar(15), 
	@container_id int, 
	@sequence_id int,
	@profit_ctr_id int,
	@select_or_insert char(1),
	@debug int,
	@company_id int
AS
/****************
This SP returns the list of waste codes contained in the specified container
Results can be Selected or Inserted into a table declared in a Stored Procedure wrapper (Parent)

Filename:	L:\Apps\SQL\EQAI\sp_container_waste.sql
PB Object(s):	None
SQL Object(s):	None

09/18/2005 SCC	Created
04/29/2013 RB	Waste code conversion, added waste_code_uid to result set
08/29/2013 RB	Waste code conversion phase II, add display_name
09/06/2013 JDB	Added the waste_code_state field to the list of columns returned,
				because the Assign Inbound Container popup needs the state to validate
				the waste codes.
06/24/2014 AM   Moved to plt_ai 
06/26/2014 SM	Added company id
07/22/2014 SM   Changed containerwaste to containerwastecode table
                Changed outer join to inner join on wastecode and where condition on uid
                Added union to bring all the waste codes from consolidation
sp_container_waste '57907-1', 1, 1, 0, 'R', 0,21
******************/
DECLARE @container_receipt_id	int
		, @container_line_id	int
		, @pos					int

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

-- Find waste codes assigned to this container
SELECT DISTINCT 
ContainerWastecode.waste_code, 
ContainerWastecode.receipt_id,
ContainerWastecode.line_id,
ContainerWastecode.container_id,
ContainerWastecode.sequence_id,
ISNULL(WasteCode.waste_code_uid,-1) AS waste_code_uid,
ISNULL(WasteCode.display_name,'') AS display_name,
ISNULL(WasteCode.state, '') AS waste_code_state
INTO #waste
FROM ContainerWastecode
INNER JOIN WasteCode 	ON ContainerWastecode.waste_code_uid = WasteCode.waste_code_uid
WHERE ContainerWastecode.receipt_id = @container_receipt_id
AND ContainerWastecode.line_id = @container_line_id
AND ContainerWastecode.profit_ctr_id = @profit_ctr_id
AND ContainerWastecode.company_id = @company_id
AND (@container_id = 0 OR ContainerWastecode.container_id = @container_id)
AND (@sequence_id = 0 OR ContainerWastecode.sequence_id = @sequence_id)
Union
SELECT DISTINCT 
	ReceiptWasteCode.waste_code ,
	ReceiptWasteCode.receipt_id ,
	ReceiptWasteCode.line_id ,
	ContainerDestination.container_id ,
	ContainerDestination.sequence_id ,
	ReceiptWasteCode.waste_code_uid ,
	WasteCode.display_name as display_name,
	ISNULL(WasteCode.state, '') AS waste_code_state
FROM ContainerDestination (nolock)
INNER JOIN ReceiptWasteCode (nolock) ON ContainerDestination.receipt_id = ReceiptWasteCode.receipt_id
	AND ContainerDestination.line_id = ReceiptWasteCode.line_id
	AND ContainerDestination.company_id = ReceiptWasteCode.company_id
	AND ContainerDestination.profit_ctr_id = ReceiptWasteCode.profit_ctr_id
JOIN WasteCode (nolock) on ReceiptWasteCode.waste_code_uid = WasteCode.waste_code_uid
WHERE ReceiptWasteCode.receipt_id = @container_receipt_id
AND ReceiptWasteCode.line_id = @container_line_id
AND ReceiptWasteCode.profit_ctr_id = @profit_ctr_id 
AND ReceiptWasteCode.company_id = @company_id
AND NOT EXISTS (select 1 from ContainerWasteCode
					where company_id = ContainerDestination.company_id
					and profit_ctr_id = ContainerDestination.profit_ctr_id
					and receipt_id = ContainerDestination.receipt_id
					and line_id = ContainerDestination.line_id
					and container_type = ContainerDestination.container_type
					and container_id = ContainerDestination.container_id
					and sequence_id = ContainerDestination.sequence_id)

IF @debug = 1 print 'Selecting from #waste'
IF @debug = 1 SELECT * FROM #waste order by waste_code, receipt_id, line_id, container_id, sequence_id

-- RETURN WASTE CODES 
-- IF @select_or_insert = 'S'
	SELECT DISTINCT waste_code, waste_code_uid, display_name, waste_code_state
	FROM #waste
	ORDER BY waste_code
-- ELSE
-- 	INSERT #tmp_waste (waste_code)
-- 	SELECT DISTINCT waste_code FROM #waste
-- 	ORDER BY waste_code


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_container_waste] TO [EQAI]
    AS [dbo];

