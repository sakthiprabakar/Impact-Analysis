CREATE PROCEDURE sp_rpt_container_ship_out_log
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
PB Objects: r_container_ship_out_log
10/29/2010 SK	created on Plt_AI

sp_rpt_container_ship_out_log 14, 4, '2-01-04', '2-20-04', 1, 999999, 'WMLIVEOAK', 'ALL'
****************************************************************************************/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

 
 SELECT 
	Container.receipt_id
,	Container.line_id
,	Container.container_id
,	Container.container_type
,	Container.status
,	1 AS container_count
,	Container.company_id
,	Container.profit_ctr_id
,	ContainerDestination.tracking_num
,	ContainerDestination.location
,	ContainerDestination.disposal_date
,	Receipt.generator_id
,	Container.staging_row
,	generator = (SELECT ISNULL(epa_id + '/' + generator_name,'') FROM Generator WHERE Receipt.generator_id = Generator.generator_id)
,	ContainerDestination.treatment_id
,	ContainerDestination.TSDF_approval_code
,	Receipt.TSDF_code
,	Company.company_name
,	ProfitCenter.profit_ctr_name
FROM Container
JOIN Company
	ON Company.company_id = Container.company_id
JOIN ProfitCenter
	ON ProfitCenter.company_ID = Container.company_id
	AND ProfitCenter.profit_ctr_ID = Container.profit_ctr_id
INNER JOIN ContainerDestination 
	ON Container.company_id = ContainerDestination.company_id
	AND Container.profit_ctr_id = ContainerDestination.profit_ctr_id
	AND Container.receipt_id = ContainerDestination.receipt_id
	AND Container.line_id = ContainerDestination.line_id
	AND Container.container_id = ContainerDestination.container_id
	AND IsNull(ContainerDestination.tracking_num,'') <> ''
	AND IsNull(ContainerDestination.location,'') <> ''
	AND ContainerDestination.disposal_date BETWEEN @date_from AND @date_to
	AND ((@location = 'ALL' OR ContainerDestination.location = @location) 
			AND ContainerDestination.location IN (SELECT TSDF_code FROM TSDF))
INNER JOIN Receipt 
	ON Container.company_id = Receipt.company_id 
	AND Container.profit_ctr_id = Receipt.profit_ctr_id
	AND Container.receipt_id = Receipt.receipt_id 
	AND Container.line_id = Receipt.line_id
	AND Receipt.customer_id BETWEEN @customer_id_from AND @customer_id_to
WHERE	(@company_id = 0 OR Container.company_id = @company_id )
	AND (@company_id = 0 OR @profit_ctr_id = -1 OR Container.profit_ctr_id = @profit_ctr_id)
	AND NOT (@customer_id_from = 1 AND @customer_id_to = 999999)
	AND (@staging_row_in = 'ALL' OR Container.staging_row = @staging_row_in)
	
		
UNION

SELECT 
	Container.receipt_id
,	Container.line_id
,	Container.container_id
,	Container.container_type
,	Container.status
,	1 AS container_count
,	Container.company_id
,	Container.profit_ctr_id
,	ContainerDestination.tracking_num
,	ContainerDestination.location
,	ContainerDestination.disposal_date
,	Receipt.generator_id
,	Container.staging_row
,	generator = (SELECT ISNULL(epa_id + '/' + generator_name,'') FROM Generator WHERE Receipt.generator_id = Generator.generator_id)
,	ContainerDestination.treatment_id
,	ContainerDestination.TSDF_approval_code
,	Receipt.TSDF_code
,	Company.company_name
,	ProfitCenter.profit_ctr_name
FROM Container
JOIN Company
	ON Company.company_id = Container.company_id
JOIN ProfitCenter
	ON ProfitCenter.company_ID = Container.company_id
	AND ProfitCenter.profit_ctr_ID = Container.profit_ctr_id
INNER JOIN ContainerDestination 
	ON Container.company_id = ContainerDestination.company_id
	AND Container.profit_ctr_id = ContainerDestination.profit_ctr_id
	AND Container.receipt_id = ContainerDestination.receipt_id
	AND Container.line_id = ContainerDestination.line_id
	AND Container.container_id = ContainerDestination.container_id
	AND IsNull(ContainerDestination.tracking_num,'') <> ''
	AND IsNull(ContainerDestination.location,'') <> ''
	AND ContainerDestination.disposal_date BETWEEN @date_from AND @date_to
	AND ((@location = 'ALL' OR ContainerDestination.location = @location) 
			AND ContainerDestination.location IN (SELECT TSDF_code FROM TSDF))
LEFT OUTER JOIN Receipt 
	ON Container.company_id = Receipt.company_id 
	AND Container.profit_ctr_id = Receipt.profit_ctr_id
	AND Container.receipt_id = Receipt.receipt_id 
	AND Container.line_id = Receipt.line_id
	AND Receipt.customer_id BETWEEN @customer_id_from AND @customer_id_to
WHERE	(@company_id = 0 OR Container.company_id = @company_id )
	AND (@company_id = 0 OR @profit_ctr_id = -1 OR Container.profit_ctr_id = @profit_ctr_id)
	AND (@customer_id_from = 1 AND @customer_id_to = 999999)
	AND (@staging_row_in = 'ALL' OR Container.staging_row = @staging_row_in)	

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_container_ship_out_log] TO [EQAI]
    AS [dbo];

