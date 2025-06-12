USE PLT_AI
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

SET NOCOUNT ON
GO

CREATE OR ALTER PROCEDURE [dbo].[sp_process_profile_queue_cleanup] (@debug INT = 0)
AS
/***************************************************************
Loads to:	PLT_AI	
This procedure automated cleanup of profile queues based on current status, tracking status 
& last modified date.

-------------------------- History -----------------------------
09/12/2024 - Dipankar - US120785 - Initial Version

EXEC dbo.sp_process_profile_queue_cleanup 0
****************************************************************/	

BEGIN
	DECLARE @audit_reference VARCHAR(50) = 'Profile Queue Clean-Up',
			@modified_by VARCHAR(10) = 'SA',
			@today_dttm DATETIME = GETDATE(),
			@count INT

	BEGIN TRANSACTION	
	BEGIN TRY		
		PRINT 'Profile Automated Queue Cleanup Job started at ' + CAST(GETDATE() AS VARCHAR(20));
		
		DROP TABLE IF EXISTS #profiles_to_cancel

		SELECT p.profile_id, pt.tracking_id max_tracking_id, p.tracking_type, p.curr_status_code, p.customer_id, p.generator_id, 
		p.approval_desc, p.ap_expiration_date, p.ap_start_date, p.date_modified, p.modified_by, p.inactive_flag
		INTO #profiles_to_cancel
		FROM Profile p
		JOIN ProfileTracking pt ON p.profile_id = pt.profile_id
			AND pt.tracking_id = (SELECT Max(tracking_id) 
								 FROM ProfileTracking
								 WHERE profile_id = p.profile_id)
		JOIN ProfileLookup pl ON pl.code = pt.tracking_status AND pl.type = 'TrackingStatus'
			AND pl.description IN ('Awaiting Customer Response', 'Awaiting Internal Customer', 
								'Customer Service Pending', 'Incomplete - Paperwork', 'Needs Testing', 
								'New Profile', 'Operational Review', 'Pending Outbound Facility', 'ReApproval', 
								'Retail Tech Pending', 'Sample No Paperwork', 'Sending Customer confirmation', 
								'Tech New', 'Tech Pending', 'Testing', 'Treat Study')
		WHERE p.curr_status_code NOT IN ('A', 'C', 'R', 'V') -- 'P' - New/ Approved - Pending Pricess, H - Hold
		AND p.ap_start_date < CAST(DATEADD(DAY, -90, GETDATE()) AS DATE)
		AND p.profile_id > 0;

		SET @count = @@ROWCOUNT
		IF @debug = 1			
			PRINT CAST(@count AS VARCHAR) + ' profile records were found for cleanup.';

		WITH AuditColumns AS (SELECT 'tracking_type' name UNION 
							  SELECT 'curr_status_code' UNION
							  SELECT 'modified_by' UNION
							  SELECT 'date_modified')
		INSERT INTO dbo.ProfileAudit (profile_id, table_name, column_name, before_value, after_value, audit_reference, modified_by, date_modified) -- modified_by to be added
		SELECT   profile_id,
				'Profile',
				AuditColumns.name,
				CASE AuditColumns.name  WHEN 'tracking_type' THEN tracking_type
										WHEN 'curr_status_code' THEN curr_status_code 
										WHEN 'modified_by' THEN modified_by 
										WHEN 'date_modified' THEN CONVERT(VARCHAR, date_modified, 121)
										ELSE NULL END,
				CASE AuditColumns.name  WHEN 'tracking_type' THEN 'C'
										WHEN 'curr_status_code' THEN 'C' 
										WHEN 'modified_by' THEN 'SA'
										WHEN 'date_modified' THEN CONVERT(VARCHAR, @today_dttm, 121)
										ELSE NULL END,
				@audit_reference,
				@modified_by,
				@today_dttm
		FROM #profiles_to_cancel, AuditColumns

		SET @count = @@ROWCOUNT
		IF @debug = 1
			PRINT CAST(@count AS VARCHAR) + ' profile fee audit records were created';

		UPDATE p 
		SET p.curr_status_code = 'C',
			p.tracking_type = 'C',
			p.date_modified = @today_dttm,
			p.modified_by = @modified_by
		FROM Profile p
		JOIN #profiles_to_cancel tmp ON p.profile_id = tmp.profile_id

		SET @count = @@ROWCOUNT
		IF @debug = 1
			PRINT CAST(@count AS VARCHAR) + ' profile records were cancelled.';
	
		PRINT 'Profile Automated Queue Cleanup Job finished at ' + CAST(GETDATE() AS VARCHAR(20));	
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

GRANT EXECUTE ON  [dbo].[sp_process_profile_queue_cleanup] TO EQAI
GO