
CREATE PROCEDURE sp_emails_and_volumes
	
AS
declare @start_date datetime = '1/1/2012', @end_date  datetime = '12/31/2012 23:59'


select customer_id, generator_id, sum(isnull(lbs_haz_actual, 0)) as sum_weight
INTO #temp_list
FROM 
(
-- Get the weights on the Inbound containers
      select DISTINCT
            Receipt.Customer_ID,
            Receipt.Generator_ID,
            
            lbs_haz_actual = COALESCE
            (
                  CASE WHEN ISNULL(Container.container_weight, 0) > 0 THEN
                        ISNULL(Container.container_weight, 0) * (IsNull(ContainerDestination.container_percent, 0) / 100.000)
                  END,
                  CASE WHEN ISNULL(
                  /* receipt.line_weight */ dbo.fn_line_weight_or_better(receipt.receipt_id, receipt.line_id, receipt.company_id, receipt.profit_ctr_id, receipt.line_weight)
                  , 0) > 0 THEN (/* receipt.line_weight */ dbo.fn_line_weight_or_better(receipt.receipt_id, receipt.line_id, receipt.company_id, receipt.profit_ctr_id, receipt.line_weight) / receipt.container_count) * (IsNull(ContainerDestination.container_percent, 0) / 100.000) END,
                  CASE WHEN receipt.manifest_unit = 'P' THEN (receipt.manifest_quantity / receipt.container_count) * (IsNull(ContainerDestination.container_percent, 0) / 100.000) END,
                  CASE WHEN EXISTS (SELECT 1 FROM ReceiptPrice rp (nolock)
                        WHERE receipt.receipt_id = rp.receipt_id
                        AND receipt.company_id = rp.company_id
                        AND receipt.profit_ctr_id = rp.profit_ctr_id
                        AND receipt.line_id = rp.line_id
                        AND rp.bill_unit_code IN('LBS','TONS')
                  ) THEN (SELECT 
                                    CASE 
                                          WHEN rp.bill_unit_code = 'LBS' THEN (SUM(rp.bill_quantity) / receipt.container_count) * (IsNull(ContainerDestination.container_percent, 0) / 100.000)
                                          WHEN rp.bill_unit_code = 'TONS' THEN ((SUM(rp.bill_quantity) * 2000) / receipt.container_count) * (IsNull(ContainerDestination.container_percent, 0) / 100.000)
                                    END 
                        FROM ReceiptPrice rp (nolock)
                        WHERE receipt.receipt_id = rp.receipt_id
                        AND receipt.company_id = rp.company_id
                        AND receipt.profit_ctr_id = rp.profit_ctr_id
                        AND receipt.line_id = rp.line_id
                        AND rp.bill_unit_code IN('LBS','TONS')
                        GROUP BY rp.bill_unit_code
                  )
                        END
            )
      FROM Receipt (nolock)
            JOIN Container WITH(NOLOCK) ON (Receipt.company_id = Container.company_id 
                  AND Receipt.profit_ctr_id = Container.profit_ctr_id 
                  AND Receipt.receipt_id = Container.receipt_id 
                  AND Receipt.line_id = Container.line_id
                  AND Receipt.profit_ctr_id = Container.profit_ctr_id
                  AND Receipt.company_id = Container.company_id)
            JOIN ContainerDestination WITH(NOLOCK)  ON (Container.company_id = ContainerDestination.company_id
                  AND Container.profit_ctr_id = ContainerDestination.profit_ctr_id
                  AND Container.receipt_id = ContainerDestination.receipt_id 
                  AND Container.line_id = ContainerDestination.line_id
                  AND Container.container_id = ContainerDestination.container_id)
      WHERE 1=1
            AND Container.status = 'C'
            AND ContainerDestination.status = 'C'
            AND Container.container_type = 'R'
            AND Receipt.trans_mode = 'I'
            AND Receipt.trans_type = 'D'
            AND Receipt.waste_accepted_flag = 'T'
            AND Receipt.receipt_status in ('U', 'A')
            AND Receipt.fingerpr_status = 'A'
            AND Receipt.manifest_flag <> 'B'
            AND (Receipt.receipt_date >= @start_date AND Receipt.receipt_date <= @end_date)
) a
group by customer_id, generator_id
--SELECT * FROM #temp_list

SELECT c.contact_id , c.NAME, c.email, tl.customer_id as cust_gen_id, 'C' AS cg_type, cu.cust_name as cust_gen_name, cu.cust_category, sum(tl.sum_weight) as total_weight
INTO #temp_list2
FROM #temp_list tl
INNER JOIN contactXRef cxr (nolock) on tl.customer_id = cxr.customer_id and cxr.type = 'C' and cxr.status = 'A'
INNER JOIN customer cu (nolock) on tl.customer_id = cu.customer_id
INNER JOIN contact c (nolock) on cxr.contact_id = c.contact_id and c.contact_status = 'A'
WHERE 1=1
and c.email IN ( SELECT f2 FROM jpb_marketing_survey_emails (nolock) )
GROUP BY c.contact_id , c.NAME, c.email, cu.cust_name, tl.customer_id, cu.cust_category
HAVING sum(tl.sum_weight) > 0

INSERT INTO #temp_list2
SELECT c.contact_id , c.NAME, c.email, tl.generator_id, 'G', g.generator_name, null, sum(tl.sum_weight)
FROM #temp_list tl
INNER JOIN contactXRef cxr (nolock) on tl.generator_id = cxr.generator_id and cxr.type = 'G' and cxr.status = 'A'
INNER JOIN generator g (nolock) on tl.generator_id = g.generator_id
INNER JOIN contact c (nolock) on cxr.contact_id = c.contact_id and c.contact_status = 'A'
WHERE 1=1
and c.email IN ( SELECT f2 FROM jpb_marketing_survey_emails (nolock) )
GROUP BY c.contact_id , c.NAME, c.email, tl.generator_id, g.generator_name
HAVING sum(tl.sum_weight) > 0


SELECT  contact_id, name, email, cust_gen_id, cg_type, cust_gen_name, cust_category, total_weight
FROM #temp_list2 
ORDER BY cg_type, cust_gen_id

