CREATE PROCEDURE [dbo].[sp_COR_Insert_Supplement_Section_Status]
	-- Add the parameters for the stored procedure here
	@form_id int,
	@revision_id int,
	@web_userid nvarchar(100)
AS
/* ******************************************************************

	Author:		Dineshkumar

	Insert Supplements status if available

	inputs 
	
	form id
	revision id
	web_userid

	EXEC sp_COR_Insert_Supplement_Section_Status 522389, 1, 'anand_m123'

****************************************************************** */
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
BEGIN TRY
   DECLARE @Generator_id INT

	DECLARE 
		@waste_water_flag CHAR(1),
        @exceed_ldr_standards CHAR(1),
		@meets_alt_soil_treatment_stds CHAR(1),
		@more_than_50_pct_debris CHAR(1),
		@contains_pcb CHAR(1),
		@used_oil CHAR(1),
		@pharmaceutical_flag CHAR(1),
		@thermal_process_flag CHAR(1),
		@radioactive CHAR(1),
		@container_type_cylinder CHAR(1),
		@compressed_gas CHAR(1),	
		@waste_import NVARCHAR(1),
		@Benzene CHAR(1),
		@certification CHAR(1),
		@illinois CHAR(1),
		@debris CHAR(1),
		@genknowledge CHAR(1),
		@FormStatusFlag CHAR(1) = 'C'

		SELECT  @waste_water_flag = waste_water_flag, -- LDR
				@exceed_ldr_standards=waste_meets_ldr_standards, -- LDR
				@meets_alt_soil_treatment_stds=meets_alt_soil_treatment_stds, --LDR
				@more_than_50_pct_debris=more_than_50_pct_debris, --LDR

				@thermal_process_flag = thermal_process_flag,	-- Thermal
										
				@used_oil=used_oil, -- Used Oil

				@radioactive=radioactive, -- radio active

				@contains_pcb = contains_pcb, -- PCB

				@pharmaceutical_flag=pharma_waste_subject_to_prescription, --

				@container_type_cylinder=container_type_cylinder, -- Cylinder 
				@compressed_gas = compressed_gas, -- Cylinder,

				@Benzene = origin_refinery, -- Benzene

				@certification = CASE WHEN 
									 (select generator_type_id from GeneratorType where generator_type='VSQG/CESQG') = generator_type_id
									 THEN 'T'
									 ELSE null END, -- Certification

				@waste_import = case when LEN(generator_country) > 0 AND generator_country NOT IN('USA','VIR','PRI') THEN 'T' ELSE null END, -- waste import

				@illinois = case when specific_technology_requested = 'T' AND (select Count(*) from FormXUSEFacility fx where fx.form_id = @form_id and fx.revision_id = @revision_id and fx.company_id = 26 and fx.profit_ctr_id = 0) > 0 THEN 'T' ELSE null end, -- illinois

				@debris =  case when more_than_50_pct_debris = 'T' AND (specific_technology_requested = 'T' AND (select Count(*) from FormXUSEFacility fx where fx.form_id = @form_id and fx.revision_id = @revision_id and fx.company_id = 2 and fx.profit_ctr_id = 0) > 0) THEN 'T' ELSE null END,

				@genknowledge = case when routing_facility ='55|0' OR (specific_technology_requested ='T' AND (select Count(*) from FormXUSEFacility fx where fx.form_id = @form_id and fx.revision_id = @revision_id and fx.company_id = 55 and fx.profit_ctr_id = 0) > 0) THEN 'T' ELSE null end -- Generator Knowledge Supplement Form

			FROM FormWCR WHERE form_id = @form_id and revision_id = @revision_id

			
		/* PCB */
		IF (@contains_pcb = 'T' AND NOT EXISTS(SELECT * FROM FormSectionStatus WHERE form_id = @form_id AND revision_id = @revision_id AND section = 'PB'))
		BEGIN
			INSERT INTO FormSectionStatus VALUES (@form_id, @revision_id,'PB', @FormStatusFlag,getdate(),@web_userid,getdate(),@web_userid,1)
		END

		/* LDR */
		IF ((@waste_water_flag = 'W' OR @waste_water_flag = 'N' OR @exceed_ldr_standards = 'T' OR @meets_alt_soil_treatment_stds = 'T' OR @more_than_50_pct_debris = 'T') AND (NOT EXISTS(SELECT * FROM FormSectionStatus WHERE form_id = @form_id AND revision_id = @revision_id AND section = 'LR')))
		BEGIN
			INSERT INTO FormSectionStatus VALUES (@form_id, @revision_id,'LR', @FormStatusFlag,getdate(),@web_userid,getdate(),@web_userid,1)
		END

		/* Benzene */
		IF (@Benzene = 'T' AND (NOT EXISTS(SELECT * FROM FormSectionStatus WHERE form_id = @form_id AND revision_id = @revision_id AND section = 'BZ')))
		BEGIN
			INSERT INTO FormSectionStatus VALUES (@form_id, @revision_id,'BZ', @FormStatusFlag,getdate(),@web_userid,getdate(),@web_userid,1)
		END

		/* Illinois */
		IF (@illinois = 'T' AND (NOT EXISTS(SELECT * FROM FormSectionStatus WHERE form_id = @form_id AND revision_id = @revision_id AND section = 'ID')))
		BEGIN
			INSERT INTO FormSectionStatus VALUES (@form_id, @revision_id,'ID', @FormStatusFlag,getdate(),@web_userid,getdate(),@web_userid,1)
		END

		/* Pharmaceutical */
		IF (@pharmaceutical_flag = 'T' AND (NOT EXISTS(SELECT * FROM FormSectionStatus WHERE form_id = @form_id AND revision_id = @revision_id AND section = 'PL')))
		BEGIN
			INSERT INTO FormSectionStatus VALUES (@form_id, @revision_id,'PL', @FormStatusFlag,getdate(),@web_userid,getdate(),@web_userid,1)
		END

		/* Waste Import */
		IF (@waste_import = 'T' AND (NOT EXISTS(SELECT * FROM FormSectionStatus WHERE form_id = @form_id AND revision_id = @revision_id AND section = 'WI')))
		BEGIN
			INSERT INTO FormSectionStatus VALUES (@form_id, @revision_id,'WI', @FormStatusFlag,getdate(),@web_userid,getdate(),@web_userid,1)
		END

		/* Used Oil */
		IF (@used_oil = 'T' AND (NOT EXISTS(SELECT * FROM FormSectionStatus WHERE form_id = @form_id AND revision_id = @revision_id AND section = 'UL')))
		BEGIN
			INSERT INTO FormSectionStatus VALUES (@form_id, @revision_id,'UL', @FormStatusFlag,getdate(),@web_userid,getdate(),@web_userid,1)
		END

		/* Certification */
		IF (@certification = 'T' AND (NOT EXISTS(SELECT * FROM FormSectionStatus WHERE form_id = @form_id AND revision_id = @revision_id AND section = 'CN')))
		BEGIN
			INSERT INTO FormSectionStatus VALUES (@form_id, @revision_id,'CN', @FormStatusFlag,getdate(),@web_userid,getdate(),@web_userid,1)
		END

		/* Thermal */
		IF (@thermal_process_flag = 'T' AND (NOT EXISTS(SELECT * FROM FormSectionStatus WHERE form_id = @form_id AND revision_id = @revision_id AND section = 'TL')))
		BEGIN
			INSERT INTO FormSectionStatus VALUES (@form_id, @revision_id,'TL', @FormStatusFlag,getdate(),@web_userid,getdate(),@web_userid,1)
		END

		IF ((@container_type_cylinder   = 'T' OR @compressed_gas = 'T') AND (NOT EXISTS(SELECT * FROM FormSectionStatus WHERE form_id = @form_id AND revision_id = @revision_id AND section = 'CR')))
		BEGIN
			INSERT INTO FormSectionStatus VALUES (@form_id, @revision_id,'CR', @FormStatusFlag,getdate(),@web_userid,getdate(),@web_userid,1)
		END

		/* Debris */
		IF (@debris = 'T' AND (NOT EXISTS(SELECT * FROM FormSectionStatus WHERE form_id = @form_id AND revision_id = @revision_id AND section = 'DS')))
		BEGIN
			INSERT INTO FormSectionStatus VALUES (@form_id, @revision_id,'DS', @FormStatusFlag,getdate(),@web_userid,getdate(),@web_userid,1)
		END

		/* Radio Active */
		IF (@radioactive = 'T' AND (NOT EXISTS(SELECT * FROM FormSectionStatus WHERE form_id = @form_id AND revision_id = @revision_id AND section = 'RA')))
		BEGIN
			INSERT INTO FormSectionStatus VALUES (@form_id, @revision_id,'RA', @FormStatusFlag,getdate(),@web_userid,getdate(),@web_userid,1)
		END

		/* Generator Location */
		--IF (@GLFlag = 'T' AND (NOT EXISTS(SELECT * FROM FormSectionStatus WHERE form_id = @form_id AND revision_id = @revision_id AND section = 'GL')))
		--BEGIN
		--	INSERT INTO FormSectionStatus VALUES (@form_id, @revision_id,'GL', @FormStatusFlag,getdate(),@web_userid,getdate(),@web_userid,1)
		--END

		IF (@genknowledge = 'T' AND (NOT EXISTS(SELECT * FROM FormSectionStatus WHERE form_id = @form_id AND revision_id = @revision_id AND section = 'GK')))
		BEGIN
			INSERT INTO FormSectionStatus VALUES (@form_id, @revision_id,'GK', @FormStatusFlag,getdate(),@web_userid,getdate(),@web_userid,1)
		END		

	END TRY
	BEGIN CATCH			
			DECLARE @error_description VARCHAR(MAX)
			SET @error_description=CONVERT(VARCHAR(20), @form_id)+' - '+CONVERT(VARCHAR(10),@revision_id)+ ' ErrorMessage: '+Error_Message()
			INSERT INTO COR_DB.[dbo].[ErrorLogs] (ErrorDescription,[Object_Name],Web_user_id,CreatedDate)
		                               VALUES(@error_description,ERROR_PROCEDURE(),@web_userid,GETDATE())
	END CATCH

END


GO

	GRANT EXECUTE ON [dbo].[sp_COR_Insert_Supplement_Section_Status] TO COR_USER;

GO
