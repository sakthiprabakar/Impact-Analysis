CREATE PROCEDURE [dbo].[sp_rpt_tsdf_fee_pa_electronic]
    @company_id			int,
    @profit_ctr_id		int,
    @date_from			datetime, 
	@date_to			datetime,
	@customer_id_from	int,
	@customer_id_to		int,
	@manifest_from		varchar(15),
	@manifest_to		varchar(15)
AS
/***********************************************************************
PA Hazardous Waste TSDF Fee - Electronic Version

Filename:		L:\IT Apps\SQL-Deploy\Prod\NTSQL1\Plt_AI\Procedures\sp_rpt_tsdf_fee_pa_electronic.sql
PB Object(s):	r_tsdf_fee_pa_electronic
		
08/22/2014 AM	Created - 

sp_rpt_tsdf_fee_pa_electronic   27, 0, '10/17/13', '10/17/13', 13366, 13366, '0', 'zzzzz'
***********************************************************************/
BEGIN

DECLARE @lines	int
		
-- This will determine the line#'s per page, in future if we need to change line#'s per page then we can just change this number.  	
set @lines = 10

SET NOCOUNT ON

-- Create temp table tmp
CREATE TABLE #tmpsp (line_number int   IDENTITY
    , tsdf_code    varchar (20) NULL
	, tsdf_epa_id	varchar(15) NULL
	, TSDF_name     varchar (40)NULL  
	, company_id    int			NOT NULL
	, profit_ctr_id int			NOT NULL
	, receipt_date  datetime	NULL
	, receipt_id    int			NULL
	, line_id       int			NULL
	, manifest		varchar (15)NULL
	, manifest_page_num int     NULL
	, manifest_line int			NULL 
	, profile_id	int			NULL
	, approval_code	varchar(15)	NULL
	, product_receipt_id  int   NULL
	, product_line_id   int		NULL
	, product_code      varchar(15)NULL
	, bill_unit_code	varchar (4)NULL
	, quantity			int		NULL 
	, treatment_method	varchar (10) NULL
	, tons_treatment	float   NULL
	, tons_storage		float   NULL
	, tons_disposal		float   NULL
	, tons_incineration float   NULL
	, tons_recycle		float   NULL
	, tons_exempt		float   NULL )
	 
-- Create #return tmp table to insert description
CREATE TABLE #return (
	line_id		int,
	description	varchar (1500))
	
-- call sp to insert data into #tmpsp 	
INSERT INTO #tmpsp 
EXECUTE sp_rpt_tsdf_fee_pa
    @company_id,
    @profit_ctr_id,
    @date_from, 
	@date_to,
	@customer_id_from,
	@customer_id_to,
	@manifest_from,
	@manifest_to
    
-- build result description from #tmpsp 
INSERT INTO #return (line_id, description) 
      select line_number ,
      cast( #tmpsp.tsdf_epa_id as varchar) + ',' 
    + cast((case when #tmpsp.line_number > @lines 
				  then #tmpsp.line_number - (@lines * ((#tmpsp.line_number-1)/@lines)) 
				  else #tmpsp.line_number end) AS VARCHAR) + ',' 
	+ cast(((#tmpsp.line_number -1 )/@lines + 1) AS VARCHAR) + ',' 
	+ cast(case when datepart(mm, #tmpsp.receipt_date) in (1,2,3) then 1
	            when datepart(mm, #tmpsp.receipt_date) in (4,5,6) then 2
				when datepart(mm, #tmpsp.receipt_date) in (7,8,9) then 3 
				when datepart(mm, #tmpsp.receipt_date) in (10,11,12) then 4
				end AS varchar) + ','
	+ cast(datepart(yyyy, #tmpsp.receipt_date) as varchar) + ','
	+ CAST(ISNULL( #tmpsp.tons_disposal,0) AS varchar) 
		-- Add a ".0" to the end of the number if it doesn't already have a decimal; spec requires all numbers to have decimals
		+ CASE CHARINDEX('.', #tmpsp.tons_disposal) WHEN 0 THEN '.0' ELSE '' END 
		+ ','
	+ CAST(ISNULL( #tmpsp.tons_exempt, 0) AS varchar)
		-- Add a ".0" to the end of the number if it doesn't already have a decimal; spec requires all numbers to have decimals
		+ CASE CHARINDEX('.', #tmpsp.tons_exempt) WHEN 0 THEN '.0' ELSE '' END 
		+ ','
	+ CAST(ISNULL( #tmpsp.tons_incineration, 0) AS varchar)
		-- Add a ".0" to the end of the number if it doesn't already have a decimal; spec requires all numbers to have decimals
		+ CASE CHARINDEX('.', #tmpsp.tons_incineration) WHEN 0 THEN '.0' ELSE '' END 
		+ ','
	+ CAST(ISNULL( #tmpsp.tons_recycle, 0) AS varchar)
		-- Add a ".0" to the end of the number if it doesn't already have a decimal; spec requires all numbers to have decimals
		+ CASE CHARINDEX('.', #tmpsp.tons_recycle) WHEN 0 THEN '.0' ELSE '' END 
		+ ','
	+ CAST(ISNULL( #tmpsp.tons_storage, 0) AS varchar)
		-- Add a ".0" to the end of the number if it doesn't already have a decimal; spec requires all numbers to have decimals
		+ CASE CHARINDEX('.', #tmpsp.tons_storage) WHEN 0 THEN '.0' ELSE '' END 
		+ ','
    + CAST(ISNULL(#tmpsp.tons_treatment + #tmpsp.tons_storage + #tmpsp.tons_disposal + #tmpsp.tons_incineration + #tmpsp.tons_recycle , 0) AS varchar)
		-- Add a ".0" to the end of the number if it doesn't already have a decimal; spec requires all numbers to have decimals
		+ CASE CHARINDEX('.',#tmpsp.tons_treatment + #tmpsp.tons_storage + #tmpsp.tons_disposal + #tmpsp.tons_incineration + #tmpsp.tons_recycle ) WHEN 0 THEN '.0' ELSE '' END 
		+ ','
	+ CAST(ISNULL( #tmpsp.tons_treatment, 0) AS varchar)
		-- Add a ".0" to the end of the number if it doesn't already have a decimal; spec requires all numbers to have decimals
		+ CASE CHARINDEX('.', #tmpsp.tons_treatment) WHEN 0 THEN '.0' ELSE '' END 
		+ ','
	+ cast( #tmpsp.manifest as varchar) + ',' 
	+ cast( #tmpsp.manifest_page_num as varchar) + ',' 
	+ cast( #tmpsp.manifest_line as varchar) 
	    FROM #tmpsp order by #tmpsp.manifest,#tmpsp.manifest_line
     
-- send result set with description 
SELECT #return.description
FROM #tmpsp (NOLOCK)
INNER JOIN #return (NOLOCK)
	ON #tmpsp.line_number = #return.line_id
ORDER BY  #tmpsp.manifest, #tmpsp.manifest_line
	
DROP TABLE #tmpsp
DROP TABLE #return
END

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_tsdf_fee_pa_electronic] TO [EQAI]
    AS [dbo];

