-- drop proc sp_ContactCORCustomerBucket_Maintain 
go

create proc sp_ContactCORCustomerBucket_Maintain 
	@contact_id		int = null
	, @account_type	char(1) = null
	, @account_id	int = null
	, @operation	varchar(20) = null
AS
/*

SELECT  *  FROM    ContactCORCustomerBucket 
WHERE contact_id = 204309

sp_ContactCORCustomerBucket_Maintain 

sp_ContactCORCustomerBucket_Maintain  204309, 'C', 18459, 'add'

*/
BEGIN

	if exists (select 1 from sysobjects where name = 'xContactCORCustomerBucket')
		drop table xContactCORCustomerBucket;

	create table xContactCORCustomerBucket (
		contactcorcustomerbucket_uid		int not null identity(1,1) PRIMARY KEY,
		contact_id	int NOT NULL,
		customer_id	int NOT NULL
	)

	CREATE INDEX [IX_ContactCORCustomerBucket_contact_id] ON [dbo].[xContactCORCustomerBucket] ([contact_id], [customer_id])


	grant select on xContactCORCustomerBucket to COR_USER as dbo

	
	grant select, insert, update, delete on xContactCORCustomerBucket to EQAI as dbo



	insert xContactCORCustomerBucket
	select distinct x.contact_id, x.customer_id
	from CORContactxref x (nolock)
	inner join CORContact c (nolock) on x.contact_id = c.contact_id and isnull(c.web_access_flag, 'F') in ('T', 'A') and c.contact_status = 'A' and isnull(c.web_userid, '') <> ''
	-- should join to customer and only allow Active customers
	inner join customer cust on x.customer_id = cust.customer_id and cust.cust_status = 'A' and cust.terms_code <> 'NOADMIT'
	where x.status = 'A' and x.web_access = 'A' and x.type = 'C'
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

	--if 0 < (select count(*) from xContactCORCustomerBucket) 
	begin


		if @contact_id is null begin

				if exists (select 1 from sysobjects where name = 'ContactCORCustomerBucket') 
					drop table ContactCORCustomerBucket
		
				exec sp_rename xContactCORCustomerBucket, ContactCORCustomerBucket

		end else begin	
		
				delete from ContactCORCustomerBucket
				where contact_id = @contact_id

				insert ContactCORCustomerBucket
				select 
					contact_id,
					customer_id
				from xContactCORCustomerBucket

				drop table xContactCORCustomerBucket

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
	
	if exists (select 1 from sysobjects where name = 'xContactCORCustomerBucket') 
		drop table xContactCORCustomerBucket

return 0

END

GO

GRANT EXEC ON [dbo].[sp_ContactCORCustomerBucket_Maintain] TO COR_USER as dbo;

GO

