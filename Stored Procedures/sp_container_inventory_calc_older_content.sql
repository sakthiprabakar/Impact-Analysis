DROP PROC IF EXISTS sp_container_inventory_calc_older_content
GO
CREATE PROC [dbo].[sp_container_inventory_calc_older_content] (
                @copc_list                                          varchar(max) = NULL -- Optional list of companies/profitcenters to limit by
                , @disposed_flag             char(1)                                                  -- 'D'isposed or 'U'ndisposed
                , @as_of_date                  datetime = NULL                               -- Billing records are run AS OF @as_of_date. Defaults to current date.
)
AS
/* *****************************************************************************************************
DevOps 39130 info_gde 07/27/2022; New Report > "Container Inventory (as of today) - Audit of Containers with Older Contents"

sp_container_inventory_calc_older_content
                Recursive container retrieval for current (as of @as_of_date ) Un/Disposed inventory set.
                
1. Collect an initial set of containers into #ContainerInventory (either open or closed-to-final-disposition
2. Find all ancestors of the containers, add them into the same #ContainerInventory table
3. IF looking for Disposed containers only,
                                join #ContainerInventory against ContainerDestination - any open containers in ContainerDestination
                                mean the whole #ContainerInventory history is considered open

EXEC sp_container_inventory_calc_older_content '21|00', 'U'
***************************************************************************************************** */

SET NOCOUNT ON
SET ANSI_WARNINGS OFF
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

if @as_of_date is null set @as_of_date = getdate()



declare @run_for_company_id int ,
	@run_for_profit_ctr_id int 


--SET @copc_list = '21|00';
SET @run_for_company_id = LEFT(@copc_list, 2) ;  
SET @run_for_profit_ctr_id = RIGHT(@copc_list, 2) ;

IF OBJECT_ID(N'tempdb..#ContainerInventoryWork') IS NOT NULL
BEGIN
	drop table #ContainerInventoryWork
END

select 
	'0' as 'processed_flag', 
	c.status as 'container_status', 
	cd.status as 'containerdestination_status', 
	c.date_added as 'oldest_contents_date', 
	c.container_type, 
	c.company_id, 
	c.profit_ctr_id, 
	c.receipt_id, 
	c.line_id, 
	c.container_id, 
	cd.sequence_id, 
	case 
		when c.container_type = 'R'
			then	r.receipt_date--(select top 1 format(receipt_date, 'MM/dd/yyyy') from receipt where company_id = c.company_id and profit_ctr_id = c.profit_ctr_id and receipt_id = c.receipt_id and c.container_type = 'R')
		when c.container_type = 'S'
			then c.date_added
		end as 'container_date'
into #ContainerInventoryWork
from container c (nolock)
join ContainerDestination cd (nolock) 
	on c.company_id = cd.company_id
	and c.profit_ctr_id = cd.profit_ctr_id
	and c.receipt_id = cd.receipt_id
	and c.line_id = cd.line_id
	and c.container_id = cd.container_id
left outer join Receipt r (nolock)
	on c.company_id = r.company_id
	and c.profit_ctr_id = r.profit_ctr_id
	and c.receipt_id = r.receipt_id
	and c.line_id = r.line_id
	and c.container_type = 'R'
	and r.receipt_status not in ('V', 'R')
	and r.fingerpr_status not in ('V', 'R')
where 
	c.company_id = @run_for_company_id 
	and c.profit_ctr_id = @run_for_profit_ctr_id 
	and cd.status in ('N')


update #ContainerInventoryWork set oldest_contents_date = NULL

--select * from #ContainerInventoryWork

--loop through the inventory work table
while (select count(*) from #ContainerInventoryWork where processed_flag = '0') > 0
begin

--	select top 1 * from #ContainerInventoryWork where processed_flag = '0'

	IF OBJECT_ID(N'tempdb..#temp') IS NOT NULL
	BEGIN
	drop table #temp
	END
	

	declare 
		@company_id int,
		@profit_ctr_id int,
		@container_type char(1),
		@receipt_id int,
		@line_id int,
		@container_id int,
		@sequence_id int

	set @company_id = (select top 1 company_id from #ContainerInventoryWork where processed_flag = '0')
	set @profit_ctr_id = (select top 1 profit_ctr_id from #ContainerInventoryWork where processed_flag = '0')
	set @container_type = (select top 1 container_type from #ContainerInventoryWork where processed_flag = '0')
	set @receipt_id = (select top 1 receipt_id from #ContainerInventoryWork where processed_flag = '0')
	set @line_id = (select top 1 line_id from #ContainerInventoryWork where processed_flag = '0')
	set @container_id = (select top 1 container_id from #ContainerInventoryWork where processed_flag = '0')
	set @sequence_id = (select top 1 sequence_id from #ContainerInventoryWork where processed_flag = '0')

	select '01/01/1900' as date_added, * into #temp from dbo.fn_container_source(@company_id, @profit_ctr_id, @receipt_id, @line_id, @container_id, @sequence_id, 1)

	update #temp set date_added = (
	select top 1 format(receipt_date, 'MM/dd/yyyy') from receipt where company_id = #temp.company_id and profit_ctr_id = #temp.profit_ctr_id and receipt_id = #temp.receipt_id and #temp.container_type = 'R'
	)
	where #temp.container_type = 'R'

	update #temp set date_added = (
	select top 1 format(date_added, 'MM/dd/yyyy') from container where company_id = #temp.company_id and profit_ctr_id = #temp.profit_ctr_id and receipt_id = #temp.receipt_id and line_id = #temp.line_id and container_id = #temp.container_id and sequence_id = #temp.sequence_id and #temp.container_type = 'S'
	)
	where #temp.container_type = 'S'

--	select * from #temp
	update #ContainerInventoryWork set processed_flag = '1', oldest_contents_date = (select min(date_added) from #temp)
		where company_id = @company_id 
			and profit_ctr_id = @profit_ctr_id 
			and container_type = @container_type 
			and receipt_id = @receipt_id 
			and line_id = @line_id
			and container_id = @container_id 
			and sequence_id = @sequence_id

end


select 
	container_type, company_id, profit_ctr_id, receipt_id, line_id, container_id, sequence_id, 
	format(container_date, 'MM/dd/yyyy') as 'container_date', 
	format(oldest_contents_date, 'MM/dd/yyyy') as 'oldest_contents_date'
from #ContainerInventoryWork 
	where (SELECT DATEADD(dd, 0, DATEDIFF(dd, 0, oldest_contents_date)))
    < (SELECT DATEADD(dd, 0, DATEDIFF(dd, 0, container_date)))
order by container_date asc

    
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_container_inventory_calc_older_content] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_container_inventory_calc_older_content] TO [COR_USER]
    AS [dbo];



GO

GRANT EXECUTE ON [dbo].[sp_container_inventory_calc_older_content] TO [EQAI]

