-- drop proc if exists sp_hub_approvals_by_week_month
go

create proc sp_hub_approvals_by_week_month (
	@start_date datetime = null
	, @end_date datetime = null
	, @user_code		varchar(20)
	, @permission_id	int
	, @debug_code			int = 0	
)
as
/* ****************************************************************************
sp_hub_approvals_by_week_month

Approvals Created by Week and Month
Generates a listing of approvals created by facility, week, month, year and creator.	

History:
09/01/2020	JPB	Created

Sample:

	sp_hub_approvals_by_week_month '1/1/2017', '8/31/2020', 'jonathan', 159

declare @start_date datetime = '1/1/2017', --Approval Creation Start Date
		@end_date datetime = '8/17/2020'  --Approval Creation End Date

**************************************************************************** */
	
IF datepart(hh, @end_date) = 0 set @end_date = @end_date + 0.99999

SELECT secured_copc.company_id
       ,secured_copc.profit_ctr_id
INTO   #Secured_COPC
FROM   SecuredProfitCenter secured_copc (nolock)
WHERE  secured_copc.permission_id = @permission_id
       AND secured_copc.user_code = @user_code 


select 
	pqa.company_id
	, pqa.profit_ctr_id
	, pc.profit_ctr_name
	, count(*) as 'count of approvals created'
	, datepart(week, pqa.date_added) as 'week added'
	, datepart(month, pqa.date_added) as 'month added'
	, datepart(year, pqa.date_added) as 'year added'
	, (select user_name from users where user_code = pqa.added_by) as 'created by'
from ProfileQuoteApproval pqa
join #secured_COPC copc
	on pqa.company_id = copc.company_id
	and pqa.profit_ctr_id = copc.profit_ctr_id
join Profile p on p.profile_id = pqa.profile_id
join ProfitCenter pc on pqa.company_id = pc.company_ID and pqa.profit_ctr_id = pc.profit_ctr_ID
--where pqa.date_added >= '1/1/2017' and pqa.date_added < '8/17/20'
where pqa.date_added >= @start_date and pqa.date_added < @end_date
and p.tracking_type not in ('v', 'r', 'c')
and p.curr_status_code not in ('v', 'r', 'c')
group by pqa.company_id, pqa.profit_ctr_id, pc.profit_ctr_name, 
			datepart(week, pqa.date_added),
			datepart(month, pqa.date_added),
			datepart(year, pqa.date_added), 
			pqa.added_by
order by pqa.company_id, pqa.profit_ctr_id, pc.profit_ctr_name, 
			datepart(week, pqa.date_added),
			datepart(month, pqa.date_added),
			datepart(year, pqa.date_added), 
			pqa.added_by

GO
GRANT EXECUTE
    ON OBJECT::[dbo].sp_hub_approvals_by_week_month TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].sp_hub_approvals_by_week_month TO [COR_USER]
    AS [dbo];

GO
GRANT EXECUTE
    ON OBJECT::[dbo].sp_hub_approvals_by_week_month TO [EQAI]
    AS [dbo];

