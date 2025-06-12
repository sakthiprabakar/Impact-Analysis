

create procedure sp_merchandise_export_csv
	@customer_id int,
	@user_id varchar(20)
as
/***************************************************************************************
 this procedure exports a list of approved Merchandise items for a customer in CSV format

 loads to Plt_ai
 
 12/10/2008 - rb created
 12/18/2008 - rb format changed, customer requested duplicate rows for each state disposition
 02/05/2009 - rb added reference to MerchandiseExtractLog table to do incremental queries
 03/10/2009 - rb added inserting into MerchandiseExtractLog to this procedure
 05/15/2017 AM - 1.Remove deprecated SQL and replace with appropriate SQL syntax.(*= to LEFT OUTER JOIN etc.).
****************************************************************************************/

set nocount on

declare @last_extract_datetime datetime,
	@number_of_records int,
	@start_datetime datetime,
	@merchandise_id int,
	@category_id int,
	@customer_name varchar(60),
	@count int,
	@primary_disposition varchar(100),
	@waste_code_1 varchar(4), @waste_code_1_type varchar(10), @waste_code_1_state varchar(2),
	@waste_code_2 varchar(4), @waste_code_2_type varchar(10), @waste_code_2_state varchar(2),
	@waste_code_3 varchar(4), @waste_code_3_type varchar(10), @waste_code_3_state varchar(2),
	@waste_code_4 varchar(4), @waste_code_4_type varchar(10), @waste_code_4_state varchar(2),
	@waste_code_5 varchar(4), @waste_code_5_type varchar(10), @waste_code_5_state varchar(2),
	@waste_code_6 varchar(4), @waste_code_6_type varchar(10), @waste_code_6_state varchar(2),
	@additional_waste_codes char(1),
	@constituent_1 varchar(50), @constituent_2 varchar(50),	@constituent_3 varchar(50),
	@constituent_4 varchar(50), @constituent_5 varchar(50),
	@additional_constituents char(1),
	@i int,
	@val varchar(255)

-- initialize extract tracking variables
select @last_extract_datetime = null,
	@number_of_records = 0,
	@start_datetime = getdate()


-- Determine last extract datetime
select @last_extract_datetime = max(extract_date)
from MerchandiseExtractLog
where customer_id = @customer_id

if @last_extract_datetime is null
	select @last_extract_datetime = '01/01/2000'


-- temp table for results
create table #tmp (
eq_merchandise_id int not null,
category_id int null,
item_number varchar(6) null,
upc varchar(14) null,
primary_disposition varchar(100) null,
waste_code_1 varchar(4) null,
waste_code_1_type varchar(10) null,
waste_code_1_state varchar(2) null,
waste_code_2 varchar(4) null,
waste_code_2_type varchar(10) null,
waste_code_2_state varchar(2) null,
waste_code_3 varchar(4) null,
waste_code_3_type varchar(10) null,
waste_code_3_state varchar(2) null,
waste_code_4 varchar(4) null,
waste_code_4_type varchar(10) null,
waste_code_4_state varchar(2) null,
waste_code_5 varchar(4) null,
waste_code_5_type varchar(10) null,
waste_code_5_state varchar(2) null,
waste_code_6 varchar(4) null,
waste_code_6_type varchar(10) null,
waste_code_6_state varchar(2) null,
additional_waste_codes char(1) null,
constituent_1_description varchar(50) null,
constituent_2_description varchar(50) null,
constituent_3_description varchar(50) null,
constituent_4_description varchar(50) null,
constituent_5_description varchar(50) null,
additional_constituents char(1) null
)

create table #tmpstate (
eq_merchandise_id int not null,
category_id int not null,
state varchar(2) null,
state_disposition varchar(100) null
)

-- insert all approved Merchandise items linked to the customer_id specified
-- include all related tables and check their date_modified columns against @last_extract_datetime
insert #tmp (eq_merchandise_id, category_id, item_number, upc)
select m.merchandise_id, m.category_id, substring(mc_c.merchandise_code,1,6), substring(mc_u.merchandise_code,1,14)
from Merchandise m
inner join MerchandiseCode mc_c on m.merchandise_id = mc_c.merchandise_id
				and mc_c.code_type = 'C'
				and mc_c.customer_id = @customer_id
left outer join MerchandiseCode mc_u on m.merchandise_id = mc_u.merchandise_id
					and mc_u.code_type = 'U'
where m.merchandise_status = 'A'
and (
     m.date_modified >= @last_extract_datetime
     or exists (select 1 from MerchandiseCode mc where mc.merchandise_id = m.merchandise_id and mc.date_modified >= @last_extract_datetime)
     or exists (select 1 from MerchandiseCategory mcat where mcat.category_id = m.category_id and mcat.date_modified >= @last_extract_datetime)
     or exists (select 1 from MerchandiseCategoryCustomer mcc where mcc.category_id = m.category_id and mcc.customer_id = @customer_id and mcc.date_modified >= @last_extract_datetime)
     or exists (select 1 from MerchandiseStateCategory msc where msc.merchandise_id = m.merchandise_id and msc.date_modified >= @last_extract_datetime)
     or exists (select 1 from MerchandiseWasteCode mwc where mwc.merchandise_id = m.merchandise_id and mwc.date_modified >= @last_extract_datetime)
     or exists (select 1 from MerchandiseConstituent mcon where mcon.merchandise_id = m.merchandise_id and mcon.date_modified >= @last_extract_datetime)
    )

-- loop through all items and lookup dispositions, waste codes and constituents
declare c_loop cursor for
select eq_merchandise_id, category_id
from #tmp
for update

open c_loop
fetch c_loop into @merchandise_id, @category_id

while @@FETCH_STATUS = 0
begin
	-- defaults
	select @primary_disposition = '',
		@waste_code_1 = '', @waste_code_1_type = '', @waste_code_1_state = '',
		@waste_code_2 = '', @waste_code_2_type = '', @waste_code_2_state = '',
		@waste_code_3 = '', @waste_code_3_type = '', @waste_code_3_state = '',
		@waste_code_4 = '', @waste_code_4_type = '', @waste_code_4_state = '',
		@waste_code_5 = '', @waste_code_5_type = '', @waste_code_5_state = '',
		@waste_code_6 = '', @waste_code_6_type = '', @waste_code_6_state = '',
		@additional_waste_codes = 'N',
		@constituent_1 = '', @constituent_2 = '', @constituent_3 = '', 
		@constituent_4 = '', @constituent_5 = '', 
		@additional_constituents = 'N'

	-- Get primary disposition (first check for customer-specific disposition, lookup base if non-existent)
	select @primary_disposition = d.disposition_desc
	from MerchandiseCategoryCustomer mcc, Disposition d
	where mcc.category_id = @category_id
	and mcc.customer_id = @customer_id
	and mcc.disposition_id = d.disposition_id

	if @primary_disposition is null
		select @primary_disposition = d.disposition_desc
		from MerchandiseCategory mc, Disposition d
		where mc.category_id = @category_id
		and mc.default_disposition_id = d.disposition_id
 
	-- Get state specific dispositions
	select @count = count(*)
	from MerchandiseStateCategory msc, MerchandiseCategoryCustomer mcc
	where msc.merchandise_id = @merchandise_id
	and msc.category_id = mcc.category_id
	and mcc.customer_id = @customer_id

	if @count > 0
	begin
		-- first, insert the default disposition for the category
		insert #tmpstate
		select  @merchandise_id, msc.category_id, msc.state, replace(d.disposition_desc,'"','""')
		from MerchandiseStateCategory msc, MerchandiseCategory mc, Disposition d
		where msc.merchandise_id = @merchandise_id
		and msc.category_id = mc.category_id
		and mc.default_disposition_id = d.disposition_id

		-- then overwrite any disposition that has a customer-specific disposition
		update #tmpstate
		set state_disposition = replace(d.disposition_desc,'"','""')
		from #tmpstate t, MerchandiseCategoryCustomer mcc, Disposition d
		where t.eq_merchandise_id = @merchandise_id
		and t.category_id = mcc.category_id
		and mcc.customer_id = @customer_id
		and mcc.disposition_id = d.disposition_id
	end

	-- Get up to 6 waste codes
	select @count = count(*)
	from MerchandiseWasteCode
	where merchandise_id = @merchandise_id

	if @count > 0
	begin
		if @count > 6
			select @additional_waste_codes = 'Y'

		declare c_waste cursor for
		select  mwc.waste_code, wc.waste_code_origin, wc.state
		from MerchandiseWasteCode mwc, WasteCode wc
		where mwc.merchandise_id = @merchandise_id
		and mwc.waste_code = wc.waste_code
		for read only

		select @i = 1
		open c_waste
		fetch c_waste into @waste_code_1, @waste_code_1_type, @waste_code_1_state

		while @@FETCH_STATUS = 0
		begin
			select @i = @i + 1

			if @i = 2
				fetch c_waste into @waste_code_2, @waste_code_2_type, @waste_code_2_state
			else if @i = 3
				fetch c_waste into @waste_code_3, @waste_code_3_type, @waste_code_3_state
			else if @i = 4
				fetch c_waste into @waste_code_4, @waste_code_4_type, @waste_code_4_state
			else if @i = 5
				fetch c_waste into @waste_code_5, @waste_code_5_type, @waste_code_5_state
			else if @i = 6
				fetch c_waste into @waste_code_6, @waste_code_6_type, @waste_code_6_state
			else
				break

		end
		close c_waste
		deallocate c_waste
	end

	-- Get up to 5 constituents
	select @count = count(*)
	from MerchandiseConstituent
	where merchandise_id = @merchandise_id

	if @count > 0
	begin
		if @count > 5
			select @additional_constituents = 'Y'

		declare c_const cursor for
		select c.const_desc
		from MerchandiseConstituent mc, Constituents c
		where mc.merchandise_id = @merchandise_id
		and mc.const_id = c.const_id
		for read only

		select @i = 1
		open c_const
		fetch c_const into @constituent_1

		while @@FETCH_STATUS = 0
		begin
			select @i = @i + 1

			if @i = 2
				fetch c_const into @constituent_2
			else if @i = 3
				fetch c_const into @constituent_3
			else if @i = 4
				fetch c_const into @constituent_4
			else if @i = 5
				fetch c_const into @constituent_5
			else
				break

		end
		close c_const
		deallocate c_const

	end

	-- update temp table
	update #tmp
	set primary_disposition = replace(@primary_disposition,'"','""'),
		waste_code_1 = replace(@waste_code_1,'"','""'),
		waste_code_1_type = case @waste_code_1_type when 'F' then 'Federal' when 'S' then 'State' else case when datalength(isnull(@waste_code_1,'')) > 0 then 'Unknown' else '' end end,
		waste_code_1_state = replace(@waste_code_1_state,'"','""'),
		waste_code_2 = replace(@waste_code_2,'"','""'),
		waste_code_2_type = case @waste_code_2_type when 'F' then 'Federal' when 'S' then 'State' else case when datalength(isnull(@waste_code_2,'')) > 0 then 'Unknown' else '' end end,
		waste_code_2_state = replace(@waste_code_2_state,'"','""'),
		waste_code_3 = replace(@waste_code_3,'"','""'),
		waste_code_3_type = case @waste_code_3_type when 'F' then 'Federal' when 'S' then 'State' else case when datalength(isnull(@waste_code_3,'')) > 0 then 'Unknown' else '' end end,
		waste_code_3_state = replace(@waste_code_3_state,'"','""'),
		waste_code_4 = replace(@waste_code_4,'"','""'),
		waste_code_4_type = case @waste_code_4_type when 'F' then 'Federal' when 'S' then 'State' else case when datalength(isnull(@waste_code_4,'')) > 0 then 'Unknown' else '' end end,
		waste_code_4_state = replace(@waste_code_4_state,'"','""'),
		waste_code_5 = replace(@waste_code_5,'"','""'),
		waste_code_5_type = case @waste_code_5_type when 'F' then 'Federal' when 'S' then 'State' else case when datalength(isnull(@waste_code_5,'')) > 0 then 'Unknown' else '' end end,
		waste_code_5_state = replace(@waste_code_5_state,'"','""'),
		waste_code_6 = replace(@waste_code_6,'"','""'),
		waste_code_6_type = case @waste_code_6_type when 'F' then 'Federal' when 'S' then 'State' else case when datalength(isnull(@waste_code_6,'')) > 0 then 'Unknown' else '' end end,
		waste_code_6_state = replace(@waste_code_6_state,'"','""'),
		additional_waste_codes = @additional_waste_codes,
		constituent_1_description = replace(@constituent_1,'"','""'),
		constituent_2_description = replace(@constituent_2,'"','""'),
		constituent_3_description = replace(@constituent_3,'"','""'),
		constituent_4_description = replace(@constituent_4,'"','""'),
		constituent_5_description = replace(@constituent_5,'"','""'),
		additional_constituents = @additional_constituents
	where current of c_loop

	-- get next merchandise_id
	fetch c_loop into @merchandise_id, @category_id
end
close c_loop
deallocate c_loop

-- Get customer name
select @customer_name = replace(ltrim(cust_name),'"','""')
from Customer
where customer_id = @customer_id

-- determine # of records returned
select @number_of_records = count(*)
from #tmp

-- insert new record into MerchandiseExtractLog table
insert MerchandiseExtractLog
values (@customer_id, @start_datetime, @number_of_records, @user_id)

-- return results
set nocount off
select '"' + convert(varchar(10),t.eq_merchandise_id) + '",' +
	'"' + isnull(@customer_name,'') + '",' +
	'"' + isnull(t.item_number,'') + '",' +
	'"' + isnull(t.upc,'') + '",' +
	'"' + isnull(replace(ltrim(m.merchandise_desc),'"','""'),'') + '",' +
	'"' + isnull(ltrim(t.primary_disposition),'') + '",' +
	'"' + isnull(ltrim(ts.state),'') + '",' +
	'"' + isnull(ltrim(ts.state_disposition),'') + '",' +
	'"' + isnull(ltrim(t.waste_code_1),'') + '",' +
	'"' + isnull(ltrim(t.waste_code_1_type),'') + '",' +
	'"' + isnull(ltrim(t.waste_code_1_state),'') + '",' +
	'"' + isnull(ltrim(t.waste_code_2),'') + '",' +
	'"' + isnull(ltrim(t.waste_code_2_type),'') + '",' +
	'"' + isnull(ltrim(t.waste_code_2_state),'') + '",' +
	'"' + isnull(ltrim(t.waste_code_3),'') + '",' +
	'"' + isnull(ltrim(t.waste_code_3_type),'') + '",' +
	'"' + isnull(ltrim(t.waste_code_3_state),'') + '",' +
	'"' + isnull(ltrim(t.waste_code_4),'') + '",' +
	'"' + isnull(ltrim(t.waste_code_4_type),'') + '",' +
	'"' + isnull(ltrim(t.waste_code_4_state),'') + '",' +
	'"' + isnull(ltrim(t.waste_code_5),'') + '",' +
	'"' + isnull(ltrim(t.waste_code_5_type),'') + '",' +
	'"' + isnull(ltrim(t.waste_code_5_state),'') + '",' +
	'"' + isnull(ltrim(t.waste_code_6),'') + '",' +
	'"' + isnull(ltrim(t.waste_code_6_type),'') + '",' +
	'"' + isnull(ltrim(t.waste_code_6_state),'') + '",' +
	'"' + isnull(ltrim(t.additional_waste_codes),'') + '",' +
	'"' + isnull(ltrim(t.constituent_1_description),'') + '",' +
	'"' + isnull(ltrim(t.constituent_2_description),'') + '",' +
	'"' + isnull(ltrim(t.constituent_3_description),'') + '",' +
	'"' + isnull(ltrim(t.constituent_4_description),'') + '",' +
	'"' + isnull(ltrim(t.constituent_5_description),'') + '",' +
	'"' + isnull(ltrim(t.additional_constituents),'') + '"' as csv
from #tmp t
JOIN Merchandise m ON t.eq_merchandise_id = m.merchandise_id
LEFT OUTER JOIN #tmpstate ts ON t.eq_merchandise_id = ts.eq_merchandise_id

-- drop temp tables
drop table #tmp
drop table #tmpstate

return 0

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_merchandise_export_csv] TO [EQAI]
    AS [dbo];

