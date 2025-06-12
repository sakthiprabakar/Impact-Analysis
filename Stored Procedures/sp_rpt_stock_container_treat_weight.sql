CREATE PROCEDURE sp_rpt_stock_container_treat_weight
	@company_id		int
,	@profit_ctr_id 	int
,	@date_from 		datetime
,	@date_to 		datetime
,	@location		varchar(15)
,	@staging_row	varchar(5)
,	@base_container	int
AS
/***************************************************************************************
Filename:		L:\Apps\SQL\EQAI\sp_rpt_stock_container_treat_weight.SQL
PB Object(s):	d_rpt_stock_container_summary
				d_rpt_stock_container_treat_weight

08/19/2004 SCC	Created
04/05/2005 JDB	Added join from Container to ContainerDestination on container_id;
				Added container_percent into calculation
04/20/2010	RJG	Changed to use dbo.fn_container_source function to retrieve the container's ENTIRE
				family tree  (not just 1 level deep)
10/28/2010	SK	Added Company_ID as input arg, added joins to company wherever necessary
				Moved to Plt_AI

sp_rpt_stock_container_treat_weight 21, 0, '2-16-10 00:00', '2-17-10 23:59', 'ALL', 'ALL', 010004
****************************************************************************************/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

SET NOCOUNT ON

DECLARE	
	@stock_drum_count		int
,	@loop_company_id		int
,	@loop_profit_ctr_id		int
,	@loop_receipt_id		int
,	@loop_line_id			int
,	@loop_container_id		int
,	@loop_sequence_id		int	
,	@loop_base_container	varchar(50)
,	@loop_base_container_treatment_id	int
,	@loop_base_container_treatment_desc	varchar(32)
,	@loop_base_container_weight			decimal(10,3)
,	@loop_base_container_size			varchar(15)
,	@loop_base_date_created				datetime
,	@loop_base_status					varchar(10)

SELECT DISTINCT 
	dbo.fn_container_stock(ContainerDestination.line_id, ContainerDestination.company_id, ContainerDestination.profit_ctr_id) AS base_container
,	ContainerDestination.treatment_id AS base_container_treatment_id
,	Treatment.treatment_desc AS base_container_treatment_desc
,	ISNULL(Container.container_weight, 0) AS base_container_weight
,	ISNULL(Container.container_size, '') AS base_container_size
,	ContainerDestination.date_added AS date_created
,	ContainerDestination.status AS base_status
,	ContainerDestination.company_id
,	ContainerDestination.profit_ctr_id
,	ContainerDestination.receipt_id
,	ContainerDestination.line_id
,	ContainerDestination.container_id
,	ContainerDestination.sequence_id
,	ContainerDestination.container_type
INTO #stock_container
FROM ContainerDestination
INNER JOIN Container ON Container.company_id = ContainerDestination.company_id
	AND Container.profit_ctr_id = ContainerDestination.profit_ctr_id
	AND Container.receipt_id = ContainerDestination.receipt_id
	AND Container.line_id = ContainerDestination.line_id
	AND Container.container_id = ContainerDestination.container_id
	AND Container.container_type = ContainerDestination.container_type
LEFT OUTER JOIN Treatment ON ContainerDestination.company_id = Treatment.company_id
	AND ContainerDestination.profit_ctr_id = Treatment.profit_ctr_id
	AND ContainerDestination.treatment_id = Treatment.treatment_id
WHERE	( @company_id = 0 OR ContainerDestination.company_id = @company_id )
	AND ( @company_id = 0 OR @profit_ctr_id = -1 OR ContainerDestination.profit_ctr_id = @profit_ctr_id )
	AND ContainerDestination.date_added BETWEEN @date_from and @date_to
	AND ContainerDestination.container_type = 'S'
	AND (@location = 'ALL' OR ContainerDestination.location = @location)
	AND (@staging_row = 'ALL' OR Container.staging_row = @staging_row)
	AND (@base_container = -99999 OR ContainerDestination.container_id = @base_container)

SELECT @stock_drum_count = COUNT(*) FROM #stock_container

if (object_id('tempdb..#results')) IS NOT NULL DROP TABLE [#results]

CREATE TABLE [dbo].[#results](
	[base_container] [varchar](15) NULL,
	[base_container_treatment_id] [int] NULL,
	[base_container_treatment_desc] [varchar](32) NULL,
	[base_container_weight] [decimal](10, 3) NOT NULL,
	[base_container_size] [varchar](15) NOT NULL,
	[date_created] [datetime] NULL,
	[source_container] [varchar](31) NULL,
	[source_container_id] [int] NULL,
	[source_container_treatment_id] [int] NULL,
	[source_container_weight] [decimal](10, 3) NULL,
	[source_container_size] [varchar](15) NULL,
	[source_container_percent] [int] NULL,
	[source_container_status] [char](1) NULL,
	[company_id] [int] NULL,
	[profit_ctr_id] [int] NULL,
	[stock_drum_count] [int] NULL,
	[consolidation_count] [int] NOT NULL,
	[base_status] [char](1) NULL
)


DECLARE cur_stock_containers CURSOR FOR 
	SELECT company_id,
		profit_ctr_id,
		receipt_id,
		line_id,
		container_id,
		sequence_id,
		base_container,
		base_container_treatment_id,
		base_container_treatment_desc,
		base_container_weight,
		base_container_size,
		date_created,
		base_status
	FROM #stock_container
	
OPEN cur_stock_containers 

	FETCH cur_stock_containers 
	INTO @loop_company_id,
		@loop_profit_ctr_id,
		@loop_receipt_id,
		@loop_line_id,
		@loop_container_id,
		@loop_sequence_id,
		@loop_base_container,
		@loop_base_container_treatment_id,
		@loop_base_container_treatment_desc,
		@loop_base_container_weight,
		@loop_base_container_size,
		@loop_base_date_created,
		@loop_base_status		

	WHILE @@FETCH_STATUS = 0 
	BEGIN 
		-- Retrieve the entire list of containers that were poured into these base containers and their treatments and weights
		INSERT INTO [#results]
		
		SELECT DISTINCT
			@loop_base_container as base_container,
			@loop_base_container_treatment_id as base_container_treatment_id,
			@loop_base_container_treatment_desc as base_container_treatment_desc,
			@loop_base_container_weight as base_container_weight,
			@loop_base_container_size as base_container_size,
			@loop_base_date_created as base_date_created,
			CASE WHEN ContainerDestination.container_type = 'R' 
				THEN CONVERT(varchar(15), ContainerDestination.receipt_id) + '-' + CONVERT(varchar(15), ContainerDestination.line_id)
				ELSE dbo.fn_container_stock(ContainerDestination.line_id, ContainerDestination.company_id, ContainerDestination.profit_ctr_id)
				END AS source_container,
			ContainerDestination.container_id AS source_container_id,
			ContainerDestination.treatment_id AS source_container_treatment_id,
			Container.container_weight AS source_container_weight,
			Container.container_size AS source_container_size,
			ContainerDestination.container_percent AS source_container_percent,
			ContainerDestination.status AS source_container_status,
			@loop_company_id AS company_id,
			@loop_profit_ctr_id AS profit_ctr_id,
			@stock_drum_count AS stock_drum_count,
			consolidation_count = ISNULL((SELECT COUNT(*) FROM ContainerDestination 
				WHERE ContainerDestination.base_tracking_num = @loop_base_container
				AND ContainerDestination.company_id = @loop_company_id
				AND ContainerDestination.profit_ctr_id = @loop_profit_ctr_id),0),
			@loop_base_status
		FROM Container 
		INNER JOIN ContainerDestination ON Container.company_id = ContainerDestination.company_id
			AND Container.profit_ctr_id = ContainerDestination.profit_ctr_id
			AND Container.receipt_id = ContainerDestination.receipt_id
			AND Container.line_id = ContainerDestination.line_id
			AND Container.container_id = ContainerDestination.container_id
			AND Container.container_type = ContainerDestination.container_type
		INNER JOIN dbo.fn_container_source(@loop_company_id, @loop_profit_ctr_id, @loop_receipt_id, @loop_line_id, @loop_container_id, @loop_sequence_id, 0) containers 
			ON ContainerDestination.company_id = containers.company_id
			AND ContainerDestination.profit_ctr_id = containers.profit_ctr_id
			AND ContainerDestination.receipt_id = containers.receipt_id
			AND ContainerDestination.line_id = containers.line_id
			AND ContainerDestination.container_id = containers.container_id
			AND ContainerDestination.container_type = containers.container_type
		WHERE Container.company_id = @loop_company_id
			AND Container.profit_ctr_id = @loop_profit_ctr_id
		ORDER BY 
		base_container,
		base_date_created,
		source_container,
		source_container_id
		
		--print @loop_line_id
		-----------------------------------------------------
		-- Go to next row 
		-----------------------------------------------------
		FETCH cur_stock_containers 
		INTO @loop_company_id,
		@loop_profit_ctr_id,
		@loop_receipt_id,
		@loop_line_id,
		@loop_container_id,
		@loop_sequence_id,
		@loop_base_container,
		@loop_base_container_treatment_id,
		@loop_base_container_treatment_desc,
		@loop_base_container_weight,
		@loop_base_container_size,
		@loop_base_date_created,
		@loop_base_status		

	END 

CLOSE cur_stock_containers 
DEALLOCATE cur_stock_containers 		

--SELECT distinct base_container FROM #stock_container
--SELECT distinct base_container FROM #results

SELECT 
	#results.*
,	Treatment.treatment_desc
,	Company.company_name
,	ProfitCenter.profit_ctr_name
FROM #results
JOIN Company
	ON Company.company_id = #results.company_id
JOIN ProfitCenter
	ON ProfitCenter.company_id = #results.company_id
	AND ProfitCenter.profit_ctr_id = #results.profit_ctr_id
LEFT OUTER JOIN Treatment
	ON Treatment.company_id = #results.company_id
	AND Treatment.profit_ctr_id = #results.profit_ctr_id
	AND Treatment.treatment_id = ISNULL(#results.source_container_treatment_id, 0)

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_stock_container_treat_weight] TO [EQAI]
    AS [dbo];

