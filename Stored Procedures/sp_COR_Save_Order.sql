USE [PLT_AI]
GO
DROP PROCEDURE IF EXISTS [dbo].[sp_COR_Save_Order]
GO

CREATE PROCEDURE [dbo].[sp_COR_Save_Order] @Data XML
AS

/*******************************************************************
Updated By       : Ashothaman P
Updated On       : 30th April 2024
Type             : Stored Procedure
Ticket           : 85887
Object Name      : [sp_COR_Save_Order]

**********************************************************************/
BEGIN
DECLARE @web_user_id VARCHAR(150) = (
		SELECT p.v.value('web_userid[1]', 'nvarchar(150)')
		FROM @Data.nodes('ProductCartModel') p(v)
		)
DECLARE @StripeCustomerToken NVARCHAR(200)
	,@credit_card_auth_id NVARCHAR(200)
	,@stripe_payment_token NVARCHAR(200)
DECLARE @order_id INT
	,@TotalAmt MONEY
	,@cartid INT

SELECT @credit_card_auth_id = p.v.value('credit_card_auth_id[1]', 'nvarchar(200)')
	,@StripeCustomerToken = p.v.value('stripe_customer_token[1]', 'nvarchar(200)')
	,@stripe_payment_token = p.v.value('stripe_paymentmethod_token[1]', 'varchar(200)')
	,@cartid = p.v.value('cart_id[1]', 'int')
FROM @Data.nodes('ProductCartModel/OrderHeaderCart') p(v)

SELECT @TotalAmt = SUM(p.v.value('quantity[1]', 'float') * p.v.value('price[1]', 'money'))
FROM @Data.nodes('ProductCartModel/OrderDetailCart/OrderDetailCart') p(v)

EXEC @order_id = sp_sequence_next 'OrderHeader.order_id'

BEGIN TRY
BEGIN TRANSACTION saveorderTransaction;
	INSERT INTO OrderHeader (
		order_id
		,customer_id
		,contact_id
		,billing_project_id
		,ship_cust_name
		,ship_attention_name
		,ship_addr1
		,ship_addr2
		,ship_addr3
		,ship_addr4
		,ship_city
		,ship_state
		,ship_zip_code
		,ship_phone
		,contact_first_name
		,contact_last_name
		,email
		,send_email_flag
		,purchase_order
		,order_date
		,order_type
		,[status]
		,distribution_method
		,total_amt_payment
		,total_amt_order
		,credit_card_auth_id
		,stripe_customer_token
		,stripe_paymentmethod_token
		,billing_addr1
		,billing_addr2
		,billing_addr3
		,billing_addr4
		,billing_city
		,billing_state
		,billing_postal_code
		,date_added
		,added_by
		,date_modified
		,modified_by
		,currency_code
		,payment_intent_id
		)
	SELECT TOP 1 order_id = @order_id
		,customer_id = CASE 
			WHEN p.v.value('customer_id[1]', 'int') = 0
				OR p.v.value('customer_id[1]', 'int') = NULL
				THEN 12035
			ELSE p.v.value('customer_id[1]', 'int')
			END
		,contact_id = CASE 
			WHEN p.v.value('contact_id[1]', 'int') > 0
				THEN p.v.value('contact_id[1]', 'int')
			ELSE NULL
			END
		,billing_project_id = p.v.value('billing_project_id[1]', 'int')
		,ship_cust_name = p.v.value('ship_cust_name[1]', 'varchar(40)')
		,ship_attention_name = p.v.value('ship_attention_name[1]', 'varchar(40)')
		,ship_addr1 = p.v.value('ship_addr1[1]', 'varchar(40)')
		,ship_addr2 = p.v.value('ship_addr2[1]', 'varchar(40)')
		,ship_addr3 = p.v.value('ship_addr3[1]', 'varchar(40)')
		,ship_addr4 = p.v.value('ship_addr4[1]', 'varchar(40)')
		,ship_city = p.v.value('ship_city[1]', 'varchar(40)')
		,ship_state = p.v.value('ship_state[1]', 'varchar(2)')
		,ship_zip_code = p.v.value('ship_zip_code[1]', 'varchar(15)')
		,ship_phone = p.v.value('contact_phone[1]', 'varchar(40)')
		,contact_first_name = p.v.value('contact_first_name[1]', 'varchar(40)')
		,contact_last_name = p.v.value('contact_last_name[1]', 'varchar(40)')
		,email = p.v.value('contact_email[1]', 'varchar(100)')
		,send_email_flag = p.v.value('send_email_flag[1]', 'char(1)')
		,purchase_order = p.v.value('purchase_order[1]', 'varchar(100)')
		,order_date = GETDATE()
		,order_type = CASE 
			WHEN p.v.value('payment_method[1]', 'varchar(100)') = 'Account'
				THEN 'A'
			ELSE 'C'
			END
		,[status] = 'N'
		,distribution_method = 'U'
		,total_amt_payment = @TotalAmt
		,total_amt_order = @TotalAmt
		,credit_card_auth_id = @credit_card_auth_id
		,stripe_customer_token = p.v.value('stripe_customer_token[1]', 'varchar(200)')
		,stripe_paymentmethod_token = p.v.value('stripe_paymentmethod_token[1]', 'varchar(200)')
		,billing_addr1 = p.v.value('billing_addr1[1]', 'varchar(40)')
		,billing_addr2 = p.v.value('billing_addr2[1]', 'varchar(40)')
		,billing_addr3 = p.v.value('billing_addr3[1]', 'varchar(40)')
		,billing_addr4 = p.v.value('billing_addr4[1]', 'varchar(40)')
		,billing_city = p.v.value('billing_city[1]', 'varchar(40)')
		,billing_state = p.v.value('billing_state[1]', 'varchar(2)')
		,billing_postal_code = p.v.value('billing_postal_code[1]', 'varchar(30)')
		,date_added = GETDATE()
		,added_by = @web_user_id
		,date_modified = GETDATE()
		,modified_by = @web_user_id
		,currency_code = 'USD'
		,payment_intent_id = p.v.value('payment_intent_id[1]', 'nvarchar(50)')
	FROM @Data.nodes('ProductCartModel/OrderHeaderCart') p(v)

	IF (@cartid = '')
	BEGIN
		INSERT INTO OrderDetail (
			order_id
			,line_id
			,company_id
			,profit_ctr_id
			,product_id
			,STATUS
			,quantity
			,price
			,extended_amt
			,taxable_flag
			,cor_flag
			,credit_card_trans_id
			,replenishment_flag
			,date_added
			,added_by
			,date_modified
			,modified_by
			,currency_code
			)
		SELECT order_id = @order_id
			,line_id = p.v.value('line_id[1]', 'int')
			,company_id = 14
			,profit_ctr_id = 9
			,product_id = p.v.value('product_id[1]', 'int')
			,[status] = 'N'
			,quantity = p.v.value('quantity[1]', 'float')
			,price = p.v.value('price[1]', 'money')
			,extended_amt = p.v.value('quantity[1]', 'float') * p.v.value('price[1]', 'money')
			,taxable_flag = 'F'
			,cor_flag = p.v.value('cor_flag[1]', 'char(1)')
			,credit_card_trans_id = NULL
			,replenishment_flag = p.v.value('replenishment_flag[1]', 'char(1)')
			,date_added = GETDATE()
			,added_by = @web_user_id
			,date_modified = GETDATE()
			,modified_by = @web_user_id
			,currency_code = 'USD'
		FROM @Data.nodes('ProductCartModel/OrderDetailCart/OrderDetailCart') p(v)
	END
	ELSE
	BEGIN
		INSERT INTO OrderDetail (
			order_id
			,line_id
			,company_id
			,profit_ctr_id
			,product_id
			,STATUS
			,quantity
			,price
			,extended_amt
			,taxable_flag
			,cor_flag
			,credit_card_trans_id
			,replenishment_flag
			,date_added
			,added_by
			,date_modified
			,modified_by
			,currency_code
			)
		SELECT order_id = @order_id
			,line_id = row_number() OVER (
				ORDER BY p.v.value('line_id[1]', 'int')
				)
			,company_id = 14
			,profit_ctr_id = 9
			,product_id = p.v.value('product_id[1]', 'int')
			,[status] = 'N'
			,quantity = p.v.value('quantity[1]', 'float')
			,price = p.v.value('price[1]', 'money')
			,extended_amt = p.v.value('quantity[1]', 'float') * p.v.value('price[1]', 'money')
			,taxable_flag = 'F'
			,cor_flag = p.v.value('cor_flag[1]', 'char(1)')
			,credit_card_trans_id = NULL
			,replenishment_flag = p.v.value('replenishment_flag[1]', 'char(1)')
			,date_added = GETDATE()
			,added_by = @web_user_id
			,date_modified = GETDATE()
			,modified_by = @web_user_id
			,currency_code = 'USD'
		FROM @Data.nodes('ProductCartModel/OrderDetailCart/OrderDetailCart') p(v)

		INSERT INTO [COR_DB].[dbo].[PaymentLog] (
			order_id
			,stripe_payment_token
			,[Status]
			,ErrorDescription
			,CreatedDate
			,[response_message]
			)
		VALUES (
			@order_id
			,@stripe_payment_token
			,'pending'
			,NULL
			,GETDATE()
			,'order placed'
			)

		DELETE
		FROM OrderDetailCart
		WHERE cart_id = @cartid

		DELETE
		FROM OrderHeaderCart
		WHERE cart_id = @cartid
	END

	DECLARE @UserXStripeId NVARCHAR(200);

	IF (
			ISNULL(@web_user_id, '') <> ''
			AND ISNULL(@StripeCustomerToken, '') <> ''
			AND ISNULL(@credit_card_auth_id, '') <> ''
			)
	BEGIN
		IF (
				NOT EXISTS (
					SELECT TOP 1 *
					FROM cor_db.dbo.UserXStripeCustomer
					WHERE web_userid = @web_user_id
						AND StripeCustomerToken = @StripeCustomerToken
					)
				)
		BEGIN
			SET @UserXStripeId = NEWID();

			INSERT INTO cor_db.dbo.UserXStripeCustomer (
				UserXStripeId
				,web_userid
				,StripeCustomerToken
				,created_date
				,Modified_Date
				)
			SELECT @UserXStripeId
				,@web_user_id
				,@StripeCustomerToken
				,GETDATE()
				,GETDATE() --FROM  @Data.nodes('ProductCartModel/OrderHeaderCart')p(v)

			INSERT INTO cor_db.dbo.[StripeCustomerXCards] (
				UserXStripeId
				,StripeCustomerCardToken
				,created_date
				,Modified_Date
				)
			SELECT @UserXStripeId
				,@credit_card_auth_id
				,GETDATE()
				,GETDATE()
		END
		ELSE IF (
				NOT EXISTS (
					SELECT *
					FROM cor_db.dbo.UserXStripeCustomer UC
					INNER JOIN cor_db.dbo.StripeCustomerXCards SC ON SC.UserXStripeId = UC.UserXStripeId
					WHERE web_userid = @web_user_id
						AND StripeCustomerCardToken = @credit_card_auth_id
						AND StripeCustomerToken = @StripeCustomerToken
					)
				)
		BEGIN
			SET @UserXStripeId = (
					SELECT TOP 1 UserXStripeId
					FROM cor_db.dbo.UserXStripeCustomer
					WHERE web_userid = @web_user_id
						AND StripeCustomerToken = @StripeCustomerToken
					)

			INSERT INTO cor_db.dbo.[StripeCustomerXCards] (
				UserXStripeId
				,StripeCustomerCardToken
				,created_date
				,Modified_Date
				)
			SELECT @UserXStripeId
				,@credit_card_auth_id
				,GETDATE()
				,GETDATE()
		END
	END

	SELECT Order_id = @order_id
	COMMIT TRANSACTION saveorderTransaction;
END TRY

BEGIN CATCH
	IF @@TRANCOUNT > 0
    ROLLBACK TRANSACTION saveorderTransaction;
			
	INSERT INTO COR_DB.[dbo].[ErrorLogs] (
		ErrorDescription
		,[Object_Name]
		,Web_user_id
		,CreatedDate
		)
	VALUES (
		error_message()
		,ERROR_PROCEDURE()
		,ISNULL(@web_user_id, CONVERT(VARCHAR(20), @order_id))
		,GETDATE()
		)
END CATCH
END;
GO
GRANT EXECUTE ON [dbo].[sp_COR_Save_Order] TO [EQAI];
GO
GRANT EXECUTE ON [dbo].[sp_COR_Save_Order] TO [COR_USER];
GO
