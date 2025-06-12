
CREATE PROCEDURE sp_messageAttachment_insert
	 @message_id		INT
	,@attachment_type	VARCHAR(10)
	,@source			VARCHAR(32)
	,@image_id			INT
	,@filename			VARCHAR(256)
	,@attachment_id		INT = 1
AS
/**************************************************************************
Insert new record to PLT_AI MessageAttachment table

09/10/2012 TMO	Created

Example Call:
sp_messageAttachment_insert TODO: ('params')
**************************************************************************/

IF ISNULL(LEN(@attachment_type), -1) <= 0
	GOTO ATTACHMENT_TYPE_ERROR

IF ISNULL(LEN(@source), -1) <= 0
	GOTO SOURCE_ERROR

IF ISNULL(@image_id, -1) <= 0
	GOTO IMAGE_ID_ERROR

IF ISNULL(LEN(@filename), -1) <= 0
	GOTO FILENAME_ERROR
	
INSERT dbo.MessageAttachment
        ( message_id ,
          attachment_id ,
          status ,
          attachment_type ,
          source ,
          image_id ,
          filename
        )
VALUES  ( @message_id , -- message_id - int
          @attachment_id, -- attachment_id - int
          'N' , -- status - char(1)
          @attachment_type, -- attachment_type - varchar(10)
          @source, -- source - varchar(32)
          @image_id, -- image_id - int
          @filename  -- filename - varchar(256)
        )

ATTACHMENT_TYPE_ERROR:
	RAISERROR ('Attachment_type is mandatory', 1, -1)
SOURCE_ERROR:
	RAISERROR ('Source is mandatory', 1, -1)
IMAGE_ID_ERROR:
	RAISERROR ('Image_id is mandatory', 1, -1)
FILENAME_ERROR:
	RAISERROR ('Filename is mandatory', 1, -1)

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_messageAttachment_insert] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_messageAttachment_insert] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_messageAttachment_insert] TO [EQAI]
    AS [dbo];

