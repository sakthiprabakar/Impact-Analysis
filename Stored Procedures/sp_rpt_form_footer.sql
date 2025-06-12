CREATE PROCEDURE sp_rpt_form_footer
	@profiles			varchar(max)
,	@form_id			int
,	@revision_id		int
,	@form_type			varchar(3)
AS
/***************************************************************************************
Loads to:		PLT_AI
PB Object(s):	d_rpt_form_footer_3, d_rpt_form_footer_4

04/25/2017 MPM 	Created

sp_rpt_form_footer '185199, 185200, 185201, 185202', NULL, NULL, NULL
sp_rpt_form_footer '564799, 564800, 564801', NULL, NULL, NULL
sp_rpt_form_footer '564799, 185200', NULL, NULL, NULL
sp_rpt_form_footer '564799', NULL, NULL, NULL
sp_rpt_form_footer '185200', NULL, NULL, NULL
sp_rpt_form_footer NULL, 14887, 1, 'PC'
****************************************************************************************/

DECLARE @same_profit_center		int
,		@company_id				int
,		@profit_ctr_id			int
,		@first_company_id		int
,		@first_profit_ctr_id	int
,		@phone_tmp				varchar(14)
,		@fax_tmp				varchar(14)
,		@phone					varchar(10)
,		@fax					varchar(10)

-- Either @profiles or @form_id and @revision_id and @form_type should have been passed in, but not both
IF @profiles IS NOT NULL AND @profiles <> 'ZZZ'
BEGIN
	-- Stuff the profiles into a temp table
	CREATE TABLE #tmp_profiles (profile_id	int NULL)
	EXEC sp_list 0, @profiles, 'NUMBER', '#tmp_profiles'
	
	DECLARE c_approval CURSOR FOR
	SELECT company_id, profit_ctr_id
	  FROM ProfileQuoteApproval
	  JOIN #tmp_profiles ON #tmp_profiles.profile_id = ProfileQuoteApproval.profile_id
	 WHERE ProfileQuoteApproval.status = 'A'
END
ELSE
IF @form_id IS NOT NULL AND @revision_id IS NOT NULL AND @form_type IS NOT NULL AND @form_id <> -1 AND @revision_id <> -1 AND @form_type <> 'ZZZ'
BEGIN
	IF @form_type = 'PC'
	BEGIN
		DECLARE c_approval CURSOR FOR
		 SELECT ProfileQuoteApproval.company_id, ProfileQuoteApproval.profit_ctr_id
		   FROM FormCC
		   JOIN ProfileQuoteApproval ON FormCC.profile_id = ProfileQuoteApproval.profile_id
		  WHERE FormCC.form_id = @form_id
		    AND FormCC.revision_id = @revision_id 
	        AND ProfileQuoteApproval.status = 'A'
	END
	IF @form_type = 'RA'
	BEGIN
		DECLARE c_approval CURSOR FOR
		 SELECT ProfileQuoteApproval.company_id, ProfileQuoteApproval.profit_ctr_id
		   FROM FormRA
		   JOIN ProfileQuoteApproval ON FormRA.profile_id = ProfileQuoteApproval.profile_id
		  WHERE FormRA.form_id = @form_id
		    AND FormRA.revision_id = @revision_id 
	        AND ProfileQuoteApproval.status = 'A'
	END
	IF @form_type = 'GN'
	BEGIN
		DECLARE c_approval CURSOR FOR
		 SELECT ProfileQuoteApproval.company_id, ProfileQuoteApproval.profit_ctr_id
		   FROM FormGN
		   JOIN ProfileQuoteApproval ON FormGN.profile_id = ProfileQuoteApproval.profile_id
		  WHERE FormGN.form_id = @form_id
		    AND FormGN.revision_id = @revision_id 
	        AND ProfileQuoteApproval.status = 'A'
	END
	IF @form_type = 'GWA'
	BEGIN
		DECLARE c_approval CURSOR FOR
		 SELECT ProfileQuoteApproval.company_id, ProfileQuoteApproval.profit_ctr_id
		   FROM FormGWA
		   JOIN ProfileQuoteApproval ON FormGWA.profile_id = ProfileQuoteApproval.profile_id
		  WHERE FormGWA.form_id = @form_id
		    AND FormGWA.revision_id = @revision_id 
	        AND ProfileQuoteApproval.status = 'A'
	END
END

SET @same_profit_center = 1

OPEN c_approval
FETCH c_approval INTO @first_company_id, @first_profit_ctr_id

SET @company_id = @first_company_id
SET @profit_ctr_id = @first_profit_ctr_id

WHILE @@FETCH_STATUS = 0
BEGIN
	IF NOT (@company_id = @first_company_id AND @profit_ctr_id = @first_profit_ctr_id)
	BEGIN
		SET @same_profit_center = 0
		BREAK
	END
	FETCH c_approval INTO @company_id, @profit_ctr_id
END

CLOSE c_approval
DEALLOCATE c_approval

-- If all of the approvals have the same company/profit center, then check if the profit center flag is set for that profit center to display the profit center's
-- fax and phone number on certain reports' footers.  If so, return the profit center's fax and phone number.
-- If the approvals are a mix of different company/profit centers, then just return the corporate fax and phone number.	 
IF @same_profit_center = 1
BEGIN
	IF 'T' = (SELECT form_footer_pc_contact_num_flag
	            FROM ProfitCenter
	           WHERE company_ID = @company_id
	             AND profit_ctr_ID = @profit_ctr_id)
		SELECT @phone_tmp = phone, @fax_tmp = fax
		  FROM ProfitCenter
		 WHERE company_ID = @company_id
	       AND profit_ctr_ID = @profit_ctr_id
	ELSE
		SELECT @phone_tmp = phone_customer_service, @fax_tmp = fax
		  FROM Company
		 WHERE company_id = 1
END
ELSE
BEGIN
		SELECT @phone_tmp = phone_customer_service, @fax_tmp = fax
		  FROM Company
		 WHERE company_id = 1
END	
	
-- Strip out unnecessary characters from the phone string
set @phone_tmp = replace(@phone_tmp, '(', '')
set @phone_tmp = replace(@phone_tmp, ')', '')
set @phone_tmp = replace(@phone_tmp, '-', '')
set @phone_tmp = replace(@phone_tmp, ' ', '')
if LEFT(@phone_tmp, 1) = '1' 
	set @phone_tmp = substring(@phone_tmp, 2, LEN(@phone_tmp) - 1)
set @phone = @phone_tmp

-- Strip out unnecessary characters from the fax string
set @fax_tmp = replace(@fax_tmp, '(', '')
set @fax_tmp = replace(@fax_tmp, ')', '')
set @fax_tmp = replace(@fax_tmp, '-', '')
set @fax_tmp = replace(@fax_tmp, ' ', '')
if LEFT(@fax_tmp, 1) = '1' 
	set @fax_tmp = substring(@fax_tmp, 2, LEN(@fax_tmp) - 1)
set @fax = @fax_tmp

select @phone as phone, @fax as fax


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_form_footer] TO [EQAI]
    AS [dbo];

