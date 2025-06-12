CREATE PROCEDURE sp_rpt_generic_module_summary 
	@company_id			int
,	@profit_ctr_id		int
,	@date_from			datetime
,	@date_to			datetime
AS
/***********************************************************************************
This report lists specific information on all the new approvals granted 
in the specified date range. 

Load to PLT_AI
PB Object(s):		r_generic_module_summary				

08/24/2011 SK	Created, never deployed to production.
05/24/2012 DZ	Modified to use the Scan table for the date submitted.
06/20/2012 DZ	Modified to use profile's volume and unit
12/31/2012 JDB	Fixed incorrect shipping frequency field names from Profile table.
				The 6/20/12 version was never actually deployed to production with
				the Forms 2012 project because it didn't have the right field names.

sp_rpt_generic_module_summary 27, 0, '12/10/2012', '12/13/2012'
***********************************************************************************/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

;WITH T AS ( 
SELECT pqa.approval_code
,	pqa.company_id
,	pqa.profit_ctr_id
,	p.profile_id
,   p.generator_id
,	s.date_added
,	f.volume AS form_volume
,	f.frequency AS form_frequency
--,	f.frequency_other
,	'' AS form_frequency_other
,	NULLIF(dbo.fn_profile_shipping_unit( p.profile_id ), '') AS profile_volume
,	p.shipping_volume_unit_other
,	p.shipping_frequency AS profile_frequency
,	p.shipping_frequency_other AS profile_frequency_other
,   R.receipt_id
,   p.customer_id
,   R.receipt_date
,	ROW_NUMBER() OVER ( PARTITION BY pqa.approval_code ORDER BY R.receipt_date ASC, f.revision_id DESC) AS 'RowNumber'
  FROM ProfileQuoteApproval pqa
JOIN Profile p
	ON p.profile_id = pqa.profile_id
	AND p.curr_status_code NOT IN ('R', 'V')
JOIN Plt_Image..Scan s
	ON s.profile_id = pqa.profile_id
	AND s.type_id = 58
	AND s.status = 'A'
	AND s.date_added BETWEEN @date_from and @date_to
	AND NOT EXISTS (SELECT 1 
	                 FROM Plt_Image..Scan s2 
					WHERE s2.profile_id = s.profile_id 
					  AND s2.type_id = 58
					  AND s2.status = 'A'
					  AND s2.date_added > s.date_added) 
LEFT OUTER JOIN Receipt R
	ON R.approval_code = pqa.approval_code
	AND R.company_id = pqa.company_id
	AND R.profit_ctr_id = pqa.profit_ctr_id
	AND R.receipt_status NOT IN ('V', 'T')
LEFT OUTER JOIN FormWCR f
	ON f.profile_id = pqa.profile_id
	AND f.form_id = p.form_id_wcr
WHERE pqa.company_id = @company_id
	AND pqa.profit_ctr_id = @profit_ctr_id
)
SELECT --DISTINCT
	T.generator_id
,	g.EPA_ID
,	CASE T.generator_id 
	  WHEN 0 THEN CONVERT(varchar(15), T.customer_id) + ' - ' + c.cust_name
	  ELSE g.EPA_ID + ' - ' + g.generator_name +' (' + CONVERT(varchar(15), T.generator_id) + ')'
	END AS generator_name
,	T.approval_code
,   ISNULL( T.profile_volume, T.shipping_volume_unit_other) AS volume
,	CASE ISNULL(T.profile_frequency, '')
		WHEN 1 THEN 'One Time Only'
		WHEN 7 THEN 'Week'
		WHEN 30 THEN 'Month'
		WHEN 91 THEN 'Quarter'
		WHEN 365 THEN 'Year'
		ELSE T.profile_frequency_other
	END AS frequency
,	wastecodelist = dbo.fn_profile_waste_code_list(T.profile_id, 'P')
,	T.receipt_date AS min_receipt_date
,	T.date_added AS submitted_date
,	T.company_id
,	T.profit_ctr_id
,	Company.company_name
,	ProfitCenter.profit_ctr_name
FROM T
JOIN Company
	ON Company.company_id = T.company_id
JOIN ProfitCenter
	ON ProfitCenter.company_ID = T.company_id
	AND ProfitCenter.profit_ctr_ID = T.profit_ctr_id
JOIN Generator g
	ON g.generator_id = T.generator_id
JOIN Customer C
	ON C.customer_ID = T.customer_id
 WHERE T.RowNumber = 1

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_generic_module_summary] TO [EQAI]
    AS [dbo];

