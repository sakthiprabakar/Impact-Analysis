
USE PLT_AI
GO

DROP PROCEDURE IF EXISTS [dbo].[sp_COR_GetBulkRenewed_Forms];
GO

CREATE PROCEDURE [dbo].[sp_COR_GetBulkRenewed_Forms]
	@web_userid VARCHAR(200),
	@profile_id_csv_list NVARCHAR(max),
	@impersonated_web_userid VARCHAR(200) = ''	
AS

/*
   Updated by	:   Sathiyamoorthi
   Updated On	:	23 AUG 2024
   Object		:	sp_COR_GetBulkRenewed_Forms
   Description	:	to Renew multiple Profiles   (Requirement 12650: COR2 Bulk Renewal Process)
   Exec Stmt	:	Exec sp_COR_GetBulkRenewed_Forms 
							@web_userid = 'manand84', 
							@profile_id_csv_list = '699515',
							@impersonated_web_userid = ''
*/


BEGIN

BEGIN TRY 

BEGIN TRAN renew_form
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	DECLARE @modified_by_web_user_id VARCHAR(150) 
	CREATE TABLE #profile_ids (
    profile_id BIGINT
     );

	 CREATE TABLE #renewedforms (
    form_id NVARCHAR(50),
    revision_id INT,
    profile_id NVARCHAR(50));

	DECLARE @profile_id INT;
	DECLARE @i_period_int INT = 60;

	SET  @modified_by_web_user_id= @impersonated_web_userid
	INSERT INTO #profile_ids(profile_id)
	SELECT CONVERT(BIGINT, row)
		FROM dbo.fn_SplitXsvText(',', 1, REPLACE(@profile_id_csv_list, ' ', ','))
		where ISNUMERIC(row) = 1 AND row NOT LIKE '%.%'

	

	DECLARE cursor_profile CURSOR
		FOR SELECT profile_id FROM #profile_ids;

		OPEN cursor_profile;

		FETCH NEXT FROM cursor_profile INTO @profile_id

		WHILE @@FETCH_STATUS = 0
		BEGIN

			DECLARE @copysource VARCHAR(20) = 'renewal';

			DECLARE @r_form_id NVARCHAR(50) = ''
			DECLARE @r_revision_id NVARCHAR(50) = ''

					EXEC [sp_Approved_Copy]
						@profile_id,
						@copysource,
						@web_userid,
						@modified_by_web_user_id,
						@r_form_id OUT,
						@r_revision_id OUT
					 

					INSERT INTO #renewedforms (form_id, revision_id,profile_id)
					SELECT @r_form_id,  @r_revision_id,@profile_id

			DECLARE @bulkrenewprofile_id  INT = (SELECT profile_id 
													FROM formwcr 
													WHERE  CONCAT(form_id, '-',revision_id)=@r_form_id)

			UPDATE BulkRenewProfile set status='pending' where status = 'validated' and profile_id =  @bulkrenewprofile_id
		--END
			
		FETCH NEXT FROM cursor_profile INTO @profile_id;
	END;

	CLOSE cursor_profile;

	DEALLOCATE cursor_profile;

	SELECT * FROM #renewedforms

	COMMIT TRAN renew_form

END TRY

BEGIN CATCH
	  
		  DECLARE  @Message VARCHAR(2000);				
				SET @Message = Error_Message();
				SELECT @Message  MessageResult				
				INSERT INTO COR_DB.[dbo].[ErrorLogs] (ErrorDescription,[Object_Name],Web_user_id,CreatedDate)
		                VALUES('Error Message -->'  + Error_Message(),ERROR_PROCEDURE(),@web_userid,GETDATE())

	ROLLBACK TRAN renew_form

END CATCH

END

GO
GRANT EXECUTE ON [dbo].[sp_COR_GetBulkRenewed_Forms] TO COR_USER;
GO