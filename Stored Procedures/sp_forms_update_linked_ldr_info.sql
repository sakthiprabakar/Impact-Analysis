
CREATE PROCEDURE sp_forms_update_linked_ldr_info(
 @form_id			int,
 @revision_id		INT
 )
AS
/****************
sp_forms_update_linked_ldr_info

Check if there is a linked ldr for this form/rev id and if so add the 
constituent and wastecodes for that form to the ldr

6/11/2012 CRG Created
05/02/2013 JPB	waste_code_uid added

*****************/
DECLARE	
	@ldr_form_id			int,
	@ldr_revision_id		INT
	
SELECT @ldr_form_id = form_id
	,@ldr_revision_id = revision_id
FROM dbo.FormLDR
WHERE formldr.wcr_id = @form_id
	AND formldr.wcr_rev_id = @revision_id

IF(@ldr_form_id IS NOT NULL)
BEGIN
	INSERT INTO dbo.FormXConstituent
	        ( form_id ,
	          revision_id ,
	          page_number ,
	          line_item ,
	          const_id ,
	          const_desc ,
	          concentration ,
	          unit ,
	          uhc ,
	          specifier
	        )
	SELECT   @ldr_form_id, -- form_id - int
		@ldr_revision_id, -- revision_id - int
		1, -- page_number - int
		1, -- line_item - int
		const_id , -- const_id - int
		const_desc, -- const_desc - varchar(50)
		concentration, -- concentration - float
		unit, -- unit - char(10)
		uhc , -- uhc - char(1)
		'LDR'  -- specifier - varchar(30)
	FROM FormXConstituent
	WHERE form_id = @form_id
		AND revision_id = @revision_ID
	        
	INSERT INTO dbo.FormXWasteCode
        ( form_id ,
          revision_id ,
          page_number ,
          line_item ,
          waste_code ,
          specifier
           ,[waste_code_uid]
        )
	SELECT   
		@ldr_form_id, -- form_id - int
		@ldr_revision_id, -- revision_id - int
		1, -- page_number - int
		1, -- line_item - int
		waste_code, -- waste_code - char(4)
		'LDR'  -- specifier - varchar(30)
		,waste_code_uid
     FROM FormXWasteCode
		WHERE form_id = @form_id
		AND revision_id = @revision_ID
END


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_forms_update_linked_ldr_info] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_forms_update_linked_ldr_info] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_forms_update_linked_ldr_info] TO [EQAI]
    AS [dbo];

