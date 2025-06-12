CREATE PROCEDURE sp_rpt_container_disposed_by_destination
	@company_id			int
,	@profit_ctr_id		int
,	@date_from			datetime
,	@date_to			datetime
,	@customer_id_from	int
,	@customer_id_to		int
,	@location			varchar(15)
,	@staging_row_in		varchar(5)
AS
/***************************************************************************************
PB Objects: r_container_disposed_by_destination
10/29/2010 SK	created on Plt_AI

sp_rpt_container_disposed_by_destination 14, 4, '2-01-04', '2-20-04', 1, 999999, 'ALL', 'ALL'
****************************************************************************************/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

 
SELECT 
	Container.receipt_id
,	Container.line_id
,	Container.container_id
,	Container.container_type
,	Container.status
,	1 as container_count
,	Container.company_id
,	Container.profit_ctr_id
,	ContainerDestination.tracking_num
,	ContainerDestination.location
,	ContainerDestination.disposal_date
,	Receipt.generator_id
,	Container.staging_row
,	generator = (select IsNull(epa_id + '/' + generator_name,'') from generator where Receipt.generator_id = Generator.generator_id)
,	CASE WHEN Container.container_type = 'S' THEN dbo.fn_container_stock(Container.line_id, Container.company_id, Container.profit_ctr_id)
		 ELSE Convert(varchar(10), Container.Receipt_id) + '-' + Convert(varchar(10), Container.line_id) END
	As Container
,	Company.company_name
,	ProfitCenter.profit_ctr_name
FROM Container
JOIN Company
	ON Company.company_id = Container.company_id
JOIN ProfitCenter
	ON ProfitCenter.company_ID = Container.company_id
	AND ProfitCenter.profit_ctr_ID = Container.profit_ctr_id
JOIN ContainerDestination
	ON Container.company_id = ContainerDestination.company_id
	AND Container.profit_ctr_id = ContainerDestination.profit_ctr_id
	AND Container.receipt_id = ContainerDestination.receipt_id
	AND Container.line_id = ContainerDestination.line_id
	AND Container.container_id = ContainerDestination.container_id 
	AND IsNull(ContainerDestination.tracking_num,'') <> ''
    AND IsNull(ContainerDestination.location,'') <> ''
	AND ContainerDestination.disposal_date BETWEEN @date_from AND @date_to
	AND ((@location = 'ALL' OR ContainerDestination.location = @location) 
			AND ContainerDestination.location IN (SELECT location FROM ProcessLocation
													WHERE company_id = ContainerDestination.company_id
														AND profit_ctr_id = ContainerDestination.profit_ctr_id))
LEFT OUTER JOIN Receipt
	ON Receipt.company_id = Container.company_id
	AND Receipt.profit_ctr_id = Container.profit_ctr_id
	AND Receipt.receipt_id = Container.receipt_id
	AND Receipt.line_id = Container.line_id
	AND Receipt.customer_id BETWEEN @customer_id_from AND @customer_id_to
WHERE	(@company_id = 0 OR Container.company_id = @company_id )
	AND (@company_id = 0 OR @profit_ctr_id = -1 OR Container.profit_ctr_id = @profit_ctr_id)
	AND (@staging_row_in = 'ALL' OR Container.staging_row = @staging_row_in)	

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_container_disposed_by_destination] TO [EQAI]
    AS [dbo];

