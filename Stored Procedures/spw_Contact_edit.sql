/***************************************************************************************
Edits a contact's web-editable fields

10/1/2003 JPB	Created
11/15/2004 JPB  Changed CustomerContact -> Contact
5/16/2006 JPB Modified to use @Name if the newer @name fields are empty

Test Cmd Line: spw_Contact_edit, 1243, 2222, 'John Doe', 'Missing Person', 'john@doe.com', '1234567890', '1234567890', '1234567890', '1234567890', '123 My St', '', '', '', 'MyTown', 'MI', '48184', 'A', 'T', 'An unidentified person', '', ''
****************************************************************************************/
create procedure spw_Contact_edit
	@Contact_ID	int,
	@Customer_ID	int,
	@Name	varchar(40),
	@Title	varchar(20),
	@Email	varchar(60),
	@Phone	varchar(20),
	@Pager	varchar(20),
	@Fax	varchar(10),
	@Mobile	varchar(10),
	@Contact_Addr1	varchar(40),
	@Contact_Addr2	varchar(40),
	@Contact_Addr3	varchar(40),
	@Contact_Addr4	varchar(40),
	@Contact_City	varchar(40),
	@Contact_State	varchar(2),
	@Contact_Zip_Code	varchar(15),
	@Contact_Status char(1),
	@Email_Flag char(1),
	@Comments	text,
	@Personal	text,
	@Directions	text,
	@salutation varchar(10) = '',
	@first_name varchar(20) = '',
	@middle_name varchar(20) = '',
	@last_name varchar(20) = '',
	@suffix varchar(25) = ''
AS

	UPDATE Contact SET
	Name = case when (@salutation + @first_name + @middle_name + @last_name + @suffix) = '' then @Name 
	else rtrim(ltrim(replace(@salutation + ' ' + @first_name + ' ' + @middle_name + ' ' + @last_name + ' ' + @suffix, '  ', ' '))) end,
	Title = @Title,
	Email = @Email,
	Phone = @Phone,
	Pager = @Pager,
	Fax = @Fax,
	Mobile = @Mobile,
	Contact_Addr1 = @Contact_Addr1,
	Contact_Addr2 = @Contact_Addr2,
	Contact_Addr3 = @Contact_Addr3,
	Contact_Addr4 = @Contact_Addr4,
	Contact_City = @Contact_City,
	Contact_State = @Contact_State,
	Contact_Zip_Code = @Contact_Zip_Code,
	Contact_Status = @Contact_Status,
	Email_Flag = @Email_Flag,
	salutation = @salutation,
	first_name = @first_name,
	middle_name = @middle_name,
	last_name = @last_name,
	suffix = @suffix
	where contact_ID = @contact_ID

	UPDATE Contact SET
	Comments = @Comments
	where contact_ID = @contact_ID

	UPDATE Contact SET
	contact_personal_info = @Personal
	where contact_ID = @contact_ID

	UPDATE Contact SET
	contact_directions = @Directions
	where contact_ID = @contact_ID
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[spw_Contact_edit] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[spw_Contact_edit] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[spw_Contact_edit] TO [EQAI]
    AS [dbo];

