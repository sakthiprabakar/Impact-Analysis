-- drop proc sp_ContactCORReceiptBucket_Maintain 
go

-- drop table xContactCORReceiptBucket

create proc sp_ContactCORReceiptBucket_Maintain 
	@contact_id		int = null
	, @account_type	char(1) = null
	, @account_id	int = null
	, @operation	varchar(20) = null
AS
/*

SELECT  COUNT(*)  FROM    ContactCORReceiptBucket 
WHERE contact_id = 185547

sp_ContactCORReceiptBucket_Maintain 

sp_ContactCORReceiptBucket_Maintain 185547

SELECT  *  FROM    ContactCORReceiptBucket 
WHERE contact_id = 204309
and customer_id = 15622

sp_ContactCORReceiptBucket_Maintain 

sp_ContactCORReceiptBucket_Maintain 210216
, 'G', 123968, 'add'

-- before rewrite: 3:05: 12467440 rows
-- after rewrite: 1:55: 12467329

SELECT  COUNT(*)  FROM    
ContactCORReceiptBucket

-- A case where a Kroger receipt (doesn't belong to Kroger customer#)
-- is getting snuck in for Kroger users - should not contain prices.
SELECT  * FROM    ContactCORREceiptBucket
WHERE receipt_id = 2078347 and company_id = 21 -- Should appear with 4507 and 15940 customers
and contact_id = 175531	-- but for this users should only appear for 15940, and no prices.

2020-05-21 Adjusted to fix omitted Kroger-connected accessors.


*/

BEGIN

	-- Strategy: Instead of X joining contacts w workorder info and lots of updates, lets just pull 1 instance of each
	-- necessary workorder into a working table and do all the lookups on that smaller set
	-- Then split out by contact id's later.

	-- declare 		@contact_id		int = null, @account_type	char(1) = null	, @account_id	int = null	, @operation	varchar(20) = null

	drop table if exists #range
	
	-- figure out what wo's we're interested in because they belong to a customer or generator id we must report:
	select distinct h.receipt_id, h.company_id, h.profit_ctr_id, h.customer_id, h.generator_id
	into #range
	from ContactCORCustomerBucket b
	join receipt h
		on b.customer_id = h.customer_id
		and h.receipt_id is not null and h.company_id is not null and h.profit_ctr_id is not null
		and h.receipt_status not in ('V', 'R')
		and h.fingerpr_status = 'A'
		and h.trans_mode = 'I'
		and h.trans_type = 'D'
		and h.customer_id is not null
		and h.generator_id is not null
	WHERE b.contact_id = isnull(@contact_id, b.contact_id)
	and 1 = 
		case when isnull(@operation, '') in ('', 'add') then
			case when isnull(@account_type, '') in ('', 'C') then
				case when isnull(@account_id, 0) in (b.customer_id, 0) then 
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
	
	-- declare 		@contact_id		int = null, @account_type	char(1) = null	, @account_id	int = null	, @operation	varchar(20) = null
	
	insert #range
	select distinct h.receipt_id, h.company_id, h.profit_ctr_id, h.customer_id, h.generator_id
	from ContactCORGeneratorBucket b
	join receipt h
		on b.generator_id = h.generator_id
		and b.direct_flag = 'D'
		and h.receipt_id is not null and h.company_id is not null and h.profit_ctr_id is not null
		and h.receipt_status not in ('V', 'R')
		and h.fingerpr_status = 'A'
		and h.trans_mode = 'I'
		and h.trans_type = 'D'
		and h.customer_id is not null
		and h.generator_id is not null
	WHERE b.contact_id = isnull(@contact_id, b.contact_id)
	and 1 = 
		case when isnull(@operation, '') in ('', 'add') then
			case when isnull(@account_type, '') in ('', 'G') then
				case when isnull(@account_id, 0) in (b.generator_id, 0) then 
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
	and not exists (
		select 1 from #range r
		where r.receipt_id = h.receipt_id
		and r.company_id = h.company_id
		and r.profit_ctr_id = h.profit_ctr_id
	)
	-- 3080486 rows, 16s.
	
	-- declare 		@contact_id		int = null, @account_type	char(1) = null	, @account_id	int = null	, @operation	varchar(20) = null

	drop table if exists #KrogerReceipts
	
	-- Kroger relation from workorder on trip to receipt
	select distinct rh.receipt_id, rh.company_id, rh.profit_ctr_id, woh.customer_id, woh.generator_id, b.workorder_id, b.company_id w_company_id, b.profit_ctr_id w_profit_ctr_id
	into #KrogerReceipts
	FROM ContactCORWorkorderHeaderBucket b
	JOIN TripStopRate on b.customer_id = TripStopRate.customer_id
	JOIN WorkorderHeader woh
		ON b.workorder_id = woh.workorder_id
		and b.company_id = woh.company_id
		and b.profit_ctr_id = woh.profit_ctr_id
		and woh.trip_stop_rate_flag = 'T'
	JOIN TripHeader
		ON TripHeader.trip_id = woh.trip_id
		AND isnull(woh.trip_stop_rate_flag,'F') = 'T'
	join ReceiptHeader rh
		ON woh.trip_id = rh.trip_id
		AND woh.trip_sequence_id = rh.trip_sequence_id
		AND rh.customer_id in (select customer_id from customer where isnull(eq_flag, '') = 'T')
	join Receipt r
		ON rh.receipt_id = r.receipt_id
		AND rh.company_id = r.company_id
		and rh.profit_ctr_id= r.profit_ctr_id
		and r.generator_id = woh.generator_id
		and r.receipt_id is not null and r.company_id is not null and r.profit_ctr_id is not null
		and r.receipt_status not in ('V', 'R')
		and r.fingerpr_status = 'A'
		and r.trans_mode = 'I'
		and r.trans_type = 'D' -- not a receiptheader field
		and r.customer_id is not null
	WHERE b.contact_id = isnull(@contact_id, b.contact_id)
	and 1 = 
		case when isnull(@operation, '') in ('', 'add') then
			case when isnull(@account_type, '') in ('', 'G') then
				case when isnull(@account_id, 0) in (b.generator_id, 0) then 
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


	-- declare 		@contact_id		int = null, @account_type	char(1) = null	, @account_id	int = null	, @operation	varchar(20) = null
	insert #range
	select distinct r.receipt_id, r.company_id, r.profit_ctr_id, b.customer_id, b.generator_id
	FROM #KrogerReceipts b
	JOIN Receipt r
		ON r.receipt_id = b.receipt_id
		and r.company_id = b.company_id
		and r.profit_ctr_id = b.profit_ctr_id
		and r.generator_id = b.generator_id
		and r.receipt_id is not null and r.company_id is not null and r.profit_ctr_id is not null
		and r.receipt_status not in ('V', 'R')
		and r.fingerpr_status = 'A'
		and r.trans_mode = 'I'
		and r.trans_type = 'D' -- not a receiptheader field
		and r.customer_id is not null
	where not exists (
		select 1 from #range r2
		where r2.receipt_id = b.receipt_id
		and r2.company_id = b.company_id
		and r2.profit_ctr_id = b.profit_ctr_id
	)


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
	from #range A
    inner join #BadReceipts B on A.receipt_id = B.receipt_id AND A.company_id = B.company_id AND A.profit_ctr_id = B.profit_ctr_id
  
	drop table if exists xReceiptBucket

	create table xReceiptBucket (
		receipt_id	int NOT NULL,
		company_id	int NOT NULL,
		profit_ctr_id  int NOT NULL,
		receipt_date datetime NULL,
		pickup_date	datetime NULL,
		invoice_date	datetime NULL,
		customer_id	int null,
		generator_id int null,
	)	

	;with cte as (
	select x.receipt_id, x.company_id, x.profit_ctr_id, r.receipt_date,
	null as pickup_date,
	null as invoice_date,
	x.customer_id, x.generator_id
	,         ROW_NUMBER() OVER (PARTITION BY x.receipt_id, x.company_id, x.profit_ctr_id ORDER BY x.receipt_id) AS rn
	from #range x
	join receipt r (nolock) 
		on x.receipt_id = r.receipt_id
		and x.company_id = r.company_id
		and x.profit_ctr_id = r.profit_ctr_id
		and r.trans_mode = 'I'
		and r.trans_type = 'D'
		and r.customer_id is not null
		and r.generator_id is not null
	group by 
	x.receipt_id, x.company_id, x.profit_ctr_id, r.receipt_date,
		x.customer_id, x.generator_id
-- 1:08 9282681
	)
	insert xReceiptBucket (
		receipt_id	,
		company_id	,
		profit_ctr_id,
		receipt_date ,
		pickup_date	,
		invoice_date,
		customer_id	,
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
		generator_id 
	FROM cte
	WHERE rn = 1 -- THIS is removing rows that are not the first/only _type,
		-- which is why there are not 'W' type rows getting inserted later. HA.  Oof.

	
	update xReceiptBucket
	set pickup_date = (Select min(rm.generator_sign_date) from receiptmanifest rm
	 where rm.receipt_id = r.receipt_id
	 and rm.company_id = r.company_id
	 and rm.profit_ctr_id = r.profit_ctr_id
	 and rm.generator_sign_date is not null
	)
	from xReceiptBucket r

	update xReceiptBucket
	set invoice_date = (
		select min(invoice_date) 
		from billing b
		WHERE b.receipt_id = r.receipt_id
		and b.company_id = r.company_id
		and b.profit_ctr_id = r.profit_ctr_id
		and b.trans_source = 'R'
		and b.status_code = 'I'
		)
	from xReceiptBucket r

	update xReceiptBucket set pickup_date = rt1.transporter_sign_date
	from xReceiptBucket r join ReceiptTransporter rt1
		on r.receipt_id = rt1.receipt_id
		and r.company_id = rt1.company_id
		and r.profit_ctr_id = rt1.profit_ctr_id
		and rt1.transporter_sequence_id = 1
	where r.pickup_date is null
	and rt1.transporter_sign_date is not null


	drop table if exists xContactCORReceiptBucket

	create table xContactCORReceiptBucket (
		contactcorreceiptbucket_uid		int not null identity(1,1) PRIMARY KEY,
		contact_id	int NOT NULL,
		receipt_id	int NOT NULL,
		company_id	int NOT NULL,
		profit_ctr_id  int NOT NULL,
		receipt_date datetime NULL,
		pickup_date	datetime NULL,
		invoice_date	datetime NULL,
		customer_id	int null,
		generator_id int null,
		prices		bit NOT NULL
		-- , min_line_id	int not null
	)

	CREATE INDEX [IX_ContactCORReceiptBucket_contact_id] ON [dbo].xContactCORReceiptBucket ([contact_id], [receipt_id], [company_id], [profit_ctr_id]) INCLUDE (receipt_date, pickup_date, invoice_date, prices, customer_id, generator_id)
	grant select on xContactCORReceiptBucket to COR_USER
	grant select on xContactCORReceiptBucket to CRM_Service
	grant select, insert, update, delete on xContactCORReceiptBucket to EQAI

	-- declare 		@contact_id		int = null, @account_type	char(1) = null	, @account_id	int = null	, @operation	varchar(20) = null
	insert xContactCORReceiptBucket
	(
		contact_id	,
		receipt_id	,
		company_id	,
		profit_ctr_id ,
		receipt_date ,
		pickup_date	,
		invoice_date,
		customer_id	,
		generator_id ,
		prices		
	)
	-- declare 		@contact_id		int = null, @account_type	char(1) = null	, @account_id	int = null	, @operation	varchar(20) = null
	select
		x.contact_id,
		d.receipt_id	,
		d.company_id	,
		d.profit_ctr_id ,
		d.receipt_date ,
		d.pickup_date	,
		d.invoice_date,
		d.customer_id	,
		d.generator_id ,
		prices		 = 1
	from 
	xReceiptBucket d
	join ContactCORCustomerBucket x
		on d.customer_id = x.customer_id
	WHERE x.contact_id = isnull(@contact_id, x.contact_id)

	-- declare 		@contact_id		int = null, @account_type	char(1) = null	, @account_id	int = null	, @operation	varchar(20) = null
	insert xContactCORReceiptBucket
	(
		contact_id	,
		receipt_id	,
		company_id	,
		profit_ctr_id ,
		receipt_date ,
		pickup_date	,
		invoice_date,
		customer_id	,
		generator_id ,
		prices		
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
		d.generator_id ,
		prices		 = 0
	from 
	xReceiptBucket d
	join ContactCORGeneratorBucket x
		on d.generator_id = x.generator_id
		and x.direct_flag = 'D'
	WHERE x.contact_id = isnull(@contact_id, x.contact_id)
	and not exists (
		select 1 from xContactCORReceiptBucket b
		where contact_id = x.contact_id
		and receipt_id = d.receipt_id
		and company_id = d.company_id
		and profit_ctr_id = d.profit_ctr_id 
	)

	-- declare 		@contact_id		int = null, @account_type	char(1) = null	, @account_id	int = null	, @operation	varchar(20) = null
	insert xContactCORReceiptBucket
	(
		contact_id	,
		receipt_id	,
		company_id	,
		profit_ctr_id ,
		receipt_date ,
		pickup_date	,
		invoice_date,
		customer_id	,
		generator_id ,
		prices		
	)
	select distinct
		x.contact_id,
		d.receipt_id	,
		d.company_id	,
		d.profit_ctr_id ,
		d.receipt_date ,
		d.pickup_date	,
		d.invoice_date,
		x.customer_id	,
		d.generator_id ,
		prices		 = 0
	from 
	xReceiptBucket d
	join ReceiptHeader r
		on d.receipt_id = r.receipt_id
		and d.company_id = r.company_id
		and d.profit_ctr_id = r.profit_ctr_id
	join TripHeader th
		on r.trip_id = th.trip_id
	join WorkorderHeader wh
		on r.trip_id = wh.trip_id
		and r.trip_sequence_id = wh.trip_sequence_id
		AND isnull(wh.trip_stop_rate_flag,'F') = 'T'
		and d.generator_id = wh.generator_id
	join ContactCORWorkorderheaderBucket x
		on wh.workorder_id= x.workorder_id
		and wh.company_id = x.company_id
		and wh.profit_ctr_id = x.profit_ctr_id
		and d.generator_id = x.generator_id
	WHERE not exists (
		select 1 
		from xContactCORReceiptBucket r2
		WHERE r2.receipt_id = d.receipt_id
		and r2.company_id = d.company_id
		and r2.profit_ctr_id = d.profit_ctr_id
		and r2.contact_id = x.contact_id
	)
	and 
	x.contact_id = isnull(@contact_id, x.contact_id)


	drop table if exists xReceiptBucket


	/*
	update xContactCORReceiptBucket set 
		receipt_date = dateadd(m, -1, getdate())
		, pickup_date = dateadd(m, -1, getdate())-3
		, invoice_date = dateadd(m, -1, getdate()) + 3 
	WHERE customer_id = 888880
	*/
	

	update xContactCORReceiptBucket set 
	-- select b.*,
		receipt_date = case when b.receipt_date is not null then x.receipt_date else null end
		, pickup_date = case when b.pickup_date is not null then x.pickup_date else null end
		, invoice_date = case when b.invoice_date is not null then x.invoice_date else null end
	from xContactCORReceiptBucket b
	join (
		select contactcorreceiptbucket_uid
		,dateadd(m, -1, getdate()) - (5 * dense_rank() over (order by receipt_date, receipt_id desc)) receipt_date
		,dateadd(m, -1, getdate()) - (5 * dense_rank() over (order by receipt_date, receipt_id desc)) -3 pickup_date
		,dateadd(m, -1, getdate()) - (5 * dense_rank() over (order by receipt_date, receipt_id desc)) + 3 invoice_date	
		from xContactCORReceiptBucket b
		WHERE b.customer_id = 888880
	) x on b.contactcorreceiptbucket_uid = x.contactcorreceiptbucket_uid
	WHERE b.customer_id = 888880

	---- delete from xContactCORReceiptBucket
	--select x.*
	--from ContactCORReceiptBucket x
	--join (
	--	select contact_id, receipt_id, company_id, profit_ctr_id
	--	from ContactCORReceiptBucket a
	--	GROUP BY contact_id, receipt_id, company_id, profit_ctr_id
	--	having count(distinct customer_id) > 1 
	--	or count(distinct generator_id) > 1
	--) d on
	--	x.contact_id = d.contact_id
	--	and x.receipt_id = d.receipt_id
	--	and x.company_id = d.company_id
	--	and x.profit_ctr_id = d.profit_ctr_id
	
BEGIN TRY
    BEGIN TRANSACTION
	
	--if 0 < (select count(*) from xContactCORReceiptBucket) 
	begin
		
		if @contact_id is null begin


				if exists (select 1 from sysobjects where name = 'ContactCORReceiptBucket') 
					drop table ContactCORReceiptBucket
		
				exec sp_rename xContactCORReceiptBucket, ContactCORReceiptBucket

	
		end else begin


				delete from ContactCORReceiptBucket
				where contact_id = @contact_id

				insert ContactCORReceiptBucket
				select 
					contact_id,
					receipt_id,
					company_id,
					profit_ctr_id  ,
					receipt_date ,
					pickup_date	,
					invoice_date	,
					customer_id	,
					generator_id ,
					prices	
				from xContactCORReceiptBucket

				drop table xContactCORReceiptBucket

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

if exists (select 1 from sysobjects where name = 'xContactCORReceiptBucket') 
	drop table xContactCORReceiptBucket

return 0

END

GO

GRANT EXEC ON [dbo].[sp_ContactCORReceiptBucket_Maintain] TO COR_USER;

GO
