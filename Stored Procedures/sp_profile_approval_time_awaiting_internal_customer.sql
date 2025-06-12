
create proc sp_profile_approval_time_awaiting_internal_customer (
	@customer_id	int,
	@start_date		datetime,
	@end_date		datetime,
	@user_code		varchar(20), -- EQIP user code (currently running as)
	@permission_id	int			 -- EQIP Permission ID
) as
/* ****************************************************************************
sp_profile_approval_time_awaiting_internal_customer

	One-off copy of Profile Approval Time as of 4/30/2013
	This version separates the Awaiting Internal Customer status into a distinct column for output

	Since all Nisource wanted was the per-profile version, we extracted JUST that query
	and let them choose a customer_id & date range.
	
History:
	4/30/2013	JPB	Created
	
Sample:
	sp_profile_approval_time_awaiting_internal_customer 10908, '1/1/2012', '12/31/2013', 'jonathan', 273

	
**************************************************************************** */

create table #customer (customer_id int)

insert #customer select customer_id 
from SecuredCustomer sc  (nolock) 
WHERE sc.user_code = @user_code
	and sc.permission_id = @permission_id		
	and sc.customer_id = @customer_id

set @end_date = @end_date + 0.99999

SELECT
  p.customer_id AS customer_id,
  c.cust_name AS cust_name,
  p.generator_id AS generator_id,
  g.generator_name AS generator_name,
  g.epa_id AS epa_id,
  dbo.fn_approval_code_list(p.profile_id) AS approval_code,
  p.approval_desc AS approval_desc,

		SUM(CASE WHEN pl.code <> 'AIC'
				 THEN CASE WHEN pl.bypass_tracking_flag = 'F'
						   THEN CASE WHEN pt.business_minutes IS NOT NULL
									 THEN pt.business_minutes
									 ELSE dbo.fn_business_minutes(pt.time_in,
															  ISNULL(pt.time_out,
															  GETDATE()))
								END
						   ELSE 0
					  END
				 ELSE 0
			END) AS eq_minutes ,
		SUM(CASE WHEN pl.code = 'AIC'
				 THEN CASE WHEN pl.bypass_tracking_flag = 'F'
						   THEN CASE WHEN pt.business_minutes IS NOT NULL
									 THEN pt.business_minutes
									 ELSE dbo.fn_business_minutes(pt.time_in,
															  ISNULL(pt.time_out,
															  GETDATE()))
								END
						   ELSE 0
					  END
				 ELSE 0
			END) AS awaiting_internal_customer_minutes ,
		SUM(CASE WHEN pl.code <> 'AIC'
				 THEN CASE WHEN pl.bypass_tracking_flag = 'T'
						   THEN CASE WHEN pt.business_minutes IS NOT NULL
									 THEN pt.business_minutes
									 ELSE dbo.fn_business_minutes(pt.time_in,
															  ISNULL(pt.time_out,
															  GETDATE()))
								END
						   ELSE 0
					  END
				 ELSE 0
			END) AS cust_minutes ,

/* Rule:8 */
  SUM(CASE WHEN pt.business_minutes IS NOT NULL THEN pt.business_minutes 
	        ELSE dbo.fn_business_minutes(pt.time_in, IsNull(pt.time_out, GetDate())) 
        END) AS bus_minutes, 

/* Rule 9 */
  IsNull(dbo.fn_profile_total_days(p.profile_id, GetDate()), 0) AS total_days, 

/* Rule:10 */
  IsNull(dbo.fn_profile_business_days(p.profile_id, GetDate()), 0) AS business_days,                                                          

p.profile_id AS profile_id	
, p.date_added as profile_date_added    			

FROM 				
profile p  
INNER JOIN profiletracking pt on p.profile_id = pt.profile_id
LEFT OUTER JOIN profilelookup pl on pt.tracking_status = pl.code AND pl.type = 'TrackingStatus'  			
LEFT OUTER JOIN customer c on p.customer_id = c.customer_id 		
LEFT OUTER JOIN generator g on p.generator_id = g.generator_id 			
LEFT OUTER JOIN department d on pt.department_id = d.department_id	
LEFT OUTER JOIN users u on pt.eq_contact = u.user_code       

WHERE        
/* Rule:1 */ IsNull(pt.manual_bypass_tracking_flag, 'F') = 'F'  
    /* Rule:2 */ AND pt.tracking_id <= (IsNull((SELECT Min(tracking_id) FROM profiletracking WHERE profile_id = pt.profile_id AND tracking_status = 'COMP'), pt.tracking_id))   
    /* Rule:3 */ AND pt.tracking_status <> 'COMP' 	   
AND pt.profile_id IN 
(/* BEG Subquery*/
SELECT      
  DISTINCT(p.profile_id)			
FROM 				
  profile p
  INNER JOIN profiletracking pt on p.profile_id = pt.profile_id
  LEFT OUTER JOIN profilelookup pl on pt.tracking_status = pl.code AND pl.type = 'TrackingStatus'      
  INNER JOIN ProfileQuoteApproval pqa ON p.profile_id = pqa.profile_id AND pqa.status = 'A' 
  INNER JOIN ProfitCenter pc ON pqa.company_id = pc.company_id AND pqa.profit_ctr_id = pc.profit_ctr_id AND pc.status = 'A' AND pc.waste_receipt_flag = 'T'      
WHERE 
/* Rule:1 */ IsNull(pt.manual_bypass_tracking_flag, 'F') = 'F'  
    /* Rule:2 */ AND pt.tracking_id <= (IsNull((SELECT Min(tracking_id) FROM profiletracking WHERE profile_id = pt.profile_id AND tracking_status = 'COMP'), pt.tracking_id))   
    /* Rule:3 */ AND pt.tracking_status <> 'COMP' 	   
    /* Rule:4 */ AND EXISTS (SELECT profile_id FROM profiletracking WHERE profile_id = p.profile_id AND tracking_status = 'NEW')  
    /* Rule:5 */ AND p.curr_status_code not IN ('C', 'V', 'R') 	   
  /* Rule:6 */ AND p.date_added >= '7/24/2006'   
    /* Rule:7 */ AND EXISTS (SELECT profile_id FROM profiletracking WHERE profile_id = p.profile_id AND tracking_status = 'COMP')   
  AND 
    /* Rule:7.1 */ (SELECT IsNull(time_out,'1/1/1900') FROM profiletracking WHERE profile_id = pt.profile_id AND tracking_id = (IsNull((SELECT Min(tracking_id) FROM profiletracking WHERE profile_id = pt.profile_id AND tracking_status = 'COMP'),-1)))  >= @start_date
  AND 
    /* Rule:7.1 */ (SELECT IsNull(time_out,'1/1/1900') FROM profiletracking WHERE profile_id = pt.profile_id AND tracking_id = (IsNull((SELECT Min(tracking_id) FROM profiletracking WHERE profile_id = pt.profile_id AND tracking_status = 'COMP'),-1)))  <= @end_date
  AND p.customer_id IN (SELECT customer_id FROM #customer) 
)/* END Subquery*/


GROUP BY  
p.customer_id,
c.cust_name,
p.generator_id,
g.generator_name,
g.epa_id,
dbo.fn_approval_code_list(p.profile_id),
p.approval_desc,
p.profile_id
,p.date_added

ORDER BY   
p.profile_id 



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_profile_approval_time_awaiting_internal_customer] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_profile_approval_time_awaiting_internal_customer] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_profile_approval_time_awaiting_internal_customer] TO [EQAI]
    AS [dbo];

