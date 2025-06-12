 

create procedure sp_get_notes_TSDFApproval ( @TSDF_Approval_id int, @TSDF_Approval_list varchar(8000), @topics varchar(255))
as


/***************************************************************************************
Returns notes for a given TSDFApproval record
Requires: sp_get_notes (parent procedure that cals this

08/07/2017 AM	created

Test Cmd Line: sp_get_notes 'TSDFApproval',0,0,0,0,0,'','',0,3078,0,0,0,0,0,0,'ANITHA_M','' 
****************************************************************************************/


declare  @more_rows int,
         @TSDFApproval int,
         @start int,
         @end int,
         @lnth int
         
-- table for TSDFApproval notes

create table #TSDFApproval (tsdf_approval_id int null)


-- load the TSDFApproval table
         
-- table for TSDFApproval notes

-- load the TSDFApproval table
if len(@TSDF_Approval_list) > 0
begin
     select @more_rows = 1,
            @start = 1
     while @more_rows = 1
     begin
          select @end = charindex(',',@TSDF_Approval_list,@start)
          if @end > 0 
	    begin
                select @lnth = @end - @start
                
          	select @TSDFApproval = convert(int,substring(@TSDF_Approval_list,@start,@lnth))
                select @start = @end + 1
                if @TSDFApproval > 0 
                begin
                    insert into #TSDFApproval values (@TSDFApproval)
                end
             end
          else 
             begin
             	select @lnth = len(@TSDF_Approval_list)
          	select @TSDFApproval = convert(int,substring(@TSDF_Approval_list,@start,@lnth))
                select @more_rows = 0
                if @TSDFApproval > 0 
                  begin
                    insert into #TSDFApproval values (@TSDFApproval)
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
    LEFT OUTER JOIN TSDFApproval ON Note.tsdf_approval_id = TSDFApproval.tsdf_approval_id 
   WHERE ( Note.tsdf_approval_id   = @TSDF_Approval_id  OR note.tsdf_approval_id is null) 
     and Note.note_source = 'TSDFApproval' 

if Charindex('TSDFApproval',@topics) > 0 
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
   JOIN #TSDFApproval ON Note.tsdf_approval_id = #TSDFApproval.tsdf_approval_id
       AND #TSDFApproval.tsdf_approval_id is null 
   LEFT OUTER JOIN TSDFApproval ON Note.tsdf_approval_id = TSDFApproval.tsdf_approval_id
   WHERE Note.note_source = 'TSDFApproval' 
     and Note.note_type <> 'AUDIT'
     and Note.tsdf_approval_id is null 
end
     

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_get_notes_TSDFApproval] TO [EQAI]
    AS [dbo];

