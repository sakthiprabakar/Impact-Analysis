SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE [dbo].[sp_trip_complete](
	@trip_company_id        INT,
	@trip_profit_ctr_id     INT,
	@trip_ID                INT,
	@complete_tsdf_code	VARCHAR(15),
	@debug                  INT,
	@override_rec_date      DATETIME,
	@override_date_schedule DATETIME,
	@override_time_in       DATETIME,
	@override_time_out      DATETIME,
	@override_truck_code    VARCHAR(10),
	@override_conf_id       INT
)
AS
/*************************************************************************************************
sp_trip_complete
Loads to : PLT_AI

01/25/2009 KAM This procedure will take a trip and renumber the stops (aka workorders) to be
	real workorder numbers and then take the information on the workorders and create
	in-transit receipts from them based on the manifest information.
03/31/2009 KAM Updated the procedure to remove looking for the status of 'X' since workorder_ids are
	being generated before the trip is complete setting the statuses to 'N'
04/06/2009 KAM Updated to read pounds from work order detail and populate the gross and net weight
	on the receipt while setting the tare weight to zero.
04/06/2009 KAM Updated to create an exempt link to the workorder if the workorderheader.waste_flag = 'F'
04/20/2009 KAM Updated to only copy the documents on the first line of the receipt
05/08/2009 KAM Updated the receipt cursor to order by stop_id instead of Workorder_id
05/08/2009 KAM Updated to create receipt for status of N, C, A, or X
05/08/2009 KAM Updated to only copy over the documents where the document name = manifest
05/12/2009 JDB Added ERG_suffix
06/09/2009 KAM Updated to check for an exempt link before writing one out
06/29/2009 KAM Fixed an issue where the transporters were being written out with reversed sequence numbers.
07/06/2009 KAM Updated to handle the new tables WorkOrderDetailCC and WorkOrderDetailUnit.
07/23/2009 KAM Updated the procedure to only copy the documents that match the manifest number to receipts
08/06/2009 KAM Updated to only create receipt using the billing records with a billing unit
08/17/2009 KAM Updated the procedure to properly set the bulk flag.
09/04/2009 KAM Initialized the pricing variables before each pricing routine.
09/10/2009 KAM Updated the procedure to no longer update the status of the Workorder to 'N' when completing
	a trip unless the status is 'X'.
--??/??/2009 KAM Updated to record the trip and sequence number onto the receipt (new fields added)
09/11/2009 KAM Updated the procedure to only complete for a passed company/PC combination.
09/16/2009 KAM Updated to set the third_party_complete_flag in Trip Header
10/06/2009 KAM Update the query to see if he trip is complete
11/13/2009 KAM Update the receipt audit to contine the trip_id
11/13/2009 KAM Update to not include the no waste pickups in final count
11/15/2009 KAM Update the procedure to ignore voided workorders
01/19/2010 KAM Updated to allow the use of Override information for the created receipts
01/25/2010 KAM Updated to not load the time into the receipt date column
02/10/2010 KAM Updated to only accept trips in the status of 'U'
03/11/2010 KAM Updated to not reset the sr_type before writing out the pricing lines for receipt.
03/15/2010 KAM Updated the procedure to only create receipt price records for bill_units that exist on the quote
03/16/2010 KAM Updated to create receipt lines only if the WOD.quantity_used > 0
03/17/2010 KAM Updated to create receipt lines only if the WOD.quantity_used > 0 (Removed Code until we fix the Non-Primary Unit Issue)
03/23/2010 KAM Updated the copying of images to include the three new fields and changed the source to 'receipt'
06/14/2010 KAM Updated to always set the bulk_flag to 'F' because you can't pick up bulk on trips
11/02/2010 KAM Updated for he renaming of bill_quantity to quantity
11/18/2010 KAM Updated to add the creation of a ReceiptHeader Row
12/17/2010 KAM Updted to populate the receiptitem table and update the rows for pounds with decimals
	and ounces to just a decimal pounds value
02/21/2011 JDB Updated to get the @hauler and insert into ReceiptTransporter properly; that is,
	using the @link_workorder_id instead of @workorder_id
	Also changed the line_weight population to use the @pounds instead of sums of
	WorkOrderDetailItem records.
02/22/2011 JDB Updated to not store the pounds value into Receipt or ReceiptHeader gross_weight or net_weight
03/03/2011 JPB Updated 16/ounces logic to ounces/16. You want 4/16th of a pound to equal 4 ounces... not 16/4 (4lbs).
03/07/2011 RWB When inserting record into Receipt, round manifest_quantity
03/10/2011 RWB @tot_quantity was defined as int, needs to keep decimal amount,
	made sure @receipt_id is not null when determining whether one needs to be generated or not
04/22/2011 RWB Added error checking after call to sp_generate_id to catch errors while generating new Receipt ID. While
		in here, added "for read only" to all cursors to reduce lock contention and increase performance.
10/26/2011 RWB Fixed 2 problems: one was ignoring the WorkOrderStop.waste_flag equal to 'F' when counting
		the numer of receipts that should have been generated. The other was not setting the
		trip status to Complete until all TSDFs have been processed
09/04/2012 RWB Added support for Lab Packs from the MIM (ReceiptDetailItem, ReceiptWasteCode and ReceiptConstituent)
09/06/2012 RWB Added check for 3rd party disposals not yet completed (before setting status to 'C')
09/14/2012 JDB	Added code to make the waste code primary if there is only one of them, and it's not marked primary already
				This would occur when the profile had many state waste codes and NONE, but neither the generator nor the TSDF
				were in those states.  It would previously just insert the NONE waste code, but leave it as sequence_id = 2 
				or some other number, and not make it the primary.
10/01/2012 RWB Added a check against new table TripCompleteExcludeWasteCode to allow the exclusion of WasteCodes when populating
		the ReceiptWasteCode table if the stop date is earlier than a specified date
11/08/2012 RWB Completions will now be process by TSDF argument instead of by Facility
11/15/2012 RWB Fixed a bug where @waste_flag was checked for 'T', but it was empty string (and isnull() defaults to 'T').
		Also corrected count of uncompleted receipts to manage null company_id and profit_ctr_id in BillingLinkLookup
12/21/2012 RWB Put extra logic to ensure ReceiptWasteCode will have a primary waste code set with sequence_id = 1
03/28/2013 RWB Removed special logic added 10/01/2012 for the Walmart Aerosol approval waste code change (a trip was accidentally completed
				with incorrect arrive dates, which as a result sent the wrong list of waste codes to the receipts)
03/29/2013 RWB Added waste_code_uid column to ReceiptWasteCode insert. Also qualified insert statement with column names.
08/23/2013 RWB Added waste_code_uid column to Receipt insert (should have been done when ReceiptWasteCode was)
09/13/2013 RWB Modified how ReceiptWasteCode is populated (include WorkOrderWasteCode codes, and populate top6 from those)
10/09/2013 RWB Trip Receiving enahancements: Automatically generate stock containers, and save Receipts with status of Lab or Unloading.
12/04/2013 RWB Bug fix...completing a trip with split CCIDs and not using autogenerate was creating duplicate receipt lines
12/04/2013 RWB Add oxidizer_spot to Receipt insert
02/26/2015 RWB Users reported Trip Complete started throwing errors...min_concentration had been added to ReceiptConstituent
04/20/2015 RWB modified to support Kroger Invoicing requirements (pull customer_id from profile, don't link work order and receipt if trip_stop_rate_flag=T)
05/04/2015 RWB discovered bug when trip complete leaves trip in Uncomplete status when it has actually been completed. The Approve for Completion popup
               does not offer TSDFs with zero valid approvals, but the check at the end simply counted number of distinct TSDFs. Added offset to count
05/06/2015 RWB The fix deployed on 05/04 had a bug that did not show itself until a trip with 3 distinct TSDFs was completed...the subquery to determine
               the number of TSDFs that should be ignored was incorrent. It was looking for all with no quantities, instead of all in void status.
12/02/2015 RWB When determining final trip status, include all TSDFs (commented out making sure at least one approval with bill_status > -2)
02/10/2016 RWB GEM:36095 Remove requirement that TSDFs without disposal waste need to be completed
08/24/2017 RWB After an NTSQL1 system crash, trip complete started going to lunch and not completing. Added WITH RECOMPILE in case this is index/procedure cache related
05/09/2018 MPM Modified to create ReceiptWasteCode rows by using functions fn_tbl_manifest_waste_codes and fn_tbl_manifest_waste_codes_receipt_wo.
05/21/2018 RWB GEM:50759 - Calculate waste_extended_amt, sr_extended_amt and total_extended_amt when inserting into ReceiptPrice
06/22/2018 RWB GEM:51574 - Set transaction isolation level so queried tables will not be locked while executing
07/10/2018 MPM GEM 51874 - Modified to set the Receipt.manifest_form_type to WorkOrderManifest.manifest_state. I also removed 
               the name of the named transaction because rollback wasn't working when an error occurred.
12/04/2018 MPM GEM 57107 - Modified so that for each manifest that results in a receipt, a row is inserted into ReceiptManifest for each manifest page
               with the generator sign fields populated from WorkOrderManifest's generator sign fields. 
7/26/2019   RB SA-13302 Duplicate ReceiptConstituent for LabPack	
05/07/2020 MPM DevOps 15456 - Added logic to set corporate_revenue_classification_uid in new receipt lines. MPM
11/04/2020 AM DevOps:17664 - Added distinct to the Lab Pack Flag = 'T' sql 
09/24/2021 MPM DevOps 28861 - Added the column list to the inserts into ReceiptConstituent.
02/17/2022 MPM DevOps 30172 - Modified to set DOT_shipping_desc_additional and DOT_waste_flag in new receipt lines.
02/21/2022 MPM DevOps 30172 - Correction.
03/04/2022 MPM DevOps 38512 - Changed the datatype of @manifest_line from TINYINT to INT.
04/13/2022 MPM DevOps 39385 - Modified so that the count of uncompleted TSDF's near the end of the proc includes any TSDF's which have only voided disposal lines, 
               and this should prevent the trip itself from being completed prematurely, as in ME 118198.
06/05/2023 MPM DevOps 61953 - Undid the change made under 39385 and modified the EQAI "Approve for Completion" and "Complete" popup windows in the EQAI Trip window 
               so that they do not display TSDF's that do not have waste.  Together these changes should fix the issue in 39385 and also 61953.
09/18/2023 MPM DevOps 72879	- Modified receipt constituent assignment logic.
04/10/2024 KS  DevOps 78209 - Added schema reference, formatting update, and OPTIMIZE FOR UNKNOWN for better perfromance with peramiter sniffing
04/26/2024 KS  INC1255140 - Fixed the wrong call to sp_trip_complete_generate_stock_containers.

sp_trip_complete 14,0,5773,21,0,1,'2/17/11', NULL, '2/17/11 23:28', '2/17/11 23:59', '131', NULL
sp_trip_uncomplete 5773, 'JASON_B', 21, 0, 1

sp_trip_complete 14,0,1985,21,0,1,'03/15/2010', '03/15/2010', '03/15/2010', '03/15/2010', '234we',435435

sp_trip_uncomplete 1985,'jason_b',1
sp_trip_uncomplete 310,'jason_b',1

select * from workorderheader where trip_id = 310
sp_trip_uncomplete 5773, 'SA-FIX', 21,0,1
sp_helptext sp_trip_uncomplete

execute dbo.sp_trip_complete 
	@trip_company_id =14 , 
	@trip_profit_ctr_id =6 , 
	@trip_id =2189 , 
	@complete_company_id =21 , 
	@complete_profit_ctr_id =0 , 
	@debug =1 , 
	@override_rec_date ='2-8-2010 0:0:0.000' , 
	@override_date_schedule ='2-8-2010 7:30:0.000' , 
	@override_time_in ='2-8-2010 7:0:0.000' , 
	@override_time_out ='2-8-2010 8:0:0.000' , 
	@override_truck_code ='55' , 
	@override_conf_id =245571
	
*************************************************************************************************/
-- Declare Variables
DECLARE @company_id INT
	,@id_qty INT
	,@new_workorder_id INT
	,@profit_ctr_id INT
	,@rows INT
	,@workorder_id INT
	,@manifest VARCHAR(15)
	,@receipt_status CHAR(1)
	,@customer INT
	,@receipt_company_id INT
	,@receipt_profit_ctr_id INT
	,@link_company_id INT
	,@link_profit_ctr_id INT
	,@link_workorder_id INT
	,@link_count INT
	,@manifest_flag CHAR(1)
	,@generator INT
	,@zero FLOAT
	,@true CHAR(1)
	,@false CHAR(1)
	,@unknown CHAR(1)
	,@receipt_id INT
	,@user VARCHAR(15)
	,@tsdf_code VARCHAR(15)
	,@save_date DATETIME
	,@billing_project_id INT
	,@billing_project_id2 INT
	,@purchase_ORDER VARCHAR(20)
	,@purchase_order2 VARCHAR(20)
	,@release_code VARCHAR(20)
	,@release_code2 VARCHAR(20)
	,@po_sequence_id INT
	,@po_sequence_id2 INT
	,@quantity FLOAT
	,@tsdf_approval_code VARCHAR(40)
	,@manifest_page_num INT
	,@manifest_line INT
	,@manifest_line_id CHAR(1)
	,@container_count FLOAT
	,@container_code VARCHAR(15)
	,@manifest_quantity FLOAT
	,@manifest_unit VARCHAR(4)
	,@profile_id INT
	,@dot_shipping_name VARCHAR(255)
	,@dot_shipping_name2 VARCHAR(255)
	,@waste_code VARCHAR(4)
	,@waste_code2 VARCHAR(4)
	,@management_code VARCHAR(4)
	,@reportable_quantity_flag CHAR(1)
	,@reportable_quantity_flag2 CHAR(1)
	,@rq_reason VARCHAR(50)
	,@rq_reason2 VARCHAR(50)
	,@hazmat CHAR(1)
	,@hazmat2 CHAR(1)
	,@hazmat_class VARCHAR(15)
	,@hazmat_class2 VARCHAR(15)
	,@subsidiary_haz_mat_class VARCHAR(15)
	,@subsidiary_haz_mat_class2 VARCHAR(15)
	,@un_na_flag CHAR(2)
	,@un_na_flag2 CHAR(2)
	,@un_na_number INT
	,@un_na_number2 INT
	,@package_group VARCHAR(3)
	,@package_group2 VARCHAR(3)
	,@ERG_number INT
	,@ERG_number2 INT
	,@ERG_suffix CHAR(2)
	,@ERG_suffix2 CHAR(2)
	,@drmo_clin_num INT
	,@drmo_hin_num INT
	,@drmo_doc_num INT
	,@transporter_code VARCHAR(15)
	,@transporter_sign_date DATETIME
	,@continuation_flag CHAR(1)
	,@hauler VARCHAR(15)
	,@epa_id VARCHAR(12)
	,@transporter_name VARCHAR(40)
	,@transporter_epa_id VARCHAR(15)
	,@transporter_sign_name VARCHAR(40)
	,@start_date DATETIME
	,@ccvoc FLOAT
	,@ddvoc FLOAT
	,@treatment_id INT
	,@gl_account_code VARCHAR(32)
	,@location VARCHAR(15)
	,@location_type CHAR(1)
	,@fingerprint_type VARCHAR(15)
	,@fingerprint_status CHAR(1)
	,@data_complete_flag CHAR(1)
	,@terms_code VARCHAR(8)
	,@tender_type CHAR(1)
	,@bill_unit_code VARCHAR(4)
	,@line_id INT
	,@gl_account_type VARCHAR(2)
	,@trip_sequence_id INT
	,@link_req_flag CHAR(1)
	,@old_manifest VARCHAR(15)
	,@old_customer INT
	,@old_receipt_company_id INT
	,@old_receipt_profit_ctr_id INT
	,@old_link_company_id INT
	,@old_link_profit_ctr_id INT
	,@old_link_workorder_id INT
	,@old_manifest_flag CHAR(1)
	,@return_code INT
	,@error_code INT
	,@invoice_comment1 VARCHAR(80)
	,@invoice_comment2 VARCHAR(80)
	,@invoice_comment3 VARCHAR(80)
	,@invoice_comment4 VARCHAR(80)
	,@invoice_comment5 VARCHAR(80)
	,@price_id INT
	,@price MONEY
	,@quote_id INT
	,@quote_sequence_id INT
	,@sr_price MONEY
	,@sr_extended_amt MONEY
	,@waste_extended_amt MONEY
	,@total_extended_amt MONEY
	,@print_on_invoice_flag CHAR(1)
	,@user2_pos INT
	,@quote_price FLOAT
	,@bulk_flag CHAR(1)
	,@container_flag CHAR(1)
	,@sr_type CHAR(1)
	,@surcharge_flag CHAR(1)
	,@current_date DATETIME
	,@trip_status CHAR(1)
	,@billing_link_id INT
	,@pounds FLOAT
	,@waste_flag CHAR(1)
	,@image_company_id INT
	,@image_profit_ctr_id INT
	,@image_image_id INT
	,@image_document_source VARCHAR(30)
	,@image_type_id INT
	,@image_status CHAR(1)
	,@image_document_name VARCHAR(50)
	,@image_customer_id INT
	,@image_manifest VARCHAR(15)
	,@image_manifest_flag CHAR(1)
	,@image_approval_code VARCHAR(15)
	,@image_workorder_id INT
	,@image_generator_id INT
	,@image_invoice_print_flag CHAR(1)
	,@image_image_resolution INT
	,@image_scan_file VARCHAR(255)
	,@image_description VARCHAR(255)
	,@image_form_id INT
	,@image_revision_id INT
	,@image_form_version_id INT
	,@image_form_type VARCHAR(10)
	,@image_file_type VARCHAR(10)
	,@image_profile_id INT
	,@image_page_number INT
	,@image_print_in_file CHAR(1)
	,@image_view_on_web CHAR(1)
	,@image_app_source VARCHAR(20)
	,@image_merchandise_id INT
	,@image_trip_id INT
	,@image_batch_id INT
	,@image_TSDF_code VARCHAR(15)
	,@image_TSDF_approval_id INT
	,@new_type INT
	,@stop_id INT
	,@link_written CHAR(1)
	,@transporter_sequence INT
	,@price_count INT
	,@tot_quantity FLOAT
	,-- rb 03/10/2011
	@wod_sequence_id INT
	,@ll_count INT
	,@error_msg VARCHAR(200)
	,@receipt_date DATETIME
	,@line_weight FLOAT
	,@lab_pack_flag CHAR(1)
	,@rowcount INT
	,@sequence_id INT
	,@primary_flag CHAR(1)
	,@count INT
	,@waste_code_uid2 INT
	,@rec_top6_seq_id INT
	,@wc_id INT
	,@generate_stock_container CHAR(1)
	,@dest_cc_id INT
	,@in_the_lab_count INT
	,@oxidizer_spot CHAR(1)
	,@trip_stop_rate_flag CHAR(1)
	,@manifest_state VARCHAR(2)
	,@generator_sign_name VARCHAR(40)
	,@generator_sign_date DATETIME
	,@last_manifest_page_num INT
	,@corporate_revenue_classification_uid INT
	,@DOT_shipping_desc_additional VARCHAR(255)
	,@DOT_waste_flag CHAR(1)
	,@profile_labpack_flag CHAR(1)

SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

-- Initialize Variables
SELECT @receipt_status = 'T'
	,@zero = 0
	,@true = 'T'
	,@false = 'F'
	,@unknown = 'U'
	,@link_written = 'F'
	,@save_date = GetDate()
	,@current_date = Cast(CONVERT(VARCHAR(10), GetDate(), 111) AS DATETIME)
	,@user = rTrim(lTrim(Upper(SYSTEM_USER)))
	,@user2_pos = CharIndex('(2)', rTrim(lTrim(Upper(SYSTEM_USER))))
	,@line_id = 1
	,@return_code = 1
	,@old_manifest = ''
	,@old_customer = 0
	,@old_receipt_company_id = 0
	,@old_receipt_profit_ctr_id = - 1
	,@old_link_company_id = - 1
	,@old_link_profit_ctr_id = - 1
	,@old_link_workorder_id = - 1
	,@old_manifest_flag = ''
	,@price_id = 1
	,@trip_stop_rate_flag = 'F'

IF @user2_pos > 0
	SET @user = LEFT(@user, @user2_pos - 1)

-- **************************************************************************************
-- Lets start the transaction
-- **************************************************************************************
BEGIN TRANSACTION --trip_convert

-- **************************************************************************************
-- Make Sure the Trip is in 'D'ispatched status
-- **************************************************************************************
SELECT @trip_status = trip_status
	,@lab_pack_flag = isnull(lab_pack_flag, 'F')
FROM dbo.tripheader
WHERE trip_id = @trip_id

IF @debug = 1
BEGIN
	PRINT 'Trip Status = ' + @trip_status
	PRINT 'Lab Pack flag = ' + @lab_pack_flag
END

IF (@trip_status <> 'U')
BEGIN
	SET @return_code = - 2

	GOTO exit_or_error
END

-- **************************************************************************************
-- Lets make sure that there are workorders
-- **************************************************************************************
SELECT @rows = Count(*)
FROM dbo.workorderheader
WHERE company_id = @trip_company_id
	AND profit_ctr_id = @trip_profit_ctr_id
	AND trip_id = @trip_id
	AND workorderheader.workorder_status <> 'V'

IF @debug = 1
	PRINT 'Stop Count = ' + CONVERT(VARCHAR, @rows)

IF @rows = 0
	SET @return_code = 0

IF @rows > 0
BEGIN
	-- *************************************************************************************
	-- First update the workorders that are in the status of 'X' and set the status to 'N'
	-- *************************************************************************************
	-- Define and open a cursor to get each workorder and put the real ID on its rows
	DECLARE workorderhead_info CURSOR FAST_FORWARD
	FOR
	SELECT workorder_id
		,trip_sequence_id
	FROM dbo.workorderheader
	WHERE company_id = @trip_company_id
		AND profit_ctr_id = @trip_profit_ctr_id
		AND trip_id = @trip_id
		AND workorder_status = 'X'
	OPTION (OPTIMIZE FOR UNKNOWN)
	--FOR READ ONLY -- rb 04/22/2011 --WITH(NOLOCK)?

	OPEN workorderhead_info

	FETCH workorderhead_info
	INTO @workorder_id
		,@trip_sequence_id

	WHILE @@FETCH_STATUS = 0
	BEGIN
		IF @debug = 1
			PRINT 'Old Workorder ID = ' + CONVERT(VARCHAR, @workorder_id)

		UPDATE dbo.workorderheader
		SET workorder_status = 'N'
		WHERE workorder_id = @workorder_id
			AND company_id = @trip_company_id
			AND profit_ctr_id = @trip_profit_ctr_id
			AND workorder_status = 'X'

		-- goto next row
		FETCH workorderhead_info
		INTO @workorder_id
			,@trip_sequence_id
	END

	CLOSE workorderhead_info

	DEALLOCATE workorderhead_info

	-- *************************************************************************************
	-- Lets handle the Third Party Disposal if the complete_company and complete_profit_ctr_id
	-- Are both '999'
	-- *************************************************************************************

	-- rb 11/08/2012 Record that TSDF was completed if it's a 3rd Party (no receipts are generated).
	--			When all 3rd Party TSDFs have been completed, update the third_party_complete_flag.
	IF EXISTS (
			SELECT 1
			FROM dbo.TripCompleteTSDF
			WHERE trip_id = @trip_id
				AND tsdf_code = @complete_tsdf_code
				AND STATUS = 'C'
			)
	BEGIN
		IF @debug = 1
			PRINT 'TSDF has already been completed.'

		SET @return_code = - 1

		GOTO exit_or_error
	END

	-- Update TripCompleteTSDF to a status of Complete
	UPDATE dbo.TripCompleteTSDF
	SET STATUS = 'C'
		,modified_by = @user
		,date_modified = @save_date
	WHERE trip_id = @trip_id
		AND tsdf_code = @complete_tsdf_code

	-- Check for Error
	SELECT @error_code = @@ERROR

	IF (@error_code <> 0)
	BEGIN
		IF @debug = 1
			PRINT 'Error updating into TripCompleteTSDF'

		SET @return_code = - 1

		GOTO exit_or_error
	END

	IF EXISTS (
			SELECT 1
			FROM TSDF
			WHERE tsdf_code = @complete_tsdf_code
				AND isnull(eq_flag, 'F') = 'F'
			)
		AND NOT EXISTS (
			SELECT 1
			FROM dbo.WorkOrderHeader AS woh
			JOIN dbo.WorkOrderDetail AS wod 
				ON woh.workorder_id = wod.workorder_id
				AND woh.company_id = wod.company_id
				AND woh.profit_ctr_id = wod.profit_ctr_id
				AND wod.resource_type = 'D'
				AND wod.bill_rate > - 2
				AND wod.tsdf_code <> @complete_tsdf_code
			JOIN dbo.TSDF AS t 
				ON wod.tsdf_code = t.tsdf_code
				AND isnull(t.eq_flag, 'F') = 'F'
			WHERE woh.trip_id = @trip_id
				AND NOT EXISTS (
					SELECT 1
					FROM dbo.TripCompleteTSDF
					WHERE trip_id = woh.trip_id
						AND tsdf_code = wod.tsdf_code
						AND STATUS = 'C'
					)
			)
	BEGIN
		UPDATE dbo.tripheader
		SET third_party_complete_flag = 'T'
		WHERE trip_id = @trip_id

		SELECT @error_code = @@ERROR

		IF (@error_code <> 0)
		BEGIN
			SET @return_code = - 1

			GOTO exit_or_error
		END
		ELSE
		BEGIN
			SET @return_code = 0

			GOTO exit_or_error
		END
	END

	-- rb 11/08/2012 end
	-- *************************************************************************************
	-- Second, Get a list of manifests that have been created from the workorders so that
	-- we can create a seperate receipt for each manifest. Only get manifest for disposals
	-- brought into EQ facilities
	-- *************************************************************************************
	DECLARE manifest_info CURSOR FAST_FORWARD
	FOR
	SELECT DISTINCT wo.company_id
		,wo.profit_ctr_id
		,wod.manifest
		,tsdf.tsdf_code
		,wom.generator_sign_name
		,wom.generator_sign_date
	FROM dbo.workorderheader AS wo
	INNER JOIN dbo.workorderdetail AS wod 
		ON wo.company_id = wod.company_id
		AND wo.profit_ctr_id = wod.profit_ctr_id
		AND wo.workorder_id = wod.workorder_id
	INNER JOIN dbo.workordermanifest AS wom 
		ON wod.company_id = wom.company_id
		AND wod.profit_ctr_id = wom.profit_ctr_id
		AND wod.workorder_id = wom.workorder_id
		AND wod.manifest = wom.manifest
	INNER JOIN dbo.tsdf AS tsdf ON wod.tsdf_code = tsdf.tsdf_code
	WHERE wo.workorder_status IN (
			'N'
			,'C'
			,'A'
			)
		AND wod.resource_type = 'D'
		AND IsNull(tsdf.eq_flag, 'F') = 'T'
		AND tsdf.tsdf_status = 'A'
		AND wo.trip_id = @trip_id
		AND wo.company_id = @trip_company_id
		AND wo.profit_ctr_id = @trip_profit_ctr_id
		AND wod.bill_rate <> - 2
		AND wod.tsdf_code = @complete_tsdf_code
	OPTION (OPTIMIZE FOR UNKNOWN)
	--FOR READ ONLY -- rb 04/22/2011

	OPEN manifest_info

	FETCH manifest_info
	INTO @company_id
		,@profit_ctr_id
		,@manifest
		,@tsdf_code
		,@generator_sign_name
		,@generator_sign_date

	SET @link_written = 'F'

	WHILE @@FETCH_STATUS = 0
	BEGIN
		-- Reset @last_manifest_page_num
		SET @last_manifest_page_num = 0

		IF @debug = 1
		BEGIN
			PRINT 'manifest = ' + @manifest + ' / ' + @tsdf_code
			PRINT '@generator_sign_name = ' + @generator_sign_name
			PRINT '@generator_sign_date = ' + Cast(@generator_sign_date AS VARCHAR)
		END

		-- *************************************************************************************
		-- Third
		-- For each manifest/TSDF, create a new, in-transit receipt
		-- *************************************************************************************
		DECLARE receipt_info CURSOR FAST_FORWARD
		FOR
		SELECT DISTINCT wo.company_id
			,wo.profit_ctr_id
			,wo.workorder_id
			,
			--rb 04/20/2015 wo.customer_id,
			CASE 
				WHEN isnull(tsdf.eq_flag, '') = 'T'
					THEN p.customer_id
				ELSE ta.customer_id
				END
			,isnull(wo.trip_stop_rate_flag, 'F')
			,wod.manifest
			,CASE 
				WHEN IsNull(wom.manifest_flag, 'F') = 'T'
					THEN 'M'
				ELSE 'B'
				END
			,tsdf.eq_company AS destination_company_id
			,tsdf.eq_profit_ctr AS destination_profit_ctr_id
			,wo.generator_id
			,wo.billing_project_id
			,wo.purchase_order
			,wo.release_code
			,wo.po_sequence_id
			,wod.quantity_used
			,wod.tsdf_approval_code
			,wod.manifest_page_num
			,wod.manifest_line
			,wod.manifest_line_id
			,wod.container_count
			,wod.container_code
			,wodum.quantity
			,bu.manifest_unit
			,wod.profile_id
			,wod.dot_shipping_name
			,wowc.waste_code
			,wod.management_code
			,wod.reportable_quantity_flag
			,wod.rq_reason
			,wod.hazmat
			,wod.hazmat_class
			,wod.subsidiary_haz_mat_class
			,wod.un_na_flag
			,wod.un_na_number
			,wod.package_group
			,wod.erg_number
			,wod.erg_suffix
			,wod.drmo_clin_num
			,wod.drmo_hin_num
			,wod.drmo_doc_num
			,wom.continuation_flag
			,generator.epa_id
			,wod.tsdf_approval_code
			,wo.start_date
			,wo.invoice_comment_1
			,wo.invoice_comment_2
			,wo.invoice_comment_3
			,wo.invoice_comment_4
			,wo.invoice_comment_5
			,wodup.quantity
			,wos.waste_flag
			,wo.trip_sequence_id
			,wod.sequence_id
			,(
				SELECT max(isnull(generate_stock_container_flag, 'F'))
				FROM workorderdetailcc
				WHERE workorder_id = wod.workorder_id
					AND company_id = wod.company_id
					AND profit_ctr_id = wod.profit_ctr_id
					AND sequence_id = wod.sequence_id
				) AS generate_stock_container_flag
			,(
				SELECT max(isnull(destination_container_id, 0))
				FROM workorderdetailcc
				WHERE workorder_id = wod.workorder_id
					AND company_id = wod.company_id
					AND profit_ctr_id = wod.profit_ctr_id
					AND sequence_id = wod.sequence_id
				) AS destination_container_id
			,(
				SELECT count(*)
				FROM dbo.workorderdetail AS wd2(NOLOCK)
				JOIN dbo.workorderheader AS wh2(NOLOCK) 
					ON wd2.workorder_id = wh2.workorder_id
					AND wd2.company_id = wh2.company_id
					AND wd2.profit_ctr_id = wh2.profit_ctr_id
					AND wh2.workorder_status IN (
						'N'
						,'C'
						,'A'
						)
					AND wh2.trip_id = @trip_id
					AND wh2.company_id = @trip_company_id
					AND wh2.profit_ctr_id = @trip_profit_ctr_id
				JOIN dbo.profilequoteapproval AS pqa2(NOLOCK) 
					ON wd2.profile_id = pqa2.profile_id
					AND wd2.profile_company_id = pqa2.company_id
					AND wd2.profile_profit_ctr_id = pqa2.profit_ctr_id
					AND isnull(pqa2.fingerprint_type, '') <> 'NONE'
				WHERE wd2.manifest = @manifest
					AND wd2.tsdf_code = @tsdf_code
					AND wd2.bill_rate <> - 2
				) AS in_the_lab_count
			,ISNULL(wom.manifest_state, '')
			,wo.corporate_revenue_classification_uid
			,wod.DOT_shipping_desc_additional
			,wod.DOT_waste_flag
			,ISNULL(p.labpack_flag, 'F')
		FROM dbo.workorderheader AS wo
		INNER JOIN workorderdetail AS wod 
			ON wo.company_id = wod.company_id
			AND wo.profit_ctr_id = wod.profit_ctr_id
			AND wo.workorder_id = wod.workorder_id
		LEFT OUTER JOIN dbo.workorderstop AS wos 
			ON wo.company_id = wos.company_id
			AND wo.profit_ctr_id = wos.profit_ctr_id
			AND wo.workorder_id = wos.workorder_id
			AND wos.stop_sequence_id = 1
		INNER JOIN dbo.workordermanifest AS wom 
			ON wod.company_id = wom.company_id
			AND wod.profit_ctr_id = wom.profit_ctr_id
			AND wod.workorder_id = wom.workorder_id
			AND wod.manifest = wom.manifest
		LEFT OUTER JOIN dbo.tsdf 
			ON wod.tsdf_code = tsdf.tsdf_code
			AND tsdf.tsdf_status = 'A'
		LEFT OUTER JOIN dbo.generator 
			ON wo.generator_id = generator.generator_id
		LEFT OUTER JOIN dbo.workorderdetailunit AS wodum 
			ON wodum.company_id = wod.company_id
			AND wodum.profit_ctr_id = wod.profit_ctr_id
			AND wodum.workorder_id = wod.workorder_id
			AND wodum.sequence_id = wod.sequence_id
			AND wodum.manifest_flag = 'T'
		LEFT OUTER JOIN dbo.billunit AS bu 
			ON wodum.bill_unit_code = bu.bill_unit_code
		LEFT OUTER JOIN dbo.workorderwastecode AS wowc 
			ON wowc.company_id = wod.company_id
			AND wowc.profit_ctr_id = wod.profit_ctr_id
			AND wowc.workorder_id = wod.workorder_id
			AND wowc.workorder_sequence_id = wod.sequence_id
			AND wowc.sequence_id = 1
		LEFT OUTER JOIN dbo.workorderdetailunit AS wodup 
			ON wodup.company_id = wod.company_id
			AND wodup.profit_ctr_id = wod.profit_ctr_id
			AND wodup.workorder_id = wod.workorder_id
			AND wodup.sequence_id = wod.sequence_id
			AND wodup.bill_unit_code = 'LBS'
		--rb 04/20/2015
		LEFT OUTER JOIN dbo.[Profile] AS p 
			ON wod.profile_id = p.profile_id
		LEFT OUTER JOIN dbo.TSDFApproval AS ta 
			ON wod.tsdf_approval_id = ta.tsdf_approval_id
		WHERE wo.workorder_status IN (
				'N'
				,'C'
				,'A'
				)
			AND wod.manifest = @manifest
			AND wod.tsdf_code = @tsdf_code
			AND wo.trip_id = @trip_id
			AND wo.company_id = @trip_company_id
			AND wo.profit_ctr_id = @trip_profit_ctr_id
			AND wod.bill_rate <> - 2
			-- rb 11/08/2012 Complete now processes by TSDF
			--					AND tsdf.eq_company = @complete_company_id
			--					AND tsdf.eq_profit_ctr = @complete_profit_ctr_id
			AND wod.tsdf_code = @complete_tsdf_code
		ORDER BY wo.company_id
			,wo.profit_ctr_id
			,wo.trip_sequence_id
			,
			--rb 04/20/2015
			--wo.customer_id,
			CASE 
				WHEN isnull(tsdf.eq_flag, '') = 'T'
					THEN p.customer_id
				ELSE ta.customer_id
				END
			,isnull(wo.trip_stop_rate_flag, 'F')
			,wod.manifest
			,CASE 
				WHEN IsNull(wom.manifest_flag, 'F') = 'T'
					THEN 'M'
				ELSE 'B'
				END
			,tsdf.eq_company
			,tsdf.eq_profit_ctr
			,wod.manifest_page_num
			,wod.manifest_line
		OPTION (OPTIMIZE FOR UNKNOWN)
		--FOR READ ONLY -- rb 04/22/2011 --WITH(NOLOCK)?

		OPEN receipt_info

		FETCH receipt_info
		INTO @link_company_id
			,@link_profit_ctr_id
			,@link_workorder_id
			,@customer
			,@trip_stop_rate_flag
			,@manifest
			,@manifest_flag
			,@receipt_company_id
			,@receipt_profit_ctr_id
			,@generator
			,@billing_project_id
			,@purchase_order
			,@release_code
			,@po_sequence_id
			,@quantity
			,@tsdf_approval_code
			,@manifest_page_num
			,@manifest_line
			,@manifest_line_id
			,@container_count
			,@container_code
			,@manifest_quantity
			,@manifest_unit
			,@profile_id
			,@dot_shipping_name
			,@waste_code
			,@management_code
			,@reportable_quantity_flag
			,@rq_reason
			,@hazmat
			,@hazmat_class
			,@subsidiary_haz_mat_class
			,@un_na_flag
			,@un_na_number
			,@package_group
			,@erg_number
			,@erg_suffix
			,@drmo_clin_num
			,@drmo_hin_num
			,@drmo_doc_num
			,@continuation_flag
			,@epa_id
			,@tsdf_approval_code
			,@start_date
			,@invoice_comment1
			,@invoice_comment2
			,@invoice_comment3
			,@invoice_comment4
			,@invoice_comment5
			,@pounds
			,@waste_flag
			,@stop_id
			,@wod_sequence_id
			,@generate_stock_container
			,@dest_cc_id
			,@in_the_lab_count
			,@manifest_state
			,@corporate_revenue_classification_uid
			,@DOT_shipping_desc_additional
			,@DOT_waste_flag
			,@profile_labpack_flag

		WHILE @@FETCH_STATUS = 0
		BEGIN
			-- MPM - 7/12/2018 - Make sure that manifest state is either H or N; if not, return an error
			SET @manifest_state = LTRIM(RTRIM(@manifest_state))

			IF NOT (
					@manifest_state = 'N'
					OR @manifest_state = 'H'
					)
			BEGIN
				CLOSE receipt_info

				DEALLOCATE receipt_info

				CLOSE manifest_info

				DEALLOCATE manifest_info

				ROLLBACK TRANSACTION --trip_convert

				IF @debug = 1
					PRINT 'Transaction Rolled Back'

				SET @error_msg = 'Trip Completion Process Failed - WorkOrderManifest.manifest_state for work order ' + RIGHT('00' + CONVERT(VARCHAR(2), @link_company_id), 2) + '-' + RIGHT('00' + CONVERT(VARCHAR(2), @link_profit_ctr_id), 2) + '-' + CAST(@link_workorder_id AS VARCHAR(10)) + ' is invalid (' + CASE @manifest_state
						WHEN ''
							THEN '""'
						ELSE @manifest_state
						END + '). Please contact I.T.'

				RAISERROR (
						@error_msg
						,16
						,1
						)

				--RETURN - 1
				SELECT -1
					--SET @return_code = -1
					--GOTO EXIT_OR_ERROR
			END

			-- rb 11/15/2012 - There are places where @waste_flag checks are not wrapped in isnull()
			IF @waste_flag IS NULL
				OR ltrim(@waste_flag) = ''
				SET @waste_flag = 'T'

			IF @receipt_id IS NOT NULL
				-- rb 03/10/2011 this was falling through as null somehow
				AND @old_manifest = @manifest
				AND @old_customer = @customer
				AND @old_receipt_company_id = @receipt_company_id
				AND @old_receipt_profit_ctr_id = @receipt_profit_ctr_id
				AND @old_link_company_id = @link_company_id
				AND @old_link_profit_ctr_id = @link_profit_ctr_id
				AND @old_link_workorder_id = @link_workorder_id
				AND @old_manifest_flag = @manifest_flag
				SET @line_id = @line_id + 1
			ELSE
			BEGIN
				SET @line_id = 1

				EXEC @receipt_id = sp_Generate_Id @receipt_company_id
					,@receipt_profit_ctr_id
					,'R'
					,1

				-- rb 04/22/2011 check for failure
				IF @receipt_id IS NULL
					OR @receipt_id < 0
				BEGIN
					SET @return_code = - 1

					GOTO EXIT_OR_ERROR
				END

				SELECT @old_manifest = @manifest
					,@old_customer = @customer
					,@old_receipt_company_id = @receipt_company_id
					,@old_receipt_profit_ctr_id = @receipt_profit_ctr_id
					,@old_link_company_id = @link_company_id
					,@old_link_profit_ctr_id = @link_profit_ctr_id
					,@old_link_workorder_id = @link_workorder_id
					,@old_manifest_flag = @manifest_flag
			END

			IF @debug = 1
			BEGIN
				PRINT 'Sequence = ' + Cast(@wod_sequence_id AS VARCHAR)
				PRINT 'Receipt ID = ' + CONVERT(VARCHAR, @receipt_company_id) + ' - ' + CONVERT(VARCHAR, @receipt_profit_ctr_id) + ' - ' + CONVERT(VARCHAR, @receipt_id) + '/' + CONVERT(VARCHAR, @line_id)
				PRINT '@manifest_page_num = ' + Cast(@manifest_page_num AS VARCHAR)
			END

			-- *************************************************************************************
			-- Begin to build the receipt information
			-- *************************************************************************************
			SELECT @waste_code2 = [Profile].waste_code
				,@waste_code_uid2 = [Profile].waste_code_uid
				,@billing_project_id2 = profilequoteapproval.billing_project_id
				,@po_sequence_id2 = profilequoteapproval.po_sequence_id
				,@purchase_order2 = profilequoteapproval.purchase_order
				,@release_code2 = profilequoteapproval.release
				,@ccvoc = profilelab.ccvoc
				,@ddvoc = profilelab.ddvoc
				,@treatment_id = profilequoteapproval.treatment_id
				,@gl_account_code = treatment.gl_account_code
				,@management_code = treatment.management_code
				,@location = profilequoteapproval.location
				,@location_type = profilequoteapproval.location_type
				,@profile_id = [Profile].profile_id
				,@hazmat2 = [Profile].hazmat
				,@dot_shipping_name2 = [Profile].dot_shipping_name
				,@subsidiary_haz_mat_class2 = [Profile].subsidiary_haz_mat_class
				,@un_na_flag2 = [Profile].un_na_flag
				,@un_na_number2 = [Profile].un_na_number
				,@package_group2 = [Profile].package_group
				,@erg_number2 = [Profile].erg_number
				,@erg_suffix2 = [Profile].erg_suffix
				,@hazmat_class2 = [Profile].hazmat_class
				,@rq_reason2 = [Profile].rq_reason
				,@reportable_quantity_flag2 = [Profile].reportable_quantity_flag
				,@fingerprint_type = profilequoteapproval.fingerprint_type
				,@quote_id = profilequoteapproval.quote_id
				,@sr_type = profilequoteapproval.sr_type_code
				,@oxidizer_spot = isnull(profilelab.oxidizer_spot, 'U')
			FROM dbo.profilequoteapproval
			INNER JOIN dbo.[Profile] 
				ON [Profile].profile_id = profilequoteapproval.profile_id
			INNER JOIN dbo.profilelab 
				ON [Profile].profile_id = profilelab.profile_id
			INNER JOIN dbo.profilequoteheader 
				ON [Profile].profile_id = profilequoteheader.profile_id
			LEFT OUTER JOIN dbo.treatment 
				ON (profilequoteapproval.treatment_id = treatment.treatment_id)
				AND (profilequoteapproval.company_id = treatment.company_id)
				AND (profilequoteapproval.profit_ctr_id = treatment.profit_ctr_id)
			WHERE profilequoteapproval.approval_code = @tsdf_approval_code
				AND profilequoteapproval.company_id = @receipt_company_id
				AND profilequoteapproval.profit_ctr_id = @receipt_profit_ctr_id
				AND [Profile].curr_status_code = 'A'
				AND profilelab.type = 'A'
			OPTION (OPTIMIZE FOR UNKNOWN)

			-- Set Fingerprint Status
			IF IsNull(@fingerprint_type, '') <> ''
				AND @fingerprint_type = 'NONE'
			BEGIN
				SET @fingerprint_status = 'A'
				SET @data_complete_flag = 'T'

				-- rb 10/09/2013
				-- if new flag is set to automatically receive
				IF @generate_stock_container = 'T'
					OR @dest_cc_id > 0
				BEGIN
					IF @in_the_lab_count > 0
						SET @receipt_status = 'L'
					ELSE
						SET @receipt_status = 'U'
				END
			END
			ELSE
			BEGIN
				SET @fingerprint_status = 'W'
				SET @data_complete_flag = 'F'

				-- rb 10/09/2013
				-- if new flag is set to automatically receive
				IF @generate_stock_container = 'T'
					OR @dest_cc_id > 0
					SET @receipt_status = 'L'
			END

			IF @debug = 1
			BEGIN
				PRINT 'Getting @hauler from WorkOrderTransporter table'
				PRINT '@trip_company_id = ' + CONVERT(VARCHAR(10), @trip_company_id)
				PRINT '@trip_profit_ctr_id = ' + CONVERT(VARCHAR(10), @trip_profit_ctr_id)
				PRINT '@link_workorder_id = ' + CONVERT(VARCHAR(10), @link_workorder_id)
				PRINT '@manifest = ' + @manifest
			END

			-- Set hauler
			SELECT @hauler = transporter_code
			FROM dbo.workordertransporter
			WHERE company_id = @trip_company_id
				AND profit_ctr_id = @trip_profit_ctr_id
				AND workorder_id = @link_workorder_id
				AND manifest = @manifest
				AND transporter_sequence_id = (
					SELECT Max(transporter_sequence_id)
					FROM workordertransporter
					WHERE company_id = @trip_company_id
						AND profit_ctr_id = @trip_profit_ctr_id
						AND workorder_id = @link_workorder_id
						AND manifest = @manifest
					)

			----------------------------------------------------------------------------------------------------------------------
			----------------------------------------------------------------------------------------------------------------------
			-- 2/21/11 - JDB
			-- This is all good for figuring out line weight from WorkOrderDetailItem monthly weights and merchandise entries,
			-- but we are changing the population of Receipt.line_weight to just use the @pounds variable.
			-- Figure out the line weight
			SET @line_weight = 0.0

			SELECT @line_weight = Sum(IsNull(pounds, 0))
			FROM dbo.workorderdetailitem
			WHERE workorder_id = @workorder_id
				AND company_id = @trip_company_id
				AND profit_ctr_id = @trip_profit_ctr_id
				AND sequence_id = @wod_sequence_id
				AND item_type_ind = 'MW'

			SELECT @line_weight = @line_weight + (
					SELECT Sum(IsNull(merchandise_quantity, 1) * (
								IsNull(pounds, 0) + CASE 
									WHEN IsNull(ounces, 0) = 0
										THEN 0
									ELSE (ounces / 16)
									END
								))
					FROM dbo.workorderdetailitem
					WHERE workorder_id = @workorder_id
						AND company_id = @trip_company_id
						AND profit_ctr_id = @trip_profit_ctr_id
						AND sequence_id = @wod_sequence_id
						AND item_type_ind = 'ME'
					)

			-- End changes
			----------------------------------------------------------------------------------------------------------------------
			----------------------------------------------------------------------------------------------------------------------
			-- Set Tender Type
			SELECT @terms_code = terms_code
			FROM customer
			WHERE customer_id = @customer

			IF Upper(IsNull(@terms_code, '')) = 'COD'
				SET @tender_type = '1'
			ELSE
				SET @tender_type = '4'

			-- Set GL Account Type
			SELECT @gl_account_type = account_type
			FROM dbo.glaccount
			WHERE company_id = @receipt_company_id
				AND profit_ctr_id = @receipt_profit_ctr_id
				AND account_code = @gl_account_code

			-- Set the continuation Flag (always set to True)
			IF @manifest_page_num > 1
				OR @manifest_line > 4
				SET @continuation_flag = @True
			ELSE
				SET @continuation_flag = @True

			IF IsNull(@waste_flag, 'T') = 'T'
			BEGIN
				IF IsNull(@override_rec_date, '') = ''
					OR @override_rec_date = '01/01/1900'
					SET @receipt_date = @current_date
				ELSE
					SET @receipt_date = @override_rec_date

				IF IsNull(@override_date_schedule, '') = ''
					OR @override_date_schedule = '01/01/1900'
					SET @override_date_schedule = NULL

				IF IsNull(@override_time_in, '') = ''
					OR @override_time_in = '01/01/1900'
					SET @override_time_in = NULL

				IF IsNull(@override_time_out, '') = ''
					OR @override_time_out = '01/01/1900'
					SET @override_time_out = NULL

				-- Insert into the receipt table
				INSERT INTO dbo.receipt (
					company_id
					,profit_ctr_id
					,receipt_id
					,line_id
					,trans_mode
					,trans_type
					,receipt_status
					,submitted_flag
					,bulk_flag
					,created_by
					,date_added
					,modified_by
					,date_modified
					,cash_received
					,total_cash_received
					,cod_override
					,reacts_box
					,water_react
					,cyanide_spot
					,sulfide_gr100
					,react_naoh
					,react_hcl
					,odor
					,color_match
					,consist_match
					,free_liquid
					,phasing
					,react_ckd
					,react_bleach
					,cost_flag
					,cost_disposal
					,cost_lab
					,cost_process
					,cost_surcharge
					,cost_trans
					,cost_lab_est
					,cost_process_est
					,cost_surcharge_est
					,cost_trans_est
					,in_transit
					,submit_on_hold_flag
					,continuation_flag
					,customer_id
					,manifest
					,generator_id
					,manifest_flag
					,container_count
					,profile_id
					,waste_code
					,waste_code_uid
					,quantity
					,billing_project_id
					,po_sequence_id
					,purchase_order
					,release
					,manifest_page_num
					,manifest_line
					,manifest_line_id
					,manifest_hazmat
					,manifest_rq_flag
					,manifest_rq_reason
					,manifest_dot_shipping_name
					,manifest_hazmat_class
					,manifest_sub_hazmat_class
					,manifest_un_na_flag
					,manifest_un_na_number
					,manifest_package_group
					,manifest_container_code
					,manifest_quantity
					,manifest_unit
					,manifest_management_code
					,manifest_erg_number
					,manifest_erg_suffix
					,drmo_clin_num
					,drmo_hin_num
					,drmo_doc_num
					,receipt_date
					,hauler
					,load_generator_epa_id
					,approval_code
					,ccvoc
					,ddvoc
					,treatment_id
					,gl_account_code
					,location
					,location_type
					,fingerpr_status
					,data_complete_flag
					,tender_type
					,gross_weight
					,net_weight
					,tare_weight
					,time_in
					,time_out
					,truck_code
					,date_scheduled
					,schedule_confirmation_id
					,waste_accepted_flag
					,line_weight
					,oxidizer_spot
					,manifest_form_type
					,corporate_revenue_classification_uid
					,DOT_shipping_desc_additional
					,DOT_waste_flag
					)
				VALUES (
					@receipt_company_id
					,@receipt_profit_ctr_id
					,@receipt_id
					,@line_id
					,'I'
					,'D'
					,@receipt_status
					,-- rb 10/09/2013 use variable instead of harcoding to 'T'
					@false
					,'F'
					,@user
					,@save_date
					,@user
					,@save_date
					,@zero
					,@zero
					,'N'
					,@unknown
					,@unknown
					,@unknown
					,@unknown
					,@unknown
					,@unknown
					,@unknown
					,@unknown
					,@unknown
					,@unknown
					,@unknown
					,@unknown
					,@unknown
					,'E'
					,@zero
					,@zero
					,@zero
					,@zero
					,@zero
					,@zero
					,@zero
					,@zero
					,@zero
					,2
					,@false
					,@continuation_flag
					,@customer
					,@manifest
					,@generator
					,@manifest_flag
					,@container_count
					,@profile_id
					,@waste_code2
					,@waste_code_uid2
					,@quantity
					,IsNull(@billing_project_id2, @billing_project_id)
					,IsNull(@po_sequence_id, @po_sequence_id2)
					,IsNull(@purchase_order, @purchase_order2)
					,IsNull(@release_code, @release_code2)
					,@manifest_page_num
					,@manifest_line
					,@manifest_line_id
					,IsNull(@hazmat, @hazmat2)
					,IsNull(@reportable_quantity_flag, @reportable_quantity_flag2)
					,IsNull(@rq_reason, @rq_reason2)
					,IsNull(@dot_shipping_name, @dot_shipping_name2)
					,IsNull(@hazmat_class, @hazmat_class2)
					,IsNull(@subsidiary_haz_mat_class, @subsidiary_haz_mat_class2)
					,IsNull(@un_na_flag, @un_na_flag2)
					,IsNull(@un_na_number, @un_na_number2)
					,IsNull(@package_group, @package_group2)
					,@container_code
					,
					-- rb 03/07/2011 @manifest_quantity,
					CASE 
						WHEN IsNull(@manifest_quantity, 0) > 0
							AND IsNull(@manifest_quantity, 0) < 1
							THEN 1
						ELSE Round(@manifest_quantity, 0)
						END
					,@manifest_unit
					,@management_code
					,IsNull(@erg_number, @erg_number2)
					,IsNull(@erg_suffix, @erg_suffix2)
					,@drmo_clin_num
					,@drmo_hin_num
					,@drmo_doc_num
					,CONVERT(DATE, @receipt_date, 101)
					,@hauler
					,@epa_id
					,@tsdf_approval_code
					,@ccvoc
					,@ddvoc
					,@treatment_id
					,@gl_account_code
					,@location
					,@location_type
					,@fingerprint_status
					,@data_complete_flag
					,@tender_type
					,0
					,-- changed to populate with 0 on 2/22/11 JDB
					0
					,-- changed to populate with 0 on 2/22/11 JDB
					0
					,@override_time_in
					,@override_time_out
					,@override_truck_code
					,@override_date_schedule
					,@override_conf_id
					,'F'
					,
					--ROUND(@line_weight,1),
					@pounds
					,@oxidizer_spot
					,@manifest_state
					,@corporate_revenue_classification_uid
					,@DOT_shipping_desc_additional
					,@DOT_waste_flag
					)

				-- Check for Error
				SELECT @error_code = @@ERROR

				IF (@error_code <> 0)
				BEGIN
					SET @return_code = - 1

					GOTO exit_or_error
				END

				-- Insert Into Receipt Audit that we created the receipt
				INSERT INTO dbo.receiptaudit (
					company_id
					,profit_ctr_id
					,receipt_id
					,line_id
					,table_name
					,column_name
					,before_value
					,after_value
					,audit_reference
					,modified_from
					,modified_by
					,date_modified
					)
				VALUES (
					@receipt_company_id
					,@receipt_profit_ctr_id
					,@receipt_id
					,@line_id
					,'RECEIPT'
					,'receipt_id'
					,'(NULL)'
					,CONVERT(VARCHAR, @receipt_id)
					,'Trip Complete Procedure - Trip' + Cast(@trip_id AS VARCHAR)
					,'EQAI'
					,@user
					,GetDate()
					)

				IF @debug = 1
					PRINT '@line_id = ' + CONVERT(VARCHAR(10), @line_id)

				-- Insert into the ReceiptTransporter Table
				IF @line_id = 1
				BEGIN
					--Select @transporter_sequence = 1
					DECLARE transporter_info CURSOR FAST_FORWARD
					FOR
					SELECT transporter_code
						,transporter_sign_name
						,transporter_sign_date
						,transporter_sequence_id
					FROM dbo.workordertransporter WITH (NOLOCK)
					WHERE company_id = @trip_company_id
						AND profit_ctr_id = @trip_profit_ctr_id
						AND workorder_id = @link_workorder_id
						AND manifest = @manifest
					ORDER BY transporter_sequence_id DESC
					--FOR READ ONLY -- rb 04/22/2011

					OPEN transporter_info

					FETCH transporter_info
					INTO @transporter_code
						,@transporter_sign_name
						,@transporter_sign_date
						,@transporter_sequence

					IF @debug = 1
					BEGIN
						PRINT 'First WorkOrderTransporter'
						PRINT '----------------------------------------'
						PRINT '@trip_company_id = ' + CONVERT(VARCHAR(10), @trip_company_id)
						PRINT '@trip_profit_ctr_id = ' + CONVERT(VARCHAR(10), @trip_profit_ctr_id)
						PRINT '@link_workorder_id = ' + CONVERT(VARCHAR(10), @link_workorder_id)
						PRINT '@transporter_code = ' + @transporter_code
						PRINT '@transporter_sign_name = ' + IsNull(@transporter_sign_name, 'XXX')
						PRINT '@transporter_sign_date = ' + CONVERT(VARCHAR(20), @transporter_sign_date)
						PRINT '@transporter_sequence = ' + CONVERT(VARCHAR(20), @transporter_sequence)
					END

					WHILE @@FETCH_STATUS = 0
					BEGIN
						SELECT @transporter_name = transporter_name
							,@transporter_epa_id = transporter_epa_id
						FROM dbo.transporter
						WHERE transporter_code = @transporter_code

						INSERT INTO dbo.receipttransporter (
							company_id
							,profit_ctr_id
							,receipt_id
							,transporter_sequence_id
							,transporter_code
							,transporter_name
							,transporter_epa_id
							,transporter_sign_name
							,transporter_sign_date
							,added_by
							,date_added
							,modified_by
							,date_modified
							)
						VALUES (
							@receipt_company_id
							,@receipt_profit_ctr_id
							,@receipt_id
							,@transporter_sequence
							,@transporter_code
							,@transporter_name
							,@transporter_epa_id
							,@transporter_sign_name
							,@transporter_sign_date
							,
							--@start_date,
							@user
							,@save_date
							,@user
							,@save_date
							)

						FETCH transporter_info
						INTO @transporter_code
							,@transporter_sign_name
							,@transporter_sign_date
							,@transporter_sequence

						IF @debug = 1
						BEGIN
							PRINT 'Other WorkOrderTransporter'
							PRINT '----------------------------------------'
							PRINT '@trip_company_id = ' + CONVERT(VARCHAR(10), @trip_company_id)
							PRINT '@trip_profit_ctr_id = ' + CONVERT(VARCHAR(10), @trip_profit_ctr_id)
							PRINT '@workorder_id = ' + CONVERT(VARCHAR(10), @workorder_id)
							PRINT '@transporter_code = ' + @transporter_code
							PRINT '@transporter_sign_name = ' + @transporter_sign_name
							PRINT '@transporter_sign_date = ' + CONVERT(VARCHAR(20), @transporter_sign_date)
							PRINT '@transporter_sequence = ' + CONVERT(VARCHAR(20), @transporter_sequence)
						END
					END

					CLOSE transporter_info

					DEALLOCATE transporter_info

					-- insert the receipt header rew
					INSERT INTO dbo.receiptheader (
						company_id
						,profit_ctr_id
						,receipt_id
						,trans_mode
						,receipt_status
						,receipt_date
						,manifest_flag
						,manifest
						,customer_id
						,transporter_code
						,truck_code
						,bulk_flag
						,time_in
						,time_out
						,schedule_confirmation_id
						,date_scheduled
						,gross_weight
						,tare_weight
						,net_weight
						,tender_type
						,cash_received
						,total_cash_received
						,cod_override
						,workorder_company_id
						,workorder_profit_ctr_id
						,workorder_id
						,trip_id
						,trip_sequence_id
						,added_by
						,date_added
						,modified_by
						,date_modified
						,waste_accepted_flag
						)
					VALUES (
						@receipt_company_id
						,@receipt_profit_ctr_id
						,@receipt_id
						,'I'
						,@receipt_status
						,-- rb 10/09/2013 use variable instead of harcoding to 'T'
						CONVERT(DATE, @receipt_date, 101)
						,@manifest_flag
						,@manifest
						,@customer
						,@transporter_code
						,@override_truck_code
						,'F'
						,@override_time_in
						,@override_time_out
						,@override_conf_id
						,@override_date_schedule
						,0
						,
						-- changed to populate with 0 on 2/22/11 JDB
						0
						,
						-- changed to populate with 0 on 2/22/11 JDB
						0
						,@tender_type
						,@zero
						,@zero
						,'N'
						,@trip_company_id
						,@trip_profit_ctr_id
						,@workorder_id
						,@trip_id
						,@stop_id
						,@user
						,@save_date
						,@user
						,@save_date
						,'F'
						)
				END

				-- END
				IF @debug = 1
					PRINT 'Populating ReceiptWasteCodes'

				-- rb 09/04/2012 If a Lab Pack trip, populate ReceiptWasteCode from WorkOrderWasteCode
				IF @lab_pack_flag = 'T'
				BEGIN

					-- MPM - 5/9/2018 - Replaced the insert statement commented out above with the one below that selects from fn_tbl_manifest_waste_codes_receipt_wo, 
					-- so that TX waste codes are correctly inserted.
					-- DevOps:17664 - Added distinct to the select
					INSERT INTO dbo.ReceiptWasteCode (
						company_id
						,profit_ctr_id
						,receipt_id
						,line_id
						,primary_flag
						,waste_code
						,created_by
						,date_added
						,sequence_id
						,waste_code_uid
						)
					SELECT DISTINCT @receipt_company_id
						,@receipt_profit_ctr_id
						,@receipt_id
						,@line_id
						,CASE 
							WHEN isnull(t.source_sequence_id, 0) = 1
								THEN 'T'
							ELSE 'F'
							END
						,t.waste_code
						,@user
						,@save_date
						,t.source_sequence_id
						,t.waste_code_uid
					FROM dbo.fn_tbl_manifest_waste_codes_receipt_wo('Work Order', @link_company_id, @link_profit_ctr_id, @link_workorder_id, @wod_sequence_id) t
				END
				ELSE
				BEGIN
					-- MPM - 5/9/2018 - Replaced the insert statement commented out above with the one below that selects from fn_tbl_manifest_waste_codes and 
					-- fn_tbl_manifest_waste_codes_receipt_wo, so that TX waste codes are correctly inserted.
					INSERT dbo.ReceiptWasteCode (
						company_id
						,profit_ctr_id
						,receipt_id
						,line_id
						,primary_flag
						,waste_code
						,created_by
						,date_added
						,sequence_id
						,waste_code_uid
						)
					SELECT @receipt_company_id
						,@receipt_profit_ctr_id
						,@receipt_id
						,@line_id
						,'F'
						,t.waste_code
						,@user
						,@save_date
						,CONVERT(INT, NULL)
						,t.waste_code_uid
					FROM dbo.fn_tbl_manifest_waste_codes('Profile', @profile_id, @generator, @tsdf_code) AS t
					WHERE t.use_for_storage = 1
					
					UNION
					
					SELECT @receipt_company_id
						,@receipt_profit_ctr_id
						,@receipt_id
						,@line_id
						,'F'
						,t2.waste_code
						,@user
						,@save_date
						,CONVERT(INT, NULL)
						,t2.waste_code_uid
					FROM dbo.fn_tbl_manifest_waste_codes_receipt_wo('Work Order', @link_company_id, @link_profit_ctr_id, @link_workorder_id, @wod_sequence_id) AS t2

					-- set the top 6 by looping through the WorkOrderWasteCodes
					SET @rec_top6_seq_id = 0

					DECLARE c_rec_top6 CURSOR FAST_FORWARD
					FOR
					SELECT waste_code_uid
					FROM dbo.WorkOrderWasteCode
					WHERE workorder_id = @link_workorder_id
						AND company_id = @link_company_id
						AND profit_ctr_id = @link_profit_ctr_id
						AND workorder_sequence_id = @wod_sequence_id
						AND isnull(sequence_id, 0) > 0
					ORDER BY sequence_id ASC

					IF @debug = 1
					BEGIN
						PRINT 'Setting ReceiptWasteCode sequence_id and primary_flag'
					END

					OPEN c_rec_top6

					FETCH c_rec_top6
					INTO @wc_id

					WHILE @@FETCH_STATUS = 0
					BEGIN
						IF @debug = 1
							PRINT 'Checking for record in ReceiptWasteCode with null sequence_id'

						IF EXISTS (
								SELECT 1
								FROM dbo.ReceiptWasteCode WITH (NOLOCK)
								WHERE company_id = @receipt_company_id
									AND profit_ctr_id = @receipt_profit_ctr_id
									AND receipt_id = @receipt_id
									AND line_id = @line_id
									AND waste_code_uid = @wc_id
									AND sequence_id IS NULL
								)
						BEGIN
							IF @debug = 1
								PRINT 'Found record in ReceiptWasteCode'

							SET @rec_top6_seq_id = @rec_top6_seq_id + 1

							IF @rec_top6_seq_id = 1
								SET @primary_flag = 'T'
							ELSE
								SET @primary_flag = 'F'

							IF @rec_top6_seq_id >= 1
								AND @rec_top6_seq_id <= 6
							BEGIN
								UPDATE dbo.ReceiptWasteCode
								SET sequence_id = @rec_top6_seq_id
									,primary_flag = @primary_flag
								WHERE company_id = @receipt_company_id
									AND profit_ctr_id = @receipt_profit_ctr_id
									AND receipt_id = @receipt_id
									AND line_id = @line_id
									AND waste_code_uid = @wc_id
							END
						END
						ELSE
						BEGIN
							IF @debug = 1
								PRINT 'Did not find record in ReceiptWasteCode'
						END

						FETCH c_rec_top6
						INTO @wc_id
					END

					CLOSE c_rec_top6

					DEALLOCATE c_rec_top6
				END

				-- Check for Error
				SELECT @error_code = @@ERROR
					,@rowcount = @@ROWCOUNT

				IF (@error_code <> 0)
				BEGIN
					SET @return_code = - 1

					GOTO exit_or_error
				END

				/* rb 12/20/2012 end */
				-- Insert Into the ReceiptDetailItem Table from WorkorderdetailItem
				INSERT INTO dbo.receiptdetailitem (
					receipt_id
					,company_id
					,profit_ctr_id
					,line_id
					,sub_sequence_id
					,item_type_ind
					,month
					,year
					,pounds
					,ounces
					,merchandise_id
					,merchandise_quantity
					,merchandise_code_type
					,merchandise_code
					,manual_entry_desc
					,note
					,added_by
					,date_added
					,modified_by
					,date_modified
					,form_group
					,contents
					,percentage
					,dea_schedule
					,dosage_type_id
					,parent_sub_sequence_id
					,const_id
					,const_percent
					,const_uhc
					)
				SELECT @receipt_id
					,@receipt_company_id
					,@receipt_profit_ctr_id
					,@line_id
					,sub_sequence_id
					,item_type_ind
					,month
					,year
					,CASE 
						WHEN (Round(pounds, 0) <> pounds)
							AND (ounces > 0)
							THEN Round(pounds + (ounces / 16), 1)
						ELSE pounds
						END
					,CASE 
						WHEN Round(pounds, 0) <> pounds
							AND ounces > 0
							THEN 0
						ELSE ounces
						END
					,merchandise_id
					,merchandise_quantity
					,merchandise_code_type
					,merchandise_code
					,manual_entry_desc
					,note
					,added_by
					,date_added
					,modified_by
					,date_modified
					,form_group
					,contents
					,percentage
					,dea_schedule
					,dosage_type_id
					,parent_sub_sequence_id
					,const_id
					,const_percent
					,const_uhc
				FROM dbo.workorderdetailitem
				WHERE company_id = @link_company_id
					AND profit_ctr_id = @link_profit_ctr_id
					AND workorder_id = @link_workorder_id
					AND sequence_id = @wod_sequence_id

				-- Check for Error
				SELECT @error_code = @@ERROR

				IF (@error_code <> 0)
				BEGIN
					SET @return_code = - 1

					GOTO exit_or_error
				END

				-- rb 09/04/2012 If a Lab Pack trip, populate ReceiptConstituent from WorkOrderDetailItem
				-- MPM - 9/1/2023 - DevOps 72879 - Modified IF statement below to include @profile_labpack_flag
				IF @lab_pack_flag = 'T'
					AND @profile_labpack_flag = 'T'
					-- MPM - 9/24/2021 - DevOps 28861 - added the columns to the insert statement below
					INSERT INTO dbo.receiptconstituent (
						company_id
						,profit_ctr_id
						,receipt_id
						,line_id
						,const_id
						,UHC
						,min_concentration
						,concentration
						,unit
						,created_by
						,modified_by
						,date_added
						,date_modified
						)
					SELECT DISTINCT @receipt_company_id
						,@receipt_profit_ctr_id
						,@receipt_id
						,@line_id
						,const_id
						,const_uhc
						,const_percent
						,-- min_concentration 
						const_percent
						,-- ??? concentration,
						'%'
						,-- ??? unit,
						@user
						,@user
						,@save_date
						,@save_date
					FROM dbo.workorderdetailitem
					WHERE workorder_id = @link_workorder_id
						AND company_id = @link_company_id
						AND profit_ctr_id = @link_profit_ctr_id
						AND sequence_id = @wod_sequence_id
						AND item_type_ind = 'LP'
						AND isnull(const_id, 0) > 0
				ELSE
					-- Insert Into the ReceiptConstituent Table From ProfileConstituent
					INSERT INTO dbo.receiptconstituent (
						company_id
						,profit_ctr_id
						,receipt_id
						,line_id
						,const_id
						,UHC
						,min_concentration
						,concentration
						,unit
						,created_by
						,modified_by
						,date_added
						,date_modified
						)
					SELECT @receipt_company_id
						,@receipt_profit_ctr_id
						,@receipt_id
						,@line_id
						,const_id
						,uhc
						,min_concentration
						,concentration
						,unit
						,@user
						,@user
						,@save_date
						,@save_date
					FROM dbo.profileconstituent
					WHERE profile_id = @profile_id

				-- Check for Error
				SELECT @error_code = @@ERROR

				IF (@error_code <> 0)
				BEGIN
					SET @return_code = - 1

					GOTO exit_or_error
				END

				-- Insert into ReceiptComment
				IF @line_id = 1
				BEGIN
					INSERT INTO dbo.receiptcomment (
						company_id
						,profit_ctr_id
						,receipt_id
						,invoice_comment_1
						,invoice_comment_2
						,invoice_comment_3
						,invoice_comment_4
						,invoice_comment_5
						,added_by
						,date_added
						,modified_by
						,date_modified
						)
					VALUES (
						@receipt_company_id
						,@receipt_profit_ctr_id
						,@receipt_id
						,@invoice_comment1
						,@invoice_comment2
						,@invoice_comment3
						,@invoice_comment4
						,@invoice_comment5
						,@user
						,@save_date
						,@user
						,@save_date
						)

					-- Check for Error
					SELECT @error_code = @@ERROR

					IF (@error_code <> 0)
					BEGIN
						SET @return_code = - 1

						GOTO exit_or_error
					END
				END

				-- Insert into ReceiptPrice
				-- Set @sr_type = NULL
				-- Set @sr_price = NULL
				SELECT @surcharge_flag = surcharge_flag
				FROM profitcenter
				WHERE company_id = @receipt_company_id
					AND profit_ctr_id = @receipt_profit_ctr_id

				IF IsNull(@surcharge_flag, 'F') = 'F'
					OR IsNull(@sr_type, 'E') = 'E'
				BEGIN
					SET @sr_type = 'E'
					SET @sr_price = 0
				END

				SET @price_count = 0
				SET @tot_quantity = 0
				SET @price_id = 1
				-- Reset the variables for each pricing run
				SET @quote_price = 0
				SET @sr_price = 0
				SET @print_on_invoice_flag = ''
				SET @quote_sequence_id = 0
				SET @bulk_flag = 'F'
				SET @container_flag = 'T'

				DECLARE pricing CURSOR FAST_FORWARD
				FOR
				SELECT COALESCE(workorderdetailunit.bill_unit_code, size) AS bill_unit
					,workorderdetailunit.quantity
				FROM dbo.workorderdetailunit
				INNER JOIN dbo.workorderdetail 
					ON workorderdetailunit.company_id = workorderdetail.company_id
					AND workorderdetailunit.profit_ctr_id = workorderdetail.profit_ctr_id
					AND workorderdetailunit.workorder_id = workorderdetail.workorder_id
					AND workorderdetailunit.sequence_id = workorderdetail.sequence_id
					AND workorderdetail.resource_type = 'D'
				JOIN dbo.profilequotedetail 
					ON workorderdetail.profile_id = profilequotedetail.profile_id
					AND workorderdetail.profile_company_id = profilequotedetail.company_id
					AND workorderdetail.profile_profit_ctr_id = profilequotedetail.profit_ctr_id
					AND workorderdetailunit.bill_unit_code = profilequotedetail.bill_unit_code
					AND profilequotedetail.[Status] = 'A'
					AND profilequotedetail.record_type = 'D'
				WHERE workorderdetailunit.workorder_id = @link_workorder_id
					AND workorderdetailunit.company_id = @link_company_id
					AND workorderdetailunit.profit_ctr_id = @link_profit_ctr_id
					AND workorderdetailunit.quantity > 0
					AND workorderdetailunit.sequence_id = @wod_sequence_id
					AND workorderdetailunit.bill_unit_code IS NOT NULL
					AND workorderdetailunit.billing_flag = 'T'
				OPTION (OPTIMIZE FOR UNKNOWN)
				--FOR READ ONLY -- rb 04/22/2011 --WITH(NOLOCK)?

				OPEN pricing

				IF @debug = 1
				BEGIN
					PRINT 'Pricing company = ' + Cast(@link_company_id AS VARCHAR)
					PRINT 'Pricing Profit_ctr = ' + Cast(@link_profit_ctr_id AS VARCHAR)
					PRINT 'Pricing Workorder = ' + Cast(@link_workorder_id AS VARCHAR)
					PRINT 'Pricing Rows = ' + Cast(@@cursor_rows AS VARCHAR)
					PRINT 'Pricing Sequence = ' + Cast(@wod_sequence_id AS VARCHAR)
				END

				FETCH pricing
				INTO @bill_unit_code
					,@quantity

				WHILE @@FETCH_STATUS = 0
				BEGIN
					SET @price_count = @price_count + 1
					SET @tot_quantity = @tot_quantity + @quantity

					IF @debug = 1
					BEGIN
						PRINT 'Bill Unit Code = ' + @bill_unit_code
						PRINT 'Quantity = ' + Cast(@quantity AS VARCHAR)
						PRINT 'Price count = ' + Cast(@price_count AS VARCHAR)
					END

					-- Get the Quote ID
					SELECT @quote_id = profilequoteapproval.quote_id
					FROM dbo.profilequoteapproval
					JOIN dbo.[Profile]
						ON ([Profile].profile_id = profilequoteapproval.profile_id)
					JOIN dbo.profilelab 
						ON ([Profile].profile_id = profilelab.profile_id)
					WHERE profilequoteapproval.approval_code = @tsdf_approval_code
						AND profilequoteapproval.company_id = @receipt_company_id
						AND profilequoteapproval.profit_ctr_id = @receipt_profit_ctr_id
						AND [Profile].curr_status_code = 'A'
						AND profilelab.type = 'A'

					-- Select to get Pricing Information
					SELECT @quote_price = profilequotedetail.price
						,@sr_price = profilequotedetail.surcharge_price
						,@print_on_invoice_flag = profilequotedetail.print_on_invoice_flag
						,@quote_sequence_id = profilequotedetail.sequence_id
						,@bulk_flag = 'F'
						,@container_flag = IsNull(billunit.container_flag, 'F')
					FROM dbo.profilequotedetail
					LEFT OUTER JOIN dbo.billunit 
						ON profilequotedetail.bill_unit_code = billunit.bill_unit_code
					WHERE profilequotedetail.record_type = 'D'
						AND profilequotedetail.STATUS = 'A'
						AND profilequotedetail.quote_id = @quote_id
						AND profilequotedetail.profit_ctr_id = @receipt_profit_ctr_id
						AND profilequotedetail.company_id = @receipt_company_id
						AND profilequotedetail.bill_unit_code = @bill_unit_code

					SET @waste_extended_amt = round(@quantity * @quote_price, 2)
					SET @sr_extended_amt = round(@quantity * @sr_price, 2)

					INSERT INTO dbo.receiptprice (
						company_id
						,profit_ctr_id
						,receipt_id
						,line_id
						,price_id
						,bill_quantity
						,bill_unit_code
						,price
						,quote_price
						,quote_id
						,quote_sequence_id
						,sr_price
						,sr_type
						,sr_extended_amt
						,waste_extended_amt
						,total_extended_amt
						,print_on_invoice_flag
						,added_by
						,modified_by
						,date_added
						,date_modified
						)
					VALUES (
						@receipt_company_id
						,@receipt_profit_ctr_id
						,@receipt_id
						,@line_id
						,@price_id
						,@quantity
						,@bill_unit_code
						,@quote_price
						,@quote_price
						,@quote_id
						,@quote_sequence_id
						,@sr_price
						,@sr_type
						,@sr_extended_amt
						,@waste_extended_amt
						,@waste_extended_amt + @sr_extended_amt
						,@print_on_invoice_flag
						,@user
						,@user
						,@save_date
						,@save_date
						)

					-- Check for Error
					SELECT @error_code = @@ERROR

					IF (@error_code <> 0)
					BEGIN
						CLOSE pricing

						DEALLOCATE pricing

						SET @return_code = - 1

						GOTO exit_or_error
					END

					SET @price_id = @price_id + 1

					FETCH pricing
					INTO @bill_unit_code
						,@quantity
				END

				CLOSE pricing

				DEALLOCATE pricing

				IF @price_count > 1
				BEGIN
					UPDATE dbo.receipt
					SET bill_unit_code = NULL
						,quantity = @tot_quantity
						,bulk_flag = 'F'
					WHERE company_id = @receipt_company_id
						AND profit_ctr_id = @receipt_profit_ctr_id
						AND receipt_id = @receipt_id
						AND line_id = @line_id
				END

				IF @price_count = 1
				BEGIN
					UPDATE dbo.receipt
					SET bill_unit_code = @bill_unit_code
						,quantity = @tot_quantity
						,bulk_flag = 'F'
					WHERE company_id = @receipt_company_id
						AND profit_ctr_id = @receipt_profit_ctr_id
						AND receipt_id = @receipt_id
						AND line_id = @line_id
				END

				IF @price_count = 0
				BEGIN
					-- Get the Quote ID
					SELECT @quote_id = profilequoteapproval.quote_id
					FROM dbo.profilequoteapproval
					JOIN dbo.[Profile] 
						ON ([Profile].profile_id = profilequoteapproval.profile_id)
					JOIN dbo.profilelab 
						ON ([Profile].profile_id = profilelab.profile_id)
					WHERE profilequoteapproval.approval_code = @tsdf_approval_code
						AND profilequoteapproval.company_id = @receipt_company_id
						AND profilequoteapproval.profit_ctr_id = @receipt_profit_ctr_id
						AND [Profile].curr_status_code = 'A'
						AND profilelab.type = 'A'

					-- Select to get Pricing Information
					SELECT @quote_price = profilequotedetail.price
						,@sr_price = profilequotedetail.surcharge_price
						,@print_on_invoice_flag = profilequotedetail.print_on_invoice_flag
						,@quote_sequence_id = profilequotedetail.sequence_id
						,@bulk_flag = 'F'
						,@container_flag = IsNull(billunit.container_flag, 'F')
					FROM dbo.profilequotedetail
					LEFT OUTER JOIN dbo.billunit 
						ON profilequotedetail.bill_unit_code = billunit.bill_unit_code
					WHERE profilequotedetail.record_type = 'D'
						AND profilequotedetail.[Status] = 'A'
						AND profilequotedetail.quote_id = @quote_id
						AND profilequotedetail.profit_ctr_id = @receipt_profit_ctr_id
						AND profilequotedetail.company_id = @receipt_company_id
						AND profilequotedetail.bill_unit_code = @bill_unit_code

					SET @waste_extended_amt = round(@quantity * @quote_price, 2)
					SET @sr_extended_amt = round(@quantity * @sr_price, 2)

					INSERT INTO dbo.receiptprice (
						company_id
						,profit_ctr_id
						,receipt_id
						,line_id
						,price_id
						,bill_quantity
						,bill_unit_code
						,price
						,quote_price
						,quote_id
						,quote_sequence_id
						,sr_price
						,sr_type
						,sr_extended_amt
						,waste_extended_amt
						,total_extended_amt
						,print_on_invoice_flag
						,added_by
						,modified_by
						,date_added
						,date_modified
						)
					VALUES (
						@receipt_company_id
						,@receipt_profit_ctr_id
						,@receipt_id
						,@line_id
						,@price_id
						,@quantity
						,@bill_unit_code
						,@quote_price
						,@quote_price
						,@quote_id
						,@quote_sequence_id
						,@sr_price
						,@sr_type
						,@sr_extended_amt
						,@waste_extended_amt
						,@waste_extended_amt + @sr_extended_amt
						,@print_on_invoice_flag
						,@user
						,@user
						,@save_date
						,@save_date
						)

					-- Check for Error
					SELECT @error_code = @@ERROR

					IF (@error_code <> 0)
					BEGIN
						SET @return_code = - 1

						GOTO exit_or_error
					END

					UPDATE dbo.receipt
					SET bulk_flag = 'F'
					WHERE company_id = @receipt_company_id
						AND profit_ctr_id = @receipt_profit_ctr_id
						AND receipt_id = @receipt_id
						AND line_id = @line_id
				END

				---------------------------------------
				-- Copy Manifest and/or BOL
				---------------------------------------
				IF @line_id = 1
				BEGIN
					DECLARE workorder_image CURSOR FAST_FORWARD
					FOR
					SELECT company_id
						,profit_ctr_id
						,image_id
						,document_source
						,type_id
						,STATUS
						,document_name
						,customer_id
						,manifest
						,manifest_flag
						,approval_code
						,workorder_id
						,generator_id
						,invoice_print_flag
						,image_resolution
						,scan_file
						,description
						,form_id
						,revision_id
						,form_version_id
						,form_type
						,file_type
						,profile_id
						,page_number
						,print_in_file
						,view_on_web
						,app_source
						,merchandise_id
						,trip_id
						,batch_id
						,tsdf_code
						,tsdf_approval_id
					FROM plt_image.dbo.scan
					WHERE workorder_id = @link_workorder_id
						AND company_id = @link_company_id
						AND profit_ctr_id = @link_profit_ctr_id
						AND STATUS = 'A'
						AND type_id IN (
							28
							,45
							)
						AND Upper(document_name) = Upper(@manifest)
					OPTION (OPTIMIZE FOR UNKNOWN)
					--FOR READ ONLY -- rb 04/22/2011 --WITH(NOLOCK)?

					OPEN workorder_image

					FETCH workorder_image
					INTO @image_company_id
						,@image_profit_ctr_id
						,@image_image_id
						,@image_document_source
						,@image_type_id
						,@image_status
						,@image_document_name
						,@image_customer_id
						,@image_manifest
						,@image_manifest_flag
						,@image_approval_code
						,@image_workorder_id
						,@image_generator_id
						,@image_invoice_print_flag
						,@image_image_resolution
						,@image_scan_file
						,@image_description
						,@image_form_id
						,@image_revision_id
						,@image_form_version_id
						,@image_form_type
						,@image_file_type
						,@image_profile_id
						,@image_page_number
						,@image_print_in_file
						,@image_view_on_web
						,@image_app_source
						,@image_merchandise_id
						,@image_trip_id
						,@image_batch_id
						,@image_TSDF_code
						,@image_TSDF_approval_id

					WHILE @@FETCH_STATUS = 0
					BEGIN
						IF @image_type_id = 45
							SET @new_type = 2

						IF @image_type_id = 28
							SET @new_type = 1

						INSERT INTO plt_image..scan (
							company_id
							,profit_ctr_id
							,image_id
							,document_source
							,type_id
							,STATUS
							,document_name
							,date_added
							,date_modified
							,added_by
							,modified_by
							,customer_id
							,receipt_id
							,manifest
							,manifest_flag
							,approval_code
							,workorder_id
							,generator_id
							,invoice_print_flag
							,image_resolution
							,scan_file
							,description
							,form_id
							,revision_id
							,form_version_id
							,form_type
							,file_type
							,profile_id
							,page_number
							,print_in_file
							,view_on_web
							,app_source
							,upload_date
							,merchandise_id
							,trip_id
							,batch_id
							,tsdf_code
							,tsdf_approval_id
							)
						VALUES (
							@receipt_company_id
							,@receipt_profit_ctr_id
							,@image_image_id
							,'receipt'
							,@new_type
							,'A'
							,@image_document_name
							,@save_date
							,@save_date
							,@user
							,@user
							,@image_customer_id
							,@receipt_id
							,@image_manifest
							,@image_manifest_flag
							,@image_approval_code
							,NULL
							,@image_generator_id
							,'T'
							,@image_image_resolution
							,@image_scan_file
							,@image_description
							,@image_form_id
							,@image_revision_id
							,@image_form_version_id
							,@image_form_type
							,@image_file_type
							,@image_profile_id
							,@image_page_number
							,@image_print_in_file
							,@image_view_on_web
							,@image_app_source
							,@save_date
							,@image_merchandise_id
							,@image_trip_id
							,@image_batch_id
							,@image_TSDF_code
							,@image_TSDF_approval_id
							)

						SELECT @error_code = @@ERROR

						IF (@error_code <> 0)
						BEGIN
							CLOSE workorder_image

							DEALLOCATE workorder_image

							SET @return_code = - 1

							GOTO exit_or_error
						END

						UPDATE plt_image.dbo.scan
						SET invoice_print_flag = 'F'
						WHERE company_id = @image_company_id
							AND profit_ctr_id = @image_profit_ctr_id
							AND workorder_id = @image_workorder_id
							AND image_id = @image_image_id

						SELECT @error_code = @@ERROR

						IF (@error_code <> 0)
						BEGIN
							CLOSE workorder_image

							DEALLOCATE workorder_image

							SET @return_code = - 1

							GOTO exit_or_error
						END

						-- goto next row
						FETCH workorder_image
						INTO @image_company_id
							,@image_profit_ctr_id
							,@image_image_id
							,@image_document_source
							,@image_type_id
							,@image_status
							,@image_document_name
							,@image_customer_id
							,@image_manifest
							,@image_manifest_flag
							,@image_approval_code
							,@image_workorder_id
							,@image_generator_id
							,@image_invoice_print_flag
							,@image_image_resolution
							,@image_scan_file
							,@image_description
							,@image_form_id
							,@image_revision_id
							,@image_form_version_id
							,@image_form_type
							,@image_file_type
							,@image_profile_id
							,@image_page_number
							,@image_print_in_file
							,@image_view_on_web
							,@image_app_source
							,@image_merchandise_id
							,@image_trip_id
							,@image_batch_id
							,@image_TSDF_code
							,@image_TSDF_approval_id
					END

					CLOSE workorder_image

					DEALLOCATE workorder_image
				END

				-- MPM - 12/5/2018 - GEM 57107 - Insert into ReceiptManifest
				IF @debug = 1
				BEGIN
					PRINT '@line_id = ' + CAST(@line_id AS VARCHAR)
					PRINT '@generator_sign_name = ' + @generator_sign_name
					PRINT '@generator_sign_date = ' + Cast(@generator_sign_date AS VARCHAR)
				END

				IF @manifest_page_num > @last_manifest_page_num
					AND @generator_sign_name IS NOT NULL
					AND @generator_sign_date IS NOT NULL
				BEGIN
					IF @debug = 1
					BEGIN
						PRINT 'About to insert into ReceiptManifest'
						PRINT '@manifest_page_num = ' + CAST(@manifest_page_num AS VARCHAR)
					END

					INSERT INTO dbo.ReceiptManifest (
						company_id
						,profit_ctr_id
						,receipt_id
						,page
						,generator_sign_name
						,generator_sign_date
						,added_by
						,date_added
						,modified_by
						,date_modified
						)
					VALUES (
						@receipt_company_id
						,@receipt_profit_ctr_id
						,@receipt_id
						,@manifest_page_num
						,@generator_sign_name
						,@generator_sign_date
						,@user
						,@save_date
						,@user
						,@save_date
						)

					-- Check for Error
					SELECT @error_code = @@ERROR

					IF (@error_code <> 0)
					BEGIN
						SET @return_code = - 1

						GOTO exit_or_error
					END

					SET @last_manifest_page_num = @manifest_page_num
				END
			END

			IF @debug = 1
				PRINT 'Waste Flag = ' + @waste_flag

			-- Insert into Billing Link Lookup
			-- rb 04/20/2015 only if trip_stop_rate_flag <> 'T'
			IF @line_id = 1
				AND @trip_stop_rate_flag <> 'T'
			BEGIN
				SELECT @link_req_flag = link_required_flag
				FROM customerbilling
				WHERE billing_project_id = @billing_project_id
					AND customer_id = @customer

				IF IsNull(@link_req_flag, 'F') = 'T'
					SET @billing_link_id = 0
				ELSE
					SET @billing_link_id = NULL

				IF @waste_flag = 'T'
				BEGIN
					IF @debug = 1
						PRINT 'Build Link'

					INSERT INTO dbo.billinglinklookup (
						trans_source
						,company_id
						,profit_ctr_id
						,receipt_id
						,billing_link_id
						,source_type
						,source_company_id
						,source_profit_ctr_id
						,source_id
						,added_by
						,date_added
						,modified_by
						,date_modified
						,link_required_flag
						)
					VALUES (
						'I'
						,@receipt_company_id
						,@receipt_profit_ctr_id
						,@receipt_id
						,@billing_link_id
						,'W'
						,@link_company_id
						,@link_profit_ctr_id
						,@link_workorder_id
						,@user
						,@save_date
						,@user
						,@save_date
						,IsNull(@link_req_flag, 'F')
						)
				END
				ELSE
					-- Set an exempt link
				BEGIN
					IF @link_written = 'F'
					BEGIN
						IF @debug = 1
							PRINT 'Build Exempt ' + CONVERT(VARCHAR, @link_workorder_id) + ' - ' + CONVERT(VARCHAR, @link_company_id) + '/' + CONVERT(VARCHAR, @link_profit_ctr_id)

						SET @link_written = 'T'
						SET @receipt_id = NULL
						SET @receipt_company_id = NULL
						SET @receipt_profit_ctr_id = NULL
						SET @link_count = (
								SELECT Count(*)
								FROM billinglinklookup
								WHERE source_company_id = @link_company_id
									AND source_profit_ctr_id = @link_profit_ctr_id
									AND source_id = @link_workorder_id
								)

						IF @link_count = 0
						BEGIN
							INSERT INTO dbo.billinglinklookup (
								trans_source
								,company_id
								,profit_ctr_id
								,receipt_id
								,billing_link_id
								,source_type
								,source_company_id
								,source_profit_ctr_id
								,source_id
								,added_by
								,date_added
								,modified_by
								,date_modified
								,link_required_flag
								,required_source_flag
								)
							VALUES (
								'I'
								,NULL
								,NULL
								,NULL
								,0
								,'W'
								,@link_company_id
								,@link_profit_ctr_id
								,@link_workorder_id
								,@user
								,@save_date
								,@user
								,@save_date
								,'E'
								,'F'
								)
						END
					END
				END

				IF @debug = 1
				BEGIN
					PRINT 'Receipt Company: ' + CONVERT(VARCHAR, @receipt_company_id)
					PRINT 'Receipt Profit Ctr: ' + CONVERT(VARCHAR, @receipt_profit_ctr_id)
					PRINT 'Receipt ID: ' + CONVERT(VARCHAR, @receipt_id)
					PRINT 'WorkOrder Company: ' + CONVERT(VARCHAR, @link_Company_id)
					PRINT 'Workorder Profit Ctr: ' + CONVERT(VARCHAR, @link_profit_ctr_id)
					PRINT 'Workorder ID: ' + CONVERT(VARCHAR, @link_workorder_id)
				END

				-- Check for Error
				SELECT @error_code = @@ERROR

				IF (@error_code <> 0)
				BEGIN
					SET @return_code = - 1

					GOTO exit_or_error
				END
			END

			IF @debug = 1
				PRINT 'Fetching next receipt from receipt_info cursor'

			-- Next receipt Line
			FETCH receipt_info
			INTO @link_company_id
				,@link_profit_ctr_id
				,@link_workorder_id
				,@customer
				,@trip_stop_rate_flag
				,@manifest
				,@manifest_flag
				,@receipt_company_id
				,@receipt_profit_ctr_id
				,@generator
				,@billing_project_id
				,@purchase_order
				,@release_code
				,@po_sequence_id
				,@quantity
				,@tsdf_approval_code
				,@manifest_page_num
				,@manifest_line
				,@manifest_line_id
				,@container_count
				,@container_code
				,@manifest_quantity
				,@manifest_unit
				,@profile_id
				,@dot_shipping_name
				,@waste_code
				,@management_code
				,@reportable_quantity_flag
				,@rq_reason
				,@hazmat
				,@hazmat_class
				,@subsidiary_haz_mat_class
				,@un_na_flag
				,@un_na_number
				,@package_group
				,@erg_number
				,@erg_suffix
				,@drmo_clin_num
				,@drmo_hin_num
				,@drmo_doc_num
				,@continuation_flag
				,@epa_id
				,@tsdf_approval_code
				,@start_date
				,@invoice_comment1
				,@invoice_comment2
				,@invoice_comment3
				,@invoice_comment4
				,@invoice_comment5
				,@pounds
				,@waste_flag
				,@stop_id
				,@wod_sequence_id
				,@generate_stock_container
				,@dest_cc_id
				,@in_the_lab_count
				,@manifest_state
				,@corporate_revenue_classification_uid
				,@DOT_shipping_desc_additional
				,@DOT_waste_flag
				,@profile_labpack_flag
		END

		CLOSE receipt_info

		DEALLOCATE receipt_info

		-- *************************************************************************************
		-- Done with last receipt
		-- *************************************************************************************
		FETCH manifest_info
		INTO @company_id
			,@profit_ctr_id
			,@manifest
			,@tsdf_code
			,@generator_sign_name
			,@generator_sign_date
	END

	CLOSE manifest_info

	DEALLOCATE manifest_info
		-- *************************************************************************************
		-- Done with last manifest
		-- *************************************************************************************
		-- **************************************************************************************
		-- This end matches the begin to see if there are any rows to convert
		-- **************************************************************************************
END

EXIT_OR_ERROR:

IF @debug = 1
	PRINT 'Return Code ' + CONVERT(VARCHAR, @return_Code)

IF @return_code = - 1
BEGIN
	CLOSE receipt_info

	DEALLOCATE receipt_info

	CLOSE manifest_info

	DEALLOCATE manifest_info

	ROLLBACK TRANSACTION --trip_convert

	IF @debug = 1
		PRINT 'Transaction Rolled Back'

	SET @error_msg = 'Trip Completion Process Failed'

	RAISERROR (
			@error_msg
			,16
			,1
			)
END
ELSE IF @return_code = - 2
BEGIN
	ROLLBACK TRANSACTION --trip_convert

	IF @debug = 1
		PRINT 'Transaction Rolled Back'

	SET @error_msg = 'Trip Completion Process Failed - Not in Unloading Status'

	RAISERROR (
			@error_msg
			,16
			,1
			)
END
ELSE
BEGIN
	-- rb 10/22/2013 Automatically generate stock containers if any are set up to
	SET @user = left(@user, 10)

	EXEC @return_code = sp_trip_complete_generate_stock_containers @trip_company_id
		,@trip_profit_ctr_id
		,@trip_ID
		,@complete_tsdf_code
		,@user
		,@debug

	IF @return_code < 0
	BEGIN
		ROLLBACK TRANSACTION --trip_convert

		IF @debug = 1
			PRINT 'Transaction Rolled Back'

		SET @error_msg = 'Trip Completion Process Failed - Generating Stock Containers'

		RAISERROR (
				@error_msg
				,16
				,1
				)

		--RETURN - 1
		SELECT - 1
	END

	IF @debug = 1
		PRINT 'Inserting into Audit'

	INSERT INTO dbo.tripaudit (
		trip_id
		,table_name
		,column_name
		,before_value
		,after_value
		,audit_reference
		,modified_from
		,modified_by
		,date_modified
		)
	VALUES (
		@trip_id
		,'TripHeader'
		,'trip_status'
		,'U'
		,
		-- rb 11/08/2012 Complete now processes by TSDF
		--				'C for ' + Cast( @complete_company_id AS VARCHAR ) + '-' + Cast( @complete_profit_ctr_id AS VARCHAR ),
		'C for ' + @complete_tsdf_code
		,'Trip Complete Procedure'
		,'EQAI'
		,@user
		,GetDate()
		)

	SELECT @ll_count = count(DISTINCT wd.tsdf_code) - (
			SELECT count(*)
			FROM TripCompleteTSDF
			WHERE trip_id = @trip_id
				AND isnull(STATUS, '') = 'C'
			)
	FROM dbo.WorkOrderHeader AS wh
	JOIN dbo.WorkOrderDetail AS wd 
		ON wh.workorder_id = wd.workorder_id
		AND wh.company_id = wd.company_id
		AND wh.profit_ctr_id = wd.profit_ctr_id
		AND wd.resource_type = 'D'
		AND wd.tsdf_code IS NOT NULL
		AND wd.bill_rate > - 2
	WHERE wh.trip_id = @trip_id
		AND isnull(wh.workorder_status, '') <> 'V'

	IF @debug = 1
		--				PRINT 'Uncompleted Receipts = ' + +CONVERT( VARCHAR, @ll_count )
		PRINT 'Uncompleted TSDFs = ' + + CONVERT(VARCHAR, @ll_count)

	IF @ll_count = 0
	BEGIN
		-- rb 02/11/2016 If auto-completing all void disposal tsdfs, ensure that TripCompleteTSDF is populated
		INSERT dbo.TripCompleteTSDF (
			trip_id
			,tsdf_code
			,added_by
			,date_added
			,modified_by
			,date_modified
			,STATUS
			)
		SELECT DISTINCT @trip_ID
			,wd.tsdf_code
			,@user
			,GETDATE()
			,@user
			,GETDATE()
			,'C'
		FROM dbo.WorkOrderHeader AS wh
		JOIN dbo.WorkOrderDetail AS wd 
			ON wh.workorder_id = wd.workorder_id
			AND wh.company_id = wd.company_id
			AND wh.profit_ctr_id = wd.profit_ctr_id
			AND wd.resource_type = 'D'
			AND wd.tsdf_code <> @complete_tsdf_code
		WHERE wh.trip_id = @trip_id
			AND isnull(wh.workorder_status, '') <> 'V'
			AND NOT EXISTS (
				SELECT 1
				FROM dbo.WorkOrderDetail
				WHERE workorder_id = wh.workorder_id
					AND company_id = wh.company_id
					AND profit_ctr_id = wh.profit_ctr_id
					AND resource_type = 'D'
					AND tsdf_code = wd.tsdf_code
					AND bill_rate > - 2
				)
			AND NOT EXISTS (
				SELECT 1
				FROM dbo.TripCompleteTSDF
				WHERE trip_id = @trip_ID
					AND tsdf_code = wd.tsdf_code
				)

		UPDATE dbo.TripCompleteTSDF
		SET STATUS = 'C'
		WHERE trip_id = @trip_id

		-- rb 09/06/2012 Added check for 3rd party disposals not completed yet
		IF EXISTS (
				SELECT 1
				FROM dbo.TripHeader
				WHERE trip_id = @trip_id
					AND isnull(third_party_complete_flag, 'F') = 'T'
				)
			OR NOT EXISTS (
				SELECT 1
				FROM dbo.TripHeader AS th
				JOIN dbo.WorkOrderHeader AS woh 
					ON th.trip_id = woh.trip_id
					AND woh.workorder_status <> 'V'
				JOIN dbo.WorkOrderDetail AS wod 
					ON woh.workorder_id = wod.workorder_id
					AND woh.company_id = wod.company_id
					AND woh.profit_ctr_id = wod.profit_ctr_id
					AND wod.resource_type = 'D'
					AND bill_rate > - 2
				JOIN TSDF t ON wod.tsdf_code = t.tsdf_code
					AND isnull(t.eq_flag, 'F') = 'F'
				WHERE th.trip_id = @trip_id
				)
		BEGIN
			IF @debug = 1
				PRINT 'Setting status to complete...'

			-- Update TripHeader to a status of Complete
			UPDATE dbo.tripheader
			SET trip_status = 'C'
			WHERE trip_id = @trip_id

			UPDATE dbo.tripheader
			SET third_party_complete_flag = 'T'
			WHERE trip_id = @trip_id

			-- Insert Into Trip Audit that we changed the Status
			INSERT INTO dbo.tripaudit (
				trip_id
				,table_name
				,column_name
				,before_value
				,after_value
				,audit_reference
				,modified_from
				,modified_by
				,date_modified
				)
			VALUES (
				@trip_id
				,'TripHeader'
				,'trip_status'
				,'U'
				,'C'
				,'Trip Complete Procedure'
				,'EQAI'
				,@user
				,GetDate()
				)

			SET @trip_status = 'C'
		END
	END

	COMMIT TRANSACTION --trip_convert

	IF @debug = 1
		PRINT 'Transaction Committed'
END
GO

GRANT EXECUTE
    ON OBJECT::[dbo].[sp_trip_complete] TO [EQAI];