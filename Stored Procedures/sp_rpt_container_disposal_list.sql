CREATE PROCEDURE sp_rpt_container_disposal_list
	@company_id			int
,	@profit_ctr_id		int
,	@date_from			datetime
,	@date_to			datetime
,	@customer_id_from	int
,	@customer_id_to		int
,	@location			varchar(15)
AS
/************************************************************************/
/* This stored procedure is used for the "Drum Disposal List"		*/
/* by the datawindow d_rpt_drum_disposal_list				*/
/************************************************************************/
/* FILENAME:  sp_rpt_container_disposal_list.sql					*/
/*									*/
/* 04-10-00 JDB Created sp to list disposed drums within a date range.	*/
/* 09/28/00 LJT Changed = NULL to is NULL and <> null to is not null    */
-- 09/19/02 SCC Changed for receipt project, new Drum tables
/* 10/14/02 LJT Modified to look at receipts with a status of L, U ,A   */
/*              and to join on original ticket id to receipt            */
/* 11/11/04 MK  Changed generator_code to generator_id                */
/* 12/11/04 SCC Modified for Container Tracking                         */
/* 09/17/10 SK	Modified to take company_id as input argument           
				Modified to use Profile, ProfileQuoteApproval & ProfileLab
				tables instead of view Approval in Plt_XX_AI. 
				Moved and loaded the sp into Plt_AI           */
/************************************************************************/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

/* sp_rpt_container_disposal_list 14, 12, '2006-06-01', '2006-06-30', 1, 999999, 'SA-CONVT'	*/

SELECT	
	ContainerDestination.receipt_id
,	ContainerDestination.line_id
,	ContainerDestination.company_id
,	ContainerDestination.profit_ctr_id
,	ContainerDestination.container_type
,	ContainerDestination.disposal_date
,	Generator.generator_name
,	ProfileQuoteApproval.approval_code
,	Receipt.bill_unit_code
,	count(ContainerDestination.sequence_id) AS container_count
,	ProfileLab.TCE
,	ProfileLab.MC
,	Container.staging_row
,	Company.company_name
,	ProfitCenter.profit_ctr_name
FROM Receipt
JOIN Profile
	ON Profile.profile_id = Receipt.profile_id
	AND Profile.curr_status_code = 'A'
JOIN ProfileQuoteApproval
	ON ProfileQuoteApproval.profile_id = Receipt.profile_id
	AND ProfileQuoteApproval.company_id = Receipt.company_id
	AND ProfileQuoteApproval.profit_ctr_id = Receipt.profit_ctr_id
JOIN ProfileLab
	ON ProfileLab.profile_id = Receipt.profile_id
	AND ProfileLab.type = 'A'
JOIN Generator
	ON Generator.generator_id = Receipt.generator_id
JOIN ContainerDestination
	ON ContainerDestination.receipt_id = Receipt.receipt_id
	AND ContainerDestination.company_id = Receipt.company_id
	AND ContainerDestination.profit_ctr_id = Receipt.profit_ctr_id
	AND ContainerDestination.line_id = Receipt.line_id
	AND ContainerDestination.container_type = 'R'
	AND ContainerDestination.disposal_date IS NOT NULL
	AND ContainerDestination.disposal_date between @date_from and @date_to
	AND (@location = 'ALL' OR ContainerDestination.location = @location)
JOIN Container
	ON Container.receipt_id = ContainerDestination.receipt_id
	AND Container.company_id = ContainerDestination.company_id
	AND Container.profit_ctr_id = ContainerDestination.profit_ctr_id
	AND Container.line_id = ContainerDestination.line_id
	AND Container.container_type = ContainerDestination.container_type
JOIN Company
	ON Company.company_id = Receipt.company_id
JOIN ProfitCenter
	ON ProfitCenter.company_ID = Receipt.company_id
	AND ProfitCenter.profit_ctr_ID = Receipt.profit_ctr_id
WHERE Receipt.receipt_status in ('L','U','A')
	AND (@company_id = 0 OR Receipt.company_id = @company_id )
	AND (@company_id = 0 OR @profit_ctr_id = -1 OR Receipt.profit_ctr_id = @profit_ctr_id)
	AND Receipt.bulk_flag = 'F'
	AND Receipt.receipt_date > '7-31-99'
	AND Receipt.customer_id between @customer_id_from and @customer_id_to
GROUP BY 
	ContainerDestination.receipt_id
,	ContainerDestination.line_id
,	ContainerDestination.company_id
,	ContainerDestination.profit_ctr_id
,	ContainerDestination.container_type
,	ContainerDestination.disposal_date
,	Generator.generator_name
,	ProfileQuoteApproval.approval_code
,	Receipt.bill_unit_code
,	ProfileLab.TCE
,	ProfileLab.MC
,	Container.staging_row
,	Company.company_name
,	ProfitCenter.profit_ctr_name

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_container_disposal_list] TO [EQAI]
    AS [dbo];

