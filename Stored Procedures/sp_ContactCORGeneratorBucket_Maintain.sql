-- drop proc sp_ContactCORGeneratorBucket_Maintain 
go

create proc sp_ContactCORGeneratorBucket_Maintain 
	@contact_id		int = null
	, @account_type	char(1) = null
	, @account_id	int = null
	, @operation	varchar(20) = null
AS
/*

SELECT  *  FROM    ContactXref WHERE contact_id = 204309

SELECT  *  FROM    ContactCORGeneratorBucket 
WHERE contact_id = 204309
and generator_id = 123967

sp_ContactCORGeneratorBucket_Maintain 

sp_ContactCORGeneratorBucket_Maintain 204309

sp_ContactCORGeneratorBucket_Maintain 204309, 'G', 123967, 'add'

*/

BEGIN

if isnull(@operation, '') = 'remove' and isnull(@account_type, '') in ('C', 'G') and isnull(@account_id, 0)<> 0 and isnull(@contact_id, 0) <> 0
BEGIN
	BEGIN TRY
		BEGIN TRANSACTION

		delete from ContactCORGeneratorBucket
		where contact_id = @contact_id
		and 1 = case when isnull(@account_type, '') = 'G' and generator_id = isnull(@account_id, 0) then 1 else
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


	if exists (select 1 from sysobjects where name = 'xContactCORGeneratorBucket')
		drop table xContactCORGeneratorBucket;

	create table xContactCORGeneratorBucket (
		contactcorgeneratorbucket_uid		int not null identity(1,1) PRIMARY KEY,
		contact_id	int NOT NULL,
		generator_id	int NOT NULL,
		direct_flag	char(1) NOT NULL
	)

	CREATE INDEX [IX_ContactCORGeneratorBucket_contact_id] ON [dbo].xContactCORGeneratorBucket ([contact_id], [generator_id])
	grant select on xContactCORGeneratorBucket to COR_USER
	grant select, insert, update, delete on xContactCORGeneratorBucket to EQAI

	insert xContactCORGeneratorBucket
	select x.contact_id, x.generator_id, 'D' as direct_flag
	from CORContactxref x (nolock)
	inner join CORContact c (nolock) on x.contact_id = c.contact_id and isnull(c.web_access_flag, 'F') in ('T', 'A') and c.contact_status = 'A' and isnull(c.web_userid, '') <> ''
	where x.status = 'A' and x.web_access = 'A' and x.type = 'G'
	and x.contact_id = isnull(@contact_id, x.contact_id)
	and x.generator_id is not null
	--and 1 = case when isnull(@operation, '') in ('', 'add') then
	--	case when isnull(@account_type, '') in ('', 'G') then
	--		case when isnull(@account_id, 0) in (x.generator_id, 0) then 
	--			1 
	--		else
	--			0
	--		end
	--	else
	--		1
	--	end
	--else
	--	1
	--end
	union
	select x.contact_id, cg.generator_id, 'I' as direct_flag
	from CORContactxref x (nolock)
	inner join CORContact c (nolock) on x.contact_id = c.contact_id and isnull(c.web_access_flag, 'F') in ('T', 'A') and c.contact_status = 'A' and isnull(c.web_userid, '') <> ''
	join customergenerator cg (nolock) on x.customer_id = cg.customer_id   
	-- and 1=0 -- disable customergenerator access, but don't screw up existing code too much.
	-- 2/7/20 - don't want to limit this in the bucket table.
	where x.status = 'A' and x.web_access = 'A' and x.type = 'C'
	and x.contact_id = isnull(@contact_id, x.contact_id)
	and cg.generator_id is not null
	--and 1 = case when isnull(@operation, '') in ('', 'add') then
	--	case when isnull(@account_type, '') in ('', 'G') then
	--		case when isnull(@account_id, 0) in (x.generator_id, 0) then 
	--			1 
	--		else
	--			0
	--		end
	--	else
	--		1
	--	end
	--else
	--	1
	--end

BEGIN TRY
    BEGIN TRANSACTION

	--if (select count(*) from xContactCORGeneratorBucket) > 0 
	begin

		if @contact_id is null begin

				if exists (select 1 from sysobjects where name = 'ContactCORGeneratorBucket') 
					drop table ContactCORGeneratorBucket
		
				exec sp_rename xContactCORGeneratorBucket, ContactCORGeneratorBucket


		end else begin


				delete from ContactCORGeneratorBucket
				where contact_id = @contact_id

				insert ContactCORGeneratorBucket
				select 
					contact_id	,
					generator_id,
					direct_flag	
				from xContactCORGeneratorBucket

				drop table xContactCORGeneratorBucket

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

	if exists (select 1 from sysobjects where name = 'xContactCORGeneratorBucket') 
		drop table xContactCORGeneratorBucket


return 0

END

GO

GRANT EXEC ON [dbo].[sp_ContactCORGeneratorBucket_Maintain] TO COR_USER;

GO