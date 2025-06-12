
CREATE PROCEDURE sp_messageAddress_insert
	 @message_id	INT
	,@address_type	VARCHAR(10)
	,@email			VARCHAR(100)
	,@name			VARCHAR(50) = ''
	,@company		VARCHAR(50) = 'EQ'
	,@department	VARCHAR(50) = NULL
	,@fax			VARCHAR(20) = NULL
	,@phone			VARCHAR(20) = NULL
AS
/**************************************************************************
Insert new record to PLT_AI MessageAddress table

09/10/2012 TMO	Created
9/27/2018 RWB GEM:54783 Add grant statement for AX_SERVICE

Example Call:
sp_messageAddress_insert TODO: ('params')
**************************************************************************/
IF (LEN(@name) < 1)
	SET @name = @email

INSERT dbo.MessageAddress
        ( message_id ,
          address_type ,
          name ,
          company ,
          department ,
          email ,
          fax ,
          phone
        )
VALUES  ( @message_id, -- message_id - int
          @address_type, -- address_type - varchar(10)
          @name , -- name - varchar(50)
          @company, -- company - varchar(50)
          @department, -- department - varchar(50)
          @email, -- email - varchar(100)
          @fax, -- fax - varchar(20)
          @phone  -- phone - varchar(20)
        )
        
DECLARE @servername NVARCHAR(20)
SET @servername = CONVERT(NVARCHAR(20), SERVERPROPERTY('servername'))
IF @servername LIKE '%dev'
	IF NOT EXISTS (SELECT 1 FROM dbo.MessageAddress WHERE message_id = @message_id AND email = 'webdev@eqonline.com')
		INSERT dbo.MessageAddress
		        ( message_id ,
		          address_type ,
		          name ,
		          company ,
		          department ,
		          email ,
		          fax ,
		          phone
		        )
		VALUES  ( @message_id , -- message_id - int
		          'CC' , -- address_type - varchar(10)
		          'webdev@eqonline.com' , -- name - varchar(50)
		          'EQ' , -- company - varchar(50)
		          NULL , -- department - varchar(50)
		          'webdev@eqonline.com' , -- email - varchar(100)
		          NULL , -- fax - varchar(20)
		          NULL  -- phone - varchar(20)
		        )


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_messageAddress_insert] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_messageAddress_insert] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_messageAddress_insert] TO [AX_SERVICE]
    AS [dbo];


GO

GRANT EXECUTE
    ON OBJECT::[dbo].[sp_messageAddress_insert] TO [Svc_OnBase_SQL]
    AS [dbo];


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_messageAddress_insert] TO [EQAI]
    AS [dbo];

