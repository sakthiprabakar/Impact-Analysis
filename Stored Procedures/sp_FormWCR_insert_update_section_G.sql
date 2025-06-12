USE [PLT_AI]
GO
/**************************************************************************************************************/
DROP PROCEDURE IF EXISTS [dbo].[sp_FormWCR_insert_update_section_G]
GO
CREATE PROCEDURE [dbo].[sp_FormWCR_insert_update_section_G]
       @Data XML,			
	   @form_id int,  
	   @revision_id int
AS
/* ******************************************************************
	Updated By		: Dineshkumar
	Updated On		: 05-03-2019
	Type			: Stored Procedure
	Object Name		: [sp_FormWCR_insert_update_section_G]
	Procedure to Update Section G field values in FormWCR Table
inputs 
	@Data -- XML Input data
	@formid
	@revision_ID
Samples:
 EXEC [sp_FormWCR_insert_update_section_G] @Data, @form_id,@revision_ID 
****************************************************************** */
BEGIN
	begin try	 
		UPDATE  FormWCR 			 
		SET        
              ccvocgr500 = p.v.value('ccvocgr500[1]','char(1)'),
			  waste_treated_after_generation = p.v.value('waste_treated_after_generation[1]','char(1)'),
			  waste_treated_after_generation_desc = p.v.value('waste_treated_after_generation_desc[1]','VARCHAR(255)'),
			  waste_water_flag = LTRIM(RTRIM(p.v.value('waste_water_flag[1]','CHAR(1)'))),
			  meets_alt_soil_treatment_stds = p.v.value('meets_alt_soil_treatment_stds[1]','CHAR(1)'),
			  more_than_50_pct_debris = p.v.value('more_than_50_pct_debris[1]','CHAR(1)'),
			  debris_separated = p.v.value('debris_separated[1]','CHAR(1)'),
			  debris_not_mixed_or_diluted = p.v.value('debris_not_mixed_or_diluted[1]','CHAR(1)'),
			  exceed_ldr_standards = p.v.value('waste_meets_ldr_standards[1]','CHAR(1)'),
			  waste_meets_ldr_standards = p.v.value('waste_meets_ldr_standards[1]','CHAR(1)'),
			  ldr_subcategory = p.v.value('ldr_subcategory[1]','VARCHAR(100)'),
			  subject_to_mact_neshap = p.v.value('subject_to_mact_neshap[1]','CHAR(1)'),
			  neshap_standards_part = p.v.value('neshap_standards_part[1][not(@xsi:nil = "true")]','INT'),
			  neshap_subpart = p.v.value('neshap_subpart[1]','VARCHAR(255)'),
			  origin_refinery = p.v.value('origin_refinery[1]','CHAR(1)')             
          FROM
			@Data.nodes('SectionG')p(v) WHERE form_id = @form_id  and revision_id=  @revision_id
		DECLARE @SubCategoryCount INT  = 0
		SELECT @SubCategoryCount = Count(*) FROM FormLDRSubcategory WHERE form_id = @form_id AND revision_id = @revision_id
		IF(@SubCategoryCount > 0)
		BEGIN
			DELETE FormLDRSubcategory WHERE form_id = @form_id AND revision_id = @revision_id 
		END
		   INSERT INTO FormLDRSubcategory(form_id,revision_id,page_number,manifest_line_item,ldr_subcategory_id) 
			  SELECT
			       form_id = @form_id ,
				   revision_id = @revision_id,
				   page_number=1,
				   manifest_line_item=ROW_NUMBER() OVER(ORDER BY p.v.value('ldr_subcategory_id[1]', 'int') ASC),
				   ldr_subcategory_id=p.v.value('Ldr_subcategory_id[1]','int')
			  FROM
				  @Data.nodes('SectionG/ldr_subcategory/LDRSubcategory')p(v)
	end try
	begin catch
		declare @procedure nvarchar(150), 
				@mailTrack_userid nvarchar(60) = 'COR'
				set @procedure = ERROR_PROCEDURE()
				declare @error nvarchar(4000) = ERROR_MESSAGE()
				declare @error_description nvarchar(4000) = 'Form ID: ' + convert(nvarchar(15), @form_id) + '-' +  convert(nvarchar(15), @revision_id) 
															+ CHAR(13) + 
															+ CHAR(13) + 
														   'Error Message: ' + isnull(@error, '')
														   + CHAR(13) + 
														   + CHAR(13) + 
														   'Data:  ' + convert(nvarchar(4000),@Data)														   
				EXEC [COR_DB].[DBO].sp_COR_Exception_MailTrack
						@web_userid = @mailTrack_userid, 
						@object = @procedure,
						@body = @error_description
	end catch
END	  
GO
	GRANT EXECUTE ON [dbo].[sp_FormWCR_insert_update_section_G] TO COR_USER;
GO
/*******************************************************************************************/
