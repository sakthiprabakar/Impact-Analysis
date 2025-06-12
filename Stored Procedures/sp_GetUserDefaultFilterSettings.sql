CREATE PROCEDURE [dbo].[sp_GetUserDefaultFilterSettings]
	-- Add the parameters for the stored procedure here
	@web_userId nvarchar(100),
	@generator_id nvarchar(500) = null
AS
/* ******************************************************************

	Updated By		: Senthil Kumar, Dineshkumar
	Updated On		: 30 June 2021
	Type			: Stored Procedure
	Object Name		: [sp_GetUserDefaultFilterSettings]


	Procedure used to get default filter settings for the web_userid

inputs 
	
	@web_userId

Samples:
    EXEC [sp_GetUserDefaultFilterSettings]  @web_userId
    EXEC [sp_GetUserDefaultFilterSettings]  'manand84','' 

****************************************************************** */
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;	

	declare @contact_id int = (select top 1 contact_id from contact where web_userid = @web_userId and contact_status = 'A' and web_access_flag = 'T')

	declare @account_disabled char(1) = 'F'

	declare @filtered_generators table (generator_id int)
	declare @filtered_customers table (customer_id nvarchar(30))

	IF (@generator_id = null)
	BEGIN
		insert @filtered_generators
		select row from [dbo].fn_splitxsvtext(',', 1,(SELECT Top 1 g.FileterValue FROM COR_DB..UserDefaultFilterSettings g WHERE  g.web_userid=  @web_userId 
		AND g.DeletedFlag IS NULL AND g.DefaultFilterSettingId= (SELECT DefaultFilterSettingId FROM COR_DB..DefaultFilterSettings
		WHERE FilterColumnName='GeneratorName') order by g.date_modified desc))
	END
	ELSE
	BEGIN
	
		insert @filtered_generators select row from [dbo].fn_splitxsvtext(',', 1,@generator_id)
	END
	
	
	insert @filtered_customers
	select convert(nvarchar(30),row) from dbo.fn_splitxsvtext(',', 1,(SELECT Top 1 g.FileterValue FROM COR_DB..UserDefaultFilterSettings g WHERE  g.web_userid=  @web_userId AND 
	g.DeletedFlag IS NULL AND g.DefaultFilterSettingId= (SELECT DefaultFilterSettingId FROM COR_DB..DefaultFilterSettings 
	WHERE FilterColumnName='CustomerName') order by g.date_modified desc))
	
	-- insert into @filtered_customers(customer_id)  values('34')
	
	IF(select count(*) from @filtered_generators where generator_id not in( 
	select generator_id from contactcorGeneratorbucket where contact_id in (@contact_id))) > 0
	BEGIN
		set @account_disabled = 'T'
	END
	
	IF(select count(*) from @filtered_customers where customer_id not in( 
	select customer_id from contactcorCustomerbucket where contact_id in (@contact_id))) > 0
	BEGIN
		set @account_disabled = 'T'
	END

	SELECT 		
    	 (SELECT
		 Generator.generator_id,
		 EPA_ID,
		 (SELECT generator_type FROM generatortype gt WHERE gt.generator_type_id=Generator.generator_type_id) generator_type,
		 generator_name,
		 generator_city,
		 gen_mail_state,
		 gen_mail_country,
		 gen_mail_zip_code
	 FROM Generator 
	 JOIN
	  @filtered_generators filtergenerator
	-- dbo.fn_splitxsvtext(',', 1,(SELECT TOP 1 FileterValue FROM COR_DB..UserDefaultFilterSettings WHERE  web_userid=  @web_userId AND DeletedFlag IS NULL AND DefaultFilterSettingId= (SELECT DefaultFilterSettingId FROM COR_DB..DefaultFilterSettings WHERE FilterColumnName='GeneratorName')order by date_modified desc))
	 ON filtergenerator.generator_id = Generator.Generator_Id AND filtergenerator.generator_id is not null
	 --WHERE Generator.status='A'
	 FOR XML AUTO,TYPE,ROOT ('DefaultGenerators'), ELEMENTS),
	 	 (SELECT 
		 customer_ID as customer_id,
		 cust_name,
		 cust_city,
		 cust_state,
		 cust_zip_code,
		 cust_country
	 FROM Customer 
	 JOIN 
	 dbo.fn_splitxsvtext(',', 1,(SELECT TOP 1 FileterValue FROM COR_DB..UserDefaultFilterSettings WHERE  web_userid=  @web_userId AND DeletedFlag IS NULL AND DefaultFilterSettingId= (SELECT DefaultFilterSettingId FROM COR_DB..DefaultFilterSettings WHERE FilterColumnName='CustomerName') order by date_modified desc))
	 ON [row]= Customer.customer_ID AND [row] is not null
	 FOR XML AUTO,TYPE,ROOT ('DefaultCustomers'), ELEMENTS),
	 ISNULL((SELECT TOP 1 FileterValue FROM COR_DB..UserDefaultFilterSettings WHERE 
		web_userid=  @web_userId AND DeletedFlag IS NULL 
		AND DefaultFilterSettingId = (SELECT DefaultFilterSettingId FROM COR_DB..DefaultFilterSettings
		 WHERE FilterColumnName='filter_JSON') order by date_modified desc), '')  as filter_JSON,
		 @account_disabled as account_disabled
	  FOR XML RAW ('UserDefaultFilters'), ELEMENTS	
	
END

GO

GRANT EXECUTE ON [dbo].[sp_GetUserDefaultFilterSettings] TO COR_USER;

GO

