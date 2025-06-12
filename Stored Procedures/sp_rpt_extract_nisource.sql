
CREATE PROCEDURE sp_rpt_extract_nisource (
	@start_date				datetime,
	@end_date				datetime,
	@include_eq_fields		bit = 0
)
AS
/* ***************************************************************************************************
Procedure    : sp_rpt_extract_nisource
Database     : PLT_AI
Description  : Returns Nisource Extract data
Modified	 :

  This is the nisource extract
  The original was lost and this was re-created on 7-28-2008

 7-28-200 LJT - extracted '01-01-2007' and '12-31-2007'
              - extracted '01-01-2008' and '03-31-2008'

10-06-200 LJT - added approval description
              - extracted '04-01-2008' and '06-30-2008'

10-15-2008 JPB - Converted to a stored proc: sp_rpt_extract_nisource

01/13/2009 JPB - Modified sp name, made to run on plt_ai, converted @*_date fields to datetime types.

03/17/2009 JPB - Modified the final select to use the column names from the manual version
			  
sp_rpt_extract_nisource '4/1/2008', '6/30/2008'

*************************************************************************************************** */

DECLARE
	@customer_id			int,
	@extract_datetime		datetime,
	@usr					nvarchar(256),
	@days_before_delete		int

SELECT
	@customer_id			= 10877,
	@extract_datetime		= GETDATE(),
	@usr 					= UPPER(SUSER_SNAME()),
	@days_before_delete		= 90
	
IF RIGHT(@usr, 3) = '(2)'
	SELECT @usr = LEFT(@usr,(LEN(@usr)-3))
	
-----------------------------------------------------------
-- Always keep at least 5 copies
-----------------------------------------------------------
SELECT DISTINCT TOP 5 added_by, date_added 
INTO #extracts_to_keep
FROM EQ_Extract..NisourceExtract
ORDER BY date_added DESC

--SELECT * FROM #extracts_to_keep

-----------------------------------------------------------
-- Delete old extracts, but leave at least the last 5
-----------------------------------------------------------
DELETE FROM EQ_Extract..NisourceExtract
WHERE date_added < @days_before_delete
AND date_added NOT IN (
	SELECT date_added FROM #extracts_to_keep
)
	
INSERT EQ_Extract.dbo.NisourceExtract
	select
		wh.company_id,
		wh.profit_ctr_ID,
		wh.workorder_ID,
		wd.tsdf_code,
		wd.tsdf_approval_code,
		ta.waste_desc,
		cb.project_name,
		g.generator_name,
		g.generator_address_1,
		g.generator_address_2,
		g.generator_address_3,
		g.generator_city,
		g.generator_state,
		g.generator_zip_code,
		wh.start_date,
		ds.disposal_service_desc as 'disposal_method',
		wt.description as 'wastetype_description',
		wt.category as 'wastetype_category',
		ta.RCRA_Haz_flag,
		wd.quantity_used,
		wd.bill_unit_code,
		b.pound_conv,
		isnull(wd.quantity_used,0) * isnull(b.pound_conv,0) as 'total_pounds',
		wd.price as 'cost',
		@usr,
		@extract_datetime
	from workorderheader wh (nolock)
	inner join workorderdetail wd (nolock) on 
		wh.workorder_id = wd.workorder_id 
		and wh.profit_ctr_id = wd.profit_ctr_id 
		and wh.company_id = wd.company_id
	inner join customerbilling cb (nolock) on 
		wh.customer_id = cb.customer_id 
		and wh.billing_project_id = cb.billing_project_id
	inner join generator g (nolock) on 
		wh.generator_id = g.generator_id
	inner join tsdf t (nolock) on 
		wd.tsdf_code = t.tsdf_code
	inner join tsdfapproval ta (nolock) on 
		wd.tsdf_approval_id = ta.tsdf_approval_id
		and wd.company_id = ta.company_id
		and wd.profit_ctr_id = ta.profit_ctr_id
	inner join billunit b (nolock) on 
		wd.Bill_unit_code = b.bill_unit_code
	left outer join disposalservice ds (nolock) on 
		ta.disposal_service_id = ds.disposal_service_id
	left outer join wastetype wt (nolock) on 
		ta.wastetype_id = wt.wastetype_id
	where 
		wh.customer_id = @customer_id
		and wd.resource_type = 'D'
		and workorder_status = 'A' 
		and submitted_flag = 'T'
		and wh.start_date between @start_date and @end_date
		and t.eq_flag = 'F'

	union

	select
		wh.company_id,
		wh.profit_ctr_ID,
		wh.workorder_ID,
		wd.tsdf_code,
		wd.tsdf_approval_code,
		p.approval_desc,
		cb.project_name,
		g.generator_name,
		g.generator_address_1,
		g.generator_address_2,
		g.generator_address_3,
		g.generator_city,
		g.generator_state,
		g.generator_zip_code,
		wh.start_date,
		ds.disposal_service_desc as 'disposal_method',
		wt.description as 'wastetype_description',
		wt.category as 'wastetype_category',
		p.RCRA_Haz_flag,
		wd.quantity_used,
		wd.bill_unit_code,
		b.pound_conv,
		isnull(wd.quantity_used,0) * isnull(b.pound_conv,0) as 'total_pounds',
		wd.price as 'cost',
		@usr,
		@extract_datetime
	from workorderheader wh (nolock)
	inner join workorderdetail wd (nolock) on 
		wh.workorder_id = wd.workorder_id 
		and wh.profit_ctr_id = wd.profit_ctr_id
		and wh.company_id = wd.company_id
	inner join customerbilling cb (nolock) on 
		wh.customer_id = cb.customer_id 
		and wh.billing_project_id = cb.billing_project_id
	inner join generator g (nolock) on 
		wh.generator_id = g.generator_id
	inner join tsdf t (nolock) on 
		wd.tsdf_code = t.tsdf_code
	inner join profile p (nolock) on 
		wd.profile_id = p.profile_id
	inner join profilequoteapproval pqa (nolock) on 
		pqa.profile_id = p.profile_id 
		and t.eq_company = pqa.company_id 
		and t.eq_profit_ctr = pqa.profit_ctr_id
	inner join billunit b (nolock) on 
		wd.Bill_unit_code = b.bill_unit_code
	left outer join disposalservice ds (nolock) on 
		pqa.disposal_service_id = ds.disposal_service_id
	left outer join wastetype wt (nolock) on 
		p.wastetype_id = wt.wastetype_id
	where 
		wh.customer_id = @customer_id
		and wd.resource_type = 'D'
		and workorder_status = 'A' 
		and submitted_flag = 'T'
		and wh.start_date between @start_date and @end_date
		and t.eq_flag = 'T'

	order by wh.start_date 
	

	select
		company_id as 'Company',
		profit_ctr_ID as 'Profit Center',
		workorder_ID as 'Work Order ID',
		tsdf_code as 'TSDF',
		tsdf_approval_code as 'TSDF Approval',
		waste_desc as ' Waste Desription',
		project_name as 'Project Name',
		generator_name as 'Generator Name',
		generator_address_1 as 'Generator Address 1',
		generator_address_2 as 'Generator Address 2',
		generator_address_3 as 'Generator Address 3',
		generator_city as 'Generator City',
		generator_state as 'Generator State',
		generator_zip_code as 'Generator Zip Code',
		start_date as 'Workorder Start Date',
		disposal_method  as 'Disposal Method',
		wastetype_description as 'Waste Type Description',
		wastetype_category as 'Waste Type Category',
		RCRA_Haz_flag as 'RCRA Haz Flag',
		quantity_used as 'Quantity',
		bill_unit_code as 'Unit',
		pound_conv as 'Pound Conversion',
		total_pounds as 'total_pounds',
		cost as 'cost'
	from EQ_Extract..NisourceExtract (nolock) 
	where
		added_by = @usr
		and date_added = @extract_datetime
	order by start_date


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_extract_nisource] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_extract_nisource] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_extract_nisource] TO [EQAI]
    AS [dbo];

