
CREATE PROCEDURE [dbo].[sp_AccessPermission_SetDefaultPermissions]
as
begin
/*
	This procedure makes sure that IT group has access to all permissions/facilities/customers/generators.
	It also makes sure that new users have access to the standard set of permissions (phone list, etc...)
*/

/* 
	This section makes sure that everyone in the Site Admin group has access to all permissions	in the system
		all customers, all generators, etc...
*/

/* grab permissions where it users dont have any access */
if object_id('tempdb..#it_users_with_access_count') is not null drop table #it_users_with_access_count
if object_id('tempdb..#it_full_access') is not null drop table #it_full_access
if object_id('tempdb..#it_missing_access') is not null drop table #it_missing_access
IF Object_id('tempdb..#tmp_ags') IS NOT NULL  DROP TABLE #tmp_ags

SELECT *
INTO   #tmp_ags
FROM   AccessGroupSecurity
WHERE  1 = 0


 declare @it_users table  
 (  
  [user_id] int,  
  user_code varchar(20)  
 )  
 
 INSERT INTO @it_users  
  SELECT [user_id], user_code FROM users WHERE group_id = 1099  

DELETE FROM AccessGroupSecurity WHERE user_id IN (SELECT user_id FROM @it_users)

INSERT INTO #tmp_ags
            (group_id,
			 user_id,
             record_type,
             customer_id,
             generator_id,
             company_id,
             profit_ctr_id,
             TYPE,
             status,
             contact_web_access,
             primary_contact,
             date_modified,
             modified_by,
             date_added,
             added_by)
SELECT DISTINCT ag.group_id AS group_id,
       it.user_id,
       'P'         AS record_type,
       NULL        AS customer_id,
       NULL        AS generator_id,
       NULL       AS company_id,
       NULL       AS profit_ctr_id,
       'P'         AS TYPE,
       'A'         AS status,
       NULL        AS contact_web_access,
       NULL        AS primary_contact,
       Getdate()   AS date_modified,
       'sys'  AS modified_by,
       Getdate()   AS date_added,
       'sys'  AS added_by
FROM   AccessGroup ag 
	INNER JOIN @it_users it ON 1=1 AND ag.status = 'A'	
	INNER JOIN AccessPermissionGroup apg ON ag.group_id = apg.group_id
	INNER JOIN AccessPermission ap ON apg.permission_id = ap.permission_id
WHERE ap.permission_security_type = 'row'

UNION

SELECT DISTINCT ag.group_id AS group_id,
       it.user_id,
       'P'         AS record_type,
       NULL        AS customer_id,
       NULL        AS generator_id,
       NULL       AS company_id,
       NULL       AS profit_ctr_id,
       'P'         AS TYPE,
       'A'         AS status,
       NULL        AS contact_web_access,
       NULL        AS primary_contact,
       Getdate()   AS date_modified,
       'sys'  AS modified_by,
       Getdate()   AS date_added,
       'sys'  AS added_by
FROM   AccessGroup ag 
	INNER JOIN @it_users it ON 1=1 AND ag.status = 'A'	
	INNER JOIN AccessPermissionGroup apg ON ag.group_id = apg.group_id
	INNER JOIN AccessPermission ap ON apg.permission_id = ap.permission_id
WHERE ap.permission_security_type = 'permission'
--WHERE ag.permission_security_type = 'permission'

UNION

SELECT DISTINCT ag.group_id AS group_id,
       it.user_id,
       'A'         AS record_type,
       NULL        AS customer_id,
       NULL        AS generator_id,
       -9999       AS company_id,
       -9999       AS profit_ctr_id,
       'A'         AS TYPE,
       'A'         AS status,
       NULL        AS contact_web_access,
       NULL        AS primary_contact,
       Getdate()   AS date_modified,
       'sys'  AS modified_by,
       Getdate()   AS date_added,
       'sys'  AS added_by
FROM   AccessGroup ag 
	INNER JOIN @it_users it ON 1=1 AND ag.status = 'A'	
	INNER JOIN AccessPermissionGroup apg ON ag.group_id = apg.group_id
	INNER JOIN AccessPermission ap ON apg.permission_id = ap.permission_id
WHERE ap.permission_security_type = 'row'
	

UNION

SELECT DISTINCT ag.group_id AS group_id,
       it.user_id,
       'C'         AS record_type,
       -9999        AS customer_id,
       NULL        AS generator_id,
       NULL       AS company_id,
       NULL       AS profit_ctr_id,
       'C'         AS TYPE,
       'A'         AS status,
       NULL        AS contact_web_access,
       NULL        AS primary_contact,
       Getdate()   AS date_modified,
       'sys'  AS modified_by,
       Getdate()   AS date_added,
       'sys'  AS added_by
FROM   AccessGroup ag 
	INNER JOIN @it_users it ON 1=1 AND ag.status = 'A'	
	INNER JOIN AccessPermissionGroup apg ON ag.group_id = apg.group_id
	INNER JOIN AccessPermission ap ON apg.permission_id = ap.permission_id
WHERE ap.permission_security_type = 'row'
	

UNION

SELECT DISTINCT ag.group_id AS group_id,
       it.user_id,
       'G'         AS record_type,
       NULL        AS customer_id,
       -9999        AS generator_id,
       NULL       AS company_id,
       NULL       AS profit_ctr_id,
       'G'         AS TYPE,
       'A'         AS status,
       NULL        AS contact_web_access,
       NULL        AS primary_contact,
       Getdate()   AS date_modified,
       'sys'  AS modified_by,
       Getdate()   AS date_added,
       'sys'  AS added_by
FROM   AccessGroup ag 
	INNER JOIN @it_users it ON 1=1 AND ag.status = 'A'	
	INNER JOIN AccessPermissionGroup apg ON ag.group_id = apg.group_id
	INNER JOIN AccessPermission ap ON apg.permission_id = ap.permission_id
WHERE ap.permission_security_type = 'row'


--SELECT DISTINCT ag.group_id, ag.group_description FROM #tmp_ags tmp
--	inner join AccessGroup ag ON tmp.group_id = ag.group_id
--	AND ag.status = 'A'
	
--RETURN
			 
--/* 
--	This section makes sure that all EQAI users are members of the Associates group
--*/

if object_id('tempdb..#general_associate_groups') is not null drop table #general_associate_groups 
if object_id('tempdb..#remote_access_groups') is not null drop table #remote_access_groups 
if object_id('tempdb..#missing_access') is not null drop table #missing_access


SELECT apg.group_id,
       user_id
INTO   #general_associate_groups
FROM   AccessPermissionGroup apg
       INNER JOIN users u ON 1 = 1 AND u.group_id > 100
       /* permissions for 'general eq associates' */
WHERE  permission_id IN ( 7, 56, 68, 94, 
                          95, 96, 97, 98,
                          99, 100, 122, 128,
                          129, 130 ) 

	
SELECT tmp.* INTO #missing_access
	FROM #general_associate_groups tmp
	INNER JOIN Users u ON tmp.user_id = u.user_id --AND u.user_id = 1
	WHERE NOT EXISTS (select 1 from AccessGroupSecurity ags
		where ags.group_id = tmp.group_id
		and ags.user_id = tmp.user_id
		AND ags.status = 'A'
	)
		
--SELECT * FROM #missing_access	

	
/*
	This section makes sure that people with Remote Access in users have the same access in EQIP
*/	
		
SELECT apg.group_id,
       user_id
INTO   #remote_access_groups
FROM   AccessPermissionGroup apg
       INNER JOIN users u ON 1 = 1 
		AND u.group_id > 100
		and u.b2b_remote_access = 'T'
       /* permissions for 'remote associates' */
WHERE permission_id in (70,71)

	
INSERT INTO #missing_access	
SELECT tmp.* 
	FROM #remote_access_groups tmp
	INNER JOIN Users u ON tmp.user_id = u.user_id --AND u.user_id = 1
	WHERE NOT EXISTS (select 1 from AccessGroupSecurity ags
		where ags.group_id = tmp.group_id
		and ags.user_id = tmp.user_id
		AND ags.status = 'A'
		)

	

		

INSERT INTO #tmp_ags
            (group_id,
             user_id,
             contact_id,
             record_type,
             customer_id,
             generator_id,
             corporate_flag,
             company_id,
             profit_ctr_id,
             territory_code,
             TYPE,
             status,
             contact_web_access,
             primary_contact,
             date_modified,
             modified_by,
             date_added,
             added_by)
SELECT DISTINCT group_id as group_id
	,user_id
	,null as contact_id
	,'P' as record_type
	,null as customer_id
	,null as generator_id
	,null as corporate_flag
	,null as company_id
	,null as profit_ctr_id
	,null as territory_code
	,'P' as [type]
	,'A' as status
	,NULL as contact_web_access
	,NULL as primary_contact
	,Getdate()  AS date_modified
	,'sys' AS modified_by
	,Getdate()  AS date_added
	,'sys' AS added_by
FROM   #missing_access tmp 

	
			
--SELECT * FROM #tmp_ags		
	
/* commit changes to access group security */
INSERT INTO AccessGroupSecurity	
	SELECT * FROM #tmp_ags		
	


END



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_AccessPermission_SetDefaultPermissions] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_AccessPermission_SetDefaultPermissions] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_AccessPermission_SetDefaultPermissions] TO [EQAI]
    AS [dbo];

