CREATE PROCEDURE [dbo].[sp_rpt_outbound_shipment_data] 
	@company_id			int
,	@profit_ctr_id		int
,	@receipt_date_from	datetime
,	@receipt_date_to	datetime
,	@tsdf				varchar(15)
,	@tsdf_approval_from	varchar(40)
,	@tsdf_approval_to	varchar(40)
AS
/*****************************************************************************
Filename:		L:\IT Apps\SQL-Deploy\Prod\NTSQL1\PLT_AI\Procedures
PB Object(s):	r_outbound_shipment_data

08/19/2014 SM	Created.
08/25/2014 SM	Added TSDF code in search
09/23/2014 SM	Added TSDF approval to search
11/04/2014 SM	Modified for only Accepted receipts

sp_rpt_outbound_shipment_data 2, 0, '1/1/13', '1/31/13','ALL'
sp_rpt_outbound_shipment_data 2, 0, '1/1/13', '1/31/13',''
sp_rpt_outbound_shipment_data 2, 0, '1/1/13', '1/31/13','EQWDI'
*****************************************************************************/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
--SET NOCOUNT ON


SELECT	r.company_id
,		r.profit_ctr_id
,		p.profit_ctr_name
,		r.receipt_id 
,		r.line_id 
,		r.receipt_date 
,		CASE r.manifest_flag 
			WHEN 'M' THEN 'Manifest' 
			WHEN 'B' THEN 'BOL' 
			WHEN 'C' THEN 'Commingled'
			WHEN 'X' THEN 'Transfer'  
			ELSE '?' 
		END AS manifest_type
,		r.manifest
,		t.tsdf_code
,		t.tsdf_epa_id
,		t.tsdf_name
,		r.manifest_quantity
,		r.manifest_unit
,		dbo.fn_receipt_waste_code_list_all_long(r.company_id, r.profit_ctr_id, r.receipt_id, r.line_id ) as waste_codes
,		r.manifest_management_code
,		tr.transporter_code
,		tr.transporter_epa_id
,		tr.transporter_name
,		r.manifest_dot_shipping_name
,		COALESCE ((SELECT  distinct 'Haz'
		FROM    ReceiptwasteCode RWC
        JOIN Wastecode W ON RWC.waste_code_uid = W.waste_code_uid
       	WHERE   RWC.company_id = r.company_id
        AND RWC.profit_ctr_id = r.profit_ctr_id
        AND RWC.receipt_id = r.receipt_id
        AND RWC.line_id = r.line_id
        AND W.haz_flag = 'T'
        AND W.waste_code_origin = 'F'
            ),'Non-Haz' ) as haz_flag --sm
FROM Receipt r
JOIN Company c	ON c.company_id = r.company_id
JOIN ProfitCenter p 	ON p.company_ID = r.company_id
	AND p.profit_ctr_ID = r.profit_ctr_id
Join TSDF t ON t.tsdf_code = r.tsdf_code
Join Transporter tr ON tr.transporter_code = r.hauler
WHERE	 r.company_id = @company_id
		AND r.profit_ctr_id = @profit_ctr_id
		AND r.receipt_date BETWEEN @receipt_date_from AND @receipt_date_to
		AND r.trans_mode = 'O'
		AND r.receipt_status = 'A'
		AND ( t.tsdf_code = @tsdf or @tsdf = 'ALL' )
		AND r.TSDF_approval_code BETWEEN @tsdf_approval_from AND @tsdf_approval_to
Order by r.receipt_date, r.manifest, r.receipt_id, r.line_id




GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_outbound_shipment_data] TO [EQAI]
    AS [dbo];

