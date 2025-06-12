CREATE PROCEDURE sp_rpt_outbounds_without_scanned_returned_cod
	@company_id    int,
	@profit_ctr_id int,
	@date_from datetime,
	@date_to   datetime
AS
/***************************************************************************************
Loads to:		PLT_AI
PB Object(s):	r_outbounds_without_scanned_returned_cod

06/26/2017 AM 	Created - Create a New report for outbounds without a scanned returned manifest

sp_rpt_outbounds_without_scanned_returned_cod 21,0,'10/1/2016','10/10/2016'

****************************************************************************************/
Declare @cust_status varchar (3)

select distinct 
	r.company_id, 
	r.profit_ctr_id, 
	r.receipt_id, 
	r.receipt_status, 
	r.submitted_flag, 
	r.receipt_date, 
	r.manifest_flag, 
	r.manifest, 
	r.customer_id, 
	r.generator_id,
	r.tsdf_code,
	t.tsdf_name,
	t.tsdf_phone, 
	t.tsdf_city,
	t.tsdf_state,
	t.tsdf_country_code,
	c.company_name,
	p.profit_ctr_name
from receipt r 
join tsdf t on r.tsdf_code = t.tsdf_code
join Company c on r.company_id = c.company_id 
join ProfitCenter p on r.profit_ctr_id = p.profit_ctr_ID
   AND p.company_ID = r.company_id
where r.trans_mode = 'O'
and r.trans_type = 'D'
and r.receipt_status not in ('V', 'R')
and r.company_id = @company_id 
and r.profit_ctr_id = @profit_ctr_id
and r.receipt_date between @date_from and @date_to
and not exists (select 1 from plt_image..scan
				where company_id = r.company_id
				and profit_ctr_id = r.profit_ctr_id
				and receipt_id = r.receipt_id
				and type_id in (select type_id from ScanDocumentType where scan_type = 'receipt' and document_type = 'COD')
				) 
order by r.receipt_date


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_outbounds_without_scanned_returned_cod] TO [EQAI]
    AS [dbo];

