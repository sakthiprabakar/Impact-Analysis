
create proc sp_rpt_approvals_used (
    @start_date    datetime,
    @end_date      datetime,
    @copc_list     varchar(max) = NULL, -- ex: 21|1,14|0,14|1)
    @user_code     varchar(100) = NULL, -- for associates
    @contact_id    int = NULL, -- for customers,
    @permission_id int,
    @debug         int = 0
) as 
/****************************************************************

sp_rpt_approvals_used
	Returns a list of the profiles/approvals used in a set of facilities, inside of a daterange.

	05/15/2012 JPB - Converted to EQIP report.
	02/05/2013 JPB - Added Receipt Constituent & Concentration info per GEM:22942
	08/11/2014 JPB - GEM-29446: Add Treat Group, Form, Source, Mgt Code
		

sp_rpt_approvals_used '1/1/2012', '12/31/2012', '29|0', 'JONATHAN', NULL, 79

select convert(varchar(2), company_id) + '|' + convert(varchar(2), profit_ctr_id) from profitcenter where status = 'A'

****************************************************************/

if DATEPART(hh, @end_date) = 0 set @end_date = @end_date + 0.99999

if @contact_id = -1 set @contact_id = null

declare @tbl_profit_center_filter table (
    [company_id] int,
    profit_ctr_id int
)
    
INSERT @tbl_profit_center_filter
	SELECT secured_copc.company_id, secured_copc.profit_ctr_id
		FROM SecuredProfitCenter secured_copc
		INNER JOIN (
			SELECT
				RTRIM(LTRIM(SUBSTRING(row, 1, CHARINDEX('|',row) - 1))) company_id,
				RTRIM(LTRIM(SUBSTRING(row, CHARINDEX('|',row) + 1, LEN(row) - (CHARINDEX('|',row)-1)))) profit_ctr_id
			from dbo.fn_SplitXsvText(',', 0, @copc_list)
			where isnull(row, '') <> '') selected_copc 
			ON secured_copc.company_id = selected_copc.company_id 
			AND secured_copc.profit_ctr_id = selected_copc.profit_ctr_id
			AND secured_copc.user_code = @user_code
			AND secured_copc.permission_id = @permission_id    
			
	SELECT DISTINCT customer_id, cust_name INTO #Secured_Customer
		FROM SecuredCustomer sc WHERE sc.user_code = @user_code
		and sc.permission_id = @permission_id						


Select distinct 
	receipt.company_id,
	receipt.profit_ctr_id,
	P.profile_id,
	receipt.approval_code,
	P.approval_desc,
	p.epa_form_code,
	p.epa_source_code,
	p.customer_id,
	c.cust_name,
	Generator.sic_code,
	receipt.treatment_id,
	treatment.management_code,
	-- receipt.ccvoc,
	-- receipt.ddvoc,
	treatment.wastetype_id,
	WasteType.description,
	treatment.treatment_process_id,
	treatment_process,
	treatment.disposal_service_id,
	DisposalService.disposal_service_desc 
	, cons.const_desc
	, cons.const_id
	, rc.concentration
	, rc.unit
from receipt 
INNER JOIN @tbl_profit_center_filter secured_copc 
	ON receipt.company_id = secured_copc.company_id
    AND receipt.profit_ctr_id = secured_copc.profit_ctr_id
INNER JOIN #Secured_Customer secured_customer  
	ON (secured_customer.customer_id = receipt.customer_id)    
INNER JOIN Profile P (nolock) 
	on receipt.profile_id = P.profile_id
INNER JOIN Generator (nolock) 
	on receipt.generator_id = generator.generator_id
INNER JOIN Treatment (nolock) 
	on receipt.treatment_id = treatment.treatment_id
INNER JOIN WasteType (nolock) 
	on treatment.wastetype_id = wastetype.wastetype_id
INNER JOIN TreatmentProcess	(nolock) 
	on TreatmentProcess.treatment_process_id = Treatment.treatment_process_id
INNER JOIN DisposalService (nolock) 
	on DisposalService.disposal_service_id = Treatment.disposal_service_id
INNER JOIN Customer c (nolock) 
	on receipt.customer_id = c.customer_id
INNER JOIN REceiptConstituent rc (nolock) 
	on receipt.receipt_id = rc.receipt_id
	and receipt.line_id = rc.line_id
	and receipt.company_id = rc.company_id
	and receipt.profit_ctr_id = rc.profit_ctr_id
INNER JOIN Constituents cons (nolock) 
	on rc.const_id = cons.const_id
Where 
	receipt_status = 'A' 
	AND fingerpr_status = 'A'
	AND receipt.receipt_date between @start_date AND @end_date
Order By P.profile_id



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_approvals_used] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_approvals_used] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_approvals_used] TO [EQAI]
    AS [dbo];

