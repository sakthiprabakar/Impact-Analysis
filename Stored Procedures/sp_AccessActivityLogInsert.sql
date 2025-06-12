CREATE PROCEDURE [dbo].[sp_AccessActivityLogInsert] 
    @activity varchar(500),  -- generic activity title (eg: Associate Logon)
    @activity_app varchar(100), -- the application where the activity occurred (eg: EQIP)
    @activity_detail varchar(4000), -- any details relevant
    @activity_screen varchar(100), -- the screen the activity happened on
    @activity_time datetime, -- the date of activity
    @user_code varchar(20), -- user_code (if applicable)
    @user_type char(1), -- what type of record it is (User or Contact)
    @ip_address varchar(50) = null,
    @activity_parameters varchar(500) = null
    
/*	
	Description: 
	Inserts new ActivityLog record
	
	Revision History:
	??/01/2009	RJG 	Created
*/		
AS 
	SET NOCOUNT ON 
	SET XACT_ABORT ON  
	
	BEGIN TRAN
	
	INSERT INTO [dbo].[AccessActivityLog] (
		[activity], 
		[activity_app], 
		[activity_detail], 
		[activity_screen], 
		[activity_time], 
		[user_code], 
		[user_type],
		ip_address,
		activity_parameters
	)
		SELECT 
			@activity, 
			@activity_app, 
			@activity_detail, 
			@activity_screen, 
			@activity_time, 
			@user_code, 
			@user_type,
			@ip_address,
			@activity_parameters
	
	DECLARE @access_activity_id int
	SET @access_activity_id = SCOPE_IDENTITY()
	-- Begin Return Select <- do not remove
	exec sp_AccessActivityLogSelect @access_activity_id	
	-- End Return Select <- do not remove
               
	COMMIT

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_AccessActivityLogInsert] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_AccessActivityLogInsert] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_AccessActivityLogInsert] TO [EQAI]
    AS [dbo];

