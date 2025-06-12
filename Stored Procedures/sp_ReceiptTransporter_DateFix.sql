
create proc sp_ReceiptTransporter_DateFix
as

/* *************************************************************************

WorkOrderStop date fixes, ReceiptTransporter date fixes

-- 6/15/2011. The last word:
Use start date if date_act_arrive has no minutes.
Use date_act_arrive if it has minutes.
If it's a TRIP and if date_act_arrive does not have minutes, 
	use start_date as date_act_arrive and transporter_sign_date
If it's NOT a trip and no minutes on date_act_arrive, 
	and date_act_arrive not between start_date and end_date, 
	use start_date
On non-trip, don't just set workorder stop 1, set them all.

************************************************************************* */

-- Create a Work Table...   

if object_id('tempdb..#WorkOrderStop_DateFix') is not null drop table #WorkOrderStop_DateFix


	select distinct

		-- Key info
		wo.workorder_id, wo.company_id, wo.profit_ctr_id, wo.trip_id, 
		wos.stop_sequence_id, wot.transporter_sequence_id
		, wo.date_added, wo.workorder_status
		
		-- Workorder's Start Date, End Date
		, convert(varchar(12), wo.start_date, 101) as wo_start_date
		, convert(varchar(12), wo.end_date, 101) as wo_end_date

		-- What is the current Actual Arrive Date set to?
		, wos.date_act_arrive as old_wos_date_act_arrive
		
		-- Does existing wos_date_act_arrive have minutes?:
			-- Sneaky trick: dates themselves convert to whole numbers. 
			--               date + time convert to fractional numbers.
			-- So if convert->float = convert->int, it's just a date.
		, CASE WHEN 
			convert(float, isnull(wos.date_act_arrive, '1/1/1901')) = 
			convert(int, isnull(wos.date_act_arrive, '1/1/1901')) 
		  THEN 0 ELSE 1 END as old_wos_date_has_minutes
		
		-- What will the new one be?
		, convert(datetime, null) as new_wos_date_act_arrive
		
		-- What is the current Transporter (1) Sign Date set to?
		, wot.transporter_sign_date as old_wot_transporter_sign_date

		-- What will the new one be?
		, convert(datetime, null) as new_wot_transporter_sign_date

		-- What will the new one be?
		, convert(datetime, null) as new_wo_start_date
		, convert(datetime, null) as new_wo_end_date
		
		-- For what reason did we set the data the way it is?
		, convert(varchar(100), NULL) as reason

	into #WorkOrderStop_DateFix
	-- select count(wo.workorder_id)
	from workorderheader wo (nolock)  
	left outer join WorkOrderStop wos (nolock)
		ON wos.workorder_id = wo.workorder_id
		and wos.company_id = wo.company_id
		and wos.profit_ctr_id = wo.profit_ctr_id
		-- and wos.stop_sequence_id = 1 
		-- this will change in the future when there is more than 1 stop per workorder. 
		-- Doesn't have affect now (6/16)
	left outer join WorkOrderTransporter wot (nolock)
		ON wot.workorder_id = wo.workorder_id
		and wot.company_id = wo.company_id
		and wot.profit_ctr_id = wo.profit_ctr_id
		and wot.transporter_sequence_id = 1 
	WHERE
	wo.submitted_flag = 'T'
	AND (
		1=0
		or (wos.date_act_arrive is null and wo.start_date is not null)
		or (wo.trip_id is not null and wo.start_date is not null)
		or (wo.trip_id is null and wos.date_act_arrive not between wo.start_date and wo.end_date and wo.start_date is not null)
	)
		
-- Total of 106185 rows using WHERE.
-- Total of 519357 rows without WHERE.


	-- Update the Work Table...
	-- If there was no previous wos_date_act_arrive value...
	-- Use start date
	update #WorkOrderStop_DateFix set
		new_wos_date_act_arrive = wo_start_date,
		new_wot_transporter_sign_date = wo_start_date,
		reason = 'No previous wos_date_act_arrive value to compare to in the future.'
	-- select * from #WorkOrderStop_DateFix
	where old_wos_date_act_arrive is null
	and wo_start_date is not null
	-- 7589 rows


	-- Update the Work Table...
	-- If it's a TRIP and if date_act_arrive does not have minutes, 
	-- 		use start_date as date_act_arrive and transporter_sign_date
	-- Use start date if date_act_arrive has no minutes.
	update #WorkOrderStop_DateFix set
		new_wos_date_act_arrive = wo_start_date,
		new_wot_transporter_sign_date = wo_start_date,
		reason = 'Its a Trip, no minutes, using wo_start_date'
	-- select * from #WorkOrderStop_DateFix
	where trip_id is not null
	and new_wos_date_act_arrive is null
	and old_wos_date_has_minutes = 0
	and wo_start_date is not null
	-- 13248 rows


	-- Update the Work Table...
	-- If it's a TRIP and if date_act_arrive has minutes, 
	-- 		use start_date as date_act_arrive and transporter_sign_date
	-- Use date_act_arrive if it has minutes.
	update #WorkOrderStop_DateFix set
		new_wos_date_act_arrive = old_wos_date_act_arrive,
		new_wot_transporter_sign_date = old_wos_date_act_arrive,
		reason = 'Its a Trip, has minutes, using old_wos_date_act_arrive'
	-- select * from #WorkOrderStop_DateFix
	where trip_id is not null
	and new_wos_date_act_arrive is null
	and old_wos_date_has_minutes = 1
	and old_wos_date_act_arrive is not null
	-- 70745 rows



	-- Update the Work Table...
	-- If it's NOT a trip and no minutes on date_act_arrive, 
	-- 		and date_act_arrive not between start_date and end_date, use start_date
	-- Use start date if date_act_arrive has no minutes.
	update #WorkOrderStop_DateFix set
		new_wos_date_act_arrive = wo_start_date,
		new_wot_transporter_sign_date = wo_start_date,
		reason = 'Non Trip, no minutes, old_wos_date_act_arrive not between start_date, end_date, using start_date'
	-- select * from #WorkOrderStop_DateFix
	where trip_id is null
	and new_wos_date_act_arrive is null
	and old_wos_date_has_minutes = 0
	and old_wos_date_act_arrive not between wo_start_date and wo_end_date
	and wo_start_date is not null
	-- 779 rows


	-- Update the Work Table...
	-- If it's NOT a trip and has minutes on date_act_arrive, 
	-- 		and date_act_arrive not between start_date and end_date, use start_date
	-- Use date_act_arrive if it has minutes.
	update #WorkOrderStop_DateFix set
		new_wos_date_act_arrive = old_wos_date_act_arrive,
		new_wot_transporter_sign_date = old_wos_date_act_arrive,
		reason = 'Non Trip, has minutes, old_wos_date not btw start-end_date, use old_wos_date_act_arrive'
	-- select * from #WorkOrderStop_DateFix
	where trip_id is null
	and new_wos_date_act_arrive is null
	and old_wos_date_has_minutes = 1
	and old_wos_date_act_arrive not between wo_start_date and wo_end_date
	and old_wos_date_act_arrive is not null
	-- 29120 rows

	-- Update the Work Table...
	-- Move start_date earlier if the best calculated time to use is before start_date
	update #WorkOrderStop_DateFix set
		new_wo_start_date = convert(varchar(20), new_wos_date_act_arrive, 101)
	where new_wos_date_act_arrive < wo_start_date
	-- 17 rows

	update #WorkOrderStop_DateFix set
		new_wo_end_date = convert(varchar(20), new_wos_date_act_arrive, 101)
	where new_wos_date_act_arrive > dateadd(d, 1, wo_end_date)
	and new_wos_date_act_arrive is not null
	-- 34 rows

/*

Future Steps:
1. Identify and Audit where old_ <> new_
2. Update source tables where old_ <> new_
3. Update ReceiptTransporter data to match WorkOrderStop data

*/

	-- Audit WorkOrderHeader changes (moving start_date earlier):
	insert WorkOrderAudit 
	select distinct
	w.company_id, w.profit_ctr_id, w.workorder_id, '' as resource_type, 
		0 as sequence_id, 'WorkOrderHeader', 'start_date', start_date, 
		t.new_wo_start_date, null, 'SA-AGENT', getdate()
	from WorkOrderHeader w (nolock)
	inner join #WorkOrderStop_DateFix t
		on w.workorder_id = t.workorder_id
		and w.company_id = t.company_id
		and w.profit_ctr_id = t.profit_ctr_id
	where 
	w.submitted_flag = 'T'
	AND isnull(w.start_date, '1/1/1923') 
		<> isnull(t.new_wo_start_date, '1/1/1975')
	and isnull(t.new_wo_start_date, '1/1/1975') <> '1/1/1975'

	-- Update WorkOrderHeader changes (moving start_date earlier):
	Update WorkOrderHeader set start_date = t.new_wo_start_date
	-- select distinct w.company_id, w.profit_ctr_id, w.workorder_id, w.start_date, t.new_wo_start_date
	from WorkOrderHeader w (nolock)
	inner join #WorkOrderStop_DateFix t
		on w.workorder_id = t.workorder_id
		and w.company_id = t.company_id
		and w.profit_ctr_id = t.profit_ctr_id
	where 
	w.submitted_flag = 'T'
	AND isnull(w.start_date, '1/1/1923') 
		<> isnull(t.new_wo_start_date, '1/1/1975')
	and isnull(t.new_wo_start_date, '1/1/1975') <> '1/1/1975'

	-- Audit WorkOrderHeader changes (moving end_date later):
	insert WorkOrderAudit 
	select distinct
	w.company_id, w.profit_ctr_id, w.workorder_id, '' as resource_type, 
		0 as sequence_id, 'WorkOrderHeader', 'end_date', end_date, 
		t.new_wo_end_date, null, 'SA-AGENT', getdate()
	from WorkOrderHeader w (nolock)
	inner join #WorkOrderStop_DateFix t
		on w.workorder_id = t.workorder_id
		and w.company_id = t.company_id
		and w.profit_ctr_id = t.profit_ctr_id
	where 
	w.submitted_flag = 'T'
	AND isnull(w.end_date, '1/1/1923') 
		<> isnull(t.new_wo_end_date, '1/1/1975')
	and isnull(t.new_wo_end_date, '1/1/1975') <> '1/1/1975'

	-- Update WorkOrderHeader changes (moving end_date later):
	Update WorkOrderHeader set end_date = t.new_wo_end_date
	-- select distinct w.company_id, w.profit_ctr_id, w.workorder_id, w.end_date, t.new_wo_end_date
	from WorkOrderHeader w (nolock)
	inner join #WorkOrderStop_DateFix t
		on w.workorder_id = t.workorder_id
		and w.company_id = t.company_id
		and w.profit_ctr_id = t.profit_ctr_id
	where 
	w.submitted_flag = 'T'
	AND isnull(w.end_date, '1/1/1923') 
		<> isnull(t.new_wo_end_date, '1/1/1975')
	and isnull(t.new_wo_end_date, '1/1/1975') <> '1/1/1975'

	-- Audit WorkOrderStop changes:
	insert WorkOrderAudit 
	select distinct
	w.company_id, w.profit_ctr_id, w.workorder_id, '' as resource_type, 
		0 as sequence_id, 'WorkOrderStop', 'date_act_arrive', date_act_arrive, 
		t.new_wos_date_act_arrive, null, 'SA-AGENT', getdate()
	from WorkOrderStop w (nolock)
	INNER JOIN WorkOrderHeader wo
		on w.workorder_id = wo.workorder_id
		and w.company_id = wo.company_id
		and w.profit_ctr_id = wo.profit_ctr_id
	inner join #WorkOrderStop_DateFix t
		on w.workorder_id = t.workorder_id
		and w.company_id = t.company_id
		and w.profit_ctr_id = t.profit_ctr_id
		and w.stop_sequence_id = t.stop_sequence_id
	where 
	wo.submitted_flag = 'T'
	and isnull(w.date_act_arrive, '1/1/1923') 
		<> isnull(t.new_wos_date_act_arrive, '1/1/1975')
	and isnull(t.new_wos_date_act_arrive, '1/1/1975') <> '1/1/1975'

	-- Update WorkOrderStop changes:
	Update WorkOrderStop	set date_act_arrive = t.new_wos_date_act_arrive
	-- select distinct w.company_id, w.profit_ctr_id, w.workorder_id, w.date_act_arrive, t.new_wos_date_act_arrive
	from WorkOrderStop w (nolock)
	INNER JOIN WorkOrderHeader wo
		on w.workorder_id = wo.workorder_id
		and w.company_id = wo.company_id
		and w.profit_ctr_id = wo.profit_ctr_id
	inner join #WorkOrderStop_DateFix t
		on w.workorder_id = t.workorder_id
		and w.company_id = t.company_id
		and w.profit_ctr_id = t.profit_ctr_id
		and w.stop_sequence_id = t.stop_sequence_id
	where 
	wo.submitted_flag = 'T'
	and isnull(w.date_act_arrive, '1/1/1923') 
		<> isnull(t.new_wos_date_act_arrive, '1/1/1975')
	and isnull(t.new_wos_date_act_arrive, '1/1/1975') <> '1/1/1975'


	-- Audit WorkOrderTransporter changes:
	insert WorkOrderAudit 
	select distinct
	w.company_id, w.profit_ctr_id, w.workorder_id, '' as resource_type, 
		0 as sequence_id, 'WorkOrderTransporter', 'transporter_sign_date', 
		convert(varchar(20), transporter_sign_date, 101), convert(varchar(20), 
		t.new_wot_transporter_sign_date, 101), null, 'SA-AGENT', getdate()
	from WorkOrderTransporter w (nolock)
	INNER JOIN WorkOrderHeader wo
		on w.workorder_id = wo.workorder_id
		and w.company_id = wo.company_id
		and w.profit_ctr_id = wo.profit_ctr_id
	inner join #WorkOrderStop_DateFix t
		on w.workorder_id = t.workorder_id
		and w.company_id = t.company_id
		and w.profit_ctr_id = t.profit_ctr_id
		and w.transporter_sequence_id = t.transporter_sequence_id
	where 
	wo.submitted_flag = 'T'
	AND isnull(w.transporter_sign_date, '1/1/1923') 
		<> convert(varchar(20), isnull(t.new_wot_transporter_sign_date, '1/1/1975'), 101)
	and isnull(t.new_wot_transporter_sign_date, '1/1/1975') <> '1/1/1975'
	-- 12589 rows

	-- Update WorkOrderTransporter changes:
	Update WorkOrderTransporter set transporter_sign_date = convert(varchar(20), t.new_wot_transporter_sign_date, 101)
	-- select distinct w.company_id, w.profit_ctr_id, w.workorder_id, w.transporter_sequence_id, w.transporter_sign_date, convert(varchar(20), t.new_wot_transporter_sign_date, 101)
	from WorkOrderTransporter w (nolock)
	INNER JOIN WorkOrderHeader wo
		on w.workorder_id = wo.workorder_id
		and w.company_id = wo.company_id
		and w.profit_ctr_id = wo.profit_ctr_id
	inner join #WorkOrderStop_DateFix t
		on w.workorder_id = t.workorder_id
		and w.company_id = t.company_id
		and w.profit_ctr_id = t.profit_ctr_id
		and w.transporter_sequence_id = t.transporter_sequence_id
	where 
	wo.submitted_flag = 'T'
	AND isnull(w.transporter_sign_date, '1/1/1923') 
		<> convert(varchar(20), isnull(t.new_wot_transporter_sign_date, '1/1/1975'), 101)
	and isnull(t.new_wot_transporter_sign_date, '1/1/1975') <> '1/1/1975'


	-- Audit ReceiptTransporter (missing record, create it) changes:
	INSERT ReceiptAudit
	select distinct 
	r.company_id, r.profit_ctr_id, r.receipt_id, 0 as line_id, 0 as price_id, 
		'ReceiptTransporter' as table_name, 'All' as column_name, 
		'(no record)' as before_value, '(new record added)' as after_value, 
		null as audit_reference, 'SA-AGENT', 'SQL', getdate()
	from workorderheader wo (nolock) 
	inner join WorkOrderStop wos (nolock) ON wos.workorder_id = wo.workorder_id
		and wos.company_id = wo.company_id
		and wos.profit_ctr_id = wo.profit_ctr_id
		and wos.stop_sequence_id = 1 
	inner join billinglinklookup bll  (nolock) 
		on wo.company_id = bll.source_company_id
		and wo.profit_ctr_id = bll.source_profit_ctr_id
		and wo.workorder_id = bll.source_id
	inner join receipt r  (nolock) 
		on bll.receipt_id = r.receipt_id
		and bll.profit_ctr_id = r.profit_ctr_id
		and bll.company_id = r.company_id
	left outer join transporter t (nolock)
		on r.hauler = t.transporter_code
	WHERE
		wo.submitted_flag = 'T'
		and r.submitted_flag = 'T'
		and not exists (
			select 1 from receipttransporter rt1  (nolock) 
			where rt1.receipt_id = r.receipt_id
			and rt1.profit_ctr_id = r.profit_ctr_id
			and rt1.company_id = r.company_id
			and rt1.transporter_sequence_id = 1
		)

	-- Insert ReceiptTransporter (missing record, create it) changes:
	INSERT ReceiptTransporter
	select distinct
		r.company_id,
		r.profit_ctr_id,
		r.receipt_id,
		1,
		t.transporter_code,
		t.transporter_name,
		t.transporter_epa_id,
		t.transporter_contact_phone,
		null, -- .transporter_sign_name,
		wos.date_act_arrive, -- t.transporter_sign_date,
		'SA-AGENT' as added_by,
		GETDATE() as date_added,
		'SA-AGENT' as modified_by,
		GETDATE() as date_modified
	from workorderheader wo (nolock) 
	inner join WorkOrderStop wos (nolock) ON wos.workorder_id = wo.workorder_id
		and wos.company_id = wo.company_id
		and wos.profit_ctr_id = wo.profit_ctr_id
		and wos.stop_sequence_id = 1 
	inner join billinglinklookup bll  (nolock) 
		on wo.company_id = bll.source_company_id
		and wo.profit_ctr_id = bll.source_profit_ctr_id
		and wo.workorder_id = bll.source_id
	inner join receipt r  (nolock) 
		on bll.receipt_id = r.receipt_id
		and bll.profit_ctr_id = r.profit_ctr_id
		and bll.company_id = r.company_id
	left outer join transporter t (nolock)
		on r.hauler = t.transporter_code
	WHERE
		wo.submitted_flag = 'T'
		AND r.submitted_flag = 'T'
		and not exists (
			select 1 from receipttransporter rt1  (nolock) 
			where rt1.receipt_id = r.receipt_id
			and rt1.profit_ctr_id = r.profit_ctr_id
			and rt1.company_id = r.company_id
			and rt1.transporter_sequence_id = 1
		)


	-- Audit ReceiptTransporter (existing, but incorrect record, fix it) changes:
	INSERT ReceiptAudit
	select distinct 
	r.company_id, r.profit_ctr_id, r.receipt_id, 0 as line_id, 0 as price_id, 
		'ReceiptTransporter' as table_name, 'transporter_sign_date' as column_name, 
		convert(varchar(20), rt1.transporter_sign_date, 120) as before_value, 
		convert(varchar(20), wos.date_act_arrive, 120) as after_value, 
		null as audit_reference, 'SA-AGENT', 'SQL', getdate()
	from ReceiptTransporter rt1 (nolock)
	inner join receipt r  (nolock) 
		on rt1.receipt_id = r.receipt_id
		and rt1.profit_ctr_id = r.profit_ctr_id
		and rt1.company_id = r.company_id
		and rt1.transporter_sequence_id = 1
	inner join billinglinklookup bll  (nolock) 
		on bll.receipt_id = r.receipt_id
		and bll.profit_ctr_id = r.profit_ctr_id
		and bll.company_id = r.company_id
	inner join workorderheader wo (nolock) 
		on wo.company_id = bll.source_company_id
		and wo.profit_ctr_id = bll.source_profit_ctr_id
		and wo.workorder_id = bll.source_id
	inner join WorkOrderStop wos (nolock) ON wos.workorder_id = wo.workorder_id
		and wos.company_id = wo.company_id
		and wos.profit_ctr_id = wo.profit_ctr_id
		and wos.stop_sequence_id = 1 
	WHERE
		wo.submitted_flag = 'T'
		AND r.submitted_flag = 'T'	
		AND convert(varchar(20), wos.date_act_arrive, 101) 
			<> convert(varchar(20), rt1.transporter_sign_date, 101)
	and isnull(wos.date_act_arrive, '1/1/1975') <> '1/1/1975'
	-- 120

	-- Update ReceiptTransporter changes:
	UPDATE ReceiptTransporter SET transporter_sign_date = convert(varchar(20), wos.date_act_arrive, 101)
	-- select distinct rt1.receipt_id, rt1.company_id, rt1.profit_ctr_id, rt1.transporter_sign_date, convert(varchar(20), wos.date_act_arrive, 101)
	from ReceiptTransporter rt1 (nolock)
	inner join receipt r  (nolock) 
		on rt1.receipt_id = r.receipt_id
		and rt1.profit_ctr_id = r.profit_ctr_id
		and rt1.company_id = r.company_id
		and rt1.transporter_sequence_id = 1
	inner join billinglinklookup bll  (nolock) 
		on bll.receipt_id = r.receipt_id
		and bll.profit_ctr_id = r.profit_ctr_id
		and bll.company_id = r.company_id
	inner join workorderheader wo (nolock) 
		on wo.company_id = bll.source_company_id
		and wo.profit_ctr_id = bll.source_profit_ctr_id
		and wo.workorder_id = bll.source_id
	inner join WorkOrderStop wos (nolock) ON wos.workorder_id = wo.workorder_id
		and wos.company_id = wo.company_id
		and wos.profit_ctr_id = wo.profit_ctr_id
		and wos.stop_sequence_id = 1 
	where
		wo.submitted_flag = 'T'
		AND r.submitted_flag = 'T'	
		AND convert(varchar(20), wos.date_act_arrive, 101) <> convert(varchar(20), rt1.transporter_sign_date, 101)
		and isnull(wos.date_act_arrive, '1/1/1975') <> '1/1/1975'

	drop table #WorkOrderStop_DateFix


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_ReceiptTransporter_DateFix] TO [EQAI]
    AS [dbo];

