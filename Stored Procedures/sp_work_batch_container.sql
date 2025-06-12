
CREATE PROCEDURE sp_work_batch_container
	@company_id			int
,	@profit_ctr_id		int
,	@date_from			datetime
,	@date_to			datetime
,	@location_in		varchar(15)
,	@tracking_num_in	varchar(max)
,	@user_id			varchar(10)
,	@debug				int
AS
/***************************************************************************************


06/18/2004 SCC	Created
09/22/2004 JDB	Convert approval_comments to varchar(1800) since they are now text
		datatype and you cannot select them as distinct.  Why 1800?  Because the
		table already had several varchar(1990) fields, and the table size was
		too big to make it 2000 or larger.
11/11/2004 MK  Changed generator_code to generator_id
12/30/2004 SCC	Changed Ticket references
03/11/2005 SCC	Updated to reference batch tables
03/14/2005 SCC	Modified to use sp_work_report, shared with INVENTORY reports to 
		build sort on waste codes and constituents
03/21/2005 LJT	Modified to sub - select size or one bill unit value for reporting. 
                Use first price_line in receiptprice.  
                Modified to only select completed containers  
                Modified to be able to select closed batches
03/29/2005 MK	Limited size of group_report concatenated data to 2000 to fit into work_container
05/12/2005 MK	Added disposal date range to parameters and included in initial select.
09/27/2005 MK	Added batch open date to select populating #tmp. 
		Removed disposal dates from initial select. 
		Replaced disposal and receipt dates with batch dates in where clause populating #tmp.
10/10/2005 MK	Added 'N'ew to receipt statuses that are used in this report
03/23/2007 rg   moved all references to receipt_id in join criteria to the end of the where clause
		per LT.
09/20/2007 JDB	Removed join to Approval table, and converted to use subselects so that
		this SP would not block users from updating the Profile table.
09/24/2007 JDB	Commented out the big COALESCE statement for gal_conv, and added an UPDATE at the
		end of this SP because the COALESCE statement was not working properly.
12/12/2008 KAM  Updated the SQL to include Stock containers.
01/28/2009 LJT  Removed union and split out batch to be a temp table. Moved select to plt_ai from the views
11/30/2010 SK	Added company_id as input arg, modified to join to company_id
				Moved to Plt_AI
08/01/2016 AM   Added #tmp_tracking_num temp table and necessary joins. 08/05 SK added more debug stmt
11/10/2017 MPM	Updated the bill unit for stock containers

sp_work_batch_container 0,  '1-01-05','6-14-05', 'BOX LISTED', '128', 'mk', 1,  '1-01-05','6-14-05'
sp_work_batch_container 0, '6-1-2005','9-22-2005', '101', '101-1', 'SA', 1, '6-1-2005', '9-22-05'
sp_work_batch_container 21, 0, '6-1-2005','9-22-2009', 'TESTBATCH', '1', 'Lorraine', 1
sp_work_batch_container 21, 0, '1-1-2015','1-1-2017', '701', 'ALL', 'anitha_m', 1
sp_work_batch_container 42, 0, '1-1-2015', '12-12-2017', 'Inorganics', '201701', 'martha_m', 0
****************************************************************************************/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

---------------------------------------------
-- Get the batch containers
---------------------------------------------
-- These are receipt containers

-- create temp table of batch information - faster for some reason
-- must be in company to get this from the view.
--DECLARE @company_id	int

--select @company_id =  CONVERT(INT, SUBSTRING(DB_NAME(), 5, 2)) 
-- Anitha 
	CREATE TABLE #tmp_tracking_num (
		tracking_num		varchar (15)
	)
	INSERT #tmp_tracking_num
	SELECT row
	from dbo.fn_SplitXsvText(',', 1, @tracking_num_in)
	WHERE isnull(row,'') <> ''
-- Anitha END
IF @debug = 1 PRINT 'SELECT * FROM #tmp_tracking_num'
IF @debug = 1 SELECT * FROM #tmp_tracking_num

select location, batch.tracking_num, profit_ctr_id, date_opened, company_id
into #batchtmp
from batch
JOIN #tmp_tracking_num ON #tmp_tracking_num.tracking_num = batch.tracking_num OR 
		#tmp_tracking_num.tracking_num = 'ALL'
where(@location_in = 'ALL' OR Batch.location = @location_in)
	AND (@tracking_num_in = 'ALL' OR Batch.tracking_num = #tmp_tracking_num.tracking_num  )
	AND Batch.status <> 'V'
	AND Batch.date_opened BETWEEN @date_from AND @date_to
	AND Batch.profit_ctr_id = @profit_ctr_id
	AND Batch.company_id = @company_id

IF @debug = 1 PRINT 'SELECT * FROM #batchtmp'
IF @debug = 1 SELECT * FROM #batchtmp

INSERT #tmp (Container, receipt_id, line_id, container_type, container_id, sequence_id, profit_ctr_id,
	company_id, location, tracking_num, cycle, receipt_date, disposal_date, generator_name, quantity, 
	bill_unit_code, gal_conv, manifest, manifest_line_id, approval_code, treatment_id, bulk_flag, benzene, 
	generic_flag, approval_comments, waste_flag, const_flag, group_waste, group_const, group_container, 
	base_container, user_id, batch_date)
SELECT 
	dbo.fn_container_receipt(ContainerDestination.receipt_id,ContainerDestination.line_id) AS Container,
	ContainerDestination.receipt_id,
	ContainerDestination.line_id,
	ContainerDestination.container_type,
	ContainerDestination.container_id,
	ContainerDestination.sequence_id,
	ContainerDestination.profit_ctr_id,
	ContainerDestination.company_id,
	ContainerDestination.location,
	ContainerDestination.tracking_num,   
	ISNULL(ContainerDestination.cycle, 0),   
	Receipt.receipt_date,   
	ContainerDestination.disposal_date,
	generator.generator_name,   
        (SELECT quantity = 
		CASE receipt.bulk_flag 
			WHEN 'F' 
			THEN 1 
			ELSE (receipt.quantity * container_percent) / 100 END) AS quantity,

	COALESCE((SELECT container_size 
		FROM Container,billunit 
		WHERE container_size = bill_unit_code 
		AND container_size <> '' 
		AND receipt.line_id = container.line_id 
		AND receipt.profit_ctr_id = container.profit_ctr_id
		AND receipt.company_id = container.company_id
		AND receipt.receipt_id = container.receipt_id 
		AND container.container_id = containerdestination.container_id 
		AND receipt.line_id = containerdestination.line_id 
		AND receipt.profit_ctr_id = containerdestination.profit_ctr_id
		AND receipt.company_id = containerdestination.company_id
		AND receipt.receipt_id = containerdestination.receipt_id  ), 
		(SELECT bill_unit_code 
		FROM ReceiptPrice 
		WHERE receipt.line_id = receiptprice.line_id 
		AND receipt.profit_ctr_id = receiptprice.profit_ctr_id 
		AND receipt.company_id = receiptprice.company_id 
		AND receipt.receipt_id = receiptprice.receipt_id 
		AND price_id = (SELECT MIN(price_id) 
				FROM receiptprice 
				WHERE receipt.profit_ctr_id = receiptprice.profit_ctr_id
				AND receipt.company_id = receiptprice.company_id  
				AND receipt.line_id = receiptprice.line_id
				AND receipt.receipt_id = receiptprice.receipt_id  ))) AS bill_unit_code,
	0 AS gal_conv,
-- 	COALESCE((SELECT gal_conv 
-- 		FROM BillUnit 
-- 		WHERE bill_unit_code = COALESCE((SELECT container_size 
-- 		FROM Container,billunit 
-- 		WHERE container_size = bill_unit_code 
-- 		AND container_size <> '' 
-- 		AND receipt.line_id = container.line_id 
-- 		AND receipt.profit_ctr_id = container.profit_ctr_id 
-- 		AND receipt.receipt_id = container.receipt_id 
-- 		AND container.container_id = containerdestination.container_id  
-- 		AND receipt.line_id = containerdestination.line_id 
-- 		AND receipt.profit_ctr_id = containerdestination.profit_ctr_id
-- 		AND receipt.receipt_id = containerdestination.receipt_id ), 
-- 		(SELECT bill_unit_code 
-- 		FROM ReceiptPrice 
-- 		WHERE receipt.line_id = receiptprice.line_id  
-- 		AND receipt.profit_ctr_id = receiptprice.profit_ctr_id 
-- 		AND receipt.receipt_id = receiptprice.receipt_id
-- 		AND price_id = (SELECT MIN(price_id) 
-- 			FROM receiptprice 
-- 			WHERE receipt.line_id = receiptprice.line_id  
-- 			AND receipt.profit_ctr_id = receiptprice.profit_ctr_id
-- 			AND receipt.receipt_id = receiptprice.receipt_id )))), 0) AS gal_conv,
	Receipt.manifest,   
	Receipt.manifest_line_id,   
	Receipt.approval_code,   
	COALESCE(ContainerDestination.treatment_id, Receipt.treatment_id) AS treatment_id,   
	Receipt.bulk_flag,
	benzene = (SELECT benzene 
				FROM ProfileLab 
				WHERE profile_id = Receipt.profile_id 
				AND type = 'A'),
	generic_flag = (SELECT generic_flag 
					FROM Profile 
					WHERE profile_id = Receipt.profile_id),
	approval_comments = (SELECT CONVERT(varchar(1800), approval_comments) 
							FROM Profile 
							WHERE profile_id = Receipt.profile_id),
	ContainerDestination.waste_flag,
	ContainerDestination.const_flag,
	CONVERT(varchar(1990), '') AS group_waste,
	CONVERT(varchar(1990), '') AS group_const,
	CONVERT(varchar(1990), '') AS group_container,
	0 AS base_container,
	@user_id AS user_id,
	Batch.date_opened
from #batchtmp as batch
INNER JOIN  ContainerDestination
	ON ContainerDestination.location = Batch.location 
	AND ContainerDestination.tracking_num = Batch.tracking_num 
	AND ContainerDestination.profit_ctr_id = Batch.profit_ctr_id 
	AND ContainerDestination.company_id = Batch.company_id 
INNER JOIN Receipt 
	ON Receipt.receipt_id = ContainerDestination.receipt_id 
	AND Receipt.line_id = ContainerDestination.line_id  
	AND Receipt.profit_ctr_id = ContainerDestination.profit_ctr_id  
	AND Receipt.company_id = ContainerDestination.company_id  
INNER JOIN  generator 
	ON generator.generator_id = Receipt.generator_id  
WHERE 1=1
	AND Receipt.receipt_status IN ('N', 'L', 'U', 'A')
	AND Receipt.trans_mode = 'I'
	AND ContainerDestination.status = 'C'
	AND ContainerDestination.container_type = 'R'

IF @debug = 1 PRINT 'SELECT * FROM #tmp- receipts'
IF @debug = 1 SELECT * FROM #tmp

INSERT #tmp (Container, receipt_id, line_id, container_type, container_id, sequence_id, profit_ctr_id,
	company_id, location, tracking_num, cycle, receipt_date, disposal_date, generator_name, quantity, 
	bill_unit_code, gal_conv, manifest, manifest_line_id, approval_code, treatment_id, bulk_flag, benzene, 
	generic_flag, approval_comments, waste_flag, const_flag, group_waste, group_const, group_container, 
	base_container, user_id, batch_date)

-- These are the stock containers
 SELECT DISTINCT
	dbo.fn_container_stock(ContainerDestination.line_id, ContainerDestination.company_id, ContainerDestination.profit_ctr_id) AS Container,
	ContainerDestination.receipt_id,
	ContainerDestination.line_id,
	ContainerDestination.container_type,
	ContainerDestination.container_id,
	ContainerDestination.sequence_id,
	ContainerDestination.profit_ctr_id,
	ContainerDestination.company_id,
	ContainerDestination.location,
	ContainerDestination.tracking_num,   
	ISNULL(ContainerDestination.cycle,0),   
	ContainerDestination.date_added AS receipt_date,   
	ContainerDestination.disposal_date,   
	'' AS generator_name,   
	1 AS quantity,
--	'DM55' AS bill_unit_code,
	CASE Container.container_size WHEN NULL THEN 'DM55' WHEN '' THEN 'DM55' ELSE Container.container_size END as bill_unit_code,
	0 AS gal_conv,
-- 	55 AS gal_conv,
	'' AS manifest,
	'' AS manifest_line_id,
	'' AS approval_code,
	ContainerDestination.treatment_id,
	'F' AS bulk_flag,
	CONVERT(decimal(8,3), NULL) AS benzene,
	'F' AS generic_flag,
	CONVERT(varchar(1800), '') AS approval_comments,	
	'T' AS waste_flag,
	'T' AS const_flag,
	CONVERT(varchar(1990), '') AS group_waste,
	CONVERT(varchar(1990), '') AS group_const,
	CONVERT(varchar(1990), '') AS group_container,
	0 AS base_container,
	@user_id AS user_id,
	Batch.date_opened
FROM Batch
INNER JOIN ContainerDestination 
	ON Batch.location = ContainerDestination.location
	AND Batch.tracking_num = ContainerDestination.tracking_num
	AND Batch.profit_ctr_id = ContainerDestination.profit_ctr_id
	AND Batch.company_id = ContainerDestination.company_id
JOIN #tmp_tracking_num  ON #tmp_tracking_num.tracking_num = Batch.tracking_num
    OR #tmp_tracking_num.tracking_num  = 'ALL'
LEFT OUTER JOIN Container
	ON Container.profit_ctr_id = ContainerDestination.profit_ctr_id
	AND Container.company_id = ContainerDestination.company_id
	AND Container.receipt_id = ContainerDestination.receipt_id
	AND Container.container_type = ContainerDestination.container_type
	AND Container.line_id = ContainerDestination.line_id
WHERE 1=1
	AND (@tracking_num_in = 'ALL' OR Batch.tracking_num = #tmp_tracking_num.tracking_num )
	AND (@location_in = 'ALL' OR Batch.location = @location_in)
	AND Batch.profit_ctr_id = @profit_ctr_id
	AND Batch.company_id = @company_id
	AND ContainerDestination.container_type = 'S'
	AND ContainerDestination.status IN ('C', 'N')


IF @debug = 1 PRINT 'SELECT * FROM #tmp- SC'
IF @debug = 1 SELECT * FROM #tmp

-- Update the gal_conv field now
UPDATE #tmp SET gal_conv = bu.gal_conv
FROM BillUnit bu
WHERE #tmp.bill_unit_code = bu.bill_unit_code
AND #tmp.gal_conv = 0


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_work_batch_container] TO [EQAI]
    AS [dbo];

