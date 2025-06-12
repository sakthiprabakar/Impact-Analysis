USE [PLT_AI]
GO
/***************************************************************************************************/
DROP PROCEDURE IF EXISTS [sp_Validate_Profile_Section_A]
GO
CREATE PROCEDURE  [dbo].[sp_Validate_Profile_Section_A]
	-- Add the parameters for the stored procedure here
		@profile_id int 
AS
/* ******************************************************************

	Updated By		: Pasupathi P
	Updated On		: 24th Jul 2024
	Type			: Stored Procedure
	Object Name		: [sp_Validate_Profile_Section_A]
	Related Ticket  : 92207

	Procedure to validate Section A required fields and Update the Status of section

inputs 
	
	@profile_id



Samples:
 EXEC [sp_Validate_Profile_Section_A] @profile_id
 EXEC [sp_Validate_Profile_Section_A] 569059

 exec sp_Validate_Profile_Section_A 699456
 

****************************************************************** */
BEGIN
	DECLARE @ValidColumnNullCount INTEGER,@TotalValidColumn INTEGER,@Checking INTEGER;
	
	DECLARE @EPAIDValue VARCHAR(12),@GenMailzip VARCHAR(10),@Genzip VARCHAR(10),@GenMailCountry VARCHAR(10),@GenCountry VARCHAR(3),
	@CustName VARCHAR(75),@Custzip VARCHAR(10),@CustCountry VARCHAR(3),@generator_name VARCHAR(40),@generator_address_1 VARCHAR(85),
	@generator_city VARCHAR (40),@generator_phone VARCHAR (20),@gen_mail_addr1 VARCHAR (85),@gen_mail_city VARCHAR (40),
	@tech_contact_name VARCHAR (40),@tech_contact_phone VARCHAR (20), @inv_contact_name VARCHAR (40),@inv_contact_phone VARCHAR (20),
	@inv_contact_email VARCHAR (50),@purchase_order VARCHAR (20),@modified_by VARCHAR (60),	@tech_cont_email VARCHAR (50),
	@cust_addr1 VARCHAR (40),@cust_city VARCHAR (40),@GenTypeId INT,@GenId INT,@CustId INT,@NAICS_code INT, @cust_state CHAR (2),
	@gen_mail_state CHAR (2),@generator_state CHAR (2), @po_required CHAR (1),@isNewGeneratorToValidate BIT,@isNewCustomerToValidate BIT;
	
	
	SET @TotalValidColumn = 22	


	/* Task 19272: PO required ON COR2 causing billing issues */
	-- Using temp tables (#) instead of table variables (@)
	CREATE TABLE #invalid_po (value VARCHAR(20));

	INSERT INTO #invalid_po VALUES 
		('TBD'),
		('To Be Determined'),
		('Pending'),
		('Pend'),
		('Per'),
		('Per Shipment'),
		('Each'),
		('Varies'),
		('Various'),
		('T.B.D.'),
		('. '),
		('*space*'),
		('*date*'),
		('Multiple'),
		('-'),
		('N/A'),
		('NA'),
		('PO'),
		('P.O.'),
		('TBA'),
		('T.B.A.')	


	SELECT	@isNewGeneratorToValidate = (CASE WHEN (p.generator_id = -1) THEN 1 ELSE 0 END),
			@isNewCustomerToValidate = (CASE WHEN (ISNULL(p.customer_id,0) = 0) THEN 1 ELSE 0 END),
			@generator_name = g.generator_name,
			@EPAIDValue=g.EPA_ID,
			@GenTypeId=g.generator_type_ID, 
			@CustId = cus.customer_Id,
			@CustName=cus.bill_to_cust_name,
			@Custzip = cus.bill_to_zip_code,
			@CustCountry = cus.bill_to_country,
			@GenId = g.generator_id,
			@Genzip = g.generator_zip_code,
			@GenCountry = g.generator_country,
			@GenMailzip = g.gen_mail_zip_code,
			@GenMailCountry = g.gen_mail_country,
			@generator_address_1=g.generator_address_1,
			@generator_city = g.generator_city,
			@generator_state = g.generator_state,
			@generator_phone = g.generator_phone,
			@gen_mail_addr1=g.gen_mail_addr1,
			@gen_mail_city = g.gen_mail_city,
			@gen_mail_state = g.gen_mail_state,
			@tech_contact_name = tech_contact.contact_name,
			@tech_contact_phone = (CASE LTRIM(tech_contact.contact_phone) 
									WHEN '' THEN tech_contact.contact_mobile  
									ELSE ISNULL(tech_contact.Contact_phone,tech_contact.contact_mobile) END),
			@tech_cont_email = ISNULL(tech_contact.contact_email, ''),
			@NAICS_code = g.NAICS_code,
			@cust_addr1 = cus.cust_addr1,
			@cust_city = cus.cust_city,
			@cust_state = cus.cust_state,
			@inv_contact_name = invoice_contact.contact_name,
			@inv_contact_phone = CASE LTRIM(invoice_contact.contact_phone) 
									WHEN '' THEN invoice_contact.contact_mobile  
									ELSE ISNULL(invoice_contact.Contact_phone,invoice_contact.contact_mobile) END,
			@inv_contact_email = invoice_contact.contact_email,
			@po_required =p.po_required_from_form,
			@purchase_order = p.purchase_order,
			@modified_by = p.modified_by
			FROM [Profile] p
			JOIN generator AS g 
				ON p.generator_id = g.generator_id 
			JOIN customer AS cus 
				ON p.customer_id = cus.customer_id 
			OUTER APPLY(SELECT TOP 1 * 
							FROM ProfileContact AS contact 
							WHERE p.profile_id =  contact.profile_id  
							AND contact.contact_type='Technical' ORDER BY contact.profile_id )tech_contact
			OUTER APPLY(SELECT TOP 1 * 
							FROM ProfileContact AS contact 
							WHERE p.profile_id =  contact.profile_id  
							AND contact.contact_type='Invoicing'  ORDER BY contact.profile_id )invoice_contact
			WHERE p.profile_id = @profile_id

			
	SET  @ValidColumnNullCount = (SELECT  (
		(CASE WHEN ISNULL(@generator_name, '') = '' THEN 1 ELSE 0 END)
		+ (CASE WHEN ISNULL(@generator_address_1, '') = '' AND @isNewGeneratorToValidate = 1 THEN 1 ELSE 0 END)
		+ (CASE WHEN ISNULL(@generator_city, '') = '' AND @isNewGeneratorToValidate = 1 THEN 1 ELSE 0 END)
		+ (CASE WHEN ISNULL(@generator_state, '') = '' AND @isNewGeneratorToValidate = 1 THEN 1 ELSE 0 END)
		+ (CASE WHEN ISNULL(@Genzip, '') = '' AND @isNewGeneratorToValidate = 1 THEN 1 ELSE 0 END)
		+ (CASE WHEN ISNULL(@GenCountry, '') = '' AND @isNewGeneratorToValidate = 1  THEN 1 ELSE 0 END)
		+ (CASE WHEN ISNULL(@generator_phone, '') = '' AND @isNewGeneratorToValidate = 1 THEN 1 ELSE 0 END)
		+ (CASE WHEN ISNULL(@gen_mail_addr1, '') = '' AND @isNewGeneratorToValidate = 1 THEN 1 ELSE 0 END)
		+ (CASE WHEN ISNULL(@gen_mail_city, '') = '' AND @isNewGeneratorToValidate = 1 THEN 1 ELSE 0 END)
		+ (CASE WHEN ISNULL(@gen_mail_state, '') = '' AND @isNewGeneratorToValidate = 1  THEN 1 ELSE 0 END)
		+ (CASE WHEN ISNULL(@GenMailzip, '') = '' AND @isNewGeneratorToValidate = 1 THEN 1 ELSE 0 END)
		+ (CASE WHEN ISNULL(@GenMailCountry, '') = '' AND @isNewGeneratorToValidate = 1 THEN 1 ELSE 0 END)
		+ (CASE WHEN ISNULL(@tech_contact_name, '') = '' AND (@isNewGeneratorToValidate = 1 or @GenId > 0)  THEN 1 ELSE 0 END)
		+ (CASE WHEN ISNULL(@tech_contact_phone,'') ='' AND  (@isNewGeneratorToValidate = 1 or @GenId > 0)  THEN 1 ELSE 0 END)
		+ (CASE WHEN ISNULL(@tech_cont_email, '') = '' AND (@isNewGeneratorToValidate = 1 or @GenId > 0) THEN 1 ELSE 0 END)
		+ (CASE WHEN (COALESCE(@GenTypeId,NULL, 0) = 0) AND @isNewGeneratorToValidate = 1 THEN 1 ELSE 0 END)			
		+ (CASE WHEN (COALESCE(@EPAIDValue,NULL, '0') = '0') AND @isNewGeneratorToValidate = 1 THEN 1 ELSE 0 END)			 
		+ (CASE WHEN (COALESCE(@NAICS_code,NULL, 0) = 0) AND @isNewGeneratorToValidate = 1 THEN 1 ELSE 0 END)
		+ (CASE WHEN ISNULL(@CustName, '') = '' THEN 1 ELSE 0 END) 
		+ (CASE WHEN ISNULL(@cust_addr1, '') = '' AND @isNewCustomerToValidate = 1 THEN 1 ELSE 0 END)
		+ (CASE WHEN ISNULL(@cust_city, '') = '' AND @isNewCustomerToValidate = 1 THEN 1 ELSE 0 END)
		+ (CASE WHEN ISNULL(@cust_state, '') = '' AND @isNewCustomerToValidate = 1 THEN 1 ELSE 0 END)
		+ (CASE WHEN ISNULL(@Custzip, '') = '' AND @isNewCustomerToValidate = 1 THEN 1 ELSE 0 END)
		+ (CASE WHEN ISNULL(@CustCountry, '') = '' AND @isNewCustomerToValidate = 1 THEN 1 ELSE 0 END)
		+ (CASE WHEN ISNULL(@inv_contact_name, '') = '' AND @isNewCustomerToValidate = 1 THEN 1 ELSE 0 END)
		+ (CASE WHEN ISNULL(@inv_contact_phone, '') = '' AND @isNewCustomerToValidate = 1 THEN 1 ELSE 0 END)
		+ (CASE WHEN ISNULL(@inv_contact_email, '') ='' AND @isNewCustomerToValidate = 1 THEN 1 ELSE 0 END)			
		+ (CASE WHEN (@po_required = 'T' and (ISNULL(@purchase_order, '') = '' or 
			@purchase_order in (SELECT value FROM #invalid_po) or 
			@purchase_order like '%@%' or
			@purchase_order like '%/%' or
			@purchase_order like '% %' or
			(@purchase_order like '[a-zA-Z][a-zA-Z]%' and LEN(@purchase_order) <= 3))) THEN 1 ELSE 0 END)
	) AS sum_of_nulls)

		
	
	IF (EXISTS (SELECT generator_type_id FROM GeneratorType WHERE generator_type in ('LQG','SQG') AND generator_type_id=@GenTypeId)) 
		BEGIN
			SET @TotalValidColumn = @TotalValidColumn + 1
			IF (ISNULL(@EPAIDValue,'') = '')
				BEGIN 
					SET @ValidColumnNullCount = @ValidColumnNullCount + 1
				END 
		END
	 IF @GenId = -1
		BEGIN
			IF (@GenCountry = 'USA' AND LEN(@Genzip) != 5 AND LEN(@Genzip) != 9)
				BEGIN
					SET @ValidColumnNullCount = @ValidColumnNullCount + 1
				END
			ELSE IF (@GenCountry = 'MEX' AND LEN(@Genzip) != 5)
				BEGIN
					SET @ValidColumnNullCount = @ValidColumnNullCount + 1
				END
			ELSE IF(LEN(@Genzip) != 6 AND (@GenCountry != 'USA' AND @GenCountry != 'MEX'))
				BEGIN
					SET @ValidColumnNullCount = @ValidColumnNullCount + 1
				END 
			ELSE IF (@GenMailCountry = 'USA' AND LEN(@GenMailzip) != 5 AND LEN(@GenMailzip) != 9)
				BEGIN
					SET @ValidColumnNullCount = @ValidColumnNullCount + 1
				END
			ELSE IF (@GenMailCountry = 'MEX' AND LEN(@GenMailzip) != 5)
				BEGIN
					SET @ValidColumnNullCount = @ValidColumnNullCount + 1
				END
			ELSE IF(LEN(@GenMailzip) != 6 AND (@GenMailCountry != 'USA' AND @GenMailCountry != 'MEX'))
				BEGIN
					SET @ValidColumnNullCount = @ValidColumnNullCount + 1
				END
		END

	 IF ((@CustId = 0 OR ISNULL(@CustId, '') = '') AND  (@CustName IS NOT NULL))
		BEGIN
			IF (@CustCountry = 'USA' AND LEN(@Custzip) != 5 AND LEN(@Custzip) != 9)
				BEGIN
					SET @ValidColumnNullCount = @ValidColumnNullCount + 1
				END
			ELSE IF (@CustCountry = 'MEX' AND LEN(@Custzip) != 5)
				BEGIN
					SET @ValidColumnNullCount = @ValidColumnNullCount + 1
				END
			ELSE IF(LEN(@Custzip) != 6 AND (@CustCountry != 'USA' AND @CustCountry != 'MEX'))
				BEGIN
					SET @ValidColumnNullCount = @ValidColumnNullCount + 1
				END
		END

	SET @Checking = (SELECT COUNT(PROFILE_ID)  FROM ProfileSectionStatus WHERE PROFILE_ID = @profile_id AND SECTION = 'SA')

	IF @Checking = 0 
		BEGIN
			DECLARE @display_status_uid INT =(SELECT display_status_uid FROM FormDisplayStatus WHERE display_status = 'Draft')
			DECLARE @web_userid nvarchar(60)=(SELECT modified_by FROM profile WHERE profile_id = @profile_id)
			UPDATE Profile SET display_status_uid = @display_status_uid WHERE profile_id = @profile_id
			-- Track form history status
			--EXEC [sp_FormWCRStatusAudit_Insert] @formid,@Revision_ID,@display_status_uid ,@web_userid
        END
	IF (@ValidColumnNullCount = 0)
		IF @Checking = 0 
			BEGIN
				INSERT INTO ProfileSectionStatus 
				VALUES (@profile_id,'SA','Y',getdate(),1,getdate(),1,1)
			END
		ELSE 
		   BEGIN
				UPDATE ProfileSectionStatus SET section_status = 'Y' 
					WHERE PROFILE_ID = @profile_id  AND SECTION = 'SA'
		   END
	ELSE IF (@ValidColumnNullCount = @TotalValidColumn)
		IF @Checking = 0 
			BEGIN
				INSERT INTO ProfileSectionStatus 
				VALUES (@profile_id, 'SA','C',getdate(),1,getdate(),1,1)
			END
		ELSE 
			BEGIN
				UPDATE ProfileSectionStatus SET section_status = 'C'
					WHERE PROFILE_ID = @profile_id AND SECTION = 'SA'
			END
	ELSE
		IF @Checking = 0 
			BEGIN
				INSERT INTO ProfileSectionStatus 
				VALUES (@profile_id,'SA','P',getdate(),1,getdate(),1,1)
			END
		ELSE 
			BEGIN
				UPDATE ProfileSectionStatus SET section_status = 'P' 
					WHERE PROFILE_ID = @profile_id AND SECTION = 'SA'
			END
	END
	
	GO

		GRANT EXEC ON [dbo].[sp_Validate_Profile_Section_A] TO COR_USER;
		
	GO
/***************************************************************************************************/