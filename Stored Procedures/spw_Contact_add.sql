
/***************************************************************************************
Adds a Contact record, Connects it to CustomerXContact

09/15/2003 JPB	Created
11/15/2004 JPB  Changed CustomerContact -> Contact

Test Cmd Line: spw_Contact_add 2222, 'John Doe', 'Mr', 'john@doe.com', '1234567890', '1234567890', '1234567890', '1234567890', '123 My St', '', '', '', 'MyTown', 'ST', '12345-3456', 'A', 'T', 'This is a test contact', 'He likes testing', 'Turn Around and you''re there'
****************************************************************************************/
create procedure spw_Contact_add
	@customer_id	int,
	@name	varchar(40),
	@title	varchar(20),
	@email	varchar(60),
	@phone	varchar(20),
	@pager	varchar(20),
	@fax	varchar(10),
	@mobile	varchar(10),
	@contact_addr1	varchar(40),
	@contact_addr2	varchar(40),
	@contact_addr3	varchar(40),
	@contact_addr4	varchar(40),
	@contact_city	varchar(40),
	@contact_state	varchar(2),
	@contact_zip_code	varchar(15),
	@contact_status char(1),
	@email_flag char(1),
	@comments	text,
	@personal	text,
	@directions	text,
	@salutation varchar(10) = '',
	@first_name varchar(20) = '',
	@middle_name varchar(20) = '',
	@last_name varchar(20) = '',
	@suffix varchar(25) = ''
as

	set nocount on
	declare @intNextID	int
	declare @strCompany varchar(40)
	exec @intNextID = sp_sequence_next 'Contact.Contact_ID'
	begin transaction
	select top 1 @strcompany = cust_name from customer where customer_ID = @customer_ID

	insert into Contact (
	contact_ID, contact_company, name,
	title, phone, fax, pager, mobile, comments, email, date_added, contact_addr1, contact_addr2, contact_addr3, contact_addr4,
	contact_city, contact_state, contact_zip_code, contact_status, email_flag,
	contact_personal_info, contact_directions, salutation, first_name, middle_name, last_name, suffix
	) values (
	@intNextID, @strcompany, rtrim(ltrim(replace(@salutation + ' ' + @first_name + ' ' + @middle_name + ' ' + @last_name + ' ' + @suffix, '  ', ' '))),
	@title, @phone, @fax, @pager, @mobile, @comments, @email,
	getdate(), @contact_addr1, @contact_addr2, @contact_addr3, @contact_addr4,
	@contact_city, @contact_state, @contact_zip_code, @contact_status, @email_flag,
	@personal, @directions, @salutation, @first_name, @middle_name, @last_name, @suffix
	)
	insert into customerxContact
	(customer_ID, contact_ID, status)
	values
	(@customer_ID, @intnextID, @contact_status)
	commit
	set nocount off



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[spw_Contact_add] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[spw_Contact_add] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[spw_Contact_add] TO [EQAI]
    AS [dbo];

