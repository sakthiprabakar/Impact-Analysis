CREATE PROCEDURE [dbo].[sp_internal_waste_transfer_on_site]
	@receipt_date_from		datetime,
	@receipt_date_to 		datetime,
    @company_id				int,
    @profit_ctr_id			int
AS
/**************************************************************************************************
Load to:		Plt_AI
PB Object(s):	r_internal_waste_report

01/28/2014 AM	Created. 
				Get all the waste from OB that goes from facility to itself or 
				facility 2 waste is going to facility 3 or facility 3 waste is going to facility 2.
02/20/2014 AM	Added union to get inbound data where the generator country is in USA.
				Also added a check to make sure the receipt records have at least one hazardous
				waste code.
				Converted the sub-selects for various fields to joins.
07/10/2014 AM   Added EPA_form_code. Also added profile_id for 'I' Union. 

exec sp_internal_waste_transfer_on_site '01-01-2014','07-04-2014',3,0

**************************************************************************************************/

SELECT  TSDF.eq_profit_ctr as tsdf_profit_ctr,
        TSDF.eq_company as tsdf_comapny_id, 
        Receipt.company_ID as receipt_company_id, 
        Receipt.profit_ctr_id as receipt_profit_ctr_id, 
        ProfitCenter.company_ID as ProfitCenter_company_ID,
        ProfitCenter.profit_ctr_ID  as ProfitCenter_profit_ctr_ID,
        Receipt.receipt_id ,
        Receipt.trans_mode,
        Receipt.manifest, 
        Receipt.receipt_date , 
        Receipt.line_id,
        dbo.fn_receipt_weight_line (Receipt.receipt_id, Receipt.line_id, Receipt.profit_ctr_id, Receipt.company_ID ) as manifest_quantity,
        'LBS' as manifest_unit, 
        Receipt.ob_profile_ID, 
        Receipt.TSDF_approval_code, 
        Profile.approval_desc  as approval_description,
        TSDF.TSDF_code , 
        Receipt.manifest_management_code,
        TSDF.TSDF_EPA_ID, 
        ProfitCenter.EPA_ID as ob_pc_epa_id, 
        dbo.fn_receipt_top6_waste_code_list(Receipt.company_ID, Receipt.profit_ctr_id, Receipt.receipt_id, Receipt.line_id )as waste_display_name,
        Profile.EPA_source_code as source_code,
        Profile.EPA_form_code as form_code
FROM Receipt 
Join ProfitCenter ON Receipt.company_id = ProfitCenter.company_ID
   AND Receipt.profit_ctr_id = ProfitCenter.profit_ctr_ID  
Join TSDF ON Receipt.TSDF_code = TSDF.TSDF_code 
   AND TSDF.TSDF_status = 'A'
   AND TSDF.eq_flag = 'T'
   AND ( ( TSDF.TSDF_EPA_ID = ProfitCenter.EPA_ID ) OR 
         ( ProfitCenter.company_ID in (02,03) ) 
       AND TSDF.TSDF_EPA_ID IN ( SELECT ProfitCenter.EPA_ID
							        FROM ProfitCenter 
							        WHERE ProfitCenter.company_ID in (02,03)
					            ) 
		)
  AND (@company_id = 0 OR TSDF.eq_company = @company_id)
  AND (@company_id = 0 OR @profit_ctr_id = -1 OR TSDF.eq_profit_ctr = @profit_ctr_id)
Join Profile on Profile.profile_id = receipt.ob_profile_id  
WHERE Receipt.receipt_date between @receipt_date_from and @receipt_date_to 
  AND Receipt.trans_mode in ( 'O' )
  AND Receipt.trans_type = 'D'
  AND Receipt.receipt_status <> 'V'
  AND Exists ( select 1 from ReceiptWasteCode rwc 
                Join WasteCode on WasteCode.waste_code_uid = rwc.waste_code_uid
                 AND  WasteCode.haz_flag = 'T' 
			   Where Receipt.company_id = rwc.company_id 
			   AND  Receipt.profit_ctr_id = rwc.profit_ctr_id
			   and Receipt.receipt_id = rwc.receipt_id 
			   and Receipt.line_id = rwc.line_id )
  
UNION 

SELECT  Receipt.profit_ctr_id as tsdf_profit_ctr ,
        Receipt.company_ID as tsdf_comapny_id, 
        Receipt.company_ID as receipt_company_id, 
        Receipt.profit_ctr_id as receipt_profit_ctr_id, 
        ProfitCenter.company_ID as ProfitCenter_company_ID,
        ProfitCenter.profit_ctr_ID  as ProfitCenter_profit_ctr_ID,
        Receipt.receipt_id ,
        Receipt.trans_mode, 
        Receipt.manifest, 
        Receipt.receipt_date , 
        Receipt.line_id,
        dbo.fn_receipt_weight_line (Receipt.receipt_id, Receipt.line_id, Receipt.profit_ctr_id, Receipt.company_ID ) as manifest_quantity,
        'LBS' as manifest_unit, 
        Receipt.profile_id  as ob_profile_ID, 
        Receipt.approval_code as TSDF_approval_code, 
        Profile.approval_desc  as approval_description,
        TSDF.TSDF_code  as tsdf_code,
        Receipt.manifest_management_code,
        TSDF.TSDF_EPA_ID, 
        Generator.EPA_ID as ob_pc_epa_id, 
        dbo.fn_receipt_top6_waste_code_list(Receipt.company_ID, Receipt.profit_ctr_id, Receipt.receipt_id, Receipt.line_id )as waste_display_name,
        Profile.EPA_source_code as source_code,
        Profile.EPA_form_code as form_code
FROM Receipt 
Join ProfitCenter ON Receipt.company_id = ProfitCenter.company_ID
   AND Receipt.profit_ctr_id = ProfitCenter.profit_ctr_ID  
   AND (@company_id = 0 OR ProfitCenter.company_ID = @company_id)
   AND (@company_id = 0 OR @profit_ctr_id = -1 OR ProfitCenter.profit_ctr_ID = 0)	
Join Generator on Generator.generator_id = receipt.generator_id 
		AND (( (Generator.EPA_ID = ProfitCenter.EPA_ID ) OR ProfitCenter.company_ID in (02,03) )
					  AND  Generator.EPA_ID in ( select epa_id from ProfitCenter
												 where ProfitCenter.company_ID in (2,3)
												)
		    ) 
     AND Generator.generator_country = 'USA'		   			
Join TSDF ON Receipt.company_id  = TSDF.eq_company
   AND Receipt.profit_ctr_id  = TSDF.eq_profit_ctr
   AND TSDF.TSDF_status = 'A'
   AND TSDF.eq_flag = 'T'
Join Profile on Profile.profile_id = receipt.profile_id 
WHERE Receipt.receipt_date between @receipt_date_from and @receipt_date_to 
  AND Receipt.trans_mode in ( 'I' )
  AND Receipt.trans_type = 'D'
  AND Receipt.receipt_status <> 'V'
  AND Exists ( select 1 from ReceiptWasteCode rwc 
                Join WasteCode on WasteCode.waste_code_uid = rwc.waste_code_uid
                 AND  WasteCode.haz_flag = 'T' 
			   Where Receipt.company_id = rwc.company_id 
			   AND  Receipt.profit_ctr_id = rwc.profit_ctr_id
			   and Receipt.receipt_id = rwc.receipt_id 
			   and Receipt.line_id = rwc.line_id )

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_internal_waste_transfer_on_site] TO [EQAI]
    AS [dbo];

