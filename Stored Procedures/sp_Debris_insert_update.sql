USE [PLT_AI]
GO
/***************************************************************************************/
DROP PROCEDURE IF EXISTS [dbo].[sp_Debris_insert_update]
GO
CREATE PROCEDURE [dbo].[sp_Debris_insert_update]
       @Data XML,
	   @form_id int,
	   @revision_id int,
	   @web_userid varchar(100)
AS
/* ******************************************************************

Insert / update Debris data (Part of form wcr insert / update)

 Updated By   : Ranjini C
  Updated On   : 08-AUGUST-2024
  Ticket       : 93217
  Decription   : This procedure is used to assign web_userid to created_by and modified_by columns. 

inputs 
	
	Data -- XML data having values for the FormDebris table objects
	Form ID
	Revision ID

	--EXEC sp_FormWCR_insert_update_Debris '<Debris>

--<IsEdited>DS</IsEdited>

--<wcr_id>427569</wcr_id>

--<wcr_rev_id>1</wcr_rev_id>

--<date_created>0001-01-01T00:00:00</date_created>

--<date_modified>0001-01-01T00:00:00</date_modified>

--<debris_certification_flag>F</debris_certification_flag>

--<signing_name>TEST</signing_name>
--<signing_title>TT</signing_title>
--<signing_date>2018-12-19 11:59:00</signing_date>

--</Debris>', 427569,1


****************************************************************** */
  BEGIN
  IF(NOT EXISTS(SELECT 1 FROM FormDebris  WITH(NOLOCK) WHERE wcr_id = @form_id  and wcr_rev_id=  @revision_id))
	BEGIN
	    DECLARE @newForm_id INT 
		DECLARE @newrev_id INT  = 1  
		EXEC @newForm_id = sp_sequence_next 'form.form_id'
		INSERT INTO FormDebris(
			form_id,
			revision_id,
			wcr_id,
			wcr_rev_id,
			locked,
			debris_certification_flag,
			created_by,
			date_created,
			modified_by,
			date_modified)
        SELECT			 
		    form_id=@newForm_id,
			revision_id=@newrev_id,
		    wcr_id= @form_id,
			wcr_rev_id=@revision_id,
			locked= 'U',
			debris_certification_flag=p.v.value('debris_certification_flag[1]','char(1)'),
		    created_by = @web_userid,
			date_created = GETDATE(),
			modified_by = @web_userid,
		    date_modified = GETDATE()
        FROM
            @Data.nodes('Debris')p(v)
   END
  ELSE
   BEGIN
        UPDATE  FormDebris
        SET                 
			 locked= 'U',
			debris_certification_flag=p.v.value('debris_certification_flag[1]','char(1)'),
			modified_by = @web_userid,
		    date_modified = GETDATE()
		 FROM
         @Data.nodes('Debris')p(v) WHERE wcr_id = @form_id and wcr_rev_id=@revision_id
END
END
GO
GRANT EXECUTE ON [dbo].[sp_Debris_insert_update] TO COR_USER;
GO
/*********************************************************************************************/
