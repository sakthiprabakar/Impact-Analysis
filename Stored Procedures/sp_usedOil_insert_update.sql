
CREATE PROCEDURE [dbo].[sp_usedOil_insert_update]
	-- Add the parameters for the stored procedure here
	 @Data XML,
	 @form_id int,
	   @revision_id int
AS

/* ******************************************************************

Insert / update Used Oil form  (Part of form wcr insert / update)


inputs 
	
	Data -- XML data having values for the FormWCR table
	Form ID
	Revision ID


****************************************************************** */

BEGIN
	 UPDATE  FormWCR
        SET   
			wwa_halogen_gt_1000 = p.v.value('wwa_halogen_gt_1000[1]','char(1)'),
			wwa_halogen_source = p.v.value('wwa_halogen_source[1]','varchar(10)'),
			wwa_halogen_source_desc1 = p.v.value('wwa_halogen_source_desc1[1]','varchar(100)'),
			wwa_other_desc_1 =p.v.value('wwa_other_desc_1[1]','varchar(100)')
        FROM
        @Data.nodes('Usedoil')p(v) WHERE form_id = @form_id and revision_id =  @revision_id
END

GO

GRANT EXECUTE ON [dbo].[sp_usedOil_insert_update] TO COR_USER;
GO

--EXEC sp_FormWCR_insert_update_usedOil '<UsedOil>		
--<wwa_other_desc_1>wwa_other_desc_1</wwa_other_desc_1>
--<wwa_halogen_source_desc1>wwa_halogen_source_desc1</wwa_halogen_source_desc1>
--<wwa_halogen_source>wwa_halogen_source</wwa_halogen_source>
--<wwa_halogen_gt_1000>F</wwa_halogen_gt_1000>
--</UsedOil>',428898,1

--select wwa_other_desc_1,
--			wwa_halogen_source_desc1,
--			wwa_halogen_source,
--			wwa_halogen_gt_1000 from FormWCR WHERE form_id = 428898 and revision_id =  1

