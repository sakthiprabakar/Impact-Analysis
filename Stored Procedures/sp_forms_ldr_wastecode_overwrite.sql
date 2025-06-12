
CREATE PROCEDURE sp_forms_ldr_wastecode_overwrite
	@form_id				int
	, @revision_id			int
	, @page_number			int
	, @manifest_line_item	int
	, @waste_code_uid_list	varchar(max)
AS

/*********************************************************************************
sp_forms_ldr_wastecode_overwrite

10/22/2013 JPB	sp_forms_ldr_wastecode_overwrite created from sp_forms_ldr as web gains ability to put multiple
				approvals on 1 ldr form.
*********************************************************************************/

create table #wastecode (
	waste_code_uid	int
)		

insert #wastecode (waste_code_uid)
select convert(int, row) from dbo.fn_splitxsvtext(',', 1, @waste_code_uid_list)
where isnull(row, '') <> ''

delete from FormXWasteCode where form_id = @form_id and revision_id = @revision_id and page_number = @page_number and line_item = @manifest_line_item
insert FormXWasteCode (
	Form_ID
	, Revision_ID
	, Page_Number
	, Line_Item
	, Waste_Code_UID
	, Waste_Code
	, Specifier
)
select distinct
	@form_id as form_id
	, @revision_id as revision_id
	, @page_number as page_number
	, @manifest_line_item as line_item
	, wc.waste_code_uid
	, wc.waste_code as waste_code -- Not display_name, since FormXWasteCode is char(4).
	, 'LDR' as specifier
from #wastecode t
inner join wastecode wc on t.waste_code_uid = wc.waste_code_uid
where wc.status = 'A'
			

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_forms_ldr_wastecode_overwrite] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_forms_ldr_wastecode_overwrite] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_forms_ldr_wastecode_overwrite] TO [EQAI]
    AS [dbo];

