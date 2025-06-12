CREATE PROCEDURE [dbo].[sp_rpt_baseline_container_density]
	@baseline_id int = NULL,
	@generator_id int = NULL,
	@start_date datetime = NULL,
	@end_Date datetime = NULL,
	@release_code varchar(20) = NULL,
	@purchase_order varchar(20) = NULL,
	@category_record_type varchar(10) = 'C',
	@debug int = 0
/*
History:
	04/21/2010	RJG	Created
	05/14/2010	JPB Removed Billing joins.  Marked where EQ Disposal info would be needed in future.
	11/04/2010	RJG	Replaced soon-to-be obsolete columns on WorkOrderDetail with WorkOrderDetailUnit

Usage:
		EXEC sp_rpt_baseline_container_density
		  @generator_id=800,
		  @baseline_id=7,
		  @start_date='2010-05-01 00:00:00',
		  @release_code=NULL,
		  @end_Date='2010-08-01 00:00:00',
		  @purchase_order=NULL,
		  @debug=0,
		  @category_record_type=N'C' 	/* or CD1, CD2, CD3 */
*/
AS

SET NOCOUNT ON


if @debug > 0
begin
	print @start_date
	print @end_date
end

if (@start_date IS NULL AND @end_Date IS NULL) AND @release_code IS NULL AND @purchase_order IS NULL
BEGIN
	RAISERROR ('One of either @start_date & @end_date, @release_code, or @purchase_order must be filled in', -- Message text.
               16, -- Severity.
               1 -- State.
               );
	RETURN
END

DECLARE @category_id_column_to_use varchar(50)
DECLARE @category_header_column_name varchar(50)

IF @category_record_type = 'C'
BEGIN
	SET @category_id_column_to_use = 'bd.baseline_category_id'
	SET @category_header_column_name = '''Baseline Category'''
END

IF @category_record_type = 'CD1'
BEGIN
	SET @category_id_column_to_use = 'bd.baseline_category_id_custom_1'
	SET @category_header_column_name = 'bh.custom_defined_name_1'
END

IF @category_record_type = 'CD2'
BEGIN
	SET @category_id_column_to_use = 'bd.baseline_category_id_custom_2'
	SET @category_header_column_name = 'bh.custom_defined_name_2'
END

IF @category_record_type = 'CD3'
BEGIN
	SET @category_id_column_to_use = 'bd.baseline_category_id_custom_3'
	SET @category_header_column_name = 'bh.custom_defined_name_3'
END


--SELECT * FROM BaselineDetail

/*
DECLARE @tbl_ignored_bill_units TABLE
(
	bill_unit_code varchar(20)
)

INSERT INTO @tbl_ignored_bill_units
SELECT 'GAL' UNION ALL
SELECT 'YARD' UNION ALL
SELECT 'D100' UNION ALL
SELECT 'D110' UNION ALL
SELECT 'DM01' UNION ALL
SELECT 'DM05' UNION ALL
SELECT 'DM10' UNION ALL
SELECT 'DM12' UNION ALL
SELECT 'DM15' UNION ALL
SELECT 'DM16' UNION ALL
SELECT 'DM20' UNION ALL
SELECT 'DM25' UNION ALL
SELECT 'DM2X' UNION ALL
SELECT 'DM30' UNION ALL
SELECT 'DM35' UNION ALL
SELECT 'DM40' UNION ALL
SELECT 'DM45' UNION ALL
SELECT 'DM50' UNION ALL
SELECT 'DM55' UNION ALL
SELECT 'DM85' UNION ALL
SELECT 'DM95'
*/

/* 
	for EQ Disposal...
	Need to add to #result_data_temp
		WO_company_id int,
		WO_profit_ctr_id int,
		WO_workorder_id int

*/
	
CREATE TABLE #result_data_temp (
	[generator_id] [int] NULL,
	[EPA_ID] varchar(50) NULL,
	[generator_name] [varchar](40) NULL,
	[site_code] [varchar](16) NULL,
	[workorder_ID] [int] NULL,
	[company_id] [int] NULL,
	[profit_ctr_id] [smallint] NULL,
	[resource_type] [char](1) NULL,
	[sequence_id] [int] NULL,
	[transaction_description] [varchar](100) NULL,
	[approval_number] [varchar](40) NULL,
	[service_date] [datetime] NULL,
	[bill_unit_code] [varchar](4) NULL,
	[quantity] [float] NULL,
	[release_code] [varchar](20) NULL,
	[purchase_order] [varchar](20) NULL,
	[baseline_category_id] [int] NULL,
	[expected_amount] [float] NULL,
	[time_period] [varchar](50) NULL,
	[reporting_type] [varchar](15) NULL,
	[baseline_category_name] [varchar](50) NULL,
	[baseline_category_record_type] varchar(20) NULL,
	[total_expected_amount] [float] NULL,
	pound_conversion_unit varchar(20),
	pound_conversion_factor float,
	customer_id int,
	container_count int,
	workorderdetail_pounds float
)

	SELECT *
	INTO #customer_categories
	FROM BaselineCategory where customer_id = (
		SELECT customer_id 
		FROM BaselineHeader WHERE baseline_id = @baseline_id)

/* 
	for EQ Disposal...
	Need to run a similar insert select for workorders inner joined to billing link lookup, inner joined to receipt.
	... when this runs, insert the workorder's workorder_id, company_id, profit_ctr_id to new fields in the #table
	... Then after that insert finishes, run the version below with a (and workorder_id not in #table) clause
	... To add the workorders that are not linked to the set that are.  Then report/work off that #table
*/
DECLARE @sql_search varchar(max)
SET @sql_search = '
INSERT INTO #result_data_temp
SELECT DISTINCT
	woh.generator_id,
	g.EPA_ID,
	g.generator_name,
	g.site_code,
	woh.workorder_ID,
	wod.company_id,
	wod.profit_ctr_id,
	wod.resource_type,
	wod.sequence_id,
	CASE
		WHEN wod.resource_type = ''D'' THEN dbo.fn_get_waste_description(wod.TSDF_code, wod.TSDF_approval_id, wod.profile_id, wod.company_id, wod.profit_ctr_ID)
		WHEN wod.resource_type <> ''D'' then wod.description
		ELSE ''Unknown''
	END as transaction_description,
	dbo.fn_get_workorder_approval_code(wod.TSDF_code, wod.TSDF_approval_id, wod.profile_id, wod.company_id, wod.profit_ctr_ID) as approval_number,
	woh.start_date as service_date,
	wodu.bill_unit_code,
	isnull(wodu.quantity, wod.quantity) as quantity,
	woh.release_code,
	woh.purchase_order,
	' + @category_id_column_to_use + ' as baseline_category_id,
	bd.expected_amount,
	bd.time_period,
	brt.reporting_type,
	' + @category_id_column_to_use + ' as baseline_category_name,	
	bc.record_type,
	CAST(0 as float) as total_expected_amount,
	wodu.bill_unit_code as pound_conversion_unit,
	CASE
		WHEN bd.pound_conv_override IS NOT NULL THEN bd.pound_conv_override
		ELSE ISNULL((SELECT pound_conv FROM BillUnit WHERE bill_unit_code = wodu.bill_unit_code),0)
	END as pound_conversion_factor,
	bh.customer_id,
	wod.container_count,
	(
		SELECT 
			quantity
			FROM WorkOrderDetailUnit a
			WHERE a.workorder_id = wodu.workorder_id
			AND a.company_id = wodu.company_id
			AND a.profit_ctr_id = wodu.profit_ctr_id
			AND a.sequence_id = wodu.sequence_id
			AND a.billing_flag = ''F''
			AND a.bill_unit_code = ''LBS''
	) as workorderdetail_pounds
FROM   workorderheader woh
        INNER JOIN WorkOrderDetail wod ON 1=1 -- 1=1 is for debugging
			AND wod.workorder_id = woh.workorder_id
            AND wod.company_id = woh.company_id
            AND wod.profit_ctr_id = woh.profit_ctr_id
            AND wod.resource_type = ''D''
            AND woh.workorder_status = ''A''
            AND woh.submitted_flag = ''T''
            AND woh.generator_id = ' + cast(@generator_id as varchar(20)) + '
        INNER JOIN WorkOrderDetailUnit wodu ON
			wod.workorder_id = wodu.workorder_id
			AND wod.company_id = wodu.company_id
			AND wod.profit_ctr_id = wodu.profit_ctr_id
			AND wod.sequence_id = wodu.sequence_id
			AND wodu.billing_flag = ''T''			            
        INNER JOIN BaselineHeader bh ON  -- 1=1 is for debugging
			bh.customer_id = woh.customer_ID
			AND bh.baseline_id = ' + cast(@baseline_id as varchar(20)) + '
		INNER JOIN BaselineDetail bd ON 1=1  -- 1=1 is for debugging
			AND bh.baseline_id = bd.baseline_id
			AND bd.generator_id = woh.generator_id
		INNER JOIN BaselineReportingType brt ON 1=1 -- 1=1 is for debugging
			AND bd.reporting_type_id = brt.reporting_type_id
        INNER JOIN WorkorderDetailBaseline wodb ON 1=1 -- 1=1 is for debugging
			 AND wodb.workorder_id = wod.workorder_ID
			 AND wodb.company_id = wod.company_id
			 AND wodb.profit_ctr_id = wod.profit_ctr_ID
			 AND wodb.resource_type = wod.resource_type
			 AND wodb.sequence_id = wod.sequence_ID
			 AND wodb.baseline_category_id = bd.baseline_category_id 
			 AND wodb.company_id = woh.company_id
			 AND wodb.profit_ctr_id = woh.profit_ctr_ID
		INNER JOIN BaselineCategory bc ON 1=1 -- 1=1 is for debugging
			AND bc.baseline_category_id = bd.baseline_category_id 
		INNER JOIN Generator g ON 1=1  -- 1=1 is for debugging
			AND g.generator_id = woh.generator_id
' -- end main dynamic sql

IF @start_date IS NOT NULL AND @end_date IS NOT NULL
			SET @sql_search = @sql_search + ' AND woh.start_date BETWEEN ''' + (cast(@start_date as varchar(20)))+ ''' AND ''' + (cast(@end_date as varchar(20))) + ''' '

IF @purchase_order IS NOT NULL
			SET @sql_search = @sql_search + ' AND woh.purchase_order = ''' + @purchase_order + ''' '

IF @release_code IS NOT NULL
			SET @sql_search = @sql_search + ' AND woh.release_code = ''' + @release_code + ''' '

if @debug > 0
begin
	print @sql_search
end

exec(@sql_search)

DECLARE @generator_name varchar(100)
SELECT @generator_name = Generator.generator_name FROM Generator where generator_id = @generator_id

IF @debug > 0
BEGIN

	SELECT '#result_data_temp' as [#result_data_temp], * FROM #result_data_temp

	IF @debug > 1
	BEGIN
		
		SELECT '#customer_categories' as [#customer_categories], * FROM #customer_categories
		
		SELECT 'query-before-summing' as [query-before-summing],
			bc.baseline_category_id,
			tmp.baseline_category_id,
			bc.record_type,
			CASE
				WHEN bc.record_type = 'C' THEN 'Baseline Category'
				WHEN bc.record_type = 'CD1' THEN (SELECT BaselineHeader.custom_defined_name_1 FROM BaselineHeader WHERE BaselineHeader.baseline_id = @baseline_id)
				WHEN bc.record_type = 'CD2' THEN (SELECT BaselineHeader.custom_defined_name_2 FROM BaselineHeader WHERE BaselineHeader.baseline_id = @baseline_id)
				WHEN bc.record_type = 'CD3' THEN (SELECT BaselineHeader.custom_defined_name_3 FROM BaselineHeader WHERE BaselineHeader.baseline_id = @baseline_id)
			END as baseline_category_header_name,
			bc.description as category_description,
			@generator_id as generator_id,
			@generator_name as generator_name,
			--pound_conversion_workorder_detail_lines_skipped = (SELECT COUNT(bill_unit_code) FROM #result_data_temp WHERE
			--	bill_unit_code IN (SELECT bill_unit_code FROM @tbl_ignored_bill_units)
			--	AND bc.baseline_category_id = tmp.baseline_category_id
			--),
			pound_conversion_workorder_detail_lines_total_for_category = (SELECT COUNT(bill_unit_code) FROM #result_data_temp
				WHERE bc.baseline_category_id = tmp.baseline_category_id
			),
			tmp.container_count,
			tmp.customer_id
		FROM #customer_categories bc
		INNER JOIN #result_data_temp tmp ON bc.baseline_category_id = tmp.baseline_category_id
			--AND tmp.pound_conversion_unit NOT IN (SELECT bill_unit_code FROM @tbl_ignored_bill_units)
			AND bc.customer_id = tmp.customer_id
		WHERE bc.record_type = @category_record_type
		
	END
END


CREATE TABLE #category_totals 
(
	pounds float,
	baseline_category_id int,
	record_type varchar(10),
	baseline_description varchar(50),
	total_containers int
)

INSERT INTO #category_totals
	SELECT 
	tmp.workorderdetail_pounds,
	bc.baseline_category_id, 
	bc.record_type,
	bc.description,
	tmp.container_count
	FROM BaselineCategory bc 
	INNER JOIN #result_data_temp tmp ON bc.baseline_category_id = tmp.baseline_category_id
	WHERE bc.record_type = @category_record_type	
		AND bc.customer_id = tmp.customer_id		
		AND workorderdetail_pounds IS NOT NULL
		

INSERT INTO #category_totals
	SELECT 
	SUM(ISNULL(tmp.pound_conversion_factor,0) * ISNULL(tmp.quantity,0)) as pounds,
	bc.baseline_category_id, 
	bc.record_type,
	bc.description,
	tmp.container_count
	FROM BaselineCategory bc 
	INNER JOIN #result_data_temp tmp ON bc.baseline_category_id = tmp.baseline_category_id
	WHERE bc.record_type = @category_record_type	
		AND bc.customer_id = tmp.customer_id		
		AND workorderdetail_pounds IS NULL		
	GROUP BY bc.baseline_category_id, bc.description, bc.record_type, container_count


SELECT ct.baseline_category_id,
		ct.baseline_description as category_description,
		ct.pounds as total_pounds,
		ct.record_type,
		ct.total_containers,
        CASE
         WHEN ct.record_type = 'C' THEN 'Baseline Category'
         WHEN ct.record_type = 'CD1' THEN (SELECT baselineheader.custom_defined_name_1
                                           FROM   baselineheader
                                           WHERE  baselineheader.baseline_id = @baseline_id)
         WHEN ct.record_type = 'CD2' THEN (SELECT baselineheader.custom_defined_name_2
                                           FROM   baselineheader
                                           WHERE  baselineheader.baseline_id = @baseline_id)
         WHEN ct.record_type = 'CD3' THEN (SELECT baselineheader.custom_defined_name_3
                                           FROM   baselineheader
                                           WHERE  baselineheader.baseline_id = @baseline_id)
       END             AS baseline_category_header_name,
       @generator_id   AS generator_id,
       @generator_name AS generator_name,
       customer_id = (SELECT customer_id FROM BaselineHeader where baseline_id = @baseline_id),
		g.EPA_ID,
		g.site_code
 FROM #category_totals ct
	INNER JOIN Generator g ON g.generator_id = @generator_id
ORDER BY baseline_category_id, g.generator_id

	
	

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_baseline_container_density] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_baseline_container_density] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_baseline_container_density] TO [EQAI]
    AS [dbo];

