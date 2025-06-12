CREATE PROCEDURE sp_rpt_volume_fee (
	@company_id		 int
,	@profit_ctr_id	 int
,	@date_from		datetime
,	@date_to		datetime
)
AS
/*************************************************************************************************
Loads to : PLT_AI
PowerBuilder object(s): r_volume_fee_detail and r_volume_fee_summary use this procedure AS data source. 	

10/06/2017 RB	Created Rich Bianco  - This is a redesigned report from Aesop based off the Tax
				Detail and Tax Summary reports. The source in Aesop was Inventory therefore the source being
				used in EQAI is ContainerDestination. We know that the billing unit does not equate directly
				to container unit though they are used to seeing it on the report.
04/16/2018 RJB	Fix to send only eight digits precision to the dataobject because it is 
				resulting in slight differences across reports also force 8 digit precision via convert fx.

06/11/2018 AM	GEM:51248 - Modified sp to add generator_state,submitted_flag and tx_waste_code.
06/13/2018 AM   GEM:51317 - Added industrial_flag, treatment columns and all codes columns.

EXECUTE sp_rpt_volume_fee  46, 0 ,'2018-05-01', '2018-06-30'
EXECUTE sp_rpt_volume_fee  44, 0 ,'2018-05-01', '2018-06-30'
*************************************************************************************************/
SELECT 
	r.company_id,
	r.profit_ctr_id,
	r.receipt_date,
	r.receipt_id,
	r.line_id,
	r.manifest,
	r.manifest_page_num, 
	r.manifest_line,
	r.approval_code,
	p.approval_desc,
	cd.container_id,
	cd.sequence_id,
	cd.container_percent,
	r.quantity,
	dbo.fn_receipt_bill_unit(cd.receipt_id, cd.line_id, cd.profit_ctr_id, cd.company_id) AS bill_unit,
	CONVERT(DECIMAL(26,8),ROUND(ROUND(dbo.fn_receipt_weight_container_hi_prec(
						cd.receipt_id, 
						cd.line_id, 
						cd.profit_ctr_id, 
						cd.company_id, 
						cd.container_id, 
						cd.sequence_id),8) / 2000, 8)) AS wt_tons,	
	tc.tax_desc AS tax_code,
	tc.tax_rate,
	pc.profit_ctr_name,
	g.generator_state,
	r.submitted_flag,
	tx_waste_code = IsNull ( ( select wc.display_name from receiptwastecode rwc
        join wastecode wc on rwc.waste_code_uid = wc.waste_code_uid
        where rwc.company_id = r.company_id and rwc.profit_ctr_id = r.profit_ctr_id and r.line_id = rwc.line_id and rwc.receipt_id = r.receipt_id 
        and wc.state = 'TX' and wc.waste_code_origin = 'S'
        and IsNull (rwc.sequence_id,1) = 
			(	select IsNull ( min(rwc1.sequence_id),1 ) from receiptwastecode rwc1 
				join wastecode wc1 on rwc1.waste_code_uid = wc1.waste_code_uid
				where rwc1.receipt_id = r.receipt_id and rwc1.company_id = r.company_id and rwc1.profit_ctr_id = r.profit_ctr_id 
				and rwc1.line_id = r.line_id and wc1.state = 'TX' and wc1.waste_code_origin = 'S'
			)
                      ) ,''),
    g.industrial_flag,
    g.EPA_ID,
	cd.treatment_id,
	t.wastetype_category,
	t.wastetype_description,
	t.treatment_process_process,
	t.disposal_service_desc,
	t.management_code,
	d_codes = CASE when ( select count(*) from ReceiptWasteCode rwc 
		join wastecode wc on rwc.waste_code_uid = wc.waste_code_uid
		where rwc.company_id = r.company_id  and rwc.profit_ctr_id = r.profit_ctr_id and rwc.receipt_id = r.receipt_id and rwc.line_id = r.line_id 
	    and wc.waste_code_origin = 'F' and wc.display_name like 'D%' ) = 0 then 'F' else 'T' end ,
	p_codes = CASE when ( select count(*) from ReceiptWasteCode rwc 
		join wastecode wc on rwc.waste_code_uid = wc.waste_code_uid
		where rwc.company_id = r.company_id  and rwc.profit_ctr_id = r.profit_ctr_id and rwc.receipt_id = r.receipt_id and rwc.line_id = r.line_id 
	    and wc.waste_code_origin = 'F' and wc.display_name like 'P%'  ) = 0 then 'F' else 'T' end ,
	u_codes =  CASE when ( select count(*) from ReceiptWasteCode rwc 
		join wastecode wc on rwc.waste_code_uid = wc.waste_code_uid
		where rwc.company_id = r.company_id  and rwc.profit_ctr_id = r.profit_ctr_id and rwc.receipt_id = r.receipt_id and rwc.line_id = r.line_id 
	    and wc.waste_code_origin = 'F' and wc.display_name like 'U%'  ) = 0 then 'F' else 'T' end ,
	k_codes =  CASE when ( select count(*) from ReceiptWasteCode rwc 
		join wastecode wc on rwc.waste_code_uid = wc.waste_code_uid
		where rwc.company_id = r.company_id  and rwc.profit_ctr_id = r.profit_ctr_id and rwc.receipt_id = r.receipt_id and rwc.line_id = r.line_id 
	    and wc.waste_code_origin = 'F' and wc.display_name like 'K%'  ) = 0 then 'F' else 'T' end ,
	f_codes =  CASE when ( select count(*) from ReceiptWasteCode rwc 
		join wastecode wc on rwc.waste_code_uid = wc.waste_code_uid
		where rwc.company_id = r.company_id  and rwc.profit_ctr_id = r.profit_ctr_id and rwc.receipt_id = r.receipt_id and rwc.line_id = r.line_id 
	    and wc.waste_code_origin = 'F' and wc.display_name like 'F%'  ) = 0 then 'F' else 'T' end 	
FROM ContainerDestination cd
INNER JOIN Receipt AS r 
	ON	cd.receipt_id		= r.receipt_id
	AND	cd.line_id			= r.line_id
	AND cd.company_id		= r.company_id 
	AND cd.profit_ctr_id	= r.profit_ctr_id 
INNER JOIN TaxCode AS tc
	ON	cd.company_id		= tc.company_id
	AND cd.profit_ctr_id	= tc.profit_ctr_id
	AND cd.tax_code_uid		= tc.tax_code_uid
INNER JOIN Profile AS p
	ON	r.profile_id		= p.profile_id
INNER JOIN ProfitCenter pc
	ON	pc.company_id		= r.company_id
	AND pc.profit_ctr_id	= r.profit_ctr_id
INNER JOIN Generator AS g
	ON	g.generator_id		= r.generator_id 
INNER JOIN treatment AS t
    ON t.treatment_id  = cd.treatment_id and t.company_id  = cd.company_id 
     and t.profit_ctr_id = cd.profit_ctr_id 
WHERE cd.company_id			= @company_id
  AND cd.profit_ctr_id		= @profit_ctr_id
  AND cd.tax_code_uid		IS NOT NULL
  AND r.receipt_date		>= @date_from
  AND r.receipt_date		<= @date_to
  AND r.receipt_status		not in ('V','R')
  AND r.trans_type			= 'D' 

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_volume_fee] TO [EQAI]
    AS [dbo];

