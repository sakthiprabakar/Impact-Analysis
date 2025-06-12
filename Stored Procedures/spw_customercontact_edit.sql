
/***************************************************************************************
Edits a customer contact's web-editable fields

10/1/2003 JPB	Created
Test Cmd Line: spw_customercontact_edit, 1243, 2222, 'John Doe', 'Missing Person', 'john@doe.com', '1234567890', '1234567890', '1234567890', '1234567890', '123 My St', '', '', '', 'MyTown', 'MI', '48184', 'A', 'T', 'An unidentified person', '', ''
****************************************************************************************/
create procedure spw_customercontact_edit
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
	@Directions	text
AS
	
	UPDATE CUSTOMERCONTACT SET
	Name = @Name,
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
	Email_Flag = @Email_Flag
	where contact_ID = @contact_ID
	
	UPDATE CUSTOMERCONTACT SET
	Comments = @Comments
	where contact_ID = @contact_ID
	
	UPDATE CUSTOMERCONTACT SET
	contact_personal_info = @Personal
	where contact_ID = @contact_ID
	
	UPDATE CUSTOMERCONTACT SET
	contact_directions = @Directions
	where contact_ID = @contact_ID
	

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[spw_customercontact_edit] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[spw_customercontact_edit] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[spw_customercontact_edit] TO [EQAI]
    AS [dbo];

