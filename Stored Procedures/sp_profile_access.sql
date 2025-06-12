CREATE PROCEDURE sp_profile_access
	@debug		int,
	@user_code	varchar(20),
	@db_type	varchar(10)
AS
/***************************************************************************************************
LOAD TO PLT_AI
Filename:	L:\Apps\SQL\EQAI\PLT_AI\sp_profile_access
PB Object(s):	d_profile_access

This SP populates the ProfileAccess table with this user's access permissions for the 
profile screen for all companies.

10/09/2006 SCC	Created
10/17/2006 SCC	Include profile_tracking, broker, and approval_scan access in ProfileAccess table
01/08/2007 JDB	Modified to use Access table from Plt_AI (moved there from Plt_XX_AI)

sp_profile_access 1, 'JASON_B', 'DEV'
select * from ProfileAccess
***************************************************************************************************/
DECLARE @group_id	int

CREATE TABLE #tmp_access (
	company_id	int,
	profile_tracking char(1),
	approval	char(1),
	broker		char(1),
	approval_scan	char(1),
	date_added	datetime
)

-- Remove any previous retrievals
DELETE FROM ProfileAccess WHERE user_code = @user_code

-- Get this user's group ID
SELECT @group_id = group_id FROM Users WHERE user_code = @user_code

-- Insert Results
INSERT ProfileAccess (
	user_code,
	company_id,
	profit_ctr_id,
	profile_tracking, 
	approval,
	broker,
	approval_scan,
	date_added
	)
SELECT @user_code, 
	company_id, 
	NULL AS profit_ctr_id, 
	ISNULL(Access.profile_tracking, 'N'), 
	ISNULL(approval, 'N'),
	ISNULL(broker, 'N'),
	ISNULL(approval_scan, 'N'),
	GETDATE()
FROM Access
WHERE group_id = @group_id
ORDER BY company_id

IF @debug = 1
BEGIN
	SELECT * FROM ProfileAccess WHERE user_code = @user_code
END

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_profile_access] TO [EQAI]
    AS [dbo];

