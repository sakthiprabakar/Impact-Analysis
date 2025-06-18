CREATE OR ALTER PROCEDURE dbo.sp_FormXWCRComposition_Insert (
	  @form_id							int
	, @revision_id						int
	, @comp_description					varchar(40)
	, @comp_from_pct					float
	, @comp_to_pct						float
)
AS
/************************************************************
Procedure	: sp_FormXWCRComposition_Insert
Database	: PLT_AI*
Created		: 5-10-2004 - Jonathan Broome
Description	: Inserts waste information
			  into the FormXWCRComposition table.
  Updated by Blair Christensen for Titan 05/23/2025
************************************************************/
BEGIN

	INSERT INTO dbo.FormXWCRComposition (form_id, revision_id, comp_description, comp_from_pct, comp_to_pct
		 , unit, sequence_id, comp_typical_pct, date_added, added_by, date_modified, modified_by)
	VALUES (@form_id, @revision_id, @comp_description, @comp_from_pct, @comp_to_pct
		   , NULL, NULL, NULL, GETDATE(), SYSTEM_USER, GETDATE(), SYSTEM_USER
		   );

END;
GO

GRANT EXECUTE
    ON OBJECT::[dbo].[sp_FormXWCRComposition_Insert] TO [EQWEB]
    AS [dbo];
GO

GRANT EXECUTE
    ON OBJECT::[dbo].[sp_FormXWCRComposition_Insert] TO [COR_USER]
    AS [dbo];
GO

GRANT EXECUTE
    ON OBJECT::[dbo].[sp_FormXWCRComposition_Insert] TO [EQAI]
    AS [dbo];
GO

