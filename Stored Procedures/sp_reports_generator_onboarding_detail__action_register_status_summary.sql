
create proc sp_reports_generator_onboarding_detail__action_register_status_summary (
	@generator_id		int
)
as
/* ****************************************************************************
sp_reports_generator_onboarding_detail__action_register_status_summary

Simple return of status info for action register for a specific generator

sp_reports_generator_onboarding_detail__action_register_status_summary 169151
**************************************************************************** */

-- declare @generator_id int = 169151

	SELECT 'Total # Open' as count_label, count(*) as count_value, 1 as _order
	FROM ActionRegister ar
	WHERE 1=1
	and ar.view_on_web = 'T'
	and ar.status not in ('C', 'V') -- closed, void
	AND ar.generator_id = @generator_id
	and ar.action_type_id in (3,4,5,6,7)
	union all
	SELECT 'Total # Escalated (All)' as count_label, count(*) as count_value, 2 as _order
	-- select *
	FROM ActionRegister ar
	WHERE 1=1
	and ar.view_on_web = 'T'
	and ar.escalated_flag = 'T'
	and ar.status not in ('V') -- closed, void
	AND ar.generator_id = @generator_id
	and ar.action_type_id in (3,4,5,6,7)
	union all
	SELECT 'Total # Escalated (Open)' as count_label, count(*) as count_value, 3 as _order
	-- select *
	FROM ActionRegister ar
	WHERE 1=1
	and ar.view_on_web = 'T'
	and ar.escalated_flag = 'T'
	and ar.status not in ('C', 'V') -- closed, void
	AND ar.generator_id = @generator_id
	and ar.action_type_id in (3,4,5,6,7)
	union all
	SELECT 'Total # Closed' as count_label, count(*) as count_value, 4 as _order
	-- select *
	FROM ActionRegister ar
	WHERE 1=1
	and ar.view_on_web = 'T'
	and ar.status in ('C') -- closed, void
	AND ar.generator_id = @generator_id
	and ar.action_type_id in (3,4,5,6,7)
 
	ORDER BY _order
	

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_reports_generator_onboarding_detail__action_register_status_summary] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_reports_generator_onboarding_detail__action_register_status_summary] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_reports_generator_onboarding_detail__action_register_status_summary] TO [EQAI]
    AS [dbo];

