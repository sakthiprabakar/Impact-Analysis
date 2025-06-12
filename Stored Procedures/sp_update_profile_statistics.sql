CREATE PROCEDURE sp_update_profile_statistics   
 @debug  int = 0  
AS   
/***************************************************************************************************  
LOAD TO PLT_AI  
  
Filename: L:\Apps\SQL\EQAI\PLT_AI\sp_update_profile_statistics.sql  
PB Object(s): d_profile_statistics  
  
08/14/2006 RG Created  
05/29/2012 JPB Revamped. Not in use previously, now ready to go nightly. (never deployed)  
08/21/2012 JDB Modified so that it only writes Statistics records if the profile has actually been  
    used. 
07/16/2024 Dipankar DevOps: 88330 - Modified to include statistics for Profile Fee Receipts
07/22/2024 Dipankar DevOps: 88330 - Modify the SQL Query for pushing Profile Fee Receipts to temp table
07/31/2024 Dipankar DevOps: 88330 - Modified to include Statuses A & S for Profile Fee Receipts
08/08/2024 Dipankar DevOps: 94209 - Corrected line_id join condition for Profile Fee Receipt
01/06/2025 KS Rally US127371: Modified index names for the temp tables and created temp tables vbeing used.
  
sp_update_profile_statistics 1  
-- This takes a long time.... 10 minutes or so.  
  
sp_update_profile_statistics '5/25/2012', '5/30/2012'  
-- This is considerably faster.  
  
select top 100 * from ProfileStatistics where value is not null order by date_modified desc  
  
select profile_id, company_id, profit_ctr_id, statistic, count(*) from ProfileStatistics  
group by profile_id, company_id, profit_ctr_id, statistic having count(*) > 1  
  
***************************************************************************************************/  
/*  
-- debugging...  
DECLARE  
@start_date datetime = getdate()-30,  
@end_date datetime = '1/1/9999',  
@debug  int = 1  
-- both null : 7:16  
-- -30d - +1d : :20  
  
*/ 

BEGIN
	DECLARE @max_start_date datetime = '1/1/9999 23:59:59',  
			@min_start_date datetime = '1/1/1800 00:00:00',  
			@gen_count int,  
			@company_id int,  
			@profit_ctr_id int,  
			@profile_id int,  
			@execute_sql varchar(MAX)  
  
	-- Collect the stats first.  The optional date ranges might make this easy/fast.  
	-- No sense wiping out ALL of ProfileStatistics without checking first.  
  
	DROP TABLE IF EXISTS #Stat_R;
	CREATE TABLE #Stat_R (
		profile_id INT NULL
		, profile_company_id INT NULL
		, profile_profit_ctr_id INT NULL
		, receipt_company_id INT NULL
		, receipt_profit_ctr_id INT NULL
		, trans_mode CHAR(1) NULL
		, cnt INT NULL
		, mind DATETIME NULL
		, maxd DATETIME NULL
		)

	DROP TABLE IF EXISTS #Stat_W;
	CREATE TABLE #stat_w (
		profile_id INT NULL
		, profile_company_id INT NULL
		, profile_profit_ctr_id INT NULL
		, wo_company_id INT NULL
		, wo_profit_ctr_id INT NULL
		, cnt INT NULL
		, mind DATETIME NULL
		, maxd DATETIME NULL
		)

	DROP TABLE IF EXISTS #tmp_receipt_profile_fee;
	CREATE TABLE #tmp_receipt_profile_fee (
		receipt_profile_fee_uid INT NULL
		, profile_id INT NULL
		, company_id INT NULL
		, profit_ctr_id INT NULL
		, receipt_ref VARCHAR(25) NULL
		, profile_fee_code_desc VARCHAR(50) NULL
		)
			  
	-- Get Statistics
	INSERT INTO #Stat_R
		( profile_id
		, profile_company_id
		, profile_profit_ctr_id
		, receipt_company_id
		, receipt_profit_ctr_id
		, trans_mode
		, cnt
		, mind
		, maxd )
	SELECT  
		profile_id,  
		company_id AS profile_company_id,  
		profit_ctr_id AS profile_profit_ctr_id,  
		company_id AS receipt_company_id,  
		profit_ctr_id AS receipt_profit_ctr_id,  
		trans_mode,  
		COUNT(r.receipt_id) AS cnt,  
		MIN(r.receipt_date) AS mind,  
		MAX(r.receipt_date) AS maxd  
	FROM receipt r (nolock)  
	WHERE r.receipt_status = 'A'  
	AND r.trans_mode IN ('I')  
	AND r.profile_id IS NOT NULL 
	AND NOT EXISTS (SELECT 1 
					FROM ReceiptProfileFee
					WHERE receipt_id = r.receipt_id
					AND line_id = r.line_id
					AND company_id = r.company_id
					AND profit_ctr_id = r.profit_ctr_id)
	--AND profile_id = 343472  
	GROUP BY profile_id,  
	company_id,  
	profit_ctr_id,  
	trans_mode  
    
	INSERT INTO #Stat_R
		( profile_id
		, profile_company_id
		, profile_profit_ctr_id
		, receipt_company_id
		, receipt_profit_ctr_id
		, trans_mode
		, cnt
		, mind
		, maxd ) 
	SELECT  
		OB_profile_id AS profile_id,  
		OB_profile_company_ID AS profile_company_id,  
		OB_profile_profit_ctr_id AS profile_profit_ctr_id,  
		company_id AS receipt_company_id,  
		profit_ctr_id AS receipt_profit_ctr_id,  
		trans_mode,  
		COUNT(r.receipt_id) AS cnt,  
		MIN(r.receipt_date) AS mind,  
		MAX(r.receipt_date) AS maxd  
	FROM receipt r (nolock)  
	WHERE r.receipt_status = 'A'  
	AND r.trans_mode IN ('O')  
	AND r.OB_profile_id IS NOT NULL  
	--AND OB_profile_ID = 343472  
	GROUP BY OB_profile_id,  
			OB_profile_company_ID,  
			OB_profile_profit_ctr_id,  
			company_id,  
			profit_ctr_id,  
			trans_mode  

	INSERT INTO #Stat_R
		( profile_id
		, profile_company_id
		, profile_profit_ctr_id
		, receipt_company_id
		, receipt_profit_ctr_id
		, trans_mode
		, cnt
		, mind
		, maxd )
	SELECT  
		p.profile_id,  
		r.company_id AS profile_company_id,  
		r.profit_ctr_id AS profile_profit_ctr_id,  
		r.company_id AS receipt_company_id,  
		r.profit_ctr_id AS receipt_profit_ctr_id,  
		'P', -- Profile Fee  
		COUNT(r.receipt_id) AS cnt,  
		MIN(r.receipt_date) AS mind,  
		MAX(r.receipt_date) AS maxd
	FROM Receipt r (NOLOCK)  
	JOIN ReceiptProfileFee rpf (NOLOCK) 
		ON r.company_id = rpf.company_id
		AND r.profit_ctr_id = rpf.profit_ctr_id
		AND r.receipt_id = rpf.receipt_id
		AND r.line_id = rpf.line_id
	JOIN ProfileFeeCode pfc (NOLOCK) ON pfc.profile_fee_code_uid = rpf.profile_fee_code_uid
	JOIN Profile p (NOLOCK) ON p.profile_id = rpf.profile_id
	WHERE 1=1  
	AND r.receipt_status IN ('A', 'S')
	AND r.trans_mode IN ('I')  
	AND rpf.profile_id IS NOT NULL
	GROUP BY p.profile_id, r.company_id, r.profit_ctr_id
   
	CREATE INDEX idx_tmp_Stat_R ON #Stat_R (profile_id, profile_company_id, profile_profit_ctr_id, trans_mode, cnt, mind, maxd)  
    
	INSERT INTO #Stat_W
		( profile_id
		, profile_company_id
		, profile_profit_ctr_id
		, wo_company_id
		, wo_profit_ctr_id
		, cnt
		, mind
		, maxd ) 
	SELECT  
		profile_id,  
		profile_company_id,  
		profile_profit_ctr_id,  
		wh.company_id AS wo_company_id,  
		wh.profit_ctr_id AS wo_profit_ctr_id,  
		COUNT(wd.workorder_id) AS cnt,  
		MIN(wh.end_date) AS mind,  
		MAX(wh.end_date) AS maxd   
	FROM workorderheader wh (nolock)  
	INNER JOIN workorderdetail wd  (nolock)  
	ON wh.workorder_id = wd.workorder_id  
	AND wh.company_id = wd.company_id  
	AND wh.profit_ctr_id = wd.profit_ctr_id  
	WHERE wh.workorder_status = 'A'  
	AND wd.resource_type = 'D'  
	AND wd.profile_id IS NOT NULL  
	--AND profile_id = 343472  
	GROUP BY profile_id,  
			profile_company_id,  
			profile_profit_ctr_id,  
			wh.company_id,  
			wh.profit_ctr_id  
   
	CREATE INDEX idx_tmp_Stat_W ON #Stat_W (profile_id, profile_company_id, profile_profit_ctr_id, cnt, mind, maxd)  
  
	IF @debug > 0 SELECT * FROM #Stat_R WHERE profile_id = 343472  
	IF @debug > 0 SELECT * FROM #Stat_W WHERE profile_id = 343472  
  
	IF @debug > 0 SELECT * FROM #Stat_R WHERE profile_id BETWEEN 343472 AND 343479  
	IF @debug > 0 SELECT * FROM #Stat_W WHERE profile_id BETWEEN 343472 AND 343479  
   
   
	-- drop indexes:  
	drop index ProfileStatistics.index_pk  
	drop index ProfileStatistics.ProfileStatistics_cui  
 
	INSERT INTO #tmp_receipt_profile_fee
		( receipt_profile_fee_uid
			, profile_id
			, company_id
			, profit_ctr_id
			, receipt_ref
			, profile_fee_code_desc )
	SELECT  rpf.receipt_profile_fee_uid,
			rpf.profile_id,
			rpf.company_id, 
			rpf.profit_ctr_id, 
			CONVERT(VARCHAR, receipt_id) + '-' + CONVERT(VARCHAR, line_id) AS receipt_ref,
			pfc.profile_fee_code_desc	
	FROM ReceiptProfileFee rpf (NOLOCK) 
	JOIN ProfileFeeCode pfc (NOLOCK)
	ON pfc.profile_fee_code_uid = rpf.profile_fee_code_uid
	WHERE EXISTS (SELECT 1 
				  FROM Profile 
				  WHERE profile_id = rpf.profile_id)
	AND EXISTS (SELECT 1 
				FROM Receipt 
				WHERE receipt_id = rpf.receipt_id 
				AND line_id = rpf.line_id 
				AND company_id = rpf.company_id 
				AND profit_ctr_id = rpf.profit_ctr_id)	
   
	TRUNCATE TABLE ProfileStatistics -- We're doing the whole set.  
  
	--------------------------------------------------------------------------------------------------------------------  
	-- Inbound Receipt Stats  
	--------------------------------------------------------------------------------------------------------------------  
	-- Inbound Receipt - Count  
	INSERT  ProfileStatistics ( profile_id, statistic, company_id, profit_ctr_id, value, added_by, date_added, modified_by, date_modified )  
	SELECT   
		r.profile_id,  
		'Approval ' + pqa.approval_code + ':  Inbound Receipt - Count',  
		r.profile_company_id,  
		r.profile_profit_ctr_id,  
		cnt AS value,  
		'SYSTEM',  
		GETDATE(),  
		'SYSTEM',  
		GETDATE()  
	FROM #Stat_R r  
	JOIN ProfileQuoteApproval pqa (nolock) ON r.profile_id = pqa.profile_id  
	AND r.profile_company_id = pqa.company_id  
	AND r.profile_profit_ctr_id = pqa.profit_ctr_id  
	WHERE r.trans_mode = 'I'  
  
	-- Inbound Receipt - First Used  
	INSERT  ProfileStatistics ( profile_id, statistic, company_id, profit_ctr_id, value, added_by, date_added, modified_by, date_modified )  
		SELECT   
		r.profile_id,  
		'Approval ' + pqa.approval_code + ':  Inbound Receipt - First Used',  
		r.profile_company_id,  
		r.profile_profit_ctr_id,  
		CONVERT(varchar(255), mind, 101) AS value,  
		'SYSTEM',  
		GETDATE(),  
		'SYSTEM',  
		GETDATE()  
	FROM #Stat_R r  
	JOIN ProfileQuoteApproval pqa (nolock) ON r.profile_id = pqa.profile_id  
	AND r.profile_company_id = pqa.company_id  
	AND r.profile_profit_ctr_id = pqa.profit_ctr_id  
	WHERE r.trans_mode = 'I'  
  
	-- Inbound Receipt - Most Recently Used  
	INSERT  ProfileStatistics ( profile_id, statistic, company_id, profit_ctr_id, value, added_by, date_added, modified_by, date_modified )  
		SELECT   
		r.profile_id,  
		'Approval ' + pqa.approval_code + ':  Inbound Receipt - Most Recently Used',  
		r.profile_company_id,  
		r.profile_profit_ctr_id,  
		CONVERT(varchar(255), maxd, 101) AS value,  
		'SYSTEM',  
		GETDATE(),  
		'SYSTEM',  
		GETDATE()  
	FROM #Stat_R r  
	JOIN ProfileQuoteApproval pqa (nolock) ON r.profile_id = pqa.profile_id  
	AND r.profile_company_id = pqa.company_id  
	AND r.profile_profit_ctr_id = pqa.profit_ctr_id  
	WHERE r.trans_mode = 'I'  
   
  
	--------------------------------------------------------------------------------------------------------------------  
	-- Outbound Receipt Stats  
	--------------------------------------------------------------------------------------------------------------------  
	-- Outbound Receipt - Count  
	INSERT  ProfileStatistics ( profile_id, statistic, company_id, profit_ctr_id, value, added_by, date_added, modified_by, date_modified )  
	SELECT   
		r.profile_id,  
		'Approval ' + pqa.approval_code + ':  Outbound Receipt - Count in ' + pc.profit_ctr_name + ' (' + RIGHT('00' + CONVERT(varchar(2), r.receipt_company_id), 2) + '-' + RIGHT('00' + CONVERT(varchar(2), r.receipt_profit_ctr_id), 2) + ')',  
		r.profile_company_id,  
		r.profile_profit_ctr_id,  
		cnt AS value,  
		'SYSTEM',  
		GETDATE(),  
		'SYSTEM',  
		GETDATE()  
	FROM #Stat_R r  
	JOIN ProfileQuoteApproval pqa (nolock) ON r.profile_id = pqa.profile_id  
	AND r.profile_company_id = pqa.company_id  
	AND r.profile_profit_ctr_id = pqa.profit_ctr_id  
	JOIN ProfitCenter pc (nolock) ON pc.company_id = r.receipt_company_id  
	AND pc.profit_ctr_id = r.receipt_profit_ctr_id  
	WHERE r.trans_mode = 'O'  
   
	-- Outbound Receipt - First Used  
	INSERT  ProfileStatistics ( profile_id, statistic, company_id, profit_ctr_id, value, added_by, date_added, modified_by, date_modified )  
	SELECT   
		r.profile_id,  
		'Approval ' + pqa.approval_code + ':  Outbound Receipt - First Used in ' + pc.profit_ctr_name + ' (' + RIGHT('00' + CONVERT(varchar(2), r.receipt_company_id), 2) + '-' + RIGHT('00' + CONVERT(varchar(2), r.receipt_profit_ctr_id), 2) + ')',  
		r.profile_company_id,  
		r.profile_profit_ctr_id,  
		CONVERT(varchar(255), mind, 101) AS value,  
		'SYSTEM',  
		GETDATE(),  
		'SYSTEM',  
		GETDATE()  
	FROM #Stat_R r  
	JOIN ProfileQuoteApproval pqa (nolock) ON r.profile_id = pqa.profile_id  
	AND r.profile_company_id = pqa.company_id  
	AND r.profile_profit_ctr_id = pqa.profit_ctr_id  
	JOIN ProfitCenter pc (nolock) ON pc.company_id = r.receipt_company_id  
	AND pc.profit_ctr_id = r.receipt_profit_ctr_id  
	WHERE r.trans_mode = 'O'  
   
	-- Outbound Receipt - Most Recently Used  
	INSERT  ProfileStatistics ( profile_id, statistic, company_id, profit_ctr_id, value, added_by, date_added, modified_by, date_modified )  
		SELECT   
		r.profile_id,  
		'Approval ' + pqa.approval_code + ':  Outbound Receipt - Most Recently Used in ' + pc.profit_ctr_name + ' (' + RIGHT('00' + CONVERT(varchar(2), r.receipt_company_id), 2) + '-' + RIGHT('00' + CONVERT(varchar(2), r.receipt_profit_ctr_id), 2) + ')',  
		r.profile_company_id,  
		r.profile_profit_ctr_id,  
		CONVERT(varchar(255), mind, 101) AS value,  
		'SYSTEM',  
		GETDATE(),  
		'SYSTEM',  
		GETDATE()  
	FROM #Stat_R r  
	JOIN ProfileQuoteApproval pqa (nolock) ON r.profile_id = pqa.profile_id  
	AND r.profile_company_id = pqa.company_id  
	AND r.profile_profit_ctr_id = pqa.profit_ctr_id  
	JOIN ProfitCenter pc (nolock) ON pc.company_id = r.receipt_company_id  
	AND pc.profit_ctr_id = r.receipt_profit_ctr_id  
	WHERE r.trans_mode = 'O'  
   
  
	--------------------------------------------------------------------------------------------------------------------  
	-- Work Order Stats  
	--------------------------------------------------------------------------------------------------------------------  
	-- Work Order - Count  
	INSERT  ProfileStatistics ( profile_id, statistic, company_id, profit_ctr_id, value, added_by, date_added, modified_by, date_modified )  
	SELECT   
		w.profile_id,  
		'Approval ' + pqa.approval_code + ':  Work Order - Count in ' + pc.profit_ctr_name + ' (' + RIGHT('00' + CONVERT(varchar(2), w.wo_company_id), 2) + '-' + RIGHT('00' + CONVERT(varchar(2), w.wo_profit_ctr_id), 2) + ')',  
		w.profile_company_id,  
		w.profile_profit_ctr_id,  
		cnt AS value,  
		'SYSTEM',  
		GETDATE(),  
		'SYSTEM',  
		GETDATE()  
	FROM #Stat_W w  
	JOIN ProfileQuoteApproval pqa (nolock) ON w.profile_id = pqa.profile_id  
	AND w.profile_company_id = pqa.company_id  
	AND w.profile_profit_ctr_id = pqa.profit_ctr_id  
	JOIN ProfitCenter pc (nolock) ON pc.company_id = w.wo_company_id  
	AND pc.profit_ctr_id = w.wo_profit_ctr_id  
   
	-- Work Order - First Used  
	INSERT  ProfileStatistics ( profile_id, statistic, company_id, profit_ctr_id, value, added_by, date_added, modified_by, date_modified )  
	SELECT   
		w.profile_id,  
		'Approval ' + pqa.approval_code + ':  Work Order - First Used in ' + pc.profit_ctr_name + ' (' + RIGHT('00' + CONVERT(varchar(2), w.wo_company_id), 2) + '-' + RIGHT('00' + CONVERT(varchar(2), w.wo_profit_ctr_id), 2) + ')',  
		w.profile_company_id,  
		w.profile_profit_ctr_id,  
		CONVERT(varchar(255), mind, 101) AS value,  
		'SYSTEM',  
		GETDATE(),  
		'SYSTEM',  
		GETDATE()  
	FROM #Stat_W w  
	JOIN ProfileQuoteApproval pqa (nolock) ON w.profile_id = pqa.profile_id  
	AND w.profile_company_id = pqa.company_id  
	AND w.profile_profit_ctr_id = pqa.profit_ctr_id  
	JOIN ProfitCenter pc (nolock) ON pc.company_id = w.wo_company_id  
	AND pc.profit_ctr_id = w.wo_profit_ctr_id  
   
	-- Work Order - Most Recently Used  
	INSERT  ProfileStatistics ( profile_id, statistic, company_id, profit_ctr_id, value, added_by, date_added, modified_by, date_modified )  
	SELECT   
		w.profile_id,  
		'Approval ' + pqa.approval_code + ':  Work Order - Most Recently Used in ' + pc.profit_ctr_name + ' (' + RIGHT('00' + CONVERT(varchar(2), w.wo_company_id), 2) + '-' + RIGHT('00' + CONVERT(varchar(2), w.wo_profit_ctr_id), 2) + ')',  
		w.profile_company_id,  
		w.profile_profit_ctr_id,  
		CONVERT(varchar(255), mind, 101) AS value,  
		'SYSTEM',  
		GETDATE(),  
		'SYSTEM',  
		GETDATE()  
	FROM #Stat_W w  
	JOIN ProfileQuoteApproval pqa (nolock) ON w.profile_id = pqa.profile_id  
	AND w.profile_company_id = pqa.company_id  
	AND w.profile_profit_ctr_id = pqa.profit_ctr_id  
	JOIN ProfitCenter pc (nolock) ON pc.company_id = w.wo_company_id  
	AND pc.profit_ctr_id = w.wo_profit_ctr_id  

	--------------------------------------------------------------------------------------------------------------------  
	-- Profile Fee Receipt Stats  
	--------------------------------------------------------------------------------------------------------------------  
	-- Profile Fee Receipt - Count  
	INSERT  ProfileStatistics ( profile_id, statistic, company_id, profit_ctr_id, value, added_by, date_added, modified_by, date_modified )  
	SELECT   
		r.profile_id,  
		'Approval ' + pqa.approval_code + ':  Profile Fee Receipt - Count',  
		r.receipt_company_id,  
		r.receipt_profit_ctr_id,  
		cnt AS value,  
		'SYSTEM',  
		GETDATE(),  
		'SYSTEM',  
		GETDATE()  
	FROM #Stat_R r  
	JOIN ProfileQuoteApproval pqa (NOLOCK) ON r.profile_id = pqa.profile_id  
	WHERE r.trans_mode = 'P'   
  
	-- Profile Fee Receipt - First Used 
	INSERT  ProfileStatistics ( profile_id, statistic, company_id, profit_ctr_id, value, added_by, date_added, modified_by, date_modified )  
	SELECT   
		r.profile_id,  
		'Approval ' + pqa.approval_code + ':  Profile Fee Receipt - First Used (Receipt - ' + rpf.receipt_ref + ', Fee Type - ' + rpf.profile_fee_code_desc + ')',  
		r.profile_company_id,  
		r.profile_profit_ctr_id,  
		CONVERT(VARCHAR(10), mind, 101) AS value,  
		'SYSTEM',  
		GETDATE(),  
		'SYSTEM',  
		GETDATE()  
	FROM #Stat_R r  
	JOIN ProfileQuoteApproval pqa (NOLOCK) ON r.profile_id = pqa.profile_id  
	AND r.profile_company_id = pqa.company_id  
	AND r.profile_profit_ctr_id = pqa.profit_ctr_id  
	JOIN #tmp_receipt_profile_fee rpf ON rpf.profile_id = r.profile_id
	WHERE r.trans_mode = 'P' 
	AND rpf.receipt_profile_fee_uid = (SELECT MIN(receipt_profile_fee_uid) 
									   FROM #tmp_receipt_profile_fee
									   WHERE profile_id = rpf.profile_id)
  
	-- Profile Fee Receipt - Most Recently Used  
	INSERT  ProfileStatistics ( profile_id, statistic, company_id, profit_ctr_id, value, added_by, date_added, modified_by, date_modified )  
	SELECT   
		r.profile_id,  
		'Approval ' + pqa.approval_code + ':  Profile Fee Receipt - Most Recently Used (Receipt - ' + rpf.receipt_ref + ', Fee Type - ' + rpf.profile_fee_code_desc +  ')',  
		r.profile_company_id,  
		r.profile_profit_ctr_id,  
		CONVERT(VARCHAR(10), maxd, 101) AS value,  
		'SYSTEM',  
		GETDATE(),  
		'SYSTEM',  
		GETDATE()  
	FROM #Stat_R r  
	JOIN ProfileQuoteApproval pqa (NOLOCK) ON r.profile_id = pqa.profile_id  
	AND r.profile_company_id = pqa.company_id  
	AND r.profile_profit_ctr_id = pqa.profit_ctr_id  
	JOIN #tmp_receipt_profile_fee rpf ON rpf.profile_id = r.profile_id
	WHERE r.trans_mode = 'P'  
	AND rpf.receipt_profile_fee_uid = (SELECT MAX(receipt_profile_fee_uid) 
									   FROM #tmp_receipt_profile_fee
									   WHERE profile_id = rpf.profile_id)
   
	-- This always needs to happen, if we add a (where not exists...) clause  
	-- it'll refill the table with stock data after a truncate AND it'll   
	-- add new profile/co/pc info that was recently created.  
	-- Reload with defaults:  
	-- INSERT  ProfileStatistics(   
	--  profile_id,  
	--  statistic,  
	--  company_id,  
	--  profit_ctr_id,  
	--  value,  
	--  added_by,  
	--  date_added,  
	--  modified_by,  
	--  date_modified  
	-- )  
	-- SELECT DISTINCT  
	--  pqa.profile_id ,  
	--  'Approval ' + pqa.approval_code + ':  ' + s.stat,  
	--  pqa.company_id ,  
	--  pqa.profit_ctr_id ,  
	--  NULL ,  
	--  'SYSTEM',  
	--  GETDATE(),  
	--  'SYSTEM',  
	--  GETDATE()  
	-- FROM ProfileQuoteApproval pqa  
	-- INNER JOIN (  
	--  SELECT 'Inbound Receipt - Count' AS stat UNION  
	--  SELECT 'Inbound Receipt - First Used' AS stat UNION  
	--  SELECT 'Inbound Receipt - Most Recently Used' AS stat UNION  
	--  SELECT 'Outbound Receipt - Count' AS stat UNION  
	--  SELECT 'Outbound Receipt - First Used' AS stat UNION  
	--  SELECT 'Outbound Receipt - Most Recently Used' AS stat UNION  
	--  SELECT 'Work Order - Count' AS stat UNION  
	--  SELECT 'Work Order - First Used' AS stat UNION  
	--  SELECT 'Work Order - Most Recently Used' AS stat  
	-- ) s ON 1=1  
	-- WHERE NOT EXISTS (  
	--  SELECT 1 FROM ProfileStatistics  
	--  WHERE profile_id = pqa.profile_id  
	--  AND company_id = pqa.company_id  
	--  AND profit_ctr_id = pqa.profit_ctr_id  
	--  AND statistic = s.stat  
	-- )  
	--AND profile_id = 343472  
  
	---- Update ProfileStatistics (setting actual values for all the NULLs we just put in)  
	-- UPDATE ProfileStatistics  
	--  SET value =   
	--   CASE WHEN statistic LIKE '%Inbound%First Used%'  
	--   THEN  CONVERT(varchar(255), mind, 101 )  
	--   ELSE  
	--    CASE WHEN statistic LIKE '%Inbound%Most Recently Used%'  
	--    THEN  CONVERT(varchar(255), maxd, 101 )  
	--    ELSE  
	--     CASE WHEN statistic LIKE '%Inbound%Count%'  
	--     THEN CONVERT(varchar(255), cnt )  
	--     END  
	--    END  
	--   END,  
	--  date_modified = GETDATE(),  
	--  modified_by = 'SYSTEM'  
	-- FROM ProfileStatistics ps  
	-- INNER JOIN #Stat_R r  
	--  ON ps.profile_id = r.profile_id  
	--  AND ps.company_id = r.profile_company_id  
	--  AND ps.profit_ctr_id = r.profile_profit_ctr_id  
	--  AND r.trans_mode = 'I'  
	---- 1m, 13s (index)  
  
	----Outbound Receipt - Count               
	----Outbound Receipt - First Used          
	----Outbound Receipt - Most Recently Used  
  
	---- Update ProfileStatistics (setting actual values for all the NULLs we just put in)  
	-- UPDATE ProfileStatistics  
	--  SET value =   
	--   CASE WHEN statistic LIKE '%Outbound%First Used%'  
	--   THEN  CONVERT(varchar(255), mind, 101 )  
	--   ELSE  
	--    CASE WHEN statistic LIKE '%Outbound%Most Recently Used%'  
	--    THEN  CONVERT(varchar(255), maxd, 101 )  
	--    ELSE  
	--     CASE WHEN statistic LIKE '%Outbound%Count%'  
	--     THEN CONVERT(varchar(255), cnt )  
	--     END  
	--    END  
	--   END,  
	--  statistic = statistic + ' in (' + RIGHT('00' + CONVERT(varchar(2), r.receipt_company_id), 2) + '-' + RIGHT('00' + CONVERT(varchar(2), r.receipt_profit_ctr_id), 2) + ')',  
	--  date_modified = GETDATE(),  
	--  modified_by = 'SYSTEM'  
	-- FROM ProfileStatistics ps  
	-- INNER JOIN #Stat_R r  
	--  ON ps.profile_id = r.profile_id  
	--  AND ps.company_id = r.profile_company_id  
	--  AND ps.profit_ctr_id = r.profile_profit_ctr_id  
	--  AND r.trans_mode = 'O'  
	-- WHERE ps.statistic LIKE '%Outbound%'  
  
  
	---- Update ProfileStatistics  
	-- UPDATE ProfileStatistics  
	--  SET value =   
	--   CASE WHEN statistic LIKE '%Work Order%First Used%'  
	--   THEN  CONVERT(varchar(255), mind, 101 )  
	--   ELSE  
	--    CASE WHEN statistic LIKE '%Work Order%Most Recently Used%'  
	--    THEN  CONVERT(varchar(255), maxd, 101 )  
	--    ELSE  
	--     CASE WHEN statistic LIKE '%Work Order%Count%'  
	--     THEN CONVERT(varchar(255), cnt )  
	--     END  
	--    END  
	--   END,  
	--  date_modified = GETDATE(),  
	--  modified_by = 'SYSTEM'  
	-- FROM ProfileStatistics ps  
	-- INNER JOIN #Stat_W r  
	--  ON ps.profile_id = r.profile_id  
	--  AND ps.company_id = r.profile_company_id  
	--  AND ps.profit_ctr_id = r.profile_profit_ctr_id  
  
  
	-- re-create index  
	create clustered index ProfileStatistics_cui on ProfileStatistics (profile_id, statistic, profit_ctr_id, company_id)  
	create index index_pk on ProfileStatistics (profile_id, company_id, profit_ctr_id, statistic)  
  
  
	IF @debug > 0 SELECT * FROM ProfileStatistics WHERE profile_id = 343472 
END
GO

GRANT EXECUTE
    ON OBJECT::[dbo].[sp_update_profile_statistics] TO [EQAI]