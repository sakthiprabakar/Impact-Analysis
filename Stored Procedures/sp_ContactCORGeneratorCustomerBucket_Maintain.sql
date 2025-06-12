-- drop proc sp_ContactCORGeneratorCustomerBucket_Maintain
go

create proc sp_ContactCORGeneratorCustomerBucket_Maintain 
	@contact_id		int = null
	, @account_type	char(1) = null
	, @account_id	int = null
	, @operation	varchar(20) = null
AS
/*

SELECT  *  FROM    CORcontactxref WHERE contact_id = 204309
and generator_id = 123967

SELECT   * FROM    ContactCORGeneratorCustomerBucket 
WHERE contact_id = 204309
and generator_id = 123967

SELECT  COUNT(*)  FROM    ContactCORGeneratorCustomerBucket

sp_ContactCORGeneratorCustomerBucket_Maintain 

sp_ContactCORGeneratorCustomerBucket_Maintain  204309, 'G', 123967, 'add'

*/

BEGIN

/* This isn't used anywhere, so cutting time out of creating it 


if isnull(@operation, '') = 'remove' and isnull(@account_type, '') in ('C', 'G') and isnull(@account_id, 0)<> 0 and isnull(@contact_id, 0) <> 0
BEGIN
	BEGIN TRY
		BEGIN TRANSACTION

		delete from ContactCORGeneratorCustomerBucket
		where contact_id = @contact_id
		and 1 = case when isnull(@account_type, '') = 'C' and customer_id = isnull(@account_id, 0) then 1 else
			case when isnull(@account_type, '') = 'G' and generator_id = isnull(@account_id, 0) then 1 else
				0
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
	return 0
END


	if exists (select 1 from sysobjects where name = 'xContactCORGeneratorCustomerBucket')
		drop table xContactCORGeneratorCustomerBucket;

	create table xContactCORGeneratorCustomerBucket (
		contactcorgeneratorcustomerbucket_uid		int not null identity(1,1) PRIMARY KEY,
		contact_id	int NOT NULL,
		generator_id int NOT NULL,
		customer_id	int NOT NULL
	)

	CREATE INDEX [IX_ContactCORGeneratorCustomerBucket_contact_id] ON [dbo].[xContactCORGeneratorCustomerBucket] ([contact_id], [generator_id], [customer_id])
	grant select on xContactCORGeneratorCustomerBucket to COR_USER
	grant select, insert, update, delete on xContactCORGeneratorCustomerBucket to EQAI


	select generator_id, customer_id 
	into #foo
	from billing where status_code = 'I'
	and (
		@contact_id is null
		or
		(
		customer_id in (select customer_id from ContactCORCustomerBucket where contact_id = @contact_id)
		or
		generator_id in (select generator_id from ContactCORGeneratorBucket where contact_id = @contact_id)
		)
	)
	and 1 = case when isnull(@operation, '') in ('', 'add') then
		case when isnull(@account_type, '') in ('', 'C') then
			case when isnull(@account_id, 0) in (customer_id, 0) then 
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
	and 1 = case when isnull(@operation, '') in ('', 'add') then
		case when isnull(@account_type, '') in ('', 'G') then
			case when isnull(@account_id, 0) in (generator_id, 0) then 
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


	insert xContactCORGeneratorCustomerBucket
	select distinct x.contact_id, f.generator_id, f.customer_id
	from CORcontactxref x 
	inner join CORcontact c (nolock) on x.contact_id = c.contact_id and isnull(c.web_access_flag, 'F') in ('T', 'A') and c.contact_status = 'A'
	join #foo f on x.customer_id = f.customer_id
	where x.status = 'A' and x.web_access = 'A' and x.type = 'C'
	and f.generator_id is not null and f.customer_id is not null
	and x.contact_id = isnull(@contact_id, x.contact_id)
	union
	select distinct x.contact_id, f.generator_id, f.customer_id
	from CORcontactxref x 
	inner join CORcontact c (nolock) on x.contact_id = c.contact_id and isnull(c.web_access_flag, 'F') in ('T', 'A') and c.contact_status = 'A'
	join #foo f on x.generator_id = f.generator_id
	where x.status = 'A' and x.web_access = 'A' and x.type = 'G'
	and f.generator_id is not null and f.customer_id is not null
	and x.contact_id = isnull(@contact_id, x.contact_id)

BEGIN TRY
    BEGIN TRANSACTION

	if (select count(*) from xContactCORGeneratorCustomerBucket) > 0 begin

		if @contact_id is null begin


				if exists (select 1 from sysobjects where name = 'ContactCORGeneratorCustomerBucket') 
					drop table ContactCORGeneratorCustomerBucket
		
				exec sp_rename xContactCORGeneratorCustomerBucket, ContactCORGeneratorCustomerBucket

	
			end else begin


					delete from ContactCORGeneratorCustomerBucket
					where contact_id = @contact_id

					insert ContactCORGeneratorCustomerBucket
					select 
						contact_id	,
						generator_id,
						customer_id	
					from xContactCORGeneratorCustomerBucket

					drop table xContactCORGeneratorCustomerBucket

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

	if exists (select 1 from sysobjects where name = 'xContactCORGeneratorCustomerBucket') 
		drop table xContactCORGeneratorCustomerBucket


*/

return 0

END

go

grant execute on sp_ContactCORGeneratorCustomerBucket_Maintain  to eqai, eqweb

go
