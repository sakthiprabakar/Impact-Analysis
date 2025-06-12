CREATE PROCEDURE sp_reports_manifest_quarterly_extract (
    @date_from datetime
   , @date_to   datetime
   , @copc_list	varchar(max)
   , @result_set_return int
)
AS
/**************************************************************************************************************************************
Loads to : PLT_AI

 Created 06/25/2015 - AM - This is copied from L:\IT Apps\SourceCode\Development\SQL\Smita\GEM 27112.
    Which has been running manually for every quarter. Now creating in HUB (Manifest Quarterly Extract.rdl)
    so user can run it.
01/26/2017 JPB	GEM-41566 - Detail rows omitted when the generator involved has no generator_country value.    
06/16/2023 Devops 65744 -- Nagaraj M Modified the input parameter @copc_list varchar(500) to @copc_list varchar(max)
EXECUTE sp_reports_manifest_quarterly_extract '3/01/2016','03/31/2016', '21|0', 2
**************************************************************************************************************************************/

-- Get the copc list into tmp_Copc
CREATE TABLE #tmp_Copc ([company_ID] int, profit_Ctr_ID int)
IF @copc_list = 'ALL'
	INSERT #tmp_Copc
	SELECT ProfitCenter.company_ID ,ProfitCenter.profit_Ctr_ID  FROM ProfitCenter WHERE status = 'A'
ELSE
	INSERT #tmp_Copc
	SELECT 
		RTRIM(LTRIM(SUBSTRING(row, 1, CHARINDEX('|',row) - 1))) AS company_ID,
		RTRIM(LTRIM(SUBSTRING(row, CHARINDEX('|',row) + 1, LEN(row) - (CHARINDEX('|',row)-1)))) AS profit_Ctr_ID
	from dbo.fn_SplitXsvText(',', 0, @copc_list) WHERE isnull(row, '') <> ''
		
		
DECLARE 
	@tmp_filename	varchar(255)
,	@tmp_desc		varchar(255)
,	@user_code		varchar(100)
 -- 2,3 ,21

CREATE TABLE #TSDF_HDR (
	gen_epa_id				varchar(12)
,	manifest				varchar(15)
,	last_transporter_epa	varchar(15)
,	tsdf_epa_id				varchar(15)
,	discrepancy_qty_flag	char(1)
,	discrepancy_type_flag	char(1)
,	discrepancy_residue_flag		char(1)
,	discrepancy_part_reject_flag	char(1)
,	discrepancy_full_reject_flag	char(1)
,	manifest_ref_number		varchar(15)
,	alt_facility_epa_id		varchar(15)
,	receipt_date			date
)

CREATE TABLE #TSDF_DTL (
	manifest				varchar(15)
,	manifest_line			int
,	manifest_quantity		float
,	manifest_unit			char(1)
,	waste_code1				varchar(4)
,	waste_code2				varchar(4)
,	waste_code3				varchar(4)
,	waste_code4				varchar(4)
,	waste_code5				varchar(4)
,	waste_code6				varchar(4)
,	manifest_management_code varchar(4)
-- below fields for SQL internal purposes
,	receipt_id				int
,	line_id					int
,	company_id				int
,	profit_ctr_id			int		
)

CREATE TABLE #GNRTR_HDR (
	gen_epa_id				varchar(12)
,	manifest				varchar(15)
,	first_transporter_epa	varchar(15)
,	tsdf_epa_id				varchar(15)
,	gen_sign_date			date
,	import_to_us_flag		char(1)
,	export_from_us_flag		char(1)
)


CREATE TABLE #GNRTR_DTL (
	manifest				varchar(15)
,	manifest_line			int
,	manifest_UN_NA_number	int
,	container_count			int
,	manifest_container_code	varchar(15)
,	manifest_quantity		float
,	manifest_unit			char(1)
,	waste_code1				varchar(4)
,	waste_code2				varchar(4)
,	waste_code3				varchar(4)
,	waste_code4				varchar(4)
,	waste_code5				varchar(4)
,	waste_code6				varchar(4)
-- below fields for SQL internal purposes
,	receipt_id				int
,	line_id					int
,	company_id				int
,	profit_ctr_id			int	
)

-- SET NOCOUNT ON
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

-------------------------------------------------------------------------
-- 1. TSDF HDR
-------------------------------------------------------------------------

	-- Optimization: the regular query sucks: this is better.
		if object_id('tempdb..#keys') is not null
			drop table #keys

		SELECT 
			r.receipt_id, r.line_id, r.company_id, r.profit_ctr_id, r.receipt_date
		into #keys
		from Receipt r (nolock)
		Join #tmp_Copc tpc
   			ON tpc.company_id = r.company_id
			AND tpc.profit_ctr_id = r.profit_ctr_id
		WHERE 1=1
		AND r.receipt_date BETWEEN @date_from AND @date_to
		AND r.receipt_status = 'A'
		AND r.fingerpr_status = 'A'
		AND r.trans_mode = 'I'
		-- AND r.trans_type = 'D'
		-- AND r.manifest_flag IN ('M', 'C')
		AND EXISTS (SELECT top 1 1 FROM ReceiptwasteCode RWC (nolock) 
			JOIN Wastecode W (nolock) ON RWC.waste_code_uid = W.waste_code_uid 
						AND W.haz_flag = 'T'
						AND (W.waste_code_origin = 'F' OR (W.waste_code_origin = 'S' and W.state = 'MI'))
			WHERE 1=1
						AND r.receipt_id = RWC.receipt_id
						AND r.line_id = RWC.line_id
						AND r.company_id = RWC.company_id
						AND r.profit_ctr_id = RWC.profit_ctr_id
						)


INSERT INTO #TSDF_HDR
SELECT DISTINCT
	g.EPA_ID
,	r.manifest
,	RTL.transporter_EPA_ID -- last transporter
,	pc.EPA_ID
,	rd.discrepancy_qty_flag
,	rd.discrepancy_type_flag
,	rd.discrepancy_residue_flag
,	rd.discrepancy_part_reject_flag
,	rd.discrepancy_full_reject_flag
,	rd.manifest_ref_number
,	rd.alt_facility_epa_id
,	r.receipt_date
FROM 
#keys k
JOIN Receipt r(nolock)
	ON k.receipt_id = r.receipt_id and k.line_id = r.line_id and k.company_id = r.company_id and k.profit_ctr_id = r.profit_ctr_id
JOIN Generator g (nolock) ON g.generator_id = r.generator_id
	AND isnull(g.generator_country, '') <> 'CAN'
JOIN ProfitCenter pc (nolock)
	ON pc.company_id = k.company_id
	AND pc.profit_ctr_id = k.profit_ctr_id
LEFT OUTER JOIN ReceiptTransporter RTL 
	ON RTL.company_id = k.company_id
	AND RTL.profit_ctr_id = k.profit_ctr_id
	AND RTL.receipt_id = k.receipt_id
	AND RTL.transporter_sequence_id = ( SELECT MAX(RT.transporter_sequence_id) FROM dbo.ReceiptTransporter RT (nolock) WHERE RT.company_id = k.company_id
										AND RT.profit_ctr_id =k.profit_ctr_id AND RT.receipt_id = k.receipt_id ) --AND RT.transporter_sequence_id > 1 )
LEFT OUTER JOIN dbo.ReceiptDiscrepancy rd (nolock) 
	ON rd.receipt_id = k.receipt_id
	AND r.company_id = k.company_id
	and r.profit_ctr_id = k.profit_ctr_id
WHERE r.trans_type = 'D'	
and r.manifest_flag IN ('M', 'C')

-------------------------------------------------------------------------
-- 2. TSDF DTL
-------------------------------------------------------------------------
INSERT INTO #TSDF_DTL
SELECT DISTINCT
	r.manifest
,	r.manifest_line
,	r.manifest_quantity
,	r.manifest_unit
,	NULL
,	NULL
,	NULL
,	NULL
,	NULL
,	NULL
,	t.management_code
,	k.receipt_id
,	k.line_id
,	k.company_id
,	k.profit_ctr_id	
FROM 
#keys k
JOIN Receipt r(nolock)
	ON k.receipt_id = r.receipt_id and k.line_id = r.line_id and k.company_id = r.company_id and k.profit_ctr_id = r.profit_ctr_id
JOIN Generator g (nolock) ON g.generator_id = r.generator_id
	AND isnull(g.generator_country, '') <> 'CAN'
JOIN dbo.ProfileQuoteApproval pqa (nolock) ON 
	pqa.profile_id = r.profile_id
	AND pqa.company_id = k.company_id
	AND pqa.profit_ctr_id = k.profit_ctr_id
LEFT OUTER JOIN Treatment t (nolock) ON 
	t.treatment_id = pqa.treatment_id
	and t.company_id = pqa.company_id
	and t.profit_ctr_id = pqa.profit_ctr_id
WHERE 1=1
AND r.trans_type = 'D'
AND r.manifest_flag IN ('M', 'C')


-- UPdate with Waste Codes
Update #TSDF_DTL Set waste_code1 = RW.waste_code FROM ReceiptWasteCode RW (nolock) WHERE RW.receipt_id = #TSDF_DTL.receipt_id AND RW.company_id = #TSDF_DTL.company_id AND RW.profit_ctr_id = #TSDF_DTL.profit_ctr_id AND RW.line_id = #TSDF_DTL.line_id and RW.sequence_id = 1	
Update #TSDF_DTL Set waste_code2 = RW.waste_code FROM ReceiptWasteCode RW (nolock) WHERE RW.receipt_id = #TSDF_DTL.receipt_id AND RW.company_id = #TSDF_DTL.company_id AND RW.profit_ctr_id = #TSDF_DTL.profit_ctr_id AND RW.line_id = #TSDF_DTL.line_id and RW.sequence_id = 2	
Update #TSDF_DTL Set waste_code3 = RW.waste_code FROM ReceiptWasteCode RW (nolock) WHERE RW.receipt_id = #TSDF_DTL.receipt_id AND RW.company_id = #TSDF_DTL.company_id AND RW.profit_ctr_id = #TSDF_DTL.profit_ctr_id AND RW.line_id = #TSDF_DTL.line_id and RW.sequence_id = 3	
Update #TSDF_DTL Set waste_code4 = RW.waste_code FROM ReceiptWasteCode RW (nolock) WHERE RW.receipt_id = #TSDF_DTL.receipt_id AND RW.company_id = #TSDF_DTL.company_id AND RW.profit_ctr_id = #TSDF_DTL.profit_ctr_id AND RW.line_id = #TSDF_DTL.line_id and RW.sequence_id = 4	
Update #TSDF_DTL Set waste_code5 = RW.waste_code FROM ReceiptWasteCode RW (nolock) WHERE RW.receipt_id = #TSDF_DTL.receipt_id AND RW.company_id = #TSDF_DTL.company_id AND RW.profit_ctr_id = #TSDF_DTL.profit_ctr_id AND RW.line_id = #TSDF_DTL.line_id and RW.sequence_id = 5	
Update #TSDF_DTL Set waste_code6 = RW.waste_code FROM ReceiptWasteCode RW (nolock) WHERE RW.receipt_id = #TSDF_DTL.receipt_id AND RW.company_id = #TSDF_DTL.company_id AND RW.profit_ctr_id = #TSDF_DTL.profit_ctr_id AND RW.line_id = #TSDF_DTL.line_id and RW.sequence_id = 6	

-------------------------------------------------------------------------
-- 3. GENERATOR HDR
-------------------------------------------------------------------------
INSERT INTO #GNRTR_HDR
SELECT 
	Generator.EPA_ID
,	Receipt.manifest
,	Coalesce(RT1.transporter_EPA_ID, Transporter.transporter_epa_id) -- first transporter
,	TSDF.TSDF_EPA_ID
,	ReceiptManifest.generator_sign_date
,	ReceiptManifest.import_to_us_flag
,	ReceiptManifest.export_from_us_flag
FROM dbo.Receipt(nolock)
JOIN dbo.Generator ON Generator.generator_id = dbo.Receipt.generator_id
JOIN TSDF ON TSDF.tsdf_code = Receipt.tsdf_code AND TSDF.tsdf_status = 'A'
Join #tmp_Copc
   	ON #tmp_Copc.company_id = Receipt.company_id
	AND #tmp_Copc.profit_ctr_id = Receipt.profit_ctr_id
LEFT OUTER JOIN dbo.ReceiptTransporter RT1 ON RT1.company_id = Receipt.company_id
	AND RT1.profit_ctr_id = Receipt.profit_ctr_id
	AND dbo.Receipt.receipt_id = RT1.receipt_id
	AND RT1.transporter_sequence_id = 1
LEFT OUTER JOIN Transporter ON Transporter.transporter_code = Receipt.hauler
LEFT OUTER JOIN dbo.ReceiptManifest ON dbo.Receipt.company_id = dbo.ReceiptManifest.company_id
	AND dbo.Receipt.profit_ctr_id = dbo.ReceiptManifest.profit_ctr_id
	AND dbo.Receipt.receipt_id = dbo.ReceiptManifest.receipt_id	
	AND ReceiptManifest.page = 1
WHERE dbo.Receipt.company_id = #tmp_Copc.company_id  --@company_id
AND dbo.Receipt.profit_ctr_id = #tmp_Copc.profit_ctr_id  --@profit_ctr_id
AND Receipt.receipt_date BETWEEN @date_from AND @date_to
AND dbo.Receipt.fingerpr_status = 'A'
AND Receipt.receipt_status = 'A'
AND Receipt.trans_mode = 'O'
AND Receipt.manifest_flag IN ('M', 'C')
AND EXISTS (SELECT 1 FROM ReceiptwasteCode RWC JOIN Wastecode W ON RWC.waste_code = W.waste_code WHERE 
				Receipt.company_id = RWC.company_id
				AND Receipt.profit_ctr_id = RWC.profit_ctr_id
				AND Receipt.receipt_id = RWC.receipt_id
				AND Receipt.line_id = RWC.line_id
				AND W.haz_flag = 'T'
				AND (W.waste_code_origin = 'F' OR (W.waste_code_origin = 'S' and W.state = 'MI'))
				)
						
INSERT INTO #GNRTR_DTL
SELECT 
	Receipt.manifest
,	Receipt.manifest_line
,	Receipt.manifest_UN_NA_number
,	Receipt.container_count
,	Receipt.manifest_container_code
,	Receipt.manifest_quantity
,	Receipt.manifest_unit
,	NULL
,	NULL
,	NULL
,	NULL
,	NULL
,	NULL
,	Receipt.receipt_id
,	Receipt.line_id
,	Receipt.company_id
,	Receipt.profit_ctr_id		
FROM dbo.Receipt(nolock)
JOIN dbo.Generator ON Generator.generator_id = dbo.Receipt.generator_id
JOIN TSDF ON TSDF.tsdf_code = Receipt.tsdf_code AND TSDF.tsdf_status = 'A'
Join #tmp_Copc
   	ON #tmp_Copc.company_id = Receipt.company_id
	AND #tmp_Copc.profit_ctr_id = Receipt.profit_ctr_id
WHERE dbo.Receipt.company_id =  #tmp_Copc.company_id --@company_id
AND dbo.Receipt.profit_ctr_id =  #tmp_Copc.profit_ctr_id --@profit_ctr_id
AND Receipt.receipt_date BETWEEN @date_from AND @date_to
AND dbo.Receipt.fingerpr_status = 'A'
AND Receipt.receipt_status = 'A'
AND Receipt.trans_mode = 'O'
AND Receipt.manifest_flag IN ('M', 'C')
AND EXISTS (SELECT 1 FROM ReceiptwasteCode RWC JOIN Wastecode W ON RWC.waste_code = W.waste_code WHERE 
				Receipt.company_id = RWC.company_id
				AND Receipt.profit_ctr_id = RWC.profit_ctr_id
				AND Receipt.receipt_id = RWC.receipt_id
				AND Receipt.line_id = RWC.line_id
				AND W.haz_flag = 'T'
				AND (W.waste_code_origin = 'F' OR (W.waste_code_origin = 'S' and W.state = 'MI'))
				)

-- UPdate with Waste Codes
Update #GNRTR_DTL Set waste_code1 = RW.waste_code FROM ReceiptWasteCode RW WHERE RW.receipt_id = #GNRTR_DTL.receipt_id AND RW.company_id = #GNRTR_DTL.company_id AND RW.profit_ctr_id = #GNRTR_DTL.profit_ctr_id AND RW.line_id = #GNRTR_DTL.line_id and RW.sequence_id = 1	
Update #GNRTR_DTL Set waste_code2 = RW.waste_code FROM ReceiptWasteCode RW WHERE RW.receipt_id = #GNRTR_DTL.receipt_id AND RW.company_id = #GNRTR_DTL.company_id AND RW.profit_ctr_id = #GNRTR_DTL.profit_ctr_id AND RW.line_id = #GNRTR_DTL.line_id and RW.sequence_id = 2	
Update #GNRTR_DTL Set waste_code3 = RW.waste_code FROM ReceiptWasteCode RW WHERE RW.receipt_id = #GNRTR_DTL.receipt_id AND RW.company_id = #GNRTR_DTL.company_id AND RW.profit_ctr_id = #GNRTR_DTL.profit_ctr_id AND RW.line_id = #GNRTR_DTL.line_id and RW.sequence_id = 3	
Update #GNRTR_DTL Set waste_code4 = RW.waste_code FROM ReceiptWasteCode RW WHERE RW.receipt_id = #GNRTR_DTL.receipt_id AND RW.company_id = #GNRTR_DTL.company_id AND RW.profit_ctr_id = #GNRTR_DTL.profit_ctr_id AND RW.line_id = #GNRTR_DTL.line_id and RW.sequence_id = 4	
Update #GNRTR_DTL Set waste_code5 = RW.waste_code FROM ReceiptWasteCode RW WHERE RW.receipt_id = #GNRTR_DTL.receipt_id AND RW.company_id = #GNRTR_DTL.company_id AND RW.profit_ctr_id = #GNRTR_DTL.profit_ctr_id AND RW.line_id = #GNRTR_DTL.line_id and RW.sequence_id = 5	
Update #GNRTR_DTL Set waste_code6 = RW.waste_code FROM ReceiptWasteCode RW WHERE RW.receipt_id = #GNRTR_DTL.receipt_id AND RW.company_id = #GNRTR_DTL.company_id AND RW.profit_ctr_id = #GNRTR_DTL.profit_ctr_id AND RW.line_id = #GNRTR_DTL.line_id and RW.sequence_id = 6	

-- Select resultset
if @result_set_return = 1 
begin
	Select * from #TSDF_HDR Order By Manifest
end

if @result_set_return = 2
begin
	Select * from #TSDF_DTL Order By Manifest
end

if @result_set_return = 3 
begin	
	Select * from #GNRTR_HDR Order By Manifest
end

if @result_set_return = 4 
begin
	Select * from #GNRTR_DTL Order By Manifest
end

--DROP TABLE #TSDF_HDR
DROP TABLE  #TSDF_DTL
DROP TABLE  #GNRTR_HDR
DROP TABLE  #GNRTR_DTL

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_reports_manifest_quarterly_extract] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_reports_manifest_quarterly_extract] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_reports_manifest_quarterly_extract] TO [EQAI]
    AS [dbo];

