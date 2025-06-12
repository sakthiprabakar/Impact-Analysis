
CREATE PROCEDURE sp_biennial_validate
	@biennial_id	int,
	@debug			int = 0
/****************************************************************************
sp_biennial_validate 	

	Run validation checks against biennial source data

History:
	02/08/2012	JPB	Modified from previous version, commented out Enviroware section

Example:
	sp_biennial_validate 1502, 1

SELECT * FROM EQ_Extract..BiennialReportSourceDataValidation where biennial_id = 1502
		
UGH...
EQ_Extract..sp_help BiennialReportSourceDataValidation		
use eq_extract
create index idx_biennial_id on BiennialReportSourceDataValidation(biennial_id)
use plt_ai


Valid characters for alphanumeric fields are limited to: 
`~! @#$%^&*()_-+={}[]|\:;"',.?/1234567890ABCDEFGHIJKLMNOPQRSTUVWXY

****************************************************************************/	
AS
BEGIN

if @debug > 0 select getdate(), 'sp_biennial_validate: Started'

-- if object_id('eq_temp..sp_biennial_validate_TMP') is not null drop table eq_temp..sp_biennial_validate_TMP


if @debug > 0 select getdate(), 'sp_biennial_validate: Dropped Temp Table'

	--truncate table EQ_Extract..BiennialReportSourceDataValidation
	DELETE FROM EQ_Extract..BiennialReportSourceDataValidation
		WHERE biennial_id = @biennial_id

if @debug > 0 select getdate(), 'sp_biennial_validate: Deleted previous biennial_id data', @biennial_id

	if @debug > 1 print 'sp_biennial_validate_form_code'
	exec sp_biennial_validate_form_code @biennial_id
	-- sp_helptext sp_biennial_validate_form_code
	
if @debug > 0 select getdate(), 'sp_biennial_validate: finished sp_biennial_validate_form_code'	

	if @debug > 1 print 'sp_biennial_validate_epa_source_codes'
	exec sp_biennial_validate_epa_source_codes @biennial_id
	-- sp_helptext sp_biennial_validate_epa_source_codes
	
if @debug > 0 select getdate(), 'sp_biennial_validate: finished sp_biennial_validate_epa_source_codes'	

	if @debug > 1 print 'sp_biennial_validate_management_codes'
	exec sp_biennial_validate_management_codes @biennial_id

if @debug > 0 select getdate(), 'sp_biennial_validate: finished sp_biennial_validate_management_codes'	
	
	if @debug > 1 print 'sp_biennial_validate_pound_conversion'
	exec sp_biennial_validate_pound_conversion @biennial_id

if @debug > 0 select getdate(), 'sp_biennial_validate: finished sp_biennial_validate_pound_conversion'	


	if @debug > 1 print 'sp_biennial_validate_specific_gravity'
	exec sp_biennial_validate_specific_gravity @biennial_id
	-- sp_helptext sp_biennial_validate_specific_gravity
	
if @debug > 0 select getdate(), 'sp_biennial_validate: finished sp_biennial_validate_specific_gravity'	


-- 2/8/2012 - JPB - This only compared EQAI TO Enviroware data, not necessary anymore.	
--	print 'sp_biennial_validate_duplicate_manifests'
--	exec sp_biennial_validate_duplicate_manifests @biennial_id

	if @debug > 1 print 'sp_biennial_validate_address'
	exec sp_biennial_validate_address @biennial_id, @debug
	
if @debug > 0 select getdate(), 'sp_biennial_validate: finished sp_biennial_validate_address'	
	
	if @debug > 1 print 'sp_biennial_validate_epa_id'
	exec sp_biennial_validate_epa_id @biennial_id, @debug
	
if @debug > 0 select getdate(), 'sp_biennial_validate: finished sp_biennial_validate_epa_id'	

	if @debug > 1 print 'sp_biennial_validate_weight_entered'
	exec sp_biennial_validate_weight_entered @biennial_id

if @debug > 0 select getdate(), 'sp_biennial_validate: finished sp_biennial_validate_weight_entered'	

	if @debug > 1 print 'sp_biennial_validate_state_id'
	exec sp_biennial_validate_state_id @biennial_id
		
if @debug > 0 select getdate(), 'sp_biennial_validate: finished sp_biennial_validate_state_id'	

	if @debug > 1 print 'sp_biennial_validate_missing_haz_bol'
	exec sp_biennial_validate_missing_haz_bol @biennial_id

if @debug > 0 select getdate(), 'sp_biennial_validate: finished sp_biennial_validate_missing_haz_bol'	

	if @debug > 1 print 'sp_biennial_validate_duplicated_generator'
	exec sp_biennial_validate_duplicated_generator @biennial_id
		
if @debug > 0 select getdate(), 'sp_biennial_validate: finished sp_biennial_validate_duplicated_generator'	

	if @debug > 1 print 'sp_biennial_validate_allowed_characters'
	exec sp_biennial_validate_allowed_characters @biennial_id
		
if @debug > 0 select getdate(), 'sp_biennial_validate: finished sp_biennial_validate_allowed_characters'	

	
	DELETE FROM EQ_Extract..BiennialReportSourceDataValidation where validation_message is null
		and biennial_id = @biennial_id
	
if @debug > 0 select getdate(), 'sp_biennial_validate: finished deleted null lines'	
	
-- SK 02/17/2012 Drop just before inserting so as to avoid conflicts with other users	
	SELECT DISTINCT
           validation_message,
           approval_code,
           biennial_id,
           data_source,
           enviroware_manifest_document,
           enviroware_manifest_document_line,
           TRANS_MODE,
           receipt_id,
           line_id,
           Company_id,
           profit_ctr_id,
           profit_ctr_epa_id,
           container_id,
           sequence_id,
           treatment_id,
           management_code,
           lbs_haz_estimated,
           lbs_haz_actual,
           gal_haz_estimated,
           gal_haz_actual,
           yard_haz_estimated,
           yard_haz_actual,
           container_percent,
           manifest,
           manifest_line_id,
           EPA_form_code,
           EPA_source_code,
           waste_desc,
           waste_density,
           waste_consistency,
           eq_generator_id,
           generator_epa_id,
           generator_name,
           generator_address_1,
           generator_address_2,
           generator_address_3,
           generator_address_4,
           generator_address_5,
           generator_city,
           generator_state,
           generator_zip_code,
           generator_state_id,
           transporter_EPA_ID,
           transporter_name,
           transporter_addr1,
           transporter_addr2,
           transporter_addr3,
           transporter_city,
           transporter_state,
           transporter_zip_code,
           TSDF_EPA_ID,
           TSDF_name,
           TSDF_addr1,
           TSDF_addr2,
           TSDF_addr3,
           TSDF_city,
           TSDF_state,
           TSDF_zip_code
    FROM   EQ_Extract.dbo.BiennialReportSourceDataValidation
    WHERE  biennial_id = @biennial_id
           AND data_source = 'EQAI'

if @debug > 0 select getdate(), 'sp_biennial_validate: populated sp_biennial_validate_TMP'	
	

	
END


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_biennial_validate] TO [EQWEB]

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_biennial_validate] TO [COR_USER]

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_biennial_validate] TO [EQAI]

