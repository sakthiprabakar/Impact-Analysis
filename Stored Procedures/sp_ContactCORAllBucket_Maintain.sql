-- drop proc sp_ContactCORAllBucket_Maintain
go

CREATE PROCEDURE [dbo].[sp_ContactCORAllBucket_Maintain]
	@contact_id		int = null
	, @account_type	char(1) = null
	, @account_id	int = null
	, @operation	varchar(20) = null
AS
/*

SELECT  *  FROM    contact WHERE web_userid = 'zachery.wright'
exec sp_ContactCORAllBucket_Maintain 208252

*/

	if @contact_id is null RETURN 0

	exec sp_ContactCORCustomerBucket_Maintain @contact_id --, @account_type, @account_id, @operation
	exec sp_ContactCORGeneratorBucket_Maintain @contact_id --, @account_type, @account_id, @operation
	exec sp_ContactCORCustomerGeneratorBucket_Maintain @contact_id --, @account_type, @account_id, @operation
	-- exec sp_ContactCORGeneratorCustomerBucket_Maintain @contact_id --, @account_type, @account_id, @operation
	exec sp_ContactCORFormWCRBucket_Maintain @contact_id, @account_type --, @account_id, @operation
	exec sp_ContactCORProfileBucket_Maintain @contact_id, @account_type --, @account_id, @operation
	-- exec sp_ContactCOROrderBucket_Maintain @contact_id, @account_type, @account_id, @operation
	exec sp_ContactCORReceiptBucket_Maintain @contact_id --, @account_type, @account_id, @operation
	exec sp_ContactCORWorkorderHeaderBucket_Maintain @contact_id --, @account_type, @account_id, @operation
	exec sp_ContactCORBillingBucket_Maintain @contact_id --, @account_type, @account_id, @operation
	exec sp_ContactCORInvoiceBucket_Maintain @contact_id -- , @account_type, @account_id, @operation
	exec sp_ContactCORBiennialBucket_Maintain @contact_id --, @account_type, @account_id, @operation
	
RETURN 0

go

grant execute on sp_ContactCORAllBucket_Maintain to cor_user
go
grant execute on sp_ContactCORAllBucket_Maintain to eqai
go
grant execute on sp_ContactCORAllBucket_Maintain to eqweb
go
