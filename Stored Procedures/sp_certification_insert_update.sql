USE [PLT_AI]
GO
/*************************************************************************************************/
DROP PROCEDURE IF EXISTS [dbo].[sp_certification_insert_update]
GO
CREATE PROCEDURE [dbo].[sp_certification_insert_update]
       @Data XML,
	   @form_id int,
	   @revision_id int,
	   @web_userid varchar(100)
AS
/* ******************************************************************

	Updated By		: SenthilKumar
	Updated On		: 26th Feb 2019
	Type			: Stored Procedure
	Object Name		: [sp_certification_insert_update]
	
	Updated By   : Ranjini C
    Updated On   : 08-AUGUST-2024
    Ticket       : 93217
    Decription   : This procedure is used to assign web_userid to created_by and modified_by columns. 
	Procedure to insert update Cerification supplementry forms
inputs 	
	@Data
	@form_id
	@revision_id
Samples:
 EXEC [sp_certification_insert_update] @Data,@formId,@revisionId
 EXEC [sp_certification_insert_update]  '<Certification>
<wcr_id>123</wcr_id>
<wcr_rev_id>1</wcr_rev_id>
<locked>U</locked>
<vsqg_cesqg_accept_flag>F</vsqg_cesqg_accept_flag>
<created_by>test</created_by>
<modified_by>local test</modified_by>
<generator_name>PITT</generator_name>
<generator_address1>STREET generator_address1</generator_address1>
<generator_address2>WEST MORRIS STREET generator_address2</generator_address2>
<generator_address3>MORRIS generator_address3</generator_address3>
<generator_address4>generator_address4</generator_address4>
<generator_city>INDIANA</generator_city>
<generator_state>IN</generator_state>
<gen_mail_zip>461</gen_mail_zip>
<signing_date>2018-12-12 00:00:00</signing_date>
<signing_name>local signing_name</signing_name>
<signing_title>local signing_title</signing_title>
</Certification>',427568,1

***********************************************************************/  
BEGIN
BEGIN TRY	
  IF(NOT EXISTS(SELECT 1 FROM FormVSQGCESQG  WITH(NOLOCK) WHERE wcr_id = @form_id  and wcr_rev_id=  @revision_id))
	BEGIN
	    DECLARE @newForm_id INT 
		DECLARE @newrev_id INT  = 1  
		EXEC @newForm_id = sp_sequence_next 'form.form_id'
		INSERT INTO FormVSQGCESQG(
			form_id,
			revision_id,
			wcr_id,
			wcr_rev_id,
			locked,
			vsqg_cesqg_accept_flag,
			created_by,
			date_created,
			date_modified,
			modified_by
			)
        SELECT
			 
		    form_id=@newForm_id,
		    revision_id=@newrev_id,
		    wcr_id= @form_id,
			wcr_rev_id=@revision_id,
			--locked = p.v.value('locked[1]','char(1)'),
			locked = 'U',
			vsqg_cesqg_accept_flag = p.v.value('vsqg_cesqg_accept_flag[1]','char(1)'),			
		    created_by = @web_userid,
		    date_created = GETDATE(),
		    date_modified = GETDATE(),
			modified_by = @web_userid
        FROM
            @Data.nodes('Certification')p(v)
   END
	ELSE
	BEGIN
        UPDATE  FormVSQGCESQG
        SET                 
			--locked = p.v.value('locked[1]','char(1)'),
			locked = 'U',
			vsqg_cesqg_accept_flag = p.v.value('vsqg_cesqg_accept_flag[1]','char(1)'),
		    date_modified = GETDATE(),
		    modified_by = @web_userid
		 FROM
         @Data.nodes('Certification')p(v) WHERE wcr_id = @form_id and wcr_rev_id=@revision_id
	END
END TRY
BEGIN CATCH 			
		DECLARE @error_description VARCHAR(4000)
		declare @mailTrack_userid nvarchar(60) = 'COR'
		set @error_description=' ErrorMessage: '+Error_Message()
		INSERT INTO COR_DB.[dbo].[ErrorLogs] (ErrorDescription,[Object_Name],Web_user_id,CreatedDate)
							VALUES(@error_description,ERROR_PROCEDURE(),@mailTrack_userid,GETDATE())
END CATCH
END
GO
	GRANT EXEC ON [dbo].[sp_certification_insert_update] TO COR_USER;
GO
/****************************************************************************************************************/