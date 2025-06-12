-- drop proc sp_COR_web_biennial_list_by_bucket
go

CREATE PROC sp_COR_web_biennial_list_by_bucket (
	@web_userid			varchar(100)
	, @generator_id_list	varchar(max)=''
	, @receipt_start_date	datetime
	, @receipt_end_date	datetime
	, @report_level		char(1)	-- 'S'ummary or 'D'etail
	, @customer_id_list varchar(max)=''  /* Added 2019-07-17 by AA */ 
) AS
/* ********************************************************************
sp_COR_web_biennial_list_by_bucket
	Customer Service designated "biennial" report for web users.
	Not necessarily a REAL "biennial" report, but similar info.

IMPORANT:
	This "fancy" version of the COR Biennial report uses
	ContactCORBiennialBucket access -- a bucket table built specifically to allow orig_customer_id
	access to receipts via the profiles used on them - including access
	they would not have directly by the receipt customer_id, but WOULD have
	if you allowed access via profile.customer_id or profile.orig_customer_id.
	The original "strict" version is saved as sp_COR_web_biennial_list_by_access

History
	08/02/2013 JPB	Created
	01/10/2014 JPB	Modified per discussion with CS about weight methods & labels.
	02/26/2018 JPB	GEM-48410: Modified to use standard functions for weight/description
					Modified with accurate filter against voided receipt lines
	10/03/2019 MPM  DevOps 11619: Added logic to filter the result set
					using optional input parameter @customer_id_list.
	03/31/2020 JPB	This version does access differently- it grants you access to receipts
					based on your access to the profiles used on them.
Samples
SELECT  * FROM  receipt WHERE profile_id = 491824 and receipt_date between '1/1/2017' and '12/31/2017 23:59'

SELECT  *  FROM    contact WHERE web_userid like '%amand%'
SELECT  *  FROM    contactxref WHERE contact_id = 214923

sp_COR_web_biennial_list_by_bucket -- 2m, 21s, 91526 rows
--	sp_COR_web_biennial_list		-- 0s, 118 rows
	@web_userid			= 'amanda.kalinka'
	, @generator_id_list	= ''
	, @customer_id_list = ''
	, @receipt_start_date	= '1/1/2019'
	, @receipt_end_date		= '12/31/2020'
	, @report_level		= 'S'


sp_COR_web_biennial_list_by_bucket -- 2m, 21s, 91526 rows
--	sp_COR_web_biennial_list 
	@web_userid			= 'zachery.wright'
	, @generator_id_list	= '132462'
	, @receipt_start_date	= '1/1/2018'
	, @receipt_end_date		= '1/1/2021'
	, @report_level		= 'D'

sp_COR_web_biennial_list_by_bucket 
	@web_userid			= 'thames'
	, @generator_id_list	= ''
	, @receipt_start_date	= '1/1/2018'
	, @receipt_end_date		= '10/07/2019'
	, @report_level		= 'D'	
	, @customer_id_list = ''

sp_COR_web_biennial_list_by_bucket 
	@web_userid			= 'thames'
	, @generator_id_list	= '137729'
	, @receipt_start_date	= '1/1/2018'
	, @receipt_end_date		= '10/07/2019'
	, @report_level		= 'D'	
	, @customer_id_list = '14164'

sp_COR_web_biennial_list_by_bucket 
	@web_userid			= 'thames'
	, @generator_id_list	= ''
	, @receipt_start_date	= '1/1/2018'
	, @receipt_end_date		= '10/07/2019'
	, @report_level		= 'D'	
	, @customer_id_list = '14164'

sp_COR_web_biennial_list_by_bucket 
	@web_userid			= 'thames'
	, @generator_id_list	= '137729'
	, @receipt_start_date	= '1/1/2018'
	, @receipt_end_date		= '10/07/2019'
	, @report_level		= 'D'	
	, @customer_id_list = ''

select generator_id from customergenerator where customer_id = 888880
union
select generator_id from profile where customer_id = 888880

SELECT  *  FROM    generator where generator_name = 'AMAZON DMO1'	
******************************************************************** */
/*
-- Debuggging
declare
	@web_userid			varchar(100) = 'amanda.kalinka'
	, @customer_id_list varchar(max)=''  
	, @generator_id_list	varchar(max)=''
	, @receipt_start_date	datetime = '1/1/2018'
	, @receipt_end_date	datetime = '3/30/2020'
	, @report_level		char(1)	= 'D' -- 'S'ummary or 'D'etail
*/

declare
	@i_web_userid			varchar(100)	= isnull(@web_userid, '')
	, @i_generator_id_list	varchar(max)	= isnull(@generator_id_list, '')
    , @i_customer_id_list	varchar(max)	= isnull(@customer_id_list, '')
	, @i_date_start			datetime		= convert(date, @receipt_start_date)
	, @i_date_end			datetime		= convert(date, @receipt_end_date)
	, @i_report_level		char(1)			= isnull(@report_level, 'S')
	, @i_contact_id			int
	
select top 1 @i_contact_id = contact_id from CORcontact where web_userid = @i_web_userid

if isnull(@i_date_start, '1/1/1999') = '1/1/1999' set @i_date_start = dateadd(m, -3, getdate())
if isnull(@i_date_end, '1/1/1999') = '1/1/1999' set @i_date_end = getdate()
if datepart(hh, @i_date_end) = 0 set @i_date_end = @i_date_end + 0.99999


-- Input Handling:
---------------------
declare @generator table ( generator_id	bigint )

insert @generator ( generator_id ) 
select 
	convert(bigint, row) 
from 
	dbo.fn_SplitXSVText(',', 1, @i_generator_id_list) 
where 
	row is not null

declare @customer table ( customer_id	bigint )

insert @customer ( customer_id ) 
select 
	convert(bigint, row) 
from 
	dbo.fn_SplitXSVText(',', 1, @i_customer_id_list) 
where 
	row is not null

-- Access Filtering:
-----------------------
declare @foo table (
		receipt_id	int NOT NULL,
		company_id	int NOT NULL,
		profit_ctr_id  int NOT NULL,
		customer_id int,
		orig_customer_id int,
		generator_id int,
		_date datetime NULL
	)

insert @foo
select
	receipt_id
	, company_id
	, profit_ctr_id
	, customer_id
	, orig_customer_id
	, generator_id
	, isnull(pickup_date, receipt_date) _date
from ContactCORBiennialBucket x
where contact_id = @i_contact_id
	and isnull(x.pickup_date, x.receipt_date) between @i_date_start and @i_date_end
	and (
		@i_customer_id_list = ''
		or
		(x.customer_id in (select customer_id from @customer)
		or
		x.orig_customer_id in (select customer_id from @customer)
		)
	)
	and (
		@i_generator_id_list = ''
		or
		x.generator_id in (select generator_id from @generator)
	)



if object_id('tempdb..#BiennialData') is not null drop table #BiennialData

-- Querying:
--------------
-- Always do this.  It's either the exact details needed, or source for the summary:
SELECT
	-- report fields
	g.Generator_Name
	, g.epa_id as Generator_EPA_ID
	, r.Profile_ID
	, r.Approval_Code 
	, p.Approval_Desc as Waste_Description
	, pc.profit_ctr_name as Facility_Name
	, pc.epa_id as Facility_EPA_ID
	, r.Receipt_Date
	, r.Manifest
	, r.Manifest_Line
	, convert(varchar(max), null) as Federal_Waste_Codes-- dbo.fn_receipt_waste_code_list_long(r.company_id, r.profit_ctr_id, r.receipt_id, r.line_id) as Federal_Waste_Codes
	, convert(varchar(max), null) as State_Waste_Codes-- dbo.fn_csbiennial_waste_code_list_state_long(r.company_id, r.profit_ctr_id, r.receipt_id, r.line_id) as State_Waste_Codes
	, convert(varchar(20), null) as Haz_Flag 
	/* case when exists (
		select 1 from receiptwastecode rwc (nolock) inner join wastecode wc (nolock) on rwc.waste_code_uid = wc.waste_code_uid
		where rwc.receipt_id = r.receipt_id and rwc.line_id = r.line_id and rwc.company_id = r.company_id and rwc.profit_ctr_id = r.profit_ctr_id
		and wc.waste_code_origin = 'F' and wc.haz_flag = 'T'
		) 
		then 'Hazardous' else 'Non-Hazardous' end as Haz_Flag
	*/
	, p.EPA_Source_Code
	, p.EPA_Form_Code
	, th.Management_Code
	/*
	, COALESCE
		(
			-- 1.	Container weight (Inbound reporting only)
			CASE WHEN ISNULL(c.container_weight, 0) > 0 THEN convert(float, ISNULL(c.container_weight, 0) * (IsNull(cd.container_percent, 0) / 100.000)) END,
			-- 2.	Line Weight
			CASE WHEN ISNULL(r.line_weight, 0) > 0 THEN (r.line_weight / r.container_count) * (IsNull(cd.container_percent, 0) / 100.000) END,
			-- 3.	Manifested in LBS or TONS
			CASE WHEN r.manifest_unit = 'P' THEN convert(float, (r.manifest_quantity / r.container_count) * (IsNull(cd.container_percent, 0) / 100.000)) END,
			CASE WHEN r.manifest_unit = 'T' THEN convert(float, ((r.manifest_quantity * 2000.0) / r.container_count) * (IsNull(cd.container_percent, 0) / 100.000)) END,
			-- 4.	Manifested Unit (not lbs/tons) Converted to pounds
			CASE WHEN r.manifest_unit in (select manifest_unit from billunit where isnull(manifest_unit, '') not in ('P', 'T', '')) THEN convert(float, ((r.manifest_quantity * (select pound_conv from billunit where isnull(manifest_unit, '') = r.manifest_unit)) / r.container_count) * (IsNull(cd.container_percent, 0) / 100.000)) END,
			-- 5.	Billed Unit (not lbs/tons) converted to pounds
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
				GROUP BY rp.bill_unit_code
			) / r.container_count) * (IsNull(cd.container_percent, 0) / 100.000) END,
			-- If all else fails... zero
			0
			) as Total_Weight
	*/			
	, convert( DECIMAL(18,4), null) as Total_Weight -- dbo.fn_receipt_weight_line(r.receipt_id, r.line_id, r.profit_ctr_id, r.company_id) as Total_Weight
	/*
	, COALESCE
		(
			-- 1.	Container weight (Inbound reporting only)
			CASE WHEN ISNULL(c.container_weight, 0) > 0 THEN 'Reported' END,
			-- 2.	Line Weight
			CASE WHEN ISNULL(r.line_weight, 0) > 0 THEN 'Reported' END,
			-- 3.	Manifested in LBS or TONS
			CASE WHEN r.manifest_unit = 'P' THEN 'Manifested' END,
			CASE WHEN r.manifest_unit = 'T' THEN 'Manifested' END,
			-- 4.	Manifested Unit (not lbs/tons) Converted to pounds
			CASE WHEN r.manifest_unit in (select manifest_unit from billunit where isnull(manifest_unit, '') not in ('P', 'T', '')) THEN 'Calculated' END,
			-- 5.	Billed Unit (not lbs/tons) converted to pounds
			CASE WHEN EXISTS (SELECT 1 FROM ReceiptPrice rp (nolock)
				WHERE r.receipt_id = rp.receipt_id
				AND r.company_id = rp.company_id
				AND r.profit_ctr_id = rp.profit_ctr_id
				AND r.line_id = rp.line_id
				AND rp.bill_unit_code in (select bill_unit_code from billunit where isnull(pound_conv, 0) <> 0 and bill_unit_code not in ('LBS', 'TON', ''))
			) THEN 'Calculated' END,
			-- If all else fails... zero
			'Unknown'
		) as Weight_Method
	*/
	, convert(varchar(40), null) as Weight_Method --dbo.fn_receipt_weight_line_description(r.receipt_id, r.line_id, r.profit_ctr_id, r.company_id, 0) as Weight_Method
	, convert(varchar(1000), null) as Note

	-- key fields necessary to address lines
	, r.company_id
	, r.profit_ctr_id
	, r.receipt_id
	, r.line_id
	
	-- data that got you access here
	, a.customer_id
	, a.orig_customer_id
	, a.generator_id
	, a._date as pickup_date
	
INTO #BiennialData
FROM @foo a
inner join receipt r (nolock) 
	on a.receipt_id = r.receipt_id 
	and a.company_id = r.company_id 
	and a.profit_ctr_id = r.profit_ctr_id
inner join profile p (nolock)
	on r.profile_id = p.profile_id
inner join ProfileQuoteApproval pqa (nolock)
	on r.profile_id = pqa.profile_id 
	and r.company_id = pqa.company_id 
	and r.profit_ctr_id = pqa.profit_ctr_id
inner join generator g (nolock)
	on r.generator_id = g.generator_id
inner join profitcenter pc (nolock)
	on r.company_id = pc.company_id 
	and r.profit_ctr_id = pc.profit_ctr_id
inner join treatmentheader th (nolock)
	on pqa.treatment_id = th.treatment_id
WHERE 1=1
		AND r.trans_mode = 'I'
		AND r.trans_type = 'D'
		AND r.receipt_status = 'A'
		AND r.fingerpr_status = 'A'
		-- AND r.data_complete_flag = 'T'
		AND r.manifest_flag <> 'B'

---SELECT  *  FROM    contact WHERE web_userid = 'amanda.kalinka'


-- SELECT  *  FROM    #BiennialData
-- update #BiennialData set total_weight= null, weight_method = null

update #BiennialData
set Total_Weight = q_total
, Weight_Method = 'Reported'
from #BiennialData y
join
(
	select
	z.receipt_id
	, z.line_id
	, z.company_id
	, z.profit_ctr_id
	, sum( isnull(c.container_weight, 0) * (IsNull(cd.container_percent, 0) / 100.000) ) q_total
	from #BiennialData z
	inner join container c (nolock)
		on z.receipt_id = c.receipt_id
		and z.line_id = c.line_id
		and z.company_id = c.company_id
		and z.profit_ctr_id = c.profit_ctr_id
	inner join containerdestination cd (nolock)
		on c.receipt_id = cd.receipt_id
		and c.line_id = cd.line_id
		and c.container_id = cd.container_id
		and c.company_id = cd.company_id
		and c.profit_ctr_id = cd.profit_ctr_id
	where z.Total_Weight is null
		AND NOT EXISTS (
			-- You MUST make sure there's no containers for this line 
			--- with an unrecorded/zero weight, or this section returns bad data
			select top 1 1 
			from container c1 (nolock)
			where 
				c1.receipt_id = c.receipt_id
				and c1.line_id = c.line_id
				and c1.company_id = c.company_id
				and c1.profit_ctr_id = c.profit_ctr_id
				and isnull(c1.container_weight, 0) = 0
		)
	GROUP BY 
	z.receipt_id
	, z.line_id
	, z.company_id
	, z.profit_ctr_id
	having sum( isnull(c.container_weight, 0) * (IsNull(cd.container_percent, 0) / 100.000) ) > 0
) q
		on y.receipt_id = q.receipt_id
		and y.line_id = q.line_id
		and y.company_id = q.company_id
		and y.profit_ctr_id = q.profit_ctr_id
where y.total_weight is null

update #BiennialData
set Total_Weight = isnull(r.line_weight, 0)
, Weight_Method = 'Reported'
from #BiennialData y
join receipt r (nolock) 
	on
		r.receipt_id = y.receipt_id
		and r.line_id = y.line_id
		and r.profit_ctr_id = y.profit_ctr_id
		and r.company_id = y.company_id
		and isnull(r.line_weight, 0) > 0
where Total_Weight is null

update #BiennialData
set Total_Weight = 
		CASE WHEN r.manifest_unit = 'P' then convert(float, (r.manifest_quantity) ) -- pounds
		else convert(float, ((r.manifest_quantity * 2000.0) ) ) -- tons
		end
, Weight_Method = 'Manifested'
from #BiennialData y
join receipt r (nolock) 
	on
		r.receipt_id = y.receipt_id
		and r.line_id = y.line_id
		and r.profit_ctr_id = y.profit_ctr_id
		and r.company_id = y.company_id
		and r.manifest_unit IN ('T', 'P')
where Total_Weight is null

update #BiennialData
set Total_Weight = 
		convert(float, ((r.manifest_quantity * (
				select 
				case when isnull(pl.specific_gravity, 0) <> 0 then
					pound_conv * pl.specific_gravity 
				else 
					pound_conv 
				end 
				from billunit where isnull(manifest_unit, '') = r.manifest_unit
				/*
				select pound_conv from billunit where isnull(manifest_unit, '') = r.manifest_unit
				*/
				)) ) )
, Weight_Method = 'Calculated'
from #BiennialData y
join receipt r (nolock) 
	on
		r.receipt_id = y.receipt_id
		and r.line_id = y.line_id
		and r.profit_ctr_id = y.profit_ctr_id
		and r.company_id = y.company_id
		and r.manifest_unit in (select manifest_unit from billunit where isnull(manifest_unit, '') not in ('P', 'T', '')) 
	LEFT JOIN ProfileLab pl
		on r.profile_id = pl.profile_id
	and pl.type = 'A'
where Total_Weight is null

update #BiennialData
set Total_Weight = q.q_total
, Weight_Method = 'Calculated'
from #BiennialData y
join 
(
	select
	z.receipt_id
	, z.line_id
	, z.company_id
	, z.profit_ctr_id
	, SUM(bill_quantity * bu.pound_conv) q_total
	from #BiennialData z
	inner join ReceiptPrice rp (nolock)
	on rp.receipt_id = z.receipt_id
		and rp.line_id = z.line_id
		and rp.profit_ctr_id = z.profit_ctr_id
		and rp.company_id = z.company_id
		AND rp.bill_unit_code in (select bill_unit_code from billunit where isnull(pound_conv, 0) <> 0 and bill_unit_code not in ('LBS', 'TON', ''))
	INNER JOIN BillUnit bu (nolock) on rp.bill_unit_code = bu.bill_unit_code 
		and isnull(bu.pound_conv, 0) <> 0 
		and bu.bill_unit_code not in ('LBS', 'TON', '')
	where z.Total_Weight is null
	GROUP BY 
	z.receipt_id
	, z.line_id
	, z.company_id
	, z.profit_ctr_id
	having SUM(bill_quantity * bu.pound_conv) > 0
) q
		on y.receipt_id = q.receipt_id
		and y.line_id = q.line_id
		and y.company_id = q.company_id
		and y.profit_ctr_id = q.profit_ctr_id
where y.total_weight is null

update #BiennialData
set Total_Weight = 0
, Weight_Method = 'Failed to find weight'
WHERE total_weight is null

update #BiennialData
set Federal_Waste_Codes=
	 isnull(
	 ( select substring(
		(
		select ', ' + wc.display_name
		FROM    ReceiptWasteCode rwc (nolock)
		inner join WasteCode wc (nolock)
			on rwc.waste_code_uid = wc.waste_code_uid
		where rwc.receipt_id = y.receipt_id
		and rwc.line_id = y.line_id
		and rwc.company_id = y.company_id
		and rwc.profit_ctr_id = y.profit_ctr_id
		and wc.waste_code_origin = 'F'
		and wc.status= 'A'
		order by isnull(rwc.sequence_id, 1000), wc.display_name
		for xml path, TYPE).value('.[1]','nvarchar(max)'),2,20000)
	)
	, '')  
, State_Waste_Codes=
	 isnull(
	 ( select substring(
		(
		select ', ' + wc.display_name
		FROM    ReceiptWasteCode rwc (nolock)
		inner join WasteCode wc (nolock)
			on rwc.waste_code_uid = wc.waste_code_uid
		where rwc.receipt_id = y.receipt_id
		and rwc.line_id = y.line_id
		and rwc.company_id = y.company_id
		and rwc.profit_ctr_id = y.profit_ctr_id
		and wc.waste_code_origin = 'S'
		--and wc.status= 'A'
		order by isnull(rwc.sequence_id, 1000), wc.display_name
		for xml path, TYPE).value('.[1]','nvarchar(max)'),2,20000)
	)
	, '')  
, Haz_Flag =
	case when exists (
		select 1 from receiptwastecode rwc (nolock) inner join wastecode wc (nolock) on rwc.waste_code_uid = wc.waste_code_uid
		where rwc.receipt_id = y.receipt_id and rwc.line_id = y.line_id and rwc.company_id = y.company_id and rwc.profit_ctr_id = y.profit_ctr_id
		and wc.waste_code_origin = 'F' and wc.haz_flag = 'T'
		) 
		then 'Hazardous' else 'Non-Hazardous' end
from #BiennialData y


-- declare @i_contact_id int =214923
update #BiennialData
	set Note = 'Additional waste records for this generator exist but are not accessible via this report. Contact USE Customer Service for assistance.'
from #BiennialData
where generator_id in (
	SELECT  generator_id  FROM    #BiennialData
	where customer_id not in (
		select customer_id from ContactCORCustomerBucket
		where contact_id = @i_contact_id
	)
	and orig_customer_id not in (
		select customer_id from ContactCORCustomerBucket
		where contact_id = @i_contact_id
	)
)

-- declare @i_contact_id int =214923
delete from #BiennialData
where customer_id not in (
	select customer_id from ContactCORCustomerBucket
	where contact_id = @i_contact_id
)
and orig_customer_id not in (
	select customer_id from ContactCORCustomerBucket
	where contact_id = @i_contact_id
)

if @report_level = 'D' 
	select
		Generator_Name
		, Generator_EPA_ID
		, Profile_ID
		, Approval_Code
		, Waste_Description
		, Facility_Name
		, Facility_EPA_ID
		, Pickup_Date
		, Receipt_Date
		, Manifest
		, Manifest_Line
		, Federal_Waste_Codes
		, State_Waste_Codes
		, Haz_Flag as [Hazardous/Non-Hazardous]
		, EPA_Source_Code
		, EPA_Form_Code
		, Management_Code
		, sum(Total_Weight) as Total_Pounds
		, Weight_Method
		, Note

		-- data that got you access here
		, customer_id [DO NOT DISPLAY customer_id]
		, orig_customer_id [DO NOT DISPLAY orig_customer_id]
		, generator_id [DO NOT DISPLAY generator_id]
		
	from #BiennialData
	group by
		Generator_Name
		, Generator_EPA_ID
		, Profile_ID
		, Approval_Code
		, Waste_Description
		, Facility_Name
		, Facility_EPA_ID
		, Pickup_Date
		, Receipt_Date
		, Manifest
		, Manifest_Line
		, Federal_Waste_Codes
		, State_Waste_Codes
		, Haz_Flag
		, EPA_Source_Code
		, EPA_Form_Code
		, Management_Code
		, Weight_Method
		, Note
		-- data that got you access here
		, customer_id
		, orig_customer_id
		, generator_id
	order by
		Generator_Name
		, Generator_EPA_ID
		, Approval_Code
		, Waste_Description
		, Facility_Name
		, Facility_EPA_ID
		, Pickup_Date
		, Receipt_Date
		, Manifest
		, Manifest_Line
		, Haz_Flag
		, EPA_Source_Code
		, EPA_Form_Code
		, Management_Code
	
if @report_level = 'S'
	SELECT
		-- report fields
		Generator_Name
		, Generator_EPA_ID
		, Profile_ID
		, Approval_Code 
		, Waste_Description
		, Facility_Name
		, Facility_EPA_ID
		-- Summary: No Receipt_Date, Manifest, Manifest_Line
		, Federal_Waste_Codes
		, State_Waste_Codes
		, Haz_Flag as [Hazardous/Non-Hazardous]
		, EPA_Source_Code
		, EPA_Form_Code
		, Management_Code
		, SUM(Total_Weight) as Total_Pounds
		, Weight_Method
		, Note
	FROM #BiennialData
	GROUP BY
		Generator_Name
		, Generator_EPA_ID
		, Profile_ID
		, Approval_Code 
		, Waste_Description
		, Facility_Name
		, Facility_EPA_ID
		, Federal_Waste_Codes
		, State_Waste_Codes
		, Haz_Flag
		, EPA_Source_Code
		, EPA_Form_Code
		, Management_Code
		, Weight_Method
		, Note
	order by
		Generator_Name
		, Generator_EPA_ID
		, Approval_Code
		, Waste_Description
		, Facility_Name
		, Facility_EPA_ID
		, Haz_Flag
		, EPA_Source_Code
		, EPA_Form_Code
		, Management_Code

RETURN 0

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_COR_web_biennial_list_by_bucket] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_COR_web_biennial_list_by_bucket] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_COR_web_biennial_list_by_bucket] TO [EQAI]
    AS [dbo];

