
CREATE PROCEDURE sp_calculate_container_weight
(
	@container_key_table ContainerWeightCalculationTable READONLY,
	@calculation_mode varchar(20),  -- inventory or invoice
	@minimum_date datetime
)
AS
BEGIN
	
	
	declare @gallon_conversion_factor decimal(12,4)
	declare @gallon_conversion_unit varchar(20)
	
	declare @container_weight decimal(12,4)
	declare @containers_on_site int
	declare @container_percent decimal(12,4)

	declare @tomorrow datetime = CAST(CONVERT(varchar(20), dateadd(dd,1,getdate()),101) as datetime)	
	
	DECLARE @pound_to_gallon decimal(12,4)
	SELECT @pound_to_gallon = gal_conv FROM BillUnit WHERE bill_unit_code = 'LBS'		
	
declare @debug int = 0
declare @TimeStart datetime = getdate()

IF @debug > 0
	SELECT 'begin calc proc', DATEDIFF(millisecond, @TimeStart, getdate())       


	create table #container_details
	(
		receipt_id int,
		company_id int,
		profit_ctr_id int,
		line_id int,
		container_id int,
		sequence_id int,
		reporting_date datetime NULL,
		disposal_date datetime NULL,
		container_type char(1),
		container_size varchar(20),
		container_weight decimal(12,4),
		container_percent decimal(12,4),
		receipt_line_weight decimal(12,4),
		receipt_quantity int,
		receipt_bulk_flag char(1),				
		/* below are fields that will be populated later */
		container_weight_pounds decimal(12,4),
		gallon_conversion_factor decimal(12,4),
		gallon_conversion_unit varchar(20),
		containers_on_site int,
		containers_for_line int,
		average_container_weight decimal(12,4),
		total_item_count int,
		container_weight_gallons decimal(12,4),
		conversion_unit_source varchar(50),
		conversion_factor_source varchar(50),
		conversion_weight_source varchar(50),
		pound_conversion_factor decimal(12,4),
		fifty_five_gallon_container_weight_gallons decimal(12,4),
		actual_reported_gallons decimal(12,4),
		actual_reported_pounds decimal(12,4),
		estimated_gallons decimal(12,4),
		estimated_pounds decimal(12,4),
		avg_receipt_line_weight  decimal(12,4)
	)

INSERT INTO #container_details
	SELECT *,
		/* fill in defaults, data we will populate */
		NULL as container_weight_pounds,
		cast(0.0 as decimal(12,4)) as gallon_conversion_factor,
		cast('' as varchar(20)) as gallon_conversion_unit,	
		0 as containers_on_site,
		null as containers_for_line,	
		0 as average_container_weight,
		0 as total_item_count,
		0.00 as container_weight_gallons,
		cast(NULL as varchar(50)) as conversion_unit_source,
		cast(NULL as varchar(50)) as conversion_factor_source,
		cast(NULL as varchar(50)) as conversion_weight_source,	
		NULL as pound_conversion_factor,
		NULL as fifty_five_gallon_container_weight_gallons,
		NULL as actual_reported_gallons,
		NULL as actual_reported_pounds,
		NULL as estimated_gallons,
		NULL as estimated_pounds,
		NULL as avg_receipt_line_weight
	 FROM @container_key_table
	
	
IF @debug > 0
	SELECT 'after initial insert ', DATEDIFF(millisecond, @TimeStart, getdate())       	
	
/*
SELECT  
	DISTINCT
	Receipt.receipt_id,
	Receipt.company_id,
	Receipt.profit_ctr_id,
	Receipt.line_id,
	Container.container_id,
	ContainerDestination.sequence_id,
	reporting_keys.reporting_date,
	ContainerDestination.disposal_date,
	Container.container_type,
	Container.container_size,
	--CASE WHEN ISNULL(Container.container_weight,0) = 0 THEN ISNULL(Receipt.line_weight, 0) END,
	ISNULL(Container.container_weight, 0),
	NULL as container_weight_pounds,
	cast(0.0 as decimal(12,4)) as gallon_conversion_factor,
	cast('' as varchar(20)) as gallon_conversion_unit,
	ContainerDestination.container_percent,
	0 as containers_on_site,
	null as containers_for_line,	
	0 as average_container_weight,
	0 as total_item_count,
	0.00 as container_weight_gallons,
	cast(NULL as varchar(50)) as conversion_unit_source,
	cast(NULL as varchar(50)) as conversion_factor_source,
	cast(NULL as varchar(50)) as conversion_weight_source,
	Receipt.line_weight,
	NULL as pound_conversion_factor,
	NULL as fifty_five_gallon_container_weight_gallons,
	Receipt.quantity,
	Receipt.bulk_flag,
	NULL as actual_reported_gallons,
	NULL as actual_reported_pounds,
	NULL as estimated_gallons,
	NULL as estimated_pounds,
	NULL as avg_receipt_line_weight
	
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
INNER JOIN @container_key_table reporting_keys  ON 1=1
	AND ContainerDestination.receipt_id = reporting_keys.receipt_id
	AND ContainerDestination.company_id = reporting_keys.company_id
	AND ContainerDestination.profit_ctr_id = reporting_keys.profit_ctr_id
	AND ContainerDestination.line_id = reporting_keys.line_id	
	AND ContainerDestination.sequence_id = reporting_keys.sequence_id

--where Receipt.receipt_id = @receipt_id and Receipt.company_id = @company_id and Receipt.profit_ctr_id = @profit_ctr_id	

INSERT INTO #container_details
	SELECT DISTINCT 
	Container.receipt_id, 
	Container.company_id,
	Container.profit_ctr_id, 
	Container.line_id,
	Container.container_id,
	ContainerDestination.sequence_id,	
	reporting_keys.reporting_date,	
	ContainerDestination.disposal_date,
	Container.container_type,
	Container.container_size,
	Container.container_weight,
	NULL as container_weight_pounds,
	cast(0.0 as decimal(12,4)) as gallon_conversion_factor,
	cast('' as varchar(20)) as gallon_conversion_unit,
	ContainerDestination.container_percent,
	0 as containers_on_site,
	null as containers_for_line,
	0 as average_container_weight,
	0 as total_item_count,
	0.00 as container_weight_gallons,
	cast(NULL as varchar(50)) as conversion_unit_source,
	cast(NULL as varchar(50)) as conversion_factor_source,
	cast(NULL as varchar(50)) as conversion_weight_source,
	NULL as line_weight,
	NULL as pound_conversion_factor,
	NULL as fifty_five_gallon_container_weight_gallons,
	NULL as quantity,
	'F' as bulk_flag,
	NULL as actual_reported_gallons,
	NULL as actual_reported_pounds,
	NULL as estimated_gallons,
	NULL as estimated_pounds,
	NULL as avg_receipt_line_weight
FROM Container
INNER JOIN ContainerDestination WITH(NOLOCK)  ON Container.receipt_id = ContainerDestination.receipt_id
	AND Container.line_id = ContainerDestination.line_id
	AND Container.container_id = ContainerDestination.container_id
	AND Container.company_id = ContainerDestination.company_id
	AND Container.profit_ctr_id = ContainerDestination.profit_ctr_id
	AND Container.container_type = ContainerDestination.container_type	
INNER JOIN @container_key_table reporting_keys ON 1=1
AND ContainerDestination.receipt_id = reporting_keys.receipt_id
AND ContainerDestination.company_id = reporting_keys.company_id
AND ContainerDestination.profit_ctr_id = reporting_keys.profit_ctr_id
AND ContainerDestination.line_id = reporting_keys.line_id	
AND ContainerDestination.sequence_id = reporting_keys.sequence_id
WHERE 1=1
AND Container.container_type = 'S'
*/


--SELECT 'details #1', * FROM #container_details

create NONCLUSTERED index idx_details_tmp on #container_details(receipt_id, container_id, line_id, company_id, profit_ctr_id)
create NONCLUSTERED index idx_details_tmp2 on #container_details(receipt_id, company_id, profit_ctr_id)
create NONCLUSTERED index idx_details_tmp3 on #container_details(receipt_id, company_id, profit_ctr_id, line_id)
create index idx_details_tmp4 on #container_details(receipt_id, company_id, profit_ctr_id, line_id, container_id, sequence_id)


--AND #container_details.receipt_id = Container.receipt_id
--	AND #container_details.container_id = Container.container_id
--	AND #container_details.line_id = Container.line_id
--	AND #container_details.company_id = Container.company_id
--	AND #container_details.profit_ctr_id = Container.profit_ctr_id
--	AND ISNULL(Container.container_weight, 0) <> 0


IF @debug > 0
	SELECT 'before updates', DATEDIFF(millisecond, @TimeStart, getdate())       

/** Now that the major records we are going to use have been added - do the calculations **/
/** Now that the major records we are going to use have been added - do the calculations **/
/** Now that the major records we are going to use have been added - do the calculations **/
-- use the container_weight is specified
UPDATE #container_details 	
	SET gallon_conversion_factor = (SELECT gal_conv FROM BillUnit where bill_unit_code = 'LBS'),
	gallon_conversion_unit = 'LBS',
	conversion_unit_source = 'Container.container_size',
	conversion_factor_source = 'BillUnit',
	conversion_weight_source = 'has weight in container'
	FROM Container WITH(NOLOCK) 
	WHERE 1=1
	AND #container_details.receipt_id = Container.receipt_id
	AND #container_details.container_id = Container.container_id
	AND #container_details.line_id = Container.line_id
	AND #container_details.company_id = Container.company_id
	AND #container_details.profit_ctr_id = Container.profit_ctr_id
	AND ISNULL(Container.container_weight, 0) <> 0
	
IF @debug > 0
	SELECT 'UPDATE: after Container.container_size finished', DATEDIFF(millisecond, @TimeStart, getdate())       
	
UPDATE #container_details 	
	SET gallon_conversion_factor = (SELECT gal_conv FROM BillUnit where bill_unit_code = 'LBS'),
	gallon_conversion_unit = 'LBS',
	conversion_unit_source = 'Receipt.line_weight',
	conversion_factor_source = 'BillUnit',
	conversion_weight_source = 'has weight in Receipt.line_weight'
	FROM Container WITH(NOLOCK) 
	WHERE 1=1
	AND #container_details.receipt_id = Container.receipt_id
	AND #container_details.container_id = Container.container_id
	AND #container_details.line_id = Container.line_id
	AND #container_details.company_id = Container.company_id
	AND #container_details.profit_ctr_id = Container.profit_ctr_id
	AND ISNULL(#container_details.receipt_line_weight, 0) <> 0	

IF @debug > 0
	SELECT 'UPDATE: after Receipt.line_weight finished', DATEDIFF(millisecond, @TimeStart, getdate())       

-- SELECT 'details #2', * FROM #container_details

UPDATE #container_details 	
	SET gallon_conversion_unit = Container.container_size,
	conversion_unit_source = 'Container.container_size',
	conversion_factor_source = 'BillUnit',
	conversion_weight_source = 'no weight'	
	FROM Container WITH(NOLOCK) 
	WHERE 1=1
	AND #container_details.receipt_id = Container.receipt_id
	AND #container_details.container_id = Container.container_id
	AND #container_details.line_id = Container.line_id
	AND #container_details.company_id = Container.company_id
	AND #container_details.profit_ctr_id = Container.profit_ctr_id	
	AND ISNULL(Container.container_size, '') <> ''
	AND ISNULL(Container.container_weight, 0) = 0


IF @debug > 0
	SELECT 'UPDATE: after Container.container_size (no weight) finished', DATEDIFF(millisecond, @TimeStart, getdate())       
	
 --SELECT 'details #2.5', * FROM #container_details

UPDATE #container_details SET gallon_conversion_factor = bu.gal_conv,
	gallon_conversion_unit = bu.bill_unit_code,
	conversion_unit_source = 'ReceiptPrice unit (empty size/weight)',
	conversion_factor_source = 'ReceiptPrice unit (empty size/weight)',
	conversion_weight_source = '',
	receipt_quantity = rp.bill_quantity	
	FROM #container_details r WITH(NOLOCK) 
	INNER JOIN receiptprice rp WITH(NOLOCK) 
         ON 
			r.receipt_id = rp.receipt_id
			AND r.line_id = rp.line_id
			AND r.company_id = rp.company_id
            AND r.profit_ctr_id = rp.profit_ctr_id
            --AND r.price_id = rp.price_id	
    INNER JOIN BillUnit bu  WITH(NOLOCK) ON rp.bill_unit_code = bu.bill_unit_code
	WHERE 1=1
	--AND r.receipt_id = rp.receipt_id
	--AND r.company_id = rp.company_id
	--AND r.profit_ctr_id = rp.profit_ctr_id
	--AND r.line_id = rp.line_id
	AND bu.bill_unit_code = rp.bill_unit_code
	AND ISNULL(r.container_size, '') = ''
	AND ISNULL(r.container_weight,0) = 0
	AND ISNULL(r.receipt_line_weight,0) = 0
	AND r.container_type = 'R'	
	
	
IF @debug > 0
	SELECT 'UPDATE: after ReceiptPrice unit (empty size/weight) finished', DATEDIFF(millisecond, @TimeStart, getdate())       
		
	--SELECT * FROM #container_details where ISNULL(receipt_line_weight,0) > 0
	--SELECT 'details #3', * FROM #container_details



-- (Stock Containers Only) - If they have a container_size but NO weight, look up the container_weight in BillUnit
UPDATE #container_details set gallon_conversion_factor = bu.gal_conv,
	conversion_unit_source = 'stock - Container.container_size',
	conversion_factor_source = 'container_size',
	conversion_weight_source = 'no weight'
	FROM BillUnit bu  WITH(NOLOCK) WHERE 
	container_size = bu.bill_unit_code
	AND container_type = 'S'
	AND IsNull(container_weight, 0) = 0
	AND IsNull(container_size,'') <> ''
	
IF @debug > 0
	SELECT 'UPDATE: after stock - Container.container_size finished', DATEDIFF(millisecond, @TimeStart, getdate())       
		
	
-- SELECT 'details #4', * FROM #container_details	



-- calculate the 'average weight' for each container in the ENTIRE receipt
-- this only applies to Receipt Containers that do NOT have a weight specified
-- declare @average_receipt_weight decimal(12,4)
-- declare @total_item_count int

UPDATE #container_details SET average_container_weight = total FROM
	(
			SELECT SUM(details.gallon_conversion_factor) / COUNT(details.receipt_id) as total
			, details.receipt_id
			, details.company_id
			, details.profit_ctr_id
			from #container_details details  WITH(NOLOCK) 
			INNER JOIN @container_key_table keys  ON details.receipt_id = keys.receipt_id
			AND details.company_id = keys.company_id
			AND details.profit_ctr_id = keys.profit_ctr_id
			WHERE details.container_type = 'R'
			GROUP BY details.receipt_id
			, details.company_id
			, details.profit_ctr_id
	) tbl
		INNER JOIN #container_details container_details  WITH(NOLOCK) ON
			tbl.receipt_id = container_details.receipt_id
			AND tbl.company_id = container_details.company_id
			AND tbl.profit_ctr_id = container_details.profit_ctr_id
			
IF @debug > 0
	SELECT 'UPDATE: after average_container_weight finished', DATEDIFF(millisecond, @TimeStart, getdate())       
		
				


SELECT company_id,
       profit_ctr_id,
       receipt_id,
       COUNT(receipt_id) AS total
INTO   #container_totals
FROM   (SELECT cd.receipt_id,
               cd.company_id,
               cd.profit_ctr_id,
               cd.line_id,
               cd.container_id,
               cd.sequence_id
        FROM   ContainerDestination cd WITH(NOLOCK) 
               LEFT JOIN #container_details d WITH(NOLOCK) 
                 ON d.company_id = cd.company_id
                    AND d.profit_ctr_id = cd.profit_ctr_id
                    AND d.receipt_id = cd.receipt_id
                    AND d.line_id = cd.line_id
                    AND d.container_id = cd.container_id
                    AND d.sequence_id = cd.sequence_id
        --WHERE  d.receipt_id = 734074
        GROUP  BY cd.receipt_id,
                  cd.company_id,
                  cd.profit_ctr_id,
                  cd.line_id,
                  cd.container_id,
                  cd.sequence_id) tbl
GROUP  BY company_id,
          profit_ctr_id,
          receipt_id 
          
IF @debug > 0
	SELECT '#container_totals finished', DATEDIFF(millisecond, @TimeStart, getdate())       
		
create NONCLUSTERED index idx_totals_tmp on #container_totals(receipt_id, company_id, profit_ctr_id)	          
          
          
          
SELECT company_id,
       profit_ctr_id,
       receipt_id,
       line_id,
       COUNT(receipt_id) AS total
INTO   #container_totals_per_line
FROM   (SELECT cd.receipt_id,
               cd.company_id,
               cd.profit_ctr_id,
               cd.line_id,
               cd.container_id
        FROM   Container cd WITH(NOLOCK) 
               LEFT JOIN #container_details d WITH(NOLOCK) 
                 ON d.company_id = cd.company_id
                    AND d.profit_ctr_id = cd.profit_ctr_id
                    AND d.receipt_id = cd.receipt_id
                    AND d.line_id = cd.line_id
        --WHERE  d.receipt_id = 734074
        GROUP  BY cd.receipt_id,
                  cd.company_id,
                  cd.profit_ctr_id,
                  cd.line_id,
                  cd.container_id) tbl
GROUP  BY company_id,
          profit_ctr_id,
          receipt_id,
          line_id

create NONCLUSTERED index idx_totals_tmp2 on #container_totals_per_line(receipt_id, company_id, profit_ctr_id)
          
IF @debug > 0
	SELECT '#container_totals_per_line finished', DATEDIFF(millisecond, @TimeStart, getdate())                 
                 
                
--SELECT * FROM #container_totals_per_line where receipt_id = 759739


                          
UPDATE #container_details
SET    total_item_count = total
FROM   #container_totals
WHERE  #container_details.receipt_id = #container_totals.receipt_id
       AND #container_details.company_id = #container_totals.company_id
       AND #container_details.profit_ctr_id = #container_totals.profit_ctr_id 
       
IF @debug > 0
	SELECT 'UPDATE: total_item_count finished', DATEDIFF(millisecond, @TimeStart, getdate())                        

UPDATE #container_details SET containers_for_line = total
FROM   #container_totals_per_line
WHERE  #container_totals_per_line.receipt_id = #container_details.receipt_id
       AND #container_totals_per_line.company_id = #container_details.company_id
       AND #container_totals_per_line.profit_ctr_id = #container_details.profit_ctr_id 
       AND #container_totals_per_line.line_id = #container_details.line_id
       
IF @debug > 0
	SELECT 'UPDATE: containers_for_line finished', DATEDIFF(millisecond, @TimeStart, getdate())                               

UPDATE #container_details SET total_item_count = 1 
	WHERE #container_details.container_type = 'S'
	
	

-- update the containers on site (as of reporting date)
UPDATE #container_details set containers_on_site = total FROM
	(SELECT COUNT(cd.container_id) total
	, cd.company_id
	, cd.profit_ctr_id	
	, cd.receipt_id
--	, cd.line_id
	FROM ContainerDestination cd 
	LEFT JOIN #container_details details ON
			cd.receipt_id = details.receipt_id
			AND cd.line_id = details.line_id
			AND cd.container_id = details.container_id
			AND cd.company_id = details.company_id
			AND cd.profit_ctr_id = details.profit_ctr_id
			AND cd.container_type = details.container_type
	WHERE 1 =
		CASE WHEN (@calculation_mode = 'inventory' AND (details.reporting_date < cd.disposal_date OR cd.disposal_date IS NULL)) THEN 1
		WHEN @calculation_mode = 'invoice' THEN 1
	END
	GROUP BY cd.company_id
	, cd.profit_ctr_id	
	, cd.receipt_id
--	, cd.line_id
	) tbl
	INNER JOIN #container_details container_details ON
		tbl.receipt_id = container_details.receipt_id
--		AND tbl.line_id = container_details.line_id
		AND tbl.company_id = container_details.company_id
		AND tbl.profit_ctr_id = container_details.profit_ctr_id		

IF @debug > 0
	SELECT 'UPDATE: containers_on_site finished', DATEDIFF(millisecond, @TimeStart, getdate())                               


IF @calculation_mode = 'inventory'
	DELETE FROM #container_details WHERE (disposal_date <= reporting_date)	

--IF @calculation_mode = 'invoice'
--	DELETE FROM #container_details WHERE (disposal_date <= @minimum_date)	
	
		
--SELECT 'container details', * FROM #container_details	


UPDATE #container_details set gallon_conversion_factor = avg_weight
		FROM ( 
			SELECT SUM(details.gallon_conversion_factor) / COUNT(details.receipt_id) as avg_weight,
				details.receipt_id
				from #container_details details
				WHERE details.container_type = 'R'
				GROUP BY details.receipt_id
		) tbl
		WHERE #container_details.receipt_id = tbl.receipt_id
		

/* 
	If there is no container size AND it is a STOCK Container
	Assume it is a single 55 Gallon Drum
*/

UPDATE #container_details set gallon_conversion_factor = bu.gal_conv,
	gallon_conversion_unit = bu.bill_unit_code,
	conversion_unit_source = 'container size field',
	conversion_factor_source = 'BillUnit',
	conversion_weight_source = 'calculated weight'
	FROM #container_details r
    INNER JOIN BillUnit bu ON r.container_size = bu.bill_unit_code
	WHERE 
	LEN(ISNULL(r.container_size, '')) = 0
	AND r.container_type = 'S'	



-- SELECT 'details #6', * FROM #container_details



UPDATE #container_details set gallon_conversion_factor = (SELECT gal_conv FROM BillUnit bu WHERE bu.bill_unit_code = 'DM55')
	, gallon_conversion_unit = 'DM55'
	,	conversion_unit_source = 'empty size/weight/conversion assume 55gallon'
	,	conversion_factor_source = 'BillUnit - assume 55gallon'
	,	conversion_weight_source = 'calculated '	
	FROM #container_details r
	WHERE ISNULL(r.container_size,'') = ''
	AND ISNULL(r.container_weight, 0) = 0
	AND ISNULL(r.gallon_conversion_factor,0) = 0
	AND ISNULL(gallon_conversion_unit,'') = ''
	
-- SELECT 'details #7', * FROM #container_details



	
	
-- if there is no conversion anywhere, assume 55 Gallon Drum	
UPDATE #container_details set gallon_conversion_factor = (SELECT gal_conv FROM BillUnit bu WHERE bu.bill_unit_code = 'DM55'),
	gallon_conversion_unit = 'UNKNOWN' 
	FROM #container_details r
	WHERE ISNULL(r.gallon_conversion_factor, 0) = 0
	AND @calculation_mode = 'inventory'
		
		
		
		
 --SELECT 'details #8', * FROM #container_details

UPDATE #container_details set pound_conversion_factor = pound_conv
	FROM BillUnit bu
	INNER JOIN #container_details cd ON cd.gallon_conversion_unit = bu.bill_unit_code


UPDATE #container_details SET avg_receipt_line_weight = (receipt_line_weight / 
	(SELECT COUNT(receipt_id) FROM Container c WHERE #container_details.receipt_id = c.receipt_id
	AND #container_details.company_id = c.company_id
	AND #container_details.profit_ctr_id = c.profit_ctr_id
	AND #container_details.line_id = c.line_id)
)


UPDATE #container_details set container_weight = receipt_line_weight
	WHERE ISNULL(receipt_line_weight, 0) > 0 AND ISNULL(container_weight, 0) = 0


UPDATE #container_details SET container_weight = container_weight / containers_for_line

if @calculation_mode = 'inventory'
begin
	-- calculate the weights (either from actual or 'calculated')
	/* estimated container weight */
	UPDATE #container_details
	SET    
		container_weight_gallons = ( gallon_conversion_factor * containers_on_site) * ( cast(container_percent AS DECIMAL(12, 4)) / cast(100 AS DECIMAL(12, 4)) ),
		estimated_gallons = ( gallon_conversion_factor * containers_on_site) * ( cast(container_percent AS DECIMAL(12, 4)) / cast(100 AS DECIMAL(12, 4)))
	WHERE  isnull(container_weight, 0) = 0 

	/* actual container weight */
	UPDATE #container_details
	SET    container_weight_gallons = ( container_weight * @pound_to_gallon * containers_on_site) * ( cast(container_percent AS DECIMAL(12, 4)) / cast(100 AS DECIMAL(12, 4)) ),
	actual_reported_gallons = ( container_weight * @pound_to_gallon * containers_on_site) * ( cast(container_percent AS DECIMAL(12, 4)) / cast(100 AS DECIMAL(12, 4)) )
	WHERE  isnull(container_weight, 0) <> 0 



	/* estimated */
	UPDATE #container_details
	SET    container_weight_pounds  = ( avg_receipt_line_weight * pound_conversion_factor) * ( cast(container_percent AS DECIMAL(12, 4)) / cast(100 AS DECIMAL(12, 4)) ),
	estimated_pounds = ( avg_receipt_line_weight * pound_conversion_factor) * ( cast(container_percent AS DECIMAL(12, 4)) / cast(100 AS DECIMAL(12, 4)) )
	WHERE  isnull(receipt_line_weight, 0) = 0 


	UPDATE #container_details
	SET    container_weight_pounds  = ( avg_receipt_line_weight ) * ( cast(container_percent AS DECIMAL(12, 4)) / cast(100 AS DECIMAL(12, 4)) ),
	actual_reported_pounds = ( avg_receipt_line_weight) * ( cast(container_percent AS DECIMAL(12, 4)) / cast(100 AS DECIMAL(12, 4)) )
	WHERE  isnull(receipt_line_weight, 0) <> 0 
end

if @calculation_mode = 'invoice'
begin

	-- for invoice calculations, we can use the normal bill unit conversion (rather than averaging everything and calculating the conversion factor)

	UPDATE #container_details SET 
		gallon_conversion_factor = gal_conv,
		pound_conversion_factor = pound_conv
	FROM
		BillUnit bu WHERE bu.bill_unit_code = #container_details.gallon_conversion_unit
	
	--SELECT receipt_id, company_id, profit_ctr_id, line_id, container_weight, quantity, containers_for_line, gallon_conversion_factor, * FROM #container_details
	
	-- calculate the weights (either from actual or 'calculated')
	UPDATE #container_details SET 
	container_weight_gallons = ( container_weight * gallon_conversion_factor) * ( cast(container_percent AS DECIMAL(12, 4)) / cast(100 AS DECIMAL(12, 4)) ),
	container_weight_pounds  = ( container_weight * pound_conversion_factor) * ( cast(container_percent AS DECIMAL(12, 4)) / cast(100 AS DECIMAL(12, 4)) )
	WHERE ISNULL(container_weight, 0) > 0


	UPDATE #container_details SET 
	container_weight_gallons = (cast((cast(receipt_quantity as decimal(12,4)) / containers_for_line) as decimal(12,4)) * gallon_conversion_factor) * ( cast(container_percent AS DECIMAL(12, 4)) / cast(100 AS DECIMAL(12, 4)) ),
	container_weight_pounds  = (cast((cast(receipt_quantity as decimal(12,4))  / containers_for_line) as decimal(12,4)) * pound_conversion_factor) * ( cast(container_percent AS DECIMAL(12, 4)) / cast(100 AS DECIMAL(12, 4)) )
	WHERE ISNULL(container_weight, 0) = 0

	--print 6.00 / 12.00 * 55.00 * 100.00/100.00
end


UPDATE #container_details SET fifty_five_gallon_container_weight_gallons = 
	container_weight_gallons / 55.0
	FROM #container_details



SELECT cd.*
FROM   #container_details cd

IF @debug > 0
	SELECT 'finished.', DATEDIFF(millisecond, @TimeStart, getdate())                               

--SELECT cd.receipt_id,
--       cd.company_id,
--       cd.profit_ctr_id,
--       cd.line_id,
--       Sum(cd.container_weight_pounds)    AS total_pounds,
--       Sum(cd.container_weight_gallons) total_gallons
--FROM   #container_details cd 
--GROUP BY cd.receipt_id,
--       cd.company_id,
--       cd.profit_ctr_id,
--       cd.line_id
      
END

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_calculate_container_weight] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_calculate_container_weight] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_calculate_container_weight] TO [EQAI]
    AS [dbo];

