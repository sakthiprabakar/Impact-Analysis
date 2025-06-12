
CREATE PROCEDURE sp_quick_select_arg_receipt_wo_manifest
	@manifest_list	varchar(8000),
	@db_type	varchar(4),
	@company	varchar(2),
	@profit_ctr	varchar(2),
	@trans_source	char(1),
	@source		varchar(20),
	@line		varchar(5),
	@generator_id	varchar(15),
	@customer_id	varchar(15)
AS
/***************************************************************************************
Retrieves Receipts and Work Orders with the specified manifest

Filename:	L:\Apps\SQL\EQAI\sp_quick_select_arg_receipt_wo_manifest.sql

Load to PLT_AI

10/24/2007 SCC	Created
04/18/2008 JDB	Modified to exclude Receipts from select when calling from Receipt.
07/15/2008 KAM	Added to include the Generator id and name into the result set.
04/22/2010 KAM  Updated to run on PLT_AI
09/23/2010 KAM  Updated to not return the line_id and return only distinct rows.
12/13/2010 KAM  Updated to use Customer_id as a parameter

sp_quick_select_arg_receipt_wo_manifest_ai '000568302SKS', 'DEV', '22', '0', 'R', '691875', '1','23876'
****************************************************************************************/
SET NOCOUNT ON
DECLARE	@db_count		int,
		@sql			varchar(8000),
		@db_ref			varchar(20)

-- These are the receipts and work orders with the specified manifests
CREATE TABLE #tmp (
	manifest	varchar(15) NULL,
	company_id	int NULL,
	profit_ctr_id	int NULL,
	trans_source	char(11) NULL,
	source_id	int NULL,
	line_id		int NULL,
	customer_id	int NULL,
    source_status   varchar(20) null,
    source_submitted_flag char(1) null,
	generator_id	varchar(15) Null
)
-- This is the receipt or work order that is trying to find a match - so it is excluded from the results
CREATE TABLE #exclude (
	company_id	int NULL,
	profit_ctr_id	int NULL,
	trans_source	char(11) NULL,
	source_id	int NULL,
	line_id		int NULL
)
INSERT #exclude VALUES (
	CONVERT(int, @company),
	CONVERT(int, @profit_ctr),
	@trans_source,
	CONVERT(int, @source),
	CONVERT(int, @line)
)
-- These are the manifests to search - a receipt has only one, but a work order may have several
CREATE TABLE #manifest (
	manifest varchar(15) NOT NULL
)
EXEC sp_list 0, @manifest_list, 'STRING', '#manifest'

INSERT #tmp 
SELECT Receipt.manifest, 
 Receipt.company_id, 
 Receipt.profit_ctr_id, 
 'Receipt' AS trans_source, 
 Receipt.receipt_id, 
 Receipt.line_id, 
 Receipt.customer_id, 
 Receipt.receipt_status, 
 Receipt.submitted_flag, 
 Receipt.generator_id 
FROM Receipt Receipt 
 WHERE Receipt.manifest IN (SELECT manifest FROM #manifest) 
 AND  @trans_source <> 'R' 
 AND Receipt.receipt_status NOT IN ('V','R') 
 AND Receipt.fingerpr_status NOT IN ('V','R') 
 AND Receipt.generator_id = @generator_id 
 AND Receipt.customer_id = @customer_id 
 AND NOT EXISTS (SELECT 1 FROM #exclude WHERE 
 Receipt.company_id = #exclude.company_id 
		AND Receipt.profit_ctr_id = #exclude.profit_ctr_id
		AND Receipt.receipt_id = #exclude.source_id 
		AND (#exclude.line_id = 0 OR Receipt.line_id = #exclude.line_id) 
		AND #exclude.trans_source = 'R') 

UNION 

SELECT WorkOrderManifest.manifest, 
 WorkOrderHeader.company_id, 
 WorkOrderHeader.profit_ctr_id, 
 'Work Order' AS trans_source, 
 WorkOrderHeader.workorder_id, 
 WorkOrderDetail.sequence_id, 
 WorkOrderHeader.customer_id, 
 WorkOrderHeader.workorder_status, 
 WorkorderHeader.submitted_flag, 
 WorkOrderHeader.generator_id 
FROM WorkOrderHeader WorkOrderHeader 
JOIN WorkOrderDetail WorkOrderDetail 
		ON WorkOrderHeader.company_id = WorkOrderDetail.company_id 
		AND WorkOrderHeader.profit_ctr_id = WorkOrderDetail.profit_ctr_id 
		AND WorkOrderHeader.workorder_id = WorkOrderDetail.workorder_id 
		AND WorkOrderDetail.resource_type = 'D' 
JOIN WorkOrderManifest WorkOrderManifest 
		ON WorkOrderHeader.profit_ctr_id = WorkOrderManifest.profit_ctr_id 
		AND WorkOrderHeader.company_id = WorkOrderManifest.company_id 
		AND WorkOrderHeader.workorder_id = WorkOrderManifest.workorder_id 
		AND WorkOrderManifest.manifest IN (SELECT manifest FROM #manifest) 
WHERE  @trans_source  <> 'W' 
AND WorkOrderHeader.workorder_status NOT IN ('T','V', 'R') 
AND NOT EXISTS (SELECT 1 FROM #exclude 
		WHERE WorkOrderHeader.company_id = #exclude.company_id 
		AND WorkOrderHeader.profit_ctr_id = #exclude.profit_ctr_id 
		AND WorkOrderHeader.workorder_id = #exclude.source_id 
		AND (#exclude.line_id = 0 OR WorkOrderDetail.sequence_id = #exclude.line_id) 
		AND #exclude.trans_source = 'W') 
AND WorkOrderHeader.generator_id = @generator_id 
AND WorkOrderHeader.customer_id = @customer_id 

-- update for status
UPDATE #tmp
SET source_status = CASE when source_submitted_flag = 'T' then 'Submitted'
                         when source_status = 'A' then 'Accepted'
                         when source_status = 'N' then 'New'
                         when source_status = 'H' then 'Hold'
                         when source_status = 'M' then 'Manual'
                         when source_status = 'L' then 'Lab'
                         when source_status = 'U' then 'Unloading'
                         when source_status = 'T' then 'In-Transit'
                         else 'Unknown' end
WHERE trans_source = 'Receipt'

UPDATE #tmp
SET source_status = CASE when source_submitted_flag = 'T' then 'Submitted'
                         when source_status = 'A' then 'Accepted'
                         when source_status = 'C' then 'Complete'
                         when source_status = 'N' then 'New'
                         when source_status = 'P' then 'Priced'
                         when source_status = 'H' then 'Hold'
                         when source_status = 'D' then 'Dispatched'
                         else 'Unknown' end
WHERE trans_source = 'Work Order'

-- Return results
SELECT Distinct #tmp.manifest,
		#tmp.company_id,
		#tmp.profit_ctr_id,
		#tmp.trans_source,
		#tmp.source_id,
		NULL,
		#tmp.customer_id,
		#tmp.source_status,
		#tmp.source_submitted_flag, 
		Customer.cust_name,
		Generator.EPA_ID,
		Generator.Generator_name 
FROM #tmp
JOIN Customer
ON #tmp.customer_id = Customer.customer_id
Join Generator
On #tmp.generator_id = Generator.generator_id

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_quick_select_arg_receipt_wo_manifest] TO [EQAI]
    AS [dbo];

