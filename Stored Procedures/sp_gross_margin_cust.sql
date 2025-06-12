/****** Object:  StoredProcedure [dbo].[sp_gross_margin_cust]    Script Date: 4/5/2022 11:42:29 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[sp_gross_margin_cust] 
	@company_id		int
,	@profit_ctr_id	int
,	@date_from		datetime
,	@date_to		datetime
,	@cust_id_from	int
,	@cust_id_to		int
,	@territory_code	char(2)
AS
/***************************************************************************************
This SP calculates the gross margin per workorder and shows customers that average
30% less than gross margin.

Filename:	L:\Apps\SQL\EQAI\sp_gross_margin_cust.sql
PB Object(s):	r_gross_margin_cust

11/27/2000 SCC	Created
12/22/2000 LJT	Modified to calculate the gross margin for a customer instead of
		averaging the gross margin for each workorder.
03/31/2004 JDB	Fixed disposal cost calculation by adding "AND wod.bill_rate >= 0" to
		exclude costs from manifest only disposal lines.
12/30/2004 SCC  Changed Ticket to Billing
03/16/2006 rg   wrapped calc for #cust table in case to avoid devide by zero 
04/17/2007 SCC  Changed to use WorkorderHeader.submitted_flag and CustomerBilling.territory_code
11/01/2007 rg   removed decmial data type from gross_margin and replaced with money
                to avoid arithematic overflow.  Also removed isnull on sum and replaced on columns instead.
10/22/2010 SK	Added company_id as input argument, 
				Moved to Plt_AI
10/24/2012 LJT	Added company_id to where clause in sub selects and moved the disposal select to workorderdetailunit.
04/26/2021 AM DevOps:20698 - Added is null check to cust_discount and added calc lagic to get total_price and total_cost values.
04/04/2022 GDE DevOps:38986 - Added as output -Generator Name,Generator EPA ID #,Reference Code,Project # 
05/12/2022 GDE DevOps: 41922 - 'Margin/Gross Margin Average Less Than 30%' Report Additions (2)
12/19/2022 DBS DevOps: 41665: Report - Gross Margin less than 30% has incorrect status in Excel export  
03/21/2023 AM DevOps:63030 - Added ISNULL(woh.generator_id,0) check in generator join

sp_gross_margin_cust 14, 04, '12/01/2007','12/31/2007', 1, 999999, '99'
****************************************************************************************/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

CREATE TABLE #wo (
	company_id			int		NULL
,	profit_ctr_id		int		NULL
,	workorder_id 		int 	NULL
,	workorder_status	char(1) NULL
,	total_price 		money 	NULL
,	total_cost 			money 	NULL
,	customer_id 		int 	NULL
,	cust_discount		float 	NULL
,	price_equipment		money 	NULL
,	price_labor 		money 	NULL
,	price_supplies 		money 	NULL
,	price_disposal 		money 	NULL
,	price_group 		money 	NULL
,	price_other 		money 	NULL
,	cost_equipment 		money 	NULL
,	cost_labor 			money 	NULL
,	cost_supplies 		money 	NULL
,	cost_disposal 		money 	NULL
,	cost_other 			money 	NULL
,	gross_margin 		money   NULL
,	generator_name		varchar(75) NULL
,	reference_code		varchar(32) NULL
,	AX_Dimension_5_Part_1  varchar(20)     NULL
,   AX_Dimension_5_Part_2 varchar(9) NULL
,	epa_id				varchar(12) NULL
)

create table #cust ( 
	customer_id		int		NULL
,	margin_avg		money	NULL
)

-- stuff the 'x' value in the result set since this can only run for submitted
/* Insert records */
INSERT #wo
SELECT 
	woh.company_id
,	woh.profit_ctr_id
,	woh.workorder_id
,	woh.workorder_status
,	woh.total_price
,	woh.total_cost
,	woh.customer_id
,	isnull(woh.cust_discount,0)
,	price_equipment = ISNULL((SELECT SUM( isnull(quantity_used,0) * isnull(price,0) ) FROM workorderDetail wod 
								WHERE woh.workorder_id = wod.workorder_id 
									AND	woh.company_id = wod.company_id 
									AND woh.profit_ctr_id = wod.profit_ctr_id 
									AND bill_rate > 0 
									AND wod.resource_type = 'E'),0)
,	price_labor = ISNULL((SELECT SUM( isnull(quantity_used,0) * isnull(price,0) ) FROM workorderDetail wod 
							WHERE woh.workorder_id = wod.workorder_id 
								AND	woh.company_id = wod.company_id 
								AND woh.profit_ctr_id = wod.profit_ctr_id  
								AND bill_rate > 0 
								AND wod.resource_type = 'L'),0)
,	price_supplies = ISNULL((SELECT SUM( isnull(quantity_used,0) * isnull(price,0) ) FROM workorderDetail wod 
							WHERE woh.workorder_id = wod.workorder_id 
								AND	woh.company_id = wod.company_id 
								AND woh.profit_ctr_id = wod.profit_ctr_id 								AND bill_rate > 0 
									AND wod.resource_type = 'S'),0)
,	price_disposal = ISNULL((SELECT SUM(isnull(wodu.quantity,0) * isnull(wodu.price,0) ) 
								FROM workorderDetailunit wodu 
								join workorderDetail wod
								  on wodu.company_id = wod.company_id
								 and wodu.profit_ctr_id = wod.profit_ctr_id
								 and wodu.workorder_id = wod.workorder_id
								 and wodu.sequence_id = wod.sequence_id
								WHERE woh.workorder_id = wod.workorder_id 
									AND	woh.company_id = wod.company_id 
									AND woh.profit_ctr_id = wod.profit_ctr_id 	
									AND bill_rate > 0 
									AND wodu.billing_flag = 'T'
									AND wod.resource_type = 'D'), 0)
,	price_group = 0.0
,	price_other = ISNULL((SELECT SUM(isnull(quantity_used,0) * isnull(price,0) ) FROM workorderDetail wod 
							WHERE woh.workorder_id = wod.workorder_id 
								AND	woh.company_id = wod.company_id 
								AND woh.profit_ctr_id = wod.profit_ctr_id 
								AND bill_rate > 0
								AND wod.resource_type = 'O'),0)
,	cost_equipment = ISNULL((SELECT SUM( isnull(quantity_used,0) * isnull(cost,0) ) FROM workorderDetail wod 
								WHERE woh.workorder_id = wod.workorder_id 
									AND	woh.company_id = wod.company_id 
									AND woh.profit_ctr_id = wod.profit_ctr_id 
									AND wod.resource_type = 'E'),0)
,	cost_labor = ISNULL((SELECT SUM( isnull(quantity_used,0) * isnull(cost,0)) FROM workorderDetail wod 
							WHERE woh.workorder_id = wod.workorder_id 
								AND	woh.company_id = wod.company_id 
								AND woh.profit_ctr_id = wod.profit_ctr_id 
								AND wod.resource_type = 'L'),0)
,	cost_supplies = ISNULL((SELECT SUM( isnull(quantity_used,0) * isnull(cost,0) ) FROM workorderDetail wod 
								WHERE woh.workorder_id = wod.workorder_id 
								AND	woh.company_id = wod.company_id 
								AND woh.profit_ctr_id = wod.profit_ctr_id 
									AND wod.resource_type = 'S'),0)
,	cost_disposal = ISNULL((SELECT SUM( isnull(wodu.quantity,0) * isnull(wodu.cost,0) ) 
								FROM workorderDetailunit wodu 
								join workorderDetail wod
								  on wodu.company_id = wod.company_id
								 and wodu.profit_ctr_id = wod.profit_ctr_id
								 and wodu.workorder_id = wod.workorder_id
								 and wodu.sequence_id = wod.sequence_id
								WHERE woh.workorder_id = wod.workorder_id 
								AND	woh.company_id = wod.company_id 
								AND woh.profit_ctr_id = wod.profit_ctr_id 
									AND wod.resource_type = 'D'
									AND wod.bill_rate >= 0),0)
,	cost_other = ISNULL((SELECT SUM( isnull(quantity_used,0) * isnull(cost,0) ) FROM workorderDetail wod 
							WHERE woh.workorder_id = wod.workorder_id 
								AND	woh.company_id = wod.company_id 
								AND woh.profit_ctr_id = wod.profit_ctr_id 
								AND wod.resource_type = 'O'),0)
,	CASE WHEN total_price is null or total_cost is null THEN 0
		 WHEN total_price = 0 and total_cost = 0 then 0
         WHEN total_price = 0 and total_cost <> 0 then -1
		 ELSE ((total_price -  total_cost ) /  total_price ) 
   	END AS gross_margin
,	Generator.generator_name  
,	woh.reference_code
,	woh.AX_Dimension_5_Part_1 
,   woh.AX_Dimension_5_Part_2  
,	Generator.EPA_ID
FROM workorderheader woh
JOIN CustomerBilling
	ON CustomerBilling.customer_id = woh.customer_id
	AND CustomerBilling.billing_project_id= ISNULL(woh.billing_project_id, 0)
	AND CustomerBilling.status = 'A'
	AND ((@territory_code = '99') OR (CustomerBilling.territory_code = @territory_code))
JOIN Generator
	ON ISNULL ( woh.generator_id,0)=Generator.generator_id
WHERE	(@company_id = 0 OR woh.company_id = @company_id)	
	AND (@company_id = 0 OR @profit_ctr_id = -1 OR woh.profit_ctr_id = @profit_ctr_id)
	AND woh.workorder_status = 'A'
	AND ISNULL(woh.submitted_flag,'F') = 'T'
	AND woh.end_date BETWEEN @date_from AND @date_to
	AND woh.customer_id BETWEEN @cust_id_from AND @cust_id_to

-- now convert gross_margin to a percentage
UPDATE #wo SET gross_margin = round((gross_margin * 100),2)

--IF @debug_flag = 1 PRINT 'Selecting from #wo'
--IF @debug_flag = 1 SELECT gross_margin, * FROM #wo ORDER BY customer_id
--if @debug_flag = 1 select gross_margin, total_cost, total_price, workorder_id from #wo where total_price is null or total_price = 0

-- Identify customers with average gross margin less than 30%
-- wrap comuptation to protect devide by zero
INSERT #cust
SELECT 
	customer_id
,	CASE SUM(price_equipment+price_labor+price_supplies+price_disposal+price_group+price_other)
		WHEN 0 THEN 0
		ELSE ((SUM(price_equipment+price_labor+price_supplies+price_disposal+price_group+price_other)
				- SUM(cost_equipment+cost_labor+cost_supplies+cost_disposal+cost_other))
				/ SUM(price_equipment+price_labor+price_supplies+price_disposal+price_group+price_other)) * 100
        END AS	margin_avg
FROM #wo
GROUP BY customer_id

--IF @debug_flag = 1 PRINT 'Selecting from #cust'
--IF @debug_flag = 1 SELECT * FROM #cust

-- Return only those customers with less than 30% gross margin
SELECT DISTINCT
	customer.cust_name
,	#wo.generator_name
,	#wo.epa_id
,	#wo.reference_code
,	CONCAT(#wo.AX_Dimension_5_Part_1, (Case when  AX_Dimension_5_Part_2 is null OR AX_Dimension_5_Part_2='' then '' else '-' end) , #wo.AX_Dimension_5_Part_2) AS D365_Project_id
,	workorder_status
,	workorder_id
,	Billing.invoice_code
,	#wo.customer_id
,	#wo.cust_discount
,	price_equipment = price_equipment * ((100 - #wo.cust_discount) / 100)
,	price_labor = price_labor * ((100 - #wo.cust_discount) / 100)
,	price_supplies = price_supplies * ((100 - #wo.cust_discount) / 100)
,	price_disposal = price_disposal * ((100 - #wo.cust_discount) / 100)
,	price_group = price_group * ((100 - #wo.cust_discount) / 100)
,	price_other = price_other * ((100 - #wo.cust_discount) / 100)
,   (price_equipment + price_labor + price_supplies + price_disposal + price_group + price_other) as total_price
,	cost_equipment
,	cost_labor
,	cost_supplies
,	cost_disposal
,	cost_other
,	(cost_equipment + cost_labor + cost_supplies + cost_disposal + cost_other) as total_cost 
,	#wo.company_id
,	#wo.profit_ctr_id
,	Company.company_name
,	ProfitCenter.profit_ctr_name
FROM #wo
JOIN Company
	ON Company.company_id = #wo.company_id
JOIN ProfitCenter
	ON ProfitCenter.company_ID = #wo.company_id
	AND ProfitCenter.profit_ctr_ID = #wo.profit_ctr_id
JOIN #cust
	ON #cust.customer_id = #wo.customer_id
	AND #cust.margin_avg < 30
JOIN customer
	ON customer.customer_id = #wo.customer_id
LEFT OUTER JOIN Billing
	ON Billing.company_id = #wo.company_id
	AND Billing.profit_ctr_id = #wo.profit_ctr_id
	AND Billing.receipt_id  = #wo.workorder_id
	AND Billing.trans_source = 'W'
ORDER BY customer.cust_name, workorder_status

DROP TABLE #wo
DROP TABLE #cust

GO

GRANT EXECUTE
    ON OBJECT::[dbo].[sp_gross_margin_cust] TO [EQAI]
    AS [dbo];

GO