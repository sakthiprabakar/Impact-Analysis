-- drop proc sp_ContactCOROrderBucket_Maintain 
go

create proc sp_ContactCOROrderBucket_Maintain 
	@contact_id		int = null
	, @account_type	char(1) = null
	, @account_id	int = null
	, @operation	varchar(20) = null
AS
/*

SELECT  COUNT(*)  FROM    ContactCOROrderBucket 
WHERE contact_id = 185547

sp_ContactCOROrderBucket_Maintain 

sp_ContactCOROrderBucket_Maintain 185547

*/

BEGIN


	if object_id('xContactCOROrderBucket') is not null 
		drop table xContactCOROrderBucket

	create table xContactCOROrderBucket (
		contactCOROrderBucket_uid		int not null identity(1,1) PRIMARY KEY,
		contact_id	int NOT NULL,
		order_id	int NOT NULL,
		company_id	int NOT NULL,
		profit_ctr_id  int NOT NULL,
		order_date datetime NULL,
		invoice_date	datetime NULL,
		prices		bit NOT NULL
	)
	
	CREATE INDEX [IX_ContactCOROrderBucket_contact_id] ON [dbo].xContactCOROrderBucket ([contact_id], [order_id], [company_id], [profit_ctr_id]) INCLUDE (order_date, invoice_date, prices)
	grant select on xContactCOROrderBucket to COR_USER
	grant select, insert, update, delete on xContactCOROrderBucket to EQAI

	if object_id('tempdb..#foo') is not null drop table #foo
	
	select c.contact_id into #foo 
	from CORcontact c (nolock) 
	where isnull(c.web_access_flag, 'F') in ('T', 'A') 
	and isnull(c.contact_status, 'I') = 'A'
	and c.contact_id = isnull(@contact_id, c.contact_id)
	and isnull(c.web_userid, '') <> ''

	insert xContactCOROrderBucket
	select distinct x.contact_id, r.order_id, d.company_id, d.profit_ctr_id, r.order_date,
	invoice_date = (
		select min(invoice_date) 
		from billing b
		WHERE b.receipt_id = r.order_id
		and b.company_id = d.company_id
		and b.profit_ctr_id = d.profit_ctr_id
		and b.trans_source = 'O'
		and b.status_code = 'I'
		),
	1 as prices
	from CORcontactxref x (nolock) 
	join #foo on #foo.contact_id = x.contact_id
	join orderheader r (nolock) on x.customer_id = r.customer_id
	join orderdetail d (nolock) on r.order_id = d.order_id
	join customer c on x.customer_id = c.customer_id and c.cust_status = 'A' and c.terms_code <> 'NOADMIT'
	where x.status = 'A' and x.web_access = 'A' and x.type = 'C'
	and r.order_id is not null and d.company_id is not null and d.profit_ctr_id is not null
	and not exists (
		Select 1 from xContactCOROrderBucket (nolock) 
		WHERE contact_id = x.contact_id
		and order_id = r.order_id
		and company_id = d.company_id
		and profit_ctr_id = d.profit_ctr_id
	)
	and x.contact_id = isnull(@contact_id, x.contact_id)

-- 2:12 6994004

-- delete from xContactCOROrderBucket WHERE prices = 0

	insert xContactCOROrderBucket
	select distinct x.contact_id, r.order_id, d.company_id, d.profit_ctr_id, r.order_date,
	invoice_date = (
		select min(invoice_date) 
		from billing b
		WHERE b.receipt_id = r.order_id
		and b.company_id = d.company_id
		and b.profit_ctr_id = d.profit_ctr_id
		and b.trans_source = 'O'
		and b.status_code = 'I'
		),
	0 as prices
	from #foo
	join CORcontactxref x (nolock) on #foo.contact_id = x.contact_id and x.status = 'A' and x.web_access = 'A' and x.type = 'G'
	-- join #foo on #foo.contact_id = x.contact_id 
	join orderheader r (nolock) on x.generator_id = r.generator_id
	join orderdetail d (nolock) on r.order_id = d.order_id
	where 1=1
	-- and x.contact_id in (select contact_id from #foo)
	-- and x.status = 'A' and x.web_access = 'A' and x.type = 'G'
	and r.order_id is not null and d.company_id is not null and d.profit_ctr_id is not null
	and not exists (
		Select 1 from xContactCOROrderBucket (nolock) 
		WHERE contact_id = x.contact_id
		and order_id = r.order_id
		and company_id = d.company_id
		and profit_ctr_id = d.profit_ctr_id
	)
	and x.contact_id = isnull(@contact_id, x.contact_id)
-- 55s, 1411061 rows	
	
	insert xContactCOROrderBucket
	select distinct x.contact_id, r.order_id, d.company_id, d.profit_ctr_id, r.order_date,
	invoice_date = (
		select min(invoice_date) 
		from billing b
		WHERE b.receipt_id = r.order_id
		and b.company_id = d.company_id
		and b.profit_ctr_id = d.profit_ctr_id
		and b.trans_source = 'O'
		and b.status_code = 'I'
		),
	0 as prices
	from #foo
	join CORcontactxref x (nolock) on #foo.contact_id = x.contact_id and x.status = 'A' and x.web_access = 'A' and x.type = 'C' 
	-- join #foo on #foo.contact_id = x.contact_id 
	join customer c on x.customer_id = c.customer_id and c.cust_status = 'A' and c.terms_code <> 'NOADMIT'
	join customergenerator cg (nolock) on x.customer_id = cg.customer_id   and 1=0 -- disable customergenerator access, but don't screw up existing code too much.
	join orderheader r (nolock) on cg.generator_id = r.generator_id
	join orderdetail d (nolock) on r.order_id = d.order_id
	where 1=1
	-- and x.contact_id in (select contact_id from #foo)
	-- and x.status = 'A' and x.web_access = 'A' and x.type = 'C' 
	and r.order_id is not null and d.company_id is not null and d.profit_ctr_id is not null
	and not exists (
		Select 1 from xContactCOROrderBucket (nolock) 
		WHERE contact_id = x.contact_id
		and order_id = r.order_id
		and company_id = d.company_id
		and profit_ctr_id = d.profit_ctr_id
	)
	and x.contact_id = isnull(@contact_id, x.contact_id)

-- INDIVIDUAL RESULTS:
-- 2:32 692680 rows.
-- Chicken Dinner.

-- UNION RESULTS:
-- 2112431 2:34.  No #foo at all.
-- 2103741 19:19. Ow. (joining to #foo)
-- 2103741 21:18 (where in)
-- 2103741 26:43 from #foo join xref

BEGIN TRY
    BEGIN TRANSACTION

	if (select count(*) from xContactCOROrderBucket) > 0 begin
		
		if @contact_id is null begin


				if exists (select 1 from sysobjects where name = 'ContactCOROrderBucket') 
					drop table ContactCOROrderBucket
		
				exec sp_rename xContactCOROrderBucket, ContactCOROrderBucket


		end else begin


				delete from ContactCOROrderBucket
				where contact_id = @contact_id

				insert ContactCOROrderBucket
				select 
					contact_id	,
					order_id	,
					company_id	,
					profit_ctr_id,
					order_date ,
					invoice_date,
					prices		
				from xContactCOROrderBucket

				drop table xContactCOROrderBucket

		end
	
	end

	update ContactCOROrderBucket set
		order_date = dateadd(m, -1, getdate()) 
		, invoice_date = dateadd(m, -1, getdate()) + 3 
	FROM    ContactCOROrderBucket b
	join orderheader h 
		on b.order_id = h.order_id 
	WHERE h.customer_id = 888880

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

GO

GRANT EXEC ON [dbo].[sp_ContactCOROrderBucket_Maintain] TO COR_USER;

GO