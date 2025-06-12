-- drop proc sp_ContactCORProfileBucket_Maintain 
go

create proc sp_ContactCORProfileBucket_Maintain 
	@contact_id		int = null
	, @account_type	char(1) = null
	, @account_id	int = null
	, @operation	varchar(20) = null
AS
/*

SELECT  *  FROM    ContactXref WHERE  contact_id = 204309

SELECT  *  FROM    ContactCORProfileBucket 
WHERE contact_id = 204309
and customer_id  = 18459



sp_ContactCORProfileBucket_Maintain 

SELECT  *  FROM    
sp_ContactCORProfileBucket_Maintain 204309, 'C', 18459, 'add'

*/

BEGIN


	if exists (select 1 from sysobjects where name = 'xContactCORProfileBucket')
		drop table xContactCORProfileBucket;

	create table xContactCORProfileBucket (
		contactcorprofilebucket_uid		int not null identity(1,1) PRIMARY KEY,
		contact_id	int NOT NULL,
		profile_id	int NOT NULL,
		customer_id int NULL,
		generator_id int NULL,
		ap_expiration_date	datetime NULL,
		curr_status_code	char(1) NULL,
		prices		char(1) NOT NULL
	)
	
	CREATE INDEX [IX_ContactCORProfileBucket_contact_id] ON [dbo].xContactCORProfileBucket ([contact_id], [profile_id]) INCLUDE (prices, customer_id, generator_id, ap_expiration_date, curr_status_code)
	grant select on xContactCORProfileBucket to COR_USER
	grant select, insert, update, delete on xContactCORProfileBucket to EQAI

/* Direct Customer */
	insert xContactCORProfileBucket
	select x.contact_id, p.profile_id, p.customer_id, p.generator_id, p.ap_expiration_date, p.curr_status_code, 'T'
	from ContactCORCustomerBucket x (nolock) 
	join profile p (nolock) on x.customer_id = p.customer_id
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

/* Orig Customer */
	insert xContactCORProfileBucket
	select x.contact_id, p.profile_id, p.customer_id, p.generator_id, p.ap_expiration_date, p.curr_status_code, 'O' /* orig customer price */
	from CORcontactxref x (nolock) 
	join profile p (nolock) on x.customer_id = p.orig_customer_id
	inner join CORcontact c (nolock) on x.contact_id = c.contact_id and isnull(c.web_access_flag, 'F') in ('T', 'A') and c.contact_status = 'A'
	join customer cust on p.customer_id = cust.customer_id and cust.cust_status = 'A' and cust.terms_code <> 'NOADMIT'
	join customer ocust on p.orig_customer_id = ocust.customer_id and ocust.cust_status = 'A' and ocust.terms_code <> 'NOADMIT'
	where x.status = 'A' and x.web_access = 'A' and x.type = 'C'
	and not exists (
		select 1
		from xContactCORProfileBucket x2 (nolock) 
		where x2.contact_id = x.contact_id
		and x2.profile_id = p.profile_id
	)
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

/* Direct Generator */
	insert xContactCORProfileBucket
	select x.contact_id,  p.profile_id, p.customer_id, p.generator_id, p.ap_expiration_date, p.curr_status_code, 'F'
	from ContactCORGeneratorBucket x (nolock) 
	join profile p (nolock) on x.generator_id = p.generator_id
	where x.direct_flag = 'D'
	and not exists (
		select 1
		from xContactCORProfileBucket x2 (nolock) 
		where x2.contact_id = x.contact_id
		and x2.profile_id = p.profile_id
	)
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

/* Various Generator:  CustomerGenerator + ProfileGeneratorSiteType (PGST is a subset of CG connections) 

test case:

SELECT  *  FROM    contact WHERE  web_userid like 'pkgen%'
-- 210216
SELECT  *  FROM    contactxref WHERE contact_id = 210216
-- G: 35475
SELECT  *  FROM    ContactCORGeneratorBucket WHERE contact_id = 210216
-- G: 35475

SELECT  *  FROM    generator WHERE generator_id = 35475

SELECT  *  FROM    profile WHERE  generator_id = 35475 -- lots (522)
SELECT  *  FROM    ContactCORProfileBucket WHERE contact_id = 210216 -- hey, also 522.
-- Supposed to be a customergenerator connection for a profile...
SELECT  *  FROM    customergenerator WHERE generator_id = 35475
-- No.  but then...
select * from profile where profile_id = 68671
--update profile set generator_id = 0 where profile_id = 68671 
-- Now yes.
SELECT  *  FROM    customergenerator WHERE generator_id = 35475

SELECT  *  FROM    ContactCORGeneratorBucket WHERE contact_id = 210216

SELECT  *  FROM    profile WHERE customer_id in (select customer_id from customergenerator)
and generator_id = 0
and profile_id = 68671

-- So we add the logic below... Then retest

SELECT  *  FROM    profile WHERE  generator_id = 35475 -- lots (now 521, was 522 until we moved 1)
SELECT  *  FROM    ContactCORProfileBucket WHERE contact_id = 210216 -- Also 521.  Wrong.
and profile_id = 68671

*/
	insert xContactCORProfileBucket
	select distinct x.contact_id,  p.profile_id, p.customer_id, p.generator_id, p.ap_expiration_date, p.curr_status_code, 'F'
	from ContactCORGeneratorBucket x (nolock) 
	join CustomerGenerator cg on x.generator_id = cg.generator_id and x.direct_flag = 'D'
	join profile p (nolock) on cg.customer_id = p.customer_id
		and p.generator_id = 0
	where 1=1
-- and x.contact_id = 210216
-- and p.profile_id = 68671
	and not exists (
		select 1
		from xContactCORProfileBucket x2 (nolock) 
		where x2.contact_id = x.contact_id
		and x2.profile_id = p.profile_id
	)
		and x.contact_id = isnull(@contact_id, x.contact_id)
		and 1 = case when isnull(@operation, '') in ('', 'add') then
			case when isnull(@account_type, '') in ('', 'G') then
				1 
			else
				1
			end
		else
			1
		end
union
	select distinct b.contact_id, p.profile_id, p.customer_id, p.generator_id, p.ap_expiration_date, p.curr_status_code, 'F'
	FROM    Profile p (nolock)
	join ProfileGeneratorSiteType pgst (nolock)
		on p.profile_id = pgst.profile_id
		and p.generator_id = 0
	join generator g (nolock)on g.site_type = pgst.site_type
	join ContactCORGeneratorBucket b (nolock)
		on g.generator_id = b.generator_id
		and b.direct_flag = 'D'
	WHERE 
		not exists (
			select 1
			from xContactCORProfileBucket x2 (nolock) 
			where x2.contact_id = b.contact_id
			and x2.profile_id = p.profile_id
		)
		and b.contact_id = isnull(@contact_id, b.contact_id)
		and 1 = case when isnull(@operation, '') in ('', 'add') then
			case when isnull(@account_type, '') in ('', 'G') then
				1 
			else
				1
			end
		else
			1
		end

	BEGIN TRY
    BEGIN TRANSACTION

	--if (select count(*) from xContactCORProfileBucket) > 0 
	begin

		if @contact_id is null begin


				if exists (select 1 from sysobjects where name = 'ContactCORProfileBucket') 
					drop table ContactCORProfileBucket
			
				exec sp_rename xContactCORProfileBucket, ContactCORProfileBucket

		
		end else begin


				delete from ContactCORProfileBucket
				where contact_id = @contact_id

				insert ContactCORProfileBucket
				select 
					contact_id	,
					profile_id	,
					customer_id ,
					generator_id,
					ap_expiration_date,
					curr_status_code,
					prices		
				from xContactCORProfileBucket

				drop table xContactCORProfileBucket

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

				if exists (select 1 from sysobjects where name = 'xContactCORProfileBucket') 
					drop table xContactCORProfileBucket

return 0

END

GO

GRANT EXEC ON [dbo].[sp_ContactCORProfileBucket_Maintain] TO COR_USER;

GO

