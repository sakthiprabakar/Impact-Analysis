USE [PLT_AI]
GO

DROP PROCEDURE IF EXISTS [dbo].[sp_FormWCR_insert_update_section_B] 
GO 

CREATE PROCEDURE [dbo].[sp_FormWCR_insert_update_section_B]

      @Data XML,
	  @form_id int,
	  @revision_id int
AS


/* ******************************************************************
 stored procedure to save section B related data

inputs 
	
	@Data --> pass xml value
	@form_id 
	@revision_id


****************************************************************** */

    BEGIN
        UPDATe FormWCR
        SET         
            waste_common_name = p.v.value('waste_common_name[1]','varchar(50)'),
            gen_process = p.v.value('gen_process[1]','varchar(max)'),
            EPA_source_code = p.v.value('EPA_source_code[1]','varchar(10)'),
            EPA_form_code = p.v.value('EPA_form_code[1]','varchar(10)')
        FROM
        @Data.nodes('SectionB')p(v) WHERE form_id = @form_id AND revision_id = @revision_id
    END

GO

	   GRANT EXECUTE ON [dbo].[sp_FormWCR_insert_update_section_B] TO COR_USER;

GO
 
 --EXEC sp_FormWCR_insert_update_section_B '<SectionB>
 -- <waste_common_name>TEST</waste_common_name>
 -- <gen_process>GEN</gen_process>
 -- <EPA_source_code>SOUC CODE</EPA_source_code>
 -- <EPA_form_code>D</EPA_form_code>
 -- <IsEdited>B</IsEdited>
 -- </SectionB>'  ,427709,1 

 --SELECT waste_common_name,gen_process,EPA_source_code,EPA_form_code FROM FORMWCR WHERE form_id = 427709 AND revision_id = 1