
/***************************************************************************************
Updates Customer/Generator Information

09/15/2003 JPB	Created
01/07/2005 JPB  Altered to handle generator_id
loads on plt_ai
Test Cmd Line: spw_customer_edit 2222, 'category', 'website', 'directions', 'A', 'T', 'jonathan', 'MyAddress', '', '', '', 'MyTown', 'ST', '12345'
****************************************************************************************/
create procedure spw_customer_edit
	@Customer_ID	int,
	@Cust_Category	varchar(30),
	@Cust_Website	varchar(50),
	@Cust_Directions	text,
	@Designation	char(1),
	@Customer_Type	varchar(10),
	@Mail_Flag		char(1),
	@Generator_Flag	char(1),
	@By				varchar(10),
	@Cust_Addr1		varchar(40),
	@Cust_Addr2		varchar(40),
	@Cust_Addr3		varchar(40),
	@Cust_Addr4		varchar(40),
	@Cust_City		varchar(40),
	@Cust_State		varchar(2),
	@Cust_Zip_Code		varchar(10)
AS

	declare @Old_Category	varchar(30)
	declare @Old_Website	varchar(50)
	declare @Old_Directions	varchar(8000)
	declare @Old_Designation char(1)
	declare @Old_Mail_Flag char(1)
	declare @Old_Customer_Type varchar(10)
	declare @Old_GeneratorFlag char(1)
	declare @Changes		varchar(8000)
	declare @Old_Cust_Addr1		varchar(40)
	declare @Old_Cust_Addr2		varchar(40)
	declare @Old_Cust_Addr3		varchar(40)
	declare @Old_Cust_Addr4		varchar(40)
	declare @Old_Cust_City		varchar(40)
	declare @Old_Cust_State		varchar(2)
	declare @Old_Cust_Zip_Code	varchar(15)

	select @Old_Category = isnull(Cust_Category, ''),
	@Old_Website = isnull(Cust_Website, ''),
	@Old_Directions = isnull(convert(varchar(8000), cust_directions), ''),
	@Old_Designation = isnull(Designation, ''),
	@Old_Mail_Flag = isnull(Designation, ''),
	@Old_Customer_Type = isnull(customer_type, ''),
	@Old_GeneratorFlag = isnull(Generator_Flag, ''),
	@Old_Cust_Addr1 = isnull(Cust_Addr1, ''),
	@Old_Cust_Addr2 = isnull(Cust_Addr2, ''),
	@Old_Cust_Addr3 = isnull(Cust_Addr3, ''),
	@Old_Cust_Addr4 = isnull(Cust_Addr4, ''),
	@Old_Cust_City = isnull(Cust_City, ''),
	@Old_Cust_State = isnull(Cust_State, ''),
	@Old_Cust_Zip_Code = isnull(Cust_Zip_Code, '')
	from customer where customer_id = @Customer_ID

	set @Changes = ''

	print @Changes
	if UPPER(@Old_Category) <> UPPER(@Cust_Category)
		set @Changes = @Changes + '(FIELD) EQAI cust_category (FROM) ' + @Old_Category + ' (TO) ' + @Cust_Category + '; '
	if UPPER(@Old_Website) <> UPPER(@Cust_Website)
		set @Changes = @Changes + '(FIELD) EQAI cust_website (FROM) ' + @Old_Website + ' (TO) ' + @Cust_Website + '; '
	if UPPER(@Old_Directions) <> UPPER(convert(varchar(8000), @Cust_Directions))
		set @Changes = @Changes + '(FIELD) EQAI cust_directions (FROM) ' + @Old_Directions + ' (TO) ' + convert(varchar(8000),@Cust_Directions) + '; '
	if UPPER(@Old_Designation ) <> UPPER(@Designation)
		set @Changes = @Changes + '(FIELD) EQAI designation (FROM) ' + @Old_Designation + ' (TO) ' + @Designation + '; '
	if UPPER(@Old_Mail_Flag ) <> UPPER(@Mail_Flag)
		set @Changes = @Changes + '(FIELD) EQAI Mail_Flag (FROM) ' + @Old_Mail_Flag + ' (TO) ' + @Mail_Flag + '; '
	if UPPER(@Old_Customer_Type ) <> UPPER(@Customer_Type)
		set @Changes = @Changes + '(FIELD) EQAI Customer_Type (FROM) ' + @Old_Customer_Type + ' (TO) ' + @Customer_Type + '; '
	if UPPER(@Old_GeneratorFlag) <> UPPER(@Generator_Flag)
		set @Changes = @Changes + '(FIELD) EQAI generator_flag (FROM) ' + @Old_GeneratorFlag + ' (TO) ' + @Generator_Flag + '; '

	if @Customer_ID >= 90000000
	BEGIN
		if UPPER(@Old_Cust_Addr1) <> UPPER(@Cust_Addr1)
			set @Changes = @Changes + '(FIELD) EQAI Cust_Addr1 (FROM) ' + @Old_Cust_Addr1 + ' (TO) ' + @Cust_Addr1 + '; '
		if UPPER(@Old_Cust_Addr2) <> UPPER(@Cust_Addr2)
			set @Changes = @Changes + '(FIELD) EQAI Cust_Addr2 (FROM) ' + @Old_Cust_Addr2 + ' (TO) ' + @Cust_Addr2 + '; '
		if UPPER(@Old_Cust_Addr3) <> UPPER(@Cust_Addr3)
			set @Changes = @Changes + '(FIELD) EQAI Cust_Addr3 (FROM) ' + @Old_Cust_Addr3 + ' (TO) ' + @Cust_Addr3 + '; '
		if UPPER(@Old_Cust_Addr4) <> UPPER(@Cust_Addr4)
			set @Changes = @Changes + '(FIELD) EQAI Cust_Addr4 (FROM) ' + @Old_Cust_Addr4 + ' (TO) ' + @Cust_Addr4 + '; '
		if UPPER(@Old_Cust_City) <> UPPER(@Cust_City)
			set @Changes = @Changes + '(FIELD) EQAI Cust_City (FROM) ' + @Old_Cust_City + ' (TO) ' + @Cust_City + '; '
		if UPPER(@Old_Cust_State) <> UPPER(@Cust_State)
			set @Changes = @Changes + '(FIELD) EQAI Cust_State (FROM) ' + @Old_Cust_State + ' (TO) ' + @Cust_State + '; '
		if UPPER(@Old_Cust_Zip_Code) <> UPPER(@Cust_Zip_Code)
			set @Changes = @Changes + '(FIELD) EQAI Cust_Zip_Code (FROM) ' + @Old_Cust_Zip_Code + ' (TO) ' + @Cust_Zip_Code + '; '
	END

	if LEN(@Changes) > 0
	begin
		Update Customer set cust_category = @Cust_Category,
		cust_website = @Cust_Website,
		cust_directions = @Cust_Directions,
		designation = @Designation,
		mail_flag = @mail_flag,
		customer_type = @Customer_Type,
		generator_flag = @Generator_Flag,
		modified_by = @By,
		date_modified = GETDATE()
		where customer_ID = @Customer_ID

		if @Customer_ID >= 90000000
		BEGIN
			Update Customer set
			Cust_Addr1 = @Cust_Addr1,
			Cust_Addr2 = @Cust_Addr2,
			Cust_Addr3 = @Cust_Addr3,
			Cust_Addr4 = @Cust_Addr4,
			Cust_City = @Cust_City,
			Cust_State = @Cust_State,
			Cust_Zip_Code = @Cust_Zip_Code
			where customer_ID = @Customer_ID
		END

		declare @noteID int
		exec @noteID = sp_sequence_next 'CustomerNote.Note_ID'
		insert into customernote (customer_id, note_id, note, contact_date, note_type, contact_type, added_from_company, modified_by, date_added, date_modified, contact_id, status, added_by, subject, action_type, recipient, send_email_date, cc_list, note_group_id)
		values (@customer_id, @noteID, @Changes, GETDATE(), 'AUDIT', 'AUDIT', 2, @By, GETDATE(), GETDATE(), NULL, 'C', @By, NULL, 'None', NULL, NULL, NULL, NULL)
	end
	set nocount off

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[spw_customer_edit] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[spw_customer_edit] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[spw_customer_edit] TO [EQAI]
    AS [dbo];

