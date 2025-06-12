
CREATE PROCEDURE sp_rpt_stock_container_detail_review
	@company_id					int
,	@profit_ctr_id 				int
,	@stock_container_id_from	int
,	@stock_container_id_to 		int
,	@trip_id					int
,   @staging_rows				varchar(5)
AS
/***************************************************************************************
r_stock_container_detail_review

02/05/2018 MPM	Created
03/08/2018 AM Added staging_rows argument.
04/27/2018 MPM	Fixed problem when @stock_container_id_to = 999999 (when no value is specified
				for "container to")
05/09/2018 AM Fixed @stock_container_id_to bug. When @stock_container_id_to = @stock_container_id_from it returns only one row.
				 Modified @stock_container_id_from to -9999 and @stock_container_id_to = -99999 when null or 999999
05/29/2018 GEM:50918-AM - Fixed code to retrieve data even for single container. 
04/24/2019 AGC GEM:60927 added location and tracking_num to result set query to match PB datawindow definition
  
sp_rpt_stock_container_detail_review 42, 0, 3552, -99999, -99, null
sp_rpt_stock_container_detail_review 45, 0, 1, -999999, -99 , 'PCBX'
sp_rpt_stock_container_detail_review 21, 0, 320254, 320260, -99 , 'ALL'
sp_rpt_stock_container_detail_review 21, 0, 320254, 320260, 56227 , 'FX4'
sp_rpt_stock_container_detail_review 21, 0, 320256, null , null , null

****************************************************************************************/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
DECLARE 
	@debug 			int
	
if @stock_container_id_from is null or @stock_container_id_from = 999999
	set @stock_container_id_from = -9999
	
-- If the user doesn't enter a "to" value when running the report from EQAI, the app sends in 999999.
-- In this case, set the "to" value to equal the "from" value:
if @stock_container_id_to is null or @stock_container_id_to = 999999
	set @stock_container_id_to = -99999 -- @stock_container_id_from

if ( @stock_container_id_from is not null or @stock_container_id_from = -9999 )
    AND  ( @stock_container_id_to is null or @stock_container_id_to = -99999 )
    set @stock_container_id_to = @stock_container_id_from
   	
if @staging_rows is null
	set @staging_rows = 'ALL'

-- Debugging?
SELECT @debug = 0
	
CREATE TABLE #tmp_staging_rows (staging_rows	varchar(5) NULL)

if datalength((@staging_rows)) > 0 and @staging_rows <> 'ALL'
	EXEC sp_list @debug, @staging_rows, 'STRING', '#tmp_staging_rows'

if @trip_id is null 
	set @trip_id = -99

select distinct 
	dbo.fn_container_stock(c.line_id, c.company_id, c.profit_ctr_id) as base_container,
	c.company_id,
	c.profit_ctr_id,
	c.receipt_id,
	c.line_id,
	c.container_id,
	CAST(NULL AS varchar(60)) as preassigned
INTO #stock_containers
FROM Container c (nolock)
WHERE c.container_type = 'S'
AND   c.status <> 'V'
AND c.company_id = @company_id
AND c.profit_ctr_id = @profit_ctr_id
and ((c.container_id between @stock_container_id_from and @stock_container_id_to) or 
	(@stock_container_id_from = c.container_id or @stock_container_id_to = -99999) or 
	(@stock_container_id_from = -9999 and @stock_container_id_to = -99999))
and (c.trip_id = @trip_id or @trip_id = -99)
AND (@staging_rows = 'ALL' OR ISNULL(c.staging_row, '') in (select staging_rows from #tmp_staging_rows))

update #stock_containers
	set preassigned = pqa.approval_code
from #stock_containers s
join ContainerDestination cd
	on cd.company_id = s.company_id
	and cd.profit_ctr_id = s.profit_ctr_id
	and cd.receipt_id = s.receipt_id
	and cd.line_id = s.line_id
	and cd.container_id = s.container_id
	and cd.location_type = 'O' 
join ProfileQuoteApproval pqa
on pqa.profile_id = cd.OB_profile_id
and pqa.company_id = cd.OB_profile_company_ID
and pqa.profit_ctr_id = cd.OB_profile_profit_ctr_id

update #stock_containers
	set preassigned = ta.TSDF_code + ' - ' + ta.tsdf_approval_code
from #stock_containers s
join ContainerDestination cd
	on cd.company_id = s.company_id
	and cd.profit_ctr_id = s.profit_ctr_id
	and cd.receipt_id = s.receipt_id
	and cd.line_id = s.line_id
	and cd.container_id = s.container_id
	and cd.location_type = 'O' 
join TSDFApproval ta
	on ta.TSDF_approval_id = cd.TSDF_approval_id

update #stock_containers
	set preassigned = CASE WHEN cd.tracking_num is not null THEN cd.location + ' - ' + cd.tracking_num ELSE cd.location END
from #stock_containers s
join ContainerDestination cd
	on cd.company_id = s.company_id
	and cd.profit_ctr_id = s.profit_ctr_id
	and cd.receipt_id = s.receipt_id
	and cd.line_id = s.line_id
	and cd.container_id = s.container_id
	and cd.location_type = 'P' 
	and cd.location is not null

select distinct s.base_container,
	cd.company_id, 
	cd.profit_ctr_id,
	cd.receipt_id,
	cd.line_id,
	cd.container_id,
	cd.sequence_id,
	RIGHT('00' + CONVERT(varchar(2), th.company_id), 2) + '-' + RIGHT('00' + CONVERT(varchar(2), th.profit_ctr_id), 2) + '-' + CONVERT(varchar(10), th.trip_id) as source_trip,
	t.treatment_id,
	pcg.consolidation_group,
	c.container_weight,
	c.manifest_container as container_type,
	c.container_size,
	c.date_added,
	dbo.fn_container_waste_code_list(
		cd.company_id,
		cd.profit_ctr_id,
		cd.container_type,
		cd.receipt_id,
		cd.line_id,
		cd.container_id,
		cd.sequence_id) as waste_codes,
	s.preassigned,
	cd.location,
	cd.tracking_num
FROM #stock_containers s (nolock)
JOIN ContainerDestination cd (nolock)
	ON cd.company_id = s.company_id
	AND cd.profit_ctr_id = s.profit_ctr_id
	AND cd.receipt_id = s.receipt_id
	AND cd.line_id = s.line_id
	AND cd.container_id = s.container_id
	AND cd.sequence_id = 1
JOIN Container c (nolock)
	ON c.receipt_id = cd.receipt_id
	AND c.line_id = cd.line_id
	AND c.company_id = cd.company_id
	AND c.profit_ctr_id = cd.profit_ctr_id
	AND c.container_type = cd.container_type
	AND c.container_id = cd.container_id
LEFT OUTER JOIN TripHeader th (nolock)
	ON th.trip_id = c.trip_id
LEFT OUTER JOIN Treatment t (nolock)
	ON t.company_id = cd.company_id
	AND t.profit_ctr_id = cd.profit_ctr_id
	AND t.treatment_id = cd.treatment_id
LEFT OUTER JOIN ProfileConsolidationGroup pcg (nolock)
	ON pcg.consolidation_group_uid = cd.consolidation_group_uid

ORDER BY s.base_container

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_stock_container_detail_review] TO [EQAI]
    AS [dbo];

