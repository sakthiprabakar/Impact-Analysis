CREATE PROCEDURE [dbo].[sp_AccessGroupSecurityDeleteAllAccess] 
    @group_id INT,
    @user_id int,
	@record_type char(1),   -- '(A)ssociate, (C)ustomer, (G)enerator
	@modified_by varchar(50)
/*	
	Description: 
	Given a group_id and record_type (A,C,G) will delete ALL the security information for that group's record type (Associate, Customer, Generator)

	IMPORTANT: The -9999 code is used in AccessGroupSecurity to denote "all access"
	
	Revision History:
	??/01/2009	RJG 	Created
*/		
AS 
	SET NOCOUNT ON 
	SET XACT_ABORT ON  
	
	IF @record_type = 'A'
	BEGIN
		UPDATE AccessGroupSecurity
		SET 
			status = 'I',
			modified_by = @modified_by,
			date_modified = GETDATE()
		WHERE group_id = @group_id
		AND user_id = @user_id
		AND profit_ctr_id IS NOT NULL
		AND company_id IS NOT NULL
		AND record_type = @record_type
		AND status = 'A'			
				
		/*DELETE FROM AccessGroupSecurity
		WHERE group_id = @group_id
		AND profit_ctr_id IS NOT NULL
		AND company_id IS NOT NULL*/
	END
	
	IF @record_type = 'C'
	BEGIN
		UPDATE AccessGroupSecurity
		SET 
			status = 'I',
			modified_by = @modified_by,
			date_modified = GETDATE()
		WHERE group_id = @group_id
		AND user_id = @user_id
		AND customer_id IS NOT NULL
		AND record_type = @record_type
		AND status = 'A'
				
		/*DELETE FROM AccessGroupSecurity
		WHERE group_id = @group_id
		AND customer_id IS NOT NULL*/
		
	END
	
	IF @record_type = 'G'
	BEGIN
		UPDATE AccessGroupSecurity
		SET 
			status = 'I',
			modified_by = @modified_by,
			date_modified = GETDATE()
		WHERE group_id = @group_id
		AND user_id = @user_id
		AND generator_id IS NOT NULL
		AND record_type = @record_type
		AND status = 'A'		
			
		/*DELETE FROM AccessGroupSecurity
		WHERE group_id = @group_id
		AND generator_id IS NOT NULL*/
	END
	
	IF @record_type = 'T'
	BEGIN
		UPDATE AccessGroupSecurity
		SET 
			status = 'I',
			modified_by = @modified_by,
			date_modified = GETDATE()
		WHERE group_id = @group_id
		AND user_id = @user_id
		AND territory_code IS NOT NULL
		AND record_type = @record_type
		AND status = 'A'		
			
		/*DELETE FROM AccessGroupSecurity
		WHERE group_id = @group_id
		AND generator_id IS NOT NULL*/
	END	
	
	IF @record_type = 'L'
	BEGIN
		UPDATE AccessGroupSecurity
		SET 
			status = 'I',
			modified_by = @modified_by,
			date_modified = GETDATE()
		WHERE group_id = @group_id
		AND user_id = @user_id
		AND customer_id IS NOT NULL
		AND generator_id IS NOT NULL
		AND record_type = @record_type
		AND status = 'A'		
			
		/*DELETE FROM AccessGroupSecurity
		WHERE group_id = @group_id
		AND generator_id IS NOT NULL*/
	END		
	
	IF @record_type = 'P' -- permission level
	BEGIN
		UPDATE AccessGroupSecurity
		SET 
			status = 'I',
			modified_by = @modified_by,
			date_modified = GETDATE()
		WHERE group_id = @group_id
		AND user_id = @user_id
		AND record_type = @record_type
		AND status = 'A'				
	END

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_AccessGroupSecurityDeleteAllAccess] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_AccessGroupSecurityDeleteAllAccess] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_AccessGroupSecurityDeleteAllAccess] TO [EQAI]
    AS [dbo];

