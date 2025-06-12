CREATE PROCEDURE [dbo].[sp_AccessGroupSecurityDelete] 
    @group_id INT,
    @user_id int,
	@record_type char(1),
	@customer_id int = NULL,
	@generator_id int = NULL, 
	@company_id int = NULL, 
	@profit_ctr_id int = NULL,
	@territory_code varchar(10) = NULL,
	@modified_by varchar(50)
/*	
	Description: 
	Deletes specific security information from AccessGroupSecurity table

	Revision History:
	??/01/2009	RJG 	Created
	12/08/2009	RJG		Changed DELETE statements to just de-activating the line
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
		AND profit_ctr_id = @profit_ctr_id
		AND company_id = @company_id
		AND user_id = @user_id
		AND status = 'A'
		and record_type = @record_type
						
		/*DELETE FROM AccessGroupSecurity
		WHERE group_id = @group_id
		AND profit_ctr_id = @profit_ctr_id
		AND company_id = @company_id
		AND status = 'A'*/
	END
	
	IF @record_type = 'C'
	BEGIN
		UPDATE AccessGroupSecurity
		SET 
			status = 'I',
			modified_by = @modified_by,
			date_modified = GETDATE()
		WHERE group_id = @group_id
		AND customer_id = @customer_id
		AND user_id = @user_id
		AND status = 'A'
		and record_type = @record_type
						
		/*DELETE FROM AccessGroupSecurity
		WHERE group_id = @group_id
		AND customer_id = @customer_id
		AND status = 'A'*/
		
	END
	
	IF @record_type = 'G'
	BEGIN
		UPDATE AccessGroupSecurity
		SET 
			status = 'I',
			modified_by = @modified_by,
			date_modified = GETDATE()
		WHERE group_id = @group_id
		AND generator_id = @generator_id
		AND user_id = @user_id
		AND status = 'A'
		and record_type = @record_type	
	
		/*DELETE FROM AccessGroupSecurity
		WHERE group_id = @group_id
		AND generator_id = @generator_id*/
	END
	
	IF @record_type = 'T'
	BEGIN
		UPDATE AccessGroupSecurity
		SET 
			status = 'I',
			modified_by = @modified_by,
			date_modified = GETDATE()
		WHERE group_id = @group_id
		AND territory_code = @territory_code
		AND user_id = @user_id
		AND status = 'A'	
		and record_type = @record_type		
	END

	IF @record_type = 'L'
	BEGIN
		UPDATE AccessGroupSecurity
		SET 
			status = 'I',
			modified_by = @modified_by,
			date_modified = GETDATE()
		WHERE group_id = @group_id
		AND customer_id = @customer_id
		AND generator_id = @generator_id
		AND user_id = @user_id
		AND status = 'A'	
		and record_type = @record_type
	END	
	

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_AccessGroupSecurityDelete] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_AccessGroupSecurityDelete] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_AccessGroupSecurityDelete] TO [EQAI]
    AS [dbo];

