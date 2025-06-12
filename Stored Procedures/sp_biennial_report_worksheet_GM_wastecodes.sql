
CREATE PROCEDURE sp_biennial_report_worksheet_GM_wastecodes (
	@biennial_id	int,
	@state			varchar(2)
)
AS
/* **********************************************************************************
02/13/2012 SK created
Fetches the wastecodes that were reported in the GM extract for all states

02/17/2012 SK added company, profit ctr join to source, removed join to WAStecode
			Changed to use the waste code list function

sp_help BiennialReportSourcewastecode
sp_biennial_report_worksheet_GM_wastecodes 1424, 'FL'

*********************************************************************************** */

if object_id('eq_temp..sp_biennial_report_worksheet_GM_wastecodes') is not null drop table eq_temp..sp_biennial_report_worksheet_GM_wastecodes

SELECT 
	SW.biennial_id
,	SW.company_id
,	SW.profit_ctr_id
,	SW.receipt_id
,	SW.line_id
,	NULL as container_id
,	NULL as sequence_id
, dbo.fn_receipt_waste_code_list_long(SW.company_id, SW.profit_ctr_id, SW.receipt_id, SW.line_id) as waste_code
INTO eq_temp..sp_biennial_report_worksheet_GM_wastecodes
FROM EQ_Extract..BiennialReportSourceData SD
JOIN EQ_Extract..BiennialReportSourceWasteCode SW 
	ON SD.biennial_id = SW.biennial_id
	AND SD.RECEIPT_ID = SW.RECEIPT_ID AND SD.LINE_ID = SW.LINE_ID
	AND SD.CONTAINER_ID = SW.CONTAINER_ID AND SD.SEQUENCE_ID = SW.SEQUENCE_ID
	AND SD.company_id = SW.company_id AND SD.profit_ctr_id = SW.profit_ctr_id
WHERE SD.biennial_id = @biennial_id
	AND SD.TRANS_MODE = 'O'

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_biennial_report_worksheet_GM_wastecodes] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_biennial_report_worksheet_GM_wastecodes] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_biennial_report_worksheet_GM_wastecodes] TO [EQAI]
    AS [dbo];

