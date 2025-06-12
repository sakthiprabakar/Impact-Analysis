
CREATE PROCEDURE sp_forms_add_codes(
	@waste_codes varchar(max),
	@waste_code_type varchar(55),
	@form_id int,
	@revision_id int
	)
AS
/****************
11/23/2011 TO	Created
06/27/2012 TO	Changed to use waste_code_id instead of waste_code so that it can handle multiple wastecodes w/ the same code
04/22/2013 JPB	Thrilled to find waste_code_uid already used, just not saved.
				Added Saving of waste_code_uid in FormXWasteCode as part of Texas Waste Code project
				Rearranged save logic to avoid lame string parsing loop.

sp_forms_add_codes

Adds a list of waste codes to a given form_id / revision_id in 
*****************/	

/* OLD:
	
	--loop through list and insert codes
	DECLARE @Item             VARCHAR(50)
	DECLARE @Position         INT
	DECLARE @Loop             BIT

	--Make sure we enter the loop, even if there's only one item
	IF(right(@waste_codes,1) <> ' ' and Len(@waste_codes)>0)
	BEGIN
		Set @waste_codes = @waste_codes + ' '
	END 

	SET @Loop = CASE WHEN LEN(@waste_codes) > 0 THEN 1 ELSE 0 END

	WHILE (SELECT @Loop) = 1
	BEGIN
		SELECT @Position = CHARINDEX(' ', @waste_codes, 1)
		
		IF(@Position > 0)
		BEGIN
			SELECT @Item = SUBSTRING(@waste_codes, 1, @Position - 1)
			SELECT @waste_codes = SUBSTRING(@waste_codes, @Position + 1, LEN(@waste_codes) - @Position + 1)
			--insert item
			
			INSERT INTO FormXWasteCode (form_id, revision_id, line_item, page_number, waste_code, specifier, waste_code_uid) 
				SELECT	
					@form_id, 
					@revision_id, 
					NULL, 
					NULL, 
					waste_code, 
					@waste_code_type,
					waste_code_uid
				FROM WasteCode WHERE waste_code_uid = @Item
		END
		
		ELSE
		BEGIN
			SELECT @Item = @waste_codes
			SELECT @Loop = 0
		END
	END

NEW:
*/

		INSERT INTO FormXWasteCode (form_id, revision_id, line_item, page_number, waste_code, specifier, waste_code_uid) 
		SELECT	
			@form_id, 
			@revision_id, 
			NULL, 
			NULL, 
			wc.waste_code, 
			@waste_code_type,
			wc.waste_code_uid
		FROM WasteCode wc
		INNER JOIN dbo.fn_SplitXSVText(' ', 1, @waste_codes) f on wc.waste_code_uid = f.row
		WHERE isnull(f.row, '') <> ''



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

