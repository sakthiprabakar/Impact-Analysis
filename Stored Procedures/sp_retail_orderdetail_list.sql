Create Procedure sp_retail_orderdetail_list(
	@order_id int
) 
as
/************************************************************
Procedure	: sp_retail_orderdetail_list
Database	: PLT_AI*
Created		: 4-1-2008 - Jonathan Broome
Description	: Lists products for web retail

************************************************************/

	select 
		c.order_id,
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
		p.cor_available_flag
	from 
		OrderDetail c
		inner join Product p on c.product_id = p.product_id 
	where
		c.order_id = @order_id 
		and p.retail_flag = 'T' 
		and p.view_on_web_flag = 'T'
	order by p.product_code, p.product_id, p.description


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_retail_orderdetail_list] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_retail_orderdetail_list] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_retail_orderdetail_list] TO [EQAI]
    AS [dbo];

