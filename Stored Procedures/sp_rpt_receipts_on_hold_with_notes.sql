CREATE PROCEDURE sp_rpt_receipts_on_hold_with_notes 
	@company_id			int
,	@profit_ctr_id		int
,	@date_from			datetime
,	@date_to			datetime
AS
/***********************************************************************************
This SP returns receipts on Hold, with their notes (if any)

PB Object(s):	r_receipts_on_hold_with_notes

10/18/2010 SK	Created on Plt_AI
10/06/2011 JDB	Added:  AND Note.note_type <> 'AUDIT'
				(in order to exclude returning audit-type notes)
1/24/2024 Prakash DevOps #74738 Increased the length 100 to 200 for lab_comments column. 

sp_rpt_receipts_on_hold_with_notes 21, 0, '9/01/11', '10/31/11'

***********************************************************************************/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

-- Setup table
CREATE TABLE #receipts_on_hold (
	receipt_id			int				null
,	line_id				int				null
,	company_id			int				null
,	profit_ctr_id		int				null
,	receipt_date		datetime		null
,	approval_code		varchar(15)		null
,	generator_id		int				null
,	manifest			varchar(15)		null
,	hauler				varchar(20)		null
,	lab_comments		varchar(200)	null
,	truck_code			varchar(10)		null
,	generator_name		varchar(40)		null
,	transporter_name	varchar(40)		null
,	bill_unit_code		varchar(4)		null
,	quantity			float			null
,	note_id				int				null
,	note_date			datetime		null
,	note				text			null
,	added_by			varchar(10)		null
,	modified_by			varchar(10)		null
,	date_added			datetime		null
,	date_modified		datetime		null
,	record_type			char(1)			null
,	epa_id				varchar(12)		null 
,	company_name		varchar(35)		null
,	profit_ctr_name		varchar(50)		null
)

--Populate table
INSERT INTO #receipts_on_hold
SELECT 
	receipt.receipt_id
,	receipt.line_id
,	receipt.company_id
,	receipt.profit_ctr_id
,	receipt.receipt_date
,	receipt.approval_code
,	receipt.generator_id
,	receipt.manifest
,	receipt.hauler
,	receipt.lab_comments
,	receipt.truck_code
,	CASE WHEN Generator.generator_name = 'N/A' THEN '' ELSE Generator.generator_name END as generator_name
,	IsNull(Transporter_name, '') AS transporter_name
,	Receipt.bill_unit_code
,	Receipt.quantity
,	null
,	null
,	null
,	null
,	null
,	null
,	null
,	'T'
,	IsNull(Generator.epa_id, '') AS epa_id
,	Company.company_name
,	ProfitCenter.profit_ctr_name
FROM Receipt
JOIN Company
	ON Company.company_id = Receipt.company_id
JOIN ProfitCenter
	ON ProfitCenter.company_id = Receipt.company_id
	AND ProfitCenter.profit_ctr_id = Receipt.profit_ctr_id
LEFT OUTER JOIN Generator
	ON Generator.generator_id = Receipt.generator_id
LEFT OUTER JOIN Transporter
	ON Transporter.transporter_code = Receipt.hauler
WHERE	(@company_id = 0 OR Receipt.company_id = @company_id)	
	AND (@company_id = 0 OR @profit_ctr_id = -1 OR Receipt.profit_ctr_id = @profit_ctr_id)
	AND Receipt.trans_mode = 'I'
	AND Receipt.trans_type = 'D'
	AND Receipt.receipt_status = 'L'
	AND Receipt.fingerpr_status = 'H'
	AND Receipt.receipt_date between @date_from AND @date_to
	
INSERT INTO #receipts_on_hold
SELECT  
	Note.receipt_id
,	null
,	Note.company_id
,	Note.profit_ctr_id
,   null
,	null
,	null
,	null
,	null
,	null
,	null
,	null
,	null
,	null
,	null
,	Note.note_id
,	Note.note_date
,	Note.note
,	Note.added_by
,	Note.modified_by
,	Note.date_added
,	Note.date_modified
,	'N'
,	null
,	#receipts_on_hold.company_name
,	#receipts_on_hold.profit_ctr_name
FROM Note
JOIN #receipts_on_hold 
	ON #receipts_on_hold.receipt_id = Note.receipt_id
	AND #receipts_on_hold.company_id = Note.company_id
	AND #receipts_on_hold.profit_ctr_id = Note.profit_ctr_id
	AND #receipts_on_hold.line_id = (SELECT TOP 1 line_id FROM #receipts_on_hold r2 WHERE r2.receipt_id = Note.receipt_id)
WHERE Note.note_source = 'Receipt'
AND Note.note_type <> 'AUDIT'

SELECT  
	receipt_id
,	line_id
,	company_id
,	profit_ctr_id
,	receipt_date
,	approval_code
,	generator_id
,	manifest
,	hauler
,	lab_comments
,	truck_code
,	generator_name
,	transporter_name
,	bill_unit_code
,	quantity
,	note_id
,	note_date
,	note
,	added_by
,	modified_by
,	date_added
,	date_modified
,	record_type
,	epa_id
,	company_name
,	profit_ctr_name
FROM #receipts_on_hold
ORDER BY 
	company_id
,	profit_ctr_id
,	receipt_id 
,	record_type DESC
,	line_id
,	note_id

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_receipts_on_hold_with_notes] TO [EQAI]
    AS [dbo];

