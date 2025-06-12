
create proc sp_reports_GE_action_register (
	@generator_id		int
	, @status_list		varchar(max) = 'all'
	, @report_type_list	varchar(max) = 'all'
)
as
/* ****************************************************************************
sp_reports_GE_action_register

sp_reports_GE_action_register 169151
**************************************************************************** */

set @status_list = replace(@status_list, '|', ',')
create table #status (status	char(1))
insert #status select row from dbo.fn_SplitXsvText(',',1,@status_list) WHERE row is not null
union select distinct status from ActionRegister where @status_list = 'all'
/*
create table #ReportType (status	char(1))
insert #ReportType select row from dbo.fn_SplitXsvText(',',1,@status_list) WHERE row is not null
union select distinct status from ActionRegister where @status_list = 'all'
*/


-- Action Register: Supplier Corrective Action Report
	SELECT 
		ar.date_added AS 'Date_Added',
		art.action_type AS 'Action_Type',
		art.action_type_abbr + isnull('-' + arit.incident_type_abbr, '') action_type_abbr,
		'Action SubType' = case art.action_type
			when 'Incident' then arit.incident_type
			when 'Improvement' then CASE ar.improvement_type WHEN 'C' THEN 'Continuous' WHEN 'P' THEN 'Process' END
			else null
		end,
		ar.subject AS 'Subject',
		CASE ar.status WHEN 'O' THEN 'Open' WHEN 'C' THEN 'Closed' WHEN 'A' THEN 'Active' WHEN 'V' THEN 'Void' END AS 'Status',
		CASE ar.priority WHEN 'H' THEN 'High' WHEN 'L' THEN 'Low' WHEN 'R' THEN 'Regular' WHEN 'N' THEN 'N/A' END AS 'Priority',
		ar.description AS 'Description',
		ar.notes AS 'Notes',
		ar.site_contacts AS 'Site_Contacts',
		CASE ar.escalated_flag WHEN 'T' THEN 'Yes' WHEN 'F' THEN 'No' END AS 'Escalated',
		u2.user_name AS 'Escalated_To',
		ar.date_escalated AS 'Date_Escalated',
		ar.tracking_ID AS 'Tracking_ID',
		Item_Date_Category = case art.action_type
			when 'Supplier Corrective Action Report' then STUFF(REPLACE('/' + convert(nvarchar(10), ar.scar_actual_completion_date, 101),'/0','/'),1,1,'')
			when 'Lesson Learned' then STUFF(REPLACE('/' + convert(nvarchar(10), ar.incident_start_date, 101),'/0','/'),1,1,'')
			when 'USE Nonconformance' then STUFF(REPLACE('/' + convert(nvarchar(10), ar.nonconformance_end_date, 101),'/0','/'),1,1,'')
			when 'Incident' then STUFF(REPLACE('/' + convert(nvarchar(10), ar.incident_resolution_date, 101),'/0','/'),1,1,'')
			when 'Improvement' then cic.ci_category
		end
		, VN_RC_R_AT_ST = case art.action_type -- Vendor Name/Root Cause/Resolution/Acceptance Status/Site Type
			when 'Supplier Corrective Action Report' then ar.scar_vendor_name
			when 'Lesson Learned' then g.site_type
			when 'USE Nonconformance' then ar.nonconformance_root_cause
			when 'Incident' then ar.incident_resolution
			when 'Improvement' then CASE ar.improvement_acceptance_status WHEN 'P' THEN 'Proposed' WHEN 'R' THEN 'Rejected' WHEN 'D' THEN 'Denied' WHEN 'A' THEN 'Approved' WHEN 'C' THEN 'Cancelled' WHEN 'W' THEN 'Waiting' WHEN 'O' THEN 'On Hold' END
		end
	FROM ActionRegister ar
	JOIN ActionRegisterType art
		ON art.action_type_id = ar.action_type_id
	LEFT OUTER JOIN Generator g
		on ar.generator_id = g.generator_id
	LEFT OUTER JOIN Users u
		ON u.user_code = ar.voided_by
	LEFT OUTER JOIN Users u2
		ON u2.user_code = ar.escalated_to_whom
	LEFT OUTER JOIN ActionRegisterIncidentType arit
		ON art.action_type = 'Incident'
		AND arit.incident_type_id = ar.incident_type_id
	LEFT OUTER JOIN ActionRegisterCICategory cic
		ON cic.ci_category_id = ar.improvement_CI_category_id
		
	WHERE
	art.action_type in (
	'Supplier Corrective Action Report',
	'USE Nonconformance',
	'Incident',
	'Improvement',
	'Lesson Learned'
	)
	and ar.view_on_web = 'T'
	and ar.status <> 'v'
	AND ar.generator_id = @generator_id
	and ar.status in (select status from #status)


	ORDER BY case art.action_type
	when 'Supplier Corrective Action Report' then 10
	when 'USE Nonconformance' then 20
	when 'Incident' then 30
	when 'Improvement' then 40
	when 'Lesson Learned' then 50
	end
	, ar.date_added desc
 

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_reports_GE_action_register] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_reports_GE_action_register] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_reports_GE_action_register] TO [EQAI]
    AS [dbo];

