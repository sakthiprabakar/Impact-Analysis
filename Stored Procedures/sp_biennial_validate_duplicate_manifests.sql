
CREATE PROCEDURE sp_biennial_validate_duplicate_manifests
	@biennial_id int
AS

/*
	Usage: sp_biennial_validate_duplicate_manifest 96;	
*/
BEGIN

	declare @newline varchar(5) = char(10)+char(13)
	

	/* create test duplicate manifest - for testing only*/	
	--INSERT EQ_Extract..BiennialReportSourceDataValidation(rowid, biennial_id, data_source, enviroware_manifest_document, enviroware_manifest_document_line, TRANS_MODE, Company_id, profit_ctr_id, profit_ctr_epa_id, receipt_id, line_id, container_id, sequence_id, treatment_id, management_code, lbs_haz_estimated, lbs_haz_actual, gal_haz_estimated, gal_haz_actual, yard_haz_estimated, yard_haz_actual, container_percent, manifest, manifest_line_id, approval_code, EPA_form_code, EPA_source_code, waste_desc, waste_density, generator_epa_id, generator_name, generator_address_1, generator_address_2, generator_address_3, generator_address_4, generator_address_5, generator_city, generator_state, generator_zip_code, transporter_EPA_ID, transporter_name, transporter_addr1, transporter_addr2, transporter_addr3, transporter_city, transporter_state, transporter_zip_code, TSDF_EPA_ID, TSDF_name, TSDF_addr1, TSDF_addr2, TSDF_addr3, TSDF_city, TSDF_state, TSDF_zip_code)
	--	SELECT rowid, biennial_id, 'EQAI', enviroware_manifest_document, enviroware_manifest_document_line, TRANS_MODE, Company_id, profit_ctr_id, profit_ctr_epa_id, receipt_id, line_id, container_id, sequence_id, treatment_id, management_code, lbs_haz_estimated, lbs_haz_actual, gal_haz_estimated, gal_haz_actual, yard_haz_estimated, yard_haz_actual, container_percent, manifest, manifest_line_id, approval_code, EPA_form_code, EPA_source_code, waste_desc, waste_density, generator_epa_id, generator_name, generator_address_1, generator_address_2, generator_address_3, generator_address_4, generator_address_5, generator_city, generator_state, generator_zip_code, transporter_EPA_ID, transporter_name, transporter_addr1, transporter_addr2, transporter_addr3, transporter_city, transporter_state, transporter_zip_code, TSDF_EPA_ID, TSDF_name, TSDF_addr1, TSDF_addr2, TSDF_addr3, TSDF_city, TSDF_state, TSDF_zip_code FROM EQ_Extract..BiennialReportSourceData
	--	where manifest= '001591306FLE'
	
	
	SELECT COUNT(DISTINCT manifest) manifest_count, manifest 
	INTO #duplicate_manifest
	FROM EQ_Extract..BiennialReportSourceData vt
	group by manifest, biennial_id, data_source
	having biennial_id = @biennial_id
	AND data_source = 'EQAI'
	AND vt.biennial_id = @biennial_id
	AND EXISTS (SELECT 1
		FROM EQ_Extract..BiennialReportSourceData vt_tmp
		WHERE biennial_id = @biennial_id	
		AND data_source = 'ENVIROWARE'	
		AND vt.manifest = vt_tmp.manifest
		AND vt.biennial_id = @biennial_id
		AND vt.biennial_id = vt_tmp.biennial_id
	)
	
	UNION
	
	SELECT COUNT(DISTINCT manifest) manifest_count, manifest 
	FROM EQ_Extract..BiennialReportSourceData vt
	group by manifest, biennial_id, data_source
	having biennial_id = @biennial_id
	AND data_source = 'ENVIROWARE'
	AND vt.biennial_id = @biennial_id
	AND EXISTS (SELECT 1
		FROM EQ_Extract..BiennialReportSourceData vt_tmp
		WHERE biennial_id = @biennial_id	
		AND data_source = 'EQAI'	
		AND vt.manifest = vt_tmp.manifest
		AND vt.biennial_id = @biennial_id
		AND vt.biennial_id = vt_tmp.biennial_id
	)	
	
	INSERT INTO EQ_Extract..BiennialReportSourceDataValidation 
		SELECT 'Duplicate manifest entry between EQAI and ENVIROWARE: ' + src.manifest
		, src.*
	FROM EQ_Extract..BiennialReportSourceData src
		INNER JOIN #duplicate_manifest dupe ON dupe.manifest = src.manifest
		AND src.biennial_id = @biennial_id
		
END


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_biennial_validate_duplicate_manifests] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_biennial_validate_duplicate_manifests] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_biennial_validate_duplicate_manifests] TO [EQAI]
    AS [dbo];

