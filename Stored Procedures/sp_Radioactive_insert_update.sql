CREATE OR ALTER PROCEDURE dbo.sp_Radioactive_insert_update
      @Data XML
	, @form_id INTEGER
	, @revision_id INTEGER
	, @web_userid VARCHAR(100)
AS
/* ******************************************************************
 	Updated By		: Karuppiah
	Updated On		: 10th Dec 2024
	Type			: Stored Procedure
	Ticket   		: Titan-US134197,US132686,US134198,US127722
	Change			: Const_id added.
	Updated by Blair Christensen for Titan 05/27/2025

Insert / update Radioactive form  (Part of form wcr insert / update)
inputs 	
	Data -- XML data having values for the FormRadioactive table objects
	Form ID
	Revision ID
******************************************************************
declare @Data XML='<Radioactive>
  <IsEdited>RA</IsEdited>
  <wcr_id>461587</wcr_id>
  <wcr_rev_id>1</wcr_rev_id>
  <uranium_thorium_flag>T</uranium_thorium_flag>
  <uranium_source_material />
  <uranium_concentration xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:nil="true" />
  <radium_226_flag />
  <radium_226_concentration xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:nil="true" />
  <radium_228_flag />
  <radium_228_concentration xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:nil="true" />
  <lead_210_flag />
  <lead_210_concentration xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:nil="true" />
  <potassium_40_flag />
  <potassium_40_concentration xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:nil="true" />
  <exempt_byproduct_material_flag />
  <special_nuclear_material_flag />
  <accelerator_flag />
  <generated_in_particle_accelerator_flag />
  <approved_for_disposal_flag />
  <approved_by_nrc_flag />
  <approved_for_alternate_disposal_flag />
  <nrc_exempted_flag />
  <released_from_radiological_control_flag />
  <DOD_non_licensed_disposal_flag />
  <byproduct_sum_of_all_isotopes />
  <source_sof_calculations />
  <special_nuclear_sum_of_all_isotopes />
  <date_created xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:nil="true" />
  <date_modified xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:nil="true" />
-<RadioactiveExempt>
-<RadioactiveExempt><line_id>1</line_id><item_name /><total_number_in_shipment>0</total_number_in_shipment><radionuclide_contained /><activity>0</activity><disposal_site_tsdf_id>0</disposal_site_tsdf_id><cited_regulatory_exemption /><date_created xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:nil="true" /><date_modified xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:nil="true" /></RadioactiveExempt></RadioactiveExempt>
-<RadioactiveUSEI>
-<RadioactiveUSEI><line_id>1</line_id><radionuclide /><concentration>0</concentration><date_created xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:nil="true" /><date_modified xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:nil="true" /></RadioactiveUSEI></RadioactiveUSEI></Radioactive>',
	   @form_id int=461587,
	   @revision_id int=1
 */
 BEGIN
	 IF EXISTS (SELECT form_id FROM dbo.FormWCR WHERE form_id = @form_id and revision_id = @revision_id)
		BEGIN
			DECLARE @isExist BIT = 0
			      , @isExistform_id INTEGER
				  , @newForm_id INTEGER
				  , @newrev_id INTEGER = 1;

			IF NOT EXISTS (SELECT 1 FROM dbo.FormRadioactive WHERE wcr_id = @form_id and wcr_rev_id =  @revision_id)
				BEGIN
					EXEC @newForm_id = sp_sequence_next 'form.form_id';

					SELECT p.v.value('line_id[1]','int')
					  FROM @Data.nodes('Radioactive/RadioactiveExempt/RadioactiveExempt')p(v)

					INSERT INTO dbo.FormRadioactive (form_id, revision_id, wcr_id, wcr_rev_id, locked
					     , uranium_thorium_flag, uranium_source_material, uranium_concentration
					     , radium_226_flag, radium_226_concentration
						 , radium_228_flag, radium_228_concentration
					     , lead_210_flag, lead_210_concentration
						 , potassium_40_flag, potassium_40_concentration
					     , exempt_byproduct_material_flag, special_nuclear_material_flag, accelerator_flag, generated_in_particle_accelerator_flag
					     , approved_for_disposal_flag, approved_by_nrc_flag, approved_for_alternate_disposal_flag, nrc_exempted_flag
					     , released_from_radiological_control_flag, DOD_non_licensed_disposal_flag, byproduct_sum_of_all_isotopes
					     , source_sof_calculations, special_nuclear_sum_of_all_isotopes, additional_inventory_flag
					     , created_by, date_created, modified_by, date_modified
					     , specifically_exempted_flag, material_exempted_by_usa_flag, material_released_by_government_flag
					     , USEI_WAC_table_C1_flag, USEI_WAC_table_C2_flag, USEI_WAC_table_C3_flag
					     , USEI_WAC_table_C4a_flag, USEI_WAC_table_C4b_flag, USEI_WAC_table_C4c_flag, waste_type)
				    SELECT @newForm_id as form_id, @newrev_id as revision_id, @form_id as wcr_id, @revision_id as wcr_rev_id, locked= 'U'
						 , p.v.value('uranium_thorium_flag[1]', 'CHAR(1)') as uranium_thorium_flag
						 , p.v.value('uranium_source_material[1]', 'CHAR(1)') as uranium_source_material
						 , p.v.value('uranium_concentration[1]', 'VARCHAR(100)') as uranium_concentration
						 , p.v.value('radium_226_flag[1]', 'CHAR(1)') as radium_226_flag
						 , p.v.value('radium_226_concentration[1][not(@xsi:nil = "true")]', 'FLOAT') as radium_226_concentration
						 , p.v.value('radium_228_flag[1]', 'CHAR(1)') as radium_228_flag
						 , p.v.value('radium_228_concentration[1][not(@xsi:nil = "true")]', 'FLOAT') as radium_228_concentration
						 , p.v.value('lead_210_flag[1]', 'CHAR(1)') as lead_210_flag
						 , p.v.value('lead_210_concentration[1][not(@xsi:nil = "true")]', 'FLOAT') as lead_210_concentration
						 , p.v.value('potassium_40_flag[1]', 'CHAR(1)') as potassium_40_flag
						 , p.v.value('potassium_40_concentration[1][not(@xsi:nil = "true")]', 'FLOAT') as potassium_40_concentration
						 , p.v.value('exempt_byproduct_material_flag[1]', 'CHAR(1)') as exempt_byproduct_material_flag
						 , p.v.value('special_nuclear_material_flag[1]', 'CHAR(1)') as special_nuclear_material_flag
						 , p.v.value('accelerator_flag[1]', 'CHAR(1)') as accelerator_flag
						 , p.v.value('generated_in_particle_accelerator_flag[1]', 'CHAR(1)') as generated_in_particle_accelerator_flag
						 , p.v.value('approved_for_disposal_flag[1]', 'CHAR(1)') as approved_for_disposal_flag
						 , p.v.value('approved_by_nrc_flag[1]', 'CHAR(1)') as approved_by_nrc_flag
						 , p.v.value('approved_for_alternate_disposal_flag[1]', 'CHAR(1)') as approved_for_alternate_disposal_flag
						 , p.v.value('nrc_exempted_flag[1]', 'CHAR(1)') as nrc_exempted_flag
						 , p.v.value('released_from_radiological_control_flag[1]', 'CHAR(1)') as released_from_radiological_control_flag
						 , p.v.value('DOD_non_licensed_disposal_flag[1]', 'CHAR(1)') as DOD_non_licensed_disposal_flag
						 , p.v.value('byproduct_sum_of_all_isotopes[1]', 'VARCHAR(255)') as byproduct_sum_of_all_isotopes
						 , p.v.value('source_sof_calculations[1]', 'VARCHAR(4000)') as source_sof_calculations
						 , p.v.value('special_nuclear_sum_of_all_isotopes[1]', 'VARCHAR(255)') as special_nuclear_sum_of_all_isotopes
						 , p.v.value('additional_inventory_flag[1]', 'CHAR(1)') as additional_inventory_flag
						 , @web_userid as created_by, GETDATE() as date_created, @web_userid as modified_by, GETDATE() as date_modified
						 , p.v.value('specifically_exempted_flag[1]', 'CHAR(1)') as specifically_exempted_flag
						 , NULL as material_exempted_by_usa_flag, NULL as material_released_by_government_flag
						 , p.v.value('USEI_WAC_table_C1_flag[1]', 'CHAR(1)') as USEI_WAC_table_C1_flag
						 , p.v.value('USEI_WAC_table_C2_flag[1]', 'CHAR(1)') as USEI_WAC_table_C2_flag
						 , p.v.value('USEI_WAC_table_C3_flag[1]', 'CHAR(1)') as USEI_WAC_table_C3_flag
						 , p.v.value('USEI_WAC_table_C4a_flag[1]', 'CHAR(1)') as USEI_WAC_table_C4a_flag
						 , p.v.value('USEI_WAC_table_C4b_flag[1]', 'CHAR(1)') as USEI_WAC_table_C4b_flag
						 , p.v.value('USEI_WAC_table_C4c_flag[1]', 'CHAR(1)') as USEI_WAC_table_C4c_flag
						 , p.v.value('waste_type[1]', 'CHAR(1)') as waste_type
					  FROM @Data.nodes('Radioactive')p(v);
				END
			ELSE
				BEGIN		  
					SET @isExist = 1;
					SELECT @isExistform_id = form_id FROM dbo.FormRadioactive WHERE wcr_id = @form_id and wcr_rev_id = @revision_id;

					UPDATE dbo.FormRadioactive
					   SET locked = 'U'
					     , uranium_thorium_flag = p.v.value('uranium_thorium_flag[1]', 'CHAR(1)')
						 , uranium_source_material = p.v.value('uranium_source_material[1]', 'CHAR(1)')
						 , uranium_concentration = p.v.value('uranium_concentration[1]', 'VARCHAR(100)')
						 , radium_226_flag = p.v.value('radium_226_flag[1]', 'CHAR(1)')
						 , radium_226_concentration = p.v.value('radium_226_concentration[1][not(@xsi:nil = "true")]', 'FLOAT')
						 , radium_228_flag = p.v.value('radium_228_flag[1]', 'CHAR(1)')
						 , radium_228_concentration = p.v.value('radium_228_concentration[1][not(@xsi:nil = "true")]', 'FLOAT')
						 , lead_210_flag = p.v.value('lead_210_flag[1]', 'CHAR(1)')
						 , lead_210_concentration = p.v.value('lead_210_concentration[1][not(@xsi:nil = "true")]', 'FLOAT')
						 , potassium_40_flag = p.v.value('potassium_40_flag[1]', 'CHAR(1)')
						 , potassium_40_concentration = p.v.value('potassium_40_concentration[1][not(@xsi:nil = "true")]', 'FLOAT')
						 , exempt_byproduct_material_flag = p.v.value('exempt_byproduct_material_flag[1]', 'CHAR(1)')
						 , special_nuclear_material_flag = p.v.value('special_nuclear_material_flag[1]', 'CHAR(1)')
						 , accelerator_flag = p.v.value('accelerator_flag[1]', 'CHAR(1)')
						 , generated_in_particle_accelerator_flag = p.v.value('generated_in_particle_accelerator_flag[1]', 'CHAR(1)')
						 , approved_for_disposal_flag = p.v.value('approved_for_disposal_flag[1]', 'CHAR(1)')
						 , approved_by_nrc_flag = p.v.value('approved_by_nrc_flag[1]', 'CHAR(1)')
						 , approved_for_alternate_disposal_flag = p.v.value('approved_for_alternate_disposal_flag[1]', 'CHAR(1)')
						 , nrc_exempted_flag = p.v.value('nrc_exempted_flag[1]', 'CHAR(1)')
						 , released_from_radiological_control_flag = p.v.value('released_from_radiological_control_flag[1]', 'CHAR(1)')
						 , DOD_non_licensed_disposal_flag = p.v.value('DOD_non_licensed_disposal_flag[1]', 'CHAR(1)')
						 , byproduct_sum_of_all_isotopes = p.v.value('byproduct_sum_of_all_isotopes[1]','VARCHAR(255)')
						 , source_sof_calculations = p.v.value('source_sof_calculations[1]','VARCHAR(4000)')
						 , special_nuclear_sum_of_all_isotopes = p.v.value('special_nuclear_sum_of_all_isotopes[1]','VARCHAR(255)')
						 , additional_inventory_flag= p.v.value('additional_inventory_flag[1]', 'CHAR(1)')
						 , modified_by = @web_userid, date_modified = GETDATE()
						 , specifically_exempted_flag = p.v.value('specifically_exempted_flag[1]', 'CHAR(1)')
						 , USEI_WAC_table_C1_flag = p.v.value('USEI_WAC_table_C1_flag[1]', 'CHAR(1)')
						 , USEI_WAC_table_C2_flag = p.v.value('USEI_WAC_table_C2_flag[1]', 'CHAR(1)')
						 , USEI_WAC_table_C3_flag  = p.v.value('USEI_WAC_table_C3_flag[1]', 'CHAR(1)')
						 , USEI_WAC_table_C4a_flag =  p.v.value('USEI_WAC_table_C4a_flag[1]', 'CHAR(1)')
						 , USEI_WAC_table_C4b_flag = p.v.value('USEI_WAC_table_C4b_flag[1]', 'CHAR(1)')
						 , USEI_WAC_table_C4c_flag = p.v.value('USEI_WAC_table_C4c_flag[1]', 'CHAR(1)')
						 , waste_type = p.v.value('waste_type[1]', 'CHAR(1)')
					  FROM @Data.nodes('Radioactive')p(v)
					 WHERE wcr_id = @form_id and wcr_rev_id = @revision_id;
				END

			SET @form_id = CASE WHEN @isExist = 1 THEN @isExistform_id ELSE @newForm_id END

			--print @form_id
			--RadioActiveExempt
			IF EXISTS (SELECT 1 FROM dbo.FormRadioactiveExempt WHERE form_id = @form_id and revision_id = @revision_id)
				BEGIN
		    		DELETE FROM dbo.FormRadioactiveExempt WHERE form_id = @form_id and revision_id = @revision_id;
				END		

				INSERT INTO FormRadioactiveExempt(form_id, revision_id, line_id
					 , item_name, total_number_in_shipment
					 , radionuclide_contained, activity, disposal_site_tsdf_code, cited_regulatory_exemption
					 , created_by, date_created, modified_by, date_modified) 
				SELECT @form_id as form_id, @revision_id as revision_id, p.v.value('line_id[1]','int') as line_id
					 , p.v.value('item_name[1]','VARCHAR(80)') as item_name
					 , p.v.value('total_number_in_shipment[1][not(@xsi:nil = "true")]','VARCHAR(50)') as total_number_in_shipment
					 , p.v.value('radionuclide_contained[1]','VARCHAR(10)') as radionuclide_contained
					 , p.v.value('activity[1][not(@xsi:nil = "true")]','VARCHAR(50)') as activity
					 , p.v.value('disposal_site_tsdf_code[1]','VARCHAR(15)') as disposal_site_tsdf_code
					 , p.v.value('cited_regulatory_exemption[1]','VARCHAR(20)') as cited_regulatory_exemption
					 , @web_userid as created_by, GETDATE() as date_created, @web_userid as modified_by, GETDATE() as date_modified
				  FROM @Data.nodes('Radioactive/RadioactiveExempt/RadioactiveExempt')p(v);
				 --WHERE form_id = @form_id and revision_id =  @revision_id;
				 
				---RadioactiveUSEI
				IF EXISTS (SELECT 1 FROM dbo.FormRadioactiveUSEI WHERE form_id = @form_id and revision_id = @revision_id)
					BEGIN
						DELETE FROM dbo.FormRadioactiveUSEI WHERE form_id = @form_id and revision_id = @revision_id;
					END
				
				INSERT INTO dbo.FormRadioactiveUSEI (form_id, revision_id, line_id
					 , radionuclide, concentration
					 , created_by, date_created, modified_by, date_modified, const_id) 
				SELECT @form_id as form_id, @revision_id as revision_id, p.v.value('line_id[1]','int') as line_id
					 , p.v.value('radionuclide[1]', 'VARCHAR(255)') as radionuclide
					 , p.v.value('concentration[1][not(@xsi:nil = "true")]', 'FLOAT') as concentration
					 , @web_userid as created_by, GETDATE() as date_created, @web_userid as modified_by, GETDATE() as date_modified
					 , p.v.value('const_id[1]', 'INT') as const_id
				  FROM @Data.nodes('Radioactive/RadioactiveUSEI/RadioactiveUSEI')p(v);
		END
END;
GO

GRANT EXECUTE ON [dbo].[sp_Radioactive_insert_update] TO COR_USER;
GO