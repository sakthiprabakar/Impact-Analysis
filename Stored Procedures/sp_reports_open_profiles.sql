
CREATE PROCEDURE sp_reports_open_profiles (
	@debug					int, 			-- 0 or 1 for no debug/debug mode
	@database_list			varchar(8000),	-- Comma Separated Company List
	@customer_id_list		varchar(8000),	-- Comma Separated Customer ID List - what customers to include
	@generator_id_list		varchar(8000),	-- Comma Separated Generator ID List - what generators to include
	@start_date				varchar(20),	-- Start Date
	@end_date				varchar(20),	-- Start Date
	@status_list			varchar(8000) = '',	-- Comma Separated Status List
	@approval_code_list		varchar(8000) = '',	-- Comma Separated Approval Codes
	@profile_contact_list	varchar(8000) = '',	-- Comma Separated User Code List
	@tracking_contact_list	varchar(8000) = ''	-- Comma Separated User Code List
	
)
AS
/****************************************************************************************************
Procedure    : sp_reports_open_profiles
Database     : PLT_AI* 
Created      : Thu Feb 15 11:52:42 EDT 2007 - Jonathan Broome
Filename		: L:\apps\sql\develop\jonathan\sp_Reports_Open_Profiles.sql
Description  : Returns all profiles that are Pending or Hold status'd for the web site
Modified	 :
05/07/2007 - JPB - Added input parameters
03/19/2008 - JPB - Added Status List, Approval Code List, User List to inputs/criteria
10/09/2008 - JPB - Modified @database_list variable treatment, since the popup used to pick them on the web changed to delivering -'s not |'s
10/10/2008 - JPB - added & differentiated user_codes to profile_contact and tracking_contact lists.

sp_reports_open_profiles
sp_reports_open_profiles 0, '', '', '', '', ''
sp_reports_open_profiles 0, '', '5685', '', '', ''
sp_reports_open_profiles 0, '', '5685, 10908', '', '', ''
sp_reports_open_profiles 0, '', '5685, 10908', '6619, 42077', '', ''
sp_reports_open_profiles 0, '', '5685, 10908', '6619, 42077', '10/23/2006', ''
sp_reports_open_profiles 0, '', '5685, 10908', '6619, 42077', '10/09/2006', '10/10/2006'
sp_reports_open_profiles 0, '', '', '', '', '', '', '', 'DAMIAN_F'
sp_reports_open_profiles 0, '', '', '', '', '', '', '', '', 'DAMIAN_F'

****************************************************************************************************/
SET NOCOUNT ON
DECLARE @execute_sql			varchar(8000)

-- Set/normalize defaults

	IF @customer_id_list IS NULL OR LEN(@customer_id_list) = 0
	BEGIN
		SET @customer_id_list = '-1'
		IF @debug >= 1 PRINT '@customer_id_list:  ' + @customer_id_list
	END

-- Clean up the generator id list variable	
	IF @generator_id_list IS NULL OR LEN(@generator_id_list) = 0
	BEGIN
		SET @generator_id_list = '-1'
		IF @debug >= 1 PRINT '@generator_id_list:  ' + @generator_id_list
	END

	CREATE TABLE #customer (customer_id int)
	CREATE TABLE #generator (generator_id int)
	CREATE TABLE #status (code char(4))
	CREATE TABLE #approvalcode (approval_code varchar(20))
	CREATE TABLE #profile_contact (user_code varchar(10))
	CREATE TABLE #tracking_contact (user_code varchar(10))
	
	INSERT #customer select convert(int, row) from dbo.fn_SplitXsvText(',', 1, @customer_id_list) where isnull(row, '') <> ''
	INSERT #generator select convert(int, row) from dbo.fn_SplitXsvText(',', 1, @generator_id_list) where isnull(row, '') <> ''
	INSERT #status select row from dbo.fn_SplitXsvText(',', 1, @status_list) where isnull(row, '') <> ''
	INSERT #approvalcode select row from dbo.fn_SplitXsvText(',', 1, @approval_code_list) where isnull(row, '') <> ''
	INSERT #profile_contact select row from dbo.fn_SplitXsvText(',', 1, @profile_contact_list) where isnull(row, '') <> ''
	INSERT #tracking_contact select row from dbo.fn_SplitXsvText(',', 1, @tracking_contact_list) where isnull(row, '') <> ''
	
	SET @execute_sql = 'SELECT
		Profile.profile_id,
		ProfileLookup.Description as Profile_Status,
		PL2.description AS current_tracking_status,
		U.user_name AS Profile_Contact,
		U2.user_name as Tracking_Contact,
		isnull(DPT.department_description, ''Unknown'') AS current_tracking_department,
		(select user_name from Users U2 where user_code = PT.EQ_Contact) AS current_tracking_user,
		Profile.date_added,
		Profile.date_modified,
		Profile.customer_id,   
		Profile.generator_id,   
		Profile.pending_customer_name,   
		Profile.pending_generator_name,
		Customer.cust_name AS customer_name,
		Generator.generator_name,
		Generator.EPA_ID,
		Profile.curr_status_code,
		Profile.date_added,
		round((dbo.fn_business_minutes(profile.date_added, getdate())/60.0),1) as business_minutes
	FROM Profile
		INNER JOIN ProfileTracking PT on Profile.Profile_id = PT.Profile_id and Profile.profile_tracking_id = PT.tracking_id
		INNER JOIN ProfileLookup ON (Profile.curr_status_code = ProfileLookup.code and ProfileLookup.type = ''Profile'')
		INNER JOIN ProfileLookup PL2 ON (PT.Tracking_Status = PL2.code and PL2.type = ''TrackingStatus'')
		LEFT OUTER JOIN ProfileQuoteApproval ON Profile.profile_id = ProfileQuoteApproval.profile_id
		LEFT OUTER JOIN Department DPT on PT.department_id = DPT.department_id
		LEFT OUTER JOIN Users U on Profile.EQ_Contact = U.user_code
		LEFT OUTER JOIN Users U2 on PT.EQ_Contact = U2.user_code
		LEFT OUTER JOIN Customer ON (Profile.customer_id = Customer.customer_id)
		LEFT OUTER JOIN Generator ON (Profile.generator_id = Generator.generator_id)
	WHERE Profile.curr_status_code IN (''P'', ''H'') '
	
	IF @database_list <> ''
		SET @execute_sql = @execute_sql + '
			AND right(''00'' + ltrim(convert(varchar(2), ProfileQuoteApproval.company_id)), 2) + ''-'' + convert(varchar(2), ProfileQuoteApproval.profit_ctr_id) in (''' + replace(@database_list, ',', ''',''')+ ''') 
		'
	
	IF @customer_id_list <> '-1'
		SET @execute_sql = @execute_sql + '
			AND (profile.profile_id in (
				select profile_id from profile where customer_id in (select customer_id from #customer)
				union
				select profile_id from profile where orig_customer_id in (select customer_id from #customer)
				union
				select profile_id from profile where generator_id in (select generator_id from customergenerator where customer_id in (select customer_id from #customer))
				)
			)
			'
	
	if @generator_id_list <> '-1'
		SET @execute_sql = @execute_sql + '
			AND (profile.generator_id in (select generator_id from #generator)) '

	if isnull(@status_list, '') <> ''
		set @execute_sql = @execute_sql + 'and PL2.code in (select code from #status) '
			
	if isnull(@approval_code_list, '') <> ''
		SET @execute_sql = @execute_sql + '
			AND (profilequoteapproval.approval_code in (select approval_code from #approvalcode))'

	if isnull(@profile_contact_list, '') <> ''
		set @execute_sql = @execute_sql + 'and Profile.eq_contact in (select user_code from #profile_contact) '

	if isnull(@tracking_contact_list, '') <> ''
		set @execute_sql = @execute_sql + 'and pt.eq_contact in (select user_code from #tracking_contact) '
		
	IF LEN(@start_date) > 0 OR LEN(@end_date) > 0 SET @execute_sql = @execute_sql + ' AND 
		Profile.date_added BETWEEN 
			COALESCE(NULLIF(''' + @start_date + ''',''''), Profile.date_added) 
			AND 
			COALESCE(NULLIF(''' + @end_date + ''',''''), Profile.date_added) 
		AND Profile.date_added <= GETDATE()'
		
	SET @execute_sql = @execute_sql + ' ORDER by profile.date_added '

	SET NOCOUNT OFF
	
IF @debug >= 1
BEGIN
	PRINT @execute_sql
	PRINT ''
END

IF @debug >= 2 SELECT @execute_sql AS sql_statement

IF @debug < 10 EXEC(@execute_sql)

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_reports_open_profiles] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_reports_open_profiles] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_reports_open_profiles] TO [EQAI]
    AS [dbo];

