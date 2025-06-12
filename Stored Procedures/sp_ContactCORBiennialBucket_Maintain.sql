-- drop proc sp_ContactCORBiennialBucket_Maintain 
go

-- drop table xContactCORBiennialBucket

create proc sp_ContactCORBiennialBucket_Maintain 
	@contact_id		int = null
	, @account_type	char(1) = null
	, @account_id	int = null
	, @operation	varchar(20) = null
AS
/*


sp_ContactCORBiennialBucket_Maintain 11290
SELECT  *  FROM    ContactCORBiennialBucket WHERE contact_id = 11290

*/


BEGIN


/* Stolen from sp_ContactCORProfileBucket_Maintain */
	drop table if exists #ContactCORProfileBucket
	
	create table #ContactCORProfileBucket (
		contactcorprofilebucket_uid		int not null identity(1,1) PRIMARY KEY,
		contact_id	int NOT NULL,
		profile_id	int NOT NULL,
		customer_id int NULL,
		orig_customer_id	int NULL,
		generator_id int NULL,
		ap_expiration_date	datetime NULL,
		curr_status_code	char(1) NULL,
		prices		char(1) NOT NULL
	)
	
-- 	declare @contact_id		int = null	, @account_type	char(1) = null	, @account_id	int = null	, @operation	varchar(20) = null

	insert #ContactCORProfileBucket (contact_id, profile_id, customer_id, generator_id, ap_expiration_date, curr_status_code, prices)
	select contact_id, profile_id, customer_id, generator_id, ap_expiration_date, curr_status_code, prices
	from ContactCORProfileBucket x (nolock)
	WHERE x.contact_id = isnull(@contact_id, x.contact_id)
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
	

	
	update #ContactCORProfileBucket
	set orig_customer_id = p.orig_customer_id
	from #ContactCORProfileBucket b
	join profile p (nolock) on b.profile_id = b.profile_id
	
		
-- SELECT  *  FROM    #ContactCORProfileBucket


	drop table if exists #range
	
	-- figure out what wo's we're interested in because they belong to a customer or generator id we must report:
	select distinct 
		h.receipt_id
		, h.company_id
		, h.profit_ctr_id
		, h.customer_id
		-- , b.orig_customer_id
		,	convert(varchar(max), (
				select 
					',' + convert(varchar(20), q.orig_customer_id)
				from profile q
				where q.profile_id in (
					select profile_id
					from receipt h2
					where h2.receipt_id = h.receipt_id
					and h2.company_id = h.company_id
					and h2.profit_ctr_id = h.profit_ctr_id
					and h2.receipt_status not in ('V', 'R')
					and h2.fingerpr_status= 'A'
					and h2.trans_mode = 'I'
					and h2.trans_type = 'D'
				)
				and q.orig_customer_id is not null
				GROUP BY q.orig_customer_id
				order by q.orig_customer_id
				for xml path('')
			)+',') as orig_customer_id_list
		, h.generator_id
	into #range
	from #ContactCORProfileBucket b
	join receipt h
		on b.profile_id = h.profile_id
		and h.receipt_id is not null and h.company_id is not null and h.profit_ctr_id is not null
		and h.receipt_status not in ('V', 'R')
		and h.fingerpr_status = 'A'
		and h.trans_mode = 'I'
		and h.trans_type = 'D'
		and h.customer_id is not null
		and h.generator_id is not null
	-- 27511768 rows, 1:44
	-- 2337224 distinct rows, 0:8s

	DROP TABLE IF EXISTS #BadReceipts

	select receipt_id, company_id, profit_ctr_id, count(*) AS Cnt
	into #BadReceipts
	from (
		SELECT DISTINCT receipt_id, company_id, profit_ctr_id, customer_id, generator_id
		FROM dbo.Receipt
		WHERE receipt_status NOT IN ('V', 'R') AND trans_mode = 'I' AND trans_type = 'D' and receipt_id IS NOT NULL and fingerpr_status = 'A'
	) X
	group by receipt_id, company_id, profit_ctr_id
	having count(*) > 1

	delete from A
	-- select *
	from #range A
    inner join #BadReceipts B on A.receipt_id = B.receipt_id AND A.company_id = B.company_id AND A.profit_ctr_id = B.profit_ctr_id

	drop table if exists #range_contacts
	
	-- figure out what wo's we're interested in because they belong to a customer or generator id we must report:
	select distinct h.receipt_id, h.company_id, h.profit_ctr_id, b.contact_id
	into #range_contacts
	from #ContactCORProfileBucket b
	join receipt h
		on b.profile_id = h.profile_id
		and h.receipt_id is not null and h.company_id is not null and h.profit_ctr_id is not null
		and h.receipt_status not in ('V', 'R')
		and h.trans_mode = 'I'
		and h.trans_type = 'D'
		and h.fingerpr_status = 'A'
	-- 27511768 rows, 1:44
	-- 8315904 distinct rows 0:09
	

	-- drop table #ReceiptBucket
	drop table if exists #ReceiptBucket
	
	create table #ReceiptBucket (
		receipt_id	int NOT NULL,
		company_id	int NOT NULL,
		profit_ctr_id  int NOT NULL,
		receipt_date datetime NULL,
		pickup_date	datetime NULL,
		invoice_date	datetime NULL,
		customer_id	int null,
		orig_customer_id_list varchar(max) null,
		generator_id int null
	)	

	;with cte as (
	select x.receipt_id, x.company_id, x.profit_ctr_id, r.receipt_date,
	null as pickup_date,
	null as invoice_date,
	x.customer_id, x.orig_customer_id_list, x.generator_id
	,         ROW_NUMBER() OVER (PARTITION BY x.receipt_id, x.company_id, x.profit_ctr_id ORDER BY r.line_id) AS rn
	from #range x
	join receipt r (nolock) 
		on x.receipt_id = r.receipt_id
		and x.company_id = r.company_id
		and x.profit_ctr_id = r.profit_ctr_id
		and r.trans_mode = 'I'
		and r.trans_type = 'D'
		and r.receipt_status not in ('V', 'R')
		and r.fingerpr_status = 'A' 
	--group by 
	--x.contact_id, r.receipt_id, r.company_id, r.profit_ctr_id, r.receipt_date,
	--r.customer_id, r.generator_id
-- 1:08 9282681
	)
	insert #ReceiptBucket (
		receipt_id	,
		company_id	,
		profit_ctr_id,
		receipt_date ,
		pickup_date	,
		invoice_date,
		customer_id	,
		orig_customer_id_list,
		generator_id 
		)
	SELECT 
		receipt_id	,
		company_id	,
		profit_ctr_id,
		receipt_date ,
		pickup_date	,
		invoice_date,
		customer_id	,
		orig_customer_id_list,
		generator_id 
	FROM cte
	WHERE rn = 1

	-- 2314998 rows, 0:9

	update #ReceiptBucket set
	pickup_date = b.pickup_date
	, invoice_date = b.invoice_date
	from #ReceiptBucket r
	join ContactCORReceiptBucket b
		on r.receipt_id = b.receipt_id
		and r.company_id = b.company_id
		and r.profit_ctr_id = b.profit_ctr_id

	
	drop table if exists xContactCORBiennialBucket

	create table xContactCORBiennialBucket (
		contactcorbiennialbucket_uid		int not null identity(1,1) PRIMARY KEY,
		contact_id	int NOT NULL,
		receipt_id	int NOT NULL,
		company_id	int NOT NULL,
		profit_ctr_id  int NOT NULL,
		receipt_date datetime NULL,
		pickup_date	datetime NULL,
		invoice_date	datetime NULL,
		customer_id	int null,
		orig_customer_id_list varchar(max) null,
		generator_id int null,
		-- , min_line_id	int not null
	)
	
	CREATE INDEX [IX_ContactCORBiennialBucket_contact_id] ON [dbo].xContactCORBiennialBucket ([contact_id], [receipt_id], [company_id], [profit_ctr_id]) INCLUDE (receipt_date, pickup_date, invoice_date, customer_id, orig_customer_id_list, generator_id)
	grant select on xContactCORBiennialBucket to COR_USER
	grant select on xContactCORBiennialBucket to CRM_Service
	grant select, insert, update, delete on xContactCORBiennialBucket to EQAI

	insert xContactCORBiennialBucket
	(
		contact_id	,
		receipt_id	,
		company_id	,
		profit_ctr_id ,
		receipt_date ,
		pickup_date	,
		invoice_date,
		customer_id	,
		orig_customer_id_list,
		generator_id 
	)
	select 
		x.contact_id,
		d.receipt_id	,
		d.company_id	,
		d.profit_ctr_id ,
		d.receipt_date ,
		d.pickup_date	,
		d.invoice_date,
		d.customer_id	,
		d.orig_customer_id_list,
		d.generator_id 
	from 
	#ReceiptBucket d
	join #range_contacts x on 
		d.receipt_id = x.receipt_id
		and d.company_id = x.company_id
		and d.profit_ctr_id = x.profit_ctr_id
	-- 8315904 rows  1:11


--	drop table xReceiptBucket
BEGIN TRY
    BEGIN TRANSACTION
	
	--if 0 < (select count(*) from xContactCORBiennialBucket) 
	begin
		
		if @contact_id is null begin


				if exists (select 1 from sysobjects where name = 'ContactCORBiennialBucket') 
					drop table ContactCORBiennialBucket
		
				exec sp_rename xContactCORBiennialBucket, ContactCORBiennialBucket

	
		end else begin


				delete from ContactCORBiennialBucket
				where contact_id = @contact_id

				insert ContactCORBiennialBucket (
					contact_id,
					receipt_id,
					company_id,
					profit_ctr_id  ,
					receipt_date ,
					pickup_date	,
					invoice_date	,
					customer_id	,
					orig_customer_id_list,
					generator_id 
				) 
				select 
					contact_id,
					receipt_id,
					company_id,
					profit_ctr_id  ,
					receipt_date ,
					pickup_date	,
					invoice_date	,
					customer_id	,
					orig_customer_id_list,
					generator_id 
				from xContactCORBiennialBucket

				drop table xContactCORBiennialBucket

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

if exists (select 1 from sysobjects where name = 'xContactCORBiennialBucket') 
	drop table xContactCORBiennialBucket

return 0

END

GO

GRANT EXEC ON [dbo].[sp_ContactCORBiennialBucket_Maintain] TO COR_USER;

GO

