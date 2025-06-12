
CREATE PROCEDURE sp_forms_ldr_constituent_overwrite
	@form_id				int
	, @revision_id			int
	, @page_number			int
	, @manifest_line_item	int
	, @const_id_list		varchar(max)
AS

/*********************************************************************************
sp_forms_ldr_constituent_overwrite

10/22/2013 JPB	sp_forms_ldr_constituent_overwrite created from sp_forms_ldr as web gains ability to put multiple
				approvals on 1 ldr form.
03/05/2015 AM Added min_concentration.
*********************************************************************************/

create table #constituent (
	const_id	int
)		

insert #constituent (const_id)
select convert(int, row) from dbo.fn_splitxsvtext(',', 1, @const_id_list)
where isnull(row, '') <> ''

delete from FormXConstituent where form_id = @form_id and revision_id = @revision_id and page_number = @page_number and line_item = @manifest_line_item

INSERT INTO [dbo].[FormXConstituent] (
	[form_id]
	, [revision_id]
	, [page_number]
	, [line_item]
	, [const_id]
	, [const_desc]
	, [min_concentration]
	, [concentration]
	, [unit]
	, [uhc]
	, [specifier]
)
select distinct
	@form_id
	, @revision_id
	, @page_number							--<page_number, int,>
	, @manifest_line_item							--<line_item, int,>
	, ProfileConstituent.const_id
	, Constituents.const_desc
	, ProfileConstituent.min_concentration
	, ProfileConstituent.concentration
	, ProfileConstituent.unit
	, ProfileConstituent.uhc  
	, 'LDR' 
FROM ProfileConstituent  
inner join FormLDRDetail d on ProfileConstituent.profile_id = d.profile_id
inner join Constituents on ProfileConstituent.const_id = Constituents.const_id 
inner join #constituent t on ProfileConstituent.const_id = t.const_id 
WHERE 
	d.form_id = @form_id
	AND d.revision_id = @revision_id
	AND d.page_number = @page_number
	AND d.manifest_line_item = @manifest_line_item
	AND ProfileConstituent.uhc = 'T'  
			
		

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_forms_ldr_constituent_overwrite] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_forms_ldr_constituent_overwrite] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_forms_ldr_constituent_overwrite] TO [EQAI]
    AS [dbo];

