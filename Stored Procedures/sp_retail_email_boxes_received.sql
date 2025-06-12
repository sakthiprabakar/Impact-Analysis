CREATE PROCEDURE sp_retail_email_boxes_received (
	@debug int = 0, -- 0 for false, 1 for true
	@email	varchar(60),
	@order_id_list varchar(8000) -- this is a list of order ids that are associated to _ONE_ shipping address
) AS
/***************************************************************
Loads to:	Plt_AI

Sends an email to the input email address if there were any products received that haven't been emailed about yet.

05/21/2008 JPB	Created
09/22/2008 JPB	Modified to include plain text version as well as html
09/23/2008 JPB	Added code to exclude orders where send_email_flag <> 'Y'
11/11/2008 JPB	Modified: Don't send emails for "old" records (oi records where the box has been returned, but email not sent, and box was returned more than a week ago)
03/17/2009 RJG  Modified to accept a list of order_ids (passed in as part of the same location)
				Modified to add location information

select top 5 * from message order by message_id desc

sp_retail_email_boxes_received 'odfighjodg@hotmail.com'
****************************************************************/
SET NOCOUNT ON

CREATE TABLE #order_list (ID int)
Insert #order_list 
	select convert(int, row) 
	from dbo.fn_SplitXsvText(',', 0, @order_id_list) 
	where isnull(row, '') <> ''


DECLARE @date_retrieval_window int
set @date_retrieval_window = -7 -- negative number.  amount of DAYS in the past to scan for emails that should be sent out.  Usually 7

DECLARE 
	@order_detail		varchar(8000),
	@pos				int,
	@email_text			varchar(8000),
	@email_html			varchar(8000),
	@crlf				varchar(4),
	@crlf2				varchar(8),
	@message_id			int,
	@itemcount			int,
	@Tptrval			binary(16),
	@Dptrval			binary(16),
	@TptrvalText		binary(16),
	@DptrvalText		binary(16),
	@date_returned		datetime,
	@quantity_returned	float,
	@description		varchar(60),
	@cor_flag			char(1),
	@replenishment_flag	char(1),
	@order_id			int,
	@line_id			int,
	@sequence_id		int,
	@product_id			int,
	@thisDate			datetime,

	@ship_customer_name	varchar(100),
	@ship_address1		varchar(100),
	@ship_address2		varchar(100),
	@ship_address3		varchar(100),
	@ship_address4		varchar(100),
	@ship_address5		varchar(100),
	@ship_city			varchar(100),
	@ship_state			varchar(50),
	@ship_zip_code		varchar(50),

	@location		varchar(8000)

-- Abort if they're already processed, or none to process
if not exists (
   select
   -- oh.email,               -- this isn't needed, it'll be the same AND it's given by the sp input.
   -- oh.ship_attention_name, -- This could be a problem if more than 1 name is given for the same email.
   oi.date_returned,
   oi.quantity_returned,
   p.description,
   od.cor_flag,
   od.replenishment_flag,
   oi.order_id,
   oi.product_id,
   oi.line_id,
   oi.sequence_id
   from orderheader oh
   inner join orderdetail od on oh.order_id = od.order_id
   inner join orderitem oi on od.order_id = oi.order_id and od.line_id = oi.line_id
   inner join product p on od.product_id = p.product_id and od.company_id = p.company_id and od.profit_ctr_id = p.profit_ctr_id
   where oi.date_returned is not null
   and oi.date_return_ack_sent is null
   and oi.date_returned > dateadd(dd, @date_retrieval_window, getdate())
   and isnull(oh.email, '') = @email
   and oh.send_email_flag = 'Y'
) return

set @crlf = char(13) + char(10)
set @crlf2 = @crlf + @crlf
Set @email_html = '<html><body style="font-family:verdana,sans-serif;font-size:14px"><table border="0" cellspacing="0" cellpadding="0" style="border: solid 1px #000;width:716px;font-size:14px"><tr><td bgcolor="#1A9B1A" width="100%"><p style="background:url(http://dev.usecology.com/graphics/white-dot.gif) repeat-x;margin-top:100px;width:100%">&nbsp;</p></td></tr><tr><td style="padding:1em" colspan="2"><p>US Ecology has received the Pack Back box you shipped.  You may verify the information for your shipment below.    To replace your order where a new container will be shipped to you, please visit <a href="http://www.usecology.com/SustainableSolutions">http://www.usecology.com/SustainableSolutions</a>.</p><p>{LOCATION_INFO}</p>{ORDER_DETAIL}<p style="color:#396;padding-bottom:1em;border-bottom:dotted 2px #1A9B1A">Thank you for using the US Ecology Sustainable Solutions Pack Back Recycling Program!</p><p>To view the most up to date Pack Back information, please visit <a href="http://www.usecology.com/">www.usecology.com</a></p><p>US Ecology''s Pack Back program is a web based universal waste recycling program for environmentally sound and compliant solutions, encompassing federal and state specific regulations for:</p><ul style="width:100%;float:left;list-style:none"><li style="float:left;width:32.5%;">&#149; Handling</li><li style="float:left;width:32.5%;">&#149; Storage</li><li style="float:left;width:32.5%;">&#149; Labeling</li><li style="float:left;width:32.5%;">&#149; Shipping</li><li style="float:left;width:32.5%;">&#149; Tracking</li><li style="float:left;width:32.5%;">&#149; Documenting</li><li style="float:left;width:32.5%;">&#149; Training</li></ul><p style="clear:both">To speak to someone regarding the Pack Back program, please call us at <span style="white-space:nowrap">800-592-5489.</span></p></td></tr></table></body></html>'

Set @email_text = 'US Ecology - Sustainable Solutions' + @crlf2 + 'US Ecology has received the Pack Back box you shipped.  You may verify the information for your shipment below.  To replace your order where a new container will be shipped to you, please visit http://www.usecology.com/SustainableSolutions' + @crlf2 + '{LOCATION_INFO}' + @crlf2 + '{ORDER_DETAIL}Thank you for using the US Ecology Sustainable Solutions Pack Back Recycling Program!' + @crlf2 + 'To view the most up to date Pack Back information, please visit www.usecology.com' + @crlf2 + 'US Ecology''s Pack Back program is a web based universal waste recycling program for environmentally sound and compliant solutions, encompassing federal and state specific regulations for Handling, Storage, Labeling, Shipping, Tracking, Documenting and Training' + @crlf2 + 'To speak to someone regarding the Pack Back program, please call us at 800-592-5489.'

Set @order_detail = "<p style=""margin-bottom:0""><b>Items Received:</b></p>" + 
	"<table border=""0"" cellspacing=""0"" cellpadding=""6"" style=""width:100%;border: solid 1px #000"">" +
	"<tr><td>" +
	"<table cellspacing=""0"" cellpadding=""3"" style=""width:100%;font-size:14px"">" +
	"<thead><tr>" +
	"<th style=""border-bottom:solid 1px #1D9A1A;text-align:left;"">Order</th>" + 
	"<th style=""border-bottom:solid 1px #1D9A1A;text-align:left;"">Description</th>" + 
	"<th style=""border-bottom:solid 1px #1D9A1A;text-align:right"">Date Received</th>" + 
	"</tr></thead>"

create table #html (t_desc varchar(40), t_field text)
create table #text (t_desc varchar(40), t_field text)
insert #html (t_desc, t_field) values ('template', @email_html)
insert #html (t_desc, t_field) values ('detail', @order_detail)
insert #html (t_desc, t_field) values ('location', '')


insert #text (t_desc, t_field) values ('template', @email_text)
insert #text (t_desc, t_field) values ('detail', '')
insert #text (t_desc, t_field) values ('location', '')
	
SELECT @Tptrval = TEXTPTR(t_field) FROM #html where t_desc = 'template'
SELECT @Dptrval = TEXTPTR(t_field) FROM #html where t_desc = 'detail'
SELECT @TptrvalText = TEXTPTR(t_field) FROM #text where t_desc = 'template'
SELECT @DptrvalText = TEXTPTR(t_field) FROM #text where t_desc = 'detail'

DECLARE @ptr_location_token_html binary(16)
DECLARE @ptr_location_token_text binary(16)
SELECT @ptr_location_token_html = TEXTPTR(t_field) FROM #html where t_desc = 'location'
SELECT @ptr_location_token_text = TEXTPTR(t_field) FROM #text where t_desc = 'location'



DECLARE @tbl_order_info table (
	date_returned datetime,
	product_id int,
	description varchar(100),
	order_id int,
	ship_cust_name varchar(100),
	ship_addr1 varchar(100),
	ship_addr2 varchar(100),
	ship_addr3 varchar(100),
	ship_addr4 varchar(100),
	ship_addr5 varchar(100),
	ship_city varchar(50) ,
	ship_state  varchar(50),
	ship_zip_code  varchar(50)
)

INSERT INTO @tbl_order_info
select
	oi.date_returned,
	p.product_id,
	p.description,
	oi.order_id,
	oh.ship_cust_name,
	oh.ship_addr1,
	oh.ship_addr2,
	oh.ship_addr3,
	oh.ship_addr4,
	oh.ship_addr5,
	oh.ship_city,
	oh.ship_state,
	oh.ship_zip_code
   from orderheader oh
   inner join orderdetail od on oh.order_id = od.order_id
   inner join orderitem oi on od.order_id = oi.order_id and od.line_id = oi.line_id
   inner join product p on od.product_id = p.product_id and od.company_id = p.company_id and od.profit_ctr_id = p.profit_ctr_id
   INNER JOIN #order_list list ON oh.order_id = list.id
   where oi.date_returned is not null
   and oi.date_return_ack_sent is null
   and isnull(oh.email, '') = @email
   and oi.date_returned > dateadd(dd, @date_retrieval_window, getdate())
   group by 	oi.date_returned,
	p.product_id,
	p.description,
	oi.order_id,
	oh.ship_cust_name,
	oh.ship_addr1,
	oh.ship_addr2,
	oh.ship_addr3,
	oh.ship_addr4,
	oh.ship_addr5,
	oh.ship_city,
	oh.ship_state,
	oh.ship_zip_code


SELECT TOP 1 @ship_customer_name = ship_cust_name FROM @tbl_order_info
SELECT TOP 1 @ship_address1 = isnull(ship_addr1, '')  FROM @tbl_order_info
SELECT TOP 1 @ship_address2 = isnull(ship_addr2, '')  FROM @tbl_order_info
SELECT TOP 1 @ship_address3 =  isnull(ship_addr3, '') FROM @tbl_order_info
SELECT TOP 1 @ship_address4 =  isnull(ship_addr4, '') FROM @tbl_order_info
SELECT TOP 1 @ship_address5 =  isnull(ship_addr5, '') FROM @tbl_order_info
SELECT TOP 1 @ship_city =  isnull(ship_city, '')  FROM @tbl_order_info
SELECT TOP 1 @ship_state =  isnull(ship_state, '') FROM @tbl_order_info
SELECT TOP 1 @ship_zip_code =  isnull(ship_zip_code, '')  FROM @tbl_order_info

DECLARE @ship_addr varchar(1000)
SET @ship_addr = @ship_customer_name + '{{LINE_BREAK}}'

IF LEN(@ship_address1) > 0
	SET @ship_addr = @ship_addr + @ship_address1 + '{{LINE_BREAK}}'

IF LEN(@ship_address2) > 0
	SET @ship_addr = @ship_addr  + @ship_address2 +  '{{LINE_BREAK}}'

IF LEN(@ship_address3) > 0
	SET @ship_addr = @ship_addr  + @ship_address3 +  '{{LINE_BREAK}}'

IF LEN(@ship_address4) > 0
	SET @ship_addr = @ship_addr  + @ship_address4 +  '{{LINE_BREAK}}'

IF LEN(@ship_address5) > 0
	SET @ship_addr = @ship_addr  + @ship_address5 +  '{{LINE_BREAK}}'

--print '@ship_city: ' + @ship_city
--print '@ship_state: ' + @ship_state
--print '@ship_zip_code: ' + @ship_zip_code

SET @ship_addr = @ship_addr + @ship_city + ', ' +	@ship_state + ' ' + @ship_zip_code

	SET @location = '{{LINE_BREAK}}' + @ship_addr
	DECLARE @tmp_location varchar(1000)
	SET @tmp_location = '<b>Location:</b> ' + REPLACE(@location, '{{LINE_BREAK}}', '<BR>')
	UPDATETEXT #html.t_field @ptr_location_token_html NULL 0 @tmp_location

	SET @tmp_location = 'Location: ' + REPLACE(@location, '{{LINE_BREAK}}', @crlf)
	UPDATETEXT #text.t_field @ptr_location_token_text NULL 0 @tmp_location


--SELECT * FROM @tbl_order_info
--RETURN

-- declare cursor 
DECLARE ord CURSOR FOR 
   SELECT 	date_returned,
		description,
		product_id,
		order_id
	FROM @tbl_order_info

OPEN ord

FETCH ord INTO @date_returned, @description, @product_id, @order_id


WHILE @@FETCH_STATUS = 0
BEGIN
   

	Set @order_detail = "<tr>" +
		"<td align=""left"">" + Cast(@order_id as varChar(20)) + "</td>" +
		"<td><em>" + @description + "</em></td>" +
		"<td style=""text-align:right"">" + convert(varchar(20), @date_returned, 101) + "</td>" +
		"</tr>"
		
	UPDATETEXT #html.t_field @Dptrval NULL 0 @order_detail

	Set @order_detail = 
		"Order: " + Cast( @order_id as varChar(20)) + @crlf +
		"Item: " + @description + @crlf +
		"Date Received: " + convert(varchar(20), @date_returned, 101) + @crlf2

	UPDATETEXT #text.t_field @Dptrvaltext NULL 0 @order_detail
	
   -- We do not address COR or Auto Replenishment at this time. DOn't even mention them.
	set @thisDate = getdate()
	
	UPDATE OrderItem 
		Set date_return_ack_sent = @thisDate
	where order_id = @order_id 
		and product_id = @product_id
		and date_returned is not null
		and date_return_ack_sent is null
		and date_returned > dateadd(dd, @date_retrieval_window, @thisDate)
		
	INSERT OrderAudit (
		Order_id,
		line_id,
		sequence_id,
		table_name,
		column_name,
		before_value,
		after_value,
		audit_reference,
		modified_by,
		modified_from,
		date_modified
	) SELECT DISTINCT
		order_id,
		line_id,
		sequence_id,
		'OrderItem',
		'date_return_ack_sent',
		NULL,
		@thisDate,
		'sp_retail_email_boxes_received (' + @email + ')',
		left(system_user, 10),
		NULL,
		@thisDate
	From OrderItem
	where order_id = @order_id 
		and product_id = @product_id
		and date_returned is not null
		and date_return_ack_sent = @thisDate
		and date_returned > dateadd(dd, @date_retrieval_window, @thisDate)
		
	FETCH ord INTO @date_returned, @description, @product_id, @order_id
END

CLOSE ord
DEALLOCATE ord

set @order_detail = "</table></td></tr></table>"
UPDATETEXT #html.t_field @Dptrval NULL 0 @order_detail


----  Replace the text in the e-mail

-- Replace {ORDER_DETAIL} with the order detail info:
select @pos = PATINDEX('%{ORDER_DETAIL}%', t_field) -1 from #html where t_desc = 'template'
WHILE @pos > 0 BEGIN
	UPDATETEXT #html.t_field @Tptrval @pos 14 #html.t_field @Dptrval
	select @pos = PATINDEX('%{ORDER_DETAIL}%', t_field) -1 from #html where t_desc = 'template'
END
select @pos = PATINDEX('%{ORDER_DETAIL}%', t_field) -1 from #text where t_desc = 'template'
WHILE @pos > 0 BEGIN
	UPDATETEXT #text.t_field @TptrvalText @pos 14 #text.t_field @Dptrvaltext
	select @pos = PATINDEX('%{ORDER_DETAIL}%', t_field) -1 from #text where t_desc = 'template'
END


-- Replace {LOCATION_INFO} with the order detail info:
select @pos = PATINDEX('%{LOCATION_INFO}%', t_field) -1 from #html where t_desc = 'template'
WHILE @pos > 0 BEGIN
	UPDATETEXT #html.t_field @Tptrval @pos 15 #html.t_field @ptr_location_token_html
	select @pos = PATINDEX('%{LOCATION_INFO}%', t_field) -1 from #html where t_desc = 'template'
END
select @pos = PATINDEX('%{LOCATION_INFO}%', t_field) -1 from #text where t_desc = 'template'
WHILE @pos > 0 BEGIN
	UPDATETEXT #text.t_field @TptrvalText @pos 15 #text.t_field @ptr_location_token_text
	select @pos = PATINDEX('%{LOCATION_INFO}%', t_field) -1 from #text where t_desc = 'template'
END


If @@servername = 'NTSQL1' BEGIN
	-- Replace /dev. with /www.:
	select @pos = PATINDEX('%/dev.%', t_field) -1 from #html where t_desc = 'template'
	WHILE @pos > 0 BEGIN
		UPDATETEXT #html.t_field @Tptrval @pos 5 '/www.'
		select @pos = PATINDEX('%/dev.%', t_field) -1 from #html where t_desc = 'template'
	END
	select @pos = PATINDEX('%/dev.%', t_field) -1 from #text where t_desc = 'template'
	WHILE @pos > 0 BEGIN
		UPDATETEXT #text.t_field @Tptrvaltext @pos 5 '/www.'
		select @pos = PATINDEX('%/dev.%', t_field) -1 from #text where t_desc = 'template'
	END
END

If @@servername = 'NTSQL1TEST' BEGIN
	-- Replace /dev. with /test.:
	select @pos = PATINDEX('%/dev.%', t_field) -1 from #html where t_desc = 'template'
	WHILE @pos > 0 BEGIN
		UPDATETEXT #html.t_field @Tptrval @pos 5 '/test.'
		select @pos = PATINDEX('%/dev.%', t_field) -1 from #html where t_desc = 'template'
	END
	select @pos = PATINDEX('%/dev.%', t_field) -1 from #text where t_desc = 'template'
	WHILE @pos > 0 BEGIN
		UPDATETEXT #text.t_field @Tptrvaltext @pos 5 '/test.'
		select @pos = PATINDEX('%/dev.%', t_field) -1 from #text where t_desc = 'template'
	END
END


if @debug > 0
begin
-- testing only
select 'FROM' = 'donotreply@usecology.com', 
		'TO' = @email,
		@message_id as MessageID, -- message id
		'N', 
		'E',
		'Retail', 
		'US Ecology has received your shipment: ' + @ship_customer_name + ', ' + @ship_city + ', ' + @ship_state as Subject,  -- subject, 
		t.t_field, 
		h.t_field, 
		'EQWEB',
		GetDate()
	from #html h inner join #text t on 1=1 where t.t_desc = h.t_desc and h.t_desc = 'template'	
end

if @debug = 0
begin
--- Prepare the insert into the message table

	EXEC @message_id = sp_sequence_next 'message.message_id'

	INSERT INTO Message (message_id, status, message_type, message_source, subject, message, html, added_by, date_added) 
		select 
			@message_id, 
			'N', 
			'E',
			'Retail', 
			'US Ecology has received your shipment: ' + @ship_customer_name + ', ' + @ship_city + ', ' + @ship_state, 
			t.t_field, 
			h.t_field, 
			'EQWEB',
			GetDate()
		from #html h 
		inner join #text t on 1=1 
		where t.t_desc = h.t_desc and h.t_desc = 'template'	

	INSERT INTO MessageAddress(message_id, address_type, email) Values
				   (@message_id, 'TO', @email)

	INSERT INTO MessageAddress(message_id, address_type, name, company, email) Values
				   (@message_id, 'FROM', 'USecology.com', 'US Ecology', 'donotreply@usecology.com')

end

 
		   

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_retail_email_boxes_received] TO [EQAI]
    AS [dbo];

