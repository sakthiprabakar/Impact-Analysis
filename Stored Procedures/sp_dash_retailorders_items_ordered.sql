
CREATE PROCEDURE sp_dash_retailorders_items_ordered
	@measurement_id	int,
	@start_date		datetime,
	@end_date		datetime
AS
/* ************************************************
sp_dash_retailorders_items_ordered:
	@measurement_id: 	The DashboardMeasurement record related to this test.
	@start_date: 		The start date to query for
	@end_date: 			The end date to query for

Total amount of retail orders created per day

select * from DashBoardMeasurement where description like '%retai%'
-- 34

	sp_dash_retailorders_items_ordered 34, '2009-09-10 00:00:00', '2009-09-10 23:59:59'
	select * 
		from DashboardResult 
		where report_period_end_date = '2009-09-10 00:00:00.000'
		and measurement_id = 34
	delete DashboardResult 
		where report_period_end_date = '2009-09-10 00:00:00.000'
		and measurement_id = 34


LOAD TO PLT_AI*

08/11/2009 JPB Created
10/06/2009 JPB Added reporting of Company_id, Profit_ctr_id
			Added join to Product to only catch profitctrs where there are retail products
10/12/2009 RJG Added Product_Id to the order detail join to get numbers to match up like they should
10/14/2009 RJG Verified order_date is correct date field to use
************************************************ */

SET ansi_warnings OFF

INSERT DashboardResult (
	company_id,
	profit_ctr_id,
	measurement_id,
	report_period_end_date,
	answer,
	note,
	threshold_value,
	threshold_operator,
	date_modified,
	modified_by,
	added_by,
	date_added
)	
SELECT
	p.company_id,
	p.profit_ctr_id,
	dm.measurement_id,
	CONVERT (VARCHAR, @end_date, 101) AS report_period_end_date,
	convert(varchar(20), sum(o.quantity)) AS answer,
	NULL AS note,
	dm.threshold_value,
	dm.threshold_operator,
	GETDATE() AS date_modified,
	SYSTEM_USER AS modified_by,
	SYSTEM_USER AS added_by,
	GETDATE() AS date_added
FROM DashboardMeasurement dm
	INNER JOIN DashboardTier dt ON dm.tier_id = dt.tier_id
	INNER JOIN profitcenter p ON p.status = 'A'
	INNER JOIN product pro on p.company_id = pro.company_id 
		and p.profit_ctr_id = pro.profit_ctr_id 
		--and pro.retail_flag = 'T'
	LEFT OUTER JOIN orderdetail o 
		ON o.profit_ctr_id = p.profit_ctr_id
		AND o.company_id = p.company_ID
		AND o.product_id = pro.product_ID
		AND o.status <> 'V'
	INNER JOIN OrderHeader oh on o.order_id = oh.order_id
	AND oh.order_date BETWEEN @start_date AND @end_date
WHERE 
 	dm.measurement_id = @measurement_id
GROUP BY 
	dm.measurement_id,
	dm.threshold_operator,
	dm.threshold_value,
	dm.compliance_flag,
	dt.tier_name,
	p.company_id,
	p.profit_ctr_id
	
/*
	-- if no data was found, then insert zeros for these records
	-- we cannot do a left outer join above because the co/pc info is in the detail record
*/
declare @records_inserted_count int
SELECT @records_inserted_count = COUNT(dr.result_id) FROM DashboardResult dr where dr.measurement_id = @measurement_id AND dr.report_period_end_date = CONVERT (VARCHAR, @end_date, 101)

IF @records_inserted_count = 0
INSERT DashboardResult (
	company_id,
	profit_ctr_id,
	measurement_id,
	report_period_end_date,
	answer,
	note,
	threshold_value,
	threshold_operator,
	date_modified,
	modified_by,
	added_by,
	date_added
)	
SELECT
	p.company_id,
	p.profit_ctr_id,
	dm.measurement_id,
	CONVERT (VARCHAR, @end_date, 101) AS report_period_end_date,
	0 as answer,
	NULL AS note,
	dm.threshold_value,
	dm.threshold_operator,
	GETDATE() AS date_modified,
	SYSTEM_USER AS modified_by,
	SYSTEM_USER AS added_by,
	GETDATE() AS date_added
FROM DashboardMeasurement dm
	INNER JOIN DashboardTier dt ON dm.tier_id = dt.tier_id
	INNER JOIN profitcenter p ON p.status = 'A'
	INNER JOIN product pro on p.company_id = pro.company_id 
		and p.profit_ctr_id = pro.profit_ctr_id 
		--and pro.retail_flag = 'T'
WHERE 
 	dm.measurement_id = @measurement_id
GROUP BY 
	dm.measurement_id,
	dm.threshold_operator,
	dm.threshold_value,
	dm.compliance_flag,
	dt.tier_name,
	p.company_id,
	p.profit_ctr_id	

	
	
SET ansi_warnings ON


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_dash_retailorders_items_ordered] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_dash_retailorders_items_ordered] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_dash_retailorders_items_ordered] TO [EQAI]
    AS [dbo];

