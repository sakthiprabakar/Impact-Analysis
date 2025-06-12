CREATE OR ALTER PROCEDURE [dbo].[sp_rpt_waste_received] 
	@permission_id INT,
	@user_id INT = NULL,
	@user_code VARCHAR(20) = NULL,
	@copc_list VARCHAR(MAX),
	@start_date DATETIME,
	@end_date DATETIME,
	@treatment_id VARCHAR(100) = NULL,
	@disposal_service_id VARCHAR(200) = NULL,
	@treatment_process_id VARCHAR(200) = NULL,
	@waste_type_id VARCHAR(200) = NULL,
	@return_first_time_approval_receipts_only CHAR(1) = NULL
/*
exec sp_rpt_waste_received 86, 1206, 'RICH_G', '32|0', '1/01/2017','12/31/2017'
	
2018-01-05 JPB	GEM-47533 - Add receipt weight to output
2023-16-06 Nagaraj M --65744 -- Modified the copc_list to varchar(max)

03/19/2024 KS DevOps 76922 - Performance updated switch from tables variables to # temp tables.
	
*/
AS
IF object_id('tempdb..#tmp_results') IS NOT NULL
DROP TABLE IF EXISTS #tmp_results
CREATE TABLE #tmp_results (
	receipt_date DATETIME NULL,
	company_id INT NOT NULL,
	profit_ctr_id INT NOT NULL,
	receipt_id INT NULL,
	line_id INT NULL,
	profile_id INT NULL,
	approval_code VARCHAR(15) NULL,
	approval_desc VARCHAR(50) NULL,
	generator_name VARCHAR(75) NULL,
	first_profile_received_receipt_id INT NOT NULL,
	is_first_receipt_for_profile VARCHAR(20) NULL,
	profile_waste_codes VARCHAR(8000) NULL, --sixe?
	customer_id INT NOT NULL,
	cust_name VARCHAR(75) NULL,
	treatment_id INT NOT NULL,
	treatment_desc VARCHAR(30) NULL,
	disposal_service_desc VARCHAR(20) NULL,
	treatment_process VARCHAR(30) NULL,
	[description] VARCHAR(60) NULL,
	pounds DECIMAL(18, 4) NULL
	)


DROP TABLE IF EXISTS #tmp_first_receipts
CREATE TABLE #tmp_first_receipts (
	min_receipt_id INT NULL,
	profile_id INT NULL,
	company_id INT NOT NULL,
	profit_ctr_id INT NOT NULL,
	receipt_date DATETIME
)


IF @return_first_time_approval_receipts_only = ''
	SET @return_first_time_approval_receipts_only = NULL

IF @treatment_id = ''
	SET @treatment_id = NULL

IF @disposal_service_id = ''
	SET @disposal_service_id = NULL

IF @treatment_process_id = ''
	SET @treatment_process_id = NULL

IF @waste_type_id = ''
	SET @waste_type_id = NULL
SET @start_date = CONVERT(VARCHAR(20), @start_date, 101) + ' 00:00:00'
SET @end_date = CONVERT(VARCHAR(20), @end_date, 101) + ' 23:59:59'

IF @user_code = ''
	SET @user_code = NULL

IF @user_id IS NULL
	SELECT @user_id = USER_ID
	FROM dbo.users
	WHERE user_code = @user_code

IF @user_code IS NULL
	SELECT @user_code = user_code
	FROM dbo.users
	WHERE user_id = @user_id

DROP TABLE IF EXISTS #tbl_profit_center_filter
CREATE TABLE #tbl_profit_center_filter (
	[company_id] INT NULL,
	[profit_ctr_id] INT NULL
	)
	
DROP TABLE IF EXISTS #tbl_treatment
CREATE TABLE #tbl_treatment (treatment_id INT NULL)

--INSERT INTO @tbl_treatment
INSERT INTO #tbl_treatment
(
treatment_id
)
SELECT row
FROM dbo.fn_SplitXsvText(',', 0, @treatment_id)
WHERE isnull(row, '') <> ''

UNION

SELECT treatment_id
FROM dbo.treatmentheader AS th
WHERE 1 = CASE 
		WHEN @treatment_id IS NULL
			THEN 1
		ELSE 0
		END

DROP TABLE IF EXISTS #tbl_disposal_service
CREATE TABLE #tbl_disposal_service (disposal_service_id INT NULL)


INSERT INTO #tbl_disposal_service
(
disposal_service_id
)
SELECT row
FROM dbo.fn_SplitXsvText(',', 0, @disposal_service_id)
WHERE isnull(row, '') <> ''

UNION

SELECT disposal_service_id
FROM dbo.DisposalService
WHERE 1 = CASE 
		WHEN @disposal_service_id IS NULL
			THEN 1
		ELSE 0
		END

DROP TABLE IF EXISTS #tbl_treatment_process
CREATE TABLE #tbl_treatment_process (treatment_process_id INT NULL)

--INSERT INTO @tbl_treatment_process
INSERT INTO #tbl_treatment_process
(
treatment_process_id
)
SELECT row
FROM dbo.fn_SplitXsvText(',', 0, @treatment_process_id)
WHERE isnull(row, '') <> ''

UNION

SELECT treatment_process_id
FROM dbo.TreatmentProcess
WHERE 1 = CASE 
		WHEN @treatment_process_id IS NULL
			THEN 1
		ELSE 0
		END

DECLARE @tbl_waste_type TABLE (wastetype_id INT)

INSERT INTO @tbl_waste_type
SELECT row
FROM dbo.fn_SplitXsvText(',', 0, @waste_type_id)
WHERE isnull(row, '') <> ''

UNION

SELECT wastetype_id
FROM dbo.WasteType
WHERE 1 = CASE 
		WHEN @waste_type_id IS NULL
			THEN 1
		ELSE 0
		END

--SELECT * FROM @tbl_treatment
--SELECT * FROM @tbl_disposal_service
--SELECT * FROM @tbl_treatment_process
--SELECT * FROM @tbl_waste_type
																										
INSERT INTO #tbl_profit_center_filter
(	
	[company_id],
	[profit_ctr_id]
)
SELECT secured_copc.company_id,
	secured_copc.profit_ctr_id
FROM dbo.SecuredProfitCenter AS secured_copc
INNER JOIN (
	SELECT RTRIM(LTRIM(SUBSTRING(row, 1, CHARINDEX('|', row) - 1))) company_id,
		RTRIM(LTRIM(SUBSTRING(row, CHARINDEX('|', row) + 1, LEN(row) - (CHARINDEX('|', row) - 1)))) AS profit_ctr_id
	FROM dbo.fn_SplitXsvText(',', 0, @copc_list)
	WHERE isnull(row, '') <> ''
	) AS selected_copc
	ON secured_copc.company_id = selected_copc.company_id 
	AND secured_copc.profit_ctr_id = selected_copc.profit_ctr_id 
	AND secured_copc.permission_id = @permission_id 
	AND secured_copc.user_code = @user_code

--fn_approval_sec_waste_code_list (@profile_id, @type)
--where @profile_id is either the Profile.profile_id or TSDFApproval.tsdf_approval_id  you want
--and @type is 'P' for profile or 'T' for tsdfapproval
--It only retrieves secondary waste codes... so you need to do something like this:
--select isnull(p.waste_code, '') + dbo.fn_approval_sec_waste_code_list(p.profile_id, 'P') as profile_waste_codes
--from profile
-- treatment, waste type,process, disposition


INSERT INTO #tmp_results (
	receipt_date,
	company_id,
	profit_ctr_id,
	receipt_id,
	line_id,
	profile_id,
	approval_code,
	approval_desc,
	generator_name,
	first_profile_received_receipt_id,
	is_first_receipt_for_profile,
	profile_waste_codes,
	customer_id,
	cust_name,
	treatment_id,
	treatment_desc,
	disposal_service_desc,
	treatment_process,
	[description],
	pounds
	)
SELECT r.receipt_date,
	r.company_id,
	r.profit_ctr_id,
	r.receipt_id,
	r.line_id,
	r.profile_id,
	r.approval_code,
	p.approval_desc,
	g.generator_name,
	0 AS first_profile_received_receipt_id, -- filled in later
	CAST(NULL AS VARCHAR(20)) AS is_first_receipt_for_profile, -- filled in later
	isnull(p.waste_code, '') + dbo.fn_approval_sec_waste_code_list(p.profile_id, 'P') AS profile_waste_codes,
	c.customer_id,
	c.cust_name,
	th.treatment_id,
	IsNull(wt.code, ' ') + '-' + IsNull(tp.Code, ' ') + '-' + IsNull(ds.code, ' ') AS treatment_desc,
	ds.disposal_service_desc,
	tp.treatment_process,
	wt.description,
	convert(DECIMAL(18, 4), 0) AS pounds
FROM dbo.Receipt AS r
INNER JOIN #tbl_profit_center_filter AS secured_copc
	ON r.company_id = secured_copc.company_id 
	AND r.profit_ctr_id = secured_copc.profit_ctr_id 
	AND r.receipt_date BETWEEN @start_date AND @end_date
INNER JOIN dbo.[Profile] AS p WITH (NOLOCK)
	ON p.profile_id = r.profile_id
INNER JOIN dbo.Customer AS c WITH (NOLOCK)
	ON c.customer_id = r.customer_id
INNER JOIN dbo.treatmentheader AS th WITH (NOLOCK)
	ON th.treatment_id = r.treatment_id
INNER HASH JOIN dbo.treatmentdetail AS td WITH (NOLOCK) --TODO: 1:20 down to ~37 with HASH hint ~38 MERGE hint
	ON td.treatment_id = r.treatment_id 
	AND td.company_id = r.company_id 
	AND td.profit_ctr_id = r.profit_ctr_id
INNER JOIN dbo.DisposalService AS ds WITH (NOLOCK)
	ON th.disposal_service_id = ds.disposal_service_id
INNER JOIN dbo.TreatmentProcess AS tp WITH (NOLOCK)
	ON th.treatment_process_id = tp.treatment_process_id
INNER JOIN dbo.WasteType AS wt WITH (NOLOCK)
	ON th.wastetype_id = wt.wastetype_id
INNER JOIN #tbl_disposal_service AS tbl_ds
	ON ds.disposal_service_id = tbl_ds.disposal_service_id
INNER JOIN #tbl_treatment AS tbl_t
	ON tbl_t.treatment_id = th.treatment_id
INNER JOIN #tbl_treatment_process AS tbl_tp
	ON tbl_tp.treatment_process_id = tp.treatment_process_id
INNER JOIN @tbl_waste_type AS tbl_wt
	ON tbl_wt.wastetype_id = wt.wastetype_id
LEFT JOIN dbo.Generator AS g WITH (NOLOCK)
	ON r.generator_id = g.generator_id


UPDATE #tmp_results
SET pounds = dbo.fn_receipt_weight_line(receipt_id, line_id, profit_ctr_id, company_id)


INSERT INTO #tmp_first_receipts (
	min_receipt_id,
	profile_id,
	company_id,
	profit_ctr_id,
	receipt_date
)
SELECT 
	MIN(r.receipt_id) AS min_receipt_id,
	r.profile_id,
	r.company_id,
	r.profit_ctr_id,
	r.receipt_date
--INTO #tmp_first_receipts
FROM dbo.Receipt AS r
INNER JOIN #tmp_results AS tmp
	ON r.profile_id = tmp.profile_id 
	AND r.company_id = tmp.company_id 
	AND r.profit_ctr_id = tmp.profit_ctr_id 
	AND r.receipt_status <> 'V' 
	AND r.fingerpr_status <> 'V'
GROUP BY r.company_id,
	r.profit_ctr_id,
	r.receipt_date,
	r.profile_id

CREATE NONCLUSTERED INDEX [__TMP_idx_profile_copc] ON #tmp_first_receipts (
	[profile_id] ASC,
	[company_id] ASC,
	[profit_ctr_id] ASC
	)

CREATE NONCLUSTERED INDEX [__TMP_idx_profile_copc2] ON #tmp_results (
	[profile_id] ASC,
	[company_id] ASC,
	[profit_ctr_id] ASC
	)

UPDATE #tmp_results
SET first_profile_received_receipt_id = tmp.min_receipt_id
FROM #tmp_first_receipts AS tmp
WHERE 
	#tmp_results.profile_id = tmp.profile_id 
	AND #tmp_results.company_id = tmp.company_id 
	AND #tmp_results.profit_ctr_id = tmp.profit_ctr_id

UPDATE #tmp_results
SET is_first_receipt_for_profile = CASE 
		WHEN first_profile_received_receipt_id = receipt_id
			THEN 'T'
		ELSE 'F'
		END

DROP TABLE IF EXISTS #tmp_first_receipts

SELECT 
	receipt_date,
	company_id,
	profit_ctr_id,
	receipt_id,
	-- line_id,
	profile_id,
	approval_code,
	approval_desc,
	generator_name,
	first_profile_received_receipt_id, -- filled in later
	is_first_receipt_for_profile, -- filled in later
	profile_waste_codes,
	customer_id,
	cust_name,
	treatment_id,
	treatment_desc,
	disposal_service_desc,
	treatment_process,
	[description],
	SUM(pounds) AS pounds
FROM #tmp_results AS data
WHERE 1 = CASE 
		WHEN @return_first_time_approval_receipts_only IS NULL OR @return_first_time_approval_receipts_only = 'F'
			THEN 1
		WHEN @return_first_time_approval_receipts_only = 'T' AND is_first_receipt_for_profile = 'T'
			THEN 1
		ELSE 0
		END
GROUP BY 
	receipt_date,
	company_id,
	profit_ctr_id,
	receipt_id,
	-- line_id,
	profile_id,
	approval_code,
	approval_desc,
	generator_name,
	first_profile_received_receipt_id, -- filled in later
	is_first_receipt_for_profile, -- filled in later
	profile_waste_codes,
	customer_id,
	cust_name,
	treatment_id,
	treatment_desc,
	disposal_service_desc,
	treatment_process,
	[description]
ORDER BY receipt_date

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_waste_received] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_waste_received] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_waste_received] TO [EQAI]
    AS [dbo];

