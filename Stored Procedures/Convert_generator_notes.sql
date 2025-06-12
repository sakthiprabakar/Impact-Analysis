/*
-- this procedure is used to convert notes
-- 


create procedure Convert_generator_notes 
as

declare @note_id              int , 
        @company_id           int,
	@generator_id         int,
	@receipt_id           int,
	@profit_ctr_id        int,
	@batch_location       varchar(15),
	@batch_tracking_num   varchar(15),
	@customer_id          int ,
	@contact_id           int,
	@workorder_id         int ,
	@project_id           int ,
	@record_id            int ,
	-- @note                 text,
	@note_date            datetime ,
	@note_type            varchar(15),
	@status               char(1),
	@source_code          char(1),
	@added_by             varchar(60),
	@date_added           datetime ,
	@modified_by          varchar(60),
	@date_modified        datetime ,
	@contact_type         varchar(15),
	@subject 		varchar(50),
        @approval_code varchar(15) ,
        @next_key int,
        @more_rows char(1),
        @profile_id int,
        @sort_id int

-- prime up next key

select @next_key = isnull(max(note_id),0) from Note

-- test to see if new note is populated

if ( select count(*) from GeneratorNote where new_note_id is not null ) = 0
begin
	update GeneratorNote 
        set @next_key = new_note_id = @next_key + 1
end




-- process generator notes
insert NOTE ( note_id,
	note_source,
	company_id,
	profit_ctr_id,
	note_date,
	subject,
	status,
	note_type,
	note,
	customer_id,
	contact_id,
	generator_id,
	approval_code ,
	profile_id,
	receipt_id,
	workorder_id ,
	batch_location,
	batch_tracking_num,
	project_id,
	project_record_id,
	project_sort_id,
	contact_type,
	added_by,
	date_added,
	modified_by ,
	date_modified,
        app_source ) 
select  new_note_id as note_id  ,
	'Generator' as note_source,
	added_from_company as company_id ,
	null as profit_ctr_id ,
	note_date as note_date,
	subject as subject,
	'C' as status ,
	note_type as note_type,
	note as note ,
	null as customer_id ,
	null as contact_id,
	generator_id as generator_id,
	null as approval_code ,
	null as profile_id,
	null as receipt_id ,
	null as workorder_id ,
	null as batch_location ,
	null as batch_tracking_num ,
	null as project_id  ,
	null as project_record_id ,
	null as project_sort_id ,
	'Note' as contact_type,
	added_by as added_by ,
	date_added as date_added ,
	modified_by as modified_by,
	date_modified as date_modified,
        'EQAI' as app_source 
from GeneratorNote    

update Note
set subject = substring( note, 1,50),
    note_type = 'NOTE'
from Note
where note_source = 'Generator'
and subject is null
and note_type <> 'AUDIT'

update Note
set subject = 'AUDIT'
from Note
where note_source = 'Generator'
and subject is null
and note_type = 'AUDIT'



-- update sequence table

-- update sequence table

if charindex('DEV' ,upper(DB_NAME(db_id()))) > 0
begin
	update NTSQL1.plt_AI_DEV.dbo.Sequence
	set next_value = @next_key + 1
	where name = 'Note.note_id'
end
else if charindex('TEST' ,upper(DB_NAME(db_id()))) > 0
begin
	update NTSQL1.plt_AI_TEST.dbo.Sequence
	set next_value = @next_key + 1
	where name = 'Note.note_id'
end
else 
begin
	update NTSQL1.Sequence
	set next_value = @next_key + 1
	where name = 'Note.note_id'
end 									


*/
