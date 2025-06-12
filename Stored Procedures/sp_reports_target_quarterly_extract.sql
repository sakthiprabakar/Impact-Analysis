
create proc sp_reports_target_quarterly_extract (
	-- @customer_id		int	= 12113					-- Target specific
	@start_date		datetime						-- Typically quarterly, but I guess you could run for any date.
	, @end_date		datetime
	--- , @state_list	varchar(max) = 'ALL'		-- State list isn't used in this sql
)
as
/* ****************************************************************************
sp_reports_target_quarterly_extract

-- Target 2014-Q1 (OK, SC) Disposal Extract
-- According to Tracy we're not concerned at all with Workorder Disposal.
-- Beware if copying... Duplicating Line_Weight if there's more than 1 Billing Record.
-- Does not seem to happen in Targets dataset.
-- SK 01/10/2013 Modified to run for all states.

declare @customer_id int, @state_list varchar(max), @start_date datetime, @end_date datetime
select @customer_id = 12113, @state_list = 'ALL', @start_date = '01/01/2014 00:00', @end_date = '3/31/2014 23:59'

History
	4/22/2014	JPB	Created as an SP from the existing Extract script, which was nearly an SP,
					and substantially different in output that existing EQIP Target reports.

Sample:

sp_reports_target_quarterly_extract '3/1/2014', '3/31/2014'
	
**************************************************************************** */

set nocount on

-- Target specific:
declare @customer_id int = 12113

if DATEPART(hh, @end_date) = 0 set @end_date = @end_date + 0.99999

/*
create table #states (state_abbr	varchar(2))
if isnull(@state_list, '') IN ('', 'ALL', 'ANY')
	insert #states 
	select distinct 
	generator_state
	FROM    receipt r
	INNER JOIN Generator g on r.generator_id = g.generator_id
	where r.customer_id = @customer_id
	and r.receipt_date between @start_date and @end_date
else
	insert #states
	select row
	from dbo.fn_SplitXsvText(',', 1, @state_list)
	where ISNULL(row, '') <> ''
*/

set nocount off

	SELECT  -- top 1000
		CONVERT(Varchar(16), ISNULL(g.site_code, '')) as location_number,
		isnull(g.epa_id, '') as epa_id,
		isnull(r.manifest, '') as manifest,
		CASE WHEN trans_source = 'R' THEN
			CASE WHEN EXISTS (
					SELECT receipt_id 
					FROM BillingLinkLookup bll 
					WHERE bll.company_id = b.company_id
					AND bll.profit_ctr_id = b.profit_ctr_id
					AND bll.receipt_id = b.receipt_id
				) THEN (
					SELECT coalesce(rt.transporter_sign_date, /* bllwos.date_act_arrive, */ bllwoh.start_date )
					FROM BillingLinkLookup bll
						INNER JOIN WorkOrderHeader bllwoh (nolock)
							ON bllwoh.company_id = bll.source_company_id
							AND bllwoh.profit_ctr_id = bll.source_profit_ctr_id
							AND bllwoh.workorder_id = bll.source_id
						LEFT OUTER JOIN WorkOrderStop bllwos (nolock)
							ON bllwos.company_id = bll.source_company_id
							AND bllwos.profit_ctr_id = bll.source_profit_ctr_id
							AND bllwos.workorder_id = bll.source_id
							AND bllwos.stop_sequence_id = 1
					WHERE bll.company_id = b.company_id
						AND bll.profit_ctr_id = b.profit_ctr_id
						AND bll.receipt_id = b.receipt_id
				)
			ELSE
				coalesce(rt.transporter_sign_date, r.receipt_date)
			END
		ELSE
			coalesce(wos.date_act_arrive, woh.start_date)
		END as ship_date,
		isnull(r.manifest_line, '') as manifest_line,
		isnull(p.approval_desc, '') as waste_desc,
		isnull(convert(varchar(max), r.manifest_DOT_shipping_name), '') as manifest_DOT_shipping_name,
		isnull(bu.bill_unit_desc, '') as container_type,
		sum(b.quantity) as quantity, 
		isnull(p.EPA_form_code, '') as EPA_Form_Code,
		isnull(p.epa_source_code, '') as EPA_Source_Code,
		'' as density, -- Density in lbs/gal,
		'' as density_uom, -- Density Unit Of Measure (P)ounds or (G)al,
		SUM(r.line_weight) as waste_quantity,
		dbo.fn_get_list_item(',', 1, dbo.fn_receipt_waste_code_list_long(r.company_id, r.profit_ctr_id, r.receipt_id, r.line_id), 1) as epa_waste_code_1,
		dbo.fn_get_list_item(',', 1, dbo.fn_receipt_waste_code_list_long(r.company_id, r.profit_ctr_id, r.receipt_id, r.line_id), 2) as epa_waste_code_2,
		dbo.fn_get_list_item(',', 1, dbo.fn_receipt_waste_code_list_long(r.company_id, r.profit_ctr_id, r.receipt_id, r.line_id), 3) as epa_waste_code_3,
		dbo.fn_get_list_item(',', 1, dbo.fn_receipt_waste_code_list_long(r.company_id, r.profit_ctr_id, r.receipt_id, r.line_id), 4) as epa_waste_code_4,
		dbo.fn_get_list_item(',', 1, dbo.fn_receipt_waste_code_list_long(r.company_id, r.profit_ctr_id, r.receipt_id, r.line_id), 5) as epa_waste_code_5,
		dbo.fn_get_list_item(',', 1, dbo.fn_receipt_waste_code_list_long(r.company_id, r.profit_ctr_id, r.receipt_id, r.line_id), 6) as epa_waste_code_6,
		dbo.fn_get_list_item(',', 1, dbo.fn_receipt_waste_code_list_long(r.company_id, r.profit_ctr_id, r.receipt_id, r.line_id), 7) as epa_waste_code_7,
		dbo.fn_get_list_item(',', 1, dbo.fn_receipt_waste_code_list_long(r.company_id, r.profit_ctr_id, r.receipt_id, r.line_id), 8) as epa_waste_code_8,
		dbo.fn_get_list_item(',', 1, dbo.fn_receipt_waste_code_list_long(r.company_id, r.profit_ctr_id, r.receipt_id, r.line_id), 9) as epa_waste_code_9,
		dbo.fn_get_list_item(',', 1, dbo.fn_receipt_waste_code_list_long(r.company_id, r.profit_ctr_id, r.receipt_id, r.line_id), 10) as epa_waste_code_10,
		dbo.fn_get_list_item(',', 1, dbo.fn_receipt_waste_code_list_state_long(r.company_id, r.profit_ctr_id, r.receipt_id, r.line_id), 1) as state_waste_code_1,
		dbo.fn_get_list_item(',', 1, dbo.fn_receipt_waste_code_list_state_long(r.company_id, r.profit_ctr_id, r.receipt_id, r.line_id), 2) as state_waste_code_2,
		dbo.fn_get_list_item(',', 1, dbo.fn_receipt_waste_code_list_state_long(r.company_id, r.profit_ctr_id, r.receipt_id, r.line_id), 3) as state_waste_code_3,
		CASE WHEN left(r.approval_code,6) IN ('TRG014', 'TRG024', 'TRG032', 'TRG046')
			THEN 'Y' ELSE 'N'
		END as Universal_waste,
		CASE WHEN left(r.approval_code,6) IN ('TRG001', 'TRG017', 'TRG023%', 'TRG025', 'TRG026', 'TRG027', 'TRG029', 'TRG030', 'TRG033')
			THEN 'Y' ELSE 'N'
		END as NonRcra_Waste,
		isnull(rt1.transporter_name, '') as trans_name1,
		isnull(rt1.transporter_epa_id, '') as trans_epa_id1,
		isnull(rt2.transporter_name, '') as trans_name2,
		isnull(rt2.transporter_epa_id, '') as trans_epa_id2,
		isnull(tsdf.tsdf_name, '') as tsdf_name,
		isnull(tsdf.tsdf_addr1, '') as tsdf_street1,
		'' as tsdf_street2,
		isnull(tsdf.tsdf_city, '') as tsdf_city,
		isnull(tsdf.tsdf_state, '') as tsdf_state,
		isnull(tsdf.tsdf_zip_code, '') as tsdf_zip,
		isnull(tsdf.tsdf_epa_id, '') as off_site1_epa_id,
		isnull(treat.disposal_service_desc, '') as tsdf_mgmt,
		isnull(r.manifest_management_code, '') as off_site1_management_method,
		'' as state_management_method,
		'' as notes
	-- INTO EQ_Extract..Target2012Disposal
	FROM Billing b (nolock)
		INNER JOIN Generator g  (nolock)
			ON b.generator_id = g.generator_id
		INNER JOIN Receipt r  (nolock)
			ON b.receipt_id = r.receipt_id 
			and b.company_id = r.company_id 
			and b.profit_ctr_id = r.profit_ctr_id 
			and b.line_id = r.line_id
			and b.trans_source = 'R'
		INNER JOIN Profile p (nolock)
			ON r.profile_id = p.profile_id
		INNER JOIN ProfileQuoteApproval pqa (nolock)
			ON r.profile_id = pqa.profile_id
			and r.company_id = pqa.company_id
			and r.profit_ctr_id = pqa.profit_ctr_id
		INNER JOIN Treatment treat (nolock)
			ON pqa.treatment_id = treat.treatment_id
			and r.company_id = treat.company_id
			and r.profit_ctr_id = treat.profit_ctr_id
		LEFT OUTER JOIN County gc  (nolock)
			on g.generator_county = gc.county_code
		LEFT OUTER JOIN ReceiptTransporter rt (nolock)
			ON r.receipt_id = rt.receipt_id
			and r.company_id = rt.company_id
			and r.profit_ctr_id = rt.profit_ctr_id
			and rt.transporter_sequence_id = 1
		LEFT OUTER JOIN Transporter rt1 (nolock)
			ON rt.transporter_code = rt1.transporter_code
		LEFT OUTER JOIN ReceiptTransporter rttwo (nolock)
			ON r.receipt_id = rttwo.receipt_id
			and r.company_id = rttwo.company_id
			and r.profit_ctr_id = rttwo.profit_ctr_id
			and rttwo.transporter_sequence_id = 2
		LEFT OUTER JOIN Transporter rt2 (nolock)
			ON rttwo.transporter_code = rt2.transporter_code
		LEFT OUTER JOIN TSDF tsdf (nolock)
			ON pqa.company_id = tsdf.eq_company
			and pqa.profit_ctr_id = tsdf.eq_profit_ctr
			and tsdf.tsdf_status = 'A'
		LEFT OUTER JOIN WorkOrderHeader woh 
			ON b.receipt_id = woh.workorder_id 
			and b.company_id = woh.company_id 
			and b.profit_ctr_id = woh.profit_ctr_id
			and b.trans_source = 'W'
		LEFT OUTER JOIN WorkOrderDetail wod 
			ON b.receipt_id = wod.workorder_id 
			and b.company_id = wod.company_id 
			and b.profit_ctr_id = wod.profit_ctr_id 
			-- and b.line_id = wod.line_id 
			and b.workorder_sequence_id = wod.sequence_id
			and b.workorder_resource_type = wod.resource_type
			and b.trans_source = 'W'
		LEFT OUTER JOIN WorkOrderStop wos (nolock)
			ON wos.company_id = woh.company_id
			AND wos.profit_ctr_id = woh.profit_ctr_id
			AND wos.workorder_id = woh.workorder_id
			AND wos.stop_sequence_id = 1
		LEFT OUTER JOIN BillUnit bu (nolock)
			ON b.bill_unit_code = bu.bill_unit_code
	WHERE
		b.customer_id = @customer_id
		AND CASE WHEN trans_source = 'R' THEN
				CASE WHEN EXISTS (
						SELECT receipt_id 
						FROM BillingLinkLookup bll 
						WHERE bll.company_id = b.company_id
						AND bll.profit_ctr_id = b.profit_ctr_id
						AND bll.receipt_id = b.receipt_id
					) THEN (
						SELECT coalesce(rt.transporter_sign_date, /* bllwos.date_act_arrive, */ bllwoh.start_date )
						FROM BillingLinkLookup bll
							INNER JOIN WorkOrderHeader bllwoh (nolock)
								ON bllwoh.company_id = bll.source_company_id
								AND bllwoh.profit_ctr_id = bll.source_profit_ctr_id
								AND bllwoh.workorder_id = bll.source_id
							LEFT OUTER JOIN WorkOrderStop bllwos (nolock)
								ON bllwos.company_id = bll.source_company_id
								AND bllwos.profit_ctr_id = bll.source_profit_ctr_id
								AND bllwos.workorder_id = bll.source_id
								AND bllwos.stop_sequence_id = 1
						WHERE bll.company_id = b.company_id
							AND bll.profit_ctr_id = b.profit_ctr_id
							AND bll.receipt_id = b.receipt_id
					)
			ELSE
				coalesce(rt.transporter_sign_date, r.receipt_date)
			END
		ELSE
			coalesce(wos.date_act_arrive, woh.start_date)
		END BETWEEN @start_date AND @end_date
		AND b.status_code = 'I'
		AND b.trans_source = 'R'
		--and g.generator_state in ('MN', 'RI')
	GROUP BY
		CONVERT(Varchar(16), ISNULL(g.site_code, '')),
		--ISNULL(g.site_code, ''),
		--convert(int, ISNULL(g.site_code, '0')),
		g.epa_id,
		r.manifest,
		r.manifest_line,
		b.company_id,
		b.profit_ctr_id,
		b.receipt_id,
		b.trans_source,
		rt.transporter_sign_date,
		r.receipt_date,
		wos.date_act_arrive,
		woh.start_date,
		p.approval_desc,
		convert(varchar(max), r.manifest_DOT_shipping_name),
		bu.bill_unit_desc,
		b.quantity, 
		p.EPA_form_code,
		p.epa_source_code,
		-- Density in lbs/gal,
		-- Density Unit Of Measure (P)ounds or (G)al,
		dbo.fn_get_list_item(',', 1, dbo.fn_receipt_waste_code_list_long(r.company_id, r.profit_ctr_id, r.receipt_id, r.line_id), 1),
		dbo.fn_get_list_item(',', 1, dbo.fn_receipt_waste_code_list_long(r.company_id, r.profit_ctr_id, r.receipt_id, r.line_id), 2),
		dbo.fn_get_list_item(',', 1, dbo.fn_receipt_waste_code_list_long(r.company_id, r.profit_ctr_id, r.receipt_id, r.line_id), 3),
		dbo.fn_get_list_item(',', 1, dbo.fn_receipt_waste_code_list_long(r.company_id, r.profit_ctr_id, r.receipt_id, r.line_id), 4),
		dbo.fn_get_list_item(',', 1, dbo.fn_receipt_waste_code_list_long(r.company_id, r.profit_ctr_id, r.receipt_id, r.line_id), 5),
		dbo.fn_get_list_item(',', 1, dbo.fn_receipt_waste_code_list_long(r.company_id, r.profit_ctr_id, r.receipt_id, r.line_id), 6),
		dbo.fn_get_list_item(',', 1, dbo.fn_receipt_waste_code_list_long(r.company_id, r.profit_ctr_id, r.receipt_id, r.line_id), 7),
		dbo.fn_get_list_item(',', 1, dbo.fn_receipt_waste_code_list_long(r.company_id, r.profit_ctr_id, r.receipt_id, r.line_id), 8),
		dbo.fn_get_list_item(',', 1, dbo.fn_receipt_waste_code_list_long(r.company_id, r.profit_ctr_id, r.receipt_id, r.line_id), 9),
		dbo.fn_get_list_item(',', 1, dbo.fn_receipt_waste_code_list_long(r.company_id, r.profit_ctr_id, r.receipt_id, r.line_id), 10),
		dbo.fn_get_list_item(',', 1, dbo.fn_receipt_waste_code_list_state_long(r.company_id, r.profit_ctr_id, r.receipt_id, r.line_id), 1),
		dbo.fn_get_list_item(',', 1, dbo.fn_receipt_waste_code_list_state_long(r.company_id, r.profit_ctr_id, r.receipt_id, r.line_id), 2),
		dbo.fn_get_list_item(',', 1, dbo.fn_receipt_waste_code_list_state_long(r.company_id, r.profit_ctr_id, r.receipt_id, r.line_id), 3),
		CASE WHEN left(r.approval_code,6) IN ('TRG014', 'TRG024', 'TRG032', 'TRG046')
			THEN 'Y' ELSE 'N'
		END,
		CASE WHEN left(r.approval_code,6) IN ('TRG001', 'TRG017', 'TRG023%', 'TRG025', 'TRG026', 'TRG027', 'TRG029', 'TRG030', 'TRG033')
			THEN 'Y' ELSE 'N'
		END,
		rt1.transporter_name,
		rt1.transporter_epa_id,
		rt2.transporter_name,
		rt2.transporter_epa_id,
		tsdf.tsdf_name,
		tsdf.tsdf_addr1,
		tsdf.tsdf_city,
		tsdf.tsdf_state,
		tsdf.tsdf_zip_code,
		tsdf.tsdf_epa_id,
		treat.disposal_service_desc,
		r.manifest_management_code
		
ORDER BY 		CASE WHEN trans_source = 'R' THEN
				CASE WHEN EXISTS (
						SELECT receipt_id 
						FROM BillingLinkLookup bll 
						WHERE bll.company_id = b.company_id
						AND bll.profit_ctr_id = b.profit_ctr_id
						AND bll.receipt_id = b.receipt_id
					) THEN (
						SELECT coalesce(bllwos.date_act_arrive, bllwoh.start_date )
						FROM BillingLinkLookup bll
							INNER JOIN WorkOrderHeader bllwoh (nolock)
								ON bllwoh.company_id = bll.source_company_id
								AND bllwoh.profit_ctr_id = bll.source_profit_ctr_id
								AND bllwoh.workorder_id = bll.source_id
							LEFT OUTER JOIN WorkOrderStop bllwos (nolock)
								ON bllwos.company_id = bll.source_company_id
								AND bllwos.profit_ctr_id = bll.source_profit_ctr_id
								AND bllwos.workorder_id = bll.source_id
								AND bllwos.stop_sequence_id = 1
						WHERE bll.company_id = b.company_id
							AND bll.profit_ctr_id = b.profit_ctr_id
							AND bll.receipt_id = b.receipt_id
					)
				ELSE
					r.receipt_date
				END
		ELSE
			coalesce(wos.date_act_arrive, woh.start_date)
		END
		--, convert(int, ISNULL(g.site_code, '0'))
		,	CONVERT(Varchar(16), ISNULL(g.site_code, ''))


-- alter table EQ_Extract..Target2011Disposal add row_num int not null identity(1,1)
-- SELECT  *  FROM    EQ_Extract..Target2011Disposal where row_num between 60001 and 90000


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_reports_target_quarterly_extract] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_reports_target_quarterly_extract] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_reports_target_quarterly_extract] TO [EQAI]
    AS [dbo];

