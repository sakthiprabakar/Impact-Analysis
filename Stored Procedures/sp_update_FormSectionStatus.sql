USE PLT_AI
GO
DROP PROCEDURE IF EXISTS [sp_update_FormSectionStatus]
GO

CREATE PROCEDURE [dbo].[sp_update_FormSectionStatus] 
	@formid int,
	@revision_id int,
	@PCBFlag varchar(2) = '',
    @LDRFlag varchar(2) = '',
	@BZFlag varchar(2) = '',
	@IDFlag varchar(2) = '',
	@PLFlag varchar(2) = '',
	@WIFlag varchar(2) = '', 
	@ULFlag varchar(2) = '',  
	@CNFlag varchar(2) = '',  
	@TLFlag varchar(2) = '',
	@CRFlag varchar(2) = '',
	@DSFlag varchar(2) = '',
	@RAFlag varchar(2) = '',
	@GLFlag varchar(2) = ''
AS


/* ******************************************************************

FormWCR Section / Suppliment status wil be updated to the  sp_update_FormSectionStatus object

inputs 
	
	form id
	revision id
	Individual suppliments form flag list

	EXEC sp_update_FormSectionStatus 510774, 1

****************************************************************** */
BEGIN


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
		@greensboro CHAR(1)
		
		SELECT  @waste_water_flag = waste_water_flag, -- LDR
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

				@illinois = case when specific_technology_requested = 'T' AND (select Count(*) from FormXUSEFacility fx where fx.form_id = @formId and fx.revision_id = @revision_id and fx.company_id = 26 and fx.profit_ctr_id = 0) > 0 THEN 'T' ELSE null end, -- illinois

				@debris =  case when more_than_50_pct_debris = 'T' AND (specific_technology_requested = 'T' AND (select Count(*) from FormXUSEFacility fx where fx.form_id = @formId and fx.revision_id = @revision_id and fx.company_id = 2 and fx.profit_ctr_id = 0) > 0) THEN 'T' ELSE null END,

				@genknowledge = case when routing_facility ='55|0' OR (specific_technology_requested ='T' AND (select Count(*) from FormXUSEFacility fx where fx.form_id = @formId and fx.revision_id = @revision_id and fx.company_id = 55 and fx.profit_ctr_id = 0) > 0) THEN 'T' ELSE null end, -- Generator Knowledge Supplement Form

				@greensboro = case when routing_facility ='73|94' OR (specific_technology_requested ='T' AND (select Count(*) from FormXUSEFacility fx where fx.form_id = @formId and fx.revision_id = @revision_id and fx.company_id = 73 and fx.profit_ctr_id = 94) > 0) THEN 'T' ELSE null end -- Greensboro Supplement Form

			FROM FormWCR WHERE form_id = @formid and revision_id = @revision_id

		

    IF(EXISTS(SELECT * FROM FormSectionStatus WHERE form_id = @formId AND revision_id = @revision_id AND section = 'PB' ))
	 BEGIN
	   IF @contains_pcb = 'T' 	
	    BEGIN
		  UPDATE FormSectionStatus SET isActive = 1 WHERE form_id = @formId AND revision_id = @revision_id AND section = 'PB'
		END
	   ELSE --IF @PCBFlag = 'F'
	    BEGIN
		  UPDATE FormSectionStatus SET isActive = 0 WHERE form_id = @formId AND revision_id = @revision_id AND section = 'PB'		
	    END	  
	END

	IF(EXISTS(SELECT * FROM FormSectionStatus WHERE form_id = @formId AND revision_id = @revision_id AND section = 'LR' ))
	  BEGIN
	   IF @waste_water_flag = 'W' OR @waste_water_flag = 'N' OR @exceed_ldr_standards = 'T' OR @meets_alt_soil_treatment_stds = 'T' OR @more_than_50_pct_debris = 'T'
	    BEGIN
		  UPDATE FormSectionStatus SET isActive = 1 WHERE form_id = @formId AND revision_id = @revision_id AND section = 'LR'
		END
	   ELSE -- IF @LDRFlag  = 'F'
	    BEGIN
		  UPDATE FormSectionStatus SET isActive = 0 WHERE form_id = @formId AND revision_id = @revision_id AND section = 'LR'
		END
	  END
	
	IF(EXISTS(SELECT * FROM FormSectionStatus WHERE form_id = @formId AND revision_id = @revision_id AND section = 'BZ' ))
	  BEGIN
		IF @Benzene  = 'T' 
			BEGIN
			 UPDATE FormSectionStatus SET isActive = 1 WHERE form_id = @formId AND revision_id = @revision_id AND section = 'BZ'
			END	
    	ELSE --IF @BZFlag  = 'F'
	       BEGIN
		    UPDATE FormSectionStatus SET isActive = 0 WHERE form_id = @formId AND revision_id = @revision_id AND section = 'BZ'
		   END	
	  END

	IF(EXISTS(SELECT * FROM FormSectionStatus WHERE form_id = @formId AND revision_id = @revision_id AND section = 'ID' ))
	    BEGIN
		  IF @illinois  = 'T' 
	        BEGIN
              UPDATE FormSectionStatus SET isActive = 1 WHERE form_id = @formId AND revision_id = @revision_id AND section = 'ID'
	        END
	      ELSE --IF @IDFlag  = 'F'	
	       BEGIN
		     UPDATE FormSectionStatus SET isActive = 0 WHERE form_id = @formId AND revision_id = @revision_id AND section = 'ID'
		   END	
		END

	IF(EXISTS(SELECT * FROM FormSectionStatus WHERE form_id = @formId AND revision_id = @revision_id AND section = 'PL' ))
	    BEGIN
		 IF @pharmaceutical_flag  = 'T' 
			BEGIN
			  UPDATE FormSectionStatus SET isActive = 1 WHERE form_id = @formId AND revision_id = @revision_id AND section = 'PL'
			END
		 ELSE --IF @PLFlag  = 'F'
		   BEGIN
			  UPDATE FormSectionStatus SET isActive = 0 WHERE form_id = @formId AND revision_id = @revision_id AND section = 'PL'
			END
	    END


	IF(EXISTS(SELECT * FROM FormSectionStatus WHERE form_id = @formId AND revision_id = @revision_id AND section = 'WI' ))
	  BEGIN
	    IF @waste_import  = 'T' 
	       BEGIN		
	         UPDATE FormSectionStatus SET isActive = 1 WHERE form_id = @formId AND revision_id = @revision_id AND section = 'WI'
		   END
       	ELSE --IF @WIFlag  = 'F'
	      BEGIN
		     UPDATE FormSectionStatus SET isActive = 0 WHERE form_id = @formId AND revision_id = @revision_id AND section = 'WI'
		  END
	 END

	IF(EXISTS(SELECT * FROM FormSectionStatus WHERE form_id = @formId AND revision_id = @revision_id AND section = 'UL' ))
	  BEGIN
	    IF @used_oil   = 'T' 
	       BEGIN		
	         UPDATE FormSectionStatus SET isActive = 1 WHERE form_id = @formId AND revision_id = @revision_id AND section = 'UL'
		   END
       	ELSE --IF @ULFlag   = 'F'
	      BEGIN
		     UPDATE FormSectionStatus SET isActive = 0 WHERE form_id = @formId AND revision_id = @revision_id AND section = 'UL'
		  END
	 END

	IF(EXISTS(SELECT * FROM FormSectionStatus WHERE form_id = @formId AND revision_id = @revision_id AND section = 'CN' ))
	  BEGIN
	    IF @certification    = 'T' 
	       BEGIN		
	         UPDATE FormSectionStatus SET isActive = 1 WHERE form_id = @formId AND revision_id = @revision_id AND section = 'CN'
		   END
       	ELSE --IF @CNFlag    = 'F'
	      BEGIN
		     UPDATE FormSectionStatus SET isActive = 0 WHERE form_id = @formId AND revision_id = @revision_id AND section = 'CN'
		  END
	 END

	IF(EXISTS(SELECT * FROM FormSectionStatus WHERE form_id = @formId AND revision_id = @revision_id AND section = 'TL' ))
	  BEGIN
	    IF @thermal_process_flag  = 'T' 
	       BEGIN		
	         UPDATE FormSectionStatus SET isActive = 1 WHERE form_id = @formId AND revision_id = @revision_id AND section = 'TL'
		   END
       	ELSE --IF @TLFlag  = 'F'
	      BEGIN
		     UPDATE FormSectionStatus SET isActive = 0 WHERE form_id = @formId AND revision_id = @revision_id AND section = 'TL'
		  END
	 END

	IF(EXISTS(SELECT * FROM FormSectionStatus WHERE form_id = @formId AND revision_id = @revision_id AND section = 'CR' ))
	  BEGIN
	    IF @container_type_cylinder   = 'T' OR @compressed_gas = 'T'
	       BEGIN		
	         UPDATE FormSectionStatus SET isActive = 1 WHERE form_id = @formId AND revision_id = @revision_id AND section = 'CR'
		   END
       	ELSE --IF @CRFlag   = 'F'
	      BEGIN
		     UPDATE FormSectionStatus SET isActive = 0 WHERE form_id = @formId AND revision_id = @revision_id AND section = 'CR'
		  END
	 END
	 
	 IF(EXISTS(SELECT * FROM FormSectionStatus WHERE form_id = @formId AND revision_id = @revision_id AND section = 'DS' ))
	  BEGIN
	    IF @debris = 'T' 
	       BEGIN		
	         UPDATE FormSectionStatus SET isActive = 1 WHERE form_id = @formId AND revision_id = @revision_id AND section = 'DS'
		   END
       	ELSE --IF @DSFlag = 'F'
	      BEGIN
		     UPDATE FormSectionStatus SET isActive = 0 WHERE form_id = @formId AND revision_id = @revision_id AND section = 'DS'
		  END
	 END

	 IF(EXISTS(SELECT * FROM FormSectionStatus WHERE form_id = @formId AND revision_id = @revision_id AND section = 'RA' ))
	  BEGIN
	    IF @radioactive  = 'T' 
	       BEGIN		
	         UPDATE FormSectionStatus SET isActive = 1 WHERE form_id = @formId AND revision_id = @revision_id AND section = 'RA'
		   END
       	ELSE --IF @RAFlag  = 'F'
	      BEGIN
		     UPDATE FormSectionStatus SET isActive = 0 WHERE form_id = @formId AND revision_id = @revision_id AND section = 'RA'
		  END
	 END

	 IF(EXISTS(SELECT * FROM FormSectionStatus WHERE form_id = @formId AND revision_id = @revision_id AND section = 'GL' ))
	  BEGIN
	    IF @GLFlag   = 'T' 
	       BEGIN		
	         UPDATE FormSectionStatus SET isActive = 1 WHERE form_id = @formId AND revision_id = @revision_id AND section = 'GL'
		   END
       	ELSE --IF @GLFlag   = 'F'
	      BEGIN
		     UPDATE FormSectionStatus SET isActive = 0 WHERE form_id = @formId AND revision_id = @revision_id AND section = 'GL'
		  END
	 END

	 IF(EXISTS(SELECT * FROM FormSectionStatus WHERE form_id = @formId AND revision_id = @revision_id AND section = 'GK' ))
	  BEGIN
	    IF @genknowledge   = 'T' 
	    BEGIN		
	         UPDATE FormSectionStatus SET isActive = 1 WHERE form_id = @formId AND revision_id = @revision_id AND section = 'GK'
		END
       	ELSE 
	    BEGIN
		     UPDATE FormSectionStatus SET isActive = 0 WHERE form_id = @formId AND revision_id = @revision_id AND section = 'GK'
		END
	 END	 

	  IF(EXISTS(SELECT * FROM FormSectionStatus WHERE form_id = @formId AND revision_id = @revision_id AND section = 'FB' ))
	  BEGIN
	    IF @greensboro   = 'T' 
	    BEGIN		
	         UPDATE FormSectionStatus SET isActive = 1 WHERE form_id = @formId AND revision_id = @revision_id AND section = 'FB'
		END
       	ELSE 
	    BEGIN
		     UPDATE FormSectionStatus SET isActive = 0 WHERE form_id = @formId AND revision_id = @revision_id AND section = 'FB'
		END
	 END	 

END


GO

	GRANT EXECUTE ON [dbo].[sp_update_FormSectionStatus] TO COR_USER;

GO