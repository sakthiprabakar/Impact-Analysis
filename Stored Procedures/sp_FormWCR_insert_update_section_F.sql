USE [PLT_AI]
GO
/*************************************************************************************************/
DROP PROCEDURE IF EXISTS [dbo].[sp_FormWCR_insert_update_section_F] 
GO 
CREATE PROCEDURE [dbo].[sp_FormWCR_insert_update_section_F]

       @Data XML,		
	   @form_id int,
	   @revision_id int
AS
/* ******************************************************************
  Updated By       : Dinesh
  Updated On date  : 2nd Nov 2019
  Decription       : update Section F details
  Type             : Stored Procedure
  Object Name      : [sp_FormWCR_insert_update_section_F]

  Updated By   : Ranjini C
  Updated On   : 08-AUGUST-2024
  Ticket       : 93217
  Decription   : This procedure is used to assign web_userid to created_by and modified_by columns. 


  stored procedure for updating the section F related to data

  Inputs 
	   @Data,	--> XML data	
	   @form_id,
	   @revision_id
 
  Samples:
	 EXEC [dbo].[sp_FormWCR_insert_update_section_F] @Data, @form_id, @revision_id	 

****************************************************************** */
BEGIN
	begin try
        UPDATE  FormWCR 			 
        SET         
			  explosives = p.v.value('explosives[1]','char(1)'),
			  ammonia_flag = p.v.value('ammonia_flag[1]','char(1)'),
			  react_sulfide_ppm = p.v.value('react_sulfide_ppm[1][not(@xsi:nil = "true")]','FLOAT'),
			  react_sulfide =  p.v.value('react_sulfide[1]','CHAR(1)'),
			  shock_sensitive_waste = p.v.value('shock_sensitive_waste[1]','CHAR(1)'),
			  react_cyanide_ppm = p.v.value('react_cyanide_ppm[1][not(@xsi:nil = "true")]','FLOAT'),
			  react_cyanide = p.v.value('react_cyanide[1]','CHAR(1)'),
			  radioactive = p.v.value('radioactive[1]','CHAR(1)'),
			  reactive_other_description = p.v.value('reactive_other_description[1]','VARCHAR(255)'),
			  reactive_other = p.v.value('reactive_other[1]','CHAR(1)'),
			  biohazard = p.v.value('biohazard[1]','CHAR(1)'),
			  contains_pcb = p.v.value('contains_pcb[1]','CHAR(1)'),
			  dioxins_or_furans = p.v.value('dioxins_or_furans[1]','CHAR(1)'),
			  metal_fines_powder_paste = p.v.value('metal_fines_powder_paste[1]','CHAR(1)'),
			  pyrophoric_waste = p.v.value('pyrophoric_waste[1]','CHAR(1)'),
			  temp_control = p.v.value('temp_control[1]','CHAR(1)'),
			  thermally_unstable = p.v.value('thermally_unstable[1]','CHAR(1)'),
			  biodegradable_sorbents = p.v.value('biodegradable_sorbents[1]','CHAR(1)'),
			  compressed_gas = p.v.value('compressed_gas[1]','CHAR(1)'),
			  used_oil = p.v.value('used_oil[1]','CHAR(1)'),
			  oxidizer = p.v.value('oxidizer[1]','CHAR(1)'),
			  tires = p.v.value('tires[1]','CHAR(1)'),
			  organic_peroxide = p.v.value('organic_peroxide[1]','CHAR(1)'),
			  beryllium_present = p.v.value('beryllium_present[1]','CHAR(1)'), 
			  asbestos_flag = p.v.value('asbestos_flag[1]','CHAR(1)'),
			  asbestos_friable_flag = p.v.value('asbestos_friable_flag[1]','CHAR(1)'),
			  hazardous_secondary_material = p.v.value('hazardous_secondary_material[1]','CHAR(1)'),
			  hazardous_secondary_material_cert = p.v.value('hazardous_secondary_material_cert[1]','CHAR(1)'),
			  pharma_waste_subject_to_prescription = p.v.value('pharma_waste_subject_to_prescription[1]','CHAR(1)'),
			  section_F_none_apply_flag = p.v.value('section_F_none_apply_flag[1]','CHAR(1)'),
			  PFAS_Flag = p.v.value('PFAS_Flag[1]','CHAR(1)')
          FROM
        @Data.nodes('SectionF')p(v) WHERE form_id = @form_id  and revision_id=  @revision_id
	end try
	begin catch
		declare @procedure nvarchar(150), 
				@mailTrack_userid nvarchar(60) = 'COR'
				set @procedure = ERROR_PROCEDURE()
				declare @error nvarchar(4000) = ERROR_MESSAGE()
				declare @error_description nvarchar(4000) = 'Form ID: ' + convert(nvarchar(15), @form_id) + '-' +  convert(nvarchar(15), @revision_id) 
															+ CHAR(13) + 
															+ CHAR(13) + 
														   'Error Message: ' + isnull(@error, '')
														   + CHAR(13) + 
														   + CHAR(13) + 
														   'Data:  ' + convert(nvarchar(4000),@Data)

														   
				EXEC [COR_DB].[DBO].sp_COR_Exception_MailTrack
						@web_userid = @mailTrack_userid, 
						@object = @procedure,
						@body = @error_description
	end catch

END

GO

	GRANT EXECUTE ON [dbo].[sp_FormWCR_insert_update_section_F] TO COR_USER;
GO
/**************************************************************************************************************/
