CREATE PROCEDURE [dbo].[sp_AccessActivityLogUpdate] 
    @access_activity_id int, -- id to update
    @activity varchar(500), -- generic activity title (eg: Associate Logon)
    @activity_app varchar(100), -- the application where the activity occurred (eg: EQIP)
    @activity_detail varchar(4000), -- any details relevant
    @activity_screen varchar(100), -- the screen the activity happened on
    @activity_time datetime, -- the date of activity
    @contact_id int, -- contact (if applicable)
    @user_code varchar(20), -- user_code (if applicable)
    @user_type char(1), -- what type of record it is (User or Contact)
    @ip_address varchar(50),
    @activity_parameters varchar(500)    
	
/*	
	Description: 
	Updates a  AccessActivityLog record

	Revision History:
	??/01/2009	RJG 	Created
*/	
	
AS 
	SET NOCOUNT ON 
	SET XACT_ABORT ON  
	
	BEGIN TRAN

	UPDATE [dbo].[AccessActivityLog]
	SET    
		[activity] = @activity, 
		[activity_app] = @activity_app, 
		[activity_detail] = @activity_detail, 
		[activity_screen] = @activity_screen, 
		[activity_time] = @activity_time, 
		[user_code] = @user_code, 
		[user_type] = @user_type,
		ip_address = @ip_address,
		activity_parameters = @activity_parameters
	WHERE  [access_activity_id] = @access_activity_id
	
	-- Begin Return Select <- do not remove
	exec sp_AccessActivityLogSelect @access_activity_id	
	-- End Return Select <- do not remove

	COMMIT TRAN

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_AccessActivityLogUpdate] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_AccessActivityLogUpdate] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_AccessActivityLogUpdate] TO [EQAI]
    AS [dbo];

