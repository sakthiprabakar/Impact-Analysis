
CREATE PROCEDURE sp_biennial_report_worksheet_WR (
	@biennial_id	int,
	@state			varchar(2)
)
AS
/* **********************************************************************************
02/13/2012 SK created
Selects from the source data, the data for WR worksheet for all states other than IL

sp_help BiennialReportSourcedata


sp_biennial_report_worksheet_WR 1110, 'OH'

*********************************************************************************** */

if object_id('eq_temp..sp_biennial_report_output_worksheet_WR') is not null drop table eq_temp..sp_biennial_report_output_worksheet_WR

SELECT DISTINCT
	TRANS_MODE 
,	Company_id 
,	profit_ctr_id 
,	profit_ctr_epa_id  
,	receipt_id
,	line_id
,	container_id
,	sequence_id
,	treatment_id
,	management_code
,	lbs_haz_estimated AS LBS_HAZ
,	lbs_actual_match = CASE lbs_haz_estimated WHEN lbs_haz_actual THEN 'T' ELSE 'F' END
,	manifest
,	manifest_line_id
,	approval_code
,	EPA_form_code 
,	EPA_source_code
,	waste_desc
,	waste_density
,	waste_consistency
,	eq_generator_id
,	generator_epa_id
,	generator_name
,	generator_address_1 
,	generator_address_2
,	generator_address_3 
,	generator_address_4  
,	generator_address_5
,	generator_city
,	generator_state
,	generator_zip_code
,	generator_state_id
,	transporter_EPA_ID
,	transporter_name 
,	transporter_addr1
,	transporter_addr2
,	transporter_addr3
,	transporter_city 
,	transporter_state 
,	transporter_zip_code
,	TSDF_EPA_ID 
,	TSDF_name
,	TSDF_addr1
,	TSDF_addr2
,	TSDF_addr3
,	TSDF_city
,	TSDF_state
,	TSDF_zip_code
INTO eq_temp..sp_biennial_report_output_worksheet_WR
FROM EQ_Extract..BiennialReportSourceData SD
WHERE biennial_id = @biennial_id
AND SD.TRANS_MODE = 'I'


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_biennial_report_worksheet_WR] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_biennial_report_worksheet_WR] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_biennial_report_worksheet_WR] TO [EQAI]
    AS [dbo];

