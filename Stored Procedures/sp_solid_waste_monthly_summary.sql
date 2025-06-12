drop table if exists [sp_solid_waste_monthly_summary]
go

CREATE PROCEDURE [dbo].[sp_solid_waste_monthly_summary]
(
@date_start  datetime = null, 
@date_end   datetime = null,
@copc_list     varchar(4000) = NULL, -- ex: 21|1,14|0,14|1),
@user_code     varchar(100) = NULL, -- for associates,
@permission_id int
)
AS

/* **********************************************************************************  

 Author  : Prabhu  
 Updated On : 14-Nov-2023  
 Type  : Store Procedure   
 Object Name : [dbo].[sp_solid_waste_monthly_summary] 

 Ticket      :Task 72476
 Description : Inbound Solid Waste Monthly Report (Summary)
  
   *****************************************  

 Author  : Prabhu  
 Updated On : 14-Nov-2023  
 Type  : Store Procedure   
 Object Name : [dbo].[sp_solid_waste_monthly_summary] 

 Ticket      :Task 72476
 Description : Inbound Solid Waste Monthly Report (Summary)
  
   sp_solid_waste_monthly_summary 
   @date_start = '10/1/2023'  
 , @date_end = '10/31/2024' 
 , @copc_list  = ''
 , @user_code  ='myaklin'
 , @permission_id  =null
  

  sp_solid_waste_monthly_summary '1/1/2012', '12/31/2012', '', 'JONATHAN',  79  

   
********************************************************************************** */  
 
BEGIN

declare @start_date DATETIME = DATEADD(MONTH, DATEDIFF(MONTH, 0, GETDATE()), 0);
declare 
 @i_date_start   datetime = isnull(@date_start, (@start_date))
,@i_date_end   datetime = isnull(@date_end, (DATEADD(DAY, -1, DATEADD(MONTH, 1, @start_date))))

if DATEPART(hh, @i_date_end) = 0 and DATEPART(n, @i_date_end) = 0  
   set @i_date_end = DATEADD(s, (((23 * 60 * 60) + (59 * 60)) + 59), @i_date_end) 

create table #tbl_profit_center_filters (  
    company_id int,  
    profit_ctr_id int  
)   
            
if isnull(@copc_list, '') <> 'ALL' begin  
INSERT #tbl_profit_center_filters  
 SELECT secured_copc.company_id, secured_copc.profit_ctr_id  
  FROM SecuredProfitCenter secured_copc  
  INNER JOIN (  
   SELECT  
    RTRIM(LTRIM(SUBSTRING(row, 1, CHARINDEX('|',row) - 1))) company_id,  
    RTRIM(LTRIM(SUBSTRING(row, CHARINDEX('|',row) + 1, LEN(row) - (CHARINDEX('|',row)-1)))) profit_ctr_id  
   from dbo.fn_SplitXsvText(',', 0, @copc_list)  
   where isnull(row, '') <> '') selected_copc   
   ON secured_copc.company_id = selected_copc.company_id   
   AND secured_copc.profit_ctr_id = selected_copc.profit_ctr_id  
   AND secured_copc.user_code = @user_code  
   AND secured_copc.permission_id = @permission_id      
end else begin  
 INSERT #tbl_profit_center_filters  
 SELECT DISTINCT company_id, profit_ctr_id  
  FROM SecuredProfitCenter secured_copc  
  WHERE   
   secured_copc.user_code = @user_code  
   AND secured_copc.permission_id = @permission_id      
end  
	
	DROP TABLE IF EXISTS #Summary	
		
	
  SELECT 
    r.receipt_date
	,r.trans_mode
	 ,CASE WHEN WasteCode.waste_code_uid = 1510 THEN (select [dbo].[fn_receipt_weight_line] (r.receipt_id,r.line_id,r.profit_ctr_id,r.company_id))  ELSE 0 END AS  'WasteType10'
	 ,CASE WHEN WasteCode.waste_code_uid = 574 THEN (select [dbo].[fn_receipt_weight_line]  (r.receipt_id,r.line_id,r.profit_ctr_id,r.company_id))  ELSE 0 END AS  'WasteType27'
	 ,CASE WHEN WasteCode.waste_code_uid = 7113 THEN (select [dbo].[fn_receipt_weight_line] (r.receipt_id,r.line_id,r.profit_ctr_id,r.company_id))  ELSE 0 END AS  'WasteType27A'
	 ,CASE WHEN WasteCode.waste_code_uid = 575 THEN (select [dbo].[fn_receipt_weight_line]  (r.receipt_id,r.line_id,r.profit_ctr_id,r.company_id))  ELSE 0 END AS  'WasteType72'    
	 , 0 as InboundTotlaTons
	 , 0 as OutboundTotalTons
	INTO #Summary
	FROM Generator g (nolock)    
	  INNER JOIN Receipt r  (nolock)   
	  ON g.generator_id =r.generator_id  
	  LEFT JOIN County  c (nolock)   
	  ON c.county_code = g.generator_county   
	  INNER JOIN ReceiptWasteCode rwc  
	  on r.company_id = rwc.company_id  
	  and r.profit_ctr_id = rwc.profit_ctr_id  
	  and r.receipt_id = rwc.receipt_id  
	  and r.line_id = rwc.line_id  
	  INNER JOIN  WasteCode on WasteCode.waste_code_uid =rwc.waste_code_uid     
	WHERE
	trans_mode ='I'
	AND r.trans_type = 'D'
	AND r.waste_accepted_flag = 'T' 
	AND r.fingerpr_status not in ('V', 'R')
	AND r.receipt_status not in('V', 'R') 
	AND rwc.waste_code_uid in (select waste_code_uid from WasteCode wc where wc.state = 'NJ')
	AND WasteCode.waste_code_uid in(1510,574,7113,575)
	AND r.receipt_date between @i_date_start AND @i_date_end

	Insert Into #Summary
	SELECT   
    r.receipt_date
	,r.trans_mode
	 ,CASE WHEN WasteCode.waste_code_uid = 1510 THEN (select [dbo].[fn_receipt_weight_line] (r.receipt_id,r.line_id,r.profit_ctr_id,r.company_id))  ELSE 0 END AS  'WasteType10'
	 ,CASE WHEN WasteCode.waste_code_uid = 574 THEN (select [dbo].[fn_receipt_weight_line]  (r.receipt_id,r.line_id,r.profit_ctr_id,r.company_id))  ELSE 0 END AS  'WasteType27'
	 ,CASE WHEN WasteCode.waste_code_uid = 7113 THEN (select [dbo].[fn_receipt_weight_line] (r.receipt_id,r.line_id,r.profit_ctr_id,r.company_id))  ELSE 0 END AS  'WasteType27A'
	 ,CASE WHEN WasteCode.waste_code_uid = 575 THEN (select [dbo].[fn_receipt_weight_line]  (r.receipt_id,r.line_id,r.profit_ctr_id,r.company_id))  ELSE 0 END AS  'WasteType72'    
	 , 0 as InboundTotlaTons
	 , 0 as OutboundTotalTons 
 FROM TSDF t (nolock)    
  INNER JOIN Receipt r  (nolock)   
  ON t.TSDF_code =r.TSDF_code  
  INNER JOIN ReceiptWasteCode rwc  
  on r.company_id = rwc.company_id  
  and r.profit_ctr_id = rwc.profit_ctr_id  
  and r.receipt_id = rwc.receipt_id  
  and r.line_id = rwc.line_id  
  INNER JOIN  WasteCode on WasteCode.waste_code_uid =rwc.waste_code_uid     
 WHERE    
 r.trans_mode ='O'   
 AND r.trans_type = 'D'  
 AND r.fingerpr_status not in ('V', 'R')  
 AND r.receipt_status not in('V', 'R')   
 AND rwc.waste_code_uid in (select waste_code_uid from WasteCode wc where wc.state = 'NJ')  
 AND WasteCode.waste_code_uid in(1510,574,7113,575)  
 AND r.receipt_date between @i_date_start AND @i_date_end  
	

	SELECT 
	  receipt_date
	  ,trans_mode
	, format(sum(WasteType10),'N2') WasteType10
	, format(sum(WasteType27),'N2') WasteType27
	, format(sum(WasteType27A),'N2') WasteType27A
	, format(sum(WasteType72),'N2') WasteType72
    , case when trans_mode ='I' then format(sum(WasteTYpe10+  WasteType27+ WasteType27A+ Wastetype72),'N2') else  null end as TotalInboundSolidWasteReceived
	, case when trans_mode ='O' then format(sum(WasteTYpe10+  WasteType27+ WasteType27A+ Wastetype72),'N2') else  null end as TotalOutboundedSolidWasteReceived
	from #Summary
	group by receipt_date,
	         trans_mode
	


	DROP TABLE IF EXISTS #Summary	
	
END

