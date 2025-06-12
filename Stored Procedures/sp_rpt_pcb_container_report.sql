--drop proc sp_rpt_pcb_container_report
--go

create proc sp_rpt_pcb_container_report (
	@copc_list		varchar(max),
	@start_date		datetime,
	@end_date		datetime,
    @user_code		varchar(100) = NULL, -- for associates
    @contact_id		int = NULL, -- for customers,
    @permission_id	int
)
as
/* ****************************************************************************
sp_rpt_pcb_container_report

Gather the PCB containers and report on the dates involved.

History:
	12/30/2015	PRK	Per Gemini 34178 http://support.usecology.com/workspace/0/item/34178
	01/05/2016	JPB	Converted to sp_rpt_pcb_container_report
	10/28/2019	MPM	DevOps 12600 - Updates for PCB container management.

Sample:

sp_rpt_pcb_container_report
	@copc_list		= '3|0',
	@start_date		= '1/1/2015',
	@end_date		= '1/1/2020',
	@user_code		= 'jonathan',
	@contact_id		= null,
	@permission_id	= 189
	

**************************************************************************** */

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

select 
	datediff(d, rp.storage_start_date, r.receipt_date) as [Number of Days Storage to Receipt Date],
	datediff(d, r.receipt_date, 
		CASE WHEN r.company_id = 2 AND r.profit_ctr_id = 0 
		THEN CASE WHEN b.batch_id IS NOT NULL 
			THEN b.date_closed 
			ELSE cd.disposal_date END 
		ELSE cd.disposal_date END) as [Number of Days Receipt to Disposal],
	datediff(d, rp.storage_start_date, 
		CASE WHEN r.company_id = 2 AND r.profit_ctr_id = 0 
		THEN CASE WHEN b.batch_id IS NOT NULL 
			THEN b.date_closed 
			ELSE cd.disposal_date END 
		ELSE cd.disposal_date END) as [Number of Days Storage to Disposal],
	rp.storage_start_date, r.receipt_date, 
	CASE WHEN r.company_id = 2 AND r.profit_ctr_id = 0 
		THEN CASE WHEN b.batch_id IS NOT NULL 
			THEN b.date_closed 
			ELSE cd.disposal_date END 
		ELSE cd.disposal_date END AS disposal_date,
	r.company_id, r.profit_ctr_id, r.receipt_id, r.line_id, rp.sequence_id,
	r.manifest, r.generator_id, r.load_generator_EPA_ID, g.generator_name,
	rp.waste_desc, rp.container_id, rp.weight, rp.weight_entered, rp.comments,
	t.transporter_code, t.transporter_name
into #results
from receiptpcb rp
join receipt r
	on r.company_id = rp.company_id
	and r.profit_ctr_id = rp.profit_ctr_id
	and r.receipt_id = rp.receipt_id
	and r.line_id = rp.line_id
INNER JOIN @tbl_profit_center_filter secured_copc 
	ON r.company_id = secured_copc.company_id
    AND r.profit_ctr_id = secured_copc.profit_ctr_id
INNER JOIN #Secured_Customer secured_customer  
	ON (secured_customer.customer_id = r.customer_id)    
join generator g
	on r.generator_id = g.generator_id
join container c
	on r.company_id = c.company_id
	and r.profit_ctr_id = c.profit_ctr_id
	and r.receipt_id = c.receipt_id
	and r.line_id = c.line_id
	and rp.sequence_id = c.container_id
	--and c.container_type = 'R'
join containerdestination cd
	on c.company_id = cd.company_id
	and c.profit_ctr_id = cd.profit_ctr_id
	and c.receipt_id = cd.receipt_id
	and c.line_id = cd.line_id
	and c.container_id = cd.container_id
join transporter t
	on r.hauler = t.transporter_code
LEFT OUTER JOIN  Batch b
	ON b.location = cd.location 
	AND b.tracking_num = cd.tracking_num 
	AND b.profit_ctr_id = cd.profit_ctr_id 
	AND b.company_id = cd.company_id 
where 
	r.receipt_date >= @start_date
	and r.receipt_date <= @end_date

select [Number of Days Storage to Receipt Date],
	[Number of Days Receipt to Disposal],
	[Number of Days Storage to Disposal],
	storage_start_date, receipt_date, disposal_date,
	company_id, profit_ctr_id, receipt_id, line_id, sequence_id,
	manifest, generator_id, load_generator_EPA_ID, generator_name,
	waste_desc, container_id, weight, weight_entered, comments,
	transporter_code, transporter_name
from #results
order by datediff(d, storage_start_date, disposal_date) desc


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_pcb_container_report] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_pcb_container_report] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_pcb_container_report] TO [EQAI]
    AS [dbo];

