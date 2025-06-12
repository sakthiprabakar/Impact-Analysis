CREATE  PROCEDURE sp_profile_approval_validate
	@debug			int
,	@company_id		int
,	@profit_ctr_id	int
,	@approval	varchar(15)
AS
/***************************************************************************************
sp_profile_approval_validate 1, 21, 0, 'J065271DET', 'DEV'
sp_profile_approval_validate 1, 21, 0, 'HF053252', 'DEV'

Load to company databases.  Used by Receipt Transfers and Transfer Containers Inventory Report

11/08/2006 SCC  Created
01/31/2008 rg   removed db_type from the procedure prod dev test are seperate servers not db
09/30/2010 SK	moved to Plt_AI
11/20/2018 MPM	GEM 6935 - Appended approval expiration date to the returned validation string, 
				if the approval is valid.
				
****************************************************************************************/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED


DECLARE 
	@expire_date			datetime,
	@confirm_flag			char(1),
	@confirm_update_date	datetime,
	@status					char(1),
	@terms_code				varchar(8),
	@count_approval			int,
	@validation_msg			varchar(255)	

CREATE TABLE #tmp_approval (
	expire_date			datetime	NULL
,	confirm_update_date	datetime	NULL
,	status				char(1)		NULL
,	terms_code			varchar(8)	NULL
,	confirm_flag		char(1)		NULL
)

-- Validate this approval
INSERT #tmp_approval
SELECT
	Profile.ap_expiration_date
,	ProfileQuoteApproval.confirm_update_date
,	ProfileQuoteApproval.status
,	Customer.terms_code
,	ProfitCenter.confirm_flag
FROM Profile
JOIN ProfileQuoteApproval
	ON ProfileQuoteApproval.profile_id = Profile.profile_id
	AND ProfileQuoteApproval.approval_code = @approval
	AND ProfileQuoteApproval.company_id = @company_id
	AND ProfileQuoteApproval.profit_ctr_id = @profit_ctr_id
JOIN Customer
	ON Customer.customer_ID = Profile.customer_id
JOIN ProfitCenter
	ON ProfitCenter.company_ID = ProfileQuoteApproval.company_id
	AND ProfitCenter.profit_ctr_ID = ProfileQuoteApproval.profit_ctr_id
WHERE Profile.curr_status_code = 'A'	

IF @debug = 1 print 'selecting from #tmp_approval'
IF @debug = 1 select * from #tmp_approval

SELECT @count_approval = Count(*) FROM #tmp_approval
IF @count_approval = 0
	SET @validation_msg = 'Approval ' + @approval + ' does not exist or Profile is not approved.'
ELSE
BEGIN
	SELECT 	@expire_date = expire_date,
		@confirm_flag = confirm_flag,
		@confirm_update_date = confirm_update_date,
		@status = status,
		@terms_code = terms_code
	FROM #tmp_approval
	
	SET @validation_msg = ''

	-- Approval expired?
	if @expire_date < getdate()
		if @validation_msg = '' 
			SET @validation_msg = 'Expired Approval'
		else
			SET @validation_msg = @validation_msg + ', Expired Approval'
	
	-- Does this profit center requires approval confirmation?
	IF @confirm_flag = 'T' 
		-- Check for confirmed approval
		if @confirm_update_date IS NULL 
			if @validation_msg = '' 
				SET @validation_msg = 'Approval Not Confirmed'
			else
				SET @validation_msg = @validation_msg + ', Approval Not Confirmed'
	
	-- Check for NOADMIT
	if @terms_code = 'NOADMIT' 
		if @validation_msg = '' 
			SET @validation_msg = 'NOADMIT Customer'
		else
			SET @validation_msg = @validation_msg + ', NOADMIT Customer'
	ELSE IF @terms_code = 'COD' 
		if @validation_msg = '' 
			SET @validation_msg = 'C.O.D. Customer'
		else
			SET @validation_msg = @validation_msg + ', C.O.D. Customer'

	-- Check approval status
	IF @status <> 'A' 
		if @validation_msg = '' 
			SET @validation_msg = 'Approval Not Active'
		else
			SET @validation_msg = @validation_msg + ', Approval Not Active'
	
	-- Check message status
	IF @validation_msg = '' 
		-- No errors, this approval is good
		SET @validation_msg = 'Approval ' + @approval + ' is valid.  Expiration date:  ' + CONVERT(varchar,@expire_date, 1)
	ELSE
		SET @validation_msg = 'Approval ' + @approval + ' is not valid: ' + @validation_msg + '.'
END

SELECT @validation_msg
GO

GRANT EXECUTE
    ON OBJECT::[dbo].[sp_profile_approval_validate] TO [EQAI]
    AS [dbo];
GO

