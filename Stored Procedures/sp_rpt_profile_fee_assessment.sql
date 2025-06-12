/****** Object: Procedure [dbo].[sp_rpt_profile_fee_assessment]   Script Date: 8/27/2024 9:36:54 AM ******/
USE [PLT_AI];
GO
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
CREATE   PROCEDURE [dbo].[sp_rpt_profile_fee_assessment]
  @customer_id_from	int
,	@customer_id_to		int
, @start_date datetime  
, @end_date datetime  
, @company_chain  varchar(20)
, @print_criteria char(1)

  
AS  
/***********************************************************************************
PB Object : r_profile_fee_assessment

sp_rpt_profile_fee_assessment
Loads to : PLT_AI  
Modifications:  
06/27/2024 rbbautista DevOps 88343 - Created  
08/12/2024 rbbautista DevOps 94422 - Added Company Chain, Product Code, Product Description and Print Criteria option
08/22/2024 - DevOps:94929 - Retrieve the data between profile craeted date or renewed date 

EXEC dbo.sp_rpt_profile_fee_assessment 1, 999999, '06/01/2024', '7/30/2024', 'ALL', 'Y'
***********************************************************************************/  
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED  

 
SELECT DISTINCT
  Profile.profile_id
, receipt.company_id
, receipt.profit_ctr_id
, receipt.customer_id
, Customer.cust_name
, Generator.generator_id
, Generator.generator_name
, Profile.approval_desc
, Profile.curr_status_code
, ProfileFeeDetail.apply_flag
, ProfileFeeExemptionReason.exemption_reason
, Users.user_name
, ProfileFeeDetail.date_exempted
, Customer.Customer_Type
, receipt.product_code
, ProfileFeeCode.profile_fee_code_desc
, receipt.receipt_id
FROM receiptprofilefee --ProfileFeeDetail 
JOIN Receipt ON receiptprofilefee.receipt_id = receipt.receipt_id
     AND Receipt.company_id = receiptprofilefee.company_id
     AND Receipt.profit_ctr_id = receiptprofilefee.profit_ctr_id 
JOIN ProfileFeeDetail ON ProfileFeeDetail.Profile_ID = receiptprofilefee.Profile_ID
JOIN Profile
	ON Profile.profile_id = receiptprofilefee.profile_id 
	AND Profile.ap_expiration_date > GetDate()
	AND Profile.customer_id BETWEEN @customer_id_from AND @customer_id_to
	AND ( Profile.Date_Added BETWEEN @start_date AND @end_date OR Profile.renewal_date BETWEEN @start_date AND @end_date )
JOIN Customer ON Profile.Customer_ID = dbo.Customer.customer_ID
 AND (Customer.Customer_type = @company_chain OR @company_chain = 'ALL')
JOIN Generator ON Profile.generator_id = dbo.Generator.generator_id
LEFT OUTER JOIN dbo.Users ON Users.user_code = ProfileFeeDetail.exemption_approved_by
LEFT OUTER JOIN ProfileFeeExemptionReason 
 ON dbo.ProfileFeeExemptionReason.exemption_reason_uid = dbo.ProfileFeeDetail.exemption_reason_uid
LEFT OUTER JOIN ProfileFeeCode ON ProfileFeeCode.profile_fee_code = receipt.product_code 
ORDER BY Profile.profile_id

GO


GRANT EXECUTE
    ON [sp_rpt_profile_fee_assessment] TO [EQWEB]
GO
GRANT EXECUTE
    ON [sp_rpt_profile_fee_assessment] TO [COR_USER]
GO
GRANT EXECUTE
    ON [sp_rpt_profile_fee_assessment] TO [EQAI]

