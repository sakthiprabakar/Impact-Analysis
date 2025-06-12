
create procedure sp_update_ContainerDisposalStatus
as
/* **************************************************************************************************************************
ContainerDisposalStatus update process

1.	Delete old 'N'ew CDS (the non-disposed ones)
2.	Insert to #Inventory ôOpen Inventoryö (status = Current) from Container + Destination.
3.	Trace backward from the #Inventory set and add records their ancestors.
	a.	Note: This is done in sp_container_inventory_calc
4	a.	Void out ContainerDisposalStatus records if the corresponding Container record is Void or Rejected.
	b.	Update CDS set status = Void where status = Disposed AND the same container now also exists in #Inventory.
5.	Insert #Inventory records for Receipt Containers to CDS as new ôNewö records.
6.	Find the set of ContainerDestination records that are recently disposed.
	a.	ContainerDestination Disposal Date between max(date_disposed) in CDS -1 day, until getdate() and status is processed or outbound.
		i.	Slightly modified sp_container_inventory_calc for Disposed status date range.
	b.	Store them in #JustDisposed
	c.	Trace backward from those and add to #JustDisposed, all their ancestors (now also considered disposed) û This is also part of sp_container_inventory_calc already.
7.	Insert to CDS as new Disposed records, any #JustDisposed records that arenÆt already in CDS as Completed or New (#Inventory) status.
8.	Need to figure out how to know which modified receipts need to be re-imported.

History:
	3/19/2015 - Created
	10/29/2015 - Added code to update from Receipts where the receipt itself has been changed since the CDS record based on it was created
	12/4/2015 - Added code to void copious leftover old receipt records and fix where dummy weights and dollars were left after running
	12/11/2015 - Removed containerdisposalstatus_uid
				When voiding CDS rows on a receipt modified since disposal date - now change: check to see if the receipt was modified since the cds.date_added! 
					Not date disposed.  I was an idiot that day.
	10/07/2016 - JPB Performance Work.  Added debug log, Re-worked slow queries, revised related functions/indexes, etc.
	10/04/2017	MPM	Changed how the #ContainerInventory table gets created, so that this proc doesn't choke when columns are added to ContainerDestination.			

	
Scratch:	
-- ContainerDisposalStatus to hold the lifecycle of container, specifically disposal history
if exists (select 1 from sysobjects where type = 'U' and name = 'ContainerDisposalStatus')
	drop table ContainerDisposalStatus
g o
CREATE TABLE dbo.ContainerDisposalStatus (
	company_id					int			not null,
    profit_ctr_id				int			not null,
    receipt_id					int			not null,
    line_id						int			not null,
    container_id				int			not null,
    container_type				char(1)		not null,
    final_disposal_date			datetime	null,
    final_disposal_status		char(1)		null,
    pounds						float		null,
    disposal_revenue_amt		money		null,
    added_by 					varchar(10) 		not null,
    date_added 					datetime 			not null,
    modified_by 				varchar(10) 		not null,
    date_modified 				datetime 			not null
 )
g o
grant select on ContainerDisposalStatus to eqai, eqweb
grant delete on ContainerDisposalStatus to eqai, eqweb
grant insert on ContainerDisposalStatus to eqai, eqweb
grant update on ContainerDisposalStatus to eqai, eqweb
g o

 -- create index idx_keys on ContainerDisposalStatus (receipt_id, line_id, company_id, profit_ctr_id, container_id, sequence_id) include (final_disposal_date, final_disposal_status)
create index idx_keys on ContainerDisposalStatus (receipt_id, line_id, company_id, profit_ctr_id, container_id) include (final_disposal_date, final_disposal_status)
create index idx_disposal_date on ContainerDisposalStatus (final_disposal_date) include (receipt_id, line_id, company_id, profit_ctr_id, container_id)


--CREATE NONCLUSTERED INDEX [idx_disposal_date]
--ON [dbo].[ContainerDisposalStatus] ([final_disposal_date])
--INCLUDE ([receipt_id],[line_id],[company_id],[profit_ctr_id],[container_id],[container_type],[final_disposal_status],[pounds],[added_by],[date_added],[modified_by],[date_modified])

select count(*) from ContainerDisposalStatus

 
Note: For years prior to 2014, we'll just insert dummy 'C' records, because we can't
store a container for more than 365 days, and doing the whole inventory/disposal work
for all those is ridiculously slow.  We can cheat. :)

truncate table ContainerDisposalStatus

insert ContainerDisposalStatus
select distinct
	c.company_id					
	,c.profit_ctr_id				
	,c.receipt_id					
	,c.line_id						
	,c.container_id				
	,c.container_type				
	,'1/1/1899' as final_disposal_date			
	,'C' as final_disposal_status		
	,isnull(c.container_weight, 0) as pounds						
	, 0 as disposal_revenue_amt		
	,'SA' as added_by 					
	,getdate() as date_added 					
	,'SA' as modified_by 				
	,getdate() as date_modified 				
from Container c 
where container_type = 'R'
and date_added < '1/1/2014'


-----------------------------------------------
-- Before re-running, run these statements:
-----------------------------------------------
SELECT * INTO ContainerDisposalStatus_Backup_20150319 FROM ContainerDisposalStatus
-- 9,685,352
SELECT * INTO ContainerDisposalStatus_Backup_20150319_1428 FROM ContainerDisposalStatus
-- 10,469,261 (0:30)
SELECT * INTO ContainerDisposalStatus_Backup_20150319_1631 FROM ContainerDisposalStatus		-- TEST
-- 9,334,919 (0:46)
DELETE FROM ContainerDisposalStatus WHERE final_disposal_date <> '1/1/1899'
--   343,362

sp_help ContainerDisposalStatus

create index idx_tmp_date_added on ContainerDisposalStatus (date_added, final_disposal_status)

-- 2016-10-07 - Performance issues came up.  Add logging:

create table ContainerDisposalStatus_Log (
	activity varchar(1000)
	,total_ms bigint
	,step_ms bigint
	,dbg_order int not null identity(1,1)
	,date_added datetime
)


EXEC sp_update_ContainerDisposalStatus
************************************************************************************************************************** */
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

-- Clean the debug log
delete from ContainerDisposalStatus_Log where date_added < getdate() -3

-- Debug timing vars
declare @dStartTime datetime = getdate(), @dLastTime datetime = getdate()

-- Generic "count" holder so "if 0 < (...)" logic can be refactored and timed.
declare @tempcount bigint


insert ContainerDisposalStatus_Log select
'SP Start', datediff(ms, @dStartTime, getdate()), datediff(ms, @dLastTime, getdate()), @dStartTime; set @dLastTime = getdate()
 
 
-- 1.	Update CDS set status = History where status = Current
	-- Per Lorraine on 3/17, we apparently agreed to delete these?  Ok then.

--		select count(*) from  ContainerDisposalStatus where final_disposal_status = 'N'
		DELETE	from  ContainerDisposalStatus where final_disposal_status = 'N'

		insert ContainerDisposalStatus_Log select
		'Delete ''N'' records from ContainerDisposalStatus', datediff(ms, @dStartTime, getdate()), datediff(ms, @dLastTime, getdate()), @dStartTime; set @dLastTime = getdate()

--		select count(*) from  ContainerDisposalStatus where final_disposal_status = 'V' and date_added < getdate()-3
		while 1=1 begin
			Delete top (10000) from  ContainerDisposalStatus where final_disposal_status = 'V' and date_added < getdate()-3

			if @@rowcount = 0 break
			
			insert ContainerDisposalStatus_Log select
			'Deleted 10000 ''V'' records from ContainerDisposalStatus', datediff(ms, @dStartTime, getdate()), datediff(ms, @dLastTime, getdate()), @dStartTime; set @dLastTime = getdate()
		
		end

		insert ContainerDisposalStatus_Log select
		'Delete ''V'' records from ContainerDisposalStatus finished', datediff(ms, @dStartTime, getdate()), datediff(ms, @dLastTime, getdate()), @dStartTime; set @dLastTime = getdate()


-- 2.	Insert to #Inventory ôOpen Inventoryö (status = Current) from Container + Destination.

--#region Create #ContainerInventory tables
		if object_id('tempdb..#ContainerInventory') is not null 	drop table #ContainerInventory		

/*
		CREATE TABLE #ContainerInventory (
			
			-- Meta info fields about the disposition of a container's history/tree:

				generation					int				-- The recursive generation in which this record was found.
															--  Remember, this works backwards... 0 is the LAST (most current) record.
				, ultimate_disposal_status	varchar(10)		-- If the last record for this container's tree is open/closed, they ALL are the same.
				, ultimate_disposal_date	datetime		-- Disposal date of the last record for this container's tree
				
				, inventory_receipt_id		int				-- The receipt_id that appears(or appeared) on inventory at the as_of_date
															--  that was the last record for this container's tree.
				, inventory_line_id			int				-- Related to the inventory_receipt_id, obviously.
				, inventory_container_id	int				-- Related to the inventory_ receipt & line id's
				, inventory_sequence_id		int				-- Related to the inventory_container_id
			
			-- Now all fields from ContainerDestination:
			--	sp_columns ContainerDestination

				, profit_ctr_id				int
				, container_type			char(1)
				, receipt_id				int
				, line_id					int
				, container_id				int
				, sequence_id				int
				, container_percent			int
				, treatment_id				int
				, location_type				char(1)
				, location					varchar(15)
				, tracking_num				varchar(15)
				, cycle						int
				, disposal_date				datetime
				, tsdf_approval_code		varchar(40)
				, waste_stream				varchar(10)
				, base_tracking_num			varchar(15)
				, base_container_id			int
				, waste_flag				char(1)
				, const_flag				char(1)
				, status					char(1)
				, date_added				datetime
				, date_modified				datetime
				, created_by				varchar(8)
				, modified_by				varchar(8)
				, modified_from				varchar(2)
				, TSDF_approval_bill_unit_code	varchar(4)
				, company_id				int
				, OB_profile_ID				int
				, OB_profile_company_ID		int
				, OB_profile_profit_ctr_id	int
				, TSDF_approval_id			int
				, base_sequence_id			int
		)
*/
		SELECT TOP 0
			 CAST(NULL AS INT) generation
			 , CAST(NULL AS VARCHAR(10)) ultimate_disposal_status
			 , CAST(NULL AS DATETIME) ultimate_disposal_date
			 , CAST(NULL AS INT) inventory_receipt_id
			 , CAST(NULL AS INT) inventory_line_id
			 , CAST(NULL AS INT) inventory_container_id
			 , CAST(NULL AS INT) inventory_sequence_id
			 , *
		INTO #ContainerInventory
		FROM ContainerDestination 
		WHERE 1=0


		create index idx_tmp on #ContainerInventory (
			company_id
			, profit_ctr_id
			, receipt_id
			, line_id
			, container_id
			, sequence_id
			, container_type
			, generation
		)

		truncate table #ContainerInventory

--#endregion

insert ContainerDisposalStatus_Log select
'#ContainerInventory table created', datediff(ms, @dStartTime, getdate()), datediff(ms, @dLastTime, getdate()), @dStartTime; set @dLastTime = getdate()

-- 3.	Trace backward from the #Inventory set and add records their ancestors.
-- 	a.	Note: This is a LOT like sp_container_inventory_calc

--#region Gather Inventory
--EXEC sp_container_inventory_calc NULL, 'U', NULL

		exec sp_container_inventory_calc 
			@copc_list			= NULL	-- Optional list of companies/profitcenters to limit by
			, @disposed_flag	= 'U'	-- 'D'isposed or 'U'ndisposed
			, @as_of_date		= NULL	-- Billing records are run AS OF @as_of_date. Defaults to current date.

insert ContainerDisposalStatus_Log select
'sp_container_inventory_calc ''U'' finished', datediff(ms, @dStartTime, getdate()), datediff(ms, @dLastTime, getdate()), @dStartTime; set @dLastTime = getdate()


		if object_id('tempdb..#inventory') is not null 	drop table #inventory		
	
		select * into #Inventory from #ContainerInventory
		
		truncate table #ContainerInventory

		create index idx_tmp on #Inventory (
			company_id
			, profit_ctr_id
			, receipt_id
			, line_id
			, container_id
			, sequence_id
			, container_type
			, generation
		)
		
insert ContainerDisposalStatus_Log select
'#ContainerInventory records moved to #Inventory', datediff(ms, @dStartTime, getdate()), datediff(ms, @dLastTime, getdate()), @dStartTime; set @dLastTime = getdate()
	
--#endregion


-- 4a.	Void out ContainerDisposalStatus records if the corresponding Container record is Void or Rejected.
		
--#region Void containers if the corresponding Container record is Void or Rejected.
		while 1=1 begin
			UPDATE top (256) ContainerDisposalStatus SET
				final_disposal_status = 'V'
				, date_modified = GETDATE()
				, modified_by = 'CDS-Update'
				-- select count(cds.container_id)
			FROM ContainerDisposalStatus cds
			JOIN Container c
				ON c.company_id = cds.company_id
				AND c.profit_ctr_id = cds.profit_ctr_id
				AND c.receipt_id = cds.receipt_id
				AND c.line_id = cds.line_id
				AND c.container_id = cds.container_id
				AND c.status IN ('V', 'R')
			where final_disposal_status <> 'V'
			if @@rowcount = 0 break
		end

insert ContainerDisposalStatus_Log select
'ContainerDisposalStatus updated to void based on void/rejected containers', datediff(ms, @dStartTime, getdate()), datediff(ms, @dLastTime, getdate()), @dStartTime; set @dLastTime = getdate()

--#endregion


-- 4b.	Update CDS set status = Void where status = Disposed AND the same container now also exists in #Inventory.
		
--#region Void containers that were disposed, but now open


	select @tempcount = count(cds.container_id)
		-- delete from ContainerDisposalStatus
	from ContainerDisposalStatus cds
	join #Inventory i
		on cds.company_id = i.company_id
		and cds.profit_ctr_id = i.profit_ctr_id
		and cds.receipt_id = i.receipt_id
		and cds.line_id = i.line_id
		and cds.container_id = i.container_id
	where cds.final_disposal_status = 'C'
			
insert ContainerDisposalStatus_Log select
'Disposed but now re-opened container count: ' + convert(varchar(10), @tempcount), datediff(ms, @dStartTime, getdate()), datediff(ms, @dLastTime, getdate()), @dStartTime; set @dLastTime = getdate()
			
	if 0 < @tempcount
		while 1=1 begin
			UPDATE top (256) ContainerDisposalStatus SET
				final_disposal_status = 'V'
				, date_modified = getdate()
				, modified_by = 'CDS-Update'
				-- select count(cds.container_id)
				-- delete from ContainerDisposalStatus
			from ContainerDisposalStatus cds
			join #Inventory i
				on cds.company_id = i.company_id
				and cds.profit_ctr_id = i.profit_ctr_id
				and cds.receipt_id = i.receipt_id
				and cds.line_id = i.line_id
				and cds.container_id = i.container_id
			where cds.final_disposal_status = 'C'
			if @@rowcount = 0 break
		end
		
set @tempcount = 0
	
insert ContainerDisposalStatus_Log select
'ContainerDisposalStatus updated to void based on disposed, now re-opened containers', datediff(ms, @dStartTime, getdate()), datediff(ms, @dLastTime, getdate()), @dStartTime; set @dLastTime = getdate()

--#endregion

-- 4c.  Void CDS rows where the weight came from a receipt and that receipt has since been updated.

		if object_id('tempdb..#cds_update') is not null 	drop table #cds_update		

		select r.receipt_id, r.line_id, r.company_id, r.profit_ctr_id
		into #cds_update
		from Receipt r (nolock)
		INNER JOIN Container cr (nolock)
			 on r.receipt_id = cr.receipt_id
			 and r.line_id = cr.line_id
			 and r.company_id = cr.company_id
			 and r.profit_ctr_id = cr.profit_ctr_id
			and isnull(cr.container_weight, 0) = 0
		where exists (
			select 1 from ContainerDisposalStatus cds (nolock)
			WHERE r.receipt_id = cds.receipt_id
			 and r.line_id = cds.line_id
			 and r.company_id = cds.company_id
			 and r.profit_ctr_id = cds.profit_ctr_id
			 and cds.final_disposal_date > '1/1/1900' 
			 and cds.final_disposal_status in ('C')
			 and r.date_modified > cds.date_added
		)

insert ContainerDisposalStatus_Log select
'#cds_update created/populated from Receipt/ContainerDisposalStatus', datediff(ms, @dStartTime, getdate()), datediff(ms, @dLastTime, getdate()), @dStartTime; set @dLastTime = getdate()

		select @tempcount = count(*)
		from #cds_update	
	
insert ContainerDisposalStatus_Log select
'@tempcount updated from #cds_count, count: ' + convert(varchar(10), @tempcount), datediff(ms, @dStartTime, getdate()), datediff(ms, @dLastTime, getdate()), @dStartTime; set @dLastTime = getdate()


	if 0 < @tempcount begin
	
		UPDATE ContainerDisposalStatus SET
		-- select cds.*,
		final_disposal_status = 'V'
		, date_modified = getdate()
		, modified_by = 'CDS-Update'
		from ContainerDisposalStatus cds (nolock)
		join #cds_update u
			on cds.receipt_id = u.receipt_id
			and cds.line_id = u.line_id
			and cds.company_id = u.company_id
			and cds.profit_ctr_id = u.profit_ctr_id
		where cds.final_disposal_status in ('C')
		and cds.final_disposal_date > '1/1/1900'

	end

set @tempcount = 0

insert ContainerDisposalStatus_Log select
'ContainerDisposalStatus updated to void rows where the weight came from a receipt and that receipt has since been updated', datediff(ms, @dStartTime, getdate()), datediff(ms, @dLastTime, getdate()), @dStartTime; set @dLastTime = getdate()


-- 5.	Insert #Inventory records for Receipt Containers to CDS as new "Not Complete" records.
--#region Add Inventory to ContainerDisposalStatus

-- shortcut?
if object_id('tempdb..#InvSummary') is not null 	drop table #InvSummary		

select
		j.receipt_id
		, j.line_id
		, j.company_id
		, j.profit_ctr_id
		, j.container_id
		, j.container_type
		, max(j.ultimate_disposal_date) final_disposal_date
		, c.container_weight
	into #InvSummary
	from #Inventory j
	join Container c
		on j.receipt_id = c.receipt_id
		and j.line_id = c.line_id
		and j.company_id = c.company_id
		and j.profit_ctr_id = c.profit_ctr_id
		and j.container_id = c.container_id
		and c.status NOT IN ('V', 'R')
	-- where 
	-- j.container_type = 'R'
--	and isnull(c.container_weight, 0) = 0
	group by
		j.receipt_id
		, j.line_id
		, j.company_id
		, j.profit_ctr_id
		, j.container_id
		, j.container_type
		, c.container_weight 

insert ContainerDisposalStatus_Log select
'#InvSummary created/populated', datediff(ms, @dStartTime, getdate()), datediff(ms, @dLastTime, getdate()), @dStartTime; set @dLastTime = getdate()

--?? Ok/faster to put this in a copy of CDS then insert later?



	insert ContainerDisposalStatus (
		receipt_id
		, line_id
		, company_id
		, profit_ctr_id
		, container_id
		, container_type
		, final_disposal_date
		, final_disposal_status
		, disposal_revenue_amt
		, pounds
		, added_by
		, date_added
		, modified_by
		, date_modified
	)
	select 
		j.receipt_id
		, j.line_id
		, j.company_id
		, j.profit_ctr_id
		, j.container_id
		, j.container_type
		, j.final_disposal_date
		, 'N' final_disposal_status
		, -123456789 disposal_revenue_amt -- dbo.fn_get_container_disposal_revenue_amt (j.company_id, j.profit_ctr_id, j.receipt_id, j.line_id)
		, case when isnull(j.container_weight, 0) > 0 then j.container_weight else -123456789 end as pounds
		, 'CDS-Update'
		, getdate()
		, 'CDS-Update'
		, getdate()
	from #InvSummary j
-- 58070 (0:18)

select @tempcount = count(*) from #InvSummary

insert ContainerDisposalStatus_Log select
'ContainerDisposalStatus inserts from #InvSummary with dummy revenue and weights finished.  count:' + convert(Varchar(10), @tempcount), datediff(ms, @dStartTime, getdate()), datediff(ms, @dLastTime, getdate()), @dStartTime; set @dLastTime = getdate()
		

--#endregion

-- 6.	Find the set of ContainerDestination records that are recently disposed.
-- 	a.	ContainerDestination Disposal Date between max(date_disposed) in CDS -1, until getdate() and status is processed or outbound.
-- 		i.	Slightly modified sp_container_inventory_calc for Disposed status date range.
--	b.	Store them in #JustDisposed
-- 	c.	Trace backward from those and add to #JustDisposed, all their ancestors (now also considered disposed) û This is also part of sp_container_inventory_calc already.

--#region Gather Recently Disposed Container Data

-- On 3/18/2015, changed this to take all Container records that are: 
--		1. Not in the #Inventory table, meaning they are not "Not Complete" containers,
--		2. Not in the ContainerDisposalStatus table, meaning they are not already Complete.

		--DROP TABLE #JustDisposed
	
		if object_id('tempdb..#JustDisposed') is not null 	drop table #JustDisposed		
		
		SELECT DISTINCT
			c.company_id
			, c.profit_ctr_id
			, c.receipt_id
			, c.line_id
			, c.container_id
			, c.container_type
			, c.container_weight
		INTO #JustDisposed 
		FROM Container c
		WHERE c.status NOT IN ('V', 'R')
--		and receipt_id = 1085636 and line_id = 1 and company_id = 21		
		AND c.container_type = 'R'
		AND NOT EXISTS (SELECT 1 FROM #Inventory i
			WHERE i.company_id = c.company_id
			AND i.profit_ctr_id = c.profit_ctr_id
			AND i.receipt_id = c.receipt_id
			AND i.line_id = c.line_id
			AND i.container_id = c.container_id
			)
		AND NOT EXISTS (SELECT 1 FROM ContainerDisposalStatus cds
			WHERE cds.company_id = c.company_id
			AND cds.profit_ctr_id = c.profit_ctr_id
			AND cds.receipt_id = c.receipt_id
			AND cds.line_id = c.line_id
			AND cds.container_id = c.container_id
			AND cds.final_disposal_status not in ('V')
			)
	-- 1,053,731

select @tempcount = count(*) from #JustDisposed

insert ContainerDisposalStatus_Log select
'#JustDisposed created/populated, count: ' + convert(varchar(10), @tempcount), datediff(ms, @dStartTime, getdate()), datediff(ms, @dLastTime, getdate()), @dStartTime; set @dLastTime = getdate()

		--SELECT * FROM #Inventory WHERE receipt_id = 2404 AND company_id = 32

		create index idx_tmp on #JustDisposed (
			company_id
			, profit_ctr_id
			, receipt_id
			, line_id
			, container_id
			, container_type
		)

insert ContainerDisposalStatus_Log select
'#JustDisposed indexed', datediff(ms, @dStartTime, getdate()), datediff(ms, @dLastTime, getdate()), @dStartTime; set @dLastTime = getdate()

--#endregion

-- 7.	Insert to CDS as new Disposed records, any #JustDisposed records that arenÆt already in CDS as Disposed or Current status.
--#region Disposed Containers going into CDS

--SELECT * FROM #Inventory WHERE receipt_id = 2404 
--SELECT * FROM #JustDisposed WHERE receipt_id = 2404 

	-- Containers with a weight > 0/null.
	INSERT ContainerDisposalStatus (
		receipt_id
		, line_id
		, company_id
		, profit_ctr_id
		, container_id
		, container_type
		, final_disposal_date
		, final_disposal_status
		, disposal_revenue_amt
		, pounds
		, added_by
		, date_added
		, modified_by
		, date_modified
	)
	SELECT DISTINCT
		j.receipt_id
		, j.line_id
		, j.company_id
		, j.profit_ctr_id
		, j.container_id
		, j.container_type
		--, MAX(j.ultimate_disposal_date) AS final_disposal_date
		, dbo.fn_get_container_max_disposal_date (j.company_id, j.profit_ctr_id, j.receipt_id, j.line_id, j.container_id, j.container_type, NULL, NULL) AS final_disposal_date
		, 'C' AS final_disposal_status
 		, -123456789 disposal_revenue_amt -- dbo.fn_get_container_disposal_revenue_amt (j.company_id, j.profit_ctr_id, j.receipt_id, j.line_id)
		, case when ISNULL(j.container_weight, 0) > 0 then j.container_weight else -123456789 end AS pounds
		, 'CDS-Update'
		, GETDATE()
		, 'CDS-Update'
		, GETDATE()
	FROM #JustDisposed j

insert ContainerDisposalStatus_Log select
'ContainerDisposalStatus populated from #JustDisposed with dummy weights', datediff(ms, @dStartTime, getdate()), datediff(ms, @dLastTime, getdate()), @dStartTime; set @dLastTime = getdate()

--#endregion

-- We inserted weights with dummy -123456789 values above to save time.  Fix them:
--#region Fix dummy -123456789 weights used above to save time.


	-- The query version with subqueries below is obviously slower than one without them.
	-- step 1 then:
			UPDATE ContainerDisposalStatus SET
			-- select 
			pounds = r.line_weight / r.container_count
			-- select c.*
			From ContainerDisposalStatus c
			inner join receipt r
				on c.receipt_id = r.receipt_id
				and c.line_id = r.line_id
				and c.company_id = r.company_id
				and c.profit_ctr_id = r.profit_ctr_id
			where c.pounds = -123456789
			and isnull(c.final_disposal_date, '1/1/1901') > '1/1/1900'
			and ISNULL(r.line_weight, 0) > 0

select @tempcount = @@rowcount
insert ContainerDisposalStatus_Log select
'ContainerDisposalStatus dummy weights populated with line_weights, count:' + convert(varchar(10), @tempcount), datediff(ms, @dStartTime, getdate()), datediff(ms, @dLastTime, getdate()), @dStartTime; set @dLastTime = getdate()

			UPDATE ContainerDisposalStatus SET
			-- select 
			pounds = convert(float, r.manifest_quantity) / r.container_count
			-- select c.*
			From ContainerDisposalStatus c
			inner join receipt r
				on c.receipt_id = r.receipt_id
				and c.line_id = r.line_id
				and c.company_id = r.company_id
				and c.profit_ctr_id = r.profit_ctr_id
			where c.pounds = -123456789
			and isnull(c.final_disposal_date, '1/1/1901') > '1/1/1900'
			and r.manifest_unit = 'P'

select @tempcount = @@rowcount
insert ContainerDisposalStatus_Log select
'ContainerDisposalStatus dummy weights populated with manifested pounds, count:' + convert(varchar(10), @tempcount), datediff(ms, @dStartTime, getdate()), datediff(ms, @dLastTime, getdate()), @dStartTime; set @dLastTime = getdate()

			UPDATE ContainerDisposalStatus SET
			-- select 
			pounds = convert(float, (r.manifest_quantity * 2000.0)) / r.container_count
			-- select c.*
			From ContainerDisposalStatus c
			inner join receipt r
				on c.receipt_id = r.receipt_id
				and c.line_id = r.line_id
				and c.company_id = r.company_id
				and c.profit_ctr_id = r.profit_ctr_id
			where c.pounds = -123456789
			and isnull(c.final_disposal_date, '1/1/1901') > '1/1/1900'
			and r.manifest_unit = 'T'

select @tempcount = @@rowcount
insert ContainerDisposalStatus_Log select
'ContainerDisposalStatus dummy weights populated with manifested tons, count:' + convert(varchar(10), @tempcount), datediff(ms, @dStartTime, getdate()), datediff(ms, @dLastTime, getdate()), @dStartTime; set @dLastTime = getdate()
	

		-- step 2: Hairy bigger update in chunks

		while 1=1 begin
			UPDATE top (256) ContainerDisposalStatus SET
		-- select 
			pounds = COALESCE
				(
					-- 4.	Manifested Unit (not lbs/tons) Converted to pounds -- Calculated
					CASE WHEN r.manifest_unit in (select manifest_unit from billunit where isnull(manifest_unit, '') not in ('P', 'T', '')) THEN convert(float, ((r.manifest_quantity * (select pound_conv from billunit where isnull(manifest_unit, '') = r.manifest_unit)) ) ) END,
					-- 5.	Billed Unit (not lbs/tons) converted to pounds -- Calculated
					CASE WHEN EXISTS (SELECT 1 FROM ReceiptPrice rp (nolock)
						WHERE r.receipt_id = rp.receipt_id
						AND r.company_id = rp.company_id
						AND r.profit_ctr_id = rp.profit_ctr_id
						AND r.line_id = rp.line_id
						AND rp.bill_unit_code in (select bill_unit_code from billunit where isnull(pound_conv, 0) <> 0 and bill_unit_code not in ('LBS', 'TON', ''))
					) THEN ((SELECT SUM(bill_quantity * bu.pound_conv) FROM ReceiptPrice rp (nolock)
						INNER JOIN BillUnit bu (nolock) on rp.bill_unit_code = bu.bill_unit_code 
						and isnull(bu.pound_conv, 0) <> 0 
						and bu.bill_unit_code not in ('LBS', 'TON', '')
						WHERE r.receipt_id = rp.receipt_id
						AND r.company_id = rp.company_id
						AND r.profit_ctr_id = rp.profit_ctr_id
						AND r.line_id = rp.line_id
						--GROUP BY rp.bill_unit_code
					) ) END,
					
					-- 6.  JPB TEST - Billed units in TONS/LBS.
					CASE WHEN EXISTS (SELECT 1 FROM ReceiptPrice rp (nolock)
						WHERE r.receipt_id = rp.receipt_id
						AND r.company_id = rp.company_id
						AND r.profit_ctr_id = rp.profit_ctr_id
						AND r.line_id = rp.line_id
						AND rp.bill_unit_code in (select bill_unit_code from billunit where isnull(pound_conv, 0) <> 0 and bill_unit_code in ('LBS', 'TON', ''))
					) THEN ((SELECT SUM(bill_quantity * bu.pound_conv) FROM ReceiptPrice rp (nolock)
						INNER JOIN BillUnit bu (nolock) on rp.bill_unit_code = bu.bill_unit_code 
						and isnull(bu.pound_conv, 0) <> 0 
						and bu.bill_unit_code in ('LBS', 'TON', '')
						WHERE r.receipt_id = rp.receipt_id
						AND r.company_id = rp.company_id
						AND r.profit_ctr_id = rp.profit_ctr_id
						AND r.line_id = rp.line_id
						--GROUP BY rp.bill_unit_code
					) ) END,
					
					-- If all else fails... zero
					0
				) / r.container_count
			-- select c.*
		From ContainerDisposalStatus c
		inner join receipt r
			on c.receipt_id = r.receipt_id
			and c.line_id = r.line_id
			and c.company_id = r.company_id
			and c.profit_ctr_id = r.profit_ctr_id
		where c.pounds = -123456789
		and isnull(c.final_disposal_date, '1/1/1901') > '1/1/1900'
		if @@rowcount = 0 break
	end

insert ContainerDisposalStatus_Log select
'ContainerDisposalStatus rows from receipts updated with calculated weights where dummy values were present', datediff(ms, @dStartTime, getdate()), datediff(ms, @dLastTime, getdate()), @dStartTime; set @dLastTime = getdate()


-- Now there still are some left (stock containers, etc) with a dummy weight
-- that needs to be fixed - do them the old way:

	while 1=1 begin
		UPDATE top (256) ContainerDisposalStatus SET
	-- select 
		pounds = c.container_weight
	From ContainerDisposalStatus cds
	join container c
		on cds.company_id = c.company_id
		and cds.profit_ctr_id = c.profit_ctr_id
		and cds.container_type = c.container_type
		and cds.receipt_id = c.receipt_id
		and cds.line_id = c.line_id
		and cds.container_id = c.container_id
	where cds.pounds = -123456789
	and isnull(cds.final_disposal_date, '1/1/1901') > '1/1/1900'
	and isnull(cds.pounds, 0) <> isnull(c.container_weight, 0)
	if @@rowcount = 0 break
	end

insert ContainerDisposalStatus_Log select
'ContainerDisposalStatus rows (any) updated with calculated weights where dummy values were present', datediff(ms, @dStartTime, getdate()), datediff(ms, @dLastTime, getdate()), @dStartTime; set @dLastTime = getdate()

	-----------------------------------------------------------
	-- Update disposal revenue amount here
	-----------------------------------------------------------
	declare @update_time datetime
	
	-- There are MANY duplicated rows in CDS for receipt keys (multiple containers per row, etc)
	-- Get the distinct keys (since that's what the prices update on anyway)
	SELECT distinct c.company_id, c.profit_ctr_id, c.receipt_id, c.line_id
	, convert(money,  -123456789) as disposal_revenue_amt
	into #CDSReceiptKeys
	From ContainerDisposalStatus c
	where c.disposal_revenue_amt = -123456789
	and isnull(c.final_disposal_date, '1/1/1901') > '1/1/1900'

select @tempcount = count(*) from #CDSReceiptKeys 

insert ContainerDisposalStatus_Log select
'#CDSReceiptKeys created from distinct ContainerDisposalStatus receipt info, count: ' + convert(Varchar(10), @tempcount), datediff(ms, @dStartTime, getdate()), datediff(ms, @dLastTime, getdate()), @dStartTime; set @dLastTime = getdate()

	update #CDSReceiptKeys set disposal_revenue_amt = 0.00 where receipt_id = 0

insert ContainerDisposalStatus_Log select
'#CDSReceiptKeys updated for receipt_id 0', datediff(ms, @dStartTime, getdate()), datediff(ms, @dLastTime, getdate()), @dStartTime; set @dLastTime = getdate()

-- Shortcut - update from Billing if it already exists, en masse.  Way faster than calling a fn on each line.
update #CDSReceiptKeys
set disposal_revenue_amt = round(x.extended_amt_sum / (r.container_count * 1.0),2)
from #CDSReceiptKeys k
inner join (
	select k1.*, sum(extended_amt) extended_amt_sum
	from #CDSReceiptKeys k1
	join Billing b
		on b.company_id = k1.company_id
		and b.profit_ctr_id = k1.profit_ctr_id
		and b.receipt_id = k1.receipt_id
		and b.line_id = k1.line_id
		and b.trans_source = 'R'
	join  BillingDetail bd (nolock)
		on b.billing_uid = bd.billing_uid
	where bd.billing_type = 'Disposal'
	and k1.disposal_revenue_amt = -123456789
	group by
	k1.company_id, k1.profit_ctr_id, k1.receipt_id, k1.line_id, k1.disposal_revenue_amt
) x
	on x.company_id = k.company_id
	and x.profit_ctr_id = k.profit_ctr_id
	and x.receipt_id = k.receipt_id
	and x.line_id = k.line_id
inner join Receipt r
	on r.company_id = k.company_id
	and r.profit_ctr_id = k.profit_ctr_id
	and r.receipt_id = k.receipt_id
	and r.line_id = k.line_id
	and r.container_count > 0

select @tempcount = count(*) from #CDSReceiptKeys where disposal_revenue_amt <> -123456789
				
insert ContainerDisposalStatus_Log select
'#CDSReceiptKeys updated for data already in Billing, count:' + convert(Varchar(10), @tempcount), datediff(ms, @dStartTime, getdate()), datediff(ms, @dLastTime, getdate()), @dStartTime; set @dLastTime = getdate()

-- Call the fn on each line remaining to set.		
	while 1=1 begin

		update top (1000) #CDSReceiptKeys
		set disposal_revenue_amt = dbo.fn_get_container_disposal_revenue_amt (c.company_id, c.profit_ctr_id, c.receipt_id, c.line_id)
		from #CDSReceiptKeys c
		where disposal_revenue_amt = -123456789	

		if @@rowcount = 0 break

insert ContainerDisposalStatus_Log select
'#CDSReceiptKeys updated for 1000 rows', datediff(ms, @dStartTime, getdate()), datediff(ms, @dLastTime, getdate()), @dStartTime; set @dLastTime = getdate()


	end


insert ContainerDisposalStatus_Log select
'#CDSReceiptKeys updates finished', datediff(ms, @dStartTime, getdate()), datediff(ms, @dLastTime, getdate()), @dStartTime; set @dLastTime = getdate()

	-- Update CDS from #CDSReceiptKeys
		set @update_time = getdate()
		UPDATE ContainerDisposalStatus SET
		-- select *,
		disposal_revenue_amt = k.disposal_revenue_amt
		, date_modified = @update_time
		-- SELECT COUNT(*)
		From ContainerDisposalStatus c
		inner join #CDSReceiptKeys k
		on c.receipt_id = k.receipt_id
		and c.line_id = k.line_id
		and c.company_id = k.company_id
		and c.profit_ctr_id = k.profit_ctr_id
		where c.disposal_revenue_amt = -123456789
		and isnull(c.final_disposal_date, '1/1/1901') > '1/1/1900'
		
insert ContainerDisposalStatus_Log select
'ContainerDisposalStatus updated from #CDSReceiptKeys where dummy values were present', datediff(ms, @dStartTime, getdate()), datediff(ms, @dLastTime, getdate()), @dStartTime; set @dLastTime = getdate()

/*
	-- Maybe we can set sibling containers from the set that just got updated and save some calc-time.	
		Update ContainerDisposalStatus set disposal_revenue_amt = cds2.disposal_revenue_amt
		from  ContainerDisposalStatus cds (nolock)
		inner join (
				Select
					company_id
					, profit_ctr_id
					, receipt_id
					, line_id
					, final_disposal_status
					, disposal_revenue_amt
					, pounds
					, date_added
					, count(*) _count
				from ContainerDisposalStatus cds2 (nolock)
				where 
					disposal_revenue_amt <> -123456789
					and date_modified = @update_time
				group by
					company_id
					, profit_ctr_id
					, receipt_id
					, line_id
					, final_disposal_status
					, disposal_revenue_amt
					, pounds
					, date_added
				having 
					count(distinct disposal_revenue_amt) = 1
		)cds2
			on cds2.receipt_id = cds.receipt_id
			and cds2.line_id = cds.line_id
			and cds2.company_id = cds.company_id
			and cds2.profit_ctr_id = cds.profit_ctr_id
			and cds2.final_disposal_status = cds.final_disposal_status
			and cds2.pounds = cds.pounds
			and cds2.date_added = cds.date_added
		where
			cds.disposal_revenue_amt = -123456789	
	
		print ''		
		
insert ContainerDisposalStatus_Log select
'ContainerDisposalStatus rows updated with disposal_revenue_amt where sibling (same receipt-line-weight) rows could be copied from just-updated rows instead of re-calc.', datediff(ms, @dStartTime, getdate()), datediff(ms, @dLastTime, getdate()), @dStartTime; set @dLastTime = getdate()
		
	end
	-- 41k rows, 31 minutes
-- 1,201,849 (1:15:38)

	-- One more attempt afterward:
		Update ContainerDisposalStatus set disposal_revenue_amt = cds2.disposal_revenue_amt
		from  ContainerDisposalStatus cds (nolock)
		inner join (
				Select
					company_id
					, profit_ctr_id
					, receipt_id
					, line_id
					, final_disposal_status
					, disposal_revenue_amt
					, pounds
					, date_added
					, count(*) _count
				from ContainerDisposalStatus cds2 (nolock)
				where 
					disposal_revenue_amt <> -123456789
				group by
					company_id
					, profit_ctr_id
					, receipt_id
					, line_id
					, final_disposal_status
					, disposal_revenue_amt
					, pounds
					, date_added
				having 
					count(*) = 1
		)cds2
			on cds2.receipt_id = cds.receipt_id
			and cds2.line_id = cds.line_id
			and cds2.company_id = cds.company_id
			and cds2.profit_ctr_id = cds.profit_ctr_id
			and cds2.final_disposal_status = cds.final_disposal_status
			and cds2.pounds = cds.pounds
			and cds2.date_added = cds.date_added
		where
			cds.disposal_revenue_amt = -123456789	
				
insert ContainerDisposalStatus_Log select
'ContainerDisposalStatus rows updated with disposal_revenue_amt as a catch-all where dummy values are STILL present', datediff(ms, @dStartTime, getdate()), datediff(ms, @dLastTime, getdate()), @dStartTime; set @dLastTime = getdate()

*/

-- SELECT * FROM ContainerDisposalStatus WHERE final_disposal_date >= '1/1/14'

--#endregion

insert ContainerDisposalStatus_Log select
'ContainerDisposalStatus end of updates', datediff(ms, @dStartTime, getdate()), datediff(ms, @dLastTime, getdate()), @dStartTime; set @dLastTime = getdate()


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_update_ContainerDisposalStatus] TO [EQAI]
    AS [dbo];

