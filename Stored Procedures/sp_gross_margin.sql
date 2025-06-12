SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[sp_gross_margin] 
	@company_id		int
,	@profit_ctr_id	int
,	@date_from		datetime
,	@date_to		datetime
,	@cust_id_from	int
,	@cust_id_to		int
,	@territory_code	char(2)
,	@generator_id_from  int  
,	@generator_id_to int
,   @d365_project   varchar(40)
,	@gross_margin_percent_from int	
,   @gross_margin_percent_to int
,	@submitted_flag  char(1)
AS
/***************************************************************************************
This SP calculates prices and costs for workorders and shows gross margin.

Filename:	L:\Apps\SQL\EQAI\sp_gross_margin.sql
PB Object(s):	r_gross_margin

06/19/1999 SCC	Created
09/24/1999 LJT	Removed Group Totals - put the detail back in their origal categories.
11/20/2000 SCC	Added territory code argument
02/22/2001 SCC	Workorder Merge changes
03/31/2004 JDB	Fixed disposal cost calculation by adding "AND wod.bill_rate >= 0" to
		exclude costs from manifest only disposal lines.
12/30/2004 SCC  Changed Ticket to Billing
04/17/2007 SCC  Changed to use WorkorderHeader.submitted_flag and CustomerBilling.territory_code
11/02/2007 rg   revised isnull tests on computed fields to be more accurate
02/18/2008 rg   moved billing trans source condition from where clause to join criteria for billing 
                table in the final select so it will be a true outer join.
10/20/2010 SK	Added company_id as input argument, 
				Moved to Plt_AI
10/24/2012 LJT	Added company_id to where clause in sub selects and moved the disposal select to workorderdetailunit.
01/15/2016 AM   Added generator_id as input argument.
05/15/2017 AM   Added ISNULL to generator_id in where clause.
04/26/2021 AM DevOps:20698 - Added is null check to cust_discount and added calc lagic to get total_price and total_cost values.
04/04/2022 GDE DevOps:38986 - Added as output -Generator Name,Generator EPA ID #,Reference Code,Project # 
05/12/2022 GDE DevOps: 41922 - 'Margin/Gross Margin Average Less Than 30%' Report Additions (2)
03/21/2023 AM DevOps:63030 - Added ISNULL(woh.generator_id,0) check in generator join
09/29/2023 AM DevOps:72764 - Added new columns and few changes to sp.
11/07/2023 AM DevOps:74350 - When submitted flag is F then Run for all transactions.When submitted flag T then run for only submitted transactions.

EXEC sp_gross_margin 14, 04, '12/01/2007','12/31/2007', 1, 999999, '99',1, 999999

****************************************************************************************/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

CREATE TABLE #wo (
	company_id			int		NULL
,	profit_ctr_id		int		NULL
,	workorder_id		int		NULL
,	workorder_status	char(1) NULL
,	total_price			money	NULL
,	total_cost			money	NULL
,	customer_id			int		NULL
--,	cust_discount		float	NULL DevOps:72764
,	price_equipment		money	NULL
,	price_labor			money	NULL
,	price_supplies		money	NULL
,	price_disposal		money	NULL
,	price_group			money	NULL
,	price_other			money	NULL
,	cost_equipment		money	NULL
,	cost_labor			money	NULL
,	cost_supplies		money	NULL
,	cost_disposal		money	NULL
,	cost_other			money	NULL
,	generator_name		varchar(75) NULL
,	reference_code		varchar(32) NULL
,	AX_Dimension_5_Part_1  varchar(20)     NULL
,   AX_Dimension_5_Part_2 varchar(9) NULL
,	epa_id				varchar(12) NULL
,	fixed_price_flag	char(1) NULL
,	generator_id        int NULL
,	workorder_desc	    varchar(255) NULL
,	gross_margin_amount  money	NULL
,	gross_margin_percent  money	NULL
)

-- DevOps:74350 - When submitted flag is F then Run for all transactions.
IF @submitted_flag = 'F' SET @submitted_flag = 'A'

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
--,	isnull(woh.cust_discount,0) DevOps:72764
,	price_equipment = ISNULL((SELECT SUM( isnull(quantity_used,0) * isnull(price,0) ) FROM workorderDetail wod 
								WHERE woh.workorder_id = wod.workorder_id 
								AND	woh.company_id = wod.company_id 
								AND woh.profit_ctr_id = wod.profit_ctr_id 
									AND wod.bill_rate > 0 
									AND wod.resource_type = 'E'), 0)
,	price_labor = ISNULL((SELECT SUM( isnull(quantity_used,0) * isnull(price,0) ) FROM workorderDetail wod 
							WHERE woh.workorder_id = wod.workorder_id 
								AND	woh.company_id = wod.company_id 
								AND woh.profit_ctr_id = wod.profit_ctr_id 
								AND wod.bill_rate > 0 
								AND wod.resource_type = 'L'), 0)
,	price_supplies = ISNULL((SELECT SUM( isnull(quantity_used,0) * isnull(price,0) ) FROM workorderDetail wod 
								WHERE woh.workorder_id = wod.workorder_id 
								AND	woh.company_id = wod.company_id 
								AND woh.profit_ctr_id = wod.profit_ctr_id 
									AND wod.bill_rate > 0 
									AND wod.resource_type = 'S'), 0)
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
									AND wod.bill_rate > 0 
									AND wodu.billing_flag = 'T'
									AND wod.resource_type = 'D'), 0)
,	price_group = 0
,	price_other = ISNULL((SELECT SUM(isnull(quantity_used,0) * isnull(price,0) ) FROM workorderDetail wod 
							WHERE woh.workorder_id = wod.workorder_id 
								AND	woh.company_id = wod.company_id 
								AND woh.profit_ctr_id = wod.profit_ctr_id 
								AND wod.bill_rate > 0
								AND wod.resource_type = 'O'), 0)
,	cost_equipment = ISNULL((SELECT SUM( isnull(quantity_used,0) * isnull(cost,0) ) FROM workorderDetail wod 
								WHERE woh.workorder_id = wod.workorder_id 
								AND	woh.company_id = wod.company_id 
								AND woh.profit_ctr_id = wod.profit_ctr_id 
									AND wod.resource_type = 'E'), 0)
,	cost_labor = ISNULL((SELECT SUM( isnull(quantity_used,0) * isnull(cost,0) ) FROM workorderDetail wod 
							WHERE woh.workorder_id = wod.workorder_id 
								AND	woh.company_id = wod.company_id 
								AND woh.profit_ctr_id = wod.profit_ctr_id 
								AND wod.resource_type = 'L'), 0)
,	cost_supplies = ISNULL((SELECT SUM( isnull(quantity_used,0) * isnull(cost,0) ) FROM workorderDetail wod 
								WHERE woh.workorder_id = wod.workorder_id 
								AND	woh.company_id = wod.company_id 
								AND woh.profit_ctr_id = wod.profit_ctr_id 
									AND wod.resource_type = 'S'), 0)
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
									AND wod.bill_rate >= 0), 0)	-- Skip cost on manifest only disposal lines
,	cost_other = ISNULL((SELECT SUM( isnull(quantity_used,0) * isnull(cost,0) ) FROM workorderDetail wod 
							WHERE woh.workorder_id = wod.workorder_id 
								AND	woh.company_id = wod.company_id 
								AND woh.profit_ctr_id = wod.profit_ctr_id 
								AND wod.resource_type = 'O'), 0)
,	Generator.generator_name  
,	woh.reference_code
,	woh.AX_Dimension_5_Part_1 
,   woh.AX_Dimension_5_Part_2  
,	Generator.EPA_ID
,   woh.fixed_price_flag
,	Generator.generator_id
,	woh.description
,	0
,   0
FROM workorderheader woh
INNER JOIN CustomerBilling 
	ON CustomerBilling.customer_id = woh.customer_id
	AND CustomerBilling.billing_project_id = ISNULL(woh.billing_project_id, 0)
	AND ((@territory_code = '99') OR (CustomerBilling.territory_code = @territory_code))
INNER JOIN Generator
	 ON ISNULL ( woh.generator_id,0)=Generator.generator_id

WHERE	(@company_id = 0 OR woh.company_id = @company_id)	
	AND (@company_id = 0 OR @profit_ctr_id = -1 OR woh.profit_ctr_id = @profit_ctr_id)
	--AND	woh.workorder_status = 'A' -- DevOps:72764
	--AND ISNULL(woh.submitted_flag, 'F') = 'T' DevOps:72764
	AND woh.end_date BETWEEN @date_from AND @date_to
	AND woh.customer_id BETWEEN @cust_id_from AND @cust_id_to
	--AND woh.generator_id BETWEEN @generator_id_from AND @generator_id_to
	AND ( woh.generator_id BETWEEN @generator_id_from AND @generator_id_to OR ISNULL (woh.generator_id , 0 ) = 0  )
	--AND ((@territory_code = '99') OR (CustomerBilling.territory_code = @territory_code))
	AND    woh.workorder_status not in ('v', 't', 'x') -- DevOps:72764
	AND ( ( @d365_project =  'ALL' ) OR ( @d365_project = CONCAT(woh.AX_Dimension_5_Part_1, (Case when  AX_Dimension_5_Part_2 is null OR AX_Dimension_5_Part_2 ='' then '' else '-' end) ) ) )
	AND ( ( IsNull(@submitted_flag, 'F') = 'F')  OR woh.submitted_flag = @submitted_flag OR ( @submitted_flag =  'A' ) )  

-- DevOps:72764
update #wo
set  gross_margin_amount = 	( case when #wo.fixed_price_flag = 'T' then
         (#wo.total_price - #wo.total_cost )
	     when #wo.fixed_price_flag is null or #wo.fixed_price_flag = 'F' then
        (#wo.price_equipment + #wo.price_labor + #wo.price_supplies + #wo.price_disposal + #wo.price_group + #wo.price_other) - (#wo.cost_equipment + #wo.cost_labor + #wo.cost_supplies + #wo.cost_disposal + #wo.cost_other) end )
,  gross_margin_percent =  ( case when #wo.fixed_price_flag = 'T' then
									( case when #wo.total_price > 0 then
									  (1-((#wo.cost_equipment + #wo.cost_labor + #wo.cost_supplies + #wo.cost_disposal + #wo.cost_other) / (#wo.total_price))) * 100
                                          when (#wo.total_price = 0) then 0 end )
	                        when #wo.fixed_price_flag is null or #wo.fixed_price_flag = 'F' then
						       	    ( case when (#wo.price_equipment + #wo.price_labor + #wo.price_supplies + #wo.price_disposal + #wo.price_group + #wo.price_other) > 0 then
									 (1-((#wo.cost_equipment + #wo.cost_labor + #wo.cost_supplies + #wo.cost_disposal + #wo.cost_other) / (#wo.price_equipment + #wo.price_labor + #wo.price_supplies + #wo.price_disposal + #wo.price_group + #wo.price_other))) * 100
									       when (#wo.price_equipment + #wo.price_labor + #wo.price_supplies + #wo.price_disposal + #wo.price_group + #wo.price_other ) = 0 then 0 end ) end ) 
FROM workorderheader woh
where #wo.workorder_id = woh.workorder_ID

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
--,	#wo.cust_discount DevOps:72764
,	price_equipment = (case when  #wo.fixed_price_flag = 'T' then 0 else #wo.price_equipment end ) --price_equipment * ((100 - #wo.cust_discount) / 100)
,	price_labor = (case when  #wo.fixed_price_flag = 'T' then 0 else #wo.price_labor end ) --price_labor * ((100 - #wo.cust_discount) / 100)
,	price_supplies = (case when  #wo.fixed_price_flag = 'T' then 0 else #wo.price_supplies end ) -- price_supplies * ((100 - #wo.cust_discount) / 100)
,	price_disposal = (case when  #wo.fixed_price_flag = 'T' then 0 else #wo.price_disposal end ) --price_disposal * ((100 - #wo.cust_discount) / 100)
,	price_group = (case when  #wo.fixed_price_flag = 'T' then 0 else #wo.price_group end ) -- price_group * ((100 - #wo.cust_discount) / 100)
,	price_other = (case when  #wo.fixed_price_flag = 'T' then 0 else #wo.price_other end ) --price_other * ((100 - #wo.cust_discount) / 100)
,	(price_equipment + price_labor + price_supplies + price_disposal + price_group + price_other) as total_price
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
-- DevOps:72764
, gross_margin_amount
, gross_margin_percent
, #wo.generator_id
, #wo.workorder_desc
FROM #wo
JOIN Company
	ON Company.company_id = #wo.company_id
JOIN ProfitCenter
	ON ProfitCenter.company_ID = #wo.company_id
	AND ProfitCenter.profit_ctr_ID = #wo.profit_ctr_id
JOIN Customer 
	ON Customer.customer_id  = #wo.customer_id
LEFT OUTER JOIN Billing 
	ON Billing.company_id = #wo.company_id
	AND Billing.profit_ctr_id = #wo.profit_ctr_id
	AND Billing.receipt_id = #wo.workorder_id
	AND Billing.trans_source = 'W'
WHERE 1 = 1
AND  ( #wo.gross_margin_percent BETWEEN @gross_margin_percent_from AND @gross_margin_percent_to OR ( ISNULL (@gross_margin_percent_from , 0 ) = 0 AND ISNULL (@gross_margin_percent_to , 0 ) = 0 ) )
ORDER BY customer.cust_name, D365_Project_id, company_id, profit_ctr_id, workorder_id 

DROP TABLE #wo

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_gross_margin] TO [EQAI]

GO
