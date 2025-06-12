
USE [PLT_AI] 
GO 

DROP PROCEDURE IF EXISTS [dbo].[sp_COR_FormWCR_template_locked_items] 
GO 

  
CREATE PROCEDURE [dbo].[sp_COR_FormWCR_template_locked_items] 

    @template_form_id INT 
AS

/* ******************************************************************
    Created By       : Pasupathi P
    Created On       : 24th Jun 2024
    Type             : Stored Procedure
    Ticket           : 89274
    Object Name      : [sp_COR_FormWCR_template_locked_items]

	 --exec [dbo].[sp_COR_FormWCR_template_locked_items] @template_form_id = 787256
    ***********************************************************************/


BEGIN
    SET NOCOUNT ON;

    SELECT
        CASE WHEN ISNULL(l.column_status, 'U') = 'L' THEN 1 ELSE 0 END AS column_status,
        f.field_name,
        f.field_label AS label, 
        f.column_order, 
        s.section_code, 
        s.section_name ,
		f.is_header
    FROM
        dbo.FormWCRFieldInfo f
    LEFT JOIN
        dbo.FormWCRTemplateLockedItem l ON f.form_wcr_field_info_uid = l.form_wcr_field_info_id AND l.template_form_id = @template_form_id
    LEFT JOIN
        dbo.FormWCRSection s ON f.section_code = s.section_code
	LEFT JOIN dbo.FormSectionStatus fss ON  fss.section = s.section_code AND fss.form_id = @template_form_id AND fss.isActive=1
    WHERE
      f.display_status = 1 AND  (l.template_form_id = @template_form_id OR l.template_form_id IS NULL) AND fss.section = f.section_code
    ORDER BY
        s.section_order,
        f.column_order;
END; 
GO 

GRANT EXEC ON [dbo].[sp_COR_FormWCR_template_locked_items] TO COR_USER
GO 

GRANT EXECUTE ON [dbo].[sp_COR_FormWCR_template_locked_items]  TO EQWEB 
GO 

GRANT EXECUTE ON [dbo].[sp_COR_FormWCR_template_locked_items]  TO EQAI 
GO 
