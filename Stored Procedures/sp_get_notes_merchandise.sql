
create procedure sp_get_notes_merchandise ( @merchandise_id int, @merchandise_list varchar(8000), @topics varchar(255) )
as


/***************************************************************************************
Returns notes for a given merchandise record
Requires: sp_get_notes (parent procedure that calls this)

11/12/08 rb	created
05/10/2017 AM - 1.Remove deprecated SQL and replace with appropriate SQL syntax.(*= to LEFT OUTER JOIN etc.). 
08/15/2017 AM - Added tsdf_approval_id     

Loads on PLT_AI*
****************************************************************************************/

declare  @more_rows int,
         @merchandise int,
         @start int,
         @end int,
         @lnth int
         
-- table for merchandise notes

create table #merchandise (merchandise_id int null)


-- load the merchandise table

         
-- table for merchandise notes

-- load the merchandise table
if len(@merchandise_list) > 0
begin
     select @more_rows = 1,
            @start = 1
     while @more_rows = 1
     begin
          select @end = charindex(',',@merchandise_list,@start)
          if @end > 0 
	    begin
                select @lnth = @end - @start
                
          	select @merchandise = convert(int,substring(@merchandise_list,@start,@lnth))
                select @start = @end + 1
                if @merchandise > 0 
                begin
                    insert into #merchandise values (@merchandise)
                end
             end
          else 
             begin
             	select @lnth = len(@merchandise_list)
          	select @merchandise = convert(int,substring(@merchandise_list,@start,@lnth))
                select @more_rows = 0
                if @merchandise > 0 
                  begin
                    insert into #merchandise values (@merchandise)
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
    LEFT OUTER JOIN Merchandise ON Note.merchandise_id = Merchandise.merchandise_id 
     --  WHERE Note.merchandise_id = @merchandise_id 
     --and Note.merchandise_id *= Merchandise.merchandise_id 
     --and Note.note_source = 'Merchandise' 
    WHERE Note.merchandise_id = @merchandise_id 
      AND Note.note_source = 'Merchandise' 

if Charindex('Merchandise',@topics) > 0 
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
   JOIN #merchandise ON Note.merchandise_id = #merchandise.merchandise_id
   LEFT OUTER JOIN Merchandise ON Note.merchandise_id = Merchandise.merchandise_id
    --, #merchandise, Merchandise
   --WHERE Note.merchandise_id = #merchandise.merchandise_id
   --  and Note.merchandise_id *= Merchandise.merchandise_id
   WHERE Note.note_source = 'Merchandise' 
     AND Note.note_type <> 'AUDIT'
end

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_get_notes_merchandise] TO [EQAI]
    AS [dbo];

