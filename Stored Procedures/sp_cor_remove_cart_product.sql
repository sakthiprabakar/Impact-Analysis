go

drop proc if exists sp_cor_remove_cart_product

go

CREATE proc [dbo].[sp_cor_remove_cart_product]
   @cart_id int,
   @product_id int = null
As
BEGIN

   if(@product_id is not null and @product_id > 0)
    begin
        Delete from OrderDetailCart WHERE cart_id=@cart_id and product_id=@product_id
    end

   if(@cart_id > 0 and (@product_id is null or @product_id <= 0))
    begin
        Delete from OrderHeaderCart WHERE cart_id=@cart_id
        Delete from OrderDetailCart WHERE cart_id=@cart_id
    end

   IF((SELECT COUNT(*) FROM OrderDetailCart where cart_id=@cart_id) =0)
    BEGIN
        Delete from OrderHeaderCart WHERE cart_id=@cart_id
    END

END

GO

GRANT EXECUTE ON [dbo].[sp_cor_remove_cart_product] TO COR_USER;

GO