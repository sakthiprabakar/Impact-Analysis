 
CREATE PROCEDURE sp_rpt_container_inventory_for_date_range
	@start_date datetime,
	@end_date datetime,
	@copc varchar(20), -- '<co>|<pc> format 
	@bulk_flag char(1) = NULL -- 'F' -- 'T' or 'F'
	
/*

	02-11-2010	RJG	Created	
	2018-01-08	JPB	Added Isolation level statement at top, no other changes.
	
Examples: 
exec sp_rpt_container_inventory_for_date_range '02/18/2010', '02/18/2010', '21|0'
exec sp_rpt_container_inventory_for_date_range '02/18/2010', '02/18/2010', '22|0'
exec sp_rpt_container_inventory_for_date_range '02/18/2010', '02/18/2010', '2|21'
exec sp_rpt_container_inventory_for_date_range '12/01/2009', '12/10/2009', '14|4'
exec sp_rpt_container_inventory_for_date_range '12/01/2009', '12/10/2009', '22|0'
exec sp_rpt_container_inventory_for_date_range '12/01/2009', '12/15/2009', '22|0'
exec sp_rpt_container_inventory_for_date_range '12/01/2009', '12/15/2009', '2|21'
exec sp_rpt_container_inventory_for_date_range '12/01/2009', '12/31/2009', '14|4'
exec sp_rpt_container_inventory_for_date_range '12/01/2009', '12/31/2009', '14|4', 'F'
exec sp_rpt_container_inventory_for_date_range '12/01/2009', '12/31/2009', '14|4', 'T'
exec sp_rpt_container_inventory_for_date_range '12/01/2009', '12/31/2009', '14|4', NULL
exec sp_rpt_container_inventory_for_date_range '12/01/2009', '12/31/2009', '21|0', NULL
exec sp_rpt_container_inventory_for_date_range '12/01/2009', '12/31/2009', '2|21'
exec sp_rpt_container_inventory_for_date_range '12/01/2009', '12/31/2009', '3|1', 'F'
exec sp_rpt_container_inventory_for_date_range '12/01/2009', '12/31/2009', '3|1', 'T'
exec sp_rpt_container_inventory_for_date_range '12/01/2009', '12/31/2009', '3|1', NULL
exec sp_rpt_container_inventory_for_date_range '12/04/2009', '12/05/2009', '2|21', 'F'
exec sp_rpt_container_inventory_for_date_range_detail '12/01/2009', '12/10/2009', '14|4'
	
*/
AS


SET NOCOUNT ON
SET ANSI_WARNINGS OFF
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

declare @debug int = NULL --NULL --1 -- various levels of debug verbosity
declare @debug_receipt_id int = NULL -- 102808 --103844 --102808 -- 7643 --736698 --735692 --NULL -- 736576 --NULL -- 736411 -- 736411 -- 82829 -- if this is specified, it will filter by this receipt_id (105974)
declare @debug_customer_id int = NULL  --10721 -- 10721 -- if this is specified, it will filter by this customer_id (10721)
declare @debug_container_id int = NULL -- if this is specified, it will filter by this container_id
declare @debug_haz_status char(1) = NULL -- T or F, for haz or non-haz
declare @debug_only_container_type varchar(10) = NULL --'S' -- if specified, will filter out for this container type
declare @debug_only_transfer_type varchar(1) = NULL --'XFER' -- XFER, DISP, STOCK
declare @start_time datetime = getdate()

if OBJECT_ID('tempdb.dbo.#tally') IS NOT NULL DROP TABLE #tally
if OBJECT_ID('tempdb.dbo.#dates') IS NOT NULL DROP TABLE #dates
if OBJECT_ID('tempdb.dbo.#container_rows') IS NOT NULL DROP TABLE #container_rows
if OBJECT_ID('tempdb.dbo.#reporting_rows') IS NOT NULL DROP TABLE #reporting_rows
if OBJECT_ID('tempdb.dbo.#converted_rows') IS NOT NULL DROP TABLE #converted_rows

DECLARE @company_id int
DECLARE @profit_ctr_id int


DECLARE @pound_to_gallon decimal(12,4)
SELECT @pound_to_gallon = gal_conv FROM BillUnit WHERE bill_unit_code = 'LBS'


SET @company_id = RTRIM(LTRIM(SUBSTRING(@copc, 1, CHARINDEX('|',@copc) - 1)))
SET @profit_ctr_id = RTRIM(LTRIM(SUBSTRING(@copc, CHARINDEX('|',@copc) + 1, LEN(@copc) - (CHARINDEX('|',@copc)-1))))

/* Insure inclusive date range values */
SET @end_date = CAST(convert(varchar(20), @end_date, 101) + ' 23:59:59' as datetime) 
SET @start_date = CAST(convert(varchar(20), @start_date, 101) + ' 00:00:00' as datetime) 
declare @tomorrow datetime = CAST(CONVERT(varchar(20), dateadd(dd,1,getdate()),101) as datetime)


/* Create "Tally" table(Ref: http://www.sqlservercentral.com/articles/T-SQL/62867/) */
SELECT TOP 11000 IDENTITY(int,1,1) as number
	INTO #tally 
	FROM master.dbo.syscolumns sc1,	master.dbo.syscolumns sc2
	
IF object_id ('tempdb..PK_Tally_Summary_N') IS NULL
BEGIN
ALTER TABLE #tally
	ADD CONSTRAINT PK_Tally_summary_N
	PRIMARY KEY CLUSTERED (number) WITH FILLFACTOR = 100
END


/*
	The cases we want to cover are:
	1) Grab containers (Receipt & Stock) where Receipt.receipt_date in the date range
	2) Grab containers (Receipt & Stock) where ContainerDestination.disposal_date is in the date range
	3) Grab containers (Receipt & Stock) where the Receipt.receipt_date was before the @start_date but the 
		ContainerDestination.disposal_date is after the @end_date
	
	These must be mutually exclusive (hence: UNION)
	
	If it has not been disposed of (ContainerDestination.disposal_date is null), then we use tomorrow as the disposal_date for calculations
*/

CREATE TABLE #container_rows
(
	company_id int NOT NULL, 
	profit_ctr_id int NOT NULL, 
	receipt_id int NOT NULL, 
	container_id int NOT NULL, 
	line_id int NOT NULL, 
	sequence_id int NOT NULL,
	receipt_date datetime NULL,
	disposal_date datetime,
	container_count int,
	converted_container_weight decimal(12,4),
	gallon_conversion_factor decimal(12,4),
	container_percent int,
	container_type varchar(10),
	is_hazardous char(1),
	conversion_unit_source varchar(50),
	conversion_weight_source varchar(50),
	conversion_factor_source varchar(50),
	transfer_type varchar(20)
)

CREATE TABLE #reporting_rows
(
	company_id int NOT NULL, 
	profit_ctr_id int NOT NULL, 
	receipt_id int NOT NULL, 
	container_id int NOT NULL, 
	line_id int NOT NULL, 
	sequence_id int NOT NULL,
	receipt_date datetime NOT NULL,
	disposal_date datetime NOT NULL,
	reporting_date datetime NOT NULL,
	total_item_count decimal(12,4) NULL,
	containers_on_site decimal(12,4) NULL,
	gallon_converted decimal(12,4) NULL,
	fifty_five_gallon_converted decimal(12,4) NULL,
	gallon_conversion_factor decimal(12,4) NULL,
	gallon_conversion_unit varchar(20) NULL,
	converted_container_weight decimal(12,4),
	container_percent int,
	container_type varchar(10),
	is_hazardous char(1),
	transfer_type varchar(50)
)


INSERT INTO #container_rows (
	company_id, 
	profit_ctr_id, 
	receipt_id, 
	container_id, 
	line_id, 
	sequence_id,
	receipt_date, 
	disposal_date, 
	container_count,
	container_percent,
	container_type,
	transfer_type)
	/**
		Receipt containers: receipt date between start/end parameters
	**/
SELECT  
		Container.company_id,
		Container.profit_ctr_id,	
		Container.receipt_id,
		Container.container_id,
		Container.line_id,
		ContainerDestination.sequence_id,
		Receipt.receipt_date, 
		ISNULL(
			ContainerDestination.disposal_date, 
			CAST(CONVERT(varchar(20), dateadd(dd,1,getdate()),101) as datetime)
		) as disposal_date,
		Receipt.container_count,
		ContainerDestination.container_percent,
		ContainerDestination.container_type,
		case when trans_type = 'X' THEN 'XFER'
			when trans_type = 'D' THEN 'DISP'
			else trans_type
		end as transfer_type
FROM Receipt 
INNER JOIN Container WITH(NOLOCK) ON Receipt.receipt_id = Container.receipt_id
	AND Receipt.line_id = Container.line_id
	AND Receipt.company_id = Container.company_id
	AND Receipt.profit_ctr_id = Container.profit_ctr_id
INNER JOIN ContainerDestination WITH(NOLOCK) ON Container.receipt_id = ContainerDestination.receipt_id
	AND Container.line_id = ContainerDestination.line_id
	AND Container.container_id = ContainerDestination.container_id
	AND Container.company_id = ContainerDestination.company_id
	AND Container.profit_ctr_id = ContainerDestination.profit_ctr_id
	AND Container.container_type = ContainerDestination.container_type
WHERE 
	Receipt.company_id = @company_id AND Receipt.profit_ctr_id = @profit_ctr_id
	AND Receipt.receipt_status IN ('L', 'U', 'A') /* Loading, Unloading, Accepted */
	AND (
			-- for normal disposal
		(
			Receipt.trans_type = 'D' 
			AND Receipt.fingerpr_status NOT IN ('V','R') /* Not Void / Rejected */
			AND Receipt.customer_id = COALESCE(@debug_customer_id, Receipt.customer_id)
		)
		OR
			-- for transfer containers
		(Receipt.trans_type = 'X' and Receipt.fingerpr_status IS NULL)
	)
	AND Receipt.trans_mode = 'I' /* Inbound */
	AND Receipt.receipt_date > '7-31-99' 
	AND Receipt.bulk_flag = COALESCE(@bulk_flag, Receipt.bulk_flag)
	AND (
		/* IT Standard: we want to include the Receipt_Date and NOT the Disposal_date */
		(Receipt.receipt_date >= @start_date AND Receipt.receipt_date < @end_date)
	)
	AND Container.status NOT IN ('V','R') /* not Void / Rejected */
	AND Container.container_type = 'R' /* Receipt container */
	AND Receipt.receipt_id = COALESCE(@debug_receipt_id, Receipt.receipt_id)
	AND ContainerDestination.container_id = COALESCE(@debug_container_id, ContainerDestination.container_id)
	
UNION	

	/**
		Receipt containers: disposal date before end parameter and after "loop" date
	**/
SELECT
		Container.company_id,
		Container.profit_ctr_id,	
		Container.receipt_id,
		Container.container_id,
		Container.line_id,
		ContainerDestination.sequence_id,
		Receipt.receipt_date, 
		ISNULL(
			ContainerDestination.disposal_date, 
			CAST(CONVERT(varchar(20), dateadd(dd,1,getdate()),101) as datetime)
	) as disposal_date,
	Receipt.container_count,
	ContainerDestination.container_percent,
		ContainerDestination.container_type,
		case when trans_type = 'X' THEN 'XFER'
			when trans_type = 'D' THEN 'DISP'
		end as transfer_type		
FROM Receipt 
INNER JOIN Container WITH(NOLOCK) ON Receipt.receipt_id = Container.receipt_id
	AND Receipt.line_id = Container.line_id
	AND Receipt.company_id = Container.company_id
	AND Receipt.profit_ctr_id = Container.profit_ctr_id
INNER JOIN ContainerDestination WITH(NOLOCK) ON Container.receipt_id = ContainerDestination.receipt_id
	AND Container.line_id = ContainerDestination.line_id
	AND Container.container_id = ContainerDestination.container_id
	AND Container.company_id = ContainerDestination.company_id
	AND Container.profit_ctr_id = ContainerDestination.profit_ctr_id
	AND Container.container_type = ContainerDestination.container_type
WHERE 
	Receipt.company_id = @company_id AND Receipt.profit_ctr_id = @profit_ctr_id
	AND Receipt.receipt_status IN ('L', 'U', 'A') /* Loading, Unloading, Accepted */
	AND (
			-- for normal disposal
		(
			Receipt.trans_type = 'D' 
			AND Receipt.fingerpr_status NOT IN ('V','R') /* Not Void / Rejected */)
			AND Receipt.customer_id = COALESCE(@debug_customer_id, Receipt.customer_id)
		OR
			-- for transfer containers
		(Receipt.trans_type = 'X' and Receipt.fingerpr_status IS NULL)
	)
	AND Receipt.trans_mode = 'I' /* Inbound */
	AND Receipt.receipt_date > '7-31-99' 
	AND Receipt.bulk_flag = COALESCE(@bulk_flag, Receipt.bulk_flag)
	AND
	(
		/* IT Standard: we want to include the Receipt_Date and NOT the Disposal_date */
		(ISNULL(ContainerDestination.disposal_date, dateadd(dd,1,getdate())) >= @start_date AND ContainerDestination.disposal_date < @end_date)
	)
	AND Container.status NOT IN ('V','R') /* Not Void / Rejected */
	AND Container.container_type = 'R' /* Receipt Container */
	AND Receipt.receipt_id = COALESCE(@debug_receipt_id, Receipt.receipt_id)
	AND ContainerDestination.container_id = COALESCE(@debug_container_id, ContainerDestination.container_id)
	
UNION
	
/*** Receipt Container Received before @start_date and disposed sometime after @end_date (outside of reporting range) ***/
SELECT
		Container.company_id,
		Container.profit_ctr_id,	
		Container.receipt_id,
		Container.container_id,
		Container.line_id,
		ContainerDestination.sequence_id,
		Receipt.receipt_date, 
		ISNULL(
			ContainerDestination.disposal_date, 
			CAST(CONVERT(varchar(20), dateadd(dd,1,getdate()),101) as datetime)
	) as disposal_date,
	Receipt.container_count,
	ContainerDestination.container_percent,
		ContainerDestination.container_type,
		case when trans_type = 'X' THEN 'XFER'
			when trans_type = 'D' THEN 'DISP'
		end as transfer_type
FROM Receipt 
INNER JOIN Container WITH(NOLOCK) ON Receipt.receipt_id = Container.receipt_id
	AND Receipt.line_id = Container.line_id
	AND Receipt.company_id = Container.company_id
	AND Receipt.profit_ctr_id = Container.profit_ctr_id
INNER JOIN ContainerDestination WITH(NOLOCK) ON Container.receipt_id = ContainerDestination.receipt_id
	AND Container.line_id = ContainerDestination.line_id
	AND Container.container_id = ContainerDestination.container_id
	AND Container.company_id = ContainerDestination.company_id
	AND Container.profit_ctr_id = ContainerDestination.profit_ctr_id
	AND Container.container_type = ContainerDestination.container_type
WHERE 
	Receipt.company_id = @company_id AND Receipt.profit_ctr_id = @profit_ctr_id
	AND Receipt.receipt_status IN ('L', 'U', 'A') /* Loading, Unloading, Accepted */
	AND (
			-- for normal disposal
			(
				Receipt.trans_type = 'D' 
				AND Receipt.fingerpr_status NOT IN ('V','R') /* Not Void / Rejected */
				AND Receipt.customer_id = COALESCE(@debug_customer_id, Receipt.customer_id)
			)
		OR
			-- for transfer containers
		(Receipt.trans_type = 'X' and Receipt.fingerpr_status IS NULL)
	)
	AND Receipt.trans_mode = 'I' /* Inbound */
	AND Receipt.receipt_date > '7-31-99' 
	AND Receipt.bulk_flag = COALESCE(@bulk_flag, Receipt.bulk_flag)
	AND 
	(
		/* IT Standard: we want to include the Receipt_Date and NOT the Disposal_date */
		(Receipt.receipt_date < @start_date AND 
				(
					ISNULL(
						ContainerDestination.disposal_date, 
						CAST(CONVERT(varchar(20), dateadd(dd,1,getdate()),101) as datetime)
					) > @end_date
					AND ISNULL(
						ContainerDestination.disposal_date, 
						CAST(CONVERT(varchar(20), dateadd(dd,1,getdate()),101) as datetime)
					) < CAST(CONVERT(varchar(20), dateadd(dd,2,getdate()),101) as datetime)
				)
		)
	)
	AND Container.status NOT IN ('V','R') /* Not Void / Rejected */
	AND Container.container_type = 'R' /* Receipt Container */
	AND Receipt.receipt_id = COALESCE(@debug_receipt_id, Receipt.receipt_id)
	AND ContainerDestination.container_id = COALESCE(@debug_container_id, ContainerDestination.container_id)
	
	
UNION
SELECT * FROM 
(

/* 
	Stock Containers: date_added between start/end parameters 
*/

SELECT  
		ContainerDestination.company_id,
		ContainerDestination.profit_ctr_id,	
		ContainerDestination.receipt_id,
		ContainerDestination.container_id,
		ContainerDestination.line_id,
		ContainerDestination.sequence_id,
				'calc_receipt_date' = (
				--SELECT ISNULL(MIN(b.disposal_date), '1/1/2999') FROM ContainerDestination b
				SELECT MIN(b.disposal_date) FROM ContainerDestination b
				WHERE b.base_container_id = ContainerDestination.container_id
				AND b.base_tracking_num LIKE 'DL-%'
				AND b.company_id = @company_id and b.profit_ctr_id = @profit_ctr_id),
		ISNULL(
			ContainerDestination.disposal_date, 
			CAST(CONVERT(varchar(20), dateadd(dd,1,getdate()),101) as datetime)
		) as disposal_date,
		1 as container_count,
		ContainerDestination.container_percent,
			ContainerDestination.container_type,
			'STOCK' as transfer_type
FROM Container
INNER JOIN ContainerDestination WITH(NOLOCK) ON Container.receipt_id = ContainerDestination.receipt_id
	AND Container.line_id = ContainerDestination.line_id
	AND Container.container_id = ContainerDestination.container_id
	AND Container.company_id = ContainerDestination.company_id
	AND Container.profit_ctr_id = ContainerDestination.profit_ctr_id
	AND Container.container_type = ContainerDestination.container_type
WHERE Container.container_type = 'S'
	AND @bulk_flag = 'F'
	AND Container.status IN ('N','C')
	AND ContainerDestination.status IN('N','C')
	AND Container.company_id = @company_id
	AND Container.profit_ctr_id = @profit_ctr_id
		--AND ContainerDestination.date_added > '7-31-99' AND 
		--(
		--	/* IT Standard: we want to include the Receipt_Date and NOT the Disposal_date */
		--	(ContainerDestination.date_added >= @start_date AND ContainerDestination.date_added < @end_date)
		--)	
		AND ContainerDestination.container_id = COALESCE(@debug_container_id, ContainerDestination.container_id)
) tmp where 
		 calc_receipt_date > '7-31-99' AND 
		(
			/* IT Standard: we want to include the Receipt_Date and NOT the Disposal_date */
			(calc_receipt_date >= @start_date AND calc_receipt_date < @end_date)
		)
	
UNION

/* 
	Stock Containers: disposal date before end parameter and after "loop" date
*/

SELECT  
		ContainerDestination.company_id,
		ContainerDestination.profit_ctr_id,	
		ContainerDestination.receipt_id,
		ContainerDestination.container_id,
		ContainerDestination.line_id,
		ContainerDestination.sequence_id,
							'calc_receipt_date' = (
			--SELECT ISNULL(MIN(b.disposal_date), '1/1/2999') FROM ContainerDestination b
			SELECT MIN(b.disposal_date) FROM ContainerDestination b
			WHERE b.base_container_id = ContainerDestination.container_id
			AND b.base_tracking_num LIKE 'DL-%'
			AND b.company_id = @company_id and b.profit_ctr_id = @profit_ctr_id),
		ISNULL(
			ContainerDestination.disposal_date, 
			CAST(CONVERT(varchar(20), dateadd(dd,1,getdate()),101) as datetime)
		) as disposal_date,
		1 as container_count,
		ContainerDestination.container_percent,
		ContainerDestination.container_type,
			'STOCK' as transfer_type
FROM Container
INNER JOIN ContainerDestination WITH(NOLOCK) ON Container.receipt_id = ContainerDestination.receipt_id
	AND Container.line_id = ContainerDestination.line_id
	AND Container.container_id = ContainerDestination.container_id
	AND Container.company_id = ContainerDestination.company_id
	AND Container.profit_ctr_id = ContainerDestination.profit_ctr_id
	AND Container.container_type = ContainerDestination.container_type
WHERE Container.container_type = 'S'
	AND @bulk_flag = 'F'
	AND Container.status IN ('N','C')
	AND ContainerDestination.status IN('N','C')
	AND Container.company_id = @company_id
	AND Container.profit_ctr_id = @profit_ctr_id
	AND ContainerDestination.date_added > '7-31-99' AND 
	(
		/* IT Standard: we want to include the Receipt_Date and NOT the Disposal_date */
		(ISNULL(ContainerDestination.disposal_date, dateadd(dd,1,getdate())) >= @start_date AND ContainerDestination.disposal_date < @end_date)
	)		
	AND ContainerDestination.container_id = COALESCE(@debug_container_id, ContainerDestination.container_id)



UNION

/* 
	Stock Containers: disposal date before start parameter and after end parameter
*/

SELECT  * FROM ( 
	SELECT
		ContainerDestination.company_id,
		ContainerDestination.profit_ctr_id,	
		ContainerDestination.receipt_id,
		ContainerDestination.container_id,
		ContainerDestination.line_id,
		ContainerDestination.sequence_id,
				'calc_receipt_date' = (
				--SELECT ISNULL(MIN(b.disposal_date), '1/1/2999') FROM ContainerDestination b
				SELECT MIN(b.disposal_date) FROM ContainerDestination b
				WHERE b.base_container_id = ContainerDestination.container_id
				AND b.base_tracking_num LIKE 'DL-%'
				AND b.company_id = @company_id and b.profit_ctr_id = @profit_ctr_id),
		ISNULL(
			ContainerDestination.disposal_date, 
			CAST(CONVERT(varchar(20), dateadd(dd,1,getdate()),101) as datetime)
		) as disposal_date,
		1 as container_count,
		ContainerDestination.container_percent,
			ContainerDestination.container_type,
			'STOCK' as transfer_type
FROM Container
INNER JOIN ContainerDestination WITH(NOLOCK) ON Container.receipt_id = ContainerDestination.receipt_id
	AND Container.line_id = ContainerDestination.line_id
	AND Container.container_id = ContainerDestination.container_id
	AND Container.company_id = ContainerDestination.company_id
	AND Container.profit_ctr_id = ContainerDestination.profit_ctr_id
	AND Container.container_type = ContainerDestination.container_type
WHERE Container.container_type = 'S'
	AND @bulk_flag = 'F'
	AND Container.status IN ('N','C')
	AND ContainerDestination.status IN('N','C')
	AND Container.company_id = @company_id
	AND Container.profit_ctr_id = @profit_ctr_id
		--AND ContainerDestination.date_added > '7-31-99' AND 
		--(
		--	/* IT Standard: we want to include the Receipt_Date and NOT the Disposal_date */
		--	ContainerDestination.date_added < @start_date 
		--	AND ISNULL(ContainerDestination.disposal_date, CAST(CONVERT(varchar(20), dateadd(dd,1,getdate()),101) as datetime)) > @end_date
		--	AND ISNULL(ContainerDestination.disposal_date, CAST(CONVERT(varchar(20), dateadd(dd,1,getdate()),101) as datetime)) < CAST(CONVERT(varchar(20), dateadd(dd,2,getdate()),101) as datetime)
		--)	
		AND ContainerDestination.container_id = COALESCE(@debug_container_id, ContainerDestination.container_id)
) tbl
WHERE
calc_receipt_date > '7-31-99' AND 
		(
			/* IT Standard: we want to include the Receipt_Date and NOT the Disposal_date */
			calc_receipt_date < @start_date 
			AND disposal_date > @end_date
			AND disposal_date < CAST(CONVERT(varchar(20), dateadd(dd,2,getdate()),101) as datetime)
		)	 
if @debug > 5
begin
	SELECT 'before receipt_date null deletion' as [before receipt_date null deletion], * FROM #container_rows
end		
DELETE FROM #container_rows WHERE receipt_date IS NULL


if @debug > 0
begin
	print cast(datediff(MILLISECOND, @start_time, getdate()) as varchar(20)) + 'ms -- after #container_rows records added'
	
	if @debug > 5
		SELECT 'after #container_rows records added', * FROM #container_rows
end

-- update haz/ non-haz flag
UPDATE #container_rows
SET    is_hazardous = 'T'
FROM   containerdestination
WHERE  #container_rows.receipt_id = ContainerDestination.receipt_id
		AND #container_rows.line_id = ContainerDestination.line_id
		AND #container_rows.company_id = ContainerDestination.company_id
		AND #container_rows.profit_ctr_id = ContainerDestination.profit_ctr_id
		AND #container_rows.sequence_id = ContainerDestination.sequence_id
		AND #container_rows.container_id = ContainerDestination.container_id
		AND ContainerDestination.container_type = 'R'
AND
( EXISTS (SELECT 'haz'--cw.*
                 FROM   containerwastecode cw WITH(NOLOCK) 
                        JOIN wastecode WITH(NOLOCK) 
                          ON cw.waste_code = wastecode.waste_code
                 WHERE  containerdestination.company_id = cw.company_id
                        AND containerdestination.profit_ctr_id = cw.profit_ctr_id
                        AND containerdestination.receipt_id = cw.receipt_id
                        AND containerdestination.line_id = cw.line_id
                        AND containerdestination.container_id = cw.container_id
                        AND containerdestination.sequence_id = cw.sequence_id
                        AND wastecode.waste_code_origin = 'F'
                        AND Isnull(wastecode.haz_flag, 'F') = 'T')
          OR ( EXISTS (SELECT 'haz' --rwc.*
                       FROM   receiptwastecode rwc WITH(NOLOCK) 
                              JOIN wastecode WITH(NOLOCK) 
                                ON rwc.waste_code = wastecode.waste_code
                       WHERE  containerdestination.company_id = rwc.company_id
                              AND containerdestination.profit_ctr_id = rwc.profit_ctr_id
                              AND containerdestination.receipt_id = rwc.receipt_id
                              AND containerdestination.line_id = rwc.line_id
                              AND wastecode.waste_code_origin = 'F'
                              AND Isnull(wastecode.haz_flag, 'F') = 'T'
                              AND NOT EXISTS (SELECT 'haz' --cw.*
                                              FROM   containerwastecode cw WITH(NOLOCK) 
                                                     JOIN wastecode WITH(NOLOCK) 
                                                       ON cw.waste_code = wastecode.waste_code
                                              WHERE  containerdestination.company_id = cw.company_id
                                                     AND containerdestination.profit_ctr_id = cw.profit_ctr_id
                                                     AND containerdestination.receipt_id = cw.receipt_id
                                                     AND containerdestination.line_id = cw.line_id
                                                     AND containerdestination.container_id = cw.container_id
                                                     AND containerdestination.sequence_id = cw.sequence_id)) ) ) 


--SELECT 'before - container rows update', * FROM #container_rows

UPDATE #container_rows SET is_hazardous = dbo.fn_container_hazardous(
	c.company_id,
	c.profit_ctr_id,
	c.receipt_id,
	c.line_id,
	c.container_id,
	c.sequence_id)
FROM #container_rows c
WHERE c.container_type = 'S'
if @debug_haz_status IS NOT NULL
begin
	DELETE FROM #container_rows WHERE is_hazardous <> @debug_haz_status
end

--SELECT 'after - container rows update', * FROM #container_rows


UPDATE #container_rows set is_hazardous = 'F' where is_hazardous IS NULL


/*
	Now that the container data we want is there, we need to calculate
	one row for every day that the container "lived" on the site.
	Example:
		Container 1A: Rec'd 12/10/2009, Disposed 12/15/2009
	
	Returns:
		Container	Rec'd			Disposed		Report Date
		1A			12/10/2009		12/10/2009		12/10/2009
		1A			12/10/2009		12/10/2009		12/11/2009
		1A			12/10/2009		12/10/2009		12/12/2009
		1A			12/10/2009		12/10/2009		12/13/2009
		1A			12/10/2009		12/10/2009		12/14/2009
		--			--				--				--			
		Note: We are NOT including the Disposal Date because we include the Receipt Date
*/


INSERT INTO #reporting_rows (
	company_id,
	profit_ctr_id,
	receipt_id,
	container_id,
	line_id,
	sequence_id,
	receipt_date,
	disposal_date,
	reporting_date,
	container_percent,
	container_type,
	is_hazardous,
	transfer_type
	)
SELECT 
		containers.company_id,
		containers.profit_ctr_id,
		containers.receipt_id,
		containers.container_id,
		containers.line_id,
		containers.sequence_id,
		containers.receipt_date,
		containers.disposal_date,
		Dateadd(DAY, tally.number - 1, containers.receipt_date) as reporting_date,
		container_percent,
		container_type,
		is_hazardous,
		transfer_type
FROM   #container_rows containers
       CROSS JOIN #tally tally
WHERE  Dateadd(DAY, tally.number - 1, containers.receipt_date) < @end_date
AND Dateadd(DAY, tally.number - 1, containers.receipt_date) >= @start_date
AND Dateadd(DAY, tally.number - 1, containers.receipt_date) >= containers.receipt_date AND Dateadd(DAY, tally.number - 1, containers.receipt_date) < containers.disposal_date


UNION 

SELECT 
		containers.company_id,
		containers.profit_ctr_id,
		containers.receipt_id,
		containers.container_id,
		containers.line_id,
		containers.sequence_id,
		containers.receipt_date,
		containers.disposal_date,
		Dateadd(DAY, tally.number - 1, containers.disposal_date) as reporting_date,
		container_percent,
		container_type,
		is_hazardous,
		transfer_type
FROM   #container_rows containers
       CROSS JOIN #tally tally
WHERE  
	Dateadd(DAY, tally.number - 1, containers.disposal_date) < containers.disposal_date
	AND (Dateadd(DAY, tally.number - 1, containers.disposal_date) > @start_date AND Dateadd(DAY, tally.number - 1, containers.receipt_date) <= @end_date)


if @debug > 0
begin
	print cast(datediff(MILLISECOND, @start_time, getdate()) as varchar(20)) + 'ms -- after #reporting_rows records added (2)'
	
	if @debug > 5
	SELECT 'after #reporting_rows records added (2)', * FROM #reporting_rows
end

IF object_id ('tempdb..PK_Reporting_Rows_Summary_cui') IS NULL
BEGIN
ALTER TABLE #reporting_rows
	ADD CONSTRAINT PK_Reporting_Rows_Summary_cui
		PRIMARY KEY CLUSTERED (company_id, profit_ctr_id, receipt_id, container_id, line_id, sequence_id, reporting_date) WITH FILLFACTOR = 100
END
-- DEBUGGING
if @debug_only_container_type IS NOT NULL
BEGIN
	DELETE FROM #reporting_rows WHERE container_type <> @debug_only_container_type
	DELETE FROM #container_rows WHERE container_type <> @debug_only_container_type
END




SELECT DISTINCT
		reporting_rows.company_id, 
		reporting_rows.profit_ctr_id, 
		reporting_rows.receipt_id, 
		reporting_rows.container_id, 
		reporting_rows.line_id, 
		reporting_rows.sequence_id,
		reporting_rows.receipt_date,
		reporting_rows.disposal_date,
		reporting_rows.reporting_date,
		total_item_count, 
		containers_on_site,
		gallon_converted,
		fifty_five_gallon_converted,
		gallon_conversion_factor,
		gallon_conversion_unit,
		Container.container_size,
		Container.container_type,
		Container.container_weight,
		--ReceiptPrice.price_id,
		converted_container_weight,
		reporting_rows.container_percent,
		container_count,
		is_hazardous,
	cast(NULL as varchar(50)) as conversion_unit_source,
	cast(NULL as varchar(50)) as conversion_factor_source,
	cast(NULL as varchar(50)) as conversion_weight_source,
	transfer_type
	INTO #converted_rows
	FROM #reporting_rows reporting_rows WITH(NOLOCK) 
	LEFT OUTER JOIN Container WITH(NOLOCK) ON
		container.receipt_id = reporting_rows.receipt_id
		AND container.line_id = reporting_rows.line_id
		AND container.container_id = reporting_rows.container_id            	
		AND container.container_type = 'R'
		AND container.company_id = reporting_rows.company_id            
		AND container.profit_ctr_id = reporting_rows.profit_ctr_id
	LEFT OUTER JOIN ContainerDestination WITH(NOLOCK) ON 
		container.receipt_id = ContainerDestination.receipt_id
		AND container.line_id = ContainerDestination.line_id
		AND container.container_id = ContainerDestination.container_id            	
		AND container.container_type = 'R'
		AND container.company_id = ContainerDestination.company_id            
		AND container.profit_ctr_id = ContainerDestination.profit_ctr_id
	LEFT OUTER JOIN ReceiptPrice WITH(NOLOCK) ON 
		container.receipt_id = ReceiptPrice.receipt_id
		AND container.line_id = ReceiptPrice.line_id
		AND container.company_id = ReceiptPrice.company_id
		AND container.profit_ctr_id = ReceiptPrice.profit_ctr_id
	LEFT OUTER JOIN Receipt WITH(NOLOCK) ON
		Receipt.receipt_id = ReceiptPrice.receipt_id
		AND Receipt.line_id = ReceiptPrice.line_id
		AND Receipt.company_id = ReceiptPrice.company_id
		AND Receipt.profit_ctr_id = ReceiptPrice.profit_ctr_id
	LEFT OUTER JOIN BillUnit AS bu WITH(NOLOCK) 
		ON bu.bill_unit_code = ReceiptPrice.bill_unit_code
	WHERE ContainerDestination.status NOT IN ('V', 'R')
		AND Receipt.company_id = @company_id AND Receipt.profit_ctr_id = @profit_ctr_id
		
	UNION
	
	/* 
		Stock Containers
	*/
	
SELECT DISTINCT
		reporting_rows.company_id, 
		reporting_rows.profit_ctr_id, 
		reporting_rows.receipt_id, 
		reporting_rows.container_id, 
		reporting_rows.line_id, 
		reporting_rows.sequence_id,
		reporting_rows.receipt_date,
		reporting_rows.disposal_date,
		reporting_rows.reporting_date,
		total_item_count, 
		containers_on_site,
		gallon_converted,
		fifty_five_gallon_converted,
		gallon_conversion_factor,
		gallon_conversion_unit,
		Container.container_size,
		Container.container_type,
		Container.container_weight,
		--ReceiptPrice.price_id,
		converted_container_weight,
		ContainerDestination.container_percent,
		1 as container_count,
		is_hazardous,
	cast(NULL as varchar(50)) as conversion_unit_source,
	cast(NULL as varchar(50)) as conversion_factor_source,
	cast(NULL as varchar(50)) as conversion_weight_source,
	reporting_rows.transfer_type	
	FROM #reporting_rows reporting_rows WITH(NOLOCK) 
	LEFT OUTER JOIN Container WITH(NOLOCK) ON
		container.receipt_id = reporting_rows.receipt_id
		AND container.line_id = reporting_rows.line_id
		AND container.container_id = reporting_rows.container_id            	
		AND container.container_type = 'S'
		AND container.company_id = reporting_rows.company_id            
		AND container.profit_ctr_id = reporting_rows.profit_ctr_id
	LEFT OUTER JOIN ContainerDestination WITH(NOLOCK)  ON 
		container.receipt_id = ContainerDestination.receipt_id
		AND container.line_id = ContainerDestination.line_id
		AND container.container_id = ContainerDestination.container_id            	
		AND container.container_type = 'S'
		AND container.company_id = ContainerDestination.company_id            
		AND container.profit_ctr_id = ContainerDestination.profit_ctr_id
	LEFT OUTER JOIN BillUnit AS bu WITH(NOLOCK) 
		ON bu.bill_unit_code = Container.container_size
	WHERE ContainerDestination.status NOT IN ('V', 'R')
		AND ContainerDestination.company_id = @company_id AND ContainerDestination.profit_ctr_id = @profit_ctr_id	
		

--DELETE FROM #converted_rows WHERE container_percent = 0
	
if @debug > 0
begin
	print cast(datediff(MILLISECOND, @start_time, getdate()) as varchar(20)) + 'ms -- after #converted_rows records added'
	
	if @debug > 5
	SELECT 'after #converted_rows records added', * FROM #converted_rows
end	


/* 
	This contains ALL of the receipt lines if a single-receipt was pulled back from converted_rows
	we need this to know what the overall weights / container counts were to calculate the real average weight 
*/

/* get a full list of keys for all lines in this receipt */
SELECT DISTINCT
	r.receipt_id, 
	r.company_id,
	r.profit_ctr_id, 
	r.line_id, 
	r.container_count,
	cast(0 as decimal(12,4)) as average_weight, -- populated later
	cast(NULL as varchar(50)) as conversion_unit_source,
	cast(NULL as varchar(50)) as conversion_factor_source,
	cast(NULL as varchar(50)) as conversion_weight_source	
INTO #receipt_keys
	FROM Receipt r WITH(NOLOCK) 
	WHERE EXISTS(
		SELECT ''
		FROM #converted_rows cr 
		WHERE r.receipt_id = cr.receipt_id
		AND r.company_id = cr.company_id
		AND r.profit_ctr_id = cr.profit_ctr_id
		AND cr.container_type = 'R'
		)
	AND r.company_id = @company_id AND r.profit_ctr_id = @profit_ctr_id
	
	
	
/* get related information for all lines in this receipt */
SELECT  
	DISTINCT
	tmp.receipt_id, 
	tmp.company_id,
	tmp.profit_ctr_id, 
	tmp.line_id,
	Container.container_id,
	Container.container_type,
	Container.container_size,
	Container.container_weight,
	cast(0.0 as decimal(12,4)) as gallon_conversion_factor,
	cast('' as varchar(20)) as gallon_conversion_unit,
	ContainerDestination.container_percent, -- populated later
	cast(NULL as varchar(50)) as conversion_unit_source,
	cast(NULL as varchar(50)) as conversion_factor_source,
	cast(NULL as varchar(50)) as conversion_weight_source	
INTO #container_keys
FROM #receipt_keys tmp WITH(NOLOCK) 
INNER JOIN Container WITH(NOLOCK) ON tmp.receipt_id = Container.receipt_id
	AND tmp.line_id = Container.line_id
	AND tmp.company_id = Container.company_id
	AND tmp.profit_ctr_id = Container.profit_ctr_id
INNER JOIN ContainerDestination WITH(NOLOCK) ON Container.receipt_id = ContainerDestination.receipt_id
	AND Container.line_id = ContainerDestination.line_id
	AND Container.container_id = ContainerDestination.container_id
	AND Container.company_id = ContainerDestination.company_id
	AND Container.profit_ctr_id = ContainerDestination.profit_ctr_id
	AND Container.container_type = ContainerDestination.container_type	
WHERE tmp.company_id = @company_id AND tmp.profit_ctr_id = @profit_ctr_id
AND Container.container_type = 'R'


INSERT INTO #container_keys
	SELECT DISTINCT 
	tmp.receipt_id, 
	tmp.company_id,
	tmp.profit_ctr_id, 
	tmp.line_id,
	Container.container_id,
	Container.container_type,
	Container.container_size,
	Container.container_weight,
	cast(0.0 as decimal(12,4)) as gallon_conversion_factor,
	cast('' as varchar(20)) as gallon_conversion_unit,
	ContainerDestination.container_percent, -- populated later
	cast(NULL as varchar(50)) as conversion_unit_source,
	cast(NULL as varchar(50)) as conversion_factor_source,
	cast(NULL as varchar(50)) as conversion_weight_source	
FROM #converted_rows tmp WITH(NOLOCK) 
INNER JOIN Container WITH(NOLOCK) ON tmp.receipt_id = Container.receipt_id
	AND tmp.line_id = Container.line_id
	AND tmp.company_id = Container.company_id
	AND tmp.profit_ctr_id = Container.profit_ctr_id
	AND tmp.container_id = Container.container_id
INNER JOIN ContainerDestination WITH(NOLOCK)  ON Container.receipt_id = ContainerDestination.receipt_id
	AND Container.line_id = ContainerDestination.line_id
	AND Container.container_id = ContainerDestination.container_id
	AND Container.company_id = ContainerDestination.company_id
	AND Container.profit_ctr_id = ContainerDestination.profit_ctr_id
	AND Container.container_type = ContainerDestination.container_type	
WHERE tmp.company_id = @company_id AND tmp.profit_ctr_id = @profit_ctr_id
AND Container.container_type = 'S'
	


if @debug > 5
begin
	SELECT '#receipt_keys' as [#receipt_keys], * FROM #receipt_keys
	SELECT '#container_keys' as [#container_keys], * FROM #container_keys
end








/** Now that the major records we are going to use have been added - do the calculations **/
/** Now that the major records we are going to use have been added - do the calculations **/
/** Now that the major records we are going to use have been added - do the calculations **/

-- use the container_weight is specified
UPDATE #container_keys 	
	SET gallon_conversion_factor = (SELECT gal_conv FROM BillUnit where bill_unit_code = 'LBS'),
	gallon_conversion_unit = 'LBS',
	conversion_unit_source = 'Container.container_size',
	conversion_factor_source = 'BillUnit',
	conversion_weight_source = 'has weight in container'
	FROM Container
	WHERE #container_keys.receipt_id = Container.receipt_id
	AND #container_keys.container_id = Container.container_id
	AND #container_keys.line_id = Container.line_id
	AND #container_keys.company_id = Container.company_id
	AND #container_keys.profit_ctr_id = Container.profit_ctr_id
	AND ISNULL(Container.container_weight, 0) <> 0

--SELECT '#container_keys - 1', * FROM #container_keys
	
	
-- use the container_size if specified and there is no weight
UPDATE #container_keys 	
	SET gallon_conversion_unit = Container.container_size,
	conversion_unit_source = 'Container.container_size',
	conversion_factor_source = 'BillUnit',
	conversion_weight_source = 'no weight'	
	FROM Container
	WHERE #container_keys.receipt_id = Container.receipt_id
	AND #container_keys.container_id = Container.container_id
	AND #container_keys.line_id = Container.line_id
	AND #container_keys.company_id = Container.company_id
	AND #container_keys.profit_ctr_id = Container.profit_ctr_id
	AND ISNULL(Container.container_size, '') <> ''
	AND ISNULL(Container.container_weight, 0) = 0
if @debug > 5
begin
	SELECT '#container_keys	 - before ReceiptPrice lookup' as [#container_keys	 - before ReceiptPrice lookup], * FROM #container_keys
end
	
--SELECT '#container_keys - 2', * FROM #container_keys	
	
-- (Receipt Containers only)use the ReceiptPrice bill_unit and gallon_conversion if there is no container_size
UPDATE #container_keys SET gallon_conversion_factor = bu.gal_conv,
	gallon_conversion_unit = bu.bill_unit_code,
	conversion_unit_source = 'ReceiptPrice empty size/weight',
	conversion_factor_source = 'ReceiptPrice empty size/weight',
	conversion_weight_source = ''		
	FROM #converted_rows r
	INNER JOIN receiptprice rp
         ON 
			r.receipt_id = rp.receipt_id
			AND r.line_id = rp.line_id
			AND r.company_id = rp.company_id
            AND r.profit_ctr_id = rp.profit_ctr_id
            --AND r.price_id = rp.price_id	
    INNER JOIN BillUnit bu ON rp.bill_unit_code = bu.bill_unit_code
	WHERE 
	#container_keys.receipt_id = r.receipt_id
	AND #container_keys.company_id = r.company_id
	AND #container_keys.profit_ctr_id = r.profit_ctr_id
	AND #container_keys.line_id = r.line_id
	AND bu.bill_unit_code = rp.bill_unit_code
	AND ISNULL(#container_keys.container_size, '') = ''
	AND ISNULL(#container_keys.container_weight,0) = 0
	AND #container_keys.container_type = 'R'		
	
--SELECT '#container_keys - 3', * FROM #container_keys	

-- (Stock Containers Only) - If they have a container_size but NO weight, look up the container_weight in BillUnit
if @debug > 5
begin
	SELECT '#container_keys - after ReceiptPrice lookup' as [#container_keys - after ReceiptPrice lookup], * FROM #container_keys
end
	
--SELECT '#container_keys - 3', * FROM #container_keys	

-- (Stock Containers Only) - If they have a container_size but NO weight, look up the container_weight in BillUnit
UPDATE #container_keys set gallon_conversion_factor = bu.gal_conv,
	conversion_unit_source = 'stock - Container.container_size',
	conversion_factor_source = 'container_size',
	conversion_weight_source = 'no weight'
	FROM BillUnit bu WHERE 
	#container_keys.container_size = bu.bill_unit_code
	AND #container_keys.container_type = 'S'
	AND IsNull(#container_keys.container_weight,0) = 0
	AND IsNull(#container_keys.container_size,'') <> ''



-- calculate the 'average weight' for each container in the ENTIRE receipt
-- this only applies to Receipt Containers that do NOT have a weight specified
UPDATE #receipt_keys SET average_weight = avg_weight
		FROM ( 
			SELECT SUM(#container_keys.gallon_conversion_factor) / COUNT(#container_keys.receipt_id) as avg_weight,
				#container_keys.receipt_id
				from #container_keys
				WHERE #container_keys.container_type = 'R'
				GROUP BY #container_keys.receipt_id
		) tbl
		WHERE #receipt_keys.receipt_id = tbl.receipt_id
		--AND #container_keys.container_type = 'R'
		
		
-- update the total_item count
UPDATE #converted_rows SET total_item_count = item_count FROM
			(
				SELECT COUNT(#container_keys.receipt_id) as item_count,
				#container_keys.receipt_id
				from #container_keys
				--WHERE #container_keys.container_type = 'R'
				GROUP BY #container_keys.receipt_id
			) tbl
		WHERE #converted_rows.receipt_id = tbl.receipt_id
		
UPDATE #converted_rows SET total_item_count = 1 
	WHERE #converted_rows.container_type = 'S'
if @debug > 5
begin
	SELECT '#converted_rows - before avg' as [#converted_rows - before avg], * FROM [#converted_rows]
end

		
UPDATE #converted_rows set gallon_conversion_factor = #receipt_keys.average_weight
	, conversion_weight_source = 'average'	
	FROM #receipt_keys WHERE #converted_rows.receipt_id = #receipt_keys.receipt_id
	AND ISNULL(#converted_rows.container_weight,0) = 0
	AND #converted_rows.container_type = 'R'


if @debug > 5
begin
	SELECT '#converted_rows - after avg' as [#converted_rows - after avg], * FROM [#converted_rows]
	SELECT '#receipt_keys - after avg' as [#receipt_keys], * FROM #receipt_keys
end



if @debug > 0
begin
	print cast(datediff(MILLISECOND, @start_time, getdate()) as varchar(20)) + 'ms  -- after container_size check/update'
end



/* 
	If there is no container size AND it is a STOCK Container
	Assume it is a single 55 Gallon Drum
*/

UPDATE #container_keys set gallon_conversion_factor = bu.gal_conv,
	gallon_conversion_unit = bu.bill_unit_code,
	conversion_unit_source = 'container size field',
	conversion_factor_source = 'BillUnit',
	conversion_weight_source = 'calculated weight'
	FROM #container_keys r
    INNER JOIN BillUnit bu ON r.container_size = bu.bill_unit_code
	WHERE 
	LEN(ISNULL(r.container_size, '')) = 0
	AND r.container_type = 'S'	
if @debug > 5
begin
	SELECT '#container_keys - before 55 gallon assumption ' as [#container_keys - before 55 gallon assumption], * FROM #container_keys
end

	
UPDATE #container_keys set gallon_conversion_factor = (SELECT gal_conv FROM BillUnit bu WHERE bu.bill_unit_code = 'DM55')
	, gallon_conversion_unit = 'DM55'
	,	conversion_unit_source = 'empty size/weight/conversion assume 55gallon'
	,	conversion_factor_source = 'BillUnit - assume 55gallon'
	,	conversion_weight_source = 'calculated'	
	FROM #container_keys r
	WHERE ISNULL(r.container_size,'') = ''
	AND ISNULL(r.container_weight, 0) = 0
	AND ISNULL(r.gallon_conversion_factor,0) = 0
	AND ISNULL(gallon_conversion_unit,'') = ''
	
-- if there is no conversion anywhere, assume 55 Gallon Drum	
UPDATE #container_keys set gallon_conversion_factor = (SELECT gal_conv FROM BillUnit bu WHERE bu.bill_unit_code = 'DM55'),
	gallon_conversion_unit = 'UNKNOWN' 
	FROM #container_keys r
	WHERE ISNULL(r.gallon_conversion_factor,0) = 0
UPDATE #container_keys SET conversion_weight_source = r.conversion_weight_source
	FROM #receipt_keys r
	WHERE r.receipt_id = #container_keys.receipt_id
	AND r.line_id = #container_keys.line_id
	AND r.company_id = #container_keys.company_id
	AND r.profit_ctr_id = #container_keys.profit_ctr_id
		
/*
-- if there is no conversion anywhere, assume 55 Gallon Drum	
UPDATE #container_keys set gallon_conversion_factor = (SELECT gal_conv FROM BillUnit bu WHERE bu.bill_unit_code = 'DM55'),
	gallon_conversion_unit = 'DM55'
	FROM #container_keys r
	WHERE ISNULL(r.gallon_conversion_factor,0) = 0
*/

UPDATE #converted_rows set 
	gallon_conversion_factor = c.gallon_conversion_factor,
	gallon_conversion_unit = c.gallon_conversion_unit,
	conversion_unit_source = c.conversion_unit_source,
	conversion_factor_source = c.conversion_factor_source,
	conversion_weight_source = c.conversion_weight_source
	FROM #container_keys c
	WHERE c.receipt_id = #converted_rows.receipt_id
	AND c.line_id = #converted_rows.line_id
	AND c.company_id = #converted_rows.company_id
	AND c.profit_ctr_id = #converted_rows.profit_ctr_id
	AND c.container_id = #converted_rows.container_id	


	
if @debug > 0
begin
	print cast(datediff(MILLISECOND, @start_time, getdate()) as varchar(20)) + 'ms -- after receipt_price check/update'
end	
	



-- update the containers on site (as of reporting date)
UPDATE #converted_rows set containers_on_site = 
	(
		SELECT COUNT(container_id) FROM ContainerDestination cd WHERE 
		(
			cd.receipt_id = #converted_rows.receipt_id
			AND cd.line_id = #converted_rows.line_id
			AND cd.container_id = #converted_rows.container_id
			AND cd.company_id = #converted_rows.company_id
			AND cd.profit_ctr_id = #converted_rows.profit_ctr_id
			AND cd.container_type = #converted_rows.container_type
			AND (#converted_rows.reporting_date < cd.disposal_date OR #converted_rows.disposal_date = @tomorrow)
		)
	)
		
	FROM ContainerDestination cd 		
	WHERE 
		cd.receipt_id = #converted_rows.receipt_id
		AND cd.line_id = #converted_rows.line_id
		AND cd.container_id = #converted_rows.container_id
		AND cd.company_id = #converted_rows.company_id
		AND cd.profit_ctr_id = #converted_rows.profit_ctr_id		
		AND cd.container_type = #converted_rows.container_type


-- calculate the weights (either from actual or 'calculated')
UPDATE #converted_rows SET converted_container_weight = (gallon_conversion_factor * containers_on_site) * (cast(container_percent as decimal(12,4)) / cast(100 as decimal(12,4)))
	WHERE isnull(container_weight,0) = 0
	
UPDATE #converted_rows SET converted_container_weight = (container_weight * @pound_to_gallon * containers_on_site) * (cast(container_percent as decimal(12,4)) / cast(100 as decimal(12,4)))
	WHERE isnull(container_weight,0) <> 0


if @debug > 5
BEGIN
		SELECT '[cvt rows]' as [cvt rows], *
		FROM #converted_rows
		order by receipt_id
		
		SELECT '[cvt rows] - receipts' as [cvt rows - receipts], Receipt.*
		FROM #converted_rows		
		INNER JOIN Receipt ON #converted_rows.receipt_id = Receipt.receipt_id
		AND #converted_rows.company_id = Receipt.company_id
		AND #converted_rows.profit_ctr_id = Receipt.profit_ctr_id
		AND #converted_rows.line_id = Receipt.line_id
		
		SELECT '[cvt rows] - container' as [cvt rows - Container], Container.*
		FROM #converted_rows		
		INNER JOIN Container ON #converted_rows.receipt_id = Container.receipt_id
		AND #converted_rows.company_id = Container.company_id
		AND #converted_rows.profit_ctr_id = Container.profit_ctr_id
		AND #converted_rows.container_id = Container.container_id
		AND #converted_rows.line_id = Container.line_id		

		SELECT '[cvt rows] - container dest' as [cvt rows - container dest], ContainerDestination.*
		FROM #converted_rows		
		INNER JOIN ContainerDestination ON #converted_rows.receipt_id = ContainerDestination.receipt_id
		AND #converted_rows.company_id = ContainerDestination.company_id
		AND #converted_rows.profit_ctr_id = ContainerDestination.profit_ctr_id
		AND #converted_rows.container_id = ContainerDestination.container_id
		AND #converted_rows.line_id = ContainerDestination.line_id	
		AND #converted_rows.sequence_id = ContainerDestination.line_id	
end

if @debug > 0
begin
	print cast(datediff(MILLISECOND, @start_time, getdate()) as varchar(20)) + 'ms  -- after containers_on_site update'
end	



		-- need the "total_item_count" for each reporting date / haz status
		SELECT Sum(	cr.total_item_count ) as total_count, cr.reporting_date, cr.is_hazardous
			into #totals_per_day
             FROM   
				(SELECT DISTINCT reporting_date, total_item_count, receipt_id, is_hazardous FROM #converted_rows) cr 
            GROUP  BY cr.reporting_date, cr.is_hazardous

		SELECT #converted_rows.company_id,
               #converted_rows.profit_ctr_id,
               #converted_rows.reporting_date,
			   #totals_per_day.total_count,
               Sum(containers_on_site)         AS containers_on_site,
               Sum(converted_container_weight) AS converted_container_weight,
               Sum(converted_container_weight) / 55.0000 AS fifty_five_gallon_converted_container_weight,
               #converted_rows.is_hazardous
        FROM   #converted_rows
				INNER JOIN #totals_per_day ON #converted_rows.reporting_date = #totals_per_day.reporting_date
					AND #converted_rows.is_hazardous = #totals_per_day.is_hazardous
        GROUP  BY 
				  #converted_rows.company_id,
                  #converted_rows.profit_ctr_id,
                  #converted_rows.reporting_date,
                  #converted_rows.is_hazardous,
                  #totals_per_day.total_count
        ORDER  BY #converted_rows.reporting_date 
        
		
if @debug > 0
begin
	print cast(datediff(MILLISECOND, @start_time, getdate()) as varchar(20)) + 'ms -- complete'
end

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_container_inventory_for_date_range] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_container_inventory_for_date_range] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_container_inventory_for_date_range] TO [EQAI]
    AS [dbo];

