CREATE OR ALTER PROCEDURE dbo.sp_FormWCR_insert_update_section_D
      @Data XML
	, @form_id INTEGER
	, @revision_id INTEGER
AS
/************************************************************************
Updated By   : Ranjini C
Updated On   : 08-AUGUST-2024
Ticket       : 93217
Decription   : This procedure is used to assign web_userid to created_by and modified_by columns. 
Updated by Blair Christensen for Titan 05/08/2025
**********************************************************************************/
BEGIN
	BEGIN TRY
		IF EXISTS (SELECT 1 FROM dbo.FormWCR WHERE form_id = @form_id and revision_id = @revision_id)
			BEGIN	
				UPDATE dbo.FormWCR
				   SET odor_strength = p.v.value('odor_strength[1]', 'char(1)')
					 , odor_type_ammonia = p.v.value('odor_type_ammonia[1]', 'char(1)')
					 , odor_type_amines = p.v.value('odor_type_amines[1]', 'char(1)')
					 , odor_type_mercaptans = p.v.value('odor_type_mercaptans[1]', 'char(1)')
					 , odor_type_sulfur = p.v.value('odor_type_sulfur[1]', 'char(1)')
					 , odor_type_organic_acid = p.v.value('odor_type_organic_acid[1]', 'char(1)')
					 , odor_other_desc = p.v.value('odor_other_desc[1]', 'VARCHAR(50)')
					 , odor_type_other = p.v.value('odor_type_other[1]', 'char(1)')
					 , consistency_solid = p.v.value('consistency_solid[1]', 'char(1)')
					 , consistency_dust = p.v.value('consistency_dust[1]', 'char(1)')
					 , consistency_debris = p.v.value('consistency_debris[1]', 'char(1)')
					 , consistency_sludge = p.v.value('consistency_sludge[1]', 'char(1)')
					 , consistency_liquid = p.v.value('consistency_liquid[1]', 'char(1)')
					 , consistency_gas_aerosol = p.v.value('consistency_gas_aerosol[1]', 'char(1)')
					 , consistency_varies = p.v.value('consistency_varies[1]', 'char(1)')
					 , color = p.v.value('PrimaryColor[1]','varchar(25)')
								+ IIF(p.v.value('PrimaryColor[1]','varchar(25)') != ''
								OR p.v.value('SecondaryColor[1]','varchar(25)') !='', ':', '')
								+ p.v.value('SecondaryColor[1]','varchar(25)')
					 , liquid_phase = p.v.value('liquid_phase[1]', 'char(1)')
					 , paint_filter_solid_flag = p.v.value('paint_filter_solid_flag[1]', 'char(1)')
					 , incidental_liquid_flag = p.v.value('incidental_liquid_flag[1]', 'char(1)')
					 , ph_lte_2 = p.v.value('ph_lte_2[1]', 'char(1)')
					 , ph_gt_2_lt_5 = p.v.value('ph_gt_2_lt_5[1]', 'char(1)')
					 , ph_gte_5_lte_10 = p.v.value('ph_gte_5_lte_10[1]', 'char(1)')
					 , ph_gt_10_lt_12_5 = p.v.value('ph_gt_10_lt_12_5[1]', 'char(1)')
					 , ph_gte_12_5 = p.v.value('ph_gte_12_5[1]', 'char(1)')
					 , ignitability_compare_symbol = p.v.value('ignitability_compare_symbol[1]', 'varchar(2)')
					 , ignitability_compare_temperature = p.v.value('ignitability_compare_temperature[1][not(@xsi:nil = "true")]', 'int')
					 , ignitability_lt_90 = p.v.value('ignitability_lt_90[1]', 'char(1)')
					 , ignitability_90_139 = p.v.value('ignitability_90_139[1]', 'char(1)')
					 , ignitability_140_199 = p.v.value('ignitability_140_199[1]', 'char(1)')
					 , ignitability_gte_200 = p.v.value('ignitability_gte_200[1]', 'char(1)')
					 , ignitability_does_not_flash = p.v.value('ignitability_does_not_flash[1]', 'char(1)')
					 , ignitability_flammable_solid = p.v.value('ignitability_flammable_solid[1]', 'char(1)')
					 , BTU_lt_gt_5000 = p.v.value('BTU_lt_gt_5000[1]', 'char(1)')
					 , BTU_per_lb = p.v.value('BTU_per_lb[1]', 'CHAR(10)')
					 , handling_issue = p.v.value('handling_issue[1]', 'char(1)')
					 , handling_issue_desc = p.v.value('handling_issue_desc[1]', 'varchar(2000)')
				  FROM @Data.nodes('SectionD')p(v)
				 WHERE form_id = @form_id and revision_id = @revision_id;

			IF EXISTS (SELECT form_id FROM dbo.FormXWCRComposition WHERE form_id = @form_id and revision_id = @revision_id)
				BEGIN
					DELETE FROM dbo.FormXWCRComposition WHERE form_id = @form_id and revision_id=@revision_id;
				END		

			INSERT INTO dbo.FormXWCRComposition (form_id, revision_id
			     , comp_description
			     , comp_from_pct
				 , comp_to_pct
			     , unit
				 , sequence_id
				 , comp_typical_pct)
				SELECT @form_id as form_id, @revision_id as revision_id
				     , ISNULL(p.v.value('comp_description[1]', 'varchar(50)'), '') as comp_description
					 , p.v.value('comp_from_pct[1]', 'FLOAT') as comp_from_pct
					 , p.v.value('comp_to_pct[1]', 'FLOAT') as comp_to_pct
					 , '%' as unit
					 , p.v.value('sequence_id[1]', 'int') as sequence_id
					 , p.v.value('comp_typical_pct[1]', 'FLOAT') as comp_typical_pct
                  FROM @Data.nodes('SectionD/Physical_Description/Composition')p(v);
	   END
	END TRY

	BEGIN CATCH
		DECLARE @procedure NVARCHAR(150) = ERROR_PROCEDURE()
			  , @mailTrack_userid NVARCHAR(60) = 'COR'
			  , @error NVARCHAR(4000) = ERROR_MESSAGE();

		DECLARE @error_description NVARCHAR(4000) = 'Form ID: ' 
				+ CONVERT(NVARCHAR(15), @form_id) 
				+ '-' +  CONVERT(NVARCHAR(15), @revision_id) 
				+ CHAR(13) + CHAR(13) + 'Error Message: ' + isnull(@error, '')
				+ CHAR(13) + CHAR(13) + 'Data:  ' + CONVERT(NVARCHAR(4000), @Data);
				
		EXEC COR_DB.dbo.sp_COR_Exception_MailTrack @web_userid = 'COR', @object = @procedure, @body = @error_description
	END CATCH
END
GO

	GRANT EXECUTE ON [dbo].[sp_FormWCR_insert_update_section_D] TO COR_USER;

GO