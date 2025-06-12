
CREATE PROCEDURE sp_rpt_baseline_information
	@baseline_id int,
	@generator_id int
AS
BEGIN

SELECT 
		bh.baseline_description,
		bh.start_date,
		bh.end_date,
		c.customer_ID,
		c.cust_name,
		g.generator_name,
		g.EPA_ID,
		g.site_code,
		CD1_Description = (SELECT BaselineHeader.custom_defined_name_1 FROM BaselineHeader WHERE BaselineHeader.baseline_id = @baseline_id),
		CD1_Detail = (SELECT BaselineCategory.description FROM BaselineCategory WHERE baseline_category_id = bd.baseline_category_id_custom_1 AND bd.baseline_id = @baseline_id AND bd.generator_id = @generator_id),
		
		CD2_Description = (SELECT BaselineHeader.custom_defined_name_2 FROM BaselineHeader WHERE BaselineHeader.baseline_id = @baseline_id),
		CD2_Detail = (SELECT BaselineCategory.description FROM BaselineCategory WHERE baseline_category_id = bd.baseline_category_id_custom_2 AND bd.baseline_id = @baseline_id AND bd.generator_id = @generator_id),
		
		CD3_Description = (SELECT BaselineHeader.custom_defined_name_3 FROM BaselineHeader WHERE BaselineHeader.baseline_id = @baseline_id),
		CD3_Detail = (SELECT BaselineCategory.description FROM BaselineCategory WHERE baseline_category_id = bd.baseline_category_id_custom_3 AND bd.baseline_id = @baseline_id AND bd.generator_id = @generator_id),
		
		bc.description as category_description,
		brt.reporting_type,
		bd.quantity,
		bd.bill_unit_code,
		bd.expected_amount,
		bd.time_period
 FROM BaselineHeader bh
	INNER JOIN BaselineDetail bd ON bh.baseline_id = bd.baseline_id
	INNER JOIN BaselineCategory bc ON bc.baseline_category_id = bd.baseline_category_id
	INNER JOIN BaselineReportingType brt ON bd.reporting_type_id = brt.reporting_type_id
	INNER JOIN Generator g ON g.generator_id = @generator_id
	INNER JOIN Customer c ON c.customer_ID = bh.customer_id
WHERE bd.generator_id = @generator_id

END



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_baseline_information] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_baseline_information] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_baseline_information] TO [EQAI]
    AS [dbo];

