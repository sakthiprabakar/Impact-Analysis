USE [PLT_AI]
GO
/****** Object:  StoredProcedure [dbo].[sp_cor_get_product_detail]    Script Date: 7/14/2022 10:33:34 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER OFF
GO
CREATE Procedure [dbo].[sp_cor_get_product_detail]
    @product_id int
AS

-- EXEC [sp_cor_get_product_detail] 1443

BEGIN
   
   declare @customer_id int = null
	, @promotion_code varchar(15) = null
	, @cart_id		int = null

   SELECT
		top 1
		p.product_id As product_id,
        p.product_code As product_code,
		dbo.fn_retail_product_price(p.product_id, isnull(c.quantity, 1), null, null, getdate()) as product_quote_id_string,
		convert(int, NULL) as product_quote_id,	
		p.price,				
		p.description As description,
		p.short_description As short_description,
		p.summary_description As summary_description,
		p.html_description As html_description,
		p.web_image_name_thumb As web_image_name_thumb,
		p.web_image_name_full As web_image_name_full
		into #tmp
		From Product as p
		join RetailProductCategory rpc on rpc.product_category_id = p.product_category_id
		left outer join OrderDetailCart c on p.product_id = c.product_id and c.cart_id = @cart_id
		--join OrderDetailCart c on p.product_id = c.product_id 
		-- JOIN ProductQuote as q on p.product_id = q.product_id
		WHERE p.product_id = @product_id
		and p.retail_flag = 'T'
		and p.status = 'A'
		and rpc.status = 'A'
		ORDER BY rpc.category_order, rpc.name, p.description

		update #tmp set
		product_quote_id = convert(int, left(product_quote_id_string, charindex('#', product_quote_id_string)-1)),
		price = convert(money, right(product_quote_id_string, len(product_quote_id_string) - charindex('#', product_quote_id_string)))

		select * from #tmp
END

GO

	GRANT EXECUTE ON [dbo].[sp_cor_get_product_detail] TO COR_USER;

GO


