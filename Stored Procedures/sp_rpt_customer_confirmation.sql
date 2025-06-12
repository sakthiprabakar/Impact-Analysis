CREATE PROCEDURE sp_rpt_customer_confirmation
	@profiles		varchar(max)
,	@customer_id	int
,	@debug			TINYINT
,	@record_type	TINYINT
AS
/***************************************************************************************
This sp runs for the Report -> Forms -> Price Confirmation
Loads to:		PLT_AI
PB Object(s):	d_rpt_price_confirmation

11/03/2011 SK	Created
11/08/2011 SK	Added Quote_ID
10/09/2012 SK	Changed to include record_type & exclude company-profitctr
04/04/2017 MPM	Added approvals list to result set for record type 1.
05/12/2017 MPM	Added profile_id to result set for record type 1 (needs to be passed in to footer dw).
06/13/2017 MPM	Modified so that only one row for each customer is returned, so that duplicate letters are not generated.  Updated the profile_id on each customer
				to be any profile_id passed in that will work to set the proper letter footer.

sp_rpt_customer_confirmation '343472',888880, 0, 2
sp_rpt_customer_confirmation '343472,343474,347605,347608,347610,389433,389434,403603', -99, 0, 1
sp_rpt_customer_confirmation '565009, 566498', -99, 0, 1
sp_rpt_customer_confirmation '550938, 550939, 550940', -99, 0, 1
sp_rpt_customer_confirmation '41723, 41949, 44095', -99, 0, 1
sp_rpt_customer_confirmation '20124', -99, 0, 1

****************************************************************************************/
SET NOCOUNT ON

CREATE TABLE #tmp_profiles (profile_id	int NULL)
EXEC sp_list @debug, @profiles, 'NUMBER', '#tmp_profiles'

IF @record_type = 1
BEGIN

	SELECT DISTINCT
		Customer.customer_id
	,	Customer.cust_name
	,	Contact_name = dbo.fn_contact_name(Customer.customer_ID, 'primary')
	,	Customer.cust_addr1
	,	Customer.cust_addr2
	,	Customer.cust_addr3
	,	Customer.cust_addr4
	,	RTrim(CASE WHEN (cust_city + ', ' + cust_state + ' ' + IsNull(cust_zip_code,'')) IS NULL THEN 'Missing City, State, and ZipCode' 
			ELSE (cust_city + ', ' + cust_state + ' ' + IsNull(cust_zip_code,'')) END) AS cust_addr5
	,	Customer.cust_fax
	,	(SELECT STUFF(REPLACE((SELECT DISTINCT '#!' + LTRIM(RTRIM(pqa.approval_code)) AS 'data()' FROM ProfileQuoteApproval pqa JOIN Profile p on p.profile_id = pqa.profile_id WHERE pqa.profile_id IN (Select profile_id FROM #tmp_profiles) AND p.customer_id = Customer.customer_id AND pqa.status = 'A' AND pqa.approval_code IS NOT NULL FOR XML PATH('')),' #!',', '), 1, 2, '')) as approvals_list,
		NULL as profile_id
	INTO #customer
	FROM Profile
	INNER JOIN Customer
		ON Customer.customer_ID = Profile.customer_id
	WHERE Profile.profile_id IN (Select profile_id FROM #tmp_profiles )
		AND Profile.ap_expiration_date >= GETDATE()
	
	-- First, update #customer.profile_id with any profile_id that was passed in. 
	UPDATE #customer
	   SET profile_id = Profile.profile_id
	  FROM Profile
	 WHERE #customer.customer_id = Profile.customer_id
	   AND Profile.profile_id IN (Select profile_id FROM #tmp_profiles )
	   AND Profile.ap_expiration_date >= GETDATE()

	-- Then, update #customer.profile_id with any profile_id that was passed in AND that has form_footer_pc_contact_num_flag = 'T' for any associated approval's facility.	
	UPDATE #customer
	   SET profile_id = Profile.profile_id
	  FROM Profile
	 WHERE #customer.customer_id = Profile.customer_id
	   AND Profile.profile_id IN (Select profile_id FROM #tmp_profiles )
	   AND Profile.ap_expiration_date >= GETDATE()
	   AND EXISTS(SELECT 1
	                FROM ProfileQuoteApproval pqa
	                JOIN ProfitCenter pc 
					  ON pc.company_ID = pqa.company_id
	                 AND pc.profit_ctr_ID = pqa.profit_ctr_id
	                 AND pqa.profile_id = Profile.profile_id
	                 AND pc.form_footer_pc_contact_num_flag = 'T')
		
	SELECT * FROM #customer
END
ELSE
BEGIN
	SELECT DISTINCT
		Profile.profile_id	
	,	Customer.customer_id
	,	Customer.cust_name
	,	Generator.generator_id
	,	Generator.generator_name
	,	Generator.EPA_ID
	,	WasteCode.waste_code_desc
	,	Profile.approval_desc
	FROM Profile
	INNER JOIN Customer
		ON Customer.customer_ID = Profile.customer_id
		AND Customer.customer_id = @customer_id
	INNER JOIN WasteCode
		ON WasteCode.waste_code_uid = Profile.waste_code_uid	
	INNER JOIN Generator
		ON Generator.generator_id = Profile.generator_id
	WHERE Profile.profile_id IN (Select profile_id FROM #tmp_profiles )
		AND Profile.ap_expiration_date >= GETDATE()
END

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_customer_confirmation] TO [EQAI]
    AS [dbo];

