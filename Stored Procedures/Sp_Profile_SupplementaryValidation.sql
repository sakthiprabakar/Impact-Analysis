CREATE PROCEDURE [dbo].[Sp_Profile_SupplementaryValidation]
	@profile_id int,
	@form_id int,
	@revision_id int,
	@web_userid NVARCHAR(100)
AS

/* ******************************************************************

	Updated By		: Sathick
	Updated On		:  08 Jan 2018
	Type			: Stored Procedure
	Object Name		: [Sp_Profile_SupplementaryValidation]


	Procedure is used to  profile supplementary validation i.e appoved profile validation

inputs 
	
	@profile_id
	@form_id
	@revision_id

	

Samples:
 EXEC Sp_Profile_SupplementaryValidation @profile_id ,@form_id,@revision_id
 EXEC [Sp_Profile_SupplementaryValidation] 651165,512136,16, 'natalie.shellworth'

****************************************************************** */
BEGIN


DECLARE @Generator_id INT
DECLARE @waste_water_flag CHAR(1),
        @exceed_ldr_standards CHAR(1),
		@meets_alt_soil_treatment_stds CHAR(1),
		@more_than_50_pct_debris CHAR(1),
		@contains_pcb CHAR(1),
		@used_oil CHAR(1),
		@pharmaceutical_flag CHAR(1),
		@thermal_process_flag CHAR(1),
		@origin_refinery CHAR(1),
		@radioactive_waste CHAR(1),
		@reactive_other CHAR(1),
		@biohazard CHAR(1),
		@container_type_cylinder CHAR(1),
		@compressed_gas CHAR(1),
		@specific_technology_requested CHAR(1)


		Set @Generator_id = (SELECT p.generator_id From profile as p JOIN Generator as g on   p.generator_id =  g.generator_id  where p.profile_id = @profile_id)

	---LDR 

SELECT @waste_water_flag = waste_water_flag , 
@exceed_ldr_standards=waste_meets_ldr_standards,
@pharmaceutical_flag=pharmaceutical_flag,
@thermal_process_flag=thermal_process_flag,
@origin_refinery=origin_refinery,
@container_type_cylinder=container_type_cylinder ,
@specific_technology_requested = specific_technology_requested
FROM Profile WHERE profile_id = @profile_id

SELECT @biohazard=biohazard,@reactive_other = reactive_other,
@meets_alt_soil_treatment_stds=meets_alt_soil_treatment_stds,
@more_than_50_pct_debris=more_than_50_pct_debris,@used_oil=used_oil,
@radioactive_waste=radioactive_waste, @compressed_gas = compressed_gas,
@contains_pcb=contains_pcb
FROM ProfileLab WHERE profile_id = @profile_id and [type]= 'A'
--,

  /* Section A - H validation */
  
  EXEC [sp_Validate_Section_A] @form_id, @revision_id
  EXEC [sp_Validate_Section_B] @form_id, @revision_id
  EXEC [sp_Validate_Section_C] @form_id, @revision_id
  EXEC [sp_Validate_Section_D] @form_id, @revision_id
  EXEC [sp_Validate_Section_E] @form_id, @revision_id
  EXEC [sp_Validate_Section_F] @form_id, @revision_id
  EXEC [sp_Validate_Section_G] @form_id, @revision_id
  EXEC [sp_Validate_Section_H] @form_id, @revision_id
  EXEC [sp_Validate_Section_Document] @form_id, @revision_id
  
  /* END */

  IF @waste_water_flag = 'W' OR @waste_water_flag = 'N' OR @exceed_ldr_standards = 'T' OR @meets_alt_soil_treatment_stds = 'T' OR @more_than_50_pct_debris = 'T'
   BEGIN	
     EXEC sp_Validate_LDR @form_id,@revision_id,@web_userid
   END

-- LDR END

-- CERTIFICATE
  DECLARE @Generator_Country  VARCHAR(3)
  DECLARE @generator_type_id INT


  SELECT @generator_type_id = generator_type_id ,@Generator_Country = generator_Country FROM Generator where generator_id = @Generator_id

  IF  @generator_type_id = (SELECT generator_type_id  FROM dbo.GeneratorType WHERE generator_type = 'VSQG/CESQG')
   BEGIN 
    EXEC sp_Validate_Certificate @form_id,@revision_id,@web_userid
   END
-- CERTIFICATE END

-- PCB

  IF @contains_pcb = 'T'
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

IF @specific_technology_requested = 'T' AND @more_than_50_pct_debris = 'T' AND (SELECT Count(*) from ProfileUSEFacility where profile_id = @profile_id AND company_id = 2 AND profit_ctr_id = 0) > 0 
 BEGIN 
  EXEC sp_Validate_Debris @form_id,@revision_id,@web_userid
 END
-- DEBRIS END

-- Waste Import Supplement

IF ISNULL(@Generator_Country,'') <> '' AND @Generator_Country NOT IN('USA','VIR','PRI')
  BEGIN
   EXEC sp_Validate_WasteImport  @form_id,@revision_id, @web_userid
  END

-- Waste Import Supplement END

-- Illinois

IF @specific_technology_requested = 'T' AND (SELECT Count(*) from ProfileUSEFacility where profile_id = @profile_id AND company_id = 26 AND profit_ctr_id = 0) > 0
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

IF @origin_refinery = 'T'
 BEGIN
  EXEC sp_Validate_Benzene  @form_id,@revision_id,@web_userid
 END
-- BENZEN END

-- RADIOACTIVE

IF @radioactive_waste = 'T'
  BEGIN 
	EXEC sp_Validate_RadioActive  @form_id,@revision_id, @web_userid
  END
-- RADIOACTIVE END

-- Cylinder 
IF @container_type_cylinder = 'T' OR @compressed_gas = 'T'
BEGIN 
	EXEC sp_Validate_Cylinder  @form_id,@revision_id, @web_userid
END

END

GO

GRANT EXEC ON [dbo].[Sp_Profile_SupplementaryValidation] TO COR_USER;

GO
