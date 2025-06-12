
create procedure sp_get_notes ( @ra_source varchar(15),
                                @ra_company_id int,
                                @ra_profit_ctr_id int,
				@generator_id         int,
				@receipt_id           int,
				@batch_location       varchar(15),
				@batch_tracking_num   varchar(15),
				@customer_id          int ,
				@contact_id           int,
				@workorder_id         int ,
				@project_id           int ,
				@record_id            int ,
			    @profile_id           int,
                @merchandise_id       int,
        		@sort_id int,
				@user varchar(15),
				@list text,
                @topics varchar(255),
                @tsdf_approval_id		int	)
as
/***************************************************************************************
 this procedure is used to retireve the notes in the new uniform notes datawindow
 requires:
 
 06/06/06  rg created
 10/30/06  rg corrected issue with profile passing a null string
 11/12/08  rb added merchandise_id argument
 08/15/2017 AM - Added tsdf_approval_id     

 test cmd line: execute sp_get_notes  'Profile',0,0,55014,0,'','',78 ,0,0,0 ,0,90029,0,'RIK_G','','Customer,Generator' 
 EXEC sp_get_notes 'Merchandise',0,0,0,0,null,null,0,0,0,0 ,0,0,100000,null,'ANITHA_M',null,null,0
 EXEC sp_get_notes 'Generator',0,0,47168,0,null,null,0,0,0,0 ,0,0,0,null,'ANITHA_M',null,null,0
 
****************************************************************************************/
create table #notes (
note_id              int                            not null,
note_source          varchar(30)                    null,
company_id           int                            null,
profit_ctr_id        int                            null,
note_date            datetime                       null,
subject              varchar(50)                    null,
status               char(1)                        null,
note_type            varchar(15)                    null,
note                 text                           null,
customer_id          int                            null,
contact_id           int                            null,
generator_id         int                            null,
approval_code        varchar(15)                    null,
profile_id           int                            null,
receipt_id           int                            null,
workorder_id         int                            null,
merchandise_id       int                            null,
batch_location       varchar(15)                    null,
batch_tracking_num   varchar(15)                    null,
project_id           int                            null,
project_record_id    int                            null,
project_sort_id      int                            null,
contact_type         varchar(15)                    null,
added_by             varchar(60)                    null,
date_added           datetime                       null,
modified_by          varchar(60)                    null,
date_modified        datetime                       null,
app_source           varchar(20)                    null,
generator_epaid       varchar(15) null,
editable             smallint null,
sort                 smallint null,
contact_name         varchar(50) null,
tsdf_approval_id      int                           null
)

-- all queries are mutually exclusive so be sure to code them that way
-- if you add another source then you will need to add another block

if @ra_source = 'Generator' 
begin
-- call the getnotes proc for generator
   execute sp_get_notes_generator @generator_id = @generator_id, @topics = @topics
   goto finish
end

if @ra_source = 'Batch' 
begin
-- call the getnotes proc for batch
   execute sp_get_notes_batch @location = @batch_location,
				@tracking_num = @batch_tracking_num,
                               @profit = @ra_profit_ctr_id,
                               @company = @ra_company_id
   goto finish
end

if @ra_source = 'Receipt' 
begin
-- call the getnotes proc for receipt
   execute sp_get_notes_receipt @receipt = @receipt_id, 
                    @profit_ctr = @ra_profit_ctr_id, 
                    @company = @ra_company_id, 
                    @customer = @customer_id, 
                    @generator = @generator_id , 
                    @profile_list = @list,
					@topics = @topics

   goto finish
end


if @ra_source = 'Workorder' 
begin
-- call the getnotes proc for receipt
   execute sp_get_notes_workorder @workorder = @workorder_id, 
                    @profit_ctr = @ra_profit_ctr_id, 
                    @company = @ra_company_id, 
                    @customer = @customer_id, 
                    @generator = @generator_id,
                    @profile_list = @list,
					@topics = @topics

   goto finish
end

if @ra_source = 'Contact' 
begin
-- call the getnotes proc for receipt
   execute sp_get_notes_contact @contact_id = @contact_id,
                                @customer_list = @list,
								@topics = @topics

   goto finish
end


if @ra_source = 'Customer' 
begin
-- call the getnotes proc for receipt
   execute sp_get_notes_customer @customer_id = @customer_id,
                                 @contact_list = @list,
								 @topics = @topics

   goto finish
end


if @ra_source = 'Profile' 
begin
-- call the getnotes proc for receipt
   execute sp_get_notes_profile @profile_id = @profile_id,
                                @customer_id = @customer_id,
                                @generator_id = @generator_id,
                                @contact_id = @contact_id,
                                @topics = @topics

   goto finish
end

-- rb 11/12/2008
if @ra_source = 'Merchandise' 
begin
-- call the getnotes proc for receipt
   execute sp_get_notes_merchandise @merchandise_id = @merchandise_id,
                                 @merchandise_list = @list,
								 @topics = @topics

   goto finish
end

-- AM 08/7/2017
if @ra_source = 'TSDFApproval' 
begin
-- call the getnotes proc for TSDFApproval
   execute sp_get_notes_TSDFApproval @tsdf_approval_id = @tsdf_approval_id,
                                 @TSDF_Approval_list = @list,
								 @topics = @topics

   goto finish
end

finish:
-- dump out the notes table for the datawindow

-- set the editable flag for origianl authros only
-- and within the original context 

update #notes
set editable = 1
where added_by = @user 
and   note_source = @ra_source

update #notes
set editable = 0
where note_type = 'AUDIT'

if @user = 'SA'
begin
   update #notes
   set editable = 1
   where note_type <> 'AUDIT'
end

select note_id ,
	note_source,
	company_id,
	profit_ctr_id ,
	note_date,
	subject ,
	status,
	note_type ,
	note,
	customer_id,
	contact_id,
	generator_id,
	approval_code,
	profile_id,
	receipt_id,
	workorder_id,
	merchandise_id,
	batch_location,
	batch_tracking_num,
	project_id ,
	project_record_id ,
	project_sort_id,
	contact_type,
	added_by,
	date_added,
	modified_by,
	date_modified, 
        app_source,
	generator_epaid ,
	editable,
	sort,
        @user as author,
        contact_name,
        tsdf_approval_id
from #notes
order by sort asc, note_date desc, note_id desc

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_get_notes] TO [EQAI]
    AS [dbo];

