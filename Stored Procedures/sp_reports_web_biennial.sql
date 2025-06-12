
CREATE PROC sp_reports_web_biennial (
	@generator_id_list	varchar(max),
	@receipt_start_date	datetime,
	@receipt_end_date	datetime,
	@report_level		char(1),	-- 'S'ummary or 'D'etail
	@contact_id			int,		-- -1 for Associates
	@customer_id_list	varchar(max) = ''-- Comma Separated Customer ID List - what customers to include  

) AS
/* ********************************************************************
sp_reports_web_biennial
	Customer Service designated "biennial" report for web users.
	Not necessarily a REAL "biennial" report, but similar info.

History
	08/02/2013 JPB	Created
	01/10/2014 JPB	Modified per discussion with CS about weight methods & labels.
	02/26/2018 JPB	GEM-48410: Modified to use standard functions for weight/description
					Modified with accurate filter against voided receipt lines
	02/18/2021 JPB	DO:19233 bugfix - add default value to @customer_id_list input
	05/25/2023 JPB  DO:30174 - Modified code to get MANAGEMENT_CODE from Treatment View instead of TreatmentHeader (Comments added by Dipankar)

Samples
SELECT  * FROM  receipt WHERE profile_id = 491824 and receipt_date between '1/1/2017' and '12/31/2017 23:59'

-- Associate:
	sp_reports_web_biennial ',38452,,64089,,63644,', '1/1/1990', '7/31/2014', 'D', -1 
	sp_reports_web_biennial '19732', '1/1/2017', '12/31/2017', 'D', -1 

-- Contact:
	sp_reports_web_biennial '0, 89258, 89259, 89260, 89261, 89262, 89263, 89264, 89265, 89266, 89267, 89268, 89269, 89270, 89271, 89273, 89274, 89275, 89276, 89277, 89278, 89279, 89280, 89281, 89282, 89283, 89284, 89285, 89286, 89287, 89288, 89289, 89290, 89
291, 89292, 89293, 89294, 89295, 89296, 116758, 116760', '1/1/1990', '7/31/2014', 'D', 10913
	sp_reports_web_biennial '64089', '1/1/2001', '7/31/2013', 'S', 100913

select generator_id from customergenerator where customer_id = 888880
union
select generator_id from profile where customer_id = 888880
	
******************************************************************** */

-- Input Handling:
---------------------
create table #generator ( generator_id	int )

insert #generator ( generator_id ) 
select 
	convert(int, row) 
from 
	dbo.fn_SplitXSVText(',', 1, @generator_id_list) 
where 
	row is not null

if datepart(hh, @receipt_end_date) = 0 set @receipt_end_date = @receipt_end_date + 0.99999

-- Access Filtering:
-----------------------
create table #accessfilter (
	receipt_id		int,
	company_id		int,
	profit_ctr_id	int
)

if @contact_id > 0
	insert #accessfilter ( receipt_id, company_id, profit_ctr_id )
	select r.receipt_id, r.company_id, r.profit_ctr_id
	from receipt r (nolock) inner join contactxref x (nolock)
		on r.customer_id = x.customer_id and x.type = 'C'
	inner join #generator g on r.generator_id = g.generator_id
	where x.contact_id = @contact_id and x.status = 'A' and x.web_access = 'A'
	and r.receipt_status in ('U', 'A') and r.waste_accepted_flag = 'T' and r.trans_mode = 'I'
	and r.receipt_date between @receipt_start_date and @receipt_end_date
	union
	select r.receipt_id, r.company_id, r.profit_ctr_id
	from receipt r (nolock) inner join contactxref x (nolock)
		on r.generator_id = x.generator_id and x.type = 'G'
	inner join #generator g on r.generator_id = g.generator_id
	where x.contact_id = @contact_id and x.status = 'A' and x.web_access = 'A'
	and r.receipt_status in ('U', 'A') and r.waste_accepted_flag = 'T' and r.trans_mode = 'I'
	and r.receipt_date between @receipt_start_date and @receipt_end_date
	union
	select r.receipt_id, r.company_id, r.profit_ctr_id
	from receipt r (nolock) inner join customergenerator cg (nolock)
		on r.generator_id = cg.generator_id
	inner join contactxref x (nolock)
		on cg.customer_id = x.customer_id and x.type = 'C'
	inner join #generator g on r.generator_id = g.generator_id
	where x.contact_id = @contact_id and x.status = 'A' and x.web_access = 'A'
	and r.receipt_status in ('U', 'A') and r.waste_accepted_flag = 'T' and r.trans_mode = 'I'
	and r.receipt_date between @receipt_start_date and @receipt_end_date
else
	insert #accessfilter ( receipt_id, company_id, profit_ctr_id )
	select distinct r.receipt_id, r.company_id, r.profit_ctr_id
	from receipt r (nolock)	inner join #generator g on r.generator_id = g.generator_id
	where r.receipt_status in ('U', 'A') and r.waste_accepted_flag = 'T' and r.trans_mode = 'I'
	and r.receipt_date between @receipt_start_date and @receipt_end_date

-- Access Verification:
-------------------------
	if (select count(*) from #accessfilter) = 0 RETURN
	
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
	, dbo.fn_receipt_waste_code_list_long(r.company_id, r.profit_ctr_id, r.receipt_id, r.line_id) as Federal_Waste_Codes
	, dbo.fn_csbiennial_waste_code_list_state_long(r.company_id, r.profit_ctr_id, r.receipt_id, r.line_id) as State_Waste_Codes
	, case when exists (
		select 1 from receiptwastecode rwc (nolock) inner join wastecode wc (nolock) on rwc.waste_code_uid = wc.waste_code_uid
		where rwc.receipt_id = r.receipt_id and rwc.line_id = r.line_id and rwc.company_id = r.company_id and rwc.profit_ctr_id = r.profit_ctr_id
		and wc.waste_code_origin = 'F' and wc.haz_flag = 'T'
		) 
		then 'Hazardous' else 'Non-Hazardous' end as Haz_Flag
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
	, dbo.fn_receipt_weight_line(r.receipt_id, r.line_id, r.profit_ctr_id, r.company_id) as Total_Weight
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
	, dbo.fn_receipt_weight_line_description(r.receipt_id, r.line_id, r.profit_ctr_id, r.company_id, 0) as Weight_Method

	-- key fields necessary to address lines
	, r.company_id
	, r.profit_ctr_id
	, r.receipt_id
	, r.line_id
	
INTO #BiennialData
FROM #accessfilter a
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
inner join treatmentdetail th (nolock)
	on pqa.treatment_id = th.treatment_id
	and pqa.company_id = th.company_id
	and pqa.profit_ctr_id = th.profit_ctr_id
WHERE 1=1
		AND r.trans_mode = 'I'
		AND r.trans_type = 'D'
		AND r.receipt_status = 'A'
		AND r.fingerpr_status = 'A'
		-- AND r.data_complete_flag = 'T' -- 2021-01-13 - phasing out this problematic field.
		AND r.manifest_flag <> 'B'
		
if @report_level = 'D' 
	select
		Generator_Name
		, Generator_EPA_ID
		, Profile_ID
		, Approval_Code
		, Waste_Description
		, Facility_Name
		, Facility_EPA_ID
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
	from #BiennialData
	group by
		Generator_Name
		, Generator_EPA_ID
		, Profile_ID
		, Approval_Code
		, Waste_Description
		, Facility_Name
		, Facility_EPA_ID
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
	order by
		Generator_Name
		, Generator_EPA_ID
		, Approval_Code
		, Waste_Description
		, Facility_Name
		, Facility_EPA_ID
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


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_reports_web_biennial] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_reports_web_biennial] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_reports_web_biennial] TO [EQAI]
    AS [dbo];

