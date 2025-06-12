--CREATE PROC sp_workorder_migrate (
--	@company_id		int,
--	@profit_ctr_id	int,
--	@workorder_id	int
--)
--as
--/* **************************************************************************

--Moves a workorder to a new company, profitcenter, workorder_id
--part of GL Standardization.

--1/13/2012 - JPB  Created

---- Moving Workorders to the destination copcs:
--Create a migration SP...
--	in: co, pc, wo_id
--	out: new co, new pc, new wo_id

--only these:
--	21-3 -> 21-0 
--	15-2 -> 15-0
--	15-3 -> 15-0
--only unsubmitted records.

--SELECT  *  FROM    WorkorderHeader where company_id = 21 and profit_ctr_id = 3
--sp_workorder_migrate 21, 3, 100000000000 - Fails because it doesn't exist
--sp_workorder_migrate 21, 3, 100000000000 - Fails because it's already submitted
--sp_workorder_migrate 21, 3, 423300 -- Works


--Unsubmit & migrate these per code below:
--SELECT  'sp_billing_unsubmit 1, ' + convert(varchar(2), w.company_id) + ', ' + convert(varchar(2), w.profit_ctr_id) + ', ' + convert(varchar(20), w.workorder_id) + ', ''W'', ''JONATHAN''', 
--'sp_workorder_migrate ' + convert(varchar(2), w.company_id) + ', ' + convert(varchar(2), w.profit_ctr_id) + ', ' + convert(varchar(20), w.workorder_id),
--*  FROM    Workorderheader w where company_id = 21 and w.start_date > '1/1/2011'  and not exists (
--	SELECT  *  FROM    billing where receipt_id = w.workorder_id and company_id = w.company_id and profit_ctr_id = w.profit_ctr_id and status_code = 'I'
--) and w.workorder_status not in ('T', 'V') and w.profit_ctr_id = 3
--and (select count(*) from workorderdetail where workorder_id = w.workorder_id and company_id = w.company_id and profit_ctr_id = w.profit_ctr_id and print_on_invoice_flag = 'T') > 0
--union
--SELECT  'sp_billing_unsubmit 1, ' + convert(varchar(2), w.company_id) + ', ' + convert(varchar(2), w.profit_ctr_id) + ', ' + convert(varchar(20), w.workorder_id) + ', ''W'', ''JONATHAN''', 
--'sp_workorder_migrate ' + convert(varchar(2), w.company_id) + ', ' + convert(varchar(2), w.profit_ctr_id) + ', ' + convert(varchar(20), w.workorder_id),
--*  FROM    Workorderheader w where company_id = 15 and w.start_date > '1/1/2011'  and not exists (
--	SELECT  *  FROM    billing where receipt_id = w.workorder_id and company_id = w.company_id and profit_ctr_id = w.profit_ctr_id and status_code = 'I'
--) and w.workorder_status not in ('T', 'V') and w.profit_ctr_id = 2
--and (select count(*) from workorderdetail where workorder_id = w.workorder_id and company_id = w.company_id and profit_ctr_id = w.profit_ctr_id and print_on_invoice_flag = 'T') > 0
--union
--SELECT  'sp_billing_unsubmit 1, ' + convert(varchar(2), w.company_id) + ', ' + convert(varchar(2), w.profit_ctr_id) + ', ' + convert(varchar(20), w.workorder_id) + ', ''W'', ''JONATHAN''', 
--'sp_workorder_migrate ' + convert(varchar(2), w.company_id) + ', ' + convert(varchar(2), w.profit_ctr_id) + ', ' + convert(varchar(20), w.workorder_id),
--*  FROM    Workorderheader w where company_id = 15 and w.start_date > '1/1/2011' and not exists (
--	SELECT  *  FROM    billing where receipt_id = w.workorder_id and company_id = w.company_id and profit_ctr_id = w.profit_ctr_id and status_code = 'I'
--) and w.workorder_status not in ('T', 'V') and w.profit_ctr_id = 3
--and (select count(*) from workorderdetail where workorder_id = w.workorder_id and company_id = w.company_id and profit_ctr_id = w.profit_ctr_id and print_on_invoice_flag = 'T') > 0


--RUN THESE FOR EACH WO TO PROCESS:
--sp_billing_unsubmit 1, 21, 3, 423300, 'W', 'JONATHAN'
--sp_workorder_migrate 21, 3, 423300 -- Works

--select * from profitcenter where company_id = 21
--update profitcenter set next_workorder_id = 11691 where company_id = 21 and profit_ctr_id = 0

--sp_billing_unsubmit 1, 15, 3, 319300, 'W', 'JONATHAN'
--sp_billing_unsubmit 1, 21, 3, 411100, 'W', 'JONATHAN'
--sp_billing_unsubmit 1, 21, 3, 411500, 'W', 'JONATHAN'
--sp_billing_unsubmit 1, 21, 3, 411600, 'W', 'JONATHAN'
--sp_billing_unsubmit 1, 21, 3, 416900, 'W', 'JONATHAN'
--sp_billing_unsubmit 1, 21, 3, 417900, 'W', 'JONATHAN'
--sp_billing_unsubmit 1, 21, 3, 418200, 'W', 'JONATHAN'
--sp_billing_unsubmit 1, 21, 3, 419300, 'W', 'JONATHAN'
--sp_billing_unsubmit 1, 21, 3, 419400, 'W', 'JONATHAN'
--sp_billing_unsubmit 1, 21, 3, 419800, 'W', 'JONATHAN'
--sp_billing_unsubmit 1, 21, 3, 420100, 'W', 'JONATHAN'
--sp_billing_unsubmit 1, 21, 3, 420200, 'W', 'JONATHAN'
--sp_billing_unsubmit 1, 21, 3, 421100, 'W', 'JONATHAN'
--sp_billing_unsubmit 1, 21, 3, 421200, 'W', 'JONATHAN'
--sp_billing_unsubmit 1, 21, 3, 421300, 'W', 'JONATHAN'
--sp_billing_unsubmit 1, 21, 3, 421400, 'W', 'JONATHAN'
--sp_billing_unsubmit 1, 21, 3, 421500, 'W', 'JONATHAN'
--sp_billing_unsubmit 1, 21, 3, 421600, 'W', 'JONATHAN'
--sp_billing_unsubmit 1, 21, 3, 421700, 'W', 'JONATHAN'
--sp_billing_unsubmit 1, 21, 3, 422000, 'W', 'JONATHAN'
--sp_billing_unsubmit 1, 21, 3, 422100, 'W', 'JONATHAN'
--sp_billing_unsubmit 1, 21, 3, 422200, 'W', 'JONATHAN'
--sp_billing_unsubmit 1, 21, 3, 422300, 'W', 'JONATHAN'
--sp_billing_unsubmit 1, 21, 3, 422400, 'W', 'JONATHAN'
--sp_billing_unsubmit 1, 21, 3, 422500, 'W', 'JONATHAN'
--sp_billing_unsubmit 1, 21, 3, 422800, 'W', 'JONATHAN'
--sp_billing_unsubmit 1, 21, 3, 423200, 'W', 'JONATHAN'
--sp_billing_unsubmit 1, 21, 3, 423400, 'W', 'JONATHAN'
--sp_billing_unsubmit 1, 21, 3, 423500, 'W', 'JONATHAN'
--sp_billing_unsubmit 1, 21, 3, 423600, 'W', 'JONATHAN'

--SELECT  max(workorder_id)  FROM    workorderheader where company_id = 21 and profit_ctr_id = 0
--SELECT  max(workorder_id)  FROM    workorderdetail where company_id = 21 and profit_ctr_id = 0

--sp_workorder_migrate 15, 3, 319300
--sp_workorder_migrate 21, 3, 411100
--SELECT  *  FROM    GLSTD_Workorder_Migration

--sp_workorder_migrate 21, 3, 411500
--sp_workorder_migrate 21, 3, 411600
--sp_workorder_migrate 21, 3, 416900
--sp_workorder_migrate 21, 3, 417900
--sp_workorder_migrate 21, 3, 418200
--sp_workorder_migrate 21, 3, 419300
--sp_workorder_migrate 21, 3, 419400
--sp_workorder_migrate 21, 3, 419800
--sp_workorder_migrate 21, 3, 420100
--sp_workorder_migrate 21, 3, 420200
--sp_workorder_migrate 21, 3, 421100
--sp_workorder_migrate 21, 3, 421200
--sp_workorder_migrate 21, 3, 421300
--sp_workorder_migrate 21, 3, 421400
--sp_workorder_migrate 21, 3, 421500
--sp_workorder_migrate 21, 3, 421600
--sp_workorder_migrate 21, 3, 421700
--sp_workorder_migrate 21, 3, 422000
--sp_workorder_migrate 21, 3, 422100
--sp_workorder_migrate 21, 3, 422200
--sp_workorder_migrate 21, 3, 422300
--sp_workorder_migrate 21, 3, 422400
--sp_workorder_migrate 21, 3, 422500
--sp_workorder_migrate 21, 3, 422800
--sp_workorder_migrate 21, 3, 423200
--sp_workorder_migrate 21, 3, 423400
--sp_workorder_migrate 21, 3, 423500
--sp_workorder_migrate 21, 3, 423600

--************************************************************************** */

---- Make sure it exists in a valid co/pc.
--	if not exists (
--		select 1 from workorderheader w
--		where w.company_id = @company_id
--		and w.profit_ctr_ID = @profit_ctr_id
--		and w.workorder_ID = @workorder_id
--		and (
--			(w.company_id = 15 and w.profit_ctr_ID = 2)
--			or
--			(w.company_id = 15 and w.profit_ctr_ID = 3)
--			or
--			(w.company_id = 21 and w.profit_ctr_ID = 3)
--		)		
--	)
--	begin
--		select 'Workorder not found in 15-2, 15-3 or 21-3' as error
--		return
--	end

---- Make sure it isn't billed/invoiced yet.
--	if exists (
--		select 1 from workorderheader w
--		where w.company_id = @company_id
--		and w.profit_ctr_ID = @profit_ctr_id
--		and w.workorder_ID = @workorder_id
--		and w.submitted_flag = 'T'
--		UNION
--		select 1 from workorderheader w
--		where w.company_id = @company_id
--		and w.profit_ctr_ID = @profit_ctr_id
--		and w.workorder_ID = @workorder_id
--		and exists (
--			SELECT 1 from Billing b
--			where b.receipt_id = w.workorder_ID
--			and b.company_id = w.company_id
--			and b.profit_ctr_id = w.profit_ctr_ID
--			and b.trans_source = 'W'
--		)
--	)
--	begin
--		select 'Cannot move Workorders that are already submitted or invoiced' as error
--		return
--	end

---- Still here?  Proceed.
--declare @new_company_id int, @new_profit_ctr_id int, @new_workorder_id int

--BEGIN TRY
--	BEGIN TRANSACTION

--	-- Get the next workorder id, increment the profitcenter table.
--	if @company_id = 15 and (@profit_ctr_id = 2 or @profit_ctr_id = 3) begin
--		select @new_company_id = 15,
--			@new_profit_ctr_id = 0,
--			@new_workorder_id = next_workorder_id * 100
--			FROM    ProfitCenter 
--			where company_ID = 15 and profit_ctr_ID = 0
			
--			update ProfitCenter 
--				SET next_workorder_ID = next_workorder_ID + 1 
--			where company_ID = 15 and profit_ctr_ID = 0
--	end

--	if @company_id = 21 and @profit_ctr_id = 3 begin
--		select @new_company_id = 21,
--			@new_profit_ctr_id = 0,
--			@new_workorder_id = next_workorder_id * 100
--			FROM    ProfitCenter 
--			where company_ID = 21 and profit_ctr_ID = 0
			
--			update ProfitCenter 
--				SET next_workorder_ID = next_workorder_ID + 1 
--			where company_ID = 21 and profit_ctr_ID = 0
--	end

--	print 'New Company ID      : ' + convert(varchar(20), @new_company_id)
--	print 'New Profit Center ID: ' + convert(varchar(20), @new_profit_ctr_id)
--	print 'New Work Order ID   : ' + convert(varchar(20), @new_workorder_id)

--	-- Start updating hither and yon (every table that contains a workorder_id)
--/*
--	update ChangeLog	
--		set workorder_id = @new_workorder_id, company_id = @new_company_id, profit_ctr_id = @new_profit_ctr_id
--	where workorder_id = @workorder_id and company_id = @company_id and profit_ctr_id = @profit_ctr_id
--*/

--	INSERT GLSTD_Workorder_Migration
--	SELECT @workorder_id, @company_id, @profit_ctr_id, @new_workorder_id, @new_company_id, @new_profit_ctr_id, getdate()
	
--	update Note	
--		set workorder_id = @new_workorder_id, company_id = @new_company_id, profit_ctr_id = @new_profit_ctr_id
--	where workorder_id = @workorder_id and company_id = @company_id and profit_ctr_id = @profit_ctr_id

--	update OppDocument	
--		set workorder_id = @new_workorder_id, company_id = @new_company_id, profit_ctr_id = @new_profit_ctr_id
--	where workorder_id = @workorder_id and company_id = @company_id and profit_ctr_id = @profit_ctr_id

--	update OppNote	
--		set workorder_id = @new_workorder_id, company_id = @new_company_id, profit_ctr_id = @new_profit_ctr_id
--	where workorder_id = @workorder_id and company_id = @company_id and profit_ctr_id = @profit_ctr_id

--	insert ReceiptAudit 
--		select distinct company_id, Profit_ctr_id, receipt_id, NULL, NULL, 'ReceiptHeader', 'workorder_id', convert(varchar(20), workorder_id), convert(varchar(20), @new_workorder_id), NULL, system_user, 'sp_workorder_migrate', getdate()
--		from ReceiptHeader where workorder_id = @workorder_id and workorder_company_id = @company_id and workorder_profit_ctr_id = @profit_ctr_id
--		union
--		select distinct company_id, Profit_ctr_id, receipt_id, NULL, NULL, 'ReceiptHeader', 'workorder_company_id', convert(varchar(20), workorder_company_id), convert(varchar(20), @new_company_id), NULL, system_user, 'sp_workorder_migrate', getdate()
--		from ReceiptHeader where workorder_id = @workorder_id and workorder_company_id = @company_id and workorder_profit_ctr_id = @profit_ctr_id and workorder_company_id <> @new_company_id
--		union
--		select distinct company_id, Profit_ctr_id, receipt_id, NULL, NULL, 'ReceiptHeader', 'workorder_profit_ctr_id', convert(varchar(20), workorder_profit_ctr_id), convert(varchar(20), @new_profit_ctr_id), NULL, system_user, 'sp_workorder_migrate', getdate()
--		from ReceiptHeader where workorder_id = @workorder_id and workorder_company_id = @company_id and workorder_profit_ctr_id = @profit_ctr_id and workorder_profit_ctr_id <> @new_profit_ctr_id

--	update ReceiptHeader	
--		set workorder_id = @new_workorder_id, workorder_company_id = @new_company_id, workorder_profit_ctr_id = @new_profit_ctr_id
--	where workorder_id = @workorder_id and workorder_company_id = @company_id and workorder_profit_ctr_id = @profit_ctr_id

--	update TripQuestion	
--		set workorder_id = @new_workorder_id, company_id = @new_company_id, profit_ctr_id = @new_profit_ctr_id
--	where workorder_id = @workorder_id and company_id = @company_id and profit_ctr_id = @profit_ctr_id

--	update BillingLinkLookup	
--		set source_id = @new_workorder_id, source_company_id = @new_company_id, source_profit_ctr_id = @new_profit_ctr_id
--	where source_id = @workorder_id and source_company_id = @company_id and source_profit_ctr_id = @profit_ctr_id

--	update WMReceiptWorkorderTransporter	
--		set workorder_id = @new_workorder_id, workorder_company_id = @new_company_id, workorder_profit_ctr_id = @new_profit_ctr_id
--	where workorder_id = @workorder_id and workorder_company_id = @company_id and workorder_profit_ctr_id = @profit_ctr_id

--	insert WorkorderAudit 
--		select distinct company_id, Profit_ctr_id, workorder_id, '', 0, 'WorkorderDetail', 'workorder_id', convert(varchar(20), workorder_id), convert(varchar(20), @new_workorder_id), 'sp_workorder_migrate', system_user, getdate()
--		from WorkorderDetail where workorder_id = @workorder_id and company_id = @company_id and profit_ctr_id = @profit_ctr_id
--		union
--		select distinct company_id, Profit_ctr_id, workorder_id, '', 0, 'WorkorderDetail', 'company_id', convert(varchar(20), company_id), convert(varchar(20), @new_company_id), 'sp_workorder_migrate', system_user, getdate()
--		from WorkorderDetail where workorder_id = @workorder_id and company_id = @company_id and profit_ctr_id = @profit_ctr_id and company_id <> @new_company_id
--		union
--		select distinct company_id, Profit_ctr_id, workorder_id, '', 0, 'WorkorderDetail', 'profit_ctr_id', convert(varchar(20), profit_ctr_id), convert(varchar(20), @new_profit_ctr_id), 'sp_workorder_migrate', system_user, getdate()
--		from WorkorderDetail where workorder_id = @workorder_id and company_id = @company_id and profit_ctr_id = @profit_ctr_id and profit_ctr_id <> @new_profit_ctr_id

--	update WorkorderDetail	
--		set workorder_id = @new_workorder_id, company_id = @new_company_id, profit_ctr_id = @new_profit_ctr_id
--	where workorder_id = @workorder_id and company_id = @company_id and profit_ctr_id = @profit_ctr_id

--	insert WorkorderAudit 
--		select distinct company_id, Profit_ctr_id, workorder_id, '', 0, 'WorkorderDetailBaseline', 'workorder_id', convert(varchar(20), workorder_id), convert(varchar(20), @new_workorder_id), 'sp_workorder_migrate', system_user, getdate()
--		from WorkorderDetailBaseline where workorder_id = @workorder_id and company_id = @company_id and profit_ctr_id = @profit_ctr_id
--		union
--		select distinct company_id, Profit_ctr_id, workorder_id, '', 0, 'WorkorderDetailBaseline', 'company_id', convert(varchar(20), company_id), convert(varchar(20), @new_company_id), 'sp_workorder_migrate', system_user, getdate()
--		from WorkorderDetailBaseline where workorder_id = @workorder_id and company_id = @company_id and profit_ctr_id = @profit_ctr_id and company_id <> @new_company_id
--		union
--		select distinct company_id, Profit_ctr_id, workorder_id, '', 0, 'WorkorderDetailBaseline', 'profit_ctr_id', convert(varchar(20), profit_ctr_id), convert(varchar(20), @new_profit_ctr_id), 'sp_workorder_migrate', system_user, getdate()
--		from WorkorderDetailBaseline where workorder_id = @workorder_id and company_id = @company_id and profit_ctr_id = @profit_ctr_id and profit_ctr_id <> @new_profit_ctr_id

--	update WorkorderDetailBaseline	
--		set workorder_id = @new_workorder_id, company_id = @new_company_id, profit_ctr_id = @new_profit_ctr_id
--	where workorder_id = @workorder_id and company_id = @company_id and profit_ctr_id = @profit_ctr_id

--	insert WorkorderAudit 
--		select distinct company_id, Profit_ctr_id, workorder_id, '', 0, 'WorkOrderDetailCC', 'workorder_id', convert(varchar(20), workorder_id), convert(varchar(20), @new_workorder_id), 'sp_workorder_migrate', system_user, getdate()
--		from WorkOrderDetailCC where workorder_id = @workorder_id and company_id = @company_id and profit_ctr_id = @profit_ctr_id
--		union
--		select distinct company_id, Profit_ctr_id, workorder_id, '', 0, 'WorkOrderDetailCC', 'company_id', convert(varchar(20), company_id), convert(varchar(20), @new_company_id), 'sp_workorder_migrate', system_user, getdate()
--		from WorkOrderDetailCC where workorder_id = @workorder_id and company_id = @company_id and profit_ctr_id = @profit_ctr_id and company_id <> @new_company_id
--		union
--		select distinct company_id, Profit_ctr_id, workorder_id, '', 0, 'WorkOrderDetailCC', 'profit_ctr_id', convert(varchar(20), profit_ctr_id), convert(varchar(20), @new_profit_ctr_id), 'sp_workorder_migrate', system_user, getdate()
--		from WorkOrderDetailCC where workorder_id = @workorder_id and company_id = @company_id and profit_ctr_id = @profit_ctr_id and profit_ctr_id <> @new_profit_ctr_id

--	update WorkOrderDetailCC	
--		set workorder_id = @new_workorder_id, company_id = @new_company_id, profit_ctr_id = @new_profit_ctr_id
--	where workorder_id = @workorder_id and company_id = @company_id and profit_ctr_id = @profit_ctr_id

--	insert WorkorderAudit 
--		select distinct company_id, Profit_ctr_id, workorder_id, '', 0, 'WorkOrderDetailItem', 'workorder_id', convert(varchar(20), workorder_id), convert(varchar(20), @new_workorder_id), 'sp_workorder_migrate', system_user, getdate()
--		from WorkOrderDetailItem where workorder_id = @workorder_id and company_id = @company_id and profit_ctr_id = @profit_ctr_id
--		union
--		select distinct company_id, Profit_ctr_id, workorder_id, '', 0, 'WorkOrderDetailItem', 'company_id', convert(varchar(20), company_id), convert(varchar(20), @new_company_id), 'sp_workorder_migrate', system_user, getdate()
--		from WorkOrderDetailItem where workorder_id = @workorder_id and company_id = @company_id and profit_ctr_id = @profit_ctr_id and company_id <> @new_company_id
--		union
--		select distinct company_id, Profit_ctr_id, workorder_id, '', 0, 'WorkOrderDetailItem', 'profit_ctr_id', convert(varchar(20), profit_ctr_id), convert(varchar(20), @new_profit_ctr_id), 'sp_workorder_migrate', system_user, getdate()
--		from WorkOrderDetailItem where workorder_id = @workorder_id and company_id = @company_id and profit_ctr_id = @profit_ctr_id and profit_ctr_id <> @new_profit_ctr_id

--	update WorkOrderDetailItem	
--		set workorder_id = @new_workorder_id, company_id = @new_company_id, profit_ctr_id = @new_profit_ctr_id
--	where workorder_id = @workorder_id and company_id = @company_id and profit_ctr_id = @profit_ctr_id

--	insert WorkorderAudit 
--		select distinct company_id, Profit_ctr_id, workorder_id, '', 0, 'WorkOrderDetailItemTemp', 'workorder_id', convert(varchar(20), workorder_id), convert(varchar(20), @new_workorder_id), 'sp_workorder_migrate', system_user, getdate()
--		from WorkOrderDetailItemTemp where workorder_id = @workorder_id and company_id = @company_id and profit_ctr_id = @profit_ctr_id
--		union
--		select distinct company_id, Profit_ctr_id, workorder_id, '', 0, 'WorkOrderDetailItemTemp', 'company_id', convert(varchar(20), company_id), convert(varchar(20), @new_company_id), 'sp_workorder_migrate', system_user, getdate()
--		from WorkOrderDetailItemTemp where workorder_id = @workorder_id and company_id = @company_id and profit_ctr_id = @profit_ctr_id and company_id <> @new_company_id
--		union
--		select distinct company_id, Profit_ctr_id, workorder_id, '', 0, 'WorkOrderDetailItemTemp', 'profit_ctr_id', convert(varchar(20), profit_ctr_id), convert(varchar(20), @new_profit_ctr_id), 'sp_workorder_migrate', system_user, getdate()
--		from WorkOrderDetailItemTemp where workorder_id = @workorder_id and company_id = @company_id and profit_ctr_id = @profit_ctr_id and profit_ctr_id <> @new_profit_ctr_id

--	update WorkOrderDetailItemTemp	
--		set workorder_id = @new_workorder_id, company_id = @new_company_id, profit_ctr_id = @new_profit_ctr_id
--	where workorder_id = @workorder_id and company_id = @company_id and profit_ctr_id = @profit_ctr_id

--	insert WorkorderAudit 
--		select distinct company_id, Profit_ctr_id, workorder_id, '', 0, 'WorkOrderDetailTemp', 'workorder_id', convert(varchar(20), workorder_id), convert(varchar(20), @new_workorder_id), 'sp_workorder_migrate', system_user, getdate()
--		from WorkOrderDetailTemp where workorder_id = @workorder_id and company_id = @company_id and profit_ctr_id = @profit_ctr_id
--		union
--		select distinct company_id, Profit_ctr_id, workorder_id, '', 0, 'WorkOrderDetailTemp', 'company_id', convert(varchar(20), company_id), convert(varchar(20), @new_company_id), 'sp_workorder_migrate', system_user, getdate()
--		from WorkOrderDetailTemp where workorder_id = @workorder_id and company_id = @company_id and profit_ctr_id = @profit_ctr_id and company_id <> @new_company_id
--		union
--		select distinct company_id, Profit_ctr_id, workorder_id, '', 0, 'WorkOrderDetailTemp', 'profit_ctr_id', convert(varchar(20), profit_ctr_id), convert(varchar(20), @new_profit_ctr_id), 'sp_workorder_migrate', system_user, getdate()
--		from WorkOrderDetailTemp where workorder_id = @workorder_id and company_id = @company_id and profit_ctr_id = @profit_ctr_id and profit_ctr_id <> @new_profit_ctr_id

--	update WorkOrderDetailTemp	
--		set workorder_id = @new_workorder_id, company_id = @new_company_id, profit_ctr_id = @new_profit_ctr_id
--	where workorder_id = @workorder_id and company_id = @company_id and profit_ctr_id = @profit_ctr_id

--	insert WorkorderAudit 
--		select distinct company_id, Profit_ctr_id, workorder_id, '', 0, 'WorkOrderDetailUnit', 'workorder_id', convert(varchar(20), workorder_id), convert(varchar(20), @new_workorder_id), 'sp_workorder_migrate', system_user, getdate()
--		from WorkOrderDetailUnit where workorder_id = @workorder_id and company_id = @company_id and profit_ctr_id = @profit_ctr_id
--		union
--		select distinct company_id, Profit_ctr_id, workorder_id, '', 0, 'WorkOrderDetailUnit', 'company_id', convert(varchar(20), company_id), convert(varchar(20), @new_company_id), 'sp_workorder_migrate', system_user, getdate()
--		from WorkOrderDetailUnit where workorder_id = @workorder_id and company_id = @company_id and profit_ctr_id = @profit_ctr_id and company_id <> @new_company_id
--		union
--		select distinct company_id, Profit_ctr_id, workorder_id, '', 0, 'WorkOrderDetailUnit', 'profit_ctr_id', convert(varchar(20), profit_ctr_id), convert(varchar(20), @new_profit_ctr_id), 'sp_workorder_migrate', system_user, getdate()
--		from WorkOrderDetailUnit where workorder_id = @workorder_id and company_id = @company_id and profit_ctr_id = @profit_ctr_id and profit_ctr_id <> @new_profit_ctr_id

--	update WorkOrderDetailUnit	
--		set workorder_id = @new_workorder_id, company_id = @new_company_id, profit_ctr_id = @new_profit_ctr_id
--	where workorder_id = @workorder_id and company_id = @company_id and profit_ctr_id = @profit_ctr_id

--	insert WorkorderAudit 
--		select distinct company_id, Profit_ctr_id, workorder_id, '', 0, 'WorkorderHeader', 'workorder_id', convert(varchar(20), workorder_id), convert(varchar(20), @new_workorder_id), 'sp_workorder_migrate', system_user, getdate()
--		from WorkorderHeader where workorder_id = @workorder_id and company_id = @company_id and profit_ctr_id = @profit_ctr_id
--		union
--		select distinct company_id, Profit_ctr_id, workorder_id, '', 0, 'WorkorderHeader', 'company_id', convert(varchar(20), company_id), convert(varchar(20), @new_company_id), 'sp_workorder_migrate', system_user, getdate()
--		from WorkorderHeader where workorder_id = @workorder_id and company_id = @company_id and profit_ctr_id = @profit_ctr_id and company_id <> @new_company_id
--		union
--		select distinct company_id, Profit_ctr_id, workorder_id, '', 0, 'WorkorderHeader', 'profit_ctr_id', convert(varchar(20), profit_ctr_id), convert(varchar(20), @new_profit_ctr_id), 'sp_workorder_migrate', system_user, getdate()
--		from WorkorderHeader where workorder_id = @workorder_id and company_id = @company_id and profit_ctr_id = @profit_ctr_id and profit_ctr_id <> @new_profit_ctr_id

--	if @new_company_id = 15 and @new_profit_ctr_id = 0 begin
--		insert WorkorderAudit 
--			select distinct company_id, Profit_ctr_id, workorder_id, '', 0, 'WorkorderHeader', 'workorder_type_id', convert(varchar(20), workorder_type_id), convert(varchar(20), 12), 'sp_workorder_migrate', system_user, getdate()
--			from WorkorderHeader where workorder_id = @workorder_id and company_id = @company_id and profit_ctr_id = @profit_ctr_id
			
--		update WorkorderHeader	
--			set workorder_type_id = 12
--		where workorder_id = @workorder_id and company_id = @company_id and profit_ctr_id = @profit_ctr_id
--	end

--	update WorkorderHeader	
--		set workorder_id = @new_workorder_id, company_id = @new_company_id, profit_ctr_id = @new_profit_ctr_id
--	where workorder_id = @workorder_id and company_id = @company_id and profit_ctr_id = @profit_ctr_id

--	insert WorkorderAudit 
--		select distinct company_id, Profit_ctr_id, workorder_id, '', 0, 'WorkorderHours', 'workorder_id', convert(varchar(20), workorder_id), convert(varchar(20), @new_workorder_id), 'sp_workorder_migrate', system_user, getdate()
--		from WorkorderHours where workorder_id = @workorder_id and company_id = @company_id and profit_ctr_id = @profit_ctr_id
--		union
--		select distinct company_id, Profit_ctr_id, workorder_id, '', 0, 'WorkorderHours', 'company_id', convert(varchar(20), company_id), convert(varchar(20), @new_company_id), 'sp_workorder_migrate', system_user, getdate()
--		from WorkorderHours where workorder_id = @workorder_id and company_id = @company_id and profit_ctr_id = @profit_ctr_id and company_id <> @new_company_id
--		union
--		select distinct company_id, Profit_ctr_id, workorder_id, '', 0, 'WorkorderHours', 'profit_ctr_id', convert(varchar(20), profit_ctr_id), convert(varchar(20), @new_profit_ctr_id), 'sp_workorder_migrate', system_user, getdate()
--		from WorkorderHours where workorder_id = @workorder_id and company_id = @company_id and profit_ctr_id = @profit_ctr_id and profit_ctr_id <> @new_profit_ctr_id

--	update WorkorderHours	
--		set workorder_id = @new_workorder_id, company_id = @new_company_id, profit_ctr_id = @new_profit_ctr_id
--	where workorder_id = @workorder_id and company_id = @company_id and profit_ctr_id = @profit_ctr_id

--	insert WorkorderAudit 
--		select distinct company_id, Profit_ctr_id, workorder_id, '', 0, 'WorkOrderImportDetail', 'workorder_id', convert(varchar(20), workorder_id), convert(varchar(20), @new_workorder_id), 'sp_workorder_migrate', system_user, getdate()
--		from WorkOrderImportDetail where workorder_id = @workorder_id and company_id = @company_id and profit_ctr_id = @profit_ctr_id
--		union
--		select distinct company_id, Profit_ctr_id, workorder_id, '', 0, 'WorkOrderImportDetail', 'company_id', convert(varchar(20), company_id), convert(varchar(20), @new_company_id), 'sp_workorder_migrate', system_user, getdate()
--		from WorkOrderImportDetail where workorder_id = @workorder_id and company_id = @company_id and profit_ctr_id = @profit_ctr_id and company_id <> @new_company_id
--		union
--		select distinct company_id, Profit_ctr_id, workorder_id, '', 0, 'WorkOrderImportDetail', 'profit_ctr_id', convert(varchar(20), profit_ctr_id), convert(varchar(20), @new_profit_ctr_id), 'sp_workorder_migrate', system_user, getdate()
--		from WorkOrderImportDetail where workorder_id = @workorder_id and company_id = @company_id and profit_ctr_id = @profit_ctr_id and profit_ctr_id <> @new_profit_ctr_id

--	update WorkOrderImportDetail	
--		set workorder_id = @new_workorder_id, company_id = @new_company_id, profit_ctr_id = @new_profit_ctr_id
--	where workorder_id = @workorder_id and company_id = @company_id and profit_ctr_id = @profit_ctr_id

--	insert WorkorderAudit 
--		select distinct company_id, Profit_ctr_id, workorder_id, '', 0, 'WorkorderManifest', 'workorder_id', convert(varchar(20), workorder_id), convert(varchar(20), @new_workorder_id), 'sp_workorder_migrate', system_user, getdate()
--		from WorkorderManifest where workorder_id = @workorder_id and company_id = @company_id and profit_ctr_id = @profit_ctr_id
--		union
--		select distinct company_id, Profit_ctr_id, workorder_id, '', 0, 'WorkorderManifest', 'company_id', convert(varchar(20), company_id), convert(varchar(20), @new_company_id), 'sp_workorder_migrate', system_user, getdate()
--		from WorkorderManifest where workorder_id = @workorder_id and company_id = @company_id and profit_ctr_id = @profit_ctr_id and company_id <> @new_company_id
--		union
--		select distinct company_id, Profit_ctr_id, workorder_id, '', 0, 'WorkorderManifest', 'profit_ctr_id', convert(varchar(20), profit_ctr_id), convert(varchar(20), @new_profit_ctr_id), 'sp_workorder_migrate', system_user, getdate()
--		from WorkorderManifest where workorder_id = @workorder_id and company_id = @company_id and profit_ctr_id = @profit_ctr_id and profit_ctr_id <> @new_profit_ctr_id

--	update WorkorderManifest	
--		set workorder_id = @new_workorder_id, company_id = @new_company_id, profit_ctr_id = @new_profit_ctr_id
--	where workorder_id = @workorder_id and company_id = @company_id and profit_ctr_id = @profit_ctr_id

--	insert WorkorderAudit 
--		select distinct company_id, Profit_ctr_id, workorder_id, '', 0, 'WorkorderReminder', 'last_workorder_ID', convert(varchar(20), last_workorder_ID), convert(varchar(20), @new_workorder_id), 'sp_workorder_migrate', system_user, getdate()
--		from WorkorderReminder where last_workorder_ID = @workorder_id and company_id = @company_id and profit_ctr_id = @profit_ctr_id

--	update WorkorderReminder	
--		set last_workorder_ID = @new_workorder_id
--	where last_workorder_ID = @workorder_id and company_id = @company_id and profit_ctr_id = @profit_ctr_id

--	insert WorkorderAudit 
--		select distinct company_id, Profit_ctr_id, workorder_id, '', 0, 'WorkorderReminder', 'workorder_id', convert(varchar(20), workorder_id), convert(varchar(20), @new_workorder_id), 'sp_workorder_migrate', system_user, getdate()
--		from WorkorderReminder where workorder_id = @workorder_id and company_id = @company_id and profit_ctr_id = @profit_ctr_id
--		union
--		select distinct company_id, Profit_ctr_id, workorder_id, '', 0, 'WorkorderReminder', 'company_id', convert(varchar(20), company_id), convert(varchar(20), @new_company_id), 'sp_workorder_migrate', system_user, getdate()
--		from WorkorderReminder where workorder_id = @workorder_id and company_id = @company_id and profit_ctr_id = @profit_ctr_id and company_id <> @new_company_id
--		union
--		select distinct company_id, Profit_ctr_id, workorder_id, '', 0, 'WorkorderReminder', 'profit_ctr_id', convert(varchar(20), profit_ctr_id), convert(varchar(20), @new_profit_ctr_id), 'sp_workorder_migrate', system_user, getdate()
--		from WorkorderReminder where workorder_id = @workorder_id and company_id = @company_id and profit_ctr_id = @profit_ctr_id and profit_ctr_id <> @new_profit_ctr_id

--	update WorkorderReminder	
--		set workorder_id = @new_workorder_id, company_id = @new_company_id, profit_ctr_id = @new_profit_ctr_id
--	where workorder_id = @workorder_id and company_id = @company_id and profit_ctr_id = @profit_ctr_id

--	insert WorkorderAudit 
--		select distinct company_id, Profit_ctr_id, workorder_id, '', 0, 'WorkorderStop', 'workorder_id', convert(varchar(20), workorder_id), convert(varchar(20), @new_workorder_id), 'sp_workorder_migrate', system_user, getdate()
--		from WorkorderStop where workorder_id = @workorder_id and company_id = @company_id and profit_ctr_id = @profit_ctr_id
--		union
--		select distinct company_id, Profit_ctr_id, workorder_id, '', 0, 'WorkorderStop', 'company_id', convert(varchar(20), company_id), convert(varchar(20), @new_company_id), 'sp_workorder_migrate', system_user, getdate()
--		from WorkorderStop where workorder_id = @workorder_id and company_id = @company_id and profit_ctr_id = @profit_ctr_id and company_id <> @new_company_id
--		union
--		select distinct company_id, Profit_ctr_id, workorder_id, '', 0, 'WorkorderStop', 'profit_ctr_id', convert(varchar(20), profit_ctr_id), convert(varchar(20), @new_profit_ctr_id), 'sp_workorder_migrate', system_user, getdate()
--		from WorkorderStop where workorder_id = @workorder_id and company_id = @company_id and profit_ctr_id = @profit_ctr_id and profit_ctr_id <> @new_profit_ctr_id

--	update WorkorderStop	
--		set workorder_id = @new_workorder_id, company_id = @new_company_id, profit_ctr_id = @new_profit_ctr_id
--	where workorder_id = @workorder_id and company_id = @company_id and profit_ctr_id = @profit_ctr_id

--	insert WorkorderAudit 
--		select distinct company_id, Profit_ctr_id, workorder_id, '', 0, 'WorkOrderTransporter', 'workorder_id', convert(varchar(20), workorder_id), convert(varchar(20), @new_workorder_id), 'sp_workorder_migrate', system_user, getdate()
--		from WorkOrderTransporter where workorder_id = @workorder_id and company_id = @company_id and profit_ctr_id = @profit_ctr_id
--		union
--		select distinct company_id, Profit_ctr_id, workorder_id, '', 0, 'WorkOrderTransporter', 'company_id', convert(varchar(20), company_id), convert(varchar(20), @new_company_id), 'sp_workorder_migrate', system_user, getdate()
--		from WorkOrderTransporter where workorder_id = @workorder_id and company_id = @company_id and profit_ctr_id = @profit_ctr_id and company_id <> @new_company_id
--		union
--		select distinct company_id, Profit_ctr_id, workorder_id, '', 0, 'WorkOrderTransporter', 'profit_ctr_id', convert(varchar(20), profit_ctr_id), convert(varchar(20), @new_profit_ctr_id), 'sp_workorder_migrate', system_user, getdate()
--		from WorkOrderTransporter where workorder_id = @workorder_id and company_id = @company_id and profit_ctr_id = @profit_ctr_id and profit_ctr_id <> @new_profit_ctr_id

--	update WorkOrderTransporter	
--		set workorder_id = @new_workorder_id, company_id = @new_company_id, profit_ctr_id = @new_profit_ctr_id
--	where workorder_id = @workorder_id and company_id = @company_id and profit_ctr_id = @profit_ctr_id

--	insert WorkorderAudit 
--		select distinct company_id, Profit_ctr_id, workorder_id, '', 0, 'WorkOrderWasteCode', 'workorder_id', convert(varchar(20), workorder_id), convert(varchar(20), @new_workorder_id), 'sp_workorder_migrate', system_user, getdate()
--		from WorkOrderWasteCode where workorder_id = @workorder_id and company_id = @company_id and profit_ctr_id = @profit_ctr_id
--		union
--		select distinct company_id, Profit_ctr_id, workorder_id, '', 0, 'WorkOrderWasteCode', 'company_id', convert(varchar(20), company_id), convert(varchar(20), @new_company_id), 'sp_workorder_migrate', system_user, getdate()
--		from WorkOrderWasteCode where workorder_id = @workorder_id and company_id = @company_id and profit_ctr_id = @profit_ctr_id and company_id <> @new_company_id
--		union
--		select distinct company_id, Profit_ctr_id, workorder_id, '', 0, 'WorkOrderWasteCode', 'profit_ctr_id', convert(varchar(20), profit_ctr_id), convert(varchar(20), @new_profit_ctr_id), 'sp_workorder_migrate', system_user, getdate()
--		from WorkOrderWasteCode where workorder_id = @workorder_id and company_id = @company_id and profit_ctr_id = @profit_ctr_id and profit_ctr_id <> @new_profit_ctr_id

--	update WorkOrderWasteCode	
--		set workorder_id = @new_workorder_id, company_id = @new_company_id, profit_ctr_id = @new_profit_ctr_id
--	where workorder_id = @workorder_id and company_id = @company_id and profit_ctr_id = @profit_ctr_id

--	update PLT_Image..DocProcessing	
--		set workorder_id = @new_workorder_id, company_id = @new_company_id, profit_ctr_id = @new_profit_ctr_id
--	where workorder_id = @workorder_id and company_id = @company_id and profit_ctr_id = @profit_ctr_id

--	update PLT_Image..ImageHeader	
--		set workorder_id = @new_workorder_id, company_id = @new_company_id, profit_ctr_id = @new_profit_ctr_id
--	where workorder_id = @workorder_id and company_id = @company_id and profit_ctr_id = @profit_ctr_id

--	update PLT_Image..Scan	
--		set workorder_id = @new_workorder_id, company_id = @new_company_id, profit_ctr_id = @new_profit_ctr_id
--	where workorder_id = @workorder_id and company_id = @company_id and profit_ctr_id = @profit_ctr_id


--	insert WorkorderAudit 
--		select distinct company_id, Profit_ctr_id, workorder_id, '', 0, 'WorkOrderWasteCode', 'workorder_status', workorder_status, 'V', 'sp_workorder_migrate', system_user, getdate()
--		from WorkorderHeader where workorder_id = @workorder_id and company_id = @company_id and profit_ctr_id = @profit_ctr_id
--		union
--		select distinct company_id, Profit_ctr_id, workorder_id, '', 0, 'WorkOrderWasteCode', 'void_date', convert(varchar(20), void_date), convert(varchar(20), getdate()), 'sp_workorder_migrate', system_user, getdate()
--		from WorkorderHeader where workorder_id = @workorder_id and company_id = @company_id and profit_ctr_id = @profit_ctr_id and company_id <> @new_company_id
--		union
--		select distinct company_id, Profit_ctr_id, workorder_id, '', 0, 'WorkOrderWasteCode', 'void_operator', void_operator, system_user, 'sp_workorder_migrate', system_user, getdate()
--		from WorkorderHeader where workorder_id = @workorder_id and company_id = @company_id and profit_ctr_id = @profit_ctr_id and profit_ctr_id <> @new_profit_ctr_id
--		union
--		select distinct company_id, Profit_ctr_id, workorder_id, '', 0, 'WorkOrderWasteCode', 'void_reason', void_reason, 'Migrated to ' + convert(varchar(2), @new_company_id) + '-' + convert(varchar(2), @new_profit_ctr_id) + ': ' + convert(varchar(20), @new_workorder_id), 'sp_workorder_migrate', system_user, getdate()
--		from WorkorderHeader where workorder_id = @workorder_id and company_id = @company_id and profit_ctr_id = @profit_ctr_id and profit_ctr_id <> @new_profit_ctr_id

--	update WorkorderHeader
--		SET 
--		workorder_status = 'V',
--		void_date = getdate(),
--		void_operator = system_user,
--		void_reason = 'Migrated to ' + convert(varchar(2), @new_company_id) + '-' + convert(varchar(2), @new_profit_ctr_id) + ': ' + convert(varchar(20), @new_workorder_id)
--	where workorder_id = @workorder_id and company_id = @company_id and profit_ctr_id = @profit_ctr_id

--	update WorkorderAudit	
--		set workorder_id = @new_workorder_id, company_id = @new_company_id, profit_ctr_id = @new_profit_ctr_id
--	where workorder_id = @workorder_id and company_id = @company_id and profit_ctr_id = @profit_ctr_id

--	update WorkorderAuditComment	
--		set workorder_id = @new_workorder_id, company_id = @new_company_id, profit_ctr_id = @new_profit_ctr_id
--	where workorder_id = @workorder_id and company_id = @company_id and profit_ctr_id = @profit_ctr_id

--	select @new_company_id as company_id, @new_profit_ctr_id as profit_ctr_id, @new_workorder_id as workorder_id
			
--    COMMIT TRANSACTION
--END TRY
--BEGIN CATCH
--  -- Whoops, there was an error
--  IF @@TRANCOUNT > 0
--     ROLLBACK

--  -- Raise an error with the details of the exception
--  DECLARE @ErrMsg nvarchar(4000), @ErrSeverity int
--  SELECT @ErrMsg = ERROR_MESSAGE(),
--         @ErrSeverity = ERROR_SEVERITY()
         
--  RAISERROR( @ErrMsg, @ErrSeverity, 1)
--END CATCH

