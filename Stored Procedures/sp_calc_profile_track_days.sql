
create procedure sp_calc_profile_track_days ( @profile_id int, @update_flag int = 0, @user_code varchar(10) = null)
as

-- execute sp_calc_profile_track_days 24068
-- execute sp_calc_profile_track_days 24068,1,'sa'

declare @profile_tracking_days int,
        @profile_tracking_bus_days int,
        @old_profile_track_days int,
        @old_profile_bus_days int,
        @date_modified datetime


-- get the old values 
select @old_profile_track_days = profile_tracking_days,
       @old_profile_bus_days   = profile_tracking_bus_days
from profile
where profile_id = @profile_id

select @date_modified = null




-- must call this aafter the tracking record has been inserted and committed        
-- get the first copm and recalculate 

select @profile_tracking_days = datediff(dd, 
	(
		select min(pt.time_in) 
		from ProfileTracking pt
		inner join profilelookup pl on pt.tracking_status = pl.code and pl.type='TrackingStatus'
		where profile_id = @profile_id 
		and pt.time_in is not null
		and pt.tracking_id <= (
			isnull(
				(
					select min(tracking_id) 
					from profiletracking 
					where profile_id = pt.profile_id 
					and tracking_status = 'COMP'
				), 
				pt.tracking_id
			)
		)
	)
,
	(
		(
			select max(pt.time_out) 
			from ProfileTracking pt
			inner join profilelookup pl on pt.tracking_status = pl.code and pl.type='TrackingStatus'
			where profile_id = @profile_id 
			and pt.time_out is not null
			and pt.tracking_id <= (
				isnull(
					(
						select min(tracking_id) 
						from profiletracking 
						where profile_id = pt.profile_id 
						and tracking_status = 'COMP'
					), 
					pt.tracking_id
				)
			)
		)
	)
)



select @profile_tracking_bus_days = dbo.fn_business_days( 
	(
		select min(pt.time_in) 
		from ProfileTracking pt
		inner join profilelookup pl on pt.tracking_status = pl.code and pl.type='TrackingStatus'
		where profile_id = @profile_id 
		and pt.time_in is not null
		and pt.tracking_id <= (
			isnull(
				(
					select min(tracking_id) 
					from profiletracking 
					where profile_id = pt.profile_id 
					and tracking_status = 'COMP'
				), 
				pt.tracking_id
			)
		)
	)
,
	(
		(
			select max(pt.time_out) 
			from ProfileTracking pt
			inner join profilelookup pl on pt.tracking_status = pl.code and pl.type='TrackingStatus'
			where profile_id = @profile_id 
			and pt.time_out is not null
			and pt.tracking_id <= (
				isnull(
					(
						select min(tracking_id) 
						from profiletracking 
						where profile_id = pt.profile_id 
						and tracking_status = 'COMP'
					), 
					pt.tracking_id
				)
			)
		)
	)
)

if @profile_tracking_bus_days < 0 
begin
	select @profile_tracking_bus_days = null
end



if @profile_tracking_days < 0 
begin
	select @profile_tracking_days = null
end


-- if the user wants to update thne update the profile with the valid values

if @update_flag = 1
begin
        select @date_modified = getdate()

	update profile
	set profile_tracking_days = @profile_tracking_days,
	    profile_tracking_bus_days = @profile_tracking_bus_days,
            date_modified = @date_modified,
            modified_by = @user_code
	where profile_id = @profile_id
		 
	If @@rowcount <= 0 
          begin
	   raiserror ('Update of profile_tracking_days_failed',16,1)
           rollback transaction
           return
          end 

	insert ProfileAudit values ( @profile_id,
                                     'Profile',
                                     'profile_tracking_days',
                                     isnull(convert(varchar(255),@old_profile_track_days),''),
                                     isnull(convert(varchar(255),@profile_tracking_days),''),
                                     'Profile_id = ' + convert(varchar(50), @profile_id),
                                     @user_code,
                                     @date_modified,
                                     newid() )

	If @@rowcount <= 0 
          begin
	   raiserror ('Insert into ProfileAudit of profile_tracking_days_failed',16,1)
           rollback transaction
           return
          end 

	insert ProfileAudit values ( @profile_id,
                                     'Profile',
                                     'profile_tracking_bus_days',
                                     isnull(convert(varchar(255),@old_profile_bus_days),''),
                                     isnull(convert(varchar(255),@profile_tracking_bus_days),''),
                                     'Profile_id = ' + convert(varchar(50), @profile_id),
                                     @user_code,
                                     @date_modified,
                                     newid() )

	If @@rowcount <= 0 
          begin
	   raiserror ('Insert into ProfileAudit of profile_tracking_bus_days_failed',16,1)
           rollback transaction
           return
          end 

        
         
                                     
            
end


select  @profile_tracking_days as profile_tracking_days,
        @profile_tracking_bus_days as profile_tracking_bus_days,
        @old_profile_track_days as old_profile_tracking_days,
        @old_profile_bus_days as old_profile_tracking_bus_days,
        @date_modified as date_modified


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_calc_profile_track_days] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_calc_profile_track_days] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_calc_profile_track_days] TO [EQAI]
    AS [dbo];

