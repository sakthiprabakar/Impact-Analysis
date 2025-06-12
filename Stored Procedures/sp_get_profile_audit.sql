CREATE PROCEDURE dbo.sp_get_profile_audit
	@profile_id 	int
AS
/*****************************************************************************
This stored procedure is used to retrieve the audit records for a profile.
The reason it needs to be a SP is that we can show the friendly values by
updating the #tmp table with values from the corresponding lookup tables
(instead of just showing the ID that changed.)

SQL Database:	Plt_AI
PB Object(s):	d_profile_audit

03-04-2008 JDB	Created
10-26-2017 AM Added profilesafetycode.
08/26/2019 MPM	Samanage 10937/DevOps 12342 - Changed the inner join between ProfileAudit and 
				ProfileAuditLookup to be an outer join so that all audited changes
				will display on the Profile window's Audit tab.
03/23/2020 MPM	DevOps 14555 - Modified so that empty strings in either the before_value or 
				after_value columns will display as "(blank)", duplicate rows are removed, and
				audit rows for 'added_by', 'date_added', 'modified_by' and 'date_modified' are 
				not displayed.
02/26/2021 MPM	DevOps 19139 - Removed profile_tracking_days and profile_tracking_bus_days from
				auditing.
01/30/2023 Venu Devops 60720 - Added user_name field to display the user full name in profile audit screen.
01/22/2024 Kamendra DevOps #42054 - Added 3 new columns (created_by, created_date, created_after_value) to fix
			DevOps #16737. Removed NOT IN 'created_by' where clause to populate these new columns and added this where
			clause in the final select.
sp_get_profile_audit 255555
exec sp_get_profile_audit 343474
exec sp_get_profile_audit 616742
*****************************************************************************/
SELECT DISTINCT ProfileAudit.profile_id,  
ISNULL(ProfileAuditLookup.column_name_display, ProfileAudit.column_name) AS column_name_display,
ProfileAudit.table_name,
ProfileAudit.column_name,
ProfileAudit.before_value,
ProfileAudit.after_value,
ProfileAudit.audit_reference,
ProfileAudit.modified_by,
ProfileAudit.date_modified,
dbo.fn_get_user_full_name(ProfileAudit.modified_by) as user_name,
PROFILEAUD.modified_by AS created_by,
PROFILEAUD.date_modified AS created_date,
PROFILEAUD.after_value AS created_after_value
INTO #tmp
FROM ProfileAudit
LEFT OUTER JOIN ProfileAuditLookup 
	ON ProfileAudit.table_name = ProfileAuditLookup.table_name
	AND ProfileAudit.column_name = ProfileAuditLookup.column_name
LEFT OUTER JOIN ProfileAudit PROFILEAUD ON ProfileAudit.profile_id = PROFILEAUD.profile_id
AND	 PROFILEAUD.column_name = 'created_by'
WHERE ProfileAudit.profile_id = @profile_id
AND ProfileAudit.column_name NOT IN ('added_by','modified_by','date_added','date_modified', 'profile_tracking_days', 'profile_tracking_bus_days')

---------------------------------------------------------------------------------------
-- Profile.wastetype_id
---------------------------------------------------------------------------------------
UPDATE #tmp SET before_value = WasteType.category + ISNULL(' - ' + WasteType.description, '') + '  Code:  ' + ISNULL(WasteType.code, '(blank)')
FROM #tmp
INNER JOIN WasteType ON #tmp.before_value = WasteType.wastetype_id
WHERE #tmp.table_name = 'Profile'
AND #tmp.column_name = 'wastetype_id'
AND ISNUMERIC(#tmp.before_value) = 1

UPDATE #tmp SET after_value = WasteType.category + ISNULL(' - ' + WasteType.description, '') + '  Code:  ' + ISNULL(WasteType.code, '(blank)')
FROM #tmp
INNER JOIN WasteType ON #tmp.after_value = WasteType.wastetype_id
WHERE #tmp.table_name = 'Profile'
AND #tmp.column_name = 'wastetype_id'
AND ISNUMERIC(#tmp.after_value) = 1

---------------------------------------------------------------------------------------
-- ProfileQuoteApproval.disposal_service_id
---------------------------------------------------------------------------------------
UPDATE #tmp SET before_value = DisposalService.disposal_service_desc
FROM #tmp
INNER JOIN DisposalService ON #tmp.before_value = DisposalService.disposal_service_id
WHERE #tmp.table_name = 'ProfileQuoteApproval'
AND #tmp.column_name = 'disposal_service_id'
AND ISNUMERIC(#tmp.before_value) = 1

UPDATE #tmp SET after_value = DisposalService.disposal_service_desc
FROM #tmp
INNER JOIN DisposalService ON #tmp.after_value = DisposalService.disposal_service_id
WHERE #tmp.table_name = 'ProfileQuoteApproval'
AND #tmp.column_name = 'disposal_service_id'
AND ISNUMERIC(#tmp.after_value) = 1

---------------------------------------------------------------------------------------
-- ProfileQuoteApproval.treatment_process_id
---------------------------------------------------------------------------------------
UPDATE #tmp SET before_value = TreatmentProcess.treatment_process
FROM #tmp
INNER JOIN TreatmentProcess ON #tmp.before_value = TreatmentProcess.treatment_process_id
WHERE #tmp.table_name = 'ProfileQuoteApproval'
AND #tmp.column_name = 'treatment_process_id'
AND ISNUMERIC(#tmp.before_value) = 1

UPDATE #tmp SET after_value = TreatmentProcess.treatment_process
FROM #tmp
INNER JOIN TreatmentProcess ON #tmp.after_value = TreatmentProcess.treatment_process_id
WHERE #tmp.table_name = 'ProfileQuoteApproval'
AND #tmp.column_name = 'treatment_process_id'
AND ISNUMERIC(#tmp.after_value) = 1

---------------------------------------------------------------------------------------
-- profilesafetycode.profile_id
---------------------------------------------------------------------------------------
UPDATE #tmp SET before_value = profilesafetycode.profile_id
FROM #tmp
INNER JOIN profilesafetycode ON #tmp.before_value = profilesafetycode.profile_id
WHERE #tmp.table_name = 'profilesafetycode'
AND #tmp.column_name = 'profile_id'
AND ISNUMERIC(#tmp.before_value) = 1

UPDATE #tmp SET after_value = profilesafetycode.profile_id
FROM #tmp
INNER JOIN profilesafetycode ON #tmp.after_value = profilesafetycode.profile_id
WHERE #tmp.table_name = 'profilesafetycode'
AND #tmp.column_name = 'profile_id'
AND ISNUMERIC(#tmp.after_value) = 1

UPDATE #tmp
SET before_value = '(blank)'
WHERE ISNULL(LTRIM(RTRIM(before_value)), '') = ''

UPDATE #tmp
SET after_value = '(blank)'
WHERE ISNULL(LTRIM(RTRIM(after_value)), '') = ''

UPDATE #tmp
SET audit_reference = NULL
WHERE LEN(LTRIM(RTRIM(audit_reference))) = 0

UPDATE #tmp  
SET created_by = NULL  
WHERE LEN(LTRIM(RTRIM(created_by))) = 0

UPDATE #tmp  
SET created_by = NULL  
WHERE LEN(LTRIM(RTRIM(created_date))) = 0

UPDATE #tmp  
SET created_after_value = NULL  
WHERE LEN(LTRIM(RTRIM(created_after_value))) = 0 

SELECT * FROM #tmp
WHERE column_name NOT IN ('created_by')
ORDER BY date_modified DESC, table_name, column_name_display
GO

GRANT EXECUTE
    ON OBJECT::[dbo].[sp_get_profile_audit] TO [EQAI]
    AS [dbo];

