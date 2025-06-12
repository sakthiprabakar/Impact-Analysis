
CREATE PROCEDURE sp_rpt_time_on_site_summary_ssrs
	@facility_list	varchar(max)
,	@date_From		datetime
,	@date_to		datetime
AS 
/****************************************************************************
Time on Site Report Wrapper for call from SSRS
(r_time_On_Site)

02/02/2016	JPB	Copied and modified from sp_rpt_time_On_Site
8/26/2016	JPB	Per talk with Bill L and Ahmad R, modified the select for 
				Total_Scheduled_NonBulk to restrict to Scheduled types, which
				was not specified before.
05/08/2017 MPM	Modified to exclude In-Transit receipts.
07/26/2018 JPB	modified datediff(s... to datediff(n and removed one / 60.00
				This, to avoid a datediff error where the number produced was too large.
				SQL is weird.

sp_rpt_time_on_site_summary_ssrs '2,3,12,14,15,16,17,18,21,22,23,24,25,26,27,28,29,30,31,32,33,34,35,40', '6/1/2018', '6/30/2018'
sp_rpt_time_on_site_summary_ssrs null, '6/1/2016', '6/30/2016'
sp_rpt_time_on_site_summary_ssrs '2|0, 3|0, 21|0', '1/21/2015', '2/21/2015'
sp_rpt_time_on_site_summary_ssrs '32|0', '7/01/2015', '7/31/2015'

sp_helptext sp_rpt_time_on_site_summary_ssrs

grant execute on sp_ProfitCenterSelect to eqai, eqweb

****************************************************************************/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

	-- declare @facility_list	varchar(max) = '2|0, 3|0, 3|3, 12|0, 12|1, 12|2, 12|4, 12|5, 12|7, 14|0, 14|4, 14|6, 14|8, 14|9, 14|12, 14|14, 14|17, 21|0, 21|1, 21|3, 22|0, 22|1, 23|0, 25|0, 26|0, 27|0, 29|0, 32|0, 41|0, 42|0, 44|0, 45|0, 46|0, 47|0',	@date_From		datetime	= '6/1/2018',	@date_to		datetime	= '6/30/2018'

if object_id('tempdb..#foo') is not null drop table #foo
if object_id('tempdb..#bar') is not null drop table #bar
if object_id('tempdb..#facility_tmp2') is not null drop table #facility_tmp2
if object_id('tempdb..#facility_list') is not null drop table #facility_list

set @date_to = cast(CONVERT(varchar(20), @date_to, 101) + ' 23:59:59' as datetime)

create table #facility_tmp2 (company_ID int, Profit_Ctr_ID int)
create table #facility_list (company_ID int, Profit_Ctr_ID int, progress_Flag int)

if @facility_list is not null begin
	insert #facility_tmp2 (company_ID, Profit_Ctr_ID)
	select 
			case when charindex('|', row) > 0 then
				convert(int, left(row, charindex('|', row)-1))
			else
				convert(int, row)
			end,
			case when charindex('|', row) > 0 then
				convert(int, right(row, len(row) - charindex('|', row)))
			else
				null
			end
	from dbo.fn_SplitXsvText(',', 1, @facility_list)   
	where isnull(row, '') <> ''

	insert #facility_list select *, 0 from #facility_tmp2 where Profit_Ctr_ID is not null
	insert #facility_list select p.Company_ID, p.Profit_Ctr_ID, 0
		from profitcenter p where company_ID in (select company_ID from #facility_tmp2 where Profit_Ctr_ID is null)
end else begin
	insert #facility_list (company_ID, Profit_Ctr_ID, progress_Flag)
	select company_ID, Profit_Ctr_ID, 0 from profitcenter where status = 'A'
end


SELECT 
		Receipt.Company_ID
	,	Receipt.Profit_Ctr_ID
	,	Isnull(PhoneListLocation.name, ProfitCenter.Profit_Ctr_Name) Profit_Ctr_Name
	,	Receipt.Receipt_ID
	,	Receipt.Line_ID
	,	Receipt.Customer_ID
	,	Customer.Cust_Name
	,	Receipt.Hauler
	,	Receipt.Truck_Code
	,	Receipt.Generator_ID
	,	Generator.Generator_Name
	,	Generator.EPA_ID 
	,	Receipt.Approval_Code
	,	Receipt.Bill_Unit_Code
	,	Receipt.Bulk_Flag
	,	Receipt.Receipt_Date
	,	Receipt.Date_Scheduled
	,	Receipt.Time_In
	,	Receipt.Time_Out
	, Arrival = 
		case when Receipt.Date_Scheduled is null
		then null 
		else 
			case when Receipt.Time_In < Receipt.Date_Scheduled 
			then 'Early'
			else
				case when Receipt.Time_In >= Receipt.Date_Scheduled and Receipt.Time_In <= dateadd(hh, 2, Receipt.Date_Scheduled)
				then 'Within Schedule'
				else
					case when Receipt.Time_In > dateadd(hh, 2, Receipt.Date_Scheduled)
					then 'Late'
					else null
					end
				end
			end
		end
	, [Scheduled] = case when Receipt.Date_Scheduled is null then 'No' else 'Yes' end
	, Total_Hours_On_Site = convert(decimal(10,3), datediff(n, convert(datetime, Receipt.Time_In), convert(datetime, Receipt.Time_Out)) / 60.00 )
	, Scheduled_Hours_On_Site = convert(decimal(10,3), datediff(n, convert(datetime, Receipt.Date_Scheduled), convert(datetime, Receipt.Time_Out)) / 60.00 )
	, Within_2_Hours = case when convert(decimal(10,3), datediff(n, convert(datetime, Receipt.Time_In), convert(datetime, Receipt.Time_Out)) / 60.00 ) > 2
		then 'Exceeded 2 hours'
		else 'Within 2 hours'
		end
	,	Receipt_Problem.Problem_Cause
	,	Receipt.Problem_ID
	,	Receipt_Problem.Problem_Desc
	,	Receipt.manifest_Comment
	, convert(varchar(20), null) as TOS_Type
INTO #foo
FROM Receipt
JOIN #facility_list fl
	ON receipt.Company_ID = fl.Company_ID
	AND receipt.Profit_Ctr_ID = fl.Profit_Ctr_ID
JOIN Company
	ON Company.Company_ID = Receipt.Company_ID
JOIN ProfitCenter
	ON ProfitCenter.Profit_Ctr_ID = Receipt.Profit_Ctr_ID
	AND ProfitCenter.Company_ID = Receipt.Company_ID
JOIN Customer
	ON Customer.Customer_ID = Receipt.Customer_ID
LEFT OUTER JOIN Generator
	ON Generator.Generator_ID = Receipt.Generator_ID
LEFT OUTER JOIN Receipt_Problem
	ON Receipt_Problem.Problem_ID = Receipt.Problem_ID
	AND Receipt_Problem.Company_ID = Receipt.Company_ID
LEFT OUTER JOIN PhoneListLocation
	ON Receipt.company_id = PhoneListLocation.company_id
	AND Receipt.profit_ctr_id = PhoneListLocation.profit_ctr_id
WHERE 
  Receipt.Receipt_Date BETWEEN @date_From AND @date_to
  AND Receipt.Trans_type = 'D'
  AND Receipt.Receipt_Status NOT IN ('T', 'V')	  
  AND Receipt.Trans_mode = 'I'	
ORDER BY
	Receipt.Company_ID
	, Receipt.Profit_Ctr_ID
	, Receipt.Receipt_ID
	, Receipt.Line_ID

-- Early Start/Early Complete: Deliveries that are both early start and early completions (before scheduled time)
update #foo set TOS_Type = 'ES/EC'
WHERE TOS_Type is null and Arrival = 'Early' AND Time_Out < Date_Scheduled

-- Late Start: Deliveries that don't start until 2 hours + after scheduled time
update #foo set TOS_Type = 'Late Start'
WHERE TOS_Type is null and Arrival = 'Late'

-- Unscheduled: Deliveries without a scheduled date
update #foo set TOS_Type = 'Unscheduled'
WHERE TOS_Type is null and Date_Scheduled is null

-- Standard: everything else
update #foo set TOS_Type = 'Standard' where TOS_Type is null

-- Creating buckets
select 
	Company_ID
	,	Profit_Ctr_ID
	, REPLACE(RIGHT(CONVERT(VARCHAR(9), Receipt_Date, 6), 6), ' ', '-') as tos_month
	, Datepart(yyyy, Receipt_Date) Receipt_Year
	, Datepart(mm, Receipt_Date) Receipt_Month
	, Profit_Ctr_Name
	, TOS_Type
	, Bulk_Flag
	, convert(float, avg(
		CASE TOS_Type
			WHEN 'Standard' THEN
				CASE WHEN time_in > date_scheduled then Total_Hours_On_Site else Scheduled_Hours_On_Site end
			ELSE
				Total_Hours_On_Site
		END
	)) as avg_measured_hours
	, convert(float, count(distinct isnull(hauler, '') + ' ' + isnull(truck_code, '') + ' ' + convert(varchar(20), receipt_date) + ' ' + convert(varchar(20), time_in))) as load_count
Into #bar
From #foo
group by 
		Company_ID
	,	Profit_Ctr_ID
	, REPLACE(RIGHT(CONVERT(VARCHAR(9), Receipt_Date, 6), 6), ' ', '-')
	, Datepart(yyyy, Receipt_Date)
	, Datepart(mm, Receipt_Date)
	, Profit_Ctr_Name
	, TOS_Type
	, Bulk_flag
order by 
	Datepart(yyyy, Receipt_Date)
	, Datepart(mm, Receipt_Date)
	, Profit_Ctr_Name
	, TOS_Type
	, Bulk_Flag desc


-- SELECT * FROM #foo
-- SELECT * FROM #bar

select distinct
	Header.TOS_Month
	, Header.Receipt_Year
	, Header.Receipt_Month
	, Header.Profit_Ctr_Name

	, round(Standard_Bulk.Avg_Measured_Hours, 2) Standard_Bulk_Avg_Measured_Hours
	, Standard_Bulk.Load_Count Standard_Bulk_Load_Count
	, round(Standard_Nonbulk.Avg_Measured_Hours, 2) Standard_Nonbulk_Avg_Measured_Hours
	, Standard_Nonbulk.Load_Count Standard_Nonbulk_Load_Count

	, round(Esec_Bulk.Avg_Measured_Hours, 2) Esec_Bulk_Avg_Measured_Hours
	, Esec_Bulk.Load_Count Esec_Bulk_Load_Count
	, round(Esec_Nonbulk.Avg_Measured_Hours, 2) Esec_Nonbulk_Avg_Measured_Hours
	, Esec_Nonbulk.Load_Count Esec_Nonbulk_Load_Count

	, round(Late_Bulk.Avg_Measured_Hours, 2) Late_Bulk_Avg_Measured_Hours
	, Late_Bulk.Load_Count Late_Bulk_Load_Count
	, round(Late_Nonbulk.Avg_Measured_Hours, 2) Late_Nonbulk_Avg_Measured_Hours
	, Late_Nonbulk.Load_Count Late_Nonbulk_Load_Count

	, round(UnScheduled_Bulk.Avg_Measured_Hours, 2) UnScheduled_Bulk_Avg_Measured_Hours
	, UnScheduled_Bulk.Load_Count UnScheduled_Bulk_Load_Count
	, round(UnScheduled_Nonbulk.Avg_Measured_Hours, 2) UnScheduled_Nonbulk_Avg_Measured_Hours
	, UnScheduled_Nonbulk.Load_Count UnScheduled_Nonbulk_Load_Count

	, round(Total_Scheduled_Bulk.Avg_Measured_Hours * (Total_Scheduled_Bulk.Load_Count / Total_Bulk.Load_Count), 2) Total_Scheduled_Bulk_Avg_Measured_Hours
	, Total_Scheduled_Bulk.Load_Count Total_Scheduled_Bulk_Load_Count
	, round(Total_Scheduled_Nonbulk.Avg_Measured_Hours * (Total_Scheduled_Nonbulk.Load_Count / Total_Nonbulk.Load_Count), 2) Total_Scheduled_Nonbulk_Avg_Measured_Hours
	, Total_Scheduled_Nonbulk.Load_Count Total_Scheduled_Nonbulk_Load_Count

/*
	, round(Total_Bulk.Avg_Measured_Hours * (Total_Bulk.Load_Count / Total_Bulk.Load_Count), 2) Total_Bulk_Avg_Measured_Hours
	, Total_Bulk.Load_Count Total_Bulk_Load_Count
	, round(Total_Nonbulk.Avg_Measured_Hours * (Total_Nonbulk.Load_Count / Total_Nonbulk.Load_Count), 2) Total_Nonbulk_Avg_Measured_Hours
	, Total_Nonbulk.Load_Count Total_Nonbulk_Load_Count
*/

	, round(
	
		isnull((Standard_Bulk.Avg_Measured_Hours * (Standard_Bulk.Load_Count / Total_Bulk.Load_Count)), 0) +
		isnull((Esec_Bulk.Avg_Measured_Hours * (Esec_Bulk.Load_Count / Total_Bulk.Load_Count)), 0) +
		isnull((Late_Bulk.Avg_Measured_Hours * (Late_Bulk.Load_Count / Total_Bulk.Load_Count)), 0) +
		isnull((UnScheduled_Bulk.Avg_Measured_Hours * (UnScheduled_Bulk.Load_Count / Total_Bulk.Load_Count)), 0)
		
		, 2) Total_Bulk_Avg_Measured_Hours
	, Total_Bulk.Load_Count Total_Bulk_Load_Count
	
	, round(

		isnull((Standard_Nonbulk.Avg_Measured_Hours * (Standard_Nonbulk.Load_Count / Total_Nonbulk.Load_Count)), 0) +
		isnull((Esec_Nonbulk.Avg_Measured_Hours * (Esec_Nonbulk.Load_Count / Total_Nonbulk.Load_Count)), 0) +
		isnull((Late_Nonbulk.Avg_Measured_Hours * (Late_Nonbulk.Load_Count / Total_Nonbulk.Load_Count)), 0) +
		isnull((UnScheduled_Nonbulk.Avg_Measured_Hours * (UnScheduled_Nonbulk.Load_Count / Total_Nonbulk.Load_Count)), 0)

		, 2) Total_Nonbulk_Avg_Measured_Hours
	, Total_Nonbulk.Load_Count Total_Nonbulk_Load_Count

-- select *
from #bar Header

left join (
	select * from #bar where TOS_Type = 'Standard' and bulk_flag = 'T'
	) Standard_Bulk on Header.TOS_Month = Standard_Bulk.TOS_Month and Header.Company_id = Standard_Bulk.Company_id and Header.Profit_ctr_id = Standard_Bulk.Profit_ctr_id
left join (
	select * from #bar where TOS_Type = 'Standard' and bulk_flag = 'F'
	) Standard_NonBulk on Header.TOS_Month = Standard_NonBulk.TOS_Month and Header.Company_id = Standard_NonBulk.Company_id and Header.Profit_ctr_id = Standard_NonBulk.Profit_ctr_id
	
left join (
	select * from #bar where TOS_Type = 'ES/EC' and bulk_flag = 'T'
	) ESEC_Bulk on Header.TOS_Month = ESEC_Bulk.TOS_Month and Header.Company_id = ESEC_Bulk.Company_id and Header.Profit_ctr_id = ESEC_Bulk.Profit_ctr_id
left join (
	select * from #bar where TOS_Type = 'ES/EC' and bulk_flag = 'F'
	) ESEC_NonBulk on Header.TOS_Month = ESEC_NonBulk.TOS_Month and Header.Company_id = ESEC_NonBulk.Company_id and Header.Profit_ctr_id = ESEC_NonBulk.Profit_ctr_id
	
left join (
	select * from #bar where TOS_Type = 'Late Start' and bulk_flag = 'T'
	) Late_Bulk on Header.TOS_Month = Late_Bulk.TOS_Month and Header.Company_id = Late_Bulk.Company_id and Header.Profit_ctr_id = Late_Bulk.Profit_ctr_id
left join (
	select * from #bar where TOS_Type = 'Late Start' and bulk_flag = 'F'
	) Late_NonBulk on Header.TOS_Month = Late_NonBulk.TOS_Month and Header.Company_id = Late_NonBulk.Company_id and Header.Profit_ctr_id = Late_NonBulk.Profit_ctr_id

	
left join (
	select * from #bar where TOS_Type = 'UnScheduled' and bulk_flag = 'T'
	) UnScheduled_Bulk on Header.TOS_Month = UnScheduled_Bulk.TOS_Month and Header.Company_id = UnScheduled_Bulk.Company_id and Header.Profit_ctr_id = UnScheduled_Bulk.Profit_ctr_id
left join (
	select * from #bar where TOS_Type = 'UnScheduled' and bulk_flag = 'F'
	) UnScheduled_NonBulk on Header.TOS_Month = UnScheduled_NonBulk.TOS_Month and Header.Company_id = UnScheduled_NonBulk.Company_id and Header.Profit_ctr_id = UnScheduled_NonBulk.Profit_ctr_id

left join (
	select 
	company_id, profit_ctr_id, tos_month, receipt_year, receipt_month, profit_ctr_name, bulk_flag
	, avg(avg_measured_hours) avg_measured_hours, sum(load_count) load_count
	from #bar where  bulk_flag = 'T' and TOS_Type in ('Standard', 'ES/EC', 'Late Start')
	group by company_id, profit_ctr_id, tos_month, receipt_year, receipt_month, profit_ctr_name, bulk_flag
	) Total_Scheduled_Bulk on Header.TOS_Month = Total_Scheduled_Bulk.TOS_Month and Header.Company_id = Total_Scheduled_Bulk.Company_id and Header.Profit_ctr_id = Total_Scheduled_Bulk.Profit_ctr_id

left join (
	select 
	company_id, profit_ctr_id, tos_month, receipt_year, receipt_month, profit_ctr_name, bulk_flag
	, avg(avg_measured_hours) avg_measured_hours, sum(load_count) load_count
	from #bar where  bulk_flag = 'F'
	and TOS_Type in ('Standard', 'ES/EC', 'Late Start') -- 2016-08-26
	group by company_id, profit_ctr_id, tos_month, receipt_year, receipt_month, profit_ctr_name, bulk_flag
	) Total_Scheduled_NonBulk on Header.TOS_Month = Total_Scheduled_NonBulk.TOS_Month and Header.Company_id = Total_Scheduled_NonBulk.Company_id and Header.Profit_ctr_id = Total_Scheduled_NonBulk.Profit_ctr_id


left join (
	select 
	company_id, profit_ctr_id, tos_month, receipt_year, receipt_month, profit_ctr_name, bulk_flag
	, avg(avg_measured_hours) avg_measured_hours, sum(load_count) load_count
	from #bar where  bulk_flag = 'T'
	group by company_id, profit_ctr_id, tos_month, receipt_year, receipt_month, profit_ctr_name, bulk_flag
	) Total_Bulk on Header.TOS_Month = Total_Bulk.TOS_Month and Header.Company_id = Total_Bulk.Company_id and Header.Profit_ctr_id = Total_Bulk.Profit_ctr_id

left join (
	select 
	company_id, profit_ctr_id, tos_month, receipt_year, receipt_month, profit_ctr_name, bulk_flag
	, avg(avg_measured_hours) avg_measured_hours, sum(load_count) load_count
	from #bar where  bulk_flag = 'F'
	group by company_id, profit_ctr_id, tos_month, receipt_year, receipt_month, profit_ctr_name, bulk_flag
	) Total_NonBulk on Header.TOS_Month = Total_NonBulk.TOS_Month and Header.Company_id = Total_NonBulk.Company_id and Header.Profit_ctr_id = Total_NonBulk.Profit_ctr_id

order by
	Header.Receipt_Year
	, Header.Receipt_Month
	, Header.Profit_Ctr_Name





GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_time_on_site_summary_ssrs] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_time_on_site_summary_ssrs] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_time_on_site_summary_ssrs] TO [EQAI]
    AS [dbo];

