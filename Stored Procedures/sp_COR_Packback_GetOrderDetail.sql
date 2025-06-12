USE [PLT_AI]
GO

DROP PROCEDURE IF EXISTS [dbo].[sp_COR_Packback_GetOrderDetail]
GO
CREATE proc [dbo].[sp_COR_Packback_GetOrderDetail] 	 
	 @order_id INT	
AS
 /*******************************************************************
    Updated By       : Ashothaman P
    Updated On       : 30th April 2024
    Type             : Stored Procedure
    Ticket           : 85887
    Object Name      : [sp_COR_Packback_GetOrderDetail]
	exec [dbo].[sp_COR_Packback_GetOrderDetail] @order_id = 11873
  **********************************************************************/
BEGIN
	SELECT Order_id
	,Contact_id
	,ship_cust_name
	,ship_addr1
	,ship_addr2
	,ship_addr3
	,ship_addr4
	,ship_city
	,ship_state
	,ship_zip_code
	,ship_attention_name
	,ship_phone
	,contact_first_name
	,contact_last_name
	,email
	,order_date
	,purchase_order
	,total_amt_payment
	,total_amt_order
	,credit_card_auth_id
	,credit_card_type
	,credit_card_last_digits
	,billing_addr1
	,billing_addr2
	,billing_addr3
	,billing_addr4
	,billing_city
	,billing_state
	,billing_postal_code
	,currency_code
	,stripe_customer_token
	,stripe_paymentmethod_token
	,payment_intent_id
	FROM OrderHeader Where Order_id=@order_id
END

GO
GRANT EXECUTE ON [dbo].[sp_COR_Packback_GetOrderDetail] TO COR_USER;
GO