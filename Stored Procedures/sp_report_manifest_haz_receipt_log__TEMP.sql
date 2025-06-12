
create procedure sp_report_manifest_haz_receipt_log__TEMP
	@start_date datetime,
	@end_date datetime,
	@product_code varchar(20) = NULL,
	@copc_list varchar(max),
	@user_code varchar(50) = NULL,
	@user_id int = NULL,
	@permission_id int
	
/*
EXEC sp_report_manifest_haz_receipt_log
  '08/01/2010',
  '08/30/2010 23:59:59',
  'ILTAXHZ',
  '12|0,12|1,12|2,12|3,12|4,12|5,12|7,14|0,14|1,14|10,14|11,14|2,14|3,14|4,14|5,14|6,14|9,15|1,15|2,15|3,15|4,16|0,17|0,18|0,21|0,21|1,21|2,21|3,22|0,22|1,23|0,24|0,25|0,25|2,25|4,26|0,26|2,27|0,27|2,28|0,29|0,2|21,3|1',
  'RICH_G',
  1206,
  168 
    06/16/2023 Devops 65744 -- Nagaraj M Modified the input parameter @copc_list varchar(500) to @copc_list varchar(max)
*/	
	
as
begin

set @end_date = CONVERT(varchar(20), @end_date, 101) + ' 23:59:59'

IF @user_code = ''
    set @user_code = NULL
    
IF @user_id IS NULL
	SELECT @user_id = USER_ID from users where user_code = @user_code
	
IF @user_code IS NULL
	SELECT @user_code = user_code from users where user_id = @user_id
    
declare @tbl_profit_center_filter table (
    [company_id] int, 
    [profit_ctr_id] int
)
    
INSERT @tbl_profit_center_filter 
	SELECT secured_copc.company_id, secured_copc.profit_ctr_id 
	    FROM SecuredProfitCenter secured_copc
	    INNER JOIN (
	        SELECT 
	            RTRIM(LTRIM(SUBSTRING(row, 1, CHARINDEX('|',row) - 1))) company_id,
	            RTRIM(LTRIM(SUBSTRING(row, CHARINDEX('|',row) + 1, LEN(row) - (CHARINDEX('|',row)-1)))) profit_ctr_id
	        from dbo.fn_SplitXsvText(',', 0, @copc_list) 
	        where isnull(row, '') <> '') selected_copc ON 
	            secured_copc.company_id = selected_copc.company_id 
	            AND secured_copc.profit_ctr_id = selected_copc.profit_ctr_id
	            AND secured_copc.permission_id = @permission_id
	            AND secured_copc.user_code = @user_code


SELECT r.receipt_id,
	r.company_id,
	r.profit_ctr_id,
	r.line_id,
	r.receipt_date,
	r.approval_code,
	r.manifest,
	ISNULL(r.manifest_quantity, 0) as manifest_quantity,
	ISNULL(r.manifest_unit, '') as manifest_unit,
	t.management_code,
	p.description as product_description,
	p.product_code,
	r2.ref_receipt_id,
	r2.quantity,
	r2.bill_unit_code,
	bu.gal_conv,
	bu.yard_conv,
	'Unbundled' as bundle_type
INTO #results	
FROM Receipt r
INNER JOIN @tbl_profit_center_filter secure_copc ON r.company_id = secure_copc.company_id
	AND r.profit_ctr_id = secure_copc.profit_ctr_id
LEFT OUTER JOIN Receipt r2
	ON r2.ref_receipt_id = r.receipt_id
	AND r2.ref_line_id = r.line_id
	AND r2.company_id = r.company_id
	AND r2.profit_ctr_id = r.profit_ctr_id
	AND r2.trans_type = 'S' -- grab service lines for this Receipt (r)
	AND r2.product_code = COALESCE(@product_code, r2.product_code)
LEFT OUTER JOIN Product p ON r2.product_id = p.product_ID
	AND r2.product_code = COALESCE(@product_code, r2.product_code)
INNER JOIN BillUnit bu ON bu.manifest_unit = r.manifest_unit	
INNER JOIN TreatmentHeader t ON t.treatment_id = r.treatment_id
WHERE
EXISTS (SELECT 1 FROM ReceiptWasteCode rwc 
	JOIN WasteCode wc ON wc.waste_code = rwc.waste_code AND wc.haz_flag = 'T'
	WHERE rwc.receipt_id = r.receipt_id
	AND rwc.company_id = r.company_id 
	AND rwc.profit_ctr_id = r.profit_ctr_id)
AND r.receipt_date BETWEEN @start_date AND @end_date	
AND r.trans_type = 'D' -- grab disposal lines only
ORDER BY r.receipt_date ASC

UPDATE #results SET
	bill_unit_code = pqd.bill_unit_code
	, quantity = r.quantity
	, product_code = p.product_code
	, product_description = p.description
	, bundle_type = 'Bundled'
	FROM Receipt r
INNER JOIN #results ON #results.receipt_id = r.receipt_id
	AND #results.company_id = r.company_id
	AND #results.profit_ctr_id = r.profit_ctr_id
	AND #results.line_id = r.line_id
INNER JOIN ProfileQuoteDetail pqd ON
	pqd.profile_id = r.profile_id
	AND pqd.company_id = r.company_id
	AND pqd.profit_ctr_id = r.profit_ctr_id
	AND (pqd.bill_method = 'B')
	AND pqd.record_type IN ('S','T') -- Services or Transportation
	AND pqd.product_code = @product_code
	AND pqd.bill_quantity_flag IN ('U','L') -- Unit or Load	
INNER JOIN Product p ON pqd.product_id = p.product_ID
	AND pqd.product_code = @product_code
WHERE 
	#results.product_code is null

	
SELECT * FROM #results	
	


END


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_report_manifest_haz_receipt_log__TEMP] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_report_manifest_haz_receipt_log__TEMP] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_report_manifest_haz_receipt_log__TEMP] TO [EQAI]
    AS [dbo];

