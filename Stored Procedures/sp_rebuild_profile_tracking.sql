create procedure sp_rebuild_profile_tracking ( @target_lo int, @target_hi int , @debug int = 0 ) as
--  you can do any band you want.  The whole table or a series at a time
-- just remember the more rows you affect the greater the odds of table locking.
declare @profile_id int  ,
	@tracking_id int ,
	@profile_curr_status_code char(1)  ,
	@tracking_status char(1) ,
	@department_id int ,
	@EQ_contact varchar(12),
	@time_in datetime,
	@time_out datetime,
	@comment varchar(255),
	@added_by  varchar(12),
	@date_added datetime,
	@modified_by varchar(12),
	@date_modified datetime,
	@manual_bypass_tracking_flag char(1),
	@manual_bypass_tracking_reason varchar(50),
	@manual_bypass_tracking_by varchar(12),
	@business_minutes int ,
	@rowguid uniqueidentifier,
    @hold_profile int,
    @seq_no int,
    @pt_count int,
    @sq_count int,
    @rec_no int,
	@mismatch_count	int,
	@dup_count	int

create table #profiletracking (
    profile_id int NOT NULL,
	tracking_id int NOT NULL,
	profile_curr_status_code char(1)  NULL,
	tracking_status varchar(40)  NULL,
	department_id int NULL,
	EQ_contact varchar(30)  NULL,
	time_in datetime NULL,
	time_out datetime NULL,
	comment varchar(255)  NULL,
	added_by varchar(10)  NULL,
	date_added datetime NULL,
	modified_by varchar(10)  NULL,
	date_modified datetime NULL,
	manual_bypass_tracking_flag char(1) NULL,
	manual_bypass_tracking_reason varchar(50)  NULL,
	manual_bypass_tracking_by varchar(10)  NULL,
	business_minutes int NULL,
	rowguid uniqueidentifier not null)

create table #seq_tracking (profile_id int NOT NULL,
	tracking_id int NOT NULL,
	profile_curr_status_code char(1)  NULL,
	tracking_status varchar(40)  NULL,
	department_id int NULL,
	EQ_contact varchar(30)  NULL,
	time_in datetime NULL,
	time_out datetime NULL,
	comment varchar(255)  NULL,
	added_by varchar(10)  NULL,
	date_added datetime NULL,
	modified_by varchar(10)  NULL,
	date_modified datetime NULL,
	manual_bypass_tracking_flag char(1) NULL,
	manual_bypass_tracking_reason varchar(50)  NULL,
	manual_bypass_tracking_by varchar(10)  NULL,
	business_minutes int NULL,
	rowguid uniqueidentifier not null)
	
create table #tracking_dupes ( profile_id int null, tracking_id int null, track_cnt int null )

create table #max_tracking_before ( profile_id int null, tracking_id int null )
create table #max_tracking_after ( profile_id int null, tracking_id int null )


-- prime the table

-- if you want to do just one profile make the target lo and hi the same
insert #tracking_dupes
select profile_id, tracking_id, count(*) as track_cnt
from profiletracking
where profile_id between @target_lo and @target_hi
group by profile_id, tracking_id 
having count(*) > 1

insert #profiletracking
select * from profiletracking
where profiletracking.profile_id in (select distinct profile_id from #tracking_dupes)




if @@rowcount <= 0 return

if @debug = 1 
begin
	PRINT 'select count(*) as input_count from #profiletracking'
	select count(*) as input_count from #profiletracking
end

-- use cursor to process records and reassign sequence ids
set @seq_no = 1

declare mycursor cursor for 
select profile_id ,
			tracking_id,
			profile_curr_status_code ,
			tracking_status ,
			department_id ,
			EQ_contact,
			time_in,
			time_out,
			comment,
			added_by,
			date_added,
			modified_by,
			date_modified ,
			manual_bypass_tracking_flag ,
			manual_bypass_tracking_reason ,
			manual_bypass_tracking_by,
			business_minutes,
			rowguid
from #profiletracking
order by profile_id, tracking_id, date_added, time_in



open mycursor

fetch mycursor into @profile_id ,
			@tracking_id,
			@profile_curr_status_code ,
			@tracking_status ,
			@department_id ,
			@EQ_contact,
			@time_in,
			@time_out,
			@comment,
			@added_by,
			@date_added,
			@modified_by,
			@date_modified ,
			@manual_bypass_tracking_flag ,
			@manual_bypass_tracking_reason ,
			@manual_bypass_tracking_by,
			@business_minutes,
			@rowguid 

select @hold_profile = @profile_id
select @rec_no = 1

while @@fetch_status = 0
begin
	while @profile_id = @hold_profile and @@fetch_status = 0 
    begin 
       if @debug = 1
        begin
          select @rec_no = @rec_no + 1
          print  'record ' + convert(varchar(20), @rec_no) + '    profile = '  + convert(varchar(20),@profile_id) + ' tracking = ' + convert(varchar(20),@tracking_id) 
		end
       insert #seq_tracking
       values ( @profile_id ,
			@seq_No,
			@profile_curr_status_code ,
			@tracking_status ,
			@department_id ,
			@EQ_contact,
			@time_in,
			@time_out,
			@comment,
			@added_by,
			@date_added,
			@modified_by,
			@date_modified ,
			@manual_bypass_tracking_flag ,
			@manual_bypass_tracking_reason ,
			@manual_bypass_tracking_by,
			@business_minutes,
			@rowguid)
	  
      fetch mycursor into @profile_id ,
			@tracking_id,
			@profile_curr_status_code ,
			@tracking_status ,
			@department_id ,
			@EQ_contact,
			@time_in,
			@time_out,
			@comment,
			@added_by,
			@date_added,
			@modified_by,
			@date_modified ,
			@manual_bypass_tracking_flag ,
			@manual_bypass_tracking_reason ,
			@manual_bypass_tracking_by,
			@business_minutes,
			@rowguid 

      if @profile_id = @hold_profile
      begin
			select @seq_no = @seq_no + 1
      end

    end
 
-- no more for this profile so reset the seq #
   select @seq_no = 1, @hold_profile = @profile_id

end

close mycursor

deallocate mycursor

-- now the table should be the same number 
select @pt_count = count(*) from #profiletracking
select @sq_count = count(*) from #seq_tracking

if @pt_count <> @sq_count
begin
	print 'bad rebuild'
    print 'input has ' + convert(varchar(20), @pt_count) + ' records !!!'
    print 'output has ' + convert(varchar(20), @sq_count) + ' records !!!'
    return
end

----------------------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------------------
INSERT #max_tracking_before
SELECT profile_id, MAX(tracking_id) FROM ProfileTracking 
WHERE profile_id BETWEEN @target_lo AND @target_hi
GROUP BY profile_id

PRINT '---------------------------------------------------------------------'
PRINT 'INSERT INTO Resync_Profile_List - for mismatched tracking_id'
PRINT '---------------------------------------------------------------------'
INSERT INTO Resync_Profile_List
SELECT p.profile_id, p.profile_tracking_id, m.tracking_id, GETDATE()
FROM Profile p
INNER JOIN #max_tracking_before m ON p.profile_id = m.profile_id
	AND p.profile_tracking_id <> m.tracking_id
WHERE 1=1
AND p.profile_id BETWEEN @target_lo AND @target_hi

SELECT @mismatch_count = @@ROWCOUNT
IF @mismatch_count > 0
BEGIN
	PRINT 'Records inserted into Resync_Profile_List for mismatched tracking_id:  ' + CONVERT(varchar(10), @mismatch_count)
	PRINT ''
END


PRINT '---------------------------------------------------------------------'
PRINT 'INSERT INTO Resync_Profile_List - for duplicate tracking_id'
PRINT '---------------------------------------------------------------------'
INSERT INTO Resync_Profile_List
SELECT DISTINCT p.profile_id, p.profile_tracking_id, MAX(pt.tracking_id), GETDATE()
FROM Profile p
INNER JOIN ProfileTracking pt ON p.profile_id = pt.profile_id
WHERE 1=1
AND p.profile_id BETWEEN @target_lo AND @target_hi
AND p.profile_id IN (
	select profile_id from profiletracking
	group by profile_id, tracking_id
	having count(*) > 1)

GROUP BY p.profile_id, p.profile_tracking_id
ORDER BY p.profile_id

SELECT @dup_count = @@ROWCOUNT
IF @dup_count > 0
BEGIN
	PRINT 'Records inserted into Resync_Profile_List for duplicate tracking_id:  ' + CONVERT(varchar(10), @dup_count)
	PRINT ''
END
----------------------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------------------



PRINT '---------------------------------------------------------------------'
PRINT 'UPDATE ProfileTracking table'
PRINT '---------------------------------------------------------------------'
update profiletracking 
set tracking_id = sq.tracking_id
from profiletracking pt , #seq_tracking sq
where pt.profile_id = sq.profile_id
and   pt.rowguid = sq.rowguid


-- now reset the profile with the max tracking id for all profiles in the group not just the ones that have dupes
insert #max_tracking_after
select profile_id, max(tracking_id) from profiletracking 
where profile_id between @target_lo and @target_hi
group by profile_id



PRINT '---------------------------------------------------------------------'
PRINT 'UPDATE Profile table'
PRINT '---------------------------------------------------------------------'
update profile
set profile_tracking_id = m.tracking_id
from profile p, #max_tracking_after m
where p.profile_id = m.profile_id


PRINT '---------------------------------------'
PRINT 'Successfully completed'
PRINT '---------------------------------------'

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rebuild_profile_tracking] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rebuild_profile_tracking] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rebuild_profile_tracking] TO [EQAI]
    AS [dbo];

