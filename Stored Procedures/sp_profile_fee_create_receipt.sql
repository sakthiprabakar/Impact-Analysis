USE PLT_AI
GO

CREATE OR ALTER PROCEDURE [dbo].[sp_profile_fee_create_receipt] 
AS
/***************************************************************
 *sp_profile_fee_create_receipt
 *
 *This procedure creates receipts for profile fee 
 *
 * 07/01/2024 agc DevOps 88335 created 
 * 08/07/2024 Dipankar DevOps 94209 Fixed Join Issue for handling 21-00 Exemption
 * 08/08/2024 Dipankar DevOps: 93748/ DevOps: 93744 Made changes related to Notes as per latest requirements
 * 08/09/2024 Dipankar DevOps: 88335 Added logic to run the program only on Mondays
 * 08/26/2024 Dipankar DevOps: 94524 Added logic for Time Out to be 5 min. more than the Time In
 * 08/27/2024 Dipankar DevOps: 94706/ DevOps: 94717 - Note related changes done
 * 09/07/2024 Dipankar DevOps: 94706/ DevOps: 94717 - Process Date condition incremented with a day 
                                                    - to include the records from that day
 * 11/05/2024 Kamendra Rally US131397 - Exempt the "New Profile Fee" from Imported "Integration" Profiles
 * 11/11/2024 Sailaja 	Rally: DE35576 - Profile fee receipt creation Batch Process - Restrict receipt creation in companies that donot have 
						Profile fee product codes activated. Modified the join condition on product table to JOIN instead of LEFT JOIN in the cursor.
 * 11/14/2024 Kamendra Rally US132628 - Profile Fee - Temporary Exemption for Company 68
 * 12/19/2024 Kamendra Rally DE37052 - Profile Fee - Double Billing when primary facility is changed
 * 01/15/2025 Kamendra Rally US133422 -  Improvements to 'sp_profile_fee_create_receipt'
 * 02/11/2025 Anukool Rally US133821 - Removed previous 21-00 exemption logic
 * 02/14/2025 Anukool Rally DE36513 - Receipt Status should be updated as 'A'-(Accepted) instead of 'S'
 * 02/18/2025 Sailaja Rally US140671 - Profile Fee - Profile Tracking - Add Effective Date
 * 03/25/2025 Kamendra Rally US142937 - Profile Fee - Prevent billing Profiles processed more than 3 months ago

sp_profile_fee_create_receipt
****************************************************************/
BEGIN
	DECLARE @dayname VARCHAR(10) = DATENAME(weekday, GETDATE()),
			@today DATE = CAST(GetDate() AS DATE),
			@allow_receipt_auto_generation CHAR(1) = 'F',
			@allow_receipt_ondemand_generation CHAR(1) = 'F',
			@profile_fee_effective_date datetime,
			@profile_fee_process_date datetime,
			@profile_fee_grace_days int,
			@receipt_id int,
			@profile_id int,
			@customer_id int,
			@company_id int,
			@generator_id int,
			@profit_ctr_id int,
			@po_required_flag char(1),
			@date_added datetime,
			@renewal_date datetime,
			@process_date datetime,
			@source_form_id int,
			@profile_id_old int,
			@customer_id_old int,
			@company_id_old int,
			@profit_ctr_id_old int,
			@profile_fee_code_uid int,
			@profile_fee_code varchar(25),
			@product_id int,
			@product_code varchar(15),
			@product_description varchar(60),
			@line_id int,
			@count_lines int,
			@return_value int,
			@submit_status char(1),
			@submit_date datetime,
			@profile_fee_rate money,		
			@link_required_flag char(1),
			@release_required_flag char(1),
			@other_submit_required_flag char(1),
			@terms_code varchar(8),		
			@po_validation_flag char(1),
			@release_validation_flag char(1),
			@d365_hold_status varchar(10),
			@note_id int,
			@note_type varchar(15) = 'NOTE',
			@note_status char(1) = 'C',
			@note_subject varchar(50) = 'PROFILE FEE ATTENTION REQUIRED',
			@note_text varchar(250),
			@note_source varchar(30) = 'Receipt',		
			@app_source varchar(20) = 'EQAI',
			@salesforce_json_flag char(1) = 'N',
			@note_contact_type varchar(15) = 'Note',
			@note_text_combined varchar(500),
			@profile_fee_process_date_for_past_profiles DATETIME,
			@profile_fee_process_days_for_past_profiles INTEGER
	
	-- This Flag should be True for both Auto/ OnDemand Generation
	SELECT @allow_receipt_auto_generation = config_value 
	FROM plt_ai.dbo.Configuration 
	WHERE config_key = 'Allow_Profile_Fee_Receipt_Auto_Generation'

	SELECT @allow_receipt_ondemand_generation = config_value 
	FROM plt_ai.dbo.Configuration 
	WHERE config_key = 'Allow_Profile_Fee_Receipt_OnDemand_Generation'

	IF @allow_receipt_auto_generation = 'F'
	BEGIN
		PRINT 'Profile Fee Receipt Auto-Generation is not being allowed, Please check configuration setting.'
		RETURN
	END
    
	IF @dayname <> 'Monday'
	BEGIN
		IF @allow_receipt_ondemand_generation = 'F'
		BEGIN
			PRINT 'Create Profile Fee Receipts Program runs only on Mondays or when On Demand Genration is allowed.'
			RETURN
		END
	END	
	
	DROP TABLE IF EXISTS #ReceiptProfileFee;
	CREATE TABLE #ReceiptProfileFee (
		receipt_profile_fee_uid INT NULL
		, company_id INT NULL
		, profit_ctr_id INT NULL
		, receipt_id INT NULL
		, line_id INT NULL
		, profile_fee_code_uid INT NULL
		, profile_id INT NULL
		, profile_processed_date DATETIME NULL
		, added_by VARCHAR(10) NULL
		, date_added DATETIME NULL
		, modified_by VARCHAR(10) NULL
		, date_modified DATETIME NULL
		)

	DROP TABLE IF EXISTS #ReceiptAudit;
	CREATE TABLE #ReceiptAudit (
		company_id INT NULL
		, profit_ctr_id INT NULL
		, receipt_id INT NULL
		, line_id INT NULL
		, price_id INT NULL
		, table_name VARCHAR(40) NULL
		, column_name VARCHAR(40) NULL
		, before_value VARCHAR(255) NULL
		, after_value VARCHAR(255) NULL
		, audit_reference VARCHAR(255) NULL
		, modified_by VARCHAR(10) NULL
		, modified_from VARCHAR(10) NULL
		, date_modified DATETIME NULL
		)

	DROP TABLE IF EXISTS #Receipt;
	CREATE TABLE #Receipt (
		company_id INT NULL
		, profit_ctr_id INT NULL
		, receipt_id INT NULL
		, line_id INT NULL
		, trans_mode CHAR(1) NULL
		, trans_type CHAR(1) NULL
		, receipt_status CHAR(1) NULL
		, fingerpr_status CHAR(1) NULL
		, waste_accepted_flag CHAR(1) NULL
		, submitted_flag CHAR(1) NULL
		, receipt_date DATETIME NULL
		, manifest_flag CHAR(1) NULL
		, manifest VARCHAR(15) NULL
		, customer_id INT NULL
		, generator_id INT NULL
		, load_generator_EPA_ID VARCHAR(12) NULL
		, profile_id INT NULL
		, approval_code VARCHAR(15) NULL
		, waste_code VARCHAR(4) NULL
		, treatment_id INT NULL
		, product_id INT NULL
		, product_code VARCHAR(15) NULL
		, quantity FLOAT NULL
		, bill_unit_code VARCHAR(4) NULL
		, container_count INT NULL
		, hauler VARCHAR(20) NULL
		, truck_code VARCHAR(10) NULL
		, bulk_flag CHAR(1) NULL
		, problem_id INT NULL
		, service_desc VARCHAR(60) NULL
		, manifest_comment VARCHAR(100) NULL
		, gross_weight INT NULL
		, tare_weight INT NULL
		, net_weight INT NULL
		, line_weight DECIMAL(18,6) NULL
		, schedule_confirmation_id INT NULL
		, date_scheduled DATETIME NULL
		, time_in DATETIME NULL
		, time_out DATETIME NULL
		, created_by VARCHAR(8) NULL
		, date_added DATETIME NULL
		, modified_by VARCHAR(8) NULL
		, date_modified DATETIME NULL
		, date_charges_added DATETIME NULL
		, date_receipt_printed DATETIME NULL
		, submitted_by VARCHAR(10) NULL
		, date_submitted DATETIME NULL
		, void_reason VARCHAR(100) NULL
		, voided_by VARCHAR(8) NULL
		, tender_type CHAR(1) NULL
		, cash_received MONEY NULL
		, total_cash_received MONEY NULL
		, cod_override CHAR(1) NULL
		, billing_project_id INT NULL
		, po_sequence_id INT NULL
		, purchase_order VARCHAR(20) NULL
		, release VARCHAR(20) NULL
		, billing_link_id INT NULL
		, gl_account_type CHAR(1) NULL
		, gl_account_code VARCHAR(32) NULL
		, chemist VARCHAR(8) NULL
		, sampler CHAR(3) NULL
		, sludge_quantity INT NULL
		, pH_value FLOAT NULL
		, reacts_box CHAR(1) NULL
		, water_react CHAR(1) NULL
		, ignitability VARCHAR(10) NULL
		, cyanide_spot CHAR(1) NULL
		, sulfide_gr100 CHAR(1) NULL
		, react_NaOH CHAR(1) NULL
		, react_HCL CHAR(1) NULL
		, odor CHAR(1) NULL
		, color_match CHAR(1) NULL
		, consist_match CHAR(1) NULL
		, free_liquid CHAR(1) NULL
		, avg_h20_gr_10 CHAR(1) NULL
		, CCVOCgr500 CHAR(1) NULL
		, CCVOC FLOAT NULL
		, DDVOC FLOAT NULL
		, phasing CHAR(1) NULL
		, ratio VARCHAR(10) NULL
		, specific_gravity FLOAT NULL
		, BTU_per_lb INT NULL
		, pct_moisture VARCHAR(10) NULL
		, pct_chlorides VARCHAR(10) NULL
		, pct_halogens VARCHAR(10) NULL
		, pct_solids VARCHAR(10) NULL
		, consistency_desc VARCHAR(50) NULL
		, color_desc VARCHAR(25) NULL
		, density FLOAT NULL
		, PCB VARCHAR(10) NULL
		, react_CKD CHAR(1) NULL
		, react_Bleach CHAR(1) NULL
		, radiation CHAR(1) NULL
		, pct_BSW_oil VARCHAR(10) NULL
		, pct_BSW_water VARCHAR(10) NULL
		, pct_BSW_solid VARCHAR(10) NULL
		, pct_BSW_other VARCHAR(10) NULL
		, ppm_halogens VARCHAR(10) NULL
		, ppm_cod_bod VARCHAR(10) NULL
		, ppm_fog VARCHAR(10) NULL
		, FSCAN VARCHAR(4) NULL
		, arsenic VARCHAR(10) NULL
		, barium VARCHAR(10) NULL
		, cadmium VARCHAR(10) NULL
		, chromium VARCHAR(10) NULL
		, copper VARCHAR(10) NULL
		, iron VARCHAR(10) NULL
		, lead VARCHAR(10) NULL
		, nickel VARCHAR(10) NULL
		, silver VARCHAR(10) NULL
		, zinc VARCHAR(10) NULL
		, phosphorus VARCHAR(10) NULL
		, lab_comments VARCHAR(200) NULL
		, location_type CHAR(1) NULL
		, location VARCHAR(15) NULL
		, tracking_num VARCHAR(15) NULL
		, cycle INT NULL
		, TSDF_code VARCHAR(15) NULL
		, TSDF_approval_id INT NULL
		, TSDF_approval_code VARCHAR(40) NULL
		, waste_stream VARCHAR(10) NULL
		, TSDF_approval_bill_unit_code VARCHAR(4) NULL
		, OB_profile_ID INT NULL
		, OB_profile_company_ID INT NULL
		, OB_profile_profit_ctr_id INT NULL
		, OB_tsdf_accept_date DATETIME NULL
		, OB_tsdf_pcb_disposal_date DATETIME NULL
		, continuation_flag CHAR(1) NULL
		, manifest_page_num INT NULL
		, manifest_line INT NULL
		, manifest_line_id CHAR(1) NULL
		, manifest_hazmat CHAR(1) NULL
		, manifest_RQ_flag CHAR(1) NULL
		, manifest_RQ_reason VARCHAR(50) NULL
		, manifest_DOT_shipping_name TEXT NULL
		, manifest_hazmat_class VARCHAR(15) NULL
		, manifest_sub_hazmat_class VARCHAR(15) NULL
		, manifest_UN_NA_flag CHAR(2) NULL
		, manifest_UN_NA_number INT NULL
		, manifest_package_group VARCHAR(3) NULL
		, manifest_container_code VARCHAR(15) NULL
		, manifest_quantity FLOAT NULL
		, manifest_unit CHAR(1) NULL
		, manifest_management_code VARCHAR(4) NULL
		, manifest_ERG_number INT NULL
		, manifest_ERG_suffix CHAR(2) NULL
		, ref_company_id INT NULL
		, ref_profit_ctr_id INT NULL
		, ref_receipt_id INT NULL
		, ref_line_id INT NULL
		, bill_method CHAR(1) NULL
		, bill_quantity_flag CHAR(1) NULL
		, optional_flag CHAR(1) NULL
		, apply_charge_flag CHAR(1) NULL
		, confirmed_by VARCHAR(40) NULL
		, cust_invoice_ref VARCHAR(20) NULL
		, data_complete_flag CHAR(1) NULL
		, source_type CHAR(1) NULL
		, source_company_id INT NULL
		, source_profit_ctr_id INT NULL
		, source_id INT NULL
		, source_line_id INT NULL
		, cost_flag CHAR(1) NULL
		, cost_disposal MONEY NULL
		, cost_lab MONEY NULL
		, cost_process MONEY NULL
		, cost_surcharge MONEY NULL
		, cost_trans MONEY NULL
		, cost_disposal_est MONEY NULL
		, cost_lab_est MONEY NULL
		, cost_process_est MONEY NULL
		, cost_surcharge_est MONEY NULL
		, cost_trans_est MONEY NULL
		, cost_description VARCHAR(50) NULL
		, load_number INT NULL
		, min_trans_qty FLOAT NULL
		, min_load_qty FLOAT NULL
		, transfer_dest_flag CHAR(1) NULL
		, in_transit INT NULL
		, other_submit_required_flag CHAR(1) NULL
		, submit_on_hold_flag CHAR(1) NULL
		, submit_on_hold_reason VARCHAR(255) NULL
		, prenote_canada VARCHAR(40) NULL
		, manifest_canada VARCHAR(40) NULL
		, drmo_clin_num INT NULL
		, drmo_hin_num INT NULL
		, drmo_doc_num INT NULL
		, AOC VARCHAR(30) NULL
		, manifest_dot_sp_number VARCHAR(20) NULL
		, normality FLOAT NULL
		, case_number VARCHAR(15) NULL
		, control_number VARCHAR(15) NULL
		, call_number VARCHAR(15) NULL
		, waste_code_uid INT NULL
		, profile_record_type CHAR(1) NULL
		, oxidizer_spot CHAR(1) NULL
		, waste_list_code VARCHAR(15) NULL
		, consent VARCHAR(40) NULL
		, movement_document VARCHAR(40) NULL
		, foreign_permit VARCHAR(40) NULL
		, currency_code CHAR(3) NULL
		, manifest_form_type VARCHAR(1) NULL
		, manifest_consent_flag CHAR(1) NULL
		, profileapprovalimport_uid INT NULL
		, rad_concentration INT NULL
		, loads_until_sample_required INT NULL
		, box_bin_number VARCHAR(20) NULL
		, washout_required_flag CHAR(1) NULL
		, received_rail_flag CHAR(1) NULL
		, transporter_code VARCHAR(15) NULL
		, rail_car_number VARCHAR(25) NULL
		, trucks_per_rail_manifest INT NULL
		, flammability_flag CHAR(1) NULL
		, rail_transporter_code VARCHAR(15) NULL
		, corporate_revenue_classification_uid INT NULL
		, DOT_waste_flag CHAR(1) NULL
		, DOT_shipping_desc_additional VARCHAR(255) NULL
		, activity_derived_from_dose_rate DECIMAL(10,2) NULL
		, tracking_id INT NULL
		, tracking_days INT NULL
		, tracking_bus_days INT NULL
		, tracking_contact VARCHAR(10) NULL
		)

	DROP TABLE IF EXISTS #ReceiptPrice;
	CREATE TABLE #ReceiptPrice (
		company_id INT NULL
		, profit_ctr_id INT NULL
		, receipt_id INT NULL
		, line_id INT NULL
		, price_id INT NULL
		, bill_quantity DECIMAL(15,4) NULL
		, bill_unit_code VARCHAR(4) NULL
		, price MONEY NULL
		, quote_price MONEY NULL
		, quote_id INT NULL
		, quote_sequence_id INT NULL
		, sr_price MONEY NULL
		, sr_type CHAR(1) NULL
		, sr_extended_amt MONEY NULL
		, waste_extended_amt MONEY NULL
		, total_extended_amt MONEY NULL
		, print_on_invoice_flag CHAR(1) NULL
		, added_by VARCHAR(10) NULL
		, modified_by VARCHAR(10) NULL
		, date_added DATETIME NULL
		, date_modified DATETIME NULL
		, bundled_tran_bill_qty_flag VARCHAR(4) NULL
		, bundled_tran_price MONEY NULL
		, bundled_tran_extended_amt MONEY NULL
		, bundled_tran_gl_account_code VARCHAR(32) NULL
		, currency_code CHAR(3) NULL
		)

	DROP TABLE IF EXISTS #Note;
	CREATE TABLE #Note (
		note_id INT NULL
		, note_source VARCHAR(30) NULL
		, company_id INT NULL
		, profit_ctr_id INT NULL
		, note_date DATETIME NULL
		, subject VARCHAR(50) NULL
		, status CHAR(1) NULL
		, note_type VARCHAR(15) NULL
		, note TEXT NULL
		, customer_id INT NULL
		, contact_id INT NULL
		, generator_id INT NULL
		, approval_code VARCHAR(15) NULL
		, profile_id INT NULL
		, receipt_id INT NULL
		, workorder_id INT NULL
		, merchandise_id INT NULL
		, batch_location VARCHAR(15) NULL
		, batch_tracking_num VARCHAR(15) NULL
		, project_id INT NULL
		, project_record_id INT NULL
		, project_sort_id INT NULL
		, contact_type VARCHAR(15) NULL
		, added_by VARCHAR(60) NULL
		, date_added DATETIME NULL
		, modified_by VARCHAR(60) NULL
		, date_modified DATETIME NULL
		, app_source VARCHAR(20) NULL
		, rowguid UNIQUEIDENTIFIER NULL
		, TSDF_approval_id INT NULL
		, quote_id INT NULL
		, salesforce_json_flag CHAR(1) NULL
		)

	DROP TABLE IF EXISTS #ReceiptSubmit;
	CREATE TABLE #ReceiptSubmit (
		company_id INT NULL
		, profit_ctr_id INT NULL
		, receipt_id INT NULL
		, link_required_flag CHAR(1) NULL
		)

	DROP TABLE IF EXISTS #ReceiptDoNotSubmit;
	CREATE TABLE #ReceiptDoNotSubmit (
		company_id INT NULL
		, profit_ctr_id INT NULL
		, receipt_id INT NULL
		, link_required_flag CHAR(1) NULL
		)

	SELECT @profile_fee_effective_date = CONVERT(DATETIME, config_value) 
	FROM plt_ai.dbo.Configuration 
	WHERE config_key = 'Profile_Fee_Receipt_Creation_Start_Date'

	SELECT @profile_fee_grace_days = -1 * CONVERT(INT, config_value) 
	FROM plt_ai.dbo.Configuration 
	WHERE config_key = 'Profile_Fee_Receipt_Creation_Grace_Days'

	SELECT @profile_fee_process_days_for_past_profiles = -1 * CONVERT(INT, config_value) 
	FROM plt_ai.dbo.Configuration 
	WHERE config_key = 'Prevent_Profile_Fee_Receipt_Auto_Generation_processed_More_Than_90_Days_Back'

	--SET @profile_fee_effective_date = '06-24-2024'
	--SET @@profile_fee_grace_days = -7
	SET @profile_fee_process_date = DATEADD(day, @profile_fee_grace_days, CONVERT(DATETIME, CONVERT(DATE, GetDate())))
	SET @profile_fee_process_date_for_past_profiles = DATEADD(day, @profile_fee_process_days_for_past_profiles, CONVERT(DATETIME, CONVERT(DATE, GetDate())))
	SET @profile_id_old = -1
	SET @customer_id_old  = -1 
	SET @company_id_old  = -1
	SET @profit_ctr_id_old = -1
	SET @generator_id = 293186
	SET @submit_status = NULL

	DECLARE csr_profiles CURSOR FAST_FORWARD FOR
	SELECT p.profile_id, IsNull(p.orig_customer_id, p.customer_id) customer_id, pqa.company_id, pqa.profit_ctr_id, IsNull(cb.po_required_flag, 'F') po_required_flag, 
		cb.link_required_flag, p.date_added, p.renewal_date, IsNull(p.renewal_date, p.date_added) process_date, p.source_form_id, 
		IsNull(cb.release_required_flag, 'F') release_required_flag, cb.other_submit_required_flag, c.terms_code, cb.po_validation, cb.release_validation, 
		UPPER(cs.d365_hold_status) d365_hold_status, pc.profile_fee_code_uid, pc.profile_fee_code, pr.product_id, pr.product_code, pr.[description], 
		dbo.fn_get_profilefee_rate (pr.product_code, pr.company_id, pr.profit_ctr_id, IsNull(p.renewal_date, p.date_added))
	FROM Profile p
	JOIN ProfileQuoteApproval pqa ON pqa.profile_id = p.profile_id AND pqa.quote_id = p.quote_id and pqa.primary_facility_flag = 'T'
	JOIN CustomerBilling cb ON cb.customer_id = IsNull(p.orig_customer_id, p.customer_id) AND cb.billing_project_id = 0
	JOIN Customer c ON c.customer_id = IsNull(p.orig_customer_id, p.customer_id)
	LEFT JOIN ProfileFeeCode pc ON pc.profile_fee_code = (CASE WHEN p.source_form_id IS NULL 
																THEN (CASE WHEN p.renewal_date IS NULL THEN 'NewProfile' ELSE 'RenewProfile' END)
																ELSE (CASE WHEN p.renewal_date IS NULL THEN 'CORNew' ELSE 'CORRenewal' END) END)
	JOIN Product pr ON pr.company_id = pqa.company_id AND pr.profit_ctr_id = pqa.profit_ctr_id AND pr.product_code = pc.profile_fee_code
	LEFT JOIN ECOL_D365Integration.dbo.CustomerSync cs ON c.ax_customer_id = cs.d365_accountnum
	LEFT JOIN dbo.ProfileFeeExemption pfe ON pfe.company_id = pqa.company_id AND pfe.profit_ctr_id = pqa.profit_ctr_id AND pfe.profile_fee_code_uid = pc.profile_fee_code_uid AND (pfe.company_id = 68 OR (pfe.company_id = 21 AND pfe.profit_ctr_id = 0))
	WHERE ((p.renewal_date >= IsNull(plt_ai.dbo.fn_get_profile_effective_date(IsNull(p.orig_customer_id, p.customer_id), p.profile_id) , @profile_fee_effective_date) AND p.renewal_date IS NOT NULL) 
				OR p.date_added >= IsNull(plt_ai.dbo.fn_get_profile_effective_date(IsNull(p.orig_customer_id, p.customer_id), p.profile_id), @profile_fee_effective_date))
	AND ((p.renewal_date <= @profile_fee_process_date + 1 AND p.renewal_date IS NOT NULL) OR p.date_added <= @profile_fee_process_date + 1)
	AND (NOT(pqa.company_id = 21 AND pqa.profit_ctr_id = 0) OR (p.renewal_date > pfe.exemption_date AND p.renewal_date IS NOT NULL) OR p.date_added > pfe.exemption_date)
	AND ((p.renewal_date > pfe.exemption_date AND p.renewal_date IS NOT NULL) OR (p.date_added > pfe.exemption_date OR pfe.exemption_date IS NULL))
	AND plt_ai.dbo.fn_get_profilefee(IsNull(p.orig_customer_id, p.customer_id), p.profile_id, IsNull(p.renewal_date,p.date_added)) = 1
	AND (p.import_source IS NULL OR (p.import_source IS NOT NULL AND p.renewal_date IS NOT NULL))
	AND ((p.renewal_date >= @profile_fee_process_date_for_past_profiles AND p.renewal_date IS NOT NULL) OR p.date_added >= @profile_fee_process_date_for_past_profiles)
	AND NOT EXISTS (SELECT 'x'
					FROM plt_ai.dbo.ReceiptProfileFee rpf
					WHERE /*rpf.company_id = pqa.company_id
					AND rpf.profit_ctr_id = pqa.profit_ctr_id
					AND*/ rpf.profile_id = p.profile_id
					AND rpf.profile_processed_date = IsNull(p.renewal_date,p.date_added))
	ORDER BY CASE WHEN p.orig_customer_id IS NULL THEN p.customer_id ELSE p.orig_customer_id END
		, pqa.company_id, pqa.profit_ctr_id, p.profile_id

	OPEN csr_profiles

	FETCH NEXT FROM csr_profiles INTO @profile_id, @customer_id, @company_id, @profit_ctr_id, @po_required_flag, @link_required_flag, @date_added, @renewal_date, @process_date,
									  @source_form_id, @release_required_flag, @other_submit_required_flag, @terms_code, @po_validation_flag, @release_validation_flag, 
									  @d365_hold_status, @profile_fee_code_uid, @profile_fee_code, @product_id, @product_code, @product_description, @profile_fee_rate

	WHILE @@FETCH_STATUS = 0  
	BEGIN
		SET @line_id = 0
		
		IF @customer_id <> @customer_id_old OR @company_id <> @company_id_old OR @profit_ctr_id <> @profit_ctr_id_old
		BEGIN
			SET @note_text_combined = ''
			EXEC @receipt_id = plt_ai.dbo.sp_generate_id @company_id, @profit_ctr_id, 'R', 1

			IF IsNull(@receipt_id, -1) >= 0
			BEGIN				
				-- IF IsNull(@po_required_flag, 'F') <> 'T' and IsNull(@release_required_flag, 'F') <> 'T' and IsNull(@other_submit_required_flag, 'F') <> 'T' and IsNull(@terms_code, 'null') NOT IN ('COD', 'NOADMIT')
				IF (NOT (@po_required_flag = 'T' AND @po_validation_flag = 'E')) AND (NOT(@release_required_flag = 'T' AND @release_validation_flag = 'E')) 
					INSERT INTO #ReceiptSubmit (company_id, profit_ctr_id, receipt_id, link_required_flag) 
					VALUES (@company_id, @profit_ctr_id, @receipt_id, @link_required_flag)
				ELSE
				BEGIN
					INSERT INTO #ReceiptDoNotSubmit (company_id, profit_ctr_id, receipt_id, link_required_flag) 
					VALUES (@company_id, @profit_ctr_id, @receipt_id, @link_required_flag)

					IF @po_required_flag = 'T' AND @po_validation_flag = 'E'
					BEGIN
						SET @note_text = 'Profile Fee created by automated process and requires PO to be added manually.'
						SET @note_text_combined = @note_text
					END

					IF @release_required_flag = 'T' AND @release_validation_flag = 'E'
					BEGIN
						SET @note_text = 'This Customer requires a Release Number. This receipt must be billed manually.'
						IF @note_text_combined > '' 
							SET @note_text_combined += CHAR(13) + @note_text
						ELSE
							SET @note_text_combined	= @note_text	
					END
					
					EXEC plt_ai.dbo.sp_create_note @company_id, @profit_ctr_id, @customer_id, @generator_id, @note_source, @receipt_id, @note_type, 
								                   @note_status, @note_subject, @note_text_combined, @app_source, @note_contact_type, @salesforce_json_flag						
				END

				SET @line_id = 1

				INSERT INTO #ReceiptAudit 
				(company_id, profit_ctr_id, receipt_id, line_id, table_name, column_name, before_value, after_value, audit_reference, modified_by, modified_from, date_modified)
				VALUES (@company_id, @profit_ctr_id, @receipt_id, @line_id, 'RECEIPT', 'receipt_id', '(inserted)', CONVERT(VARCHAR, @receipt_id), 
				       'Profile Fee receipt creation', 'SA', 'SA', GetDate())
			END
		END

		SELECT @count_lines = Count(1) 
		FROM #Receipt 
		WHERE company_id = @company_id 
		AND profit_ctr_id = @profit_ctr_id 
		AND receipt_id = @receipt_id 
		AND product_code = @profile_fee_code

		IF @count_lines > 0
		BEGIN
			SELECT @line_id = line_id 
			FROM #Receipt 
			WHERE company_id = @company_id 
			AND profit_ctr_id = @profit_ctr_id 
			AND receipt_id = @receipt_id 
			AND product_code = @profile_fee_code

			UPDATE #Receipt 
			SET quantity = quantity + 1 
			WHERE company_id = @company_id 
			AND profit_ctr_id = @profit_ctr_id 
			AND receipt_id = @receipt_id 
			AND product_code = @profile_fee_code 
			AND line_id = @line_id
			
			UPDATE #ReceiptPrice 
			SET bill_quantity = bill_quantity + 1, 
				waste_extended_amt = waste_extended_amt + @profile_fee_rate, 
				total_extended_amt = total_extended_amt + @profile_fee_rate 
			WHERE company_id = @company_id and profit_ctr_id = @profit_ctr_id and receipt_id = @receipt_id and line_id = @line_id and price_id = 1
		END
		ELSE
		BEGIN
			SELECT @line_id = count(line_id) + 1 
			FROM #Receipt 
			WHERE company_id = @company_id 
			AND profit_ctr_id = @profit_ctr_id 
			AND receipt_id = @receipt_id
			
			INSERT INTO #Receipt 
			(company_id, profit_ctr_id, receipt_id, line_id, trans_mode, trans_type, receipt_status, fingerpr_status, receipt_date, manifest_flag, manifest, 
			customer_id, generator_id, product_id, product_code, quantity, created_by, date_added, modified_by, date_modified, billing_project_id, bill_unit_code, service_desc, 
			time_in, time_out, currency_code, submitted_flag, manifest_form_type)
			VALUES (@company_id, @profit_ctr_id, @receipt_id, @line_id, 'I', 'S', 'A', 'A', CONVERT(DATETIME, CONVERT(DATE, GetDate())), 'B', CONVERT(VARCHAR, @receipt_id), 
			@customer_id, @generator_id, @product_id, @product_code, 1, 'SA', GetDate(), 'SA', GetDate(), 0, 'EACH', @product_description, 
			GetDate(), DateAdd(Minute, 5, GetDate()), 'USD', 'F', 'N')
			
			INSERT INTO #ReceiptPrice 
			(company_id, profit_ctr_id, receipt_id, line_id, price_id, bill_quantity, bill_unit_code, price, quote_price, quote_sequence_id, sr_price, 
			sr_type, sr_extended_amt, waste_extended_amt, total_extended_amt, print_on_invoice_flag, added_by, modified_by, date_added, date_modified, currency_code)
			VALUES (@company_id, @profit_ctr_id, @receipt_id, @line_id, 1, 1, 'EACH', @profile_fee_rate, @profile_fee_rate, 1, 0, 
			'E', 0, @profile_fee_rate, @profile_fee_rate, 'T', 'SA', 'SA', GetDate(), GetDate(), 'USD')
		END

		INSERT INTO #ReceiptProfileFee 
		(company_id, profit_ctr_id, receipt_id, line_id, profile_fee_code_uid, profile_id, profile_processed_date, added_by, date_added, 
		 modified_by, date_modified)
		VALUES (@company_id, @profit_ctr_id, @receipt_id, @line_id, @profile_fee_code_uid, @profile_id, @process_date, 'SA', GetDate(), 'SA', GetDate())

		SET @customer_id_old = @customer_id
		SET @company_id_old = @company_id
		SET @profit_ctr_id_old = @profit_ctr_id

		FETCH NEXT FROM csr_profiles INTO @profile_id, @customer_id, @company_id, @profit_ctr_id, @po_required_flag, @link_required_flag, @date_added, @renewal_date, 
										  @process_date, @source_form_id, @release_required_flag, @other_submit_required_flag, @terms_code, @po_validation_flag, 
										  @release_validation_flag, @d365_hold_status, @profile_fee_code_uid, @profile_fee_code, @product_id, @product_code, 
										  @product_description, @profile_fee_rate
	END -- cursor loop

	CLOSE csr_profiles

	DEALLOCATE csr_profiles

	BEGIN TRANSACTION

	INSERT INTO plt_ai.dbo.Receipt 
	(company_id, profit_ctr_id, receipt_id, line_id, trans_mode, trans_type, receipt_status, fingerpr_status, receipt_date, manifest_flag, manifest, customer_id, 
	 generator_id, product_id, product_code, quantity, created_by, date_added, modified_by, date_modified, billing_project_id, bill_unit_code, service_desc, 
	 time_in, time_out, currency_code, submitted_flag, manifest_form_type)
	SELECT company_id, profit_ctr_id, receipt_id, line_id, trans_mode, trans_type, receipt_status, fingerpr_status, receipt_date, manifest_flag, manifest, customer_id, 
	generator_id, product_id, product_code, quantity, created_by, date_added, modified_by, date_modified, billing_project_id, bill_unit_code, service_desc, 
	time_in, time_out, currency_code, submitted_flag, manifest_form_type 
	FROM #Receipt

	INSERT INTO plt_ai.dbo.ReceiptPrice 
	(company_id, profit_ctr_id, receipt_id, line_id, price_id, bill_quantity, bill_unit_code, price, quote_price, quote_sequence_id, 
	 sr_price, sr_type, sr_extended_amt, waste_extended_amt, total_extended_amt, print_on_invoice_flag, added_by, modified_by, date_added, date_modified, currency_code)
	SELECT company_id, profit_ctr_id, receipt_id, line_id, price_id, bill_quantity, bill_unit_code, price, quote_price, quote_sequence_id, 
	sr_price, sr_type, sr_extended_amt, waste_extended_amt, total_extended_amt, print_on_invoice_flag, added_by, modified_by, date_added, date_modified, currency_code 
	FROM #ReceiptPrice

	INSERT INTO plt_ai.dbo.Note 
	(rowguid, note_id, note_source, company_id, profit_ctr_id, note_date, [subject], [status], note_type, note, customer_id, generator_id, receipt_id, contact_type, 
	 added_by, date_added, modified_by, date_modified, app_source, salesforce_json_flag)
	SELECT rowguid, note_id, note_source, company_id, profit_ctr_id, note_date, [subject], [status], note_type, note, customer_id, generator_id, receipt_id, contact_type, 
	added_by, date_added, modified_by, date_modified, app_source, salesforce_json_flag 
	FROM #Note

	INSERT INTO plt_ai.dbo.ReceiptAudit 
	(company_id, profit_ctr_id, receipt_id, line_id, table_name, column_name, before_value, after_value, audit_reference, modified_by, modified_from, date_modified)
	SELECT company_id, profit_ctr_id, receipt_id, line_id, table_name, column_name, before_value, after_value, audit_reference, modified_by, modified_from, date_modified 
	FROM #ReceiptAudit

	INSERT INTO plt_ai.dbo.ReceiptProfileFee 
	(company_id, profit_ctr_id, receipt_id, line_id, profile_fee_code_uid, profile_id, profile_processed_date, added_by, date_added, modified_by, date_modified)
	SELECT company_id, profit_ctr_id, receipt_id, line_id, profile_fee_code_uid, profile_id, profile_processed_date, added_by, date_added, modified_by, date_modified 
	FROM #ReceiptProfileFee

	COMMIT TRANSACTION

	DECLARE csr_submit_to_billing CURSOR FAST_FORWARD FOR	
		SELECT DISTINCT company_id, profit_ctr_id, receipt_id, link_required_flag
		FROM #ReceiptSubmit

	OPEN csr_submit_to_billing

	FETCH NEXT FROM csr_submit_to_billing INTO @company_id, @profit_ctr_id, @receipt_id, @link_required_flag

	WHILE @@FETCH_STATUS = 0  
	BEGIN
		SET @submit_date = CONVERT(DATETIME, CONVERT(DATE, GetDate()))
		BEGIN TRANSACTION

		EXEC @return_value = plt_ai.dbo.sp_billing_submit 0, @company_id, @profit_ctr_id, 'R', @receipt_id, @submit_date, @submit_status, 'SA', ''
		IF @return_value = 0
		BEGIN
			UPDATE plt_ai.dbo.Receipt 
			SET receipt_status = 'A' 
			WHERE company_id = @company_id 
			AND profit_ctr_id = @profit_ctr_id 
			AND receipt_id = @receipt_id

			IF @link_required_flag = 'T'
			BEGIN
				INSERT INTO plt_ai.dbo.BillingLinkLookup 
				(trans_source, company_id, profit_ctr_id, receipt_id, billing_link_id, source_type, added_by, date_added, modified_by, date_modified, link_required_flag)
				VALUES ('I', @company_id, @profit_ctr_id, @receipt_id, 0, 'W', 'SA', GetDate(), 'SA', GetDate(), 'E')
					
				INSERT INTO plt_ai.dbo.ReceiptAudit 
				(company_id, profit_ctr_id, receipt_id, line_id, price_id, table_name, column_name, before_value, after_value, modified_by, modified_from, date_modified)
				VALUES (@company_id, @profit_ctr_id, @receipt_id, 0, 0, 'BillingLinkLookup', 'All', '(no record)', '(new record added)', 'SA', 'IR', GetDate())
			END
		END
		ELSE
		BEGIN
			SET @note_text = ''
			-- For @terms_code = 'NOADMIT' AND @d365_hold_status = 'ALL', Submit should be successful, no note is needed. 
			-- For failure in Submit, this should be analyzed and fixed.
			IF ((@terms_code <> 'NOADMIT') AND (@d365_hold_status = 'ALL') OR (@terms_code = 'NOADMIT') AND (@d365_hold_status <> 'ALL'))
			BEGIN				
				IF @terms_code = 'NOADMIT' AND @d365_hold_status <> 'ALL'
					SET @note_text = 'Customer is on NO ADMIT, Credit must be contacted to remove hold to allow submittal.'
				ELSE IF @terms_code <> 'NOADMIT' AND @d365_hold_status = 'ALL'
					SET @note_text = 'Customer is on NO ADMIT, Credit must be contacted to remove hold to allow submittal.'				
			
				IF EXISTS (SELECT 1 FROM plt_ai.dbo.Note 
						   WHERE company_id = @company_id AND profit_ctr_id = @profit_ctr_id AND receipt_id = @receipt_id AND [subject] = @note_subject)
				BEGIN
					UPDATE plt_ai.dbo.Note 
					SET [note] = CAST(CONVERT(VARCHAR(500), [note]) + CHAR(13) + @note_text AS TEXT)
					WHERE company_id = @company_id 
					AND profit_ctr_id = @profit_ctr_id 
					AND receipt_id = @receipt_id 
					AND [subject] = @note_subject
				END
				ELSE
				BEGIN
					EXEC plt_ai.dbo.sp_create_note @company_id, @profit_ctr_id, @customer_id, @generator_id, @note_source, @receipt_id, @note_type, 
													   @note_status, @note_subject, @note_text, @app_source, @note_contact_type, @salesforce_json_flag
				
					INSERT INTO plt_ai.dbo.Note 
					(rowguid, note_id, note_source, company_id, profit_ctr_id, note_date, [subject], [status], note_type, note, customer_id, generator_id, receipt_id, contact_type, 
					 added_by, date_added, modified_by, date_modified, app_source, salesforce_json_flag)
					SELECT rowguid, note_id, note_source, company_id, profit_ctr_id, note_date, [subject], [status], note_type, note, customer_id, generator_id, receipt_id, contact_type, 
					added_by, date_added, modified_by, date_modified, app_source, salesforce_json_flag 
					FROM #Note			
				END	
			END
		END

		COMMIT TRANSACTION

		FETCH NEXT FROM csr_submit_to_billing INTO @company_id, @profit_ctr_id, @receipt_id, @link_required_flag
	END -- cursor loop

	CLOSE csr_submit_to_billing

	DEALLOCATE csr_submit_to_billing

	DECLARE csr_do_not_submit_to_billing CURSOR FAST_FORWARD FOR
		SELECT DISTINCT company_id, profit_ctr_id, receipt_id, link_required_flag
		FROM #ReceiptDoNotSubmit

	OPEN csr_do_not_submit_to_billing

	FETCH NEXT FROM csr_do_not_submit_to_billing INTO @company_id, @profit_ctr_id, @receipt_id, @link_required_flag

	WHILE @@FETCH_STATUS = 0  
	BEGIN
		SET @submit_date = CONVERT(DATETIME, CONVERT(DATE, GetDate()))
		BEGIN TRANSACTION
		IF @link_required_flag = 'T'
		BEGIN
			INSERT INTO plt_ai.dbo.BillingLinkLookup 
			(trans_source, company_id, profit_ctr_id, receipt_id, billing_link_id, source_type, added_by, date_added, modified_by, date_modified, link_required_flag)
			VALUES ('I', @company_id, @profit_ctr_id, @receipt_id, 0, 'W', 'SA', GetDate(), 'SA', GetDate(), 'E')

			INSERT INTO plt_ai.dbo.ReceiptAudit 
			(company_id, profit_ctr_id, receipt_id, line_id, price_id, table_name, column_name, before_value, after_value, modified_by, modified_from, date_modified)
			VALUES (@company_id, @profit_ctr_id, @receipt_id, 0, 0, 'BillingLinkLookup', 'All', '(no record)', '(new record added)', 'SA', 'IR', GetDate())
		END
		COMMIT TRANSACTION
		FETCH NEXT FROM csr_do_not_submit_to_billing INTO @company_id, @profit_ctr_id, @receipt_id, @link_required_flag
	END -- cursor loop

	CLOSE csr_do_not_submit_to_billing

	DEALLOCATE csr_do_not_submit_to_billing
END
GO

GRANT EXECUTE ON dbo.sp_profile_fee_create_receipt TO EQAI
GO
