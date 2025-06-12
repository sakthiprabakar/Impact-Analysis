--DROP PROCEDURE dbo.sp_rpt_tx_inbound_loads_received
GO

CREATE PROCEDURE [dbo].[sp_rpt_tx_inbound_loads_received] (
	@company_id		 int
,	@profit_ctr_id	 int
,	@date_from		datetime
,	@date_to		datetime
)
AS
/*************************************************************************************************
Filename:	L:\IT Apps\SourceCode\Development\SQL\Jacqueline\DevOps task 11249 - 
							Report Create TX Inbound Loads received\sp_rpt_tx_inbound_loads_received.aql
PB Object(s):	r_tx_inbound_loads_received
Loads to:		PlT_AI
	
06/28/219	JXM  Created				   
					   
Purpose:  Inbound loads received with Texas state specific generator, transporter and waste code details.

sp_rpt_tx_inbound_loads_received 46, 0, '2019/01/02', '2019/01/04'	  
sp_rpt_tx_inbound_loads_received 46, 0, '2019/01/01', '2019/01/31'	  
*************************************************************************************************/
select	distinct
--        RESULTS.receipt_id --remove JXM
--,	    RESULTS.line_id --remove JXM
        RESULTS.company_id
,		RESULTS.company_name
,		RESULTS.profit_ctr_id
,		RESULTS.profit_ctr_name
--report columns to display
,		RESULTS.manifest
,		RESULTS.generator_name
,		RESULTS.generator_id
,		RESULTS.texas_waste_code 
,       RESULTS.waste_codes_desc as waste_description
,		RESULTS.receipt_date
,       IsNull( case when RESULTS.total_gallons <= 1   then   (RESULTS.total_gallons *  (select pound_conv from billunit where  bill_unit_code = 'DM01') /2000)
			 when RESULTS.total_gallons <= 2   then   (RESULTS.total_gallons *  (select pound_conv from billunit where  bill_unit_code = 'DM02') /2000)
			 when RESULTS.total_gallons <= 2.5 then   (RESULTS.total_gallons *  (select pound_conv from billunit where  bill_unit_code = 'DMX2') /2000)
			 when RESULTS.total_gallons <= 5   then   (RESULTS.total_gallons *  (select pound_conv from billunit where  bill_unit_code = 'DM05') /2000)
			 when RESULTS.total_gallons <= 6   then   (RESULTS.total_gallons *  (select pound_conv from billunit where  bill_unit_code = 'DM06') /2000)
			 when RESULTS.total_gallons <= 10   then   (RESULTS.total_gallons * (select pound_conv from billunit where  bill_unit_code = 'DM10') /2000)
			 when RESULTS.total_gallons <= 12   then   (RESULTS.total_gallons * (select pound_conv from billunit where  bill_unit_code = 'DM12') /2000)
			 when RESULTS.total_gallons <= 15   then   (RESULTS.total_gallons * (select pound_conv from billunit where  bill_unit_code = 'DM15') /2000)
			 when RESULTS.total_gallons <= 16   then   (RESULTS.total_gallons * (select pound_conv from billunit where  bill_unit_code = 'DM16') /2000)
		 	 when RESULTS.total_gallons <= 20   then   (RESULTS.total_gallons * (select pound_conv from billunit where  bill_unit_code = 'DM20') /2000)
			 when RESULTS.total_gallons <= 25   then   (RESULTS.total_gallons * (select pound_conv from billunit where  bill_unit_code = 'DM25') /2000)
			 when RESULTS.total_gallons <= 30   then   (RESULTS.total_gallons * (select pound_conv from billunit where  bill_unit_code = 'DM30') /2000)
			 when RESULTS.total_gallons <= 35   then   (RESULTS.total_gallons * (select pound_conv from billunit where  bill_unit_code = 'DM35') /2000)
			 when RESULTS.total_gallons <= 40   then   (RESULTS.total_gallons * (select pound_conv from billunit where  bill_unit_code = 'DM40') /2000)
			 when RESULTS.total_gallons <= 45   then   (RESULTS.total_gallons * (select pound_conv from billunit where  bill_unit_code = 'DM45') /2000)
			 when RESULTS.total_gallons <= 50   then   (RESULTS.total_gallons * (select pound_conv from billunit where  bill_unit_code = 'DM50') /2000)
			 when RESULTS.total_gallons <= 55   then   (RESULTS.total_gallons * (select pound_conv from billunit where  bill_unit_code = 'DM55') /2000)
			 when RESULTS.total_gallons <= 75   then   (RESULTS.total_gallons * (select pound_conv from billunit where  bill_unit_code = 'DM75') /2000)
			 when RESULTS.total_gallons <= 85   then   (RESULTS.total_gallons * (select pound_conv from billunit where  bill_unit_code = 'DM85') /2000)
			 when RESULTS.total_gallons <= 95   then   (RESULTS.total_gallons * (select pound_conv from billunit where  bill_unit_code = 'DM95') /2000)
			 when RESULTS.total_gallons <= 100  then   (RESULTS.total_gallons * (select pound_conv from billunit where  bill_unit_code = 'D100') /2000)
			 when RESULTS.total_gallons <= 110  then   (RESULTS.total_gallons * (select pound_conv from billunit where  bill_unit_code = 'D110') /2000)
			 else /* RESULTS.total_gallons > 110 then */ ((RESULTS.total_gallons * 8.34)/2000)
		end, 0) as weight_in_tons
,       RESULTS.transporter_code 
,       RESULTS.transporter_name 
,       RESULTS.approval_code
,       IsNull(RESULTS.volume_in_gallons,0)
,       IsNull(RESULTS.wash_water_qty,0)
FROM ( 	SELECT DISTINCT
--		    Receipt.Receipt_id --remove JXM
--		,	Receipt.Line_id --remove JXM
			Receipt.company_id
		,	Company.Company_name
		,	Receipt.profit_ctr_id
		,	ProfitCenter.profit_ctr_name
		,	Receipt.manifest   
		,	Generator.generator_name
		,	Receipt.generator_id
		,   ( SELECT SUBSTRING(LTRIM(RTRIM(ISNULL(WC.Display_Name,''))), 1, 8)
					 FROM ReceiptWasteCode RWC
					 JOIN WasteCode WC
					   ON RWC.Waste_Code_Uid = WC.Waste_Code_Uid
					WHERE RWC.Receipt_ID = Receipt.Receipt_ID 
					  AND RWC.Company_ID = Company.Company_ID
					  AND RWC.Profit_Ctr_ID = ProfitCenter.Profit_Ctr_ID
					  AND RWC.Line_ID = Receipt.Line_ID
					  AND WC.State = 'TX'
					  AND WC.Display_Name like '%1'
					  AND IsNull(RWC.Sequence_ID,1) = ( SELECT IsNull( min(RWC.Sequence_ID),1 ) 
														  FROM ReceiptWasteCode RWC
														  JOIN WasteCode WC 
															ON RWC.Waste_Code_Uid = WC.Waste_Code_Uid
														 WHERE RWC.Receipt_ID = Receipt.Receipt_ID 
														   AND RWC.Company_ID = Company.Company_ID
														   AND RWC.Profit_Ctr_ID = ProfitCenter.Profit_Ctr_ID
														   AND RWC.Line_ID = Receipt.Line_ID
														   AND WC.State = 'TX'
														   AND IsNull(WC.Display_Name,WC.Display_Name) like '%1'
														) ) AS texas_waste_code 
		,   (SELECT WC.waste_code_desc
					 FROM ReceiptWasteCode RWC
					 JOIN WasteCode WC
					   ON RWC.Waste_Code_Uid = WC.Waste_Code_Uid
					WHERE RWC.Receipt_ID = Receipt.Receipt_ID 
					  AND RWC.Company_ID = Company.Company_ID
					  AND RWC.Profit_Ctr_ID = ProfitCenter.Profit_Ctr_ID
					  AND RWC.Line_ID = Receipt.Line_ID
					  AND WC.State = 'TX'
					  AND WC.Display_Name like '%1') AS waste_codes_desc
		,	Receipt.receipt_date
		,   CAST( ( dbo.fn_calculated_gallons(Company.Company_ID,ProfitCenter.Profit_Ctr_ID,Receipt.Receipt_ID,Receipt.Line_ID,ContainerDestination.container_id,ContainerDestination.sequence_id) ) AS NUMERIC(18,4)) AS total_gallons 
		,   Transporter.transporter_code
		,   Transporter.transporter_name
		,   Receipt.approval_code
		,   CAST( ( dbo.fn_calculated_gallons(Company.Company_ID,ProfitCenter.Profit_Ctr_ID,Receipt.Receipt_ID,Receipt.Line_ID,null,null) ) AS NUMERIC(18,4)) AS volume_in_gallons 
		,   CASE WHEN Receipt.trans_type = 'W' THEN Receipt.quantity ELSE 0 END as wash_water_qty 
		, ContainerDestination.container_id
		, ContainerDestination.sequence_id
		FROM Receipt
		  LEFT OUTER JOIN Company   
			  on Receipt.Company_ID = Company.Company_ID
			  AND Company.Company_ID = @company_id
		  LEFT OUTER JOIN Generator  
			  on Receipt.Generator_ID = Generator.Generator_ID
			 --AND Generator.Generator_State = 'TX' suggested by oswin
		  LEFT OUTER JOIN ProfitCenter  
			  on Receipt.Company_ID = ProfitCenter.Company_ID
			  AND Receipt.Profit_Ctr_ID = ProfitCenter.Profit_Ctr_ID
		  --LEFT OUTER JOIN Transporter   suggested by oswin
		  JOIN Transporter
			  on Receipt.Hauler = Transporter.Transporter_Code
         INNER JOIN ContainerDestination
			 on ContainerDestination.Profit_Ctr_ID = Receipt.Profit_Ctr_ID
			 AND ContainerDestination.Receipt_ID = Receipt.Receipt_ID
			 AND ContainerDestination.Line_ID = Receipt.Line_ID
		JOIN TSDF T --add suggested by oswin
             on T.eq_company = @company_id
			AND T.eq_profit_ctr = @profit_ctr_id
			AND T.tsdf_status = 'A'
			AND T.eq_flag = 'T'
			AND T.tsdf_state = 'TX'		
		WHERE 
			 Receipt.Company_ID = @company_id 
		AND	 Receipt.Profit_Ctr_ID = @profit_ctr_id
		AND	 Receipt.Receipt_Date between @date_from and @date_to 
		AND  Receipt.trans_mode = 'I'
		AND  Receipt.Receipt_Status not in('V', 'R')
		AND  Receipt.Fingerpr_Status not in('V', 'R')
		AND  ( ( select IsNull(ProfitCenter.calculated_gallons_flag,'F') 
				   from ProfitCenter 
				  where ProfitCenter.Company_ID = Receipt.Company_ID
					and ProfitCenter.profit_ctr_id = Receipt.Profit_Ctr_ID
			 ) = 'T') 
		) RESULTS
WHERE  RESULTS.texas_waste_code is not null
ORDER BY RESULTS.Receipt_Date ASC, RESULTS.texas_waste_code

GO

GRANT EXECUTE
	ON [dbo].[sp_rpt_tx_inbound_loads_received]
	TO [EQAI]
GO


