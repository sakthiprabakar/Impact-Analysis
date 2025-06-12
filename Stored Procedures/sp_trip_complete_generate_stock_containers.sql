SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE [dbo].[sp_trip_complete_generate_stock_containers]
	@trip_company_id int,
	@trip_profit_ctr_id int,
	@trip_id int,
	@tsdf_code varchar(15),
	@user varchar(10),
	@debug int = null
--WITH RECOMPILE
AS
/************************************************************************************************* 
Loads to :    PLT_AI

10/29/2013 RB	This procedure is called by sp_trip_complete if a trip is setup to automatically
		generate Stock containers (generates Receipt Container and Stock Container records).
12/06/2013 RB	Was only creating containers if they were activated and entered into WorkOrderDetailCC.
		It turns out they can print a label and enter the number as well (so Container records
		not created). Modified to insert Container/ContainerDestination records if they don't exist.
12/09/2013 RB	Bugfix...when generating base_tracking_num, container_id section was not being zero-padded
05/04/2015 RB	After Kroger Invoicing, base_tracking_num was being set for Kroger customers
07/21/2015 RB	If all of the receipt lines that are being consolidated into the stock container are for the
				same approval, populate outbound location and approval information in ContainerDestination
09/10/2015 RB	Now that the MIM uploads container_type and container_size, include them on Container record
09/29/2015 RB	container size and type were combos of null and empty string, distinct query started failing
10/01/2015 RB	Query for container_type and container_size since EQAI allowed corruption of data which broke group by in main cursor
08/24/2017 RWB	After an NTSQL1 system crash, trip complete started going to lunch and not completing. Added WITH RECOMPILE in case this is index/procedure cache related
12/14/2017 JCG	Zach's change to add tax_code_uid to Consolidation. EQAI-47065  Tax Codes not assigned to containers on trip completion/consolidation to stock containers
01/10/2018 AM	Added code for consolidation_group_uid.
05/02/2018 MPM	GEM 50240 - Added code for air_permit_status_uid.
08/02/2018 MPM	GEM  52425 - Changed call to fn_get_product_tax_code after changing the input parameters to this function.
07/26/2019 RB	SA-13302 Duplicate ContainerConstituent for LabPack	  
09/12/2020 RB	ME-54548 Trip complete for 3 trips in 47-00 suddenly started reporting: Warning: NULL value is eliminated by an aggregate or other SET operation
08/27/2021 MPM	DevOps 27596 - Modified so that values are getting set on the resultant stock container in the scenario 
				where there is more than 1 profile being consolidated into the same container.
04/10/2024 KS	DevOps 78209 - Added schema reference, formatting update, and OPTIMIZE FOR UNKNOWN for better perfromance with peramiter sniffing

*************************************************************************************************/
DECLARE @container_count INT
	,@dest_cc_id INT
	,@seq_dest_cc_id INT
	,@w_id INT
	,@c_id INT
	,@p_id INT
	,@cc_id INT
	,@p_treatment_id INT
	,@weight DECIMAL(10, 3)
	,@initial_tran_count INT
	,@container_id INT
	,@receipt_container_count INT
	,@cc_percentage DECIMAL(8, 3)
	,@bulk_flag CHAR(1)
	,@staging_row VARCHAR(5)
	,@receipt_id INT
	,@line_id INT
	,@sequence_id INT
	,@treatment_id INT
	,@tracking_num VARCHAR(15)
	,@line_weight DECIMAL(18, 6)
	,@fract_weight DECIMAL(10, 2)
	,@summed_weight DECIMAL(10, 2)
	,@description VARCHAR(30)
	,@container_code VARCHAR(15)
	,@bill_unit_code VARCHAR(4)
	,@debug_msg VARCHAR(255)
	,@err_msg VARCHAR(255)
	,@location_type CHAR(1)
	,@location VARCHAR(15)
	,@profile_id INT
	,@tsdf_approval_id INT
	,@approval_code VARCHAR(40)
	,@ob_profile_id INT
	,@ob_company_id INT
	,@ob_profit_ctr_id INT
	,@ob_tsdf_approval_id INT
	,@waste_stream VARCHAR(10)
	,@container_type VARCHAR(2)
	,@container_size VARCHAR(4)
	,@tax_code_uid INT
	,@consolidation_group_uid INT
	,@air_permit_status_uid INT
	,@air_permit_flag CHAR(1)
	,@consolidation_group_flag CHAR(1)
	,@update_consolidation_group CHAR(1)
	,@update_air_permit_status CHAR(1)
	,@stock_container_approval_count INT

IF isnull(@debug, 0) = 1
BEGIN
	SET @debug_msg = 'exec sp_trip_complete_generate_stock_containers ' + convert(VARCHAR(10), @trip_id) + ', ''' + @tsdf_code + ''''

	PRINT @debug_msg
END

SET NOCOUNT ON

-- 07/21/2015 for outbound population
CREATE TABLE #outbound (
	company_id INT NOT NULL
	,profit_ctr_id INT NOT NULL
	,container_id INT NOT NULL
	,sequence_id INT NOT NULL
	,receipt_id INT NOT NULL
	,line_id INT NOT NULL
	)

-- record initial tran count
SELECT @initial_tran_count = @@TRANCOUNT

-- get count of distinct CCIDs
SELECT @container_count = count(DISTINCT wdc.consolidated_container_id)
FROM dbo.WorkOrderDetailCC AS wdc
JOIN dbo.WorkOrderDetail AS wd
	ON wdc.workorder_id = wd.workorder_id
	AND wdc.company_id = wd.company_id
	AND wdc.profit_ctr_id = wd.profit_ctr_id
	AND wdc.sequence_id = wd.sequence_id
	AND wd.resource_type = 'D'
	AND wd.bill_rate > - 2
	AND wd.TSDF_code = @tsdf_code
JOIN dbo.WorkOrderHeader AS wh 
	ON wd.workorder_id = wh.workorder_id
	AND wd.company_id = wh.company_id
	AND wd.profit_ctr_id = wh.profit_ctr_id
	AND wh.trip_id = @trip_id
WHERE isnull(wdc.generate_stock_container_flag, 'F') = 'T'
OPTION (OPTIMIZE FOR UNKNOWN)

IF isnull(@debug, 0) = 1
BEGIN
	SET @debug_msg = '# of distinct consolidated_container_ids to autogenerate: ' + convert(VARCHAR(10), @container_count)

	PRINT @debug_msg
END

-- activate # of stock containers for TSDF EQ company/profit_ctr
SELECT @c_id = eq_company
	,@p_id = eq_profit_ctr
FROM TSDF(NOLOCK)
WHERE TSDF_code = @tsdf_code

IF isnull(@debug, 0) = 1
BEGIN
	SET @debug_msg = 'TSDF company_id=' + isnull(convert(VARCHAR(10), @c_id), '') + ', profit_ctr_id=' + isnull(convert(VARCHAR(10), @p_id), '')

	PRINT @debug_msg
END

-- MPM - 5/2/2018 - Get the air permit flag and the consolidation_group_flag.
-- If consolidation_group_flag = T, then we need to update ContainerDestination.consolidation_group_uid.
-- If air permit flag = T, then we need to update ContainerDestination.air_permit_status_uid.
SELECT @air_permit_flag = ISNULL(air_permit_flag, 'F')
	,@consolidation_group_flag = ISNULL(consolidation_group_flag, 'F')
FROM ProfitCenter
WHERE company_id = @c_id
	AND profit_ctr_id = @p_id

IF isnull(@debug, 0) = 1
BEGIN
	SET @debug_msg = '@air_permit_flag = ' + @air_permit_flag + ', @consolidation_group_flag = ' + @consolidation_group_flag

	PRINT @debug_msg
END

-- if no containers to generate, return
IF @container_count > 0
BEGIN
	UPDATE ProfitCenter
	SET next_container_label_id = next_container_label_id + @container_count
	WHERE company_id = @c_id
		AND profit_ctr_id = @p_id

	IF @@ERROR <> 0
	BEGIN
		SET @err_msg = 'ERROR: Unable to update next_container_label_id in ProfitCenter table'

		GOTO ON_ERROR
	END

	-- retrieve the first stock container number to use
	SELECT @seq_dest_cc_id = next_container_label_id - @container_count
	FROM ProfitCenter
	WHERE company_id = @c_id
		AND profit_ctr_id = @p_id

	IF @seq_dest_cc_id IS NULL
		OR @seq_dest_cc_id < 1
	BEGIN
		SET @err_msg = 'ERROR: Unable to select next_container_label_id from ProfitCenter table'

		GOTO ON_ERROR
	END

	IF isnull(@debug, 0) = 1
	BEGIN
		SET @debug_msg = 'Next available destination_container_id: ' + convert(VARCHAR(10), @seq_dest_cc_id)

		PRINT @debug_msg
	END
END

-- update WorkOrderDetailCC with #s
IF isnull(@debug, 0) = 1
	PRINT 'begin transaction'

BEGIN TRANSACTION

DECLARE c_loop_cc CURSOR FAST_FORWARD
FOR
SELECT DISTINCT wdc.consolidated_container_id
	,wdc.destination_container_id
	,pqa.treatment_id --, pqa.consolidation_group_uid, pqa.air_permit_status_uid
FROM dbo.WorkOrderDetailCC AS wdc
JOIN dbo.WorkOrderDetail AS wd 
	ON wdc.workorder_id = wd.workorder_id
	AND wdc.company_id = wd.company_id
	AND wdc.profit_ctr_id = wd.profit_ctr_id
	AND wdc.sequence_id = wd.sequence_id
	AND wd.resource_type = 'D'
	AND wd.bill_rate > - 2
	AND wd.TSDF_code = @tsdf_code
JOIN dbo.ProfileQuoteApproval AS pqa 
	ON wd.profile_company_id = pqa.company_id
	AND wd.profile_profit_ctr_id = pqa.profit_ctr_id
	AND wd.profile_id = pqa.profile_id
JOIN dbo.WorkOrderHeader AS wh 
	ON wd.workorder_id = wh.workorder_id
	AND wd.company_id = wh.company_id
	AND wd.profit_ctr_id = wh.profit_ctr_id
	AND wh.trip_id = @trip_id
WHERE (
		isnull(wdc.generate_stock_container_flag, 'F') = 'T'
		OR isnull(wdc.destination_container_id, 0) > 0
		)
OPTION (OPTIMIZE FOR UNKNOWN)

OPEN c_loop_cc

FETCH c_loop_cc
INTO @cc_id
	,@dest_cc_id
	,@p_treatment_id --,@consolidation_group_uid, @air_permit_status_uid

WHILE @@FETCH_STATUS = 0
BEGIN
	-- MPM - 5/3/2018 - GEM 50240
	-- Only set the consolidation_group_uid if there is only one across all approvals for all containers consolidated into the given stock container.
	-- Only set the air_permit_status_uid is there is only one across all approvals for all containers consolidated into the given stock container.
	SET @consolidation_group_uid = NULL
	SET @air_permit_status_uid = NULL
	SET @update_consolidation_group = 'F'
	SET @update_air_permit_status = 'F'

	IF isnull(@debug, 0) = 1
	BEGIN
		PRINT 'at top of c_loop_cc loop'
		PRINT '@cc_id = ' + CASE 
				WHEN @cc_id IS NULL
					THEN 'null'
				ELSE convert(VARCHAR(10), @cc_id)
				END + ', @dest_cc_id = ' + CASE 
				WHEN @dest_cc_id IS NULL
					THEN 'null'
				ELSE convert(VARCHAR(10), @dest_cc_id)
				END
	END

	IF @consolidation_group_flag = 'T'
	BEGIN
		IF (
				SELECT count(DISTINCT coalesce(pqa.consolidation_group_uid, 0))
				FROM dbo.WorkOrderDetailCC AS wdc
				JOIN dbo.WorkOrderDetail AS wd 
					ON wdc.workorder_id = wd.workorder_id
					AND wdc.company_id = wd.company_id
					AND wdc.profit_ctr_id = wd.profit_ctr_id
					AND wdc.sequence_id = wd.sequence_id
					AND wd.resource_type = 'D'
					AND wd.bill_rate > - 2
					AND wd.TSDF_code = @tsdf_code
				JOIN dbo.ProfileQuoteApproval AS pqa 
					ON wd.profile_company_id = pqa.company_id
					AND wd.profile_profit_ctr_id = pqa.profit_ctr_id
					AND wd.profile_id = pqa.profile_id
				JOIN dbo.WorkOrderHeader AS wh 
					ON wd.workorder_id = wh.workorder_id
					AND wd.company_id = wh.company_id
					AND wd.profit_ctr_id = wh.profit_ctr_id
					AND wh.trip_id = @trip_id
				WHERE (
						isnull(wdc.generate_stock_container_flag, 'F') = 'T'
						OR isnull(wdc.destination_container_id, 0) > 0
						)
					AND wdc.consolidated_container_id = @cc_id
				) = 1
		BEGIN
			IF isnull(@debug, 0) = 1
			BEGIN
				PRINT 'in count (distinct pqa.consolidation_group_uid) = 1 branch'
			END

			SELECT @consolidation_group_uid = nullif(max(coalesce(pqa.consolidation_group_uid, 0)), 0)
			FROM dbo.WorkOrderDetailCC AS wdc
			JOIN dbo.WorkOrderDetail AS wd 
				ON wdc.workorder_id = wd.workorder_id
				AND wdc.company_id = wd.company_id
				AND wdc.profit_ctr_id = wd.profit_ctr_id
				AND wdc.sequence_id = wd.sequence_id
				AND wd.resource_type = 'D'
				AND wd.bill_rate > - 2
				AND wd.TSDF_code = @tsdf_code
			JOIN dbo.ProfileQuoteApproval AS pqa 
				ON wd.profile_company_id = pqa.company_id
				AND wd.profile_profit_ctr_id = pqa.profit_ctr_id
				AND wd.profile_id = pqa.profile_id
			JOIN dbo.WorkOrderHeader AS wh 
				ON wd.workorder_id = wh.workorder_id
				AND wd.company_id = wh.company_id
				AND wd.profit_ctr_id = wh.profit_ctr_id
				AND wh.trip_id = @trip_id
			WHERE (
					isnull(wdc.generate_stock_container_flag, 'F') = 'T'
					OR isnull(wdc.destination_container_id, 0) > 0
					)
				AND wdc.consolidated_container_id = @cc_id
			OPTION (OPTIMIZE FOR UNKNOWN)

			SET @update_consolidation_group = 'T'
		END
	END

	IF @air_permit_flag = 'T'
	BEGIN
		IF (
				SELECT count(DISTINCT coalesce(pqa.air_permit_status_uid, 0))
				FROM dbo.WorkOrderDetailCC AS wdc
				JOIN dbo.WorkOrderDetail AS wd 
					ON wdc.workorder_id = wd.workorder_id
					AND wdc.company_id = wd.company_id
					AND wdc.profit_ctr_id = wd.profit_ctr_id
					AND wdc.sequence_id = wd.sequence_id
					AND wd.resource_type = 'D'
					AND wd.bill_rate > - 2
					AND wd.TSDF_code = @tsdf_code
				JOIN dbo.ProfileQuoteApproval AS pqa 
					ON wd.profile_company_id = pqa.company_id
					AND wd.profile_profit_ctr_id = pqa.profit_ctr_id
					AND wd.profile_id = pqa.profile_id
				JOIN dbo.WorkOrderHeader AS wh 
					ON wd.workorder_id = wh.workorder_id
					AND wd.company_id = wh.company_id
					AND wd.profit_ctr_id = wh.profit_ctr_id
					AND wh.trip_id = @trip_id
				WHERE (
						isnull(wdc.generate_stock_container_flag, 'F') = 'T'
						OR isnull(wdc.destination_container_id, 0) > 0
						)
					AND wdc.consolidated_container_id = @cc_id
				) = 1
		BEGIN
			IF isnull(@debug, 0) = 1
			BEGIN
				PRINT 'in count (distinct pqa.air_permit_status_uid) = 1 branch'
			END

			SELECT @air_permit_status_uid = nullif(max(coalesce(pqa.air_permit_status_uid, 0)), 0)
			FROM dbo.WorkOrderDetailCC AS wdc
			JOIN dbo.WorkOrderDetail AS wd 
				ON wdc.workorder_id = wd.workorder_id
				AND wdc.company_id = wd.company_id
				AND wdc.profit_ctr_id = wd.profit_ctr_id
				AND wdc.sequence_id = wd.sequence_id
				AND wd.resource_type = 'D'
				AND wd.bill_rate > - 2
				AND wd.TSDF_code = @tsdf_code
			JOIN dbo.ProfileQuoteApproval AS pqa 
				ON wd.profile_company_id = pqa.company_id
				AND wd.profile_profit_ctr_id = pqa.profit_ctr_id
				AND wd.profile_id = pqa.profile_id
			JOIN dbo.WorkOrderHeader AS wh 
				ON wd.workorder_id = wh.workorder_id
				AND wd.company_id = wh.company_id
				AND wd.profit_ctr_id = wh.profit_ctr_id
				AND wh.trip_id = @trip_id
			WHERE (
					isnull(wdc.generate_stock_container_flag, 'F') = 'T'
					OR isnull(wdc.destination_container_id, 0) > 0
					)
				AND wdc.consolidated_container_id = @cc_id
			OPTION (OPTIMIZE FOR UNKNOWN)

			SET @update_air_permit_status = 'T'
		END
	END

	IF isnull(@debug, 0) = 1
		PRINT 'before calculating total weight of container'

	-- calculate total weight of container
	SELECT @weight = ROUND(SUM(isnull(wdu.quantity, 0) * isnull(wdc.percentage * 0.01, 0)), 3)
	FROM dbo.WorkOrderDetailUnit AS wdu(NOLOCK)
	JOIN dbo.WorkOrderDetail AS wd(NOLOCK) 
		ON wdu.workorder_id = wd.workorder_id
		AND wdu.company_id = wd.company_id
		AND wdu.profit_ctr_id = wd.profit_ctr_id
		AND wdu.sequence_id = wd.sequence_id
		AND wd.resource_type = 'D'
		AND wd.TSDF_code = @tsdf_code
		AND wd.bill_rate > - 2
	JOIN dbo.WorkOrderDetailCC AS wdc(NOLOCK) 
		ON wd.workorder_id = wdc.workorder_id
		AND wd.company_id = wdc.company_id
		AND wd.profit_ctr_id = wdc.profit_ctr_id
		AND wd.sequence_id = wdc.sequence_id
		AND wdc.consolidated_container_id = @cc_id
	JOIN dbo.WorkOrderHeader AS wh 
		ON wd.workorder_ID = wh.workorder_ID
		AND wd.company_id = wh.company_id
		AND wd.profit_ctr_ID = wh.profit_ctr_ID
		AND wh.trip_id = @trip_id
	WHERE wdu.bill_unit_code = 'LBS'
	OPTION (OPTIMIZE FOR UNKNOWN)

	-- build stock container description	
	SELECT @description = left(ltrim(rtrim(wastetype_category + ' - ' + wastetype_description)), 30)
	FROM dbo.Treatment
	WHERE treatment_id = @p_treatment_id
		AND company_id = @c_id
		AND profit_ctr_id = @p_id

	-- query container_type and container_size...this uses max() because there is bad data where a screen change could null the values out on one of many records
	SELECT @container_type = max(isnull(wdc.container_type, ''))
	FROM dbo.WorkOrderDetailCC AS wdc
	JOIN dbo.WorkOrderDetail AS wd 
		ON wdc.workorder_id = wd.workorder_id
		AND wdc.company_id = wd.company_id
		AND wdc.profit_ctr_id = wd.profit_ctr_id
		AND wdc.sequence_id = wd.sequence_id
		AND wd.resource_type = 'D'
		AND wd.bill_rate > - 2
		AND wd.TSDF_code = @tsdf_code
	JOIN dbo.WorkOrderHeader AS wh 
		ON wd.workorder_id = wh.workorder_id
		AND wd.company_id = wh.company_id
		AND wd.profit_ctr_id = wh.profit_ctr_id
		AND wh.trip_id = @trip_id
	WHERE wdc.consolidated_container_id = @cc_id
	OPTION (OPTIMIZE FOR UNKNOWN)

	SELECT @container_size = max(isnull(wdc.container_size, ''))
	FROM WorkOrderDetailCC AS wdc
	JOIN dbo.WorkOrderDetail AS wd 
		ON wdc.workorder_id = wd.workorder_id
		AND wdc.company_id = wd.company_id
		AND wdc.profit_ctr_id = wd.profit_ctr_id
		AND wdc.sequence_id = wd.sequence_id
		AND wd.resource_type = 'D'
		AND wd.bill_rate > - 2
		AND wd.TSDF_code = @tsdf_code
	JOIN dbo.WorkOrderHeader AS wh 
		ON wd.workorder_id = wh.workorder_id
		AND wd.company_id = wh.company_id
		AND wd.profit_ctr_id = wh.profit_ctr_id
		AND wh.trip_id = @trip_id
	WHERE wdc.consolidated_container_id = @cc_id
	OPTION (OPTIMIZE FOR UNKNOWN)

	IF isnull(@debug, 0) = 1
		PRINT 'before check for an existing container'

	IF EXISTS (
			SELECT 1
			FROM dbo.Container
			WHERE company_id = @c_id
				AND profit_ctr_id = @p_id
				AND container_type = 'S'
				AND receipt_id = 0
				AND line_id = @dest_cc_id
				AND container_id = @dest_cc_id
			)
	BEGIN
		IF (isnull(@debug, 0) = 1)
		BEGIN
			SET @debug_msg = 'Manually entered stock container id: ' + isnull(convert(VARCHAR(10), @dest_cc_id), 'null')

			PRINT @debug_msg
		END

		IF isnull(@debug, 0) = 1
		BEGIN
			SET @debug_msg = 'Update Container set container_weight=' + isnull(CONVERT(VARCHAR(10), @weight), 'null') + ', description=''' + isnull(@description, 'null') + ''', staging_row=''DOCK'', container_type=''' + isnull(@container_type, '') + ''', container_size=''' + isnull(@container_size, '') + ''', trip_id=' + isnull(CONVERT(VARCHAR(10), @trip_id), 'null') + ', modified_by=''' + isnull(@user, 'null') + ''', date_modified=getdate() where company_id=' + isnull(CONVERT(VARCHAR(10), @c_id), 'null') + ' and profit_ctr_id=' + isnull(CONVERT(VARCHAR(10), @p_id), 'null') + ' and container_type=''S'' and receipt_id=0 and line_id=' + isnull(CONVERT(VARCHAR(10), @dest_cc_id), 'null') + ' and container_id=' + isnull(CONVERT(VARCHAR(10), @dest_cc_id), 'null')

			PRINT @debug_msg
		END

		UPDATE dbo.Container
		SET container_weight = @weight
			,description = @description
			,staging_row = 'DOCK'
			,manifest_container = @container_type
			,container_size = @container_size
			,trip_id = @trip_id
			,modified_by = @user
			,date_modified = getdate()
		WHERE company_id = @c_id
			AND profit_ctr_id = @p_id
			AND container_type = 'S'
			AND receipt_id = 0
			AND line_id = @dest_cc_id
			AND container_id = @dest_cc_id

		IF @@ERROR <> 0
		BEGIN
			CLOSE c_loop_cc

			DEALLOCATE c_loop_cc

			SET @err_msg = 'ERROR: Unable to update Stock record in Container table'

			GOTO ON_ERROR
		END

		UPDATE dbo.ContainerDestination
		SET treatment_id = @p_treatment_id
			,modified_by = @user
			,date_modified = getdate()
			,consolidation_group_uid = CASE 
				WHEN @consolidation_group_flag = 'T'
					AND @update_consolidation_group = 'T'
					THEN @consolidation_group_uid
				ELSE consolidation_group_uid
				END
			,air_permit_status_uid = CASE 
				WHEN @air_permit_flag = 'T'
					AND @update_air_permit_status = 'T'
					THEN @air_permit_status_uid
				ELSE air_permit_status_uid
				END
		WHERE company_id = @c_id
			AND profit_ctr_id = @p_id
			AND container_type = 'S'
			AND receipt_id = 0
			AND line_id = @dest_cc_id
			AND container_id = @dest_cc_id

		IF @@ERROR <> 0
		BEGIN
			CLOSE c_loop_cc

			DEALLOCATE c_loop_cc

			SET @err_msg = 'ERROR: Unable to update Stock record in ContainerDestination table'

			GOTO ON_ERROR
		END
	END
	ELSE
	BEGIN
		IF isnull(@debug, 0) = 1
			PRINT 'no existing container'

		IF isnull(@dest_cc_id, 0) < 1
		BEGIN
			IF (isnull(@debug, 0) = 1)
			BEGIN
				SET @debug_msg = 'Automatically generated stock container id: ' + isnull(convert(VARCHAR(10), @seq_dest_cc_id), 'null')

				PRINT @debug_msg
			END

			SET @dest_cc_id = @seq_dest_cc_id
			-- increment next stock container number
			SET @seq_dest_cc_id = @seq_dest_cc_id + 1

			IF isnull(@debug, 0) = 1
			BEGIN
				SET @debug_msg = 'update WorkOrderDetailCC set destination_container_id=' + convert(VARCHAR(10), @dest_cc_id) + ' where company_id=' + convert(VARCHAR(10), @trip_company_id) + ' and profit_ctr_id=' + convert(VARCHAR(10), @trip_profit_ctr_id) + ' and consolidated_container_id=' + convert(VARCHAR(10), @cc_id) + ' and workorder_id in (select workorder_id from WorkOrderHeader where trip_id = ' + CONVERT(VARCHAR(10), @trip_id) + ')'

				PRINT @debug_msg
			END

			UPDATE dbo.WorkOrderDetailCC
			SET destination_container_id = @dest_cc_id
			WHERE company_id = @trip_company_id
				AND profit_ctr_id = @trip_profit_ctr_id
				AND consolidated_container_id = @cc_id
				--TODO: can this be an EXSISTS?
				AND workorder_id IN (
					SELECT workorder_id
					FROM dbo.WorkOrderHeader
					WHERE trip_id = @trip_id
					)

			IF @@ERROR <> 0
			BEGIN
				CLOSE c_loop_cc

				DEALLOCATE c_loop_cc

				SET @err_msg = 'ERROR: Unable to update destination_container_id in WorkOrderDetailCC table'

				GOTO ON_ERROR
			END
		END

		IF isnull(@debug, 0) = 1
		BEGIN
			SET @debug_msg = 'Insert Stock Container record, weight=' + CONVERT(VARCHAR(10), @weight)

			PRINT @debug_msg
		END

		INSERT dbo.Container (
			company_id
			,profit_ctr_id
			,container_type
			,receipt_id
			,line_id
			,container_id
			,STATUS
			,price_id
			,field_sequence_ID
			,staging_row
			,manifest_container
			,container_size
			,container_weight
			,amount_solids
			,description
			,date_added
			,date_modified
			,created_by
			,modified_by
			,trip_id
			)
		VALUES (
			@c_id
			,@p_id
			,'S'
			,0
			,@dest_cc_id
			,@dest_cc_id
			,'N'
			,0
			,''
			,'DOCK'
			,@container_type
			,@container_size
			,@weight
			,''
			,@description
			,GETDATE()
			,GETDATE()
			,@user
			,@user
			,@trip_id
			)

		IF @@ERROR <> 0
		BEGIN
			CLOSE c_loop_cc

			DEALLOCATE c_loop_cc

			SET @err_msg = 'ERROR: Unable to insert Stock record into Container table'

			GOTO ON_ERROR
		END

		IF isnull(@debug, 0) = 1
			PRINT 'Insert Stock ContainerDestination record'

		INSERT dbo.ContainerDestination (
			company_id
			,profit_ctr_id
			,container_type
			,receipt_id
			,line_id
			,container_id
			,sequence_id
			,container_percent
			,treatment_id
			,location_type
			,waste_flag
			,const_flag
			,STATUS
			,date_added
			,date_modified
			,created_by
			,modified_by
			,modified_from
			,base_sequence_id
			,consolidation_group_uid
			,air_permit_status_uid
			)
		VALUES (
			@c_id
			,@p_id
			,'S'
			,0
			,@dest_cc_id
			,@dest_cc_id
			,1
			,100
			,@p_treatment_id
			,'U'
			,'F'
			,'F'
			,'N'
			,GETDATE()
			,GETDATE()
			,@user
			,@user
			,'TC'
			,1
			,CASE 
				WHEN @consolidation_group_flag = 'T'
					AND @update_consolidation_group = 'T'
					THEN @consolidation_group_uid
				ELSE NULL
				END
			,CASE 
				WHEN @air_permit_flag = 'T'
					AND @update_air_permit_status = 'T'
					THEN @air_permit_status_uid
				ELSE NULL
				END
			)

		IF @@ERROR <> 0
		BEGIN
			CLOSE c_loop_cc

			DEALLOCATE c_loop_cc

			SET @err_msg = 'ERROR: Unable to insert Stock record into ContainerDestination table'

			GOTO ON_ERROR
		END
	END

	-- loop through all receipt lines linked to the CC ID
	-- JCG EQAI-47065  Tax Codes not assigned to containers on trip completion/consolidation to stock containers
	DECLARE c_loop_receipt CURSOR FAST_FORWARD
	FOR
	SELECT DISTINCT bll.company_id
		,bll.profit_ctr_id
		,bll.receipt_id
		,r.line_id
		,isnull(r.bulk_flag, 'F')
		,isnull(r.container_count, 1)
		,r.treatment_id
		,r.line_weight
		,isnull(wdc.percentage, 0)
		,left(ltrim(rtrim(p.approval_desc)), 30)
		,r.manifest_container_code
		,r.bill_unit_code
		,p.profile_id
	FROM dbo.WorkorderHeader AS wh
	JOIN dbo.WorkOrderDetail AS wd 
		ON wh.workorder_id = wd.workorder_id
		AND wh.company_id = wd.company_id
		AND wh.profit_ctr_id = wd.profit_ctr_id
		AND wd.resource_type = 'D'
		AND wd.bill_rate > - 2
		AND wd.tsdf_code = @tsdf_code
	JOIN dbo.WorkOrderDetailCC AS wdc 
		ON wd.workorder_id = wdc.workorder_id
		AND wd.company_id = wdc.company_id
		AND wd.profit_ctr_id = wdc.profit_ctr_id
		AND wd.sequence_id = wdc.sequence_id
		AND wdc.consolidated_container_id = @cc_id
	JOIN dbo.BillingLinkLookup AS bll 
		ON wh.workorder_id = bll.source_id
		AND wh.company_id = bll.source_company_id
		AND wh.profit_ctr_id = bll.source_profit_ctr_id
		AND bll.source_type = 'W'
		AND bll.trans_source = 'I'
	JOIN dbo.Receipt AS r --WITH (INDEX (Receipt_cui)) --TODO: Can it be updated to a JOIN HINT or be removed with updated indexing?
		ON bll.company_id = r.company_id
		AND bll.profit_ctr_id = r.profit_ctr_id
		AND bll.receipt_id = r.receipt_id
		AND r.line_id > 0
		AND wd.manifest = r.manifest
		AND wd.manifest_line = r.manifest_line
	JOIN dbo.[Profile] AS p 
		ON r.profile_id = p.profile_id
	WHERE wh.trip_id = @trip_id
		AND isnull(wh.trip_stop_rate_flag, '') <> 'T'
	
	UNION
	
	SELECT DISTINCT r.company_id
		,r.profit_ctr_id
		,r.receipt_id
		,r.line_id
		,isnull(r.bulk_flag, 'F')
		,isnull(r.container_count, 1)
		,r.treatment_id
		,r.line_weight
		,isnull(wdc.percentage, 0)
		,left(ltrim(rtrim(p.approval_desc)), 30)
		,r.manifest_container_code
		,r.bill_unit_code
		,p.profile_id
	FROM dbo.WorkorderHeader AS wh
	JOIN dbo.WorkOrderDetail AS wd 
		ON wh.workorder_id = wd.workorder_id
		AND wh.company_id = wd.company_id
		AND wh.profit_ctr_id = wd.profit_ctr_id
		AND wd.resource_type = 'D'
		AND wd.bill_rate > - 2
		AND wd.tsdf_code = @tsdf_code
	JOIN dbo.WorkOrderDetailCC AS wdc 
		ON wd.workorder_id = wdc.workorder_id
		AND wd.company_id = wdc.company_id
		AND wd.profit_ctr_id = wdc.profit_ctr_id
		AND wd.sequence_id = wdc.sequence_id
		AND wdc.consolidated_container_id = @cc_id
	JOIN dbo.ReceiptHeader AS rh 
		ON wh.trip_id = rh.trip_id
		AND wh.trip_sequence_id = rh.trip_sequence_id
		AND EXISTS (
			SELECT 1
			FROM dbo.Receipt AS r
			WHERE r.company_id = rh.company_id
				AND r.profit_ctr_id = rh.profit_ctr_id
				AND r.receipt_id = rh.receipt_id
				AND r.receipt_status <> 'V'
			)
	JOIN dbo.Receipt AS r 
		ON rh.company_id = r.company_id
		AND rh.profit_ctr_id = r.profit_ctr_id
		AND rh.receipt_id = r.receipt_id
		AND r.line_id > 0
		AND wd.manifest = r.manifest
		AND wd.manifest_line = r.manifest_line
	JOIN dbo.[Profile] AS p 
		ON r.profile_id = p.profile_id
	WHERE wh.trip_id = @trip_id
		AND isnull(wh.trip_stop_rate_flag, '') = 'T'
	OPTION (OPTIMIZE FOR UNKNOWN)

	OPEN c_loop_receipt

	FETCH c_loop_receipt
	INTO @c_id
		,@p_id
		,@receipt_id
		,@line_id
		,@bulk_flag
		,@receipt_container_count
		,@treatment_id
		,@line_weight
		,@cc_percentage
		,@description
		,@container_code
		,@bill_unit_code
		,@profile_id

	--TODO: 81% performance hit here
	WHILE @@FETCH_STATUS = 0
	BEGIN
		SELECT @consolidation_group_uid = pqa.consolidation_group_uid
			,@air_permit_status_uid = pqa.air_permit_status_uid
		FROM dbo.ProfileQuoteApproval AS pqa
		WHERE pqa.company_id = @c_id
			AND pqa.profit_ctr_id = @p_id
			AND pqa.profile_id = @profile_id

		-- Consolidate receipt into stock container
		IF @bulk_flag = 'T'
			SET @staging_row = 'BULK'
		ELSE
			SET @staging_row = 'DOCK'

		SET @tracking_num = 'DL-' + right('0' + convert(VARCHAR(2), @c_id), 2) + right('0' + convert(VARCHAR(2), @p_id), 2) + '-' + right('00000' + convert(VARCHAR(10), @dest_cc_id), 6)
		SET @container_id = 0
		SET @summed_weight = 0

		IF @receipt_container_count > 1
			SET @fract_weight = ROUND(@line_weight / @receipt_container_count, 2, 1)
		ELSE
			SET @fract_weight = ROUND(@line_weight, 2)

		WHILE @container_id < @receipt_container_count
		BEGIN
			SET @container_id = @container_id + 1

			IF @container_id = @receipt_container_count
				SET @fract_weight = @line_weight - @summed_weight
			SET @summed_weight = @summed_weight + @fract_weight

			IF NOT EXISTS (
					SELECT 1
					FROM dbo.Container AS c
					WHERE c.company_id = @c_id
						AND c.profit_ctr_id = @p_id
						AND c.container_type = 'R'
						AND c.receipt_id = @receipt_id
						AND c.line_id = @line_id
						AND c.container_id = @container_id
					)
			BEGIN
				IF isnull(@debug, 0) = 1
				BEGIN
					SET @debug_msg = 'Insert Receipt Container: ' + CONVERT(VARCHAR(2), @c_id) + '-' + CONVERT(VARCHAR(2), @p_id) + '-' + CONVERT(VARCHAR(10), @receipt_id) + '-' + CONVERT(VARCHAR(10), @line_id) + ', container_id=' + CONVERT(VARCHAR(10), @container_id)

					PRINT @debug_msg
				END

				INSERT dbo.Container (
					company_id
					,profit_ctr_id
					,container_type
					,receipt_id
					,line_id
					,container_id
					,STATUS
					,price_id
					,staging_row
					,manifest_container
					,container_size
					,container_weight
					,description
					,date_added
					,date_modified
					,created_by
					,modified_by
					,trip_id
					)
				VALUES (
					@c_id
					,@p_id
					,'R'
					,@receipt_id
					,@line_id
					,@container_id
					,'C'
					,1
					,@staging_row
					,@container_code
					,@bill_unit_code
					,@fract_weight
					,@description
					,GETDATE()
					,GETDATE()
					,@user
					,@user
					,@trip_id
					)

				IF @@ERROR <> 0
				BEGIN
					CLOSE c_loop_receipt

					DEALLOCATE c_loop_receipt

					CLOSE c_loop_cc

					DEALLOCATE c_loop_cc

					SET @err_msg = 'ERROR: Unable to insert Receipt record into Container table'

					GOTO ON_ERROR
				END
			END

			SELECT @sequence_id = isnull(max(sequence_id) + 1, 1)
			FROM dbo.ContainerDestination(NOLOCK)
			WHERE company_id = @c_id
				AND profit_ctr_id = @p_id
				AND container_type = 'R'
				AND receipt_id = @receipt_id
				AND line_id = @line_id
				AND container_id = @container_id

			IF isnull(@debug, 0) = 1
				PRINT 'Insert Receipt ContainerDestination record'

			-- JCG 12/14/17 Zach's change to add tax_code_uid to Consolidation. 
			--  EQAI-47065  Tax Codes not assigned to containers on trip completion/consolidation to stock containers
			SELECT @tax_code_uid = dbo.fn_get_product_tax_code(@c_id, @p_id, @receipt_id, @line_id)

			INSERT dbo.ContainerDestination (
				company_id
				,profit_ctr_id
				,container_type
				,receipt_id
				,line_id
				,container_id
				,sequence_id
				,container_percent
				,treatment_id
				,location_type
				,disposal_date
				,base_tracking_num
				,base_container_id
				,waste_flag
				,const_flag
				,STATUS
				,date_added
				,date_modified
				,created_by
				,modified_by
				,modified_from
				,base_sequence_id
				,tax_code_uid
				,consolidation_group_uid
				,air_permit_status_uid
				)
			VALUES (
				@c_id
				,@p_id
				,'R'
				,@receipt_id
				,@line_id
				,@container_id
				,@sequence_id
				,@cc_percentage
				,@treatment_id
				,'C'
				,convert(DATETIME, convert(VARCHAR(10), getdate(), 101))
				,@tracking_num
				,@dest_cc_id
				,'F'
				,'F'
				,'C'
				,GETDATE()
				,GETDATE()
				,@user
				,@user
				,'TC'
				,1
				,@tax_code_uid
				,CASE 
					WHEN @consolidation_group_flag = 'T'
						AND @update_consolidation_group = 'T'
						THEN @consolidation_group_uid
					ELSE NULL
					END
				,CASE 
					WHEN @air_permit_flag = 'T'
						AND @update_air_permit_status = 'T'
						THEN @air_permit_status_uid
					ELSE NULL
					END
				)

			IF @@ERROR <> 0
			BEGIN
				CLOSE c_loop_receipt

				DEALLOCATE c_loop_receipt

				CLOSE c_loop_cc

				DEALLOCATE c_loop_cc

				SET @err_msg = 'ERROR: Unable to insert Receipt record into ContainerDestination table'

				GOTO ON_ERROR
			END

			INSERT dbo.ContainerWasteCode (
				company_id
				,profit_ctr_id
				,container_type
				,receipt_id
				,line_id
				,container_id
				,sequence_id
				,waste_code
				,date_added
				,created_by
				,source_receipt_id
				,source_line_id
				,source_container_id
				,source_sequence_id
				,waste_code_uid
				)
			SELECT rwc.company_id
				,rwc.profit_ctr_id
				,'S'
				,0
				,@dest_cc_id
				,@dest_cc_id
				,1
				,rwc.waste_code
				,getdate()
				,@user
				,@receipt_id
				,@line_id
				,@container_id
				,1
				,rwc.waste_code_uid
			FROM dbo.ReceiptWasteCode AS rwc(NOLOCK)
			WHERE rwc.company_id = @c_id
				AND rwc.profit_ctr_id = @p_id
				AND rwc.receipt_id = @receipt_id
				AND rwc.line_id = @line_id
				AND NOT EXISTS (
					SELECT 1
					FROM dbo.ContainerWasteCode AS cwc
					WHERE cwc.company_id = @c_id
						AND cwc.profit_ctr_id = @p_id
						AND cwc.container_type = 'S'
						AND cwc.receipt_id = 0
						AND cwc.line_id = @dest_cc_id
						AND cwc.container_id = @dest_cc_id
						AND cwc.sequence_id = 1
						AND cwc.waste_code_uid = rwc.waste_code_uid
					)

			IF @@ERROR <> 0
			BEGIN
				CLOSE c_loop_receipt

				DEALLOCATE c_loop_receipt

				CLOSE c_loop_cc

				DEALLOCATE c_loop_cc

				SET @err_msg = 'ERROR: Unable to insert into ContainerWasteCode table'

				GOTO ON_ERROR
			END

			INSERT dbo.ContainerConstituent (
				company_id
				,profit_ctr_id
				,container_type
				,receipt_id
				,line_id
				,container_id
				,sequence_id
				,const_id
				,UHC
				,date_added
				,created_by
				,source_receipt_id
				,source_line_id
				,source_container_id
				,source_sequence_id
				)
			SELECT DISTINCT company_id
				,profit_ctr_id
				,'S'
				,0
				,@dest_cc_id
				,@dest_cc_id
				,1
				,const_id
				,UHC
				,getdate()
				,@user
				,@receipt_id
				,@line_id
				,@container_id
				,1
			FROM dbo.ReceiptConstituent AS rc(NOLOCK)
			WHERE rc.company_id = @c_id
				AND rc.profit_ctr_id = @p_id
				AND rc.receipt_id = @receipt_id
				AND rc.line_id = @line_id
				AND NOT EXISTS (
					SELECT 1
					FROM dbo.ContainerConstituent AS cc
					WHERE cc.company_id = @c_id
						AND cc.profit_ctr_id = @p_id
						AND cc.container_type = 'S'
						AND cc.receipt_id = 0
						AND cc.line_id = @dest_cc_id
						AND cc.container_id = @dest_cc_id
						AND cc.sequence_id = 1
						AND cc.const_id = rc.const_id
					)

			IF @@ERROR <> 0
			BEGIN
				CLOSE c_loop_receipt

				DEALLOCATE c_loop_receipt

				CLOSE c_loop_cc

				DEALLOCATE c_loop_cc

				SET @err_msg = 'ERROR: Unable to insert into ContainerConstituent table'

				GOTO ON_ERROR
			END
		END

		-- 07/21/2015 Collect records to query outbound info after main loop
		INSERT #outbound (
			company_id
			,profit_ctr_id
			,container_id
			,sequence_id
			,receipt_id
			,line_id
			)
		VALUES (
			@c_id
			,@p_id
			,@dest_cc_id
			,@sequence_id
			,@receipt_id
			,@line_id
			)

		IF @@ERROR <> 0
		BEGIN
			CLOSE c_loop_receipt

			DEALLOCATE c_loop_receipt

			CLOSE c_loop_cc

			DEALLOCATE c_loop_cc

			SET @err_msg = 'ERROR: Unable to insert into #outbound table'

			GOTO ON_ERROR
		END

		FETCH c_loop_receipt
		INTO @c_id
			,@p_id
			,@receipt_id
			,@line_id
			,@bulk_flag
			,@receipt_container_count
			,@treatment_id
			,@line_weight
			,@cc_percentage
			,@description
			,@container_code
			,@bill_unit_code
			,@profile_id
	END

	CLOSE c_loop_receipt

	DEALLOCATE c_loop_receipt

	FETCH c_loop_cc
	INTO @cc_id
		,@dest_cc_id
		,@p_treatment_id --, @consolidation_group_uid, @air_permit_status_uid
END

CLOSE c_loop_cc

DEALLOCATE c_loop_cc

-- 07/21/2015 Collect outbound info for any qualifying container destination sequences (only applies to EQ Profiles)
IF (
		SELECT ISNULL(eq_flag, 'F')
		FROM dbo.TSDF
		WHERE TSDF_code = @tsdf_code
		) = 'T'
BEGIN
	DECLARE c_loop_outbound CURSOR FAST_FORWARD
	FOR
	SELECT DISTINCT company_id
		,profit_ctr_id
		,container_id
		,sequence_id
	FROM #outbound

	OPEN c_loop_outbound

	FETCH c_loop_outbound
	INTO @c_id
		,@p_id
		,@container_id
		,@sequence_id

	WHILE @@FETCH_STATUS = 0
	BEGIN
		SET @profile_id = NULL
		SET @tsdf_approval_id = NULL
		SET @location_type = NULL
		SET @location = NULL
		SET @approval_code = NULL
		SET @ob_profile_id = NULL
		SET @ob_company_id = NULL
		SET @ob_profit_ctr_id = NULL
		SET @waste_stream = NULL

		-- if all receipt lines in the container contain the same profile
		-- MPM - 8/30/2021 - DevOps 27596 - Modified to handle the case in which values are not getting set on the resultant stock container 
		-- when there is more than 1 profile being consolidated into the same container.  In that case, we need to set only location_type = 'U' in 
		-- the ContainerDestination table, and not set other column values in ContainerDestination.
		SELECT @stock_container_approval_count = count(*)
		FROM (
			SELECT DISTINCT pqa.location_type
				,pqa.location
				,pqa.OB_EQ_profile_id
				,pqa.OB_EQ_company_id
				,pqa.OB_EQ_profit_ctr_id
				,pqa.OB_TSDF_approval_id
			FROM dbo.ContainerDestination AS cd
			JOIN dbo.receipt AS r 
				ON cd.company_id = r.company_id
				AND cd.profit_ctr_id = r.profit_ctr_id
				AND cd.receipt_id = r.receipt_id
				AND cd.line_id = r.line_id
				AND r.receipt_status <> 'V'
			JOIN dbo.ProfileQuoteApproval AS pqa 
				ON pqa.company_id = r.company_id
				AND pqa.profit_ctr_id = r.profit_ctr_id
				AND pqa.profile_id = r.profile_id
				AND pqa.approval_code = r.approval_code
			WHERE cd.company_id = @c_id
				AND cd.profit_ctr_id = @p_id
				AND cd.base_tracking_num = 'DL-' + RIGHT('0' + convert(VARCHAR(2), @c_id), 2) + RIGHT('0' + convert(VARCHAR(2), @p_id), 2) + '-' + RIGHT('00000' + convert(VARCHAR(6), @container_id), 6)
				AND cd.sequence_id = @sequence_id
			) t

		IF @stock_container_approval_count = 1
		BEGIN
			SELECT @profile_id = MIN(r.profile_id)
			FROM dbo.ContainerDestination AS cd
			JOIN dbo.receipt AS r 
				ON cd.company_id = r.company_id
				AND cd.profit_ctr_id = r.profit_ctr_id
				AND cd.receipt_id = r.receipt_id
				AND cd.line_id = r.line_id
				AND r.receipt_status <> 'V'
			WHERE cd.company_id = @c_id
				AND cd.profit_ctr_id = @p_id
				AND cd.base_tracking_num = 'DL-' + RIGHT('0' + convert(VARCHAR(2), @c_id), 2) + RIGHT('0' + convert(VARCHAR(2), @p_id), 2) + '-' + RIGHT('00000' + convert(VARCHAR(6), @container_id), 6)
				AND cd.sequence_id = @sequence_id

			SELECT @location_type = location_type
				,@location = location
				,@ob_profile_id = OB_EQ_profile_id
				,@ob_company_id = OB_EQ_company_id
				,@ob_profit_ctr_id = OB_EQ_profit_ctr_id
				,@ob_tsdf_approval_id = OB_TSDF_approval_id
			FROM dbo.ProfileQuoteApproval
			WHERE profile_id = @profile_id
				AND company_id = @c_id
				AND profit_ctr_id = @p_id

			IF ISNULL(@ob_profile_id, 0) > 0
				SELECT @approval_code = approval_code
				FROM dbo.ProfileQuoteApproval
				WHERE profile_id = @ob_profile_id
					AND company_id = @ob_company_id
					AND profit_ctr_id = @ob_profit_ctr_id
			ELSE IF ISNULL(@ob_tsdf_approval_id, 0) > 0
				SELECT @approval_code = TSDF_approval_code
					,@waste_stream = waste_stream
				FROM dbo.TSDFApproval
				WHERE TSDF_approval_id = @ob_tsdf_approval_id
		END

		IF (
				@location_type IS NOT NULL
				OR ISNULL(@ob_profile_id, 0) > 0
				OR ISNULL(@ob_tsdf_approval_id, 0) > 0
				)
			AND @stock_container_approval_count = 1
		BEGIN
			UPDATE dbo.ContainerDestination
			SET location_type = @location_type
				,location = @location
				,waste_stream = @waste_stream
				,OB_profile_id = @ob_profile_id
				,OB_profile_company_ID = @ob_company_id
				,OB_profile_profit_ctr_id = @ob_profit_ctr_id
				,tsdf_approval_id = @ob_tsdf_approval_id
				,tsdf_approval_code = @approval_code
			WHERE company_id = @c_id
				AND profit_ctr_id = @p_id
				AND receipt_id = 0
				AND line_id = @container_id
				AND container_id = @container_id
				AND sequence_id = 1
				AND container_type = 'S'

			IF @@ERROR <> 0
			BEGIN
				CLOSE c_loop_outbound

				DEALLOCATE c_loop_outbound

				SET @err_msg = 'ERROR: Unable to update ContainerDestination with outbound info'

				GOTO ON_ERROR
			END
		END

		IF @stock_container_approval_count > 1
		BEGIN
			UPDATE dbo.ContainerDestination
			SET location_type = 'U'
			WHERE company_id = @c_id
				AND profit_ctr_id = @p_id
				AND receipt_id = 0
				AND line_id = @container_id
				AND container_id = @container_id
				AND sequence_id = 1
				AND container_type = 'S'

			IF @@ERROR <> 0
			BEGIN
				CLOSE c_loop_outbound

				DEALLOCATE c_loop_outbound

				SET @err_msg = 'ERROR: Unable to update ContainerDestination with outbound info'

				GOTO ON_ERROR
			END
		END

		FETCH c_loop_outbound
		INTO @c_id
			,@p_id
			,@container_id
			,@sequence_id
	END

	CLOSE c_loop_outbound

	DEALLOCATE c_loop_outbound
END

-- SUCCESS
ON_SUCCESS:

IF @@TRANCOUNT > @initial_tran_count
BEGIN
	IF isnull(@debug, 0) = 1
		PRINT 'commit transaction'

	COMMIT TRANSACTION
END

RETURN 0

-- ERROR
ON_ERROR:

IF @@TRANCOUNT > @initial_tran_count
BEGIN
	IF isnull(@debug, 0) = 1
		PRINT 'rollback transaction'

	ROLLBACK TRANSACTION
END

RAISERROR (
		@err_msg
		,16
		,1
		)

RETURN - 1

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_trip_complete_generate_stock_containers] TO [EQAI]
    AS [dbo];

