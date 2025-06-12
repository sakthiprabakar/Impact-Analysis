
CREATE PROC sp_profile_turnaround_time_summary (
	@copc_list	varchar(max)
	, @start_date datetime
	, @end_date datetime
)

/* *************************************************************************
sp_profile_turnaround_time_summary

Returns summarized Profile Turnaround Time information
	NOT RELATED TO PROFILE APPROVAL TIME (except in name similarity).
	This version is much simpler.

Sample:
	sp_profile_turnaround_time_summary '', '1/1/2016', '6/30/2016 23:59'
	
		Total_Approvals	Zero_to_Three_Days	Four_to_Five_Days	Six_to_Ten_Days	Over_Ten_Days	Average_Approval_Days	Three_Day_Percent	Five_Day_Percent	Ten_Day_Percent		Eleven_Day_Percent
		10472			5216				2337				1491			1428			12						49.810000000000000	22.320000000000000	14.240000000000000	13.640000000000000
	
	sp_profile_turnaround_time_summary '21|0', '1/1/2016', '6/30/2016 23:59'
	
		Total_Approvals	Zero_to_Three_Days	Four_to_Five_Days	Six_to_Ten_Days	Over_Ten_Days	Average_Approval_Days	Three_Day_Percent	Five_Day_Percent	Ten_Day_Percent		Eleven_Day_Percent
		6056			2909				1475				892				780				11						48.040000000000000	24.360000000000000	14.730000000000000	12.880000000000000
	sp_profile_turnaround_time_summary '1/1/2015', '6/30/2015 23:59'

History:
	02/16/2016	JPB	Created.  GEM-36062
	02/22/2016	JPB	Per AJH, changed first two bucket terms, and accounted for decimals between the integers in those cases.
	01/11/2017	JPB	Per GEM-41204 - Added facility dropdown to inputs.

************************************************************************* */

AS


-- Database List: (expects x|y, x1|y1 format list)
    create table #database_list (company_id int, profit_ctr_id int)
    if datalength((@copc_list)) > 0 begin
        declare @scrub table (dbname varchar(10), company_id int, profit_ctr_id int)

        -- Split the input list into the scub table's dbname column
        insert @scrub select row as dbname, null, null from dbo.fn_SplitXsvText(',', 1, @copc_list) where isnull(row, '') <> ''

        -- Split the CO|PC values in dbname into company_id, profit_ctr_id: company_id first.
        update @scrub set company_id = convert(int, case when charindex('|', dbname) > 0 then left(dbname, charindex('|', dbname)-1) else dbname end) where dbname like '%|%'

        -- Split the CO|PC values in dbname into company_id, profit_ctr_id: profit_ctr_id's turn
        update @scrub set profit_ctr_id = convert(int, replace(dbname, convert(varchar(10), company_id) + '|', '')) where dbname like '%|%'

        -- Put the remaining, valid (process_flag = 0) scrub table results into #profitcenter_list
        insert #database_list
        select distinct company_id, profit_ctr_id from @scrub where company_id is not null and profit_ctr_id is not null
    end
    
    if 0 = (select count(*) from #database_list)
		insert #database_list
		select company_id, profit_ctr_id
		from profitcenter

-- declare 	@start_date datetime = '1/1/2015', @end_date datetime = '12/31/2015 23:59'


if datepart(hh, @end_date) = 0 set @end_date = @end_date + 0.99999

declare @dataset table (
	profile_id int
	, date_start datetime
	, date_end datetime
)

declare @mathset table (
	profile_id int
	, date_start datetime
	, adjusted_date_start datetime
	, date_end datetime
--	, business_minutes int
--	, business_hours int
	, total_days int
	, business_days int
)

-- Step 1: Select the profiles and calculate their start/end dates that were completed within the input date range.
insert @dataset
select
	profile.profile_id
	, coalesce(
		case when profile.received_date > profile.ap_start_date then profile.date_added else profile.received_date end
		, profile.date_added
	  ) as date_start
	, valid_profiles.date_end
from profile
inner join		
( 
	-- This set finds first completion dates within the input date range.
	select profile_id
	, min(Coalesce(time_out, time_in, getdate())) as date_end
	from ProfileTracking 
	where tracking_status = 'COMP' 
	and profile_curr_status_code = 'A'
	and IsNull(manual_bypass_tracking_flag, 'F') = 'F'
	group by profile_id
	having min(Coalesce(time_out, time_in, getdate())) between @start_date and @end_date
) valid_profiles
	on profile.profile_id = valid_profiles.profile_id
where 
	-- guarantee the date_end value (first completed date) comes after the received_date/date_added to weed out reapprovals with recent date_received values.
	valid_profiles.date_end > coalesce(
		case when profile.received_date > profile.ap_start_date then profile.date_added else profile.received_date end
		, profile.date_added
	)
	-- filter by company & profitcenter
	and exists (
		select 1 
		from profilequoteapproval pqa
		inner join #database_list dl
			on pqa.company_id = dl.company_id
			and pqa.profit_ctr_id = dl.profit_ctr_id
		where pqa.profile_id = profile.profile_id
		and pqa.status = 'A'
	)

-- Step 2: Calculate "adjusted" start date (noon when hour is otherwise 0), and biz mi
insert @mathset
select profile_id
	, date_start
	, case when datepart(hh, date_start) = 0 then dateadd(hh, 12, date_start) else date_start end as adjusted_date_start
	, date_end
/*
-- Not actually needed:
	, dbo.fn_business_minutes(
		case when datepart(hh, date_start) = 0 then dateadd(hh, 12, date_start) else date_start end -- When no hours are set, assume noon that day
		, date_end
		) as business_minutes
	, (dbo.fn_business_minutes(
		case when datepart(hh, date_start) = 0 then dateadd(hh, 12, date_start) else date_start end -- When no hours are set, assume noon that day
		, date_end
		) / 60) as business_hours
*/
	, IsNull(datediff(dd, case when datepart(hh, date_start) = 0 then dateadd(hh, 12, date_start) else date_start end, date_end) + 1, 0) AS total_days
    , IsNull(dbo.fn_business_days(case when datepart(hh, date_start) = 0 then dateadd(hh, 12, date_start) else date_start end, date_end), 0) AS business_days                                                        
from @dataset

/* Original 
Select 
	-- @start_date From_Date	
	-- , @end_date To_Date	
	count(profile_id) Total_Approvals	
	, Sum(case When Business_days Between 0 And 3 Then 1 Else 0 End) Zero_to_Three_Days	
	, Sum(case When Business_days Between 3.0000001 And 5 Then 1 Else 0 End) Four_to_Five_Days	
	, Sum(case When Business_days Between 5.0000001 And 10 Then 1 Else 0 End) Six_to_Ten_Days	
	, Sum(case When Business_days > 10.0000001 Then 1 Else 0 End) Over_Ten_Days	
	, Avg(business_days) Average_Approval_Days	
	, Round(((sum(case When Business_days Between 0 And 3 Then 1 Else 0 End) * 1.00) / Count(profile_id)) * 100.00, 2) Three_Day_Percent	
	, Round(((sum(case When Business_days Between 3.0000001 And 5 Then 1 Else 0 End) * 1.00) / Count(profile_id)) * 100.00, 2) Five_Day_Percent
	, Round(((sum(case When Business_days Between 5.0000001 And 10 Then 1 Else 0 End) * 1.00) / Count(profile_id)) * 100.00, 2) Ten_Day_Percent	
	, Round(((sum(case When Business_days > 10.0000001 Then 1 Else 0 End) * 1.00) / Count(profile_id)) * 100.00, 2) Eleven_Day_Percent
from @mathset

Extra Crispy 
*/

Select 
	d.company_id, d.profit_ctr_id,
	case when d.company_id = 0 then 999999 else d.company_id end _order1, case when d.company_id = 0 then 999999 else d.profit_ctr_id end _order2
	,count(m.profile_id) Total_Approvals	
	, Sum(case When m.Business_days Between 0 And 3 Then 1 Else 0 End) Zero_to_Three_Days	
	, Sum(case When m.Business_days Between 3.0000001 And 5 Then 1 Else 0 End) Four_to_Five_Days	
	, Sum(case When m.Business_days Between 5.0000001 And 10 Then 1 Else 0 End) Six_to_Ten_Days	
	, Sum(case When m.Business_days > 10.0000001 Then 1 Else 0 End) Over_Ten_Days	
	, Avg(m.business_days) Average_Approval_Days	
	, Round(((sum(case When m.Business_days Between 0 And 3 Then 1 Else 0 End) * 1.00) / Count(m.profile_id)) * 100.00, 2) Three_Day_Percent	
	, Round(((sum(case When m.Business_days Between 3.0000001 And 5 Then 1 Else 0 End) * 1.00) / Count(m.profile_id)) * 100.00, 2) Five_Day_Percent
	, Round(((sum(case When m.Business_days Between 5.0000001 And 10 Then 1 Else 0 End) * 1.00) / Count(m.profile_id)) * 100.00, 2) Ten_Day_Percent	
	, Round(((sum(case When m.Business_days > 10.0000001 Then 1 Else 0 End) * 1.00) / Count(m.profile_id)) * 100.00, 2) Eleven_Day_Percent
from #database_list d
left join ProfileQuoteApproval pqa
	on d.company_id = pqa.company_id
	and d.profit_ctr_id = pqa.profit_ctr_id
	and pqa.status = 'A'
left join @mathset m
	on pqa.profile_id = m.profile_id
group by d.company_id, d.profit_ctr_id
having Count(m.profile_id) > 0

union all

Select 
	0, 0,
	999999 _order1, 999999 order2,
	-- @start_date From_Date	
	-- , @end_date To_Date	
	count(profile_id) Total_Approvals	
	, Sum(case When Business_days Between 0 And 3 Then 1 Else 0 End) Zero_to_Three_Days	
	, Sum(case When Business_days Between 3.0000001 And 5 Then 1 Else 0 End) Four_to_Five_Days	
	, Sum(case When Business_days Between 5.0000001 And 10 Then 1 Else 0 End) Six_to_Ten_Days	
	, Sum(case When Business_days > 10.0000001 Then 1 Else 0 End) Over_Ten_Days	
	, Avg(business_days) Average_Approval_Days	
	, Round(((sum(case When Business_days Between 0 And 3 Then 1 Else 0 End) * 1.00) / Count(profile_id)) * 100.00, 2) Three_Day_Percent	
	, Round(((sum(case When Business_days Between 3.0000001 And 5 Then 1 Else 0 End) * 1.00) / Count(profile_id)) * 100.00, 2) Five_Day_Percent
	, Round(((sum(case When Business_days Between 5.0000001 And 10 Then 1 Else 0 End) * 1.00) / Count(profile_id)) * 100.00, 2) Ten_Day_Percent	
	, Round(((sum(case When Business_days > 10.0000001 Then 1 Else 0 End) * 1.00) / Count(profile_id)) * 100.00, 2) Eleven_Day_Percent
from @mathset
order by _order1, _order2 



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_profile_turnaround_time_summary] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_profile_turnaround_time_summary] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_profile_turnaround_time_summary] TO [EQAI]
    AS [dbo];

