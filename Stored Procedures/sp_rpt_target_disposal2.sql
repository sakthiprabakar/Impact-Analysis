
create proc sp_rpt_target_disposal2
AS

declare @customer_id int, @start_date datetime, @end_date datetime
select @customer_id = 12113, @start_date = '1/1/2011 00:00', @end_date = '12/31/2011 23:59'


	SELECT -- top 30
		ISNULL(g.site_code, '') as location_number,
		g.generator_address_1 as generator_address,
		g.generator_city,
		g.generator_state,
		g.generator_zip_code,
		gc.county_name as generator_county,
		g.epa_id,
		rt1.transporter_name,
		rt1.transporter_addr1 as transporter_address,
		rt1.transporter_city,
		rt1.transporter_state,
		rt1.transporter_zip_code,
		rt1.transporter_epa_id,
		tsdf.tsdf_name,
		tsdf.tsdf_addr1 as tsdf_address,
		tsdf.tsdf_city,
		tsdf.tsdf_state,
		tsdf.tsdf_zip_code,
		tsdf.tsdf_epa_id,
		p.approval_desc,
		treat.disposal_service_desc,
		dbo.fn_receipt_waste_code_list(b.company_id, b.profit_ctr_id, b.receipt_id, b.line_id) as epa_waste_codes,
		dbo.fn_receipt_waste_code_list_state(b.company_id, b.profit_ctr_id, b.receipt_id, b.line_id) as state_waste_codes,
		r.manifest_container_code,
		p.EPA_form_code,
		p.epa_source_code,
		-- null as specific_gravity,
		CASE WHEN trans_source = 'R' THEN
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
		END as pickup_date,
		r.receipt_date,
		r.manifest,
		r.manifest_line,
		r.manifest_management_code as h_form_code,
		-- NULL as d_form_code,
		r.manifest_UN_NA_number,
		convert(varchar(max), r.manifest_DOT_shipping_name) as manifest_DOT_shipping_name,
		r.manifest_hazmat_class,
		SUM(r.line_weight) as weight,
		r.approval_code,
		CASE WHEN left(r.approval_code,6) IN ('TRG014', 'TRG024', 'TRG032', 'TRG046')
			THEN 'Yes' ELSE 'No'
		END as Universal_waste,
		CASE WHEN left(r.approval_code,6) IN ('TRG001', 'TRG017', 'TRG023%', 'TRG025', 'TRG026', 'TRG027', 'TRG029', 'TRG030', 'TRG033')
			THEN 'Yes' ELSE 'No'
		END as NonRcra_Waste
		

	FROM Billing b (nolock)
		LEFT OUTER JOIN Generator g  (nolock)
			ON b.generator_id = g.generator_id
		LEFT OUTER JOIN County gc  (nolock)
			on g.generator_county = gc.county_code
		LEFT OUTER JOIN Receipt r  (nolock)
			ON b.receipt_id = r.receipt_id 
			and b.company_id = r.company_id 
			and b.profit_ctr_id = r.profit_ctr_id 
			and b.line_id = r.line_id
			and b.trans_source = 'R'
		LEFT OUTER JOIN ReceiptTransporter rt (nolock)
			ON r.receipt_id = rt.receipt_id
			and r.company_id = rt.company_id
			and r.profit_ctr_id = rt.profit_ctr_id
			and rt.transporter_sequence_id = 1
		LEFT OUTER JOIN Transporter rt1 (nolock)
			ON rt.transporter_code = rt1.transporter_code
		LEFT OUTER JOIN Profile p (nolock)
			ON r.profile_id = p.profile_id
		LEFT OUTER JOIN ProfileQuoteApproval pqa (nolock)
			ON r.profile_id = pqa.profile_id
			and r.company_id = pqa.company_id
			and r.profit_ctr_id = pqa.profit_ctr_id
		LEFT OUTER JOIN Treatment treat (nolock)
			ON pqa.treatment_id = treat.treatment_id
			and r.company_id = treat.company_id
			and r.profit_ctr_id = treat.profit_ctr_id
		LEFT OUTER JOIN TSDF tsdf (nolock)
			ON pqa.company_id = tsdf.eq_company
			and pqa.profit_ctr_id = tsdf.eq_profit_ctr
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
	WHERE
		b.customer_id = @customer_id
		AND b.invoice_date BETWEEN @start_date AND @end_date
		AND b.status_code = 'I'
	GROUP BY
		ISNULL(g.site_code, ''),
		g.generator_address_1,
		g.generator_city,
		g.generator_state,
		g.generator_zip_code,
		gc.county_name,
		g.epa_id,
		rt1.transporter_name,
		rt1.transporter_addr1,
		rt1.transporter_city,
		rt1.transporter_state,
		rt1.transporter_zip_code,
		rt1.transporter_epa_id,
		tsdf.tsdf_name,
		tsdf.tsdf_addr1,
		tsdf.tsdf_city,
		tsdf.tsdf_state,
		tsdf.tsdf_zip_code,
		tsdf.tsdf_epa_id,
		p.approval_desc,
		treat.disposal_service_desc,
		dbo.fn_receipt_waste_code_list(b.company_id, b.profit_ctr_id, b.receipt_id, b.line_id),
		dbo.fn_receipt_waste_code_list_state(b.company_id, b.profit_ctr_id, b.receipt_id, b.line_id),
		r.manifest_container_code,
		p.EPA_form_code,
		p.epa_source_code,
		-- null as specific_gravity,
/*
		CASE WHEN trans_source = 'R' THEN
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
		END,
		*/
		b.company_id,
		b.profit_ctr_id,
		b.receipt_id,
		b.trans_source,
		coalesce(wos.date_act_arrive, woh.start_date),
		
		r.receipt_date,
		r.manifest,
		r.manifest_line,
		r.manifest_management_code,
		-- NULL as d_form_code,
		r.manifest_UN_NA_number,
		convert(varchar(max), r.manifest_DOT_shipping_name),
		r.manifest_hazmat_class,
		-- r.line_weight,
		r.approval_code,
		CASE WHEN left(r.approval_code,6) IN ('TRG014', 'TRG024', 'TRG032', 'TRG046')
			THEN 'Yes' ELSE 'No'
		END,
		CASE WHEN left(r.approval_code,6) IN ('TRG001', 'TRG017', 'TRG023%', 'TRG025', 'TRG026', 'TRG027', 'TRG029', 'TRG030', 'TRG033')
			THEN 'Yes' ELSE 'No'
		END

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_target_disposal2] TO [EQAI]
    AS [dbo];

