
create procedure sp_AccessGroupSecurity_AssignDefaults
	@target_user_id int,			-- Who should get set up?
	@audit_user_code varchar(10)	-- Who's setting them up?
as
begin
/* ***************************************************************************
sp_AccessGroupSecurity_AssignDefaults

	Created to standardize and automate "default" permissions any new EQAI user gets
	for the Hub (was EQIP) site.
	
	Two hard-coded groups are targetted for the input @user_id:
	1000599: Everyone (phone list, etc)
	1000603: Remote Apps (Citrix, Network apps, etc)

History:

	04/13/2016	JPB	Created per Paul_K

Sample:

	sp_AccessGroupSecurity_AssignDefaults 627, 'JONATHAN' -- 627 = Jonathan, so this is redundant/unusual.
	

*************************************************************************** */
-- SELECT * FROM users where user_code = 'SARA_D'
-- declare @target_user_id int =627, @audit_user_code varchar(10) = 'PAUL_K', @source_user_id int = 1235

	declare @tbl_groups table(
		group_id int
	)
	
	INSERT @tbl_groups values (1000599), (1000603);
	
	
if OBJECT_ID('tempdb..#tmp_AccessGroupSecurity') is not null drop table #tmp_AccessGroupSecurity					

SELECT DISTINCT
	   tg.group_id AS group_id,
       @target_user_id as user_id,
       null as contact_id,
       ags.record_type,
       ags.customer_id,
       ags.generator_id,
       ags.corporate_flag,
       ags.company_id,
       ags.profit_ctr_id,
       ags.territory_code,
       ags.TYPE,
       ags.status,
       ags.contact_web_access,
       ags.primary_contact,
       Getdate() as date_modified,
       @audit_user_code as modified_by,
       Getdate() date_added,
       @audit_user_code added_by
INTO #tmp_AccessGroupSecurity
FROM   AccessGroupSecurity ags
       INNER JOIN @tbl_groups tg
         ON ags.group_id = tg.group_id
           --- AND user_id = @source_user_id 
		where status = 'A'
		and ags.record_type = 'P'
	
	
INSERT INTO AccessGroupSecurity 
	SELECT * FROM #tmp_AccessGroupSecurity
	WHERE NOT EXISTS (
		select 1
		FROM #tmp_AccessGroupSecurity tmp
		INNER JOIN AccessGroupSecurity ags ON 1=1
		AND ISNULL(ags.company_id, '') = ISNULL(tmp.company_id, '')
		and ISNULL(ags.profit_ctr_id, '') = ISNULL(tmp.profit_ctr_id, '')
		AND ISNULL(ags.record_type, '') = ISNULL(tmp.record_type, '')
		AND ISNULL(ags.customer_id, '') = ISNULL(tmp.customer_id, '')
		AND ISNULL(ags.generator_id,'') = ISNULL(tmp.generator_id, '')
		AND ISNULL(ags.territory_code, '') = ISNULL(tmp.territory_code, '')
		AND ISNULL(ags.group_id,'') = ISNULL(tmp.group_id, '')
		AND ISNULL(ags.user_id,'') = ISNULL(tmp.user_id,'')
		AND ags.status = 'A'
	)	
	
end


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_AccessGroupSecurity_AssignDefaults] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_AccessGroupSecurity_AssignDefaults] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_AccessGroupSecurity_AssignDefaults] TO [EQAI]
    AS [dbo];

