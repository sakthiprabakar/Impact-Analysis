create proc sp_message_requeue (
	@message_id_list	varchar(max) = ''
)
as
/* ****************************************************************************
sp_message_requeue

	takes a list of CSV message id's, check to see if they're failed/in progress
	and sets their (and related tables) status back to New so they can resend.
	WILL NOT requeue a sent or voided message.  Do those by hand, slacker.
	
History
	8/9/2012 - JPB: Created

-- select * from message where date_added > '8/1/2012' and status not in ('S', 'V', 'N')
-- select * from message where date_added > '8/1/2012' and status in ('V')
	
Example
	sp_message_requeue
	sp_message_requeue '281749, 281750, 281752, 281753, 281875, 277754' /* Last 2 are sent, void, just to test */
	sp_message_requeue '281518, 281525, 281530'
	
One or more attachments failed:   Could not retrieve blob for attachment_id 1 ( InvoiceImage.image_id 1379947)  2013-03-09 00:56:30.210   command finished  2013-03-09 00:56:30.227   checking existence of temp\512034\Invoice_40444649.PDF  2013-03-09 00:56:
30.240   file does not exist:  temp\512034\Invoice_40444649.PDF  2013-03-09 00:56:30.260   processing attachment 1  2013-03-09 00:56:30.263   cscript.exe GetAttachment.vbs "temp\512034\Invoice_40444649_Attachments.PDF" 512034 2  Could not retrieve blob fo
r attachment_id 2 ( InvoiceImage.image_id 1379948)  2013-03-09 00:56:30.680   command finished  2013-03-09 00:56:30.687   checking existence of temp\512034\Invoice_40444649_Attachments.PDF  2013-03-09 00:56:30.690   file does not exist:  temp\512034\Invoi
ce_40444649_Attachments.PDF  2013-03-09 00:56:30.700   attachment count check: DB = 2, Email = 0  2013-03-09 00:56:30.707   counts match.  2013-03-09 00:56:30.717   Error found: Invoice_40444649.PDF is missing.  Invoice_40444649_Attachments.PDF is missing
.    2013-03-09 00:56:30.740   -FAILED- : New EQ Invoice 40444649 || TO: billing@eqonline.com || FROM: billing@eqonline.com || ****************************************  This Email Failed!  We can't say exactly why, but this email  was not delivered to the
 TO address.  Could be a bad address, internet problem  over-limit attachment size, etc.  We recommend trying to send the email below   again yourself.    Subject: New EQ Invoice 40444649  To: billing@eqonline.com  webdev@eqonline.com    From: billing@eqo
nline.com  Possible error: Invoice_40444649.PDF is missing.  Invoice_40444649_Attachments.PDF is missing.    ****************************************    Dear Valued Customer,  Pursuant to your request, the attached invoice and attachments have been sent t
o you via e-mail.  Thank you for your continued business!  Sincerely,  EQ - The Environmental Quality Company    EQ is committed to providing the highest quality environmental services possible and delivering "Best in Class" customer care that continually
 sets the standard in the industry.  Working closely with each customer, we create a valuable strategic alliance by implementing environmental solutions that enhance their business.  For more information on EQ, please visit our website at www.eqonline.com
 or call (800) 592-5489.  2013-03-09 00:56:30.857     attachments:     {    }  .execute()  {    Trying server mail:smtp.eqonline.com    <- 220 smtprelay.eqonline.com Microsoft ESMTP MAIL Service, Version: 7.0.6002.18264 ready at  Sat, 9 Mar 2013 00:56:35 
-0500     -> EHLO ntsql1dev    <- 250-smtprelay.eqonline.com Hello [10.13.1.23]  250-AUTH=LOGIN  250-AUTH LOGIN  250-TURN  250-SIZE 20480000  250-ETRN  250-PIPELINING  250-DSN  250-ENHANCEDSTATUSCODES  250-8bitmime  250-BINARYMIME  250-CHUNKING  250-VRFY 
 250-TLS  250-STARTTLS  250 OK    -> AUTH LOGIN  Sending authentication data..    -> MAIL FROM:<billing@eqonline.com>    <- 250 2.1.0 billing@eqonline.com....Sender OK    -> RCPT TO:billing@eqonline.com    <- 250 2.1.5 billing@eqonline.com     -> DATA    
<- 354 Start mail input; end with <CRLF>.<CRLF>    Sending headers...    Sending body...    Message sent    <- 250 2.6.0 <WEB01JswFCHOzyfyz5b000015ac@smtprelay.eqonline.com> Queued mail for delivery    0 of 1 servers failed  }  	
	
	sp_message_requeue 'void 512034'
	
	sp_message_requeue 'info 512034'

One or more attachments failed:   Could not retrieve blob for attachment_id 1 ( InvoiceImage.image_id 1379947)  2013-03-09 00:56:30.210   command finished  2013-03-09 00:56:30.227   checking existence of temp\512034\Invoice_40444649.PDF  2013-03-09 00:56:
30.240   file does not exist:  temp\512034\Invoice_40444649.PDF  2013-03-09 00:56:30.260   processing attachment 1  2013-03-09 00:56:30.263   cscript.exe GetAttachment.vbs "temp\512034\Invoice_40444649_Attachments.PDF" 512034 2  Could not retrieve blob fo
r attachment_id 2 ( InvoiceImage.image_id 1379948)  2013-03-09 00:56:30.680   command finished  2013-03-09 00:56:30.687   checking existence of temp\512034\Invoice_40444649_Attachments.PDF  2013-03-09 00:56:30.690   file does not exist:  temp\512034\Invoi
ce_40444649_Attachments.PDF  2013-03-09 00:56:30.700   attachment count check: DB = 2, Email = 0  2013-03-09 00:56:30.707   counts match.  2013-03-09 00:56:30.717   Error found: Invoice_40444649.PDF is missing.  Invoice_40444649_Attachments.PDF is missing
.    2013-03-09 00:56:30.740   -FAILED- : New EQ Invoice 40444649 || TO: billing@eqonline.com || FROM: billing@eqonline.com || ****************************************  This Email Failed!  We can't say exactly why, but this email  was not delivered to the
 TO address.  Could be a bad address, internet problem  over-limit attachment size, etc.  We recommend trying to send the email below   again yourself.    Subject: New EQ Invoice 40444649  To: billing@eqonline.com  webdev@eqonline.com    From: billing@eqo
nline.com  Possible error: Invoice_40444649.PDF is missing.  Invoice_40444649_Attachments.PDF is missing.    ****************************************    Dear Valued Customer,  Pursuant to your request, the attached invoice and attachments have been sent t
o you via e-mail.  Thank you for your continued business!  Sincerely,  EQ - The Environmental Quality Company    EQ is committed to providing the highest quality environmental services possible and delivering "Best in Class" customer care that continually
 sets the standard in the industry.  Working closely with each customer, we create a valuable strategic alliance by implementing environmental solutions that enhance their business.  For more information on EQ, please visit our website at www.eqonline.com
 or call (800) 592-5489.  2013-03-09 00:56:30.857     attachments:     {    }  .execute()  {    Trying server mail:smtp.eqonline.com    <- 220 smtprelay.eqonline.com Microsoft ESMTP MAIL Service, Version: 7.0.6002.18264 ready at  Sat, 9 Mar 2013 00:56:35 
-0500     -> EHLO ntsql1dev    <- 250-smtprelay.eqonline.com Hello [10.13.1.23]  250-AUTH=LOGIN  250-AUTH LOGIN  250-TURN  250-SIZE 20480000  250-ETRN  250-PIPELINING  250-DSN  250-ENHANCEDSTATUSCODES  250-8bitmime  250-BINARYMIME  250-CHUNKING  250-VRFY 
 250-TLS  250-STARTTLS  250 OK    -> AUTH LOGIN  Sending authentication data..    -> MAIL FROM:<billing@eqonline.com>    <- 250 2.1.0 billing@eqonline.com....Sender OK    -> RCPT TO:billing@eqonline.com    <- 250 2.1.5 billing@eqonline.com     -> DATA    
<- 354 Start mail input; end with <CRLF>.<CRLF>    Sending headers...    Sending body...    Message sent    <- 250 2.6.0 <WEB01JswFCHOzyfyz5b000015ac@smtprelay.eqonline.com> Queued mail for delivery    0 of 1 servers failed  }      Last Modified By: Messe
nger  Last Modified At: Mar  9 2013 12:56AM    Voided By: JONATHAN  Voided At: Mar 13 2013  4:27PM

	
**************************************************************************** */

declare @info_mode int = 0, @void_mode int = 0, @message_id int, @error varchar(max) = '', @crlf varchar(4) = CHAR(13) + CHAR(10)

if len(ltrim(rtrim(@message_id_list))) = 0 
begin

	create table #instructions (instructions varchar(40), ord int)
	insert #instructions
	select 'SP_Message_Requeue', 100
	union
	select 'This SP will re-queue message_ids that', 200
	union
	select '  have failed (or been In Progress ', 300
	union
	select '  for over 30 minutes).', 400
	union
	select 'Running it without arguments shows this', 500
	union
	select '   info, plus a list of current failures.', 600
	union
	select 'Running it with the word ''info'' first in the ', 700
	union
	select '   arg list shows Message table data for', 800
	union
	select '    the list.', 810
	union
	select 'Running it with the word ''void'' first in the ', 850
	union
	select '   arg list voids Message table data for', 851
	union
	select '    the list.', 852
	union
	select 'Running it with a comma-separated list', 900
	union
	select '   of message_ids will requeue those', 1000
	union
	select '    messages.', 1100
	
	select instructions from #instructions order by ord

	-- Since you didn't list a message to view, we show you all the fails that you might be interested in.
	select 
		message_id
		, date_added
		, date_to_send
		, case status when 'F' then 'Failed' when 'I' then
			case when date_modified < dateadd(n, -30, getdate()) then 'In Progress over 30m' else 'In Progress (Normal)' end
			end as status
		, case message_type when 'E' then 'Email' when 'F' then 'Fax' else message_type end as message_type
		, error_description
		, date_modified
		, message_source
		, subject
		, message
		, html
		, added_by
		, modified_by
		from Message 
		where date_added > getdate()-30 
		and status not in ('S', 'V', 'N')

end -- @message_id_list was blank/null
else
begin -- @message_id_list was given

	if left(ltrim(@message_id_list), 4) = 'info' begin
		set @info_mode = 1
		set @message_id_list = replace(@message_id_list, 'info', '')
	end

	if left(ltrim(@message_id_list), 4) = 'void' begin
		set @void_mode = 1
		set @message_id_list = replace(@message_id_list, 'void', '')
	end

	create table #messages (message_id int, status varchar(20))
	
	insert #messages (message_id)
	select convert(int, row)
	from dbo.fn_splitxsvtext(',', 1, @message_id_list)
	where row is not null
	
	if @info_mode = 0 and @void_mode = 0 begin

		update #Messages set status = m.status
		from #Messages inner join Message m on #Messages.message_id = m.message_id

		update #Messages set status = 'I - over 30m'
		from #Messages inner join Message m on #Messages.message_id = m.message_id
		where m.status = 'I' and date_modified < dateadd(n, -30, getdate()) -- Only if it's in progress longer than 30m

		select 'Cannot auto-requeue this message' as problem, * from #Messages where status not in ('F', 'I - over 30m')
			
		update MessageAttachment set status = 'N' where message_id in (select message_id from #Messages where status in ('F', 'I - over 30m'))
		update Message set status = 'N' where message_id in (select message_id from #Messages where status in ('F', 'I - over 30m'))

		select 'Requeued' as status, * from #Messages where status in ('F', 'I - over 30m')
	end
	else
	begin
		while @info_mode = 1 and exists (select 1 from #messages where status is null) begin
			select top 1 @message_id = message_id from #messages where status is null order by message_id
			
			select * from message where message_id = @message_id
			select * from messageaddress where message_id = @message_id
			select *
				, case when source = 'InvoiceImage' then
					(select coalesce( 'Exists: ' + convert(varchar(20), convert(numeric(5,2), round(((datalength(image_blob) / 1024.00) / 1024.00) , 2))) + 'mb', 'Image does not exist')
					 from plt_image..InvoiceImage where image_id = messageattachment.image_id )
				  else
					(select coalesce( 'Exists: ' + convert(varchar(20), convert(numeric(5,2), round(((datalength(image_blob) / 1024.00) / 1024.00), 2))) + 'mb', 'Image does not exist')
					 from plt_image..ScanImage where image_id = messageattachment.image_id )
				  end as [info]
			from messageattachment where message_id = @message_id
			select '' as divider
			
			update #messages set status = 'done' where message_id = @message_id
		
		end

		while @void_mode = 1 and exists (select 1 from #messages where status is null) begin
			select top 1 @message_id = message_id from #messages where status is null order by message_id

			if exists (select 1 from message where message_id = @message_id and isnull(status, '') <> 'V') begin
				select @error = isnull(error_description, '') from message where message_id = @message_id
				select @error = @error + @crlf + @crlf + 'Last Modified By: ' + isnull(modified_by, '') + @crlf + 'Last Modified At: ' + isnull(convert(varchar(20), date_modified), '') from message where message_id = @message_id
				update message set status = 'V', date_modified = getdate(), modified_by = system_user where message_id = @message_id
				select @error = @error + @crlf + @crlf + 'Voided By: ' + modified_by + @crlf + 'Voided At: ' + convert(varchar(20), date_modified) from message where message_id = @message_id
				update message set error_description = @error where message_id = @message_id
				
				select 'Message_id ' + convert(varchar(20), @message_id) + ' voided.' as info
			end
			
			update #messages set status = 'done' where message_id = @message_id
		
		end

	end
end


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_message_requeue] TO [EQAI]
    AS [dbo];

