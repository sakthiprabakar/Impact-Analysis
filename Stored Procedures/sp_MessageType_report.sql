
CREATE PROCEDURE sp_MessageType_report (
	@start_date	datetime = NULL,
	@end_date	datetime = NULL,
	@force_report_send int = 0,
	@debug		int = 0
) AS
/***************************************************************
Loads to:	Plt_AI

Creates an email summarizing the Message table activity between 2 dates.

02/12/2009 JPB	Created
04/02/2009 JPB  Changed donotreply address to itdept
02/10/2010 JPB  Modified to list Failed & InProgress first, then the rest.
11/22/2011 JPB  Modified subject to indicate problems easier.
	- Also rewrote to use varchar(max) fields instead of goofy text update kludges.
04/11/20-12 JPB	Modified to...
				1. Select for last 24 hours of start date - also last 24 hours of date_to_send
					(some emails are set to send 24 hours after date_added)
				2. Still Waiting shouldn't be red, it's not an error, unless it should've already sent
04/12/2012 RWB	Look for type_id already set before attempting to match by subject.
                Note that a bug still needs to be fixed...when a window is matched, a duplicate record is returned.
05/03/2012 JPB  Added new reporting for last-date-sent vs last-date-added and flagging errors where there's a send
                delay more than 60 minutes ongoing.
08/02/2012 JPB	Changed reporting period to cover the last week, always.  Also set up to run more often and only
				report problems through the day - no emails if nothing to report unless force_report_send is specified
				at the regular 5am scheduled run.
09/10/2013 JPB	Slight change in timing: Most fails we see now are where the last record was
				Added so recently that the regular schedule for the sender hasn't picked it up yet.
				So no we ignore records less than 5 minutes old.
				Also, added a max age to the #types update of 60 days. Cut execution from 28s to 3s.

sp_MessageType_report null, null, 0, 2

-- 7/21 - 7/25: No fails or problems. So unless the @force flag is given, no email report comes out.
sp_MessageType_report @start_date = '7/21/2012', @end_date = '7/25/2012', @force_report_send = 0, @debug = 1 

sp_MessageType_Report 
	@start_date = null, 
	@end_date = null, 
	@force_report_send = 1,
	@debug = 11

select top 5 * from message order by message_id desc

select * from MessageType

****************************************************************/

DECLARE 
	@days_to_run_default	int = 30,
	@timer				datetime = getdate(),
	@order_detail		varchar(max),
	@email_text			varchar(max) = '',
	@detail_text		varchar(max) = '',
	@email_html			varchar(max) = '',
	@detail_html		varchar(max) = '',
	@crlf				varchar(4),
	@crlf2				varchar(8),
	@message_id			int,
	@description		varchar(60), 
	@q					int,
	@total_count		int, 
	@sent_count			int, 
	@fail_count			int, 
	@in_progress_too_long_minutes	int = 30,
	@fail_in_progress_too_long_count			int, 
	@total_fail_count	int = 0,
	@new_count			int, 
	@in_progress_count	int,
	@lastDateSent		varchar(60),
	@lastDateAdd		varchar(60),
	@bigSendDelay		int,
	@cnt				int,
	@thisDate			varchar(40),
	@serverType			varchar(20),
	@subject			varchar(200)

if @end_date is NULL set @end_date = getdate()
if @start_date is NULL set @start_date = dateadd(dd, (-1 * @days_to_run_default), @end_date)

if @debug > 0 print 'Started: ' + convert(varchar(20), datediff(ms, @timer, getdate()))

SELECT @serverType = replace(@@SERVERNAME, 'ntsql1', '')
if @serverType = '' set @serverType = 'PROD'

set @crlf = char(13) + char(10)
set @crlf2 = @crlf + @crlf
Set @email_html = '<html><body style="font-family:verdana,sans-serif;font-size:14px"><p>Summary of {server} EQ Message-Sender activity between {start_date} and {end_date}.</p>
	<table border="1" cellspacing="0" cellpadding="2" style="font-size:14px"><tr><th></th><th>Description</th><th>Total</th><th>Sent</th><th>Failed</th>
	<th>In Progress Too Long (over ' + convert(varchar(20), @in_progress_too_long_minutes) + 'm)</th><th>Still New</th><th>Still In Progress (not over limit yet)</th><th>Since Last Send</th>
	<th>Since Last Add</th></tr>{detail}</table><p>This is an automated email, run at {current_date}.</p></body></html>'
Set @email_text = 'Summary of {server} EQ Message-Sender activity between {start_date} and {end_date}.' + @crlf2 + '{detail}' + @crlf2 + 'This is an automated email, run at {current_date}.' + @crlf

set @subject = 'Message Sender Report'

if @debug > 0 print 'Init vars Done: ' + convert(varchar(20), datediff(ms, @timer, getdate()))

select type_id, convert(datetime, null) as max_date_added, convert(datetime, null) as max_date_sent
into #types from MessageType

update #types
	set max_date_added = td.max_date_added,
	max_date_sent = td.max_date_sent
from #types inner join 
	(
	select coalesce(m.message_type_id, mt.type_id) as type_id, 
	max(m.date_added) max_date_added,
	max(m.date_delivered) max_date_sent
	from messagetype mt
	left outer join message m 
	on (
		(m.message_type_id is not null and m.message_type_id = mt.type_id )
		or
		(m.message_type_id is null and m.subject like '%' + mt.subject_string + '%' and m.message_type = mt.type_flag)
	)
	and coalesce(m.date_to_send, m.date_added) < getdate()
	where m.date_added > getdate()-60
	and m.date_added < dateadd(mi, -5, getdate())
	and m.status <> 'V'
	group by coalesce(m.message_type_id, mt.type_id)
) td on #types.type_id = td.type_id

if @debug > 0 print '#Types helper table created: ' + convert(varchar(20), datediff(ms, @timer, getdate()))

-- Run to #list, so we can order later.
-- rb 04/12/2012 Add another unioned select where Message.message_type_id is set, modify the select that joins
--               on message subject to process only Message.message_type_id = null.
--               After adding this, union was creating duplicates for those new types with values, removed union.
	select 
		mt.description, 
		1 as q,
		(count(distinct message_id)) as total_count,
		(sum (case when status = 'S' then 1 else 0 end)) as sent_count,
		(sum (case when status = 'F' and not error_description like '%This Email Failed!%' then 1 else 0 end)) as fail_count,
		(sum (case when status = 'N' then 1 else 0 end)) as new_count,
		(sum (case when status = 'I' and coalesce(m.date_to_send, m.date_added) > dateadd(n, (-1 * @in_progress_too_long_minutes), getdate()) then 1 else 0 end)) as in_progress_count,
		(sum (case when status = 'I' and coalesce(m.date_to_send, m.date_added) < dateadd(n, (-1 * @in_progress_too_long_minutes), getdate()) then 1 else 0 end)) as fail_in_progress_too_long_count,
		isnull((dbo.fn_time_for_humans(t.max_date_sent, getdate()) + ' (' + convert(varchar(20), t.max_date_sent) + ')'), 'Never') as last_date_sent,
		isnull((dbo.fn_time_for_humans(t.max_date_added, getdate()) + ' (' + convert(varchar(20), t.max_date_added) + ')'), 'Never') as last_date_added,
		case when datediff(n, isnull(t.max_date_sent, getdate()), isnull(t.max_date_added, getdate())) > 60	then 1 else 0 end as big_send_delay
 	into #list
	from messagetype mt 
	join message m on m.message_type_id = mt.type_id and m.message_type = mt.type_flag 
		and (
			m.date_added between @start_date and @end_date
			OR
			isnull(m.date_to_send, m.date_added) between @start_date and @end_date
			)
	left outer join #types t on mt.type_id = t.type_id
	where m.status <> 'V'
	group by mt.description, mt.subject_string, mt.type_flag, t.max_date_sent, t.max_date_added

if @debug > 0 print 'Query 1 (Message Type Defined) Done: ' + convert(varchar(20), datediff(ms, @timer, getdate()))
if @debug > 1 begin
	print 'Query 1 Produced...'
	select * from #list where q = 1
end


	insert #list
	select 
		mt.description, 
		2 as q,
		(count(distinct message_id)) as total_count,
		(sum (case when status = 'S' then 1 else 0 end)) as sent_count,
		(sum (case when status = 'F' and not error_description like '%This Email Failed!%' then 1 else 0 end)) as fail_count,
		(sum (case when status = 'N' then 1 else 0 end)) as new_count,
		(sum (case when status = 'I' and coalesce(m.date_to_send, m.date_added) > dateadd(n, (-1 * @in_progress_too_long_minutes), getdate()) then 1 else 0 end)) as in_progress_count,
		(sum (case when status = 'I' and coalesce(m.date_to_send, m.date_added) < dateadd(n, (-1 * @in_progress_too_long_minutes), getdate()) then 1 else 0 end)) as fail_in_progress_too_long_count,
		isnull((dbo.fn_time_for_humans(t.max_date_sent, getdate()) + ' (' + convert(varchar(20), t.max_date_sent) + ')'), 'Never') as last_date_sent,
		isnull((dbo.fn_time_for_humans(t.max_date_added, getdate()) + ' (' + convert(varchar(20), t.max_date_added) + ')'), 'Never') as last_date_added,
		case when datediff(n, isnull(t.max_date_sent, getdate()), isnull(t.max_date_added, getdate())) > 60	then 1 else 0 end as big_send_delay
	from messagetype mt 
	left outer join message m on m.subject like '%' + mt.subject_string + '%' and m.message_type = mt.type_flag 
		and (
			m.date_added between @start_date and @end_date
			OR
			isnull(m.date_to_send, m.date_added) between @start_date and @end_date
			)
	left outer join #types t on mt.type_id = t.type_id
	where m.message_type_id is null
	and m.status <> 'V'
	and not exists (select 1 from #list where description = mt.description)
	group by mt.description, mt.subject_string, mt.type_flag, t.max_date_sent, t.max_date_added

if @debug > 0 print 'Query 2 (Message Type Maybe Defined) Done: ' + convert(varchar(20), datediff(ms, @timer, getdate()))
if @debug > 1 begin
	print 'Query 2 Produced...'
	select * from #list where q = 2
end

	insert #list
	select 
		'Other ' +
		case m.message_type
			when 'E' then 'Email'
			when 'F' then 'Fax'
			else '(Unknown type)'
		end 
		as description, 
		3 as q,
		isnull(count(distinct message_id), 0) as total_count,
		isnull(sum (case when status = 'S' then 1 else 0 end), 0) as sent_count,
		isnull(sum (case when (status = 'F' and not error_description like '%This Email Failed!%') or (status = 'N' and isnull(date_to_send, date_added) < getdate()) then 1 else 0 end), 0) as fail_count,
		isnull(sum (case when status = 'N' and isnull(date_to_send, date_added) > getdate() then 1 else 0 end), 0) as new_count,
		(sum (case when status = 'I' and coalesce(m.date_to_send, m.date_added) > dateadd(n, (-1 * @in_progress_too_long_minutes), getdate()) then 1 else 0 end)) as in_progress_count,
		(sum (case when status = 'I' and coalesce(m.date_to_send, m.date_added) < dateadd(n, (-1 * @in_progress_too_long_minutes), getdate()) then 1 else 0 end)) as fail_in_progress_too_long_count,
		isnull(
			(
				dbo.fn_time_for_humans(
					(
						select max(date_modified) 
						from message 
						where status = 'S' and 		
							'Other ' +
							case m.message_type
								when 'E' then 'Email'
								when 'F' then 'Fax'
								else '(Unknown type)'
							end
							=
							'Other ' +
							case message.message_type
								when 'E' then 'Email'
								when 'F' then 'Fax'
								else '(Unknown type)'
							end
 					), 
					getdate()
				) + ' (' + convert(varchar(20), 
					(select max(date_modified) 
					from message 
					where status = 'S' and
							'Other ' +
							case m.message_type
								when 'E' then 'Email'
								when 'F' then 'Fax'
								else '(Unknown type)'
							end
							=
							'Other ' +
							case message.message_type
								when 'E' then 'Email'
								when 'F' then 'Fax'
								else '(Unknown type)'
							end
					)
				) + ')'
			), 'Never') as last_date_sent,
		isnull(
			(
				dbo.fn_time_for_humans(
					(
						select max(date_added) 
						from message 
						where 
							'Other ' +
							case m.message_type
								when 'E' then 'Email'
								when 'F' then 'Fax'
								else '(Unknown type)'
							end
							=
							'Other ' +
							case message.message_type
								when 'E' then 'Email'
								when 'F' then 'Fax'
								else '(Unknown type)'
							end
					), 
					getdate()
				) + ' (' + convert(varchar(20), 
					(select max(date_added) 
					from message 
					where
						status <> 'V'
						AND
							'Other ' +
							case m.message_type
								when 'E' then 'Email'
								when 'F' then 'Fax'
								else '(Unknown type)'
							end
							=
							'Other ' +
							case message.message_type
								when 'E' then 'Email'
								when 'F' then 'Fax'
								else '(Unknown type)'
							end
					)
				) + ')'
			), 'Never') as last_date_added,
			case when datediff(n, 
				isnull(
					(
						select max(date_modified) 
						from message 
						where status = 'S' and 
							'Other ' +
							case m.message_type
								when 'E' then 'Email'
								when 'F' then 'Fax'
								else '(Unknown type)'
							end
							=
							'Other ' +
							case message.message_type
								when 'E' then 'Email'
								when 'F' then 'Fax'
								else '(Unknown type)'
							end
					), 
					getdate()
				),
				isnull(
					(
						select max(date_added) 
						from message 
						where 
							status <> 'V'
							AND
							'Other ' +
							case m.message_type
								when 'E' then 'Email'
								when 'F' then 'Fax'
								else '(Unknown type)'
							end
							=
							'Other ' +
							case message.message_type
								when 'E' then 'Email'
								when 'F' then 'Fax'
								else '(Unknown type)'
							end
						
					), 
					getdate()
				)
			) > 60
			then 1		
			else 0
			end as big_send_delay
	from message m 
	where m.message_type_id is null
	and m.status <> 'V'
	and m.message_id not in (
		select m.message_id
		from messagetype mt 
		inner join message m on ((m.subject like '%' + mt.subject_string + '%' and m.message_type = mt.type_flag)
										or (m.message_type_id = mt.type_id and m.message_type = mt.type_flag))
		and (
			m.date_added between @start_date and @end_date
			OR
			isnull(m.date_to_send, m.date_added) between @start_date and @end_date
			)
	)
	and (
		m.date_added between @start_date and @end_date
		OR
		isnull(m.date_to_send, m.date_added) between @start_date and @end_date
		)
	and not exists (select 1 from #list where description = 'Other ' +
		case m.message_type
			when 'E' then 'Email'
			when 'F' then 'Fax'
			else '(Unknown type)'
		end )		
	GROUP BY m.message_type
	-- rb 04/21/2012 Removed after removing unions, the cursor orders by this
	--order by q, description

if @debug > 0 print 'Query 3 (No Message Type Required) Done: ' + convert(varchar(20), datediff(ms, @timer, getdate()))
if @debug > 1 begin
	print 'Query 3 Produced...'
	select * from #list where q = 3
end

IF (select SUM(fail_count) + SUM(big_send_delay) + SUM(fail_in_progress_too_long_count) + @force_report_send  from #list) > 0
BEGIN

		IF (select SUM(fail_count) + SUM(big_send_delay) + SUM(fail_in_progress_too_long_count) from #list) = 0
			set @subject = @subject + ' [No Problems!]'

		select @subject = @subject + ' (' +
			convert(varchar(10), SUM(fail_count) + SUM(big_send_delay) + SUM(fail_in_progress_too_long_count)) + 'f, ' +
			convert(varchar(10), SUM(new_count) ) + 'w, ' +
			convert(varchar(10), SUM(in_progress_count) ) + 'i, ' +
			convert(varchar(10), SUM(total_count) ) + 't) '
		from #list

		if @debug > 0 print 'Email Subject Created: ' + convert(varchar(20), datediff(ms, @timer, getdate()))
			
		-- Failed messages:
		-- declare cursor 
		DECLARE ord CURSOR FOR 
			select description, q, total_count, sent_count, fail_count, fail_in_progress_too_long_count, new_count, in_progress_count, last_date_sent, last_date_added, big_send_delay
			from #list
			where fail_count > 0 or big_send_delay > 0 or fail_in_progress_too_long_count > 0
			order by total_count desc, description
		OPEN ord

		FETCH ord INTO @description, @q, @total_count, @sent_count, @fail_count, @fail_in_progress_too_long_count, @new_count, @in_progress_count, @lastDateSent, @lastDateAdd, @bigSendDelay

		set @cnt = 0
		WHILE @@FETCH_STATUS = 0
		BEGIN
		   set @cnt = @cnt + 1

			Set @order_detail = '<tr>' +
				'<td align="right">' + Cast(@cnt as varChar(20)) + '.</td>' +
				'<td><em>' + @description + '</em></td>' +
				'<td>' + Cast( @total_count as varChar(20)) + '</td>' +
				'<td>' + Cast( @sent_count as varChar(20)) + '</td>'
				
			if @fail_count > 0
				set @order_detail = @order_detail + '<td bgcolor="#ff3333">'
			else
				set @order_detail = @order_detail + '<td>'
			set @order_detail = @order_detail + Cast( @fail_count as varChar(20)) + '</td>'

			if @fail_in_progress_too_long_count > 0
				set @order_detail = @order_detail + '<td bgcolor="#ff3333">'
			else
				set @order_detail = @order_detail + '<td>'
			set @order_detail = @order_detail + Cast( @fail_in_progress_too_long_count as varChar(20)) + '</td>'
			
			if @new_count > 0
				set @order_detail = @order_detail + '<td bgcolor="#66cc33">'
			else
				set @order_detail = @order_detail + '<td>'
			set @order_detail = @order_detail + Cast( @new_count as varChar(20)) + '</td>'

			if @in_progress_count > 0
				set @order_detail = @order_detail + '<td bgcolor="#ffff33">'
			else
				set @order_detail = @order_detail + '<td>'
			set @order_detail = @order_detail + Cast( @in_progress_count as varChar(20)) + '</td>'
			
			if @bigSendDelay > 0
				set @order_detail = @order_detail + '<td bgcolor="#ff3333">'
			else
				set @order_detail = @order_detail + '<td>'
			set @order_detail = @order_detail + @lastDateSent + '</td>'
			
			if @bigSendDelay > 0
				set @order_detail = @order_detail + '<td bgcolor="#ff3333">'
			else
				set @order_detail = @order_detail + '<td>'
			set @order_detail = @order_detail + @lastDateAdd + '</td>'

			set @detail_html = @detail_html + '</tr>'

			set @detail_html = @detail_html + @order_detail
				
			Set @order_detail = 'Item ' + Cast(@cnt as varChar(20)) + ': ' + @description + @crlf +
				'  Total: ' + Cast( @total_count as varChar(20)) + @crlf +
				'  Sent: ' + Cast( @sent_count as varChar(20)) + @crlf +
				'  Failed: ' + Cast( @fail_count as varChar(20)) + @crlf +
				'  In Progress Too Long: ' + Cast( @fail_in_progress_too_long_count as varChar(20)) + @crlf +
				'  Still New: ' + Cast( @new_count as varChar(20)) + @crlf +
				'  Still In Progress (Ok): ' + Cast( @in_progress_count as varChar(20)) + @crlf +
				'  Last Sent: ' + @lastDateSent + @crlf +
				'  Last Date Added: ' + @lastDateAdd + @crlf2

			set @detail_text = @detail_text + @order_detail
			
			FETCH ord INTO @description, @q, @total_count, @sent_count, @fail_count, @fail_in_progress_too_long_count, @new_count, @in_progress_count, @lastDateSent, @lastDateAdd, @bigSendDelay
		END

		CLOSE ord
		DEALLOCATE ord

		if @debug > 0 print 'Cursor 1 (Fails) Done: ' + convert(varchar(20), datediff(ms, @timer, getdate()))


		-- Messages still in progress:
		DECLARE ord CURSOR FOR 
			select description, q, total_count, sent_count, fail_count, fail_in_progress_too_long_count, new_count, in_progress_count, last_date_sent, last_date_added, big_send_delay
			from #list
			where in_progress_count > 0
			and not (fail_count > 0 or big_send_delay > 0 or fail_in_progress_too_long_count > 0)
			order by total_count desc, description
		OPEN ord

		FETCH ord INTO @description, @q, @total_count, @sent_count, @fail_count, @fail_in_progress_too_long_count, @new_count, @in_progress_count, @lastDateSent, @lastDateAdd, @bigSendDelay

		WHILE @@FETCH_STATUS = 0
		BEGIN
		   set @cnt = @cnt + 1

			Set @order_detail = '<tr>' +
				'<td align="right">' + Cast(@cnt as varChar(20)) + '.</td>' +
				'<td><em>' + @description + '</em></td>' +
				'<td>' + Cast( @total_count as varChar(20)) + '</td>' +
				'<td>' + Cast( @sent_count as varChar(20)) + '</td>'

			if @fail_count > 0
				set @order_detail = @order_detail + '<td bgcolor="#ff3333">'
			else
				set @order_detail = @order_detail + '<td>'
			set @order_detail = @order_detail + Cast( @fail_count as varChar(20)) + '</td>'

			if @fail_in_progress_too_long_count > 0
				set @order_detail = @order_detail + '<td bgcolor="#ff3333">'
			else
				set @order_detail = @order_detail + '<td>'
			set @order_detail = @order_detail + Cast( @fail_in_progress_too_long_count as varChar(20)) + '</td>'
			
			if @new_count > 0
				set @order_detail = @order_detail + '<td bgcolor="#66cc33">'
			else
				set @order_detail = @order_detail + '<td>'
			set @order_detail = @order_detail + Cast( @new_count as varChar(20)) + '</td>'

			if @in_progress_count > 0
				set @order_detail = @order_detail + '<td bgcolor="#ffff33">'
			else
				set @order_detail = @order_detail + '<td>'
			set @order_detail = @order_detail + Cast( @in_progress_count as varChar(20)) + '</td>'
			
			if @bigSendDelay > 0
				set @order_detail = @order_detail + '<td bgcolor="#ff3333">'
			else
				set @order_detail = @order_detail + '<td>'
			set @order_detail = @order_detail + @lastDateSent + '</td>'
			
			if @bigSendDelay > 0
				set @order_detail = @order_detail + '<td bgcolor="#ff3333">'
			else
				set @order_detail = @order_detail + '<td>'
			set @order_detail = @order_detail + @lastDateAdd + '</td>'

			set @detail_html = @detail_html + '</tr>'
				
			set @detail_html = @detail_html + @order_detail

			Set @order_detail = 'Item ' + Cast(@cnt as varChar(20)) + ': ' + @description + @crlf +
				'  Total: ' + Cast( @total_count as varChar(20)) + @crlf +
				'  Sent: ' + Cast( @sent_count as varChar(20)) + @crlf +
				'  Failed: ' + Cast( @fail_count as varChar(20)) + @crlf +
				'  In Progress Too Long: ' + Cast( @fail_in_progress_too_long_count as varChar(20)) + @crlf +
				'  Still New: ' + Cast( @new_count as varChar(20)) + @crlf +
				'  Still In Progress (Ok): ' + Cast( @in_progress_count as varChar(20)) + @crlf +
				'  Last Sent: ' + @lastDateSent + @crlf +
				'  Last Date Added: ' + @lastDateAdd + @crlf2

			set @detail_text = @detail_text + @order_detail
			
			FETCH ord INTO @description, @q, @total_count, @sent_count, @fail_count, @fail_in_progress_too_long_count, @new_count, @in_progress_count, @lastDateSent, @lastDateAdd, @bigSendDelay
		END

		CLOSE ord
		DEALLOCATE ord

		if @debug > 0 print 'Cursor 2 (In Progress) Done: ' + convert(varchar(20), datediff(ms, @timer, getdate()))

		-- The rest:
		DECLARE ord CURSOR FOR 
			select description, q, total_count, sent_count, fail_count, fail_in_progress_too_long_count, new_count, in_progress_count, last_date_sent, last_date_added, big_send_delay
			from #list
			where not (in_progress_count > 0)
			and not (fail_count > 0 or big_send_delay > 0 or fail_in_progress_too_long_count > 0)
			order by total_count desc, description
		OPEN ord

		FETCH ord INTO @description, @q, @total_count, @sent_count, @fail_count, @fail_in_progress_too_long_count, @new_count, @in_progress_count, @lastDateSent, @lastDateAdd, @bigSendDelay

		WHILE @@FETCH_STATUS = 0
		BEGIN
		   set @cnt = @cnt + 1

			Set @order_detail = '<tr>' +
				'<td align="right">' + Cast(@cnt as varChar(20)) + '.</td>' +
				'<td><em>' + @description + '</em></td>' +
				'<td>' + Cast( @total_count as varChar(20)) + '</td>' +
				'<td>' + Cast( @sent_count as varChar(20)) + '</td>'
				
			if @fail_count > 0
				set @order_detail = @order_detail + '<td bgcolor="#ff3333">'
			else
				set @order_detail = @order_detail + '<td>'
			set @order_detail = @order_detail + Cast( @fail_count as varChar(20)) + '</td>'

			if @fail_in_progress_too_long_count > 0
				set @order_detail = @order_detail + '<td bgcolor="#ff3333">'
			else
				set @order_detail = @order_detail + '<td>'
			set @order_detail = @order_detail + Cast( @fail_in_progress_too_long_count as varChar(20)) + '</td>'
			
			if @new_count > 0
				set @order_detail = @order_detail + '<td bgcolor="#66cc33">'
			else
				set @order_detail = @order_detail + '<td>'
			set @order_detail = @order_detail + Cast( @new_count as varChar(20)) + '</td>'

			if @in_progress_count > 0
				set @order_detail = @order_detail + '<td bgcolor="#ffff33">'
			else
				set @order_detail = @order_detail + '<td>'
			set @order_detail = @order_detail + Cast( @in_progress_count as varChar(20)) + '</td>'
			
			if @bigSendDelay > 0
				set @order_detail = @order_detail + '<td bgcolor="#ff3333">'
			else
				set @order_detail = @order_detail + '<td>'
			set @order_detail = @order_detail + @lastDateSent + '</td>'
			
			if @bigSendDelay > 0
				set @order_detail = @order_detail + '<td bgcolor="#ff3333">'
			else
				set @order_detail = @order_detail + '<td>'
			set @order_detail = @order_detail + @lastDateAdd + '</td>'

			set @detail_html = @detail_html + '</tr>'

			set @detail_html = @detail_html + @order_detail		

			Set @order_detail = 'Item ' + Cast(@cnt as varChar(20)) + ': ' + @description + @crlf +
				'  Total: ' + Cast( @total_count as varChar(20)) + @crlf +
				'  Sent: ' + Cast( @sent_count as varChar(20)) + @crlf +
				'  Failed: ' + Cast( @fail_count as varChar(20)) + @crlf +
				'  In Progress Too Long: ' + Cast( @fail_in_progress_too_long_count as varChar(20)) + @crlf +
				'  Still New: ' + Cast( @new_count as varChar(20)) + @crlf +
				'  Still In Progress (Ok): ' + Cast( @in_progress_count as varChar(20)) + @crlf +
				'  Last Sent: ' + @lastDateSent + @crlf +
				'  Last Date Added: ' + @lastDateAdd + @crlf2

			set @detail_text = @detail_text + @order_detail
			
			FETCH ord INTO @description, @q, @total_count, @sent_count, @fail_count, @fail_in_progress_too_long_count, @new_count, @in_progress_count, @lastDateSent, @lastDateAdd, @bigSendDelay
		END

		CLOSE ord
		DEALLOCATE ord

		if @debug > 0 print 'Cursor 3 (all others) Done: ' + convert(varchar(20), datediff(ms, @timer, getdate()))

		-- Replace {detail} with the detail info:
		set @email_html = REPLACE(@email_html, '{detail}', @detail_html)
		set @email_text = REPLACE(@email_text, '{detail}', @detail_text)

		-- Replace {start_date} with @start_date:
		set @email_html = REPLACE(@email_html, '{start_date}', convert(varchar(20), @start_date))
		set @email_text = REPLACE(@email_text, '{start_date}', convert(varchar(20), @start_date))

		-- Replace {end_date} with @end_date:
		set @email_html = REPLACE(@email_html, '{end_date}', convert(varchar(20), @end_date))
		set @email_text = REPLACE(@email_text, '{end_date}', convert(varchar(20), @end_date))

		-- Replace {current_date} with getdate():
		set @email_html = REPLACE(@email_html, '{current_date}', convert(varchar(20), getdate()))
		set @email_text = REPLACE(@email_text, '{current_date}', convert(varchar(20), getdate()))

		-- Replace {server} with @serverType:
		set @email_html = REPLACE(@email_html, '{server}', @serverType)
		set @email_text = REPLACE(@email_text, '{server}', @serverType)

		--- Prepare the insert into the message table

		if @debug > 0 print 'Replaced slugs in email body: ' + convert(varchar(20), datediff(ms, @timer, getdate()))

		EXEC @message_id = sp_sequence_next 'message.message_id'

		Insert Into Message (message_id, status, message_type, message_source, subject, message, html, added_by, date_added) 
			select @message_id, 'N', 'E','SchedTask', @subject, @email_text, @email_html, 'EQWEB',GetDate()

		if @debug = 0
			Insert Into MessageAddress(message_id, address_type, email) Values
				(@message_id, 'TO', 'webmaster@eqonline.com')
		else
			Insert Into MessageAddress(message_id, address_type, email) Values
				(@message_id, 'TO', 'jonathan.broome@eqonline.com')

		Insert Into MessageAddress(message_id, address_type, name, company, email) Values
					   (@message_id, 'FROM', 'EQ Online', 'EQ', 'itdept@eqonline.com')

		if @debug > 0 print 'Message Queued: ' + convert(varchar(20), datediff(ms, @timer, getdate()))

END


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_MessageType_report] TO PUBLIC
    AS [dbo];

