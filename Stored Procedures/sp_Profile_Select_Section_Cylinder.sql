GO
DROP PROCEDURE IF EXISTS [dbo].[sp_Profile_Select_Section_Cylinder]
GO

CREATE PROCEDURE [dbo].[sp_Profile_Select_Section_Cylinder](
 @profileId	INT )
AS
/***********************************************************************************

	CREATED BY		: Monish V
	Updated On	: 23-November-2022
	Ticket		: 58692
	Type		: Store Procedure 
	Object Name	: [dbo].[sp_Profile_Select_Section_Cylinder]

	Description	: 
                Procedure to get cylinder profile details
				

	Input		:
				@profileId
				
																
	Execution Statement	: EXEC [plt_ai].[dbo].[sp_Profile_Select_Section_Cylinder] 

*************************************************************************************/
BEGIN
		SELECT  
			ISNULL(Cylinder.cylinder_quantity,'') AS cylinder_quantity,
			ISNULL(Cylinder.CGA_number,'') AS CGA_number,
			ISNULL(Cylinder.original_label_visible_flag,'') AS original_label_visible_flag,
			ISNULL(Cylinder.manufacturer,'') AS manufacturer,
			ISNULL(Cylinder.markings_warnings_comments,'') AS markings_warnings_comments,
            ISNULL(Cylinder.DOT_shippable_flag, '') AS DOT_shippable_flag,
			ISNULL(Cylinder.DOT_not_shippable_reason, '') AS DOT_not_shippable_reason,
			ISNULL(Cylinder.poisonous_inhalation_flag, '') AS poisonous_inhalation_flag,
			ISNULL(Cylinder.hazard_zone, '') AS hazard_zone,
			ISNULL(Cylinder.DOT_ICC_number, '') AS DOT_ICC_number,
			ISNULL(Cylinder.cylinder_type_id, '') AS cylinder_type_id,
			ISNULL(Cylinder.heaviest_gross_weight, '') AS heaviest_gross_weight,
			ISNULL(Cylinder.heaviest_gross_weight_unit, '') AS heaviest_gross_weight_unit,
            ISNULL(Cylinder.external_condition, '') AS external_condition,
            ISNULL(Cylinder.cylinder_pressure, '') AS cylinder_pressure,
			ISNULL(Cylinder.pressure_relief_device,'') AS pressure_relief_device,
			ISNULL(Cylinder.protective_cover_flag, '') AS protective_cover_flag,
			ISNULL(Cylinder.workable_valve_flag,'') AS workable_valve_flag,
			ISNULL(Cylinder.threads_impaired_flag, '') AS threads_impaired_flag,                            
			ISNULL(Cylinder.valve_condition, '') AS valve_condition,
			ISNULL(Cylinder.corrosion_color, '') AS corrosion_color
		FROM  ProfileCGC  AS Cylinder
		WHERE 
			profile_id = @profileId	
		FOR XML RAW ('Cylinder'), ROOT ('ProfileModel'), ELEMENTS

END

GO
GRANT EXECUTE ON [dbo].[sp_Profile_Select_Section_Cylinder] TO COR_USER;
GO