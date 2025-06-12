drop proc if exists sp_biennial_report_worksheet_GM_IL 
go
CREATE PROCEDURE sp_biennial_report_worksheet_GM_IL (
	@biennial_id	int,
	@state			varchar(2)
)
AS
/* **********************************************************************************
Selects from the source data, all that was reported for GM for Illinois
History:	02/13/2012 SK created
			02/22/2012 SK Modified the select to match the changes on sp_biennial_report_output_IL_GM
sp_help BiennialReportSourcedata

EXEC sp_biennial_report_worksheet_GM_IL 1457, 'IL'

*********************************************************************************** */

-- if object_id('eq_temp..sp_biennial_report_output_worksheet_GM_IL') is not null drop table eq_temp..sp_biennial_report_output_worksheet_Gm_IL

delete from eq_temp..sp_biennial_report_output_worksheet_Gm_IL

insert eq_temp..sp_biennial_report_output_worksheet_Gm_IL
SELECT DISTINCT
	SD.TRANS_MODE 
,	SD.Company_id 
,	SD.profit_ctr_id 
,	LEFT(SD.profit_ctr_epa_id + space(12), 12) AS HANDLER_ID 
,	SD.receipt_id
,	SD.line_id
,	container_id
,	sequence_id
,	SD.treatment_id
,	lbs_haz_estimated AS LBS_HAZ
,	lbs_actual_match = CASE lbs_haz_estimated WHEN lbs_haz_actual THEN 'T' ELSE 'F' END
,	gal_haz_actual AS GAL_HAZ
,	yard_haz_actual AS YARD_HAZ
,	SD.manifest
,	SD.manifest_line_id
,	SD.approval_code
,	LEFT(IsNull(SD.EPA_FORM_CODE,' ') + SPACE(4), 4) as FORM_CODE
,	SD.EPA_source_code
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
,	CASE WHEN ISNULL(sd.yard_haz_actual,0) <> 0 and ISNULL(sd.gal_haz_actual,0) = 0 THEN 2 -- yards
		 WHEN ISNULL(sd.gal_haz_actual,0) <> 0 and ISNULL(sd.yard_haz_actual,0) = 0 THEN 1 -- gallons
		 WHEN ISNULL(sd.gal_haz_actual,0) <> 0 and ISNULL(sd.yard_haz_actual,0) <> 0 and sd.waste_consistency LIKE '%LIQUID%' THEN 1 -- gallons
		 WHEN ISNULL(sd.gal_haz_actual,0) <> 0 and ISNULL(sd.yard_haz_actual,0) <> 0 and sd.waste_consistency NOT LIKE '%LIQUID%' THEN 2 -- yards
		 ELSE 3 -- pounds
	END AS UNIT_OF_MEASURE
,	CONVERT(VARCHAR(4), CONVERT(NUMERIC(4,2), SD.waste_density)) as WST_DENSITY
,	RIGHT(space(10) + ISNULL(convert(varchar(10), convert(numeric(10,1), 
				SUM(
					CASE WHEN ISNULL(sd.yard_haz_actual,0) <> 0 and ISNULL(sd.gal_haz_actual,0) = 0 then isnull(sd.yard_haz_actual, 0)
						when ISNULL(sd.gal_haz_actual,0) <> 0 and ISNULL(sd.yard_haz_actual,0) = 0 then isnull(sd.gal_haz_actual, 0)
						when ISNULL(sd.gal_haz_actual,0) <> 0 and ISNULL(sd.yard_haz_actual,0) <> 0 and sd.waste_consistency LIKE '%LIQUID%' 
							THEN isnull(sd.gal_haz_actual, 0)
						when ISNULL(sd.gal_haz_actual,0) <> 0 and ISNULL(sd.yard_haz_actual,0) <> 0 and sd.waste_consistency NOT LIKE '%LIQUID%' 
							THEN isnull(sd.yard_haz_actual, 0)
						ELSE isnull(lbs_haz_estimated, 0)
					END
				))),''), 10) as IO_TDR_QTY
,	LEFT(SD.TSDF_EPA_ID + space(12), 12) AS SITE_1_US_EPAID_NUMBER
,	LEFT(COALESCE(ta.management_code, trmt.management_code, '') + SPACE(4), 4) as SITE_1_MANAGEMENT_METHOD
,	RIGHT(space(10) + ISNULL(convert(varchar(10), convert(numeric(10,1), 
				SUM(
					CASE WHEN ISNULL(sd.yard_haz_actual,0) <> 0 and ISNULL(sd.gal_haz_actual,0) = 0 then isnull(sd.yard_haz_actual, 0)
						when ISNULL(sd.gal_haz_actual,0) <> 0 and ISNULL(sd.yard_haz_actual,0) = 0 then isnull(sd.gal_haz_actual, 0)
						when ISNULL(sd.gal_haz_actual,0) <> 0 and ISNULL(sd.yard_haz_actual,0) <> 0 and sd.waste_consistency LIKE '%LIQUID%' 
							THEN isnull(sd.gal_haz_actual, 0)
						when ISNULL(sd.gal_haz_actual,0) <> 0 and ISNULL(sd.yard_haz_actual,0) <> 0 and sd.waste_consistency NOT LIKE '%LIQUID%' 
							THEN isnull(sd.yard_haz_actual, 0)
						ELSE isnull(lbs_haz_estimated, 0)
					END
				))),''), 10) as SITE_1_TOTAL_QUANTITY_SHIPPED
,	TSDF_name
,	TSDF_addr1
,	TSDF_addr2
,	TSDF_addr3
,	TSDF_city
,	TSDF_state
,	TSDF_zip_code
,	LEFT(IsNull(SD.waste_desc,' ') + SPACE(50), 50) as DESCRIPTION
,	waste_consistency
--INTO eq_temp..sp_biennial_report_output_worksheet_GM_IL
FROM EQ_Extract..BiennialReportSourceData SD
INNER JOIN Receipt r
	on r.receipt_id = SD.receipt_id
	and r.line_id = SD.line_id
	and r.company_id = SD.company_id
	and r.profit_ctr_id = SD.profit_ctr_id
	and r.trans_mode = SD.trans_mode
LEFT OUTER JOIN TSDFApproval ta
	on r.tsdf_approval_id = ta.tsdf_approval_id
	and r.company_id = ta.company_id
	and r.profit_ctr_id = ta.profit_ctr_id
LEFT OUTER JOIN ProfileQuoteApproval pqa
	on r.ob_profile_id = pqa.profile_id
	and r.ob_profile_company_id = pqa.company_id
	and r.ob_profile_profit_ctr_id = pqa.profit_ctr_id
LEFT OUTER JOIN Treatment trmt
	on pqa.treatment_id = trmt.treatment_id
	AND pqa.company_id = trmt.company_id
	AND pqa.profit_ctr_id = trmt.profit_ctr_id
WHERE biennial_id = @biennial_id
AND SD.TRANS_MODE = 'O'
GROUP BY
	SD.TRANS_MODE 
,	SD.Company_id 
,	SD.profit_ctr_id 
,	LEFT(SD.profit_ctr_epa_id + space(12), 12)
,	SD.receipt_id
,	SD.line_id
,	container_id
,	sequence_id
,	SD.treatment_id
,	lbs_haz_estimated
,	lbs_haz_actual
,	gal_haz_actual
,	yard_haz_actual
,	SD.manifest
,	SD.manifest_line_id
,	SD.approval_code
,	LEFT(IsNull(SD.EPA_FORM_CODE,' ') + SPACE(4), 4)
,	SD.EPA_source_code
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
,	CASE WHEN ISNULL(sd.yard_haz_actual,0) <> 0 and ISNULL(sd.gal_haz_actual,0) = 0 THEN 2 -- yards
		 WHEN ISNULL(sd.gal_haz_actual,0) <> 0 and ISNULL(sd.yard_haz_actual,0) = 0 THEN 1 -- gallons
		 WHEN ISNULL(sd.gal_haz_actual,0) <> 0 and ISNULL(sd.yard_haz_actual,0) <> 0 and sd.waste_consistency LIKE '%LIQUID%' THEN 1 -- gallons
		 WHEN ISNULL(sd.gal_haz_actual,0) <> 0 and ISNULL(sd.yard_haz_actual,0) <> 0 and sd.waste_consistency NOT LIKE '%LIQUID%' THEN 2 -- yards
		 ELSE 3 -- pounds
	END
,	SD.waste_density
,	LEFT(SD.TSDF_EPA_ID + space(12), 12)
,	LEFT(COALESCE(ta.management_code, trmt.management_code, '') + SPACE(4), 4)
,	TSDF_name
,	TSDF_addr1
,	TSDF_addr2
,	TSDF_addr3
,	TSDF_city
,	TSDF_state
,	TSDF_zip_code
,	LEFT(IsNull(SD.waste_desc,' ') + SPACE(50), 50)
,	waste_consistency

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_biennial_report_worksheet_GM_IL] TO [EQWEB]

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_biennial_report_worksheet_GM_IL] TO [COR_USER]

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_biennial_report_worksheet_GM_IL] TO [EQAI]

