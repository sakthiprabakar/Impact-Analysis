CREATE PROCEDURE sp_canadian_haz_waste_report_validation
	@company_id		int
,	@profit_ctr_id	int
,	@start_date		datetime
,	@end_date		datetime
AS
/**************************************************************************************

Filename:	L:\Apps\SQL\EQAI\sp_canadian_haz_waste_report_validation.sql
PB Object(s):	r_canadian_haz_waste_outbound_validation

06/1/2017 AM	Created

sp_canadian_haz_waste_report_validation 21, 0, '02/25/2017', '02/28/2017'
**************************************************************************************/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

CREATE TABLE #output (
	company_id				int				NULL,
	profit_ctr_id			int				NULL,
	receipt_id				int				NULL,
	line_id					INT				NULL,
    receipt_status          varchar(1)		NULL,
	receipt_date			datetime		NULL,
	tsdf_code				varchar(15)		NULL,
	tsdf_name				varchar(40)		NULL,
	tsdf_country_code		varchar(3)		NULL,
	waste_list_code			varchar(15)		NULL,
	company_name			varchar(35)		NULL,
	profit_ctr_name			varchar(50)		Null,
)

INSERT #output 
select r.company_id, 
       r.profit_ctr_id, 
       r.receipt_id, 
       r.line_id, 
       r.receipt_status, 
       r.receipt_date, 
       t.tsdf_code, 
       t.tsdf_name, 
       t.tsdf_country_code,
       r.waste_list_code,
       c.company_name,
	   p.profit_ctr_name
from receipt r
JOIN Company c
	ON c.company_id = r.company_id
JOIN ProfitCenter p
	ON p.company_ID = r.company_id
	AND p.profit_ctr_ID = r.profit_ctr_id
join tsdf t on r.tsdf_code = t.tsdf_code
WHERE r.receipt_date BETWEEN @start_date AND @end_date  
AND  (@company_id = 0 OR r.company_id = @company_id)	
AND  (@company_id = 0 OR @profit_ctr_id = -1 OR r.profit_ctr_id = @profit_ctr_id)
AND   r.trans_mode = 'O'  
AND   r.trans_type = 'D'
AND   r.receipt_status NOT IN ('V','R')  
AND   t.tsdf_country_code <> 'USA' 
AND   r.waste_list_code IS NULL
Order BY r.receipt_date, r.company_id, r.profit_ctr_id, r.receipt_id, r.line_id

SELECT * FROM #output	

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_canadian_haz_waste_report_validation] TO [EQAI]
    AS [dbo];

