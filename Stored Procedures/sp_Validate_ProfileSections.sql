USE [PLT_AI]
GO
DROP PROCEDURE IF EXISTS [sp_Validate_ProfileSections]
GO

CREATE PROCEDURE [dbo].[sp_Validate_ProfileSections]
	-- Add the parameters for the stored procedure here
	@profile_id INTEGER,
	@web_userid nvarchar(60)
AS


/* ******************************************************************

	Updated By		: Prabhu
	Updated On		: 2nd Nov 2021
	Type			: Stored Procedure
	Object Name		: [sp_Validate_Profile]


	procedure to validate edited sections. 
	
	i.e) Edited sections passed with comma seperated values. 
	Based on the sections the appropriate  section validation stored procedure will be excecuted 

inputs 
	
	@profile_id
	@edited_Section_Details
	@web_userid


Samples:
 EXEC [sp_Validate_ProfileSections] @profile_id,@web_userid
 EXEC [sp_Validate_ProfileSections] 430235,'manand84'

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
		@specific_technology_requested CHAR(1),
		@genknowledge CHAR(1),
		@fuel_blending CHAR(1)


		Set @Generator_id = (SELECT p.generator_id From profile as p JOIN Generator as g on   p.generator_id =  g.generator_id  where p.profile_id = @profile_id)

	---LDR 

SELECT @waste_water_flag = waste_water_flag , 
@exceed_ldr_standards=waste_meets_ldr_standards,
@pharmaceutical_flag=pharmaceutical_flag,
@thermal_process_flag=thermal_process_flag,
@origin_refinery=origin_refinery,
@container_type_cylinder=container_type_cylinder ,
@specific_technology_requested = specific_technology_requested,
@genknowledge =  case when (specific_technology_requested ='T' AND (select Count(*) from ProfileUSEFacility px where px.profile_id = @profile_id and px.company_id = 55 and px.profit_ctr_id = 0) > 0) THEN 'T' ELSE null end,
@fuel_blending = case when (specific_technology_requested ='T' AND (select Count(*) from ProfileUSEFacility px where px.profile_id = @profile_id and px.company_id = 73 and px.profit_ctr_id = 94) > 0) THEN 'T' ELSE null end
FROM Profile WHERE profile_id = @profile_id

SELECT @biohazard=biohazard,@reactive_other = reactive_other,
@meets_alt_soil_treatment_stds=meets_alt_soil_treatment_stds,
@more_than_50_pct_debris=more_than_50_pct_debris,@used_oil=used_oil,
@radioactive_waste=radioactive_waste, @compressed_gas = compressed_gas,
@contains_pcb=contains_pcb
FROM ProfileLab WHERE profile_id = @profile_id and [type]= 'A'
--,

  /* Section A - H validation */
  
  EXEC [sp_Validate_Profile_Section_A] @profile_id
  EXEC [sp_Validate_Profile_Section_B] @profile_id
  EXEC [sp_Validate_Profile_Section_C] @profile_id
  EXEC [sp_Validate_Profile_Section_D] @profile_id
  EXEC [sp_Validate_Profile_Section_E] @profile_id
  EXEC [sp_Validate_Profile_Section_F] @profile_id
  EXEC [sp_Validate_Profile_Section_G] @profile_id
  EXEC [sp_Validate_Profile_Section_H] @profile_id
  
    
  /* END */

  IF @waste_water_flag = 'W' OR @waste_water_flag = 'N' OR @exceed_ldr_standards = 'T' OR @meets_alt_soil_treatment_stds = 'T' OR @more_than_50_pct_debris = 'T'
   BEGIN	
     EXEC sp_Validate_Profile_LDR @profile_id,@web_userid
   END

-- LDR END

-- CERTIFICATE
  DECLARE @Generator_Country  VARCHAR(3)
  DECLARE @generator_type_id INT


  SELECT @generator_type_id = generator_type_id ,@Generator_Country = generator_Country FROM Generator where generator_id = @Generator_id

  IF  @generator_type_id = (SELECT generator_type_id  FROM dbo.GeneratorType WHERE generator_type = 'VSQG/CESQG')
   BEGIN 
    EXEC sp_Validate_Profile_Certificate @profile_id,@web_userid
   END
-- CERTIFICATE END

-- PCB

  IF @contains_pcb = 'T'
    BEGIN
	 EXEC sp_Validate_Profile_PCB @profile_id,@web_userid
	END
-- PCB END  

-- USED OIL 

 IF @used_oil = 'T'
   BEGIN
    EXEC sp_Validate_Profile_UsedOil @profile_id,@web_userid
   END
-- USED OIL END

--  pharmaceutical

 IF @pharmaceutical_flag = 'T'
	BEGIN
      EXEC	sp_Validate_Profile_Pharmaceutical @profile_id,@web_userid
	END
-- pharmaceutical END

-- DEBRIS

IF @specific_technology_requested = 'T' AND @more_than_50_pct_debris = 'T' AND (SELECT Count(*) from ProfileUSEFacility where profile_id = @profile_id AND company_id = 2 AND profit_ctr_id = 0) > 0 
 BEGIN 
  EXEC sp_Validate_Profile_Debris @profile_id,@web_userid
 END
-- DEBRIS END

-- Waste Import Supplement

IF ISNULL(@Generator_Country,'') <> '' AND @Generator_Country NOT IN('USA','VIR','PRI')
  BEGIN
   EXEC sp_Validate_Profile_WasteImport  @profile_id,@web_userid
  END

-- Waste Import Supplement END

-- Illinois

IF @specific_technology_requested = 'T' AND (SELECT Count(*) from ProfileUSEFacility where profile_id = @profile_id AND company_id = 26 AND profit_ctr_id = 0) > 0
BEGIN
	EXEC sp_Validate_Profile_IllinoisDisposal  @profile_id,@web_userid
END

-- 

-- THERMAL 

IF @thermal_process_flag = 'T'
BEGIN
  EXEC sp_Validate_Profile_Thermal  @profile_id,@web_userid
END
-- THERMAL END

-- BENZEN

IF @origin_refinery = 'T'
 BEGIN
  EXEC sp_Validate_Profile_Benzene  @profile_id,@web_userid
 END
-- BENZEN END

-- RADIOACTIVE

IF @radioactive_waste = 'T'
  BEGIN 
	EXEC sp_Validate_Profile_RadioActive  @profile_id,@web_userid
  END
-- RADIOACTIVE END

-- Cylinder 
IF @container_type_cylinder = 'T' OR @compressed_gas = 'T'
BEGIN 
	EXEC sp_Validate_Profile_Cylinder  @profile_id,@web_userid
END

--Generator Knowledge
IF @genknowledge = 'T'
BEGIN
	EXEC sp_Validate_Profile_GeneratorKnowledge_Form @profile_id,@web_userid
END
--Generator Knowledge

--Fuel Blending
IF @fuel_blending = 'T'
BEGIN
	EXEC sp_Validate_ProfileEcoflo @profile_id,@web_userid
END
--Fuel Blending End
END

GO
	GRANT EXEC ON [dbo].[sp_Validate_ProfileSections] TO COR_USER;
GO
