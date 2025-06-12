USE [PLT_AI]
GO
/****** Object:  StoredProcedure [dbo].[sp_COR_BulkRenewalDocument_Insert]    Script Date: 11/27/2021 11:27:53 AM ******/

CREATE Procedure [dbo].[sp_COR_BulkRenewalDocument_Insert]

@web_userid VARCHAR (60)  ,
@Envelope_id NVARCHAR(200)           ,
@imageByte			IMAGE	

AS

BEGIN

BEGIN TRY
 
  declare @current_db_name varchar(30), 
		  @file_type varchar(10) = 'pdf'
  select @current_db_name = current_database from plt_image.dbo.ScanCurrentDB  

  declare @document_name nvarchar(200) = 'Signed Document_' + (SELECT FORMAT (getdate(), 'MM_dd_yyyy_hh_mm_ss'))

 declare @form_id int , @revision_id int

 declare bulkrenewaldoc_cursor CURSOR 
 for  select form_id, revision_id from plt_ai.dbo.Formsignaturequeue where e_signature_envelope_id=@Envelope_id;
 
 open bulkrenewaldoc_cursor

 fetch next from bulkrenewaldoc_cursor into @form_id,@revision_id
while @@fetch_status = 0
begin

	declare @image_id int
	exec @image_id = [Plt_AI].dbo.SP_SEQUENCE_SILENT_NEXT 'scanImage.image_id'

	declare @copy_source varchar(20)
	declare @profile_id int

	select @copy_source = copy_source, @profile_id = profile_id from plt_ai.dbo.formwcr where form_id = @form_id and revision_id =@revision_id
 insert plt_image.dbo.scan
 (			
			[image_id]           ,
			[document_source]    ,
			[type_id]            ,
			[status]             ,
			[document_name]      ,
			[date_added]         ,
			[date_modified]      ,
			[added_by]           ,
			[modified_by]        ,			
			[form_id]            ,
			[revision_id]        ,			
			[form_type]          ,
			[file_type]          ,
			[profile_id]         ,			
			[view_on_web]        ,
			[app_source]         ,
			[upload_date]
		)
		values
		(			
			@image_id,			
			'CORDOC',	
			(select type_id from plt_image.dbo.scandocumenttype where type_code ='cordoc'), -- type_id	
			'A',
			@document_name,
			getdate(),
			getdate(),
			@web_userid,
			@web_userid,			
			@form_id            ,
			@revision_id       ,			
			'WCR'          ,
			@file_type          ,			
			case when @copy_source='renewal'
			then 
				@profile_id 			
			else null end,	
			'T',		
			'COR'         ,
			getdate()        			
		)

		exec plt_image.dbo.sp_COR_Scan_Insert_Image @image_id, @current_db_name ,@document_name,@file_type,@imageByte   
  
		UPDATE plt_image.dbo.Scan SET status = 'A' WHERE image_id =  @image_id   

		fetch next from bulkrenewaldoc_cursor into @form_id,@revision_id

	end
	close bulkrenewaldoc_cursor;
	deallocate bulkrenewaldoc_cursor;
END TRY
 BEGIN CATCH
		DECLARE @Message VARCHAR(MAX)	
		SET @Message = Error_Message();		
		DECLARE @error_description VARCHAR(MAX)
				set @error_description=' ErrorMessage: '+Error_Message()
		INSERT INTO COR_DB.[dbo].[ErrorLogs] (ErrorDescription,[Object_Name],Web_user_id,CreatedDate)
							VALUES(@error_description,ERROR_PROCEDURE(),@web_userid,GETDATE())
  END CATCH
end

GO

	GRANT EXEC ON [sp_COR_BulkRenewalDocument_Insert] TO COR_USER;

GO