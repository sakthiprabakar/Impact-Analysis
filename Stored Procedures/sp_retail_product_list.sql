Create Procedure sp_retail_product_list (
	@cart_id		int = null,
	@customer_id	int = null,
	@promotion_code	varchar(15) = null
)
as
/************************************************************
Procedure	: sp_retail_product_list
Database	: PLT_AI*
Created		: 4-1-2008 - Jonathan Broome
Description	: Lists products for web retail

4/9/2008 JPB Added getdate() parameter to fn_reatil_product_price call per Keith
	Added and status = 'A' to product query, because it's the right thing to do.
	
************************************************************/

	SET NOCOUNT ON
	
	select 
		p.product_id,
		p.product_code, 
		dbo.fn_retail_product_price(p.product_id, isnull(c.quantity, 1), @customer_id, @promotion_code, getdate()) as product_quote_id_string,
		convert(int, NULL) as product_quote_id,
		p.price, 
		p.description, 
		p.short_description, 
		p.summary_description, 
		p.html_description,
		p.company_id,
		p.profit_ctr_id,
		p.web_image_name_thumb,
		p.web_image_name_full
	into #temp	 
	from 
		Product p
		left outer join OrderDetailCart c on p.product_id = c.product_id and c.cart_id = @cart_id
	where 
		retail_flag = 'T' 
		and view_on_web_flag = 'T'
		and status = 'A'


	update #temp set
		product_quote_id = convert(int, left(product_quote_id_string, charindex('#', product_quote_id_string)-1)),
		price = convert(money, right(product_quote_id_string, len(product_quote_id_string) - charindex('#', product_quote_id_string)))
	
	SET NOCOUNT OFF
	
	select 
		product_id,
		product_code, 
		product_quote_id,
		price, 
		description, 
		short_description, 
		summary_description, 
		html_description,
		web_image_name_thumb,
		web_image_name_full
	from 
		#temp
	order by product_code, product_id, description


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_retail_product_list] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_retail_product_list] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_retail_product_list] TO [EQAI]
    AS [dbo];

