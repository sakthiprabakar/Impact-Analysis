/*

-- Commented 6/25/2019 - JPB - error deploying to misousqldev01, seems like deprecated code.

CREATE PROCEDURE sp_biennial_report_source_enviroware
	@biennial_id	int = null, -- if not specified, will create a new run
	@Company	varchar(5),	-- '2|21, 25|00' etc.
	@start_date datetime,
	@end_date datetime,
	@user_code	varchar(10) -- 'JONATHAN' (or SYSTEM_USER)
AS
/-*
	This procedure should only be used for accessing the 2010 Envirite data (OH or IL data specifically)
	If you want to get the EQAI data for 2010, use the 'sp_biennial_report_source' procedure
	Usage: sp_biennial_report_source_enviroware;	
	
exec	sp_biennial_report_source_enviroware NULL, '26|00', '1/1/2010', '12/31/2010 23:59:59', 'RICH_G'	
exec	sp_biennial_report_source_enviroware NULL, '25|00', '2010', 'RICH_G'
exec	sp_biennial_report_source_enviroware NULL, '26|00', '2010', 'RICH_G'
	
	--query to get latest run for a given co/pc
	
	declare @company_id int = 25
	declare @profit_ctr_id int = 0
	declare @data_source varchar(20) = 'ENVIROWARE' -- can be either 'EQAI' or 'ENVIROWARE'
	SELECT * FROM BiennialReportSourceData
		WHERE company_id = @company_id
		AND profit_ctr_id = @profit_ctr_id
		AND data_source = @data_source
		AND biennial_id = (
			SELECT max(biennial_id) FROM BiennialReportSourceData
			WHERE company_id = @company_id
			AND profit_ctr_id = @profit_ctr_id
			AND data_source = @data_source
		)
*-/
BEGIN
	
	

-- Setup
	DECLARE @is_new_run char(1) = 'F'
	if @biennial_id is null set @is_new_run = 'T'
		
	DECLARE @waste_density varchar(6) = '8.3453'
	DECLARE @data_source varchar(10) = 'ENVIROWARE'
	--DECLARE @user_code varchar(20) = 'RICH_G'
	
	declare @debug int = 0
	
	-- Get run id's
	DECLARE @company_id int,
			@profit_ctr_id int,
			@profit_ctr_epa_id varchar(20)
		
	SELECT @company_id = convert(int, Rtrim(Ltrim(Substring(row, 1, Charindex('|', row) - 1)))),
		@profit_ctr_id = convert(int, Rtrim(Ltrim(Substring(row, Charindex('|', row) + 1, Len(row) - (Charindex('|', row) - 1)))))
	FROM dbo.fn_splitxsvtext(',', 1, @Company) WHERE Isnull(row, '') <> ''	
	
	set @end_date = DATEADD(DAY, 1, @end_date)
	set @end_date = DATEADD(s,-1,@end_date)
	
	-- Since this is Envirite stuff from Enviroware, it is only good for 2010 since we migrated to EQAI after the acquisition
	--DECLARE @start_date datetime = convert(datetime, '1/1/' + convert(varchar(4), @year))
	--declare @end_date datetime = dateadd(ms, -3, dateadd(yyyy, 1, @start_date))
	
	declare @company_xref table (
		eq_company_id int,
		eq_profit_ctr_id int,
		envirite_company_id int
	)	
	
	INSERT INTO @company_xref VALUES (25, 0, 1022) -- Envirite OH
	INSERT INTO @company_xref VALUES (26, 0, 1019) -- Envirite IL
	INSERT INTO @company_xref VALUES (27, 0, 1025) -- Envirite PA
	
	DELETE FROM @company_xref where eq_company_id <> @company_id
		
	
	-- Holder for the current run id, run_start
	declare @date_added datetime = getdate()
	

	if object_id('tempdb..#envirite_biennial_staging') is not null drop table #envirite_biennial_staging

	SELECT @profit_ctr_epa_id = epa_id from ProfitCenter where company_id = @company_id and profit_ctr_id = @profit_ctr_id	

	-- Log the current run
	insert EQ_Extract..BiennialLog
	select 
		COALESCE(@biennial_id, (select isnull(max(biennial_id), 0) + 1 from EQ_Extract..BiennialLog)) as biennial_id,
		@company,
		@start_date,
		@end_date,
		@user_code,
		@date_added,
		@date_added,
		null

	if @biennial_id is null
	begin
		-- Capture the current run id		
		select TOP 1
			@biennial_id = biennial_id 
		from EQ_Extract..BiennialLog
		where added_by = @user_code
			and date_added = @date_added
	end

	SELECT biennial_id, data_source, enviroware_manifest_document, enviroware_manifest_document_line, TRANS_MODE, Company_id, profit_ctr_id, profit_ctr_epa_id, receipt_id, line_id, container_id, sequence_id, treatment_id, management_code, lbs_haz_estimated, lbs_haz_actual, gal_haz_estimated, gal_haz_actual, yard_haz_estimated, yard_haz_actual, container_percent, manifest, manifest_line_id, approval_code, EPA_form_code, EPA_source_code, waste_desc, waste_density, generator_epa_id, generator_name, generator_address_1, generator_address_2, generator_address_3, generator_address_4, generator_address_5, generator_city, generator_state, generator_zip_code, generator_state_id, transporter_EPA_ID, transporter_name, transporter_addr1, transporter_addr2, transporter_addr3, transporter_city, transporter_state, transporter_zip_code, TSDF_EPA_ID, TSDF_name, TSDF_addr1, TSDF_addr2, TSDF_addr3, TSDF_city, TSDF_state, TSDF_zip_code
	INTO #envirite_biennial_staging
	FROM EQ_Extract.dbo.BiennialReportSourceData
	WHERE 1=0

--delete from BiennialReportSourceData where data_source = @data_source and biennial_id = @biennial_id
	
INSERT INTO EQ_Extract.dbo.BiennialReportSourceData (biennial_id, data_source, enviroware_manifest_document, enviroware_manifest_document_line, TRANS_MODE, Company_id, profit_ctr_id, profit_ctr_epa_id, receipt_id, line_id, container_id, sequence_id, treatment_id, management_code, lbs_haz_estimated, lbs_haz_actual, gal_haz_estimated, gal_haz_actual, yard_haz_estimated, yard_haz_actual, container_percent, manifest, manifest_line_id, approval_code, EPA_form_code, EPA_source_code, waste_desc, waste_density, generator_epa_id, generator_name, generator_address_1, generator_address_2, generator_address_3, generator_address_4, generator_address_5, generator_city, generator_state, generator_zip_code, generator_state_id, transporter_EPA_ID, transporter_name, transporter_addr1, transporter_addr2, transporter_addr3, transporter_city, transporter_state, transporter_zip_code, TSDF_EPA_ID, TSDF_name, TSDF_addr1, TSDF_addr2, TSDF_addr3, TSDF_city, TSDF_state, TSDF_zip_code)
SELECT 
		@biennial_id AS biennial_id
       ,@data_source AS data_source
       ,ml.DOCUMENT
       ,ml.DOCUMENT_LINE
       ,'I' AS TRANS_MODE -- Inbound
       ,company_xref.eq_company_id as company_id
       ,company_xref.eq_profit_ctr_id as profit_ctr_id
       ,@profit_ctr_epa_id AS profit_ctr_epa_id
       ,NULL AS receipt_id
       ,NULL AS line_id
       ,NULL AS container_id
       ,NULL AS sequence_id
       ,pqa.treatment_id AS treatment_id
       ,pm.MANAGEMENT_METHOD_CODE AS management_code
       ,NULL as lbs_haz_estimated       
       ,CASE 
			WHEN ml.UM_WEIGHT = 'LBS' OR ml.um_weight = 'LB' THEN ROUND(ISNULL(ml.WEIGHT, 0), 2)
			WHEN ml.UM_WEIGHT = 'TON' THEN ROUND(ISNULL(ml.WEIGHT, 0), 2) * 2000
		END AS lbs_haz_actual
		,NULL as gal_haz_estimated		
	   ,CASE 
			WHEN ml.UM_VOLUME = 'GAL' THEN ROUND(ISNULL(ml.VOLUME, 0), 2)
		END as gal_haz_actual
		,NULL as yard_haz_estimated		
	   ,CASE 
			WHEN ml.UM_VOLUME = 'CY' THEN ROUND(ISNULL(ml.VOLUME, 0), 2)
		END as yard_haz_actual
       ,100 AS container_percent
       ,mm.STATE_MANIFEST AS manifest
       ,NULL AS manifest_line_id
       ,pqa.approval_code AS approval_code
       ,pm.FORM_CODE AS EPA_form_code
       ,pm.SOURCE_CODE AS EPA_source_code
       ,eq_profile.approval_desc AS waste_desc
       ,COALESCE(
			profilelab.density  
			,@waste_density) as waste_density
       ,eq_gen.EPA_ID AS generator_epa_id
       ,eq_gen.generator_name AS generator_name
       ,eq_gen.gen_mail_addr1 AS generator_address_1
       ,eq_gen.generator_address_2 AS generator_address_2
       ,eq_gen.generator_address_3 AS generator_address_3
       ,eq_gen.generator_address_4 AS generator_address_4
       ,eq_gen.generator_address_5 AS generator_address_5
       ,eq_gen.generator_city AS generator_city
       ,eq_gen.generator_state AS generator_state
       ,eq_gen.generator_zip_code AS generator_zip_code
       ,eq_gen.state_id as generator_state_id
       ,ew_transporter.EPA_ID AS transporter_EPA_ID
       ,CONVERT(varchar(40), ew_transporter.DIVISION_NAME) AS transporter_name
       ,ew_transporter.ADDRESS_1 AS transporter_addr1
       ,ew_transporter.ADDRESS_2 AS transporter_addr2
       ,NULL AS transporter_addr3
       ,ew_transporter.CITY AS transporter_city
       ,ew_transporter.STATE AS transporter_state
       ,ew_transporter.ZIP AS transporter_zip_code
       ,tsdf.EPA_ID AS TSDF_EPA_ID
       ,tsdf.DIVISION_NAME AS TSDF_name
       ,tsdf.ADDRESS_1 AS TSDF_addr1
       ,tsdf.ADDRESS_2 AS TSDF_addr2
       ,NULL AS TSDF_addr3
       ,tsdf.CITY AS TSDF_city
       ,tsdf.STATE AS TSDF_state
       ,tsdf.ZIP AS TSDF_zip_code
FROM   Envirite.dbo.load_master lm WITH(NOLOCK)
       INNER JOIN Envirite.dbo.load_detail ld WITH(NOLOCK)
         ON lm.LOAD = ld.LOAD
       INNER JOIN Envirite.dbo.company_master ew_generators WITH(NOLOCK)
         ON ew_generators.COMPANY = ld.GENERATOR_COMPANY
       INNER JOIN Envirite.dbo.company_master ew_transporter WITH(NOLOCK)
         ON ew_transporter.COMPANY = lm.TRANSPORTER
       INNER JOIN Envirite.dbo.profile_master pm WITH(NOLOCK)
         ON ld.PROFILE = pm.PROFILE
            AND pm.profile_type NOT LIKE '%O' -- do not include Outbound
       INNER JOIN Envirite.dbo.manifest_master mm WITH(NOLOCK)
         ON mm.LOAD = lm.LOAD
	   INNER JOIN Envirite.dbo.manifest_line ml  WITH(NOLOCK)
		ON ml.DOCUMENT = mm.DOCUMENT         
		AND ml.DOCUMENT = ld.DOCUMENT
		AND ml.DOCUMENT_LINE = ld.DOCUMENT_LINE
       INNER JOIN Envirite.dbo.ENVIRITE_ProfileXRef profile_xref WITH(NOLOCK)
         ON profile_xref.profile = ld.PROFILE
       INNER JOIN Profile eq_profile
         ON profile_xref.profile_id = eq_profile.profile_id
       --AND eq_profile.curr_status_code = 'A'
       INNER JOIN Envirite.dbo.ENVIRITE_GeneratorXRef generator_xref WITH(NOLOCK)
         ON ld.GENERATOR_COMPANY = generator_xref.envirite_generator
       INNER JOIN Generator eq_gen WITH(NOLOCK)
         ON generator_xref.eq_generator = eq_gen.generator_id
       INNER JOIN Envirite.dbo.company_master tsdf WITH(NOLOCK)
         ON tsdf.COMPANY = lm.DESTINATION
       INNER JOIN ProfileQuoteApproval pqa
         ON pqa.profile_id = eq_profile.profile_id
            AND pqa.status = 'A'
        INNER JOIN @company_xref company_xref  
		on company_xref.envirite_company_id = tsdf.COMPANY
        LEFT JOIN Envirite.dbo.ENVIRITE_BillUnitXref unit_xref  WITH(NOLOCK) ON
			unit_xref.envirite_um = ml.CONTAINER_TYPE
			AND unit_xref.envirite_container_size = ml.CONTAINER_SIZE
		LEFT JOIN BillUnit eq_BillUnit ON eq_BillUnit.bill_unit_code = unit_xref.bill_unit_code
		LEFT JOIN ProfileLab profilelab ON profile_xref.profile_id = ProfileLab.profile_id
			and profilelab.type = 'A'
WHERE lm.ARRIVED BETWEEN @start_date AND @end_date
 --AND EXISTS (        
	--	SELECT 1
 --       FROM   Envirite.dbo.ENVIRITE_ManifestWasteCodeList mwc WITH(NOLOCK)
 --              INNER JOIN WasteCode wc WITH(NOLOCK)
 --                ON mwc.WASTE_CODE = wc.waste_code
 --       WHERE  wc.haz_flag = 'T'
 --              AND mwc.DOCUMENT = mm.DOCUMENT 
	--)
	
       AND EXISTS (        
		SELECT 1
        FROM   Envirite.dbo.manifest_waste_codes mwc
               INNER JOIN WasteCode wc WITH(NOLOCK)
                 ON mwc.WASTE_CODE = wc.waste_code
                 AND mwc.DOCUMENT = ml.DOCUMENT
        WHERE  wc.haz_flag = 'T'
	)
	
	
       
       
if @debug > 0
begin
	SELECT ml.*
	FROM   Envirite.dbo.load_master lm WITH(NOLOCK)
       INNER JOIN Envirite.dbo.load_detail ld WITH(NOLOCK)
         ON lm.LOAD = ld.LOAD
       INNER JOIN Envirite.dbo.company_master ew_generators WITH(NOLOCK)
         ON ew_generators.COMPANY = ld.GENERATOR_COMPANY
       INNER JOIN Envirite.dbo.company_master ew_transporter WITH(NOLOCK)
         ON ew_transporter.COMPANY = lm.TRANSPORTER
       INNER JOIN Envirite.dbo.profile_master pm WITH(NOLOCK)
         ON ld.PROFILE = pm.PROFILE
            AND pm.profile_type NOT LIKE '%O' -- do not include Outbound
       INNER JOIN Envirite.dbo.manifest_master mm WITH(NOLOCK)
         ON mm.LOAD = lm.LOAD
	   INNER JOIN Envirite.dbo.manifest_line ml  WITH(NOLOCK)
		ON ml.DOCUMENT = mm.DOCUMENT         
		AND ml.DOCUMENT = ld.DOCUMENT
		AND ml.DOCUMENT_LINE = ld.DOCUMENT_LINE
       INNER JOIN Envirite.dbo.ENVIRITE_ProfileXRef profile_xref WITH(NOLOCK)
         ON profile_xref.profile = ld.PROFILE
       INNER JOIN Profile eq_profile
         ON profile_xref.profile_id = eq_profile.profile_id
       --AND eq_profile.curr_status_code = 'A'
       INNER JOIN Envirite.dbo.ENVIRITE_GeneratorXRef generator_xref WITH(NOLOCK)
         ON ld.GENERATOR_COMPANY = generator_xref.envirite_generator
       INNER JOIN Generator eq_gen WITH(NOLOCK)
         ON generator_xref.eq_generator = eq_gen.generator_id
       INNER JOIN Envirite.dbo.company_master tsdf WITH(NOLOCK)
         ON tsdf.COMPANY = lm.DESTINATION
       INNER JOIN ProfileQuoteApproval pqa
         ON pqa.profile_id = eq_profile.profile_id
            AND pqa.status = 'A'
        INNER JOIN @company_xref company_xref  
		on company_xref.envirite_company_id = tsdf.COMPANY
        LEFT JOIN Envirite.dbo.ENVIRITE_BillUnitXref unit_xref  WITH(NOLOCK) ON
			unit_xref.envirite_um = ml.CONTAINER_TYPE
			AND unit_xref.envirite_container_size = ml.CONTAINER_SIZE
		LEFT JOIN BillUnit eq_BillUnit ON eq_BillUnit.bill_unit_code = unit_xref.bill_unit_code
		LEFT JOIN ProfileLab profilelab ON profile_xref.profile_id = ProfileLab.profile_id
			and profilelab.type = 'A'
WHERE lm.ARRIVED BETWEEN @start_date AND @end_date
 --AND EXISTS (        
	--	SELECT 1
 --       FROM   Envirite.dbo.ENVIRITE_ManifestWasteCodeList mwc WITH(NOLOCK)
 --              INNER JOIN WasteCode wc WITH(NOLOCK)
 --                ON mwc.WASTE_CODE = wc.waste_code
 --       WHERE  wc.haz_flag = 'T'
 --              AND mwc.DOCUMENT = mm.DOCUMENT 
	--)
	
       AND EXISTS (        
		SELECT 1
        FROM   Envirite.dbo.manifest_waste_codes mwc
               INNER JOIN WasteCode wc WITH(NOLOCK)
                 ON mwc.WASTE_CODE = wc.waste_code
                 AND mwc.DOCUMENT = ml.DOCUMENT
        WHERE  wc.haz_flag = 'T'
	)

end
       

--biennial_id, data_source, profit_ctr_id, receipt_id, line_id, container_id, sequence_id, waste_code, enviroware_manifest_document, enviroware_manifest_document_line
INSERT INTO EQ_Extract..BiennialReportSourceWasteCode
SELECT DISTINCT @biennial_id
       ,'ENVIROWARE' as data_source
       ,NULL as company_id
       ,NULL as profit_ctr_id
       ,NULL as receipt_id
       ,NULL as line_id
       ,NULL as container_id
       ,NULL as sequence_id
       ,mwc.waste_code
       ,mwc.DOCUMENT as enviroware_manifest_document
       ,mwc.DOCUMENT_LINE as enviroware_manifest_document_line
--FROM   Envirite..ENVIRITE_ManifestWasteCodeList mwc
FROM Envirite..manifest_waste_codes mwc







--update #envirite_biennial_staging set profit_ctr_epa_id = pc.EPA_ID
--	FROM ProfitCenter pc WHERE #envirite_biennial_staging.company_id = pc.company_id
--	AND #envirite_biennial_staging.profit_ctr_id = pc.profit_ctr_ID



INSERT INTO EQ_Extract.dbo.BiennialReportSourceData
            (biennial_id, data_source, enviroware_manifest_document, enviroware_manifest_document_line, TRANS_MODE, Company_id, profit_ctr_id, profit_ctr_epa_id, receipt_id, line_id, container_id, sequence_id, treatment_id, management_code, lbs_haz_estimated, lbs_haz_actual, gal_haz_estimated, gal_haz_actual, yard_haz_estimated, yard_haz_actual, container_percent, manifest, manifest_line_id, approval_code, EPA_form_code, EPA_source_code, waste_desc, waste_density, generator_epa_id, generator_name, generator_address_1, generator_address_2, generator_address_3, generator_address_4, generator_address_5, generator_city, generator_state, generator_zip_code, generator_state_id, transporter_EPA_ID, transporter_name, transporter_addr1, transporter_addr2, transporter_addr3, transporter_city, transporter_state, transporter_zip_code, TSDF_EPA_ID, TSDF_name, TSDF_addr1, TSDF_addr2, TSDF_addr3, TSDF_city, TSDF_state, TSDF_zip_code)
SELECT biennial_id, data_source, enviroware_manifest_document, enviroware_manifest_document_line, TRANS_MODE, Company_id, profit_ctr_id, profit_ctr_epa_id, receipt_id, line_id, container_id, sequence_id, treatment_id, management_code, lbs_haz_estimated, lbs_haz_actual, gal_haz_estimated, gal_haz_actual, yard_haz_estimated, yard_haz_actual, container_percent, manifest, manifest_line_id, approval_code, EPA_form_code, EPA_source_code, waste_desc, waste_density, generator_epa_id, generator_name, generator_address_1, generator_address_2, generator_address_3, generator_address_4, generator_address_5, generator_city, generator_state, generator_zip_code, generator_state_id, transporter_EPA_ID, transporter_name, transporter_addr1, transporter_addr2, transporter_addr3, transporter_city, transporter_state, transporter_zip_code, TSDF_EPA_ID, TSDF_name, TSDF_addr1, TSDF_addr2, TSDF_addr3, TSDF_city, TSDF_state, TSDF_zip_code
FROM   #envirite_biennial_staging 



if @is_new_run = 'T'	
	SELECT @biennial_id	as biennial_id
       
       
       
       
       
/-*       
SELECT lm.*, ld.* FROM Envirite.dbo.load_master lm
	INNER JOIN Envirite.dbo.load_detail ld ON lm.LOAD = ld.LOAD
	INNER JOIN Envirite.dbo.company_master ew_generators ON ew_generators.COMPANY = ld.GENERATOR_COMPANY
	INNER JOIN Envirite.dbo.company_master ew_transporter ON ew_transporter.COMPANY = lm.TRANSPORTER
	INNER JOIN Envirite.dbo.profile_master pm ON ld.PROFILE = pm.PROFILE
		AND pm.profile_type NOT LIKE '%O' -- do not include Outbound
	INNER JOIN Envirite.dbo.manifest_master mm ON mm.LOAD = lm.LOAD
	INNER JOIN Envirite.dbo.ENVIRITE_ProfileXRef profile_xref ON profile_xref.profile = ld.PROFILE
	INNER JOIN Profile eq_profile ON profile_xref.profile_id = eq_profile.profile_id
		--AND eq_profile.curr_status_code = 'A'
	INNER JOIN Envirite.dbo.ENVIRITE_GeneratorXRef generator_xref ON ld.GENERATOR_COMPANY = generator_xref.envirite_generator
	INNER JOIN Generator eq_gen ON generator_xref.eq_generator = eq_gen.generator_id
	INNER JOIN Envirite.dbo.company_master ew_destination ON ew_destination.COMPANY = lm.DESTINATION
	WHERE lm.ARRIVED BETWEEN '01/01/2010' and '12/31/2010 23:59:59'
*-/	
	       
/-*
SELECT * FROM Envirite.dbo.load_master lm
	INNER JOIN Envirite.dbo.load_detail ld ON lm.LOAD = ld.LOAD
	INNER JOIN Envirite.dbo.company_master ew_generators ON ew_generators.COMPANY = ld.GENERATOR_COMPANY
	INNER JOIN Envirite.dbo.company_master ew_transporter ON ew_transporter.COMPANY = lm.TRANSPORTER
	INNER JOIN Envirite.dbo.profile_master pm ON ld.PROFILE = pm.PROFILE
		AND pm.profile_type NOT LIKE '%O' -- do not include Outbound
	INNER JOIN Envirite.dbo.manifest_master mm ON mm.LOAD = lm.LOAD
	INNER JOIN Envirite.dbo.ENVIRITE_ProfileXRef profile_xref ON profile_xref.profile = ld.PROFILE
	INNER JOIN Profile eq_profile ON profile_xref.profile_id = eq_profile.profile_id
		--AND eq_profile.curr_status_code = 'A'
	INNER JOIN Envirite.dbo.ENVIRITE_GeneratorXRef generator_xref ON ld.GENERATOR_COMPANY = generator_xref.envirite_generator
	INNER JOIN Generator eq_gen ON generator_xref.eq_generator = eq_gen.generator_id
	INNER JOIN Envirite.dbo.company_master ew_destination ON ew_destination.COMPANY = lm.DESTINATION
	WHERE lm.ARRIVED BETWEEN '01/01/2010' and '12/31/2010 23:59:59'
*-/
--SELECT * FROM load_master lm
--	INNER JOIN load_detail ld ON lm.LOAD = ld.LOAD
--	INNER JOIN company_master ew_generators ON ew_generators.COMPANY = ld.GENERATOR_COMPANY
--	INNER JOIN company_master ew_transporter ON ew_transporter.COMPANY = lm.TRANSPORTER
--	INNER JOIN profile_master pm ON ld.PROFILE = pm.PROFILE
--		AND pm.profile_type NOT LIKE '%O' -- do not include Outbound
--	INNER JOIN manifest_master mm ON mm.LOAD = lm.LOAD
--	INNER JOIN ENVIRITE_ProfileXRef profile_xref ON profile_xref.profile = ld.PROFILE
--	INNER JOIN Profile eq_profile ON profile_xref.profile_id = eq_profile.profile_id
--		--AND eq_profile.curr_status_code = 'A'
--	INNER JOIN ENVIRITE_GeneratorXRef generator_xref ON ld.GENERATOR_COMPANY = generator_xref.envirite_generator
--	INNER JOIN Generator eq_gen ON generator_xref.eq_generator = eq_gen.generator_id
--	INNER JOIN company_master ew_destination ON ew_destination.COMPANY = lm.DESTINATION
--	WHERE lm.ARRIVED BETWEEN '01/01/2010' and '12/31/2010 23:59:59'
--SELECT TRANSPORTED_ID FROM company_master 
--SELECT DISTINCT pm.PROFILE_TYPE from profile_master pm


	
	
END


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_biennial_report_source_enviroware] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_biennial_report_source_enviroware] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_biennial_report_source_enviroware] TO [EQAI]
    AS [dbo];

*/
