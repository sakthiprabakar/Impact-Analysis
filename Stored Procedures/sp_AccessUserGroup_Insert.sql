CREATE PROCEDURE [dbo].[sp_AccessUserGroup_Insert] 
    @group_id int,
    @user_id int,
    @added_by varchar(50)
/*	
	Description: 
	Associates a user with a group

	Revision History:
	??/01/2009	RJG 	Created
	12/08/2009	RJG		Added audit info
*/			
AS 
	SET NOCOUNT ON 
	SET XACT_ABORT ON  
	
	BEGIN TRAN
	
		-- check for duplicate
	IF NOT EXISTS (SELECT * FROM AccessUserXGroup WHERE user_id = @user_id AND group_id = @group_id)
	BEGIN
	
		INSERT INTO [dbo].[AccessUserXGroup] (
			[group_id], 
			[user_id],
			[added_by],
			[date_added])
		SELECT 
			@group_id, 
			@user_id, 
			@added_by, 
			GETDATE()
	
	END
	-- Begin Return Select <- do not remove
	SELECT *
	FROM   [dbo].[AccessUserXGroup]
	WHERE  [group_id] = @group_id
	       AND [user_id] = @user_id
	-- End Return Select <- do not remove
               
	COMMIT

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_AccessUserGroup_Insert] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_AccessUserGroup_Insert] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_AccessUserGroup_Insert] TO [EQAI]
    AS [dbo];

