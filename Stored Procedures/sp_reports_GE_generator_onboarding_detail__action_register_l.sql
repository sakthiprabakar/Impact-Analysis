
create proc sp_reports_GE_generator_onboarding_detail__action_register_l (
	@generator_id		int
	, @status_list		varchar(max) = 'all'
)
as
/* ****************************************************************************
sp_reports_GE_generator_onboarding_detail__action_register_l

Shell for calling sp_reports_GE_generator_onboarding_detail with varying arguments
This is because SSRS won't let me have multiple different recordsets in multiple different
calls of the same stored procedure: that is to say, it is stupid.

sp_reports_GE_generator_onboarding_detail__action_register_l 169151, 'ALL'
**************************************************************************** */

set @status_list = replace(@status_list, '|', ',')
create table #status (status	char(1))
insert #status select row from dbo.fn_SplitXsvText(',',1,@status_list) WHERE row is not null
union select distinct status from ActionRegister where @status_list = 'all'

	--Action Register:  Lessons Learned
	SELECT --ar.action_register_id AS 'action_register_id',
		ar.date_added AS 'date_added',
	--                ar.generator_id AS 'generator_id',
		art.action_type AS 'action_type',
		ar.subject AS 'subject',
		CASE ar.status WHEN 'O' THEN 'Open' WHEN 'C' THEN 'Closed' WHEN 'A' THEN 'Active' WHEN 'V' THEN 'Void' END AS 'Status',
		CASE ar.priority WHEN 'H' THEN 'High' WHEN 'L' THEN 'Low' WHEN 'R' THEN 'Regular' WHEN 'N' THEN 'N/A' END AS 'Priority',
		ar.description AS 'description',
		ar.notes AS 'notes',
		ar.site_contacts AS 'site_contacts',
		--ar.void_reason AS 'void_reason',
		--u.user_name AS 'voided_by',
		--ar.date_voided AS 'date_voided',
		CASE ar.escalated_flag WHEN 'T' THEN 'Yes' WHEN 'F' THEN 'No' END AS 'escalated',
		u2.user_name AS 'escalated_to',
		ar.date_escalated AS 'date_escalated',
		ar.tracking_ID AS 'tracking_id',
	--                CASE ar.view_on_web WHEN 'T' THEN 'Yes' WHEN 'F' THEN 'No' END AS 'view_on_web',
		ar.incident_start_date AS 'start_date'
	--	ar.incident_resolution_date AS 'resolution_date',
	--	ar.incident_resolution AS 'resolution'
	--                ar.incident_estimated_financial_impact AS 'incident_estimated_financial_impact',
	--                CASE ar.incident_source WHEN 'A' THEN 'Audit' WHEN 'I' THEN 'Incident' END AS 'incident_source',
	--                (SELECT STUFF(REPLACE((SELECT DISTINCT '#!' + LTRIM(RTRIM(u3.user_name)) AS 'data()' FROM Users u3 JOIN ActionRegisterContact arc ON arc.user_code = u3.user_code WHERE arc.action_register_id = ar.action_register_id FOR XML PATH('')),' #!',', '), 1, 2, '')) as 'USE_contacts'
	FROM ActionRegister ar
	JOIN ActionRegisterType art
		ON art.action_type_id = ar.action_type_id
	--LEFT OUTER JOIN Users u
	--	ON u.user_code = ar.voided_by
	LEFT OUTER JOIN Users u2
		ON u2.user_code = ar.escalated_to_whom
	WHERE art.action_type = 'Lesson Learned'
	and ar.view_on_web = 'T'
	and ar.status <> 'v'
	AND ar.generator_id = @generator_id
	and ar.status in (select status from #status)
	ORDER BY ar.date_added desc  
 

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_reports_GE_generator_onboarding_detail__action_register_l] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_reports_GE_generator_onboarding_detail__action_register_l] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_reports_GE_generator_onboarding_detail__action_register_l] TO [EQAI]
    AS [dbo];

