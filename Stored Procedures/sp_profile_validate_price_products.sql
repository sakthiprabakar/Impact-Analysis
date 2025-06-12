-- DROP PROCEDURE [dbo].[sp_profile_validate_price_products]
GO


CREATE PROCEDURE [dbo].[sp_profile_validate_price_products]
	@profile_id int,
	@company_id int,
	@profit_ctr_id int
AS
/***************************************************************************************
 This procedure validates profile pricing products, mostly required taxes for specific states

 loads to Plt_ai
 
 10/15/2010 - rb created
 03/14/2011 - rb For PA tax, reference TreatmentProcess table instead of transship_flag.
                 IL Hazardous Material Fee needs to reference TreatmentProcess Transship as well,
                 and only require fee if waste is not transhipped
 03/14/2011 - rb Remove OK Non Haz validation
 12/27/2012 - rb Added validation for Waste Disposal Host WHCA products
 01/07/2013 - rb Changed validation to check for at least one Product instead of one product per billing unit
 05/01/2014 - JDB Updated the check for hazardous waste codes so that it does not include
					EQ waste codes in its count.
 10/06/2017 - JCG Added NV validation.
 11/17/2017 - JDB Added ID validation.
 04/17/2018 - RJB Added TX validation based on ID validation but modified to support tax_groups
				Also minor updating on two SQL statements that get counts on haz and non-haz waste
				codes. It used to be acceptable to join ProfileWasteCode and WasteCode by waste_code
				but since addition of waste_code_uid we should be joining on uid. Changed under 
				direction of Jason via Skype conversation on 4.20.2018 Modified error messages
				per Paul K. testing on 5.3.2018
 05/24/2018 - RJB Added logic to handle bundling differently instead of relying on bill method
				use the ref_sequence_id as some are 'soft' bundled via ref_sequence_id
 08/08/2018 - MPM - GEM 52421 - Added a message to suggest TX fee 'C' when the profile contains a 
				waste code UNIV{xxxx} and TX fee C is missing.  Also modified the existing TX validation 
				which requires a federal EPA waste code on the profile if @tax_group is TX C or E; this 
				validation will now be bypassed if the @tax_group = 'TX-C' and @univ_waste_code_count > 0.
 06/12/2019 - MPM - DevOps task 11200 - Changed the state validations for ID, NV and TX to companies 44, 45 and 46 instead.
 10/18/2019 - JCB - DevOps 12474: fix to correctly join ProfileQuoteDetail to Product: add pqd.product_ID = p.product_ID
08/12/2020 - AM DevOps:17151 - Adedd set transaction isolation level read uncommitted

 EXEC sp_profile_validate_price_products 347605, 45, 0
****************************************************************************************/
set transaction isolation level read uncommitted

declare @tsdf_state varchar(2),
		@haz_waste_code_count int,
		@nonhaz_waste_code_count int,
		@product_code varchar(15),
		@idx int,
		@bill_unit_code varchar(4),
		@taxcode_count	int,
		@epa_wc_fpku_count int,
		@epa_wc_d_count int,
		@epa_wc_count int,
		@unbundled_all_count int,
		@unbundled_not_all_count int,
		@unmatched_disp_and_taxgroup_count int,
		@bundled_taxcode_count int,
		@tax_group varchar(10),
		@univ_waste_code_count int

-- result table
create table #msg (
msg_id int not null,
msg_text varchar(255) not null
)

-- get TSDF state
select @tsdf_state = isnull(TSDF_state,'')
from TSDF (nolock)
where eq_company = @company_id
and eq_profit_ctr = @profit_ctr_id
and TSDF_status = 'A'
and ISNULL(eq_flag,'F') = 'T'

-- get counts of associated Hazardous and Non-Hazardous waste codes
select @haz_waste_code_count = count(*)
from ProfileWasteCode pwc (nolock)
inner join WasteCode wc (nolock) on pwc.waste_code_uid = wc.waste_code_uid
where pwc.profile_id = @profile_id
and ISNULL(wc.haz_flag,'F') = 'T'
AND wc.waste_code_origin <> 'E'

select @nonhaz_waste_code_count = count(*)
from ProfileWasteCode pwc (nolock)
inner join WasteCode wc (nolock) on pwc.waste_code_uid = wc.waste_code_uid
where pwc.profile_id = @profile_id
and ISNULL(wc.haz_flag,'F') = 'F'

select @univ_waste_code_count = count(*)
from ProfileWasteCode pwc (nolock)
inner join WasteCode wc (nolock) 
on pwc.waste_code_uid = wc.waste_code_uid
where pwc.profile_id = @profile_id
and wc.waste_code_origin = 'S'
AND wc.state = 'TX'
and wc.display_name like 'UNIV%'

--
-- STATE VALIDATIONS
--

-- TX
-- DevOps task 11200 - MPM - per PK, these validations should only be done for Robstown (46-00)
IF @tsdf_state = 'TX' AND @company_id = 46 AND @profit_ctr_id = 0
BEGIN
	 
	/* 	Gemini 49441 #1 & #5: There must be at least one (and only one) distinct Tax Code associated with the profile approval.
	
		Function below returns three possible values dependent on count of distinct Tax Groups for the profile
		1. If none exist then NULL returned
		2. If one exists then the Tax Group string is returned
		3. If more than one exists then 'VARIES' string is returned.
		
		We may use this #1 & #5 logic for NV and ID (maybe other) since it is possible as result of how data in TaxCode is populated- but wanted to double check w Jason.
	*/
	SELECT @tax_group = dbo.fn_get_profile_tax_group(@company_id, @profit_ctr_id, @profile_id)
	
	-- Check for ZERO tax groups associated with this profile approval
	IF @tax_group IS NULL
	BEGIN
		SELECT @idx = ISNULL(@idx, 0) + 1
		INSERT #msg VALUES (@idx, 'For company ' + CONVERT(varchar(10), @company_id) + ', there must be at least one Service price record that corresponds to a TX tax group. ') 
	END
	
	-- Check for MORE THAN ONE tax groups associated with this profile approval 
	IF @tax_group = 'VARIES'
	BEGIN
		SELECT @idx = ISNULL(@idx, 0) + 1
		INSERT #msg VALUES (@idx, 'For company ' + CONVERT(varchar(10), @company_id) + ', the Service price records may correspond to one TX tax group only. ') 

		IF @univ_waste_code_count > 0
		BEGIN
			SELECT @idx = ISNULL(@idx, 0) + 1
			INSERT #msg VALUES (@idx, 'For company ' + CONVERT(varchar(10), @company_id) + 
				', the Texas fee should be Texas group C (Hazardous Characteristic) because this profile has a UNIV waste code ') 
		END	

	END

	-- Remaining validations are moot if we do not have one- and exactly one tax group so enter if only one
	IF @tax_group is not null AND @tax_group <> 'VARIES' 
	BEGIN 
	
		/* 
			Gemini 49441 #2: If the tax group is bundled into any single disposal price, the same tax group code must be bundled into every other disposal 
			unit's price for same approval. No need to use Tax Group in the validation here because it is know (at this point) there is one (and only one)
			tax group for this profile approval. Essentially we are looking for naked disposal price lines 
		*/
		SELECT @bundled_taxcode_count = COUNT(1)
		FROM profilequotedetail AS pqd 
		INNER JOIN product p ON pqd.product_id = p.product_id 
			AND ISNULL(pqd.dist_company_id, pqd.company_id) = p.company_id 
			AND ISNULL(pqd.dist_profit_ctr_id, pqd.profit_ctr_id) = p.profit_ctr_id 
		INNER JOIN taxcode ON pqd.dist_company_id = taxcode.company_id 
			AND pqd.dist_profit_ctr_id = taxcode.profit_ctr_id 
			AND taxcode.tax_code_uid = p.tax_code_uid
		WHERE  pqd.profile_id = @profile_id 
			AND pqd.company_id = @company_id 
			AND pqd.profit_ctr_id = @profit_ctr_id 
			AND pqd.record_type = 'S'
			AND pqd.bill_method = 'B' 
			AND pqd.ref_sequence_id is not null
			
		IF @bundled_taxcode_count > 0 -- at least one bundled into a disposal price line
		BEGIN
			-- Gemini 49441 #2 Part 2 of 2: Count naked disposal lines (without bundled tax code)
			SELECT @unmatched_disp_and_taxgroup_count = COUNT(1) 
			FROM profilequotedetail 
			WHERE  profilequotedetail.profile_id = @profile_id 
				AND profilequotedetail.company_id = @company_id 
				AND profilequotedetail.profit_ctr_id = @profit_ctr_id
				AND profilequotedetail.record_type = 'D'  -- disposal 
				AND (
						(	-- If true, outer query disposal line is not matched which is bad
							SELECT COUNT(1)
							FROM profilequotedetail AS pqd 
							INNER JOIN product p ON pqd.product_id = p.product_id 
								AND ISNULL(pqd.dist_company_id, pqd.company_id) = p.company_id 
								AND ISNULL(pqd.dist_profit_ctr_id, pqd.profit_ctr_id) = p.profit_ctr_id 
							INNER JOIN taxcode ON pqd.dist_company_id = taxcode.company_id 
								AND pqd.dist_profit_ctr_id = taxcode.profit_ctr_id 
								AND taxcode.tax_code_uid = p.tax_code_uid
							WHERE  pqd.profile_id = profilequotedetail.profile_id 
								AND pqd.company_id = profilequotedetail.company_id 
								AND pqd.profit_ctr_id = profilequotedetail.profit_ctr_id
								AND pqd.record_type = 'S' -- service
								AND pqd.bill_method = 'B' -- bundled
								AND pqd.ref_sequence_id = profilequotedetail.sequence_id -- linkage to outer disposal line
							) = 0
					)
			
			-- just one unmatched disposal line is a validation error here
			IF @unmatched_disp_and_taxgroup_count > 0 
			BEGIN
				SELECT @idx = ISNULL(@idx, 0) + 1
				INSERT #msg VALUES (@idx, 'For company ' + CONVERT(varchar(10), @company_id) + 
					@tax_group  + ', is bundled into this disposal price line, therefore the same tax group code must be bundled into every other disposal unit price line.') 
			END
		END

		/* 
			Gemini 49441  #3 & #4: If the product tax code is unbundled and disposal price lines to which it applies are NOT set to ‘All’, then an unbundled 
			product tax code should exist for each and every disposal bill unit price line. 
		*/	
		SELECT 
			@unbundled_all_count 	 = ISNULL(SUM(CASE WHEN pqd.ref_sequence_id = 0 THEN 1 ELSE 0 END),0),
			@unbundled_not_all_count = ISNULL(SUM(CASE WHEN pqd.ref_sequence_id <> 0 THEN 1 ELSE 0 END),0)
		FROM profilequotedetail AS pqd 
		INNER JOIN product p ON pqd.product_id = p.product_id 
			AND ISNULL(pqd.dist_company_id, pqd.company_id) = p.company_id 
			AND ISNULL(pqd.dist_profit_ctr_id, pqd.profit_ctr_id) = p.profit_ctr_id 
		INNER JOIN taxcode ON pqd.dist_company_id = taxcode.company_id 
			AND pqd.dist_profit_ctr_id = taxcode.profit_ctr_id 
			AND taxcode.tax_code_uid = p.tax_code_uid
		WHERE  pqd.profile_id = @profile_id 
			AND pqd.company_id = @company_id 
			AND pqd.profit_ctr_id = @profit_ctr_id 
			AND pqd.ref_sequence_id is not null 
			AND pqd.record_type = 'S'
			AND pqd.bill_method in ('U','M') -- Added manual pre Paul 5.25.18
			
		IF @unbundled_not_all_count > 0 
		BEGIN
			-- Gemini 49441 #3 & #4 Part 2 of 2: See if there are naked disposal lines per this rule 
			SELECT @unmatched_disp_and_taxgroup_count = COUNT(1) 
			FROM profilequotedetail 
			WHERE  profilequotedetail.profile_id = @profile_id 
				AND profilequotedetail.company_id = @company_id 
				AND profilequotedetail.profit_ctr_id = @profit_ctr_id
				AND profilequotedetail.record_type = 'D' 
				AND (
					(SELECT COUNT(1)
					FROM profilequotedetail AS pqd 
					INNER JOIN product p ON pqd.product_id = p.product_id 
						AND ISNULL(pqd.dist_company_id, pqd.company_id) = p.company_id 
						AND ISNULL(pqd.dist_profit_ctr_id, pqd.profit_ctr_id) = p.profit_ctr_id 
					INNER JOIN taxcode ON pqd.dist_company_id = taxcode.company_id 
						AND pqd.dist_profit_ctr_id = taxcode.profit_ctr_id 
						AND taxcode.tax_code_uid = p.tax_code_uid
					WHERE  pqd.profile_id = profilequotedetail.profile_id 
						AND pqd.company_id = profilequotedetail.company_id 
						AND pqd.profit_ctr_id = profilequotedetail.profit_ctr_id
						AND pqd.record_type = 'S' 
						AND pqd.ref_sequence_id = profilequotedetail.sequence_id) = 0
						)
			IF @unmatched_disp_and_taxgroup_count > 0 
			BEGIN
				SELECT @idx = ISNULL(@idx, 0) + 1
				INSERT #msg VALUES (@idx, 'For company ' + CONVERT(varchar(10), @company_id) + 
					', If the product tax code is unbundled and the disposal price lines to which it applies are NOT set to ALL, then an unbundled tax code is required for each disposal line. ') 
			END

		END		
		
		/*  
			Gemini 49441 #6, #7 and #8: Validations require we have a count of EPA Waste codes in three groupings: (FPKU) (G) and (ALL) so count them 
		*/
		SELECT 
			@epa_wc_fpku_count = ISNULL(SUM(CASE WHEN LEFT(wc.waste_code,1) in ('F','P','K','U') THEN 1 ELSE 0 END),0),
			@epa_wc_d_count    = ISNULL(SUM(CASE WHEN LEFT(wc.waste_code,1) in ('D') THEN 1 ELSE 0 END),0),
			@epa_wc_count	   = ISNULL(SUM(1),0)
		FROM ProfileWasteCode AS pwc 
		INNER JOIN WasteCode AS wc ON pwc.waste_code_uid = wc.waste_code_uid
		WHERE pwc.profile_id = @profile_id
		AND wc.waste_code_origin = 'F' -- federal only
		
		/*  
			Gemini 49441 #6: If the tax groups TX-C or TX-E are assigned to profile approval, at least one EPA Waste code is required  
		*/
		IF @tax_group in ('TX-C', 'TX-E') AND @epa_wc_count = 0 AND NOT (@tax_group = 'TX-C' AND @univ_waste_code_count > 0)
		BEGIN
			SELECT @idx = ISNULL(@idx, 0) + 1
			INSERT #msg VALUES (@idx, 'For company ' + CONVERT(varchar(10), @company_id) + 
				', the Texas Fee selected is incompatible for the waste codes on this profile. The Texas fee group selected expects at least one Federal EPA waste code on the profile. ') 
		END
		
		/*  
			Gemini 49441 #7: If the tax groups TX-C or TX-E are assigned to profile approval, at least one EPA Waste code is required  
		*/
		IF @epa_wc_fpku_count > 0 AND @tax_group NOT IN ('TX-E', 'TX-N/A') 
		BEGIN
			SELECT @idx = ISNULL(@idx, 0) + 1
			INSERT #msg VALUES (@idx, 'For company ' + CONVERT(varchar(10), @company_id) + 
				', the Texas Fee selected is incompatible for the waste codes on the profile. When a profile has Federal EPA F, P, K, or U codes, the ' +
				'Texas fee should be either Texas group E (Hazardous Listed) or N/A. ') 
		END
			
		/*  
			Gemini 49441 #8: If the profile has any D EPA waste codes (but no F, P, K, or U codes), it must have one a “Characteristic Hazardous” fee code
		*/
		IF @epa_wc_d_count > 0 AND @epa_wc_fpku_count = 0 AND @tax_group NOT IN ('TX-C', 'TX-N/A')
		BEGIN
			SELECT @idx = ISNULL(@idx, 0) + 1
			INSERT #msg VALUES (@idx, 'For company ' + CONVERT(varchar(10), @company_id) + 
				', the Texas fee selected is incompatible for the waste codes.  This profile has only Federal EPA D codes and the ' +
				'Texas fee should be Texas group C (Hazardous Characteristic) or N/A ') 
		END	
			
	END -- block that processes for one and only one tax group  

	-- MPM - 8/6/2018 - GEM 52421 - Suggest TX fee 'C' when the profile contains a waste code UNIV{xxxx}
	IF @univ_waste_code_count > 0
	BEGIN
		IF @tax_group IS NULL OR @tax_group = 'VARIES'
		BEGIN
			SELECT @idx = ISNULL(@idx, 0) + 1
			INSERT #msg VALUES (@idx, 'For company ' + CONVERT(varchar(10), @company_id) + 
				', the Texas fee should be Texas group C (Hazardous Characteristic) because this profile has a UNIV waste code ') 
		END
		ELSE IF @tax_group <> 'TX-C'
		BEGIN
			SELECT @idx = ISNULL(@idx, 0) + 1
			INSERT #msg VALUES (@idx, 'For company ' + CONVERT(varchar(10), @company_id) + 
				', the Texas fee selected is incompatible for the waste codes.  This profile has a UNIV waste code and the ' +
				'Texas fee should be Texas group C (Hazardous Characteristic) ') 
		END
	END

END -- block for TSDF of TX

-- NV
-- DevOps task 11200 - MPM - per PK, these validations should only be done for Beatty (45-00)
IF @tsdf_state = 'NV' AND @company_id = 45 AND @profit_ctr_id = 0
BEGIN
	SET @taxcode_count = (SELECT COUNT(DISTINCT taxcode.tax_code_uid) 
		FROM   profilequotedetail pqd 
		INNER JOIN product p ON pqd.product_id = p.product_id 
			AND ISNULL(pqd.dist_company_id, pqd.company_id) = p.company_id 
			AND ISNULL(pqd.dist_profit_ctr_id, pqd.profit_ctr_id) = p.profit_ctr_id 
		INNER JOIN taxcode ON pqd.dist_company_id = taxcode.company_id 
			AND pqd.dist_profit_ctr_id = taxcode.profit_ctr_id 
			AND taxcode.tax_code_uid = p.tax_code_uid
		WHERE  pqd.profile_id = @profile_id 
		AND pqd.company_id = @company_id 
		AND pqd.profit_ctr_id = @profit_ctr_id 
		AND pqd.record_type = 'S' 
		AND taxcode.tax_code_uid IS NOT NULL
	 )
	
	IF @taxcode_count IS NULL SET @taxcode_count = 0;

	IF @taxcode_count < 1
	BEGIN
		SELECT @idx = ISNULL(@idx, 0) + 1
		INSERT #msg VALUES (@idx, 'For company ' + CONVERT(varchar(10), @company_id) + ', there must be at least one Service price record that corresponds to a NV tax code. ') -- + CONVERT(varchar(2), @taxcode_count))
	END
	ELSE
	BEGIN  
		IF @taxcode_count > 1
		BEGIN
			SELECT @idx = ISNULL(@idx, 0) + 1
			INSERT #msg VALUES (@idx, 'For company ' + CONVERT(varchar(10), @company_id) + ', the Service price records may correspond to one NV tax code only. ') -- + CONVERT(varchar(2), @taxcode_count))
		END
	END
END

-- ID (Idaho)
-- DevOps task 11200 - MPM - per PK, these validations should only be done for Idaho (44-00)
IF @tsdf_state = 'ID' AND @company_id = 44 AND @profit_ctr_id = 0
BEGIN
	SET @taxcode_count = (SELECT COUNT(DISTINCT taxcode.tax_code_uid) 
		FROM ProfileQuoteDetail AS pqd 
		INNER JOIN Product AS p ON pqd.product_id = p.product_id 
			AND ISNULL(pqd.dist_company_id, pqd.company_id) = p.company_id 
			AND ISNULL(pqd.dist_profit_ctr_id, pqd.profit_ctr_id) = p.profit_ctr_id 
		INNER JOIN TaxCode ON pqd.dist_company_id = TaxCode.company_id 
			AND pqd.dist_profit_ctr_id = TaxCode.profit_ctr_id 
			AND TaxCode.tax_code_uid = p.tax_code_uid
		WHERE  pqd.profile_id = @profile_id 
		AND pqd.company_id = @company_id 
		AND pqd.profit_ctr_id = @profit_ctr_id 
		AND pqd.record_type = 'S' 
		AND taxcode.tax_code_uid IS NOT NULL
	 )
	
	IF @taxcode_count IS NULL SET @taxcode_count = 0;

	IF @taxcode_count < 1
	BEGIN
		SELECT @idx = ISNULL(@idx, 0) + 1
		INSERT #msg VALUES (@idx, 'For company ' + CONVERT(varchar(10), @company_id) + ', there must be at least one Service price record that corresponds to an ID tax code. ')
	END
	ELSE
	BEGIN  
		IF @taxcode_count > 1
		BEGIN
			SELECT @idx = ISNULL(@idx, 0) + 1
			INSERT #msg VALUES (@idx, 'For company ' + CONVERT(varchar(10), @company_id) + ', the Service price records may correspond to one ID tax code only. ')
		END
	END
END
	
-- IL
if @tsdf_state = 'IL'
begin
	if @haz_waste_code_count > 0
	begin
		select @product_code = 'ILTAXHZ'
		if not exists (select 1 from ProfileQuoteApproval pqa
					inner join TreatmentProcess tp on pqa.treatment_process_id = tp.treatment_process_id
									and tp.code = 'Tranship'
					where pqa.profile_id = @profile_id
					and pqa.company_id = @company_id
					and pqa.profit_ctr_id = @profit_ctr_id)
		and not exists (select 1 from ProfileQuoteDetail pqd
						inner join Product p on pqd.product_ID = p.product_ID
											and ISNULL(pqd.dist_company_id,pqd.company_id) = p.company_ID
											and ISNULL(pqd.dist_profit_ctr_id,pqd.profit_ctr_id) = p.profit_ctr_id
						where pqd.profile_id = @profile_id
						and pqd.company_id = @company_id
						and pqd.profit_ctr_id = @profit_ctr_id
						and pqd.record_type = 'S'
						and p.product_code = @product_code)
		begin
			select @idx = isnull(@idx,0) + 1
			insert #msg values (@idx, 'For company ' + CONVERT(varchar(10),@company_id) + ', '
							+ 'there must be at least one Service record containing product ''' + @product_code + '''')
		end
	end
end

-- OH
if @tsdf_state = 'OH'
begin
	if @haz_waste_code_count > 0
	begin
		select @product_code = 'OHTAXHZ'
		if not exists (select 1 from ProfileQuoteDetail pqd
						inner join Product p on pqd.product_ID = p.product_ID
											and ISNULL(pqd.dist_company_id,pqd.company_id) = p.company_ID
											and ISNULL(pqd.dist_profit_ctr_id,pqd.profit_ctr_id) = p.profit_ctr_id
						where pqd.profile_id = @profile_id
						and pqd.company_id = @company_id
						and pqd.profit_ctr_id = @profit_ctr_id
						and pqd.record_type = 'S'
						and p.product_code = @product_code)
		begin
			select @idx = isnull(@idx,0) + 1
			insert #msg values (@idx, 'For company ' + CONVERT(varchar(10),@company_id) + ', '
							+ 'there must be at least one Service record containing product ''' + @product_code + '''')
		end
	end
end

-- OK
if @tsdf_state = 'OK'
begin
	if @haz_waste_code_count > 0
	begin
		select @product_code = 'OKTAXHZ'
		if not exists (select 1 from ProfileQuoteDetail pqd
						inner join Product p on pqd.product_ID = p.product_ID
											and ISNULL(pqd.dist_company_id,pqd.company_id) = p.company_ID
											and ISNULL(pqd.dist_profit_ctr_id,pqd.profit_ctr_id) = p.profit_ctr_id
						where pqd.profile_id = @profile_id
						and pqd.company_id = @company_id
						and pqd.profit_ctr_id = @profit_ctr_id
						and pqd.record_type = 'S'
						and p.product_code = @product_code)
		begin
			select @idx = isnull(@idx,0) + 1
			insert #msg values (@idx, 'For company ' + CONVERT(varchar(10),@company_id) + ', '
							+ 'there must be at least one Service record containing product ''' + @product_code + '''')
		end
	end
/*** rb Removed by request
	else if @nonhaz_waste_code_count > 0
	begin
		select @product_code = 'OKTAXNH'
		if not exists (select 1 from ProfileQuoteDetail pqd
						inner join Product p on pqd.product_ID = p.product_ID
											and ISNULL(pqd.dist_company_id,pqd.company_id) = p.company_ID
											and ISNULL(pqd.dist_profit_ctr_id,pqd.profit_ctr_id) = p.profit_ctr_id
						where pqd.profile_id = @profile_id
						and pqd.company_id = @company_id
						and pqd.profit_ctr_id = @profit_ctr_id
						and pqd.record_type = 'S'
						and p.product_code = @product_code)
		begin
			select @idx = isnull(@idx,0) + 1
			insert #msg values (@idx, 'For company ' + CONVERT(varchar(10),@company_id) + ', '
							+ 'there must be at least one Service record containing product ''' + @product_code + '''')
		end
	end
***/
end

-- PA
if @tsdf_state = 'PA'
begin
	if @haz_waste_code_count > 0
	begin
		select @product_code = 'PATAXHZTRANS'

		if exists (select 1 from ProfileQuoteApproval pqa
					inner join TreatmentProcess tp on pqa.treatment_process_id = tp.treatment_process_id
									and tp.code = 'Tranship'
					where pqa.profile_id = @profile_id
					and pqa.company_id = @company_id
					and pqa.profit_ctr_id = @profit_ctr_id)
		and not exists (select 1 from ProfileQuoteDetail pqd
						inner join Product p on pqd.product_ID = p.product_ID
											and ISNULL(pqd.dist_company_id,pqd.company_id) = p.company_ID
											and ISNULL(pqd.dist_profit_ctr_id,pqd.profit_ctr_id) = p.profit_ctr_id
						where pqd.profile_id = @profile_id
						and pqd.company_id = @company_id
						and pqd.profit_ctr_id = @profit_ctr_id
						and pqd.record_type = 'S'
						and p.product_code = @product_code)
		begin
			select @idx = isnull(@idx,0) + 1
			insert #msg values (@idx, 'For company ' + CONVERT(varchar(10),@company_id) + ', '
							+ 'there must be at least one Service record containing product ''' + @product_code + '''')
		end

		select @product_code = 'PATAXHZTREAT'

		if not exists (select 1 from ProfileQuoteApproval pqa
					inner join TreatmentProcess tp on pqa.treatment_process_id = tp.treatment_process_id
									and tp.code = 'Tranship'
					where pqa.profile_id = @profile_id
					and pqa.company_id = @company_id
					and pqa.profit_ctr_id = @profit_ctr_id)
		and not exists (select 1 from ProfileQuoteDetail pqd
						inner join Product p on pqd.product_ID = p.product_ID
											and ISNULL(pqd.dist_company_id,pqd.company_id) = p.company_ID
											and ISNULL(pqd.dist_profit_ctr_id,pqd.profit_ctr_id) = p.profit_ctr_id
						where pqd.profile_id = @profile_id
						and pqd.company_id = @company_id
						and pqd.profit_ctr_id = @profit_ctr_id
						and pqd.record_type = 'S'
						and p.product_code = @product_code)
		begin
			select @idx = isnull(@idx,0) + 1
			insert #msg values (@idx, 'For company ' + CONVERT(varchar(10),@company_id) + ', '
							+ 'there must be at least one Service record containing product ''' + @product_code + '''')
		end

		-- rb Note that 'YORK CITY TAX' will soon be renamed 'PATAXHZYORK'
		select @product_code = 'YORK CITY TAX'
		if not exists (select 1 from ProfileQuoteDetail pqd
						inner join Product p on pqd.product_ID = p.product_ID
											and ISNULL(pqd.dist_company_id,pqd.company_id) = p.company_ID
											and ISNULL(pqd.dist_profit_ctr_id,pqd.profit_ctr_id) = p.profit_ctr_id
						where pqd.profile_id = @profile_id
						and pqd.company_id = @company_id
						and pqd.profit_ctr_id = @profit_ctr_id
						and pqd.record_type = 'S'
						and p.product_code = @product_code)
		begin
			select @idx = isnull(@idx,0) + 1
			insert #msg values (@idx, 'For company ' + CONVERT(varchar(10),@company_id) + ', '
							+ 'there must be at least one Service record containing product ''' + @product_code + '''')
		end
	end
end

-- rb 12/27/2012 WHCA validation
select @product_code = 'WHCA'
if ((@company_id = 3 and @profit_ctr_id = 0)
		or exists (select 1 from ProfileQuoteApproval pqa
					inner join DisposalService ds
						on pqa.disposal_service_id = ds.disposal_service_id
						and ds.code = 'Sub C'
					where pqa.profile_id = @profile_id
					and pqa.company_id = @company_id
					and pqa.profit_ctr_id = @profit_ctr_id
					and pqa.status = 'A')
	)
	and not exists (select 1 from ProfileQuoteApproval pqa
					inner join Profile p
						on pqa.profile_id = p.profile_id
					inner join CustomerBilling cb
						on p.customer_id = cb.customer_id
						and cb.billing_project_id = isnull(pqa.billing_project_id,0)
						and cb.status = 'A'
						and isnull(cb.whca_exempt,'F') = 'T'
					where pqa.profile_id = @profile_id
					and pqa.company_id = @company_id
					and pqa.profit_ctr_id = @profit_ctr_id
					and pqa.status = 'A')
begin
	/*** rb 01/07/2013 This was the check for at least one WHCA product per billing unit
	declare c_bu cursor for
	select distinct pqd_d.bill_unit_code
	from ProfileQuoteDetail pqd_d (nolock)
	where pqd_d.profile_id = @profile_id
	and pqd_d.company_id = @company_id
	and pqd_d.profit_ctr_id = @profit_ctr_id
	and pqd_d.record_type = 'D'
	and pqd_d.status = 'A'
	and not exists (select 1 from ProfileQuoteDetail pqd_s
					join Product p
						on ISNULL(pqd_d.dist_company_id,pqd_d.company_id) = p.company_ID
						and ISNULL(pqd_d.dist_profit_ctr_id,pqd_d.profit_ctr_id) = p.profit_ctr_id
						and pqd_d.bill_unit_code = p.bill_unit_code
						and p.product_code = @product_code
					where pqd_d.profile_id = pqd_s.profile_id
					and pqd_d.company_id = pqd_s.company_ID
					and pqd_d.profit_ctr_id = pqd_s.profit_ctr_id
					and pqd_s.ref_sequence_id = pqd_d.sequence_id
					and pqd_s.record_type = 'S'
					and pqd_s.status = 'A'
					and pqd_s.product_id = p.product_id)
	for read only

	open c_bu
	fetch c_bu into @bill_unit_code
	
	while @@FETCH_STATUS = 0
	begin
		select @idx = isnull(@idx,0) + 1
		insert #msg values (@idx, 'For company ' + CONVERT(varchar(10),@company_id) + ', bill unit ' + @bill_unit_code
							+ ' must have at least one Service record containing product ''' + @product_code + '''')

		fetch c_bu into @bill_unit_code
	end
	
	close c_bu
	deallocate c_bu
	***/
	if not exists (select 1 from ProfileQuoteDetail pqd
			join Product p
				on ISNULL(pqd.dist_company_id,pqd.company_id) = p.company_ID
				and ISNULL(pqd.dist_profit_ctr_id,pqd.profit_ctr_id) = p.profit_ctr_id
				and pqd.bill_unit_code = p.bill_unit_code
				and pqd.product_ID = p.product_ID                  -- jcb 20191018 DevOps 12474 ADD
				and p.product_code = @product_code
			where pqd.profile_id = @profile_id
			and pqd.company_id = @company_ID
			and pqd.profit_ctr_id = @profit_ctr_id
			and pqd.record_type = 'S'
			and pqd.status = 'A')
	begin
		select @idx = isnull(@idx,0) + 1
		insert #msg values (@idx, 'For company ' + CONVERT(varchar(10),@company_id)
		+ ', there must be at least one Service record containing a WHCA product for at least one of the billing units')
	end
end 

--
-- RETURN RESULTS
--
SELECT msg_text FROM #msg ORDER BY msg_id
DROP TABLE #msg
RETURN 0
GO


