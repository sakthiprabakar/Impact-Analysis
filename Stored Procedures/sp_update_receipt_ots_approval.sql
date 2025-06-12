CREATE PROCEDURE sp_update_receipt_ots_approval
	@profile_id		int,
	@company_id		int,
	@profit_ctr_id	int,
	@receipt_id		int,
	@user_code		varchar(10)
AS
/**************************************************************************
Filename:	L:\Apps\SQL\Plt_AI\sp_update_receipt_ots_approval.sql
Load to plt_ai (NTSQL1)

05/20/2010 JDB	Created
05/25/2010 JDB	Fixed join between Receipt and ReceiptWasteCode/Constituent
				that would cause all lines to be deleted before re-inserting
				into ReceiptWasteCode/Constituent for the approval line.
03/29/2013 RWB Added waste_code_uid column to ReceiptWasteCode insert. Also qualified insert statement with column names.
04/03/2017 RWB At some point, a column was added to ReceiptConstituent, and the insert statement in this proc hadn't been updated

SELECT * FROM Sequence
sp_update_receipt_ots_approval 354660, 21, 0, 760929, 'JASON_B'
sp_update_receipt_ots_approval 354660, 21, 0, 760930, 'JASON_B'
**************************************************************************/
DECLARE	@return_msg						varchar(255),
		@count_container_complete		int,
		@count_container_waste_codes	int,
		@count_container_constituents	int,
		@next_note_id					int

SET @return_msg = ''
SET @count_container_complete = 0
SET @count_container_waste_codes = 0
SET @count_container_constituents = 0
SET NOCOUNT ON

------------------------------------------
-- Check for complete containers
------------------------------------------
SELECT @count_container_complete = COUNT(*)
FROM Container c
INNER JOIN Receipt r ON c.company_id = r.company_id
	AND c.profit_ctr_id = r.profit_ctr_id
	AND c.receipt_id = r.receipt_id
	AND c.line_id = r.line_id
WHERE c.company_id = @company_id
AND c.profit_ctr_id = @profit_ctr_id
AND c.receipt_id = @receipt_id
AND r.profile_id = @profile_id
AND r.trans_mode = 'I'
AND r.trans_type = 'D'
AND r.receipt_status IN ('T', 'N', 'L', 'U')
AND r.fingerpr_status NOT IN ('R', 'V')
AND c.status = 'C'

SELECT @count_container_complete = @count_container_complete + COUNT(*)
FROM ContainerDestination cd
INNER JOIN Receipt r ON cd.company_id = r.company_id
	AND cd.profit_ctr_id = r.profit_ctr_id
	AND cd.receipt_id = r.receipt_id
	AND cd.line_id = r.line_id
WHERE cd.company_id = @company_id
AND cd.profit_ctr_id = @profit_ctr_id
AND cd.receipt_id = @receipt_id
AND r.profile_id = @profile_id
AND r.trans_mode = 'I'
AND r.trans_type = 'D'
AND r.receipt_status IN ('T', 'N', 'L', 'U')
AND r.fingerpr_status NOT IN ('R', 'V')
AND cd.status = 'C'

IF @count_container_complete > 0
BEGIN
	SET @return_msg = 'Cannot update receipt ' + CONVERT(varchar(10), @receipt_id) + ' because it has completed containers.'
	GOTO ErrorEnd
END

--Check containers for waste codes or constituents
SELECT @count_container_waste_codes = COUNT(*)
FROM ContainerWasteCode cwc
INNER JOIN Receipt r ON cwc.company_id = r.company_id
	AND cwc.profit_ctr_id = r.profit_ctr_id
	AND cwc.receipt_id = r.receipt_id
	AND cwc.line_id = r.line_id
WHERE cwc.company_id = @company_id
AND cwc.profit_ctr_id = @profit_ctr_id
AND (cwc.receipt_id = @receipt_id 
	OR cwc.source_receipt_id = @receipt_id)
AND r.profile_id = @profile_id
AND r.trans_mode = 'I'
AND r.trans_type = 'D'
AND r.receipt_status IN ('T', 'N', 'L', 'U')
AND r.fingerpr_status NOT IN ('R', 'V')
AND cwc.container_type = 'R'

IF @count_container_waste_codes > 0
BEGIN
	SET @return_msg = 'Cannot update this receipt ' + CONVERT(varchar(10), @receipt_id) + ' because its containers have specific waste codes listed.'
	GOTO ErrorEnd
END


SELECT @count_container_constituents = COUNT(*)
FROM ContainerConstituent cc
INNER JOIN Receipt r ON cc.company_id = r.company_id
	AND cc.profit_ctr_id = r.profit_ctr_id
	AND cc.receipt_id = r.receipt_id
	AND cc.line_id = r.line_id
WHERE cc.company_id = @company_id
AND cc.profit_ctr_id = @profit_ctr_id
AND (cc.receipt_id = @receipt_id
	OR cc.source_receipt_id = @receipt_id)
AND r.profile_id = @profile_id
AND r.trans_mode = 'I'
AND r.trans_type = 'D'
AND r.receipt_status IN ('T', 'N', 'L', 'U')
AND r.fingerpr_status NOT IN ('R', 'V')
AND cc.container_type = 'R'

IF @count_container_constituents > 0
BEGIN
	SET @return_msg = 'Cannot update receipt ' + CONVERT(varchar(10), @receipt_id) + ' because its containers have specific constituents listed.'
	GOTO ErrorEnd
END


------------------------------------------------
-- Update Receipt Line(s)
------------------------------------------------
--PRINT 'Refreshing Receipt'
UPDATE Receipt SET treatment_id = pqa.treatment_id,
	approval_code = pqa.approval_code,
	manifest_erg_number = p.erg_number,
	manifest_dot_sp_number = p.manifest_dot_sp_number,
	manifest_hazmat = p.hazmat,
	manifest_un_na_flag = p.UN_NA_flag,
	manifest_un_na_number = p.un_na_number,  
	manifest_dot_shipping_name = p.dot_shipping_name,
	manifest_hazmat_class = p.hazmat_class,
	manifest_sub_hazmat_class = p.subsidiary_haz_mat_class,
	manifest_package_group = p.package_group,
	manifest_management_code = t.management_code,
	manifest_rq_flag = p.reportable_quantity_flag,
	manifest_rq_reason = p.RQ_reason,
	gl_account_code = t.gl_account_code,
	billing_project_id = pqa.billing_project_id,
	po_sequence_id = pqa.po_sequence_id,
	purchase_order = pqa.purchase_order,
	release = pqa.release,
	waste_code = CASE r.receipt_status
		WHEN 'T' THEN r.waste_code
		ELSE p.waste_code
		END,
	bulk_flag = CASE r.receipt_status
		WHEN 'T' THEN r.bulk_flag
		ELSE pqd.bulk_flag
		END,
	CCVOC = pl.CCVOC,
	DDVOC = pl.DDVOC,
	location = pqa.location,
	location_type = pqa.location_type,
	OB_profile_company_id = pqa.OB_EQ_company_id,
	OB_profile_profit_ctr_id = pqa.OB_EQ_profit_ctr_id,
	OB_profile_id = pqa.OB_EQ_profile_id,
	TSDF_approval_id = pqa.OB_TSDF_approval_id,
	TSDF_approval_code = COALESCE(pqa2.approval_code, ta.TSDF_approval_code),
	waste_stream = ta.waste_stream
FROM Receipt r
INNER JOIN ProfileQuoteApproval pqa ON r.company_id = pqa.company_id
	AND r.profit_ctr_id = pqa.profit_ctr_id
	AND r.profile_id = pqa.profile_id
INNER JOIN ProfileQuoteDetail pqd ON pqa.company_id = pqd.company_id
	AND pqa.profit_ctr_id = pqd.profit_ctr_id
	AND pqa.profile_id = pqd.profile_id
	AND r.bill_unit_code = pqd.bill_unit_code
INNER JOIN Profile p ON p.profile_id = pqa.profile_id
INNER JOIN ProfileLab pl ON p.profile_id = pl.profile_id
INNER JOIN ProfileQuoteHeader pqh ON p.profile_id = pqh.profile_id
LEFT OUTER JOIN Treatment t ON pqa.treatment_id = t.treatment_id
	AND pqa.company_id = t.company_id
	AND pqa.profit_ctr_id = t.profit_ctr_id
LEFT OUTER JOIN ProfileQuoteApproval pqa2 ON pqa.OB_EQ_company_id = pqa2.company_id
	AND pqa.OB_EQ_profit_ctr_id = pqa2.profit_ctr_id
	AND pqa.OB_EQ_profile_id = pqa2.profile_id
LEFT OUTER JOIN TSDFApproval ta ON pqa.OB_TSDF_approval_id = ta.TSDF_approval_id
WHERE r.company_id = @company_id
AND r.profit_ctr_id = @profit_ctr_id
AND r.receipt_id = @receipt_id
AND r.profile_id = @profile_id
AND r.trans_mode = 'I'
AND r.trans_type = 'D'
AND r.receipt_status IN ('T', 'N', 'L', 'U')
AND r.fingerpr_status NOT IN ('R', 'V')
AND p.curr_status_code = 'A'
AND pl.type = 'A'
AND pqa.status = 'A'
AND pqd.status = 'A'

SELECT @return_msg = @return_msg + 'Receipt ' + CONVERT(varchar(10), @receipt_id) + ' (' + CONVERT(varchar(2), @company_id) + '-' + CONVERT(varchar(2), @profit_ctr_id) + ') -- ' + CONVERT(varchar(6), @@ROWCOUNT) + ' Receipt line(s) updated.  '
--PRINT @return_msg


------------------------------------------------
-- Receipt Waste Codes
------------------------------------------------
--PRINT 'Refreshing Receipt Waste Codes'
DELETE ReceiptWasteCode
FROM ReceiptWasteCode rwc
INNER JOIN Receipt r ON r.company_id = rwc.company_id
	AND r.profit_ctr_id = rwc.profit_ctr_id
	AND r.receipt_id = rwc.receipt_id
	AND r.line_id = rwc.line_id
INNER JOIN ProfileQuoteApproval pqa ON r.company_id = pqa.company_id
	AND r.profit_ctr_id = pqa.profit_ctr_id
	AND r.profile_id = pqa.profile_id
INNER JOIN Profile p ON p.profile_id = pqa.profile_id
WHERE 1=1
AND r.company_id = @company_id
AND r.profit_ctr_id = @profit_ctr_id
AND r.receipt_id = @receipt_id
AND r.profile_id = @profile_id
AND r.trans_mode = 'I'
AND r.trans_type = 'D'
AND r.receipt_status IN ('T', 'N', 'L', 'U')
AND r.fingerpr_status NOT IN ('R', 'V')
AND p.curr_status_code = 'A'
AND pqa.status = 'A'

SELECT @return_msg = @return_msg + 'Deleted ' + CONVERT(varchar, @@ROWCOUNT) + ' Waste Codes, '

INSERT INTO ReceiptWasteCode (company_id, profit_ctr_id, receipt_id, line_id, primary_flag, waste_code, created_by, date_added, sequence_id, waste_code_uid)
SELECT @company_id,
	@profit_ctr_id,
	@receipt_id,
	line_id,
	pwc.primary_flag,
	pwc.waste_code,
	@user_code,
	GETDATE(),
	pwc.sequence_id,
	pwc.waste_code_uid
FROM Receipt r
INNER JOIN ProfileWasteCode pwc ON r.profile_id = pwc.profile_id
INNER JOIN ProfileQuoteApproval pqa ON r.company_id = pqa.company_id
	AND r.profit_ctr_id = pqa.profit_ctr_id
	AND r.profile_id = pqa.profile_id
INNER JOIN Profile p ON p.profile_id = pqa.profile_id
WHERE 1=1
AND r.company_id = @company_id
AND r.profit_ctr_id = @profit_ctr_id
AND r.receipt_id = @receipt_id
AND r.profile_id = @profile_id
AND r.trans_mode = 'I'
AND r.trans_type = 'D'
AND r.receipt_status IN ('T', 'N', 'L', 'U')
AND r.fingerpr_status NOT IN ('R', 'V')
AND p.curr_status_code = 'A'
AND pqa.status = 'A'

SELECT @return_msg = @return_msg + 'inserted ' + CONVERT(varchar, @@ROWCOUNT) + '.  '



------------------------------------------------
-- Receipt Constituents
------------------------------------------------
--PRINT 'Deleting Receipt Constituents'

DELETE ReceiptConstituent
FROM ReceiptConstituent rc
INNER JOIN Receipt r ON r.company_id = rc.company_id
	AND r.profit_ctr_id = rc.profit_ctr_id
	AND r.receipt_id = rc.receipt_id
	AND r.line_id = rc.line_id
INNER JOIN ProfileQuoteApproval pqa ON r.company_id = pqa.company_id
	AND r.profit_ctr_id = pqa.profit_ctr_id
	AND r.profile_id = pqa.profile_id
INNER JOIN Profile p ON p.profile_id = pqa.profile_id
WHERE 1=1
AND r.company_id = @company_id
AND r.profit_ctr_id = @profit_ctr_id
AND r.receipt_id = @receipt_id
AND r.profile_id = @profile_id
AND r.trans_mode = 'I'
AND r.trans_type = 'D'
AND r.receipt_status IN ('T', 'N', 'L', 'U')
AND r.fingerpr_status NOT IN ('R', 'V')
AND p.curr_status_code = 'A'
AND pqa.status = 'A'

SELECT @return_msg = @return_msg + 'Deleted ' + CONVERT(varchar, @@ROWCOUNT) + ' Constituents, '

--PRINT 'Inserting Receipt Constituents'

INSERT INTO ReceiptConstituent
SELECT @company_id,
	@profit_ctr_id,
	@receipt_id,
	line_id,
	pc.const_id,
	pc.UHC,
	pc.min_concentration,
	pc.concentration,
	pc.unit,
	@user_code,
	@user_code,
	GETDATE(),
	GETDATE()
FROM Receipt r
INNER JOIN ProfileConstituent pc ON r.profile_id = pc.profile_id
INNER JOIN ProfileQuoteApproval pqa ON r.company_id = pqa.company_id
	AND r.profit_ctr_id = pqa.profit_ctr_id
	AND r.profile_id = pqa.profile_id
INNER JOIN Profile p ON p.profile_id = pqa.profile_id
WHERE 1=1
AND r.company_id = @company_id
AND r.profit_ctr_id = @profit_ctr_id
AND r.receipt_id = @receipt_id
AND r.profile_id = @profile_id
AND r.trans_mode = 'I'
AND r.trans_type = 'D'
AND r.receipt_status IN ('T', 'N', 'L', 'U')
AND r.fingerpr_status NOT IN ('R', 'V')
AND p.curr_status_code = 'A'
AND pqa.status = 'A'

SELECT @return_msg = @return_msg + 'inserted ' + CONVERT(varchar, @@ROWCOUNT) + '.  '




------------------------------------------------
-- Update Container(s)
------------------------------------------------
--PRINT 'Updating Container(s)'

UPDATE ContainerDestination SET treatment_id = pqa.treatment_id,
	location = pqa.location,
	location_type = pqa.location_type,
	OB_profile_company_id = pqa.OB_EQ_company_id,
	OB_profile_profit_ctr_id = pqa.OB_EQ_profit_ctr_id,
	OB_profile_id = pqa.OB_EQ_profile_id,
	TSDF_approval_id = pqa.OB_TSDF_approval_id,
	TSDF_approval_code = COALESCE(pqa2.approval_code, ta.TSDF_approval_code),
	waste_stream = ta.waste_stream
FROM Receipt r
INNER JOIN ContainerDestination cd ON cd.company_id = r.company_id
	AND cd.profit_ctr_id = r.profit_ctr_id
	AND cd.receipt_id = r.receipt_id
	AND cd.line_id = r.line_id
INNER JOIN ProfileQuoteApproval pqa ON r.company_id = pqa.company_id
	AND r.profit_ctr_id = pqa.profit_ctr_id
	AND r.profile_id = pqa.profile_id
INNER JOIN Profile p ON p.profile_id = pqa.profile_id
LEFT OUTER JOIN ProfileQuoteApproval pqa2 ON pqa.OB_EQ_company_id = pqa2.company_id
	AND pqa.OB_EQ_profit_ctr_id = pqa2.profit_ctr_id
	AND pqa.OB_EQ_profile_id = pqa2.profile_id
LEFT OUTER JOIN TSDFApproval ta ON pqa.OB_TSDF_approval_id = ta.TSDF_approval_id
WHERE r.company_id = @company_id
AND r.profit_ctr_id = @profit_ctr_id
AND r.receipt_id = @receipt_id
AND r.profile_id = @profile_id
AND r.trans_mode = 'I'
AND r.trans_type = 'D'
AND r.receipt_status IN ('T', 'N', 'L', 'U')
AND r.fingerpr_status NOT IN ('R', 'V')
AND p.curr_status_code = 'A'
AND pqa.status = 'A'

SELECT @return_msg = @return_msg + CONVERT(varchar(6), @@ROWCOUNT) + ' Container line(s) updated.  '



------------------------------------------------
-- Receipt Audit
------------------------------------------------
INSERT INTO ReceiptAudit
SELECT @company_id,
	@profit_ctr_id,
	@receipt_id,
	r.line_id,
	0,
	'Receipt',
	'approval_code',
	r.approval_code,
	pqa.approval_code,
	'OTS Approval Update - Refreshed from Approval ' + pqa.approval_code + ' (Profile ID ' + CONVERT(varchar(8), pqa.profile_id) + ')',
	@user_code,
	'OTS',
	GETDATE()
FROM Receipt r
INNER JOIN ProfileQuoteApproval pqa ON r.company_id = pqa.company_id
	AND r.profit_ctr_id = pqa.profit_ctr_id
	AND r.profile_id = pqa.profile_id
INNER JOIN Profile p ON p.profile_id = pqa.profile_id
WHERE r.company_id = @company_id
AND r.profit_ctr_id = @profit_ctr_id
AND r.receipt_id = @receipt_id
AND r.profile_id = @profile_id
AND r.trans_mode = 'I'
AND r.trans_type = 'D'
AND r.receipt_status IN ('T', 'N', 'L', 'U')
AND r.fingerpr_status NOT IN ('R', 'V')
AND p.curr_status_code = 'A'
AND pqa.status = 'A'


------------------------------------------------
-- Profile Note
------------------------------------------------
--SELECT * FROM Note WHERE note_source = 'profile' AND note_type = 'NOTE' ORDER BY date_added desc
--SELECT * FROM Sequence WHERE name = 'Note.note_id'
--DROP TABLE #tmp
--CREATE TABLE #tmp (
--	next_note_id	int	)

--INSERT #tmp EXEC ('sp_sequence_next ''Note.note_id'', 0')
--SELECT * FROM #tmp

--EXEC @next_note_id = sp_sequence_silent_next 'Note.note_id'


--EXEC @next_note_id = sp_sequence_next 'Note.note_id', 0

--INSERT INTO Note
--SELECT @next_note_id, 
--	'Profile', 
--	@company_id, 
--	@profit_ctr_id, 
--	GETDATE(), 
--	'OTS Approval Update',
--	'C',
--	'NOTE',
--	@return_msg,
--	p.customer_id,
--	NULL,
--	p.generator_id,
--	pqa.approval_code,
--	p.profile_id,
--	NULL,
--	NULL,
--	NULL,
--	NULL,
--	NULL,
--	NULL,
--	NULL,
--	NULL,
--	'Note',
--	@user_code,
--	GETDATE(),
--	@user_code,
--	GETDATE(),
--	'EQAI',
--	NEWID()
--FROM Profile p
--INNER JOIN ProfileQuoteApproval pqa ON p.profile_id = pqa.profile_id
--WHERE p.profile_id = @profile_id
--AND pqa.company_id = @company_id
--AND pqa.profit_ctr_id = @profit_ctr_id
	

ErrorEnd:
SELECT @return_msg AS return_msg FROM Company WHERE company_id = @company_id

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_update_receipt_ots_approval] TO [EQAI]
    AS [dbo];

