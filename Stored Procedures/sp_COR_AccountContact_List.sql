USE [PLT_AI]
GO

CREATE PROCEDURE [dbo].[sp_COR_AccountContact_List] 
	@web_userid nvarchar(150),
	@account_type NVARCHAR(1) = '',
	@contact_company NVARCHAR(150) = '',
	@contact_id int = -1,
	@name nvarchar(100) = '',
	@email NVARCHAR(100) = '',
	@phone NVARCHAR(20) = '',
	@title NVARCHAR(150) = '',
	@customer_id_list varchar(255)='',  /* Added 2019-07-17 by AA */
    @generator_id_list varchar(255)=''  /* Added 2019-07-17 by AA */,
	@page INT = 1,
	@perpage INT = 10
AS

/*

	Created By: Dinesh
	CreatedOn: 10-Oct-2019
	Modified By : Sathiya Moorthi
	Modified on : 23-Aug-2023
	Description: list out all the contact information against the user

	Ticket			: 70844
	Change		: Contact table Phone size 20 so changed @tblUserContacts table declartion in 20 characters 

	Exec sp_COR_AccountContact_List 
		@web_userid = 'nyswyn100',
		@account_type = 'C',
		@contact_id = '',
		@contact_company = '',
		@name  = '',
		@email  = '',
		@phone  = '',
		@title  = '',
		@customer_id_list = '',  /* Added 2019-07-17 by AA */
		@generator_id_list ='',
		@page = 1,
		@perpage = 999999 


*/

BEGIN
	SET NOCOUNT ON;
declare
	@i_web_userid		varchar(100) = @web_userid
	, @i_account_type	varchar(1) = @account_type
	, @i_company varchar(150) = @contact_company
	, @i_name varchar(100) = @name
	, @i_email varchar(100) = @email
	, @i_phone varchar(20) = @phone
	, @i_title varchar(150) = @title
	, @i_customer_id_list varchar(255) = isnull(@customer_id_list, '')
	, @i_generator_id_list varchar(255) = isnull(@generator_id_list, '')
	, @i_page int = @page
	, @i_perpage int = @perpage
	, @i_contact_id int
	, @i_contact_id_search int = @contact_id

select top 1 @i_contact_id = contact_id from CORcontact where web_userid = @i_web_userid

declare @tblUserContacts Table
(
	type nvarchar(50),
	contact_id int,
	company nvarchar(150),
	name nvarchar(150),
	email nvarchar(100),
	phone varchar(20),
	title nvarchar(200)	
)		



	declare @generator_filter table (generator_id int)
	declare @customer_filter table (customer_id int)
	declare @contact_filter table (contact_id int, customer_id int, generator_id int, result_type varchar(40))
	
	insert @generator_filter select convert(int, value) from STRING_SPLIT(@generator_id_list, ',') where value <> ''
	insert @customer_filter select convert(int, value) from STRING_SPLIT(@customer_id_list, ',') where value <> ''

	-- combined
	INSERT @contact_filter
SELECT x.contact_id, x.customer_id, x.generator_id, 'Both Customer and Generator'
FROM contactxref x
JOIN Contact c ON x.contact_id = c.contact_id AND c.contact_status = 'A' AND x.status = 'A'
JOIN contactxref cust ON x.contact_id = cust.contact_id AND cust.customer_id IN (SELECT customer_id FROM @customer_filter) AND cust.status = 'A' AND cust.type = 'C' 
JOIN contactxref gen ON x.contact_id = gen.contact_id AND gen.generator_id IN (SELECT generator_id FROM @generator_filter) AND gen.status = 'A' AND gen.type = 'G'

INSERT INTO @contact_filter (contact_id, customer_id, generator_id, result_type)
SELECT
    x.contact_id,
    x.customer_id,
    x.generator_id,
    CASE
        WHEN x.generator_id IS NOT NULL THEN 'Generator Only'
        WHEN x.customer_id IS NOT NULL THEN 'Customer Only'
    END AS result_type
FROM contactxref x
JOIN Contact c ON x.contact_id = c.contact_id AND c.contact_status = 'A' AND x.status = 'A'
LEFT JOIN (
    SELECT DISTINCT contact_id
    FROM contactxref
    WHERE generator_id IN (SELECT generator_id FROM @generator_filter) AND status = 'A' AND type = 'G'
) AS gen_contacts ON x.contact_id = gen_contacts.contact_id
LEFT JOIN (
    SELECT DISTINCT contact_id
    FROM contactxref
    WHERE customer_id IN (SELECT value FROM STRING_SPLIT(@customer_id_list, ',') WHERE RTRIM(LTRIM(value)) <> '') AND status = 'A' AND type = 'C'
) AS cust_contacts ON x.contact_id = cust_contacts.contact_id
WHERE gen_contacts.contact_id IS NOT NULL OR cust_contacts.contact_id IS NOT NULL;





INSERT INTO @tblUserContacts
SELECT DISTINCT
    CASE WHEN x.type = 'C' THEN 'Customer' ELSE 'Generator' END AS [Type],
    c.contact_id,
    c.contact_company,
    c.name,
    c.email,
    c.phone,
    c.title
FROM ContactXref x
INNER JOIN Contact c ON x.contact_id = c.contact_id
LEFT JOIN ContactCORGeneratorBucket g ON x.generator_id = g.generator_id AND g.contact_id = @i_contact_id
LEFT JOIN ContactCORCustomerBucket cu ON x.customer_id = cu.customer_id AND cu.contact_id = @i_contact_id
LEFT JOIN (
    SELECT DISTINCT contact_id
    FROM contactxref
    WHERE generator_id IN (SELECT generator_id FROM @generator_filter) AND status = 'A' AND type = 'G'
) AS gen_contacts ON x.contact_id = gen_contacts.contact_id
LEFT JOIN (
    SELECT DISTINCT contact_id
    FROM contactxref
    WHERE customer_id IN (SELECT value FROM STRING_SPLIT(@customer_id_list, ',') WHERE RTRIM(LTRIM(value)) <> '') AND status = 'A' AND type = 'C'
) AS cust_contacts ON x.contact_id = cust_contacts.contact_id
LEFT JOIN CORContactXRole cr ON cr.contact_id = x.contact_id
LEFT JOIN cor_db.[dbo].[RolesRef] roles ON cr.roleid = roles.roleid AND roles.roleName LIKE '%internal user%'
WHERE
    c.contact_status = 'A' AND x.status = 'A'
    AND (gen_contacts.contact_id IS NOT NULL OR cu.customer_id IS NOT NULL)
    AND (@i_account_type = '' OR x.type = @i_account_type)
    AND (ISNULL(@i_company, '') = '' OR c.contact_company LIKE '%' + @i_company + '%')
    AND (ISNULL(@i_name, '') = '' OR c.name LIKE '%' + @i_name + '%')
    AND (ISNULL(@i_email, '') = '' OR c.email LIKE '%' + @i_email + '%')
    AND (ISNULL(@i_phone, '') = '' OR c.phone LIKE '%' + @i_phone + '%')
    AND (ISNULL(@i_title, '') = '' OR c.title LIKE '%' + @i_title + '%')
    AND (ISNULL(@i_contact_id_search, '') = '' OR @i_contact_id_search = -1 OR c.contact_id = @i_contact_id_search)
    AND roles.roleId IS NULL
    AND (NOT EXISTS (SELECT 1 FROM @contact_filter) OR x.contact_id IN (SELECT contact_id FROM @contact_filter));


	
	select  *, (select count(*) from @tblUserContacts) as total_count from @tblUserContacts
	order by name
	OFFSET @i_perpage * (@i_page - 1) ROWS
	FETCH NEXT @i_perpage ROWS ONLY;
	    
return 0
END

GO
 
	GRANT EXECUTE ON [dbo].[sp_COR_AccountContact_List] TO COR_USER;

GO