USE [PLT_AI]
GO

DROP PROCEDURE IF EXISTS [sp_Validate_Section_C]
GO
CREATE PROCEDURE  [dbo].[sp_Validate_Section_C]
	-- Add the parameters for the stored procedure here
	@formid INT,
	@Revision_ID int
AS



/* ******************************************************************

	Updated By		: Sathik
	Updated On		: 04-03-19
	Type			: Stored Procedure
	Object Name		: [sp_Validate_Section_C]


	Procedure to validate Section C required fields and Update the Status of section

inputs 
	
	@formid
	@revision_ID

Returns

	form_id
	revision_id

Samples:
 EXEC [sp_Validate_Section_C] @form_id,@revision_ID
 EXEC [sp_Validate_Section_C] 569276, 1

****************************************************************** */
SET NOCOUNT ON;
BEGIN
	DECLARE @ValidColumnNullCount INTEGER,@TotalValidColumn INTEGER;
	
	DECLARE @SectionType VARCHAR(2),@hazmat_flag VARCHAR(1),@DOT_shipping_name VARCHAR(255),@DOT_inhalation_haz_flag VARCHAR(1),
	@frequency VARCHAR(20),@frequency_other VARCHAR(20),@container_type_combination VARCHAR(1),@container_type_combination_desc VARCHAR(100),
	@RQ_Flaq VARCHAR(1),@RQ_Reason VARCHAR(50),@DOT_sp_permit_flag VARCHAR(1),@DOT_sp_permit_text VARCHAR(255),@container_type_other VARCHAR(1),
	@container_type_other_desc VARCHAR(100),@emergency_phone_number VARCHAR(50);

	DECLARE @FormStatusFlag VARCHAR(1) = 'Y';

	DECLARE @ContainerNullCount INT,@ContainerSizeReqCount INT,@waste_codecount INT,@UnitsCount INT, @ContainerSizeCount INT,
	@VolumeCount INT;
	
	DECLARE @RQ_threshold FLOAT;

	DECLARE @DOT_waste_flag CHAR(1), @drum_type CHAR(1), @totes_type CHAR(1), @box_type CHAR(1);
	DECLARE @drumlist TABLE(bill_unit_code VARCHAR(4))
	DECLARE @totes TABLE (bill_unit_code VARCHAR(4))
	DECLARE @boxes TABLE (bill_unit_code VARCHAR(4))
	DECLARE @FormXWCRContainerSize TABLE (form_id INT,revision_id INT,bill_unit_code VARCHAR(50))
	SET @SectionType = 'SC'
	SET @TotalValidColumn = 6

	/* Task 11434: Section C.7 & C.8 Re-Design Phase2 */
	
	INSERT INTO @drumlist
	SELECT bill_unit_code 
		FROM billunit 
		WHERE bill_unit_desc 
		IN  
		(
			'1 Gallon Drum',
			'2 Gallon Drum',
			'2.5 Gallon Drum',
			'5 Gallon Drum',
			'6 Gallon Drum',
			'10 Gallon Drum',
			'12 Gallon Drum',
			'15 Gallon Drum',
			'16 Gallon Drum',
			'20 Gallon Drum',
			'25 Gallon Drum',
			'30 Gallon Drum',
			'35 Gallon Drum',
			'40 Gallon Drum',
			'45 Gallon Drum',
			'50 Gallon Drum',
			'55 Gallon Drum',
			'75 Gallon Drum',
			'85 Gallon Drum',
			'95 Gallon Drum',
			'100 Gallon Drum',
			'110 Gallon Drum',
			'Overpack'
		)

	
	INSERT INTO @totes
	SELECT bill_unit_code 
		FROM billunit 
		WHERE bill_unit_desc 
		IN  
		(
			'110 Gallon Tote',
			'220 Gallon Tote',
			'250 Gallon Tote',
			'275 Gallon Tote',
			'300 Gallon Tote',
			'330 Gallon Tote',
			'350 Gallon Tote',
			'400 Gallon Tote',
			'550 Gallon Tote'
		)

	
	INSERT INTO @boxes
	SELECT bill_unit_code 
		FROM billunit 
		WHERE bill_unit_desc 
		IN  
		(
			'Cubic Yard Bag/Box',
			'1.5 Cubic Yard Bag/Box',
			'2 Cubic Yard Bag/Box',
			'B12 Box',
			'B25 Box',
			'Flow Bin'
		)

	--SELECT * INTO #tempFormWCR FROM FormWCR WHERE form_id=@formid and revision_id=@Revision_ID 
	SELECT @container_type_other_desc=container_type_other_desc,@container_type_other=container_type_other,
		   @DOT_sp_permit_text=DOT_sp_permit_text,@DOT_sp_permit_flag=DOT_sp_permit_flag,@frequency_other= frequency_other ,@frequency =frequency,
		   @DOT_inhalation_haz_flag=DOT_inhalation_haz_flag,@DOT_shipping_name=DOT_shipping_name,
		   @container_type_combination=container_type_combination,@container_type_combination_desc=container_type_combination_desc,@container_type_other=container_type_other,
		   @container_type_other_desc=container_type_other_desc,@RQ_Flaq=reportable_quantity_flag,@RQ_Reason=RQ_reason,@RQ_threshold=RQ_threshold,@hazmat_flag=hazmat_flag,
		   @emergency_phone_number=emergency_phone_number,@DOT_waste_flag=DOT_waste_flag
		FROM FormWCR 
		WHERE form_id = @formid AND revision_id=@Revision_ID 

	
		-- check check 24-Hour Emergency Phone value (C5) validation

		SELECT @waste_codecount=COUNT(DISTINCT waste_code_uid) 
			FROM FormXWasteCode 
			WHERE (specifier = 'state' OR specifier = 'rcra_characteristic' OR specifier = 'rcra_listed')
			AND form_id = @formid AND revision_id=@revision_ID AND waste_code_uid >0

       -- Container Type
	   SET @ContainerNullCount = (SELECT  (
				  (CASE WHEN ISNULL(container_type_bulk,'')= '' OR container_type_bulk = 'F'  THEN 0 ELSE 1 END)
				+ (CASE WHEN ISNULL(container_type_totes,'')= '' OR container_type_totes = 'F' THEN 0 ELSE 1 END)
				+ (CASE WHEN ISNULL(container_type_pallet,'')= '' OR container_type_pallet = 'F' THEN 0 ELSE 1 END)
				+ (CASE WHEN ISNULL(container_type_boxes,'')= '' OR container_type_boxes = 'F'  THEN 0 ELSE 1 END)
				+ (CASE WHEN ISNULL(container_type_drums,'')= '' OR container_type_drums = 'F' THEN 0 ELSE 1 END)
				+ (CASE WHEN ISNULL(container_type_cylinder,'')= '' OR container_type_cylinder = 'F' THEN 0 ELSE 1 END)
				+ (CASE WHEN ISNULL(container_type_labpack ,'')= '' OR container_type_labpack = 'F' THEN 0 ELSE 1 END)
				+ (CASE WHEN ISNULL(container_type_combination,'')= '' OR container_type_combination = 'F' THEN 0 ELSE 1 END)
				+ (CASE WHEN ISNULL(container_type_other,'')= '' OR container_type_other = 'F'  THEN 0 ELSE 1 END)
		    ) AS sum_of_containernulls
			FROM FormWcr
			WHERE form_id =  @formid AND revision_id = @Revision_ID)

		-- ContainerSize
		SET @ContainerSizeReqCount = (SELECT  (
				  (CASE WHEN ISNULL(container_type_bulk,'')= '' OR container_type_bulk = 'F'  THEN 0 ELSE 1 END)
				+ (CASE WHEN ISNULL(container_type_totes,'')= '' OR container_type_totes = 'F' THEN 0 ELSE 1 END)
				+ (CASE WHEN ISNULL(container_type_pallet,'')= '' OR container_type_pallet = 'F' THEN 0 ELSE 1 END)
				+ (CASE WHEN ISNULL(container_type_boxes,'')= '' OR container_type_boxes = 'F'  THEN 0 ELSE 1 END)
				+ (CASE WHEN ISNULL(container_type_drums,'')= '' OR container_type_drums = 'F' THEN 0 ELSE 1 END)
				+ (CASE WHEN ISNULL(container_type_labpack ,'')= '' OR container_type_labpack = 'F' THEN 0 ELSE 1 END)
		    ) AS sum_of_containerReqCount
			From FormWcr
			Where 
			form_id =  @formid AND revision_id = @Revision_ID)			 

		/* Task 11434: Section C.7 & C.8 Re-Design Phase2 */
		
		INSERT INTO @FormXWCRContainerSize
		SELECT form_id,revision_id,bill_unit_code
							FROM FormXWCRContainerSize 
							WHERE form_id = @formid AND revision_id = @Revision_ID 

		SELECT TOP 1 @drum_type = container_type_drums, 
					@box_type = container_type_boxes,
					@totes_type = container_type_totes
			FROM FormWcr 
			WHERE form_id = @formid AND revision_id = @Revision_ID		
			
		--- IF DOT Hazardous Material Value T , Check Proper Shipping name:
		IF (
				(ISNULL(@hazmat_flag,'') = '' OR @hazmat_flag = 'U') 
				OR 
				(@hazmat_flag = 'T' AND  
				(ISNULL(@DOT_shipping_name,'')= '' OR 
				(@DOT_waste_flag='T' AND @DOT_shipping_name ='waste') OR
				ISNULL(@DOT_inhalation_haz_flag,'')= '' OR
				ISNULL(@emergency_phone_number,'')=''))
		   )
		BEGIN
			SET @FormStatusFlag = 'P'				   
		END
			 
		ELSE IF ((@waste_codecount > 0) AND (ISNULL(@emergency_phone_number,'')=''))
		BEGIN
			SET @FormStatusFlag = 'P'			
		END
		ELSE IF (@RQ_Flaq = 'T' AND ((ISNULL(@RQ_Reason,'')= '' ) OR (ISNULL(@RQ_threshold,'')= '')))
		BEGIN
			SET @FormStatusFlag = 'P'
		END       
	    ELSE IF (ISNULL(@DOT_sp_permit_flag,'')= '' OR (@DOT_sp_permit_flag = 'T' AND (ISNULL(@DOT_sp_permit_text,'')= '')))
		BEGIN
			SET @FormStatusFlag = 'P'
		END
		ELSE IF @ContainerNullCount < 1
		BEGIN
			SET @FormStatusFlag = 'P'
		END
		ELSE IF (@container_type_other = 'T' AND ISNULL(@container_type_other_desc,'') = '')
		BEGIN
			SET @FormStatusFlag = 'P'
		END
		ELSE IF (@container_type_combination = 'T' AND ISNULL(@container_type_combination_desc,'')='')
		BEGIN
			SET @FormStatusFlag = 'P'
		END
		ELSE IF(@ContainerSizeReqCount > 0 AND NOT EXISTS(SELECT form_id from @FormXWCRContainerSize))
		BEGIN				
			--SET @ContainerSizeCount  = (SELECT COUNT(form_id) FROM FormXWCRContainerSize WHERE form_id = @formid AND revision_id = @Revision_ID) 
			--IF (@ContainerSizeCount <= 0)
			--	BEGIN
					SET @FormStatusFlag = 'P'
			--END
		END	    		
		ELSE IF EXISTS(SELECT form_id FROM FormXUnit WHERE form_id = @formid AND revision_id = @Revision_ID AND (ISNULL(bill_unit_code,'')= '' OR ISNULL(quantity,'')= '' ))
		BEGIN
			SET @FormStatusFlag = 'P'
		END        
		--ELSE IF EXISTS((SELECT form_id FROM FormXUnit WHERE form_id = @formid AND revision_id = @Revision_ID AND ISNULL(quantity,'')= '' ))
		--BEGIN
		--	SET @FormStatusFlag = 'P'
		--END
        ELSE IF (ISNULL(@frequency,'')= '')
		BEGIN
		SET @FormStatusFlag = 'P'
		END
        ELSE IF ((@frequency = 'O' OR @frequency = '-99') AND (ISNULL(@frequency_other,'')= ''))
		BEGIN
			SET @FormStatusFlag = 'P'
		END				
		ELSE IF(@drum_type = 'T' AND 
				NOT EXISTS (SELECT form_id
							FROM @FormXWCRContainerSize 
							WHERE bill_unit_code IN (SELECT d.bill_unit_code FROM @drumlist d)))
		BEGIN
			SET @FormStatusFlag = 'P'
		END
		ELSE IF(@drum_type <> 'T' AND 
				EXISTS (SELECT form_id 
						FROM @FormXWCRContainerSize 
						WHERE bill_unit_code IN (SELECT d.bill_unit_code FROM @drumlist d)))
		BEGIN
			SET @FormStatusFlag = 'P'
		END
		ELSE IF(@box_type = 'T' AND 
			NOT EXISTS (SELECT form_id 
							FROM @FormXWCRContainerSize 
							WHERE bill_unit_code IN (SELECT b.bill_unit_code FROM @boxes b)) )
		BEGIN
			SET @FormStatusFlag = 'P'
		END
		ELSE IF(@box_type <> 'T' AND 
			 EXISTS (SELECT form_id 
							FROM @FormXWCRContainerSize 
							WHERE bill_unit_code IN (SELECT b.bill_unit_code FROM @boxes b)) )
		BEGIN
			SET @FormStatusFlag = 'P'
		END
		ELSE IF(@totes_type = 'T' AND 
			 NOT EXISTS (SELECT form_id 
							FROM @FormXWCRContainerSize 
							WHERE bill_unit_code IN (SELECT t.bill_unit_code FROM @totes t)))
		BEGIN
			SET @FormStatusFlag = 'P'
		END
		ELSE IF(@totes_type <> 'T' AND 
			 EXISTS (SELECT form_id 
							FROM @FormXWCRContainerSize 
							WHERE bill_unit_code in (select t.bill_unit_code from @totes t))) 
		BEGIN
			SET @FormStatusFlag = 'P'
		END
		ELSE 
		BEGIN
			SET @FormStatusFlag = 'Y'
		END


    IF(NOT EXISTS(SELECT FORM_ID FROM FormSectionStatus WHERE FORM_ID =@formid AND revision_id = @Revision_ID  AND SECTION ='SC'))
	BEGIN
		INSERT INTO FormSectionStatus 
			VALUES (@formid,@Revision_ID,'SC',@FormStatusFlag,GETDATE(),1,GETDATE(),1,1)
	END
	ELSE 
	BEGIN
		UPDATE FormSectionStatus SET section_status = @FormStatusFlag 
			WHERE FORM_ID = @formid AND revision_id = @Revision_ID AND SECTION = 'SC'
	END
END

GO
GRANT EXEC ON [dbo].[sp_Validate_Section_C] TO COR_USER;
GO