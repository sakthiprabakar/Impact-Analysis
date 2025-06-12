USE [PLT_AI]
GO

DROP PROCEDURE IF EXISTS [dbo].[sp_retail_email_order_stripe_error]
GO

/****** Object:  StoredProcedure [dbo].[sp_retail_email_order_stripe_error]    Script Date: 8/3/2023 7:34:22 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER OFF
GO

CREATE PROCEDURE [dbo].[sp_retail_email_order_stripe_error] (
	@order_id	int,
	@stripe_message varchar(max))
AS
/* **************************************************************
Loads to:	Plt_AI

09/03/2022 AGC	DevOps 48918 Created--copied from sp_retail_email_order_confirm
08/02/2023 Dipankar DevOps 50330 - Statements referring deprecated servers commented out
3/18/2024 Prakash DevOps 79132 - Replaced US Ecology, www.usecology.com with Republic Services and www.republicservices.com

sp_retail_email_order_stripe_error 1066

update messageaddress set email = 'jonathan.broome@usecology.com' where message_id = 174 and address_type = 'TO'
select top 5 * from message order by message_id desc
select top 5 * from messageaddress order by message_id desc
*************************************************************** */

IF (select send_email_flag from orderheader where order_id = @order_id) = 'N' RETURN

DECLARE @Order_total	money,
	@last_4_cc		varchar(20),
	@item_desc		varchar(50),
	@price			money,
	@subtotal		money,
	@qty			int,
	@tot			money,
	@cor_flag		char(1),
	@rep_flag		char(1),
	@order_detail	varchar(8000),
	@pos			int,
	@email_html		varchar(8000),
	@email_text		varchar(8000),
	@crlf			varchar(4),
	@crlf2			varchar(8),
	@message_id		int,
	@cnt			int,
	@contact_name	varchar(200),
	@ship_name		varchar(200),
	@ship_company	varchar(200),
	@email_addr		varchar(200),
	@ship_phone		varchar(200),
	@ship_addr		varchar(1000),
	@bill_name		varchar(1000),
	@purchase_order	varchar(100),
	@release_code	varchar(100),
	@Tptrval 		binary(16),
	@Dptrval 		binary(16),
	@TptrvalText	binary(16),
	@DptrvalText	binary(16),
	@vOrderID		varchar(20)
	
	
set @crlf = char(13) + char(10)
set @crlf2 = @crlf + @crlf
Set @email_html = '<html><body style="font-family:verdana,sans-serif;font-size:14px"><table border="0" cellspacing="0" cellpadding="0" style="border: solid 1px #000;width:716px;font-size:14px"><tr><td bgcolor="#1A9B1A" width="100%"><p style="background:url(http://dev.usecology.com/graphics/white-dot.gif) repeat-x;margin-top:100px;width:100%">&nbsp;</p></td></tr><tr><td style="padding:1em" colspan="2"><p>Your Pack Back order has been received.  Thank you for your order.</p><p>The following error occurred while processing order reference number <b>{ORDER_ID}</b>. <b>{STRIPE_MESSAGE}</b> <b>{CREDIT_CARD}</b></p>{ORDER_DETAIL}<p style="color:#396;padding-bottom:1em;border-bottom:dotted 2px #1A9B1A">Thank you for using the Republic Services Sustainable Solutions Pack Back Recycling Program!</p><p>To view the most up to date Pack Back information, please visit <a href="http://www.republicservices.com/">www.republicservices.com</a></p><p>Republic Services''s Pack Back program is a web based universal waste recycling program for environmentally sound and compliant solutions, encompassing federal and state specific regulations for:</p><ul style="width:100%;float:left;list-style:none"><li style="float:left;width:32.5%;">&#149; Handling</li><li style="float:left;width:32.5%;">&#149; Storage</li><li style="float:left;width:32.5%;">&#149; Labeling</li><li style="float:left;width:32.5%;">&#149; Shipping</li><li style="float:left;width:32.5%;">&#149; Tracking</li><li style="float:left;width:32.5%;">&#149; Documenting</li><li style="float:left;width:32.5%;">&#149; Training</li></ul><p>To speak to someone regarding the Pack Back program, please call us at <span style="white-space:nowrap">800-592-5489.</span></p></td></tr></table></body></html>'
Set @email_text = 'Republic Services - Sustainable Solutions' + @crlf2 + 'Your Pack Back order has been received.  Thank you for your order.' + @crlf2 + 'The following error occurred while processing order reference number {ORDER_ID}.' + @crlf2 + '{STRIPE_MESSAGE}' + @crlf2 + '{CREDIT_CARD}' + @crlf2 + '{ORDER_DETAIL}' + @crlf2 + 'Thank you for using the RepublicServices Sustainable Solutions Pack Back Recycling Program!' + @crlf2 + 'To view the most up to date Pack Back information, please visit www.republicservices.com' + @crlf2 + 'Republic Services''s Pack Back program is a web based universal waste recycling program for environmentally sound and compliant solutions, encompassing federal and state specific regulations for Handling, Storage, Labeling, Shipping, Tracking, Documenting and Training' + @crlf2 + 'To speak to someone regarding the Pack Back program, please call us at 800-592-5489.'

Set @order_detail = "<p style=""margin-bottom:0""><b>Your Order #{ORDER_ID}</b></p>" + 
	"<table border=""0"" cellspacing=""0"" cellpadding=""6"" style=""width:100%;border: solid 1px #000"">" +
	"<tr><td>" +
	"<table cellspacing=""0"" cellpadding=""3"" style=""width:100%;font-size:14px"">" +
	"<thead><tr>" +
	"<th style=""border-bottom:solid 1px #1D9A1A;text-align:left;width:100%"" colspan=""2"">Item</th>" + 
	"<th style=""border-bottom:solid 1px #1D9A1A;text-align:left;width:100%;text-align:center"">Quantity</th>" + 
	"<th style=""border-bottom:solid 1px #1D9A1A;text-align:right"">Price</th>" + 
	"<th style=""border-bottom:solid 1px #1D9A1A;text-align:right"">Ext<br/>Price</th>" + 
	"</tr></thead>"

create table #html (t_desc varchar(40), t_field text)
create table #text (t_desc varchar(40), t_field text)
insert #html (t_desc, t_field) values ('template', @email_html)
insert #html (t_desc, t_field) values ('detail', @order_detail)
insert #text (t_desc, t_field) values ('template', @email_text)
insert #text (t_desc, t_field) values ('detail', '')

SELECT @Tptrval = TEXTPTR(t_field) FROM #html where t_desc = 'template'
SELECT @Dptrval = TEXTPTR(t_field) FROM #html where t_desc = 'detail'
SELECT @TptrvalText = TEXTPTR(t_field) FROM #text where t_desc = 'template'
SELECT @DptrvalText = TEXTPTR(t_field) FROM #text where t_desc = 'detail'

set @vOrderID = convert(varchar(20), @order_id)

-- declare cursor 
DECLARE ord CURSOR FOR SELECT p.short_description, od.quantity, od.price, (od.quantity * od.price) as subtotal, od.cor_flag, od.replenishment_flag 
	from Product p, orderdetail od
	Where od.product_id = p.product_id
	and od.company_id = p.company_id
	and od.profit_ctr_id = p.profit_ctr_id
	and od.order_id = @order_id
	order by od.line_id, od.product_id;

OPEN ord

FETCH ord INTO @item_desc, @qty, @price, @subtotal, @cor_flag, @rep_flag
SET @cnt = 0
SET @tot = 0

WHILE @@FETCH_STATUS = 0
BEGIN
	SET @cnt = @cnt + 1
	SET @tot = @tot + @subtotal

	Set @order_detail = "<tr>" +
		"<td align=""right"">" + Cast(@cnt as varChar(20)) + ".</td>" +
		"<td><em>" + @item_desc + "</em></td>" +
		"<td style=""text-align:center"">" + Cast(@qty as varchar(20)) + "</td>" +
		"<td style=""text-align:right"">$" + Cast(@price as varchar(20)) + "</td>" +
		"<td style=""text-align:right"">$" + Cast(@subtotal as varchar(20)) + "</td>" +
		"</tr>"
	UPDATETEXT #html.t_field @Dptrval NULL 0 @order_detail

	Set @order_detail = "Item " + Cast(@cnt as varChar(20)) + ': ' + @item_desc + @crlf +
		"Quantity: " + Cast(@qty as varchar(20)) + @crlf +
		"Price: $" + Cast(@price as varchar(20)) + @crlf +
		"Ext Price: $" + Cast(@subtotal as varchar(20)) + @crlf
	UPDATETEXT #text.t_field @Dptrvaltext NULL 0 @order_detail
	
	if @cor_flag = 'T' BEGIN
		set @order_detail = "<tr>" +
			"<td>&nbsp;</td>" +
			"<td style=""padding:0 0 0 2.5em;text-indent:-2.49em"">&nbsp; <b>Certificate Of Recycling</b> requested when this item is recycled</td>" +
			"<td>&nbsp;</td><td>&nbsp;</td></tr>"
		UPDATETEXT #html.t_field @Dptrval NULL 0 @order_detail
		
		set @order_detail = "* Certificate Of Recycling requested when this item is recycled" + @crlf
		UPDATETEXT #text.t_field @Dptrvaltext NULL 0 @order_detail
	END
			

	if @rep_flag = 'T' BEGIN
		set @order_detail = "<tr>" +
			"<td>&nbsp;</td>" +
			"<td style=""padding:0 0 0 2.5em;text-indent:-2.49em"">&nbsp; <b>Automatic Replenishment</b> requested when this item is returned for recycling</td>" +
			"<td>&nbsp;</td><td>&nbsp;</td></tr>"
		UPDATETEXT #html.t_field @Dptrval NULL 0 @order_detail
		
		set @order_detail = "* Automatic Replenishment requested when this item is returned for recycling" + @crlf
		UPDATETEXT #text.t_field @Dptrvaltext NULL 0 @order_detail
	END

	set @order_detail = @crlf
	UPDATETEXT #text.t_field @Dptrvaltext NULL 0 @order_detail
	
	FETCH ord INTO @item_desc, @qty, @price, @subtotal, @cor_flag, @rep_flag
END

CLOSE ord
DEALLOCATE ord

Set @order_detail = "<tfoot><tr><td colspan=""4"" style=""border-top:solid 1px #1D9A1A;font-weight:bold;vertical-align:middle;text-align:right;font-size:15px"">Order Total:</td>" +
	"<td style=""border-top:solid 1px #1D9A1A;font-weight:bold;vertical-align:middle;text-align:right;font-size:15px"">$" + cast(@tot as varchar(20)) + "</td>" +
	"</tr></tfoot></table>"
UPDATETEXT #html.t_field @Dptrval NULL 0 @order_detail

Set @order_detail = "Order Total: $" + cast(@tot as varchar(20)) + @crlf2
UPDATETEXT #text.t_field @Dptrvaltext NULL 0 @order_detail

Select @contact_name = isnull(contact_first_name + ' ', '') + isnull(contact_last_name, ''), @last_4_cc = credit_card_last_digits, @order_total = total_amt_order, @ship_name = ship_attention_name, @ship_company = ship_cust_name, @email_addr = email, @ship_phone = dbo.fn_FormatPhoneNumber(ship_phone), @ship_addr = isnull(ship_addr1 + "</td></tr><tr><td>", '') + isnull(ship_addr2 + "</td></tr><tr><td>", '') + isnull(ship_city + ', ', '') + isnull(ship_state + ' ', '') + isnull(ship_zip_code, '') from orderHeader where order_id = @order_id
-- select @contact_name = name from contact where contact_id = (select contact_id from orderheader where order_id = @order_id)
-- if @contact_name is null set @contact_name = @email_addr

select @bill_name = CASE WHEN order_type = 'A' THEN 'Bill To ' + rtrim(c.cust_name) + ' (' + convert(varchar(10), c.customer_id) + ')'
	ELSE rtrim(upper(substring(credit_card_type, 1, 1)) + lower(substring(credit_card_type, 2, 20))) + ' ending in ' + rtrim(credit_card_last_digits) END,
	@purchase_order = purchase_order,
	@release_code = release_code
	FROM orderHeader 
	LEFT OUTER JOIN Customer c on orderheader.customer_id = c.customer_id
	WHERE order_id = @order_id

Set @order_detail = "<table cellspacing=""0"" cellpadding=""0"" style=""margin-top:1em;width:100%;font-size:14px""><tr>" +
"<td width=""33%"" valign=""top"" style=""padding:0 1em""><h4 style=""margin-bottom:0;font-size:14px"">Your Information:</h4>" +
"<table cellspacing=""0"" cellpadding=""0"">" +
	"<tr><td>" + @contact_name + "</td</tr>" +
	"<tr><td>" + replace(@email_addr, '@', '@<wbr/>') + "</td></tr>" +
	"<tr><td>" + @ship_phone + "</td></tr>" +
	"</table></td>"
UPDATETEXT #html.t_field @Dptrval NULL 0 @order_detail

Set @order_detail = "Your Information:" + @crlf +
	@contact_name + @crlf +
	@email_addr + @crlf +
	@ship_phone + @crlf2
UPDATETEXT #text.t_field @Dptrvaltext NULL 0 @order_detail

set @order_detail = "<td width=""33%"" valign=""top"" style=""padding:0 1em"">" +
   "<h4 style=""margin-bottom:0;font-size:14px"">Billed To:</h4>" +
   "<table cellspacing=""0"" cellpadding=""0"">" +
	"<tr><td>" + @bill_name + "</td></tr>" + 
	ISNULL("<tr><td>PO: " + @purchase_order + "</td></tr>", "") +
	ISNULL("<tr><td>Release: " + @release_code + "</td></tr>", "") +
	"</table></td>"
UPDATETEXT #html.t_field @Dptrval NULL 0 @order_detail

set @order_detail = "Billed To:" + @crlf +
	@bill_name + @crlf + 
	ISNULL("PO: " + @purchase_order + @crlf, "") +
	ISNULL("Release: " + @release_code + @crlf, "") + 
	@crlf
UPDATETEXT #text.t_field @Dptrvaltext NULL 0 @order_detail

set @order_detail = 
   "<td width=""33%"" valign=""top"" style=""padding:0 1em"">" +
   "<h4 style=""margin-bottom:0;font-size:14px"">Shipped To:</h4>" +
   "<table cellspacing=""0"" cellpadding=""0"">" +
	"<tr><td>" + @ship_company + "</td></tr>" +
	"<tr><td>Attn: " + @ship_name + "</td></tr>" +
	"<tr><td>" + @ship_addr + "</td></tr>" +
	"</table></td>"
UPDATETEXT #html.t_field @Dptrval NULL 0 @order_detail

set @order_detail = "Shipped To:" + @crlf +
	@ship_company + @crlf +
	"Attn: " + @ship_name + @crlf +
	replace(@ship_addr, "</td></tr><tr><td>", ' ') + @crlf
UPDATETEXT #text.t_field @DptrvalText NULL 0 @order_detail

set @order_detail = "</tr></table></td></tr></table>"
UPDATETEXT #html.t_field @Dptrval NULL 0 @order_detail

----  Replace the text in the e-mail

Set @last_4_cc = IsNull(@last_4_cc,'')
If @last_4_cc = '' 
   SET @order_detail = 'Your Republic Services Account will be charged a total of $' + Convert(VarChar(40),@order_total,1) + ' when your order is shipped.'
Else
   SET @order_detail = 'Your Credit Card ending in ' + @last_4_cc + ' will be charged a total of $' + Convert(VarChar(40),@order_total,1) + ' when your order is shipped.'

-- Replace {CREDIT_CARD} with specific info:
select @pos = PATINDEX('%{CREDIT_CARD}%', t_field) -1 from #html where t_desc = 'template'
WHILE @pos > 0 BEGIN
	UPDATETEXT #html.t_field @Tptrval @pos 13 @order_detail
	select @pos = PATINDEX('%{CREDIT_CARD}%', t_field) -1 from #html where t_desc = 'template'
END
select @pos = PATINDEX('%{CREDIT_CARD}%', t_field) -1 from #text where t_desc = 'template'
WHILE @pos > 0 BEGIN
	UPDATETEXT #text.t_field @Tptrvaltext @pos 13 @order_detail
	select @pos = PATINDEX('%{CREDIT_CARD}%', t_field) -1 from #text where t_desc = 'template'
END

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

-- Replace {ORDER_ID} with specific info:
select @pos = PATINDEX('%{ORDER_ID}%', t_field) -1 from #html where t_desc = 'template'
WHILE @pos > 0 BEGIN
	UPDATETEXT #html.t_field @Tptrval @pos 10 @vorderid
	select @pos = PATINDEX('%{ORDER_ID}%', t_field) -1 from #html where t_desc = 'template'
END
select @pos = PATINDEX('%{ORDER_ID}%', t_field) -1 from #text where t_desc = 'template'
WHILE @pos > 0 BEGIN
	UPDATETEXT #text.t_field @Tptrvaltext @pos 10 @vorderid
	select @pos = PATINDEX('%{ORDER_ID}%', t_field) -1 from #text where t_desc = 'template'
END

-- Replace {STRIPE_MESSAGE} with specific info:
select @pos = PATINDEX('%{STRIPE_MESSAGE}%', t_field) -1 from #html where t_desc = 'template'
WHILE @pos > 0 BEGIN
	UPDATETEXT #html.t_field @Tptrval @pos 16 @stripe_message
	select @pos = PATINDEX('%{STRIPE_MESSAGE}%', t_field) -1 from #html where t_desc = 'template'
END
select @pos = PATINDEX('%{STRIPE_MESSAGE}%', t_field) -1 from #text where t_desc = 'template'
WHILE @pos > 0 BEGIN
	UPDATETEXT #text.t_field @Tptrvaltext @pos 16 @stripe_message
	select @pos = PATINDEX('%{STRIPE_MESSAGE}%', t_field) -1 from #text where t_desc = 'template'
END

/* -- 50330 - Commented
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
*/
 
--- Prepare the insert into the message table

EXEC @message_id = sp_sequence_next 'message.message_id'

Insert Into Message (message_id, status, message_type, message_source, subject, message, html, added_by, date_added) 
	select @message_id, 'N', 'E','Retail', 'Your Republic Services Online Order Confirmation', t.t_field, h.t_field, 'EQWEB',GetDate()
	from #html h inner join #text t on 1=1 where t.t_desc = h.t_desc and h.t_desc = 'template'	

Insert Into MessageAddress(message_id, address_type, name, company, email) Values
	(@message_id, 'TO', @contact_name, @ship_company, @email_addr)

Insert Into MessageAddress(message_id, address_type, name, company, email) Values
	 (@message_id, 'FROM', 'republicservices.com', 'Republic Services', 'customerservice.eq@usecology.com')

Insert Into MessageAttachment(message_id, attachment_id, status, attachment_type, source, image_id, filename) 
	select @message_id, 1, 'N', 'image', 'EQDocLibrary', id, file_name 
	from eqdoclibrary where id=2

	
-- Update the OrderDetail now that the receipt is sent.
Update OrderDetail set date_emailed_receipt = getdate() where order_id = @order_id
GO


GRANT EXECUTE
    ON OBJECT::[dbo].[sp_retail_email_order_stripe_error] TO [EQAI]