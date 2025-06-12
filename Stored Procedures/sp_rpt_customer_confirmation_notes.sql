USE [PLT_AI]
GO

DROP PROCEDURE IF EXISTS [dbo].[sp_rpt_customer_confirmation_notes]
GO

SET ANSI_NULLS OFF
GO

SET QUOTED_IDENTIFIER OFF
GO

CREATE PROCEDURE [dbo].[sp_rpt_customer_confirmation_notes]
	@profile_id		varchar(255)
AS
/***************************************************************************************
Returns notes for Customer Quote Confirmation Report->Forms-> Customer Confirmation
Loads to:		Plt_AI
PB Object(s):	d_rpt_customer_confirmation_notes

11/08/2011 SK	Created
07/25/2012 SK This should take several profiles as input, fixed
08/07/2012 SK Fixed the conditional notes 6 & 7
10/09/2012 SK TruckLoad should be all one word
08/04/2015 AM Modified insurance surcharge text and commented energy surcharge text. 
			   We missed correcting text under EIR project.
06/23/2017 MPM	Added a note for additional fuel surcharge.
09/07/2017 MPM	Added an additional note.
05/24/2018 MPM	Added note 10 to be displayed after emanifest_validation_date.
06/27/2018 MPM	Edited note 10 and removed note 7 after emanifest_validation_date.
04/08/2019 MPM	GEM 59726 - Price Confirmation Updates
12/06/2019 MPM	Samanage 10833/DevOps 12935 - Added note 12.
07/08/2020 MPM	DevOps 16662 - Modified when EIR note is displayed.
10/03/2020 GDE  Modified -- Note 9; DevOps 17343 - Update to Price Confirmation Language 
12/02/2022 Prabhu - DevOps:57361 - modified profiles to profile_id
12/05/2022 AM -  DevOps:57361 - Added ERF and FRF changes
12/07/2022 AM - DevOps:49459 - Modified Note 11 text.
06/05/2023 AM - DevOps:65105 - Added new Note 4 and re-arranged Note sequence_id's.
12/18/2023 AGC  DevOps 75147/75149 - added EEC fee
02/08/2024  AM  DevOps:77798 - Price Confirmation PDF > EEC Fee Verbiage When EEC = Exempt 
06/17/2024  AM  DevOps:88748 - Price Confirmation - Added Profile Fee Text
07/02/2024  AM  DevOps:91794 - Price Confirmation - Do not Display Profile Fee text for LabPack Profiles
30/12/2024 Prabhu - US116932 - EQAI Price Confirmation Form Updates
10/01/2025 Prabhu - US138059 - Price Confirmation Form > Logic to Generate "EEC Fee Terms & Conditions" Text

sp_rpt_customer_confirmation_notes 394385
sp_rpt_customer_confirmation_notes 479911
sp_rpt_customer_confirmation_notes 783501
sp_rpt_customer_confirmation_notes 1057567
****************************************************************************************/
DECLARE	
	@note							varchar(2000)
,	@sequence_id					tinyint
,	@insurance_surcharge_percent	money
,	@ensr_applied						tinyint
,	@debug							TINYINT
,	@apply_michigan_deq				TINYINT
,	@apply_quoted_bulk_charge		Tinyint
,	@emanifest_validation_date		datetime 
,	@customer_id					int
,	@erf_flag						varchar(1)
,	@frf_flag						varchar(1)
,	@eir_flag						varchar(1)
,	@billing_project_id				int	
,	@recovery_fee_billing_project_id int
,	@apply_flag						varchar(1)
,	@labpack_flag					varchar(1)
,	@eecfee_sequence_id			    int
,   @term_condition_desc            varchar(1000)

select @emanifest_validation_date = cast(config_value as datetime) 
from Configuration 
where config_key = 'emanifest_validation_date'

----------------------------------------
-- Create table to store profiles
----------------------------------------
CREATE TABLE #tmp_profiles (profile_id	int NULL)
		
----------------------------------------
-- Create table to store notes
----------------------------------------
CREATE TABLE #tmp_notes (
	sequence_id		tinyint,
	note			varchar(max)	
)

-----------------------------------------------------
---- Create table to store facility specific values
-----------------------------------------------------
--CREATE TABLE #tmp_facility_terms (
--	insurance_surcharge_percent		money
--,	apply_ensr						tinyint
--,	apply_fac_terms					tinyint	
--)

EXEC sp_list @debug, @profile_id, 'NUMBER', '#tmp_profiles'

SELECT 
	CASE CB.insurance_surcharge_flag 
		WHEN 'T' THEN IsNull(Company.insurance_surcharge_percent, 0.00)
		WHEN 'F' THEN 0.00
		ELSE (CASE PQA.insurance_exempt WHEN 'T' THEN 0.00 ELSE IsNull(Company.insurance_surcharge_percent, 0.00) END)
	END AS insurance_surcharge_percent,
	--CASE CB.ensr_flag 
	--	WHEN 'T' THEN 1 
	--	WHEN 'F' THEN 0 
	--	ELSE (CASE PQA.ensr_exempt WHEN 'F' THEN 0 ELSE 1 END)
	--END AS ensr_applied,
	CASE PQA.ensr_exempt WHEN 'F' THEN 0 ELSE 1 END AS ensr_applied,	
	CASE WHEN PQA.company_ID IN (2, 3, 21) THEN 1 ELSE 0 END AS apply_michigan_deq,
	CASE PC.confirmation_bulk_density_flag WHEN 'T' THEN 1 ELSE 0 END AS apply_quoted_bulk_charge,
	Profile.customer_id,
	ISNULL(PQA.billing_project_id,0) as billing_project_id,
	Profile.labpack_flag
INTO #tmp
FROM Profile
INNER JOIN ProfileQuoteApproval PQA
	ON PQA.profile_id = Profile.profile_id
INNER JOIN ProfitCenter PC
	ON PC.company_ID = PQA.company_id
	AND PC.profit_ctr_ID = PQA.profit_ctr_id	
INNER JOIN Company
	ON Company.company_id = PQA.company_id
INNER JOIN CustomerBilling CB
	ON CB.customer_id = Profile.customer_id
	AND CB.billing_project_id = ISNULL(PQA.billing_project_id, 0)
WHERE Profile.profile_id IN (Select profile_id FROM #tmp_profiles )

SELECT @insurance_surcharge_percent = MAX(insurance_surcharge_percent) FROM #tmp
SELECT @ensr_applied = MAX(ensr_applied) FROM #tmp
SELECT @apply_michigan_deq = MAX(apply_michigan_deq) FROM #tmp
SELECT @apply_quoted_bulk_charge = MAX(apply_quoted_bulk_charge) FROM #tmp
SELECT @customer_id = customer_id  from #tmp 
SELECT @billing_project_id = billing_project_id from #tmp
SELECT @labpack_flag = labpack_flag from #tmp

--PRINT ' @billing_project_id: ' select * from #tmp 
----------------------------------------
-- Note 1 (insurance surcharge)
----------------------------------------
--IF @insurance_surcharge_percent > 0.00
--BEGIN
--	SET @sequence_id = 1
--	--SET @note = 'An insurance surcharge of ' + CONVERT(varchar(10), @insurance_surcharge_percent) + '% will apply to all transportation, disposal and services provided.'
--	SET @note = 'An Energy, Insurance and Recovery Fee will apply to all waste recycling, treatment and disposal fees.'
--	INSERT INTO #tmp_notes VALUES (@sequence_id, @note)
--
----------------------------------------
-- Note 2 (Recovery Fee (ERF) and/or Fuel Recovery Fee (FRF)) 
----------------------------------------
--DevOps:77798 - Added cursor to go through every billing project.

DECLARE c_recovery_fee CURSOR FOR
 SELECT billing_project_id
 FROM #tmp 
FOR READ ONLY

 OPEN c_recovery_fee
 FETCH c_recovery_fee
 INTO @recovery_fee_billing_project_id

  WHILE (@@FETCH_STATUS = 0)

BEGIN 
	SELECT @eir_flag = dbo.fn_get_recovery_fee_flag('EIR', @customer_id, @recovery_fee_billing_project_id, GETDATE())
	SELECT @frf_flag = dbo.fn_get_recovery_fee_flag('FRF', @customer_id, @recovery_fee_billing_project_id, GETDATE())

	IF @frf_flag = 'T' AND ( @eir_flag = 'U' OR @eir_flag = 'F' ) -- @erf_flag <> 'U' OR @frf_flag <> 'U' 
		 BEGIN
		 	SET @sequence_id = 2
			--SET @note = 'An Environmental Recovery Fee (ERF) and/or Fuel Recovery Fee (FRF) will apply to the total invoice. These fees will appear on your invoices as a combined line item assessed on all charges. For more information, please visit: https://www.republicservices.com/customer-support/fee-disclosures' 
			SET @note = 'An EEC fee will apply to the total invoice. This fee will appear on your invoices as a combined line item assessed on all charges. For more information, please visit: https://www.republicservices.com/customer-support/fee-disclosures'
			INSERT INTO #tmp_notes VALUES (@sequence_id, @note)
			BREAK
		 END 		 
	------------------------------------------
	-- Note 2 (energy surcharge)
	----------------------------------------
	IF  ( @eir_flag = 'T' OR @eir_flag = 'P' ) AND ( @frf_flag = 'F' OR @frf_flag = 'U') --@ensr_applied = 0
	BEGIN
		SET @sequence_id = 2
		SET @note = 'An Energy, Insurance and Recovery Fee will apply to all waste recycling, treatment and disposal fees.'
		INSERT INTO #tmp_notes VALUES (@sequence_id, @note)
		--SET @note = 'An energy surcharge will be applied to all waste streams received at EQ''s fixed based TSDF operations.  The energy surcharge will be adjusted quarterly, based upon the U.S. Department of Labor Consumer Price Index (CPI) - Energy.  The appropriate energy surcharge will be applied to the waste treatment/disposal fee(s) based on the date of waste receipt.  For more information on the current energy surcharge, please contact customer service at (800) 592-5489.'
		--INSERT INTO #tmp_notes VALUES (@sequence_id, @note)
		BREAK
	END
	FETCH c_recovery_fee
 INTO @recovery_fee_billing_project_id

END 
CLOSE c_recovery_fee
DEALLOCATE c_recovery_fee

------------------------------------------------------------------
-- Insert  Customer EECFee term conditions into the temporary table
--------------------------------------------------------------------
SELECT 
    @eecfee_sequence_id = ROW_NUMBER() OVER (ORDER BY ect.EECFeeTermsConditions_uid),
    @term_condition_desc =ect.EECFeeterms_condition_desc
	FROM 
    CustomerEECFeeTermsConditions cct
	INNER JOIN 
    EECFeeTermsConditions ect ON cct.EECFeeTermsConditions_uid = ect.EECFeeTermsConditions_uid
	WHERE 
    cct.customer_id =@customer_id
	AND  getdate() between cct.date_effective_from and cct.date_effective_to 

IF @eecfee_sequence_id > 0 AND  @frf_flag = 'T' AND ( @eir_flag = 'U' OR @eir_flag = 'F' )
begin
  SET @sequence_id = @eecfee_sequence_id
  SET @note = @term_condition_desc
  INSERT INTO #tmp_notes VALUES (@sequence_id, @note)
end

----------------------------------------
-- Note 3 - DevOps:88748 - Profile Fee 
----------------------------------------
---IF ( @labpack_flag = 'F' OR @labpack_flag = 'U') 
IF @labpack_flag = 'T'
BEGIN
	DECLARE c_profile_fee CURSOR FOR
	 SELECT apply_flag
	 from ProfileFeeDetail PFD
	  WHERE PFD.profile_id IN (Select profile_id FROM #tmp_profiles )

	FOR READ ONLY

	 OPEN c_profile_fee
	 FETCH c_profile_fee
	 INTO @apply_flag

	  WHILE (@@FETCH_STATUS = 0)

	BEGIN 
		iF @apply_flag = 'T'
		BEGIN
		SET @sequence_id = 3
		SET @note = 'Fees will be charged for waste approvals. A Profile Submission Fee of $125 will be charged for each initial profile approval, and a Profile Renewal Fee of $40 will be charged for each profile renewal.'
		INSERT INTO #tmp_notes VALUES (@sequence_id, @note)
		END
	
		FETCH c_profile_fee
	 INTO @apply_flag

	END 
	CLOSE c_profile_fee
	DEALLOCATE c_profile_fee
END 
----------------------------------------
-- Note 4 (Additional Fees)
----------------------------------------
SET @sequence_id = 4
---SET @note = 'Additional fees may apply at the time of delivery for off-loading assistance, due to non-conforming waste, or other issues.'
SET @note = 'All containers must be received in a condition consistent with applicable requirements. Additional charges will apply if waste is not properly classified, described, packaged, labeled, or contained.'
INSERT INTO #tmp_notes VALUES (@sequence_id, @note)

----------------------------------------
-- Note 5 - DevOps:65105
----------------------------------------
SET @sequence_id = 5
SET @note = 'Pricing is subject to change.'
INSERT INTO #tmp_notes VALUES (@sequence_id, @note)


----------------------------------------
-- Note 6
----------------------------------------
SET @sequence_id = 6
SET @note = 'The specified pricing is contingent upon the waste conforming to the approved profile.'
INSERT INTO #tmp_notes VALUES (@sequence_id, @note)

----------------------------------------
-- Note 7
----------------------------------------
SET @sequence_id = 7
---SET @note = 'All containers must meet US DOT requirements.'
SET @note = 'Additional charges may apply for off-loading assistance, due to non-conforming waste, or other issues.'
INSERT INTO #tmp_notes VALUES (@sequence_id, @note)

IF @apply_quoted_bulk_charge = 1
BEGIN
	----------------------------------------
	-- Note 7 (Bulk Disposal Charges Billing)
	----------------------------------------
	SET @sequence_id = 7
	SET @note = 'Quoted bulk disposal charges for solid materials will be billed by the cubic yard if the truckload density is less than 2,000 pounds per cubic yard. If the truckload density is greater than 2,000 pounds per cubic yard then bulk charges will be billed by the ton regardless of the approved container. USE Facility personnel will monitor all shipments.'
	INSERT INTO #tmp_notes VALUES (@sequence_id, @note)
END

IF @apply_michigan_deq = 1 AND GETDATE() < @emanifest_validation_date 
BEGIN
	----------------------------------------
	-- Note 8
	----------------------------------------
	SET @sequence_id = 8
	SET @note = 'The Michigan DEQ will assess a manifest fee for all hazardous waste manifests used in the State of Michigan.'
	INSERT INTO #tmp_notes VALUES (@sequence_id, @note)
END

----------------------------------------
-- Note 9
----------------------------------------
SET @sequence_id = 9
SET @note = 'If transportation is provided, an additional fuel surcharge will apply based on the weekly US DOE fuel price index.'
INSERT INTO #tmp_notes VALUES (@sequence_id, @note)

----------------------------------------
-- Note 10
----------------------------------------
SET @sequence_id = 10
--SET @note = 'Customer acknowledges that USE Facility may, at its sole discretion, ship waste to one of its affiliated locations or one of its approved, third-party facilities for treatment, disposal and/or recycling, and that such alternative location may be located outside of the United States.'
  SET @note = 'Customer acknowledges that Republic Services Facility may, at its sole discretion, change the treatment or other handling processes used for the waste or ship waste to one of its affiliated locations or one of its approved, third-party facilities for treatment, disposal and/or recycling, and that such alternative location may be located outside of the United States.'
INSERT INTO #tmp_notes VALUES (@sequence_id, @note)

----------------------------------------
-- Note 11
-- Display after emanifest_validation_date
----------------------------------------

IF GETDATE() >= @emanifest_validation_date 
BEGIN
	SET @sequence_id = 11
	SET @note = 'Due to the US EPA''s e-manifest regulations, a fee will be assessed to all customers for shipments utilizing a hazardous waste manifest.'
	INSERT INTO #tmp_notes VALUES (@sequence_id, @note)
END

----------------------------------------
-- Note 12
-- Terms and conditions
----------------------------------------
SET @sequence_id = 12
--SET @note = 'The Terms and Conditions are located at:
--https://www.usecology.com/Libraries/Facility_Documents/Services_Terms_and_Conditions.sflb.ashx'
---SET @note = 'The Terms and Conditions are located at: https://www.republicservices.com/cms/documents/Environmental-Solutions/ES-Terms-Conditions.pdf'
SET @note = 'The Environmental Service Terms & Conditions are located at: www.RepublicServices.com/ServiceTermsES'
INSERT INTO #tmp_notes VALUES (@sequence_id, @note)

----------------------------------------
-- Note 13
----------------------------------------
SET @sequence_id = 13
SET @note = 'Standard non-hazardous disposal pricing does not include PFOS/PFAS contaminants.'
INSERT INTO #tmp_notes VALUES (@sequence_id, @note)

-- Select all notes ordered by sequence ID
SELECT * FROM #tmp_notes ORDER BY sequence_id



GO

GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_customer_confirmation_notes] TO [EQAI];
GO

GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_customer_confirmation_notes] TO [svc_CORAppUser];
GO

GRANT EXECUTE
   ON OBJECT::[dbo].[sp_rpt_customer_confirmation_notes] TO [COR_USER];
GO

