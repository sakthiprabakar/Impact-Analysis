ALTER PROCEDURE dbo.sp_forms_add_codes (
	  @waste_codes VARCHAR(1000)
	, @waste_code_type VARCHAR(55)
	, @form_id INTEGER
	, @revision_id INTEGER
	)
AS
/****************
11/23/2011 TO	Created
06/27/2012 TO	Changed to use waste_code_id instead of waste_code so that it can handle multiple wastecodes w/ the same code
04/22/2013 JPB	Thrilled to find waste_code_uid already used, just not saved.
				Added Saving of waste_code_uid in FormXWasteCode as part of Texas Waste Code project
				Rearranged save logic to avoid lame string parsing loop.
Updated by Blair Christensen for Titan 05/08/2025
sp_forms_add_codes

Adds a list of waste codes to a given form_id / revision_id in 
*****************/	
BEGIN
	INSERT INTO dbo.FormXWasteCode (form_id, revision_id, page_number, line_item
		 , waste_code_uid, waste_code, specifier
	     , lock_flag, added_by, date_added, modified_by, date_modified) 
		SELECT @form_id, @revision_id, NULL, NULL
			 , wc.waste_code_uid
			 , wc.waste_code
			 , @waste_code_type
			 , NULL, SYSTEM_USER, GETDATE(), SYSTEM_USER, GETDATE()
		  FROM dbo.WasteCode wc
			   JOIN dbo.fn_SplitXSVText(' ', 1, @waste_codes) f on wc.waste_code_uid = f.[row]
		 WHERE ISNULL(f.[row], '') <> '';
END
GO

GRANT EXECUTE
    ON OBJECT::[dbo].[sp_forms_add_codes] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_forms_add_codes] TO [COR_USER]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_forms_add_codes] TO [EQAI]
    AS [dbo];
GO
