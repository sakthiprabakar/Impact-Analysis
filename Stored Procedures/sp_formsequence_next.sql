CREATE PROCEDURE sp_formsequence_next
	@form_id	int,
	@revision_id	int,
	@modified_by	varchar(60),
	@select int = 1
AS
/***************************************************************************************
returns the next revision_id in a form_id's lineage, and increments the sequence
Load:	plt_ai

notes:	this sp will take an optional 2nd parameter, to force no select @result.
	this sp will create a new sequence if the form_id given does not exist in the table yet.

08/29/2005 jpb  created
10/01/2007 WAC	Removed server references in queries.

sp_formsequence_next 410, 1, 'jonathan.broome@eqonline.com', 0 -- zero = silent
****************************************************************************************/
SET NOCOUNT ON
SET XACT_ABORT ON
DECLARE @next_revision_id int,
	@error varchar(255),
	@last_user varchar(60),
	@old_revision int,
	@old_user varchar(60),
	@signed int,
	@check_rev_id int

start:
set @error = ''

/*
--CRG June, 6 2012
--Check to make sure there is an entry and that it matches the current form table entries
--Should prevent mistakes when EQAI entered the form

SELECT @check_rev_id = MAX(revision_id) FROM formheader WHERE form_id = @form_id

IF((@check_rev_id + 1) <> (SELECT next_revision_id FROM formsequence where form_id = @form_id) AND @check_rev_id IS NOT NULL)
BEGIN
	UPDATE formsequence SET next_revision_id = (@check_rev_id + 1), last_user = 'abcdefghijklmnopqrstuvwxyz' WHERE form_id = @form_id
END
*/

-- JPB If there's no FormSequence record, populate from max form revision existing:
If not exists (select 1 from formsequence where form_id= @form_id)
	insert formsequence select top 1 
	form_id,
	revision_id + 1 as next_revision_id,
	modified_by as last_user,
	newid() as rowguid
	from formheader
	where form_id = @form_id
	order by revision_id desc
else begin
-- JPB If there's a FormSequence record already but somehow it's got a lower revision_id
--     Than exists in formheader, update formsequence to the highest revision info (+1), and same user as formheader
	select top 1
	@check_rev_id = fh.revision_id + 1, 
	@last_user = fh.modified_by
	from formheader fh
	where form_id = @form_id
	order by revision_id desc

	if (select next_revision_id from formsequence where form_id = @form_id) < @check_rev_id
	-- e.g. if formsequence.next_revision_id < formheader.revision_id + 1
	update formsequence set 
	next_revision_id = @check_rev_id, 
	last_user = @last_user
	where form_id = @form_id
end

begin transaction formsequence_next

	select @next_revision_id = next_revision_id, @last_user = last_user from formsequence where form_id = @form_id
	if @next_revision_id is null and @form_id is not null
		begin
			-- Leave the alphabet in this insert, because the next pass compares it to the real modified_by, and updates the revision properly on new records
			insert formsequence (form_id, next_revision_id, last_user) values (@form_id, 1, 'abcdefghijklmnopqrstuvwxyz')
			commit transaction formsequence_next
			goto start
		end
	else
		if @next_revision_id is null
			set @error = 'null form_id submitted, no updates could be made.'
		else
			begin
				select @signed = count(*) 
				from formsignature s 
				inner join formheaderdistinct d on s.form_id = d.form_id 
					and s.revision_id = d.revision_id 
				where s.form_id = @form_id

				if (@last_user <> @modified_by) or (@signed = 1) or (@revision_id is null) or (@revision_id +1 <> @next_revision_id)
					begin
						if @revision_id +1 > @next_revision_id
							set @next_revision_id = @revision_id + 1
						update formsequence set next_revision_id = (@next_revision_id + 1), last_user = @modified_by where form_id = @form_id
						set @revision_id = @next_revision_id
					end
			end
if @error = ''
	commit transaction formsequence_next
else
	rollback transaction formsequence_next

if @error = ''
	select @revision_id as next where @select <> 0
else
begin
	set @revision_id = null
	select @error as next where @select <> 0
end
SET NOCOUNT OFF
SET XACT_ABORT OFF
IF @revision_id IS NULL SET @revision_id = -1
RETURN @revision_id

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_formsequence_next] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_formsequence_next] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_formsequence_next] TO [EQAI]
    AS [dbo];

