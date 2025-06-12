USE [PLT_AI]
GO
/*****************************************************************************************/
DROP PROCEDURE IF EXISTS [dbo].[sp_FormWCR_insert_update_section_L] 
GO
CREATE PROCEDURE [dbo].[sp_FormWCR_insert_update_section_L]
	-- Add the parameters for the stored procedure here
	       @Data XML,
		   @form_id int,
		   @revision_id int
AS
/* 
-- =============================================
-- Author:  Senthil Kumar
-- Create date: 14th Aug, 2019
-- Description: To insert Facility 
-- =============================================
  Updated By   : Ranjini C
  Updated On   : 08-AUGUST-2024
  Ticket       : 93217
  Decription   : This procedure is used to assign web_userid to created_by and modified_by columns. 
EXEC [sp_FormWCR_insert_update_section_L] '<SectionL>
<IsEdited>SL</IsEdited>
<routing_facility>44|0</routing_facility>
<USEFacility/>
</SectionL>', 497830, 1
 */
BEGIN
	SET NOCOUNT ON;
	select @Data
	BEGIN TRY
		UPDATE FormWCR 
		SET 
			routing_facility = p.v.value('routing_facility[1]','nvarchar(5)') , 
			approval_code = p.v.value('approval_code[1]','nvarchar(20)')  
		FROM
        @Data.nodes('SectionL')p(v) WHERE form_id = @form_id and revision_id=  @revision_id
	END TRY
	BEGIN CATCH
		declare @procedure nvarchar(150), 
				@mailTrack_userid nvarchar(60) = 'COR'
				set @procedure = ERROR_PROCEDURE()
				declare @error nvarchar(4000) = ERROR_MESSAGE()
				declare @error_description nvarchar(4000) = 'Form ID: ' + convert(nvarchar(15), @form_id) + '-' +  convert(nvarchar(15), @revision_id) 
															+ CHAR(13) + 
															+ CHAR(13) + 
														   'Error Message: ' + isnull(@error, '')
														   + CHAR(13) + 
														   + CHAR(13) + 
														   'Data:  ' + convert(nvarchar(4000), @Data)														   
				EXEC [COR_DB].[DBO].sp_COR_Exception_MailTrack
						@web_userid = @mailTrack_userid, 
						@object = @procedure,
						@body = @error_description
	END CATCH
END
GO
	GRANT EXECUTE ON [dbo].[sp_FormWCR_insert_update_section_L] TO COR_USER;
GO
/*****************************************************************************************/