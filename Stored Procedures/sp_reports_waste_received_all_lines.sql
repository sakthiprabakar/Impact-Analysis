
/********************
sp_reports_waste_received_all_lines:

Returns data for Waste Received, for a specific receipt id.

LOAD TO PLT_XX_AI

05/18/2005 JPB Created
01/17/2005 MK  Modified to join to receiptprice for bill_unit matching
02/20/2011 JPB  Added Line Weight to output
08/01/2013 JPB	Modified for TX Waste Codes
06/20/2014	JPB	Convert to accept company_id and live on plt_ai, not plt_xx_ai

sp_reports_waste_received_all_lines 2, 0,386703

sp_reports_waste_received_all_lines 21, 0,1196597, 'T'
sp_reports_waste_received_all_lines 27, 0,63834, 'T'
sp_reports_waste_received_all_lines 27, 0,63797, 'T'

SELECT * FROM receipt WHERE receipt_id = 1196597 and company_id = 21

**********************/


CREATE PROCEDURE sp_reports_waste_received_all_lines
	@company_id	int,
	@profit_ctr_id	int,	-- The profit center to run against.
	@receipt_id	int,	-- Receipt ID
	@status_override char(1) = 'F'
AS

select
	r.company_id,
	r.profit_ctr_id,
	cu.customer_id,
	cu.cust_name,
	r.receipt_id,
	r.line_id,
	case r.trans_mode
		when 'I' then 'Inbound'
		when 'O' then 'Outbound'
	end as trans_mode,
	case r.receipt_status
		when 'A' then 'Accepted'
		when 'L' then 'In the Lab'
		when 'M' then 'Manual'
		when 'N' then 'New'
		when 'R' then 'Rejected'
		when 'T' then 'In-Transit'
		when 'U' then 'Unloading'
		when 'V' then 'Void'
		else r.receipt_status
	end as receipt_status,
	case r.fingerpr_status
		when 'A' then 'Accepted'
		when 'H' then 'Hold'
		when 'R' then 'Rejected'
		when 'V' then 'Void'
		when 'W' then 'Waiting'
	end as fingerpr_status,
	case r.waste_accepted_flag
		when 'T' then 'Waste Accepted'
		when 'F' then 'Not Waste Accepted'
	end as waste_accepted_flag,
	case r.submitted_flag
		when 'T' then 'Submitted'
		when 'F' then 'Not Submitted'
	end as submitted_flag,
	b.price_id,
	r.receipt_date,
	r.tsdf_code,
    case when r.trans_mode = 'I' OR (tsdf.eq_company is not null and tsdf.eq_profit_ctr is not null) then 'T' else 'F' end as our_tsdf,
    tsdf.eq_company as tsdf_company_id,
    tsdf.eq_profit_ctr as tsdf_profit_ctr_id,
	coalesce(r.approval_code, r.tsdf_approval_code) as approval_code,
	coalesce(r.profile_id, r.tsdf_approval_id) as approval_id,
	r.company_id as approval_company_id,
	r.profit_ctr_id as approval_profit_ctr_id,
	case r.trans_type
		when 'D' then 'Disposal'
		when 'S' then 'Service'
		else r.trans_type
	end as trans_type,
	g.generator_id,
	g.epa_id,
	g.generator_name,
	pwc.display_name as waste_code,
	bu.bill_unit_desc,
	b.bill_unit_code,
	r.quantity,
	r.gross_weight,
	r.tare_weight,
	r.net_weight,
	r.line_weight,
	r.time_in,
	r.time_out,
	r.date_scheduled,
	r.manifest,
	r.service_desc
FROM Receipt r
	LEFT JOIN Billing b 
		ON r.receipt_id = b.receipt_id 
		AND r.company_id = b.company_id
		AND r.profit_ctr_id = b.profit_ctr_id
		AND r.line_id = b.line_id 
		AND r.billing_project_id = b.billing_project_id
	INNER JOIN Customer cu ON r.customer_id = cu.customer_id
	LEFT OUTER JOIN Generator g ON r.generator_id = g.generator_id
	left join receiptprice rp 
		on b.receipt_id = rp.receipt_id 
		and b.company_id = rp.company_id 
		and b.profit_ctr_id = rp.profit_ctr_id 
		and b.line_id = rp.line_id 
		and b.price_id = rp.price_id
	left join billunit bu on rp.bill_unit_code = bu.bill_unit_code	
	left JOIN ReceiptWasteCode rwc 
		on r.receipt_id = rwc.receipt_id
		and r.company_id = rwc.company_id
		and r.profit_ctr_id = rwc.profit_ctr_id
		and r.line_id = rwc.line_id
		and rwc.primary_flag = 'T'
	left JOIN WasteCode pwc ON
		rwc.waste_code_uid = pwc.waste_code_uid
	left join TSDF ON
		r.tsdf_code = TSDF.tsdf_code
	
WHERE
	r.receipt_id = @receipt_id
	and r.company_id = @company_id
	and r.profit_ctr_id = @profit_ctr_id
	and (
		@status_override = 'F' and (
			r.receipt_status='A'
			and r.trans_mode = 'I'
			and b.status_code = 'I'
			AND r.receipt_date < GETDATE()
		) 
		or @status_override = 'T'
	)
ORDER BY r.line_id, b.price_id


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_reports_waste_received_all_lines] TO PUBLIC
    AS [dbo];

