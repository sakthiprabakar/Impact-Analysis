
create proc sp_reports_transship_profiles (
	@start_date datetime,
	@end_date datetime
) as
/* ***********************************************************************
sp_reports_transship_profiles

Explanation:	
	In EQAI, please create a report that details the following:
	Time Period (entered by user)
	# of Waste Approvals that have a transship TG's completed within above time period broken out by:
	-  USE facility waste approved into (e.g. Detroit South, USEM, York). 
	-  # of above approvals that show the outbound facility to be ANOTHER USE facility-Sub broken 
		out by approvals that require a new approval # for 3rd party vs. approvals that fit under 
		an existing 3rd party approval #,
	-  # of approvals that show the outbound facility to be a non USE facility (sub-broken out by 
		export to another country)-Sub broken out by approvals that require a new approval # for 
		3rd party vs. approvals that fit under an existing 3rd party approval #
	-  Separately, a line that shows (for the time period) how many transship approvals were done 
		into each site that did not have a "pre location" blank-no entry (Profile tracking screen 
		detail tab).  Another Gemini will be created which details this item.

History:
	2/28/2017	JPB	Created SP based on Paul_K's script for GEM:40755

Sample:
	exec sp_reports_transship_profiles '1/1/2017', '1/31/2017'
	
*********************************************************************** */

-- End Of Day on @end_date:
if datepart(hh, @end_date) = 0 set @end_date = @end_date + 0.99999

-- Set up related dates:
declare @min_start_date datetime = DATEADD(month, -8, @start_date)
declare @expiration_start_date_reg datetime = DATEADD(year, 1, @start_date)
declare @expiration_end_date_reg datetime = DATEADD(year, 1, @end_date)
declare @expiration_start_date_univ datetime = DATEADD(year, 20, @start_date)
declare @expiration_end_date_univ datetime = DATEADD(year, 20, @end_date)

-- TO a USE Facility
select distinct 
'Transship to another USE Facility, using an existing approval' as result_type,
p.ap_expiration_date, p.ap_start_date, p.Profile_id, o_pc.default_TSDF_code as 'Receiving Facility', pqa.company_id as 'Inbound Company', pqa.profit_ctr_id as 'Inbound Profit Center', p.customer_id, p.generator_id, 
pqa.Treatment_id, t.Treatment_process_code, pc.default_TSDF_code as 'Outbound TSDF', t2.TSDF_country_code as 'Outbound TSDF Country', cast(pqa.ob_eq_Profile_id as char) as 'Approval ID', isnull(p.added_by, '') as 'Created By', isnull(u.user_name,'') as 'User Name', pqa.date_added as 'Date OB Created', 'USE' as 'TSDF Type', cast(pqa.OB_EQ_company_id as char) as 'Outbound Company ID', cast(pqa.OB_EQ_profit_ctr_id as char) as 'Outbound Profit Center ID'
--, * 
from ProfileQuoteApproval pqa 
	join Profile p on p.Profile_id = pqa.Profile_id
	--join Profileaudit pa on p.Profile_id = pa.Profile_id and pa.after_value = 'A' and table_name = 'Profile' and pa.column_name = 'curr_status_code' 
	join ProfileTracking pt on pqa.Profile_id = pt.Profile_id 
	join ProfileQuoteDetail pqd on pqa.Profile_id = pqd.Profile_id and pqa.company_id = pqd.company_id and pqa.profit_ctr_id = pqd.profit_ctr_id 
	
	join Treatment t on pqa.Treatment_id = t.Treatment_id and pqa.company_id = t.company_id and pqa.profit_ctr_id = t.profit_ctr_id
	left outer join TSDFApproval ta on pqa.ob_TSDF_approval_id = ta.TSDF_approval_id
	left outer join TSDF ts on ta.TSDF_code = ts.TSDF_code
	left outer join ProfitCenter pc on pqa.OB_EQ_company_id = pc.company_ID and pqa.OB_EQ_profit_ctr_id = pc.profit_ctr_ID
	left outer join TSDF t2 on t2.TSDF_code = pc.default_TSDF_code
	join ProfitCenter o_pc on pqa.company_id = o_pc.company_ID and pqa.profit_ctr_id = o_pc.profit_ctr_ID
	left outer join Users u on p.added_by = u.user_code
	where 
		--pt.tracking_status = 'COMP' and pt.time_in >= @start_date and pt.time_out <= @end_date
		--pa.date_modified >= @start_date and pa.date_modified <= @end_date
		((p.ap_expiration_date >= @expiration_start_date_reg and p.ap_expiration_date <= @expiration_end_date_reg)
		or
		(p.ap_expiration_date >= @expiration_start_date_univ and p.ap_expiration_date <= @expiration_end_date_univ))
		and t.Treatment_process_code = 'Tranship'
		and pqa.status = 'A' 
		and pqa.OB_EQ_Profile_id is not null  and pqa.location is not null and location_type = 'O' and pqa.ob_TSDF_approval_id is null --13
		and p.ap_start_date >= @min_start_date

		
UNION 


-- TO a NON-USE Facility
select distinct 
'Transship to 3rd Party (non-USE) Facility, using an existing approval' as result_type,
p.ap_expiration_date, p.ap_start_date, p.Profile_id, o_pc.default_TSDF_code as 'Receiving Facility', pqa.company_id as 'Inbound Company', pqa.profit_ctr_id as 'Inbound Profit Center', p.customer_id, p.generator_id, 
pqa.Treatment_id, t.Treatment_process_code, ts.TSDF_code as 'Outbound TSDF', ts.TSDF_country_code as 'Outbound TSDF Country', cast(pqa.OB_TSDF_approval_id as char) as 'Approval ID', isnull(ta.added_by,'') as 'Created By', isnull(u.user_name,'') as 'User Name', ta.date_added as 'Date OB Created', '3rd Party' as 'TSDF Type', cast(ta.company_id as char) as 'Outbound Company ID', cast(ta.profit_ctr_id as char) as 'Outbound Profit Center ID'
--, * 
from ProfileQuoteApproval pqa 
	join Profile p on p.Profile_id = pqa.Profile_id
	--join Profileaudit pa on p.Profile_id = pa.Profile_id and pa.after_value = 'A' and table_name = 'Profile' and pa.column_name = 'curr_status_code' 
	join ProfileTracking pt on pqa.Profile_id = pt.Profile_id 
	join ProfileQuoteDetail pqd on pqa.Profile_id = pqd.Profile_id and pqa.company_id = pqd.company_id and pqa.profit_ctr_id = pqd.profit_ctr_id 
	join Treatment t on pqa.Treatment_id = t.Treatment_id and pqa.company_id = t.company_id and pqa.profit_ctr_id = t.profit_ctr_id
	left outer join TSDFApproval ta on pqa.ob_TSDF_approval_id = ta.TSDF_approval_id
	left outer join TSDF ts on ta.TSDF_code = ts.TSDF_code
	left outer join ProfitCenter pc on pqa.OB_EQ_company_id = pc.company_ID and pqa.OB_EQ_profit_ctr_id = pc.profit_ctr_ID
	join ProfitCenter o_pc on pqa.company_id = o_pc.company_ID and pqa.profit_ctr_id = o_pc.profit_ctr_ID
	left outer join Users u on p.added_by = u.user_code
	where 
		--pt.tracking_status = 'COMP' and pt.time_in >= @start_date and pt.time_out <= @end_date
		--pa.date_modified >= @start_date and pa.date_modified <= @end_date
		((p.ap_expiration_date >= @expiration_start_date_reg and p.ap_expiration_date <= @expiration_end_date_reg)
		or
		(p.ap_expiration_date >= @expiration_start_date_univ and p.ap_expiration_date <= @expiration_end_date_univ))
		and t.Treatment_process_code = 'Tranship'
		and pqa.status = 'A' 
		and pqa.OB_EQ_Profile_id is null  and pqa.location is not null and location_type = 'O' and pqa.ob_TSDF_approval_id is not null --72
		and p.ap_start_date >= @min_start_date
--		and p.Profile_id = 546609
union

-- To NO Facility(?)
select distinct 
'Transship to Unspecified Facility' as result_type,
p.ap_expiration_date, p.ap_start_date, p.Profile_id, o_pc.default_TSDF_code as 'Receiving Facility', pqa.company_id as 'Inbound Company', pqa.profit_ctr_id as 'Inbound Profit Center', p.customer_id, p.generator_id, 
pqa.Treatment_id, t.Treatment_process_code, '' as 'Outbound TSDF', '' as 'Outbound TSDF Country', '' as 'Approval ID', '' as 'Created By', '' as 'User Name', '' as 'Date OB Created', 'None Assigned' as 'TSDF Type',  ''as 'Outbound Company ID', '' as 'Outbound Profit Center ID'
--, * 
from ProfileQuoteApproval pqa 
	join Profile p on p.Profile_id = pqa.Profile_id
	--join Profileaudit pa on p.Profile_id = pa.Profile_id and pa.after_value = 'A' and table_name = 'Profile' and pa.column_name = 'curr_status_code' 
	join ProfileTracking pt on pqa.Profile_id = pt.Profile_id 
	join ProfileQuoteDetail pqd on pqa.Profile_id = pqd.Profile_id and pqa.company_id = pqd.company_id and pqa.profit_ctr_id = pqd.profit_ctr_id 
	
	join Treatment t on pqa.Treatment_id = t.Treatment_id and pqa.company_id = t.company_id and pqa.profit_ctr_id = t.profit_ctr_id
	left outer join TSDFApproval ta on pqa.ob_TSDF_approval_id = ta.TSDF_approval_id
	left outer join TSDF ts on ta.TSDF_code = ts.TSDF_code
	left outer join ProfitCenter pc on pqa.OB_EQ_company_id = pc.company_ID and pqa.OB_EQ_profit_ctr_id = pc.profit_ctr_ID
	join ProfitCenter o_pc on pqa.company_id = o_pc.company_ID and pqa.profit_ctr_id = o_pc.profit_ctr_ID
	left outer join Users u on p.added_by = u.user_code
	where 
		--pt.tracking_status = 'COMP' and pt.time_in >= @start_date and pt.time_out <= @end_date
		--pa.date_modified >= @start_date and pa.date_modified <= @end_date
		((p.ap_expiration_date >= @expiration_start_date_reg and p.ap_expiration_date <= @expiration_end_date_reg)
		or
		(p.ap_expiration_date >= @expiration_start_date_univ and p.ap_expiration_date <= @expiration_end_date_univ))
		and t.Treatment_process_code = 'Tranship'
		and pqa.status = 'A' 
		and pqa.OB_EQ_Profile_id is null and pqa.ob_TSDF_approval_id is null and pqa.location is null --132
		and p.ap_start_date >= @min_start_date
-------------------Added
UNION

-- TO a USE Facility without a specific ob Profile set?
select distinct 
'Transship to USE Facility, unspecified approval' as result_type,
p.ap_expiration_date, p.ap_start_date, p.Profile_id, o_pc.default_TSDF_code as 'Receiving Facility', pqa.company_id as 'Inbound Company', pqa.profit_ctr_id as 'Inbound Profit Center', p.customer_id, p.generator_id, 
pqa.Treatment_id, t.Treatment_process_code, pqa.location as 'Outbound TSDF', ts.TSDF_country_code as 'Outbound TSDF Country', '' as 'Approval ID', isnull(p.added_by, '') as 'Created By', isnull(u.user_name,'') as 'User Name', pqa.date_added as 'Date OB Created', 'USE' as 'TSDF Type', cast(ts.eq_company as char) as 'Outbound Company ID', cast(ts.eq_profit_ctr as char) as 'Outbound Profit Center ID'
--, * 
from ProfileQuoteApproval pqa 
	join Profile p on p.Profile_id = pqa.Profile_id
	join ProfileTracking pt on pqa.Profile_id = pt.Profile_id 
	join ProfileQuoteDetail pqd on pqa.Profile_id = pqd.Profile_id and pqa.company_id = pqd.company_id and pqa.profit_ctr_id = pqd.profit_ctr_id 
	join Treatment t on pqa.Treatment_id = t.Treatment_id and pqa.company_id = t.company_id and pqa.profit_ctr_id = t.profit_ctr_id
	left outer join TSDFApproval ta on pqa.ob_TSDF_approval_id = ta.TSDF_approval_id
	join TSDF ts on pqa.location = ts.TSDF_code and ts.eq_flag = 'T'
	left outer join ProfitCenter pc on pqa.OB_EQ_company_id = pc.company_ID and pqa.OB_EQ_profit_ctr_id = pc.profit_ctr_ID
	join ProfitCenter o_pc on pqa.company_id = o_pc.company_ID and pqa.profit_ctr_id = o_pc.profit_ctr_ID
	left outer join Users u on p.added_by = u.user_code
	where 
		((p.ap_expiration_date >= @expiration_start_date_reg and p.ap_expiration_date <= @expiration_end_date_reg)
		or
		(p.ap_expiration_date >= @expiration_start_date_univ and p.ap_expiration_date <= @expiration_end_date_univ))
		and t.Treatment_process_code = 'Tranship'
		and pqa.status = 'A' 
		and pqa.OB_EQ_Profile_id is null  and pqa.location is not null and location_type = 'O' and pqa.ob_TSDF_approval_id is null --13
		and p.ap_start_date >= @min_start_date
		and ( ts.eq_flag = 'T')

UNION 


-- NON USE Facility without a TSDF approval?
select distinct
'Transship to 3rd Party (non-USE) Facility, unspecified approval' as result_type,
p.ap_expiration_date, p.ap_start_date, p.Profile_id, o_pc.default_TSDF_code as 'Receiving Facility', pqa.company_id as 'Inbound Company', pqa.profit_ctr_id as 'Inbound Profit Center', p.customer_id, p.generator_id, 
pqa.Treatment_id, t.Treatment_process_code, pqa.location as 'Outbound TSDF', ts.TSDF_country_code as 'Outbound TSDF Country', '' as 'Approval ID', '' as 'Created By', '' as 'User Name', '' as 'Date OB Created', '3rd Party' as 'TSDF Type', '' as 'Outbound Company ID', '' as 'Outbound Profit Center ID'
--, * 
from ProfileQuoteApproval pqa 
	join Profile p on p.Profile_id = pqa.Profile_id
	join ProfileTracking pt on pqa.Profile_id = pt.Profile_id 
	join ProfileQuoteDetail pqd on pqa.Profile_id = pqd.Profile_id and pqa.company_id = pqd.company_id and pqa.profit_ctr_id = pqd.profit_ctr_id 
	
	join Treatment t on pqa.Treatment_id = t.Treatment_id and pqa.company_id = t.company_id and pqa.profit_ctr_id = t.profit_ctr_id
	join TSDF ts on pqa.location = ts.TSDF_code and ts.eq_flag <> 'T'
	left outer join ProfitCenter pc on pqa.OB_EQ_company_id = pc.company_ID and pqa.OB_EQ_profit_ctr_id = pc.profit_ctr_ID
	join ProfitCenter o_pc on pqa.company_id = o_pc.company_ID and pqa.profit_ctr_id = o_pc.profit_ctr_ID
	left outer join Users u on p.added_by = u.user_code
	where 
		((p.ap_expiration_date >= @expiration_start_date_reg and p.ap_expiration_date <= @expiration_end_date_reg)
		or
		(p.ap_expiration_date >= @expiration_start_date_univ and p.ap_expiration_date <= @expiration_end_date_univ))
		and t.Treatment_process_code = 'Tranship'
		and pqa.status = 'A' 
		and pqa.OB_EQ_Profile_id is null  and pqa.location is not null and location_type = 'O' and pqa.ob_TSDF_approval_id is null --72
		and p.ap_start_date >= @min_start_date
		and ( ts.eq_flag<> 'T'  or ts.eq_flag is null)
		



		order by p.Profile_id
--		select * from ProfileQuoteApproval where Profile_id = 546609


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_reports_transship_profiles] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_reports_transship_profiles] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_reports_transship_profiles] TO [EQAI]
    AS [dbo];

