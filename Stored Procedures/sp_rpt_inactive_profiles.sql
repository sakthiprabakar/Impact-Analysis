DROP PROCEDURE IF EXISTS dbo.sp_rpt_inactive_profiles 
GO

CREATE PROCEDURE dbo.sp_rpt_inactive_profiles 
	@expired_date_from	datetime
,	@expired_date_to	datetime
,	@customer_id_from	int
,	@customer_id_to		int
,	@generator_id_from	int
,	@generator_id_to	int

AS
/***********************************************************************************
Modifications:
04/29/2021 MPM	DevOps 19944 - Created
05/13/2021 MPM	DevOps 20750 - Modified to identify inactive profiles by 
				Profile.inactive_flag = 'T'.
05/20/2021 MPM	DevOps 19944/20750 - Modified to return only active approvals.
02/04/2022 MPM	DevOps 21146 - Changed the approval range input parameters to generator ID range.
07/26/2022 GDE  DevOps 21149 - PROD EQAI - Report Center - Inactive Profiles - Edits to Report Columns

EXEC dbo.sp_rpt_inactive_profiles '1/1/2021', '4/29/2021', 1, 999999, '0', 'ZZ' 
EXEC dbo.sp_rpt_inactive_profiles NULL, NULL, NULL, NULL, NULL, NULL
***********************************************************************************/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

IF @expired_date_from = '' SET @expired_date_from = NULL
IF @expired_date_to = '' SET @expired_date_to = NULL
IF @customer_id_from = '' SET @customer_id_from = NULL
IF @customer_id_to = '' SET @customer_id_to = NULL
IF @generator_id_from = '' SET @generator_id_from = NULL
IF @generator_id_to = '' SET @generator_id_to = NULL

SELECT 
	p.profile_id
,	p.approval_desc
,	p.ap_start_date
,	p.ap_expiration_date
,	p.expired_not_received_date
,	p.customer_id
,	c.cust_name
,	p.generator_id
, 	g.generator_name
,	pqa.company_id
,	pqa.profit_ctr_id
,	pqa.approval_code
FROM Profile p
JOIN ProfileQuoteApproval pqa
	ON p.profile_id = pqa.profile_id
	AND p.curr_status_code = 'A'
	AND pqa.status = 'A'
JOIN Customer c
	ON c.customer_ID = p.customer_id
JOIN Generator g
	ON p.generator_id = g.generator_id
WHERE p.inactive_flag = 'T'
	AND ((p.expired_not_received_date BETWEEN @expired_date_from AND @expired_date_to) OR (@expired_date_from IS NULL AND @expired_date_to IS NULL))
	AND ((p.customer_id BETWEEN @customer_id_from AND @customer_id_to) OR (@customer_id_from IS NULL AND @customer_id_to IS NULL))
	AND ((p.generator_id BETWEEN @generator_id_from AND @generator_id_to) OR (@generator_id_from IS NULL AND @generator_id_to IS NULL))
ORDER BY pqa.profile_id, pqa.company_id, pqa.profit_ctr_id, pqa.approval_code
GO

GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_inactive_profiles] TO [EQAI]
    AS [dbo];
