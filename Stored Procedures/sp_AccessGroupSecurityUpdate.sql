CREATE PROCEDURE [dbo].[sp_AccessGroupSecurityUpdate] 
    @group_id INT,
	@record_type char(1),
	@customer_id int = NULL,
	@generator_id int = NULL, 
	@company_id int = NULL, 
	@profit_ctr_id int = NULL,
	@type char(1) = NULL, 
	@status char(1) = NULL,
	@contact_web_access char(1),
	@primary_contact char(1),
	@modified_by varchar(50)
	
	/*
	Description: 
	Updates AccessGroupSecurity table for record_types of (C)ustomer and (G)enerator
	Does not apply to associates - since web_access is a contact only field.  changing access at the CoPc level is a "delete all, then add new" action

	Revision History:
	??/01/2009	RJG 	Created
	12/08/2009	RJG		Added audit info
	
	
	*/
AS 
	SET NOCOUNT ON 
	SET XACT_ABORT ON  
	
	/* does not apply to associates - since web_access is a contact only field.  changing access at the CoPc level is a "delete all, then add new" action*/
	--IF @record_type = 'A'
	--BEGIN
	--	-- update Associate record
	--	UPDATE AccessGroupSecurity
	--	SET
	--		contact_web_access = @contact_web_access
	--	WHERE group_id = @group_id
	--	AND profit_ctr_id = @profit_ctr_id
	--	AND company_id = @company_id
	--END
	
	IF @record_type = 'C'
	BEGIN
		UPDATE AccessGroupSecurity
		SET
			contact_web_access = @contact_web_access,
			primary_contact = @primary_contact,
			[modified_by] = @modified_by,
			[date_modified] = getdate()
		WHERE group_id = @group_id
		AND customer_id = @customer_id
		
	END
	
	IF @record_type = 'G'
	BEGIN
		UPDATE AccessGroupSecurity
		SET
			contact_web_access = @contact_web_access,
			primary_contact = @primary_contact,
			[modified_by] = @modified_by,
			[date_modified] = getdate()			
		WHERE group_id = @group_id
		AND generator_id = @generator_id
	END

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_AccessGroupSecurityUpdate] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_AccessGroupSecurityUpdate] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_AccessGroupSecurityUpdate] TO [EQAI]
    AS [dbo];

