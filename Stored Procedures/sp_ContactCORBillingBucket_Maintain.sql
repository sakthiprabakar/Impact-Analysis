-- drop proc sp_ContactCORBillingBucket_Maintain 
go

create proc sp_ContactCORBillingBucket_Maintain 
	@contact_id		int = null
	, @account_type	char(1) = null
	, @account_id	int = null
	, @operation	varchar(20) = null
AS
/*

SELECT  COUNT(*)  FROM    ContactCORBillingBucket 
WHERE contact_id = 204309

sp_ContactCORBillingBucket_Maintain 

sp_ContactCORBillingBucket_Maintain  204309, 'C', 18459, 'add'

SELECT  TOP 10 *  FROM    ContactCORBillingBucket

*/

BEGIN

if isnull(@operation, '') = 'remove' and isnull(@account_type, '') in ('C', 'G') and isnull(@account_id, 0)<> 0 and isnull(@contact_id, 0) <> 0
BEGIN
	BEGIN TRY
		BEGIN TRANSACTION

		delete from ContactCORBillingBucket
		where contact_id = @contact_id
		and 1 = case when isnull(@account_type, '') = 'C' and customer_id = isnull(@account_id, 0) then 1 else
			0
		end

		COMMIT TRAN -- Transaction Success!
	END TRY
	BEGIN CATCH
		IF @@TRANCOUNT > 0
			ROLLBACK TRAN --RollBack in case of Error

		-- you can Raise ERROR with RAISEERROR() Statement including the details of the exception
		-- RAISERROR(ERROR_MESSAGE(), ERROR_SEVERITY(), 1)
	END CATCH
	return 0
END

	if exists (select 1 from sysobjects where name = 'xContactCORBillingBucket')
		drop table xContactCORBillingBucket;

	create table xContactCORBillingBucket (
		contactcorbillingbucket_uid		int not null identity(1,1) PRIMARY KEY,
		contact_id	int NOT NULL,
		receipt_id	int NOT NULL,
		company_id	int NOT NULL,
		profit_ctr_id  int NOT NULL,
		trans_source	char(1) NOT NULL,
		customer_id		int	NULL,
		generator_id	int NULL,
		status_code		char(1)
	)

	CREATE INDEX [IX_ContactCORBillingBucket_contact_id] ON [dbo].[xContactCORBillingBucket] ([contact_id], [receipt_id], [company_id], [profit_ctr_id], [trans_source]) INCLUDE (customer_id, generator_id, status_code)
	grant select on xContactCORBillingBucket to COR_USER as dbo
	grant select, insert, update, delete on xContactCORBillingBucket to EQAI as dbo


	insert xContactCORBillingBucket (contact_id, receipt_id, company_id, profit_ctr_id, trans_source, customer_id, generator_id, status_code)
	select distinct x.contact_id, b.receipt_id, b.company_id, b.profit_ctr_id, b.trans_source, b.customer_id, b.generator_id, b.status_code
	from ContactCORCustomerBucket x (nolock) 
	join billing b (nolock) on x.customer_id = b.customer_id
	where b.receipt_id is not null and b.company_id is not null and b.profit_ctr_id is not null
	and x.contact_id = isnull(@contact_id, x.contact_id)
	and 1 = case when isnull(@operation, '') in ('', 'add') then
		case when isnull(@account_type, '') in ('', 'C') then
			case when isnull(@account_id, 0) in (x.customer_id, 0) then 
				1 
			else
				0
			end
		else
			1
		end
	else
		1
	end


BEGIN TRY
	BEGIN TRANSACTION

	-- if 0 < (select count(*) from xContactCORBillingBucket) 
	begin


		if @contact_id is null begin
		
				 if exists (select 1 from sysobjects where name = 'ContactCORBillingBucket') 
					 drop table ContactCORBillingBucket
			
				exec sp_rename xContactCORBillingBucket, ContactCORBillingBucket
			
		end else begin	
		
				delete from ContactCORBillingBucket
				where contact_id = @contact_id

				insert ContactCORBillingBucket
				select 
					contact_id,
					receipt_id,
					company_id,
					profit_ctr_id,
					trans_source,
					customer_id,
					generator_id,
					trans_source
				from xContactCORBillingBucket

				drop table xContactCORBillingBucket
			
		end

	end

    COMMIT TRAN -- Transaction Success!
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
        ROLLBACK TRAN --RollBack in case of Error

    -- you can Raise ERROR with RAISEERROR() Statement including the details of the exception
    -- RAISERROR(ERROR_MESSAGE(), ERROR_SEVERITY(), 1)
END CATCH
	
		if exists (select 1 from sysobjects where name = 'xContactCORBillingBucket')
		drop table xContactCORBillingBucket;

return 0

END

GO
		    
	GRANT EXEC ON [dbo].[sp_ContactCORBillingBucket_Maintain] TO COR_USER as dbo;

GO

