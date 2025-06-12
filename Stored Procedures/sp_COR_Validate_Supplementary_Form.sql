CREATE PROCEDURE [dbo].[sp_COR_Validate_Supplementary_Form]
	-- Add the parameters for the stored procedure here
	@form_id int,
	@revision_id int,
	@web_userid nvarchar(100)
AS

/*

EXEC sp_COR_Validate_Supplementary_Form 517469, 1, 'manand84'

*/

BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	
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
		@FormStatusFlag CHAR(1) = 'C',
		@generator_type_id int,
		@Generator_Country nvarchar(10),
		@genknowledge CHAR(1),
		@fuel_blending CHAR(1)

		SELECT  				
				@waste_water_flag = waste_water_flag, -- LDR
				@exceed_ldr_standards=waste_meets_ldr_standards, -- LDR
				@meets_alt_soil_treatment_stds=meets_alt_soil_treatment_stds, --LDR
				@more_than_50_pct_debris=more_than_50_pct_debris, --LDR

				@thermal_process_flag=thermal_process_flag,	-- Thermal
										
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

				@illinois = case when specific_technology_requested = 'T' AND (select Count(*) from FormXUSEFacility fx  where fx.form_id = @form_id and fx.revision_id = @revision_id and fx.company_id = 26 and fx.profit_ctr_id = 0) > 0 THEN 'T' ELSE null end, -- illinois

				@debris =  case when more_than_50_pct_debris = 'T' AND (specific_technology_requested = 'T' AND (select Count(*) from FormXUSEFacility fx where fx.form_id = @form_id and fx.revision_id = @revision_id and fx.company_id = 2 and fx.profit_ctr_id = 0) > 0) THEN 'T' ELSE null END,

				@genknowledge = case when routing_facility ='55|0' OR (specific_technology_requested ='T' AND (select Count(*) from FormXUSEFacility fx where fx.form_id = @form_id and fx.revision_id = @revision_id and fx.company_id = 55 and fx.profit_ctr_id = 0) > 0) THEN 'T' ELSE null end, -- Generator Knowledge Supplement Form

				@fuel_blending = case when routing_facility ='73|94' OR (specific_technology_requested ='T' AND (select Count(*) from FormXUSEFacility fx where fx.form_id = @form_id and fx.revision_id = @revision_id and fx.company_id = 73 and fx.profit_ctr_id = 94) > 0) THEN 'T' ELSE null end   --Fuel Supplement

			FROM FormWCR WHERE form_id = @form_id and revision_id = @revision_id	

select  @illinois as ill
   IF @waste_water_flag = 'W' OR @waste_water_flag = 'N' OR @exceed_ldr_standards = 'T' OR @meets_alt_soil_treatment_stds = 'T' OR @more_than_50_pct_debris = 'T'
   BEGIN	
     EXEC sp_Validate_LDR @form_id,@revision_id,@web_userid
   END

-- LDR END

-- CERTIFICATE
  
  IF  @certification = 'T'
   BEGIN 
    EXEC sp_Validate_Certificate @form_id,@revision_id,@web_userid
   END
-- CERTIFICATE END

-- PCB

  	IF (@contains_pcb = 'T')
    BEGIN
	 EXEC sp_Validate_PCB @form_id,@revision_id,@web_userid
	END
-- PCB END  

-- USED OIL 

 IF @used_oil = 'T'
   BEGIN
    EXEC sp_Validate_UsedOil @form_id,@revision_id,@web_userid
   END
-- USED OIL END

--  pharmaceutical

 IF @pharmaceutical_flag = 'T'
	BEGIN
      EXEC	sp_Validate_Pharmaceutical @form_id,@revision_id,@web_userid
	END
-- pharmaceutical END

-- DEBRIS

IF @debris = 'T'
 BEGIN 
  EXEC sp_Validate_Debris @form_id,@revision_id,@web_userid
 END
-- DEBRIS END

-- Waste Import Supplement

IF  @waste_import = 'T'
  BEGIN
   EXEC sp_Validate_WasteImport  @form_id,@revision_id, @web_userid
  END

-- Waste Import Supplement END

-- Illinois

IF @illinois = 'T'
BEGIN
	EXEC sp_Validate_IllinoisDisposal  @form_id,@revision_id,@web_userid
END

-- 

-- THERMAL 

IF @thermal_process_flag = 'T'
BEGIN
  EXEC sp_Validate_Thermal  @form_id,@revision_id,@web_userid
END
-- THERMAL END

-- BENZEN

IF @Benzene = 'T'
 BEGIN
  EXEC sp_Validate_Benzene  @form_id,@revision_id,@web_userid
 END
-- BENZEN END

-- RADIOACTIVE

IF @radioactive = 'T'
  BEGIN 
	EXEC sp_Validate_RadioActive  @form_id,@revision_id, @web_userid
  END
-- RADIOACTIVE END

-- Cylinder 
IF @container_type_cylinder = 'T' OR @compressed_gas = 'T'
BEGIN 
	EXEC sp_Validate_Cylinder  @form_id,@revision_id, @web_userid
END

-- Generator Knowledge supplement
IF @genknowledge = 'T'
BEGIN 
	EXEC sp_Validate_GeneratorKnowledge_Form  @form_id,@revision_id, @web_userid
END

--Fuel Bending Supplement
IF @fuel_blending = 'T'
BEGIN
	EXEC sp_Validate_FormEcoflo @form_id,@revision_id, @web_userid
END

END

GO

	GRANT EXECUTE ON [dbo].[sp_COR_Validate_Supplementary_Form]	 TO COR_USER;

GO

