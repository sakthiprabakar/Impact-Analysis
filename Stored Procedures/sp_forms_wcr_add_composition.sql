
CREATE OR ALTER PROCEDURE dbo.sp_forms_wcr_add_composition (
	  @form_id		INTEGER
	, @revision_id	INTEGER
	, @sequence_id	INTEGER
	, @desc			VARCHAR(255)	= NULL
	, @from_value	FLOAT			= NULL
	, @to_value		FLOAT			= NULL
	, @unit			VARCHAR(10)		= NULL
)
AS
/****************
sp_forms_wcr_add_composition

11/23/2011 CRG Created
11/06/2013 JPB	Added Unit & Sequence
Updated by Blair Christensen for Titan 05/08/2025

SELECT * FROM FormXWCRComposition where form_id = 238369 and revision_id = 3
*****************/
BEGIN
	INSERT INTO dbo.FormXWCRComposition (form_id, revision_id
		 , comp_description, comp_from_pct, comp_to_pct, unit, sequence_id, comp_typical_pct
		 , date_added, added_by, date_modified, modified_by)
	VALUES (@form_id, @revision_id
		 , @desc,  @from_value, @to_value, @unit, @sequence_id, NULL
		 , GETDATE(), SYSTEM_USER, GETDATE(), SYSTEM_USER
         );
END;
GO

GRANT EXECUTE
    ON OBJECT::[dbo].[sp_forms_wcr_add_composition] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_forms_wcr_add_composition] TO [COR_USER]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_forms_wcr_add_composition] TO [EQAI]
    AS [dbo];
GO
