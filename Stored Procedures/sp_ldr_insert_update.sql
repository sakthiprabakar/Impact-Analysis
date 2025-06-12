USE [PLT_AI]
GO
/*****************************************************************************************/
DROP PROCEDURE IF EXISTS [dbo].[sp_ldr_insert_update]
GO
CREATE PROCEDURE [dbo].[sp_ldr_insert_update]
         @Data XML ,
	     @form_id int,
		 @revision_id int,
		 @web_userid varchar(100)
AS 
/* ******************************************************************

	Updated By		: Dinesh Kumar
	Updated On		: 1st May 2021
	Type			: Stored Procedure
	Object Name		: [sp_ldr_insert_update]
	
	Updated By   : Ranjini C
    Updated On   : 08-AUGUST-2024
    Ticket       : 93217
    Decription   : This procedure is used to assign web_userid to created_by and modified_by columns. 
	Procedure to insert update LDR supplementry forms
inputs 	
	@Data
	@form_id
	@revision_id


Samples:
 EXEC [sp_ldr_insert_update] @Data,@formId,@revisionId
 EXEC [sp_ldr_insert_update] '<LDR>		
--<signing_title>tested</signing_title>
--<signing_date></signing_date>
--<generator_name>PITT OHIO EXPRESS</generator_name>
--<generator_id>1</generator_id>
--<generator_epa_id>1</generator_epa_id>
--<manifest_doc_no>T</manifest_doc_no>
--<rowguid>B9AF54D9-2524-4508-9438-A22A823D9661</rowguid>
--<created_by>TEST</created_by>
--<modified_by>TEST</modified_by>
--<approval_code>GDG</approval_code>
--<status>1</status>
--<locked>F</locked>
--<manifest_line_item>1</manifest_line_item>
--<ldr_notification_frequency>T</ldr_notification_frequency>
--<Wastecode>
-- <Wastecode>
-- <waste_code_uid>1</waste_code_uid>
-- <waste_code>1</waste_code>
-- <specifier>T</specifier>
--  </Wastecode>
--</Wastecode>
--<LDRSubcategory>
-- <LDRSubcategory>
--  <manifest_line_item>1</manifest_line_item>
--  <ldr_subcategory_id>1</ldr_subcategory_id>
--</LDRSubcategory>
--</LDRSubcategory>
--<Constituent>
--   <Constituent>
--    <const_id>1</const_id>
--   </Constituent>
--</Constituent>
--</LDR>', 427534,1

***********************************************************************/
 IF(EXISTS(SELECT form_id FROM FormWCR  WITH(NOLOCK)  WHERE form_id = @form_id and revision_id =  @revision_id))
   BEGIN
		IF(NOT EXISTS(SELECT 1 FROM FormLDR  WHERE wcr_id = @form_id and wcr_rev_id =  @revision_id))
		BEGIN
				DECLARE @newForm_id INT 
				DECLARE @newrev_id INT  = 1  
				EXEC @newForm_id = sp_sequence_next 'form.form_id'	
			  INSERT INTO FormLDR(form_id,revision_id,wcr_id,wcr_rev_id,generator_id,generator_name,generator_epa_id,manifest_doc_no,ldr_notification_frequency,waste_managed_id,rowguid,status,locked,date_created,date_modified,created_by,modified_by)
			  SELECT TOP 1		 
					form_id=@newForm_id,
					revision_id=@newrev_id,
					wcr_id = @form_id,
					wcr_rev_id = @revision_id,
					generator_id = p.v.value('generator_id[1]','int'),
					generator_name = p.v.value('generator_name[1]','varchar(40)'),
					generator_epa_id = p.v.value('generator_epa_id[1]','varchar(12)'),
					manifest_doc_no = p.v.value('manifest_doc_no[1]','varchar(20)'),
					ldr_notification_frequency = p.v.value('ldr_notification_frequency[1]','char(1)'),
					waste_managed_id = p.v.value('waste_managed_id[1]','INT'),
					rowguid =  NEWID(),-- p.v.value('rowguid[1]','uniqueidentifier'),
					status = '1',
					--  locked = p.v.value('locked[1]','char(1)'),
					locked = 'U',
					date_created = GETDATE(),
					date_modified = GETDATE(),
					created_by =@web_userid,
					modified_by =@web_userid				  
			  FROM
				  @Data.nodes('LDR')p(v)
		END
        ELSE
           BEGIN
              UPDATE  FormLDR
              SET                 
			   manifest_doc_no = p.v.value('manifest_doc_no[1]','varchar(20)'),
			   waste_managed_id = p.v.value('waste_managed_id[1]','INT'),
			   ldr_notification_frequency = p.v.value('ldr_notification_frequency[1]','char(1)'),			   
			   date_modified = GETDATE(),
			   status = '1',
			   modified_by = @web_userid
		      FROM
               @Data.nodes('LDR')p(v) WHERE wcr_id = @form_id and wcr_rev_id =  @revision_id
           END		
        IF(NOT EXISTS(SELECT * FROM FormLDRDetail  WHERE form_id = @form_id and revision_id =  @revision_id))
		    BEGIN
			  INSERT INTO FormLDRDetail(form_id,revision_id,approval_code,manifest_line_item,constituents_requiring_treatment_flag) 
			  SELECT top 1
			       form_id = @form_id ,
				   revision_id = @revision_id,
				   approval_code=p.v.value('approval_code[1]','VARCHAR(40)'),
				   manifest_line_item=p.v.value('manifest_line_item[1]','int'),
				   constituents_requiring_treatment_flag=p.v.value('constituents_requiring_treatment_flag[1]','char(1)')
			  FROM
				  @Data.nodes('LDR')p(v)
		    END
         ELSE 
		    BEGIN
			 UPDATE  FormLDRDetail 
			 SET 
			   approval_code=p.v.value('approval_code[1]','VARCHAR(40)'),
			   manifest_line_item=p.v.value('manifest_line_item[1]','int'),
			   constituents_requiring_treatment_flag=p.v.value('constituents_requiring_treatment_flag[1]','char(1)')
             FROM
               @Data.nodes('LDR')p(v) WHERE form_id = @form_id and revision_id =  @revision_id
			END
   END
GO
	GRANT EXECUTE ON [dbo].[sp_ldr_insert_update] TO COR_USER;
GO
/***********************************************************************************/



