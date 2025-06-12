CREATE PROC sp_container_inventory_calc (
	@copc_list			varchar(max) = NULL -- Optional list of companies/profitcenters to limit by
	, @disposed_flag	char(1)				-- 'D'isposed or 'U'ndisposed
	, @as_of_date		datetime = NULL		-- Billing records are run AS OF @as_of_date. Defaults to current date.
)
AS
/* *****************************************************************************************************

sp_container_inventory_calc
	Recursive container retrieval for current (as of @as_of_date ) Un/Disposed inventory set.
	
1. Collect an initial set of containers into #ContainerInventory (either open or closed-to-final-disposition
2. Find all ancestors of the containers, add them into the same #ContainerInventory table
3. IF looking for Disposed containers only,
		join #ContainerInventory against ContainerDestination - any open containers in ContainerDestination
		mean the whole #ContainerInventory history is considered open


History:
	2015-10-21 - Found a case where a weight had been based on receipt line_weight which was changed
		after the CDS record was created - and the container record was already considered closed
		so the receipt weight <> CDS weight and never updated.
		Needed to add an inclusion to updates where weight was based on receipt and receipt date modified is after container date.

	2022-03-10 AGC DevOps 30107 changed disposed logic to: (is the container flagged as put into a process 
		OR (linked to an outbound AND the outbound is set to accepted status)) 
		AND is the disposal date in the past.

	2022-04-12 JPB DevOps 40347 changed disposed logic to fix the outbound receipt verification
		Should be checking tracking-num, not receipt_id & line_id (those point at the inbound, not the outbound)

Returns populated #ContainerInventory table.
Rows have 1 of 3 status: Disposed, Undisposed

Assumes this table is created:

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

drop table #profitcenter_filter

		exec sp_container_inventory_calc 
			@copc_list			= NULL	-- Optional list of companies/profitcenters to limit by
			, @disposed_flag	= 'U'	-- 'D'isposed or 'U'ndisposed
			, @as_of_date		= NULL	-- Billing records are run AS OF @as_of_date. Defaults to current date.

		-- 00:30.    100,442 rows.  This ignores modified receipt records.  The old normal.
		-- 17:26.  2,621,454 rows.  This includes modified receipt records.  The new normal.

SELECT  *
FROM    #ContainerInventory where receipt_id = 1085636 and line_id = 1 and company_id = 21

SELECT  *
FROM    ContainerDisposalStatus where receipt_id = 1085636 and line_id = 1 and company_id = 21

SELECT  *
INTO jpb_ContainerInventory
FROM    #ContainerInventory

sp_helptext sp_update_ContainerDisposalStatus

***************************************************************************************************** */

SET NOCOUNT ON
SET ANSI_WARNINGS OFF
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

-- 		declare @copc_list varchar(max) = '21|0', @disposed_flag char(1) = 'U', @as_of_date datetime = '6/17/2014'



if @as_of_date is null set @as_of_date = getdate()

-- If the @as_of_date's hour value is 0, it's been given as just a date.  Extended it through end-of-day on that date.
if datepart(hh, @as_of_date ) = 0 set @as_of_date = @as_of_date + 0.99999


-- Verify temp table index exists, or add it.
if not exists (
	SELECT 1
	FROM tempdb.sys.indexes 
	WHERE object_id = OBJECT_ID('tempdb..#ContainerInventory')
	AND name is not null
)
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

-- Handle copc_list:

	if OBJECT_ID('tempdb..#profitcenter_filter') is not null
		drop table #profitcenter_filter


	CREATE TABLE #profitcenter_filter (
		company_id int
		, profit_ctr_id int
	)

	if @copc_list IS NULL
		-- No value given = use any/all.
		insert #profitcenter_filter
		select company_id, profit_ctr_id
		from profitcenter
	ELSE
		-- Value given = limit to that value list
		insert #profitcenter_filter
		select tmp.company_id, tmp.profit_ctr_id
		from dbo.fn_web_profitctr_parse(@copc_list) tmp

-- A counter for tracking iterations in the loop below.
declare @n int
declare @OpenSetCreated int = 0

-- A marker for where the process begins, used when we first collect "Open" containers, then repeat
-- to collect "Closed" containers using the same logic.  Uses Goto.  Ick.  But effective.
ContainerLoop:

-- Create Open Container set first, it's always needed.
-- if @OpenSetCreated = 0

	insert #ContainerInventory
		select 
		0 -- Generation
		, 'Undisposed' -- Open = Undisposed, fyi.
		, null -- Disposal Date
		, cd.receipt_id -- Inventory fields...
		, cd.line_id
		, cd.container_id
		, cd.sequence_id
		, cd.* -- All fields from ContainerDestination
	from ContainerDestination cd (nolock) 
	INNER JOIN #profitcenter_filter f on cd.company_id = f.company_id and cd.profit_ctr_id = f.profit_ctr_id
	where 1=1
		-- We only want Stock containers, OR Receipt containers from valid, non-rejected/voided, inbound disposal receipt lines.
		and cd.container_type = 'S'
		and cd.status not in ('C', 'R', 'V') -- Open
union
-- declare @as_of_date datetime = getdate()
		select 
		0 -- Generation
		, 'Undisposed' -- Open = Undisposed, fyi.
		, null -- Disposal Date
		, cd.receipt_id -- Inventory fields...
		, cd.line_id
		, cd.container_id
		, cd.sequence_id
		, cd.* -- All fields from ContainerDestination
	from ContainerDestination cd (nolock) 
	INNER JOIN #profitcenter_filter f on cd.company_id = f.company_id and cd.profit_ctr_id = f.profit_ctr_id
	where 1=1
		-- We only want Stock containers, OR Receipt containers from valid, non-rejected/voided, inbound disposal receipt lines.
		and cd.container_type = 'S'
		and
			-- Or it can be Closed now, but it must have been closed after the end of our date range
			cd.status in ('C') 
			-- coalescing the date because it's missing on some closed records
			and coalesce(cd.disposal_date, cd.date_modified) > @as_of_date
			-- we're stopping at getdate() because there's some goofy future records (year 9006)
			and coalesce(cd.disposal_date, cd.date_modified) < getdate()
union
-- declare @as_of_date datetime = getdate()

		select 
		0 -- Generation
		, 'Undisposed' -- Open = Undisposed, fyi.
		, null -- Disposal Date
		, cd.receipt_id -- Inventory fields...
		, cd.line_id
		, cd.container_id
		, cd.sequence_id
		, cd.* -- All fields from ContainerDestination
	from ContainerDestination cd (nolock) 
	INNER JOIN #profitcenter_filter f on cd.company_id = f.company_id and cd.profit_ctr_id = f.profit_ctr_id
	INNER JOIN receipt r (nolock)
		on r.receipt_id = cd.receipt_id
		and r.line_id = cd.line_id
		and r.company_id = cd.company_id
		and r.profit_ctr_id = cd.profit_ctr_id
		and r.fingerpr_status in ('W', 'H', 'A')
		and r.trans_type = 'D'
		and r.trans_mode = 'I'
		and r.receipt_status not in ('V', 'R')
	where 1=1
	and cd.container_type = 'R'
	and cd.status not in ('C', 'R', 'V') -- Open
	
union
-- declare @as_of_date datetime = getdate()
		select 
		0 -- Generation
		, 'Undisposed' -- Open = Undisposed, fyi.
		, null -- Disposal Date
		, cd.receipt_id -- Inventory fields...
		, cd.line_id
		, cd.container_id
		, cd.sequence_id
		, cd.* -- All fields from ContainerDestination
	from ContainerDestination cd (nolock) 
	INNER JOIN #profitcenter_filter f on cd.company_id = f.company_id and cd.profit_ctr_id = f.profit_ctr_id
	INNER JOIN receipt r (nolock)
		on r.receipt_id = cd.receipt_id
		and r.line_id = cd.line_id
		and r.company_id = cd.company_id
		and r.profit_ctr_id = cd.profit_ctr_id
		and r.fingerpr_status in ('W', 'H', 'A')
		and r.trans_type = 'D'
		and r.trans_mode = 'I'
		and r.receipt_status not in ('V', 'R')
	where 1=1
	and cd.container_type = 'R'
	and
			-- Or it can be Closed now, but it must have been closed after the end of our date range
			cd.status in ('C') 
			-- coalescing the date because it's missing on some closed records
			and coalesce(cd.disposal_date, cd.date_modified) > @as_of_date
			-- we're stopping at getdate() because there's some goofy future records (year 9006)
			and coalesce(cd.disposal_date, cd.date_modified) < getdate()

/*
-- Now a first-step temp for finding records based on receipt data where the receipt has changed.
select distinct cds.containerdisposalstatus_uid, cds.receipt_id, cds.line_id, cds.company_id, cds.profit_ctr_id, cds.container_id, cds.final_disposal_date
into #f1
from ContainerDisposalStatus cds (nolock)
INNER JOIN Receipt r (nolock) 
		 on r.receipt_id = cds.receipt_id
		 and r.line_id = cds.line_id
		 and r.company_id = cds.company_id
		 and r.profit_ctr_id = cds.profit_ctr_id
	INNER JOIN Container cr (nolock)
		 on r.receipt_id = cr.receipt_id
		 and r.line_id = cr.line_id
		 and r.company_id = cr.company_id
		 and r.profit_ctr_id = cr.profit_ctr_id
		and isnull(cr.container_weight, 0) = 0
where cds.final_disposal_date > '1/1/1900' and final_disposal_status in ('C', 'V')


-- second step:
	insert #ContainerInventory

		select 
		0 -- Generation
		, 'Undisposed' -- Open = Undisposed, fyi.
		, null -- Disposal Date
		, cd.receipt_id -- Inventory fields...
		, cd.line_id
		, cd.container_id
		, cd.sequence_id
		, cd.* -- All fields from ContainerDestination

-- select  cds.receipt_id, cds.line_id, cds.company_id, cds.profit_ctr_id
from #f1 cds
join receipt r
		 on r.receipt_id = cds.receipt_id
		 and r.line_id = cds.line_id
		 and r.company_id = cds.company_id
		 and r.profit_ctr_id = cds.profit_ctr_id
and r.date_modified > cds.final_disposal_date
				and r.fingerpr_status in ('W', 'H', 'A')
				and r.trans_type = 'D'
				and r.trans_mode = 'I'
				and r.receipt_status not in ('V', 'R')
join ContainerDestination cd (nolock) on cds.receipt_id = cd.receipt_id
		 and cds.line_id = cd.line_id
		 and cds.container_id = cd.container_id
		 and cd.sequence_id = cd.sequence_id
		 and cds.profit_ctr_id = cd.profit_ctr_id
		 and cds.company_id = cd.company_id
				and cd.container_type = 'R'
				and cd.status = 'C'
*/

/* old:

	insert #ContainerInventory
		select 
		0 -- Generation
		, 'Undisposed' -- Open = Undisposed, fyi.
		, null -- Disposal Date
		, receipt_id -- Inventory fields...
		, line_id
		, container_id
		, sequence_id
		, cd.* -- All fields from ContainerDestination
	from ContainerDestination cd (nolock) 
	INNER JOIN #profitcenter_filter f on cd.company_id = f.company_id and cd.profit_ctr_id = f.profit_ctr_id
	where 1=1
	-- date_added <= @as_of_date
	-- DON'T limit to records added before end date.
	--  because records added after can be the only way
	--  to find valid inventory open during the date range.
	--  instead, we'll add them all now, remove them later.
	and (
		-- We only want Stock containers, OR Receipt containers from valid, non-rejected/voided, inbound disposal receipt lines.
		container_type = 'S'
		OR
		(
			container_type = 'R'
			and exists (
				select 1 from receipt r (nolock)
				where r.receipt_id = cd.receipt_id
				and r.line_id = cd.line_id
				and r.company_id = cd.company_id
				and r.profit_ctr_id = cd.profit_ctr_id
				and r.fingerpr_status in ('W', 'H', 'A')
				and r.trans_type = 'D'
				and r.trans_mode = 'I'
				and r.receipt_status not in ('V', 'R')
			)
		)
	)
	and (
		-- The containerdestination status must be open, in this set... not Closed, Rejected or Void
		status not in ('C', 'R', 'V') -- Open
		OR
		(
			-- Or it can be Closed now, but it must have been closed after the end of our date range
			status in ('C') 
			-- coalescing the date because it's missing on some closed records
			and coalesce(disposal_date, date_modified) > @as_of_date
			-- we're stopping at getdate() because there's some goofy future records (year 9006)
			and coalesce(disposal_date, date_modified) < getdate()
		)
		OR
		(
			-- 2015-10-21:
			-- Or it can be Closed now, but the weight was based on Receipt information that has been modified after it was closed.
			status in ('C') 
			and exists (
				select 1 from receipt r (nolock)
				left join container cr
					 on r.receipt_id = cr.receipt_id
					 and r.line_id = cr.line_id
					 and r.company_id = cr.company_id
					 and r.profit_ctr_id = cr.profit_ctr_id
				where r.receipt_id = cd.receipt_id
				and r.line_id = cd.line_id
				and r.company_id = cd.company_id
				and r.profit_ctr_id = cd.profit_ctr_id
				and r.fingerpr_status in ('W', 'H', 'A')
				and r.trans_type = 'D'
				and r.trans_mode = 'I'
				and r.receipt_status not in ('V', 'R')
				and r.date_modified > cd.date_modified
				and isnull(cr.container_weight, 0) = 0
			)
			
		)
	) -- Open	

*/

-- ELSE -- @OpenSetCreated was already 1, meaning the open set is already created.
	 --  ^This only happens below, after the initial loop, so in this branch, we're obviously working on the closed set:
	
	-- populate #ContainerInventory
	IF @disposed_flag = 'D' 
		-- ^ only if this is a disposal run. Otherwise it's not needed, but we pass through here anyway, so we'll skip this insert.

		insert #ContainerInventory
			select 
			0 -- Generation
			, 'Disposed' -- Open = Undisposed, fyi.  Closed = Disposed.
			, disposal_date -- Disposal Date
			, receipt_id -- Inventory fields...
			, line_id
			, container_id
			, sequence_id
			, cd.* -- All fields from ContainerDestination
		from ContainerDestination cd (nolock) 
		INNER JOIN #profitcenter_filter f on cd.company_id = f.company_id and cd.profit_ctr_id = f.profit_ctr_id
		where status = 'C' -- Completed
		-- date_added <= @as_of_date
		-- DON'T limit to records added before end date.
		--  because records added after can be the only way
		--  to find valid inventory open during the date range.
		--  instead, we'll add them all now, remove them later.
		and (
			-- We only want Stock containers, OR Receipt containers from valid, non-rejected/voided, inbound disposal receipt lines.
			container_type = 'S'
			OR
			(
				container_type = 'R'
				and  exists (
					select 1 from receipt r (nolock)
					where r.receipt_id = cd.receipt_id
					and r.line_id = cd.line_id
					and r.company_id = cd.company_id
					and r.profit_ctr_id = cd.profit_ctr_id
					and r.trans_type = 'D'
					and r.trans_mode = 'I'
					and r.fingerpr_status in ('W', 'H', 'A')
					and r.receipt_status not in ('V', 'R')
				)
			)
		)

		-- and disposal_date between -1 year prior up through @as_of_date
		and coalesce(disposal_date, date_modified) between dateadd(yyyy, -1, @as_of_date) AND @as_of_date

		-- The container was marked as Processed or Outbound-ed
		-- DevOps 30107 AGC 03/10/2022 changed to check if outbound has been accepted
		and (location_type = 'P'
		 or (location_type = 'O'
		and exists (
		        select 1
				from receipt o (nolock)
				where o.company_id = cd.company_id
				and o.profit_ctr_id = cd.profit_ctr_id
				and o.trans_mode = 'O'
				and convert(varchar(20), o.receipt_id) + '-' + convert(varchar(20), o.line_id)  = cd.tracking_num
				and o.manifest_flag <> 'X'
				and o.receipt_status = 'A')
				)
		    ) 

-- END of ELSE (Disposed set)

-- Set a generation counter value
set @n = 1

-- Loop over #ContainerInventory records that aren't processed yet.
while exists (select 1 from #ContainerInventory where generation = 0) begin

	-- Mark the "current" set with generation value -1.  We'll be adding new ones as 0 in a moment, don't want confusion
	update #ContainerInventory set generation = -1 where generation = 0
	
	-- Add additional rows to #ContainerInventory
	insert #ContainerInventory
	select 0 -- as generation 
		, o.ultimate_disposal_status	-- o. = the "related" record's info.  It's a child, but we are working backwards from youngest to oldest.
		, o.ultimate_disposal_date		-- The ultimate*, and inventory* fields
		, o.inventory_receipt_id		-- Come from the set being processed, NOT the new records being added.
		, o.inventory_line_id			-- This way each new set put into the table (ancestors) carries the
		, o.inventory_container_id		-- final information identifying the eventual descendant & disposal date
		, o.inventory_sequence_id
		, c.* -- Everything from ContainerDestination
	from #ContainerInventory o
	join ContainerDestination c (nolock) 
		-- New set (ancestors) have base_* fields that match their descendant (=destination.  "base_" is a bad name choice, imo)
	on c.base_container_id = o.container_id
	and c.base_sequence_id = o.sequence_id
	and c.company_id = o.company_id
	and c.profit_ctr_id = o.profit_ctr_id
	and c.base_tracking_num = CASE o.container_type
		WHEN 'S' THEN
			'DL-' + 
			right('00' + convert(varchar(2), o.company_id), 2) +
			right('00' + convert(varchar(2), o.profit_ctr_id), 2) +
			'-' +
			right('000000' + convert(varchar(6), o.container_id), 6)
		WHEN 'R' THEN
			convert(varchar(10), o.receipt_id) +
			'-' +
			convert(varchar(10), o.line_id)
		END
		-- We're only adding new records for the set currently being processed
	where o.generation = -1
	
	---- Separate runs for Open & Closed:
	--AND o.ultimate_disposal_status = CASE @OpenSetCreated
	--	WHEN 0 then 'Undisposed'
	--	ELSE 'Disposed'
	--END
	
	-- We keep getting the same record pulled in from multiple iterations.
	AND NOT EXISTS (
		select 1 from #ContainerInventory x
		where x.company_id = c.company_id
		and x.profit_ctr_id = c.profit_ctr_id
		and x.receipt_id = c.receipt_id
		and x.line_id = c.line_id
		and x.container_id = c.container_id
		and x.sequence_id = c.sequence_id
	)

		-- Now that we're done with adding new records to the table, let's mark the current set
		-- according to the iteration counter @n (so they're not processed again, AND so we can
		-- examine levels of ancestry, if wanted)
	update #ContainerInventory set generation = @n where generation = -1
	
		-- Now that we've assigned @n to a set of records, increment it for the next set to use.
	set @n = @n + 1
	
END
-- Now the looping is done.

-- If #OpenContainer doesn't exist yet - fill it from #WContainer, then empty #WContainer, then go back and run again for closed containers.
--IF @OpenSetCreated = 0 BEGIN

--	set @OpenSetCreated = 1
	
--	IF @disposed_flag = 'D' 
--		GOTO ContainerLoop

--END

-- We did not limit the original set of records to just those added before the @as_of_date
-- This was on purpose, because records added after might refer to records added during that
-- wouldn't have gotteen included otherwise.

-- Now that we're done with all that work, we want to clean a few things up:

	-- Get rid of records in the whole set that were created after our date range. We don't need/want them now.
		-- This can cause confusion though.  A record from AFTER the range might be identified as the inventory
		-- record (since it was the first one added to the table), and is now getting deleted.
		-- If that's happening, shouldn't any records that are referring to it get their inventory_ data updated?

-- 		declare @copc_list varchar(max) = NULL, @disposed_flag char(1) = 'U', @as_of_date datetime = '6/17/2014'
		
		-- Containers created after @as_of_date should be marked 'UnCreated'
		UPDATE #ContainerInventory set 
			ultimate_disposal_status = 'UnCreated'
		where date_added > @as_of_date

		-- Containers that reference an UnCreated container should reference themselves instead.
		UPDATE my_own set 
			-- my_own.ultimate_disposal_status = 'Undisposed'
			-- Don't set status to a value, it might wipe out UnCreated values.
			my_own.ultimate_disposal_date = NULL
			, my_own.inventory_receipt_id = my_own.receipt_id
			, my_own.inventory_line_id = my_own.line_id
			, my_own.inventory_container_id = my_own.container_id
			, my_own.inventory_sequence_id = my_own.sequence_id
		FROM #ContainerInventory my_own
		INNER JOIN #ContainerInventory uncreated
			ON 
			my_own.inventory_receipt_id = uncreated.receipt_id
			AND my_own.inventory_line_id = uncreated.line_id
			AND my_own.inventory_container_id = uncreated.container_id
			AND my_own.inventory_sequence_id = uncreated.sequence_id
			AND uncreated.ultimate_disposal_status = 'UnCreated'

		-- Containers disposed of AFTER the @as_of_date should reference themselves, not a future container.
		-- a lesson learned 8/5/2014 while answering why some deferred containers pointed to containers that didn't exist yet.
		UPDATE my_own set 
			-- my_own.ultimate_disposal_status = 'Undisposed'
			-- Don't set status to a value, it might wipe out UnCreated values.
			ultimate_disposal_date = NULL
			, inventory_receipt_id = my_own.receipt_id
			, inventory_line_id = my_own.line_id
			, inventory_container_id = my_own.container_id
			, inventory_sequence_id = my_own.sequence_id
		FROM #ContainerInventory my_own
		inner join container c
			on my_own.company_id = c.company_id
			and my_own.profit_ctr_id = c.profit_ctr_id
			and my_own.inventory_receipt_id = c.receipt_id
			and my_own.inventory_line_id = c.line_id
			and my_own.inventory_container_id = c.container_id
		WHERE isnull(my_own.disposal_date, getdate()) > @as_of_date


/*
fyi... 
Just EQPA (27), 
	Open only, as of 6/17: 1:36.
	Open & Closed, 6/17  : 10:09  Whew.

ALL copc
	Open & Closed, 6/17  : 

SELECT * FROM #ContainerInventory where company_id = 27 and ultimate_disposal_status = 'Disposed'
*/

-- Now anything in #OpenContainer IS OPEN, it's the hierarchy of open containers in the first place.
-- Now join ANY receipt joinable, to receipt, then to billing to get the number of containers in #opencontainer
-- as a percentage of the number of containers on that original receipt line
-- to apply to the revenue for that receipt line from billing.


-- If this is a disposal run and #OpenContainer already exists,
-- Then we need to update #WContainer statuses if they match #OpenContainer - because if they match, they're not closed.

update cd set ultimate_disposal_status = 'Undisposed'
from #ContainerInventory co
join #ContainerInventory cd
	on co.company_id = cd.company_id
	and co.profit_ctr_id = cd.profit_ctr_id
	and co.receipt_id = cd.receipt_id
	and co.line_id = cd.line_id
	and co.container_id = cd.container_id
where co.ultimate_disposal_status = 'Undisposed'
and cd.ultimate_disposal_status = 'Disposed'

delete from #ContainerInventory where ultimate_disposal_status = 'Uncreated'

-- SELECT count(*) FROM #ContainerInventory 
-- SELECT * FROM #ContainerInventory where company_id = 27


/*
fyi... 
Just EQPA (27), 
	Open only, as of 6/17: 0:17  Very nice.
	Open & Closed, 6/17  : 0:39  Whoa.  Yay for indexes & running both simultaneously.  This was 6minutes.

ALL copc
	Open only, as of 6/17: 01:29.
	Open & Closed, 6/17  : 5:06

SELECT * FROM #ContainerInventory where company_id = 27 and ultimate_disposal_status = 'Disposed'

select * into jpb_ContainerInventory1 from #ContainerInventory

select count(*) from jpb_ContainerInventory1 -- 49008
select count(*) from jpb_ContainerInventory2 -- 53169

select 53169 - 49008 -- 4161

select * from jpb_ContainerInventory1 a
	where not exists (
	select 1 from jpb_ContainerInventory2 b
	where a.receipt_id = b.receipt_id 
	and a.line_id = b.line_id
	and a.company_id = b.company_id
	and a.profit_ctr_id = b.profit_ctr_id
	and a.container_id = b.container_id
	and a.sequence_id = b.sequence_id
)
-- Nothing in A(1) that is not also in B(2)

select * from jpb_ContainerInventory2 a
	where not exists (
	select 1 from jpb_ContainerInventory1 b
	where a.receipt_id = b.receipt_id 
	and a.line_id = b.line_id
	and a.company_id = b.company_id
	and a.profit_ctr_id = b.profit_ctr_id
	and a.container_id = b.container_id
	and a.sequence_id = b.sequence_id
)
-- Nothing in A(1) that is not also in B(2)

select 
company_id, profit_ctr_id, receipt_id, line_id, container_id, sequence_id
, count(*)
from jpb_ContainerInventory1
group by company_id, profit_ctr_id, receipt_id, line_id, container_id, sequence_id
having count(*) > 1
-- 0 rows

select 
company_id, profit_ctr_id, receipt_id, line_id, container_id, sequence_id
, count(*)
from jpb_ContainerInventory2
group by company_id, profit_ctr_id, receipt_id, line_id, container_id, sequence_id
having count(*) > 3
-- 3818 rows = count > 1
-- 341 = count > 2
-- 2 = count > 3

select 341 + 3818 + 2 -- 4161



*/



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_container_inventory_calc] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_container_inventory_calc] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_container_inventory_calc] TO [EQAI]
    AS [dbo];

