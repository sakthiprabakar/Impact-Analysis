
CREATE PROCEDURE sp_dash_container_inventory
	@measurement_id	int,
	@start_date		datetime,
	@end_date		datetime
AS
/* ************************************************
sp_dash_container_inventory:
	@measurement_id	int - the id to save this data with.

Total amount of ALL REV invoices generated per day

select * from DashBoardMeasurement where description like '%inven%'
-- ??

	sp_dash_container_inventory 9
	select * 
		from DashboardResult 
		where measurement_id = 9
	delete DashboardResult 
		where measurement_id = 9

fix dbo.		
		
LOAD TO PLT_AI*

10/06/2009 JPB Created as modified version of plt_xx_ai..sp_rpt_inv_container

************************************************ */

-- These are the Outbound Receipts that are open, not Accepted
SELECT Receipt.company_id,
		Receipt.profit_ctr_id,
		Receipt.receipt_id,
		Receipt.line_id,
		CONVERT(varchar(10), Receipt.receipt_id) + '-' + CONVERT(varchar(5), Receipt.line_id) as outbound_receipt,
		Receipt.receipt_date
INTO #outbounds
FROM Receipt Receipt
WHERE Receipt.trans_mode = 'O'
	AND Receipt.receipt_status = 'N'

-- 1A -- Get Incomplete Receipt/ContainerDestination records
--	ContainerDestination.status = 'N'
SELECT DISTINCT 
	-- ContainerDestination.receipt_id, 
	-- ContainerDestination.line_id,
	ContainerDestination.profit_ctr_id,
	-- ContainerDestination.container_type,
	-- ContainerDestination.container_id,
	-- 'DISP' AS load_type,
	-- Receipt.manifest,
	-- CONVERT(varchar(50), Receipt.approval_code) AS approval_code,
	-- Receipt.waste_code,
	COUNT(ContainerDestination.container_id) AS containers_on_site,
	-- Receipt.bill_unit_code,
	-- Receipt.receipt_date,
	-- ISNULL(ContainerDestination.Location, '') AS location, 
	-- DATEDIFF(dd, receipt.receipt_date, getdate()) AS days_on_site,
	-- getdate() AS as_of_date,
	-- CONVERT(varchar(15),'') AS tracking_num,
	-- ISNULL(Container.staging_row, '') AS staging_row,
	-- Receipt.fingerpr_status,
	-- COALESCE(ContainerDestination.treatment_id, Receipt.treatment_id) AS treatment_id,
	-- Container.container_size,
	-- Container.container_weight,
	-- ISNULL(ContainerDestination.tsdf_approval_code, '') AS tsdf_approval_code,
	Receipt.company_id --,
	-- NULL AS outbound_receipt,
	-- NULL AS outbound_receipt_date
INTO #tmp
FROM Receipt Receipt
INNER JOIN Container Container 
	ON Receipt.receipt_id = Container.receipt_id
	AND Receipt.line_id = Container.line_id
	AND Receipt.profit_ctr_id = Container.profit_ctr_id
	AND Receipt.company_id = Container.company_id
INNER JOIN ContainerDestination ContainerDestination 
	ON Container.receipt_id = ContainerDestination.receipt_id
	AND Container.line_id = ContainerDestination.line_id
	AND Container.container_id = ContainerDestination.container_id
	AND Container.company_id = ContainerDestination.company_id
	AND Container.profit_ctr_id = ContainerDestination.profit_ctr_id
	AND Container.container_type = ContainerDestination.container_type
WHERE 1=1
	AND Receipt.receipt_status IN ('L', 'U', 'A')
	AND Receipt.trans_type = 'D'
	AND Receipt.trans_mode = 'I'
	AND Receipt.fingerpr_status NOT IN ('V','R')
	AND Receipt.receipt_date > '7-31-99'
	AND Container.status IN ('N','C')
	AND Container.container_type = 'R'
	AND ContainerDestination.status = 'N'
GROUP BY
	Receipt.company_id,
	-- ContainerDestination.receipt_id, 
	-- ContainerDestination.line_id,
	-- ContainerDestination.container_id,
	ContainerDestination.profit_ctr_id --,
	-- Receipt.trans_type,
	-- ContainerDestination.container_type,
	-- Receipt.manifest,
	-- Receipt.approval_code,
	-- Receipt.waste_code,
	-- Receipt.bill_unit_code,
	-- Receipt.receipt_date,
	-- ContainerDestination.location,
	-- Container.staging_row,
	-- Receipt.location,
	-- Receipt.fingerpr_status,
	-- COALESCE(ContainerDestination.treatment_id, Receipt.treatment_id),
	-- Container.container_size,
	-- Container.container_weight,
	-- ContainerDestination.tsdf_approval_code

UNION ALL

-- 1B -- Get Incomplete Receipt/ContainerDestination records
--	ContainerDestination.status = 'C' but outbound not accepted
SELECT DISTINCT 
	-- ContainerDestination.receipt_id, 
	-- ContainerDestination.line_id,
	ContainerDestination.profit_ctr_id,
	-- ContainerDestination.container_type,
	-- ContainerDestination.container_id,
	-- 'DISP' AS load_type,
	-- Receipt.manifest,
	-- CONVERT(varchar(50), Receipt.approval_code) AS approval_code,
	-- Receipt.waste_code,
	COUNT(ContainerDestination.container_id) AS containers_on_site,
	-- Receipt.bill_unit_code,
	-- Receipt.receipt_date,
	-- ISNULL(ContainerDestination.Location, '') AS location, 
	-- DATEDIFF(dd, receipt.receipt_date, getdate()) AS days_on_site,
	-- getdate() AS as_of_date,
	-- CONVERT(varchar(15),'') AS tracking_num,
	-- ISNULL(Container.staging_row, '') AS staging_row,
	-- Receipt.fingerpr_status,
	-- COALESCE(ContainerDestination.treatment_id, Receipt.treatment_id) AS treatment_id,
	-- Container.container_size,
	-- Container.container_weight,
	-- ISNULL(ContainerDestination.tsdf_approval_code, '') AS tsdf_approval_code,
	Receipt.company_id --,
	-- #outbounds.outbound_receipt,
	-- #outbounds.receipt_date AS outbound_receipt_date
FROM Receipt Receipt
INNER JOIN Container Container 
	ON Receipt.receipt_id = Container.receipt_id
	AND Receipt.line_id = Container.line_id
	AND Receipt.profit_ctr_id = Container.profit_ctr_id
	AND Receipt.company_id = Container.company_id
INNER JOIN ContainerDestination ContainerDestination 
	ON Container.receipt_id = ContainerDestination.receipt_id
	AND Container.line_id = ContainerDestination.line_id
	AND Container.container_id = ContainerDestination.container_id
	AND Container.company_id = ContainerDestination.company_id
	AND Container.profit_ctr_id = ContainerDestination.profit_ctr_id
	AND Container.container_type = ContainerDestination.container_type
LEFT OUTER JOIN #outbounds 
	ON ContainerDestination.tracking_num = #outbounds.outbound_receipt
	AND ContainerDestination.profit_ctr_id = #outbounds.profit_ctr_id
	AND ContainerDestination.company_id = #outbounds.company_id
WHERE 1=1
	AND Receipt.receipt_status IN ('L', 'U', 'A') 
	AND Receipt.trans_type = 'D'
	AND Receipt.trans_mode = 'I'
	AND Receipt.fingerpr_status NOT IN ('V', 'R')
	AND Receipt.receipt_date > '7-31-99'
	AND Container.status IN ('N', 'C')
	AND Container.container_type = 'R'
	AND ContainerDestination.status = 'C' 
	AND ContainerDestination.tracking_num IN (
		SELECT outbound_receipt 
		FROM #outbounds 
		WHERE profit_ctr_id = ContainerDestination.profit_ctr_id 
			AND company_id = ContainerDestination.company_id
		)
GROUP BY
	Receipt.company_id,
	-- ContainerDestination.receipt_id, 
	-- ContainerDestination.line_id,
	-- ContainerDestination.container_id,
	ContainerDestination.profit_ctr_id --,
	-- Receipt.trans_type,
	-- ContainerDestination.container_type,
	-- Receipt.manifest,
	-- Receipt.approval_code,
	-- Receipt.waste_code,
	-- Receipt.bill_unit_code,
	-- Receipt.receipt_date,
	-- ContainerDestination.location,
	-- Container.staging_row,
	-- Receipt.location,
	-- Receipt.fingerpr_status,
	-- COALESCE(ContainerDestination.treatment_id, Receipt.treatment_id),
	-- Container.container_size,
	-- Container.container_weight,
	-- ContainerDestination.tsdf_approval_code,
	-- #outbounds.outbound_receipt,
	-- #outbounds.receipt_date

UNION ALL

-- 2A -- Get Incomplete Receipt Transfer/ContainerDestination records 
--	ContainerDestination.status = 'N'
SELECT DISTINCT 
	-- ContainerDestination.receipt_id, 
	-- ContainerDestination.line_id,
	ContainerDestination.profit_ctr_id,
	-- ContainerDestination.container_type,
	-- ContainerDestination.container_id,
	-- 'TFER' AS load_type,
	-- Container.manifest,
	-- ContainerDestination.tsdf_approval_code,
	-- NULL AS waste_code,
	COUNT(ContainerDestination.container_id) AS containers_on_site,
	-- ContainerDestination.TSDF_approval_bill_unit_code,
	-- Receipt.receipt_date,
	-- ISNULL(ContainerDestination.Location, '') AS location, 
	-- DATEDIFF(dd, receipt.receipt_date, getdate()) AS days_on_site,
	-- getdate() AS as_of_date,
	-- CONVERT(varchar(15),'') AS tracking_num,
	-- ISNULL(Container.staging_row, '') AS staging_row,
	-- 'A' AS fingerpr_status,
	-- COALESCE(ContainerDestination.treatment_id, Receipt.treatment_id) AS treatment_id,
	-- Container.container_size,
	-- Container.container_weight,
	-- ISNULL(ContainerDestination.tsdf_approval_code, '') AS tsdf_approval_code,
	Receipt.company_id --,
	-- NULL AS outbound_receipt,
	-- NULL AS outbound_receipt_date
FROM Receipt Receipt
INNER JOIN Container Container 
	ON Receipt.receipt_id = Container.receipt_id
	AND Receipt.line_id = Container.line_id
	AND Receipt.profit_ctr_id = Container.profit_ctr_id
	AND Receipt.company_id = Container.company_id
INNER JOIN ContainerDestination ContainerDestination 
	ON Container.receipt_id = ContainerDestination.receipt_id
	AND Container.line_id = ContainerDestination.line_id
	AND Container.container_id = ContainerDestination.container_id
	AND Container.company_id = ContainerDestination.company_id
	AND Container.profit_ctr_id = ContainerDestination.profit_ctr_id
	AND Container.container_type = ContainerDestination.container_type
WHERE 1=1
	AND Receipt.receipt_status IN ('N', 'U', 'A') 
	AND Receipt.trans_type = 'X'
	AND Receipt.trans_mode = 'I'
	AND Receipt.fingerpr_status IS NULL
	AND Receipt.receipt_date > '7-31-99'
	AND Container.status IN ('N','C')
	AND Container.container_type = 'R'
	AND ContainerDestination.status = 'N'
GROUP BY
	Receipt.company_id,
	-- ContainerDestination.receipt_id, 
	-- ContainerDestination.line_id,
	-- ContainerDestination.container_id,
	ContainerDestination.profit_ctr_id --,
	-- Receipt.trans_type,
	-- ContainerDestination.container_type,
	-- Container.manifest,
	-- ContainerDestination.tsdf_approval_code,
	-- ContainerDestination.TSDF_approval_bill_unit_code,
	-- Receipt.receipt_date,
	-- ContainerDestination.location,
	-- Container.staging_row,
	-- Receipt.location,
	-- COALESCE(ContainerDestination.treatment_id, Receipt.treatment_id),
	-- Container.container_size,
	-- Container.container_weight,
	-- ContainerDestination.tsdf_approval_code

UNION ALL

-- 2B -- Get Incomplete Receipt Transfer/ContainerDestination records
--	ContainerDestination.status = 'C' but outbound not accepted
SELECT DISTINCT 
	-- ContainerDestination.receipt_id, 
	-- ContainerDestination.line_id,
	ContainerDestination.profit_ctr_id,
	-- ContainerDestination.container_type,
	-- ContainerDestination.container_id,
	-- 'TFER' AS load_type,
	-- Container.manifest,
	-- ContainerDestination.tsdf_approval_code,
	-- NULL AS waste_code,
	COUNT(ContainerDestination.container_id) AS containers_on_site,
	-- ContainerDestination.TSDF_approval_bill_unit_code,
	-- Receipt.receipt_date,
	-- ISNULL(ContainerDestination.Location, '') AS location, 
	-- DATEDIFF(dd, receipt.receipt_date, getdate()) AS days_on_site,
	-- getdate() AS as_of_date,
	-- CONVERT(varchar(15),'') AS tracking_num,
	-- ISNULL(Container.staging_row, '') AS staging_row,
	-- 'A' AS fingerpr_status,
	-- COALESCE(ContainerDestination.treatment_id, Receipt.treatment_id) AS treatment_id,
	-- Container.container_size,
	-- Container.container_weight,
	-- ISNULL(ContainerDestination.tsdf_approval_code, '') AS tsdf_approval_code,
	Receipt.company_id --,
	-- #outbounds.outbound_receipt,
	-- #outbounds.receipt_date AS outbound_receipt_date
FROM Receipt Receipt
INNER JOIN Container Container
	ON Receipt.receipt_id = Container.receipt_id
	AND Receipt.line_id = Container.line_id
	AND Receipt.profit_ctr_id = Container.profit_ctr_id
	AND Receipt.company_id = Container.company_id
INNER JOIN ContainerDestination ContainerDestination
	ON Container.receipt_id = ContainerDestination.receipt_id
	AND Container.line_id = ContainerDestination.line_id
	AND Container.container_id = ContainerDestination.container_id
	AND Container.company_id = ContainerDestination.company_id
	AND Container.profit_ctr_id = ContainerDestination.profit_ctr_id
	AND Container.container_type = ContainerDestination.container_type
LEFT OUTER JOIN #outbounds 
	ON ContainerDestination.tracking_num = #outbounds.outbound_receipt
	AND ContainerDestination.profit_ctr_id = #outbounds.profit_ctr_id
	AND ContainerDestination.company_id = #outbounds.company_id
WHERE 1=1
	AND Receipt.receipt_status IN ('N', 'U', 'A') 
	AND Receipt.trans_type = 'X'
	AND Receipt.trans_mode = 'I'
	AND Receipt.fingerpr_status IS NULL
	AND Receipt.receipt_date > '7-31-99'
	AND Container.status IN ('N','C')
	AND Container.container_type = 'R'
	AND ContainerDestination.status = 'C' 
	AND ContainerDestination.tracking_num IN (
		SELECT outbound_receipt 
		FROM #outbounds 
		WHERE profit_ctr_id = ContainerDestination.profit_ctr_id 
			AND company_id = ContainerDestination.company_id
		)
		
GROUP BY
	Receipt.company_id,
	-- ContainerDestination.receipt_id, 
	-- ContainerDestination.line_id,
	-- ContainerDestination.container_id,
	ContainerDestination.profit_ctr_id --,
	-- Receipt.trans_type,
	-- ContainerDestination.container_type,
	-- Container.manifest,
	-- ContainerDestination.tsdf_approval_code,
	-- ContainerDestination.TSDF_approval_bill_unit_code,
	-- Receipt.receipt_date,
	-- ContainerDestination.location,
	-- Container.staging_row,
	-- Receipt.location,
	-- COALESCE(ContainerDestination.treatment_id, Receipt.treatment_id),
	-- Container.container_size,
	-- Container.container_weight,
	-- ContainerDestination.tsdf_approval_code,
	-- #outbounds.outbound_receipt,
	-- #outbounds.receipt_date

UNION ALL

-- 3A -- Include Incomplete Stock Label Drum records without a tracking number
--	ContainerDestination.status = 'N'
SELECT DISTINCT 
	-- ContainerDestination.receipt_id, 
	-- ContainerDestination.line_id,
	ContainerDestination.profit_ctr_id,
	-- ContainerDestination.container_type,
	-- ContainerDestination.container_id AS container_id,
	-- 'STOCK' AS load_type,
	-- '' AS manifest,
	-- '' AS approval_code,
	-- '' AS waste_code,
	1 AS containers_on_site,
	-- '' AS bill_unit_code,
	-- ContainerDestination.date_added AS receipt_date,
	-- ISNULL(ContainerDestination.Location, '') AS location, 
	-- DATEDIFF(dd, ContainerDestination.date_added, getdate()) AS days_on_site,
	-- getdate() AS as_of_date,
	-- -- tracking_num = dbo.fn_container_stock(ContainerDestination.line_id, ContainerDestination.profit_ctr_id),
	-- tracking_num = 'DL-' 
	-- 	+ RIGHT('00' + Convert(varchar(2), Container.company_id), 2)
	-- 	+ RIGHT('00' + Convert(varchar(2), ContainerDestination.profit_ctr_ID), 2)
	-- 	+ '-' 
	-- 	+ RIGHT('000000' + Convert(varchar(15), ContainerDestination.line_id), 6),
	-- ISNULL(Container.staging_row, '') AS staging_row,
	-- Case
	-- 	(Select count(*) from containerDestination cd2
	-- 	where cd2.profit_ctr_id = ContainerDestination.profit_ctr_id
	-- 		AND cd2.company_id = Container.company_id
	-- 		AND cd2.base_container_id = container.container_id)
	-- 	When 0 then ''
	-- 		Else
	-- 		 CASE (
	-- 			Select count(*) 
	-- 			from receipt receipt 
	-- 			join containerDestination cd2 
	-- 				on receipt.receipt_id = cd2.receipt_id 
	-- 				and receipt.line_id = cd2.line_id
	-- 				and receipt.profit_ctr_id = cd2.profit_ctr_id
	-- 				and receipt.company_id = cd2.company_id
	-- 			where cd2.profit_ctr_id = containerDestination.profit_ctr_id
	-- 				AND cd2.company_id = Container.company_id
	-- 				AND cd2.base_container_id = container.container_id				
	-- 				AND fingerpr_status not in ('A','V')
	-- 			)
	-- 		 When 0 then 'A'
	-- 		 Else ''
	-- 		End
	-- 	End
	-- 	AS fingerpr_status,
	-- ContainerDestination.treatment_id,
	-- Container.container_size,
	-- Container.container_weight,
	-- ISNULL(ContainerDestination.tsdf_approval_code, '') AS tsdf_approval_code,
	Container.company_id --,
	-- NULL AS outbound_receipt,
	-- NULL AS outbound_receipt_date
FROM Container Container
INNER JOIN ContainerDestination ContainerDestination 
	ON Container.receipt_id = ContainerDestination.receipt_id
	AND Container.line_id = ContainerDestination.line_id
	AND Container.container_id = ContainerDestination.container_id
	AND Container.company_id = ContainerDestination.company_id
	AND Container.profit_ctr_id = ContainerDestination.profit_ctr_id
	AND Container.container_type = ContainerDestination.container_type
WHERE Container.container_type = 'S'
	AND Container.status IN ('N','C')
	AND ContainerDestination.status = 'N'
GROUP BY
	Container.company_id,
	-- ContainerDestination.receipt_id, 
	-- ContainerDestination.line_id,
	-- ContainerDestination.container_id,
	-- Container.container_id,
	ContainerDestination.profit_ctr_id --,
	-- ContainerDestination.container_type,
	-- ContainerDestination.Date_added,
	-- ContainerDestination.location,
	-- Container.staging_row,
	-- ContainerDestination.treatment_id,
	-- Container.container_size,
	-- Container.container_weight,
	-- ContainerDestination.tsdf_approval_code

UNION ALL

-- 3B -- Include Incomplete Stock Label Drum records without a tracking number
--	ContainerDestination.status = 'C' but outbound not accepted
SELECT DISTINCT 
	-- ContainerDestination.receipt_id, 
	-- ContainerDestination.line_id,
	ContainerDestination.profit_ctr_id,
	-- ContainerDestination.container_type,
	-- ContainerDestination.container_id AS container_id,
	-- 'STOCK' AS load_type,
	-- '' AS manifest,
	-- '' AS approval_code,
	-- '' AS waste_code,
	1 AS containers_on_site,
	-- '' AS bill_unit_code,
	-- ContainerDestination.date_added AS receipt_date,
	-- ISNULL(ContainerDestination.Location, '') AS location, 
	-- DATEDIFF(dd, ContainerDestination.date_added, getdate()) AS days_on_site,
	-- getdate() AS as_of_date,
	-- -- tracking_num = dbo.fn_container_stock(ContainerDestination.line_id, ContainerDestination.profit_ctr_id),
	-- tracking_num = 'DL-' 
	-- 	+ RIGHT('00' + Convert(varchar(2), Container.company_id), 2)
	-- 	+ RIGHT('00' + Convert(varchar(2), ContainerDestination.profit_ctr_ID), 2)
	-- 	+ '-' 
	-- 	+ RIGHT('000000' + Convert(varchar(15), ContainerDestination.line_id), 6),
	-- ISNULL(Container.staging_row, '') AS staging_row,
	-- Case
	-- 	(Select count(*) from containerDestination cd2
	-- 	where cd2.profit_ctr_id = ContainerDestination.profit_ctr_id
	-- 		AND cd2.company_id = Container.company_id
	-- 		AND cd2.base_container_id = container.container_id)
	-- 	When 0 then ''
	-- 		Else
	-- 		 CASE (
	-- 			Select count(*) 
	-- 			from receipt receipt
	-- 			join containerDestination cd2
	-- 				on receipt.receipt_id = cd2.receipt_id 
	-- 				and	receipt.line_id = cd2.line_id 
	-- 				and receipt.profit_ctr_id = cd2.profit_ctr_id
	-- 				and receipt.company_id = cd2.company_id
	-- 			where cd2.base_container_id = container.container_id 
	-- 				and cd2.profit_ctr_id = ContainerDestination.profit_ctr_id
	-- 				and cd2.company_id = container.company_id
	-- 				and	fingerpr_status not in ('A','V')
	-- 			)
	-- 		 When 0 then 'A'
	-- 		 Else ''
	-- 		End
	-- 	End
	-- 	AS fingerpr_status,
	-- ContainerDestination.treatment_id,
	-- Container.container_size,
	-- Container.container_weight,
	-- ISNULL(ContainerDestination.tsdf_approval_code, '') AS tsdf_approval_code,
	Container.company_id --,
	-- #outbounds.outbound_receipt,
	-- #outbounds.receipt_date AS outbound_receipt_date
FROM Container Container
INNER JOIN ContainerDestination ContainerDestination 
	ON Container.receipt_id = ContainerDestination.receipt_id
	AND Container.line_id = ContainerDestination.line_id
	AND Container.container_id = ContainerDestination.container_id
	AND Container.company_id = ContainerDestination.company_id
	AND Container.profit_ctr_id = ContainerDestination.profit_ctr_id
	AND Container.container_type = ContainerDestination.container_type
LEFT OUTER JOIN #outbounds 
	ON ContainerDestination.tracking_num = #outbounds.outbound_receipt
	AND ContainerDestination.profit_ctr_id = #outbounds.profit_ctr_id
	AND ContainerDestination.company_id = #outbounds.company_id
WHERE Container.container_type = 'S'
	AND Container.status IN ('N','C')
	AND ContainerDestination.status = 'C' 
	AND ContainerDestination.tracking_num IN (
		SELECT outbound_receipt 
		FROM #outbounds 
		WHERE profit_ctr_id = ContainerDestination.profit_ctr_id 
			AND company_id = ContainerDestination.company_id
		)
GROUP BY
	Container.company_id,
	-- ContainerDestination.receipt_id, 
	-- ContainerDestination.line_id,
	-- ContainerDestination.container_id,
	-- Container.container_id,
	ContainerDestination.profit_ctr_id --,
	-- ContainerDestination.container_type,
	-- ContainerDestination.Date_added,
	-- ContainerDestination.location,
	-- Container.staging_row,
	-- ContainerDestination.treatment_id,
	-- Container.container_size,
	-- Container.container_weight,
	-- ContainerDestination.tsdf_approval_code,
	-- #outbounds.outbound_receipt,
	-- #outbounds.receipt_date

-- Return Results
/*
	SELECT DISTINCT 
		#tmp.receipt_id, 
		#tmp.line_id,
		#tmp.profit_ctr_id,
		#tmp.container_type,
		#tmp.container_id,
		#tmp.load_type,
		#tmp.manifest,
		#tmp.approval_code,
		#tmp.waste_code,
		SUM(#tmp.containers_on_site) containers_on_site,
		#tmp.bill_unit_code,
		#tmp.receipt_date,
		#tmp.location, 
		#tmp.days_on_site,
		#tmp.as_of_date,
		#tmp.tracking_num,
		#tmp.staging_row,
		#tmp.fingerpr_status,
		#tmp.treatment_id,
		Treatment.treatment_desc,
		#tmp.container_size,
		#tmp.container_weight,
		#tmp.tsdf_approval_code,
		#tmp.company_id,
		#tmp.outbound_receipt,
		#tmp.outbound_receipt_date
	FROM #tmp
	LEFT OUTER JOIN Treatment Treatment
		ON #tmp.treatment_id = Treatment.treatment_id
		AND #tmp.profit_ctr_id = Treatment.profit_ctr_id
		AND #tmp.company_id = Treatment.company_id
	GROUP BY
		#tmp.company_id,
		#tmp.receipt_id, 
		#tmp.line_id,
		#tmp.profit_ctr_id,
		#tmp.container_type,
		#tmp.container_id,
		#tmp.load_type,
		#tmp.manifest,
		#tmp.approval_code,
		#tmp.waste_code,
		#tmp.bill_unit_code,
		#tmp.receipt_date,
		#tmp.location, 
		#tmp.days_on_site,
		#tmp.as_of_date,
		#tmp.tracking_num,
		#tmp.staging_row,
		#tmp.fingerpr_status,
		#tmp.treatment_id,
		Treatment.treatment_desc,
		#tmp.container_size,
		#tmp.container_weight,
		#tmp.tsdf_approval_code,
		#tmp.outbound_receipt,
		#tmp.outbound_receipt_date
		
-- Here's an option to reconsider someday: We could un -- comment the
-- Union Select above then use this select to return daily info on
-- inventory per treatment, bill_unit, waste_code, etc.
-- but for initial launch, we just count per profit_ctr_id.		
	SELECT
		#tmp.company_id,
		#tmp.profit_ctr_id,
		#tmp.as_of_date,
		#tmp.waste_code,
		SUM(#tmp.containers_on_site) containers_on_site,
		#tmp.bill_unit_code,
		AVG(#tmp.days_on_site) avg_days_on_site,
		#tmp.staging_row,
		#tmp.treatment_id,
		Treatment.treatment_desc
	FROM #tmp
	LEFT OUTER JOIN Treatment Treatment
		ON #tmp.treatment_id = Treatment.treatment_id
		AND #tmp.profit_ctr_id = Treatment.profit_ctr_id
		AND #tmp.company_id = Treatment.company_id
	GROUP BY
		#tmp.company_id,
		#tmp.profit_ctr_id,
		#tmp.as_of_date,
		#tmp.waste_code,
		#tmp.bill_unit_code,
		#tmp.staging_row,
		#tmp.treatment_id,
		Treatment.treatment_desc
*/

INSERT DashboardResult (
	company_id,
	profit_ctr_id,
	measurement_id,
	report_period_end_date,
	answer,
	note,
	threshold_value,
	threshold_operator,
	date_modified,
	modified_by,
	added_by,
	date_added
)	
	SELECT
		#tmp.company_id,
		#tmp.profit_ctr_id,
		@measurement_id measurement_id,
		CONVERT (VARCHAR, getdate(), 101) AS report_period_end_date,
		convert(varchar(20), SUM(#tmp.containers_on_site)) answer,
		NULL AS note,
		dm.threshold_value,
		dm.threshold_operator,
		GETDATE() AS date_modified,
		SYSTEM_USER AS modified_by,
		SYSTEM_USER AS added_by,
		GETDATE() AS date_added
	FROM DashboardMeasurement dm
		INNER JOIN DashboardTier dt ON dm.tier_id = dt.tier_id
		LEFT OUTER JOIN #tmp ON 1=1
	WHERE 
		dm.measurement_id = @measurement_id
	GROUP BY
		#tmp.company_id,
		#tmp.profit_ctr_id,
		dm.threshold_value,
		dm.threshold_operator
	ORDER BY
		#tmp.company_id,
		#tmp.profit_ctr_id

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_dash_container_inventory] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_dash_container_inventory] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_dash_container_inventory] TO [EQAI]
    AS [dbo];

