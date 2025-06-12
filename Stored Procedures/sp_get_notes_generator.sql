 


create procedure sp_get_notes_generator ( @generator_id int, @topics varchar(255))
as


/***************************************************************************************
Returns notes for a given generator record
Requires: sp_get_notes (parent procedure that calls this)

06/06/06 rg	created
11/12/08 rb     added merchandise_id argument
05/10/2017 AM - 1.Remove deprecated SQL and replace with appropriate SQL syntax.(*= to LEFT OUTER JOIN etc.). 
08/15/2017 AM - Added tsdf_approval_id     

Loads on PLT_AI*
Test Cmd Line: sp_get_notes 'Generator',0,0,32,0,0,'','',0,0,0,0,0,'',0,0,'ADAM_G',''
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
	Generator.EPA_ID,
	0 as editable,
	1 as sort,
        Contact.name,
    Note.tsdf_approval_id
    FROM Note
    LEFT OUTER JOIN Contact ON Note.contact_id = Contact.contact_id
    INNER JOIN Generator ON Note.generator_id = Generator.generator_id
    WHERE Note.generator_id = @generator_id  
      AND Note.note_source = 'Generator' 

if Charindex('Profile',@topics) > 0 
begin
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
	2 as sort,
        null ,
    Note.tsdf_approval_id
    FROM Note
   WHERE Note.generator_id = @generator_id
     and Note.note_source = 'Profile' 
     and Note.note_type <> 'AUDIT'
end     

if Charindex('Workorder',@topics) > 0 
begin
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
	3 as sort,
        null ,
    Note.tsdf_approval_id
    FROM Note
   WHERE Note.generator_id = @generator_id
     and Note.generator_id > 0 
     and Note.note_source = 'Workorder'
     and Note.note_type <> 'AUDIT'
end      

if Charindex('Receipt',@topics) > 0 
begin
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
	4 as sort,
        null ,
    Note.tsdf_approval_id
    FROM Note
   WHERE Note.generator_id = @generator_id
     and Note.generator_id > 0 
     and Note.note_source = 'Receipt'
     and Note.note_type <> 'AUDIT'
end      


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_get_notes_generator] TO [EQAI]
    AS [dbo];

