CREATE PROCEDURE sp_WasteCode2013_delete_waste_code
	@waste_code varchar(4)
AS

/***************************************************************************************
sp_WasteCode2013_delete_waste_code
	Cleans up Bad Waste codes from the system

Deletes from 
	WasteCode
	WasteCodeXProfitCenter
	WasteCodeCas

Audits, Deletes, and adds NONE if none left from
	ProfileWasteCode
	ReceiptWasteCode
	Receipt
	WorkOrderWasteCode
	
Audits, Deletes, and sets to Profile/TSDFApproval Primary, or NONE of necessary from
	Profile
	ProfileQuoteHeader
	TSDFApprovalWasteCode
	TSDFApproval

Audits, Switches waste code to current primary/none from
	Billing

Loads to:		Plt_AI

09/20/2013 SK	Created
09/26/2013 JPB	Renamed to sp_WasteCode2013_delete_waste_code (obv. belongs to that project now)
				Added inserts to WasteCode2013_Changes

****************************************************************************************/

DECLARE 
	@date_modified		datetime	= getdate()
	, @rowcount			int			= 0
	, @phase			decimal		= 3
	, @waste_code_uid	int
	, @tablename		varchar(40) = ''

CREATE TABLE #Affected_Records( 
	record_id		INT
,	company_id		INT
,	profit_ctr_id	INT
,	line_id			INT
)

PRINT '--------------------------------------------------------'
PRINT 'Starting delete of ' + @waste_code + ' in all tables on ' + DB_NAME()
PRINT '--------------------------------------------------------'

-- Gather info on the doomed waste code
SELECT @waste_code_uid = waste_code_uid from wastecode where waste_code = @waste_code

-- Log the operation's start
INSERT WasteCode2013_Changes (waste_code, waste_code_uid, action, description, phase, date_effective)
VALUES (@waste_code, @waste_code_uid, 'Delete Started (debug)', 'Delete via sp_WasteCode2013_delete_waste_code started ' + CASE WHEN @waste_code_uid is null then '(no waste_code_uid found in WasteCode)' else '(waste_code_uid = ' + convert(Varchar(20), @waste_code_uid) + ')' end, @phase, GETDATE())

begin transaction waste_code_delete

--WASTECODE
	set @tablename = 'WasteCode'
	IF @waste_code_uid is not null BEGIN
		IF EXISTS (select 1 from WASTECODE where waste_code = @waste_code and waste_code_uid = @waste_code_uid) BEGIN
		
			begin try
				DELETE FROM WasteCode where waste_code = @waste_code and waste_code_uid = @waste_code_uid
				set @rowcount = @@rowcount
			
				INSERT WasteCode2013_Changes (waste_code, waste_code_uid, action, description, phase, date_effective)
				VALUES (@waste_code, @waste_code_uid, 'Delete', 'Delete from ' + @tablename + '. ' + convert(varchar(20), @rowcount) + ' rows affected.', @phase, GETDATE())
			end try
			begin catch
				rollback transaction waste_code_delete
				-- Log the operation's failure
				INSERT WasteCode2013_Changes (waste_code, waste_code_uid, action, description, phase, date_effective)
				VALUES (@waste_code, @waste_code_uid, 'Delete Failed (debug)', 'Failed while working on ' + @tablename + '. Rolled back any changes made.', @phase, GETDATE())
				return
			end catch
			
		END
	END ELSE BEGIN
		INSERT WasteCode2013_Changes (waste_code, waste_code_uid, action, description, phase, date_effective)
		VALUES (@waste_code, @waste_code_uid, 'Delete (debug)', 'No records in ' + @tablename + '.', @phase, GETDATE())
	END
				
--WASTECODEXPROFITCENTER
	set @tablename = 'WasteCodeXProfitCenter'
	IF @waste_code_uid is not null BEGIN
		IF EXISTS (select 1 from WasteCodeXProfitCenter where waste_code = @waste_code and waste_code_uid = @waste_code_uid) BEGIN
			begin try
				DELETE FROM WasteCodeXProfitCenter where waste_code = @waste_code and waste_code_uid = @waste_code_uid
				set @rowcount = @@rowcount
				
				INSERT WasteCode2013_Changes (waste_code, waste_code_uid, action, description, phase, date_effective)
				VALUES (@waste_code, @waste_code_uid, 'Delete (debug)', 'Delete from ' + @tablename + '. ' + convert(varchar(20), @rowcount) + ' rows affected.', @phase, GETDATE())
			end try
			begin catch
				rollback transaction waste_code_delete
				-- Log the operation's failure
				INSERT WasteCode2013_Changes (waste_code, waste_code_uid, action, description, phase, date_effective)
				VALUES (@waste_code, @waste_code_uid, 'Delete Failed (debug)', 'Failed while working on ' + @tablename + '. Rolled back any changes made.', @phase, GETDATE())
				return
			end catch

		END
	END ELSE BEGIN
		INSERT WasteCode2013_Changes (waste_code, waste_code_uid, action, description, phase, date_effective)
		VALUES (@waste_code, @waste_code_uid, 'Delete (debug)', 'No records in ' + @tablename + '.', @phase, GETDATE())
	END
		
--WASTECODECAS
	set @tablename = 'WasteCodeCas'
	IF @waste_code_uid is not null BEGIN
		IF EXISTS (select 1 from WasteCodeCas where waste_code = @waste_code and waste_code_uid = @waste_code_uid) BEGIN
			begin try
				DELETE FROM WasteCodeCas where waste_code = @waste_code and waste_code_uid = @waste_code_uid
				set @rowcount = @@rowcount
			
				INSERT WasteCode2013_Changes (waste_code, waste_code_uid, action, description, phase, date_effective)
				VALUES (@waste_code, @waste_code_uid, 'Delete (debug)', 'Delete from ' + @tablename + '. ' + convert(varchar(20), @rowcount) + ' rows affected.', @phase, GETDATE())
			end try
			begin catch
				rollback transaction waste_code_delete
				-- Log the operation's failure
				INSERT WasteCode2013_Changes (waste_code, waste_code_uid, action, description, phase, date_effective)
				VALUES (@waste_code, @waste_code_uid, 'Delete Failed (debug)', 'Failed while working on ' + @tablename + '. Rolled back any changes made.', @phase, GETDATE())
				return
			end catch

		END
	END ELSE BEGIN
		INSERT WasteCode2013_Changes (waste_code, waste_code_uid, action, description, phase, date_effective)
		VALUES (@waste_code, @waste_code_uid, 'Delete (debug)', 'No records in ' + @tablename + '.', @phase, GETDATE())
	END
		
--PROFILEWASTECODE
	set @tablename = 'ProfileWasteCode'
	IF @waste_code_uid is not null BEGIN
		IF EXISTS (select 1 from ProfileWasteCode where waste_code = @waste_code and waste_code_uid = @waste_code_uid) BEGIN
		
			begin try
				INSERT #Affected_Records
				SELECT DISTINCT profile_id, NULL, NULL, NULL
				FROM dbo.ProfileWasteCode WHERE waste_code = @waste_code and waste_code_uid = @waste_code_uid ORDER BY profile_id

				-- Audit this change
				INSERT INTO ProfileAudit
				SELECT
						ProfileWasteCode.profile_id
					,	'ProfileWasteCode'
					,	'waste_code'
					,	@waste_code
					,	''
					,	'Deleted waste code ' + @waste_code
					,	'SA-WASTE'
					,	@date_modified
					,	newID()
				FROM dbo.ProfileWasteCode WHERE dbo.ProfileWasteCode.waste_code = @waste_code and waste_code_uid = @waste_code_uid ORDER BY profile_id

				DELETE FROM ProfileWasteCode where waste_code = @waste_code and waste_code_uid = @waste_code_uid
				set @rowcount = @@rowcount
				
				INSERT WasteCode2013_Changes (waste_code, waste_code_uid, action, description, phase, date_effective)
				VALUES (@waste_code, @waste_code_uid, 'Delete (debug)', 'Delete from ' + @tablename + '. ' + convert(varchar(20), @rowcount) + ' rows affected (AUDITED).', @phase, GETDATE())
				
				-- For affected profiles which don't have any waste codes now,add 'None'
				INSERT INTO ProfileAudit
				SELECT
						#Affected_Records.record_id
					,	'ProfileWasteCode'
					,	'waste_code'
					,	''
					,	'NONE'
					,	'Added waste code NONE'
					,	'SA-WASTE'
					,	@date_modified
					,	newID()
				FROM #Affected_Records
				WHERE NOT EXISTS (SELECT 1 FROM ProfileWasteCode PWC where PWC.profile_id = #Affected_Records.record_id)
				
				INSERT INTO dbo.ProfileWasteCode
				SELECT #Affected_Records.record_id	-- profile_id - int
				,	'T'									-- primary_flag - char(1)
				,	WasteCode.waste_code_uid			-- waste_code_uid - int
				,	WasteCode.waste_code				-- waste_code - varchar(4)
				,	'SA-WASTE'							-- added_by - varchar(10)
				,	@date_modified							-- date_added - datetime
				,	NEWID()								-- rowguid - uniqueidentifier
				,	1									-- sequence_id
				,	'O' AS sequence_flag
				FROM #Affected_Records
				JOIN WasteCode ON WasteCode.waste_code = 'NONE'
				WHERE NOT EXISTS (SELECT 1 FROM ProfileWasteCode PWC where PWC.profile_id = #Affected_Records.record_id)
				set @rowcount = @@rowcount
				
				INSERT WasteCode2013_Changes (waste_code, waste_code_uid, action, description, phase, date_effective)
				VALUES (@waste_code, @waste_code_uid, 'Delete (debug)', 'Added waste_code ''NONE'' where there none left in on affected profiles in ' + @tablename + '. ' + convert(varchar(20), @rowcount) + ' rows affected (AUDITED).', @phase, GETDATE())

				DELETE FROM #Affected_Records
			
			end try
			begin catch
				rollback transaction waste_code_delete
				-- Log the operation's failure
				INSERT WasteCode2013_Changes (waste_code, waste_code_uid, action, description, phase, date_effective)
				VALUES (@waste_code, @waste_code_uid, 'Delete Failed (debug)', 'Failed while working on ' + @tablename + '. Rolled back any changes made.', @phase, GETDATE())
				return
			end catch
		END
	END ELSE BEGIN
		INSERT WasteCode2013_Changes (waste_code, waste_code_uid, action, description, phase, date_effective)
		VALUES (@waste_code, @waste_code_uid, 'Delete (debug)', 'No records in ' + @tablename + '.', @phase, GETDATE())
	END

--PROFILE
	set @tablename = 'Profile'
--	IF @waste_code_uid is not null BEGIN -- In this table, waste_code_uid is NULLABLE
		IF EXISTS (select 1 from Profile where waste_code = @waste_code OR waste_code_uid = @waste_code_uid) BEGIN
		
			begin try
				-- Audit this change
				INSERT INTO ProfileAudit
				SELECT
						Profile.profile_id
					,	'Profile'
					,	'waste_code'
					,	@waste_code
					,	Coalesce(ProfileWasteCode.waste_code, WasteCode.waste_code)
					,	'Updated waste code from ' + @waste_code + ' to ' + Coalesce(ProfileWasteCode.waste_code, WasteCode.waste_code)
					,	'SA-WASTE'
					,	@date_modified
					,	newID()
				FROM Profile
				JOIN WasteCode ON WasteCode.waste_code = 'NONE'
				LEFT OUTER JOIN ProfileWasteCode 
					ON ProfileWasteCode.profile_id = Profile.profile_id
					AND ProfileWasteCode.primary_flag = 'T'
				WHERE Profile.waste_code = @waste_code

				INSERT INTO ProfileAudit
					SELECT
						Profile.profile_id
					,	'Profile'
					,	'waste_code_uid'
					,	@waste_code_uid
					,	Coalesce(ProfileWasteCode.waste_code_uid, WasteCode.waste_code_uid)
					,	'Updated waste code uid from ' + convert(Varchar(20), @waste_code_uid) + ' to ' + convert(varchar(20), Coalesce(ProfileWasteCode.waste_code_uid, WasteCode.waste_code_uid))
					,	'SA-WASTE'
					,	@date_modified
					,	newID()
				FROM Profile
				JOIN WasteCode ON WasteCode.waste_code = 'NONE'
				LEFT OUTER JOIN ProfileWasteCode 
					ON ProfileWasteCode.profile_id = Profile.profile_id
					AND ProfileWasteCode.primary_flag = 'T'
				WHERE Profile.waste_code_uid = @waste_code_uid

				UPDATE Profile Set waste_code = Coalesce(ProfileWasteCode.waste_code, WasteCode.waste_code),
				waste_code_uid = Coalesce(ProfileWasteCode.waste_code_uid, WasteCode.waste_code_uid)
				FROM Profile
				JOIN WasteCode ON WasteCode.waste_code = 'NONE'
				LEFT OUTER JOIN ProfileWasteCode 
					ON ProfileWasteCode.profile_id = Profile.profile_id
					AND ProfileWasteCode.primary_flag = 'T'
				WHERE Profile.waste_code = @waste_code OR Profile.waste_code_uid = @waste_code_uid 
				set @rowcount = @@rowcount
				
				INSERT WasteCode2013_Changes (waste_code, waste_code_uid, action, description, phase, date_effective)
				VALUES (@waste_code, @waste_code_uid, 'Delete (debug)', 'Switched to Primary waste code or NONE in ' + @tablename + '. ' + convert(varchar(20), @rowcount) + ' rows affected (AUDITED).', @phase, GETDATE())
			end try
			begin catch
				rollback transaction waste_code_delete
				-- Log the operation's failure
				INSERT WasteCode2013_Changes (waste_code, waste_code_uid, action, description, phase, date_effective)
				VALUES (@waste_code, @waste_code_uid, 'Delete Failed (debug)', 'Failed while working on ' + @tablename + '. Rolled back any changes made.', @phase, GETDATE())
				return
			end catch
						
		END ELSE BEGIN
			INSERT WasteCode2013_Changes (waste_code, waste_code_uid, action, description, phase, date_effective)
			VALUES (@waste_code, @waste_code_uid, 'Delete (debug)', 'No records in ' + @tablename + '.', @phase, GETDATE())
		END

--PROFILEQUOTEHEADER
	set @tablename = 'ProfileQuoteHeader'
--	IF @waste_code_uid is not null BEGIN -- There's no _uid on this table, that's on purpose.  We might get rid of this field, but for now keep it consistent.
		IF EXISTS (select 1 from ProfileQuoteHeader where waste_code = @waste_code) BEGIN

			begin try
				-- Audit and Update this waste code
				INSERT INTO ProfileAudit
				SELECT
						PQH.profile_id
					,	'ProfileQuoteHeader'
					,	'waste_code'
					,	@waste_code
					,	Profile.waste_code
					,	'Updated waste code from ' + @waste_code + ' to ' + Profile.waste_code
					,	'SA-WASTE'
					,	@date_modified
					,	newID()
				FROM ProfileQuoteHeader PQH
				JOIN Profile ON Profile.profile_id = PQH.profile_id
				WHERE PQH.waste_code = @waste_code
				
				UPDATE ProfileQuoteHeader Set waste_code = Profile.waste_code
				--, waste_code_uid = Profile.waste_code_uid
				FROM ProfileQuoteHeader
				JOIN Profile ON Profile.profile_id = ProfileQuoteHeader.profile_id
				WHERE ProfileQuoteHeader.waste_code = @waste_code

				set @rowcount = @@rowcount
				
				INSERT WasteCode2013_Changes (waste_code, waste_code_uid, action, description, phase, date_effective)
				VALUES (@waste_code, @waste_code_uid, 'Delete (debug)', 'Switched to Profile''s waste code in ' + @tablename + '. ' + convert(varchar(20), @rowcount) + ' rows affected (AUDITED).', @phase, GETDATE())
			end try
			begin catch
				rollback transaction waste_code_delete
				-- Log the operation's failure
				INSERT WasteCode2013_Changes (waste_code, waste_code_uid, action, description, phase, date_effective)
				VALUES (@waste_code, @waste_code_uid, 'Delete Failed (debug)', 'Failed while working on ' + @tablename + '. Rolled back any changes made.', @phase, GETDATE())
				return
			end catch
			
		END ELSE BEGIN
			INSERT WasteCode2013_Changes (waste_code, waste_code_uid, action, description, phase, date_effective)
			VALUES (@waste_code, @waste_code_uid, 'Delete (debug)', 'No records in ' + @tablename + '.', @phase, GETDATE())
		END

--TSDFAPPROVALWASTECODE
	set @tablename = 'TSDFApprovalWasteCode'
	IF @waste_code_uid is not null BEGIN
		IF EXISTS (select 1 from TSDFApprovalWasteCode where waste_code = @waste_code and waste_code_uid = @waste_code_uid) BEGIN
		
			begin try
				INSERT #Affected_Records
				SELECT DISTINCT TSDF_approval_id, company_id, profit_ctr_id, NULL
				FROM dbo.TSDFApprovalWasteCode WHERE waste_code = @waste_code and waste_code_uid = @waste_code_uid ORDER BY TSDF_approval_id

				DELETE FROM TSDFApprovalWasteCode where waste_code = @waste_code and waste_code_uid = @waste_code_uid
				set @rowcount = @@rowcount
				
				INSERT WasteCode2013_Changes (waste_code, waste_code_uid, action, description, phase, date_effective)
				VALUES (@waste_code, @waste_code_uid, 'Delete (debug)', 'Delete from ' + @tablename + '. ' + convert(varchar(20), @rowcount) + ' rows affected.', @phase, GETDATE())

				-- For affected approvals which don't have any waste codes now,add 'None'
				INSERT INTO dbo.TSDFApprovalWasteCode
				SELECT #Affected_Records.record_id	-- tsdf_approval_id - int
				,	#Affected_Records.company_id			--	company_id int
				,	#Affected_Records.profit_ctr_id		-- profit_ctr_id
				,	'T'									-- primary_flag - char(1)
				,	WasteCode.waste_code_uid			-- waste_code_uid - int
				,	WasteCode.waste_code				-- waste_code - varchar(4)
				,	'SA-WASTE'							-- added_by - varchar(10)
				,	@date_modified							-- date_added - datetime
				,	NEWID()								-- rowguid - uniqueidentifier
				,	1									-- sequence_id
				,	'O' AS sequence_flag
				FROM #Affected_Records
				JOIN WasteCode ON WasteCode.waste_code = 'NONE'
				JOIN TSDFApproval ON TSDFApproval.tsdf_approval_id = #Affected_Records.record_id
					and TSDFApproval.company_id = #Affected_Records.company_id
					and TSDFApproval.profit_ctr_id = #Affected_Records.profit_ctr_id
				WHERE NOT EXISTS (SELECT 1 FROM TSDFApprovalWasteCode PWC where PWC.tsdf_approval_id = #Affected_Records.record_id
					and TSDFApproval.company_id = #Affected_Records.company_id
					and TSDFApproval.profit_ctr_id = #Affected_Records.profit_ctr_id
				)
				set @rowcount = @@rowcount
				
				INSERT WasteCode2013_Changes (waste_code, waste_code_uid, action, description, phase, date_effective)
				VALUES (@waste_code, @waste_code_uid, 'Delete (debug)', 'Added waste_code ''NONE'' where there none left in on affected approvals in ' + @tablename + '. ' + convert(varchar(20), @rowcount) + ' rows affected.', @phase, GETDATE())

				DELETE FROM #Affected_Records
			end try
			begin catch
				rollback transaction waste_code_delete
				-- Log the operation's failure
				INSERT WasteCode2013_Changes (waste_code, waste_code_uid, action, description, phase, date_effective)
				VALUES (@waste_code, @waste_code_uid, 'Delete Failed (debug)', 'Failed while working on ' + @tablename + '. Rolled back any changes made.', @phase, GETDATE())
				return
			end catch
			
		END
	END ELSE BEGIN
		INSERT WasteCode2013_Changes (waste_code, waste_code_uid, action, description, phase, date_effective)
		VALUES (@waste_code, @waste_code_uid, 'Delete (debug)', 'No records in ' + @tablename + '.', @phase, GETDATE())
	END

--TSDFAPPROVAL
	set @tablename = 'TSDFApproval'
--	IF @waste_code_uid is not null BEGIN -- In this table, waste_code_uid is NULLABLE
		IF EXISTS (select 1 from TSDFApproval where waste_code = @waste_code OR waste_code_uid = @waste_code_uid) BEGIN
		
			begin try
				UPDATE TSDFApproval Set waste_code = Coalesce(TSDFApprovalWasteCode.waste_code, WasteCode.waste_code),
				waste_code_uid = Coalesce(TSDFApprovalWasteCode.waste_code_uid, WasteCode.waste_code_uid)
				FROM TSDFApproval
				JOIN WasteCode ON WasteCode.waste_code = 'NONE'
				LEFT OUTER JOIN TSDFApprovalWasteCode 
					ON TSDFApprovalWasteCode.tsdf_approval_id = TSDFApproval.tsdf_approval_id
					AND TSDFApprovalWasteCode.primary_flag = 'T'
				WHERE TSDFApproval.waste_code = @waste_code OR TSDFApproval.waste_code_uid = @waste_code_uid 
				set @rowcount = @@rowcount
				
				INSERT WasteCode2013_Changes (waste_code, waste_code_uid, action, description, phase, date_effective)
				VALUES (@waste_code, @waste_code_uid, 'Delete (debug)', 'Switched to Primary waste code or NONE in ' + @tablename + '. ' + convert(varchar(20), @rowcount) + ' rows affected.', @phase, GETDATE())
			end try
			begin catch
				rollback transaction waste_code_delete
				-- Log the operation's failure
				INSERT WasteCode2013_Changes (waste_code, waste_code_uid, action, description, phase, date_effective)
				VALUES (@waste_code, @waste_code_uid, 'Delete Failed (debug)', 'Failed while working on ' + @tablename + '. Rolled back any changes made.', @phase, GETDATE())
				return
			end catch
						
		END ELSE BEGIN
			INSERT WasteCode2013_Changes (waste_code, waste_code_uid, action, description, phase, date_effective)
			VALUES (@waste_code, @waste_code_uid, 'Delete (debug)', 'No records in ' + @tablename + '.', @phase, GETDATE())
		END
		
--RECEIPTWASTECODE
	set @tablename = 'ReceiptWasteCode'
	IF @waste_code_uid is not null BEGIN
		IF EXISTS (select 1 from ReceiptWasteCode where waste_code = @waste_code and waste_code_uid = @waste_code_uid) BEGIN

			begin try		
				INSERT #Affected_Records
				SELECT Receipt_id, company_id, profit_ctr_id, line_id 
				FROM dbo.ReceiptWasteCode WHERE waste_code = @waste_code and waste_code_uid = @waste_code_uid ORDER BY Receipt_id

				-- Audit this change
				INSERT INTO ReceiptAudit
				SELECT
						ReceiptWasteCode.company_id
					,	ReceiptWasteCode.profit_ctr_id
					,	ReceiptWasteCode.receipt_id
					,	ReceiptWasteCode.line_id
					,	NULL
					,	'ReceiptWasteCode'
					,	'waste_code'
					,	@waste_code
					,	''
					,	'Deleted waste code ' + @waste_code
					,	'SA-WASTE'
					,	''
					,	@date_modified
				FROM dbo.ReceiptWasteCode WHERE dbo.ReceiptWasteCode.waste_code = @waste_code and waste_code_uid = @waste_code_uid ORDER BY receipt_id

				DELETE FROM ReceiptWasteCode where waste_code = @waste_code and waste_code_uid = @waste_code_uid
				set @rowcount = @@rowcount
				
				INSERT WasteCode2013_Changes (waste_code, waste_code_uid, action, description, phase, date_effective)
				VALUES (@waste_code, @waste_code_uid, 'Delete (debug)', 'Delete from ' + @tablename + '. ' + convert(varchar(20), @rowcount) + ' rows affected (AUDITED).', @phase, GETDATE())
				
				-- For affected Receipt lines which don't have any waste codes now,add 'None'
				INSERT INTO ReceiptAudit
				SELECT
						#Affected_Records.company_id
					,	#Affected_Records.profit_ctr_id
					,	#Affected_Records.record_id
					,	#Affected_Records.line_id
					,	NULL
					,	'ReceiptWasteCode'
					,	'waste_code'
					,	''
					,	'NONE'
					,	'Added waste code NONE'
					,	'SA-WASTE'
					,	''
					,	@date_modified
				FROM #Affected_Records
				WHERE NOT EXISTS (SELECT 1 FROM ReceiptWasteCode PWC where PWC.Receipt_id = #Affected_Records.record_id
									AND PWC.line_id = #Affected_records.line_id AND PWC.company_id = #Affected_Records.company_id
									AND PWC.profit_ctr_id = #Affected_Records.profit_ctr_id)
				
				INSERT INTO dbo.ReceiptWasteCode
				SELECT 
					#Affected_Records.company_id
				,	#Affected_Records.profit_ctr_id
				,	#Affected_Records.record_id
				,	#Affected_Records.line_id
				,	'T'									-- primary_flag - char(1)
				,	WasteCode.waste_code_uid			-- waste_code_uid - int
				,	WasteCode.waste_code				-- waste_code - varchar(4)
				,	'SA-WASTE'							
				,	@date_modified							
				,	1									
				FROM #Affected_Records
				JOIN WasteCode ON WasteCode.waste_code = 'NONE'
				WHERE NOT EXISTS (SELECT 1 FROM ReceiptWasteCode PWC where PWC.Receipt_id = #Affected_Records.record_id
									AND PWC.line_id = #Affected_records.line_id AND PWC.company_id = #Affected_Records.company_id
									AND PWC.profit_ctr_id = #Affected_Records.profit_ctr_id)
				set @rowcount = @@rowcount
				
				INSERT WasteCode2013_Changes (waste_code, waste_code_uid, action, description, phase, date_effective)
				VALUES (@waste_code, @waste_code_uid, 'Delete (debug)', 'Added waste_code ''NONE'' where there none left in on affected receipt lines in ' + @tablename + '. ' + convert(varchar(20), @rowcount) + ' rows affected (AUDITED).', @phase, GETDATE())

				DELETE FROM #Affected_Records
			
			end try
			begin catch
				rollback transaction waste_code_delete
				-- Log the operation's failure
				INSERT WasteCode2013_Changes (waste_code, waste_code_uid, action, description, phase, date_effective)
				VALUES (@waste_code, @waste_code_uid, 'Delete Failed (debug)', 'Failed while working on ' + @tablename + '. Rolled back any changes made.', @phase, GETDATE())
				return
			end catch
		END
	END ELSE BEGIN
		INSERT WasteCode2013_Changes (waste_code, waste_code_uid, action, description, phase, date_effective)
		VALUES (@waste_code, @waste_code_uid, 'Delete (debug)', 'No records in ' + @tablename + '.', @phase, GETDATE())
	END

--RECEIPT
	set @tablename = 'Receipt'
--	IF @waste_code_uid is not null BEGIN -- In this table, waste_code_uid is NULLABLE
		IF EXISTS (select 1 from Receipt where waste_code = @waste_code OR waste_code_uid = @waste_code_uid) BEGIN

			begin try		
				-- Audit this change
				INSERT INTO ReceiptAudit
				SELECT
						Receipt.company_id
					,	Receipt.profit_ctr_id
					,	Receipt.receipt_id
					,	Receipt.line_id
					,	NULL
					,	'Receipt'
					,	'waste_code'
					,	@waste_code
					,	Coalesce(ReceiptWasteCode.waste_code, WasteCode.waste_code)
					,	'Updated waste code from ' + @waste_code + ' to ' + Coalesce(ReceiptWasteCode.waste_code, WasteCode.waste_code)
					,	'SA-WASTE'
					,	Receipt.modified_by
					,	@date_modified
				FROM Receipt
				JOIN WasteCode ON WasteCode.waste_code = 'NONE'
				LEFT OUTER JOIN ReceiptWasteCode 
					ON ReceiptWasteCode.Receipt_id = Receipt.Receipt_id
					AND ReceiptWasteCode.company_id = Receipt.company_id
					AND ReceiptWasteCode.profit_ctr_id = Receipt.profit_ctr_id
					AND ReceiptWasteCode.line_id = Receipt.line_id
					AND ReceiptWasteCode.sequence_id = (Select MIN(sequence_id) FROM ReceiptWasteCode RWC
														where RWC.receipt_id = Receipt.Receipt_id
															AND RWC.company_id = Receipt.company_id
															AND RWC.profit_ctr_id = Receipt.profit_ctr_id
															AND RWC.line_id = Receipt.line_id)
				WHERE Receipt.waste_code = @waste_code

				INSERT INTO ReceiptAudit
				SELECT
						Receipt.company_id
					,	Receipt.profit_ctr_id
					,	Receipt.receipt_id
					,	Receipt.line_id
					,	NULL
					,	'Receipt'
					,	'waste_code_uid'
					,	@waste_code_uid
					,	Coalesce(ReceiptWasteCode.waste_code_uid, WasteCode.waste_code_uid)
					,	'Updated waste code uid from ' + convert(Varchar(20), @waste_code_uid) + ' to ' + Convert(varchar(20), Coalesce(ReceiptWasteCode.waste_code_uid, WasteCode.waste_code_uid))
					,	'SA-WASTE'
					,	Receipt.modified_by
					,	@date_modified
				FROM Receipt
				JOIN WasteCode ON WasteCode.waste_code = 'NONE'
				LEFT OUTER JOIN ReceiptWasteCode 
					ON ReceiptWasteCode.Receipt_id = Receipt.Receipt_id
					AND ReceiptWasteCode.company_id = Receipt.company_id
					AND ReceiptWasteCode.profit_ctr_id = Receipt.profit_ctr_id
					AND ReceiptWasteCode.line_id = Receipt.line_id
					AND ReceiptWasteCode.sequence_id = (Select MIN(sequence_id) FROM ReceiptWasteCode RWC
														where RWC.receipt_id = Receipt.Receipt_id
															AND RWC.company_id = Receipt.company_id
															AND RWC.profit_ctr_id = Receipt.profit_ctr_id
															AND RWC.line_id = Receipt.line_id)
				WHERE Receipt.waste_code_uid = @waste_code_uid

				UPDATE Receipt Set waste_code = Coalesce(ReceiptWasteCode.waste_code, WasteCode.waste_code),
				waste_code_uid = Coalesce(ReceiptWasteCode.waste_code_uid, WasteCode.waste_code_uid)
				FROM Receipt
				JOIN WasteCode ON WasteCode.waste_code = 'NONE'
				LEFT OUTER JOIN ReceiptWasteCode 
					ON ReceiptWasteCode.Receipt_id = Receipt.receipt_id
					AND ReceiptWasteCode.company_id = Receipt.company_id
					AND ReceiptWasteCode.profit_ctr_id = Receipt.profit_ctr_id
					AND ReceiptWasteCode.line_id = Receipt.line_id
					AND ReceiptWasteCode.sequence_id = (Select MIN(sequence_id) FROM ReceiptWasteCode RWC
														where RWC.receipt_id = Receipt.receipt_id
															AND RWC.company_id = Receipt.company_id
															AND RWC.profit_ctr_id = Receipt.profit_ctr_id
															AND RWC.line_id = Receipt.line_id)
				WHERE Receipt.waste_code = @waste_code
				set @rowcount = @@rowcount
				
				INSERT WasteCode2013_Changes (waste_code, waste_code_uid, action, description, phase, date_effective)
				VALUES (@waste_code, @waste_code_uid, 'Delete (debug)', 'Switched to first waste code or NONE in ' + @tablename + '. ' + convert(varchar(20), @rowcount) + ' rows affected (AUDITED).', @phase, GETDATE())
			end try
			begin catch
				rollback transaction waste_code_delete
				-- Log the operation's failure
				INSERT WasteCode2013_Changes (waste_code, waste_code_uid, action, description, phase, date_effective)
				VALUES (@waste_code, @waste_code_uid, 'Delete Failed (debug)', 'Failed while working on ' + @tablename + '. Rolled back any changes made.', @phase, GETDATE())
				return
			end catch
						
		END ELSE BEGIN
			INSERT WasteCode2013_Changes (waste_code, waste_code_uid, action, description, phase, date_effective)
			VALUES (@waste_code, @waste_code_uid, 'Delete (debug)', 'No records in ' + @tablename + '.', @phase, GETDATE())
		END
				
--WORKORDERWASTECODE
	set @tablename = 'WorkOrderWasteCode'
	IF @waste_code_uid is not null BEGIN
		IF EXISTS (select 1 from WorkOrderWasteCode where waste_code = @waste_code and waste_code_uid = @waste_code_uid) BEGIN
		
			begin try
				INSERT #Affected_Records
				SELECT DISTINCT workorder_id, company_id, profit_ctr_id, workorder_sequence_id 
				FROM dbo.WorkOrderWasteCode WHERE waste_code = @waste_code ORDER BY workorder_id

				-- Audit this change
				INSERT INTO WorkOrderAudit
				SELECT
						WorkOrderWasteCode.company_id
					,	WorkOrderWasteCode.profit_ctr_id
					,	WorkOrderWasteCode.workorder_id
					,	''
					,	WorkOrderWasteCode.workorder_sequence_id
					,	'WorkOrderWasteCode'
					,	'waste_code'
					,	@waste_code
					,	''
					,	'Deleted waste code ' + @waste_code
					,	'SA-WASTE'
					,	@date_modified
				FROM dbo.WorkOrderWasteCode WHERE waste_code = @waste_code and waste_code_uid = @waste_code_uid ORDER BY workorder_id

				DELETE FROM WorkOrderWasteCode where waste_code = @waste_code and waste_code_uid = @waste_code_uid
				set @rowcount = @@rowcount
				
				INSERT WasteCode2013_Changes (waste_code, waste_code_uid, action, description, phase, date_effective)
				VALUES (@waste_code, @waste_code_uid, 'Delete (debug)', 'Delete from ' + @tablename + '. ' + convert(varchar(20), @rowcount) + ' rows affected (AUDITED).', @phase, GETDATE())
				
				-- For affected WorkOrder lines which don't have any waste codes now,add 'None'
				INSERT INTO WorkOrderAudit
				SELECT
						#Affected_Records.company_id
					,	#Affected_Records.profit_ctr_id
					,	#Affected_Records.record_id
					,	''
					,	#Affected_Records.line_id
					,	'WorkOrderWasteCode'
					,	'waste_code'
					,	''
					,	'NONE'
					,	'Added waste code NONE'
					,	'SA-WASTE'
					,	@date_modified
				FROM #Affected_Records
				WHERE NOT EXISTS (SELECT 1 FROM WorkOrderWasteCode PWC where PWC.WorkOrder_id = #Affected_Records.record_id
									AND PWC.workorder_sequence_id = #Affected_records.line_id AND PWC.company_id = #Affected_Records.company_id
									AND PWC.profit_ctr_id = #Affected_Records.profit_ctr_id)
				
				INSERT INTO dbo.WorkOrderWasteCode
				SELECT 
					#Affected_Records.company_id
				,	#Affected_Records.profit_ctr_id
				,	#Affected_Records.record_id
				,	#Affected_Records.line_id
				,	WasteCode.waste_code_uid			-- waste_code_uid - int
				,	WasteCode.waste_code				-- waste_code - varchar(4)
				,	1	
				,	'SA-WASTE'							
				,	@date_modified							
				FROM #Affected_Records
				JOIN WasteCode ON WasteCode.waste_code = 'NONE'
				WHERE NOT EXISTS (SELECT 1 FROM WorkOrderWasteCode PWC where PWC.WorkOrder_id = #Affected_Records.record_id
									AND PWC.workorder_sequence_id = #Affected_records.line_id AND PWC.company_id = #Affected_Records.company_id
									AND PWC.profit_ctr_id = #Affected_Records.profit_ctr_id)
				set @rowcount = @@rowcount
				
				INSERT WasteCode2013_Changes (waste_code, waste_code_uid, action, description, phase, date_effective)
				VALUES (@waste_code, @waste_code_uid, 'Delete (debug)', 'Added waste_code ''NONE'' where there none left in on affected workorder lines in ' + @tablename + '. ' + convert(varchar(20), @rowcount) + ' rows affected (AUDITED).', @phase, GETDATE())

				DELETE FROM #Affected_Records
			end try
			begin catch
				rollback transaction waste_code_delete
				-- Log the operation's failure
				INSERT WasteCode2013_Changes (waste_code, waste_code_uid, action, description, phase, date_effective)
				VALUES (@waste_code, @waste_code_uid, 'Delete Failed (debug)', 'Failed while working on ' + @tablename + '. Rolled back any changes made.', @phase, GETDATE())
				return
			end catch
				
		END
	END ELSE BEGIN
		INSERT WasteCode2013_Changes (waste_code, waste_code_uid, action, description, phase, date_effective)
		VALUES (@waste_code, @waste_code_uid, 'Delete (debug)', 'No records in ' + @tablename + '.', @phase, GETDATE())
	END

--BILLING
	set @tablename = 'Billing'
--	IF @waste_code_uid is not null BEGIN -- In this table, waste_code_uid is NULLABLE
		IF EXISTS (select 1 from Billing where waste_code = @waste_code OR waste_code_uid = @waste_code_uid) BEGIN

			begin try
				-- Audit this change
			
				DECLARE @Audit_id INT
				
				Select @Audit_id = Isnull(Max(Audit_id), 0) + 1 from BillingAudit

				INSERT INTO BillingAudit
				SELECT
					@Audit_id
				,	B.company_id
				,	B.profit_ctr_id
				,	B.receipt_id
				,	B.line_id
				,	Isnull(B.price_id, 0)
				,	0
				,	''
				,	'Billing'
				,	'waste_code'
				,	@waste_code
				,	'NONE'
				,	@date_modified
				,	'SA-WASTE'
				,	'Updated for receipts of type Disposal and Wash'
				,	B.trans_source
				FROM Billing B
				WHERE B.waste_code = @waste_code
				AND B.trans_source = 'R'
				AND B.trans_type IN ('D', 'W')

				INSERT INTO BillingAudit
				SELECT
					@Audit_id
				,	B.company_id
				,	B.profit_ctr_id
				,	B.receipt_id
				,	B.line_id
				,	Isnull(B.price_id, 0)
				,	0
				,	''
				,	'Billing'
				,	'waste_code_uid'
				,	@waste_code_uid
				,	WasteCode.waste_code_uid
				,	@date_modified
				,	'SA-WASTE'
				,	'Updated for receipts of type Disposal and Wash'
				,	B.trans_source
				FROM Billing B
				JOIN WasteCode ON WasteCode.waste_code = 'NONE'
				WHERE B.waste_code_uid = @waste_code_uid
				AND B.trans_source = 'R'
				AND B.trans_type IN ('D', 'W')		
				
				UPDATE Billing Set waste_code = WasteCode.waste_code, waste_code_uid = WasteCode.waste_code_uid
				, modified_by = 'SA-WASTE', date_modified = @date_modified
				FROM Billing JOIN WasteCode ON WasteCode.waste_code = 'NONE' WHERE Billing.waste_code = @waste_code
				AND Billing.trans_source = 'R' AND Billing.trans_type IN ('D', 'W')
				set @rowcount = @@rowcount

				INSERT WasteCode2013_Changes (waste_code, waste_code_uid, action, description, phase, date_effective)
				VALUES (@waste_code, @waste_code_uid, 'Delete (debug)', 'Switched to waste code NONE in ' + @tablename + ' (for receipts of type Disposal and Wash). ' + convert(varchar(20), @rowcount) + ' rows affected (AUDITED).', @phase, GETDATE())

				Select @Audit_id = Isnull(Max(Audit_id), 0) + 1 from BillingAudit

				INSERT INTO BillingAudit
				SELECT
					@Audit_id
				,	B.company_id
				,	B.profit_ctr_id
				,	B.receipt_id
				,	B.line_id
				,	Isnull(B.price_id, 0)
				,	0
				,	''
				,	'Billing'
				,	'waste_code'
				,	@waste_code
				,	NULL
				,	@date_modified
				,	'SA-WASTE'
				,	'Updated for workorders, retail orders and receipts other than Disposal and Wash'
				,	B.trans_source
				FROM Billing B
				WHERE B.waste_code = @waste_code
				AND B.trans_source IN ('R', 'W', 'O')
				AND B.trans_type NOT IN ('D', 'W')

				INSERT INTO BillingAudit
				SELECT
					@Audit_id
				,	B.company_id
				,	B.profit_ctr_id
				,	B.receipt_id
				,	B.line_id
				,	Isnull(B.price_id, 0)
				,	0
				,	''
				,	'Billing'
				,	'waste_code_uid'
				,	@waste_code_uid
				,	NULL
				,	@date_modified
				,	'SA-WASTE'
				,	'Updated for workorders, retail orders and receipts other than Disposal and Wash'
				,	B.trans_source
				FROM Billing B
				WHERE B.waste_code_uid = @waste_code_uid
				AND B.trans_source IN ('R', 'W', 'O')
				AND B.trans_type NOT IN ('D', 'W')			
				
				UPDATE Billing Set waste_code = NULL, waste_code_uid = NULL
				, modified_by = 'SA-WASTE', date_modified = @date_modified
				FROM Billing WHERE Billing.waste_code = @waste_code
				AND Billing.trans_source IN ('R', 'W', 'O') AND Billing.trans_type NOT IN ('D', 'W')
				set @rowcount = @@rowcount

				INSERT WasteCode2013_Changes (waste_code, waste_code_uid, action, description, phase, date_effective)
				VALUES (@waste_code, @waste_code_uid, 'Delete (debug)', 'Switched to waste code NONE in ' + @tablename + ' (for workorders, retail orders and receipts other than Disposal and Wash). ' + convert(varchar(20), @rowcount) + ' rows affected (AUDITED).', @phase, GETDATE())
			end try
			begin catch
				rollback transaction waste_code_delete
				-- Log the operation's failure
				INSERT WasteCode2013_Changes (waste_code, waste_code_uid, action, description, phase, date_effective)
				VALUES (@waste_code, @waste_code_uid, 'Delete Failed (debug)', 'Failed while working on ' + @tablename + '. Rolled back any changes made.', @phase, GETDATE())
				return
			end catch

		END ELSE BEGIN
			INSERT WasteCode2013_Changes (waste_code, waste_code_uid, action, description, phase, date_effective)
			VALUES (@waste_code, @waste_code_uid, 'Delete (debug)', 'No records in ' + @tablename + '.', @phase, GETDATE())
		END
		
	PRINT '--------------------------------------------------------'
	PRINT 'Finished delete of ' + @waste_code + ' in all tables on ' + DB_NAME()
	PRINT '--------------------------------------------------------'
	
-- Log the operation's end
INSERT WasteCode2013_Changes (waste_code, waste_code_uid, action, description, phase, date_effective)
VALUES (@waste_code, @waste_code_uid, 'Delete Finished (debug)', 'Delete via sp_WasteCode2013_delete_waste_code finished ' + CASE WHEN @waste_code_uid is null then '(no waste_code_uid found in WasteCode)' else '(waste_code_uid = ' + convert(Varchar(20), @waste_code_uid) + ')' end, @phase, GETDATE())

commit transaction waste_code_delete
	

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_WasteCode2013_delete_waste_code] TO [EQAI]
    AS [dbo];

