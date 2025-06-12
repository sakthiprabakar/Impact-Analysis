-- drop proc sp_rpt_lib_approvals_used

go

CREATE PROC sp_rpt_lib_approvals_used (
	@copc_list		varchar(max),
	@start_date		datetime,
	@end_date		datetime,
	@user_code		varchar(10),
	@permission_id	int
) AS
/* ****************************************************************************
sp_rpt_lib_approvals_used

Depends on sp_lib_waste_code_list

Report output for LIB Worksheet as requested in GEM:36752

Lists approval numbers that had receipts created within the designated time period that had one of the LIB EQAI waste codes selected.




History:

03/31/2016 JPB	Created - GEM:36752

Sample:
	sp_rpt_lib_approvals_used
		@copc_list		= '21|0',
		@start_date		= '1/1/2019',
		@end_date		= '12/31/2019',
		@user_code		= 'JONATHAN',
		@permission_id	= 289


was
company_id	profit_ctr_id	profit_ctr_name		profile_id	approval_code	display_name	waste_code_desc						treatment_id	treatment_process_process	disposal_service_desc	conv_gallons_quantity
21			0				EQ Detroit, Inc.	492216		171541T-0DET	021L, 029L		021L: Other Oil, 029L: Other Wastes	1218			Solidification				Subtitle D Landfill		2750
		
**************************************************************************** */

SET NOCOUNT ON
-- SET ANSI_WARNINGS OFF
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

/*
-- debuggery:
drop table #base;drop table #lib_wastecode; drop table #tbl_profit_center_filter
declare 
	@copc_list		varchar(max)= '21|0',
	@start_date		datetime= '1/1/2019',
	@end_date		datetime= '12/31/2019',
	@user_code		varchar(10)= 'JONATHAN',
	@permission_id	int= 289
*/

-- Get the list of LIB Waste Codes...
	Create table #lib_wastecode (waste_code_uid int)
	exec sp_lib_waste_code_list

-- Handle Inputs
	create table #tbl_profit_center_filter  (
		[company_id] int, 
		profit_ctr_id int
	)	

	if @copc_list <> 'All'
	begin
	INSERT #tbl_profit_center_filter 
	SELECT secured_copc.company_id, secured_copc.profit_ctr_id 
		FROM 
			SecuredProfitCenter secured_copc (nolock)
		INNER JOIN (
			SELECT 
				RTRIM(LTRIM(SUBSTRING(row, 1, CHARINDEX('|',row) - 1))) company_id,
				RTRIM(LTRIM(SUBSTRING(row, CHARINDEX('|',row) + 1, LEN(row) - (CHARINDEX('|',row)-1)))) profit_ctr_id
			from dbo.fn_SplitXsvText(',', 0, @copc_list) 
			where isnull(row, '') <> '') selected_copc ON secured_copc.company_id = selected_copc.company_id AND secured_copc.profit_ctr_id = selected_copc.profit_ctr_id
			and secured_copc.permission_id = @permission_id
			and secured_copc.user_code = @user_code
	end		
	else
	begin

		INSERT #tbl_profit_center_filter
		SELECT secured_copc.company_id
			   ,secured_copc.profit_ctr_id
		FROM   SecuredProfitCenter secured_copc (nolock)
		WHERE  secured_copc.permission_id = @permission_id
			   AND secured_copc.user_code = @user_code 

	end

	if datepart(hh, @end_date) = 0 set @end_date = @end_date + 0.999999

--SELECT  *  FROM    wastecode where waste_code_uid in (73, 75)


select r.company_id
	, r.profit_ctr_id
	, r.receipt_id
	, r.line_id
	, r.profile_id
	, r.approval_code
	, r.treatment_id
	, x.waste_code_uid
	, r.bill_unit_code
	, r.quantity
into #base
from receipt r
join
(
select distinct rwc.company_id, rwc.profit_ctr_id, rwc.receipt_id, rwc.line_id, lwc.waste_code_uid
from
#lib_wastecode lwc
join receiptwastecode rwc  
	on rwc.waste_code_uid = lwc.waste_code_uid
join #tbl_profit_center_filter f
	on rwc.company_id = f.company_id
	and rwc.profit_ctr_id = f.profit_ctr_id
join receipt r
	on r.receipt_id = rwc.receipt_id
	and r.line_id = rwc.line_id
	and r.company_id = rwc.company_id
	and r.profit_ctr_id = rwc.profit_ctr_id
	and r.receipt_date between @start_date and @end_date
	and r.trans_mode = 'I'
	and r.trans_type = 'D'
	and r.receipt_status = 'A'
	and r.fingerpr_status = 'A'
	and r.waste_accepted_flag = 'T'
)
x
	on r.receipt_id = x.receipt_id
	and r.line_id = x.line_id
	and r.company_id = x.company_id
	and r.profit_ctr_id = x.profit_ctr_id
	
/*

SELECT  *  FROM    #base

SELECT  company_id, profit_ctr_id, receipt_id, line_id
FROM     #base
GROUP BY company_id, profit_ctr_id, receipt_id, line_id
having count(*) > 1

SELECT  *  FROM    #base WHERE receipt_id = 2057765 and line_id = 5
*/

select distinct
	company_id
	, profit_ctr_id
	, receipt_id
	, line_id
	, approval_code
	, profile_id
	, treatment_id
	, bill_unit_code
	, quantity
into #base_receipts
from #base


select distinct
	b.company_id
	, b.profit_ctr_id
	, pc.profit_ctr_name
--	, r.receipt_id
--	, r.line_id
	, b.profile_id	
	, b.approval_code
	-- , b.waste_code_uid
	-- , wc.display_name
	, display_name = isnull(( select substring(
		(
			select distinct ', ' + wc.display_name
			FROM #base c
			join wastecode wc on c.waste_code_uid = wc.waste_code_uid
			where c.company_id = b.company_id
			and c.profit_ctr_id = b.profit_ctr_id
			and c.profile_id = b.profile_id
			--order by wc.display_name
			for xml path, TYPE).value('.[1]','nvarchar(max)'
		),2,20000)	) , '')
	
	, waste_code_desc = isnull(( select substring(
		(
			select distinct ', ' + wc.display_name + ': ' + wc.waste_code_desc
			FROM #base c
			join wastecode wc on c.waste_code_uid = wc.waste_code_uid
			where c.company_id = b.company_id
			and c.profit_ctr_id = b.profit_ctr_id
			and c.profile_id = b.profile_id
			--order by wc.display_name
			for xml path, TYPE).value('.[1]','nvarchar(max)'
		),2,20000)	) , '')
	
	-- , wc.waste_code_desc
	, b.treatment_id
	, t.treatment_process_process
	, t.disposal_service_desc
--	, count(rwc.waste_code_uid) number_of_occurrences
--	, r.bill_unit_code
--	, r.quantity
--	, bu.gal_conv as conversion_to_gallons_factor
	, SUM((b.quantity * bu.gal_conv)) as conv_gallons_quantity
from #base_receipts b
join profitcenter pc
	on b.company_id = pc.company_id
	and b.profit_ctr_id = pc.profit_ctr_id
join billunit bu
	on b.bill_unit_code = bu.bill_unit_code
join treatment t
	on b.treatment_id = t.treatment_id
	and b.company_id = t.company_id
	and b.profit_ctr_id = t.profit_ctr_id
group by
	b.company_id
	, b.profit_ctr_id
	, pc.profit_ctr_name
--	, r.receipt_id
--	, r.line_id
	, b.profile_id	
	, b.approval_code
	--, b.waste_code_uid
	--, wc.display_name
	--, wc.waste_code_desc
	, b.treatment_id
	, t.treatment_process_process
	, t.disposal_service_desc
--	, count(rwc.waste_code_uid) number_of_occurrences
--	, r.bill_unit_code
--	, r.quantity
--	, bu.gal_conv as conversion_to_gallons_factor
order by 
	b.company_id
	, b.profit_ctr_id
	, b.approval_code
	--, wc.waste_code_desc


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_lib_approvals_used] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_lib_approvals_used] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_lib_approvals_used] TO [EQAI]
    AS [dbo];

