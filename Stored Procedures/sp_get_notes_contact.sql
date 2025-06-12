 

create procedure sp_get_notes_contact ( @contact_id int, @customer_list varchar(8000), @topics varchar(255))
as


/***************************************************************************************
Returns notes for a given contact record
Requires: sp_get_notes (parent procedure that cals this

06/06/06 rg	created
11/12/08 rb     added merchandise_id argument
08/15/2017 AM - Added tsdf_approval_id     


Loads on PLT_AI*
Test Cmd Line: sp_get_notes 'Contact',0,0,0,0,0,'','',0,3078,0,0,0,0,0,0,'ADAM_G','' 
****************************************************************************************/


declare  @more_rows int,
         @customer int,
         @start int,
         @end int,
         @lnth int
         
-- table for contact notes

create table #customers (customer_id int null)


-- load the cotnact table

         
-- table for contact notes

-- load the cotnact table
if len(@customer_list) > 0
begin
     select @more_rows = 1,
            @start = 1
     while @more_rows = 1
     begin
          select @end = charindex(',',@customer_list,@start)
          if @end > 0 
	    begin
                select @lnth = @end - @start
                
          	select @customer = convert(int,substring(@customer_list,@start,@lnth))
                select @start = @end + 1
                if @customer > 0 
                begin
                    insert into #customers values (@customer)
                end
             end
          else 
             begin
             	select @lnth = len(@customer_list)
          	select @customer = convert(int,substring(@customer_list,@start,@lnth))
                select @more_rows = 0
                if @customer > 0 
                  begin
                    insert into #customers values (@customer)
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
   WHERE Note.contact_id = @contact_id  
     and Note.note_source = 'Contact' 

if Charindex('Customer',@topics) > 0 
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
        null,
    Note.tsdf_approval_id
    FROM Note, #customers
   WHERE Note.customer_id = #customers.customer_id
     and Note.note_source = 'Customer' 
     and Note.note_type <> 'AUDIT'
     and ( Note.contact_id is null or Note.contact_id = @contact_id )
end
     

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_get_notes_contact] TO [EQAI]
    AS [dbo];

