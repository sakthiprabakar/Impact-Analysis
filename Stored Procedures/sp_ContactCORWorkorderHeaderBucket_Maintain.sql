-- drop proc sp_ContactCORWorkorderHeaderBucket_Maintain 
go

CREATE PROCEDURE sp_ContactCORWorkorderHeaderBucket_Maintain 
	@contact_id		int = null
	, @account_type	char(1) = null
	, @account_id	int = null
	, @operation	varchar(20) = null
AS
/*

-- drop table xContactCORWorkorderHeaderBucket 
SELECT  COUNT(*)  FROM    ContactCORWorkorderHeaderBucket 
WHERE contact_id = 185547

sp_ContactCORWorkorderHeaderBucket_Maintain 

sp_ContactCORWorkorderHeaderBucket_Maintain 210216
, 'G', 123968, 'add'

*/

BEGIN



DECLARE @today datetime = convert(date, getdate())


	-- Strategy: Instead of X joining contacts w workorder info and lots of updates, lets just pull 1 instance of each
	-- necessary workorder into a working table and do all the lookups on that smaller set
	-- Then split out by contact id's later.

	if exists (select 1 from sysobjects where name = 'xWorkorderHeaderBucket')
		drop table xWorkorderHeaderBucket;

	create table xWorkorderHeaderBucket (
		workorder_id	int NOT NULL,
		company_id	int NOT NULL,
		profit_ctr_id  int NOT NULL,
		start_date	datetime NULL,
		service_date	datetime NULL,
		requested_date	datetime NULL,
		scheduled_date	datetime NULL,
		report_status		varchar(20) NULL,
		invoice_date		datetime NULL,
		customer_id		int null,
		generator_id	int null,
		prices		bit NOT NULL,
		_start_date	datetime NULL,
		_end_date	datetime NULL,
		_date_act_arrive	datetime NULL,
		_updated bit not null
	)

	if object_id('tempdb..#range') is not null drop table #range
	
	-- declare 		@contact_id		int = null, @account_type	char(1) = null	, @account_id	int = null	, @operation	varchar(20) = null

	-- figure out what wo's we're interested in because they belong to a customer or generator id we must report:
	select 'C' as type, b.customer_id as _id, h.workorder_id, h.company_id, h.profit_ctr_id
	into #range
	from ContactCORCustomerBucket b
	join workorderheader h
		on b.customer_id = h.customer_id
		and h.workorder_id is not null and h.company_id is not null and h.profit_ctr_id is not null
		and h.workorder_status NOT IN ('V','X','T')
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
	union
	select 'G' as type, b.generator_id as _id, h.workorder_id, h.company_id, h.profit_ctr_id
	from ContactCORGeneratorBucket b
	join workorderheader h
		on b.generator_id = h.generator_id
		and b.direct_flag = 'D'
		and h.workorder_id is not null and h.company_id is not null and h.profit_ctr_id is not null
		and h.workorder_status NOT IN ('V','X','T')
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
	-- 1763266 rows, 3s.

	-- declare @contact_id int
	
	insert xWorkorderHeaderBucket (workorder_id, company_id, profit_ctr_id, customer_id, generator_id, start_date, service_date, requested_date, scheduled_date, invoice_date, prices, _start_date, _end_date, _date_act_arrive, _updated)
	SELECT h.workorder_id, h.company_id, h.profit_ctr_id, h.customer_id, h.generator_id, isnull(h.start_date, h.date_added), 
	coalesce(BillingComment.service_date, '1/1/1899') as service_date,
	wos.date_request_initiated as requested_date,
	wos.date_est_arrive as scheduled_date,
	null as invoice_date,
	--(select min(invoice_date) from billing bi (nolock)
	--	WHERE bi.receipt_id = h.workorder_id 
	--	and bi.company_id = h.company_id 
	--	and bi.profit_ctr_id = h.profit_ctr_id 
	--	and bi.trans_source = 'w' 
	--	and bi.status_code = 'I' ) as invoice_date,
	1 as prices, h.start_date, h.end_date, 
	wos.date_act_arrive, 0 as _updated
	from #range b (nolock)
	join Workorderheader h (nolock) 
		on b.workorder_id = h.workorder_id
		and b.company_id = h.company_id
		and b.profit_ctr_id = h.profit_ctr_id
	left join workorderstop wos (nolock) 
		on h.workorder_id = wos.workorder_id 
		and h.company_id = wos.company_id 
		and h.profit_ctr_id = wos.profit_ctr_id
		and wos.stop_sequence_id = 1 
		and wos.date_request_initiated is not null
	left join BillingComment (nolock)
		on BillingComment.receipt_id = h.workorder_id
		AND BillingComment.company_id = h.company_id
		AND BillingComment.profit_ctr_id = h.profit_ctr_id
		AND BillingComment.trans_source = 'W'
		AND BillingComment.service_date is not null
-- 1763266, 5s

	--SELECT  *  FROM    xWorkorderHeaderBucket

	update xWorkorderHeaderBucket
	set invoice_date =
		(select min(invoice_date) from billing bi (nolock)
		WHERE bi.receipt_id = h.workorder_id 
		and bi.company_id = h.company_id 
		and bi.profit_ctr_id = h.profit_ctr_id 
		and bi.trans_source = 'w' 
		and bi.status_code = 'I' ) 
	from xWorkorderHeaderBucket h
	WHERE invoice_date is null
-- 4s


	-- DECLARE @today datetime = convert(date, getdate())
	while exists (select 1 from xWorkorderHeaderBucket where _updated = 0) begin
	-- DECLARE @today datetime = convert(date, getdate())
		set rowcount 100000
		update xWorkorderHeaderBucket
		set report_status = case 
					when ((x.requested_date is not null and x.scheduled_date is null
						-- and not completed
						and not isnull(x._end_date, getdate()+1) <= @today and x.invoice_date is null)
						OR (x.requested_date is null and x.scheduled_date is null and x._end_date is null
						and x.scheduled_date is null and x._start_date is null))
							then 'Requested'
					when (x.scheduled_date is not null
						-- and not completed
						and not isnull(x._end_date, getdate()+1) <= @today and x.invoice_date is null)
							then 'Scheduled'
					when (isnull(x._date_act_arrive, getdate()+1) <= @today and x.invoice_date is null)
							then 'Completed'
					when (x.invoice_date is not null)
							then 'Invoiced'
					else
						'Unknown'
					end
			, _updated = 1
		from xWorkorderHeaderBucket x (nolock) 
		where x._updated = 0
		set rowcount 0
	end	
	-- 24s

	while exists (select 1 from xWorkorderHeaderBucket where service_date = '1/1/1899') begin
		set rowcount 100000

		update xWorkorderHeaderBucket
		set service_date = coalesce (
				wos.date_act_arrive
				, woh.start_date 
				, '1/2/1899'
			)
		FROM xWorkorderHeaderBucket woh
		LEFT OUTER JOIN WorkOrderStop wos (nolock) 
			ON wos.workorder_id = woh.workorder_id
			and wos.company_id = woh.company_id
			and wos.profit_ctr_id = woh.profit_ctr_id
			and wos.stop_sequence_id = 1 
		WHERE service_date = '1/1/1899'
		set rowcount 0
	end
	-- 1s

	if exists (select 1 from sysobjects where name = 'xContactCORWorkorderHeaderBucket')
		drop table xContactCORWorkorderHeaderBucket;

	create table xContactCORWorkorderHeaderBucket (
		ContactCorWorkorderHeaderBucket_uid		int not null identity(1,1) PRIMARY KEY,
		contact_id	int NOT NULL,
		workorder_id	int NOT NULL,
		company_id	int NOT NULL,
		profit_ctr_id  int NOT NULL,
		start_date	datetime NULL,
		service_date	datetime NULL,
		requested_date	datetime NULL,
		scheduled_date	datetime NULL,
		report_status		varchar(20) NULL,
		invoice_date		datetime NULL,
		customer_id		int null,
		generator_id	int null,
		prices		bit NOT NULL
	)
	
	CREATE INDEX [IX_ContactCORWorkorderHeaderBucket_contact_id] ON [dbo].xContactCORWorkorderHeaderBucket ([contact_id], [workorder_id], [company_id], [profit_ctr_id]) INCLUDE (start_date, service_date, requested_date, scheduled_date, report_status, invoice_date, customer_id, generator_id, prices)
	grant select on xContactCORWorkorderHeaderBucket to COR_USER
	grant select on xContactCORWorkorderHeaderBucket to CRM_Service
	grant select, insert, update, delete on xContactCORWorkorderHeaderBucket to EQAI

	insert xContactCORWorkorderHeaderBucket
		(contact_id, workorder_id, company_id, profit_ctr_id, start_date, service_date, requested_date, scheduled_date, report_status, invoice_date, customer_id, generator_id, prices)
	select distinct
		x.contact_id,
		d.workorder_id	,
		d.company_id	 ,
		d.profit_ctr_id , 
		d.start_date	,
		d.service_date,	
		d.requested_date,	
		d.scheduled_date,	
		d.report_status,	
		d.invoice_date,	
		d.customer_id	,	
		d.generator_id,	
		prices		 = 1
	from 
	xWorkorderHeaderBucket d
	join ContactCORCustomerBucket x
		on d.customer_id = x.customer_id
	WHERE x.contact_id = isnull(@contact_id, x.contact_id)

	insert xContactCORWorkorderHeaderBucket
		(contact_id, workorder_id, company_id, profit_ctr_id, start_date, service_date, requested_date, scheduled_date, report_status, invoice_date, customer_id, generator_id, prices)
	select distinct
		x.contact_id,
		d.workorder_id	,
		d.company_id	 ,
		d.profit_ctr_id , 
		d.start_date	,
		d.service_date,	
		d.requested_date,	
		d.scheduled_date,	
		d.report_status,	
		d.invoice_date,	
		d.customer_id	,	
		d.generator_id,	
		prices		 = 0
	from 
	xWorkorderHeaderBucket d
	join ContactCORGeneratorBucket x
		on d.generator_id = x.generator_id
		and x.direct_flag = 'D'
	LEFT JOIN xContactCORWorkorderHeaderBucket dup
		on x.contact_id = dup.contact_id
		and d.workorder_id = dup.workorder_id
		and d.company_id = dup.company_id
		and d.profit_ctr_id = dup.profit_ctr_id
		and dup.prices = 1
	WHERE x.contact_id = isnull(@contact_id, x.contact_id)
	and dup.contact_id is null
-- 8115542, 1m 50s

	drop table xWorkorderHeaderBucket

-- SELECT  TOP 10 *  FROM    xContactCORWorkorderHeaderBucket

	/*
	update xContactCORWorkorderHeaderBucket set 
		start_date  =    dateadd(m, -1, getdate())
		, service_date = dateadd(m, -1, getdate())
		, invoice_date = dateadd(m, -1, getdate()) +3 
	WHERE customer_id = 888880
	
	SELECT  TOP 10 *
	FROM    ContactCORWorkorderHeaderBucket
	*/
	update xContactCORWorkorderHeaderBucket set 
	-- select b.*,
		start_date = case when b.start_date is not null then x.start_date else null end
		, service_date = case when b.service_date is not null then x.start_date else null end
		, invoice_date = case when b.invoice_date is not null then x.invoice_date else null end
	from xContactCORWorkorderHeaderBucket b
	join (
		select ContactCORWorkorderHeaderBucket_uid
		,dateadd(m, -1, getdate()) - (7 * dense_rank() over (order by start_date desc)) start_date
		,dateadd(m, -1, getdate()) - (7 * dense_rank() over (order by start_date desc)) + 3 invoice_date	
		from xContactCORWorkorderHeaderBucket b
		WHERE b.customer_id = 888880
	) x on b.ContactCORWorkorderHeaderBucket_uid = x.ContactCORWorkorderHeaderBucket_uid
	WHERE b.customer_id = 888880


BEGIN TRY
    BEGIN TRANSACTION

-- if 0 < (select count(*) from xContactCORWorkorderHeaderBucket) 
begin
-- SELECT  top 1000 *  FROM    xContactCORWorkorderHeaderBucket



	if @contact_id is null begin


			if exists (select 1 from sysobjects where name = 'ContactCORWorkorderHeaderBucket')
				drop table ContactCORWorkorderHeaderBucket
		
			exec sp_rename xContactCORWorkorderHeaderBucket, ContactCORWorkorderHeaderBucket

	
	end else begin


			delete from ContactCORWorkorderHeaderBucket
			where contact_id = @contact_id

			insert ContactCORWorkorderHeaderBucket
				(
				contact_id	,
				workorder_id	,
				company_id	,
				profit_ctr_id  ,
				start_date	,
				service_date	,
				requested_date	,
				scheduled_date	,
				report_status	,
				invoice_date	,
				customer_id		,
				generator_id	,
				prices		
				)				
			select 
				contact_id	,
				workorder_id	,
				company_id	,
				profit_ctr_id  ,
				start_date	,
				service_date	,
				requested_date	,
				scheduled_date	,
				report_status	,
				invoice_date	,
				customer_id		,
				generator_id	,
				prices		
			from xContactCORWorkorderHeaderBucket

			drop table xContactCORWorkorderHeaderBucket


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

	if exists (select 1 from sysobjects where name = 'xContactCORWorkorderHeaderBucket')
		drop table xContactCORWorkorderHeaderBucket;

return 0


END

GO

GRANT EXEC ON [dbo].[sp_ContactCORWorkorderHeaderBucket_Maintain] TO COR_USER;

GO

