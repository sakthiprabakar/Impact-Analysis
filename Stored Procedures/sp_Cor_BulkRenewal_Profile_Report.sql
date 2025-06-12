
ALTER  PROCEDURE [dbo].[sp_Cor_BulkRenewal_Profile_Report]
(
    @profile_id nvarchar(max)
	
	
	
)   
as

/* ******************************************************************

	Updated By		: Prabhu
	Updated On		: 06th December 2021
	Type			: Stored Procedure
	Object Name		: [sp_Cor_BulkRenewal_Profile_Report]


	Procedure to Bulk Renewal Documents

inputs 
	
	@profile_id
	


Samples:
 EXEC [sp_Cor_BulkRenewal_Profile_Report] @profile_id
 EXEC [sp_Cor_BulkRenewal_Profile_Report] '699456,699517'
****************************************************************** */
BEGIN
	declare @profile_id_list table (
		profile_id nvarchar(30)
	)

		
insert @profile_id_list
select row
from dbo.fn_SplitXsvText(',', 1, replace(@profile_id, ' ', ','))
 Create  table #temptable
  (
  profile_id nvarchar(30),
  )

;WITH Splitted
AS (
SELECT CAST('<x>' + REPLACE(profile_id, '-', '</x><x>') + '</x>' AS XML) AS Parts
FROM @profile_id_list
)
insert into #temptable(profile_id)
SELECT Parts.value(N'/x[1]', 'varchar(50)') AS profile_id


FROM Splitted;



  SELECT	   
     	      Profile.profile_id
            , Profile.customer_id
			, Profile.waste_code
            , cus.cust_name
            , cus.cust_addr1
            , cus.cust_city
            , cus.cust_state
            , cus.cust_zip_code
            , contact.name
            , g.generator_name
			, g.EPA_ID
			, Profile.approval_desc
			, PQA.approval_code
			, PQA.company_id
			, PQA.profit_ctr_id
			, PQA.quote_id
			, Profile.ap_expiration_date
			, ProfitCenter.profit_ctr_name
			, ProfitCenter.EPA_ID AS profit_ctr_epa_ID
			, Profile.OTS_flag
			, [wcr_sign_name]  signing_name
            , [wcr_sign_company]  signing_company
	        , [wcr_sign_date]    signing_date
			  
			  from #temptable tt join
 Profile on Profile.profile_id = tt.profile_id

LEFT JOIN generator AS g 
         ON Profile.generator_id = g.generator_id 
       LEFT JOIN contact AS contact 
              ON Profile.contact_id = contact.contact_id 
       JOIN customer AS cus 
         ON Profile.customer_id = cus.customer_id
		 INNER JOIN ProfileQuoteApproval PQA
		ON PQA.profile_id = Profile.profile_id
		AND PQA.status = 'A'
		INNER JOIN ProfitCenter
		ON ProfitCenter.company_ID = PQA.company_id
		AND ProfitCenter.profit_ctr_ID = PQA.profit_ctr_id
		--WHERE Profile.profile_id = @profile_id


END		


	GO

	GRANT EXECUTE ON [dbo].[sp_Cor_BulkRenewal_Profile_Report] TO COR_USER;

    GO



	