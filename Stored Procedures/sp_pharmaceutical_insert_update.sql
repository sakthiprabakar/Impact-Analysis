USE [PLT_AI]
GO
/***********************************************************************************/
DROP PROCEDURE IF EXISTS [dbo].[sp_pharmaceutical_insert_update]

GO
CREATE PROCEDURE [dbo].[sp_pharmaceutical_insert_update]
       @Data XML,
	   @form_id int,
	   @revision_id int,
	   @web_userid varchar(100)
AS

/* ******************************************************************
Insert / update Pharmaceutical form  (Part of form wcr insert / update)
inputs 
	
	Data -- XML data having values for the FormPharmaceutical table objects
	Form ID
	Revision ID
	--EXEC sp_FormWCR_insert_update_pharmaceutical '<Pharmaceutical>
--<wcr_id>427534</wcr_id>
--<wcr_rev_id>1</wcr_rev_id>
--<locked>U</locked>
--<pharm_certification_flag>F</pharm_certification_flag>			
--<modified_by>TESTed</modified_by>
--<created_by>TESTd</created_by>
--<signing_date> </signing_date>
--<signing_name>test</signing_name>
--</Pharmaceutical>',427534 , 1
****************************************************************** */
 BEGIN
 BEGIN TRY
  IF(NOT EXISTS(SELECT 1 FROM FormPharmaceutical  WITH(NOLOCK) WHERE wcr_id = @form_id  and wcr_rev_id=  @revision_id))
	BEGIN
	    DECLARE @newForm_id INT 
		DECLARE @newrev_id INT  = 1  
		EXEC @newForm_id = sp_sequence_next 'form.form_id'
		INSERT INTO FormPharmaceutical(
			form_id,
			revision_id,
			wcr_id,
			wcr_rev_id,
			locked,
			pharm_certification_flag,
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
			-- locked = p.v.value('locked[1]','char(1)'),
			locked = 'U',
			pharm_certification_flag = p.v.value('pharm_certification_flag[1]','char(1)'),			
		    created_by = @web_userid,
		    date_created = GETDATE(),
		    date_modified = GETDATE(),
			modified_by = @web_userid
        FROM
            @Data.nodes('Pharmaceutical')p(v)
   END
  ELSE
   BEGIN
        UPDATE  FormPharmaceutical
        SET                 
			-- locked = p.v.value('locked[1]','char(1)'),
			locked = 'U',
			pharm_certification_flag = p.v.value('pharm_certification_flag[1]','char(1)'),
		    date_modified = GETDATE(),
		    modified_by = @web_userid
		 FROM 
         @Data.nodes('Pharmaceutical')p(v) WHERE wcr_id = @form_id and wcr_rev_id=@revision_id

END
 END TRY
			  BEGIN CATCH
				--IF @@TRANCOUNT > 0
				--ROLLBACK TRANSACTION;
				declare @mailTrack_userid nvarchar(60) = 'COR'
			     DECLARE @error_description VARCHAR(4000)
				 set @error_description=CONVERT(VARCHAR(20), @form_id)+' - '+CONVERT(VARCHAR(10),@revision_id)+ ' ErrorMessage: '+Error_Message()+'\n XML: '+CONVERT(VARCHAR(4000),@Data)
				INSERT INTO COR_DB.[dbo].[ErrorLogs] (ErrorDescription,[Object_Name],Web_user_id,CreatedDate)
		                               VALUES(@error_description,ERROR_PROCEDURE(),@mailTrack_userid,GETDATE())
			END CATCH
END

GO
GRANT EXECUTE ON [dbo].[sp_pharmaceutical_insert_update] TO COR_USER;
GO
/**************************************************************************************************************/
