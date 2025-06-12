
/****************
This SP returns the list of container waste codes

Filename:	L:\Apps\SQL\EQAI\sp_container_waste_list.sql
PB Object(s):	d_container_entry_waste_code_list
SQL Object(s):	Calls sp_container_match_waste_consolidated

12/19/2003 SCC	Created
12/16/2004 SCC	Modified for Container Tracking
04/14/2005 JDB	Added bill_unit_code for TSDFApproval
09/12/2005 SCC	Added retrieval by input container ID
09/19/2005 SCC	Rewrote to use new no-drill-down waste code retrieval
09/27/2013 RWB	Added waste_code_uid and display_name to #tmp_waste results
06/23/2014 SM	Moved to plt_AI and added company_id

sp_container_waste_list 'DL-2200-003703', 3703, 1, 0, 1,1
sp_container_waste_list 624149, 2, 1, 1, 0, 1,1

******************/
CREATE PROCEDURE sp_container_waste_list 
	@receipt_id int,
	@line_id int,
	@container_id int,
	@sequence_id int,
	@profit_ctr_id int, 
	@debug int,
	@company_id int
AS
DECLARE	@count_waste_codes int,
	@pos int,
	@waste_code_list varchar(8000),
	@waste_code varchar(10)

-- Get the waste codes for this container
SELECT DISTINCT cw.waste_code, 0 as process_flag, cw.waste_code_uid, wc.display_name
INTO #tmp_waste
FROM ContainerWaste cw
join WasteCode wc on cw.waste_code_uid = wc.waste_code_uid
WHERE cw.receipt_id = @receipt_id
AND cw.line_id = @line_id
AND cw.container_id = @container_id
AND cw.sequence_id = @sequence_id
AND cw.profit_ctr_id = @profit_ctr_id
AND cw.company_id = @company_id

SELECT @count_waste_codes = count(waste_code) FROM #tmp_waste

-- Build the string of waste codes
SET @waste_code_list = ''
SET ROWCOUNT 1
WHILE @count_waste_codes > 0
BEGIN
	--SELECT @waste_code = waste_code FROM #tmp_waste WHERE process_flag = 0
	SELECT @waste_code = display_name FROM #tmp_waste WHERE process_flag = 0
	SELECT @pos = CHARINDEX(@waste_code, @waste_code_list)
	IF @waste_code_list = ''
		SET @waste_code_list = @waste_code
	ELSE
		IF @pos = 0
			SET @waste_code_list = @waste_code_list + ',' + @waste_code

	UPDATE #tmp_waste SET process_flag = 1 WHERE process_flag = 0
	SET @count_waste_codes = @count_waste_codes - 1
END
SET ROWCOUNT 0
SELECT @waste_code_list as waste_code_list


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_container_waste_list] TO [EQAI]
    AS [dbo];

