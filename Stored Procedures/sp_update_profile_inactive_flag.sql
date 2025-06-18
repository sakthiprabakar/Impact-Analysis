DROP PROCEDURE IF EXISTS sp_update_profile_inactive_flag
GO
CREATE PROCEDURE dbo.sp_update_profile_inactive_flag
AS
/***************************************************************************************************
LOAD TO PLT_AI

This sp runs as a nightly process to update expired_not_received_date and inactive_flag
DevOps:38510 - 04/12/2022  AM     Created
DevOps:21238 - 05/16/2022 AM If:The expired_not_received_date != null, AND the inactive_flag = 'F', AND the the profile is expired,
 AND the profile has not shipped in 2 years... Then:
	Reset the inactive_flag to 'T' on the 90th day from the expired_not_received_date value.
	Replace the original expired_not_received_date value with new expired_not_received_date (getdate)
Rally # DE34270 - 04/09/2025 - Sailaja - Automatic Profile Inactivation process firing incorrectly
		- Updated the expired_not_received_date to be >= 90, instead of exact 90th day to avoid profile not being picked 
		in case of any issue in the nightly job
		- Included the profile date_added <= DATEADD(mm, -24,@now) check in the initial temp table creation
		- Pulled out inactive_flag as it needs to work for expired_not_received_date is null condition also 						
***************************************************************************************************/
DECLARE @now DATETIME = GETDATE()

CREATE TABLE #profile (profile_id INT NOT NULL)

-- Get profiles that need to have expired_not_received_date set
INSERT INTO #profile
(profile_id)
SELECT DISTINCT
p.profile_id
FROM dbo.PROFILE p
WHERE p.curr_status_code = 'A' -- approved
	AND p.ap_expiration_date <= CAST(getdate() AS DATE) -- expired
	AND (
		(
			expired_not_received_date IS NOT NULL
			AND @now >= DATEADD(dd, 90, expired_not_received_date)
			)
		OR expired_not_received_date IS NULL
		)
	AND (
		inactive_flag = 'F'
		OR inactive_flag IS NULL
		)
	-- Pulled out inactive_flag as it needs to work for expired_not_received_date is null condition also - Rally # DE34270 - Sailaja
	-- expired_not_received_date is not null and 90th day from expired_not_received_date and inactive_flag = F 
	-- OR expired_not_received_date is null  - DevOps:21238 - AM
	AND p.profile_id NOT IN (
		SELECT r.profile_id
		FROM Receipt r
		WHERE r.trans_type = 'D' -- disposal line
			AND r.receipt_status NOT IN (
				'R'
				,'V'
				) -- not rejected or voided
			AND r.receipt_date >= dateadd(year, - 2, getdate()) -- received within the past two years
			AND r.profile_id IS NOT NULL
		
		UNION
		
		SELECT wod.profile_id
		FROM WorkOrderDetail wod
		JOIN WorkOrderHeader woh ON woh.company_id = wod.company_id
			AND woh.profit_ctr_id = wod.profit_ctr_id
			AND woh.workorder_id = wod.workorder_id
			AND woh.workorder_status NOT IN (
				'V'
				,'X'
				,'T'
				) -- not voided, not a trip stop, not a template
			AND woh.start_date >= dateadd(year, - 2, getdate()) -- start date is within the past two years
			AND wod.profile_id IS NOT NULL
		)
	AND p.date_added <= DATEADD(mm, - 24, @now)

--Included the profile date_added <= DATEADD(mm, -24,@now) check in the initial temp table creation - Rally # DE34270 - Sailaja
INSERT INTO dbo.ProfileAudit (
	profile_id
	,table_name
	,column_name
	,before_value
	,after_value
	,audit_reference
	,modified_by
	,date_modified
	)
SELECT #profile.profile_id
	,'Profile'
	,'expired_not_received_date'
	,CAST(CAST(p.expired_not_received_date AS DATE) AS VARCHAR(255))
	,CAST(CAST(@now AS DATE) AS VARCHAR(255))
	,'DevOps 19944/DevOps 20750'
	,CURRENT_USER
	,@now
FROM #profile
JOIN dbo.PROFILE p ON p.profile_id = #profile.profile_id

INSERT INTO dbo.ProfileAudit (
	profile_id
	,table_name
	,column_name
	,before_value
	,after_value
	,audit_reference
	,modified_by
	,date_modified
	)
SELECT #profile.profile_id
	,'Profile'
	,'inactive_flag'
	,p.inactive_flag
	,'T'
	,'DevOps 19944/DevOps 20750'
	,CURRENT_USER
	,@now
FROM #profile
JOIN dbo.PROFILE p ON p.profile_id = #profile.profile_id

UPDATE dbo.PROFILE
SET expired_not_received_date = CAST(@now AS DATE)
	,inactive_flag = 'T'
	,modified_by = CURRENT_USER
	,date_modified = @now
FROM #profile
WHERE PROFILE.profile_id = #profile.profile_id
	--AND date_added <= DATEADD(mm, -24,@now)
	--Included the profile date_added <= DATEADD(mm, -24,@now) check in the initial temp table creation - Rally # DE34270 - Sailaja
GO

GRANT EXECUTE
    ON OBJECT::[dbo].[sp_update_profile_inactive_flag] TO [EQAI];
