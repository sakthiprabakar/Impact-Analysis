CREATE PROCEDURE sp_customer_sync_finance
	@debug			int, 
	@customer_code	varchar(6),
	@db_type		varchar(4),
	@user_code		varchar(10),
	@addr1			varchar(40),
	@addr2			varchar(40),
	@addr3			varchar(40),
	@addr4			varchar(40),
	@addr5			varchar(40),
	@return_code	int		OUTPUT
AS
/***************************************************************************************
This SP synchronizes the customer information between EQAI and all of the Finance DBs

Filename:		L:\Apps\SQL\EQAI\Plt_AI\sp_customer_sync_finance.sql
Loads to:		Plt_AI
PB Object(s):	w_customer

04/27/2007 SCC	Created
11/16/2007 SCC	Modified to replace single quotes in customer fields with 2 single quotes so they will insert
				and changed to use Customer.bill_to_cust_name for address_name
11/22/2007 JDB	Modified to get attention name and phone from the contact in CustomerBillingXContact
				for 0 billing project where attn_name_flag = 'T'.
01/22/2009 JDB	Initialized the @attention_email variable to empty string - since we turned on
				the DB setting CONCAT_NULL_YIELDS_NULL, it was breaking the SQL statement.
10/28/2013 JDB	Modified to use the FinanceSyncControl table, and only synchronize customer
				changes to Epicor if the appropriate flag is turned on.

sp_customer_sync_finance 1, '009515', 'DEV', 'JASON_B', 'P.O. BOX 406','','','','', 0
sp_customer_sync_finance 1, '011820', 'PROD', 'JASON_B', '830 EAST CENTRE PARK BLVD','','','','',0
sp_customer_sync_finance 1, '909090', 'TEST', 'JASON_B', 'TESTING','','','','',0
****************************************************************************************/
DECLARE	@company_id		int,
	@customer_id		int,
	@cust_name			varchar(40),
	@customer_exists	int,
	@customer_discount	float,
	@db_name_epic		varchar(20),
	@db_count			int,
	@julian_date		int,
	@name1				varchar(40),
	@name2				varchar(40),
	@pos				int,
	@pos2				int,
	@success_count		int,
	@server_epic		varchar(20),
	@short_name			varchar(40),
	@sql_cmd			varchar(8000),
	@territory_code		varchar(2),
	@salesperson_code	varchar(4),
	@today				datetime,
	@address_name		varchar (40),
	@addr6				varchar (40),
	@attention_name		varchar (40),
	@attention_phone	varchar (30),
	@attention_email	varchar (255),
	@contact_name		varchar (40),
	@contact_phone		varchar (30),
	@phone_1			varchar (30),
	@city				varchar (40),
	@state				varchar (40),
	@postal_code		varchar (15),
	@country			varchar (40),
	@contact_email		varchar (255),
	@status_type		int,
	@terms_code			varchar(8),
	@credit_limit		money,
	@sync_cust_epicor	tinyint
	
---------------------------------------------------------------
-- Do we export invoices/adjustments to Epicor?
---------------------------------------------------------------
SELECT @sync_cust_epicor = sync
FROM FinanceSyncControl
WHERE module = 'Customer'
AND financial_system = 'Epicor'

IF @sync_cust_epicor = 1
-- Synchronize the customer to Epicor
BEGIN

	CREATE TABLE #finance_db (
		company_id	int NULL,
		db_name_epic	varchar(20) NULL,
		customer_exists	int NULL,
		process_flag 	int NULL
	)

	------------------------------------------------------------------------------------
	-- e01 must have a record
	------------------------------------------------------------------------------------
	IF NOT EXISTS (SELECT 1 FROM EQConnect WHERE db_name_epic = 'e01' AND db_type = @db_type)
		INSERT #finance_db VALUES (0, 'e01', 0, 0)

	INSERT #finance_db
	SELECT DISTINCT
		C.company_id,
		C.db_name_epic,
		0 as customer_exists,
		0 as process_flag
	FROM EQConnect C
	WHERE C.db_type = @db_type

	SELECT @server_epic = 'NTSQLFinance'

	SELECT @db_count = COUNT(*) FROM #finance_db

	IF @debug = 1 print 'Epicor server: ' + @server_epic

	-- Setup for a new financial record
	SELECT @today = GETDATE()
	SELECT @julian_date = DATEDIFF(dd, '01-01-1980', @today) + 722815
	SET @success_count = 0

	-- Setup the customer ID
	SET @customer_id = CONVERT(int, @customer_code)

	-- Setup the territory code
	SELECT @customer_discount = ISNULL(CustomerBilling.cust_discount,0),
		@territory_code = ISNULL(CustomerBilling.territory_code, '00'),
		@salesperson_code = 'AE' + ISNULL(CustomerBilling.territory_code, '00')
	FROM CustomerBilling
	WHERE CustomerBilling.customer_id = @customer_id
	AND CustomerBilling.billing_project_id = 0
	AND CustomerBilling.status = 'A'

	-- Setup this customer short name
	SELECT @cust_name = REPLACE(ISNULL(bill_to_cust_name,' '),'''','''''') 
		FROM Customer WHERE customer_id = @customer_id

	SELECT @pos = CHARINDEX(' ', @cust_name, 1)
	IF @pos > 0
	BEGIN
		SELECT @name1 = SUBSTRING(@cust_name, 1, @pos - 1)
		SELECT @pos2 = CHARINDEX( ' ', @cust_name, @pos + 1)
		IF @pos2 > 0
			IF (@pos2 - @pos - 1) <= 0
				SET @name2 = SUBSTRING(@cust_name, @pos + 1, LEN(@cust_name) - @pos + 1)
			ELSE
				SET @name2 = SUBSTRING(@cust_name, @pos + 1, @pos2 - @pos - 1)
		ELSE
			SET @name2 = SUBSTRING(@cust_name, @pos + 1, LEN(@cust_name) - @pos + 1)

		-- Put the two together
		IF LEN(@name1) >= 10
			SET @short_name = SUBSTRING(@name1, 1, 5) + SUBSTRING(@name2, 1, 5)
		ELSE
			SET @short_name = SUBSTRING(@name1 + @name2, 1, 10)
	END
	ELSE
		-- No spaces
		SET @short_name = SUBSTRING(@cust_name, 1, 10)

	SET	@addr6			= REPLACE(@addr5,'','''')
	SET	@addr5			= REPLACE(@addr4,'','''')
	SET	@addr4			= REPLACE(@addr3,'','''')
	SET	@addr3			= REPLACE(@addr2,'','''')
	SET	@addr2			= REPLACE(@addr1,'','''')


	SELECT 	@address_name = REPLACE(Customer.bill_to_cust_name,'',''''),
		@addr1 = REPLACE(Customer.bill_to_cust_name,'',''''),
		@status_type = CASE ISNULL(Customer.cust_status, 'N') 
			WHEN 'A' THEN 1 
			WHEN 'I' THEN 2 
			ELSE 3 END,
		@contact_name = REPLACE(ISNULL(Contact.name,'ACCOUNTS PAYABLE'),'',''''),
		@contact_phone = REPLACE(ISNULL(Contact.phone,' '),'',''''),
		@phone_1 = REPLACE(ISNULL(Customer.cust_fax,' '),'',''''),
		@terms_code = REPLACE(ISNULL(Customer.terms_code,' '),'',''''),
		@credit_limit = ISNULL(Customer.credit_limit, 0.00),
		@city = REPLACE(ISNULL(Customer.bill_to_city,' '),'',''''),
		@state = REPLACE(ISNULL(Customer.bill_to_state,' '),'',''''),
		@postal_code = REPLACE(ISNULL(Customer.bill_to_zip_code,' '),'',''''),
		@country = REPLACE(ISNULL(Customer.bill_to_country,' '),'',''''),
		@contact_email = REPLACE(ISNULL(Contact.email,' '),'','''')
	FROM Customer
	LEFT OUTER JOIN ContactXRef ON Customer.customer_id = ContactXRef.customer_id
		AND ContactXRef.primary_contact = 'T'
		AND ContactXRef.status = 'A'
	LEFT OUTER JOIN Contact ON ContactXRef.contact_id = Contact.contact_id
		AND Contact.contact_status = 'A'
	WHERE	Customer.customer_id = @customer_id

	-- Get attention name and phone from the CustomerBillingXContact record with attn_name_flag = 'T' for this customer
	SET @attention_name = ''
	SET @attention_phone = ''
	SET @attention_email = ''
	SELECT 	@attention_name = REPLACE(ISNULL(c.name,' '),'',''''),
		@attention_phone = REPLACE(ISNULL(c.phone,' '),'',''''),
		@attention_email = REPLACE(ISNULL(c.email,' '),'','''')
	FROM CustomerBillingXContact cbxc
	INNER JOIN Contact c ON cbxc.contact_id = c.contact_id
	WHERE cbxc.customer_id = @customer_id
	AND cbxc.billing_project_id = 0
	AND cbxc.attn_name_flag = 'T'

	---------------------------------------------------------
	-- Insert or Update each Finance database
	---------------------------------------------------------
	WHILE @db_count > 0
	BEGIN
		SET ROWCOUNT 1
		SELECT @db_name_epic = db_name_epic, @company_id = company_id
		FROM #finance_db WHERE process_flag = 0

		-- See if a customer record exists in this database
		SET @sql_cmd = 'UPDATE #finance_db SET customer_exists = 1 WHERE '
			+ 'process_flag = 0 AND EXISTS (SELECT 1 FROM ' 
			+ @server_epic + '.' + @db_name_epic + '.dbo.armaster WHERE customer_code = '
			+ '''' + @customer_code + ''')'
		EXECUTE (@sql_cmd)

		SELECT @customer_exists = customer_exists 
		FROM #finance_db WHERE process_flag = 0
		SET ROWCOUNT 0

		IF @debug = 1 PRINT @db_name_epic + ':  Customer exists for finance db:  ' + CONVERT(varchar(10), @customer_exists)


		-- Just update the customer record
		IF @customer_exists = 1
		BEGIN
			SET @sql_cmd = 'SET QUOTED_IDENTIFIER OFF SET ANSI_NULLS ON UPDATE '
				+ @server_epic + '.' + @db_name_epic + '.dbo.armaster SET '
				+ 'address_name = ''' + @address_name + ''' , '
				+ 'addr1 = ''' + @addr1 + ''' , '
				+ 'addr2 = ''' + @addr2 + ''' , '
				+ 'addr3 = ''' + @addr3 + ''' , '
				+ 'addr4 = ''' + @addr4 + ''' , '
				+ 'addr5 = ''' + @addr5 + ''' , '
				+ 'addr6 = ''' + @addr6 + ''' , '
				+ 'status_type = ' + CONVERT(varchar(10), @status_type) + ', '
				+ 'attention_name = ''' + @attention_name + ''', '
				+ 'attention_phone = ''' + @attention_phone + ''', '
				+ 'attention_email = ''' + @attention_email + ''', '
				+ 'contact_name = ''' + @contact_name + ''', '
				+ 'contact_phone = ''' + @contact_phone + ''', '
				+ 'phone_1 = ''' + @phone_1 + ''', '
				+ 'terms_code = ''' + @terms_code + ''', '
				+ 'territory_code = ''' + @territory_code + ''' , '
				+ 'salesperson_code = ''' + @salesperson_code + ''' , '
				+ 'credit_limit = ' + CONVERT(varchar(20), @credit_limit) + ', '
				+ 'modified_by_user_name = ''' + @user_code + ''', '
				+ 'modified_by_date = ''' + CONVERT(varchar(30), @today) + ''', '
				+ 'city = ''' + @city + ''', '
				+ 'state = ''' + @state + ''', '
				+ 'postal_code = ''' + @postal_code + ''', '
				+ 'country = ''' + @country + ''' , '
				+ 'contact_email = ''' + @contact_email + ''',  '
				+ 'trade_disc_percent = ' + CONVERT(varchar(20), @customer_discount) + ' '
			+ 'FROM  '
			+ @server_epic + '.' + @db_name_epic + '.dbo.armaster FinanceCustomer '
			+ 'WHERE FinanceCustomer.customer_code = ''' + @customer_code + ''' '

	-- 			+ 'posting_code = (SELECT ATC.posting_code FROM '
	-- 			+ @server_epic + '.' + @db_name_epic + '.dbo.artemcus ATC '
	-- 			+ 'WHERE ATC.template_code = ''arcodefs''), '


	-- 			+ 'posting_code = CASE ' + convert(varchar(2),@company_id) + ' WHEN 0 THEN ''' + @e01_posting_code + ''''
	-- 			+ ' ELSE (SELECT MIN(ProfitCenter.posting_code) FROM ProfitCenter '
	-- 			+ ' WHERE ProfitCenter.company_id = ' + convert(varchar(2),@company_id) +' ) END , '

		END

		-- Need to insert a new record
		ELSE
		BEGIN
			SET @sql_cmd = 'SET QUOTED_IDENTIFIER OFF SET ANSI_NULLS ON INSERT '
				+ @server_epic + '.' + @db_name_epic + '.dbo.armaster ( 
				customer_code,
				ship_to_code,
				address_name,
				short_name,
				addr1,
				addr2,
				addr3,
				addr4,
				addr5,
				addr6,
				addr_sort1,
				addr_sort2,
				addr_sort3,
				address_type,
				status_type,
				attention_name,
				attention_phone,
				contact_name,
				contact_phone,
				tlx_twx,
				phone_1,
				phone_2,
				tax_code,
				terms_code,
				fob_code,
				freight_code,
				posting_code,
				location_code,
				alt_location_code,
				dest_zone_code,
				territory_code,
				salesperson_code,
				fin_chg_code,
				price_code,
				payment_code,
				vendor_code,
				affiliated_cust_code,
				print_stmt_flag,
				stmt_cycle_code,
				inv_comment_code,
				stmt_comment_code,
				dunn_message_code,
				note,
				trade_disc_percent,
				invoice_copies,
				iv_substitution,
				ship_to_history,
				check_credit_limit,
				credit_limit,
				check_aging_limit,
				aging_limit_bracket,
				bal_fwd_flag,
				ship_complete_flag,
				resale_num,
				db_num,
				db_date,
				db_credit_rating,
				late_chg_type,
				valid_payer_flag,
				valid_soldto_flag,
				valid_shipto_flag,
				payer_soldto_rel_code,
				across_na_flag,
				date_opened,
				added_by_user_name,
				added_by_date,
				modified_by_user_name,
				modified_by_date,
				rate_type_home,
				rate_type_oper,
				limit_by_home,
				nat_cur_code,
				one_cur_cust,
				city,
				state,
				postal_code,
				country,
				remit_code,
				forwarder_code,
				freight_to_code,
				route_code,
				route_no,
				url,
				special_instr,
				guid,
				price_level,
				ship_via_code,
				ddid,
				so_priority_code,
				country_code,
				tax_id_num,
				ftp,
				attention_email,
				contact_email,
				dunning_group_id,
				consolidated_invoices,
				writeoff_code,
				delivery_days
			)
			SELECT 
				+ ''' + @customer_code + ''', '
				+ ''' '' AS ship_to_code, '
				+ '''' + @address_name + ''', '
				+ '''' + @short_name + ''', '
				+ '''' + @addr1 + ''', '
				+ '''' + @addr2 + ''', '
				+ '''' + @addr3 + ''', '
				+ '''' + @addr4 + ''', '
				+ '''' + @addr5 + ''', '
				+ '''' + @addr6 + ''', '
				+ ''' '' AS addr_sort1, '
				+ ''' '' AS addr_sort2, '
				+ ''' '' AS addr_sort3, '
				+ '0 AS address_type, '
				+ CONVERT(char(1), @status_type) + ', '
				+ '''' + @attention_name + ''', '
				+ '''' + @attention_phone + ''', '
				+ '''' + @contact_name + ''', '
				+ '''' + @contact_phone + ''', '
				+ ''' '' AS tlx_twx, '
				+ '''' + @phone_1 + ''', '
				+ ''' '' AS phone_2, '
				+ '''NOTAX'' AS tax_code, '
				+ '''' + @terms_code + ''', '
				+ ''' '' AS fob_code, '
				+ ''' '' AS freight_code, '
				+ ' posting_code = (SELECT ATC.posting_code FROM ' + @server_epic + '.' + @db_name_epic + '.dbo.artemcus ATC WHERE ATC.template_code = ''arcodefs'') ,'
				+ ''' '' AS location_code, '
				+ ''' '' AS alt_location_code, '
				+ ''' '' AS dest_zone_code, '
				+ '''' + @territory_code + ''', '
				+ '''' + @salesperson_code + ''', '
				+ ''' '' AS fin_chg_code, '
				+ ''' '' AS price_code, '
				+ ''' '' AS payment_code, '
				+ ''' '' AS vendor_code, '
				+ ''' '' AS affiliated_cust_code, '
				+ '0 AS print_stmt_flag, '
				+ ''' '' AS stmt_cycle_code, '
				+ ''' '' AS inv_comment_code, '
				+ ''' '' AS stmt_comment_code, '
				+ ''' '' AS dunn_message_code, '
				+ ''' '' AS note, '
				+ CONVERT(varchar(10), @customer_discount) + ', '
				+ '1 AS invoice_copies, '
				+ '0 AS iv_substitution, '
				+ '0 AS ship_to_history, '
				+ '0 AS check_credit_limit, '
				+ CONVERT(varchar(10), @credit_limit) + ', '
				+ '0 AS check_aging_limit, '
				+ '1 AS aging_limit_bracket, '
				+ '0 AS bal_fwd_flag, '
				+ '0 AS ship_complete_flag, '
				+ ''' '' AS resale_num, '
				+ ''' '' AS db_num, '
				+ '0 AS db_date, '
				+ '0 AS db_credit_rating, '
				+ '0 AS late_chg_type, '
				+ '1 AS valid_payer_flag, '
				+ '1 AS valid_soldto_flag, '
				+ '1 AS valid_shipto_flag, '
				+ ''' '' AS payer_soldto_rel_code, '
				+ '0 AS across_na_flag, '
				+ CONVERT(varchar(10),@julian_date) + ' AS date_opened, '
				+ '''' + @user_code + ''', '
				+ '''' + CONVERT(varchar(30), @today) + ''', '
				+ '''' + @user_code + ''', '
				+ '''' + CONVERT(varchar(30), @today) + ''', '
				+ '''BUY'' AS rate_type_home, '
				+ '''BUY'' AS rate_type_oper, '
				+ '0 AS limit_by_home, '
				+ '''USD'' AS nat_cur_code, '
				+ '0 AS one_cur_cust, '
				+ '''' + @city + ''', '
				+ '''' + @state + ''', '
				+ '''' + @postal_code + ''', '
				+ '''' + @country + ''', '
				+ ''' '' AS remit_code, '
				+ ''' '' AS forwarder_code, '
				+ ''' '' AS freight_to_code, '
				+ ''' '' AS route_code, '
				+ ''' '' AS route_no, '
				+ ''' '' AS url, '
				+ ''' '' AS special_instr, '
				+ ''' '' AS guid, '
				+ '''1'' AS price_level, '
				+ ''' '' AS ship_via_code, '
				+ 'NULL AS ddid, '
				+ 'NULL AS so_priority_code, '
				+ '''USA'' AS country_code, '
				+ ''' '' AS tax_id_num, '
				+ ''' '' AS ftp, '
				+ '''' + @attention_email + ''', '
				+ '''' + @contact_email + ''', '
				+ ''' '' AS dunning_group_id, '
				+ '0 AS consolidated_invoices, '
				+ '''WRITEOFF'' AS writeoff_code, '
				+ '0 AS delivery_days '
		END

		IF @debug = 1 print '@sql_cmd: '
		IF @debug = 1 print @sql_cmd

		EXECUTE (@sql_cmd)
		SET @success_count = @success_count + @@ROWCOUNT
		IF @debug = 1 PRINT '@success_count: ' + STR(@success_count)

		-- Go on to the next
		SET ROWCOUNT 1
		UPDATE #finance_db SET process_flag = 1 WHERE process_flag = 0
		SET ROWCOUNT 0
		SET @db_count = @db_count - 1
	END

	SELECT @db_count = COUNT(*) FROM #finance_db
	SELECT @return_code = @db_count - @success_count
END			-- IF @sync_cust_epicor = 1
ELSE
BEGIN
	SELECT @return_code = 0
END

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_customer_sync_finance] TO [EQAI]
    AS [dbo];

