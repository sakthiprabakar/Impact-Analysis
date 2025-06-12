	
create proc sp_phonebill_generate_internal (
	@phone_bill_report_id	int				-- What record set in the source tables to run against
	, @user_id_list			varchar(max)	-- Only matching id's will get emailed. Null = all.  0 = IT.
	, @display_or_email		char(1) = 'D'	-- 'D'isplay fields only, or 'E'mail results?
)
as
/* *********************************
sp_phonebill_generate_internal

	Generates internal phone bill distribution report fields
	Can either return them (Display option) or Email them to the General Managers
	for the sites found in the results.

History:
9/16/2014	JPB	Created
10/27/2014	JPB	Move Dept to header grouping, also (new field) jpb_status.
				Per discussion with LT, PK. Adding new fields to output from Inventory.
				In the future these fields will just be part of the PhoneBillReportDetail records (or similar table)
				On this run, we'll provide them from a separate table.
12/01/2014	JPB	Added null handling around insert of jpb_status into #data.				
12/04/2014	JPB Imported a new inventory spreadsheet to PhoneInventory_20141204
12/22/2014 	JPB	Converted hard-coded inventory table to PhoneBillImportInventory
02/02/2015	JPB	Added 'UNKNOWN RECIPIENT' catch for cases where UsersData doesn't have info for a co-pc-dep case.
02/06/2015	JPB	Modified SP: If there's an UNKNOWN RECIPIENT, no emails or display will work.

Sample:

1. Find a phone bill report_id:
	select top 5 * from PhoneBillReport order by date_added desc

2. Run sp:
	sp_phonebill_generate_internal
		@phone_bill_report_id = 40
		, @user_id_list = ''
		, @display_or_email = 'D'
	
10/27/2014 temporary source table for inventory data:
	-- This to be populated from an Excel Spreadsheet Paul is curating

SELECT * FROM PhoneBillInventory_20141027
alter table PhoneBillInventory_20141027 ADD jpb_jpb_status varchar(20)
update PhoneBillInventory_20141027 set jpb_jpb_status = 'Active'
SELECT * FROM PhoneBillInventory_20141027 where [Current Plan] like '%su%'
update PhoneBillInventory_20141027 set jpb_jpb_status = 'Cancelled' where [Current Plan] like '%x%'
SELECT * FROM PhoneBillInventory_20141027 where [Current Plan] like '%su%'
update PhoneBillInventory_20141027 set jpb_jpb_status = 'Suspended' where [Current Plan] like '%su%'
update PhoneBillInventory_20141027 set phone_number = replace(phone_number, '-', '')

	create table PhoneBillInventory_20141027 (
		phone_number			varchar(20)
		, jpb_status				varchar(20)
		, [Device Make]	varchar(40)
		, [Device Classification]			varchar(40)
		-- Other fields we're not displaying (IP, date issued to user by IT, etc)
	)

	-- Dummy Data	
	insert PhoneBillInventory_20141027
	select distinct
		wireless_number
		, case convert(int, right(convert(Varchar(20),wireless_number),1)) % 3 when 0 then 'Suspended' when 1 then 'Cancelled' else 'Normal' end jpb_status
		, case convert(int, right(convert(Varchar(20),wireless_number),1)) % 4 when 0 then 'Samsung' when 1 then 'Casio' else 'Apple' end [Device Make]
		, case convert(int, right(convert(Varchar(20),wireless_number),1)) % 5 when 0 then 'Flip' when 1 then 'Smart - IPhone' else 'Smart - Rugged Android' end [Device Classification]
	from PhoneBillImportDetail
	where phone_bill_import_id = 36
	
12/04/2014 - Imported a new inventory spreadsheet to PhoneInventory_20141204
	
	SELECT * FROM PhoneInventory_20141204
	
	-- drop table PhoneBillInventory_20141204
	
	select distinct PhoneNumber as phone_number
	, Manufacturer as [Device Make]
	, Classification as [Device Classification]
	into PhoneBillInventory_20141204
	FROM PhoneInventory_20141204
	where PhoneNumber is not null
	
	SELECT * FROM PhoneBillInventory_20141204
	
	select phone_number	
	, isnull(pbi.jpb_status, 'Unknown') as jpb_status
	, pbi.[Device Make]
	, pbi.[Device Classification]
	FROM PhoneBillInventory_20141204
	
alter table PhoneBillInventory_20141027 ADD jpb_jpb_status varchar(20)
update PhoneBillInventory_20141027 set jpb_jpb_status = 'Active'
SELECT * FROM PhoneBillInventory_20141027 where [Current Plan] like '%su%'
update PhoneBillInventory_20141027 set jpb_jpb_status = 'Cancelled' where [Current Plan] like '%x%'
SELECT * FROM PhoneBillInventory_20141027 where [Current Plan] like '%su%'
update PhoneBillInventory_20141027 set jpb_jpb_status = 'Suspended' where [Current Plan] like '%su%'
update PhoneBillInventory_20141027 set phone_number = replace(phone_number, '-', '')
	
	
00-00-001, 01-00-220, 14-09-720, 15-00-721, 26-00-250

********************************* */

SET NOCOUNT ON
SET ANSI_WARNINGS OFF
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

-- declare @it_email varchar(100) = 'jonathan.broome@usecology.com' -- for testing.
declare @it_email varchar(100) = 'it.services@usecology.com' -- for reals.

declare @this_user varchar(10) = system_user

declare @email_body varchar(max) = '', @email_subject varchar(255)

declare @email_date_to_send datetime = dateadd(mi, 120, getdate())

create table #users (
	user_id	int
)

create table #DisplayOutput (
	o_id						int not null identity(1,1)
	, record_set				int
	, bill_recipient_user_id	int
	, bill_recipient_name		varchar(40)
	, bill_recipient_email		varchar(80)
	, facility_department		varchar(60)
	, vendor_name				varchar(80)
	, bill_year					int
	, bill_month				int
	, user_name					varchar(40)
	, short_desc				varchar(80)
	, wireless_number			varchar(80)
	, amount					money
	, dummy_for_check_box		int
	-- Added 10/27/2014:
	, jpb_status				varchar(20)
	, [Device Make]	varchar(40)
	, [Device Classification]			varchar(40)
)

if isnull(@user_id_list, '') <> ''
	insert #users
	select convert(int, row)
	from dbo.fn_splitxsvtext(',', 1, @user_id_list)
	where row is not null

--- declare @phone_bill_report_id int = 40
select 
	right('0' + convert(varchar(2),u.company_id), 2) + '-' + right('0' + convert(varchar(2),u.profit_ctr_id), 2) + '-' + u.department as facility_department
	, v.vendor_name
	, c.short_desc
	, i.user_name
	, u.bill_amount as amount
	, r.bill_month
	, r.bill_year
	, dbo.fn_FormatPhoneNumber(i.wireless_number) as wireless_number
	-- added 10/27/2014
	, '' as jpb_status -- isnull(pbi.jpb_status, 'Unknown') as jpb_status
	, pbi.[Manufacturer]
	, pbi.[Classification]
into #data	
from PhoneBillReport r
join PhoneBillReportDetailUser u
    on r.phone_bill_report_id = u.phone_bill_report_id
join PhoneBillImportDetail i
    on u.phone_bill_import_id = i.phone_bill_import_id
    and u.phone_bill_import_seq_id = i.sequence_id
join PhoneBillVendor v
    on u.phone_bill_vendor_id = v.phone_bill_vendor_id
join PhoneBillCostCode c
    on u.phone_bill_cost_code_id = c.phone_bill_cost_code_id
left join Phonebillimportinventory pbi
	on pbi.phone_bill_import_id = i.phone_bill_import_id
	and i.wireless_number = pbi.wireless_number
where r.phone_bill_report_id = @phone_bill_report_id
order by 
	right('0' + convert(varchar(2),u.company_id), 2) + '-' + right('0' + convert(varchar(2),u.profit_ctr_id), 2) + '-' + u.department
	, vendor_name
	, i.user_name
	, short_desc

-- Setup for display or email, filtering by user_id_list

-- Problem: This only allows userdata records that currently exist, and does not give a way to add new ones if needed.
-- Solution: Switch to left joins and handle nulls.


select distinct 
	d.facility_department
	, isnull(pcd.user_id, 0) as user_id
	, isnull(u.user_name, 'UNKNOWN RECIPIENT') as user_name
	, isnull(u.email, 'itadmin@usecology.com') as email
	, d.jpb_status
	, 0 as process_flag
into #recipient
from #data d
left join UsersData pcd
	on d.facility_department = pcd.match_value
	and pcd.record_purpose = 'sp_phonebill_generate_internal email recipient'
left join users u
	on pcd.user_id = u.user_id and u.group_id <> 0

-- 2015-02-06 - If there are ANY "UNKNOWN RECIPIENT"s in #recipient, we do not generate emails, and only display a warning.
declare @unknown_recipients bit = 0
if exists (select 1 from #recipient where user_name = 'UNKNOWN RECIPIENT')
	set @unknown_recipients = 1

/*

drop table #recipient

SELECT * FROM #data where facility_department like '01-00-220%'

SELECT * FROM #recipient where facility_department like '14-17%'

select * from #recipient where email = 'itadmin@usecology.com'

SELECT  TOP 20 *
FROM    usersdata 
where record_purpose = 'sp_phonebill_generate_internal email recipient'
and match_value like '01-00-%'

SELECT * FROM users where user_name like '%oleksi%'

insert usersdata (record_purpose, match_value, user_id) values 
('sp_phonebill_generate_internal email recipient', '00-00-001', 2018),
('sp_phonebill_generate_internal email recipient', '00-00-012', 2018),
('sp_phonebill_generate_internal email recipient', '00-00-070', 2018),
('sp_phonebill_generate_internal email recipient', '00-00-071', 2018),
('sp_phonebill_generate_internal email recipient', '00-00-075', 2018),
-- 01-00-220
('sp_phonebill_generate_internal email recipient', '14-09-720', 2018),
('sp_phonebill_generate_internal email recipient', '14-17-100', 872),
('sp_phonebill_generate_internal email recipient', '14-17-500', 872),
('sp_phonebill_generate_internal email recipient', '14-17-530', 872),
('sp_phonebill_generate_internal email recipient', '14-17-540', 872),
('sp_phonebill_generate_internal email recipient', '14-17-560', 872),
('sp_phonebill_generate_internal email recipient', '14-17-575', 872),
('sp_phonebill_generate_internal email recipient', '14-17-575', 872),
('sp_phonebill_generate_internal email recipient', '15-00-721', 658),
('sp_phonebill_generate_internal email recipient', '26-00-250', 1342),
('sp_phonebill_generate_internal email recipient', '26-00-310', 1342),
('sp_phonebill_generate_internal email recipient', '26-00-510', 1342),

*/

if isnull(@user_id_list, '') <> '' and @unknown_recipients = 0
	-- Only matching id's will get emailed. Null = all.  0 = IT.
	delete from #recipient where user_id not in (
		select user_id from #users
	)
	
	
--if exists (select 1 from #users where user_id = 0)
--	insert #recipient
--	select distinct 
--		d.facility_department
--		, 0 -- pcd.user_id
--		, 'IT Admin'
--		, @it_email
--		, 0 as process_flag
--	from #data d


declare 
	@report_header varchar(max) = '<div style="width:90%; margin:2px">'
	, @report_footer varchar(max) = '</div>'
	, @table_header varchar(max) = '<table cellspacing="0" cellpadding="4" width="100%" style="border:solid 1px #000; font-size:8pt; font-family:Arial, sans-serif">'
	, @table_title_header varchar(max) = '<tr><th colspan="6">'
	, @table_title_footer varchar(max) = '</th></tr>'
	, @table_spacer varchar(max) = '<tr><td colspan="6">&nbsp;</td></tr>'
	, @section_header varchar(max) = '<tr><th colspan="6" align="left">[dept]</th></tr>' --, @section_header varchar(max) = '<tr><th colspan="6" align="left">[dept] - [jpb_status]</th></tr>'
	, @row_header varchar(max) = '<tr><td>'
	, @row_total varchar(max) = '<tr style="font-weight: bold;"><td colspan="5" align="right">'
	, @column_sep varchar(max) = '</td><td>'
	, @column_sep_right varchar(max) = '</td><td align="right">'
	, @column_sep_right_total varchar(max) = '</td><td align="right" style="border-top: solid 1px #000; border-bottom: double 3px #000; ">'
	, @row_footer varchar(max) = '</td></tr>'
	, @table_footer varchar(max) = '</table><br/></br>'


create table #EmailLines (
	overall_row	int not null identity(1,1)
	, bill_recipient_name	varchar(100)
	, bill_recipient_email	varchar(100)
	, subject varchar(255)
	, email_body varchar(max)
)

create table #EmailQueue (
	email_id		int not null identity(1,1)
	, email_name		varchar(100)
	, email_address	varchar(100)
	, subject		varchar(255)
	, email_body	varchar(max)
)

declare @this_recipient_user_id int
	, @this_recipient_name varchar(100)
	, @this_recipient_email varchar(100)
	, @department_key	varchar(20)
	, @jpb_status			varchar(20)


-- USER (phone bill recipient) level grouping:
while exists (select 1 from #recipient where process_flag = 0 and user_id is not null and @unknown_recipients = 0) begin

	select top 1 
		@this_recipient_user_id = user_id
		, @this_recipient_name = user_name
		, @this_recipient_email = email
		, @department_key = facility_department
		, @jpb_status = jpb_status
	from #recipient r
	where process_flag = 0
	and user_id is not null
	order by 
		user_name
		, facility_department
		, jpb_status

	-- Display -- 10/27/2014 - This happens whether we send email OR display.
	-- if isnull(@display_or_email, 'D') = 'D' begin 

		-- detail level rows
		insert #DisplayOutput (
			record_set
			, bill_recipient_user_id
			, bill_recipient_name
			, bill_recipient_email
			, facility_department
			, jpb_status
			, vendor_name
			, bill_year
			, bill_month
			, [Device Make]
			, [Device Classification]
			, user_name
			, short_desc
			, wireless_number
			, amount
			, dummy_for_check_box
		)
		select 
			1 as record_set
			, r.user_id as bill_recipient_user_id
			, r.user_name as bill_recipient_name
			, r.email as bill_recipient_email
			, d.facility_department
			, d.jpb_status
			, d.vendor_name
			, d.bill_year
			, d.bill_month
			, d.[Manufacturer] as [Device Make]
			, d.[Classification] as [Device Classification]
			, d.user_name
			, d.short_desc			-- Plan
			, d.wireless_number
			, d.amount
			, 0 as dummy_for_check_box
		from #data d
		inner join #recipient r 
			on d.facility_department = r.facility_department
			and r.user_id = @this_recipient_user_id
		where d.facility_department = @department_key
			and d.jpb_status = @jpb_status
		
		-- subtotal level rows
		insert #DisplayOutput (
			record_set
			, bill_recipient_user_id
			, bill_recipient_name
			, bill_recipient_email
			, facility_department
			, jpb_status
			, vendor_name
			, bill_year
			, bill_month
			, [Device Make]
			, [Device Classification]
			, user_name
			, short_desc
			, wireless_number
			, amount
			, dummy_for_check_box
		)
		select 
			2 as record_set
			, do.bill_recipient_user_id
			, do.bill_recipient_name
			, do.bill_recipient_email
			, do.facility_department
			, do.jpb_status
			, '' -- do.vendor_name
			, '' -- do.bill_year
			, '' -- do.bill_month
			, '' -- [Device Make]
			, '' -- [Device Classification]
			, '' -- d.user_name
			, '' -- d.short_desc
			, @department_key + ' SubTotal' --, @department_key + ' ' + @jpb_status + ' SubTotal' --d.wireless_number
			, sum(do.amount) as amount
			, 0 as dummy_for_check_box
		from #DisplayOutput do
		where 1=1
			and do.bill_recipient_user_id = @this_recipient_user_id
			and do.facility_department = @department_key
			and do.jpb_status = @jpb_status
			and do.record_set = 1
		group by 
			do.bill_recipient_user_id
			, do.bill_recipient_name
			, do.bill_recipient_email
			, do.facility_department
			, do.jpb_status
			, do.vendor_name
			, do.bill_year
			, do.bill_month

		update #recipient 
		set process_flag = 1 
		where user_id = @this_recipient_user_id
		and facility_department = @department_key
		and jpb_status = @jpb_status
		and process_flag = 0
		
		if not exists (
			select 1
			from #recipient 
			where user_id = @this_recipient_user_id
			and process_flag = 0
		) begin

			-- total level rows
			insert #DisplayOutput (
				record_set
				, bill_recipient_user_id
				, bill_recipient_name
				, bill_recipient_email
				, facility_department
				, jpb_status
				, vendor_name
				, bill_year
				, bill_month
				, [Device Make]
				, [Device Classification]
				, user_name
				, short_desc
				, wireless_number
				, amount
				, dummy_for_check_box
			)
			select 
				3 as record_set
				, do.bill_recipient_user_id
				, do.bill_recipient_name
				, do.bill_recipient_email
				, @department_key -- do.facility_department
				, @jpb_status -- do.jpb_status
				, '' -- do.vendor_name
				, 0 -- do.bill_year
				, 0 -- do.bill_month
				, '' -- [Device Make]
				, '' -- [Device Classification]
				, 'Total' -- d.user_name
				, '' -- d.short_desc
				, '' --d.wireless_number
				, sum(do.amount) as amount
				, 0 as dummy_for_check_box
			from #DisplayOutput do
			where 1=1
				and do.bill_recipient_user_id = @this_recipient_user_id
				-- and do.facility_department = @department_key
				-- and do.jpb_status = @jpb_status
				and do.record_set = 2
			group by 
				do.bill_recipient_user_id
				, do.bill_recipient_name
				, do.bill_recipient_email

		end

end

	-- end -- if isnull(@display_or_email, 'D') = 'D'
	
-- Send email
if isnull(@display_or_email, 'D') = 'E' begin 

	-- We're going to re-walk this data, so reset the flag
	update #recipient set process_flag = 0	
	
	-- Track the previous loop values (for table header/footer usage)
	declare 
		@previous_user_id int = -1
		, @previous_dept_jpb_status varchar(100) = ''
		

	-- USER (phone bill recipient) level grouping:
	while exists (select 1 from #recipient where process_flag = 0 and user_id is not null and @unknown_recipients = 0) begin

		select top 1 
			@this_recipient_user_id = user_id
			, @this_recipient_name = user_name
			, @this_recipient_email = email
			, @department_key = facility_department
			, @jpb_status = jpb_status
		from #recipient r
		where process_flag = 0
		and user_id is not null
		order by 
			user_name
			, facility_department
			, jpb_status

		-- Build email contents based on #DisplayOutput
		
		if @previous_user_id <> @this_recipient_user_id begin
			-- means we're on a new user.  And since we're at the top of the loop, we put in header info.
			
			-- define the emails subject
			select top 1 @email_subject = @this_recipient_name + ': ' + vendor_name + ' charges for ' + convert(varchar(4), bill_month) + '/' + convert(varchar(4), bill_year)
			from #DisplayOutput
			where bill_recipient_user_id = @this_recipient_user_id
			
			insert #EmailLines
			select
				@this_recipient_name
				, @this_recipient_email
				, @email_subject
				, @report_header
					+ @table_header 
					+ @table_title_header 
					+ @this_recipient_name 
					+ ': ' + @email_subject
					+ @table_title_footer 
					
			set @previous_user_id = @this_recipient_user_id
			
		end -- end of new user header in email

		if @previous_dept_jpb_status <> @department_key + ' ' + @jpb_status begin
			-- means we're in a new section.  Put a separator and section header in

			insert #EmailLines
			select
				@this_recipient_name
				, @this_recipient_email
				, @email_subject
				, @table_spacer
					-- + REPLACE(REPLACE(@section_header, '[dept]', @department_key), '[jpb_status]', @jpb_status)
					+ REPLACE(@section_header, '[dept]', @department_key)

			set @previous_dept_jpb_status = @department_key + ' ' + @jpb_status
			
		end -- end of new section header
		
		-- regular body lines
		insert #EmailLines
		select
			@this_recipient_name
			, @this_recipient_email
			, @email_subject
			, case when record_set = 3 then @table_spacer else '' end -- If we're about to print a Total line, create space above it. 
			
				+ case when record_set = 1 THEN -- If this is a "regular" data row:
					@row_header
					+ user_name											-- User
					+ @column_sep
					+ isnull([Device Make], '')					-- Make
					+ @column_sep	
					+ isnull([Device Classification], '')							-- Class
					+ @column_sep
					+ isnull(short_desc, '')							-- Plan
					+ @column_sep
					+ isnull(wireless_number, '')						-- Number
					+ @column_sep_right
					+ convert(varchar(40), isnull(amount, '0.00'))		-- Cost
					
				ELSE -- Not a "regular" data row... subtotal or total:
					@row_total
					+ case when record_set = 2 THEN
						facility_department + ' SubTotal:'
						else
						'Total:'
						end
					+ @column_sep_right_total
					+ '$'
					+ convert(varchar(40), isnull(amount, '0.00'))
				END
				
				+ @row_footer
				+ case when record_set = 3 then @table_footer + @report_footer else '' end

		as email_body
		from #DisplayOutput
		where
			bill_recipient_name = @this_recipient_name
			and facility_department = @department_key
			and jpb_status = @jpb_status
		order by 
			o_id

		update #recipient
			set process_flag = 1
		where
			@this_recipient_user_id = user_id
			and @this_recipient_name = user_name
			and @this_recipient_email = email
			and @department_key = facility_department
			and @jpb_status = jpb_status
			
		if not exists (
			select 1
			from #recipient 
			where user_id = @this_recipient_user_id
			and process_flag = 0
		) begin
		
			-- Done handling all the rows for this user.  Send the email.
			
			set @email_body = ''
			
			select @email_body = coalesce(@email_body, '') + email_body
			FROM #EmailLines
			order by 
			overall_row
	 
			set @email_body = @email_body + '<span style="font-size:8pt">Generated ' + convert(varchar(40), getdate()) + ' from phone_bill_report_id ' + convert(varchar(20), @phone_bill_report_id) + '</span><br/></br>'

			insert #EmailQueue
			select
				@this_recipient_name
				, @this_recipient_email
				, @email_subject
				, @email_body

			declare @out_message_id int

			exec @out_message_id = sp_message_insert
				 @subject			= @email_subject
				,@message			= @email_body
				,@html				= @email_body
				,@created_by		= @this_user
				,@message_source	= 'PhoneBill SP'
				,@date_to_send		= @email_date_to_send
				,@message_type_id	= NULL
				
			exec sp_messageAddress_insert
				 @message_id	= @out_message_id
				,@address_type	= 'TO'
				,@email			= @this_recipient_email
				,@name			= @this_recipient_name
				,@company		= 'EQ'
				,@department	= NULL
				,@fax			= NULL
				,@phone			= NULL

			exec sp_messageAddress_insert
				 @message_id	= @out_message_id
				,@address_type	= 'BCC'
				,@email			= 'IT.Services@usecology.com'
				,@name			= 'IT Services Mailbox'
				,@company		= 'EQ'
				,@department	= NULL
				,@fax			= NULL
				,@phone			= NULL

			exec sp_messageAddress_insert
				 @message_id	= @out_message_id
				,@address_type	= 'FROM'
				,@email			= 'IT.Services@usecology.com'
				,@name			= 'IT Services Mailbox'
				,@company		= 'EQ'
				,@department	= NULL
				,@fax			= NULL
				,@phone			= NULL


			set @email_body = ''
		
			-- Reset the email-building tables
			if object_id('tempdb..#EmailBuild') is not null
				drop table #EmailBuild
			truncate table #EmailLines

		end -- if we're done with all the rows for this user

	end -- loop over all users
					
end -- in email mode


-- select datalength(email_body), * from #EmailQueue order by email_id

-- kludge cleanup... we had to set facility_department and jpb_status on TOTAL rows to make the email work.
-- Clear them out now
update #DisplayOutput set facility_department = '', jpb_status = '' where record_set = 3

-- Display mode: Return records
if isnull(@display_or_email, 'D') = 'D' begin

	if @unknown_recipients <> 0 begin
		SET IDENTITY_INSERT #DisplayOutput ON
		INSERT #DisplayOutput
		(
		o_id
		, record_set
		, bill_recipient_user_id
		, bill_recipient_name
		, bill_recipient_email
		, vendor_name
		, bill_year
		, bill_month
		, facility_department
		, jpb_status
		, user_name
		, [Device Make]
		, [Device Classification]
		, short_desc
		, wireless_number
		, amount
		, dummy_for_check_box
		)		
		SELECT
		0 o_id
		, 1 record_set
		, 0 bill_recipient_user_id
		, 'Unknown Recipients! Bill info Disabled' as bill_recipient_name
		, null bill_recipient_email
		, null vendor_name
		, null bill_year
		, null bill_month
		, facility_department
		, null jpb_status
		, null user_name
		, null [Device Make]
		, null [Device Classification]
		, 'This facility-department missing in UsersData table' as short_desc
		, null wireless_number
		, null amount
		, null dummy_for_check_box
		FROM #recipient
		WHERE user_name = 'UNKNOWN RECIPIENT'
		SET IDENTITY_INSERT #DisplayOutput OFF
	END
		
	SELECT 
		o_id
		, record_set
		, bill_recipient_user_id
		, bill_recipient_name
		, bill_recipient_email
		, vendor_name
		, bill_year
		, bill_month
		, facility_department
		, jpb_status
		, user_name
		, [Device Make]
		, [Device Classification]
		, short_desc
		, wireless_number
		, amount
		, dummy_for_check_box
	FROM #DisplayOutput order by o_id
end

-- If we sent emails, recap- send the whole body of all, combined, to IT.
if isnull(@display_or_email, 'D') = 'E' and @unknown_recipients = 0 begin 

	declare @allemail varchar(max)
		, @createdby varchar(10) = system_user

	select @allemail = coalesce(@allemail, '') + email_body
	FROM #EmailQueue
	order by email_id
	
	set @allemail = 'Email Send Scheduled For : ' + convert(varchar(20), @email_date_to_send) + '<br/><br/>' + @allemail
	--select * from #EmailQueue
	--order by email_id
	

	exec @out_message_id = sp_message_insert
		 @subject			= 'Phone Bill Processor Results'
		,@message			= ''
		,@html				= @allemail
		,@created_by		= @createdby
		,@message_source	= 'PhoneBill SP'
		,@date_to_send		= NULL
		,@message_type_id	= NULL
		
	exec sp_messageAddress_insert
		 @message_id	= @out_message_id
		,@address_type	= 'TO'
		,@email			= @it_email
		,@name			= 'IT Services Mailbox'
		,@company		= 'EQ'
		,@department	= NULL
		,@fax			= NULL
		,@phone			= NULL

	exec sp_messageAddress_insert
		 @message_id	= @out_message_id
		,@address_type	= 'FROM'
		,@email			= 'it.services@usecology.com'
		,@name			= 'IT Services Mailbox'
		,@company		= 'EQ'
		,@department	= NULL
		,@fax			= NULL
		,@phone			= NULL

end



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_phonebill_generate_internal] TO PUBLIC
    AS [dbo];


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_phonebill_generate_internal] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_phonebill_generate_internal] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_phonebill_generate_internal] TO [EQAI]
    AS [dbo];

