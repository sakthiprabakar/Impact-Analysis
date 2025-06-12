go

drop proc if exists sp_cor_get_cart_products

go

CREATE proc [dbo].[sp_cor_get_cart_products]
   @cart_id int =null,
   @web_userid varchar(100)=null
As

--EXEC [sp_cor_get_cart_products]11263
--EXEC [sp_cor_get_cart_products]@web_userid='manand84'

BEGIN

   IF(isnull(@web_userid, '') <> '')
    BEGIN

       --declare @contact_id int = (select top 1 contact_id from contact where web_userid = @web_userid)
        set @cart_id = (select top 1 cart_id from orderheadercart where web_userid= @web_userid Order By Cart_id desc)
    END

   SELECT
            od.cart_id AS cart_id,
            od.line_id As line_id,
            p.product_ID As product_id,
            p.product_code As product_code,
            dbo.fn_retail_product_price(p.product_id, isnull(od.quantity, 1), null, null, getdate()) as product_quote_id_string,
            convert(int, NULL) as product_quote_id,
            od.quantity As quantity,
            od.price As price,
            p.description As description,
            p.summary_description,
            p.html_description,
            p.web_image_name_thumb As web_image_name_thumb,
            p.web_image_name_full As web_image_name_full,
            od.cor_flag,
            od.replenishment_flag
            INTO #tmp    
            FROM OrderDetailCart AS od
            INNER Join Product AS p ON od.product_ID = p.product_ID
            INNER Join OrderHeaderCart AS oh ON od.cart_id=oh.cart_id
            WHERE od.cart_id = @cart_id
            AND p.retail_flag = 'T'
            --AND p.view_on_web_flag = 'T'
            AND p.status = 'A'
            AND ISNULL(oh.credit_card_auth_id, '' ) = ''
            ORDER BY p.product_code, p.product_id, p.description

           UPDATE #tmp set
                product_quote_id = CONVERT(int, left(product_quote_id_string, CHARINDEX('#', product_quote_id_string)-1)),
                price = CONVERT(money, right(product_quote_id_string, LEN(product_quote_id_string) - CHARINDEX('#', product_quote_id_string)))

           SELECT *, (select sum(quantity) from #tmp) as total_count from #tmp

END   


GO

GRANT EXECUTE
    ON OBJECT::[dbo].sp_cor_get_cart_products TO [COR_USER]
    AS [dbo];

GO