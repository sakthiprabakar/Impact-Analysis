 


create procedure sp_get_notes_receipt ( @receipt int, @profit_ctr int, @company int, @customer int, @generator int , @profile_list varchar(8000), @topics varchar(255))
as


/***************************************************************************************
Returns notes for a given receipt record
Requires: sp_get_notes (parent procedure that cals this

06/06/06 rg	created
11/12/08 rb     added merchandise_id argument
08/15/2017 AM - Added tsdf_approval_id     

Loads on PLT_AI*
Test Cmd Line: sp_get_notes 'Receipt',14,12,0,10,12,'','',0,0,0,0,0,'',0,0,'ADAM_G',''
****************************************************************************************/
create table #profiles (profile_id int null)


declare  @more_rows int,
         @profile int,
         @start int,
         @end int,
         @lnth int
         
        
-- load the cotnact table

         
-- table for contact notes

-- load the cotnact table
if len(@profile_list) > 0
begin
     select @more_rows = 1,
            @start = 1
     while @more_rows = 1
     begin
          select @end = charindex(',',@profile_list,@start)
          if @end > 0 
	    begin
                select @lnth = @end - @start
                
          	select @profile = convert(int,substring(@profile_list,@start,@lnth))
                select @start = @end + 1
                if @customer > 0 
                begin
                    insert into #profiles values (@profile)
                end
             end
          else 
             begin
             	select @lnth = len(@profile_list)
          	select @profile = convert(int,substring(@profile_list,@start,@lnth))
                select @more_rows = 0
                if @profile > 0 
                  begin
                    insert into #profiles values (@profile)
                  end                
             end
          
      end
end 


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
   WHERE Note.receipt_id = @receipt
     and Note.profit_ctr_id = @profit_ctr 
     and Note.company_id = @company
      and Note.note_source = 'Receipt' 

if Charindex('Generator',@topics) > 0 
begin
insert #notes
-- generator
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
	2 as sort,
        null,
    Note.tsdf_approval_id
    FROM Note,  Generator
   WHERE Note.generator_id = Generator.generator_id
     and Note.generator_id = @generator
     and Note.note_source = 'Generator'
      and Note.note_type <> 'AUDIT' 

end

if Charindex('Customer',@topics) > 0 
begin

-- customer
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
        null,
    Note.tsdf_approval_id 
    FROM Note
   WHERE Note.customer_id = @customer
     and Note.note_source = 'Customer' 
     and Note.note_type <> 'AUDIT'
end

if Charindex('Profile',@topics) > 0 
begin

-- approval
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
        null,
    Note.tsdf_approval_id
    FROM Note
   WHERE Note.profile_id in ( select profile_id from #profiles )
      and Note.note_source = 'Profile' 
      and Note.note_type <> 'AUDIT'

end



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_get_notes_receipt] TO [EQAI]
    AS [dbo];

