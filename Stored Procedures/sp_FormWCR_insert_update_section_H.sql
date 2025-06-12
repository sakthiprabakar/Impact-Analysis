USE [PLT_AI]
GO
/*******************************************************************************************/
DROP PROC IF EXISTS sp_FormWCR_insert_update_section_H 
GO
CREATE PROCEDURE [dbo].[sp_FormWCR_insert_update_section_H]
       @Data XML,			
	   @form_id int,
	   @revision_id int,
	   @web_userid varchar(100)

AS
/************************************************************************
Updated By   : Ranjini C
Updated On   : 08-AUGUST-2024
Ticket       : 93217
Decription   : This procedure is used to assign web_userid to created_by and modified_by columns. 
**********************************************************************************/
BEGIN	
	begin try
		IF(EXISTS(SELECT * FROM FormWCR WHERE form_id = @form_id  and revision_id=  @revision_id))
BEGIN
UPDATE  FormWCR
        SET
              specific_technology_requested = p.v.value('specific_technology_requested[1]','char(1)'),
			  requested_technology = p.v.value('requested_technology[1]','VARCHAR(255)'),
			  thermal_process_flag =  p.v.value('thermal_process_flag[1]','CHAR(1)'),
			  other_restrictions_requested = p.v.value('other_restrictions_requested[1]','VARCHAR(255)'),			  
			  signing_name = p.v.value('signing_name[1]','VARCHAR(40)'),
			  signing_title = p.v.value('signing_title[1]','VARCHAR(40)'),
			  signing_company = p.v.value('signing_company[1]','VARCHAR(40)'),
			  signed_on_behalf_of = p.v.value('signed_on_behalf_of[1]','CHAR(1)'),
			  signing_date = null
        FROM
        @Data.nodes('SectionH')p(v) WHERE form_id = @form_id  and revision_id=  @revision_id		  
		IF(EXISTS(SELECT form_id FROM FormXUSEFacility WHERE form_id = @form_id  and revision_id=  @revision_id))
		BEGIN
		DELETE FROM FormXUSEFacility WHERE form_id = @form_id  and revision_id=  @revision_id
END
Declare @specific_technology_requested nvarchar(10);
Select @specific_technology_requested=p.v.value('specific_technology_requested[1]','char(1)')  FROM 
							@Data.nodes('SectionH')p(v) 
IF @specific_technology_requested = 'T'
BEGIN
	INSERT INTO FormXUSEFacility (  form_id ,
				   revision_id ,
				   company_id ,
				   profit_ctr_id  ,
				   date_created ,
				   date_modified ,
				   created_by,
				   modified_by )
				  SELECT			   
				   form_id = @form_id,
				   revision_id = @revision_id,
				   company_id = p.v.value('company_id[1]','int'),
				   profit_ctr_id = p.v.value('profit_ctr_id[1]','int') ,
				   date_created =Getdate(),
				   date_modified = Getdate(),
				   created_by = @web_userid,
				   modified_by = @web_userid  
				  FROM
				  @Data.nodes('SectionH/USEFacility/USEFacility')p(v)
END	
		IF( NOT EXISTS(SELECT form_id FROM FormSignature WHERE form_id = @form_id  and revision_id=  @revision_id))
		BEGIN
		INSERT INTO FormSignature ( form_id,
			   revision_id ,
			   form_signature_type_id ,
			   form_version_id,
			   sign_company ,
			   sign_name ,
			   sign_title ,
			   sign_email ,
			   sign_phone ,
			   sign_fax ,
			   sign_address ,
			   sign_city ,
			   sign_state,
			   sign_zip_code,
			   date_added ,
			   sign_comment_internal ,
			   rowguid ,
			   logon ,
			   contact_id,
			   e_signature_type_id ,
			  -- e_signature_id ,
			   e_signature_url )
              SELECT
			   form_id = @form_id,
			   revision_id = p.v.value('revision_id[1]','int'),
			   form_signature_type_id = p.v.value('form_signature_type_id[1]','int'),
			   form_version_id = p.v.value('form_version_id[1]','int'),
			   sign_company = p.v.value('sign_company[1]','varchar(40)'),
			   sign_name = p.v.value('sign_name[1]','varchar(40)'),
			   sign_title = p.v.value('sign_title[1]','varchar(20)'),
			   sign_email = p.v.value('sign_email[1]','varchar(60)'),
			   sign_phone = p.v.value('sign_phone[1]','varchar(20)'),
			   sign_fax = p.v.value('sign_fax[1]','varchar(20)'),
			   sign_address = p.v.value('sign_address[1]','varchar(255)'),
			   sign_city = p.v.value('sign_city[1]','varchar(40)'),
			   sign_state = p.v.value('sign_state[1]','varchar(2)'),
			   sign_zip_code = p.v.value('sign_zip_code[1]','varchar(15)'),
			   date_added = getdate(),
			   sign_comment_internal = p.v.value('sign_comment_internal[1]','varchar(16)'),
			   rowguid = NEWID(),
			   logon = p.v.value('logon[1]','varchar(60)'),
			   contact_id = p.v.value('contact_id[1]','int'),
			   e_signature_type_id = p.v.value('e_signature_type_id[1]','int'),
			--   e_signature_id = p.v.value('e_signature_id[1]','int'),
			   e_signature_url = p.v.value('e_signature_url[1]','varchar(255)') 
              FROM
              @Data.nodes('SectionH/Signature/Signature')p(v)
END
ELSE
BEGIN
          UPDATE  FormSignature
        SET  
              form_version_id = p.v.value('form_version_id[1]','int'),
			   sign_company = p.v.value('sign_company[1]','varchar(40)'),
			   sign_name = p.v.value('sign_name[1]','varchar(40)'),
			   sign_title = p.v.value('sign_title[1]','varchar(20)'),
			   sign_email = p.v.value('sign_email[1]','varchar(60)'),
			   sign_phone = p.v.value('sign_phone[1]','varchar(20)'),
			   sign_fax = p.v.value('sign_fax[1]','varchar(20)'),
			   sign_address = p.v.value('sign_address[1]','varchar(255)'),
			   sign_city = p.v.value('sign_city[1]','varchar(40)'),
			   sign_state = p.v.value('sign_state[1]','varchar(2)'),
			   sign_zip_code = p.v.value('sign_zip_code[1]','varchar(15)'),
			   date_added = p.v.value('date_added[1]','datetime'),
			   sign_comment_internal = p.v.value('sign_comment_internal[1]','varchar(16)'),
			 --  rowguid = p.v.value('rowguid[1]','uniqueidentifier'),
			   logon = p.v.value('logon[1]','varchar(60)'),
			   contact_id = p.v.value('contact_id[1]','int'),
			   e_signature_type_id = p.v.value('e_signature_type_id[1]','int'),
			  -- e_signature_id = p.v.value('e_signature_id[1]','int'),
			   e_signature_url = p.v.value('e_signature_url[1]','varchar(255)')
		  FROM
        @Data.nodes('SectionH/Signature/Signature')p(v) WHERE form_id = @form_id and revision_id=  @revision_id
       END
	END
	end try
	begin catch
		declare @procedure nvarchar(150)
		declare @mailTrack_userid nvarchar(60) = 'COR'
				set @procedure = ERROR_PROCEDURE()
				declare @error nvarchar(4000) = ERROR_MESSAGE()
				declare @error_description nvarchar(4000) = 'Form ID: ' + convert(nvarchar(15), @form_id) + '-' +  convert(nvarchar(15), @revision_id) 
															+ CHAR(13) + 
															+ CHAR(13) + 
														   'Error Message: ' + isnull(@error, '')
														   + CHAR(13) + 
														   + CHAR(13) + 
														   'Data:  ' + convert(nvarchar(4000), @Data)
				EXEC [COR_DB].[DBO].sp_COR_Exception_MailTrack
						@web_userid = @mailTrack_userid,
						@object = @procedure,
						@body = @error_description
	end catch

END
GO
	GRANT EXECUTE ON [dbo].[sp_FormWCR_insert_update_section_H] TO COR_USER;
GO
/*****************************************************************************************/

