
CREATE PROCEDURE sp_biennial_report_worksheet_WR_wastecodes (
	@biennial_id	int,
	@state			varchar(2)
)
AS
/* **********************************************************************************
02/13/2012 SK created
Fetches the wastecodes that were reported in the WR extract

02/17/2012 Removed join to .WasteCode, not needed here, as we already have the right data at this stage.

use eq_extract
sp_help BiennialReportSourceData
sp_help BiennialReportSourcewastecode

create index idx_wastecode_join on BiennialReportSourceWasteCode (biennial_id, receipt_id, line_id, container_id, sequence_id, company_id, profit_ctr_id)
create index idx_wastecode_join on BiennialReportSourceData (biennial_id, receipt_id, line_id, container_id, sequence_id, company_id, profit_ctr_id)

	ON SD.biennial_id = SW.biennial_id
	AND SD.RECEIPT_ID = SW.RECEIPT_ID AND SD.LINE_ID = SW.LINE_ID
	AND SD.CONTAINER_ID = SW.CONTAINER_ID AND SD.SEQUENCE_ID = SW.SEQUENCE_ID
	AND SD.company_id = SW.company_id AND SD.profit_ctr_id = SW.profit_ctr_id

sp_biennial_report_worksheet_WR_wastecodes 1434, 'FL'

select max(sequence_id) from EQ_Extract..BiennialReportSourceWasteCode
SELECT * FROM eq_temp..sp_biennial_report_worksheet_WR_wastecodes

*********************************************************************************** */
if object_id('eq_temp..sp_biennial_report_worksheet_WR_wastecodes') is not null drop table eq_temp..sp_biennial_report_worksheet_WR_wastecodes

declare @maxlen int = 200

SELECT DISTINCT
	SW.biennial_id
,	SW.company_id
,	SW.profit_ctr_id
,	SW.receipt_id
,	SW.line_id
,  NULL as container_id
, NULL as sequence_id
, case when datalength(dbo.fn_receipt_waste_code_list_long(SW.company_id, SW.profit_ctr_id, SW.receipt_id, SW.line_id)) > @maxlen 
	then left(dbo.fn_receipt_waste_code_list_long(SW.company_id, SW.profit_ctr_id, SW.receipt_id, SW.line_id), @maxlen) + ' ... More: See Receipt'
	else dbo.fn_receipt_waste_code_list_long(SW.company_id, SW.profit_ctr_id, SW.receipt_id, SW.line_id)
	end as waste_code
-- ,	SW.container_id
-- ,	SW.sequence_id
-- ,	SW.waste_code
INTO eq_temp..sp_biennial_report_worksheet_WR_wastecodes
FROM EQ_Extract..BiennialReportSourceData SD
JOIN EQ_Extract..BiennialReportSourceWasteCode SW 
	ON SD.biennial_id = SW.biennial_id
	AND SD.RECEIPT_ID = SW.RECEIPT_ID AND SD.LINE_ID = SW.LINE_ID
	AND SD.CONTAINER_ID = SW.CONTAINER_ID AND SD.SEQUENCE_ID = SW.SEQUENCE_ID
	AND SD.company_id = SW.company_id AND SD.profit_ctr_id = SW.profit_ctr_id
WHERE SD.biennial_id = @biennial_id
	AND SD.TRANS_MODE = 'I'

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_biennial_report_worksheet_WR_wastecodes] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_biennial_report_worksheet_WR_wastecodes] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_biennial_report_worksheet_WR_wastecodes] TO [EQAI]
    AS [dbo];

