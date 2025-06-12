
CREATE PROCEDURE sp_rpt_time_on_site_ssrs
	@facility_list	varchar(max)
,	@date_From		datetime
,	@date_to		datetime
AS 
/****************************************************************************
Time on Site Report Wrapper for call from SSRS
(r_time_On_Site)

02/02/2016	JPB	Copied and modified from sp_rpt_time_On_Site
05/08/2017 MPM	Modified to exclude In-Transit receipts.


sp_rpt_time_On_Site_Ssrs '2|0, 3|0, 21|0', '1/21/2015', '2/21/2015'
sp_rpt_time_On_Site_Ssrs '21|0', '1/01/2015', '2/01/2015'

****************************************************************************/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

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
	,	ProfitCenter.Profit_Ctr_Name
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
	, Total_Hours_On_Site = convert(decimal(10,3), datediff(s, convert(datetime, Receipt.Time_In), convert(datetime, Receipt.Time_Out)) / 60.00 / 60.00)
	, Scheduled_Hours_On_Site = convert(decimal(10,3), datediff(s, convert(datetime, Receipt.Date_Scheduled), convert(datetime, Receipt.Time_Out)) / 60.00 / 60.00)
	, Within_2_Hours = case when convert(decimal(10,3), datediff(s, convert(datetime, Receipt.Time_In), convert(datetime, Receipt.Time_Out)) / 60.00 / 60.00) > 2
		then 'Exceeded 2 hours'
		else 'Within 2 hours'
		end
	,	Receipt_Problem.Problem_Cause
	,	Receipt.Problem_ID
	,	Receipt_Problem.Problem_Desc
	,	Receipt.manifest_Comment
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


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_time_on_site_ssrs] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_time_on_site_ssrs] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_time_on_site_ssrs] TO [EQAI]
    AS [dbo];

