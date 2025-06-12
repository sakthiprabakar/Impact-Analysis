
CREATE PROCEDURE [dbo].[sp_pi2010_rpt_approval_confirm_additional_notes]
	@company_id int,
	@customer_id	int
AS
/***************************************************************************************
Returns additional notes for Customer Quote Confirmations; this information used to be
hard-coded into the d_rpt_confirm_approval DW.

Filename:		L:\Apps\SQL\EQAI\Plt_XX_AI\Procedures\sp_rpt_approval_confirm_additional_notes.sql
Loads to:		Plt_XX_AI
PB Object(s):	d_rpt_approval_confirm_additional_notes

08/27/2010 RWB	Created as copy of Plt_XX_ai.sp_rpt_approval_confirm_additional_notes,
		for price increase 2010 letters

sp_rpt_approval_confirm_additional_notes 14, 0, 6243
****************************************************************************************/
DECLARE	@note							varchar(2000),
		@sequence_id					tinyint,
		@ensr_applied					tinyint,
		@insurance_surcharge_percent	money

SELECT PriceIncrease2010_Approval.approval_code,
	PriceIncrease2010_Approval.profile_id,
	Company.insurance_surcharge_percent,
	CustomerBilling.ensr_flag,
	ProfileQuoteApproval.ensr_exempt,
	0 AS ensr_applied
INTO #tmp
FROM PriceIncrease2010_Approval
INNER JOIN Company ON PriceIncrease2010_Approval.company_id = Company.company_id
INNER JOIN ProfileQuoteApproval on PriceIncrease2010_Approval.company_id = ProfileQuoteApproval.company_id
	AND PriceIncrease2010_Approval.profit_ctr_id = ProfileQuoteApproval.profit_ctr_id
	AND PriceIncrease2010_Approval.profile_id = ProfileQuoteApproval.profile_id
	AND PriceIncrease2010_Approval.approval_code = ProfileQuoteApproval.approval_code
LEFT OUTER JOIN CustomerBilling ON PriceIncrease2010_Approval.customer_id = CustomerBilling.customer_id
	AND ISNULL(ProfileQuoteApproval.billing_project_id, 0) = CustomerBilling.billing_project_id
WHERE PriceIncrease2010_Approval.company_id = @company_id
AND PriceIncrease2010_Approval.customer_id = @customer_id

UPDATE #tmp SET ensr_applied = 1 WHERE ensr_flag = 'T'
UPDATE #tmp SET ensr_applied = 1 WHERE ensr_flag = 'P' AND ensr_exempt = 'F'

SELECT @insurance_surcharge_percent = MAX(insurance_surcharge_percent) FROM #tmp
SELECT @ensr_applied = MAX(ensr_applied) FROM #tmp


----------------------------------------
-- Create table to store notes
----------------------------------------
CREATE TABLE #tmp_notes (
	sequence_id		tinyint,
	note			text	)

----------------------------------------
-- Note 1
----------------------------------------
SET @sequence_id = 1
SET @note = 'Quoted bulk disposal charges for solid materials will be billed by the cubic yard if waste density is less than 2,000 pounds per cubic yard.  If the waste density is greater than 2,000 pounds per cubic yard then bulk disposal charges will be billed by the ton regardless of the approved container.  EQ personnel will monitor all shipments.'
INSERT INTO #tmp_notes VALUES (@sequence_id, @note)

----------------------------------------
-- Note 2 (insurance surcharge)
----------------------------------------
IF @insurance_surcharge_percent > 0.00
BEGIN
	SET @sequence_id = 2
	SET @note = 'An insurance surcharge of ' + CONVERT(varchar(10), @insurance_surcharge_percent) + '% will apply to all transportation, disposal and services provided.'
	INSERT INTO #tmp_notes VALUES (@sequence_id, @note)
END

----------------------------------------
-- Note 3 (energy surcharge)
----------------------------------------
IF @ensr_applied = 1
BEGIN
	SET @sequence_id = 3
	SET @note = 'An Energy Surcharge will be applied to all waste streams received at EQ''s fixed based TSDF operations.  The energy surcharge will be adjusted quarterly, based upon the U.S. Department of Labor Consumer Price Index (CPI) - Energy.  The appropriate energy surcharge will be applied to the waste treatment/disposal fee(s) based on the date of waste receipt.  For more information on the current energy surcharge, please contact customer service at 1-800-592-5489.'
	INSERT INTO #tmp_notes VALUES (@sequence_id, @note)
END

----------------------------------------
-- Note 4
----------------------------------------
SET @sequence_id = 4
SET @note = 'The Michigan DEQ will assess a manifest fee for all hazardous waste manifests used in the State of Michigan.'
INSERT INTO #tmp_notes VALUES (@sequence_id, @note)

----------------------------------------
-- Note 5
----------------------------------------
SET @sequence_id = 5
SET @note = 'Additional fees may apply at time of delivery for assistance in off-loading or due to non-conforming wastes.'
INSERT INTO #tmp_notes VALUES (@sequence_id, @note)

SELECT * FROM #tmp_notes ORDER BY sequence_id

