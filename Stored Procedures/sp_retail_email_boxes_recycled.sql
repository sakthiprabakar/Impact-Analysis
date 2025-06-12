CREATE PROCEDURE sp_retail_email_boxes_recycled (
	@debug int = 0, -- 0 for false, 1 for true
	@email	varchar(60),
	@order_id_list varchar(8000), -- this is a list of order ids that are associated to _ONE_ shipping address
	@processing_mode varchar(20) = 'automatic' /*
										'automatic' or 'manual'.  When set to "Manual" the procedure will:
											* Generate a "preview" (status of P) email and NOT send it out until its status is set to the appropriate one. 
											* Will return ALL of the order item information - not just the ones that have been processed in the batch	
									*/
) AS
/***************************************************************
Loads to:	Plt_AI

Sends an email to the input email address if there were any products recycled that haven't been emailed about yet.

05/21/2008 JPB	Created
09/22/2008 JPB	Modified to include plain text version as well as html
03/13/2009 JPB	Revised email formatting:
					Moved "Order" column to left in html, top line in text.
					Removed # from Item in text.

03/16/2009 RJG  Modified to accept a list of order_ids (passed in as part of the same location)
				Modified to add location information
03/18/2009 RJG  Modified add disclaimer text to email header
				Modified to add COUNT(product_id) as total_boxes to the email				
04/02/2009 JPB  Changed donotreply address to customerservice.eq
04/17/2009 RJG  Added date received, tracking number columns
				Modified order number formatting (xxxx-y-z) 
					
06/01/2009 RJG	Included return_weight in the COR, added different processing mode for one-off COR generations

06/03/2009 RJG	Removed weight from the Text only version of the email send out

11/09/2017	JPB	It's been a while since EQ was acquired, probably time to put the new name on this email.

	************** TEST CASES *****************

		Test 1) Processing with weights entered
				Expectation: 
					* Weight column SHOULD appear
		
		Test 2) Processing with no weights entered
				Expectation:
					* Weight column should NOT appear
		
		Test 3) Manual processing
				Expectation:
					* Result should include previously processed AND not-yet-processed order items (both HTML and Text emails)
					* Message status should be 'P'
					* No email will be sent
					
		Test 4) Automatic processing
				Expectation: 
					* Result should include only UNprocessed items
					* Message status should be 'N'


	SELECT * FROM OrderHeader WHERE order_id = 1191
	SELECT * FROM OrderItem WHERE order_id = 1191
	
	-- UPDATE OrderHeader SET email = 'jonathan.broome@usecology.com' WHERE order_id = 1191
	-- reset all items for testing
	UPDATE OrderItem SET date_cor_sent = NULL WHERE order_id = 1191

	-- only reset a few items
	UPDATE OrderItem SET date_cor_sent = getdate() WHERE order_id = 1191 
	UPDATE OrderItem SET date_cor_sent = NULL WHERE order_id = 1191 AND sequence_id IN (1,3,5,7)

	-- reset all weights
	UPDATE OrderItem SET return_weight = NULL WHERE order_id = 1191

	-- ALL order items should be returned
	exec sp_retail_email_boxes_recycled 1, 'jonathan.broome@usecology.com', 1191, 'manual'
	exec sp_retail_email_boxes_recycled 0, 'jonathan.broome@usecology.com', 1191, 'automatic'
	
	SELECT TOP 10 * FROM message order by date_added desc
	SELECT * FROM messageaddress WHERE message_id = 2873783
	-- update message set status = 'V' where message_id = 2873783
**********************/	

CREATE TABLE #order_list (ID int)
Insert #order_list 
	select convert(int, row) 
	from dbo.fn_SplitXsvText(',', 0, @order_id_list) 
	where isnull(row, '') <> ''

-- Abort if they're already processed, or none to process
if not exists (
	select
	   oi.order_id
	from OrderHeader oh
	inner join OrderItem oi
		on oi.order_id = oh.order_id
	inner join OrderDetail od 
		on oi.order_id = od.order_id
		and oi.line_id = od.line_id
	inner join product p 
		on od.product_id = p.product_id 
		and od.company_id = p.company_id 
		and od.profit_ctr_id = p.profit_ctr_id
	where
		oi.outbound_receipt_id is not null
		and isnull(oh.email, '') = @email
		and od.cor_flag = 'T'  
		and (oi.date_cor_sent is null or @processing_mode = 'manual')

) return

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
	@quantity_returned	varchar(50),
	@description		varchar(60),
	@cor_flag			char(1),
	@replenishment_flag	char(1),
	@order_id			int,
	@line_id			int,
	@sequence_id		int,
	@product_id			int,
	@thisDate			datetime,

	@total_boxes		int,
	@ship_customer_name	varchar(100),
	@ship_address1		varchar(100),
	@ship_address2		varchar(100),
	@ship_address3		varchar(100),
	@ship_address4		varchar(100),
	@ship_address5		varchar(100),
	@ship_city			varchar(100),
	@ship_state			varchar(50),
	@ship_zip_code		varchar(50),

	@location		varchar(8000),

	@order_line int,
	@order_item_number int,
	@received_date datetime,
	@return_tracking_number varchar(50),
	
	@return_weight decimal(10,3),
	@items_with_return_weight int
	
set @crlf = char(13) + char(10)
set @crlf2 = @crlf + @crlf








DECLARE @tbl_order_info table (
	quantity_returned varchar(50),
	total_boxes int,
	product_id int,
	description varchar(100),
	order_id int,
	order_line int,
	order_item_number int,
	return_tracking_number varchar(50),
	received_date datetime,
	ship_cust_name varchar(100),
	ship_addr1 varchar(100),
	ship_addr2 varchar(100),
	ship_addr3 varchar(100),
	ship_addr4 varchar(100),
	ship_addr5 varchar(100),
	ship_city varchar(50) ,
	ship_state  varchar(50),
	ship_zip_code  varchar(50),
	return_weight decimal(10,3)
)

/*
	This order info table contains the shipping info, order info, and order detail item info
*/
INSERT INTO @tbl_order_info
(
	quantity_returned,
	total_boxes,
	product_id,
	description,
	order_id,
	order_line,
	order_item_number,
	return_tracking_number,
	received_date,
	ship_cust_name,
	ship_addr1,
	ship_addr2,
	ship_addr3,
	ship_addr4,
	ship_addr5,
	ship_city,
	ship_state,
	ship_zip_code,
	return_weight
)
select
		sum(oi.quantity_returned) as quantity_returned,
		count(p.product_id) total_boxes,
		p.product_id,
		p.description,
		oi.order_id,
		oi.line_id,
		oi.sequence_id,
		oi.tracking_barcode_returned,
		oi.date_returned,
		oh.ship_cust_name,
		oh.ship_addr1,
		oh.ship_addr2,
		oh.ship_addr3,
		oh.ship_addr4,
		oh.ship_addr5,
		oh.ship_city,
		oh.ship_state,
		oh.ship_zip_code,
		oi.return_weight
	from OrderHeader oh
	inner join OrderItem oi
		on oi.order_id = oh.order_id
	inner join OrderDetail od 
		on oi.order_id = od.order_id
		and oi.line_id = od.line_id
	inner join product p 
		on od.product_id = p.product_id 
		and od.company_id = p.company_id 
		and od.profit_ctr_id = p.profit_ctr_id
	INNER JOIN #order_list order_list ON oi.order_id = order_list.id
	where
		oi.outbound_receipt_id is not null
		and (oi.date_cor_sent is null or  @processing_mode = 'manual')
		and isnull(oh.email, '') = @email
		and od.cor_flag = 'T'  
		and exists (
			select s.image_id 
				from Plt_Image..Scan s 
				inner join Plt_Image..ScanDocumentType sdt 
					on s.type_id = sdt.type_id
					and sdt.document_Type = 'COR' 
				inner join Receipt r
					on s.receipt_id = r.receipt_id
					and s.company_id = r.company_id
					and s.profit_ctr_id = r.profit_ctr_id
					and r.trans_mode = 'O'
				where
					s.receipt_id = oi.outbound_receipt_id
					and s.company_id = od.company_id
					and s.profit_ctr_id = od.profit_ctr_id
					and s.document_source = 'receipt'
					and s.status = 'A'
		)
	group by 
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
		oh.ship_zip_code,
		oi.line_id,
		oi.sequence_id,
		oi.tracking_barcode_returned,
		oi.date_returned,
		oi.return_weight

update @tbl_order_info set quantity_returned = 'N/A' where quantity_returned IS null

SELECT @items_with_return_weight = COUNT(*) FROM @tbl_order_info WHERE return_weight IS NOT NULL

Set @email_html = '<html>
<body style="font-family: verdana,sans-serif; font-size: 10px">
    <table border="0" cellspacing="0" cellpadding="0" style="border: solid 1px #000;
        width: 716px; font-size: 10px">
        <tr>
            <td bgcolor="#1A9B1A" width="100%">
                <p style="background: url(http://www.usecology.com/graphics/white-dot.gif) repeat-x;
                    margin-top: 100px; width: 100%">
                    &nbsp;</p>
            </td>
        </tr>
        <tr>
            <td style="padding: 1em" colspan="2">
                <p>
                    This notice serves as your <strong>Certificate of Recycling</strong> for the universal
                    waste recently received by US Ecology through our Pack Back program. To replace your order
                    where a new container will be shipped to you, please visit <a href="http://www.usecology.com/SustainableSolutions">http://www.usecology.com/SustainableSolutions</a>.</p>
                <p>{LOCATION_INFO}</p>
                {ORDER_DETAIL}<p>
                    US Ecology certifies that the received waste listed above has been properly recycled in
                    accordance with all local, state and federal regulations. The quantity represents
                    the total number of units recorded by the customer.</p>
                <p style="color: #396; padding-bottom: 1em; border-bottom: dotted 2px #1A9B1A">
                    Thank you for using the US Ecology Sustainable Solutions Pack Back Recycling Program!</p>
                <p>
                    To view the most up to date Pack Back information, please visit <a href="http://www.usecology.com/">www.usecology.com</a></p>
                <p>
                    US Ecology''s Pack Back program is a web based universal waste recycling program for environmentally
                    sound and compliant solutions, encompassing federal and state specific regulations
                    for:</p>
                <ul style="width: 100%; float: left; list-style: none">
                    <li style="float: left; width: 32.5%;">&#149; Handling</li>
                    <li style="float: left; width: 32.5%;">&#149; Storage</li>
                    <li style="float: left; width: 32.5%;">&#149; Labeling</li>
                    <li style="float: left; width: 32.5%;">&#149; Shipping</li>
                    <li style="float: left; width: 32.5%;">&#149; Tracking</li>
                    <li style="float: left; width: 32.5%;">&#149; Documenting</li>
                    <li style="float: left; width: 32.5%;">&#149; Training</li>
                </ul>
                <p style="clear: both">
                    To speak to someone regarding the Pack Back program, please call us at <span style="white-space: nowrap">800-592-5489.</span></p>
            </td>
        </tr>
    </table>
</body>
</html>'

Set @email_text = 'US Ecology - Sustainable Solutions' + @crlf2 + 'This notice serves as your Certificate of Recycling for the universal waste recently received by US Ecology through our Pack Back program.  To replace your order where a new container will be shipped to you, please visit http://www.usecology.com/SustainableSolutions' + @crlf2 + '{LOCATION_INFO} ' + @crlf2 +'{ORDER_DETAIL}US Ecology certifies that the received waste listed above has been properly recycled in accordance with all local, state and federal regulations.  The quantity represents the total number of units recorded by the customer.  ' + @crlf2 + 'Thank you for using the US Ecology Sustainable Solutions Pack Back Recycling Program!' + @crlf2 + 'To view the most up to date Pack Back information, please visit www.usecology.com' + @crlf2 + 'US Ecology''s Pack Back program is a web based universal waste recycling program for environmentally sound and compliant solutions, encompassing federal and state specific regulations for Handling, Storage, Labeling, Shipping, Tracking, Documenting and Training' + @crlf2 + 'To speak to someone regarding the Pack Back program, please call us at 800-592-5489.'

Set @order_detail = '<p style="margin-bottom:0"><b>Items Recycled:</b></p>
	<table border="0" cellspacing="0" cellpadding="6" style="width:100%;border: solid 1px #000">
		<tr><td>
			<table cellspacing="0" cellpadding="3" style="width:100%;font-size:10px">
				<thead><tr>
					<th style="border-bottom:solid 1px #1D9A1A;text-align:left">Order</th>
					<th style="border-bottom:solid 1px #1D9A1A;text-align:left">Description</th>
					<th style="border-bottom:solid 1px #1D9A1A;text-align:left">Date Received</th>
					<th style="border-bottom:solid 1px #1D9A1A;text-align:left">Tracking Number</th>'
										
IF @items_with_return_weight > 0 
BEGIN
	Set @order_detail = @order_detail + '<th style="border-bottom:solid 1px #1D9A1A;text-align:left">Verified Weight</th>'
END

Set @order_detail = @order_detail + '<th style="border-bottom:solid 1px #1D9A1A;text-align:left">Quantity</th>'
Set @order_detail = @order_detail + '</tr>'
Set @order_detail = @order_detail + '</thead>'



create table #html (t_desc varchar(40), t_field text)
create table #text (t_desc varchar(40), t_field text)
insert #html (t_desc, t_field) values ('template', @email_html)
insert #html (t_desc, t_field) values ('detail', @order_detail)
insert #html (t_desc, t_field) values ('location', '')

insert #text (t_desc, t_field) values ('template', @email_text)
insert #text (t_desc, t_field) values ('detail', 'Items Recycled:' + @crlf)
insert #text (t_desc, t_field) values ('location', '')

	
SELECT @Tptrval = TEXTPTR(t_field) FROM #html where t_desc = 'template'
SELECT @Dptrval = TEXTPTR(t_field) FROM #html where t_desc = 'detail'
SELECT @TptrvalText = TEXTPTR(t_field) FROM #text where t_desc = 'template'
SELECT @DptrvalText = TEXTPTR(t_field) FROM #text where t_desc = 'detail'

DECLARE @ptr_location_token_html binary(16)
DECLARE @ptr_location_token_text binary(16)
SELECT @ptr_location_token_html = TEXTPTR(t_field) FROM #html where t_desc = 'location'
SELECT @ptr_location_token_text = TEXTPTR(t_field) FROM #text where t_desc = 'location'


--SELECT * FROM @tbl_order_info
--RETURN

SELECT TOP 1 @ship_customer_name = ship_cust_name FROM @tbl_order_info
SELECT TOP 1 @ship_address1 = isnull(ship_addr1, '')  FROM @tbl_order_info
SELECT TOP 1 @ship_address2 = isnull(ship_addr2, '')  FROM @tbl_order_info
SELECT TOP 1 @ship_address3 =  isnull(ship_addr3, '') FROM @tbl_order_info
SELECT TOP 1 @ship_address4 =  isnull(ship_addr4, '') FROM @tbl_order_info
SELECT TOP 1 @ship_address5 =  isnull(ship_addr5, '') FROM @tbl_order_info
SELECT TOP 1 @ship_city =  isnull(ship_city, '')  FROM @tbl_order_info
SELECT TOP 1 @ship_state =  isnull(ship_state, '') FROM @tbl_order_info
SELECT TOP 1 @ship_zip_code =  isnull(ship_zip_code, '')  FROM @tbl_order_info

--SELECT TOP 1 ship_addr2, @ship_address2 FROM @tbl_order_info

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
	
-- declare cursor 
DECLARE cur_order_info CURSOR FOR 
	SELECT 	
	quantity_returned,
	product_id,
	description,
	order_id,
	total_boxes,
	order_line,
	order_item_number,
	return_tracking_number,
	received_date,
	return_weight
	FROM @tbl_order_info
	ORDER BY order_id DESC, order_line, order_item_number

	   
OPEN cur_order_info

FETCH cur_order_info INTO 
	@quantity_returned, 
	@product_id, 
	@description, 
	@order_id,
	@total_boxes,	
	@order_line,
	@order_item_number,
	@return_tracking_number,
	@received_date,
	@return_weight



WHILE @@FETCH_STATUS = 0
BEGIN

	declare @order_number_formatted varchar(50)
	set @order_number_formatted = Cast( @order_id as varChar(20)) + '-' + cast(@order_line as varchar(20)) + '-' + cast(@order_item_number as varchar(20))

	Set @order_detail = '<tr>' +
		'<td>' + @order_number_formatted + '</td>' +
		'<td><em>' + @description + '</em></td>' +
		'<td align="left">' + convert(varchar(10),@received_date,101) + '</td>' +
		'<td align="left">' + @return_tracking_number + '</td>'
	
	IF @items_with_return_weight > 0 
	BEGIN
		set @order_detail = @order_detail + '<td align="left">' + ISNULL(cast(@return_weight as varchar(20)),"") + '</td>'
	END

	set @order_detail = @order_detail + '<td align="left">' + Cast(@quantity_returned as varChar(20)) + '</td>'
	set @order_detail = @order_detail + '</tr>'
		
	UPDATETEXT #html.t_field @Dptrval NULL 0 @order_detail

	Set @order_detail = 
		"Order: " + @order_number_formatted + @crlf +
		"Item: " + @description + @crlf +
		"Date Received: " + convert(varchar(10),@received_date,101) + @crlf +
		"Tracking Number: " + @return_tracking_number + @crlf


	IF @return_weight IS NOT NULL
	BEGIN
		set @order_detail = @order_detail + "Verified Weight: " + ISNULL(cast(@return_weight as varchar(20)),"") + @crlf
	END
	
	set @order_detail = @order_detail + "Quantity: " + Cast( @quantity_returned as varChar(20)) + @crlf2

	UPDATETEXT #text.t_field @Dptrvaltext NULL 0 @order_detail
	
    set @thisDate = getdate()
   
	update OrderItem
		set date_cor_sent = getdate()
	from OrderHeader oh
		inner join OrderDetail od 
			on od.order_id = oh.order_id
		inner join OrderItem oi
			on oi.order_id = od.order_id
			and oi.line_id = od.line_id
		inner join OrderItem OrderItem
			on oi.order_id = OrderItem.order_id
			and oi.line_id = OrderItem.line_id
			and oi.sequence_id = OrderItem.sequence_id
		inner join product p 
			on od.product_id = p.product_id 
			and od.company_id = p.company_id 
			and od.profit_ctr_id = p.profit_ctr_id
		where
			oi.outbound_receipt_id is not null
			and oi.date_cor_sent is null
			and isnull(oh.email, '') = @email
			and oh.order_id = @order_id 
			and oi.product_id = @product_id
			and od.cor_flag = 'T'  
			and exists (
				select s.image_id 
					from Plt_Image..Scan s 
					inner join Plt_Image..ScanDocumentType sdt 
						on s.type_id = sdt.type_id
						and sdt.document_Type = 'COR' 
					inner join Receipt r
						on s.receipt_id = r.receipt_id
						and s.company_id = r.company_id
						and s.profit_ctr_id = r.profit_ctr_id
						and r.trans_mode = 'O'
					where
						s.receipt_id = oi.outbound_receipt_id
						and s.company_id = od.company_id
						and s.profit_ctr_id = od.profit_ctr_id
						and s.document_source = 'receipt'
						and s.status = 'A'
			)
		
		
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
		oi.order_id,
		oi.line_id,
		oi.sequence_id,
		'OrderItem',
		'date_cor_sent',
		NULL,
		@thisDate,
		'sp_retail_email_boxes_recycled (''' + @email + ''',''' + @order_id_list + ''')',
		left(system_user, 10),
		NULL,
		@thisDate
	from OrderHeader oh
	inner join OrderDetail od 
		on od.order_id = oh.order_id
	inner join OrderItem oi
		on oi.order_id = od.order_id
		and oi.line_id = od.line_id
	inner join OrderItem OrderItem
		on oi.order_id = OrderItem.order_id
		and oi.line_id = OrderItem.line_id
		and oi.sequence_id = OrderItem.sequence_id
	inner join product p 
		on od.product_id = p.product_id 
		and od.company_id = p.company_id 
		and od.profit_ctr_id = p.profit_ctr_id
	where
		oi.outbound_receipt_id is not null
		and isnull(oh.email, '') = @email
		and oh.order_id = @order_id 
		and oi.product_id = @product_id
		and oi.date_cor_sent = @thisDate
		and od.cor_flag = 'T'  
		and exists (
			select s.image_id 
				from Plt_Image..Scan s 
				inner join Plt_Image..ScanDocumentType sdt 
					on s.type_id = sdt.type_id
					and sdt.document_Type = 'COR' 
				inner join Receipt r
					on s.receipt_id = r.receipt_id
					and s.company_id = r.company_id
					and s.profit_ctr_id = r.profit_ctr_id
					and r.trans_mode = 'O'
				where
					s.receipt_id = oi.outbound_receipt_id
					and s.company_id = od.company_id
					and s.profit_ctr_id = od.profit_ctr_id
					and s.document_source = 'receipt'
					and s.status = 'A'
		)
		
		
	FETCH cur_order_info INTO 		
	@quantity_returned, 
	@product_id, 
	@description, 
	@order_id,
	@total_boxes,	
	@order_line,
	@order_item_number,
	@return_tracking_number,
	@received_date,
	@return_weight
	
END

CLOSE cur_order_info
DEALLOCATE cur_order_info

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

declare @message_status char(1)
SET @message_status = 'N'

IF @processing_mode = 'manual'
BEGIN
	SET @message_status = 'P' --'P'review
END
 
 

IF @debug > 0
BEGIN

	-- testing only
	SELECT 'FROM' = 'customerservice.eq@usecology.com', 
		'TO' = @email,
		NULL as MessageID, -- message id
		@message_status as Status, -- status
		'E' as MessageType, -- message type
		'Retail' as MessageSource, -- message source
		'US Ecology Certificate Of Recycling: ' + @ship_customer_name + ', ' + @ship_city + ', ' + @ship_state as Subject,  -- subject
		t.t_field as TextBody,  -- text body field
		h.t_field as HtmlBody, -- html body field
		'EQWEB' as AddedBy, -- added by
		GetDate() as DateAdded -- date added
		from #html h 
		inner join #text t on 1=1 
		where t.t_desc = h.t_desc and h.t_desc = 'template'	
		
		select 'This is debug mode - the email was not queued to be sent.' as DEBUG_MODE_ONLY		
END

IF @debug = 0
BEGIN
	--SELECT 'TODO: insert to message table'
	--- Prepare the insert into the message table
	
	EXEC @message_id = sp_sequence_next 'message.message_id'

	INSERT INTO Message (
		message_id, 
		status, 
		message_type, 
		message_source, 
		subject, 
		message, 
		html, 
		added_by, 
		date_added
	)
		select 
			@message_id, 
			@message_status, 
			'E',
			'Retail', 
			'US Ecology Certificate Of Recycling: ' + @ship_customer_name + ', ' + @ship_city + ', ' + @ship_state as Subject,  -- subject
			t.t_field, 
			h.t_field, 
			'EQWEB',
			GetDate()
		from #html h 
		inner join #text t on 1=1 
		where t.t_desc = h.t_desc and h.t_desc = 'template'	

	Insert Into MessageAddress(
		message_id, 
		address_type, 
		email
	) VALUES
	 (@message_id, 'TO', @email)

	INSERT INTO MessageAddress(
		message_id, 
		address_type, 
		name, 
		company, 
		email
	) VALUES
	 (@message_id, 'FROM', 'USEcology.com', 'US Ecology', 'customerservice.eq@usecology.com')
	
END



			   

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_retail_email_boxes_recycled] TO [EQAI]
    AS [dbo];

