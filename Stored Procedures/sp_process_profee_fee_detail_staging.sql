USE PLT_AI
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

SET NOCOUNT ON
GO

IF OBJECT_ID ('dbo.sp_process_profile_fee_detail_staging', 'P') IS NOT NULL
	DROP PROCEDURE dbo.sp_process_profile_fee_detail_staging;
GO

CREATE OR ALTER PROCEDURE [dbo].[sp_process_profile_fee_detail_staging] (@debug INT = 0)
AS
/***************************************************************
Loads to:	Plt_AI	
This procedure creates/ updates ProfileFeeDetail records for Profiles. It is called from a nightly process and looks for 
ProfileFeeDetailStaging records which are becoming Current Effective today. ProfileFeeDetailStaging records are populated 
for future effective-dated CustomerBillingProfileFee records.

-------------------------- History -----------------------------
06/26/2024 - Dipankar - DevOps: 90039 - Initial Version

EXEC dbo.sp_process_profile_fee_detail_staging 0
****************************************************************/	
BEGIN
	DECLARE 
		@current_date DATE = CAST(GETDATE() AS DATE),
		@current_datetime DATETIME = GETDATE(),
		@count INT = 0,
		@job_name VARCHAR(30) = 'Profile Fee Nightly Job'

	BEGIN TRANSACTION	
	BEGIN TRY		
		PRINT 'Profile fee staging records processing started at ' + CAST(GETDATE() AS VARCHAR(20));

		SELECT @count = COUNT(1) 
		FROM dbo.ProfileFeeDetailStaging
		JOIN dbo.CustomerBillingProfileFee 
			ON CustomerBillingProfileFee.customer_billing_profile_fee_uid = ProfileFeeDetailStaging.customer_billing_profile_fee_uid
		WHERE CustomerBillingProfileFee.date_effective = @current_date
		AND ProfileFeeDetailStaging.process_flag = 'F'
			   
		IF @debug = 1		
			PRINT CAST(@count AS VARCHAR) + ' profile fee staging records are available for processing.'
		
	    -- Fetch ProfileFeeDetailStaging records to be processed today into a Temp Staging Table
		SELECT  Profile.profile_id,
				CustomerBillingProfileFee.customer_id,
				CustomerBillingProfileFee.customer_billing_profile_fee_uid,				
				CustomerBillingProfileFee.apply_flag AS apply_flag_after,
				CustomerBillingProfileFee.exemption_reason_uid AS exemption_reason_uid_after,
				CustomerBillingProfileFee.exemption_approved_by AS exemption_approved_by_after,
				CustomerBillingProfileFee.date_exempted AS date_exempted_after,
				CustomerBillingProfileFee.added_by AS added_by_after,
				CustomerBillingProfileFee.modified_by AS modified_by_after,
				ProfileFeeDetail.profile_fee_detail_uid, 	-- WHEN profile_fee_detail_uid is NULL Then Insert Else Update
				ProfileFeeDetail.apply_flag AS apply_flag_before,
				ProfileFeeDetail.exemption_reason_uid AS exemption_reason_uid_before,
				ProfileFeeDetail.exemption_approved_by AS exemption_approved_by_before,
			    ProfileFeeDetail.date_exempted AS date_exempted_before,
				ProfileFeeDetail.modified_by AS modified_by_before
		INTO #tmp_staging 
		FROM dbo.ProfileFeeDetailStaging
		JOIN dbo.CustomerBillingProfileFee 
			ON CustomerBillingProfileFee.customer_billing_profile_fee_uid = ProfileFeeDetailStaging.customer_billing_profile_fee_uid
		JOIN dbo.Profile 
			ON Profile.customer_id = CustomerBillingProfileFee.customer_id
		LEFT JOIN ProfileFeeDetail 
			ON Profile.profile_id = ProfileFeeDetail.profile_id 
		WHERE CustomerBillingProfileFee.date_effective = @current_date
		AND ProfileFeeDetailStaging.process_flag = 'F'

		SET @count = @@ROWCOUNT
		IF @debug = 1			
			PRINT CAST(@count AS VARCHAR) + ' profile records would be updated.'
						 
		-- Update records on ProfileFeeDetail Table
		UPDATE pfd 
		SET apply_flag = #tmp_staging.apply_flag_after, 
			exemption_reason_uid = #tmp_staging.exemption_reason_uid_after, 
			exemption_approved_by = #tmp_staging.exemption_approved_by_after, 
			date_exempted = #tmp_staging.date_exempted_after,
			modified_by = #tmp_staging.modified_by_after,
			date_modified = @current_datetime			
		FROM dbo.ProfileFeeDetail pfd
		JOIN #tmp_staging 
			ON #tmp_staging.profile_fee_detail_uid = pfd.profile_fee_detail_uid
		WHERE #tmp_staging.profile_fee_detail_uid IS NOT NULL

		SET @count = @@ROWCOUNT
		IF @debug = 1
			PRINT CAST(@count AS VARCHAR) + ' profile fee record were updated.'			
		
		-- Insert records into ProfileFeeDetail Table
		INSERT INTO dbo.ProfileFeeDetail (profile_id, apply_flag, exemption_reason_uid, exemption_approved_by, date_exempted, added_by, date_added, modified_by, date_modified) 
		SELECT profile_id, apply_flag_after, exemption_reason_uid_after, exemption_approved_by_after, date_exempted_after, added_by_after, @current_datetime, modified_by_after, @current_datetime
		FROM #tmp_staging
		WHERE profile_fee_detail_uid IS NULL

		SET @count = @@ROWCOUNT
		IF @debug = 1
			PRINT CAST(@@ROWCOUNT AS VARCHAR) + ' profile fee records were created.';

		WITH AuditColumns AS (SELECT name FROM SYSCOLUMNS 
							  WHERE OBJECT_NAME(id) = 'ProfileFeeDetail' 
							  AND name in ('apply_flag', 'profile_id'))
		INSERT INTO dbo.ProfileAudit (profile_id, table_name, column_name, before_value, after_value, audit_reference, modified_by, date_modified) -- modified_by to be added
		SELECT   profile_id,
				'ProfileFeeDetail',
				AuditColumns.name,
				'(inserted)',
				CASE AuditColumns.name  WHEN 'apply_flag' THEN apply_flag_after
										WHEN 'profile_id' THEN CONVERT(VARCHAR, profile_id) 
										ELSE NULL END,
				'Updated by ' + @job_name,
				modified_by_after,
				@current_datetime
		FROM #tmp_staging, AuditColumns
		WHERE apply_flag_after = 'T' 
		AND profile_fee_detail_uid IS NULL

		SET @count = @@ROWCOUNT
		IF @debug = 1
			PRINT CAST(@count AS VARCHAR) + ' profile fee audit records were created (New - Apply).';

		WITH AuditColumns AS (SELECT name FROM SYSCOLUMNS 
							WHERE OBJECT_NAME(id) = 'ProfileFeeDetail' 
							AND name in ('apply_flag', 'profile_id', 'date_exempted', 'exemption_approved_by', 'exemption_reason_uid'))
		INSERT INTO dbo.ProfileAudit (profile_id, table_name, column_name, before_value, after_value, audit_reference, modified_by, date_modified) -- modified_by to be added
		SELECT profile_id,
			'ProfileFeeDetail',
			AuditColumns.name,
			CASE profile_fee_detail_uid WHEN NULL THEN '(inserted)' ELSE (
			CASE AuditColumns.name  WHEN 'apply_flag' THEN apply_flag_before
									WHEN 'profile_id' THEN CONVERT(VARCHAR, profile_id) 
									WHEN 'date_exempted' THEN CONVERT(VARCHAR(10), date_exempted_before, 101)
									WHEN 'exemption_approved_by' THEN exemption_approved_by_before
									WHEN 'exemption_reason_uid' THEN CONVERT(VARCHAR, exemption_reason_uid_before) ELSE NULL END) END,
			CASE AuditColumns.name  WHEN 'apply_flag' THEN apply_flag_after
									WHEN 'profile_id' THEN CONVERT(VARCHAR, profile_id) 
									WHEN 'date_exempted' THEN CONVERT(VARCHAR(10), date_exempted_after, 101)
									WHEN 'exemption_approved_by' THEN exemption_approved_by_after
									WHEN 'exemption_reason_uid' THEN CONVERT(VARCHAR, exemption_reason_uid_after) ELSE NULL END,
			'Updated by ' + @job_name,
			modified_by_after,
			@current_datetime
		FROM #tmp_staging, AuditColumns
		WHERE apply_flag_after = 'F' 
		OR profile_fee_detail_uid IS NOT NULL;

		SET @count = @@ROWCOUNT
		IF @debug = 1
			PRINT CAST(@count AS VARCHAR) + ' profile fee audit records were created (New - Exempt Or Update - Apply/ Exempt).';
		
		-- Update Process Flag & Processed Date on ProfileFeeDetailStaging Table
		UPDATE pfds
		SET process_flag = 'T',
			date_processed = GETDATE()
		FROM ProfileFeeDetailStaging pfds
		JOIN #tmp_staging ON #tmp_staging.customer_billing_profile_fee_uid = pfds.customer_billing_profile_fee_uid

		SET @count = @@ROWCOUNT
		IF @debug = 1
			PRINT CAST(@count AS VARCHAR) + ' profile fee staging records were processed.';
		
		PRINT 'Profile fee staging records processing finished at ' + CAST(GETDATE() AS VARCHAR(20));
	END TRY

	BEGIN CATCH
	  DECLARE @ErrorMessage NVARCHAR(4000), 
			  @ErrorSeverity INT,
			  @ErrorState INT

	  -- Determine if an error occurred
	  IF @@TRANCOUNT > 0
		  ROLLBACK TRANSACTION

	  -- Return the error information
	  SELECT @ErrorMessage = ERROR_MESSAGE(),
			 @ErrorSeverity = ERROR_SEVERITY(),
			 @ErrorState = ERROR_STATE()
	  
	  RAISERROR(@ErrorMessage, @ErrorSeverity, @ErrorState)
	END CATCH

	IF @@TRANCOUNT > 0 
		COMMIT TRANSACTION
END
GO

GRANT EXECUTE ON [dbo].[sp_process_profile_fee_detail_staging] TO EQAI
GO

-- EXEC dbo.sp_process_profee_fee_detail_staging 0