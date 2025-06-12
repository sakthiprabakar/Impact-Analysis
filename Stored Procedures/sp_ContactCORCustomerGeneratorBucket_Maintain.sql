-- drop proc sp_ContactCORCustomerGeneratorBucket_Maintain 
go

create proc sp_ContactCORCustomerGeneratorBucket_Maintain 
	@contact_id		int = null
	, @account_type	char(1) = null
	, @account_id	int = null
	, @operation	varchar(20) = null
AS
/*


SELECT  *  FROM    Contactxref WHERE contact_id = 204309

SELECT  * FROM    ContactCORCustomerGeneratorBucket 
WHERE contact_id = 204309
and customer_id  = 18459

sp_ContactCORCustomerGeneratorBucket_Maintain 

sp_ContactCORCustomerGeneratorBucket_Maintain 204309, 'C', 18459, 'add'

*/

BEGIN

	if exists (select 1 from sysobjects where name = 'xContactCORCustomerGeneratorBucket')
		drop table xContactCORCustomerGeneratorBucket;

	create table xContactCORCustomerGeneratorBucket (
		_uid		int not null identity(1,1) PRIMARY KEY,
		contact_id	int NOT NULL,
		customer_id	int NOT NULL,
		generator_id int NOT NULL
	)

	CREATE INDEX [IX_ContactCORCustomerGeneratorBucket_contact_id] ON [dbo].[xContactCORCustomerGeneratorBucket] ([contact_id], [customer_id], [generator_id])
	grant select on xContactCORCustomerGeneratorBucket to COR_USER as dbo
	grant select, insert, update, delete on xContactCORCustomerGeneratorBucket to EQAI as dbo

	/* Not used, so cutting out the time consuming parts

	insert xContactCORCustomerGeneratorBucket
	select distinct x.contact_id, x.customer_id, cg.generator_id
	from CORcontactxref x (nolock)
	inner join CORcontact c (nolock) on x.contact_id = c.contact_id and isnull(c.web_access_flag, 'F') in ('T', 'A') and c.contact_status = 'A'
	inner join Customer cust on x.customer_id = cust.customer_id and cust.cust_status = 'A' and cust.terms_code <> 'NOADMIT'
	inner join CustomerGenerator cg on x.customer_id = cg.customer_id   
		--and 1=0 -- disable customergenerator access, but don't screw up existing code too much.
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
	*/

BEGIN TRY
	BEGIN TRANSACTION

	-- if 0 < (select count(*) from xContactCORCustomerGeneratorBucket) 
	begin


		if @contact_id is null begin



				if exists (select 1 from sysobjects where name = 'ContactCORCustomerGeneratorBucket') 
					drop table ContactCORCustomerGeneratorBucket
		
				exec sp_rename xContactCORCustomerGeneratorBucket, ContactCORCustomerGeneratorBucket

		end else begin

				delete from ContactCORCustomerGeneratorBucket
				where contact_id = @contact_id

				insert ContactCORCustomerGeneratorBucket
				select 
					contact_id	,
					customer_id	,
					generator_id
				from xContactCORCustomerGeneratorBucket

				drop table xContactCORCustomerGeneratorBucket
	

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

				if exists (select 1 from sysobjects where name = 'xContactCORCustomerGeneratorBucket') 
					drop table xContactCORCustomerGeneratorBucket

return 0

END

GO

GRANT EXEC ON [dbo].[sp_ContactCORCustomerGeneratorBucket_Maintain] TO COR_USER as dbo;

GO

