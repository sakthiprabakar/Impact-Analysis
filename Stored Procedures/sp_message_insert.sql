-- drop proc sp_message_insert
go

CREATE PROCEDURE sp_message_insert
	 @subject			VARCHAR(255)
	,@message			VARCHAR(MAX)
	,@html				VARCHAR(MAX)
	,@created_by		VARCHAR(10)
	,@message_source	VARCHAR(30) = 'USEcology.com'
	,@date_to_send		DATETIME	= NULL
	,@message_type_id	INT			= NULL
	,@message_id		INT			= NULL
	

AS
/**************************************************************************
Insert new record to PLT_AI Message table

09/10/2012 TMO	Created
07/22/2015 JPB	Can't believe we never accepted an optional inbound message_id before.  Added.
8/29/2018 GSO Added grant statements used by OnBase application to send messages
9/27/2018 RWB GEM:54783 Add grant statement for AX_SERVICE
05/05/2020 JPB  DO:15268 Added MessageConfig handling.

Example Call:
sp_message_insert 'subject', 'message', '<body>message</body>', 'travis_o'

sp_message_insert
	 @subject			= 'Test MessageConfig Entry'
	,@message			= 'This is a test message'
	,@html				= ''
	,@created_by		= 'Jonathan'
	,@message_source	= 'COR-Email-Sample-Config'
	,@date_to_send		= NULL
	,@message_type_id	= NULL
	,@message_id		= NULL

-- (dropped MessageConfig table)
-- called sp above
SELECT  * FROM     Message where message_id = 3768669
	-- Works when there's no MessageConfig table

-- (created empty MessageConfig table)
-- called sp above
SELECT  * FROM     Message where message_id = 3768670
	-- Works when MessageConfig table contains no relevant rows

-- (insert sample row into MessageConfig table)
-- called sp above
SELECT  * FROM     Message where message_id = 3768672
	-- delivery delay config works!

-- (insert sample footer row into MessageConfig table)
-- called sp above
SELECT  * FROM     Message where message_id = 3768673
	-- delivery delay config works!
	-- and
	-- footer config works!

-- (expired the footer row in MessageConfig table)
-- called sp above
SELECT  * FROM     Message where message_id = 3768674
	-- delivery delay config works!
	-- and
	-- expiration works!



SELECT  * FROM    MessageConfig 

**************************************************************************/
SET NOCOUNT ON
DECLARE
	@int_message_id		INT,
	@now			DATETIME
	
if @message_id is null
	EXEC @int_message_id = sp_sequence_next 'Message.message_id', 1
else
	set @int_message_id = @message_id
	

IF ISNULL(@int_message_id, -1) <= 0
	GOTO ErrorLabel
	
SET @now = GETDATE()

/* Code added 5/5/2020 - JPB for allowing MessageConfig use */
-- If there's a MessageConfig table...
IF EXISTS (select 1 from sysobjects where name = 'MessageConfig') BEGIN

    -- Create a temporary table to store the relevant Config info from MessageConfig
    declare @Config table (config_key varchar(255), config_value varchar(max), _done int)

    -- Populate the @Config temp table from MessageConfig for this message_source value
    -- Only bring in config info with both a key and value (non null)
    insert @config (config_key, config_value, _done) 
    select config_key, config_value, 0 
    from MessageConfig
    where message_source = @message_source
    and getdate() between 
        isnull(effective_date_start, getdate()-1) 
        and 
        isnull(effective_date_end, getdate()+1)
    and config_key is not null
    and config_value is not null

    -- Create instance variables for handling this @Config record
    declare @loop_config_key varchar(255), @loop_config_value varchar(max)

    -- Loop over each @Config row to handle it
    while exists (select 1 from @config where _done = 0) begin

        -- Populate the instance variables for this loop occurence from @Config
        select top 1 
            @loop_config_key = config_key
            , @loop_config_value = config_value
        from @Config 
        where _done = 0

        -- Here's where we handle the possible configuration key effects
        -- Each MessageConfig config_key value must have a handler here.

        -- 'delivery delay': introduce a value to the date_to_send value, if null.
        if @loop_config_key = 'delivery delay' begin
            if @date_to_send is null -- we only apply the config table logic if the user did not already provide a specific date value here
                set @date_to_send = dateadd(minute, convert(int, @loop_config_value), getdate())
        end

        -- 'footer': add a footer to the message text (not html).
        if @loop_config_key = 'footer' begin
                set @message = @message + isnull(@loop_config_value, '')
        end


        -- more config_key handlers as needed


        -- Update this @config table row so it's marked as done and the next can be handled
        update @config set _done = 1 where config_key = @loop_config_key

    end -- end of loop over each @config row to handle

END
/* End of Code added 5/5/2020 - JPB for allowing MessageConfig use */

INSERT dbo.Message
        ( message_id ,
          status ,
          message_type ,
          message_source ,
          subject ,
          message ,
          added_by ,
          date_added ,
          modified_by ,
          date_modified ,
          date_to_send ,
          date_delivered ,
          error_description ,
          html ,
          message_type_id
        )
VALUES  ( @int_message_id, -- message_id - int
          'N', -- status - char(1)
          'E', -- message_type - char(1)
          @message_source, -- message_source - varchar(30)
          @subject, -- subject - varchar(255)
          @message, -- message - text
          @created_by, -- added_by - varchar(10)
          @now, -- date_added - datetime
          @created_by, -- modified_by - varchar(10)
          @now, -- date_modified - datetime
          @date_to_send, -- date_to_send - datetime
          NULL, -- date_delivered - datetime
          NULL, -- error_description - text
          @html, -- html - text
          @message_type_id  -- message_type_id - int
        )

SET NOCOUNT OFF
SELECT @int_message_id AS message_id
RETURN @int_message_id
        
ErrorLabel:
	RAISERROR ('Failed to create new message_id', 1, -1)

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_message_insert] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_message_insert] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_message_insert] TO [AX_SERVICE]
    AS [dbo];


GO

GRANT EXECUTE
    ON OBJECT::[dbo].[sp_message_insert] TO [Svc_OnBase_SQL]
    AS [dbo];


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_message_insert] TO [EQAI]
    AS [dbo];



