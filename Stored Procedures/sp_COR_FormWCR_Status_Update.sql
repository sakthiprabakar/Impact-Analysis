CREATE PROCEDURE sp_COR_FormWCR_Status_Update
      @formid INT,
      @revision_id INT,
	  @displayStatus VARCHAR(30),
	  @webuserid VARCHAR(150)
AS

/* ******************************************************************

	Updated By		: SenthilKumar
	Updated On		: 26th Aug 2019
	Type			: Stored Procedure
	Object Name		: [sp_COR_FormWCR_Status_Update]


	Procedure is used to formwcr status update i.e Draft,Ready For Submission,Accepted,Approved,Submitted,Canceled,Pending Customer Response,Pending Signature

inputs 
	
	 @formid 
     @revision_id 
	 @profileid 
	 @displayStatus 
	 @webuserid 



Samples:
 EXEC sp_COR_FormWCR_Status_Update @form_id,@revision_id ,@displayStatus , @webuserid 
 EXEC [sp_COR_FormWCR_Status_Update] 474805,1, 0,'Pending Signature','manand84'

****************************************************************** */
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	 SET NOCOUNT ON;
	 DECLARE @display_status_uid INT;
	 SET @display_status_uid=(SELECT display_status_uid FROM FormDisplayStatus WHERE display_status = @displayStatus)
	 UPDATE FormWcr SET display_status_uid = @display_status_uid,date_modified=GETDATE(),modified_by=@webuserid WHERE form_id = @formid and revision_id =  @revision_id

	  EXEC [sp_FormWCRStatusAudit_Insert] @formid,@revision_id,@display_status_uid ,@webuserid
END
GO

GRANT EXEC ON [dbo].[sp_COR_FormWCR_Status_Update] TO COR_USER;

GO