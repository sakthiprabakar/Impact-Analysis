
create procedure sp_AccessGroupSecurity_CopyAccess
	@source_user_id int,
	@source_user_type varchar(10),
	@target_user_id int,
	@target_user_type varchar(10),
	@group_ids varchar(max),
	@audit_user_code varchar(10)
as
begin

	declare @tbl_groups table(
		group_id int
	)
	
	INSERT INTO @tbl_groups (group_id)
		SELECT [ROW] as group_id from dbo.fn_SplitXsvText(',', 0, @group_ids) 
			
if OBJECT_ID('tempdb..#tmp_AccessGroupSecurity') is not null drop table #tmp_AccessGroupSecurity					

SELECT tg.group_id AS group_id,
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
            AND user_id = @source_user_id 
		where status = 'A'


-- deactivate the old permission that was the same
UPDATE AccessGroupSecurity SET status = 'I'
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
	
	
	
INSERT INTO AccessGroupSecurity 
	SELECT * FROM #tmp_AccessGroupSecurity
			
	
end

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_AccessGroupSecurity_CopyAccess] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_AccessGroupSecurity_CopyAccess] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_AccessGroupSecurity_CopyAccess] TO [EQAI]
    AS [dbo];

