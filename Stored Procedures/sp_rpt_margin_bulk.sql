CREATE PROCEDURE sp_rpt_margin_bulk 
	@company_id		int
,	@profit_ctr_id	int
,	@date_from 		datetime
,	@date_to 		datetime
AS
/***************************************************************************************
Rich Treatments to be selected: (1,7,29,35,43,47)
  1            Rich Fuel to Cement Kiln Bulk
  7            Processable Solids for Liquid Fuel Bulk
  29           Discretion to Blend Bulk
  35           Isocyanates Bulk
  43           Rich Fuel- Code Limits Bulk
  47           Chlorinated Fuel- Rich Bulk

Lean Treatments to be selected:(5,37,39,45,49)
  5            Lean Fuel for Thermal Destruction Bulk
  37           Acid Bulk
  39           Base Bulk
  45           Lean Fuel- Code Limits Bulk
  49           Chlorinated Fuel- Lean Bulk

01/15/2003 JDB	Created
03/28/2003 LJT	Modified
06/23/2003 JDB	Modified so that Percent_margin is not dividing by zero.
11/11/2004 MK	Changed generator_code to generator_id
11/19/2004 JDB	Changed ticket_id to line_id
01/06/2005 SCC	Changed for multiple receipt prices
11/12/2010 SK	Added company_id as input arg, added joins to company
				moved to Plt_AI

sp_rpt_margin_bulk 2, -1, '2003-02-01', '2003-03-31'
****************************************************************************************/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED


SELECT DISTINCT 
	r.receipt_date
,	g.generator_name
,	r.generator_id
,	r.manifest
,	total_gallons = ISNULL(r.quantity, 0.00)*b.gal_conv
,	r.container_count
,	gallon_pct_of_load = ISNULL(((ISNULL(r.quantity, 0.00)*b.gal_conv / 
							(select SUM(ISNULL(r2.quantity, 0.00)*b2.gal_conv)
								from receipt r2, billunit B2 
								where r2.receipt_id = r.receipt_id 
								 and r2.bill_unit_code = b2.bill_unit_code
								 and r2.trans_type = 'D' 
								 and r2.company_id = r.company_id
								 and r2.profit_ctr_id = r.profit_ctr_id
								 and r2.receipt_status not in ('T', 'R','V')))), 0.00)
,	total_cost_misc = (select ISNULL(sum(RP.total_extended_amt),0.00)             
						from receipt r2 , ReceiptPrice RP
						where r2.receipt_id = r.receipt_id 
							and r2.trans_type = 'S' 
							and r2.receipt_status not in ('T', 'R','V')
							and r2.profit_ctr_id = r.profit_ctr_id
							and r2.company_id = r.company_id
							and r2.receipt_id = RP.receipt_id
							and r2.line_id = RP.line_id
							and r2.company_id = RP.company_id
							and r2.profit_ctr_id = RP.profit_ctr_id )
,	invoice_amount = ISNULL(ReceiptPrice.total_extended_amt, 0.00)
,	r.manifest_comment AS comments
,	r.receipt_id
,	r.line_id
,	r.approval_code
,	r.bill_unit_code
,	r.bulk_flag
,	r.treatment_id
,	r.location
,	r.receipt_status
,	r.company_id
,	r.profit_ctr_id
INTO #reportdata
FROM receipt r
JOIN ReceiptPrice 
	ON r.receipt_id = ReceiptPrice.receipt_id 
	AND r.line_id = ReceiptPrice.line_id 
	AND r.profit_ctr_id = ReceiptPrice.profit_ctr_id 
	AND r.company_id = ReceiptPrice.company_id
INNER JOIN billunit b 
	ON r.bill_unit_code = b.bill_unit_code
INNER JOIN generator g 
	ON r.generator_id = g.generator_id
WHERE (@company_id = 0 OR r.company_id = @company_id)	
	AND (@company_id = 0 OR @profit_ctr_id = -1 OR r.profit_ctr_id = @profit_ctr_id)
	AND r.trans_mode = 'I'
	AND r.trans_type = 'D'
	AND r.bulk_flag = 'T'
	AND r.receipt_status NOT IN ('T', 'V')
	AND r.receipt_date BETWEEN @date_from AND @date_to
	AND r.treatment_id IN (1,7,29,35,43,47,5,37,39,45,49)


SELECT DISTINCT 
	receipt_date
,	generator_name
,	generator_id
,	manifest
,	total_gallons
,	container_count
,	lean_fuel = (CASE WHEN treatment_id in (05,37,39,45,49) THEN total_gallons ELSE 0 END)
,	rich_fuel = (CASE WHEN treatment_id in (01,07,29,35,43,47) THEN total_gallons ELSE 0 END)
,	unloading_time_min = total_gallons / 200 
,	unloading_time_hour = (total_gallons / 200) / 60 
,	cost_lab = (((total_gallons / 5000) * 17) + 17.00)* gallon_pct_of_load
,	cost_process = (((total_gallons / 200) / 60) * 68 )+ ((total_gallons / 5000) * 68 * 0.75)
,	cost_misc =  total_cost_misc * gallon_pct_of_load
,	cost_disposal = (CASE WHEN treatment_id in (01,07,29,35,43,47) THEN total_gallons * 0.45 
						  WHEN treatment_id in (05,37,39,45,49) THEN total_gallons * 0.605
                          ELSE 0 END)
,	cost_total = (CASE WHEN treatment_id in (01,07,29,35,43,47) THEN (total_gallons * 0.45) + (total_cost_misc * gallon_pct_of_load)
																	+ ((((total_gallons / 5000) * 17) + 17.00)* gallon_pct_of_load)
																	+ (((total_gallons / 200) / 60) * 68 )+ ((total_gallons / 5000) * 68 * 0.75)
                       WHEN  treatment_id in (05,37,39,45,49) THEN (total_gallons * 0.605) + (total_cost_misc * gallon_pct_of_load)
																	+ ((((total_gallons / 5000) * 17) + 17.00)* gallon_pct_of_load)
																	+ (((total_gallons / 200) / 60) * 68 )+ ((total_gallons / 5000) * 68 * 0.75)
                       ELSE 0 END)
,	cost_total_gallon = (CASE WHEN treatment_id in (01,07,29,35,43,47) THEN ((total_gallons * 0.45) + (total_cost_misc * gallon_pct_of_load)
																		 + ((((total_gallons / 5000) * 17) + 17.00)* gallon_pct_of_load)
																		 + (((total_gallons / 200) / 60) * 68 )+ ((total_gallons / 5000) * 68 * 0.75))
																	   / (total_gallons)
                              WHEN  treatment_id in (05,37,39,45,49) THEN ((total_gallons * 0.605) + (total_cost_misc * gallon_pct_of_load)
																		 + ((((total_gallons / 5000) * 17) + 17.00)* gallon_pct_of_load)
																		 + (((total_gallons / 200) / 60) * 68) + ((total_gallons / 5000) * 68 * 0.75))
																	   / ( total_gallons)
                              ELSE 0 END)
,	invoice_amount = (invoice_amount + (total_cost_misc * gallon_pct_of_load))
,	price_gallon = ((invoice_amount + (total_cost_misc * gallon_pct_of_load)) / total_gallons)
,	total_margin = (invoice_amount + (total_cost_misc * gallon_pct_of_load)) 
                  -  (CASE WHEN treatment_id in (01,07,29,35,43,47) THEN (total_gallons * 0.45) + (total_cost_misc * gallon_pct_of_load)
																	  + ((((total_gallons / 5000) * 17) + 17.00)* gallon_pct_of_load)
																	  + ((((total_gallons / 200) / 60) * 68 )+ ((total_gallons / 5000) * 68 * 0.75))
                           WHEN  treatment_id in (05,37,39,45,49) THEN (total_gallons * 0.605) + (total_cost_misc * gallon_pct_of_load)
																	  + ((((total_gallons / 5000) * 17) + 17.00)* gallon_pct_of_load)
																	  + ((((total_gallons / 200) / 60) * 68 )+ ((total_gallons / 5000) * 68 * 0.75))
                           ELSE 0 END)
,	Percent_margin = (CASE WHEN invoice_amount + (total_cost_misc * gallon_pct_of_load) = 0 THEN 0
						   ELSE (1 - (CASE	WHEN treatment_id in (01,07,29,35,43,47) THEN (total_gallons * 0.45) + (total_cost_misc * gallon_pct_of_load)
																					  + ((((total_gallons / 5000) * 17) + 17.00)* gallon_pct_of_load)
																					  + ((((total_gallons / 200) / 60) * 68 )+ ((total_gallons / 5000) * 68 * 0.75))
											WHEN  treatment_id in (05,37,39,45,49) THEN (total_gallons * 0.605) + (total_cost_misc * gallon_pct_of_load)
																					  + ((((total_gallons / 5000) * 17) + 17.00)* gallon_pct_of_load)
																					  + ((((total_gallons / 200) / 60) * 68 )+ ((total_gallons / 5000) * 68 * 0.75))
											ELSE 0 END)
								/ (invoice_amount + (total_cost_misc * gallon_pct_of_load))) END)
,	comments
,	receipt_id
,	line_id
,	approval_code
,	bill_unit_code
,	bulk_flag
,	treatment_id
,	location
,	receipt_status
,	#reportdata.company_id
,	#reportdata.profit_ctr_id
,	Company.company_name
,	ProfitCenter.profit_ctr_name
FROM #reportdata
JOIN Company
	ON Company.company_id = #reportdata.company_id
JOIN ProfitCenter
	ON ProfitCenter.company_ID = #reportdata.company_id
	AND ProfitCenter.profit_ctr_ID = #reportdata.profit_ctr_id

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_margin_bulk] TO [EQAI]
    AS [dbo];

