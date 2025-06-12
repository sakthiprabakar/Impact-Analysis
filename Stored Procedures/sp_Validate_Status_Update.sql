
CREATE PROCEDURE  [dbo].[sp_Validate_Status_Update]
	-- Add the parameters for the stored procedure here
	@formid INT,
    @revision_id INT
AS


/*******************************************************************

procedure to update the status of form.

i.e)
		Form Status will be update based on the individual section status

		e.g) If all Section Status is 'Y' then the form status will be updated as Not submitted
				otherwise form status mode considered as Draft 

inputs 
	
	@web_userid



Samples:
 EXEC [sp_Validate_Status_Update] @formid, @revision_id

 EXEC [sp_Validate_Status_Update] 89034, 1

****************************************************************** */

BEGIN
	DECLARE @ValidCompleteSection INTEGER;
	DECLARE @TotalValidSection INTEGER; -- Based on Section count


	SET @TotalValidSection = (SELECT  Count(*)  AS sum_of_validsection
			From FormSectionStatus
			Where 
			form_id =  @formid and revision_id =  @revision_id AND isActive = 1)

	SET  @ValidCompleteSection = (SELECT  Count(*)  AS sum_of_completed
			From FormSectionStatus
			Where 
			form_id =  @formid and revision_id =  @revision_id AND isActive = 1 and  section_status = 'Y')

-- SECTION STATUS in FORMWCR

--select * from FormDisplayStatus

--SELECT * FROM FormSectionStatus
DECLARE @web_userid nvarchar(60)=(SELECT modified_by FROM FormWcr WHERE form_id = @formid AND revision_id = @Revision_ID)
DECLARE @display_status_uid INT
IF (@ValidCompleteSection = @TotalValidSection)
  --- CHECKING FORM DOCUMENT DETAILS
    -- IF DOCUMENT SUB - Submitted
    -- ELSE - Not Submitted
    -- BEGIN
	--  UPDATE FormWcr SET display_status_uid = (SELECT display_status_uid FROM FormDisplayStatus WHERE display_status = 'Not Submitted') WHERE form_id = @formid and revision_id =  @revision_id
	-- END
	BEGIN
	  SET @display_status_uid  =(SELECT display_status_uid FROM FormDisplayStatus WHERE display_status = 'Ready For Submission')
	  UPDATE FormWcr SET display_status_uid = @display_status_uid WHERE form_id = @formid and revision_id =  @revision_id
	  -- Track form history status
	 EXEC [sp_FormWCRStatusAudit_Insert] @formid,@revision_id,@display_status_uid ,@web_userid
	END
ELSE
   BEGIN
	  SET @display_status_uid  =(SELECT display_status_uid FROM FormDisplayStatus WHERE display_status = 'Draft')
	  UPDATE FormWcr SET display_status_uid =@display_status_uid WHERE form_id = @formid and revision_id =  @revision_id
	  -- Track form history status
	 EXEC [sp_FormWCRStatusAudit_Insert] @formid,@revision_id,@display_status_uid ,@web_userid
   END

END

GO
GRANT EXEC ON [dbo].[sp_Validate_Status_Update] TO COR_USER;




 