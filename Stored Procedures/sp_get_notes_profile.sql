 



create procedure sp_get_notes_profile ( @profile_id int, 
                                        @customer_id int,
        				@generator_id int,
					@contact_id int,
                                        @topics varchar(255) )
as


/***************************************************************************************
Returns notes for a given generator record
Requires: sp_get_notes (parent procedure that calls this)

06/06/06 rg	created
10/30/2006 rg   corrected problem with null profile_id
11/12/2008 rb   added merchandise_id argument
08/15/2017 AM - Added tsdf_approval_id     


Loads on PLT_AI*
Test Cmd Line: sp_get_notes_profile 90029, 'Generator,Customer'
****************************************************************************************/

/*  declare @customer_id int,
        @generator_id int,
	@contact_id int


select @customer_id = customer_id,
       @generator_id = generator_id,
       @contact_id = contact_id
from Profile 
where profile_id = @profile_id


 */

if @profile_id = 0 
begin
	select @profile_id = null
end


if @profile_id is not null
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
	'',
	0 as editable,
	1 as sort,
        '',
    Note.tsdf_approval_id
    FROM Note
   WHERE Note.profile_id = @profile_id  
     and Note.note_source = 'Profile' 
end

if ( Charindex('Customer',@topics) > 0 ) and ( @customer_id is not null )  
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
   WHERE Note.customer_id = @customer_id
     and Note.note_source = 'Customer'
     and Note.note_type <> 'AUDIT'
end

if ( Charindex('Generator',@topics) > 0 ) and ( @generator_id is not null )
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
	Generator.EPA_ID,
	0 as editable,
	3 as sort,
        null ,
    Note.tsdf_approval_id
    FROM Note,Generator
   WHERE Note.generator_id = @generator_id
     and Note.generator_id = Generator.generator_id
     and Note.note_source = 'Generator'
     and Note.note_type <> 'AUDIT'
end

if ( Charindex('Contact',@topics) > 0 ) and ( @contact_id is not null ) 
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
   WHERE Note.contact_id = @contact_id
     and Note.note_source = 'Contact'
     and Note.note_type <> 'AUDIT'
end

if ( Charindex('Workorder',@topics) > 0 ) and ( @profile_id is not null )
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
	5 as sort,
        null ,
    Note.tsdf_approval_id
    FROM Note
   WHERE Note.profile_id = @profile_id
     and Note.note_source = 'Workorder'
     and Note.note_type <> 'AUDIT'
end
      

if ( Charindex('Receipt',@topics) > 0 ) and ( @profile_id is not null )
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
	6 as sort,
        null ,
    Note.tsdf_approval_id
    FROM Note
   WHERE Note.profile_id = @profile_id
     and Note.note_source = 'Receipt'
     and Note.note_type <> 'AUDIT'
end      



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_get_notes_profile] TO [EQAI]
    AS [dbo];

