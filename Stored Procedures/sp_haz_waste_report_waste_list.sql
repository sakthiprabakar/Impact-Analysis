CREATE PROCEDURE sp_haz_waste_report_waste_list 
	@company_id		int
,	@profit_ctr_id	int
,	@receipt_id		int
,	@line_id		int
AS
/**************************************************************************************
This SP returns the list of container waste codes

Filename:	L:\Apps\SQL\EQAI\sp_haz_waste_export_waste_list.sql
PB Object(s):	d_haz_waste_export_waste_list

02/15/2006 MK	Created - based on sp_container_waste_list
07/30/2008 JDB	Replaced Receipt.outbound_kilograms field with a calculation based
				on manifest_quantity and BillUnit.kg_conv, and renamed
				un_na_number to manifes_un_na_number.
07/31/2008 KAM  Updated the procedure to only return the top 6 waste codes for each receipt_line.
11/03/2010 SK	Added Company_ID as input argument
				moved to Plt_AI

sp_haz_waste_export_waste_list 'STABLEX','141722',3264,0,'01/01/2005','12/31/2005'
**************************************************************************************/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

DECLARE	
	@count_waste_codes	int,
	@pos				int,
	@waste_code_list	varchar(8000),
	@waste_code			varchar(4)

SET ROWCOUNT 0
-- Get the waste codes for this container
SELECT DISTINCT rw.waste_code, 0 AS process_flag 
INTO #tmp_waste
FROM  ReceiptWasteCode rw
WHERE rw.receipt_id = @receipt_id
	AND rw.line_id = @line_id
	AND rw.profit_ctr_id = @profit_ctr_id
	AND rw.company_id = @company_id

-- AND r.prenote_canada = @prenote
-- AND r.tsdf_code = @tsdf_code
-- AND ISNULL(r.manifest_un_na_number, 0) = @un_na_number
-- AND r.profit_ctr_id = @profit_ctr_id
-- AND r.receipt_date BETWEEN @start_date AND @end_date
   AND rw.sequence_id BETWEEN 1 and 6
-- AND r.receipt_id = @receipt_id
-- and r.line_id = @line_id
-- AND r.tsdf_approval_code IN 
-- 	(SELECT DISTINCT r.tsdf_approval_code
-- 	FROM receipt r, 
-- 	tsdf t,
-- 	tsdfapproval ta
-- 	WHERE r.tsdf_code = ta.tsdf_code
-- 	AND r.profit_ctr_id = ta.profit_ctr_id
-- 	AND r.tsdf_approval_code = ta.tsdf_approval_code
-- 	AND r.customer_id = ta.customer_id
-- 	AND r.waste_stream = ta.waste_stream
-- 	AND r.bill_unit_code = ta.bill_unit_code
-- 	AND r.trans_mode = 'O'
-- 	AND r.receipt_status = 'A'
-- 	AND r.profit_ctr_id = @profit_ctr_id
-- 	AND r.receipt_date BETWEEN @start_date AND @end_date
-- 	AND LEFT(t.tsdf_zip_code,1) BETWEEN 'a' AND 'Z')
-- 	AND r.line_id = rw.line_id


SELECT @count_waste_codes = COUNT(waste_code) FROM #tmp_waste

-- Build the string of waste codes
SET @waste_code_list = ''
SET ROWCOUNT 1
WHILE @count_waste_codes > 0
BEGIN
	SELECT @waste_code = waste_code FROM #tmp_waste WHERE process_flag = 0
	SELECT @pos = CHARINDEX(@waste_code, @waste_code_list)
	IF @waste_code_list = ''
		SET @waste_code_list = @waste_code
	ELSE
		IF @pos = 0
			SET @waste_code_list = @waste_code_list + ', ' + @waste_code

	UPDATE #tmp_waste SET process_flag = 1 WHERE process_flag = 0
	SET @count_waste_codes = @count_waste_codes - 1
END

SET ROWCOUNT 0

UPDATE #output SET waste_codes = @waste_code_list
WHERE receipt_id = @receipt_id
	AND line_id = @line_id
	AND profit_ctr_id = @profit_ctr_id
	AND company_id = @company_id


SET ROWCOUNT 1

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_haz_waste_report_waste_list] TO [EQAI]
    AS [dbo];

