USE [PLT_AI]
GO

/***************************************************************************************************************/
DROP PROCEDURE IF EXISTS [dbo].[sp_cylinder_insert_update]
GO
CREATE  PROCEDURE [dbo].[sp_cylinder_insert_update]
       @Data XML,
	   @form_id int,
	   @revision_id int,
	   @web_userid varchar(100)
AS
/* ******************************************************************

	Updated By		: SenthilKumar
	Updated On		: 26th Feb 2019
	Type			: Stored Procedure
	Object Name		: [sp_cylinder_insert_update]
	
	Updated By   : Ranjini C
    Updated On   : 08-AUGUST-2024
    Ticket       : 93217
    Decription   : This procedure is used to assign web_userid to created_by and modified_by columns. 
	Procedure to insert update Cylinder supplementry forms
inputs 	
	@Data
	@form_id
	@revision_id
Samples:
 EXEC [sp_cylinder_insert_update] @Data,@formId,@revisionId
 EXEC [sp_cylinder_insert_update] '<Cylinder>
			<cylinder_quantity>1</cylinder_quantity>
			<CGA_number>dsfds</CGA_number>
			<original_label_visible_flag>T</original_label_visible_flag>
			<manufacturer>T</manufacturer>
			<markings_warnings_comments>hjgsdhjfsjdhfgsjfgjdsf</markings_warnings_comments>
			<DOT_shippable_flag>1</DOT_shippable_flag>
			<DOT_not_shippable_reason>cxvfg</DOT_not_shippable_reason>
			<poisonous_inhalation_flag>T</poisonous_inhalation_flag>
			<hazard_zone>F</hazard_zone>
			<DOT_ICC_number>tested</DOT_ICC_number>
			<cylinder_type_id>1</cylinder_type_id>
			<heaviest_gross_weight>1</heaviest_gross_weight>
			<heaviest_gross_weight_unit>1</heaviest_gross_weight_unit>
			<external_condition>T</external_condition>
			<cylinder_pressure>T</cylinder_pressure>
			<pressure_relief_device></pressure_relief_device>
			<protective_cover_flag>T</protective_cover_flag>
			<workable_valve_flag>T</workable_valve_flag>
			<threads_impaired_flag>T</threads_impaired_flag>
            <valve_condition>F</valve_condition>
            <corrosion_color> DSFDSDSFDS</corrosion_color>
			<created_by>Local</created_by>
			<modified_by>localtest</modified_by>
</Cylinder>', 427534 ,1
***********************************************************************/
DECLARE @cylinder_type_id INT = (SELECT p.v.value('cylinder_type_id[1]','int') from @Data.nodes('Cylinder')p(v)) ;
IF (@cylinder_type_id = 0 )
 BEGIN
   SET @cylinder_type_id = NULL;
 END
  IF(NOT EXISTS(SELECT 1 FROM FormCGC  WITH(NOLOCK) WHERE form_id = @form_id  and revision_id=  @revision_id))
	BEGIN
		INSERT INTO FormCGC(
			form_id,
			revision_id,
			cylinder_quantity,
			CGA_number,
			original_label_visible_flag,
			manufacturer,
			markings_warnings_comments,
			DOT_shippable_flag,
			DOT_not_shippable_reason,
			poisonous_inhalation_flag,
			hazard_zone,
			DOT_ICC_number,
			cylinder_type_id,
			heaviest_gross_weight,
			heaviest_gross_weight_unit,
			external_condition,
			cylinder_pressure,
			pressure_relief_device,
			protective_cover_flag,
			workable_valve_flag,
			threads_impaired_flag,
            valve_condition,
            corrosion_color,
			created_by,
			date_created,
			modified_by,
			date_modified)
        SELECT
			 
		    form_id=@form_id,
			revision_id=@revision_id,
			cylinder_quantity=p.v.value('cylinder_quantity[1]','int'),
			CGA_number=p.v.value('CGA_number[1]','varchar(10)'),
			original_label_visible_flag=p.v.value('original_label_visible_flag[1]','char(1)'),
			manufacturer=p.v.value('manufacturer[1]','varchar(40)'),
			markings_warnings_comments=p.v.value('markings_warnings_comments[1]','varchar(255)'),
			DOT_shippable_flag=p.v.value('DOT_shippable_flag[1]','char(1)'),
			DOT_not_shippable_reason=p.v.value('DOT_not_shippable_reason[1]','varchar(255)'),
			poisonous_inhalation_flag=p.v.value('poisonous_inhalation_flag[1]','char(1)'),
			hazard_zone=p.v.value('hazard_zone[1]','char(1)'),
			DOT_ICC_number=p.v.value('DOT_ICC_number[1]','varchar(15)'),
			cylinder_type_id=@cylinder_type_id,--p.v.value('cylinder_type_id[1]','int'),
			heaviest_gross_weight=p.v.value('heaviest_gross_weight[1]','int'),
			heaviest_gross_weight_unit=p.v.value('heaviest_gross_weight_unit[1]','char(1)'),
			external_condition=p.v.value('external_condition[1]','char(1)'),
			cylinder_pressure=p.v.value('cylinder_pressure[1]','char(1)'),
			pressure_relief_device=p.v.value('pressure_relief_device[1]','char(1)'),
			protective_cover_flag=p.v.value('protective_cover_flag[1]','char(1)'),
			workable_valve_flag=p.v.value('workable_valve_flag[1]','char(1)'),
			threads_impaired_flag=p.v.value('threads_impaired_flag[1]','char(1)'),
            valve_condition=p.v.value('valve_condition[1]','char(1)'),
            corrosion_color=p.v.value('corrosion_color[1]','varchar(20)'),
		    created_by = @web_userid,
			date_created = GETDATE(),
			modified_by = @web_userid,
		    date_modified = GETDATE()
        FROM
            @Data.nodes('Cylinder')p(v)

   END
  ELSE
   BEGIN
        UPDATE  FormCGC
        SET                 
			cylinder_quantity=p.v.value('cylinder_quantity[1]','int'),
			CGA_number=p.v.value('CGA_number[1]','varchar(10)'),
			original_label_visible_flag=p.v.value('original_label_visible_flag[1]','char(1)'),
			manufacturer=p.v.value('manufacturer[1]','varchar(40)'),
			markings_warnings_comments=p.v.value('markings_warnings_comments[1]','varchar(255)'),
			DOT_shippable_flag=p.v.value('DOT_shippable_flag[1]','char(1)'),
			DOT_not_shippable_reason=p.v.value('DOT_not_shippable_reason[1]','varchar(255)'),
			poisonous_inhalation_flag=p.v.value('poisonous_inhalation_flag[1]','char(1)'),
			hazard_zone=p.v.value('hazard_zone[1]','char(1)'),
			DOT_ICC_number=p.v.value('DOT_ICC_number[1]','varchar(15)'),
			cylinder_type_id=@cylinder_type_id,--p.v.value('cylinder_type_id[1]','int'),
			heaviest_gross_weight=p.v.value('heaviest_gross_weight[1]','int'),
			heaviest_gross_weight_unit=p.v.value('heaviest_gross_weight_unit[1]','char(1)'),
			external_condition=p.v.value('external_condition[1]','char(1)'),
			cylinder_pressure=p.v.value('cylinder_pressure[1]','char(1)'),
			pressure_relief_device=p.v.value('pressure_relief_device[1]','char(1)'),
			protective_cover_flag=p.v.value('protective_cover_flag[1]','char(1)'),
			workable_valve_flag=p.v.value('workable_valve_flag[1]','char(1)'),
			threads_impaired_flag=p.v.value('threads_impaired_flag[1]','char(1)'),
            valve_condition=p.v.value('valve_condition[1]','char(1)'),
            corrosion_color=p.v.value('corrosion_color[1]','varchar(20)'),
		    date_modified = GETDATE(),
		    modified_by = @web_userid
		 FROM
         @Data.nodes('Cylinder')p(v) WHERE form_id = @form_id and revision_id=@revision_id
END
GO
GRANT EXECUTE ON [dbo].[sp_cylinder_insert_update] TO COR_USER;
GO
/***************************************************************************************/

