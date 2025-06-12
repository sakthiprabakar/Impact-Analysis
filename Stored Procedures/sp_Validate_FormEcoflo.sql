DROP PROCEDURE IF EXISTS [sp_Validate_FormEcoflo]
GO


CREATE PROCEDURE [dbo].[sp_Validate_FormEcoflo]
	@formid INT,
	@revision_ID INT,
	@web_userid nvarchar(200)
AS

/***********************************************************************************
 
    Updated By    : Nallaperumal C
    Updated On    : 15-october-2023
    Type          : Store Procedure 
    Object Name   : [sp_Validate_FormEcoflo]
	Ticket		  : 73641
                                                    
    Execution Statement    
	
	EXEC  [dbo].[sp_Validate_FormEcoflo]  @formid, @revision_ID, @web_userid
	EXEC  [dbo].[sp_Validate_FormEcoflo]  786742, 1, 'manand84'
*************************************************************************************/

BEGIN


	DECLARE @ValidColumnNullCount INTEGER;
	DECLARE @TotalValidColumn INTEGER; -- Based Select Column count
	DECLARE @SectionType VARCHAR;

	DECLARE @FormStatusFlag VARCHAR(1) = 'Y';
	
	
	SET @SectionType = 'FB'
	SET @TotalValidColumn = 1

	SET  @ValidColumnNullCount = (SELECT  (
					(CASE WHEN COALESCE(fef.viscosity_value, '') = '' THEN 1 ELSE 0 END)
					+(CASE WHEN ( fef.total_solids_flag != 'T' AND  COALESCE(fef.total_solids_low, '') = '' ) THEN 1 ELSE 0 END)
					+(CASE WHEN ( fef.total_solids_flag != 'T' AND COALESCE(fef.total_solids_high, '') = '') THEN 1 ELSE 0 END)
					+(CASE WHEN ( fef.total_solids_flag != 'T' AND COALESCE(fef.total_solids_description, '') = '') THEN 1 ELSE 0 END)
					+(CASE WHEN ( fef.fluorine_low_flag != 'T' AND fluorine_low IS NULL OR (CAST(fef.fluorine_low AS VARCHAR(40))) = '' ) THEN 1 ELSE 0 END)
					+(CASE WHEN ( fef.fluorine_high_flag != 'T' AND fef.fluorine_high IS NULL OR (CAST(fef.fluorine_high AS VARCHAR(40))) = '' ) THEN 1 ELSE 0 END)
					+(CASE WHEN ( fef.chlorine_low_flag != 'T' AND fef.chlorine_low IS NULL OR (CAST(fef.chlorine_low AS VARCHAR(40))) = '' ) THEN 1 ELSE 0 END)
					+(CASE WHEN ( fef.chlorine_high_flag != 'T' AND fef.chlorine_high IS NULL OR (CAST(fef.chlorine_high AS VARCHAR(40))) = '' ) THEN 1 ELSE 0 END)
					+(CASE WHEN ( fef.bromine_low_flag != 'T' AND fef.bromine_low IS NULL OR (CAST(fef.bromine_low AS VARCHAR(40))) = '' ) THEN 1 ELSE 0 END)
					+(CASE WHEN ( fef.bromine_high_flag != 'T' AND fef.bromine_high IS NULL OR (CAST(fef.bromine_high AS VARCHAR(40))) = '' ) THEN 1 ELSE 0 END)
					+(CASE WHEN ( fef.iodine_low_flag != 'T' AND fef.iodine_low IS NULL OR (CAST(fef.iodine_low AS VARCHAR(40))) = '' ) THEN 1 ELSE 0 END)
					+(CASE WHEN (fef.iodine_high_flag != 'T' AND  fef.iodine_high IS NULL OR (CAST(fef.iodine_high AS VARCHAR(40))) = '' ) THEN 1 ELSE 0 END)
				    ) AS sum_of_nulls
			From FormWcr AS wcr
			INNER JOIN FormEcoflo as fef on wcr.form_id = fef.wcr_id AND wcr.revision_id = fef.wcr_rev_id
			Where 
			wcr.form_id =  @formid and wcr.revision_id = @revision_ID)

	--	select column from FormEcoflo using form_id  
	print cast( @ValidColumnNullCount as varchar(10))

	IF 	@ValidColumnNullCount != 0 
		BEGIN
			SET @FormStatusFlag = 'P'
		END
	
	IF(NOT EXISTS(SELECT * FROM FormSectionStatus WHERE FORM_ID =@formid AND revision_id = @Revision_ID  AND SECTION ='FB'))
		BEGIN
			INSERT INTO FormSectionStatus VALUES (@formid,@Revision_ID,'FB',@FormStatusFlag,getdate(),@web_userid,getdate(),@web_userid,1)
		END
	 ELSE 
		BEGIN
			UPDATE FormSectionStatus SET section_status = @FormStatusFlag WHERE FORM_ID = @formid AND revision_id = @Revision_ID AND SECTION = 'FB'
		END

END

GO
GRANT EXEC ON [dbo].[sp_Validate_FormEcoflo] TO COR_USER;
GO
