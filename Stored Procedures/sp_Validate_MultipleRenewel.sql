USE [PLT_AI]
GO



CREATE PROCEDURE [dbo].[sp_Validate_MultipleRenewel] 
	-- Add the parameters for the stored procedure here
	@profile_id int 
AS

/* ******************************************************************
		Author		:	Mubarak
		Create date	:	Sep 30, 2021
		Description	:	Task 29638: URGENT - PROD COR/EQAI - Profile - Multiple Renewal Forms Generated
	
		Exec Stmt	:  exec sp_Validate_MultipleRenewel '659778'
****************************************************************** */
BEGIN

	
	declare  @setstatus char(1)
	 
    -- Insert statements for procedure here
	if (select Top 1 count(*) from profile where 
	((document_update_status is null ) or (document_update_status !='P') )and ((inactive_flag is null) or (inactive_flag !='T')) and
	((reapproval_allowed is null ) or (reapproval_allowed !='F') ) and ((doc_status_reason IS NULL) OR (doc_status_reason != 'Data Update') ) and profile_id = @profile_id ) = 1
	Begin
		SET @setstatus = 'T'
	END
	Else
	Begin
		SET @setstatus = 'F'
	End
	select @setstatus

END

GO

GRANT EXECUTE ON [dbo].[sp_Validate_MultipleRenewel] TO COR_USER;

GO