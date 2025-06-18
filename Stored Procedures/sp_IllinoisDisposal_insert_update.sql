ALTER PROCEDURE dbo.sp_IllinoisDisposal_insert_update 
	  @Data XML
	, @form_id INT
	, @revision_id INT
	, @web_userid VARCHAR(100)
AS
/* ******************************************************************    
Insert / update Illinois Disposal form  (Part of form wcr insert / update)  
  Updated By   : Ranjini C
  Updated On   : 08-AUGUST-2024
  Ticket       : 93217
  Decription   : This procedure is used to assign web_userid to created_by and modified_by columns.
  Updated by Jonathon Carey for Titan 05/08/2025
  --Updated by Blair Christensen for Titan 05/21/2025
inputs      
 Data -- XML data having values for the FormIllinoisDisposal table objects  
 Form ID  
 Revision ID
****************************************************************** */
BEGIN
	IF NOT EXISTS (
				SELECT 1
				  FROM dbo.FormIllinoisDisposal
				 WHERE wcr_id = @form_id
					AND wcr_rev_id = @revision_id)
		BEGIN
			DECLARE @newForm_id INTEGER
				  , @newrev_id INTEGER = 1
				  , @FormWCR_uid INTEGER;

			EXEC @newForm_id = sp_sequence_next 'form.form_id'

			IF EXISTS (SELECT 1 FROM dbo.FormWCR WHERE form_id = @form_id AND revision_id = @revision_id)
				BEGIN
					SELECT @FormWCR_uid = formWCR_uid
					  FROM dbo.FormWCR
					 WHERE form_id = @form_id
					   AND revision_id = @revision_id;
				END
			ELSE
				BEGIN
					SET @FormWCR_uid = NULL;
				END

			INSERT INTO dbo.FormIllinoisDisposal (form_id, revision_id, formWCR_uid
				 , wcr_id, wcr_rev_id, locked
				 , none_apply_flag
				 , incecticides_flag
				 , pesticides_flag
				 , herbicides_flag
				 , household_waste_flag
				 , carcinogen_flag
				 , other_flag
				 , other_specify
				 , sulfide_10_250_flag
				 , universal_waste_flag
				 , characteristic_sludge_flag
				 , virgin_unused_product_flag
				 , spent_material_flag
				 , cyanide_plating_on_site_flag
				 , substitute_commercial_product_flag
				 , by_product_flag
				 , rx_lime_flammable_gas_flag
				 , pollution_control_waste_IL_flag
				 , industrial_process_waste_IL_flag
				 , phenol_gt_1000_flag
				 , generator_state_id
				 , d004_above_PQL, d005_above_PQL, d006_above_PQL, d007_above_PQL, d008_above_PQL, d009_above_PQL
				 , d010_above_PQL, d011_above_PQL, d012_above_PQL, d013_above_PQL, d014_above_PQL
				 , d015_above_PQL, d016_above_PQL, d017_above_PQL, d018_above_PQL, d019_above_PQL
				 , d020_above_PQL, d021_above_PQL, d022_above_PQL, d023_above_PQL, d024_above_PQL
				 , d025_above_PQL, d026_above_PQL, d027_above_PQL, d028_above_PQL, d029_above_PQL
				 , d030_above_PQL, d031_above_PQL, d032_above_PQL, d033_above_PQL, d034_above_PQL, d035_above_PQL
				 , d036_above_PQL, d037_above_PQL, d038_above_PQL, d039_above_PQL
				 , d040_above_PQL, d041_above_PQL, d042_above_PQL, d043_above_PQL
				 , created_by, date_created, date_modified, modified_by
				 , generator_certification_flag
				 , certify_flag
				 )
			SELECT @newForm_id as form_id, @newrev_id as revision_id, @FormWCR_uid as formWCR_uid
				 , @form_id as wcr_id, @revision_id as wcr_rev_id, 'U' as locked
				 , p.v.value('none_apply_flag[1]', 'CHAR(1)') as none_apply_flag
				 , p.v.value('incecticides_flag[1]', 'CHAR(1)') as incecticides_flag
				 , p.v.value('pesticides_flag[1]', 'CHAR(1)') as pesticides_flag
				 , p.v.value('herbicides_flag[1]', 'CHAR(1)') as herbicides_flag
				 , p.v.value('household_waste_flag[1]', 'CHAR(1)') as household_waste_flag
				 , p.v.value('carcinogen_flag[1]', 'CHAR(1)') as carcinogen_flag
				 , p.v.value('other_flag[1]', 'CHAR(1)') as other_flag
				 , p.v.value('other_specify[1]', 'char(80)') as other_specify
				 , p.v.value('sulfide_10_250_flag[1]', 'CHAR(1)') as sulfide_10_250_flag
				 , p.v.value('universal_waste_flag[1]', 'CHAR(1)') as universal_waste_flag
				 , p.v.value('characteristic_sludge_flag[1]', 'CHAR(1)') as characteristic_sludge_flag
				 , p.v.value('virgin_unused_product_flag[1]', 'CHAR(1)') as virgin_unused_product_flag
				 , p.v.value('spent_material_flag[1]', 'CHAR(1)') as spent_material_flag
				 , p.v.value('cyanide_plating_on_site_flag[1]', 'CHAR(1)') as cyanide_plating_on_site_flag
				 , p.v.value('substitute_commercial_product_flag[1]', 'CHAR(1)') as substitute_commercial_product_flag
				 , p.v.value('by_product_flag[1]', 'CHAR(1)') as by_product_flag
				 , p.v.value('rx_lime_flammable_gas_flag[1]', 'CHAR(1)') as rx_lime_flammable_gas_flag
				 , p.v.value('pollution_control_waste_IL_flag[1]', 'CHAR(1)') as pollution_control_waste_IL_flag
				 , p.v.value('industrial_process_waste_IL_flag[1]', 'CHAR(1)') as industrial_process_waste_IL_flag
				 , p.v.value('phenol_gt_1000_flag[1]', 'CHAR(1)') as phenol_gt_1000_flag
				 , p.v.value('generator_state_id[1]', 'VARCHAR(40)') as generator_state_id
				 , p.v.value('d004_above_PQL[1]', 'CHAR(1)') as d004_above_PQL
				 , p.v.value('d005_above_PQL[1]', 'CHAR(1)') as d005_above_PQL
				 , p.v.value('d006_above_PQL[1]', 'CHAR(1)') as d006_above_PQL
				 , p.v.value('d007_above_PQL[1]', 'CHAR(1)') as d007_above_PQL
				 , p.v.value('d008_above_PQL[1]', 'CHAR(1)') as d008_above_PQL
				 , p.v.value('d009_above_PQL[1]', 'CHAR(1)') as d009_above_PQL
				 , p.v.value('d010_above_PQL[1]', 'CHAR(1)') as d010_above_PQL
				 , p.v.value('d011_above_PQL[1]', 'CHAR(1)') as d011_above_PQL
				 , p.v.value('d012_above_PQL[1]', 'CHAR(1)') as d012_above_PQL
				 , p.v.value('d013_above_PQL[1]', 'CHAR(1)') as d013_above_PQL
				 , p.v.value('d014_above_PQL[1]', 'CHAR(1)') as d014_above_PQL
				 , p.v.value('d015_above_PQL[1]', 'CHAR(1)') as d015_above_PQL
				 , p.v.value('d016_above_PQL[1]', 'CHAR(1)') as d016_above_PQL
				 , p.v.value('d017_above_PQL[1]', 'CHAR(1)') as d017_above_PQL
				 , p.v.value('d018_above_PQL[1]', 'CHAR(1)') as d018_above_PQL
				 , p.v.value('d019_above_PQL[1]', 'CHAR(1)') as d019_above_PQL
				 , p.v.value('d020_above_PQL[1]', 'CHAR(1)') as d020_above_PQL
				 , p.v.value('d021_above_PQL[1]', 'CHAR(1)') as d021_above_PQL
				 , p.v.value('d022_above_PQL[1]', 'CHAR(1)') as d022_above_PQL
				 , p.v.value('d023_above_PQL[1]', 'CHAR(1)') as d023_above_PQL
				 , p.v.value('d024_above_PQL[1]', 'CHAR(1)') as d024_above_PQL
				 , p.v.value('d025_above_PQL[1]', 'CHAR(1)') as d025_above_PQL
				 , p.v.value('d026_above_PQL[1]', 'CHAR(1)') as d026_above_PQL
				 , p.v.value('d027_above_PQL[1]', 'CHAR(1)') as d027_above_PQL
				 , p.v.value('d028_above_PQL[1]', 'CHAR(1)') as d028_above_PQL
				 , p.v.value('d029_above_PQL[1]', 'CHAR(1)') as d029_above_PQL
				 , p.v.value('d030_above_PQL[1]', 'CHAR(1)') as d030_above_PQL
				 , p.v.value('d031_above_PQL[1]', 'CHAR(1)') as d031_above_PQL
				 , p.v.value('d032_above_PQL[1]', 'CHAR(1)') as d032_above_PQL
				 , p.v.value('d033_above_PQL[1]', 'CHAR(1)') as d033_above_PQL
				 , p.v.value('d034_above_PQL[1]', 'CHAR(1)') as d034_above_PQL
				 , p.v.value('d035_above_PQL[1]', 'CHAR(1)') as d035_above_PQL
				 , p.v.value('d036_above_PQL[1]', 'CHAR(1)') as d036_above_PQL
				 , p.v.value('d037_above_PQL[1]', 'CHAR(1)') as d037_above_PQL
				 , p.v.value('d038_above_PQL[1]', 'CHAR(1)') as d038_above_PQL
				 , p.v.value('d039_above_PQL[1]', 'CHAR(1)') as d039_above_PQL
				 , p.v.value('d040_above_PQL[1]', 'CHAR(1)') as d040_above_PQL
				 , p.v.value('d041_above_PQL[1]', 'CHAR(1)') as d041_above_PQL
				 , p.v.value('d042_above_PQL[1]', 'CHAR(1)') as d042_above_PQL
				 , p.v.value('d043_above_PQL[1]', 'CHAR(1)') as d043_above_PQL
				 , @web_userid as created_by, GETDATE() as date_created, GETDATE() as date_modified, @web_userid as modified_by
				 , p.v.value('generator_certification_flag[1]', 'CHAR(1)') as generator_certification_flag
				 , p.v.value('certify_flag[1]', 'CHAR(1)') as certify_flag
			  FROM @Data.nodes('IllinoisDisposal') p(v);
		END
	ELSE
		BEGIN
			UPDATE dbo.FormIllinoisDisposal
			   SET locked = 'U'
				 , none_apply_flag = p.v.value('none_apply_flag[1]', 'CHAR(1)')
				 , incecticides_flag = p.v.value('incecticides_flag[1]', 'CHAR(1)')
				 , pesticides_flag = p.v.value('pesticides_flag[1]', 'CHAR(1)')
				 , herbicides_flag = p.v.value('herbicides_flag[1]', 'CHAR(1)')
				 , household_waste_flag = p.v.value('household_waste_flag[1]', 'CHAR(1)')
				 , carcinogen_flag = p.v.value('carcinogen_flag[1]', 'CHAR(1)')
				 , other_flag = p.v.value('other_flag[1]', 'CHAR(1)')
				 , other_specify = p.v.value('other_specify[1]', 'char(80)')
				 , sulfide_10_250_flag = p.v.value('sulfide_10_250_flag[1]', 'CHAR(1)')
				 , universal_waste_flag = p.v.value('universal_waste_flag[1]', 'CHAR(1)')
				 , characteristic_sludge_flag = p.v.value('characteristic_sludge_flag[1]', 'CHAR(1)')
				 , virgin_unused_product_flag = p.v.value('virgin_unused_product_flag[1]', 'CHAR(1)')
				 , spent_material_flag = p.v.value('spent_material_flag[1]', 'CHAR(1)')
				 , cyanide_plating_on_site_flag = p.v.value('cyanide_plating_on_site_flag[1]', 'CHAR(1)')
				 , substitute_commercial_product_flag = p.v.value('substitute_commercial_product_flag[1]', 'CHAR(1)')
				 , by_product_flag = p.v.value('by_product_flag[1]', 'CHAR(1)')
				 , rx_lime_flammable_gas_flag = p.v.value('rx_lime_flammable_gas_flag[1]', 'CHAR(1)')
				 , pollution_control_waste_IL_flag = p.v.value('pollution_control_waste_IL_flag[1]', 'CHAR(1)')
				 , industrial_process_waste_IL_flag = p.v.value('industrial_process_waste_IL_flag[1]', 'CHAR(1)')
				 , phenol_gt_1000_flag = p.v.value('phenol_gt_1000_flag[1]', 'CHAR(1)')
				 , generator_state_id = p.v.value('generator_state_id[1]', 'VARCHAR(40)')
				 , d004_above_PQL = p.v.value('d004_above_PQL[1]', 'CHAR(1)')
				 , d005_above_PQL = p.v.value('d005_above_PQL[1]', 'CHAR(1)')
				 , d006_above_PQL = p.v.value('d006_above_PQL[1]', 'CHAR(1)')
				 , d007_above_PQL = p.v.value('d007_above_PQL[1]', 'CHAR(1)')
				 , d008_above_PQL = p.v.value('d008_above_PQL[1]', 'CHAR(1)')
				 , d009_above_PQL = p.v.value('d009_above_PQL[1]', 'CHAR(1)')
				 , d010_above_PQL = p.v.value('d010_above_PQL[1]', 'CHAR(1)')
				 , d011_above_PQL = p.v.value('d011_above_PQL[1]', 'CHAR(1)')
				 , d012_above_PQL = p.v.value('d012_above_PQL[1]', 'CHAR(1)')
				 , d013_above_PQL = p.v.value('d013_above_PQL[1]', 'CHAR(1)')
				 , d014_above_PQL = p.v.value('d014_above_PQL[1]', 'CHAR(1)')
				 , d015_above_PQL = p.v.value('d015_above_PQL[1]', 'CHAR(1)')
				 , d016_above_PQL = p.v.value('d016_above_PQL[1]', 'CHAR(1)')
				 , d017_above_PQL = p.v.value('d017_above_PQL[1]', 'CHAR(1)')
				 , d018_above_PQL = p.v.value('d018_above_PQL[1]', 'CHAR(1)')
				 , d019_above_PQL = p.v.value('d019_above_PQL[1]', 'CHAR(1)')
				 , d020_above_PQL = p.v.value('d020_above_PQL[1]', 'CHAR(1)')
				 , d021_above_PQL = p.v.value('d021_above_PQL[1]', 'CHAR(1)')
				 , d022_above_PQL = p.v.value('d022_above_PQL[1]', 'CHAR(1)')
				 , d023_above_PQL = p.v.value('d023_above_PQL[1]', 'CHAR(1)')
				 , d024_above_PQL = p.v.value('d024_above_PQL[1]', 'CHAR(1)')
				 , d025_above_PQL = p.v.value('d025_above_PQL[1]', 'CHAR(1)')
				 , d026_above_PQL = p.v.value('d026_above_PQL[1]', 'CHAR(1)')
				 , d027_above_PQL = p.v.value('d027_above_PQL[1]', 'CHAR(1)')
				 , d028_above_PQL = p.v.value('d028_above_PQL[1]', 'CHAR(1)')
				 , d029_above_PQL = p.v.value('d029_above_PQL[1]', 'CHAR(1)')
				 , d030_above_PQL = p.v.value('d030_above_PQL[1]', 'CHAR(1)')
				 , d031_above_PQL = p.v.value('d031_above_PQL[1]', 'CHAR(1)')
				 , d032_above_PQL = p.v.value('d032_above_PQL[1]', 'CHAR(1)')
				 , d033_above_PQL = p.v.value('d033_above_PQL[1]', 'CHAR(1)')
				 , d034_above_PQL = p.v.value('d034_above_PQL[1]', 'CHAR(1)')
				 , d035_above_PQL = p.v.value('d035_above_PQL[1]', 'CHAR(1)')
				 , d036_above_PQL = p.v.value('d036_above_PQL[1]', 'CHAR(1)')
				 , d037_above_PQL = p.v.value('d037_above_PQL[1]', 'CHAR(1)')
				 , d038_above_PQL = p.v.value('d038_above_PQL[1]', 'CHAR(1)')
				 , d039_above_PQL = p.v.value('d039_above_PQL[1]', 'CHAR(1)')
				 , d040_above_PQL = p.v.value('d040_above_PQL[1]', 'CHAR(1)')
				 , d041_above_PQL = p.v.value('d041_above_PQL[1]', 'CHAR(1)')
				 , d042_above_PQL = p.v.value('d042_above_PQL[1]', 'CHAR(1)')
				 , d043_above_PQL = p.v.value('d043_above_PQL[1]', 'CHAR(1)')
				 , date_modified = GETDATE()
				 , modified_by = @web_userid
				 , generator_certification_flag = p.v.value('generator_certification_flag[1]', 'CHAR(1)')
				 , certify_flag = p.v.value('certify_flag[1]', 'CHAR(1)')
			  FROM @Data.nodes('IllinoisDisposal') p(v)
			 WHERE wcr_id = @form_id
			   AND wcr_rev_id = @revision_id;
		END

	DECLARE @h2sHCN INT
			, @Standard INT
			, @F_signing_name NVARCHAR(40)
			, @signing_name NVARCHAR(40);

	SELECT @h2sHCN = form_signature_type_id
	  FROM dbo.FormSignatureType
	 WHERE [description] = 'H2S/HCN';

	SELECT @Standard = form_signature_type_id
	  FROM dbo.FormSignatureType
	 WHERE [description] = 'Standard';

	SELECT @F_signing_name = p.v.value('F_signing_name[1]', 'varchar(40)')
	  FROM @Data.nodes('IllinoisDisposal') p(v);

	SELECT @signing_name = p.v.value('signing_name[1]', 'varchar(40)')
	  FROM @Data.nodes('IllinoisDisposal') p(v);

	IF ((@F_signing_name IS NOT NULL AND @F_signing_name <> '')
		AND NOT EXISTS (
			SELECT form_id
				FROM dbo.FormSignature
				WHERE form_id = @form_id
				AND revision_id = @revision_id
				AND form_signature_type_id = @h2sHCN)
		)
		BEGIN
			INSERT INTO dbo.FormSignature (form_id, revision_id, form_signature_type_id
					--, form_version_id, sign_company
					, sign_name
					--, sign_title, sign_email, sign_phone, sign_fax, sign_address, sign_city, sign_state, sign_zip_code
					, date_added
					--, sign_comment_internal, logon, contact_id
					--, e_signature_type_id, e_signature_envelope_id, e_signature_url, e_signature_status
					--, web_userid, created_by, date_created
					, modified_by, date_modified
					)
			SELECT @form_id as form_id, @revision_id as revision_id, @h2sHCN as form_signature_type_id
					, p.v.value('F_signing_name[1]', 'VARCHAR(40)') as sign_name
					, GETDATE() as date_added
					, SYSTEM_USER as modified_by, GETDATE() as date_modified
				FROM @Data.nodes('IllinoisDisposal') p(v);
		END

	IF ((@signing_name IS NOT NULL AND @signing_name <> '')
		AND NOT EXISTS (
			SELECT form_id
				FROM dbo.FormSignature
				WHERE form_id = @form_id
				AND revision_id = @revision_id
				AND form_signature_type_id = @Standard)
		)
		BEGIN
			INSERT INTO dbo.FormSignature (form_id, revision_id, form_signature_type_id
							--, form_version_id, sign_company
							, sign_name
							--, sign_title, sign_email, sign_phone, sign_fax, sign_address, sign_city, sign_state, sign_zip_code
							, date_added
							--, sign_comment_internal, logon, contact_id
							--, e_signature_type_id, e_signature_envelope_id, e_signature_url, e_signature_status
							--, web_userid, created_by, date_created
							, modified_by, date_modified
							)
			SELECT @form_id as form_id, @revision_id as revision_id, @Standard as form_signature_type_id
				 , p.v.value('signing_name[1]', 'VARCHAR(40)') as sign_name
				 , GETDATE() as date_added
				 , SYSTEM_USER as modified_by, GETDATE() as date_modified
			  FROM @Data.nodes('IllinoisDisposal') p(v);
		END
END
GO

GRANT EXECUTE ON [dbo].[sp_IllinoisDisposal_insert_update] TO COR_USER;
GO
