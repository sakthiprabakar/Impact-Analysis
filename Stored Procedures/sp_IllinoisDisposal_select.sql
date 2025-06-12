
CREATE PROCEDURE [dbo].[sp_IllinoisDisposal_select](
	
		 @form_id INT,
		 @revision_id	INT

)
AS

/***********************************************************************************

	Author		: SathickAli
	Updated On	: 20-Dec-2018
	Type		: Store Procedure 
	Object Name	: [dbo].[sp_IllinoisDisposal_select]

	Description	: 
                Procedure to get IllinoisDisposal profile details and status (i.e Clean, partial, completed)
				

	Input		:
				@form_id
				@revision_id
				
																
	Execution Statement	: EXEC [plt_ai].[dbo].[sp_IllinoisDisposal_select] 518997,1

*************************************************************************************/
BEGIN
	DECLARE @section_status CHAR(1);
		SELECT @section_status =section_status FROM formsectionstatus WHERE form_id=@form_id and section='ID'

		DECLARE @certify_flag_count int = (SELECT TOP 1 count(*) FROM FormSignature WHERE form_id = @form_id  and revision_id=  @revision_id)

	SELECT
			COALESCE(WD.wcr_id, @form_id) as wcr_id,
			COALESCE(WD.wcr_rev_id, @revision_id) as wcr_rev_id,
			ISNULL(WD.form_id,'') AS form_id,
			ISNULL(WD.revision_id,'') AS revision_id ,
			ISNULL(	WD.locked,'') AS locked,
			ISNULL(	WD.none_apply_flag,'') AS none_apply_flag,
			ISNULL(	WD.incecticides_flag,'') AS incecticides_flag,
			ISNULL(	WD.pesticides_flag,'') AS pesticides_flag,
			ISNULL(	WD.herbicides_flag,'') AS herbicides_flag,
			ISNULL(	WD.household_waste_flag,'') AS household_waste_flag,
			ISNULL(	WD.carcinogen_flag,'') AS carcinogen_flag,
			ISNULL(	WD.other_flag,'') AS other_flag,
			ISNULL(	WD.other_specify,'') AS other_specify,
			ISNULL(	WD.sulfide_10_250_flag,'') AS sulfide_10_250_flag,
			ISNULL(	WD.universal_waste_flag,'') AS universal_waste_flag,
			ISNULL(	WD.characteristic_sludge_flag,'') AS characteristic_sludge_flag,
			ISNULL(	WD.virgin_unused_product_flag,'') AS virgin_unused_product_flag,
			ISNULL(	WD.spent_material_flag,'') AS spent_material_flag,
			ISNULL(	WD.cyanide_plating_on_site_flag,'') AS cyanide_plating_on_site_flag,
			ISNULL(	WD.substitute_commercial_product_flag,'') AS substitute_commercial_product_flag,
			ISNULL(	WD.by_product_flag,'') AS by_product_flag,
			ISNULL(	WD.rx_lime_flammable_gas_flag,'') AS rx_lime_flammable_gas_flag,
			ISNULL(	WD.pollution_control_waste_IL_flag,'') AS pollution_control_waste_IL_flag,
			ISNULL(	WD.industrial_process_waste_IL_flag,'') AS industrial_process_waste_IL_flag,
			ISNULL(	WD.phenol_gt_1000_flag,'') AS phenol_gt_1000_flag,
			ISNULL(	WD.generator_state_id,'') AS generator_state_id,
			ISNULL(	WD.d004_above_PQL,'') AS d004_above_PQL,
			ISNULL(	WD.d005_above_PQL,'') AS d005_above_PQL,
			ISNULL(	WD.d006_above_PQL,'') AS d006_above_PQL,
			ISNULL(	WD.d007_above_PQL,'') AS d007_above_PQL,
			ISNULL(	WD.d008_above_PQL,'') AS d008_above_PQL,
			ISNULL(	WD.d009_above_PQL,'') AS d009_above_PQL,
			ISNULL(	WD.d010_above_PQL,'') AS d010_above_PQL,
			ISNULL(	WD.d011_above_PQL,'') AS d011_above_PQL,
			ISNULL(	WD.d012_above_PQL,'') AS d012_above_PQL,
			ISNULL(	WD.d013_above_PQL,'') AS d013_above_PQL,
			ISNULL(	WD.d014_above_PQL,'') AS d014_above_PQL,
			ISNULL(	WD.d015_above_PQL,'') AS d015_above_PQL,
			ISNULL(	WD.d016_above_PQL,'') AS d016_above_PQL,
			ISNULL(	WD.d017_above_PQL,'') AS d017_above_PQL,
			ISNULL(	WD.d018_above_PQL,'') AS d018_above_PQL,
			ISNULL(	WD.d019_above_PQL,'') AS d019_above_PQL,
			ISNULL(	WD.d020_above_PQL,'') AS d020_above_PQL,
			ISNULL(	WD.d021_above_PQL,'') AS d021_above_PQL,
			ISNULL(	WD.d022_above_PQL,'') AS d022_above_PQL,
			ISNULL(	WD.d023_above_PQL,'') AS d023_above_PQL,
			ISNULL(	WD.d024_above_PQL,'') AS d024_above_PQL,
			ISNULL(	WD.d025_above_PQL,'') AS d025_above_PQL,
			ISNULL(	WD.d026_above_PQL,'') AS d026_above_PQL,
			ISNULL(	WD.d027_above_PQL,'') AS d027_above_PQL,
			ISNULL(	WD.d028_above_PQL,'') AS d028_above_PQL,
			ISNULL(	WD.d029_above_PQL,'') AS d029_above_PQL,
			ISNULL(	WD.d030_above_PQL,'') AS d030_above_PQL,
			ISNULL(	WD.d031_above_PQL,'') AS d031_above_PQL,
			ISNULL(	WD.d032_above_PQL,'') AS d032_above_PQL,
			ISNULL(	WD.d033_above_PQL,'') AS d033_above_PQL,
			ISNULL(	WD.d034_above_PQL,'') AS d034_above_PQL,
			ISNULL(	WD.d035_above_PQL,'') AS d035_above_PQL,
			ISNULL(	WD.d036_above_PQL,'') AS d036_above_PQL,
			ISNULL(	WD.d037_above_PQL,'') AS d037_above_PQL,
			ISNULL(	WD.d038_above_PQL,'') AS d038_above_PQL,
			ISNULL(	WD.d039_above_PQL,'') AS d039_above_PQL, 
			ISNULL(	WD.d040_above_PQL,'') AS d040_above_PQL,
			ISNULL(	WD.d041_above_PQL,'') AS d041_above_PQL,
			ISNULL(	WD.d042_above_PQL,'') AS d042_above_PQL,
			ISNULL(	WD.d043_above_PQL,'') AS d043_above_PQL,
			ISNULL(	WD.created_by,'') AS created_by,
			ISNULL(	WD.date_created,'') AS date_created,
			ISNULL(	WD.date_modified,'') AS date_modified,
			ISNULL(	WD.modified_by,'') AS modified_by,
			ISNULL(	WCR.generator_name,'') AS generator_name,
			ISNULL(	WCR.epa_id,'') AS epa_id,
			ISNULL(	WCR.waste_common_name,'') AS waste_common_name,
			ISNULL(	WCR.gen_process,'') AS gen_process,
			ISNULL(	WCR.signing_name,'') AS signing_name,
			ISNULL(WCR.signing_title,'') AS signing_title,
			ISNULL(WCR.signing_date,'') AS signing_date
			,@section_status AS IsCompleted,
			ISNULL((SELECT 	WCR.signing_name AS F_signing_name FROM FormSignature WHERE form_id = @form_id  and revision_id=  @revision_id AND form_signature_type_id=(SELECT TOP 1 form_signature_type_id FROM FormSignatureType WHERE [description]='H2S/HCN')),'') AS F_signing_name,
			ISNULL(generator_certification_flag,'') as generator_certification_flag,
			--case when @certify_flag_count > 0 then 'T' else '' end as certify_flag
			ISNULL(WD.certify_flag, '') as certify_flag
		FROM  FormIllinoisDisposal AS WD 
		LEFT JOIN  FormWCR AS WCR ON WD.wcr_id = WCR.form_id AND WD.wcr_rev_id = WCR.revision_id
		WHERE	 
			WCR.form_id = @form_id and  WCR.revision_id = @revision_id
		FOR XML RAW ('IllinoisDisposal'), ROOT ('ProfileModel'), ELEMENTS
			--FOR XML AUTO, ROOT ('ProfileModel'), ELEMENTS) AS FormWCRSelectSection;
END

GO
		
	GRANT EXEC ON [dbo].[sp_IllinoisDisposal_select] TO COR_USER;
	
GO	    
			

		

		