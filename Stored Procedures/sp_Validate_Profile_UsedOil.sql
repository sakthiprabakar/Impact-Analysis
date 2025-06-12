USE [PLT_AI]
GO
/****** Object:  StoredProcedure [dbo].[sp_Validate_Profile_UsedOil]    Script Date: 26-11-2021 13:19:08 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- =============================================
-- Author:		<Author,,Sathick>
-- Create date: <Create Date,,>
-- Description:	<Description,,>
-- =============================================
CREATE PROCEDURE  [dbo].[sp_Validate_Profile_UsedOil]
	-- Add the parameters for the stored procedure here
	@profile_id INT,
	@web_userid nvarchar(200)
AS
	

/* ******************************************************************

	Updated By		: Dineshkumar
	Updated On		: 9th Jan 2019
	Type			: Stored Procedure
	Object Name		: [sp_Validate_Profile_UsedOil]


	Procedure to validate Used Oil Section required fields and Update the Status of section

inputs 
	
	@profile_id
	@web_userid


Samples:
 EXEC [sp_Validate_Profile_UsedOil] @profile_id,@web_userid
 EXEC [sp_Validate_Profile_UsedOil] 523932,'anand_m123'

****************************************************************** */

BEGIN
	DECLARE @ValidColumnNullCount INTEGER;
	DECLARE @TotalValidColumn INTEGER; -- Based Select Column count
	DECLARE @SectionType VARCHAR(3);
	
	DECLARE @ProfileStatusFlag varchar(1) = 'Y'

	declare @wwa_halogen_list table
	(
		description nvarchar(50)
	)

	insert into @wwa_halogen_list values('Metalwork'),('Halogen'),('Chloroflu'),('Other')
	
	DECLARE @wwa_halogen_gt_1000 CHAR(1),
			@halogen_source  VARCHAR(10),
			@halogen_source_desc VARCHAR(100),
			@halogen_source_other VARCHAR(100) 

		SELECT @wwa_halogen_gt_1000=wwa_halogen_gt_1000,@halogen_source=halogen_source,@halogen_source_desc=halogen_source_desc,@halogen_source_other=halogen_source_other FROM ProfileLab WHERE profile_id = @profile_id and type ='A'
			

	   IF (@wwa_halogen_gt_1000 IS NULL OR @wwa_halogen_gt_1000 = '')
        BEGIN
		  SET @ProfileStatusFlag = 'P'
		END
       ELSE
	    BEGIN
		  IF @wwa_halogen_gt_1000 = 'T'
		  BEGIN
		   IF (NOT EXISTS(select * from  @wwa_halogen_list where description in (@halogen_source))) -- IS NULL  OR @wwa_halogen_source = '' OR @wwa_halogen_source = 'F')
		    BEGIN 
			 SET @ProfileStatusFlag = 'P'
			END
           ELSE
		    BEGIN
				 IF @halogen_source = 'Halogen'
				   BEGIN 
				    print 'Halogen '
					 IF (@halogen_source_desc IS NULL OR @halogen_source_desc = '')
					 BEGIN 
					   print 'Halogen source '
					   SET @ProfileStatusFlag = 'P'
					 END
				   END

				IF @halogen_source = 'Other'
				   BEGIN 
				    print 'Other'
					 IF (@halogen_source_other IS NULL OR @halogen_source_other = '')
					 BEGIN 
					   print 'Other desc'
					   SET @ProfileStatusFlag = 'P'
					 END
				   END
            END
		 END
		END
	    
	   
    IF(NOT EXISTS(SELECT * FROM ProfileSectionStatus WHERE profile_id =@profile_id AND SECTION ='UL'))
		BEGIN
			INSERT INTO ProfileSectionStatus VALUES (@profile_id,'UL',@ProfileStatusFlag,getdate(),@web_userid,getdate(),@web_userid,1)
		END
	 ELSE 
		BEGIN
			UPDATE ProfileSectionStatus SET section_status = @ProfileStatusFlag WHERE profile_id = @profile_id AND SECTION = 'UL'
		END

   

END

GO
	GRANT EXEC ON [dbo].[sp_Validate_Profile_UsedOil] TO COR_USER;
GO