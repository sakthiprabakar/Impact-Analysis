DROP PROCEDURE IF EXISTS [sp_Validate_ProfileEcoflo]
GO

CREATE PROCEDURE [dbo].[sp_Validate_ProfileEcoflo]
	@profile_id INT,
	@web_userid nvarchar(200)
AS

/***********************************************************************************
 
    Updated By    : Nallaperumal C
    Updated On    : 14-october-2023
    Type          : Store Procedure 
    Object Name   : [sp_Validate_ProfileEcoflo]
    Ticket        : 73641
                                                    
    Execution Statement    
	
	EXEC  [dbo].[sp_Validate_ProfileEcoflo]  @formid, @revision_ID, @web_userid
 
*************************************************************************************/

BEGIN


	DECLARE @ValidColumnNullCount INTEGER;
	DECLARE @TotalValidColumn INTEGER; -- Based Select Column count
	DECLARE @SectionType VARCHAR;

	DECLARE @ProfileStatusFlag VARCHAR(1) = 'Y';
	
	
	SET @SectionType = 'FB'
	SET @TotalValidColumn = 1

	SET  @ValidColumnNullCount = (SELECT  (
					(CASE WHEN COALESCE(viscosity_value, '') = '' THEN 1 ELSE 0 END)
					+(CASE WHEN COALESCE(total_solids_low, '') = '' THEN 1 ELSE 0 END)
					+(CASE WHEN COALESCE(total_solids_high, '') = '' THEN 1 ELSE 0 END)
					+(CASE WHEN COALESCE(total_solids_description, '') = '' THEN 1 ELSE 0 END)
					+(CASE WHEN (fluorine_low_flag != 'T' AND fluorine_low IS NULL OR (CAST(fluorine_low AS VARCHAR(40))) = '') THEN 1 ELSE 0 END)
					+(CASE WHEN (fluorine_high_flag != 'T' AND fluorine_high IS NULL OR (CAST(fluorine_high AS VARCHAR(40))) = '') THEN 1 ELSE 0 END)
					+(CASE WHEN (chlorine_low_flag != 'T' AND chlorine_low IS NULL OR (CAST(chlorine_low AS VARCHAR(40))) = '') THEN 1 ELSE 0 END)
					+(CASE WHEN (chlorine_high_flag != 'T' AND chlorine_high IS NULL OR (CAST(chlorine_high AS VARCHAR(40))) = '') THEN 1 ELSE 0 END)
					+(CASE WHEN (bromine_low_flag != 'T' AND bromine_low IS NULL OR (CAST(bromine_low AS VARCHAR(40))) = '') THEN 1 ELSE 0 END)
					+(CASE WHEN (bromine_high_flag != 'T' AND bromine_high IS NULL OR (CAST(bromine_high AS VARCHAR(40))) = '') THEN 1 ELSE 0 END)
					+(CASE WHEN (iodine_low_flag != 'T' AND iodine_low IS NULL OR (CAST(iodine_low AS VARCHAR(40))) = '') THEN 1 ELSE 0 END)
					+(CASE WHEN (iodine_high_flag != 'T' AND iodine_high IS NULL OR (CAST(iodine_high AS VARCHAR(40))) = '') THEN 1 ELSE 0 END)
				    ) AS sum_of_nulls
			From ProfileEcoflo
			Where profile_id =  @profile_id)

	--	select column from ProfileEcoflo using form_id  
	print cast( @ValidColumnNullCount as varchar(10))

	IF 	@ValidColumnNullCount != 0 
		BEGIN
			SET @ProfileStatusFlag = 'P'
		END
	
	IF(NOT EXISTS(SELECT * FROM ProfileSectionStatus WHERE profile_id =@profile_id AND SECTION ='FB'))
		BEGIN
			INSERT INTO ProfileSectionStatus VALUES (@profile_id,'FB',@ProfileStatusFlag,getdate(),@web_userid,getdate(),@web_userid,1)
		END
	 ELSE 
		BEGIN
			UPDATE ProfileSectionStatus SET section_status = @ProfileStatusFlag WHERE profile_id = @profile_id AND SECTION = 'FB'
		END

END



GO
GRANT EXEC ON [dbo].[sp_Validate_ProfileEcoflo] TO COR_USER;
GO