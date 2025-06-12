DROP PROCEDURE IF EXISTS sp_update_profile_inactive_flag
GO
CREATE PROCEDURE sp_update_profile_inactive_flag
       
AS 
/***************************************************************************************************
LOAD TO PLT_AI

This sp runs as a nightly process to update expired_not_received_date and inactive_flag
DevOps:38510 - 04/12/2022  AM     Created
DevOps:21238 - 05/16/2022 AM
***************************************************************************************************/

DECLARE @now DATETIME = GETDATE()

-- Get profiles that need to have expired_not_received_date set
SELECT DISTINCT p.profile_id
INTO #profile
FROM Profile p
WHERE p.curr_status_code = 'A' -- approved
AND p.ap_expiration_date <= CAST(getdate() AS date) -- expired
--AND p.expired_not_received_date IS NULL
AND (( expired_not_received_date is not null AND @now = DATEADD(dd,90,expired_not_received_date)  
        AND inactive_flag = 'F')
OR expired_not_received_date is null) 
-- expired_not_received_date is not null and 90th day from expired_not_received_date and inactive_flag = F 
-- OR expired_not_received_date is null  - DevOps:21238 - AM
AND p.profile_id NOT IN
(
SELECT r.profile_id
FROM Receipt r
WHERE r.trans_type = 'D' -- disposal line
AND r.receipt_status NOT IN ('R', 'V') -- not rejected or voided
AND r.receipt_date >= dateadd(year, -2, getdate()) -- received within the past two years
AND r.profile_id IS NOT NULL
UNION
SELECT wod.profile_id
FROM WorkOrderDetail wod
JOIN WorkOrderHeader woh
ON woh.company_id = wod.company_id
AND woh.profit_ctr_id = wod.profit_ctr_id
AND woh.workorder_id = wod.workorder_id
AND woh.workorder_status NOT IN ('V', 'X', 'T') -- not voided, not a trip stop, not a template
AND woh.start_date >= dateadd(year, -2, getdate()) -- start date is within the past two years
AND wod.profile_id IS NOT NULL
)

INSERT INTO ProfileAudit(profile_id, table_name, column_name, before_value, after_value, audit_reference, modified_by, date_modified)
SELECT profile_id, 'Profile', 'expired_not_received_date', '(blank)', CAST(CAST(@now AS date) AS VARCHAR(255)), 'DevOps 19944/DevOps 20750', CURRENT_USER, @now
FROM #profile

INSERT INTO ProfileAudit(profile_id, table_name, column_name, before_value, after_value, audit_reference, modified_by, date_modified)
SELECT #profile.profile_id, 'Profile', 'inactive_flag', p.inactive_flag, 'T', 'DevOps 19944/DevOps 20750', CURRENT_USER, @now
FROM #profile
JOIN Profile p
ON p.profile_id = #profile.profile_id

UPDATE Profile
SET expired_not_received_date = CAST(@now AS date),
inactive_flag = 'T',
modified_by = CURRENT_USER,
date_modified = @now
FROM #profile
WHERE Profile.profile_id = #profile.profile_id
AND date_added <= DATEADD(mm, -24,@now)        

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_update_profile_inactive_flag] TO [EQAI]
    AS [dbo];
