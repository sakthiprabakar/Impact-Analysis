

CREATE PROCEDURE sp_Access_SearchUsersAndContacts
(
	@debug int = 0,
	@user_id int = NULL,
	@contact_id int = NULL,
	@user_name varchar(50) = NULL,
	@user_code varchar(50) = NULL,
	@email varchar(100) = NULL,
	@user_type varchar(25) = NULL,
	@start_row int = 0,
	@end_row int = 20
)
/*	
	Description: 
	Searches for and returns generic, common information between users and contacts (id, name, etc...)

	Revision History:
	??/01/2009	RJG 	Created
	12/28/2010	RJG		Added filter for EQAI associates only (group_id > 100)
	07/29/2011	RJG		Added fitlers for AE and NAM
	
sp_Access_SearchUsersAndContacts 0, null, null, 'bob',  null, 'bob', 'A', 1, 50
	
*/	
AS
	SET NOCOUNT ON
	
	declare @search_sql varchar(8000)
	--DECLARE @debug int
	--SET @debug = 0 --0 = Off, 1 = On
	
	CREATE TABLE #search_results
	(
		row_num int identity(1,1),
		id int,
		username varchar(50),
		user_code varchar(50),
		email varchar(100),
		user_type varchar(10)
	)
	
	
	
	-- begin searching for associates/users
	IF @user_type = 'A' OR @user_type = 'AE' or @user_type = 'NAM' OR @user_type IS NULL
	BEGIN
	
		-- we have the username, no need to search the email
		SET @email = NULL
	
		set @search_sql = '
		INSERT INTO #search_results (id, username, user_code, email, user_type)
		SELECT DISTINCT
			user_id, 
			user_name + case when group_id = 0 then ''--(Terminated)'' else '''' end , 
			user_code,
			email, 
			''A'' as user_type '	
		set @search_sql = @search_sql + ' FROM Users WHERE user_code is not null and user_code not like ''x0%'' and isnull(email, '''') <> '''' and (group_id > 100 or group_id = 0) '
		
		IF @user_id IS NOT NULL
			SET @search_sql = @search_sql + ' AND user_id = ' + cast(@user_id as varchar(20))
			
		IF @user_code IS NOT NULL
			SET @search_sql = @search_sql + ' AND user_code = ' + cast(@user_id as varchar(20))
			
		IF @user_name IS NOT NULL
			SET @search_sql = @search_sql + ' AND user_name LIKE ''%' + @user_name + '%'''
		
		IF @email IS NOT NULL
			SET @search_sql = @search_sql + ' AND email LIKE ''%' + @email + '%'''
		
		if @user_type = 'AE' 
			set @search_sql = @search_sql + ' AND EXISTS( SELECT 1 FROM UsersXEQContact ux WHERE ux.user_code = Users.user_code AND ux.EQContact_type = ''AE'') '
			
		if @user_type = 'NAM' 
			set @search_sql = @search_sql + ' AND EXISTS( SELECT 1 FROM UsersXEQContact ux WHERE ux.user_code = Users.user_code AND ux.EQContact_type = ''NAM'') '			
		
		SET @search_sql = @search_sql + ' ORDER BY user_name + case when group_id = 0 then ''--(Terminated)'' else '''' end'
		
		IF @debug >= 1 print @search_sql
		
		exec(@search_sql)
		
		--SELECT *  FROM #search_results
	END

	-- begin searching for contacts	
	IF @user_type = 'C' OR @user_type IS NULL
	BEGIN
		SET @search_sql = '
		INSERT INTO #search_results (id, username, email, user_type)
			SELECT DISTINCT
				co.contact_id, 
				co.name, 
				co.email, 
				''C'' as user_type 
			FROM contact co
		   INNER JOIN contactxref bxc 
			 ON co.contact_id = bxc.contact_id 
				AND bxc.status = ''A'' 
				AND co.contact_status = ''A'' 
				AND bxc.web_access = ''A'' 
		WHERE  co.contact_status = ''A'' 
					 AND ((bxc.TYPE = ''C'' 
					 AND EXISTS (SELECT cu.customer_id 
								 FROM   customer cu 
								 WHERE  bxc.customer_id = cu.customer_id 
										AND cu.terms_code <> ''NOADMIT'')) 
					 OR (bxc.TYPE = ''G'' 
						 AND EXISTS (SELECT g.generator_id 
									 FROM   generator g 
									 WHERE  bxc.generator_id = g.generator_id 
											AND g.status = ''A''))) '
		
		IF @contact_id IS NOT NULL
			SET @search_sql = @search_sql + ' AND co.contact_id = ' + cast(@contact_id as varchar(20))
		IF @user_name IS NOT NULL
			SET @search_sql = @search_sql + ' AND co.name LIKE ''%' + @user_name + '%'''
		
		IF @email IS NOT NULL
			SET @search_sql = @search_sql + ' AND co.email LIKE ''%' + @email + '%'''		
			
		
		SET @search_sql = @search_sql + ' ORDER BY name'

														
			
		IF @debug >= 1 print @search_sql
		
		exec(@search_sql)			
	END
	
	declare @result_sql varchar(500)
	if @end_row = -1
	begin
		set @result_sql = 'SELECT * FROM #search_results'		
	end	
	else
		set @result_sql = 'SELECT * FROM #search_results WHERE row_num BETWEEN ' + convert(varchar(20), @start_row) + ' AND ' + convert(varchar(20), @end_row)

	exec(@result_sql)

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_Access_SearchUsersAndContacts] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_Access_SearchUsersAndContacts] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_Access_SearchUsersAndContacts] TO [EQAI]
    AS [dbo];

