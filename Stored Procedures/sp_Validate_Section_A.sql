USE [PLT_AI]
GO

/***************************************************************************************************/
DROP PROCEDURE IF EXISTS [sp_Validate_Section_A]
GO
CREATE  PROCEDURE  [dbo].[sp_Validate_Section_A]
	-- Add the parameters for the stored procedure here
	@formid INT,
    @Revision_ID int
AS



/* ******************************************************************

	Updated By		: Pasupathi P
	Updated On		: 24th Jul 2024
	Type			: Stored Procedure
	Object Name		: [sp_Validate_Section_A]
	Related Ticket  : 92207


	Procedure to validate Section A required fields and Update the Status of section

inputs 
	
	@formid
	@revision_ID



Samples:
 EXEC [sp_Validate_Section_A] @form_id,@revision_ID
 EXEC [sp_Validate_Section_A] 569059, 1

****************************************************************** */

BEGIN
	DECLARE @ValidColumnNullCount INTEGER,@TotalValidColumn INTEGER,@Checking INTEGER;

	DECLARE @EPAIDValue VARCHAR(12),@Genzip VARCHAR(10),@GenCountry VARCHAR(3),@GenMailzip VARCHAR(10),@GenMailCountry VARCHAR(3),
	@CustName VARCHAR(75),@Custzip VARCHAR(10),@CustCountry VARCHAR(3),@generator_name VARCHAR(40),@generator_address1 VARCHAR(40),
	@generator_city VARCHAR (40),@generator_phone VARCHAR (20),@gen_mail_address1 VARCHAR(40),@gen_mail_city VARCHAR (40),
	@tech_contact_name VARCHAR (40),@tech_contact_phone VARCHAR (20),@tech_cont_email VARCHAR (50),@cust_addr1 VARCHAR (40),
	@cust_city VARCHAR (40),@inv_contact_name VARCHAR (40),@inv_contact_phone VARCHAR (20),@inv_contact_email VARCHAR (50),
	@purchase_order VARCHAR (20),@modified_by VARCHAR (60);

	DECLARE @GenTypeId INT,@GenId INT,@CustId INT,@NAICS_code INT;

	DECLARE @generator_state CHAR (2),@gen_mail_state CHAR (2),@cust_state CHAR (2),@po_required CHAR (1);

	DECLARE @isNewGeneratorToValidate BIT,@isNewCustomerToValidate BIT;
	
	SET @TotalValidColumn = 22	


	/* Task 19272: PO required ON COR2 causing billing issues */
	-- Using temp tables (#) instead of table variables (@)
	CREATE TABLE #invalid_po (value VARCHAR(20));


	INSERT INTO #invalid_po (value) VALUES 
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

	 SELECT @isNewGeneratorToValidate = (CASE WHEN (f.generator_id = -1) THEN 1 ELSE 0 END),
		 @isNewCustomerToValidate = (CASE WHEN (ISNULL(f.customer_id,0) = 0) THEN 1 ELSE 0 END),
		 @generator_name = f.generator_name,
		 @EPAIDValue=f.EPA_ID,
		 @GenTypeId=f.generator_type_ID, 
		 @CustId = f.customer_Id,
		 @CustName=f.cust_name,
		 @Custzip = f.cust_zip,
		 @CustCountry = f.cust_country,
		 @GenId = f.generator_id,
		 @Genzip = f.generator_zip,
		 @GenCountry = f.generator_country,
		 @GenMailzip = f.gen_mail_zip,
		 @GenMailCountry = f.gen_mail_country,
		 @generator_address1=f.generator_address1,
		 @generator_city = f.generator_city,
		 @generator_state = f.generator_state,
		 @generator_phone = f.generator_phone,
		 @gen_mail_address1=f.gen_mail_address1,
		 @gen_mail_city = f.gen_mail_city,
		 @gen_mail_state = f.gen_mail_state,
		 @tech_contact_name = f.tech_contact_name,
		 @tech_contact_phone = f.tech_contact_phone,
		 @tech_cont_email = f.tech_cont_email,
		 @NAICS_code = f.NAICS_code,
		 @cust_addr1 = f.cust_addr1,
		 @cust_city = f.cust_city,
		 @cust_state = f.cust_state,
		 @inv_contact_name = f.inv_contact_name,
		 @inv_contact_phone = f.inv_contact_phone,
		 @inv_contact_email = f.inv_contact_email,
		 @po_required =f.po_required,
		 @purchase_order = f.purchase_order,
		 @modified_by = f.modified_by
	FROM formwcr f WHERE f.form_id = @formid AND f.revision_id = @Revision_ID 

	SET  @ValidColumnNullCount = (SELECT  (
				(CASE WHEN ISNULL(@generator_name, '') = '' THEN 1 ELSE 0 END)
			  + (CASE WHEN ISNULL(@generator_address1, '') = '' AND @isNewGeneratorToValidate = 1 THEN 1 ELSE 0 END)
			  + (CASE WHEN ISNULL(@generator_city, '') = '' AND @isNewGeneratorToValidate = 1 THEN 1 ELSE 0 END)
			  + (CASE WHEN ISNULL(@generator_state, '') = '' AND @isNewGeneratorToValidate = 1 THEN 1 ELSE 0 END)
			  + (CASE WHEN ISNULL(@Genzip, '') = '' AND @isNewGeneratorToValidate = 1 THEN 1 ELSE 0 END)
			  + (CASE WHEN ISNULL(@GenCountry, '') = '' AND @isNewGeneratorToValidate = 1  THEN 1 ELSE 0 END)
			  + (CASE WHEN ISNULL(@generator_phone, '') = '' AND @isNewGeneratorToValidate = 1 THEN 1 ELSE 0 END)
			  + (CASE WHEN ISNULL(@gen_mail_address1, '') = '' AND @isNewGeneratorToValidate = 1 THEN 1 ELSE 0 END)
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
		
		SET @Checking = (SELECT COUNT(FORM_ID) 
							FROM FormSectionStatus 
							WHERE FORM_ID = @formid AND revision_id = @Revision_ID AND SECTION = 'SA')

		IF @Checking = 0 
			BEGIN
				DECLARE @display_status_uid INT =(SELECT display_status_uid 
													FROM FormDisplayStatus 
													WHERE display_status = 'Draft')
				--DECLARE @web_userid NVARCHAR(60)=@modified_by

				UPDATE FormWcr SET display_status_uid = @display_status_uid 
					WHERE form_id = @formid AND revision_id = @Revision_ID
				-- Track form history status
				EXEC [sp_FormWCRStatusAudit_Insert] @formid,@Revision_ID,@display_status_uid ,@modified_by
			END

		IF (@ValidColumnNullCount = 0)
			IF (@Checking = 0)
				BEGIN
					INSERT INTO FormSectionStatus 
					VALUES (@formid,@Revision_ID,'SA','Y',GETDATE(),@modified_by,GETDATE(),@modified_by,1)
				END
			ELSE 
			   BEGIN
					UPDATE FormSectionStatus SET section_status = 'Y' 
						WHERE FORM_ID = @formid AND revision_id = @Revision_ID AND SECTION = 'SA'
			   END
		ELSE IF (@ValidColumnNullCount = @TotalValidColumn)
			IF (@Checking = 0)
				BEGIN
					INSERT INTO FormSectionStatus 
					VALUES (@formid,@Revision_ID,'SA','C',GETDATE(),@modified_by,GETDATE(),@modified_by,1)
				END
			ELSE 
				BEGIN
					UPDATE FormSectionStatus SET section_status = 'C' 
						WHERE FORM_ID = @formid AND revision_id = @Revision_ID AND SECTION = 'SA'
				END
		ELSE
			IF (@Checking = 0)
				BEGIN
					INSERT INTO FormSectionStatus 
					VALUES (@formid,@Revision_ID,'SA','P',GETDATE(),@modified_by,GETDATE(),@modified_by,1)
				END
			ELSE 
				BEGIN
					UPDATE FormSectionStatus SET section_status = 'P' 
						WHERE FORM_ID = @formid AND revision_id = @Revision_ID AND SECTION = 'SA'
				END
		END
		
		GO

		GRANT EXEC ON [dbo].[sp_Validate_Section_A] TO COR_USER;
		GO
/***************************************************************************************************/