USE PLT_AI
GO

DROP PROCEDURE IF EXISTS [dbo].[sp_Profile_SourceStatus_Update];
GO

CREATE PROCEDURE [dbo].[sp_Profile_SourceStatus_Update]
      @formid INT,
      @revision_id INT,
	  @profileid INT,
	  @copysource VARCHAR(30),
	  @webuserid VARCHAR(150),
	  @modified_by_web_user_id VARCHAR(150) = ''
AS

/* ******************************************************************

	Updated By		: Sathiyamoorthi
	Updated On		:  30th AUG 2024
	Type			: Stored Procedure
	Object Name		: [sp_Profile_SourceStatus_Update]


	Procedure is used to profile source status update i.e copy,amendment,discard,cancel,undo,renewal,template

inputs 
	
	 @formid 
     @revision_id 
	 @profileid 
	 @copysource 
	 @webuserid 



Samples:
 EXEC sp_Profile_SourceStatus_Update @form_id,@revision_id, @profileid ,@copysource , @webuserid 
 EXEC [sp_Profile_SourceStatus_Update] 479137,1, 0,'discard','manand84'

****************************************************************** */
BEGIN
BEGIN TRY

IF ISNULL(@modified_by_web_user_id, '') = '' SET @modified_by_web_user_id = @webuserid

IF OBJECT_ID(N'tempdb..#tempFormDisplayStatus') IS NOT NULL
	BEGIN
		DROP TABLE tempFormDisplayStatus
	END	

	create table #tempFormDisplayStatus 
	(
		display_status_uid int,
		display_status varchar(100),
	)

	insert into #tempFormDisplayStatus
	select * from (SELECT display_status_uid,display_status FROM FormDisplayStatus) tf

 DECLARE @displaystatus INT;
	set @copysource = LOWER(@copysource)
    IF @copysource = 'DISCARD' OR @copysource = 'discard'
     BEGIN 
	  -- Pending 
	  IF (@formid != 0 OR @formid IS NOT NULL ) AND (@revision_id !=0 OR @revision_id IS NOT NULL)
	   BEGIN	
	         
	      SET @displaystatus = (SELECT display_status_uid FROM FORMWCR WHERE form_id = @formid AND revision_id =  @revision_id)		  
		  IF @displaystatus in (SELECT display_status_uid FROM #tempFormDisplayStatus WHERE display_status in('Draft','Not Submitted','Ready For Submission','Pending Customer Response'))								
		    BEGIN
			select @displaystatus
			  SET @displaystatus=(SELECT display_status_uid FROM #tempFormDisplayStatus WHERE display_status = 'Deleted')
	          UPDATE FormWcr SET display_status_uid = @displaystatus WHERE form_id = @formid and revision_id =  @revision_id
			   -- Track form history status
				EXEC [sp_FormWCRStatusAudit_Insert] @formid,@revision_id,@displaystatus ,@webuserid
	        END
		  ELSE IF  @displaystatus = (SELECT display_status_uid FROM #tempFormDisplayStatus WHERE display_status = 'Submitted')		  
			BEGIN
			  SET @displaystatus=(SELECT display_status_uid FROM #tempFormDisplayStatus WHERE display_status = 'Ready For Submission')
		      UPDATE FormWcr SET display_status_uid = @displaystatus WHERE form_id = @formid and revision_id =  @revision_id
			    -- Track form history status
				EXEC [sp_FormWCRStatusAudit_Insert] @formid,@revision_id,@displaystatus ,@webuserid
			END
			
	   END
	  
	END

	IF @copysource = 'cancel' 
	 BEGIN
	  -- APPROVAL 
	   IF (@profileid != 0 OR @profileid IS NOT NULL )
	    BEGIN
		SET @displaystatus=(SELECT display_status_uid FROM #tempFormDisplayStatus WHERE display_status = 'Deleted')
	      UPDATE PROFILE SET display_status_uid = @displaystatus WHERE profile_id = @profileid
		   -- Track form history status
			EXEC [sp_FormWCRStatusAudit_Insert] @formid,@revision_id,@displaystatus ,@webuserid
	    END
      END

	 IF @copysource = 'unsubmit' 
	 BEGIN
	  -- APPROVAL 
	   IF (@formid != 0 OR @formid IS NOT NULL ) AND (@revision_id !=0 OR @revision_id IS NOT NULL)
	    BEGIN
		SET @displaystatus=(SELECT display_status_uid FROM #tempFormDisplayStatus WHERE display_status = 'Ready For Submission')
	      UPDATE FormWcr SET display_status_uid = @displaystatus, signing_date = null WHERE form_id = @formid and revision_id =  @revision_id
		  -- Track form history status
			EXEC [sp_FormWCRStatusAudit_Insert] @formid,@revision_id,@displaystatus ,@webuserid

			--remove signed document ticket# 15817
			declare @signeddocument_available int = (select top 1 image_id from plt_image..scan (nolock) where form_id = @formid and revision_id = @revision_id 
													and (document_source = 'APPRFORM' or document_source = 'APPRRECERT' or document_source = 'CORDOC'))
			IF(@signeddocument_available > 0)
			BEGIN
				UPDATE plt_image..scan set form_id = null, revision_id = null where form_id = @formid and revision_id = @revision_id 
													and (document_source = 'APPRFORM' or document_source = 'APPRRECERT' or document_source = 'CORDOC') 
			END

	    END
    END

	IF @copysource = 'undo'
	 BEGIN 
	   IF (@formid != 0 AND @formid IS NOT NULL ) AND (@revision_id !=0 AND @revision_id IS NOT NULL)
        BEGIN
	        DECLARE @profile_id INT
		    SET @profile_id = (SELECT profile_id FROM FORMWCR WHERE form_id = @formid AND revision_id =  @revision_id)
			SET @displaystatus =(SELECT display_status_uid FROM #tempFormDisplayStatus WHERE display_status = 'Deleted')
		    UPDATE FormWcr SET display_status_uid = @displaystatus WHERE form_id = @formid and revision_id =  @revision_id
	        -- Track form history status
			
			EXEC [sp_FormWCRStatusAudit_Insert] @formid,@revision_id,@displaystatus ,@webuserid
			print @profile_id
			IF @profile_id != 0 OR @profile_id IS NOT NULL
			 BEGIN			
			 --select document_update_status,* from [profile] where profile_id=@profile_id
				UPDATE [Profile] Set document_update_status = 'A' WHERE profile_id = @profile_id			  
			 END

			 DECLARE @bulkrnenw_profile_id INT
			 SET @bulkrnenw_profile_id = (SELECT TOP 1 profile_id FROM BulkRenewProfile WHERE profile_id=@profile_id)
			 IF @bulkrnenw_profile_id != 0 OR @bulkrnenw_profile_id IS NOT NULL
			 BEGIN			
			 DELETE FROM BulkRenewProfile WHERE profile_id=@bulkrnenw_profile_id
			 END

	    END
	END
	

	IF @copysource = 'copy' OR @copysource = 'amendment' or @copysource = 'renewal' or @copysource = 'template' --amendment
	 BEGIN 
	   IF (@formid != 0 OR @formid IS NOT NULL ) AND (@revision_id !=0 OR @revision_id IS NOT NULL)
        BEGIN
			-- waiting insert formwcrtemplate 
		 EXEC sp_FormWCR_Copy @formid,@revision_id ,@webuserid ,@modified_by_web_user_id,'',0, 0
		END

	

		--SELECT * FROM FormCOPYSOURCE
	   IF (@formid = 0 OR @formid IS NULL ) AND (@revision_id =0 OR @revision_id IS NULL) AND (@profileid != 0 OR @profileid IS NOT NULL )
	    BEGIN
	      -- profile copy exec implement
		  EXEC sp_Approved_Copy @profileid , @copysource , @webuserid,@modified_by_web_user_id
	    END
	 END
	
	
	--Select 1 as Result;
	 Select 1 as Result;
	 
End try
Begin Catch 
    Select ERROR_MESSAGE() as Error;
End Catch
   
END

GO
GRANT EXEC ON [dbo].[sp_Profile_SourceStatus_Update] TO COR_USER;
GO
