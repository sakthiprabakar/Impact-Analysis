DROP PROCEDURE IF EXISTS sp_trip_update_approval
GO

CREATE PROCEDURE sp_trip_update_approval (
	@trip_id			int, 
	@company_id			int, 
	@profit_ctr_id		int, 
	@tsdf_approval_id	int,
	@profile_id			int, 
	@rows				int		output) 
WITH RECOMPILE
AS
/*******************************************************************************************
02/24/2010 KAM	Created
03/11/2010 JDB	Added auditing
03/15/2010 JDB	Fixed audit of manifest waste description for Profiles
07/15/2011 JDB	Removed the insert of the audit record into WorkOrderAudit table because
				it was taking a very long time.
10/17/2011 JDB	Modified this SP to also re-populate the WorkOrderWasteCode tables from
				the profile/TSDF approval.  Also added variables for the work order's CO/PC.
03/29/2013 RWB	Added waste_code_uid column to WorkOrderWasteCode insert. Also qualified insert statement with column names.
08/14/2013 JDB	Modified to populate WorkOrderWasteCode records using the new table-valued function (dbo.fn_tbl_manifest_waste_codes) 
				for calculating the top 6 manifest waste codes.
10/16/2013 RWB	Added SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED to hopefully stop blocking that is occurring
06/06/2014 RWB	After monitoring this procedure taking 1.5-2.0 minutes for approvals, and debugging, discovered that the cursor
		was taking all of the time. Restructured select to be logically the same, but proc now runs in a fraction of a second.
04/30/2015 RWB	bill_rate needs to be set to manifest-only if the TSDF.eq_flag = 'T' or WorkOrderHeader.trip_stop_rate_flag = 'T'
07/12/2021 MPM	DevOps 21779 - Rewrote in an attempt to improve efficiencies and prevent DB blocking.
02/24/2022 MPM	DevOps 37276 - Modified to update newer WorkOrderDetail columns DOT_waste_flag and DOT_shipping_desc_additional.

sp_trip_update_approval 18345, 21, 0, 0, 424422, 0

SELECT * FROM WorkOrderWasteCode WHERE workorder_id = 2818400 AND company_id = 15 AND profit_ctr_id = 1
*******************************************************************************************/
DECLARE @waste_stream					Varchar(10),
		@waste_code						Varchar(4),
		@waste_description				Varchar(50),
		@bill_rate						Float,
		@container_code					Varchar(15),
		@wt_vol_unit					Varchar(15),
		@dot_shipping_name				Varchar(255),
		@hand_instruct					Varchar(255),
		@waste_desc						Varchar(50),
		@management_code				Varchar(4),
		@rq_flag						Char(1),
		@rq_reason						Varchar(50),
		@hazmat							Char(1),
		@hazmat_class					varchar(15),
		@sub_haz_mat_class				varchar(15),
		@un_na_flag						Char(2),
		@package_group					varchar(3),
		@man_handling_code				varchar(15),
		@man_wt_vol_unit				varchar(15),
		@un_na_number					int,
		@erg_number						int,
		@erg_suffix						char(2),
		@man_dot_sp_num					varchar(20),
		@broker_flag					char(1),
		@ldr_req_flag					char(1),
		@manifest_waste_desc			Varchar(50),
		@user_name						varchar(32),
		@save_date						datetime,
		@wo_company_id					int,
		@wo_profit_ctr_id				int,
		@workorder_id					int,
		@generator_id					int,
		@TSDF_code						varchar(15),
		@manifest						varchar(15),
		@DOT_waste_flag					char(1),
		@DOT_shipping_desc_additional	varchar(255)
		
-- rb 10/16/2013
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
		
SELECT @user_name = SUSER_SNAME()

IF RIGHT(@user_name, 3) = '(2)'
	SET @user_name = LEFT(@user_name, LEN(@user_name) - 3)

SELECT @save_date = GETDATE()

SELECT	@wo_company_id = company_id,
		@wo_profit_ctr_id = profit_ctr_id
FROM TripHeader WHERE trip_id = @trip_id

CREATE TABLE #manifestwastecodes (
	generator_id		int			NULL,
	TSDF_code			varchar(15)	NULL,
	waste_code_uid		int			NULL,
	waste_code			varchar(4)	NULL,
	storage_sequence_id	int			NULL
)

BEGIN TRANSACTION APP_UPDATE

If IsNull(@profile_id,0) = 0 and @tsdf_approval_id > 0
Begin

	--select 'TSDF Approval'

	-- Save work order info in #wod
	SELECT wod.company_id, wod.profit_ctr_id, wod.workorder_id, wod.sequence_id, woh.generator_id, wod.TSDF_code
	INTO #wod
	FROM WorkOrderDetail wod
	JOIN WorkOrderHeader woh
		ON woh.company_id = wod.company_id
		AND woh.profit_ctr_id = wod.profit_ctr_id
		AND woh.workorder_id = wod.workorder_id
		AND woh.trip_id = @trip_id
	WHERE wod.company_id = @company_id
	AND wod.profit_ctr_id = @profit_ctr_id
	AND wod.TSDF_approval_id = @tsdf_approval_id
	AND wod.bill_rate > -2
	AND wod.resource_type = 'D'

	-- Save distinct generator_id/TSDF_code combos in #generator_tsdf
	SELECT DISTINCT generator_id, TSDF_code
	INTO #generator_tsdf
	FROM #wod 

	DECLARE WO_Cursor CURSOR FORWARD_ONLY READ_ONLY FOR
	SELECT generator_id, TSDF_code
	FROM #generator_tsdf
		
	OPEN WO_Cursor
	FETCH NEXT FROM WO_Cursor INTO @generator_id, @TSDF_code

	WHILE @@FETCH_STATUS = 0
	BEGIN
		-- Insert waste codes from table function fn_tbl_manifest_waste_codes to #manifestwastecodes
		INSERT #manifestwastecodes
		SELECT	@generator_id,
				@TSDF_code,
				manifestwastecodes.waste_code_uid,
				manifestwastecodes.waste_code,
				manifestwastecodes.storage_sequence_id
		FROM dbo.fn_tbl_manifest_waste_codes('TSDFApproval', @TSDF_approval_id, @generator_id, @TSDF_code) manifestwastecodes 
		WHERE manifestwastecodes.use_for_storage = 1
		AND manifestwastecodes.storage_sequence_id BETWEEN 1 AND 6

		FETCH NEXT FROM WO_Cursor INTO @generator_id, @TSDF_code
	END

	CLOSE WO_Cursor
	DEALLOCATE WO_Cursor

	--select 'select * from #manifestwastecodes'
	--select * from #manifestwastecodes

	---- For TSDF Approvals
	SELECT @waste_stream = TSDFApproval.waste_stream,
		--@waste_code =	TSDFApproval.waste_code,
		@waste_description = TSDFApproval.waste_desc,
 		@container_code = TSDFApproval.manifest_container_code,
		@wt_vol_unit = TSDFApproval.manifest_wt_vol_unit,
		@dot_shipping_name = TSDFApproval.DOT_shipping_name,
		@hand_instruct = TSDFApproval.hand_instruct, 
		@management_code = TSDFApproval.management_code, 
		@rq_flag = TSDFApproval.reportable_quantity_flag, 
		@rq_reason = TSDFApproval.RQ_reason,
		@hazmat = TSDFApproval.hazmat, 
		@hazmat_class = TSDFApproval.hazmat_class, 
		@sub_haz_mat_class = TSDFApproval.subsidiary_haz_mat_class, 
		@un_na_flag = TSDFApproval.UN_NA_flag,
		@package_group = TSDFApproval.package_group, 
		@man_handling_code = TSDFApproval.manifest_handling_code, 
		--@man_wt_vol_unit = TSDFApproval.manifest_wt_vol_unit,
		@un_na_number = TSDFApproval.UN_NA_number, 
		@erg_number = TSDFApproval.ERG_number, 
		@erg_suffix = IsNUll(TSDFApproval.ERG_suffix, ''), 
		@man_dot_sp_num = TSDFApproval.manifest_dot_sp_number,
		@bill_rate = 1,				--Always set bill rate to STD for TSDF approvals
		@DOT_waste_flag = TSDFApproval.DOT_waste_flag,
		@DOT_shipping_desc_additional = TSDFApproval.DOT_shipping_desc_additional
	FROM TSDFApproval
	INNER JOIN TSDF ON TSDF.TSDF_code = TSDFapproval.TSDF_code
	WHERE TSDFApproval.TSDF_approval_status = 'A'
		AND TSDF.TSDF_status = 'A'
		and TSDFApproval.TSDF_approval_id = @tsdf_approval_id
  		and TSDFApproval.company_id = @company_id
  		and TSDFApproval.profit_ctr_id = @profit_ctr_id

	-- Update the trip Rows
	Update WorkorderDetail 
	Set waste_stream = @waste_stream,
		--waste_code = @waste_code,
		description = @waste_description,
		container_code = @container_code,
		manifest_wt_vol_unit = @man_wt_vol_unit,
		DOT_shipping_name = @dot_shipping_name,
		manifest_hand_instruct = @hand_instruct,
		manifest_waste_desc = @waste_description,
		management_code = @management_code,
		reportable_quantity_flag = @rq_flag,
		RQ_reason = @rq_reason,
		hazmat = @hazmat,
		hazmat_class = @hazmat_class,
		subsidiary_haz_mat_class = @sub_haz_mat_class,
		UN_NA_flag = @un_na_flag,
		UN_NA_number = @un_na_number,
		package_group = @package_group,
		manifest_handling_code = @man_handling_code,
		ERG_number = @erg_number,
		ERG_suffix = @erg_suffix,
		manifest_dot_sp_number = @man_dot_sp_num,
		bill_rate = case when isnull(t.eq_flag,'') = 'T' or isnull(wh.trip_stop_rate_flag,'') = 'T' then -1 else @bill_rate end,
		DOT_waste_flag = @DOT_waste_flag,
		DOT_shipping_desc_additional = @DOT_shipping_desc_additional
		--manifest_unit = @man_wt_vol_unit
	From #wod
	Join TSDF t
		on #wod.tsdf_code = t.tsdf_code 
		and t.tsdf_status = 'A'
	Join WorkorderHeader wh
		on #wod.workorder_id = wh.workorder_id
		and #wod.company_id = wh.company_id
		and #wod.profit_ctr_id = wh.profit_ctr_id
	WHERE WorkorderDetail.workorder_id = #wod.workorder_id
		and WorkorderDetail.company_id = #wod.company_id
		and WorkorderDetail.profit_ctr_id = #wod.profit_ctr_id	
		and WorkOrderDetail.sequence_id = #wod.sequence_id
		and WorkOrderDetail.resource_type = 'D'

	SELECT @rows = @@ROWCOUNT

	--select 'Just updated ' + cast(@rows as varchar(10)) + ' rows in WorkOrderDetail'
		
	-- Delete the existing WorkOrderWasteCode records
	DELETE WorkOrderWasteCode
	FROM WorkOrderWasteCode wowc
	JOIN #wod 
		ON #wod.company_id = wowc.company_id
		AND #wod.profit_ctr_ID = wowc.profit_ctr_id
		AND #wod.workorder_ID = wowc.workorder_id
		AND #wod.sequence_ID = wowc.workorder_sequence_id
		AND #wod.company_id = @wo_company_id
		AND #wod.profit_ctr_ID = @wo_profit_ctr_id

	--select 'Just deleted ' + cast(@@ROWCOUNT as varchar(10)) + ' rows from WorkOrderWasteCode'

	-- Insert new WorkOrderWasteCode records
	INSERT WorkOrderWasteCode (company_id, profit_ctr_id, workorder_id, workorder_sequence_id, waste_code, sequence_id, added_by, date_added, waste_code_uid)
	SELECT #wod.company_id,
		#wod.profit_ctr_ID,
		#wod.workorder_ID,
		#wod.sequence_ID AS workorder_sequence_id,
		#manifestwastecodes.waste_code,
		#manifestwastecodes.storage_sequence_id,
		@user_name AS added_by,
		@save_date AS date_added,
		#manifestwastecodes.waste_code_uid
	FROM #wod 
	JOIN #manifestwastecodes
		ON #manifestwastecodes.generator_id = #wod.generator_id
		AND #manifestwastecodes.TSDF_code = #wod.TSDF_code

	--select 'Just inserted ' + cast(@@ROWCOUNT as varchar(10)) + ' rows into WorkOrderWasteCode'

End
Else
Begin
	If @profile_id > 0 and @tsdf_approval_id = 0
	Begin

		--select 'Profile'

		-- Save work order info in #wod2
		SELECT wod.company_id, wod.profit_ctr_id, wod.workorder_id, wod.sequence_id, woh.generator_id, wod.TSDF_code, wod.profile_company_id, wod.profile_profit_ctr_id
		INTO #wod2
		FROM WorkOrderDetail wod
		JOIN WorkOrderHeader woh
			ON woh.company_id = wod.company_id
			AND woh.profit_ctr_id = wod.profit_ctr_id
			AND woh.workorder_id = wod.workorder_id
			AND woh.trip_id = @trip_id
		WHERE wod.company_id = @wo_company_id
		AND wod.profit_ctr_id = @wo_profit_ctr_id
		AND wod.profile_id = @profile_id
		AND wod.bill_rate > -2
		AND wod.resource_type = 'D'

		--select 'select * from #wod2'
		--select * from #wod2

		-- Save distinct generator_id/TSDF_code combos in #generator_tsdf2
		SELECT DISTINCT generator_id, TSDF_code
		INTO #generator_tsdf2
		FROM #wod2

		--select 'select * from #generator_tsdf2'
		--select * from #generator_tsdf2

		DECLARE WO_Cursor CURSOR FORWARD_ONLY READ_ONLY FOR
		SELECT generator_id, TSDF_code
		FROM #generator_tsdf2
		
		OPEN WO_Cursor
		FETCH NEXT FROM WO_Cursor INTO @generator_id, @TSDF_code

		WHILE @@FETCH_STATUS = 0
		BEGIN
			-- Insert waste codes from table function fn_tbl_manifest_waste_codes to #manifestwastecodes
			INSERT #manifestwastecodes
			SELECT	@generator_id,
					@TSDF_code,
					manifestwastecodes.waste_code_uid,
					manifestwastecodes.waste_code,
					manifestwastecodes.storage_sequence_id
			FROM dbo.fn_tbl_manifest_waste_codes('Profile', @profile_id, @generator_id, @TSDF_code) manifestwastecodes 
			WHERE manifestwastecodes.use_for_storage = 1
			AND manifestwastecodes.storage_sequence_id BETWEEN 1 AND 6

			FETCH NEXT FROM WO_Cursor INTO @generator_id, @TSDF_code
		END

		CLOSE WO_Cursor
		DEALLOCATE WO_Cursor
		
		--select 'select * from #manifestwastecodes'
		--select * from #manifestwastecodes

		-- For Profile Approvals
		SELECT --@waste_code = Profile.waste_code,
			@waste_desc = Profile.approval_desc,
			@broker_flag = Profile.broker_flag,
			@container_code = Profile.manifest_container_code,
			@dot_shipping_name = Profile.DOT_shipping_name, 
			@hand_instruct = Profile.manifest_hand_instruct,
			@manifest_waste_desc = COALESCE(Profile.manifest_waste_desc, Profile.approval_desc), 
			@waste_description = Profile.approval_desc, 
			@management_code = Treatment.management_code, 
			@rq_flag = Profile.reportable_quantity_flag, 
			@rq_reason = Profile.RQ_reason,
			@hazmat = Profile.hazmat, 
			@hazmat_class = Profile.hazmat_class, 
			@sub_haz_mat_class = Profile.subsidiary_haz_mat_class, 
			@un_na_flag = Profile.UN_NA_flag,
			@package_group = Profile.package_group, 
			@man_handling_code = Profile.manifest_handling_code, 
			--@man_wt_vol_unit = Profile.manifest_wt_vol_unit,
			@un_na_number = Profile.UN_NA_number, 
			@erg_number = Profile.ERG_number, 
			@erg_suffix = ISNULL(Profile.ERG_suffix, ''),
			@man_dot_sp_num = Profile.manifest_dot_sp_number,
			@DOT_waste_flag = Profile.DOT_waste_flag,
			@DOT_shipping_desc_additional = Profile.DOT_shipping_desc_additional
		FROM Profile
		INNER JOIN ProfileQuoteApproval 
			ON Profile.profile_id = ProfileQuoteApproval.profile_id
		JOIN Treatment 
			ON ProfileQuoteApproval.treatment_id = Treatment.treatment_id
			AND ProfileQuoteApproval.company_id = Treatment.company_id
			AND ProfileQuoteApproval.profit_ctr_id = Treatment.profit_ctr_id
		WHERE ProfileQuoteApproval.profile_id = @profile_id
		AND ProfileQuoteApproval.company_id = @company_id
		AND ProfileQuoteApproval.profit_ctr_id = @profit_ctr_id
		AND profile.curr_status_code = 'A'

		If @broker_flag = 'D' or @broker_flag = 'I'
			Select @bill_rate = -1
		Else
			Select @bill_rate = 1
				
		-- Update the trip Rows
		Update WorkorderDetail 
		Set --waste_code = @waste_code,
			description = @waste_description,
			container_code = @container_code,
			manifest_wt_vol_unit = @man_wt_vol_unit,
			DOT_shipping_name = @dot_shipping_name,
			manifest_hand_instruct = @hand_instruct,
			manifest_waste_desc = @manifest_waste_desc,
			management_code = @management_code,
			reportable_quantity_flag = @rq_flag,
			RQ_reason = @rq_reason,
			hazmat = @hazmat,
			hazmat_class = @hazmat_class,
			subsidiary_haz_mat_class = @sub_haz_mat_class,
			UN_NA_flag = @un_na_flag,
			UN_NA_number = @un_na_number,
			package_group = @package_group,
			manifest_handling_code = @man_handling_code,
			ERG_number = @erg_number,
			ERG_suffix = @erg_suffix,
			manifest_dot_sp_number = @man_dot_sp_num,
			bill_rate = case when isnull(t.eq_flag,'') = 'T' or isnull(wh.trip_stop_rate_flag,'') = 'T' then -1 else @bill_rate end,
			DOT_waste_flag = @DOT_waste_flag,
			DOT_shipping_desc_additional = @DOT_shipping_desc_additional
		--manifest_unit = @man_wt_vol_unit
		From #wod2
		Join TSDF t
			on #wod2.tsdf_code = t.tsdf_code 
			and t.tsdf_status = 'A'
		Join WorkorderHeader wh
			on #wod2.workorder_id = wh.workorder_id
			and #wod2.company_id = wh.company_id
			and #wod2.profit_ctr_id = wh.profit_ctr_id
		WHERE WorkOrderDetail.company_id = #wod2.company_id
		AND WorkOrderDetail.profit_ctr_id = #wod2.profit_ctr_id
		AND WorkOrderDetail.workorder_id = #wod2.workorder_id
		AND WorkOrderDetail.sequence_id = #wod2.sequence_id
		AND WorkOrderDetail.resource_type = 'D'
		AND #wod2.company_id = @wo_company_id
		AND #wod2.profit_ctr_id = @wo_profit_ctr_id
		AND #wod2.profile_company_id = @company_id
		AND #wod2.profile_profit_ctr_id = @profit_ctr_id
				
		SELECT @rows = @@ROWCOUNT
			
		--select 'Just updated ' + cast(@rows as varchar(10)) + ' rows in WorkOrderDetail'

		-- Delete the existing WorkOrderWasteCode records
		DELETE WorkOrderWasteCode
		FROM WorkOrderWasteCode wowc
		JOIN #wod2 
			ON #wod2.company_id = wowc.company_id
			AND #wod2.profit_ctr_ID = wowc.profit_ctr_id
			AND #wod2.workorder_ID = wowc.workorder_id
			AND #wod2.sequence_ID = wowc.workorder_sequence_id
		WHERE #wod2.company_id = @wo_company_id
		AND #wod2.profit_ctr_ID = @wo_profit_ctr_id

		--select 'Just deleted ' + cast(@@ROWCOUNT as varchar(10)) + ' rows from WorkOrderWasteCode'

		INSERT WorkOrderWasteCode (company_id, profit_ctr_id, workorder_id, workorder_sequence_id, waste_code, sequence_id, added_by, date_added, waste_code_uid)
		SELECT #wod2.company_id,
			#wod2.profit_ctr_ID,
			#wod2.workorder_ID,
			#wod2.sequence_ID AS workorder_sequence_id,
			#manifestwastecodes.waste_code,
			#manifestwastecodes.storage_sequence_id,
			@user_name AS added_by,
			@save_date AS date_added,
			#manifestwastecodes.waste_code_uid
		FROM #wod2 
		JOIN #manifestwastecodes
			ON #manifestwastecodes.generator_id = #wod2.generator_id
			AND #manifestwastecodes.TSDF_code = #wod2.TSDF_code

		--select 'Just inserted ' + cast(@@ROWCOUNT as varchar(10)) + ' rows into WorkOrderWasteCode'

	End	
End

COMMIT TRANSACTION APP_UPDATE
RETURN @rows

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_trip_update_approval] TO [EQAI]
    AS [dbo];

