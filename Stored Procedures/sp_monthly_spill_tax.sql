USE [PLT_AI]
GO
/****** Object:  StoredProcedure [dbo].[sp_monthly_spill_tax]    Script Date: 09-11-2023 09:12:35 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[sp_monthly_spill_tax]
(
@date_start  datetime = null, 
@date_end   datetime = null,
@copc_list     varchar(max) = NULL, -- ex: 21|1,14|0,14|1),
@user_code     varchar(100) = NULL, -- for associates,
@permission_id int
)
AS

/* **********************************************************************************  

 Author  : Prabhu  
 Updated On : 01-Nov-2023  
 Type  : Store Procedure   
 Object Name : [dbo].[sp_monthly_spill_tax] 

 Ticket      :Task 71695
 Description : Monthly Spill Tax Report 
  
   sp_monthly_spill_tax  
   @date_start = '10/1/2021'  
 , @date_end = '10/31/2023' 
 , @copc_list  = null
 , @user_code  ='jonathan'
 , @permission_id  =null
  
   
********************************************************************************** */  
 
BEGIN

declare @start_date DATETIME = DATEADD(MONTH, DATEDIFF(MONTH, 0, GETDATE()), 0);
declare 
 @i_date_start   datetime = isnull(@date_start, (@start_date))
,@i_date_end   datetime = isnull(@date_end, (DATEADD(DAY, -1, DATEADD(MONTH, 1, @start_date))))

if DATEPART(hh, @i_date_end) = 0  set @i_date_end = @i_date_end +0.99999
 ---  set @i_date_end = DATEADD(s, (((23 * 60 * 60) + (59 * 60)) + 59), @i_date_end) 

declare @tbl_profit_center_filter table (  
    [company_id] int,  
    profit_ctr_id int  
)  
            
if isnull(@copc_list, '') <> 'ALL' begin  
INSERT @tbl_profit_center_filter  
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
 INSERT @tbl_profit_center_filter  
 SELECT DISTINCT company_id, profit_ctr_id  
  FROM SecuredProfitCenter secured_copc  
  WHERE   
   secured_copc.user_code = @user_code  
   AND secured_copc.permission_id = @permission_id      
end  



  SELECT 
  Receipt.manifest_quantity,
  Receipt.manifest_unit,
  Receipt.receipt_date,
  Receipt.manifest,
  Receipt.line_id,
  Receipt.receipt_ID,
  Receipt.company_id,
  Receipt.profit_ctr_id,
  wastecode.waste_code_uid,
  WasteCode.haz_flag,

  CASE WHEN WasteCode.haz_flag = 'T'  THEN 'Hazardous ' 
  WHEN WasteCode.waste_code_uid = 7123  THEN  'Petroleum'
  ELSE NULL END AS waste_type
  FROM Receipt (nolock)    

INNER JOIN Receiptwastecode rwc  (nolock)  
	ON Receipt.receipt_id = rwc.receipt_id
	AND Receipt.company_id = rwc.company_id
	AND Receipt.profit_ctr_id = rwc.profit_ctr_id 
	AND receipt.line_id = rwc.line_id

INNER JOIN  WasteCode on WasteCode.waste_code_uid =rwc.waste_code_uid
WHERE  
Receipt.trans_mode ='I' 
AND Receipt.trans_type = 'D'
AND Receipt.waste_accepted_flag = 'T' 
AND Receipt.receipt_status not in('R', 'V') 
AND Receipt.fingerpr_status not in ('R', 'V')
AND (wastecode.haz_flag = 'T' or rwc.waste_code_uid = 7123  ) 
AND Receipt.receipt_date between @i_date_start AND @i_date_end
AND 
	(@copc_list = '' OR
	EXISTS(SELECT * FROM @tbl_profit_center_filter tb where tb.company_id = Receipt.company_id AND tb.profit_ctr_id = Receipt.profit_ctr_id)
	)

END

GO
GRANT EXECUTE on [dbo].[sp_monthly_spill_tax] to COR_USER
GO
GRANT EXECUTE on [dbo].[sp_monthly_spill_tax] to EQWEB
GO
GRANT EXECUTE on [dbo].[sp_monthly_spill_tax]  to EQAI