CREATE PROCEDURE sp_reports_tons_disposed (
	@start_date datetime
	, @end_date datetime
	, @report_type char(1) ='S' -- 'S'ummary or 'D'etail
)
AS
/* *******************************************************************
sp_reports_tons_disposed

Returns summary and Detail data sets about the quantities of waste disposed between two receipt dates

History:
	2015-11-17	JPB	Created
	
Sample:
	exec sp_reports_tons_disposed 
		@start_date  = '1/1/2015'
		, @end_date  = '1/15/2015'

******************************************************************* */

SET ANSI_WARNINGS OFF
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

if datepart(hh, @end_date) = 0
	set @end_date = @end_date + 0.99999


-- Detail:
select 
cds.company_id, cds.profit_ctr_id
, cds.receipt_id, cds.line_id, cds.container_id
, cds.pounds
, r.receipt_date
, cds.final_disposal_date
from receipt r
inner join containerdisposalstatus cds
	on r.receipt_id = cds.receipt_id
	and r.line_id = cds.line_id
	and r.company_id = cds.company_id
	and r.profit_ctr_id = cds. profit_ctr_id
left join profitcenter pc on cds.company_id = pc.company_id and cds.profit_ctr_id = pc.profit_ctr_id
where final_disposal_date between @start_date and @end_date
and final_disposal_status = 'C'
and container_type = 'R'
group by
cds.company_id, cds.profit_ctr_id
, cds.receipt_id, cds.line_id, cds.container_id
, cds.pounds
, r.receipt_date
, cds.final_disposal_date
order by
cds.company_id, cds.profit_ctr_id
, cds.receipt_id, cds.line_id, cds.container_id
, cds.pounds
, r.receipt_date
, cds.final_disposal_date
-- compute sum(cds.pounds)



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_reports_tons_disposed] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_reports_tons_disposed] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_reports_tons_disposed] TO [EQAI]
    AS [dbo];

