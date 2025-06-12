CREATE PROCEDURE sp_pa_waste_stream_notification
	@profile_id		int,
	@approval_code	Varchar(15),
	@company_id		int,
	@profit_ctr_id  int,
	@volume			Varchar(40),
	@frequency		Varchar(40),
	@coordinator	Varchar(50),
	@title			Varchar(50),
	@phone			Varchar(20),
	@basis_1		Char(1),
	@basis_2		Char(1),
	@basis_3		Char(1),
	@basis_4		Char(1)	
AS
/**************************************************************************
Filename:	L:\Apps\SQL\Plt_AI\sp_pa_waste_stream_notification.sql
Load to plt_ai (NTSQL1)

05/21/2010 KAM	Created
06/03/2010 KAM	Added Phone to the input and changed how call_phone is set.
06/08/2010 KAM	Increased waste_type to varchar(50) to match Profile table.
07/01/2011 SK	Modified to always fetch the Contact name & contact_phone from Generators primary contact
				Leave contact info blank if generator is 'VARIOUS'
09/02/2014 AM   Increased waste_code_list to varchar(8000)to print all waste codes on Profile.Pennsylvania Waste Notification screen.
10/31/2018 AM   EQAI-56253 - Attention Name Change (PADEP) - PA Waste Stream Notification Letter

sp_pa_waste_stream_notification 68029,'120603BAF',2,21,'50 tons','365','kam','sir','(839) 876-9876 x 263','T','T','T','T'
**************************************************************************/
SET NOCOUNT ON

DECLARE	@letter_date					datetime,
		@delivery_method				varchar(50),
		@to_name						varchar(50),
		@to_dept_1						varchar(50),
		@to_dept_2						varchar(50),
		@to_street_addr					varchar(50),
		@to_city						varchar(50),
		@to_state						char(2),
		@to_zip							varchar(10),
		@gen_id							int,
		@gen_name						varchar(50),
		@gen_addr1						varchar(40),
		@gen_addr2						varchar(40),
		@gen_city						varchar(50),
		@gen_state						char(2),
		@gen_zip						varchar(10),		
		@gen_epa_id						varchar(12),
		@gen_contact					varchar(40),
		@gen_contact_phone				varchar(20),
		@waste_type						varchar(50),
		@waste_code_list				varchar(8000),
		@waste_code						varchar(10),
		@permit_number					varchar(20),
		@profit_ctr_name				varchar(50),
		@call_phone						varchar(25),
		@contact_id						int				


Select @letter_date = GETDATE()
Select @delivery_method = 'Via UPS Ground Service'
Select @to_name = 'Mr. Jess Fultz'  --John Spang
Select @to_dept_1 = 'PA Department of Environmental Protection'
Select @to_dept_2 = 'Harrisburg Regional Office'
Select @to_street_addr = '909 Elmerton Avenue'
Select @to_city = 'Harrisburg'
Select @to_state = 'PA'
Select @to_zip = '17110-8200'

if LEN(@phone) < 1
	Select @call_phone = '(800) 878-1618'
Else
	Select @call_phone = @phone
	
Select	@gen_id = Generator.generator_id, 
		@gen_name = Generator.generator_name,
		@gen_addr1 = Generator.generator_address_1,
		@gen_addr2 = Generator.generator_address_2,
		@gen_city = Generator.generator_city,
		@gen_state = Generator.generator_state,
		@gen_zip = Generator.generator_zip_code,
		@gen_epa_id = Generator.EPA_ID,
		@gen_contact = CASE Generator.EPA_ID WHEN 'VARIOUS' THEN ''
											  ELSE ( select c.name from Contact c, ContactXRef x where c.contact_id = x.contact_id and x.type = 'G' and x.primary_contact = 'T' and x.generator_id = Profile.generator_id ) END,
		@gen_contact_phone = CASE Generator.EPA_ID WHEN 'VARIOUS' THEN ''
													ELSE (select c.phone from Contact c, ContactXRef x where c.contact_id = x.contact_id and x.type = 'G' and x.primary_contact = 'T' and x.generator_id = Profile.generator_id ) END,
		@waste_type = Profile.approval_desc,
		@waste_code = Profile.waste_code
From    Profile 
		Inner Join Generator on Profile.generator_id = Generator.generator_id
		Where Profile.profile_id = @profile_id
		
		
		
Select  @waste_code_list = 	COALESCE(@waste_code_list + ', ', '') + pwc.waste_code
	FROM ProfileWasteCode pwc 
	WHERE pwc.profile_id = @profile_id
	
	
Select	@profit_ctr_name = profit_ctr_name,
		@permit_number = EPA_ID
From ProfitCenter
Where company_ID = @company_id and
		profit_ctr_ID = @profit_ctr_id
		
		
Select	@profit_ctr_name = dba_name
From Company
Where company_ID = @company_id 
			
		
--Select @contact_id = IsNull(contact_id,0) from profile where profile_id = @profile_id		
--If @contact_id > 0 
--	Select	@gen_contact = name, @gen_contact_phone = phone from Contact where contact_ID = @contact_id 		

Select 	@letter_date,
		@delivery_method,
		@to_name,
		@to_dept_1,
		@to_dept_2,
		@to_street_addr,
		@to_city,
		@to_state,
		@to_zip,
		@gen_id,
		@gen_name,
		@gen_addr1,
		@gen_addr2,
		@gen_epa_id,
		@gen_contact,
		@gen_contact_phone,
		@volume,
		@frequency,
		@waste_type,
		@waste_code_list,
		@coordinator,
		@title,
		@gen_city,
		@gen_state,
		@gen_zip,
		@profit_ctr_name,
		@permit_number,
		@call_phone,
		@basis_1,
		@basis_2,
		@basis_3,
		@basis_4
GO

GRANT EXECUTE
    ON OBJECT::[dbo].[sp_pa_waste_stream_notification] TO [EQAI]
    AS [dbo];
GO

