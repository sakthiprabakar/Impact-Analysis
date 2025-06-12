USE [PLT_AI]
GO
/*********************************************************************************************/
DROP PROCEDURE IF EXISTS [dbo].[sp_Radioactive_insert_update]
GO
CREATE  PROCEDURE [dbo].[sp_Radioactive_insert_update]
       @Data XML,
	   @form_id int,
	   @revision_id int,
	   @web_userid varchar(100)
AS
/* ******************************************************************
 	Updated By		: Karuppiah
	Updated On		: 10th Dec 2024
	Type			: Stored Procedure
	Ticket   		: Titan-US134197,US132686,US134198,US127722
	Change			: Const_id added.

Insert / update Radioactive form  (Part of form wcr insert / update)
inputs 	
	Data -- XML data having values for the FormRadioactive table objects
	Form ID
	Revision ID
****************************************************************** */
--declare       @Data XML='<Radioactive>
--  <IsEdited>RA</IsEdited>
--  <wcr_id>461587</wcr_id>
--  <wcr_rev_id>1</wcr_rev_id>
--  <uranium_thorium_flag>T</uranium_thorium_flag>
--  <uranium_source_material />
--  <uranium_concentration xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:nil="true" />
--  <radium_226_flag />
--  <radium_226_concentration xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:nil="true" />
--  <radium_228_flag />
--  <radium_228_concentration xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:nil="true" />
--  <lead_210_flag />
--  <lead_210_concentration xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:nil="true" />
--  <potassium_40_flag />
--  <potassium_40_concentration xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:nil="true" />
--  <exempt_byproduct_material_flag />
--  <special_nuclear_material_flag />
--  <accelerator_flag />
--  <generated_in_particle_accelerator_flag />
--  <approved_for_disposal_flag />
--  <approved_by_nrc_flag />
--  <approved_for_alternate_disposal_flag />
--  <nrc_exempted_flag />
--  <released_from_radiological_control_flag />
--  <DOD_non_licensed_disposal_flag />
--  <byproduct_sum_of_all_isotopes />
--  <source_sof_calculations />
--  <special_nuclear_sum_of_all_isotopes />
--  <date_created xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:nil="true" />
--  <date_modified xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:nil="true" />
---<RadioactiveExempt>
---<RadioactiveExempt><line_id>1</line_id><item_name /><total_number_in_shipment>0</total_number_in_shipment><radionuclide_contained /><activity>0</activity><disposal_site_tsdf_id>0</disposal_site_tsdf_id><cited_regulatory_exemption /><date_created xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:nil="true" /><date_modified xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:nil="true" /></RadioactiveExempt></RadioactiveExempt>
---<RadioactiveUSEI>
---<RadioactiveUSEI><line_id>1</line_id><radionuclide /><concentration>0</concentration><date_created xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:nil="true" /><date_modified xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:nil="true" /></RadioactiveUSEI></RadioactiveUSEI></Radioactive>',
--	   @form_id int=461587,
--	   @revision_id int=1
 IF(EXISTS(SELECT form_id FROM FormWCR  WITH(NOLOCK)  WHERE form_id = @form_id and revision_id =  @revision_id))
   BEGIN
   declare @isExist bit=0,@isExistform_id int;
   DECLARE @newForm_id INT 
   	DECLARE @newrev_id INT  = 1
		IF(NOT EXISTS(SELECT 1 FROM FormRadioactive WITH(NOLOCK) WHERE wcr_id = @form_id and wcr_rev_id =  @revision_id))
			BEGIN
				EXEC @newForm_id = sp_sequence_next 'form.form_id'			
			select p.v.value('line_id[1]','int') FROM
				  @Data.nodes('Radioactive/RadioactiveExempt/RadioactiveExempt')p(v)
			  INSERT INTO FormRadioactive(form_id,revision_id,wcr_id,wcr_rev_id,locked,uranium_thorium_flag,uranium_source_material,radium_226_flag,radium_228_flag,lead_210_flag,potassium_40_flag,exempt_byproduct_material_flag,special_nuclear_material_flag,accelerator_flag,generated_in_particle_accelerator_flag,approved_for_disposal_flag,approved_by_nrc_flag,approved_for_alternate_disposal_flag,nrc_exempted_flag,released_from_radiological_control_flag,DOD_non_licensed_disposal_flag,
			 byproduct_sum_of_all_isotopes,source_sof_calculations,special_nuclear_sum_of_all_isotopes, date_created,date_modified,created_by,modified_by
			 ,uranium_concentration,radium_226_concentration ,radium_228_concentration,lead_210_concentration,potassium_40_concentration,additional_inventory_flag,
			 specifically_exempted_flag,
			 USEI_WAC_table_C1_flag,
			 USEI_WAC_table_C2_flag, 
			USEI_WAC_table_C3_flag, 
			USEI_WAC_table_C4a_flag, 
			USEI_WAC_table_C4b_flag, 
			USEI_WAC_table_C4c_flag,
			waste_type)--byproduct_material,WAC_limit,source_material,special_nuclear_material,sum_of_all_isotopes--
			  SELECT			 
				    form_id=@newForm_id,
				    revision_id=@newrev_id,
				    wcr_id = @form_id,
				    wcr_rev_id = @revision_id,
				   -- locked = p.v.value('locked[1]','char(1)'),
				    locked= 'U',
				    uranium_thorium_flag= p.v.value('uranium_thorium_flag[1]','char(1)'),
				    uranium_source_material= p.v.value('uranium_source_material[1]','char(1)'),
				    radium_226_flag= p.v.value('radium_226_flag[1]','char(1)'),
					radium_228_flag= p.v.value('radium_228_flag[1]','char(1)'),
					lead_210_flag= p.v.value('lead_210_flag[1]','char(1)'),
					potassium_40_flag= p.v.value('potassium_40_flag[1]','char(1)'),
					exempt_byproduct_material_flag= p.v.value('exempt_byproduct_material_flag[1]','char(1)'),
					special_nuclear_material_flag= p.v.value('special_nuclear_material_flag[1]','char(1)'),
					accelerator_flag= p.v.value('accelerator_flag[1]','char(1)'),
					generated_in_particle_accelerator_flag= p.v.value('generated_in_particle_accelerator_flag[1]','char(1)'),
					approved_for_disposal_flag= p.v.value('approved_for_disposal_flag[1]','char(1)'),
					approved_by_nrc_flag= p.v.value('approved_by_nrc_flag[1]','char(1)'),
					approved_for_alternate_disposal_flag= p.v.value('approved_for_alternate_disposal_flag[1]','char(1)'),
					nrc_exempted_flag= p.v.value('nrc_exempted_flag[1]','char(1)'),
					released_from_radiological_control_flag= p.v.value('released_from_radiological_control_flag[1]','char(1)'),
					DOD_non_licensed_disposal_flag= p.v.value('DOD_non_licensed_disposal_flag[1]','char(1)'),
					--byproduct_material= p.v.value('byproduct_material[1]','varchar(255)'),
					--WAC_limit= p.v.value('WAC_limit[1]','varchar(255)'),
					--source_material= p.v.value('source_material[1]','varchar(255)'),
					--special_nuclear_material= p.v.value('special_nuclear_material[1]','varchar(255)'),
					--sum_of_all_isotopes= p.v.value('sum_of_all_isotopes[1]','varchar(255)'),
					byproduct_sum_of_all_isotopes=p.v.value('byproduct_sum_of_all_isotopes[1]','varchar(255)'),
					source_sof_calculations=p.v.value('source_sof_calculations[1]','varchar(4000)'),
					special_nuclear_sum_of_all_isotopes=p.v.value('special_nuclear_sum_of_all_isotopes[1]','varchar(255)'),
					date_created = GETDATE(),
					date_modified = GETDATE(),
				    created_by = @web_userid,
				    modified_by = @web_userid,
					uranium_concentration=p.v.value('uranium_concentration[1]','varchar(100)'),
					radium_226_concentration = p.v.value('radium_226_concentration[1][not(@xsi:nil = "true")]','float'),
					radium_228_concentration = p.v.value('radium_228_concentration[1][not(@xsi:nil = "true")]','float'),
					lead_210_concentration = p.v.value('lead_210_concentration[1][not(@xsi:nil = "true")]','float'),
					potassium_40_concentration = p.v.value('potassium_40_concentration[1][not(@xsi:nil = "true")]','float'),
					additional_inventory_flag= p.v.value('additional_inventory_flag[1]','char(1)'),
					specifically_exempted_flag = p.v.value('specifically_exempted_flag[1]','char(1)'),
					USEI_WAC_table_C1_flag = p.v.value('USEI_WAC_table_C1_flag[1]','char(1)'), 
					USEI_WAC_table_C2_flag = p.v.value('USEI_WAC_table_C2_flag[1]','char(1)'), 
					USEI_WAC_table_C3_flag  = p.v.value('USEI_WAC_table_C3_flag[1]','char(1)'), 
					USEI_WAC_table_C4a_flag =  p.v.value('USEI_WAC_table_C4a_flag[1]','char(1)'), 
					USEI_WAC_table_C4b_flag = p.v.value('USEI_WAC_table_C4b_flag[1]','char(1)'),
					USEI_WAC_table_C4c_flag = p.v.value('USEI_WAC_table_C4c_flag[1]','char(1)'),
					waste_type = p.v.value('waste_type[1]','char(1)')			
			  FROM
				  @Data.nodes('Radioactive')p(v)
		   END
        ELSE
           BEGIN		  
		  set @isExist=1;
		  select @isExistform_id= form_id from FormRadioactive  WHERE wcr_id = @form_id and wcr_rev_id =  @revision_id
              UPDATE  FormRadioactive
              SET                 
					--locked = p.v.value('locked[1]','char(1)'),
					locked= 'U',
				    uranium_thorium_flag= p.v.value('uranium_thorium_flag[1]','char(1)'),
				    uranium_source_material= p.v.value('uranium_source_material[1]','char(1)'),
				    radium_226_flag= p.v.value('radium_226_flag[1]','char(1)'),
					radium_228_flag= p.v.value('radium_228_flag[1]','char(1)'),
					lead_210_flag= p.v.value('lead_210_flag[1]','char(1)'),
					potassium_40_flag= p.v.value('potassium_40_flag[1]','char(1)'),
					exempt_byproduct_material_flag= p.v.value('exempt_byproduct_material_flag[1]','char(1)'),
					special_nuclear_material_flag= p.v.value('special_nuclear_material_flag[1]','char(1)'),
					accelerator_flag= p.v.value('accelerator_flag[1]','char(1)'),
					generated_in_particle_accelerator_flag= p.v.value('generated_in_particle_accelerator_flag[1]','char(1)'),
					approved_for_disposal_flag= p.v.value('approved_for_disposal_flag[1]','char(1)'),
					approved_by_nrc_flag= p.v.value('approved_by_nrc_flag[1]','char(1)'),
					approved_for_alternate_disposal_flag= p.v.value('approved_for_alternate_disposal_flag[1]','char(1)'),
					nrc_exempted_flag= p.v.value('nrc_exempted_flag[1]','char(1)'),
					released_from_radiological_control_flag= p.v.value('released_from_radiological_control_flag[1]','char(1)'),
					DOD_non_licensed_disposal_flag= p.v.value('DOD_non_licensed_disposal_flag[1]','char(1)'),
					byproduct_sum_of_all_isotopes=p.v.value('byproduct_sum_of_all_isotopes[1]','varchar(255)'),
					source_sof_calculations=p.v.value('source_sof_calculations[1]','varchar(4000)'),
					special_nuclear_sum_of_all_isotopes=p.v.value('special_nuclear_sum_of_all_isotopes[1]','varchar(255)'),
					--byproduct_material= p.v.value('byproduct_material[1]','varchar(255)'),
					--WAC_limit= p.v.value('WAC_limit[1]','varchar(255)'),
					--source_material= p.v.value('source_material[1]','varchar(255)'),
					--special_nuclear_material= p.v.value('special_nuclear_material[1]','varchar(255)'),
					--sum_of_all_isotopes= p.v.value('sum_of_all_isotopes[1]','varchar(255)'),
				    date_modified = GETDATE(),
				    modified_by = @web_userid,
				    uranium_concentration=p.v.value('uranium_concentration[1]','varchar(100)'),
				    radium_226_concentration = p.v.value('radium_226_concentration[1][not(@xsi:nil = "true")]','float'),
					radium_228_concentration = p.v.value('radium_228_concentration[1][not(@xsi:nil = "true")]','float'),
					lead_210_concentration = p.v.value('lead_210_concentration[1][not(@xsi:nil = "true")]','float'),
					potassium_40_concentration = p.v.value('potassium_40_concentration[1][not(@xsi:nil = "true")]','float'),
					additional_inventory_flag= p.v.value('additional_inventory_flag[1]','char(1)'),
					specifically_exempted_flag = p.v.value('specifically_exempted_flag[1]','char(1)'),
					USEI_WAC_table_C1_flag = p.v.value('USEI_WAC_table_C1_flag[1]','char(1)'), 
					USEI_WAC_table_C2_flag = p.v.value('USEI_WAC_table_C2_flag[1]','char(1)'), 
					USEI_WAC_table_C3_flag  = p.v.value('USEI_WAC_table_C3_flag[1]','char(1)'), 
					USEI_WAC_table_C4a_flag =  p.v.value('USEI_WAC_table_C4a_flag[1]','char(1)'), 
					USEI_WAC_table_C4b_flag = p.v.value('USEI_WAC_table_C4b_flag[1]','char(1)'),
					USEI_WAC_table_C4c_flag = p.v.value('USEI_WAC_table_C4c_flag[1]','char(1)'),
					waste_type = p.v.value('waste_type[1]','char(1)')		
		      FROM
               @Data.nodes('Radioactive')p(v) WHERE wcr_id = @form_id and wcr_rev_id =  @revision_id
           END

	SET @form_id=	CASE WHEN @isExist=1 THEN @isExistform_id ELSE @newForm_id END
	print @form_id
		 --RadioActiveExempt
			  IF(EXISTS(SELECT 1 FROM FormRadioactiveExempt  WITH(NOLOCK) WHERE form_id = @form_id and revision_id =  @revision_id))
				BEGIN
		    		DELETE FROM FormRadioactiveExempt WHERE form_id = @form_id and revision_id =  @revision_id 
			   END		
				--disposal_site_tsdf_id
			  INSERT INTO FormRadioactiveExempt(
			  form_id,
			  revision_id,
			  line_id,
			  item_name,
			  total_number_in_shipment,
			  radionuclide_contained,
			  activity,
			  disposal_site_tsdf_code,
			  cited_regulatory_exemption,
			  created_by,
			  date_created,
			  modified_by,
			  date_modified) 
			  SELECT
			        form_id = @form_id ,
				    revision_id = @revision_id,
				    line_id=p.v.value('line_id[1]','int'),
					item_name=p.v.value('item_name[1]','VARCHAR(80)'),
					total_number_in_shipment=p.v.value('total_number_in_shipment[1][not(@xsi:nil = "true")]','NVARCHAR(50)'),
					radionuclide_contained=p.v.value('radionuclide_contained[1]','VARCHAR(10)'),
					activity=p.v.value('activity[1][not(@xsi:nil = "true")]','NVARCHAR(50)'),
					--disposal_site_tsdf_id=p.v.value('disposal_site_tsdf_id[1]','int'),
					disposal_site_tsdf_code=p.v.value('disposal_site_tsdf_code[1]','VARCHAR(15)'),
					cited_regulatory_exemption=p.v.value('cited_regulatory_exemption[1]','VARCHAR(20)'),
					created_by = @web_userid,
					date_created = GETDATE(),
				    modified_by = @web_userid,
					date_modified = GETDATE()
			  FROM
				  @Data.nodes('Radioactive/RadioactiveExempt/RadioactiveExempt')p(v) --where form_id = @form_id and revision_id =  @revision_id			
			---RadioactiveUSEI
				 IF(EXISTS(SELECT 1 FROM FormRadioactiveUSEI  WITH(NOLOCK) WHERE form_id = @form_id and revision_id =  @revision_id))
				  BEGIN
				   DELETE FROM FormRadioactiveUSEI WHERE form_id = @form_id and revision_id =  @revision_id 
				  END
				 INSERT INTO FormRadioactiveUSEI(form_id,revision_id,line_id,radionuclide,concentration,date_created,date_modified,created_by,modified_by) 
				  SELECT
					   form_id =  @form_id ,
					   revision_id = @revision_id,
					   line_id=p.v.value('line_id[1]','int'),
					   radionuclide=p.v.value('radionuclide[1]','varchar(255)'),
					   concentration=p.v.value('concentration[1][not(@xsi:nil = "true")]','float'),
					   const_id = p.v.value('const_id[1]','int'), 
					   sectionEflag = p.v.value('sectionEflag[1]','char(1)'),  
					   date_created = GETDATE(),
					   date_modified = GETDATE(),
					   created_by = @web_userid,
					   modified_by = @web_userid
				  FROM
					  @Data.nodes('Radioactive/RadioactiveUSEI/RadioactiveUSEI')p(v)  
END
GO
   GRANT EXECUTE ON [dbo].[sp_Radioactive_insert_update] TO COR_USER;
GO
/***************************************************************************************************/

  


