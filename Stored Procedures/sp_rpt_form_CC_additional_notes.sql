DROP PROCEDURE sp_rpt_form_CC_additional_notes
GO
CREATE PROCEDURE sp_rpt_form_CC_additional_notes
	@form_id		int,
	@revision_id	int
AS
/***************************************************************************************
Returns additional notes for Customer Quote Confirmations; this information used to be
hard-coded into the d_rpt_form_cc DW.

Filename:		L:\Apps\SQL\EQAI\Plt_AI\Procedures\sp_rpt_form_CC_additional_notes.sql
Loads to:		Plt_AI
PB Object(s):	d_rpt_form_cc_additional_notes

09/18/2008 JDB	Created
09/07/2011 SK	Added new notes and modified sequence ID's on notes
11/08/2011 SK	Added join to FormXApproval to get facility specific notes
04/05/2012 SK	Changed to fetch the ensr_applied & insr_exempt from FormXApproval
08/08/2012 SK	Changed the text for note# 6 and also the conditions for the same. Also used FXA.insurance_surcharge_percent to determine the surcharge
10/09/2012 SK	Truck Load should be all one word
12/29/2014 AM   Modified energy surcharges text and commented insurance surcharges, since we don't add any insurance surcharges after eir changes get processed
06/23/2017 MPM	Added a note for additional fuel surcharge.
09/07/2017 MPM	Added an additional note.
05/24/2018 MPM	Added note 10 to be displayed after emanifest_validation_date.
06/27/2018 MPM	Edited note 10 and removed note 7 after emanifest_validation_date.
04/08/2019 MPM	GEM 59726 - Price Confirmation Updates
12/06/2019 MPM	Samanage 10833/DevOps 12935 - Added note 12.
05/18/2020 AM   DevOps:15724 - EQAI- PC for EIR Exempt approval
06/13/2020 OE	Devops:16237 - EQAI-Price Confirmations missing EIR Fee note
06/26/2020 MPM	DevOps 16583 - Uncommented the lines that populate @emanifest_validation_date
				so that the e-manifest note will be displayed on the PC.
10/06/2020 GDE	DevOps 17343 - Update to price confirmation notes ( #9)




sp_rpt_form_CC_additional_notes 164216, 1
sp_rpt_form_CC_additional_notes 425112, 1
****************************************************************************************/
DECLARE	@note							varchar(2000),
		@sequence_id					tinyint,
		@ensr_applied					tinyint,
		@insurance_surcharge_percent	money,
		@apply_michigan_deq				TINYINT,
		@apply_quoted_bulk_charge		tinyint,
		@get_today_date				    datetime,
		@emanifest_validation_date		datetime,
		@ensr_exempt					char(1)
		
select @emanifest_validation_date = cast(config_value as datetime) 
from Configuration 
where config_key = 'emanifest_validation_date'
		
SELECT 
	FXA.approval_code,
	FXA.profile_id,
	FXA.insurance_surcharge_percent AS insurance_surcharge_percent,
	CASE FXA.ensr_exempt WHEN 'F' THEN 0 ELSE 1 END AS ensr_applied,
	CASE WHEN FXA.company_ID IN (2, 3, 21) THEN 1 ELSE 0 END AS apply_michigan_deq,
	CASE PC.confirmation_bulk_density_flag WHEN 'T' THEN 1 ELSE 0 END AS apply_quoted_bulk_charge
INTO #tmp
FROM FormCC
INNER JOIN FormXApproval FXA
	ON FXA.form_id = FormCC.form_id 
	AND FXA.revision_id = FormCC.revision_id
	AND FXA.form_type = 'CC'
INNER JOIN Company 
	ON FXA.company_id = Company.company_id
INNER JOIN ProfitCenter PC
	ON PC.company_id = FXA.company_id
	AND PC.profit_ctr_id = FXA.profit_ctr_id
WHERE FormCC.form_id = @form_id
AND FormCC.revision_id = @revision_id

SELECT @insurance_surcharge_percent = MAX(insurance_surcharge_percent) FROM #tmp
SELECT @ensr_applied = MAX(ensr_applied) FROM #tmp
SELECT @apply_michigan_deq = MAX(apply_michigan_deq) FROM #tmp
SELECT @apply_quoted_bulk_charge = MAX(apply_quoted_bulk_charge) FROM #tmp

----------------------------------------
-- Create table to store notes
----------------------------------------
CREATE TABLE #tmp_notes (
	sequence_id		tinyint,
	note			varchar(max)	)

----------------------------------------
-- Note 1 (insurance surcharge)
----------------------------------------
--IF @insurance_surcharge_percent > 0.00
--BEGIN
--	SET @sequence_id = 1
--	SET @note = 'An insurance surcharge of ' + CONVERT(varchar(10), @insurance_surcharge_percent) + '% will apply to all transportation, disposal and services provided.'
--	INSERT INTO #tmp_notes VALUES (@sequence_id, @note)
--END

----------------------------------------
-- Note 2 (energy surcharge) 
----------------------------------------
IF @ensr_applied = 0
BEGIN
	SET @sequence_id = 2
	SET @get_today_date = GetDate ()
	
	--IF @get_today_date <= dbo.fn_GetEIRrate_min_effective_date () 
	IF @ensr_applied = 0
	 BEGIN
	   --SET @note = 'An energy surcharge will be applied to all waste streams received at EQ''s fixed based TSDF operations.  The energy surcharge will be adjusted quarterly, based upon the U.S. Department of Labor Consumer Price Index (CPI) - Energy.  The appropriate energy surcharge will be applied to the waste treatment/disposal fee(s) based on the date of waste receipt.  For more information on the current energy surcharge, please contact customer service at (800) 592-5489.'
		SET @note = 'An Energy, Insurance, and Recovery Fee will apply to all waste recycling, treatment and disposal fees.' 
	END 
	--ELSE
	 --BEGIN
	 --  SET @note = 'An Energy, Insurance, and Recovery Fee will apply to all waste recycling, treatment and disposal fees.' 
	 --END  
	INSERT INTO #tmp_notes VALUES (@sequence_id, @note)
END

----------------------------------------
-- Note 3 (Additional Fees)
----------------------------------------
SET @sequence_id = 3
SET @note = 'Additional fees may apply at the time of delivery for off-loading assistance, due to non-conforming waste, or other issues.'
INSERT INTO #tmp_notes VALUES (@sequence_id, @note)

----------------------------------------
-- Note 4 
----------------------------------------
SET @sequence_id = 4
SET @note = 'The specified pricing is contingent upon the waste conforming to the approved waste profile.'
INSERT INTO #tmp_notes VALUES (@sequence_id, @note)

----------------------------------------
-- Note 5
----------------------------------------
SET @sequence_id = 5
SET @note = 'All containers must meet US DOT requirements.'
INSERT INTO #tmp_notes VALUES (@sequence_id, @note)

-----------------------------------------------------------------------------------------------------
-- Facility Specific Notes:
-- Following is conditional for approvals destined to specific facilities
-----------------------------------------------------------------------------------------------------
IF @apply_quoted_bulk_charge = 1
BEGIN
	----------------------------------------
	-- Note 6 (Bulk Disposal Charges Billing)
	----------------------------------------
	SET @sequence_id = 6
	SET @note = 'Quoted bulk disposal charges for solid materials will be billed by the cubic yard if the truckload density is less than 2,000 pounds per cubic yard. If the truckload density is greater than 2,000 pounds per cubic yard then bulk charges will be billed by the ton regardless of the approved container. USE Facility personnel will monitor all shipments.'
	INSERT INTO #tmp_notes VALUES (@sequence_id, @note)
END

IF @apply_michigan_deq = 1 AND (GETDATE() < @emanifest_validation_date)
BEGIN
	----------------------------------------
	-- Note 7
	----------------------------------------
	SET @sequence_id = 7
	SET @note = 'The Michigan DEQ will assess a manifest fee for all hazardous waste manifests used in the State of Michigan.'
	INSERT INTO #tmp_notes VALUES (@sequence_id, @note)
END

----------------------------------------
-- Note 8
----------------------------------------
SET @sequence_id = 8
SET @note = 'If transportation is provided, an additional fuel surcharge will apply based on the weekly US DOE fuel price index.'
INSERT INTO #tmp_notes VALUES (@sequence_id, @note)

----------------------------------------
-- Note 9
----------------------------------------
SET @sequence_id = 9
SET @note = 'Customer acknowledges that USE Facility may, at its sole discretion, change the treatment or other handling processes used for the waste or ship waste to one of its affiliated locations or one of its approved, third-party facilities for treatment, disposal and/or recycling, and that such alternative location may be located outside of the United States.'
INSERT INTO #tmp_notes VALUES (@sequence_id, @note)

----------------------------------------
-- Note 10
-- Display after emanifest_validation_date
----------------------------------------

IF GETDATE() >= @emanifest_validation_date 
BEGIN
	SET @sequence_id = 10
	SET @note = 'Due to the US EPA''s e-manifest regulations, a fee will be assessed to all customers for shipments utilizing a hazardous waste manifest.'
	INSERT INTO #tmp_notes VALUES (@sequence_id, @note)
END

----------------------------------------
-- Note 11
-- Terms and conditions
----------------------------------------
SET @sequence_id = 11
SET @note = 'The Terms and Conditions are located at: https://www.usecology.com/Libraries/Facility_Documents/Services_Terms_and_Conditions.sflb.ashx'
INSERT INTO #tmp_notes VALUES (@sequence_id, @note)

----------------------------------------
-- Note 12
----------------------------------------
SET @sequence_id = 12
SET @note = 'Standard non-hazardous disposal pricing does not include PFOS/PFAS contaminants.'
INSERT INTO #tmp_notes VALUES (@sequence_id, @note)

-- Select all notes ordered by sequence ID
SELECT * FROM #tmp_notes ORDER BY sequence_id
GO

GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_form_CC_additional_notes] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_form_CC_additional_notes] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_form_CC_additional_notes] TO [EQAI]
    AS [dbo];

