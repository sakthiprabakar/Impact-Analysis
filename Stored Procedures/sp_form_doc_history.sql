
CREATE PROCEDURE sp_form_doc_history
	@profile_id INT
AS
/*********************************************************************************
--5/22/2011 CRG Created

--sp_form_doc_history
--Gets the document history for a given profile_id to display on web
--sp_form_doc_history @profile_id = 41723
*********************************************************************************/ 

SELECT 'Edited' AS [action]
	,type AS [Type]
	,form_id
	,revision_id
	,date_modified AS [Date]
	,modified_by AS [user]
FROM FormHeader
WHERE (
		profile_id = @profile_id
		OR approval_key = @profile_id
		)
	AND date_modified <> date_created
	AND STATUS = 'A'

UNION

SELECT 'New Revision' AS [action]
	,type AS [Type]
	,form_id
	,revision_id
	,date_created AS [Date]
	,created_by AS [user]
FROM FormHeader
WHERE (
		profile_id = @profile_id
		OR approval_key = @profile_id
	)
	AND form_id > 0
	AND revision_id <> 1
	AND STATUS = 'A'

UNION

SELECT 'Created' AS [action]
	,type AS [Type]
	,form_id
	,revision_id
	,date_created AS [Date]
	,created_by AS [user]
FROM FormHeader
WHERE (
		profile_id = @profile_id
		OR approval_key = @profile_id
		)
	AND form_id > 0
	AND revision_id = 1
	AND STATUS = 'A'

UNION

SELECT 'Signed' AS [action]
	,type AS [Type]
	,form_id
	,revision_id
	,signing_date AS [Date]
	,signing_name AS [User]
FROM FormHeader
WHERE (
		profile_id = @profile_id
		OR approval_key = @profile_id
		)
	AND form_id > 0
	AND signing_date IS NOT NULL
	AND locked = 'L'
	AND STATUS = 'A'

UNION

SELECT 'Viewed' AS [action]
	,report AS [Type]
	,form_id
	,revision_id
	,date_added AS [DATE]
	,added_by AS [USER]
FROM Plt_Image..DocProcessing
WHERE PROFILE_ID = @profile_id
	AND form_id > 0
	AND STATUS = 'A'
	AND operation = 'V'
ORDER BY DATE

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_form_doc_history] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_form_doc_history] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_form_doc_history] TO [EQAI]
    AS [dbo];

