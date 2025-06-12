
CREATE PROCEDURE [dbo].[sp_Copy_Profile]

	@form_id int , 
	@revision_id int,
	@web_user_id nvarchar(100),
	@profile_id int , 
	@copysource nvarchar(10),
	@modified_by_web_user_id nvarchar(100) = '',
	@Message nvarchar(100) Output,
    @formId int OUTPUT,
    @rev_id int output

AS


/* ******************************************************************

	Updated By		: Dineshkumar
	Updated On		: 11st Feb 2019
	Type			: Stored Procedure
	Object Name		: [sp_Copy_Profile]


	Common stored procedure for copy both FormWCR and Profile

	if pass form_id, revision_id and Copy Source, Form will copy
	if pass profile_id and copy source, approved Profile will copy

inputs 
	
	@form_id
	@revision_id
	@web_user_id
	@profile_id
	@copysource
	@Message
	@formId
	@rev_id


Samples:
 EXEC [sp_Copy_Profile]
						@form_id
						@revision_id
						@web_user_id
						@profile_id
						@copysource
						@Message
						@formId
						@rev_id

 EXEC [sp_Copy_Profile] 902383, 1

****************************************************************** */

BEGIN
IF(@form_id != 0)
BEGIN
print '1'
		exec sp_FormWCR_Copy @form_id , @revision_id ,@web_user_id,@modified_by_web_user_id ,@Message,@formId ,@rev_id 
END
ELSE
BEGIN
		exec sp_Approved_Copy @profile_id , @copysource ,@web_user_id,@modified_by_web_user_id
print '2'
END


END

GO

GRANT EXEC ON [dbo].[sp_Copy_Profile] TO COR_USER;

GO