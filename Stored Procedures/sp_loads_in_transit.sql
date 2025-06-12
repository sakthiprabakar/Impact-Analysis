CREATE PROCEDURE sp_loads_in_transit
	@company_ID int,
	@profit_ctr_id int,
	@source_company_id int,
	@date_from datetime,
	@date_to datetime,
	@manifest varchar(15),
	@db_type varchar(4),
	@show_all_or_new int,
	@load_type char(1),
	@debug int
AS
-- LOAD TO PLT_AI

-- 01/31/06 SCC Created
-- 05/15/06 SCC	Modified to include Receipt Transfers
-- 07/26/06 SCC	Added load_type of 'A' for ALL so the reports would run for disposal and transfer loads
-- 10/13/06 SCC Transfer check for match to company and profit center needed to be OR, not AND
-- 11/09/06 SCC Removed nasty NOT EXIST statements from main query, added update from single server/database to improve performance
-- 02/01/07 SCC Fixed to select Transfer Detail manifest isntead of Transfer receipt doc/manifest
-- 06/12/07 SCC Fixed to match the TSDF company and profit center to match the company asking for In-Transit loads
-- 07/27/07 SCC Show pass-thru transfers and final dest transfers.
-- 11/27/07 rg  removed @servername and added source_line _id
-- 02/20/08 rg  removed soruce line from update for already_used to test
-- 02/03/09 KAM since the tables have been moved to plt_ai there is no need to go to the company DB and loop through
-- 03/20/09 KAM Returned the line_id to always be one as this is now unused functionality and was causing the window to show duplicates
-- 12/20/10 KAM Updated for new Work Order tables
-- 05/07/12 RWB Set transaction isolation level to eliminate blocking issues
-- 07/09/2014 SK modified the Company ID connected information query for #tmp_this_company
-- 05/16/17	MPM	Rewrote dynamic SQL strings to replace "*=" with "left outer join" syntax.
-- 05/09/20 MPM DevOps 15456 - Added corporate_revenue_classification_uid to result set.

-- BLOCKNUM Identifiers:
--	1 = Outbound Disposal loads to this EQ TSDF (company_id and profit_ctr_id)
--	2 = Transfers where final TSDF is this EQ TSDF - turns into a disposal
--	3 = WorkOrder Disposal to this EQ TSDF
--	4 = Pass-Thru Transfers

-- sp_loads_in_transit 21, 0, 14, '02/01/2008', '02/28/2008', 'ALL', 'TEST', 0, 'A', 1
-- sp_loads_in_transit 21, 0, 14, '7/27/2010', '01/03/2011', 'ALL', 'DEV', 0, 'R', 1
/*
sp_loads_in_transit 21, 0, 14, '02/01/2008', '02/28/2008', 'ALL', 'TEST', 0, 'A', 0
sp_loads_in_transit_MPM 21, 0, 14, '02/01/2008', '02/28/2008', 'ALL', 'TEST', 0, 'A', 0
*/
-- 05/07/12 RWB Set transaction isolation level to eliminate blocking issues
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

DECLARE
	@database_name varchar(20),
	@server_name varchar(10),
	--@this_database_name varchar(20),
	--@this_server_name varchar(10),
	@process_count int,
	@sql varchar(8000),
	--@share_database varchar(10),
	@this_profit_ctr_name varchar(50),
	@show_all int,
	@show_new int

-- Create a table to hold this company info
CREATE TABLE #tmp_this_company (
	company_name varchar(35) NULL,
	profit_ctr_name varchar(50) NULL
)

-- Create a table to hold the results
CREATE TABLE #tmp_results (
	block_num int NULL,
	source_company_id int NOT NULL,
	source_profit_ctr_id int NOT NULL,
	source_customer_id int NULL,
	source_manifest varchar(15) NULL,
	source_manifest_flag char(1) NULL,
	source_id int NULL,
	source_line_id int NULL,
	source_date datetime NULL,
	source_type char(1) NULL,
	source_transporter_code varchar(15) NULL,
	source_company_name varchar(35) NULL,
	source_profit_ctr_name varchar(50) NULL,
	source_customer_name varchar(40) NULL,
	source_transporter_name varchar(40) NULL,
	destination_company_id int NULL,
	destination_profit_ctr_id int NULL,
	already_received int NULL,
	corporate_revenue_classification_uid int NULL
)

-- Get the databases to query
SELECT	C.company_id,
	D.database_name,
	D.server_name,
	0 as process_flag
INTO #tmp_database
FROM	EQConnect C,
	EQDatabase D
WHERE	C.db_name_eqai = D.database_name
	AND C.db_type = D.db_type
	AND C.db_type = @db_type
	AND (@source_company_id = 0 OR C.company_id = @source_company_id)

SET @process_count = @@rowcount

IF @debug = 1 print 'Inter-company databases:'
IF @debug = 1 SELECT * FROM #tmp_database

---- Setup share database name
--SET @share_database = 'PLT_AI'

-- Show?
SET @show_all = 0
SET @show_new = 1

-- Initialize for this company
--SELECT @this_database_name = D.database_name,  
--	@this_server_name = D.server_name 
--FROM	EQConnect C, 	EQDatabase D
--WHERE	C.db_name_eqai = D.database_name
--	AND C.db_type = D.db_type
--	AND C.db_type = @db_type
--	AND C.company_id = @company_id

--SET @sql = 'INSERT #tmp_this_company SELECT Company.company_name, ProfitCenter.profit_ctr_name FROM '
--	+ @this_database_name + '.dbo.Company Company, '
--	+ @this_database_name + '.dbo.ProfitCenter ProfitCenter '
--	+ ' WHERE Company.company_id = ProfitCenter.company_id AND ProfitCenter.profit_ctr_id = '
--	+ CONVERT(varchar(2), @profit_ctr_id)
--EXECUTE (@sql)

-- SK 07/09/2014
INSERT #tmp_this_company
SELECT Company.company_name
, ProfitCenter.profit_ctr_name 
FROM Company, ProfitCenter
WHERE Company.company_id = ProfitCenter.company_id 
AND ProfitCenter.profit_ctr_id = @profit_ctr_id
AND Company.company_id = @company_id

IF @debug = 1 select * from #tmp_this_company
select @this_profit_ctr_name = profit_ctr_name FROM #tmp_this_company
	
BEGIN
	-- Regular disposal loads or both types of loads
	IF @load_type = 'R' OR @load_type = 'A'
	BEGIN
		SET @sql = 'INSERT #tmp_results SELECT DISTINCT 1, '
		+ ' OB.company_id, '
		+ ' OB.profit_ctr_id, '
		+ ' OB.customer_id, '
		+ ' OB.manifest, '
		+ ' OB.manifest_flag, '
		+ ' OB.receipt_id, '
		+ ' OB.line_id, '
		+ ' OB.receipt_date, '
		+ ' ''R'' as source_type, '
		+ ' OB.hauler, '
		+ ' Company.company_name, '
		+ ' ProfitCenter.profit_ctr_name, '
		+ ' Customer.cust_name, '
		+ ' Transporter.transporter_name, '
		+ ' TSDF.eq_company as destination_company_id, '
		+ ' TSDF.eq_profit_ctr as destination_profit_ctr_id, '
		+ ' 0 AS already_received, '
		+ ' OB.corporate_revenue_classification_uid '
		+ ' FROM '
		+ ' Receipt OB '
		+ ' JOIN Company '
		+ ' ON OB.company_id = Company.company_id '
		+ ' JOIN ProfitCenter '
		+ ' ON OB.company_id = ProfitCenter.company_id '
		+ ' AND OB.profit_ctr_id = ProfitCenter.profit_ctr_id '
		+ ' JOIN Customer '
		+ ' ON OB.customer_id = Customer.customer_id '
		+ ' LEFT OUTER JOIN Transporter '
		+ ' ON OB.hauler = Transporter.transporter_code '
		+ ' JOIN TSDF '
		+ ' ON OB.tsdf_code = TSDF.tsdf_code '
		+ ' WHERE OB.trans_mode = ''O'' '
		+ ' AND OB.trans_type = ''D'' '
		+ ' AND OB.receipt_status = ''A'' '
		+ ' AND (OB.receipt_date BETWEEN ''' + CONVERT(varchar(30), @date_from, 101) + ''' AND ''' +  + CONVERT(varchar(30), @date_to, 101) + ''') '
		+ ' AND (''' + @manifest + ''' = ''ALL'' OR OB.manifest = ''' + @manifest + ''') '
		+ ' AND OB.tsdf_code IS NOT NULL '
		+ ' AND IsNull(TSDF.eq_flag,''F'') = ''T''  '
		+ ' AND TSDF.eq_company = ' + CONVERT(varchar(2), @company_id) 
		+ ' AND TSDF.eq_profit_ctr = ' + CONVERT(varchar(2), @profit_ctr_id)
		+ ' AND ((OB.company_id = ' + CONVERT(varchar(2), @source_company_id) + ') OR (0 = ' + CONVERT(varchar(2), @source_company_id)+ '))'
		+ ' AND ((' + CONVERT(char(1), @show_all_or_new) + ' = ' + CONVERT(char(1), @show_all) + ') OR '
		+ '  (' + CONVERT(char(1), @show_all_or_new) + ' = ' + CONVERT(char(1), @show_new) + ')) '
		+ ' UNION ALL '
		+ ' SELECT DISTINCT 2, '
		+ ' OB.company_id,  '
		+ ' OB.profit_ctr_id,  '
		+ ' OB.customer_id,  '
		+ ' Container.manifest,  '
		+ ' OB.manifest_flag,  '
		+ ' OB.receipt_id,  '
		+ ' OB.line_id, '
		+ ' OB.receipt_date,  '
		+ ' ''R'' as source_type, '
		+ ' OB.hauler, '
		+ ' Company.company_name, '
		+ ' ProfitCenter.profit_ctr_name, '
		+ ' NULL AS cust_name, '
		+ ' Transporter.transporter_name, '
		+ ' TSDF.eq_company as destination_company_id, '
		+ ' TSDF.eq_profit_ctr as destination_profit_ctr_id, '
		+ ' 0 AS already_received, '
		+ ' OB.corporate_revenue_classification_uid '
		+ ' FROM '
		+ ' Receipt OB '
		+ ' JOIN Company '
		+ ' ON OB.company_id = Company.company_id '
		+ ' JOIN ProfitCenter '
		+ ' ON OB.company_id = ProfitCenter.company_id '
		+ ' AND OB.profit_ctr_id = ProfitCenter.profit_ctr_id '
		+ ' JOIN Container '
		+ ' ON OB.company_id = Container.company_id '
		+ ' AND OB.profit_ctr_id = Container.profit_ctr_id '
		+ ' JOIN ContainerDestination '
		+ ' ON Container.company_id = ContainerDestination.company_id '
		+ ' AND Container.profit_ctr_id = ContainerDestination.profit_ctr_id '
		+ ' AND Container.receipt_id = ContainerDestination.receipt_id '
		+ ' AND Container.line_id = ContainerDestination.line_id '
		+ ' AND Container.container_id = ContainerDestination.container_id '
		+ ' AND ContainerDestination.location_type = ''O'' '
		+ ' AND ContainerDestination.tracking_num = CONVERT(varchar(20),OB.receipt_id) + ''-'' + CONVERT(varchar(10), OB.line_id) '
		+ ' LEFT OUTER JOIN Transporter '
		+ ' ON OB.hauler = Transporter.transporter_code '
		+ ' JOIN TSDF '
		+ ' ON OB.tsdf_code = TSDF.tsdf_code '
		+ ' WHERE OB.trans_mode = ''O''  '
		+ ' AND OB.trans_type IN (''X'') '
		+ ' AND OB.receipt_status = ''A'' '
		+ ' AND OB.transfer_dest_flag = ''D'' '
		+ ' AND (OB.receipt_date BETWEEN ''' + CONVERT(varchar(30), @date_from, 101) + ''' AND ''' + CONVERT(varchar(30), @date_to, 101) + ''') '
		+ ' AND (''' + @manifest + ''' = ''ALL'' OR Container.manifest = ''' + @manifest + ''') '
		+ ' AND OB.tsdf_code IS NOT NULL '
		+ ' AND IsNull(TSDF.eq_flag,''F'') = ''T'' '
		+ ' AND TSDF.eq_company = ' + CONVERT(varchar(2), @company_id)
		+ ' AND TSDF.eq_profit_ctr = ' + CONVERT(varchar(2), @profit_ctr_id)
		+ ' AND ((OB.company_id = ' + CONVERT(varchar(2), @source_company_id) + ') OR (0 = ' + CONVERT(varchar(2), @source_company_id)+ '))'
		+ ' AND ((' + CONVERT(char(1), @show_all_or_new) + ' = ' + CONVERT(char(1), @show_all) + ') OR '
		+ '  (' + CONVERT(char(1), @show_all_or_new) + ' = ' + CONVERT(char(1), @show_new) + '))  '
		+ ' UNION ALL '
		+ ' SELECT DISTINCT 3, convert(varchar(2), WO.company_id) ,  '
		+ ' WO.profit_ctr_id, '
		+ ' WO.customer_id, '
		+ ' WOD.manifest, '
		+ ' CASE WHEN IsNull(WOM.manifest_flag,''F'') = ''T'' THEN ''M'' ELSE ''B'' END, '
		+ ' WO.workorder_id, '
		+ ' 0 as source_line_id, '
		+ ' WO.end_date, '
		+ ' ''W'' as source_type, '
		+ ' WOT.transporter_code, '
		+ ' Company.company_name, '
		+ ' ProfitCenter.profit_ctr_name, '
		+ ' Customer.cust_name, '
		+ ' Transporter.transporter_name, '
		+ ' TSDF.eq_company as destination_company_id, '
		+ ' TSDF.eq_profit_ctr as destination_profit_ctr_id, '
		+ ' 0 AS already_received, '
		+ ' WO.corporate_revenue_classification_uid '
		+ ' FROM '
		+ ' WorkOrderHeader WO '
		+ ' JOIN WorkOrderDetail WOD '
		+ ' ON WO.company_id = WOD.company_id '
		+ ' AND WO.profit_ctr_id = WOD.profit_ctr_id '
		+ ' AND WO.workorder_id = WOD.workorder_id '
		+ ' JOIN WorkOrderManifest WOM '
		+ ' ON WOD.company_id = WOM.company_id '
		+ ' AND WOD.profit_ctr_id = WOM.profit_ctr_id '
		+ ' AND WOD.workorder_id = WOM.workorder_id '
		+ ' AND WOD.manifest = WOM.manifest '
		+ ' JOIN WorkOrderTransporter WOT '
		+ ' ON WOD.company_id = WOT.company_id '
		+ ' AND WOD.profit_ctr_id = WOT.profit_ctr_id '
		+ ' AND WOD.workorder_id = WOT.workorder_id '
		+ ' AND WOD.manifest = WOT.manifest '
		+ ' AND WOT.transporter_sequence_id = 1 '
		+ ' JOIN Company '
		+ ' ON WO.company_id = Company.company_id '
		+ ' JOIN ProfitCenter '
		+ ' ON WOD.company_id = ProfitCenter.company_id '
		+ ' AND WOD.profit_ctr_id = ProfitCenter.profit_ctr_id '
		+ ' JOIN Customer '
		+ ' ON WO.customer_id = Customer.customer_id '
		+ ' JOIN Transporter '
		+ ' ON WOT.transporter_code = Transporter.transporter_code '
		+ ' JOIN TSDF '
		+ ' ON WOD.tsdf_code = TSDF.tsdf_code '
		+ ' WHERE '
		+ ' WO.workorder_status IN (''C'', ''A'', ''N'')  '
		+ ' AND WO.end_date IS NOT NULL '
		+ ' AND WOD.resource_type = ''D'' '
		+ ' AND (WO.end_date BETWEEN ''' + CONVERT(varchar(30), @date_from, 101) + ''' AND ''' +  + CONVERT(varchar(30), @date_to, 101) + ''') '
		+ ' AND (''' + @manifest + ''' = ''ALL'' OR WOD.manifest = ''' + @manifest + ''') '
		+ ' AND WOD.tsdf_code IS NOT NULL '
		+ ' AND IsNull(TSDF.eq_flag,''F'') = ''T'' '
		+ ' AND TSDF.eq_company = ' + CONVERT(varchar(2), @company_id)
		+ ' AND TSDF.eq_profit_ctr = ' + CONVERT(varchar(2), @profit_ctr_id)
		+ ' AND ((WO.company_id = ' + CONVERT(varchar(2), @source_company_id) + ')  OR ( 0 = ' + CONVERT(varchar(2), @source_company_id)+ '))'
		+ ' AND ((' + CONVERT(char(1), @show_all_or_new) + ' = ' + CONVERT(char(1), @show_all) + ') OR '
		+ '  (' + CONVERT(char(1), @show_all_or_new) + ' = ' + CONVERT(char(1), @show_new) + '))'

		IF @debug = 1 PRINT @sql
		EXECUTE (@sql)

	END
	-- In-transit loads or both types of loads
	IF @load_type = 'X' OR @load_type = 'A' 
	BEGIN
		SET @sql = 'INSERT #tmp_results SELECT DISTINCT 4,  '
		+ ' OB.company_id,  '
		+ ' OB.profit_ctr_id, ' 
		+ ' OB.customer_id,  '
		+ ' Container.manifest, ' 
		+ ' OB.manifest_flag,  '
		+ ' OB.receipt_id,  '
		+ ' OB.line_id,  '
		+ ' OB.receipt_date,  '
		+ ' ''R'' as source_type, '
		+ ' OB.hauler, '
		+ ' Company.company_name, '
		+ ' ProfitCenter.profit_ctr_name, '
		+ ' NULL AS cust_name, '
		+ ' Transporter.transporter_name, '
		+ ' TSDF.eq_company as destination_company_id, '
		+ ' TSDF.eq_profit_ctr as destination_profit_ctr_id, '
		+ ' 0 AS already_received, '
		+ ' OB.corporate_revenue_classification_uid '
		+ ' FROM '
		+ ' Receipt OB '
		+ ' JOIN Company '
		+ ' ON OB.company_id = Company.company_id '
		+ ' JOIN ProfitCenter '
		+ ' ON OB.company_id = ProfitCenter.company_id '
		+ ' AND OB.profit_ctr_id = ProfitCenter.profit_ctr_id '
		+ ' JOIN Container '
		+ ' ON OB.company_id = Container.company_id '
		+ ' AND OB.profit_ctr_id = Container.profit_ctr_id '
		+ ' JOIN ContainerDestination '
		+ ' ON Container.company_id = ContainerDestination.company_id '
		+ ' AND Container.profit_ctr_id = ContainerDestination.profit_ctr_id '
		+ ' AND Container.receipt_id = ContainerDestination.receipt_id '
		+ ' AND Container.line_id = ContainerDestination.line_id '
		+ ' AND Container.container_id = ContainerDestination.container_id '
		+ ' AND ContainerDestination.location_type = ''O'' '
		+ ' AND ContainerDestination.tracking_num = CONVERT(varchar(20),OB.receipt_id) + ''-'' + CONVERT(varchar(10), OB.line_id)  '
		+ ' LEFT OUTER JOIN Transporter '
		+ ' ON OB.hauler = Transporter.transporter_code '
		+ ' JOIN TSDF '
		+ ' ON containerdestination.location = TSDF.tsdf_code '
		+ ' JOIN Receipt IB '
		+ ' ON Container.company_id = IB.company_id '
		+ ' AND Container.profit_ctr_id = IB.profit_ctr_id '
		+ ' AND Container.receipt_id = IB.receipt_id '
		+ ' AND Container.line_id = IB.line_id '
		+ ' WHERE OB.trans_mode = ''O''  '
		+ ' AND OB.trans_type = ''X'' '
		+ ' AND OB.manifest_flag = ''X'' '
		+ ' AND OB.receipt_status = ''A'' '
		+ ' AND OB.transfer_dest_flag = ''X'' '
		+ ' AND (OB.receipt_date BETWEEN ''' + CONVERT(varchar(30), @date_from, 101) + ''' AND ''' +  + CONVERT(varchar(30), @date_to, 101) + ''') '
		+ ' AND (''' + @manifest + ''' = ''ALL'' OR Container.manifest = ''' + @manifest + ''') '
		+ ' AND IB.tsdf_code IS NOT NULL '
		+ ' AND IsNull(TSDF.eq_flag,''F'') = ''T'' '
		+ ' AND ((' + CONVERT(char(1), @show_all_or_new) + ' = ' + CONVERT(char(1), @show_all) + ') OR '
		+ '  (' + CONVERT(char(1), @show_all_or_new) + ' = ' + CONVERT(char(1), @show_new) + '))'
	
		IF @debug = 1 PRINT @sql
		EXECUTE (@sql)
	END
END

-- dont Show what has already been received as a transfer 

UPDATE #tmp_results SET already_received = 1
	FROM Receipt, 
        ReceiptCommingled     
	WHERE Receipt.source_company_id = #tmp_results.source_company_id
	AND Receipt.source_profit_ctr_id = #tmp_results.source_profit_ctr_id
	AND Receipt.source_id = #tmp_results.source_id
        and ReceiptCommingled.receipt_id = Receipt.receipt_id
        and ReceiptCommingled.line_id = Receipt.line_id
        and ReceiptCommingled.profit_ctr_id = Receipt.profit_ctr_id
        and ReceiptCommingled.company_id = Receipt.company_id
        and ReceiptCommingled.manifest = #tmp_results.source_manifest
        and Receipt.trans_type = 'X'


-- dont show show what has already bee received as a disposal
-- this logic was based on being able to split manifests since
-- we can no longer do that ther is no reason to test for source line on workorders
-- rg 022008

-- outbound receipts
UPDATE #tmp_results SET already_received = 1
	FROM Receipt     
	WHERE Receipt.source_company_id = #tmp_results.source_company_id
	AND Receipt.source_profit_ctr_id = #tmp_results.source_profit_ctr_id
	AND Receipt.source_id = #tmp_results.source_id
	AND Receipt.source_line_id = #tmp_results.source_line_id
   AND Receipt.manifest = #tmp_results.source_manifest
   AND Receipt.trans_type = 'D'

-- receipt_workorder join
UPDATE #tmp_results SET already_received = 1
	FROM Receipt, BillingLinkLookup     
	WHERE Receipt.company_id = BillingLinkLookup.company_id
	AND	Receipt.profit_ctr_id = BillingLinkLookup.profit_ctr_id
	AND	Receipt.receipt_id = BillingLinkLookup.receipt_id
	AND BillingLinkLookup.source_company_id = #tmp_results.source_company_id
	AND BillingLinkLookup.source_profit_ctr_id = #tmp_results.source_profit_ctr_id
	AND BillingLinkLookup.source_id = #tmp_results.source_id
	and Receipt.manifest = #tmp_results.source_manifest
   and receipt.trans_type = 'D'


IF @debug = 1 print 'Selecting from #tmp_results'
IF @debug = 1 Select * from #tmp_results


-- Return the results
SELECT DISTINCT
	0 as include, 
	#tmp_results.source_company_id,
	#tmp_results.source_profit_ctr_id,
	#tmp_results.source_customer_id,
	#tmp_results.source_manifest,
	#tmp_results.source_manifest_flag,
	#tmp_results.source_id,
	#tmp_results.source_date,
	#tmp_results.source_type,
	#tmp_results.source_transporter_code,
	#tmp_results.source_company_name,
	#tmp_results.source_profit_ctr_name,
	#tmp_results.source_customer_name,
	#tmp_results.source_transporter_name,
	#tmp_results.destination_company_id,
	#tmp_results.destination_profit_ctr_id,
	#tmp_results.already_received,
	@company_id as this_company_id, 
	@profit_ctr_id as this_profit_ctr_id, 
	@this_profit_ctr_name as this_profit_ctr_name,
   1 as  source_line_id,
   	#tmp_results.corporate_revenue_classification_uid
FROM #tmp_results 
WHERE already_received = 0
ORDER BY source_company_id, source_profit_ctr_id, source_date, source_manifest

DROP TABLE #tmp_results

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_loads_in_transit] TO [EQAI]
    AS [dbo];

