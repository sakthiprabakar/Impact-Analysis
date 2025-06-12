-- drop proc if exists sp_invoiced_me_ticket_notification
go

create proc sp_invoiced_me_ticket_notification
as
/* ----------------------------------------------------------------------------
sp_invoiced_me_ticket_notification

per Devops ticket 18089

	With EQAI version 7.4.71, we are introducing the ability / requirement to 
	tie a Manage Engine ticket to a work order.  Using this functionality, 
	Ken Knibbs would like us to add a nightly process to detect when an invoice 
	is generated for a transaction that contains a manage engine ticket number.

	If any invoices were generated in the past 24 hours that contain a transaction 
	with a Manage Engine ticket number, do the following.  Please note, if there 
	are more than 1 ME ticket number in a single invoice, send out an email for 
	each ME ticket.  Distinct on WorkOrderHeader.ticket_number 
		+ InvoiceHeader.invoice_code & InvoiceHeader.revision_id.

	1. Send an email to:  grocinvoice@usecology.com

	2. Attach the Invoice and Invoice Attachement PDFs to the email.

	3. Set the Subject of the email to the following, replacing the variables with 
		the information.  Also to note, the ## need to be included.
		
		Example:  (disregard line breaks in Example/Format)
			"##55123## - D365 Project:  P0001234.23 - 
					Invoice:  631046 - Invoice Date:  11/19/2020 - $87,543.21"
					
		Format:  (disregard line breaks in Example/Format)
			"##<Ticket No> ##- D365 Project:  <AX Project No.> - 
					Invoice:  <Invoice No.> - 
					Invoice Date:  <Invoice Date> - <Invoice Amount>"
					
			Ticket No = WorkOrderHeader.ticket_number
			AX Project No = WorkOrderHeader.AX_Dimension_5_Part_1
				If WorkOrderHeader.AX_Dimension_5_Part_2 is not null and is not 
					blank, then append a period and then the part 2 value.  
				
				For example AX_Dimension_5_Part_1 = P138.00189, 
					AX_Dimension_5_Part_2 = 04, display as:  P138.00189.04
					
				If WorkOrderHeader.AX_Dimension_5_Part_2 is null or is blank, 
					then display just the WorkOrderHeader.AX_Dimension_5_Part_1 
					value and no ending period.
					
			Invoice No = InvoiceHeader.invoice_code + 'R' + InvoiceHeader.revision_id
			Invoice Date = InvoiceHeader.invoice_date
			Invoice Amount = InvoiceHeader.total_amt_due
	
	4. Set the content of the email to the following: (disregard line breaks in text)

		The attached invoice was generated from EQAI for the following Manage 
		Engine ticket number:
	 
		(table):
		Manage Engine Ticket Number:	61098

		Manage Engine Link:				https://servicedesk.nrcc.com:4243/WorkOrder.do
										?woMode=viewWO&woID=[ME Ticket Number]

		D365 Project #					WorkOrderHeader.AX_Dimension_5_Part_1

											If WorkOrderHeader.AX_Dimension_5_Part_2 
											is not null and is not blank, then 
											append a period and then the part 2 
											value. 

											For example AX_Dimension_5_Part_1 = 
											P138.00189, AX_Dimension_5_Part_2 = 04, 
											display as:  P138.00189.04

											If WorkOrderHeader.AX_Dimension_5_Part_2 
											is null or is blank, then display 
											just the WorkOrderHeader.AX_Dimension_5_Part_1 
											value and no ending period.

		Billed From:					EQAI

		Service Facility:				ProfitCenter.profit_ctr_name

		Work Order #					Company ID-Profit Center ID-Work Order ID
											
											WorkOrderHeader.company_id + ‘-‘ 
											+ WorkOrderHeader.profit_ctr_id + ‘-‘ 
											+ WorkOrderHeader.workorder_id

		Invoice Date:					InvoiceHeader.invoice_date

		Invoice Amount:					InvoiceHeader.total_amt_due

		Company Name:					Customer.cust_name Customer Name from EQAI

		D365 Customer ID:				Customer.ax_customer_id from EQAI

		Customer Billing Address:		Customer Billing address from EQAI (City, State
											, Zip, Country)

Ongoing list of changes to make to the attached script:
	Add Paul as a test recipient
	
	Use the Config tables to store values like recipients, email addresses, last-ran date, etc.
	
	Make capable of multiple recipient addresses.


<end of ticket-copied content>

SELECT  * FROM    configuration
sp_columns COnfiguration

insert Configuration (config_key, config_value, added_by, date_added, modified_by, date_modified)
values ('sp_invoiced_me_ticket_notification recipients', 'Jonathan Broome <jonathan.broome@usecology.com>, Paul Kalinka <paul.kalinka@usecology.com>', 'jonathan', getdate(), 'jonathan', getdate())

insert Configuration (config_key, config_value, added_by, date_added, modified_by, date_modified)
values ('sp_invoiced_me_ticket_notification sender', 'do-not-reply@usecology.com', 'jonathan', getdate(), 'jonathan', getdate())

insert Configuration (config_key, config_value, added_by, date_added, modified_by, date_modified)
values ('sp_invoiced_me_ticket_notification last-ran-date', '1/1/2020', 'jonathan', getdate(), 'jonathan', getdate())

-- update configuration set config_value = '2/23/2021' where config_key = 'sp_invoiced_me_ticket_notification last-ran-date'

SELECT  * FROM    Configuration WHERE config_key like 'sp_invoiced_me_ticket_notification%'
delete  FROM    Configuration WHERE config_key like 'sp_invoiced_me_ticket_notification%'
sp_invoiced_me_ticket_notification

SELECT  TOP 10 *
FROM    message ORDER BY date_added desc
SELECT  * FROM    messageaddress WHERE message_id in (4087991, 4087992, 4087993, 4087994, 4087995, 4087996)

update message set status = 'V' WHERE message_id in  (4087991, 4087992, 4087993, 4087994, 4087995, 4087996)
and status= 'N'
-- 2021-03-02 16:52:53.440

History:
2021-01-25 JPB	Created
2021-03-02 JPB	Added Configuration table logic, multiple recipients option


---------------------------------------------------------------------------- */
declare @email_destination varchar(max) = ''
	, @email_sender varchar(max) = ''
	, @last_ran_date datetime = '1/1/2020'
	, @debug int = 0 /*  1 = list info, don't send email */

select top 1 @email_destination = config_value
from configuration (nolock)
where config_key = 'sp_invoiced_me_ticket_notification recipients'

if isnull(@email_destination, '') = ''
	select @email_destination = 'grocinvoice@usecology.com'

-- If on test or dev, don't actually email the groc.  OR the address in Config.
if @@SERVERNAME like '%test%' or @@SERVERNAME like '%dev%'
	select @email_destination = 'webmastergroup@usecology.com'

select top 1 @email_sender = config_value
from configuration (nolock)
where config_key = 'sp_invoiced_me_ticket_notification sender'

if isnull(@email_sender, '') = ''
	select @email_sender = 'webmastergroup@usecology.com'


select top 1 @last_ran_date = convert(date,config_value)
from configuration (nolock)
where config_key = 'sp_invoiced_me_ticket_notification last-ran-date'

if @last_ran_date is null
	select @last_ran_date = '1/1/2020'

if @debug = 1
	select 'Config Values' as [table]
		, @email_destination [@email_destination]
		, @email_sender [@email_sender]
		, @last_ran_date [@last_ran_date]

	
drop table if exists #work

create table #work (
	_row bigint
	, ticket_number	int
	, invoice_id	int
	, revision_id	int
	, invoice_code	varchar(16)
	, [subject]		varchar(255)
	, email_to		varchar(max)
	, invoice_image_id	int
	, attachment_image_id	int
	, html_body	varchar(max)
	, invoice_date	datetime
	, w_invoice_code	varchar(100)
	, w_invoice_total	varchar(100)
	, w_ax_customer_id	varchar(100)
	, w_cust_name	varchar(100)
	, w_transaction_id	varchar(100)
	, w_facility	varchar(100)
	, w_me_ticket	varchar(20)
	, message_id	bigint
	)

insert #work
select distinct 
	convert(bigint, 0) as _row
	, woh.ticket_number
	, ih.invoice_id
	, ih.revision_id
	, ih.invoice_code
	,'##'
		+ convert(varchar(20),woh.ticket_number)
		+ '## - D365 Project: ' 
		+ isnull(nullif(woh.AX_Dimension_5_Part_1 ,''), 'N/A')
		+ isnull('.' + nullif(AX_Dimension_5_Part_2,''), '')
		+ ' - Invoice: ' 
		+ ih.invoice_code + 'R' + convert(varchar(10),ih.revision_id)
		+ ' - Invoice Date: '
		+ convert(varchar(10), ih.invoice_date, 101)
		+ ' - '
		+ format(ih.total_amt_due, '$#,###.00')
		as subject
/*		
	, woh.ticket_number
	, ih.invoice_code + 'R' + convert(varchar(10),ih.revision_id) invoice_code
	, ih.status
	, ih.invoice_date
	, format(ih.total_amt_due, '$#,###.00') total_amt_due
	, ih.invoice_image_id
	, ih.attachment_image_id
	, woh.AX_Dimension_5_Part_1 + isnull('.' + nullif(AX_Dimension_5_Part_2,''), '') AX_Project
*/
	, @email_destination as email_to
	, ih.invoice_image_id
	, ih.attachment_image_id
	, '
		<html><head>
			<style>
			body{font-family:Calibri,sans-serif}
			td{border:1pt solid rgb(142,170,219);padding:2px 6px}
			table{border-collapse:collapse}
			tr:nth-child(even){background:rgb(217,226,243)}
			</style></head>
		<body>
		The attached invoice was generated from EQAI for the following Manage Engine ticket number:
		<table>
		<tr><td>
			Manage Engine Ticket Number:
		</td><td>
		' + convert(varchar(20),woh.ticket_number) + '
		</td></tr>
		<tr><td>
			Manage Engine Link:
		</td><td>
			<a href="https://servicedesk.nrcc.com:4243/WorkOrder.do?woMode=viewWO&woID=' + convert(varchar(20),woh.ticket_number) + '" target="_blank">https://servicedesk.nrcc.com:4243/WorkOrder.do?woMode=viewWO&woID=' + convert(varchar(20),woh.ticket_number) + '<
/a>
		</td></tr>
		<tr><td>
			D365 Project #:
		</td><td>
		' + woh.AX_Dimension_5_Part_1 
			+ isnull('.' + nullif(AX_Dimension_5_Part_2,''), '') + '
		</td></tr>
		<tr><td>
			Billed From:
		</td><td>
			EQAI
		</td></tr>
		<tr><td>
			Service Facility:
		</td><td>
		' + pc.profit_ctr_name + '
		</td></tr>
		<tr><td>
			Work Order #:
		</td><td>
		' + convert(varchar(2), woh.company_id) + '-' + convert(varchar(2), woh.profit_ctr_id) + '-' + convert(varchar(20), woh.workorder_id) + '
		</td></tr>
		<tr><td>
			Invoice Date:
		</td><td>
		' + convert(varchar(10), ih.invoice_date, 101) + '
		</td></tr>
		<tr><td>
			Invoice Amount:
		</td><td>
		' + format(ih.total_amt_due, '$#,###.00') + '
		</td></tr>
		<tr><td>
			Company Name:
		</td><td>
		' + cust.cust_name + '
		</td></tr>
		<tr><td>
			D365 Customer ID:
		</td><td>
		' + ax_customer_id + '
		</td></tr>
		<tr><td>
			Customer Billing Address:
		</td><td>
		' + cust.cust_city + ', ' + cust.cust_state +'  ' + cust.cust_zip_code + '  ' + cust.cust_country + '
		</td></tr>
		</table></body></html>
		' as html_body
, ih.invoice_date
, ih.invoice_code + 'R' + convert(varchar(10),ih.revision_id) as w_invoice_code
, format(ih.total_amt_due, '$#,###.00') as w_invoice_total
, ax_customer_id as w_ax_customer_id
, cust.cust_name as w_cust_name
, convert(varchar(2), woh.company_id) + '-' + convert(varchar(2), woh.profit_ctr_id) + '-' + convert(varchar(20), woh.workorder_id) as w_transaction_id
, pc.profit_ctr_name as w_facility
, convert(varchar(20),woh.ticket_number) as w_me_ticket
, convert(bigint, 0) as message_id
from invoiceheader ih (nolock) 
join axinvoiceheader ax (nolock) on ih.invoice_id = ax.invoice_id and ih.revision_id = ax.revision_id
join invoicedetail id (nolock) on ih.invoice_id = id.invoice_id and ih.revision_id = id.revision_id
join workorderheader woh (nolock) on id.trans_source = 'W' and id.receipt_id = woh.workorder_id and id.company_id = woh.company_id and id.profit_ctr_id = woh.profit_ctr_id
join profitcenter pc (nolock) on woh.company_id = pc.company_id and woh.profit_ctr_id = pc.profit_ctr_id
join customer cust (nolock) on ih.customer_id = cust.customer_id
WHERE isnull(woh.ticket_number,0) > 0
and ax.date_added >= @last_ran_date

-- SELECT  * FROM    #work ORDER BY _row

update #work set _row = x._row
from #work w join (
	select row_number() over (order by invoice_date, invoice_id) as _row
	, ticket_number
	, invoice_id
	, revision_id
	, invoice_code
	, invoice_date
	from #work
) x
	on w.ticket_number = x.ticket_number
	and w.invoice_id = x.invoice_id
	and w.revision_id = x.revision_id
	and w.invoice_code = x.invoice_code
	and w.invoice_date = x.invoice_date
	
-- SELECT  * FROM    #work ORDER BY _row
-- update #work set message_id = 0



-- status email:
insert #Work
select 
	(select isnull(max(_row), 0) +1 from #work)
	, -1 ticket_number
	, -1 invoice_id
	, 0 revision_id
	, '' invoice_code
	,'## Invoiced Ticket Notification Status ##' as subject
	, 'webmastergroup@usecology.com' as email_to
	, null invoice_image_id
	, null attachment_image_id
	, '
		<html><head>
			<style>
			body{font-family:Calibri,sans-serif}
			td{border:1pt solid rgb(142,170,219);padding:2px 6px}
			table{border-collapse:collapse}
			tr:nth-child(even){background:rgb(217,226,243)}
			</style></head>
		<body>
		The Invoiced Manage Engine Ticket Notification procedure ran at ' + convert(varchar(20), getdate()) + '.
		<br/><br/>
		Want Stats?
		<br/><br/>
		Stats:
		<table>
		<tr><td>
			Manage Engine Tickets Found:
		</td><td>
		' + convert(varchar(20),(select count(*) from #work)) + '
		</td></tr>
		' + case when (select count(*) from #work) = 0 then ''
			else '			
		<tr><td>
			Invoice Summary:
		</td><td>
		<table cellspacing=0 cellpadding=1 border=1>
		<tr>
		<th>Invoice</th>
		<th>Invoice Amt</th>
		<th>Cust ID</th>
		<th>Customer</th>
		<th>Work Order</th>
		<th>Facility</th>
		<th>ME Ticket</th>
		</tr>
		' +
	
			 isnull(
			 ( select substring(
				(
				select '  ' +
					'<tr>' +
					'<td>' + w_invoice_code + '</td>' +
					'<td>' + w_invoice_total + '</td>' +
					'<td>' + w_ax_customer_id + '</td>' +
					'<td>' + w_cust_name + '</td>' +
					'<td>' + w_transaction_id + '</td>' +
					'<td>' + w_facility + '</td> ' +
					'<td>' + w_me_ticket + '</td>' +
					'</tr>'
				FROM    #work w
				order by _row
				for xml path, TYPE).value('.[1]','nvarchar(max)'),2,20000)
			)
			, '') +
		'
		</table>
		</td></tr>
		' end + '
		</table></body></html>
		' as html_body
	, null invoice_date
	, null w_invoice_code
	, null w_invoice_total
	, null w_ax_customer_id
	, null w_cust_name
	, null w_transaction_id
	, null w_facility
	, null w_me_ticket
	, 0 message_id

-- SELECT  * FROM    #Work


declare @row bigint
	, @msg_id bigint
	, @subject varchar(255)
	, @email_to	varchar(max)
	, @invoice_code varchar(16)
	, @invoice_image_id bigint
	, @attachment_image_id bigint
	, @invoice_filename varchar(100)
	, @attachment_filename varchar(100)
	, @message varchar(max)
	, @html varchar(max)
	, @sql varchar(max)
	, @crlf varchar(2) = CHAR(13) + CHAR(10)
	, @this_email varchar(100)
	, @email_name varchar(100)
	, @email_addr varchar(100)

declare @tbl_email_to table (
	idx	int
	, email_to	varchar(100)
)
	
while exists (Select 1 from #work where message_id = 0) begin

	select top 1
		@row = _row
		, @msg_id = null
		, @subject = subject
		, @email_to	= email_to
		, @invoice_code = invoice_code
		, @invoice_image_id = invoice_image_id
		, @attachment_image_id = attachment_image_id
		, @invoice_filename = 'Invoice_' + invoice_code + '.PDF'
		, @attachment_filename = 'Invoice_' + invoice_code + '_Attachments.PDF'
		, @message = ''
		, @html = html_body
		, @sql = ''
	from #work
	where message_id = 0	
	order by _row

	if @debug = 1 begin
	
		select
		@row [@row]
		, @subject [@subject]
		, @email_to	[@email_to]
		, @invoice_code [@invoice_code]
		, @invoice_image_id [@invoice_image_id]
		, @attachment_image_id [@attachment_image_id]
		, @invoice_filename [@invoice_filename]
		, @attachment_filename [@attachment_filename]
		, @html [@html]
		
	end
	else
	begin

		delete from @tbl_email_to
		
		insert @tbl_email_to (idx, email_to)
		select idx, row
		from dbo.fn_SplitXsvText(',', 1, @email_to)
		where row is not null

	/*
		select 
			@row _row
			, @msg_id message_id
			, @subject subject
			, @email_to email_to
			, @invoice_code invoice_code
			, @invoice_image_id invoice_image_id
			, @attachment_image_id attachment_image_id
			, @html html
	*/
		
		-- select @sql = 'declare @msg_id bigint,@date_to_send datetime = dateadd(mi, 2, getdate()))'
		declare @date_to_send datetime = dateadd(mi, 2, getdate())
		
		-- select @sql = @sql + ';' + @crlf + 'EXEC @msg_id = sp_message_insert ''' + @subject + ''', null, ''' + @html + ''', ''SQLAgent'', ''Invoiced ME Ticket job'', @date_to_send, NULL, NULL'
		EXEC @msg_id = sp_message_insert @subject, NULL, @html, 'SQLAgent', 'Invoiced ME Ticket job', @date_to_send, NULL, NULL

		if @invoice_image_id is not null BEGIN
			-- select @sql = @sql + ';' + @crlf + 'EXEC sp_messageAttachment_insert @msg_id, ''Image'', ''InvoiceImage'', ' + convert(varchar(20), @invoice_image_id) + ', ''' + @invoice_filename + ''', 1'
			EXEC sp_messageAttachment_insert @msg_id, 'Image', 'InvoiceImage', @invoice_image_id, @invoice_filename, 1
		END

		if @attachment_image_id is not null BEGIN
			-- select @sql = @sql + ';' + @crlf + 'EXEC sp_messageAttachment_insert @msg_id, ''Image'', ''InvoiceImage'', ' + convert(varchar(20), @attachment_image_id) + ', ''' + @attachment_filename+ ''', 2'
			EXEC sp_messageAttachment_insert @msg_id, 'Image', 'InvoiceImage', @attachment_image_id, @attachment_filename, 2
		END

		-- select @sql = @sql + ';' + @crlf + 'EXEC sp_messageAddress_insert @msg_id, ''FROM'', ''' + @email_to + ''', ''' + @email_to + ''', ''USE'', NULL, NULL, NULL'
		EXEC sp_messageAddress_insert @msg_id, 'FROM', 'do-not-reply@usecology.com', 'do-not-reply@usecology.com', 'USE', NULL, NULL, NULL

		while exists (select 1 from @tbl_email_to where idx > 0) begin
		
			select top 1 
			@this_email = email_to
			from @tbl_email_to
			where idx > 0
			
			-- handle EmailName <EmailAddress> format:
			if charindex('<',@this_email) > 0
				select @email_name = ltrim(rtrim(left(@this_email, charindex('<', @this_email)-1)))
				, @email_addr = ltrim(rtrim(replace(replace(right(@this_email, len(@this_email)-charindex('<', @this_email)+1),'<',''), '>', '')))
			else
				select @email_name = @this_email
				, @email_addr = @this_email
			
			-- select @sql = @sql + ';' + @crlf + 'EXEC sp_messageAddress_insert @msg_id, ''TO'', ''' + @email_to + ''', ''' + @email_to + ''', ''USE'', NULL, NULL, NULL'
			EXEC sp_messageAddress_insert @msg_id, 'TO', @email_addr, @email_name, 'USE', NULL, NULL, NULL
			
			update @tbl_email_to set idx = 0 where email_to = @this_email
			
		end

		-- select @sql [sql]
		
	end -- debug = 0
	
	update #work set message_id = @msg_id where _row = @row

	-- select '-------------------------------'
			
end -- while

update configuration set config_value = convert(varchar(40), getdate(), 121)
where config_key = 'sp_invoiced_me_ticket_notification last-ran-date'



go

grant execute on sp_invoiced_me_ticket_notification to EQAI

