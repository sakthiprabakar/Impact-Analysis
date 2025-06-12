
create procedure sp_reports_billing_summary_master_for_aging
(
	@debug			int = 0, 
	@db_list	varchar(8000),
	@cust_min		varchar(8),
	@cust_max		varchar(8),
	@as_of_date		datetime,
	@customer_type	varchar(10),
	@detail_level	char(1) = 'S' -- (S)ummary or (D)etail
)
/*********************************************************************************************************
06/16/2023 Devops 65744 -- Nagaraj M Modified the parameter @all_copc_list varchar(500) to @copc_list varchar(max)
07/05/2024 KS	Rally117980 - Modified datatype for #billing_summary_report_results.line_desc_1 and #billing_summary_report_results.line_desc_2 to VARCHAR(100)
******************************************************************************************************/
as 	
if object_id('tempdb..#aging_report_results') is not null drop table #aging_report_results
if object_id('tempdb..#billing_summary_report_results') is not null drop table #billing_summary_report_results

SET @as_of_date = convert(varchar(20), @as_of_date, 101)

IF (CHARINDEX(',',@db_list,1) > 0)
	SET @db_list = SUBSTRING(@db_list,2, LEN(@db_list)-1)
	
	

/* this table is a mirror from the output of the NTSQLFinance.emaster.dbo.sp_reports_web_aging procedure */
create table #aging_report_results
(
	customer_id int NULL,
	customer_name varchar(100) NULL,
	company_id int NULL,
	company_name varchar(100) NULL,
	apply_to_num varchar(100) NULL,
	trx_type varchar(20) NULL,
	aging_date datetime NULL,
	balance float NULL,
	terms_code varchar(20) NULL
)	

/* this table is a mirror of the output of the sp_reports_billing_summary_master */
CREATE TABLE #billing_summary_report_results(
	[company_id] [smallint] NOT NULL,
	[profit_ctr_id] [smallint] NOT NULL,
	[profit_ctr_name] [varchar](50) NULL,
	[trans_source] [char](10) NULL,
	[receipt_id] [int] NULL,
	[line_id] [int] NULL,
	[price_id] [int] NULL,
	[status_code] [char](1) NULL,
	[billing_date] [datetime] NULL,
	[invoice_code] [varchar](16) NULL,
	[invoice_date] [datetime] NULL,
	[customer_id] [int] NULL,
	[cust_name] [varchar](40) NULL,
	[bill_unit_code] [varchar](4) NULL,
	[generator_id] [int] NULL,
	[generator_name] [varchar](40) NULL,
	[epa_id] [varchar](12) NULL,
	[approval_code] [varchar](15) NULL,
	[location_code] [varchar](8) NULL,
	[quantity] [float] NULL,
	[extended_amt] [money] NULL,
	[manifest] [varchar](15) NULL,
	[purchase_order] [varchar](20) NULL,
	[release_code] [varchar](20) NULL,
	[trans_type] [char](10) NULL,
	[line_desc_1] [varchar](100) NULL,
	[line_desc_2] [varchar](100) NULL,
	[description] [varchar](60) NULL,
	[billing_project_id] [int] NOT NULL,
	[bill_unit_description] [varchar](40) NULL,
	[billing_project_name] [varchar](40) NULL,
	[session_key] [uniqueidentifier] NULL,
	[session_added] [datetime] NULL,
	[pickup_date] datetime NULL,
	[site_code] varchar(20) NULL
) ON [PRIMARY]
		

declare @character char(1) = '0';
declare @expectedLength int = 6;

-- the input for cust min/max must be 6 character zero padded string
select @cust_min = REPLICATE(@character, @expectedLength - LEN(@cust_min)) + CAST(@cust_min as varchar(8))
select @cust_max = REPLICATE(@character, @expectedLength - LEN(@cust_max)) + CAST(@cust_max as varchar(8))
		
INSERT #aging_report_results
EXEC NTSQLFinance.emaster.dbo.sp_reports_web_aging
  @debug,
  @db_list,
  @cust_min,
  @cust_max,
  @as_of_date,
  @customer_type 


IF @detail_level = 'S'
BEGIN
	SELECT DISTINCT age.*,ih.total_amt_due, ih.invoice_date
	FROM #aging_report_results age
		LEFT JOIN InvoiceHeader ih ON age.apply_to_num = ih.invoice_code
			and ih.status = 'I'
RETURN		
END


/*INSERT #aging_report_results
EXEC NTSQLFinance.emaster.dbo.sp_reports_web_aging
  0,
  'e01,e02,e03,e12,e14,e15,e21,e22,e23,e24,e25,e26,e27,e28,e29',
  '6243',
  '6243',
  '10/06/2010',
  NULL 
*/  


/* convert the aging invoice_codes to a CSV */
declare @newline varchar(4) = char(13) + char(10)
declare @invoice_code_list varchar(max)

select @invoice_code_list = coalesce(@invoice_code_list, '') + ',' + 
	apply_to_num 
	from #aging_report_results
	INNER JOIN InvoiceHeader ih ON #aging_report_results.apply_to_num = ih.invoice_code

IF CHARINDEX(',', @invoice_code_list, 1) > 0
	SET @invoice_code_list = SUBSTRING(@invoice_code_list,2, LEN(@invoice_code_list)-1)

if (SELECT COUNT(*) FROM #aging_report_results) = 0
begin
	set @invoice_code_list = '-1' -- dummy value to not return any records, but still return the schema
end


/* prepare the whole active co/pc list as a CSV */
declare @all_copc_list varchar(max)
select @all_copc_list = coalesce(@all_copc_list, '') + ',' + cast(company_ID as varchar(10)) + '|' + cast(profit_ctr_ID as varchar(10))
	FROM ProfitCenter pc where pc.status = 'A'
	ORDER BY company_ID,profit_ctr_ID
	
IF CHARINDEX(',', @all_copc_list, 1) > 0
	SET @all_copc_list = SUBSTRING(@all_copc_list,2, LEN(@all_copc_list)-1)



/* grab the billing summaries for the invoices that are aged */
INSERT #billing_summary_report_results
EXEC sp_reports_billing_summary_master
  0,
  @all_copc_list,
  '',
  '',
  '',
  @invoice_code_list,
  '',
  '',
  '',
  '',
  '',
  'D',
  -1,
  '',
  0,
  -1 

--SELECT
--	result.*,
--	'........................',
--	ta.*,
--	'........................',
--	ih.*,
--	'........................'


IF @detail_level = 'D' 
BEGIN

--SELECT age.apply_to_num, SUM(age.balance) FROM #aging_report_results age
--group by age.apply_to_num
	

SELECT 
	age.*
	,bs.profit_ctr_id
	,ih.total_amt_due
	,bs.approval_code
	,bs.bill_unit_code
	,bs.bill_unit_description
	,bs.billing_date
	,bs.billing_project_id
	,bs.billing_project_name
	,bs.cust_name
	,bs.description
	,bs.epa_id
	,bs.extended_amt
	,bs.generator_id
	,bs.generator_name
	,bs.invoice_date
	,bs.line_desc_1
	,bs.line_desc_2
	,bs.line_id
	,bs.location_code
	,bs.manifest
	,bs.pickup_date
	,bs.price_id
	,bs.profit_ctr_name
	,bs.purchase_order
	,bs.quantity
	,bs.receipt_id
	,bs.release_code
	,bs.site_code
	,bs.status_code
	,bs.trans_source
	,bs.trans_type
FROM #aging_report_results age
	LEFT OUTER JOIN #billing_summary_report_results bs ON age.apply_to_num = bs.invoice_code
		and bs.status_code = 'I'
	LEFT OUTER JOIN InvoiceHeader ih ON age.apply_to_num = ih.invoice_code
		and ih.status = 'I' AND bs.invoice_code IS NULL
ORDER BY customer_name	
END





GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_reports_billing_summary_master_for_aging] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_reports_billing_summary_master_for_aging] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_reports_billing_summary_master_for_aging] TO [EQAI]
    AS [dbo];

