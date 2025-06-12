USE [PLT_AI]
GO
/****** Object:  StoredProcedure [dbo].[sp_Validate_Profile_Section_C]    Script Date: 25-11-2021 20:25:56 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE  [dbo].[sp_Validate_Profile_Section_C]
	-- Add the parameters for the stored procedure here
	@profile_id int

AS

 

/* ******************************************************************

	Updated By		: Prabhu
	Updated On		: 21st Sep 2021
	Type			: Stored Procedure
	Object Name		: [sp_Validate_Profile_Section_C]


	Procedure to validate Section C required fields and Update the Status of section

inputs 
	
	@profile_id
	


Samples:
 EXEC [sp_Validate_Profile_Section_C] @profile_id
 EXEC [sp_Validate_Profile_Section_C] 699442


****************************************************************** */

BEGIN
	DECLARE @ValidColumnNullCount INTEGER;
	DECLARE @TotalValidColumn INTEGER; 
	DECLARE @SectionType VARCHAR(2);
	DECLARE @hazmat_flag varchar(1);
	DECLARE @DOT_shipping_name VARCHAR(255);
	DECLARE @DOT_inhalation_haz_flag VARCHAR(1);
	DECLARE @ContainerNullCount INT;
	DECLARE @ContainerSizeReqCount INT;
	DECLARE @frequency VARCHAR(20);
	DECLARE @frequency_other VARCHAR(20);
	--
	DECLARE @container_type_combination VARCHAR(1);
	DECLARE @container_type_combination_desc VARCHAR(100);
	
	DECLARE @RQ_Flaq varchar(1);
	DECLARE @RQ_Reason varchar(50);
	DECLARE @RQ_threshold float

	DECLARE @DOT_sp_permit_flag VARCHAR(1);
	DECLARE @DOT_sp_permit_text VARCHAR(255);

	DECLARE @container_type_other VARCHAR(1);
	DECLARE @container_type_other_desc VARCHAR(100);

	DECLARE @emergency_phone_number varchar(50);

	SET @SectionType = 'SC'
	SET @TotalValidColumn = 6

	DECLARE @ProfileStatusFlag varchar(1) = 'Y'

	DECLARE @drumlist table 
	(
		bill_unit_code varchar(4)
	)
	insert into @drumlist
	select bill_unit_code from billunit 
		where bill_unit_desc 
		in  
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

	DECLARE @totes table 
	(
		bill_unit_code varchar(4)
	)
	insert into @totes
	select bill_unit_code from billunit 
		where bill_unit_desc 
		in  
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

	DECLARE @boxes table 
	(
		bill_unit_code varchar(4)
	)
	insert into @boxes
	select bill_unit_code from billunit 
		where bill_unit_desc 
		in  
		(
			'Cubic Yard Bag/Box',
			'1.5 Cubic Yard Bag/Box',
			'2 Cubic Yard Bag/Box',
			'B12 Box',
			'B25 Box',
			'Flow Bin'
		)
 
	SELECT @container_type_other_desc=container_type_other_desc,@container_type_other=container_type_other,
		   @DOT_sp_permit_text=DOT_sp_permit_text,@DOT_sp_permit_flag=DOT_sp_permit_flag,@frequency_other= shipping_frequency_other ,@frequency =shipping_frequency,
		   @DOT_inhalation_haz_flag=DOT_inhalation_haz_flag,@DOT_shipping_name=DOT_shipping_name,
		   @container_type_combination=container_type_combination,@container_type_combination_desc=container_type_combination_desc,@container_type_other=container_type_other,
		   @container_type_other_desc=container_type_other_desc,@RQ_Flaq=reportable_quantity_flag,@RQ_Reason=RQ_reason,@RQ_threshold=RQ_threshold,@hazmat_flag=hazmat,
		   @emergency_phone_number=emergency_phone_number
	FROM Profile WHERE profile_id = @profile_id 

	
	   --  Check DOT Hazardous Material?
	    IF (@hazmat_flag IS NULL OR @hazmat_flag = '' or @hazmat_flag = 'U')
			BEGIN
				SET @ProfileStatusFlag = 'P'

			END
		  ELSE 
		   BEGIN
		     IF @hazmat_flag = 'T' 
			  BEGIN
			    --- IF DOT Hazardous Material Value T , Check Proper Shipping name:
			    IF (@DOT_shipping_name IS NULL OR @DOT_shipping_name = '')
				 BEGIN
				   SET @ProfileStatusFlag = 'P'
				 END
			    --- IF DOT Hazardous Material Value T , Check DOT Inhalation Hazard:
			    IF (@DOT_inhalation_haz_flag IS NULL OR @DOT_inhalation_haz_flag = '')
			     BEGIN
			       SET @ProfileStatusFlag = 'P'
			     END

				 --IF DOT Hazardous Material (C1) value T, check 24-Hour Emergency Phone value (C5)
				 If (@emergency_phone_number IS NULL OR @emergency_phone_number='')
				 BEGIN
					SET @ProfileStatusFlag = 'P'
					print 'hazmat_flag and C5 Emergency phone number' + @ProfileStatusFlag
				 END

			  END
		   END

		   	print 'hazmat_flag' + @ProfileStatusFlag


			-- check check 24-Hour Emergency Phone value (C5) validation

			
			
				Declare @rcra_codecount int 
				select @rcra_codecount=count(distinct pw.waste_code_uid) from ProfileWasteCode as pw 
				inner join WasteCode as w on  pw.waste_code_uid = w.waste_code_uid 
				where profile_id=@profile_id AND [status] = 'A' AND waste_code_origin = 'F' AND haz_flag = 'T' AND waste_type_code IN ('L', 'C') 

				Declare @state_codecount int 
				select @state_codecount=count(distinct pw.waste_code_uid) from ProfileWasteCode as pw 
				inner join WasteCode as w on  pw.waste_code_uid = w.waste_code_uid 
				where profile_id=@profile_id AND waste_code_origin = 'S' AND [state] <> 'TX' AND [state] <> 'PA'  

			--select @waste_codecount=count(distinct waste_code_uid) FROM ProfileWasteCode WHERE (specifier = 'state' or specifier = 'rcra_characteristic' or specifier = 'rcra_listed')
			-- and profile_id = @profile_id and waste_code_uid >0
			 
			Declare @waste_codecount int
			set @waste_codecount = @rcra_codecount + @state_codecount

			IF (@waste_codecount > 0)
			BEGIN
				If (@emergency_phone_number IS NULL OR @emergency_phone_number='')
				 BEGIN
					SET @ProfileStatusFlag = 'P'
					print 'Waste code and C5 Emergency phone number' + @ProfileStatusFlag
				 END
			END


		  IF (@RQ_Flaq = 'T')
		   BEGIN
		     IF (@RQ_Reason IS NULL OR @RQ_reason = '' ) --,@RQ_threshold)
		      BEGIN
			   SET @ProfileStatusFlag = 'P'
			  END

			 IF (@RQ_threshold IS NULL OR @RQ_threshold = '')
			  BEGIN
			    SET @ProfileStatusFlag = 'P'
			  END
		   END
		 -- END

		 	print 'RQ value' + @ProfileStatusFlag


       -- DOT Permit 
	    IF (@DOT_sp_permit_flag IS NULL OR @DOT_sp_permit_flag = '')
		  BEGIN
		   SET @ProfileStatusFlag = 'P'
		  END
        ELSE
		 BEGIN
		   IF @DOT_sp_permit_flag = 'T'
		    BEGIN
			  IF (@DOT_sp_permit_text IS NULL OR @DOT_sp_permit_text = '')
			   BEGIN
			    SET @ProfileStatusFlag = 'P'
			   END
			END
		 END

       -- Container Type
	   SET @ContainerNullCount = (SELECT  (
				  (CASE WHEN container_type_bulk IS NULL OR container_type_bulk = '' OR container_type_bulk = 'F'  THEN 0 ELSE 1 END)
				+ (CASE WHEN container_type_totes IS NULL OR container_type_totes = '' OR container_type_totes = 'F' THEN 0 ELSE 1 END)
				+ (CASE WHEN container_type_pallet IS NULL OR container_type_pallet = '' OR container_type_pallet = 'F' THEN 0 ELSE 1 END)
				+ (CASE WHEN container_type_boxes IS NULL OR container_type_boxes = '' OR container_type_boxes = 'F'  THEN 0 ELSE 1 END)
				+ (CASE WHEN container_type_drums IS NULL OR container_type_drums = '' OR container_type_drums = 'F' THEN 0 ELSE 1 END)
				+ (CASE WHEN container_type_cylinder IS NULL OR container_type_cylinder = '' OR container_type_cylinder = 'F' THEN 0 ELSE 1 END)
				+ (CASE WHEN container_type_labpack IS NULL OR container_type_labpack = '' OR container_type_labpack = 'F' THEN 0 ELSE 1 END)
				+ (CASE WHEN container_type_combination IS NULL OR container_type_combination = '' OR container_type_combination = 'F' THEN 0 ELSE 1 END)
				+ (CASE WHEN container_type_other IS NULL OR container_type_other = '' OR container_type_other = 'F'  THEN 0 ELSE 1 END)
		    ) AS sum_of_containernulls
			From Profile
			Where 
			profile_id =  @profile_id)

		IF @ContainerNullCount < 1
		 BEGIN
		    SET @ProfileStatusFlag = 'P'
		 END

		
       --ELSE
	    --BEGIN
		 IF @container_type_other = 'T'
		  BEGIN
		    IF @container_type_other_desc IS NULL OR @container_type_other_desc = ''
			 BEGIN
			   SET @ProfileStatusFlag = 'P'
			 END
		  END
		--END


		IF @container_type_combination = 'T'
		BEGIN
			IF @container_type_combination_desc Is Null or @container_type_combination_desc=''
			BEGIN
				SET @ProfileStatusFlag = 'P'
			END
		END

		print 'Container Type Combination' + @ProfileStatusFlag

		-- ContainerSize
		SET @ContainerSizeReqCount = (SELECT  (
				  (CASE WHEN container_type_bulk IS NULL OR container_type_bulk = '' OR container_type_bulk = 'F'  THEN 0 ELSE 1 END)
				+ (CASE WHEN container_type_totes IS NULL OR container_type_totes = '' OR container_type_totes = 'F' THEN 0 ELSE 1 END)
				+ (CASE WHEN container_type_pallet IS NULL OR container_type_pallet = '' OR container_type_pallet = 'F' THEN 0 ELSE 1 END)
				+ (CASE WHEN container_type_boxes IS NULL OR container_type_boxes = '' OR container_type_boxes = 'F'  THEN 0 ELSE 1 END)
				+ (CASE WHEN container_type_drums IS NULL OR container_type_drums = '' OR container_type_drums = 'F' THEN 0 ELSE 1 END)
				+ (CASE WHEN container_type_labpack IS NULL OR container_type_labpack = '' OR container_type_labpack = 'F' THEN 0 ELSE 1 END)
		    ) AS sum_of_containerReqCount
			From Profile
			Where 
			profile_id =  @profile_id)

		IF(@ContainerSizeReqCount > 0)
		BEGIN
		DECLARE @ContainerSizeCount INT;
		SET @ContainerSizeCount  = (SELECT COUNT(*) FROM ProfileContainerSize WHERE PROFILE_ID = @profile_id)
 
		IF @ContainerSizeCount <= 0
		 BEGIN
			 SET @ProfileStatusFlag = 'P'
		 END
      
	  print 'Container size count ' + @ProfileStatusFlag
	  END
	    -- Units
		DECLARE @UnitsCount INT;
		SET @UnitsCount  = (SELECT COUNT (*) FROM ProfileShippingUnit WHERE profile_id = @profile_id AND  (bill_unit_code IS NULL OR bill_unit_code = ''))
 
		IF @UnitsCount > 0
		 BEGIN
			 SET @ProfileStatusFlag = 'P'
		 END
        
		print 'Units ' + @ProfileStatusFlag

		-- Volume
		DECLARE @VolumeCount INT;
		SET @VolumeCount  = (SELECT COUNT (*) FROM ProfileShippingUnit WHERE profile_id = @profile_id AND (quantity IS NULL OR quantity = '') )
 
		IF @VolumeCount > 0
		 BEGIN
			 SET @ProfileStatusFlag = 'P'
		 END

		 print 'Volume ' + @ProfileStatusFlag
		
       -- Frequency
        IF (@frequency IS NULL OR @frequency = '')
		 BEGIN
		   SET @ProfileStatusFlag = 'P'
		 END
        ELSE 
		 BEGIN
		  IF @frequency = 'O' OR @frequency = '-99'
		   BEGIN
		     IF (@frequency_other IS NULL OR @frequency_other = '')
			  BEGIN
			    SET @ProfileStatusFlag = 'P'
			  END
		   END
		 END

		DECLARE @drum_type char(1), @totes_type char(1), @box_type char(1)

		select top 1 @drum_type = container_type_drums, 
					@box_type = container_type_boxes,
					@totes_type = container_type_totes
		From Profile Where PROFILE_ID = @profile_id 

		 IF(@drum_type = 'T' AND 
			 (SELECT COUNT (*) FROM ProfileContainerSize WHERE PROFILE_ID = @profile_id 
			 and bill_unit_code in (select d.bill_unit_code from @drumlist d)) <= 0)
		 BEGIN
			SET @ProfileStatusFlag = 'P'
		 END

		 IF(@drum_type <> 'T' AND 
			 (SELECT COUNT (*) FROM ProfileContainerSize WHERE PROFILE_ID = @profile_id 
			 and bill_unit_code in (select d.bill_unit_code from @drumlist d)) > 0)
		 BEGIN
			SET @ProfileStatusFlag = 'P'
		 END
		
		 IF(@box_type = 'T' AND 
			 (SELECT COUNT (*) FROM ProfileContainerSize WHERE PROFILE_ID = @profile_id  
			 and bill_unit_code in (select b.bill_unit_code from @boxes b)) <= 0)
		 BEGIN
			SET @ProfileStatusFlag = 'P'
		 END

		  IF(@box_type <> 'T' AND 
			 (SELECT COUNT (*) FROM ProfileContainerSize WHERE PROFILE_ID = @profile_id  
			 and bill_unit_code in (select b.bill_unit_code from @boxes b)) > 0)
		 BEGIN
			SET @ProfileStatusFlag = 'P'
		 END

		 IF(@totes_type = 'T' AND 
			 (SELECT COUNT (*) FROM ProfileContainerSize WHERE PROFILE_ID = @profile_id  
			 and bill_unit_code in (select t.bill_unit_code from @totes t)) <= 0)
		 BEGIN
			SET @ProfileStatusFlag = 'P'
		 END

		  IF(@totes_type <> 'T' AND 
			 (SELECT COUNT (*) FROM ProfileContainerSize WHERE PROFILE_ID = @profile_id  
			 and bill_unit_code in (select t.bill_unit_code from @totes t)) > 0)
		 BEGIN
			SET @ProfileStatusFlag = 'P'
		 END


     IF(NOT EXISTS(SELECT * FROM ProfileSectionStatus WHERE PROFILE_ID = @profile_id AND SECTION ='SC'))
		BEGIN
			INSERT INTO ProfileSectionStatus VALUES (@profile_id,'SC',@ProfileStatusFlag,getdate(),1,getdate(),1,1)
		END
	 ELSE 
		BEGIN
			UPDATE ProfileSectionStatus SET section_status = @ProfileStatusFlag WHERE PROFILE_ID = @profile_id AND SECTION = 'SC'
		END
END

GO
	GRANT EXEC ON [dbo].[sp_Validate_Profile_Section_C] TO COR_USER;
GO


