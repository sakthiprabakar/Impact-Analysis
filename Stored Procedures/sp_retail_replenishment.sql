CREATE PROCEDURE sp_retail_replenishment ( @debug int )
AS
/***************************************************************
Loads to:	Plt_AI
This procedure creates a new retail order after an item is returned and the replenish flag 
is set to 'T' for the line on the order.  It is called from a nightly process and looks for
the previous 30 days' returned packages.

-------------------------- History -----------------------------
11/18/2008 KAM	Created
01/14/2008 KAM	Activated in Production
03/30/2009 KAM Updated to get the correct qty to replenish
04/02/2009 JPB  Changed donotreply address to itdept
11/08/2010 JPB  Added count of messages to email subject.
02/26/2018 MPM	Added population of new column, currency_code, in OrderHeader and OrderDetail.
				Also added column list for the insert into OrderDetail.

------------------------ Example Call --------------------------
exec sp_retail_replenishment 1
exec sp_retail_replenishment 0
****************************************************************/

DECLARE 
@return_date		datetime,
@new_order_date	datetime,
@item_return_date	datetime,
@order_id 			int,
@line_id				int,
@product_id			int,
@order_type			char(1),
@order_error		int,
@customer_id		int,
@status				char(1),
@terms				varchar(8),
@new_order_id		int,
@orders_generated	int,
@qty					int,
@error_reason		varchar(255),
@company_id			int, 
@profit_ctr_id 	int, 
@taxable				char(1),
@cor					char(1),
@quote_id			int,
@price				money,
@price_rtn			varchar(20),
@pos					int,
@email_text			varchar(4000),
@crlf					char(2),
@message_id			int,
@ship_name			varchar(40),
@email_text_it		varchar(4000),
@em_cust				varchar(80),
@em_ship_name		varchar(80),
@em_ship_addr1		varchar(80),
@em_ship_addr2		varchar(80),
@em_city				varchar(80),
@em_state			varchar(10),
@em_ship_zip		varchar(10),
@em_added			varchar(20),
@em_contact			varchar(80),
@em_cust_no			int,
@currency_code		char(3)

Create table #repl_rpt (org_ord_id int,new_order_id int, message varchar(255))

Select @return_date = DateAdd(DAY,DATEDIFF(DAY,'20000101',GetDate())-30,'20000101')
Select @new_order_date = DateAdd(DAY,DATEDIFF(DAY,'20000101',GetDate()),'20000101')

DECLARE replenish CURSOR FOR SELECT DISTINCT OrderItem.Order_id, OrderItem.Line_id, OrderItem.Product_id, OrderHeader.Order_type, OrderHeader.Customer_id, OrderHeader.Ship_cust_name, OrderItem.date_returned
	From OrderItem, OrderDetail, OrderHeader
	Where OrderItem.order_id = OrderHeader.Order_id and
		OrderItem.order_id = OrderDetail.Order_id and OrderItem.line_id = OrderDetail.Line_id and
		OrderDetail.replenishment_flag = 'T' and
		OrderItem.date_returned > @return_date and
		OrderItem.status <> 'F'

OPEN replenish

Fetch replenish into @order_id, @line_id, @product_id, @order_type, @customer_id, @ship_name, @item_return_date
If @debug = 1 
	BEGIN
		Print 'Order = ' + Cast(@order_id as Varchar(10)) + ' Line = ' + cast(@line_id as Varchar(10)) + ' Product = ' + Cast(@product_id as varchar(10)) + ' Order Type = ' + @order_type + ' Customer = ' + cast(@customer_id as varchar(10))
	END

WHILE @@FETCH_STATUS = 0
	BEGIN
	
		SET @order_error = 0
	
		IF @order_type = 'A'
			BEGIN
				Select @status = cust_status, @terms = terms_code, @currency_code = currency_code from Customer where customer_id = @customer_id 
				Set @error_reason = ''
				If @status <> 'A'
					Begin
						Set @order_error = 1
						Set @error_reason = 'No order created because the customer is no longer active. Customer ' + Cast(@customer_id as Varchar(10)) + "  " + @ship_name
					END
				if @terms = 'NOADMIT' or @terms = 'COD'
			 		BEGIN 
						Set @order_error = 1
						Set @error_reason = 'No order created because the customer now has terms of COD or No Admit. Customer ' + Cast(@customer_id as Varchar(10)) + "  " + @ship_name
					END
			END
		IF @order_error = 0 
			BEGIN
				-- Copy Order Here
				-- Get the new order ID
				EXEC @new_order_id = sp_sequence_next 'OrderHeader.order_id',0
	
				-- The the Quantity to Replenish
				Select @qty = count(*) from OrderItem where Order_id = @order_id 
																	and line_id = @line_id 		
																	and OrderItem.date_returned > @return_date 
																	and OrderItem.status <> 'F'
	
				-- Create the new OrderHeader Row
				Select * into #temp_order from OrderHeader where order_id = @order_id
			
				-- Get the contents of the existing fields for the new detail row			
				Select @company_id = company_id, @profit_ctr_id = profit_ctr_id, @taxable = taxable_flag, @cor = cor_flag
					From OrderDetail
					Where order_id = @order_id and line_id = @line_id
	
				-- Get the current price for the customer, product, date
				Set @price_rtn = dbo.fn_retail_product_price(@product_id,@qty,@customer_id,NULL,@new_order_date)
				
				-- Parse the Quote ID from the actual price
				Set @pos = Charindex('#',@price_rtn)
				Set @quote_id = Cast(Left(@price_rtn,@pos-1) as int)
				Set @price = Cast(Right(@price_rtn,Len(@price_rtn)- @pos) as Money)
				
				--Write the detail row out
				Insert Into OrderDetail (
								order_id,
								line_id,
								company_id,
								profit_ctr_id,
								product_quote_id,
								product_id,
								status,
								quantity,
								price,
								extended_amt,
								taxable_flag,
								cor_flag,
								replenishment_flag,
								replenishment_order_id,
								replenishment_line_id,
								credit_card_trans_id,
								date_emailed_receipt,
								price_modified_by,
								date_added,
								added_by,
								date_modified,
								modified_by,
								currency_code)
								Values (@new_order_id,
								1,
								@company_id, 
								@profit_ctr_id,
								@quote_id,
								@product_id,
								'N',
								@qty,
								@price,
								(@qty * @price),
								@taxable,
								@cor,
								'T',
								@order_id,
								@line_id,
								NULL,
								NULL,
								NULL,
								GetDate(),
								'SA',
								GetDate(),
								'SA',
								@currency_code)
	
				--  Update the Old OrderHeader row to be the new OrderHeader row
				Update #temp_order set order_id = @new_order_id,
					order_date = @new_order_date,
					status = 'N',
					date_submitted = NULL,
					submitted_flag = 'F',
					total_amt_payment = (@qty * @price),
					total_amt_order = (@qty * @price),
					date_added = GetDate(),
					date_modified = GetDate(),
					modified_by = 'SA',
					currency_code = @currency_code

					Update #temp_order set original_replenishment_order_id = @order_id where original_replenishment_order_id is Null

					If @debug = 1 
						BEGIN
							Print 'Order = ' + cast(@order_id as varchar) + ' New Order = ' + cast(@new_order_id as varchar) + ' Quantity = ' + cast(@qty as varchar)
						END
		
				Insert into OrderHeader select * from #temp_order

				-- Write out an Audit record that replenishment created this order
				Insert into OrderAudit values (@new_order_id, NULL, NULL, 'OrderHeader','orderheader_status','(new record inserted)',cast(@new_order_id as varchar),'Creation of replenishment order.','SA','REPL PROC',GetDate())

				Update OrderItem set status = 'F' where order_id = @order_id and line_id = @line_id and date_returned = @item_return_date

				Drop Table #temp_order
				Set @error_reason = 'Replenishment Order Created from order ' + cast(@order_id as varchar) + '  ' + @ship_name 
				Insert Into #repl_rpt Values (@order_id, @new_order_id,@error_reason)
		
			END
		ELSE
			-- Bad status or terms code
			BEGIN
				Insert Into #repl_rpt Values (@order_id, NULL, @error_reason)

				-- Turn off the replenishment flag for the line on this order
				Update OrderDetail set replenishment_flag = 'F' where order_id = @order_id and line_id = @line_id

				-- Write out an Audit record that we switched the replenishment flag
				Insert into OrderAudit values (@order_id, @line_id, NULL, 'OrderDetail','replenishment_flag','T','F','Unable to create replenishment order.','SA','REPL PROC',GetDate())
			END
		-- Try Next Row
		Fetch replenish into @order_id, @line_id, @product_id, @order_type, @customer_id, @ship_name, @item_return_date
	END

CLOSE replenish
DEALLOCATE replenish

--  Generate Report and E-mails here

Select @orders_generated = count(*) from #repl_rpt

If @debug = 1 
	BEGIN
		Print 'Orders Processed = ' + Cast(@orders_generated as Varchar(10))
	END

Set @email_text = ''
Set @email_text_it = ''
Set @crlf = char(13) + char(10)
If @orders_generated > 0 
   Begin
		DECLARE replenish_rpt CURSOR FOR SELECT org_ord_id ,new_order_id , message 
			From #repl_rpt
		
		OPEN replenish_rpt
		
		Fetch replenish_rpt into @order_id, @new_order_id, @error_reason
		
		WHILE @@FETCH_STATUS = 0
		BEGIN
			set @email_text = @email_text + 'Order ' + Cast(@new_order_id as Varchar(10)) + " created.     " + @error_reason + @crlf
			set @email_text_it = @email_text_it + 'Order ' + Cast(@new_order_id as Varchar(10)) + " created.     " + @error_reason + @crlf
	
			Select 	@em_cust = cust_name, @em_ship_name = ship_cust_name, @em_ship_addr1 = ship_addr1,
						@em_ship_addr2 = ship_addr2, @em_city = ship_city, @em_state = ship_state,
						@em_ship_zip = ship_zip_code, @em_contact = contact_last_name + ', ' + contact_first_name,
						@em_added = OrderHeader.added_by, @em_cust_no = OrderHeader.customer_id
			From		Orderheader, Customer
			Where		Orderheader.customer_id = Customer.Customer_id and
						orderheader.order_id = @order_id

			Set @email_text = @email_text + @crlf + @crlf + 'Customer:       ' + IsNull(@em_cust,'') + '  (' + cast(@em_cust_no as varchar) + ')'
			Set @email_text = @email_text + @crlf  + 'Ship To Name:   ' + IsNull(@em_ship_name,'')
			Set @email_text = @email_text + @crlf  + 'Ship Address 1: ' + IsNull(@em_ship_addr1,'')
			Set @email_text = @email_text + @crlf  + 'Ship Address 2: ' + IsNull(@em_ship_addr2,'')
			Set @email_text = @email_text + @crlf  + 'Ship City:      ' + IsNull(@em_city,'')
			Set @email_text = @email_text + @crlf  + 'Ship State:     ' + IsNull(@em_state,'')
			Set @email_text = @email_text + @crlf  + 'Ship Zip:       ' + IsNull(@em_ship_zip,'')
			Set @email_text = @email_text + @crlf  + 'Added By:       ' + IsNull(@em_added,'')
			Set @email_text = @email_text + @crlf + @crlf 

			EXEC @message_id = sp_sequence_next 'message.message_id',0

			If @debug = 1 
				BEGIN
					Print ' Message ID = ' + cast(@message_id as varchar(10))
				END
	--		Set @email_text = 'Test E-mail, please Delete'

			Insert Into Message (message_id, status, message_type, message_source, subject, message,  added_by, date_added) 
				Values(@message_id, 'N', 'E','Retail', @em_cust + ' Order Replenishment', @email_text,'EQWEB',GetDate())

			Insert Into MessageAddress(message_id, address_type, name, company, email) Values
				(@message_id, 'TO', 'Customer Service', 'EQ', 'EQ.CustomerService@eqonline.com')
			
			--Insert Into MessageAddress(message_id, address_type, name, company, email) Values
				--(@message_id, 'TO', 'IT Department', 'EQ', 'webmaster@eqonline.com')

			Insert Into MessageAddress(message_id, address_type, name, company, email) Values
				 (@message_id, 'FROM', 'EQ Online', 'EQ', 'itdept@eqonline.com')

			If @debug = 1 
				BEGIN
					Print 'Email Text = ' + @email_text + ' Message ID = ' + cast(@message_id as varchar(10))
				END

			Set @email_text = ''
	
			Fetch replenish_rpt into @order_id, @new_order_id, @error_reason
		END
		CLOSE replenish_rpt
		DEALLOCATE replenish_rpt

		Set @email_text_it = @email_text_it + @crlf + @crlf + 'Total Orders Processed = ' +  cast(@orders_generated as Varchar(10))

   End
ELSE
   Begin
 		Set @email_text_it = "No orders to Replenish for " + Cast(@new_order_date as VarChar(20))
   END

--- Prepare the insert into the message table

EXEC @message_id = sp_sequence_next 'message.message_id',0

If @debug = 1 
	BEGIN
		Print 'Email Text = ' + @email_text_it + ' Message ID = ' + cast(@message_id as varchar(10))
	END

Insert Into Message (message_id, status, message_type, message_source, subject, message,  added_by, date_added) 
	Values(@message_id, 'N', 'E','Retail', 'EQ Online Order Replenishment - ' + Cast(@orders_generated as Varchar) + ' on ' + Cast(@new_order_date as Varchar), @email_text_it,'EQWEB',GetDate())

--Insert Into MessageAddress(message_id, address_type, name, company, email) Values
--	(@message_id, 'TO', 'IT Department', 'EQ', 'ITDept@eqonline.com')

--Insert Into MessageAddress(message_id, address_type, name, company, email) Values
--	(@message_id, 'TO', 'Customer Service', 'EQ', 'EQ.CustomerService@eqonline.com')

Insert Into MessageAddress(message_id, address_type, name, company, email) Values
	(@message_id, 'TO', 'IT Department', 'EQ', 'webmaster@eqonline.com')

Insert Into MessageAddress(message_id, address_type, name, company, email) Values
	 (@message_id, 'FROM', 'EQ Online', 'EQ', 'itdept@eqonline.com')


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_retail_replenishment] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_retail_replenishment] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_retail_replenishment] TO [EQAI]
    AS [dbo];

