Create Procedure sp_retail_orderdetailcart_list(
	@cart_id int,
	@customer_id int = null,
	@promotion_code varchar(30) = null
) 
as
/************************************************************
Procedure	: sp_retail_orderdetailcart_list
Database	: PLT_AI*
Created		: 4-1-2008 - Jonathan Broome
Description	: Lists products for web retail

************************************************************/

	SET NOCOUNT ON

	select 
		c.cart_id,
		c.date_added,
		c.product_id,
		c.quantity,
		c.replenishment_flag as rep_flag,
		c.cor_flag,
		c.price, 
		p.description,
		p.summary_description,
		p.html_description,
		p.replenishment_flag,
		p.cor_available_flag,
		dbo.fn_retail_product_price(p.product_id, isnull(c.quantity, 1), @customer_id, @promotion_code, getdate()) as product_quote_id_string,
		convert(int, NULL) as product_quote_id,
		p.product_code
	into #temp	 
	from 
		OrderDetailCart c
		inner join Product p on c.product_id = p.product_id 
	where
		c.cart_id = @cart_id 
		and p.retail_flag = 'T' 
		and p.view_on_web_flag = 'T'
		and p.status = 'A'
	order by p.product_code, p.product_id, p.description

	if @customer_id is not null or @promotion_code is not null
		update #temp set
			product_quote_id = convert(int, left(product_quote_id_string, charindex('#', product_quote_id_string)-1)),
			price = convert(money, right(product_quote_id_string, len(product_quote_id_string) - charindex('#', product_quote_id_string)))

	SET NOCOUNT OFF
	
	select 
		cart_id,
		date_added,
		product_id,
		quantity,
		rep_flag,
		cor_flag,
		price, 
		description,
		summary_description,
		html_description,
		replenishment_flag,
		cor_available_flag
	from 
		#temp
	order by product_code, product_id, description


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_retail_orderdetailcart_list] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_retail_orderdetailcart_list] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_retail_orderdetailcart_list] TO [EQAI]
    AS [dbo];

