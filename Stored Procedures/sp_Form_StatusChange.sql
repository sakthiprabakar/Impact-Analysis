/************************************************************
Procedure	: sp_Form_StatusChange
Database	: PLT_AI*
Created		: 7-15-2004 - Jonathan Broome
Description	: Finds all the form entries related to the
			  form/revision passed in, and changes their
			  status to @status

09/15/2005 JDB	Removed group_id (code still here; commented out)
************************************************************/
CREATE PROCEDURE sp_Form_StatusChange (
	@form_id	int,
	@revision_id	int,
	@status		char(1)	)
AS

DECLARE @itype		varchar(20),
	@iform_id	int,
	@irevision_id	int,
	@isql		varchar(1000)

-- select @group_id = group_id from FormHeader where form_id = @form_id and revision_id = @revision_id
-- 
-- if @group_id is not null
-- begin
-- 	declare curForm cursor for select form_id, revision_id, type from FormHeader where group_id = @group_id
-- 	open curForm
-- 	fetch next from curform into @iform_id, @irevision_id, @itype
-- 	while @@fetch_status = 0
-- 	begin
-- 		set @isql = 'update form' + ltrim(rtrim(@itype)) + ' set status=''' + @status + ''' where form_id = ' + convert(varchar(20),@iForm_id) + ' and revision_id = ' + convert(varchar(20),@iRevision_id)
-- 		exec(@isql)
-- 		fetch next from curForm into @iform_id, @irevision_id, @itype
-- 	end
-- 	close curForm
-- 	deallocate curForm
-- end
-- else
BEGIN
	SELECT	@iform_id = form_id,
		@irevision_id = revision_id, 
		@itype = type 
	FROM FormHeader 
	WHERE form_id = @form_id 
	AND revision_id = @revision_id

	SET @isql = 'update form' + ltrim(rtrim(@itype)) + ' set status=''' + @status + ''' where form_id = ' + convert(varchar(20),@iForm_id) + ' and revision_id = ' + convert(varchar(20),@iRevision_id)
	EXEC(@isql)
END


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_Form_StatusChange] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_Form_StatusChange] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_Form_StatusChange] TO [EQAI]
    AS [dbo];

