USE [PLT_AI]
GO
	drop proc if exists sp_COR_Save_Cart
GO

CREATE PROCEDURE [dbo].[sp_COR_Save_Cart] @Data xml
AS
BEGIN
 DECLARE @web_user_id varchar(150) = (SELECT
    p.v.value('web_userid[1]', 'nvarchar(150)')
  FROM @Data.nodes('ProductCartModel') p (v))

 
  DECLARE @credit_card_auth_id nvarchar(200),
          @paymentmethod nvarchar(200)
  DECLARE @cart_id int

  SELECT
    @cart_id = p.v.value('cart_id[1]', 'int'),
    @credit_card_auth_id = p.v.value('stripe_paymentmethod_token[1]', 'nvarchar(200)'),
    @paymentmethod = ISNULL(p.v.value('payment_method[1]', 'nvarchar(200)'), '')
  FROM @Data.nodes('ProductCartModel/OrderHeaderCart') p (v)

BEGIN TRY
  
  IF (ISNULL(@credit_card_auth_id, '') = ''
    AND @paymentmethod = '')
  BEGIN
    IF (EXISTS (SELECT
        cart_id
      FROM OrderHeaderCart
      WHERE cart_id = @cart_id)
      )
    BEGIN

      UPDATE OrderHeaderCart
      SET customer_id = case when p.v.value('customer_id[1]', 'int') = 0 or p.v.value('customer_id[1]', 'int') = null then 12035  else p.v.value('customer_id[1]', 'int') end,
          contact_id = case when p.v.value('contact_id[1]', 'int') > 0 then p.v.value('contact_id[1]', 'int') else null end,
          web_userid = @web_user_id,
          contact_first_name =  p.v.value('contact_first_name[1]', 'varchar(20)'), -- @contact_first_name,
          contact_last_name =  p.v.value('contact_last_name[1]', 'varchar(20)'), -- @contact_last_name,
          contact_company_name = p.v.value('contact_company_name[1]', 'varchar(40)'),
          contact_email = p.v.value('contact_email[1]', 'varchar(60)'),
          send_email_flag = p.v.value('send_email_flag[1]', 'char(1)'),
          contact_phone = p.v.value('contact_phone[1]', 'varchar(20)'),
          ship_cust_name = p.v.value('ship_cust_name[1]', 'varchar(40)'),
          ship_attention_name = p.v.value('ship_attention_name[1]', 'varchar(40)'),
          ship_addr1 = p.v.value('ship_addr1[1]', 'varchar(40)'),
          ship_addr2 = p.v.value('ship_addr2[1]', 'varchar(40)'),
          ship_addr3 = p.v.value('ship_addr3[1]', 'varchar(40)'),
          ship_addr4 = p.v.value('ship_addr4[1]', 'varchar(40)'),
          ship_city = p.v.value('ship_city[1]', 'varchar(40)'),
          ship_state = p.v.value('ship_state[1]', 'varchar(2)'),
          ship_zip_code = p.v.value('ship_zip_code[1]', 'varchar(15)'),
          payment_method = p.v.value('payment_method[1]', 'char(20)'),
          name_on_card = p.v.value('payment_method[1]', 'varchar(40)'),
          billing_addr1 = p.v.value('billing_addr1[1]', 'varchar(40)'),
          billing_addr2 = p.v.value('billing_addr2[1]', 'varchar(40)'),
          billing_addr3 = p.v.value('billing_addr3[1]', 'varchar(40)'),
          billing_addr4 = p.v.value('billing_addr4[1]', 'varchar(40)'),
          billing_city = p.v.value('billing_city[1]', 'varchar(40)'),
          billing_state = p.v.value('billing_state[1]', 'varchar(2)'),
          billing_postal_code = p.v.value('billing_postal_code[1]', 'varchar(15)'),
          credit_card_auth_id = p.v.value('credit_card_auth_id[1]', 'varchar(30)')
      FROM @Data.nodes('ProductCartModel/OrderHeaderCart') p (v)
      WHERE cart_id = @cart_id
    END

    IF (NOT EXISTS (SELECT
        cart_id
      FROM OrderHeaderCart
      WHERE cart_id = @cart_id)
      )
    BEGIN

		select @cart_id = max(cart_id) + 1 from OrderHeaderCart;

      --EXEC @cart_id = sp_sequence_next 'OrderHeader.order_id'

      INSERT INTO OrderHeaderCart (cart_id, customer_id, web_userid, contact_id,
      contact_first_name, contact_last_name, contact_company_name,
      contact_email, send_email_flag, contact_phone, ship_cust_name,
      ship_attention_name, ship_addr1, ship_addr2, ship_addr3, ship_addr4,
      ship_city, ship_state, ship_zip_code,purchase_order,
      payment_method, name_on_card, billing_addr1, billing_addr2, billing_addr3,
      billing_addr4, billing_city, billing_state, billing_postal_code,
      credit_card_auth_id, date_added)
        SELECT TOP 1
          cart_id = @cart_id,
          customer_id = case when p.v.value('customer_id[1]', 'int') = 0 or p.v.value('customer_id[1]', 'int') = null then 12035  else p.v.value('customer_id[1]', 'int') end,
          web_userid = @web_user_id,
          contact_id = case when p.v.value('contact_id[1]', 'int') > 0 then p.v.value('contact_id[1]', 'int') else null end,
          contact_first_name =  p.v.value('contact_first_name[1]', 'varchar(20)'), -- @contact_first_name,
          contact_last_name =  p.v.value('contact_last_name[1]', 'varchar(20)'), -- @contact_last_name,
          contact_company_name = p.v.value('contact_company_name[1]', 'varchar(40)'),
          contact_email = p.v.value('contact_email[1]', 'varchar(60)'),
          send_email_flag = p.v.value('send_email_flag[1]', 'char(1)'),
          contact_phone =p.v.value('contact_phone[1]', 'varchar(20)'),
          ship_cust_name = p.v.value('ship_cust_name[1]', 'varchar(40)'),
          ship_attention_name = p.v.value('ship_attention_name[1]', 'varchar(40)'),
          ship_addr1 = p.v.value('ship_addr1[1]', 'varchar(40)'),
          ship_addr2 = p.v.value('ship_addr2[1]', 'varchar(40)'),
          ship_addr3 = p.v.value('ship_addr3[1]', 'varchar(40)'),
          ship_addr4 = p.v.value('ship_addr4[1]', 'varchar(40)'),
          ship_city = p.v.value('ship_city[1]', 'varchar(40)'),
          ship_state = p.v.value('ship_state[1]', 'varchar(2)'),
          ship_zip_code = p.v.value('ship_zip_code[1]', 'varchar(15)'),
		  purchase_order=p.v.value('purchase_order[1]', 'varchar(100)'),
          payment_method = p.v.value('payment_method[1]', 'char(20)'),
          name_on_card = p.v.value('payment_method[1]', 'varchar(40)'),
          billing_addr1 = p.v.value('billing_addr1[1]', 'varchar(40)'),
          billing_addr2 = p.v.value('billing_addr2[1]', 'varchar(40)'),
          billing_addr3 = p.v.value('billing_addr3[1]', 'varchar(40)'),
          billing_addr4 = p.v.value('billing_addr4[1]', 'varchar(40)'),
          billing_city = p.v.value('billing_city[1]', 'varchar(40)'),
          billing_state = p.v.value('billing_state[1]', 'varchar(2)'),
          billing_postal_code = p.v.value('billing_postal_code[1]', 'varchar(15)'),
          credit_card_auth_id = p.v.value('credit_card_auth_id[1]', 'varchar(30)'),
          date_added = GETDATE()
        FROM @Data.nodes('ProductCartModel/OrderHeaderCart') p (v)

    END

    UPDATE OrderDetailCart
    SET quantity = p.v.value('quantity[1]', 'float'),
        price = p.v.value('price[1]', 'money'),
        cor_flag = p.v.value('cor_flag[1]', 'char(1)'),
        replenishment_flag = p.v.value('replenishment_flag[1]', 'char(1)')
    FROM @Data.nodes('ProductCartModel/OrderDetailCart/OrderDetailCart') p (v)
    WHERE product_id = p.v.value('product_id[1]', 'int')
    AND cart_id = @cart_id

    INSERT INTO OrderDetailCart (cart_id, product_id, quantity, price, cor_flag, replenishment_flag, date_added)
      SELECT
        cart_id = @cart_id,
        product_id = p.v.value('product_id[1]', 'int'),
        quantity = p.v.value('quantity[1]', 'float'),
        price = p.v.value('price[1]', 'money'),
        cor_flag = p.v.value('cor_flag[1]', 'char(1)'),
        replenishment_flag = p.v.value('replenishment_flag[1]', 'char(1)'),
        date_added = GETDATE()
      FROM @Data.nodes('ProductCartModel/OrderDetailCart/OrderDetailCart') p (v)
      WHERE p.v.value('product_id[1]', 'int')
      NOT IN (SELECT
        product_id
      FROM OrderDetailCart
      WHERE cart_id = @cart_id)


    CREATE TABLE #tmpCarts (
      cart_id int,
      line_id int,
      product_ID int,
      product_code varchar(15),
      product_quote_id_string nvarchar(200),
      product_quote_id int,
      quantity float,
      price money,
      description varchar(60),
      summary_description [text] NULL,
      html_description [text] NULL,
      web_image_name_thumb varchar(40),
      web_image_name_full varchar(40),
      cor_flag char(1),
      replenishment_flag char(1),
      total_count float
    )

    INSERT INTO #tmpCarts
    EXEC sp_cor_get_cart_products @cart_id = @cart_id

    SELECT
      @cart_id AS cart_id,
      (SELECT
        SUM(quantity)
      FROM #tmpCarts)
      AS total_count
    DROP TABLE #tmpCarts


  END
  ELSE
  BEGIN
    EXEC plt_ai..[sp_COR_Save_Order] @Data
  END

  END TRY
  BEGIN CATCH
	INSERT INTO COR_DB.[dbo].[ErrorLogs] (ErrorDescription,[Object_Name],Web_user_id,CreatedDate)
		                               VALUES(error_message(),ERROR_PROCEDURE(),ISNULL(@web_user_id,CONVERT(VARCHAR(20),@cart_id)),GETDATE())
  END CATCH
END


GO

	GRANT EXECUTE ON [dbo].[sp_COR_Save_Cart] TO COR_USER;

GO