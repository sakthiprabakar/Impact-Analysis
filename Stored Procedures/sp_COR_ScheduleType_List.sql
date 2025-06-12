-- drop proc sp_COR_ScheduleType_List
go

create proc sp_COR_ScheduleType_List (
	@web_userid varchar(100)
)
as
/* ****************************************************************
sp_COR_ScheduleType_List

List the Work Order Schedule Types available to a user

select * from WorkOrderScheduleType


sp_COR_ScheduleType_List 'customer.demo@usecology.com'
sp_COR_ScheduleType_List 'nyswyn100'
sp_COR_ScheduleType_List 'zachery.wright'

**************************************************************** */

declare @i_web_userid varchar(100) = @web_userid

declare @foo table (
		workorder_id	int NOT NULL,
		company_id	int NOT NULL,
		profit_ctr_id  int NOT NULL,
		start_date	datetime NULL,
		prices		bit NOT NULL
	)
	
	
SELECT
		t.schedule_type
FROM  WorkOrderScheduleType t
where exists (
	select 1 from
	ContactCORWorkorderHeaderBucket x (nolock) 
	join CORcontact c (nolock) on x.contact_id = c.contact_id and c.web_userid = @i_web_userid
	join WorkorderHeader w (nolock) 
		on w.workorder_id = x.workorder_id
		and w.company_id = x.company_id
		and w.profit_ctr_id = x.profit_ctr_id
	where w.workorderscheduletype_uid = t.workorderscheduletype_uid
)
	and t.status = 'A'
	union
	select 'Pending' schedule_type
	union
	select 'Scheduled' schedule_type
order by schedule_type

return 0

go

grant execute on sp_COR_ScheduleType_List to cor_user, eqweb, eqai
go
