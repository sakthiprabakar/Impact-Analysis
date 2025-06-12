
Create Proc sp_FormTemplate_list (
	@user_code		varchar(20)	= NULL
)
/* ****************************************************************************
sp_FormTemplate_list

List the templates available on web (Without requiring a web code deploy)
Takes an optional user-code.  If this is an EQ User, also include templates in a 'P'ending status.
Otherwise just list 'A'ctive templates.

History:
5/13/2013 - JPB - Created

Sample:
	sp_FormTemplate_list 'null'
	sp_FormTemplate_list 'Jonathan'


Scratch:
	Update FormWCRTemplate set status = 'P' where template_form_id = 221495
	Update FormWCRTemplate set status = 'A' where template_form_id = 221495
	
**************************************************************************** */
AS

	create table #status (status char(1))
	insert #status values ('A')
	
	if exists (select 1 from users where user_code = @user_code and group_id <> 0)
		insert #status values ('P')
	
	SELECT NULL as template_form_id, 'Select a template...' as name, 1 as Ord 
	UNION ALL 
	SELECT template_form_id, name, 2 as Ord 
	FROM dbo.FormWCRTemplate t
	inner join #status s on t.status = s.status
	ORDER BY Ord, Name

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_FormTemplate_list] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_FormTemplate_list] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_FormTemplate_list] TO [EQAI]
    AS [dbo];

