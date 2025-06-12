CREATE PROCEDURE [dbo].[sp_AccessGroupSecurityInsert] 
    @group_id INT,
    @user_id int,
	@record_type char(1),
	@customer_id int = NULL,
	@generator_id int = NULL, 
	@company_id int = NULL, 
	@profit_ctr_id int = NULL,
	@territory_code varchar(10) = NULL,
	@type char(1) = NULL, 
	@status char(1) = NULL,
	@contact_web_access char(1) = NULL,
	@primary_contact char(1) = NULL,
	@added_by varchar(50) = NULL
	AS 
/*	
	Description: 
	Given a group_id, will insert the requested security information for a record_type (_A_ssociate, _C_ustomer, _G_enerator)

	IMPORTANT: The -9999 code is used in AccessGroupSecurity to denote "all access"
	
	Revision History:
	??/01/2009	RJG 	Created
*/	


 BEGIN

	SET NOCOUNT ON 
	SET XACT_ABORT ON  
	
	--if @company_id = '-9999'
	--	or @profit_ctr_id = '-9999'
	--	or @generator_id = '-9999'
	--	or @customer_id = '-9999'
	--	or @territory_code = '-9999'
	--begin
	--	/* disable existing access in order to grant them a single 'all access'
	--	for this group */
	--	UPDATE AccessGroupSecurity set status = 'I'
	--	where user_id = @user_id
	--	AND group_id = @group_id	
	--	AND record_type = @record_type
	--end
	-- A, P, C, G, L, T
	
	IF @record_type = 'A'
		UPDATE AccessGroupSecurity set status = 'I'
		where user_id = @user_id
		AND group_id = @group_id	
		AND record_type = @record_type
		AND company_id = @company_id
		AND profit_ctr_id = @profit_ctr_id
		
	IF @record_type = 'P'
		UPDATE AccessGroupSecurity set status = 'I'
		where user_id = @user_id
		AND group_id = @group_id	
		AND record_type = @record_type

	IF @record_type = 'C'
		UPDATE AccessGroupSecurity set status = 'I'
		where user_id = @user_id
		AND group_id = @group_id	
		AND record_type = @record_type
		AND customer_id = @customer_id
		
	IF @record_type = 'G'
		UPDATE AccessGroupSecurity set status = 'I'
		where user_id = @user_id
		AND group_id = @group_id	
		AND record_type = @record_type
		AND generator_id = @generator_id

	IF @record_type = 'L'
		UPDATE AccessGroupSecurity set status = 'I'
		where user_id = @user_id
		AND group_id = @group_id	
		AND record_type = @record_type
		AND customer_id = @customer_id
		AND generator_id = @generator_id
		
	IF @record_type = 'T'
		UPDATE AccessGroupSecurity set status = 'I'
		where user_id = @user_id
		AND group_id = @group_id	
		AND record_type = @record_type
		AND territory_code = @territory_code

		-- insert Associate record
		INSERT INTO AccessGroupSecurity (
			group_id,
			user_id,
			record_type,
			customer_id,
			generator_id,
			company_id,
			profit_ctr_id,
			territory_code,
			[type],
			[status],
			contact_web_access,
			primary_contact, 
			added_by,
			date_added)
		VALUES (
			@group_id,
			@user_id,
			@record_type,
			@customer_id,
			@generator_id,
			@company_id,
			@profit_ctr_id,
			@territory_code,
			@type,
			@status,
			@contact_web_access,
			@primary_contact,
			@added_by,
			GETDATE()
		)

END

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_AccessGroupSecurityInsert] TO [EQWEB]
    AS [dbo];
GO

GRANT EXECUTE
    ON OBJECT::[dbo].[sp_AccessGroupSecurityInsert] TO [COR_USER]
    AS [dbo];

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_AccessGroupSecurityInsert] TO [EQAI]
    AS [dbo];

