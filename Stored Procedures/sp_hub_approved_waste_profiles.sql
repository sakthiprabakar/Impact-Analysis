drop proc if exists sp_hub_approved_waste_profiles
go

create procedure sp_hub_approved_waste_profiles (
	@completion_start_date	datetime
	, @completion_end_date	datetime
	, @copc_list			varchar(2000) = 'all'
	, @user_code			varchar(100)
	, @permission_id		int
)
as

/* *******************************************************************************
sp_hub_approved_waste_profiles


4/4/2024 - JPB - Created from script code

******************************************************************************* */

-- Debug run
/*
		declare
			@completion_start_date	datetime
			, @completion_end_date	datetime
			, @copc_list			varchar(2000) = 'all'
			, @user_code			varchar(100) = 'jonathan'
			, @permission_id		int = 189

		select @completion_start_date = '12/1/2024 00:00'
			, @completion_end_date = getdate()
			, @copc_list = '25|0, 26|0, 25|4'
			, @user_code			= 'jonathan'
			, @permission_id		= 189
*/
-- end Debug setup


-- internal vars/tables:
	declare @start_date datetime, @end_date datetime
	declare @tbl_profit_center_filter table (company_id int, profit_ctr_id int)

-- handle inputs/defaults:
	select @start_date = isnull(@completion_start_date, dateadd(m, -1, getdate()))	--'12/1/2023 00:00'
	, @end_date = isnull(@completion_end_date, getdate())

	if isnull(@copc_list, '') <> 'ALL' begin  
	INSERT @tbl_profit_center_filter  
	 SELECT distinct secured_copc.company_id, secured_copc.profit_ctr_id  
	  FROM SecuredProfitCenter secured_copc  
	  INNER JOIN (  
	   SELECT  
		RTRIM(LTRIM(SUBSTRING(value, 1, CHARINDEX('|',value) - 1))) company_id,  
		RTRIM(LTRIM(SUBSTRING(value, CHARINDEX('|',value) + 1, LEN(value) - (CHARINDEX('|',value)-1)))) profit_ctr_id  
	   from string_split(@copc_list, ',') 
	   where isnull(value, '') <> '') selected_copc   
	   ON secured_copc.company_id = selected_copc.company_id   
	   AND secured_copc.profit_ctr_id = selected_copc.profit_ctr_id  
	   AND secured_copc.user_code = @user_code  
	   AND secured_copc.permission_id = @permission_id      
	end else begin  
	 INSERT @tbl_profit_center_filter  
	 SELECT DISTINCT company_id, profit_ctr_id  
	  FROM SecuredProfitCenter secured_copc  
	  WHERE   
	   secured_copc.user_code = @user_code  
	   AND secured_copc.permission_id = @permission_id      
	end  


-- ProfileTracking fix
	-- Need to perform this before running -
	-- fix incorrectly numbered profiletracking data:

	declare @max_profile_id bigint, @max_profile_id_minus_400k bigint, @sql varchar(500)
	select @max_profile_id = max(profile_id) from profiletracking
	select @max_profile_id_minus_400k = @max_profile_id - 400000

	-- Call sp_rebuild_profile_tracking for a few 100k rows before, through current...
	-- sp_rebuild_profile_tracking	[start of profile_id range], [end of profile_id range], [debug 1/0]

	if exists (
		select profile_id, tracking_id from profiletracking
		where profile_id between @max_profile_id_minus_400k and @max_profile_id
		GROUP BY profile_id, tracking_id 
		having count(*) > 1
	)
	begin
		set @sql = 'sp_rebuild_profile_tracking ' 
			+ convert(varchar(20), @max_profile_id_minus_400k) + ', ' 
			+ convert(varchar(20), @max_profile_id) + ', 0' 

		exec(@sql)
	end

-- get to work...

; with pt0 as (

	-- what profiles were completed in our time range?
	select profile_id
	from profiletracking
	WHERE tracking_status = 'COMP'
	and coalesce(time_out, time_in) between
	@start_date and @end_date

),
pt1 as (
     
	-- now get the first instance of completion for each profile in pt0
	-- (because pt0 might not be the first time it completed)
	select profile_id, min(tracking_id) min_tracking_id 
	from profiletracking 
	WHERE profile_id in (select profile_id from pt0)
	and tracking_status = 'COMP' 
	GROUP BY profile_id

),
pt2 as (

	-- now get the full data for the first completion instance
	-- found in pt1, IF that instance was actually in our date range

	select p2.profile_id, p2.tracking_id,
	p2.profile_curr_status_code, p2.tracking_status, p2.time_in, p2.time_out,
	p2.added_by
	from profiletracking p2
	join pt1 on p2.profile_id =
	pt1.profile_id
	and p2.tracking_id = pt1.min_tracking_id
	WHERE coalesce(p2.time_out, p2.time_in)
	between @start_date and @end_date

)

-- now select out profile/cust/gen data for our 1st-time completed profiles

select 
	pqa.company_id
	, pqa.profit_ctr_id
	, pqa.approval_code
	, p.approval_desc
	, p.profile_id
	, p.curr_status_code as profile_status
	, pqa.status as approval_status
	, p.customer_id
	, c.cust_name
	, p.generator_id
	, g.generator_name
	, p.date_added as profile_created_date
	, coalesce(pt2.time_out, pt2.time_in) as tracking_completed_date
	, u.user_name as tracking_completed_user_name
	, u.user_code as tracking_completed_user_code
from pt2
join profile p on pt2.profile_id = p.profile_id
join profilequoteapproval pqa on p.profile_id = pqa.profile_id
join customer c on p.customer_id = c.customer_id
join generator g on p.generator_id = g.generator_id
join users u on pt2.added_by = u.user_code
join @tbl_profit_center_filter pc on pqa.company_id = pc.company_id and pqa.profit_ctr_id = pc.profit_ctr_id
WHERE 1=1
	and p.curr_status_code = 'A'
	and coalesce(pt2.time_out, pt2.time_in) between @start_date and @end_date
ORDER BY pqa.company_id, pqa.profit_ctr_id, p.profile_id


go

grant execute on sp_hub_approved_waste_profiles to eqweb, cor_user
go

