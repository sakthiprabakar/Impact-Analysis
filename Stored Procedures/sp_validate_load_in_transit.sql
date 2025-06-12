--drop PROCEDURE sp_validate_load_in_transit
--go
CREATE PROCEDURE sp_validate_load_in_transit
	@company_ID int,
	@profit_ctr_id int,
	@source_company_id int,
	@source_profit_ctr_id int,
	@source_receipt_id int,
	@source_workorder_id int,
	@manifest	varchar(15),
	@debug int
AS
/************************************************************************************
LOAD TO PLT_AI

02/26/2009 KAM	Created
12/20/2010 KAM	Updated to use new work order tables
05/08/2020 MPM	DevOps 15456 - Added corporate_revenue_classification_uid to result set.

BLOCKNUM Identifiers:
1 = Outbound Disposal loads to this EQ TSDF (company_id and profit_ctr_id)
2 = Transfers where final TSDF is this EQ TSDF - turns into a disposal
3 = WorkOrder Disposal to this EQ TSDF
4 = Pass-Thru Transfers

sp_validate_load_in_transit 29,0,14,9,-999999,6454301,'-0',0
************************************************************************************/
DECLARE
	@sql varchar(8000)

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
	destination_company_id int NULL,
	destination_profit_ctr_id int NULL,
	already_received int NULL,
	corporate_revenue_classification_uid int NULL
)

-- Regular disposal loads or both types of loads
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
	+ ' TSDF.eq_company as destination_company_id, '
	+ ' TSDF.eq_profit_ctr as destination_profit_ctr_id, '
	+ ' 0 AS already_received, '
	+ ' OB.corporate_revenue_classification_uid '
	+ ' FROM '
	+ ' Receipt OB, '
	+ ' TSDF TSDF '
	+ ' WHERE OB.trans_mode = ''O'' '
	+ ' AND OB.trans_type = ''D'' '
	+ ' AND OB.receipt_status = ''A'' '
	+ ' AND OB.tsdf_code IS NOT NULL '
	+ ' AND OB.tsdf_code = TSDF.tsdf_code '
	+ ' AND IsNull(TSDF.eq_flag,''F'') = ''T''  '
	+ ' AND TSDF.eq_company = ' + CONVERT(varchar(2), @company_id) 
	+ ' AND TSDF.eq_profit_ctr = ' + CONVERT(varchar(2), @profit_ctr_id)
	+ ' AND OB.company_id = ' + CONVERT(varchar(2), @source_company_id)
	+ ' AND OB.profit_ctr_id = ' + CONVERT(varchar(2), @source_profit_ctr_id)
	+ ' AND OB.receipt_id = ' + CONVERT(varchar, @source_receipt_id)
	+ ' AND (OB.manifest = ''' + @manifest + ''' or ''' + @manifest + ''' = ''-0'' )'
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
	+ ' TSDF.eq_company as destination_company_id, '
	+ ' TSDF.eq_profit_ctr as destination_profit_ctr_id, '
	+ ' 0 AS already_received, '
	+ ' OB.corporate_revenue_classification_uid '
	+ ' FROM '
	+ ' Receipt OB, '
	+ ' Container Container, '
	+ ' ContainerDestination ContainerDestination, '
	+ ' TSDF TSDF '
	+ ' WHERE OB.trans_mode = ''O''  '
	+ ' AND OB.trans_type IN (''X'') '
	+ ' AND OB.receipt_status = ''A'' '
	+ ' AND OB.transfer_dest_flag = ''D'' '
	+ ' AND OB.company_id = Container.company_id '
	+ ' AND OB.profit_ctr_id = Container.profit_ctr_id '
	+ ' AND Container.company_id = ContainerDestination.company_id '
	+ ' AND Container.profit_ctr_id = ContainerDestination.profit_ctr_id '
	+ ' AND Container.receipt_id = ContainerDestination.receipt_id '
	+ ' AND Container.line_id = ContainerDestination.line_id '
	+ ' AND Container.container_id = ContainerDestination.container_id '
	+ ' AND ContainerDestination.location_type = ''O'' '
	+ ' AND ContainerDestination.tracking_num = CONVERT(varchar(20),OB.receipt_id) + ''-'' + CONVERT(varchar(10), OB.line_id) '
	+ ' AND OB.tsdf_code IS NOT NULL '
	+ ' AND OB.tsdf_code = TSDF.tsdf_code '
	+ ' AND IsNull(TSDF.eq_flag,''F'') = ''T'' '
	+ ' AND TSDF.eq_company = ' + CONVERT(varchar(2), @company_id)
	+ ' AND TSDF.eq_profit_ctr = ' + CONVERT(varchar(2), @profit_ctr_id)
	+ ' AND OB.company_id = ' + CONVERT(varchar(2), @source_company_id) 
	+ ' AND OB.profit_ctr_id = ' + CONVERT(varchar(2), @source_profit_ctr_id)
	+ ' AND OB.receipt_id = ' + CONVERT(varchar, @source_receipt_id)
	+ ' AND (Container.manifest = ''' +  @manifest  + ''' or ''' + @manifest + ''' = ''-0'' )'
	+ ' UNION ALL '
	+ ' SELECT DISTINCT 3, ' + convert(varchar(2), @source_company_id) + ',  '
	+ ' WO.profit_ctr_id, '
	+ ' WO.customer_id, '
	+ ' WOD.manifest, '
	+ ' CASE WHEN IsNull(WOM.manifest_flag,''F'') = ''T'' THEN ''M'' ELSE ''B'' END, '
	+ ' WO.workorder_id, '
	+ ' 0 as source_line_id, '
	+ ' WO.end_date, '
	+ ' ''W'' as source_type, '
	+ ' WOT.transporter_code, '
	+ ' TSDF.eq_company as destination_company_id, '
	+ ' TSDF.eq_profit_ctr as destination_profit_ctr_id, '
	+ ' 0 AS already_received, '
	+ ' WO.corporate_revenue_classification_uid '
	+ ' FROM '
	+ ' WorkOrderHeader WO, '
	+ ' WorkOrderDetail WOD, '
	+ ' WorkOrderManifest WOM, '
	+ ' TSDF TSDF, '
	+ ' WorkorderTransporter WOT '
	+ ' WHERE '
	+ ' WO.workorder_status IN (''C'', ''A'',''N'')  '
	+ ' AND WO.end_date IS NOT NULL '
	+ ' AND WOD.resource_type = ''D'' '
	+ ' AND WO.company_id = WOD.company_id '
	+ ' AND WO.profit_ctr_id = WOD.profit_ctr_id '
	+ ' AND WO.workorder_id = WOD.workorder_id '
	+ ' AND WOD.company_id = WOM.company_id '
	+ ' AND WOD.profit_ctr_id = WOM.profit_ctr_id '
	+ ' AND WOD.workorder_id = WOM.workorder_id '
	+ ' AND WOD.manifest = WOM.manifest '
	+ ' AND WOD.company_id = WOT.company_id '
	+ ' AND WOD.profit_ctr_id = WOT.profit_ctr_id '
	+ ' AND WOD.workorder_id = WOT.workorder_id '
	+ ' AND WOD.manifest = WOT.manifest '
	+ ' AND WOT.transporter_sequence_id = 1 '
	+ ' AND WOD.tsdf_code IS NOT NULL '
	+ ' AND WOD.tsdf_code = TSDF.tsdf_code '
	+ ' AND IsNull(TSDF.eq_flag,''F'') = ''T'' '
	+ ' AND TSDF.eq_company = ' + CONVERT(varchar(2), @company_id)
	+ ' AND TSDF.eq_profit_ctr = ' + CONVERT(varchar(2), @profit_ctr_id)
	+ ' AND WO.company_id = ' + CONVERT(varchar(2), @source_company_id) 
	+ ' AND WO.profit_ctr_id = ' + CONVERT(varchar(2), @source_profit_ctr_id)
	+ ' AND WO.workorder_id = ' + CONVERT(varchar, @source_workorder_id)
	+ ' AND (WOD.manifest = ''' + @manifest  + ''' or ''' + @manifest + ''' = ''-0'' )'

	IF @debug = 1 PRINT @sql
	EXECUTE (@sql)

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
	+ ' TSDF.eq_company as destination_company_id, '
	+ ' TSDF.eq_profit_ctr as destination_profit_ctr_id, '
	+ ' 0 AS already_received, '
	+ ' OB.corporate_revenue_classification_uid '
	+ ' FROM '
	+ ' Receipt OB, '
	+ ' Receipt IB, '
	+ ' Container, '
	+ ' ContainerDestination , '
	+ ' TSDF '
	+ ' WHERE OB.trans_mode = ''O''  '
	+ ' AND OB.trans_type = ''X'' '
	+ ' AND OB.manifest_flag = ''X'' '
	+ ' AND OB.receipt_status = ''A'' '
	+ ' AND OB.transfer_dest_flag = ''X'' '
	+ ' AND OB.company_id = Container.company_id '
	+ ' AND OB.profit_ctr_id = Container.profit_ctr_id '
	+ ' AND Container.company_id = ContainerDestination.company_id '
	+ ' AND Container.profit_ctr_id = ContainerDestination.profit_ctr_id '
	+ ' AND Container.receipt_id = ContainerDestination.receipt_id '
	+ ' AND Container.line_id = ContainerDestination.line_id '
	+ ' AND Container.container_id = ContainerDestination.container_id '
	+ ' AND ContainerDestination.location_type = ''O'' '
	+ ' AND ContainerDestination.tracking_num = CONVERT(varchar(20),OB.receipt_id) + ''-'' + CONVERT(varchar(10), OB.line_id)  '
	+ ' AND Container.company_id = IB.company_id '
	+ ' AND Container.profit_ctr_id = IB.profit_ctr_id '
	+ ' AND Container.receipt_id = IB.receipt_id '
	+ ' AND Container.line_id = IB.line_id '
--	+ ' AND IB.tsdf_code IS NOT NULL '
	+ ' AND containerdestination.location = TSDF.tsdf_code '
	+ ' AND IsNull(TSDF.eq_flag,''F'') = ''T'' '
	+ ' AND OB.company_id = ' + CONVERT(varchar(2), @source_company_id) 
	+ ' AND OB.profit_ctr_id = ' + CONVERT(varchar(2), @source_profit_ctr_id)
	+ ' AND OB.receipt_id = ' + CONVERT(varchar, @source_receipt_id)
	+ ' AND (OB.manifest = ''' + @manifest  + ''' or ''' + @manifest + ''' = ''-0'' )'
	
IF @debug = 1 PRINT @sql
	EXECUTE (@sql)

-- dont Show what has already been received as a transfer 

UPDATE #tmp_results SET already_received = 1
	FROM Receipt, 
        ReceiptCommingled     
	WHERE Receipt.source_company_id = #tmp_results.source_company_id
	AND Receipt.source_profit_ctr_id = #tmp_results.source_profit_ctr_id
	AND Receipt.source_id = #tmp_results.source_id
	AND Receipt.source_line_id = #tmp_results.source_line_id
        and ReceiptCommingled.receipt_id = Receipt.receipt_id
        and ReceiptCommingled.line_id = Receipt.line_id
        and ReceiptCommingled.profit_ctr_id = Receipt.profit_ctr_id
        and ReceiptCommingled.company_id = Receipt.company_id
        and ReceiptCommingled.manifest = #tmp_results.source_manifest
        and Receipt.trans_type = 'X'


-- dont show show what has already bee received as a disposal
-- this logic was based on being able to split manifests since
-- we can no longer do that there is no reason to test for source line on workorders

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
	#tmp_results.destination_company_id,
	#tmp_results.destination_profit_ctr_id,
	#tmp_results.already_received,
	@company_id as this_company_id, 
	@profit_ctr_id as this_profit_ctr_id, 
	1 as source_line_id,
   	#tmp_results.corporate_revenue_classification_uid
FROM #tmp_results 
WHERE already_received = 0

DROP TABLE #tmp_results

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_validate_load_in_transit] TO [EQAI]
    AS [dbo];

