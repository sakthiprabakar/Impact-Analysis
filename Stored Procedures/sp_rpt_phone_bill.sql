
create procedure sp_rpt_phone_bill
	@bill_month int,
	@bill_year int
as

/******************
 * 11/05/2012 RB Created
 * 07/18/2014 RB Added check for non-existent cost codes
 ******************/

declare @report_id int,
		@cc varchar(2),
		@err varchar(255),
		@shared_count numeric(8,2),
		@eff_date datetime

-- gather subtotals required for calculations into a temp table
create table #subtotals (
	phone_bill_vendor_id int not null,
	total_bill_amt numeric(8,2) not null,
	shared_amt numeric(8,2) not null,
	nonshared_amt numeric(8,2) not null,
	equipment_amt numeric(8,2) not null)

create table #allocated_user (
	phone_bill_import_id int not null,
	phone_bill_import_seq_id int not null,
	company_id int not null,
	profit_ctr_id int not null,
	department varchar(3) not null,
	phone_bill_vendor_id int not null,
	phone_bill_cost_code_id int not null,
	allocated_amt numeric(8,2) not null)

-- create comparison date for cost code effective date
select @eff_date = dateadd(mm,1,convert(varchar(2),@bill_month) + '/1/' + convert(varchar(4),@bill_year))


-- begin transaction
begin transaction

-- validate cost codes
select @cc = min(d.cost_center)
from PhoneBillImportDetail d
join PhoneBillImport i
	on d.phone_bill_import_id = i.phone_bill_import_id
	and i.bill_month = @bill_month
	and i.bill_year = @bill_year
where not exists (select 1 from PhoneBillCostCode c
			where c.cost_code = substring(d.cost_center, 11, 2))

if @cc is not null and datalength(@cc) > 0
begin
	select @err = 'Error: Cost Center ' + @cc + ' does not exist in PhoneBillCostCode table'
	goto ON_ERROR
end

-- get distinct list of vendors and total amount for each
insert #subtotals
select t.phone_bill_vendor_id, sum(d.total_current_charges), 0, 0, 0
from PhoneBillImport i 
join PhoneBillImportDetail d 
	on  i.phone_bill_import_id = d.phone_bill_import_id
join PhoneBillTemplate t
	on i.phone_bill_template_id = t.phone_bill_template_id
where i.bill_month = @bill_month
and i.bill_year = @bill_year
group by t.phone_bill_vendor_id

if @@error <> 0
begin
	select @err = 'Error retrieving distinct list of vendors'
	goto ON_ERROR
end


-- get total shared amount for each vendor
update #subtotals
set shared_amt = (select sum(isnull(v.allocated_amount,0))
					from PhoneBillImportDetail d
					join PhoneBillImport i
						on d.phone_bill_import_id = i.phone_bill_import_id
						and i.bill_month = @bill_month
						and i.bill_year = @bill_year
					join PhoneBillTemplate t
						on i.phone_bill_template_id = t.phone_bill_template_id
						and s.phone_bill_vendor_id = t.phone_bill_vendor_id
					join PhoneBillCostCode c
						on c.cost_code = substring(d.cost_center, 11,2)
						and c.shared_flag = 'T'
						and c.status = 'A'
					join PhoneBillCostCodeVendor v
						on c.phone_bill_cost_code_id = v.phone_bill_cost_code_id
						and t.phone_bill_vendor_id = v.phone_bill_vendor_id
						and v.effective_date = (select max(effective_date)
									from PhoneBillCostCodeVendor
									where phone_bill_cost_code_id = c.phone_bill_cost_code_id
									and phone_bill_vendor_id = s.phone_bill_vendor_id
									and effective_date < @eff_date)
					)
from #subtotals s

if @@error <> 0
begin
	select @err = 'Error computing shared amount per vendor'
	goto ON_ERROR
end


-- get total non-shared amount for each vendor
update #subtotals
set nonshared_amt = (select sum(isnull(d.total_current_charges,0) - isnull(d.equipment_charges,0))
					from PhoneBillImportDetail d
					join PhoneBillImport i
						on d.phone_bill_import_id = i.phone_bill_import_id
						and i.bill_month = @bill_month
						and i.bill_year = @bill_year
					join PhoneBillTemplate t
						on i.phone_bill_template_id = t.phone_bill_template_id
						and s.phone_bill_vendor_id = t.phone_bill_vendor_id
					join PhoneBillCostCode c
						on c.cost_code = substring(d.cost_center, 11,2)
						and c.shared_flag = 'F'
						and c.status = 'A'
					)
from #subtotals s

if @@error <> 0
begin
	select @err = 'Error computing non-shared amount per vendor'
	goto ON_ERROR
end

-- get total equipment charges
update #subtotals
set equipment_amt = (select sum(isnull(d.equipment_charges,0))
					from PhoneBillImportDetail d
					join PhoneBillImport i
						on d.phone_bill_import_id = i.phone_bill_import_id
						and i.bill_month = @bill_month
						and i.bill_year = @bill_year
					join PhoneBillTemplate t
						on i.phone_bill_template_id = t.phone_bill_template_id
						and s.phone_bill_vendor_id = t.phone_bill_vendor_id
					)
from #subtotals s

if @@error <> 0
begin
	select @err = 'Error computing equipment charges'
	goto ON_ERROR
end

insert #allocated_user
select d.phone_bill_import_id,
		d.sequence_id,
		convert(int,substring(d.cost_center, 1, 2)),
		convert(int,substring(d.cost_center, 4, 2)),
		substring(d.cost_center, 7, 3),
		t.phone_bill_vendor_id,
		c.phone_bill_cost_code_id,
		isnull(v.allocated_amount,0)
from PhoneBillImportDetail d
join PhoneBillImport i
	on d.phone_bill_import_id = i.phone_bill_import_id
	and i.bill_month = @bill_month
	and i.bill_year = @bill_year
join PhoneBillTemplate t
	on i.phone_bill_template_id = t.phone_bill_template_id
join #subtotals s
	on t.phone_bill_vendor_id = s.phone_bill_vendor_id
join PhoneBillCostCode c
	on c.cost_code = substring(d.cost_center, 11,2)
	and c.shared_flag = 'T'
	and c.status = 'A'
join PhoneBillCostCodeVendor v
	on c.phone_bill_cost_code_id = v.phone_bill_cost_code_id
	and t.phone_bill_vendor_id = v.phone_bill_vendor_id
	and v.effective_date = (select max(effective_date)
				from PhoneBillCostCodeVendor
				where phone_bill_cost_code_id = c.phone_bill_cost_code_id
				and phone_bill_vendor_id = s.phone_bill_vendor_id
				and effective_date < @eff_date)
		
if @@error <> 0
begin
	select @err = 'Error computing distinct counts per co/pc/dept/vendor/user'
	goto ON_ERROR
end

-- get the shared count into a variable for calculations
select @shared_count = count(*) from #allocated_user

-- insert a report header record
insert PhoneBillReport (bill_month, bill_year, added_by, date_added)
values (@bill_month, @bill_year, suser_name(), getdate())

if @@error <> 0
begin
	select @err = 'Error attempting to insert into PhoneBillReport table'
	goto ON_ERROR
end

-- record the new report ID
select @report_id = @@IDENTITY

-- insert shared amounts by user
insert PhoneBillReportDetailUser
select @report_id,
		a.phone_bill_import_id,
		a.phone_bill_import_seq_id,
		case when isnull(c.override_company_id,0) <> 0 then c.override_company_id else a.company_id end,
		case when isnull(c.override_profit_ctr_id,0) <> 0 then c.override_profit_ctr_id else a.profit_ctr_id end,
		case when isnull(ltrim(rtrim(c.override_department)),'') <> '' then c.override_department else a.department end,
		a.phone_bill_vendor_id,
		a.phone_bill_cost_code_id,
		round((a.allocated_amt / s.shared_amt) * (s.total_bill_amt - s.nonshared_amt - s.equipment_amt), 2)
from #allocated_user a
join #subtotals s
	on a.phone_bill_vendor_id = s.phone_bill_vendor_id
join PhoneBillCostCode c on a.phone_bill_cost_code_id = c.phone_bill_cost_code_id

if @@error <> 0
begin
	select @err = 'Error attempting to insert shared amount into PhoneBillReportDetailUser table'
	goto ON_ERROR
end


-- roll up non-shared amount by co/pc/dept/user where co/pc/dept is not overridden (those will only go in co/pc/dept report)
insert PhoneBillReportDetailUser
select @report_id,
		d.phone_bill_import_id,
		d.sequence_id,
		convert(int,substring(d.cost_center, 1, 2)),
		convert(int,substring(d.cost_center, 4, 2)),
		substring(d.cost_center, 7, 3),
		t.phone_bill_vendor_id,
		c.phone_bill_cost_code_id,
		isnull(d.total_current_charges,0) - isnull(d.equipment_charges,0)
from PhoneBillImportDetail d
join PhoneBillImport i
	on d.phone_bill_import_id = i.phone_bill_import_id
	and i.bill_month = @bill_month
	and i.bill_year = @bill_year
join PhoneBillTemplate t
	on i.phone_bill_template_id = t.phone_bill_template_id
join PhoneBillCostCode c
	on c.cost_code = substring(d.cost_center, 11,2)
	and c.shared_flag = 'F'
	and c.status = 'A'
	and c.override_company_id is null
	and c.override_profit_ctr_id is null
	and c.override_department is null

if @@error <> 0
begin
	select @err = 'Error attempting to insert non-shared into PhoneBillReportDetailUser table'
	goto ON_ERROR
end

-- roll up shared amount by co/pc/dept/user
insert PhoneBillReportDetail
select @report_id, u.company_id, u.profit_ctr_id, u.department, u.phone_bill_vendor_id,
		u.phone_bill_cost_code_id,
		count(*), sum(u.bill_amount)
from PhoneBillReportDetailUser u
where u.phone_bill_report_id = @report_id
group by u.company_id, u.profit_ctr_id, u.department, u.phone_bill_vendor_id, u.phone_bill_cost_code_id

if @@error <> 0
begin
	select @err = 'Error attempting to insert user allocated amouts into PhoneBillReportDetail table'
	goto ON_ERROR
end

-- roll up overridden co/pc/dept
insert PhoneBillReportDetail
select @report_id, c.override_company_id, c.override_profit_ctr_id, c.override_department, t.phone_bill_vendor_id,
		c.phone_bill_cost_code_id,
		count(*), sum(isnull(d.total_current_charges,0) - isnull(d.equipment_charges,0))
from PhoneBillImportDetail d
join PhoneBillImport i
	on d.phone_bill_import_id = i.phone_bill_import_id
	and i.bill_month = @bill_month
	and i.bill_year = @bill_year
join PhoneBillTemplate t
	on i.phone_bill_template_id = t.phone_bill_template_id
join PhoneBillCostCode c
	on c.cost_code = substring(d.cost_center, 11,2)
	and c.shared_flag = 'F'
	and c.status = 'A'
	and c.override_company_id is not null
	and c.override_profit_ctr_id is not null
	and c.override_department is not null
group by c.override_company_id, c.override_profit_ctr_id, c.override_department, t.phone_bill_vendor_id, c.phone_bill_cost_code_id

if @@error <> 0
begin
	select @err = 'Error attempting to insert user allocated amouts into PhoneBillReportDetail table'
	goto ON_ERROR
end
	
-- insert equipment charges
insert PhoneBillReportDetail
select @report_id, c.override_company_id, c.override_profit_ctr_id, c.override_department,
		s.phone_bill_vendor_id, c.phone_bill_cost_code_id, 0, s.equipment_amt
from #subtotals s
join PhoneBillCostCode c on c.cost_code = 'EQ'

if @@error <> 0
begin
	select @err = 'Error attempting to insert equipment charges into PhoneBillReportDetail table'
	goto ON_ERROR
end

-- insert a rounding offset if necessary
insert PhoneBillReportDetail
select @report_id, c.override_company_id, c.override_profit_ctr_id, c.override_department,
		s.phone_bill_vendor_id, c.phone_bill_cost_code_id, 0,
		s.total_bill_amt - (select sum(isnull(d.bill_amount,0))
							from PhoneBillReportDetail d
							where d.phone_bill_report_id = @report_id
							and d.phone_bill_vendor_id = s.phone_bill_vendor_id)
from #subtotals s
join PhoneBillCostCode c on c.cost_code = 'SH'
where s.total_bill_amt <> (select sum(isnull(d.bill_amount,0))
							from PhoneBillReportDetail d
							where d.phone_bill_report_id = @report_id
							and d.phone_bill_vendor_id = s.phone_bill_vendor_id)

if @@error <> 0
begin
	select @err = 'Error attempting to insert rounding offset into PhoneBillReportDetail table'
	goto ON_ERROR
end

-- a report has been generated
commit transaction
goto ON_SUCCESS

ON_ERROR:
rollback transaction
raiserror (@err, 16, 1)
return -1

ON_SUCCESS:
select @report_id as report_id
return 0

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_phone_bill] TO [EQAI]
    AS [dbo];

