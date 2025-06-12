
create procedure sp_rpt_illinois_attachment_h_report
	@permission_id int,
	@user_id int = NULL,
	@user_code varchar(20) = null,
	@copc_list varchar(max),
	@type_code_list varchar(100) =  NULL,
	@start_date datetime,
	@end_date datetime
	
/*
	exec sp_rpt_illinois_attachment_h_report 86, 1206, 'RICH_G', '26|0', 'APPRILHFL,APPRILHPRT,APPRILHEX','10/01/2010','1/11/2011'
	06/16/2023 Devops 65744 -- Nagaraj M Modified the input parameter @copc_list varchar(500) to @copc_list varchar(max)
*/	
as

if object_id('tempdb..#tmp_results') IS NOT NULL drop table #tmp_results

set @start_date = CONVERT(varchar(20), @start_date, 101) + ' 00:00:00'
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

declare @tbl_document_type_codes table (
	type_code varchar(20),
	type_id int
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

--declare @type_code_list varchar(100) = 'APPRILHFL,APPRILHPRT,APPRILHEX'
INSERT @tbl_document_type_codes
    SELECT row,
    (SELECT type_id FROM PLT_IMAGE.dbo.ScanDocumentType sdt WHERE sdt.type_code = row) as type_id
    from dbo.fn_SplitXsvText(',', 0, @type_code_list) 
    where isnull(row, '') <> ''
    

SELECT
	r.receipt_date,
	r.company_id,
		r.profit_ctr_id,
		r.receipt_id,
		
		r.profile_id,	
		r.approval_code,
		p.approval_desc,
		g.generator_name,
		sdt.document_type,
		s.document_name,	
			(SELECT TOP 1 receipt_id AS first_receipt_id
			FROM   Receipt tmp_r
			WHERE  tmp_r.profile_id = p.profile_id
				AND tmp_r.company_id = r.company_id
				AND tmp_r.profit_ctr_id = r.profit_ctr_id
				AND tmp_r.receipt_status <> 'V'
				AND tmp_r.fingerpr_status <> 'V'
			ORDER  BY receipt_date ASC)
		as first_profile_received_receipt_id,
		c.customer_id,
		c.cust_name
	INTO #tmp_results		
	FROM   Profile p  WITH(NOLOCK)
		   LEFT JOIN Receipt r WITH(NOLOCK)
			 ON p.profile_id = r.profile_id
		   LEFT JOIN PLT_IMAGE.dbo.Scan s WITH(NOLOCK)
			 ON s.profile_id = r.profile_id
			 AND s.image_id = (
				SELECT MAX(image_id) FROM PLT_IMAGE.dbo.Scan tmp_s WITH(NOLOCK)
				INNER JOIN @tbl_document_type_codes tcodes ON tcodes.type_id = s.type_id
				WHERE s.profile_id = tmp_s.profile_id
			 )
		
		   LEFT JOIN PLT_Image.dbo.ScanDocumentType sdt WITH(NOLOCK)
			 ON s.type_id = sdt.type_id
				AND s.type_id IN( SELECT type_id FROM @tbl_document_type_codes)
		   LEFT JOIN Customer c  WITH(NOLOCK) ON
			c.customer_id = r.customer_id
		   LEFT JOIN Generator g  WITH(NOLOCK) ON
			r.generator_id = g.generator_id
			INNER JOIN @tbl_profit_center_filter secured_copc ON r.company_id = secured_copc.company_id
			AND r.profit_ctr_id = secured_copc.profit_ctr_id
	WHERE  1 = 1
	AND r.receipt_date BETWEEN @start_date and @end_date

SELECT DISTINCT
receipt_date
,company_id
,profit_ctr_id
,receipt_id
,profile_id
,approval_code
,approval_desc
,generator_name
,document_type
,document_name
,
	CASE
		WHEN first_profile_received_receipt_id = receipt_id THEN 'Y'
		ELSE 'N'
	END as is_first_receipt_for_profile
,first_profile_received_receipt_id
,customer_id
,cust_name
FROM #tmp_results data
ORDER BY receipt_date


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_illinois_attachment_h_report] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_illinois_attachment_h_report] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_illinois_attachment_h_report] TO [EQAI]
    AS [dbo];

