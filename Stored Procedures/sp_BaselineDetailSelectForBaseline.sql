CREATE PROCEDURE [dbo].[sp_BaselineDetailSelectForBaseline] 
    @baseline_id INT = NULL
AS 
	SET NOCOUNT ON 

	SELECT BaselineDetail.[baseline_id],
           BaselineDetail.[baseline_category_id],
           BaselineDetail.[generator_id],
           BaselineDetail.[status],
           BaselineDetail.[reporting_type_id],
           BaselineReportingType.reporting_type,
           BaselineDetail.[quantity],
           BaselineDetail.[expected_amount],
           BaselineDetail.[bill_unit_code],
           BaselineDetail.[pound_conv_override],
           BaselineDetail.[time_period],
           BaselineDetail.[baseline_category_id_custom_1],
           BaselineDetail.[baseline_category_id_custom_2],
           BaselineDetail.[baseline_category_id_custom_3],
           [baseline_category_id_custom_value_1] = (SELECT description FROM BaselineCategory WHERE record_type = 'CD1' AND baseline_category_id = BaselineDetail.baseline_category_id_custom_1) ,
           [baseline_category_id_custom_value_2] = (SELECT description FROM BaselineCategory WHERE record_type = 'CD2' AND baseline_category_id = BaselineDetail.baseline_category_id_custom_2) ,
           [baseline_category_id_custom_value_3] = (SELECT description FROM BaselineCategory WHERE record_type = 'CD3' AND baseline_category_id = BaselineDetail.baseline_category_id_custom_3) ,                                 
           g.generator_name,
           baseCategory.description,
           BaselineDetail.[modified_by],
           BaselineDetail.[date_modified],
           BaselineDetail.[added_by],
           BaselineDetail.[date_added]
    FROM   [dbo].[BaselineDetail]
		INNER JOIN Generator g ON BaselineDetail.generator_id = g.generator_id
		INNER JOIN BaselineCategory baseCategory ON BaselineDetail.baseline_category_id = baseCategory.baseline_category_id
		INNER JOIN BaselineReportingType ON BaselineReportingType.reporting_type_id= BaselineDetail.reporting_type_id
    WHERE  [baseline_id] = @baseline_id
	AND BaselineDetail.status ='A'

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_BaselineDetailSelectForBaseline] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_BaselineDetailSelectForBaseline] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_BaselineDetailSelectForBaseline] TO [EQAI]
    AS [dbo];

