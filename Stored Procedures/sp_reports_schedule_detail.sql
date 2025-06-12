

CREATE PROCEDURE sp_reports_schedule_detail

/********************
sp_reports_schedule_detail:

Returns the detail for a schedule item

How to check that the person using this is allowed to see the data:
	If there's a single approval (profile), the contact calling this must belong to the customer (with web access) that is on the profile.
	If there's multiple approvals (profiles), the contact calling this must belong to the customer (with web access) for ALL the profiles.
	Otherwise, show nothing.
		And if we're showing nothing in detail, then nothing in the report must be visible.  WHy show summary if not detail?

LOAD TO PLT_XX_AI*

select top 20 * from schedule s inner join profilewastecode pwc on s.profile_id = pwc.profile_id inner join wastecode w on pwc.waste_code_uid = w.waste_code_uid
where w.state = 'TX'
order by s.date_added desc

sp_reports_schedule_detail 2, 0, 435932 

sp_reports_schedule 0, '2|0', '', '435932', '3/30/2013', '8/6/2013',-1

08/15/2006 JPB Created
10/20/2006 JPB Added 5th recordset for profitcenter info
07/30/2013 JPB	Modified for TX Waste Codes project

**********************/
	@company_id				int,
	@profit_ctr_id			int,
	@confirmation_id		varchar(20),
	@contact_id				int = 0		-- associates use -1
AS

set nocount on

declare @sql varchar(8000), @tsql varchar(8000)

-- Header table to restrict future results to match the most important query.
create table #header (confirmation_id int)

-- header details
set @sql = '
SELECT Distinct 
    s.confirmation_ID /* fields */
FROM schedule s
	/* scheduleapproval */
    inner join company c on s.company_id = c.company_id
    inner join profitcenter pc on s.profit_ctr_id = pc.profit_ctr_id
    left outer join profilequoteapproval pqa on s.approval_code = pqa.approval_code and s.profit_ctr_id = pqa.profit_ctr_id and s.company_id = pqa.company_id
    left outer join profile p on pqa.profile_id = p.profile_id and p.curr_status_code = ''A''
    left outer join wastecode w on p.waste_code_uid = w.waste_code_uid
    left outer join BillUnit b on s.bill_unit_code = b.bill_unit_code 
    left outer join generator g on p.generator_id = g.generator_id 
    left outer join contact co on p.contact_id = co.contact_id 
WHERE s.confirmation_ID = ' + convert(varchar(20), @confirmation_id) + ' 
AND s.company_id = ' + convert(varchar(20), @company_id) + '
AND s.profit_ctr_ID = ' + convert(varchar(20), @profit_ctr_id) + ' 
'

if @contact_id > 0 
	set @sql = @sql + 'AND (p.customer_id in (select customer_id from contactxref where contact_id = ' + convert(varchar(20), @contact_id) + ' and status = ''A'' and web_access = ''A'')
						 OR
						 p.generator_id in (select generator_id from contactxref where contact_id = ' + convert(varchar(20), @contact_id) + ' and status = ''A'' and web_access = ''A'')
					) 
'

set @sql = @sql + '	
	and s.status = ''A''
'

set @tsql = @sql + '
					-- this is to guarantee there are no profiles for other customers, in this confirmation
					AND (select count(*) from scheduleapproval s2 inner join profile sp2 on s2.profile_id = sp2.profile_id where s2.confirmation_id = SA.confirmation_id
					AND (sp2.customer_id not in (select customer_id from contactxref where contact_id = ' + convert(varchar(20), @contact_id) + ' and status = ''A'' and web_access = ''A'')
					) 
					) = 0 '

set @tsql = replace(@tsql, 's.confirmation_ID /* fields */', 's.confirmation_ID /* fields2 */')
set @tsql = replace(@tsql, 's.bill_unit_code', 'sa.bill_unit_code')
set @tsql = replace(@tsql, 's.profile_id', 'sa.profile_id')
set @tsql = replace(@tsql, 's.profit_ctr_id', 'sa.profit_ctr_id')
set @tsql = replace(@tsql, '/* scheduleapproval */', 'left outer join scheduleapproval sa on s.confirmation_id = sa.confirmation_id and s.profit_ctr_id = sa.profit_ctr_id')

set @sql = @sql + ' UNION ' + @tsql

exec ('INSERT #header ' + @sql)

set @sql = replace(@sql, 's.confirmation_ID /* fields */', 's.profit_ctr_id, s.confirmation_ID, s.time_scheduled, s.quantity, s.approval_code, 
    s.contact, s.contact_company, s.contact_fax, s.load_type, s.contact_phone, 
    g.epa_id, g.generator_name, 
    b.bill_unit_desc, 
    p.approval_desc, w.display_name as waste_code, p.OTS_flag, p.profile_id, 
    w.waste_code_desc,
    c.company_name,  
    pc.profit_ctr_name, pc.address_1, pc.address_2, 
	co.name as contact_name ' )

set @sql = replace(@sql, 's.confirmation_ID /* fields2 */', 's.profit_ctr_id, s.confirmation_ID, s.time_scheduled, s.quantity, s.approval_code, 
    s.contact, s.contact_company, s.contact_fax, s.load_type, s.contact_phone, 
    null as epa_id, null as generator_name, 
    null as bill_unit_desc, 
    null as approval_desc, null as waste_code, null as OTS_flag, null as profile_id, 
    null as waste_code_desc,
    c.company_name,  
    pc.profit_ctr_name, pc.address_1, pc.address_2, 
	null as contact_name ' )
	
	
exec (@sql)

-- comments
SELECT comment 
FROM ScheduleComment
INNER JOIN #header on ScheduleComment.confirmation_id = #header.confirmation_ID
WHERE ScheduleComment.confirmation_ID = @confirmation_id
AND company_id = @company_id
AND profit_ctr_ID = @profit_ctr_id 


-- multiple approvals per confirmation details
set @sql = '
SELECT Distinct 
    SA.quantity, SA.approval_code, SA.profile_id,
    G.epa_id, G.generator_name, 
    p.approval_desc, p.OTS_flag, w.display_name as waste_code, 
    W.waste_code_desc, 
    B.bill_unit_desc
FROM ScheduleApproval SA
INNER JOIN #header on SA.confirmation_id = #header.confirmation_ID
left outer join profile p on sa.profile_id = p.profile_id
left outer join Generator G on p.generator_id = g.generator_id
left outer join WasteCode W on p.waste_code_uid = W.waste_code_uid 
left outer join billunit B on p.bill_unit_code = B.bill_unit_code 
WHERE sa.confirmation_ID = ' + convert(varchar(20), @confirmation_id) + ' 
AND sa.company_id = ' + convert(varchar(20), @company_id) + '
AND sa.profit_ctr_ID = ' + convert(varchar(20), @profit_ctr_id) + '  
AND p.curr_status_code = ''A'' 
'

if @contact_id > 0 
	set @sql = @sql + 'AND (p.customer_id in (select customer_id from contactxref where contact_id = ' + convert(varchar(20), @contact_id) + ' and status = ''A'' and web_access = ''A'')
						 OR
						 p.generator_id in (select generator_id from contactxref where contact_id = ' + convert(varchar(20), @contact_id) + ' and status = ''A'' and web_access = ''A'')
					) 
					-- this is to guarantee there are no profiles for other customers, in this confirmation
					AND (select count(*) from scheduleapproval s2 inner join profile sp2 on s2.profile_id = sp2.profile_id where s2.confirmation_id = SA.confirmation_id
					AND (sp2.customer_id not in (select customer_id from contactxref where contact_id = ' + convert(varchar(20), @contact_id) + ' and status = ''A'' and web_access = ''A'')
					) 
					) = 0 '

exec(@sql)


-- waste codes (only applies to a single profile on a confirmation)
SELECT 
    wc.display_name as waste_code, 
    pwc.primary_flag 
FROM 
    schedule s 
inner join ProfileWasteCode pwc on s.profile_id = pwc.profile_id
inner join wastecode wc on pwc.waste_code_uid = wc.waste_code_uid
INNER JOIN #header on s.confirmation_id = #header.confirmation_ID
WHERE s.confirmation_ID = @confirmation_id
AND s.company_id = @company_id
AND s.profit_ctr_ID = @profit_ctr_id 
ORDER BY pwc.primary_flag desc, wc.display_name

-- profit center info
SELECT
	fax, scheduling_phone
FROM
	profitcenter
WHERE
	company_id = @company_id
	AND profit_ctr_id = @profit_ctr_id


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_reports_schedule_detail] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_reports_schedule_detail] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_reports_schedule_detail] TO [EQAI]
    AS [dbo];

