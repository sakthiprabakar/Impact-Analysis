
create proc sp_reports_GE_generator_onboarding_detail__action_register_i (
	@generator_id		int
	, @status_list		varchar(max) = 'all'
)
as
/* ****************************************************************************
sp_reports_GE_generator_onboarding_detail__action_register_i

Shell for calling sp_reports_GE_generator_onboarding_detail with varying arguments
This is because SSRS won't let me have multiple different recordsets in multiple different
calls of the same stored procedure: that is to say, it is stupid.

sp_reports_GE_generator_onboarding_detail__action_register_i 169151
**************************************************************************** */

set @status_list = replace(@status_list, '|', ',')
create table #status (status	char(1))
insert #status select row from dbo.fn_SplitXsvText(',',1,@status_list) WHERE row is not null
union select distinct status from ActionRegister where @status_list = 'all'

	--Action Register:  Improvement
	SELECT --ar.action_register_id AS 'action_register_id',
		ar.date_added AS 'date_added',
	--                ar.generator_id AS 'generator_id',
		art.action_type AS 'action_type',
		CASE ar.improvement_type WHEN 'C' THEN 'Continuous' WHEN 'P' THEN 'Process' END AS 'improvement_type',
		CASE ar.improvement_acceptance_status WHEN 'P' THEN 'Proposed' WHEN 'R' THEN 'Rejected' WHEN 'D' THEN 'Denied' WHEN 'A' THEN 'Approved' WHEN 'C' THEN 'Cancelled' WHEN 'W' THEN 'Waiting' WHEN 'O' THEN 'On Hold' END AS 'acceptance_status',
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
		ar.improvement_date_raised AS 'improvement_date_raised',
		ar.improvement_target_completion_date AS 'target_completion_date',
		ar.improvement_date_implemented AS 'date_implemented',
		cic.ci_category AS 'CI_category',
		ar.improvement_estimated_annual_financial_impact AS 'estimated_annual_financial_impact',
		ar.improvement_percentage AS 'improvement_percentage',
		ar.improvement_reason_for_denial AS 'reason_for_denial',
		ar.improvement_estimated_waste_volume_impacted AS 'estimated_waste_volume_impacted',
		ar.improvement_estimated_waste_volume_unit AS 'estimated_waste_volume_unit'
	--                (SELECT STUFF(REPLACE((SELECT DISTINCT '#!' + LTRIM(RTRIM(u3.user_name)) AS 'data()' FROM Users u3 JOIN ActionRegisterContact arc ON arc.user_code = u3.user_code WHERE arc.action_register_id = ar.action_register_id FOR XML PATH('')),' #!',', '), 1, 2, '')) as 'USE_contacts'
	FROM ActionRegister ar
	JOIN ActionRegisterType art
		ON art.action_type_id = ar.action_type_id
	LEFT OUTER JOIN Users u
		ON u.user_code = ar.voided_by
	LEFT OUTER JOIN Users u2
		ON u2.user_code = ar.escalated_to_whom
	LEFT OUTER JOIN ActionRegisterCICategory cic
		ON cic.ci_category_id = ar.improvement_CI_category_id
	WHERE art.action_type = 'Improvement'
	and ar.view_on_web = 'T'
	and ar.status <> 'v'
	AND ar.generator_id = @generator_id
	and ar.status in (select status from #status)
	ORDER BY ar.date_added desc

 

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_reports_GE_generator_onboarding_detail__action_register_i] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_reports_GE_generator_onboarding_detail__action_register_i] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_reports_GE_generator_onboarding_detail__action_register_i] TO [EQAI]
    AS [dbo];

