CREATE PROCEDURE [dbo].[sp_load_in_transit_receipt] 
	@company_id int,
	@profit_ctr_id int,
	@source_company_id int,
	@source_profit_ctr_id int,
	@source_id int,
	@source_type char(1),
	@source_manifest varchar(15),
	@source_manifest_flag char(1),
	@dest_company_id int,
	@dest_profit_ctr_id int,
	@db_type varchar(4),
	@debug int
AS
-- LOAD TO PLT_AI 

-- 02/01/06 SCC Created
-- 05/30/06 SCC Modified to support Transfers
-- 06/30/06 RG  Modified for approval to Profile.  TSDF is an eq so profile
-- 10/12/06 SCC Fixed Join to Profile.  Added db_type to all DB retrieves.
-- 02/01/07 SCC Fixed to select Transfer Detail manifest instead of Transfer receipt doc/manifest
-- 07/30/07 SCC Retrieve In-Transit TRANSFER to another facility
-- 12/12/07  rg   fixed to proces by manifest
-- 01/30/08 rg  revised to convert manifest line to int for better sorting
-- 02/26/08 rg  revised to convert wodmanifest_unit to a true manifest unit using the billunit table
-- 10/19/10 KAM  updated to get the unit and qty from the correct table
-- 01/18/11 JDB  Updated to get generator_id from workorderheader
-- 02/15/11 SK	 Updated to use customerID from OB receipt for receipts with manifestflag of 'M','C','B'

-- sp_load_in_transit_receipt 2, 21, 21, 1, 2809, 'R', '002745391JJK','X',2,21, 'DEV', 1
-- sp_load_in_transit_receipt 21, 0, 14, 0, 13705400, 'W', 'JASON001', 'M', 21, 0, 'TEST', 1

DECLARE
	@database_name varchar(20),
	@database_name_suffix varchar(4),
	@server_name varchar(10),
	@process_count int,
	@sql varchar(8000)

-- Create a table to hold the results
CREATE TABLE #tmp_results (
	line_id int NOT NULL,
	approval_code varchar(40) NULL,
	manifest varchar(15) NULL,
	manifest_line_id int NULL,
	manifest_page_num int NULL,
	manifest_quantity float NULL,
	manifest_unit char(1) NULL,
	quantity float NULL,
	container_count int NULL,
	price_id int NULL,
	bill_quantity float NULL,
	bill_unit_code varchar(4) NULL,
	customer_id int NULL,
	generator_id int NULL,
	include int NULL,
	customer_name varchar(40) NULL,
	generator_name varchar(40) NULL,
	generator_EPA_ID varchar(12) NULL,
	tsdf_code varchar(15) NULL,
	destination_company_id int NULL,
	destination_profit_ctr_id int NULL,
	profile_id int null,
	drmo_clin_num int NULL,
	drmo_hin_num int NULL,
	drmo_doc_num int NULL,
	ib_receipt_id int null,
	ib_line_id int null,
	ib_co_id int null,
	ib_pc_id int null
)

-- Get the database to query for the source
SELECT	@database_name = D.database_name,
	@server_name = D.server_name
FROM	EQConnect C, EQDatabase D
WHERE	C.db_name_eqai = D.database_name
	AND C.db_type = D.db_type
	AND C.db_type = @db_type
	AND C.company_id = @source_company_id

-- This is an Outbound Disposal Receipt
IF @source_type = 'R' AND @source_manifest_flag IN ('M','C','B')
BEGIN
	SET @sql = 'INSERT #tmp_results SELECT DISTINCT 
	OB.line_id, 
	OB.tsdf_approval_code, 
	OB.manifest, 
	dbo.fn_convert_manifest_line(OB.manifest_line_id, OB.manifest_page_num),
	OB.manifest_page_num, 
	OB.manifest_quantity,
	OB.manifest_unit, 
	OB.quantity, 
	OB.container_count,
	RP.price_id,
	COALESCE(RP.bill_quantity,OB.quantity),
	RP.bill_unit_code,
	OB.customer_id AS customer_id,
	0 AS generator_id,
	1 AS include,
	'''',
	'''',
	'''',
	TSDF.tsdf_code,
	TSDF.eq_company AS destination_company_id,
	TSDF.eq_profit_ctr AS destination_profit_ctr_id,
        OB.profile_id, 
	NULL AS drmo_clin_num, 
	NULL AS drmo_hin_num, 
	NULL AS drmo_doc_num,
    ob.receipt_id,
    ob.line_id,
    ob.company_id,
    ob.profit_ctr_id	
	FROM Receipt OB,
	ReceiptPrice RP, 
	TSDF TSDF 
	WHERE OB.trans_mode = ''O'' 
	AND OB.trans_type IN (''D'')
	AND OB.receipt_status = ''A''
	AND OB.company_id = RP.company_id
	AND OB.profit_ctr_id = RP.profit_ctr_id
	AND OB.receipt_id = RP.receipt_id
	AND OB.line_id = RP.line_id
	AND OB.company_id = ' + CONVERT(varchar(2), @source_company_id) + '
	AND OB.profit_ctr_id = ' + CONVERT(varchar(2), @source_profit_ctr_id) + '
	AND OB.receipt_id = ' + CONVERT(varchar(20), @source_id) + '
	AND OB.manifest = ''' + @source_manifest + '''
	AND OB.tsdf_code IS NOT NULL
	AND OB.tsdf_code = TSDF.tsdf_code
	AND ISNULL(TSDF.eq_flag,''F'') = ''T''
	'
END

-- This is an Outbound Transfer that is going on to another facility
ELSE IF @source_type = 'R' AND @source_manifest_flag = 'X' AND NOT
	(@company_id = @dest_company_id AND @profit_ctr_id = @dest_profit_ctr_id)
BEGIN
	SET @sql = 'INSERT #tmp_results '
	+ ' SELECT DISTINCT ' 
        + '     c.line_id , '
	+ ' rc.approval_code , '
	+ ' c.manifest , '
	+ ' rc.manifest_line_id, '
	+ ' ISNULL(ib.manifest_page_num,1) AS manifest_page_num, '
	+ ' rc.manifest_quantity, '
	+ ' rc.manifest_unit, '
	+ ' rc.container_count, '
	+ ' rc.container_count , '
	+ ' NULL AS price_id , '
	+ ' NULL AS billqty, '
	+ ' NULL AS bill_unit_code, '
	+ ' 0 AS customer_id, '
	+ ' 0 AS generator_id, '
	+ ' 1 AS include, '
	+ ' '''' AS customer_name, '
	+ ' '''' AS generator_name, '
	+ ' '''' AS generator_EPA_ID, '
	+ ' ib.tsdf_code, '
	+ ' tsdf.eq_company AS destination_company_id , '
	+ ' tsdf.eq_profit_ctr AS destination_profit_ctr_id , '
    + '     ib.profile_id, '
	+ ' null AS drmo_clin_num , '
	+ ' null AS drmo_hin_num , '
	+ ' null AS drmo_doc_num, '
    + ' ib.receipt_id, '
    + ' ib.line_id, '
    + ' ib.company_id, '
    + ' ib.profit_ctr_id	'
+ ' FROM Container c '
+ ' inner join ContainerDestination cd on cd.receipt_id = c.receipt_id '
+ '        and cd.line_id = c.line_id '
+ '        and cd.profit_ctr_id = c.profit_ctr_id '
+ '        and cd.company_id = c.company_id '
+ '        and cd.container_id = c.container_id '
+ '        and cd.location_type = ''O'' '
+ ' inner join Receipt ib on c.receipt_id = ib.receipt_id '
+ '        and c.line_id = ib.line_id '
+ '        and c.profit_ctr_id = ib.profit_ctr_id '
+ '        and c.company_id = ib.company_id '
+ ' inner join ReceiptCommingled rc on c.receipt_id = rc.receipt_id '
+ '        and c.line_id = rc.line_id '
+ '        and c.profit_ctr_id = rc.profit_ctr_id '
+ '        and c.company_id = rc.company_id '
+ '        and c.manifest = rc.manifest '
+ ' inner join Receipt ob on cd.tracking_num =  ( convert(varchar(10), ob.receipt_id) + ''-'' + convert(varchar(4),ob.line_id) ) '
+ '        and cd.profit_ctr_id = ob.profit_ctr_id '
+ '        and cd.company_id = ob.company_id '
+ ' inner join TSDF TSDF on ib.tsdf_code = tsdf.tsdf_code  '
+ ' WHERE ob.trans_mode = ''O'' '
	+ ' AND ob.trans_type = ''X'' '
	+ ' AND ob.receipt_status = ''A'' '
	+ ' AND ob.company_id = ' + CONVERT(varchar(10), @source_company_id)
	+ ' AND ob.profit_ctr_id = ' + CONVERT(varchar(10), @source_profit_ctr_id)
	+ ' AND ob.receipt_id = ' + CONVERT(varchar(20), @source_id)
	+ ' AND c.manifest = ' + '''' + @source_manifest + ''''
END


-- This is an Outbound Transfer where this facility is the final destination
ELSE IF @source_type = 'R' AND @source_manifest_flag = 'X' AND 
	(@company_id = @dest_company_id AND @profit_ctr_id = @dest_profit_ctr_id)
BEGIN
	SET @sql = 'INSERT #tmp_results '
	+ ' SELECT DISTINCT  '
	+ ' OB.line_id,  '
	+ ' RC.approval_code, ' 
	+ ' rc.manifest,  '
	+ ' rc.manifest_line_id,  '
	+ ' 1 AS manifest_page_num,  '
	+ ' RC.manifest_quantity, '
	+ ' RC.manifest_unit,  '
	+ ' RC.container_count,  '
	+ ' RC.container_count, '
	+ ' NULL AS price_id, '
	+ ' NULL AS bill_quantity, '
	+ ' NULL AS bill_unit_code, '
	+ ' 0 AS customer_id, '
	+ ' 0 AS generator_id, '
	+ ' 1 AS include, '
    + ' '''',  '
    + ' '''',  '
    + ' '''', '
	+ ' TSDF.tsdf_code, '
	+ ' TSDF.eq_company AS destination_company_id, '
	+ ' TSDF.eq_profit_ctr AS destination_profit_ctr_id, '
    + '     RC.profile_id,  '
	+ ' NULL AS drmo_clin_num,  '
	+ ' NULL AS drmo_hin_num,  '
	+ ' NULL AS drmo_doc_num,  '
	+ ' ob.receipt_id, '
    + ' ob.line_id, '
    + ' ob.company_id, '
    + ' ob.profit_ctr_id	'
	+ ' FROM Receipt ob  '
	+ ' inner join ContainerDestination cd on cd.tracking_num = CONVERT(varchar(20),OB.receipt_id) + ''-'' + CONVERT(varchar(10), OB.line_id) '
    + '     	AND cd.location_type = ''O'' '
    + '         AND cd.company_id = ob.company_id '
	+ ' inner join Container c on c.profit_ctr_id = cd.profit_ctr_id '
	+ ' 	AND c.company_id = cd.company_id '
	+ ' 	AND c.receipt_id = cd.receipt_id '
	+ ' 	AND c.line_id = cd.line_id '
	+ ' 	AND c.container_id = cd.container_id '
	+ ' inner join ReceiptCommingled rc on c.profit_ctr_id = RC.profit_ctr_id '
	+ ' 	AND c.company_id = RC.company_id '
	+ ' 	AND c.receipt_id = RC.receipt_id '
	+ ' 	AND c.line_id = RC.line_id '
	+ ' inner join TSDF TSDF on ob.tsdf_code = TSDF.tsdf_code '
	+ ' WHERE ob.trans_mode = ''O'' '
	+ ' AND ob.trans_type = ''X'' '
	+ ' AND ob.receipt_status = ''A'' '
	+ ' AND ob.company_id = ' + CONVERT(varchar(10), @source_company_id)
	+ ' AND ob.profit_ctr_id = ' + CONVERT(varchar(10), @source_profit_ctr_id)
	+ ' AND ob.receipt_id = ' + CONVERT(varchar(20), @source_id)
	+ ' AND rc.manifest = ' + '''' + @source_manifest + ''''
	+ ' AND TSDF.eq_company = ' + convert(varchar(4) , @dest_company_id)
	+ ' AND TSDF.eq_profit_ctr = ' + convert(varchar(4) , @dest_profit_ctr_id)
END

-- This is a Work Order
-- the manifest unit on a workorder is really the bill unt so we need to convert it to a real manifest unit.
-- rg022608 
ELSE
BEGIN
	SET @sql = 'INSERT #tmp_results SELECT DISTINCT 
	WOD.sequence_id, 
	WOD.tsdf_approval_code, 
	WOD.manifest, 
	WOD.manifest_line, 
	WOD.manifest_page_num, 
	WODU2.quantity,
	bu.manifest_unit, 
	WODU.quantity, 
	WOD.container_count,
	1 AS price_id,
	WODU.quantity,
	WODU.bill_unit_code,
	woh.customer_id,
	woh.generator_id,
	1 AS include,
	'''',
	'''',
	'''',
	TSDF.tsdf_code,
	TSDF.eq_company AS destination_company_id,
	TSDF.eq_profit_ctr AS destination_profit_ctr_id,
        WOD.profile_id, 
	WOD.drmo_clin_num, 
	WOD.drmo_hin_num, 
	WOD.drmo_doc_num,
    wod.workorder_id,
    wod.sequence_id, 
    wod.company_id, 
    wod.profit_ctr_id		
	FROM WorkOrderDetail WOD 
	INNER JOIN WorkOrderHeader woh ON woh.company_id = wod.company_id
		AND woh.profit_ctr_id = wod.profit_ctr_id
		AND woh.workorder_id = wod.workorder_id
	Left Outer join TSDF on WOD.tsdf_code = TSDF.tsdf_code 
		AND ISNULL(TSDF.eq_flag,''F'') = ''T''
	LEFT Outer Join  WorkorderDetailUnit WODU on  WOD.company_id = WODU.company_id
			and WOD.profit_ctr_id = WODU.profit_ctr_id
			and WOD.Workorder_id = WODU.workorder_id
			AND WOD.Sequence_id = WODU.sequence_id
			AND WODU.billing_flag = ''T''
	LEFT outer Join WorkorderDetailUnit WODU2 on WOD.company_id = WODU2.company_id
			and WOD.profit_ctr_id = WODU2.profit_ctr_id
			and WOD.Workorder_id = WODU2.workorder_id
			AND WOD.Sequence_id = WODU2.sequence_id
			AND WODU2.manifest_flag = ''T''
	Left Outer Join BillUnit bu  on WODU2.bill_unit_code = bu.bill_unit_code
	WHERE WOD.resource_type = ''D'' 
	AND WOD.company_id = ' + CONVERT(varchar(2), @source_company_id) + '
	AND WOD.profit_ctr_id = ' + CONVERT(varchar(2), @source_profit_ctr_id) + '
	AND WOD.workorder_id = ' + CONVERT(varchar(20), @source_id) + '
	AND WOD.manifest = ''' + @source_manifest + '''
	AND WOD.tsdf_code IS NOT NULL
	AND WOD.bill_rate > -2
'	
END
	
IF @debug = 1 PRINT @sql
EXECUTE (@sql)

-- Update with customer IDs for the destination company
SELECT	@database_name = D.database_name, 
	@server_name = D.server_name
FROM	EQConnect C, EQDatabase D
WHERE	C.db_name_eqai = D.database_name
	AND C.db_type = D.db_type
	AND C.db_type = @db_type
	AND C.company_id = @dest_company_id

SET @sql = 'UPDATE #tmp_results SET 
	customer_id = ISNULL(#tmp_results.customer_id, Profile.customer_id),
	generator_id = ISNULL(#tmp_results.generator_id, Profile.generator_id),
	customer_name = Customer.cust_name,
	generator_name = Generator.generator_name,
	generator_EPA_ID = Generator.EPA_ID 
	FROM Profile Profile, 
	ProfileQuoteApproval ProfileQuoteApproval, 
	Customer Customer, 
	Generator Generator '
	+ ' WHERE Profile.profile_id = ProfileQuoteApproval.profile_id '
	+ ' AND Profile.curr_status_code = ''A'' '
	+ ' AND ProfileQuoteApproval.status = ''A'' '
	+ ' AND ProfileQuoteApproval.company_id = ' + CONVERT(varchar(2), @dest_company_id)
	+ ' AND ProfileQuoteApproval.profit_ctr_id = ' + CONVERT(varchar(2), @dest_profit_ctr_id)
	+ ' AND ProfileQuoteApproval.approval_code = #tmp_results.approval_code '
	+ ' AND Profile.customer_id = Customer.customer_id '
	+ ' AND Profile.generator_id = Generator.generator_id '
-- IF @debug = 1 PRINT @sql
EXECUTE (@sql)

-- Return the results
SELECT * FROM #tmp_results ORDER BY manifest, manifest_page_num, manifest_line_id, line_id, price_id, bill_unit_code

DROP TABLE #tmp_results

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_load_in_transit_receipt] TO [EQAI]
    AS [dbo];

