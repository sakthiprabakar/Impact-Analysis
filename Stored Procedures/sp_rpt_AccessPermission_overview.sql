
CREATE PROCEDURE sp_rpt_AccessPermission_overview
	@user_code_list varchar(max) = NULL
AS
BEGIN

SET NOCOUNT ON
-- first, get all permissions
declare @user_code varchar(50)
declare @user_id int
declare @group_id int

if object_id('tempdb..#tmp_access_info') is not null drop table #tmp_access_info
if object_id('tempdb..#tmp_holding') is not null drop table #tmp_holding

IF LEN(@user_code_list) = 0
	set @user_code_list = NULL

declare @user_code_filter table (
	user_code varchar(20)
)

INSERT @user_code_filter
	SELECT list.row
	FROM   dbo.fn_SplitXsvText(',', 0, @user_code_list) list
	WHERE  Isnull(row, '') <> '' 

--SELECT * FROM @user_code_filter


CREATE TABLE #tmp_access_info(
user_id int NULL,
group_id int NULL,
--group_id int NULL,
[2_21] varchar(50) NULL,
[3_1] varchar(50) NULL,
[12_0] varchar(50) NULL,
[12_1] varchar(50) NULL,
[12_2] varchar(50) NULL,
[12_3] varchar(50) NULL,
[12_4] varchar(50) NULL,
[12_5] varchar(50) NULL,
[12_7] varchar(50) NULL,
[14_0] varchar(50) NULL,
[14_1] varchar(50) NULL,
[14_2] varchar(50) NULL,
[14_3] varchar(50) NULL,
[14_4] varchar(50) NULL,
[14_5] varchar(50) NULL,
[14_6] varchar(50) NULL,
[14_9] varchar(50) NULL,
[14_10] varchar(50) NULL,
[14_11] varchar(50) NULL,
[14_12] varchar(50) NULL,
[15_1] varchar(50) NULL,
[15_2] varchar(50) NULL,
[15_3] varchar(50) NULL,
[15_4] varchar(50) NULL,
[16_0] varchar(50) NULL,
[17_0] varchar(50) NULL,
[18_0] varchar(50) NULL,
[21_0] varchar(50) NULL,
[21_1] varchar(50) NULL,
[21_2] varchar(50) NULL,
[21_3] varchar(50) NULL,
[22_0] varchar(50) NULL,
[22_1] varchar(50) NULL,
[23_0]varchar(50) NULL,
[24_0] varchar(50) NULL,
[25_0] varchar(50) NULL,
[25_2] varchar(50) NULL,
[25_4] varchar(50) NULL,
[26_0] varchar(50) NULL,
[26_2] varchar(50) NULL,
[27_0] varchar(50) NULL,
[27_2] varchar(50) NULL,
[28_0] varchar(50) NULL,
[29_0] varchar(50) NULL,
[15_0] varchar(50) NULL,
[3_0] varchar(50) NULL,
[15_6] varchar(50) NULL,
[15_7] varchar(50) NULL,
[14_14] varchar(50) NULL,
[14_15] varchar(50) NULL,
[2_0] varchar(50) NULL,
[22_2] varchar(50) NULL
)

CREATE TABLE #tmp_holding
(
	company_id int,
	profit_ctr_id int
)

select DISTINCT 
	u.user_id,
	u.user_code,
	apg.group_id
INTO #tmp_cursor_data	
FROM AccessPermissionGroup apg
	INNER JOIN AccessGroup ag ON apg.group_id = ag.group_id
	INNER JOIN AccessGroupSecurity ags ON apg.group_id = ags.group_id
	INNER JOIN Users u ON ags.user_id = u.user_id	
	INNER JOIN @user_code_filter ucf ON (u.user_code = ucf.user_code)
	INNER JOIN AccessPermission ap ON apg.permission_id = ap.permission_id
	INNER JOIN AccessPermissionSet aps ON aps.set_id = ap.set_id
where 1=1
AND ag.status = 'A'
AND ap.status = 'A'
AND aps.status = 'A'

UNION

select DISTINCT 
	u.user_id,
	u.user_code,
	apg.group_id
FROM AccessPermissionGroup apg
	INNER JOIN AccessGroup ag ON apg.group_id = ag.group_id
	INNER JOIN AccessGroupSecurity ags ON apg.group_id = ags.group_id
	INNER JOIN Users u ON ags.user_id = u.user_id	
	INNER JOIN AccessPermission ap ON apg.permission_id = ap.permission_id
	INNER JOIN AccessPermissionSet aps ON aps.set_id = ap.set_id
where 1=1
AND 1 = 
	CASE 
		WHEN @user_code_list IS NULL THEN 1
		ELSE 0
	END
AND ag.status = 'A'
AND ap.status = 'A'
AND aps.status = 'A'
order by u.user_code

--SELECT '#tmp_cursor_data', * FROM #tmp_cursor_data

declare @c CURSOR

SET @c = CURSOR FOR
	SELECT * FROM #tmp_cursor_data
	
declare @sql varchar(max)
declare @sql_updates varchar(max)

OPEN @c
FETCH NEXT FROM @c INTO @user_id, @user_code, @group_id

/* Do cursor loop */
WHILE @@FETCH_STATUS = 0
BEGIN

	--SELECT @user_code = user_code FROM Users where user_id = @user_id
	--print @user_code
	truncate table #tmp_holding
	INSERT INTO #tmp_holding (company_id, profit_ctr_id) 
		SELECT DISTINCT p.company_id, p.profit_ctr_id
		 FROM (SELECT DISTINCT company_id, profit_ctr_id
				FROM AccessPermissionGroup apg
				INNER JOIN AccessGroup ag ON apg.group_id = ag.group_id
				INNER JOIN AccessGroupSecurity ags ON apg.group_id = ags.group_id
				WHERE apg.group_id = apg.group_id
				--AND ags.user_id = @user_id  
				AND ags.company_id IS NOT NULL
				AND ags.profit_ctr_id IS NOT NULL
				AND ag.status = 'A'
				AND ags.record_type = 'A'
				AND ags.status = 'A'
			) x
			INNER JOIN SecuredProfitCenter secured_copc ON 
			(
				(x.company_id = secured_copc.company_id and x.profit_ctr_id = secured_copc.profit_ctr_id)
				OR
				(x.company_id = -9999 AND x.profit_ctr_id = -9999)
			)
			--and secured_copc.user_id = @user_id
			INNER JOIN ProfitCenter p ON p.company_ID = secured_copc.company_id AND p.profit_ctr_ID = secured_copc.profit_ctr_id
			WHERE p.status = 'A'		

	SET @sql = 'INSERT INTO #tmp_access_info (user_id, group_id) VALUES (' +cast(@user_id as varchar(20))+ ',' + (cast(@group_id as varchar(20))) + ')'
	exec(@sql)
	
	SET @sql_updates = 'UPDATE #tmp_access_info SET user_id=user_id ' /* user_id = user_id is just for proper txt output when there is no data */

	SELECT @sql_updates = COALESCE(@sql_updates + ', ', '') + 
	'[' + cast(company_id as varchar(20)) + '_' + cast(profit_ctr_id as varchar(20)) + ']=''X'''
		FROM #tmp_holding
			
			
	SET @sql_updates = REPLACE(@sql_updates, 'SET ,', 'SET ')
	SET @sql_updates = @sql_updates + ' WHERE user_id = ' + cast(@user_id as varchar(20)) + ' AND group_id = ' + cast(@group_id as varchar(20)) 
	
	--print @sql_updates
	EXEC(@sql_updates)
	
	FETCH NEXT FROM @c INTO @user_id, @user_code, @group_id
END

CLOSE @c
DEALLOCATE @c

--SELECT * FROM #tmp_access_info

UPDATE #tmp_access_info SET 
[12_0] = 'N/A',
[12_1] = 'N/A',
[12_2] = 'N/A',
[12_3] = 'N/A',
[12_4] = 'N/A',
[12_5] = 'N/A',
[12_7] = 'N/A',
[14_0] = 'N/A',
[14_1] = 'N/A',
[14_2] = 'N/A',
[14_3] = 'N/A',
[14_4] = 'N/A',
[14_5] = 'N/A',
[14_6] = 'N/A',
[14_9] = 'N/A',
[14_10] = 'N/A',
[14_11] = 'N/A',
[14_12] = 'N/A',
[15_1] = 'N/A',
[15_2] = 'N/A',
[15_3] = 'N/A',
[15_4] = 'N/A',
[16_0] = 'N/A',
[17_0] = 'N/A',
[18_0] = 'N/A',
[2_21] = 'N/A',
[21_0] = 'N/A',
[21_1] = 'N/A',
[21_2] = 'N/A',
[21_3] = 'N/A',
[22_0] = 'N/A',
[22_1] = 'N/A',
[23_0] = 'N/A',
[24_0] = 'N/A',
[25_0] = 'N/A',
[25_2] = 'N/A',
[25_4] = 'N/A',
[26_0] = 'N/A',
[26_2] = 'N/A',
[27_0] = 'N/A',
[27_2] = 'N/A',
[28_0] = 'N/A',
[29_0] = 'N/A',
[3_1] = 'N/A',
[15_0] = 'N/A',
[3_0] = 'N/A',
[15_6] = 'N/A',
[15_7] = 'N/A',
[14_14] = 'N/A',
[14_15] = 'N/A',
[2_0] = 'N/A',
[22_2] = 'N/A'
WHERE group_id IN (
	SELECT group_id from AccessGroup where permission_security_type = 'permission'
)


SELECT u.first_name,
       u.last_name,
       u.user_code,
       aps.set_name,
       ap.record_type,
       ap.permission_description,
       ap.permission_id,
       ag.group_description,
       ag.permission_security_type,
       tp.*
FROM   #tmp_access_info tp
       INNER JOIN Users u ON tp.user_id = u.user_id
       INNER JOIN AccessPermissionGroup apg ON tp.group_id = apg.group_id
       INNER JOIN AccessPermission ap ON apg.permission_id = ap.permission_id
       INNER JOIN AccessPermissionSet aps ON ap.set_id = aps.set_id
       INNER JOIN AccessGroup ag ON apg.group_id = ag.group_id
WHERE ap.status = 'A'
AND aps.status = 'A'
AND u.group_id > 100
ORDER  BY u.last_name,
          u.first_name 

END


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_AccessPermission_overview] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_AccessPermission_overview] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_AccessPermission_overview] TO [EQAI]
    AS [dbo];

