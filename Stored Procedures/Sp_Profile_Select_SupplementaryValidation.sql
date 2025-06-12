
-- =============================================
-- Author:	 Meenachi
-- Create date: 06-Feb-2018
-- Description:	Select Approved Profile Supplementary Validation 
-- =============================================
CREATE  PROCEDURE [dbo].[Sp_Profile_Select_SupplementaryValidation]
	@profile_id int
AS
BEGIN

--DECLARE @profile_id int=597390;



DECLARE  @Generator_id INT,@waste_water_flag CHAR(1),
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
		@compressed_gas CHAR(1)


DECLARE @LDR CHAR(1)='N',@VSQG_CESQG_CERTIFICATE CHAR(1)='N',@PCB CHAR(1)='N',@usedoil CHAR(1)='N',@pharmaceutical CHAR(1)='N',@DEBRIS CHAR(1)='N',
@Waste_Import CHAR(1)='N',@THERMAL CHAR(1)='N',@RADIOACTIVEFLAG CHAR(1)='N',@RADIOACTIVE CHAR(1)='N',@compressedgas CHAR(1)='N',@BENZEN CHAR(1)='N';
		Set @Generator_id = (SELECT p.generator_id From profile as p  JOIN Generator as g on   p.generator_id =  g.generator_id  where p.profile_id = @profile_id)

	---LDR 

SELECT @waste_water_flag = waste_water_flag , @exceed_ldr_standards=exceed_ldr_standards,@pharmaceutical_flag=pharmaceutical_flag,@thermal_process_flag=thermal_process_flag,@origin_refinery=origin_refinery,@container_type_cylinder=container_type_cylinder FROM Profile WHERE profile_id = @profile_id
SELECT @biohazard=biohazard,@reactive_other = reactive_other,@meets_alt_soil_treatment_stds=meets_alt_soil_treatment_stds,
@more_than_50_pct_debris=more_than_50_pct_debris,@used_oil=used_oil,@radioactive_waste=radioactive_waste,
@contains_pcb=contains_pcb,@compressed_gas=compressed_gas
 FROM ProfileLab WHERE profile_id = @profile_id

  IF @waste_water_flag = 'W' OR @waste_water_flag = 'N' OR @exceed_ldr_standards = 'T' OR @meets_alt_soil_treatment_stds = 'T' OR @more_than_50_pct_debris = 'T'
   BEGIN
    SET @LDR='Y'
   END

-- LDR END

-- CERTIFICATE
  DECLARE @Generator_Country  VARCHAR(3)
  DECLARE @generator_type_id INT


  SELECT @generator_type_id = generator_type_id ,@Generator_Country = generator_Country FROM Generator where generator_id = @Generator_id

  IF  @generator_type_id = (SELECT generator_type_id  FROM dbo.GeneratorType WHERE generator_type = 'CESQG' ) OR @generator_type_id = (SELECT generator_type_id  FROM dbo.GeneratorType WHERE generator_type = 'VSQG')
   BEGIN 
    SET @VSQG_CESQG_CERTIFICATE='Y'
   END
-- CERTIFICATE END

-- PCB

  IF @contains_pcb = 'T'
    BEGIN
	 SET @PCB='Y'
	END
-- PCB END  

-- USED OIL 

 IF @used_oil = 'T'
   BEGIN
    SET @usedoil='Y'
   END
-- USED OIL END

--  pharmaceutical

 IF @pharmaceutical_flag = 'T'
	BEGIN
      SET @pharmaceutical='Y'
	END
-- pharmaceutical END

-- DEBRIS

IF @more_than_50_pct_debris = 'T'
 BEGIN 
  SET @DEBRIS='Y'
 END
-- DEBRIS END

-- Waste Import Supplement

IF ISNULL(@Generator_Country,'') != '' AND @Generator_Country NOT IN('USA','VIR','PRI')
  BEGIN
   SET @Waste_Import='Y'
  END

-- Waste Import Supplement END

-- THERMAL 

IF @thermal_process_flag = 'T'
BEGIN
  SET @THERMAL='Y'
END
-- THERMAL END

-- BENZEN

IF @origin_refinery = 'T'
 BEGIN
  SET @BENZEN='Y'
 END
-- BENZEN END

-- RADIOACTIVE

IF @radioactive_waste = 'T' OR @reactive_other = 'T' OR	@biohazard = 'T' OR @container_type_cylinder = 'T'
  BEGIN 
	SET @RADIOACTIVEFLAG='Y'
  END
-- RADIOACTIVE END

--Compressed Gas Cylinder 

IF @container_type_cylinder = 'T' OR @compressed_gas = 'T'
  BEGIN 
	SET @compressedgas='Y'
  END
-- Compressed Gas Cylinder  END
SELECT @compressedgas AS Compressed_Gas_Cylinder,@RADIOACTIVEFLAG AS RadioActive,@BENZEN AS Benzene,@THERMAL AS Thermal,@Waste_Import Waste_Import
,@DEBRIS AS Debris_Waste,@pharmaceutical  AS pharmaceutical ,@usedoil AS UsedOil,@PCB AS PCB,@VSQG_CESQG_CERTIFICATE AS CERTIFICATE,@LDR AS LDR

END

GO

GRANT EXECUTE ON [Sp_Profile_Select_SupplementaryValidation] to COR_USER
GO
