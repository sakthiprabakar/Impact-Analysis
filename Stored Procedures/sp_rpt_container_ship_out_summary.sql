-- DROP PROCEDURE [dbo].[sp_rpt_container_ship_out_summary]
GO

GO
CREATE PROCEDURE sp_rpt_container_ship_out_summary
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
PB Objects: r_container_ship_out_summary
10/29/2010 SK	created on Plt_AI
07/09/2019 MPM	Incident 12752 - Rewrote with Receipt as the base table to improve
				performance.

sp_rpt_container_ship_out_summary 14, 4, '2-01-04', '2-20-04', 1, 999999, 'WMLIVEOAK', 'ALL'
sp_rpt_container_ship_out_summary 22, 0, '4/1/2019', '4/30/2019', 1, 999999, 'ALL', 'ALL'
****************************************************************************************/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

 
 SELECT 
	Container.receipt_id
,	Container.line_id
,	Container.container_id
,	Container.container_type
,	Container.status
,	Container.container_size
,	Container.container_weight
,	1 AS container_count
,	Container.company_id
,	Container.profit_ctr_id
,	ContainerDestination.tracking_num
,	ContainerDestination.location
,	ContainerDestination.disposal_date
,	ContainerDestination.treatment_id
,	ContainerDestination.container_percent
,	Container.staging_row
,	ContainerDestination.treatment_id
,	ContainerDestination.TSDF_approval_code
,	Receipt.TSDF_code
,	Company.company_name
,	ProfitCenter.profit_ctr_name
FROM Receipt
JOIN Container
	ON Container.company_id = Receipt.company_id
	AND Container.profit_ctr_id = Receipt.profit_ctr_id
	AND (@staging_row_in = 'ALL' OR Container.staging_row = @staging_row_in)	
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
	AND IsNull(ContainerDestination.tracking_num, '') = convert(varchar(10), receipt.receipt_id) + '-' + convert(varchar(5), receipt.line_id)--dbo.fn_container_receipt(Receipt.receipt_id, Receipt.line_id)
    AND IsNull(ContainerDestination.location, '') = Receipt.TSDF_code
	AND ContainerDestination.disposal_date BETWEEN @date_from AND @date_to
	AND ((@location = 'ALL' OR ContainerDestination.location = @location) 
			AND ContainerDestination.location IN (SELECT TSDF_code FROM TSDF))
WHERE	(@company_id = 0 OR Receipt.company_id = @company_id )
	AND (@company_id = 0 OR @profit_ctr_id = -1 OR Receipt.profit_ctr_id = @profit_ctr_id)
	AND Receipt.customer_id BETWEEN @customer_id_from AND @customer_id_to
GO
GRANT EXECUTE
	ON [dbo].[sp_rpt_container_ship_out_summary]
	TO [EQAI]
GO
