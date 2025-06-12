
CREATE PROCEDURE [dbo].[sp_cylinder_select](
	
		 @form_id INT,
		 @revision_id	INT

)
AS


/***********************************************************************************

	Author		: SathickAli
	Updated On	: 20-Dec-2018
	Type		: Store Procedure 
	Object Name	: [dbo].[sp_cylinder_select]

	Description	: 
                Procedure to get cylinder profile details and status (i.e Clean, partial, completed)
				

	Input		:
				@form_id
				@revision_id
				
																
	Execution Statement	: EXEC [plt_ai].[dbo].[sp_cylinder_select] 893442,1

*************************************************************************************/
BEGIN

DECLARE @section_status CHAR(1);
	SELECT @section_status=section_status FROM formsectionstatus WHERE form_id=@form_id AND revision_id = @revision_id and section='CR'
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
			ISNULL(Cylinder.corrosion_color, '') AS corrosion_color,
			@section_status AS IsCompleted
	FROM  FormCGC  as Cylinder
	WHERE 
		form_id = @form_id and revision_id = @revision_id		
	FOR XML RAW ('Cylinder'), ROOT ('ProfileModel'), ELEMENTS

	END

	GO

	GRANT EXEC ON [dbo].[sp_cylinder_select] TO COR_USER;

	GO
	


			
			

		 