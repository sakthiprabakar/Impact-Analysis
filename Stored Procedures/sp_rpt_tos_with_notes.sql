

CREATE PROCEDURE sp_rpt_tos_with_notes 
	@company_id		int
,	@profit_ctr_id	int
,	@date_from		datetime
,	@date_to		datetime
,	@cust_id_from	int
,	@cust_id_to		int
AS 
/******************************************************************
Time on Site with Notes Report 
(r_time_on_site_wnotes)

PB Object(s):	r_time_on_site_wnotes
				w_report_center

10/15/2010 SK	Added Company_ID as input argument
				Added Joins to company_id wherever necessary
				Moved to Plt_AI
02/22/2011 SK	Bad Join from Receipt to Receipt_Problem fixed. Added company_id				
05/08/2017 MPM	Modified to exclude In-Transit receipts.
07/08/2019	JPB	Cust_name: 40->75 / Generator_Name: 40->75

sp_rpt_tos_with_notes 02, 21, '2/22/2011', '2/22/2011', 1, 999999
*******************************************************************/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED


DECLARE 
	@approval_list			varchar(4000)
,	@receipt_company_id		int
,	@receipt_profit_ctr_id	int
,	@receipt_id				int
,	@curr_company_id		int
,	@curr_profit_ctr_id		int
,	@curr_receipt_id		int
,	@curr_approval			varchar(15)
,	@approval_code			varchar(15)
,	@more_lines				char(1)
,	@approval_cnt			int  

CREATE TABLE #receipts ( 
	record_type			char(1)			null
,	load_type			int				null
,	receipt_id			int				null
,	line_id				int				null
,	customer_id			int				null
,	company_id			int				null
,	profit_ctr_id		int				null
,	cust_name			varchar(75)		null
,	time_in				datetime		null
,	time_out			datetime		null
,	receipt_date		datetime		null
,	approval_code		varchar(15)		null
,	approval_list       varchar(4000)	null
,	manifest_comment	varchar(100)	null
,	date_scheduled		datetime		null
,	problem_id			int				null
,	problem_desc		varchar(40)		null
,	problem_cause		char(1)			null
,	bulk_flag			char(1)			null 
,	company_name		varchar(35)		null
,	profit_ctr_name		varchar(50)		null
)

-- first get the header and line records
INSERT #receipts
SELECT
	'H'
,	CASE WHEN receipt.bulk_flag = 'T' THEN 1 ELSE 2 END
,	Receipt.receipt_id
,	Receipt.line_id
,	Receipt.customer_id
,	Receipt.company_id
,	Receipt.profit_ctr_id
,	Customer.cust_name
,	Receipt.time_in
,	Receipt.time_out
,	Receipt.receipt_date
,	Receipt.approval_code
,	null
,	Receipt.manifest_comment
,	Receipt.date_scheduled
,	Receipt.problem_id
,	Receipt_problem.problem_desc
,	Receipt_problem.problem_cause
,	Receipt.bulk_flag
,	Company.company_name
,	ProfitCenter.profit_ctr_name
FROM Receipt
JOIN Company
	ON Company.company_id = Receipt.company_id
JOIN ProfitCenter
	ON ProfitCenter.profit_ctr_ID = Receipt.profit_ctr_id
	AND ProfitCenter.company_ID = Receipt.company_id
INNER JOIN Customer 
	ON Customer.customer_id = Receipt.customer_id
LEFT OUTER JOIN Receipt_problem 
	ON Receipt_problem.problem_id = Receipt.problem_id
	AND receipt_problem.company_id = Receipt.company_id
WHERE ( @company_id = 0 OR Receipt.company_id = @company_id )
  AND ( @company_id = 0 OR @profit_ctr_id = -1 OR Receipt.profit_ctr_id = @profit_ctr_id )
  AND Receipt.receipt_status NOT IN ('T', 'V')
  AND IsNull(receipt.problem_id,0) > 0 
  AND Receipt.receipt_date BETWEEN @date_from AND @date_to
  AND Receipt.trans_type = 'D'
  AND Receipt.customer_id BETWEEN @cust_id_from AND @cust_id_to
  AND Receipt.trans_mode = 'I'

-- set the line records
UPDATE #receipts
SET record_type = 'L',
    time_in = null,
    time_out = null,
    date_scheduled = null
WHERE line_id > 1

-- now loop and build approval string via cursor
-- declare cursor 
DECLARE grp CURSOR FOR SELECT
company_id,
profit_ctr_id,
receipt_id,
approval_code
FROM #receipts
ORDER BY company_id, profit_ctr_id, receipt_id, line_id

OPEN grp

FETCH grp INTO @receipt_company_id, @receipt_profit_ctr_id, @receipt_id, @approval_code 
SET @curr_approval = ''
SET @approval_list = ''
SET @more_lines = 'T'
SET @approval_cnt = 0
SELECT @curr_company_id = @receipt_company_id,
	   @curr_profit_ctr_id = @receipt_profit_ctr_id ,
	   @curr_receipt_id = @receipt_id


WHILE @@fetch_status = 0
BEGIN
     WHILE @@fetch_status = 0 and @more_lines = 'T'
     BEGIN
		 IF @curr_approval <> @approval_code
		 BEGIN 
			  IF @approval_cnt > 0 
				 BEGIN
					SELECT @approval_list = @approval_list + ', ' + @approval_code
					SELECT @approval_cnt = @approval_cnt + 1
					SELECT @curr_approval = @approval_code
				 END
			  ELSE
				  BEGIN
					SELECT @approval_list = @approval_code
					SELECT @approval_cnt = @approval_cnt + 1
					SELECT @curr_approval = @approval_code
				  END
		   END

		   FETCH grp INTO @receipt_company_id, @receipt_profit_ctr_id, @receipt_id,@approval_code
		   IF @curr_company_id <> @receipt_company_id or
			  @curr_profit_ctr_id <> @receipt_profit_ctr_id or
			  @curr_receipt_id <> @receipt_id
			  BEGIN
					SET @more_lines = 'F'
			  END
     END
  
     UPDATE #receipts
        SET approval_list = @approval_list
        WHERE company_id = @receipt_company_id
			and  profit_ctr_id = @receipt_profit_ctr_id
			and receipt_id = @receipt_id
			and record_type = 'H'

      SET @curr_approval = ''
      SET @approval_list = ''
      SET @more_lines = 'T'
      SET @approval_cnt = 0
      SELECT @curr_company_id = @receipt_company_id,
			  @curr_profit_ctr_id = @receipt_profit_ctr_id ,
			  @curr_receipt_id = @receipt_id
  
  END

CLOSE grp

DEALLOCATE grp

-- now remove everything but the header
DELETE FROM #receipts WHERE record_type = 'L'

-- now get the notes
SELECT 
	r.record_type
,	r.load_type
,	r.receipt_id
,	r.customer_id
,	r.company_id
,	r.profit_ctr_id
,	r.cust_name
,	r.time_in
,	r.time_out
,	r.receipt_date
,	r.approval_list
,	r.manifest_comment
,	r.date_scheduled
,	r.problem_id
,	r.problem_desc
,	r.problem_cause
,	r.bulk_flag
,	r.company_name
,	r.profit_ctr_name
,	n.note_id
,	n.note_date
,	n.subject
,	n.note
FROM #receipts r
LEFT OUTER JOIN Note n 
	ON n.receipt_id  = r.receipt_id
	AND n.company_id = r.company_id
	AND n.profit_ctr_id = r.profit_ctr_id
	AND n.note_source = 'Receipt'
	AND n.note_type = 'NOTE'
ORDER BY
r.load_type, r.receipt_id, r.record_type, n.note_date


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_tos_with_notes] TO [EQAI]
    AS [dbo];

