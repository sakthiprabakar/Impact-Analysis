
create proc sp_target_disposal_extract_validation (
	@start_date		datetime
	,@end_date		datetime
	,@report_log_id int = NULL
) AS
/* ******************************************************************
sp_target_disposal_extract_validation

	Created to run the build process for Target, THEN perform validation on that info.
	
	Created to satisfy Target (12113) requirements for monthly data
	formatted to their spec.
	
	Similar to (orig copied from, then modified)
	L:\IT Apps\SQL\Special Manual Requests\Target\Extract SC, 4-1 - 5-31-2012\
	
History:
	2012-10-10	JPB	Created
	2014-08-22	JPB	GEM:-29706 - Modify Validations: ___ Not-Submitted only true if > $0
	
	
Samples:
	sp_target_disposal_extract_validation  '12/1/2013', '12/31/2013 23:59'

****************************************************************** */

SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

-- declare 	@start_date		datetime =  '1/1/2014'	,@end_date		datetime = '1/31/2014 23:59', @report_log_id int = null
declare @customer_id int = 12113


-- Fix/Set EndDate's time.
if isnull(@end_date,'') <> ''
	if datepart(hh, @end_date) = 0 set @end_date = @end_date + 0.99999

-- Define extract values:
DECLARE
    @extract_datetime       datetime,
    @usr                    nvarchar(256),
    @sp_name_args           varchar(1000),
    @timer					    datetime = getdate(),
    @steptimer				    datetime = getdate(),
    @debug                  int
SELECT
    @extract_datetime       = GETDATE(),
    @usr                    = UPPER(SUSER_SNAME()),
    @sp_name_args           = object_name(@@PROCID) + ' ''' + convert(varchar(20), @start_date) + ''', ''' + convert(varchar(20), @end_date) + '''',
    @debug                  = 1
    
if @report_log_id is not null and len(@usr) > 10
   select @usr = user_code from reportlog where report_log_id = @report_log_id

if @debug > 0 begin
   Print 'Extract started at ' + convert(varchar(40), @timer)
   PRINT 'Elapsed time is ' + convert(varchar(40), datediff(ms, @timer, getdate())) + 'ms'
   Print 'Current step elapsed time is ' + convert(varchar(40), datediff(ms, @steptimer, getdate())) + 'ms'
end
set @steptimer = getdate()


CREATE TABLE #TargetValidateCustomer (
	customer_id 	int
)
INSERT #TargetValidateCustomer values (@customer_id)


IF RIGHT(@usr, 3) = '(2)'
    SELECT @usr = LEFT(@usr,(LEN(@usr)-3))

if @debug > 0 begin
   print 'Run Setup Finished'
   PRINT 'Elapsed time is ' + convert(varchar(40), datediff(ms, @timer, getdate())) + 'ms'
   Print 'Current step elapsed time is ' + convert(varchar(40), datediff(ms, @steptimer, getdate())) + 'ms'
end
set @steptimer = getdate()
    

EXEC sp_target_disposal_extract_build 
	@start_date				
	,@end_date				
    ,@extract_datetime      
    ,@usr                   

if @debug > 0 begin
   print 'Build Run Finished'
   PRINT 'Elapsed time is ' + convert(varchar(40), datediff(ms, @timer, getdate())) + 'ms'
   Print 'Current step elapsed time is ' + convert(varchar(40), datediff(ms, @steptimer, getdate())) + 'ms'
end
set @steptimer = getdate()


/* *************************************************************

Validate Phase...

    Run the Validation every time, but may not be exported below...

    Look for blank transporter info
    Look for missing waste codes
    Look for 0 weight lines
    Look for blank service_date
    Look for blank Facility Number
    Look for blank Facility Type
    Look for un-submitted records that would've been included if they were submitted
    Look for count of D_ images
    Look for duplicate manifest/line combinations
    Look for missing dot descriptions
    Look for missing waste descriptions

************************************************************** */

-- Create list of missing transporter info
    INSERT EQ_Extract..TargetDisposalValidation
    SELECT  DISTINCT
    	'Missing Transporter Info' as Problem,
    	source_table,
    	Company_id,
    	Profit_ctr_id,
    	Receipt_id,
    	NULL,
    	@usr,
    	@extract_datetime
    FROM EQ_TEMP.dbo.TargetDisposalExtract (nolock) 
    WHERE 
    	ISNULL((select transporter_name from transporter (nolock) where transporter_code = EQ_TEMP.dbo.TargetDisposalExtract.transporter1_code), '') = ''
	    AND waste_desc <> 'No waste picked up'
	    AND added_by = @usr 
	    AND date_added = @extract_datetime
	    AND submitted_flag = 'T'
    	
if @debug > 0 begin
   print 'Validation: Missing Transporter Info, Finished'
   PRINT 'Elapsed time is ' + convert(varchar(40), datediff(ms, @timer, getdate())) + 'ms'
   Print 'Current step elapsed time is ' + convert(varchar(40), datediff(ms, @steptimer, getdate())) + 'ms'
end
set @steptimer = getdate()

-- Create list of Missing Waste Code
    INSERT EQ_Extract..TargetDisposalValidation
    SELECT DISTINCT
    	'Missing Waste Code',
    	source_table,
    	company_id,
    	profit_ctr_id,
    	receipt_id,
    	NULL,
    	@usr,
    	@extract_datetime
    from EQ_TEMP.dbo.TargetDisposalExtract e (nolock) 
    where
	    waste_desc <> 'No waste picked up'
	    and manifest_line is not null
	    and item_type in ('A', 'D', 'N')
	    AND added_by = @usr 
	    and date_added = @extract_datetime
	    AND submitted_flag = 'T'
	    and source_table = 'Workorder'
	    and coalesce(waste_code_1, waste_code_2, waste_code_3, waste_code_4, waste_code_5, waste_code_6, waste_code_7, waste_code_8, waste_code_9, waste_code_10, waste_code_11, waste_code_12, '') = ''
	    and coalesce(state_waste_code_1, state_waste_code_2, state_waste_code_3, state_waste_code_4, state_waste_code_5, '') = ''
	UNION ALL
    SELECT DISTINCT
    	'Missing Waste Code',
    	source_table,
    	company_id,
    	profit_ctr_id,
    	receipt_id,
    	NULL,
    	@usr,
    	@extract_datetime
    from EQ_TEMP.dbo.TargetDisposalExtract e (nolock) 
    where
	    waste_desc <> 'No waste picked up'
	    and manifest_line is not null
	    and item_type in ('A', 'D', 'N')
	    AND added_by = @usr 
	    and date_added = @extract_datetime
	    AND submitted_flag = 'T'
	    and source_table = 'Receipt'
	    and coalesce(waste_code_1, waste_code_2, waste_code_3, waste_code_4, waste_code_5, waste_code_6, waste_code_7, waste_code_8, waste_code_9, waste_code_10, waste_code_11, waste_code_12, '') = ''
	    and coalesce(state_waste_code_1, state_waste_code_2, state_waste_code_3, state_waste_code_4, state_waste_code_5, '') = ''

if @debug > 0 begin
   print 'Validation: Missing Waste Codes, Finished'
   PRINT 'Elapsed time is ' + convert(varchar(40), datediff(ms, @timer, getdate())) + 'ms'
   Print 'Current step elapsed time is ' + convert(varchar(40), datediff(ms, @steptimer, getdate())) + 'ms'
end
set @steptimer = getdate()

-- Create list of missing Weights
    INSERT EQ_Extract..TargetDisposalValidation
    SELECT DISTINCT
    	'Missing Weight',
    	source_table,
    	company_id,
    	profit_ctr_id,
    	receipt_id,
    	'line/seq: ' + convert(varchar(20), line_sequence_id),
    	@usr,
    	@extract_datetime
    from EQ_TEMP.dbo.TargetDisposalExtract (nolock) 
    where
    	isnull(pounds,0) = 0
	    AND waste_desc <> 'No waste picked up'
	    and manifest_line is not null
	    and item_type in ('A', 'D')
	    AND added_by = @usr 
	    and date_added = @extract_datetime
	    AND submitted_flag = 'T'

if @debug > 0 begin
   print 'Validation: Missing Weights, Finished'
   PRINT 'Elapsed time is ' + convert(varchar(40), datediff(ms, @timer, getdate())) + 'ms'
   Print 'Current step elapsed time is ' + convert(varchar(40), datediff(ms, @steptimer, getdate())) + 'ms'
end
set @steptimer = getdate()

-- Create list of missing Service Dates
    INSERT EQ_Extract..TargetDisposalValidation
    SELECT DISTINCT
    	'Missing Service Date',
    	source_table,
    	company_id,
    	profit_ctr_id,
    	receipt_id,
    	NULL,
    	@usr,
    	@extract_datetime
    from EQ_TEMP.dbo.TargetDisposalExtract (nolock) 
    where
    	isnull(service_date, '') = ''
	    AND added_by = @usr 
	    and date_added = @extract_datetime
	    AND submitted_flag = 'T'

if @debug > 0 begin
   print 'Validation: Missing Service Dates, Finished'
   PRINT 'Elapsed time is ' + convert(varchar(40), datediff(ms, @timer, getdate())) + 'ms'
   Print 'Current step elapsed time is ' + convert(varchar(40), datediff(ms, @steptimer, getdate())) + 'ms'
end
set @steptimer = getdate()

-- Create list of receipts missing workorders
    INSERT EQ_Extract..TargetDisposalValidation
    SELECT DISTINCT
    	'Receipt missing Workorder',
    	source_table,
    	company_id,
    	profit_ctr_id,
    	receipt_id,
    	NULL,
    	@usr,
    	@extract_datetime
    from EQ_TEMP.dbo.TargetDisposalExtract (nolock) 
    WHERE
		source_table = 'receipt'
    	AND isnull(receipt_workorder_id, '') = ''
	    AND added_by = @usr 
	    and date_added = @extract_datetime
	    AND submitted_flag = 'T'

if @debug > 0 begin
   print 'Validation: Receipts Missing Workorders, Finished'
   PRINT 'Elapsed time is ' + convert(varchar(40), datediff(ms, @timer, getdate())) + 'ms'
   Print 'Current step elapsed time is ' + convert(varchar(40), datediff(ms, @steptimer, getdate())) + 'ms'
end
set @steptimer = getdate()

-- Create list of missing site codes
    INSERT EQ_Extract..TargetDisposalValidation
     SELECT DISTINCT
    	'Missing Generator Site Code',
    	source_table,
    	company_id,
    	profit_ctr_id,
    	receipt_id,
    	NULL,
    	@usr,
    	@extract_datetime
    from EQ_TEMP.dbo.TargetDisposalExtract (nolock) 
    where
    	site_code = ''
	    AND added_by = @usr 
	    and date_added = @extract_datetime
	    AND submitted_flag = 'T'

if @debug > 0 begin
   print 'Validation: Missing Site Codes, Finished'
   PRINT 'Elapsed time is ' + convert(varchar(40), datediff(ms, @timer, getdate())) + 'ms'
   Print 'Current step elapsed time is ' + convert(varchar(40), datediff(ms, @steptimer, getdate())) + 'ms'
end
set @steptimer = getdate()

-- Create list of missing site type
    INSERT EQ_Extract..TargetDisposalValidation
     SELECT DISTINCT
    	'Missing Generator Site Type',
    	source_table,
    	company_id,
    	profit_ctr_id,
    	receipt_id,
    	NULL,
    	@usr,
    	@extract_datetime
    from EQ_TEMP.dbo.TargetDisposalExtract (nolock) 
    where
    	isnull(site_type, '') = ''
	    AND added_by = @usr 
	    and date_added = @extract_datetime
	    AND submitted_flag = 'T'

if @debug > 0 begin
   print 'Validation: Missing Site Types, Finished'
   PRINT 'Elapsed time is ' + convert(varchar(40), datediff(ms, @timer, getdate())) + 'ms'
   Print 'Current step elapsed time is ' + convert(varchar(40), datediff(ms, @steptimer, getdate())) + 'ms'
end
set @steptimer = getdate()

-- Create list of unsubmitted receipts
    INSERT EQ_Extract..TargetDisposalValidation
     SELECT DISTINCT
    	'Receipt Not Submitted',
    	source_table,
    	company_id,
    	profit_ctr_id,
    	receipt_id,
    	NULL,
    	@usr,
    	@extract_datetime
    from EQ_TEMP.dbo.TargetDisposalExtract t (nolock) 
    where
		source_table = 'Receipt'
	    AND added_by = @usr 
	    and date_added = @extract_datetime
	    AND submitted_flag = 'F'
	    and 0 < (
			select sum(
				case when isnull(rp.total_extended_amt, 0) > 0 
					then isnull(rp.total_extended_amt, 0)
					else 
						case when isnull(rp.total_extended_amt, 0) = 0 and rp.print_on_invoice_flag = 'T' 
							then 1 
							else isnull(rp.total_extended_amt, 0)
						end 
				end
			)
			from receiptprice rp (nolock)
			where rp.receipt_id = t.receipt_id
			and rp.company_id = t.company_id
			and rp.profit_ctr_id = t.profit_ctr_id
	    )

if @debug > 0 begin
   print 'Validation: Unsubmitted Receipts, Finished'
   PRINT 'Elapsed time is ' + convert(varchar(40), datediff(ms, @timer, getdate())) + 'ms'
   Print 'Current step elapsed time is ' + convert(varchar(40), datediff(ms, @steptimer, getdate())) + 'ms'
end
set @steptimer = getdate()

-- Create list of unsubmitted workorders
    INSERT EQ_Extract..TargetDisposalValidation
     SELECT DISTINCT
    	'Workorder Not Submitted',
    	source_table,
    	company_id,
    	profit_ctr_id,
    	receipt_id,
    	NULL,
    	@usr,
    	@extract_datetime
    from EQ_TEMP.dbo.TargetDisposalExtract t (nolock) 
    where
		source_table like 'Workorder%'
	    AND added_by = @usr 
	    and date_added = @extract_datetime
	    AND submitted_flag = 'F'
	    and 0 < (
			select sum(isnull(wh.total_price, 0))
			from workorderheader wh (nolock)
			where wh.workorder_id = t.receipt_id
			and wh.company_id = t.company_id
			and wh.profit_ctr_id = t.profit_ctr_id
	    )
	    
if @debug > 0 begin
   print 'Validation: Unsubmitted Workorders, Finished'
   PRINT 'Elapsed time is ' + convert(varchar(40), datediff(ms, @timer, getdate())) + 'ms'
   Print 'Current step elapsed time is ' + convert(varchar(40), datediff(ms, @steptimer, getdate())) + 'ms'
end
set @steptimer = getdate()


if @debug > 0 begin
   print 'Validation: Missing Scans, Finished'
   PRINT 'Elapsed time is ' + convert(varchar(40), datediff(ms, @timer, getdate())) + 'ms'
   Print 'Current step elapsed time is ' + convert(varchar(40), datediff(ms, @steptimer, getdate())) + 'ms'
end
set @steptimer = getdate()

-- Create count of receipt-based records in extract
    INSERT EQ_Extract..TargetDisposalValidation
     SELECT
    	' Count of Receipt-based records',
    	null,
    	null,
    	null,
    	null,
    	convert(varchar(20), count(*)),
    	@usr,
    	@extract_datetime
    from EQ_TEMP.dbo.TargetDisposalExtract (nolock) 
    where
		source_table ='Receipt'
	    AND added_by = @usr 
	    and date_added = @extract_datetime
	    AND submitted_flag = 'T'

if @debug > 0 begin
   print 'Validation: Receipt Record Count, Finished'
   PRINT 'Elapsed time is ' + convert(varchar(40), datediff(ms, @timer, getdate())) + 'ms'
   Print 'Current step elapsed time is ' + convert(varchar(40), datediff(ms, @steptimer, getdate())) + 'ms'
end
set @steptimer = getdate()

-- Create count of workorder -based records in extract
    INSERT EQ_Extract..TargetDisposalValidation
     SELECT 
    	' Count of Workorder-based records',
    	null,
    	null,
    	null,
    	null,
    	convert(varchar(20), count(*)),
    	@usr,
    	@extract_datetime
    from EQ_TEMP.dbo.TargetDisposalExtract (nolock) 
    where
		source_table ='Workorder'
    	AND waste_desc <> 'No waste picked up'
	    AND added_by = @usr 
	    and date_added = @extract_datetime
	    AND submitted_flag = 'T'

if @debug > 0 begin
   print 'Validation: Workorder Record Count, Finished'
   PRINT 'Elapsed time is ' + convert(varchar(40), datediff(ms, @timer, getdate())) + 'ms'
   Print 'Current step elapsed time is ' + convert(varchar(40), datediff(ms, @steptimer, getdate())) + 'ms'
end
set @steptimer = getdate()

-- Create count of NWP -based records in extract
    INSERT EQ_Extract..TargetDisposalValidation
     SELECT 
    	' Count of No Waste Pickup records',
    	null,
    	null,
    	null,
    	null,
    	convert(varchar(20), count(*)),
    	@usr,
    	@extract_datetime
    from EQ_TEMP.dbo.TargetDisposalExtract (nolock) 
    where
		source_table ='Workorder'
    	AND waste_desc = 'No waste picked up'
	    AND added_by = @usr 
	    and date_added = @extract_datetime
	    AND submitted_flag = 'T'

if @debug > 0 begin
   print 'Validation: No Waste Pickup Record Count, Finished'
   PRINT 'Elapsed time is ' + convert(varchar(40), datediff(ms, @timer, getdate())) + 'ms'
   Print 'Current step elapsed time is ' + convert(varchar(40), datediff(ms, @steptimer, getdate())) + 'ms'
end
set @steptimer = getdate()

-- Create list of unusually high number of manifest names
    INSERT EQ_Extract..TargetDisposalValidation
     SELECT
    	'High Number of same manifest-line',
    	null,
    	null,
    	null,
    	null,
    	CONVERT(varchar(20), count(*)) + ' times: ' + isnull(manifest, '') + ' line ' + isnull(CONVERT(varchar(10), Manifest_Line), ''),
    	@usr,
    	@extract_datetime
    from EQ_TEMP.dbo.TargetDisposalExtract (nolock) 
    where
    	waste_desc <> 'No waste picked up'
    	AND bill_unit_desc not like '%cylinder%'
	    AND added_by = @usr 
	    and date_added = @extract_datetime
	    AND submitted_flag = 'T'
	group by manifest, manifest_line
	having count(*) > 2

if @debug > 0 begin
   print 'Validation: Count high # of Manifest-Line combo, Finished'
   PRINT 'Elapsed time is ' + convert(varchar(40), datediff(ms, @timer, getdate())) + 'ms'
   Print 'Current step elapsed time is ' + convert(varchar(40), datediff(ms, @steptimer, getdate())) + 'ms'
end
set @steptimer = getdate()

-- Create list of missing dot descriptions
    INSERT EQ_Extract..TargetDisposalValidation
     SELECT DISTINCT
    	'Missing DOT Description',
    	source_table,
    	company_id,
    	profit_ctr_id,
    	receipt_id,
    	NULL,
    	@usr,
    	@extract_datetime
    from EQ_TEMP.dbo.TargetDisposalExtract (nolock) 
    where
	    added_by = @usr 
	    and date_added = @extract_datetime
	    AND submitted_flag = 'T'
        AND ISNULL(
            CASE WHEN EQ_TEMP.dbo.TargetDisposalExtract.tsdf_approval_id IS NOT NULL THEN
                dbo.fn_manifest_dot_description('T', EQ_TEMP.dbo.TargetDisposalExtract.tsdf_approval_id)
            ELSE
                CASE WHEN EQ_TEMP.dbo.TargetDisposalExtract.profile_id IS NOT NULL THEN
                    dbo.fn_manifest_dot_description('P', EQ_TEMP.dbo.TargetDisposalExtract.profile_id)
                ELSE
                    ''
                END
            END
        , '') = ''
	    and approval_or_resource not in ('STOPFEE', 'GASSUR%')
	    and waste_desc <> 'No waste picked up'


if @debug > 0 begin
   print 'Validation: Missing DOT Description, Finished'
   PRINT 'Elapsed time is ' + convert(varchar(40), datediff(ms, @timer, getdate())) + 'ms'
   Print 'Current step elapsed time is ' + convert(varchar(40), datediff(ms, @steptimer, getdate())) + 'ms'
end
set @steptimer = getdate()


-- Create list of missing bill units in extract
    INSERT EQ_Extract..TargetDisposalValidation
     SELECT 
    	'Missing Bill Unit',
    	source_table,
    	company_id,
    	profit_ctr_id,
    	receipt_id,
    	'line ' + convert(varchar(10), line_sequence_id),
    	@usr,
    	@extract_datetime
    from EQ_TEMP.dbo.TargetDisposalExtract (nolock) 
    where
		isnull(bill_unit_desc, '') = ''
		AND waste_desc <> 'No waste picked up'
	    AND added_by = @usr 
	    and date_added = @extract_datetime
	    AND submitted_flag = 'T'

if @debug > 0 begin
   print 'Validation: Missing Bill Unit Description, Finished'
   PRINT 'Elapsed time is ' + convert(varchar(40), datediff(ms, @timer, getdate())) + 'ms'
   Print 'Current step elapsed time is ' + convert(varchar(40), datediff(ms, @steptimer, getdate())) + 'ms'
end
set @steptimer = getdate()


-- Create list of missing waste descriptions
    INSERT EQ_Extract..TargetDisposalValidation
     SELECT DISTINCT
    	'Missing Waste Description',
    	source_table,
    	company_id,
    	profit_ctr_id,
    	receipt_id,
    	NULL,
    	@usr,
    	@extract_datetime
    from EQ_TEMP.dbo.TargetDisposalExtract (nolock) 
    where
    	waste_desc = ''
	    AND added_by = @usr 
	    AND date_added = @extract_datetime
	    AND submitted_flag = 'T'
	    and approval_or_resource not in ('STOPFEE', 'GASSUR%')
	    and waste_desc <> 'No waste picked up'

if @debug > 0 begin
   print 'Validation: Missing Waste Description, Finished'
   PRINT 'Elapsed time is ' + convert(varchar(40), datediff(ms, @timer, getdate())) + 'ms'
   Print 'Current step elapsed time is ' + convert(varchar(40), datediff(ms, @steptimer, getdate())) + 'ms'
end
set @steptimer = getdate()

-- Create list of blank waste code 1's
    INSERT EQ_Extract..TargetDisposalValidation
     SELECT DISTINCT
    	'Blank Waste Code 1',
    	source_table,
    	company_id,
    	profit_ctr_id,
    	receipt_id,
    	'line/seq: ' + convert(varchar(20), line_sequence_id),
    	@usr,
    	@extract_datetime
    from EQ_TEMP.dbo.TargetDisposalExtract (nolock) 
    where
    	ISNULL(waste_code_1, '') = ''
    	AND coalesce(waste_code_2, waste_code_3, waste_code_4, waste_code_5, waste_code_6, waste_code_7, waste_code_8, waste_code_9, waste_code_10, '') <> ''
	    AND added_by = @usr 
	    AND date_added = @extract_datetime
	    AND submitted_flag = 'T'
	    and waste_desc <> 'No waste picked up'

if @debug > 0 begin
   print 'Validation: Blank Waste Code 1, Finished'
   PRINT 'Elapsed time is ' + convert(varchar(40), datediff(ms, @timer, getdate())) + 'ms'
   Print 'Current step elapsed time is ' + convert(varchar(40), datediff(ms, @steptimer, getdate())) + 'ms'
end
set @steptimer = getdate()

-- Catch generators serviced that aren't in the extracts
    INSERT EQ_Extract..TargetDisposalValidation
     SELECT DISTINCT
    	'Site serviced, NOT in extract',
    	'Workorder',
    	woh.company_id,
    	woh.profit_ctr_id,
    	woh.workorder_id,
    	left(convert(varchar(20), woh.generator_id) + ' (' + isnull(g.site_code, 'Code?') + ' - ' + isnull(g.generator_city, 'city?') + ', ' + isnull(g.generator_state, 'ST?') + ')', 40),
    	@usr,
    	@extract_datetime
	FROM workorderheader woh (nolock)
	INNER JOIN billing b (nolock)
		on woh.workorder_id = b.receipt_id
		and woh.company_id = b.company_id
		and woh.profit_ctr_id = b.profit_ctr_id
		and b.status_code = 'I'
		and b.trans_source = 'W'
	INNER join TripHeader th (nolock) ON woh.trip_id = th.trip_id
	INNER JOIN generator g (nolock) on woh.generator_id = g.generator_id
	LEFT OUTER JOIN WorkOrderStop wos (nolock) ON wos.workorder_id = woh.workorder_id
		and wos.company_id = woh.company_id
		and wos.profit_ctr_id = woh.profit_ctr_id
		and wos.stop_sequence_id = 1 /* this will change in the future when there is more than 1 stop per workorder */
	WHERE th.trip_status IN ('D', 'C', 'A', 'U')
	AND woh.workorder_status <> 'V'
	AND (woh.customer_id IN (select customer_id from #TargetValidateCustomer) OR woh.generator_id in (select generator_id from CustomerGenerator (nolock) where customer_id IN (select customer_id from #TargetValidateCustomer)))
	AND coalesce(b.invoice_date, wos.date_act_arrive, woh.start_date) between @start_date and @end_date
	AND g.generator_id not in (
		select generator_id 
		from EQ_TEMP.dbo.TargetDisposalExtract  (nolock)
		where submitted_flag = 'T'
		AND added_by = @usr
		AND date_added = @extract_datetime
	)
    AND woh.billing_project_id not in (5486)


if @debug > 0 begin
   print 'Validation: Generators Serviced, but not in extracts, Finished'
   PRINT 'Elapsed time is ' + convert(varchar(40), datediff(ms, @timer, getdate())) + 'ms'
   Print 'Current step elapsed time is ' + convert(varchar(40), datediff(ms, @steptimer, getdate())) + 'ms'
end
set @steptimer = getdate()


/* *************************************************************
Populate Output tables from this run.
************************************************************* */

SELECT *
FROM EQ_Extract..TargetDisposalValidation
where 
	date_added = @extract_datetime 
	and added_by = @usr


print 'Return Run Information, Finished'
PRINT 'Elapsed time is ' + convert(varchar(40), datediff(ms, @timer, getdate())) + 'ms'
Print 'Current step elapsed time is ' + convert(varchar(40), datediff(ms, @steptimer, getdate())) + 'ms'
set @steptimer = getdate()


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_target_disposal_extract_validation] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_target_disposal_extract_validation] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_target_disposal_extract_validation] TO [EQAI]
    AS [dbo];

