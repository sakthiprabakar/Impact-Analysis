
create procedure sp_ContactSearch
	@debug int = 0,
	@permission_id int = null,
	@customer_id_list varchar(max) = NULL,
	@user_code varchar(20) = NULL,
	@user_id int = NULL,
	@search_contact_id int = NULL,
	@first_name varchar(50) = NULL,
	@last_name varchar(50) = NULL,
	@search_mode varchar(25) = 'AccessSpecific' --' or Full, AccessSpecific, CustomerSpecific, GeneratorSpecific
/*
Usage: sp_ContactSelect

Full search mode does not filter by Customer, Generator or Access
*/
as

--declare @debug int = 0

IF @user_code is NULL
	SELECT @user_code = user_code FROM Users u where u.USER_ID = @user_id
	
if @first_name IS NOT NULL AND @first_name <> ''
	set @first_name = '%' + @first_name + '%'
	
if @last_name IS NOT NULL AND @last_name <> ''
	set @last_name = '%' + @last_name + '%'	

CREATE TABLE #SecuredCustomer(customer_id int)	
CREATE TABLE #SecuredGenerator(generator_id int)	

if @search_mode = 'AccessSpecific' OR @search_mode = 'GeneratorSpecific'
begin
	INSERT INTO #SecuredGenerator
	SELECT DISTINCT generator_id
	FROM   SecuredGenerator sc
	WHERE  sc.user_code = @user_code AND sc.permission_id = @permission_id
	
	INSERT INTO #SecuredCustomer
	SELECT DISTINCT customer_id
	FROM   SecuredCustomer sc
	WHERE  sc.user_code = @user_code AND sc.permission_id = @permission_id 	
end

--IF @search_mode = 'AccessSpecific'
--begin


--	--UNION

--	--SELECT row
--	--from dbo.fn_SplitXsvText(',', 1, @customer_id_list)
--	--where isnull(row, '') <> ''
-- end

if @search_mode = 'CustomerSpecific'
begin
	INSERT INTO #SecuredCustomer
		SELECT distinct row
		from dbo.fn_SplitXsvText(',', 1, @customer_id_list)
		where isnull(row, '') <> ''
end


if @debug > 0
	select '#SecuredCustomer' as [securedcustomer], * FROM #SecuredCustomer    
	
if @debug > 0
	select '#SecuredGenerator' as [securedgenerator], * FROM #SecuredGenerator    	
 
create index __sp_ContactSelect__cui_secured_customer_tmp on #SecuredCustomer(customer_id)
create index __sp_ContactSelect__cui_secured_generator_tmp on #SecuredGenerator(generator_id)

declare @search_sql varchar(max) = ''
--contact_ID
--contact_status
--contact_type
--contact_company
--name
--title
--phone
--fax
--pager
--mobile
--comments
--email
--email_flag
--added_from_company
--modified_by
--date_added
--date_modified
--web_password
--contact_addr1
--contact_addr2
--contact_addr3
--contact_addr4
--contact_city
--contact_state
--contact_zip_code
--contact_country
--comments
--contact_personal_info
--contact_directions
--salutation
--first_name
--middle_name
--last_name
--suffix
--web_access
--userkey
--record_count
SET @search_sql = 'SELECT
	DISTINCT Isnull(last_name, '''') + '', '' + Isnull(first_name, '''') AS display_name,
		c.contact_ID,
		c.contact_status,
		c.contact_type,
		c.contact_company,
		c.name,
		c.title,
		c.phone,
		c.fax,
		c.pager,
		c.mobile,
		c.email,
		c.email_flag,
		c.added_from_company,
		c.modified_by,
		c.date_added,
		c.date_modified,
		c.web_password,
		c.contact_addr1,
		c.contact_addr2,
		c.contact_addr3,
		c.contact_addr4,
		c.contact_city,
		c.contact_state,
		c.contact_zip_code,
		c.contact_country,
		c.salutation,
		c.first_name,
		c.middle_name,
		c.last_name,
		c.suffix
	FROM contact c '

if @search_mode <> 'Full'
	SET @search_sql = @search_sql + ' INNER JOIN contactxref x
		ON c.contact_id = x.contact_id
		AND x.status=''A'' '
		
IF @search_mode = 'CustomerSpecific'
begin
	SET @search_sql = @search_sql + ' JOIN #SecuredCustomer secured_customer ON x.customer_id = secured_customer.customer_id '
end

IF @search_mode = 'GeneratorSpecific'
begin
	SET @search_sql = @search_sql + ' JOIN #SecuredGenerator secured_generator ON x.generator_id = secured_generator.generator_id '
end

IF @search_mode = 'AccessSpecific'
begin
	SET @search_sql = @search_sql + ' 
		AND EXISTS(
				SELECT 1 FROM ContactXRef a
					JOIN #SecuredCustomer secured_customer ON a.customer_id = secured_customer.customer_id
				UNION
				SELECT 1 FROM ContactXRef b
					JOIN #SecuredGenerator secured_generator ON b.generator_id = secured_generator.generator_id
			) '
end


SET @search_sql = @search_sql + ' WHERE 1=1 AND contact_status = ''A'' '


if @first_name IS NOT NULL and @first_name <> ''
	SET @search_sql = @search_sql + ' AND first_name LIKE ''' + @first_name + ''' '
	
if @last_name IS NOT NULL and @last_name <> ''
	SET @search_sql = @search_sql + ' AND last_name LIKE ''' + @last_name + ''' '	
	
if @search_contact_id  IS NOT NULL and @search_contact_id  <> ''
	SET @search_sql = @search_sql + ' AND c.contact_id = ' + CAST(@search_contact_id  as varchar(10))
	

SET @search_sql = @search_sql + ' ORDER BY last_name, first_name '

if @debug > 0
	SELECT @search_sql

EXECUTE(@search_sql)


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_ContactSearch] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_ContactSearch] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_ContactSearch] TO [EQAI]
    AS [dbo];

