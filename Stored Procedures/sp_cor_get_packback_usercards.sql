go

drop proc if exists sp_cor_get_packback_usercards

go

CREATE proc [dbo].[sp_cor_get_packback_usercards] @web_userid nvarchar(100)
AS
BEGIN
  SET NOCOUNT ON;
  SELECT
    web_userid,
    StripeCustomerToken stripe_customer_token,
    StripeCustomerCardToken credit_card_auth_id
  FROM cor_db.dbo.UserXStripeCustomer UC
  INNER JOIN cor_db.dbo.StripeCustomerXCards SC
    ON SC.UserXStripeId = UC.UserXStripeId
  WHERE web_userid = @web_userid AND ISNULL(StripeCustomerToken,'')<>'' AND ISNULL(StripeCustomerCardToken,'')<>''
END

GO

    GRANT EXECUTE ON [dbo].[sp_cor_get_packback_usercards] TO COR_USER;

GO