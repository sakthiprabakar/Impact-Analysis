
create procedure sp_get_notes_batch ( @location varchar(15), @tracking_num varchar(15), @profit int, @company int)
as

/***************************************************************************************
Returns notes for a given batch record
Requires: sp_get_notes (parent procedure that cals this

06/06/06 rg	created
11/12/08 rb     added merchandise_id argument
08/15/2017 AM - Added tsdf_approval_id     

Loads on PLT_AI*
Test Cmd Line: sp_get_notes 'Batch',03,01,0,0,0,'location','track#',0,0,0,0,0,0,0,0,'ADAM_G','' 
****************************************************************************************/
insert #notes
SELECT  Note.note_id  ,
	Note.note_source ,
	Note.company_id,
	Note.profit_ctr_id,
	Note.note_date,
	Note.subject,
	Note.status ,
	Note.note_type ,
	Note.note ,
	Note.customer_id,
	Note.contact_id,
	Note.generator_id,
	Note.approval_code,
	Note.profile_id,
	Note.receipt_id,
	Note.workorder_id,
	Note.merchandise_id,
	Note.batch_location,
	Note.batch_tracking_num,
	Note.project_id,
	Note.project_record_id,
	Note.project_sort_id,
	Note.contact_type,
	Note.added_by,
	Note.date_added,
	Note.modified_by,
	Note.date_modified,
        Note.app_source,
	null,
	0 as editable,
	1 as sort,
        null,
    Note.tsdf_approval_id
    FROM Note
   WHERE Note.batch_location = @location
     and Note.batch_tracking_num = @tracking_num 
     and Note.company_id = @company
     and Note.profit_ctr_id = @profit 
     and Note.note_source = 'Batch' 



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_get_notes_batch] TO [EQAI]
    AS [dbo];

