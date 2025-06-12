
Create Procedure sp_web_accountinfo (
	@customer_id	int,
	@contact_id		int
)
AS
/* ***********************************************************
Procedure    : sp_web_accountinfo
Database     : PLT_AI*
Created      : 8/22/2007 8:45 AM - Jonathan Broome
Description  : Used on Customers' "Account Information" page, this SP
	provides the information shown on the screen according to input contact_id & customer_id
	Returns 3 recordsets:
		Customer Info
		Billing Info
		Contact Info

Modifications:
8/22/2007 8:45 AM - JPB - Created.
2/28/2017	JPB		Removed NTSQLFinance references

Examples:

sp_web_accountinfo 888880, 10913	-- Should work
sp_web_accountinfo 888888, 100913	-- Should fail
sp_web_accountinfo 888888, -1		-- Should work

*********************************************************** */

	if @contact_id > 0
		if not exists (select customer_id from contactxref where customer_id = @customer_id and contact_id = @contact_id and status = 'A' and web_access = 'A' and type = 'C') 
			begin
				select 0 where 1 = 0
				select 0 where 1 = 0
				select 0 where 1 = 0
				return
			end

	-- Customer Info
	SELECT 
		customer_id,
		cust_name,
		cust_addr1,
		cust_addr2,
		cust_addr3,
		cust_addr4,
		cust_addr5,
		cust_city, 
		cust_state,
		cust_zip_code,
		cust_phone,
		cust_fax
	FROM 
		customer
	WHERE 
		customer_id = @customer_id

	-- Billing Info		
	SELECT 
		bill_to_cust_name,
		bill_to_addr1 addr1,
		bill_to_addr2 addr2,
		bill_to_addr3 addr3,
		bill_to_addr4 addr4,
		bill_to_addr5 addr5,
		ltrim(rtrim(isnull(bill_to_city + ', ','') + ' ' + isnull(bill_to_state, '') + '  ' + isnull(bill_to_zip_code, '') + ' ' + isnull(bill_to_country, ''))) bill_to_addr6 ,
		null as attention_name,
		null as attention_phone,
		null as phone_1,
		null as phone_2,
		cust_name as address_name
	FROM 
		customer 
	WHERE 
		customer_id = @customer_id
		

	-- Contact Info
	SELECT DISTINCT 
		co.contact_id, 
		co.name, 
		co.email, 
		co.phone, 
		co.fax, 
		co.pager, 
		co.mobile, 
		(
			CASE WHEN EXISTS (
				SELECT
					contact_id
				FROM
					contactxref
				WHERE
					customer_id = cu.customer_id
					AND contact_id = co.contact_id
					AND status = 'A'
					AND web_access = 'A'
					AND type = 'C'
				)
			THEN
				'yes'
			ELSE
				'no'
			END
		) as b2b_account,
		'' as primary_company_list 
		from customer cu 
		inner join contactxref cxc on cu.customer_id = cxc.customer_id and cxc.type='C' and cxc.status = 'A'
		inner join contact co on cxc.contact_id = co.contact_id and co.contact_status = 'A' 
		where 
			cu.customer_id = @customer_id
		order by 
			co.name


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_web_accountinfo] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_web_accountinfo] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_web_accountinfo] TO [EQAI]
    AS [dbo];

