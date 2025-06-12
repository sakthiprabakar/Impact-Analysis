/**************************************************************************
Load to plt_ai

11/29/2004 MK	Updates eqfax password on EQFax
05/01/2007 WAC	Commented out SQL in this procedure because EQAI already has 
		these SQL insert/update as script in w_logon.wf_sync_password,
		w_change_password.wf_sql_password and w_users.wf_sql_password.
		This will allow a fix without a deploy of EQAI.

DELETE FROM EQFax WHERE user_code = 'jason_b'
SELECT * FROM EQFax WHERE user_code = 'jason_b'
SELECT * FROM EQFax WHERE status <> 'C'
sp_eqfax_user 'USER', 'PASSWORD', 'I'
**************************************************************************/
CREATE PROCEDURE sp_eqfax_user
	@user_code 	varchar(8), 
	@password	varchar(20),
	@status		char(1)
AS

-- DECLARE @user_cnt 	smallint, 
-- 	@user_id_cnt 	smallint, 
-- 	@msg 		varchar(100), 
-- 	@user_name	varchar(40),
-- 	@errorcount 	int,
-- 	@password_new	varchar(128)
-- 
-- SELECT @password_new = master.dbo.fn_encode(@password)
-- 
-- SELECT @user_cnt = COUNT(*) FROM EQFax WHERE user_code = @user_code
--     IF @user_cnt = 0
--     BEGIN
-- 	SELECT @user_name = user_name from users WHERE user_code = @user_code 
-- 
-- 	INSERT INTO EQFax (user_code, password, user_name, status, date_added)
-- 	VALUES (@user_code, @password_new, @user_name, @status, GETDATE())
-- 	IF @@ERROR <> 0 
-- 	BEGIN
-- 	    SELECT @msg = 'Error adding user to EQFax table'
-- 	END
--     END
--     ELSE
--     BEGIN
-- 	UPDATE EQFax 
-- 	SET password=@password_new,
-- 	    status=@status
-- 	WHERE user_code=@user_code
-- 	IF @@ERROR <> 0 
-- 	BEGIN
-- 	    SELECT @msg = 'Error updating user in EQFax table'
-- 	END
-- 	
--     END
  RETURN

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_eqfax_user] TO PUBLIC
    AS [dbo];

