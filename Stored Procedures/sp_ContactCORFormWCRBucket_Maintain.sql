-- drop proc sp_ContactCORFormWCRBucket_Maintain 
go

create proc sp_ContactCORFormWCRBucket_Maintain 
	@contact_id		int = null
	, @account_type	char(1) = null
	, @account_id	int = null
	, @operation	varchar(20) = null
AS
/*

SELECT  *  FROM    Contactxref WHERE contact_id = 204309

SELECT  COUNT(*)  FROM    ContactCORFormWCRBucket 
WHERE contact_id = 11290
and generator_id = 123967

delete FROM    ContactCORFormWCRBucket 
WHERE contact_id = 11290

sp_ContactCORFormWCRBucket_Maintain 

sp_ContactCORFormWCRBucket_Maintain 11290

*/

BEGIN


	if exists (select 1 from sysobjects where name = 'xContactCORFormWCRBucket')
		drop table xContactCORFormWCRBucket;

	create table xContactCORFormWCRBucket (
		contactcorformwcrbucket_uid	int not null identity(1,1) primary key,
		contact_id	int not null,
		form_id		int	not null,
		revision_id	int not null,
		customer_id	int null,
		generator_id int null
	)

	CREATE INDEX [IX_ContactCORFormWCRBucket_contact_id] ON [dbo].xContactCORFormWCRBucket (contact_id, form_id, revision_id) include (customer_id, generator_id);
	grant select on xContactCORFormWCRBucket to COR_USER as dbo
	grant select, insert, update, delete on xContactCORFormWCRBucket to EQAI as dbo

	insert xContactCORFormWCRBucket
	select x.contact_id, f.form_id, f.revision_id, f.customer_id, f.generator_id
	from ContactCORCustomerBucket  x (nolock) 
	join formwcr f (nolock) on x.customer_id = f.customer_id
	where x.contact_id = isnull(@contact_id, x.contact_id)
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
	union
	select x.contact_id, f.form_id, f.revision_id, f.customer_id, f.generator_id
	from ContactCORGeneratorBucket x (nolock) 
	join formwcr f (nolock) on x.generator_id = f.generator_id
	where x.direct_flag = 'D'
	and x.contact_id = isnull(@contact_id, x.contact_id)
	and 1 = case when isnull(@operation, '') in ('', 'add') then
		case when isnull(@account_type, '') in ('', 'G') then
			case when isnull(@account_id, 0) in (x.generator_id, 0) then 
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
	union
	select c.contact_id, f.form_id, f.revision_id, f.customer_id, f.generator_id
	from CORcontact c join formwcr f on c.email = f.created_by
	and c.contact_id = isnull(@contact_id, c.contact_id)
	and 1 = case when isnull(@operation, '') in ('', 'add') then
		case when isnull(@account_type, '') in ('', 'G') then
			case when isnull(@account_id, 0) in (f.generator_id, 0) then 
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
		case when isnull(@account_type, '') in ('', 'C') then
			case when isnull(@account_id, 0) in (f.customer_id, 0) then 
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

	--if (select count(*) from xContactCORFormWCRBucket) > 0 
	begin

		if @contact_id is null begin


				if exists (select 1 from sysobjects where name = 'ContactCORFormWCRBucket') 
					drop table ContactCORFormWCRBucket
		
				exec sp_rename xContactCORFormWCRBucket, ContactCORFormWCRBucket


		end else begin


				delete from ContactCORFormWCRBucket
				where contact_id = @contact_id

				insert ContactCORFormWCRBucket
				select 
					contact_id	,
					form_id		,
					revision_id	,
					customer_id	,
					generator_id
				from xContactCORFormWCRBucket

				drop table xContactCORFormWCRBucket

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

		if exists (select 1 from sysobjects where name = 'xContactCORFormWCRBucket') 
			drop table xContactCORFormWCRBucket
	
return 0

END

GO

GRANT EXEC ON [dbo].[sp_ContactCORFormWCRBucket_Maintain] TO COR_USER as dbo;

GO

