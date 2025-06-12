
Create Proc sp_rpt_baseline_validation (
	@baseline_id int = NULL,
	@generator_id int = NULL,
	@month_startdate datetime = NULL,
	@release_code varchar(20) = NULL,
	@purchase_order varchar(20) = NULL,
	@debug int = 0
)
AS
BEGIN	
/*
History:
	04/21/2010	RJG	Created
	05/14/2010	JPB Removed Billing joins.  Marked where EQ Disposal info would be needed in future.

exec sp_rpt_baseline_validation @baseline_id = 7,
	@generator_id = 88029,
	@month_startdate = '07/01/2010',
	@release_code = NULL,
	@purchase_order = NULL,
	@debug = 0

		
*/

	declare @start_date datetime = NULL
	declare @end_date datetime = NULL

	if @month_startdate IS NOT NULL
	begin
		SET @start_date = CAST(MONTH(@month_startdate) as varchar(20)) + '/1/' + cast(YEAR(@month_startdate) as varchar(20))
		SET @end_date = DATEADD(SECOND, -1, DATEADD(MONTH, 1, @start_date)) 
	end

	if @debug > 0
	begin
		print @start_date
		print @end_date 
	end

	if @month_startdate IS NULL AND @release_code IS NULL AND @purchase_order IS NULL
	BEGIN
		RAISERROR ('One of either @month_startdate, @release_code, or @purchase_order must be filled in', -- Message text.
				   16, -- Severity.
				   1 -- State.
				   );
		RETURN
	END

	/*
	-- BASELINE VALIDATION
		select * from BaselineHeader
		select * from BaselineDetail where baseline_id = 4

		select * from WorkorderDetail where workorder_ID = 6487200 and sequence_id = 1

		select * from WorkorderDetailBaseline where workorder_ID = 6487200

		select * from BaselineDetail where baseline_category_id = 102

		declare 	@baseline_id int = 2,
			@generator_id int = 34538,
			@month_startdate datetime = '9/1/2009',
			@release_code varchar(20) = NULL,
			@purchase_order varchar(20) = NULL,
			@category_record_type varchar(10) = 'C',
			@debug int = 0

		declare @start_date datetime = NULL
		declare @end_date datetime = NULL

		if @month_startdate IS NOT NULL
		begin
			SET @start_date = CAST(MONTH(@month_startdate) as varchar(20)) + '/1/' + cast(YEAR(@month_startdate) as varchar(20))
			SET @end_date = DATEADD(SECOND, -1, DATEADD(MONTH, 1, @start_date)) 
		end
	*/


--	if OBJECT_ID('tempdb..#Results') is not null drop table #Results

	create table #Results (
		problem_description		varchar(100),
		workorder_company_id	int,
		workorder_profit_ctr_id	int,
		workorder_id			int,
		workorder_resource_type	char(1),
		workorder_sequence_id	int,
		problem_value			varchar(100)
	)


	-- Check for prices that don't match (Disposal)
		-- sum of wdb.price should match wd.price.
		insert #results
		select 
			'Workorder Price != Baseline Price' as problem,
			wd.company_id, 
			wd.profit_ctr_id, 
			wd.workorder_id, 
			wd.resource_type, 
			wd.sequence_id, 
			'WO price: ' + convert(varchar(20), wodu.price) + ' vs Baseline price: ' + convert(varchar(20), sum(wdb.price))
		from WorkOrderDetail wd
		INNER JOIN WorkOrderDetailUnit wodu ON
			wd.workorder_id = wodu.workorder_id
			AND wd.company_id = wodu.company_id
			AND wd.profit_ctr_id = wodu.profit_ctr_id
			AND wd.sequence_id = wodu.sequence_id
			AND wd.resource_type = 'D'
			AND wodu.billing_flag = 'T'
		inner join WorkorderHeader wh
			on wd.workorder_ID = wh.workorder_id
			and wd.company_id = wh.company_id
			and wd.profit_ctr_ID = wh.profit_ctr_id
		INNER JOIN BaselineHeader bh ON  -- 1=1 is for debugging
			bh.customer_id = wh.customer_ID
		inner join WorkorderDetailBaseline wdb 
			on wd.workorder_ID = wdb.workorder_id
			and wd.company_id = wdb.company_id
			and wd.profit_ctr_ID = wdb.profit_ctr_id
			and wd.resource_type = wdb.resource_type
			and wd.sequence_ID = wdb.sequence_id
		inner join BaselineDetail bd
			on wdb.baseline_category_id = bd.baseline_category_id
			AND bh.baseline_id = bd.baseline_id
			AND bd.generator_id = wh.generator_id
			and wh.generator_id = bd.generator_id
		WHERE bh.baseline_id = @baseline_id
		AND 1 = 
			CASE WHEN @month_startdate IS NOT NULL
					AND wh.start_date BETWEEN @start_date AND @end_date
			THEN 1
			WHEN @purchase_order IS NOT NULL
				AND wh.purchase_order = @purchase_order
				THEN 1
			WHEN @release_code IS NOT NULL
				AND wh.release_code = @release_code
				THEN 1
			END
		AND wh.generator_id = @generator_id
		group by wd.company_id, wd.profit_ctr_id, wd.workorder_id, wd.resource_type, wd.sequence_id, wodu.price
		having wodu.price <> sum(wdb.price)
		order by wd.company_id, wd.profit_ctr_ID, wd.workorder_ID, wd.resource_type, wd.sequence_ID
		
		-- Check for prices that don't match. (non-disposal)
		insert #results
		select 
			'Non Disposal Workorder Price != Baseline Price' as problem,
			wd.company_id, 
			wd.profit_ctr_id, 
			wd.workorder_id, 
			wd.resource_type, 
			wd.sequence_id, 
			'WO price: ' + convert(varchar(20), wd.price) + ' vs Baseline price: ' + convert(varchar(20), sum(wdb.price))
		from WorkOrderDetail wd
		inner join WorkorderHeader wh
			on wd.workorder_ID = wh.workorder_id
			and wd.company_id = wh.company_id
			and wd.profit_ctr_ID = wh.profit_ctr_id
			AND wd.resource_type <> 'D'
		INNER JOIN BaselineHeader bh ON  -- 1=1 is for debugging
			bh.customer_id = wh.customer_ID
		inner join WorkorderDetailBaseline wdb 
			on wd.workorder_ID = wdb.workorder_id
			and wd.company_id = wdb.company_id
			and wd.profit_ctr_ID = wdb.profit_ctr_id
			and wd.resource_type = wdb.resource_type
			and wd.sequence_ID = wdb.sequence_id
		inner join BaselineDetail bd
			on wdb.baseline_category_id = bd.baseline_category_id
			AND bh.baseline_id = bd.baseline_id
			AND bd.generator_id = wh.generator_id
			and wh.generator_id = bd.generator_id
		WHERE bh.baseline_id = @baseline_id
		AND 1 = 
			CASE WHEN @month_startdate IS NOT NULL
					AND wh.start_date BETWEEN @start_date AND @end_date
			THEN 1
			WHEN @purchase_order IS NOT NULL
				AND wh.purchase_order = @purchase_order
				THEN 1
			WHEN @release_code IS NOT NULL
				AND wh.release_code = @release_code
				THEN 1
			END
		AND wh.generator_id = @generator_id
		group by wd.company_id, wd.profit_ctr_id, wd.workorder_id, wd.resource_type, wd.sequence_id, wd.price
		having wd.price <> sum(wdb.price)
		order by wd.company_id, wd.profit_ctr_ID, wd.workorder_ID, wd.resource_type, wd.sequence_ID		
		

	-- Look for invalid WDB Category assignments. (Disposal)
		insert #results
		select distinct
			'Invalid Baseline Category Assignment' as problem,
			wdb.company_id, 
			wdb.profit_ctr_id, 
			wdb.workorder_id, 
			wdb.resource_type, 
			wdb.sequence_id, 
			'Category: ' + convert(varchar(20), wdb.baseline_category_id) + ' not in BaseLineDetail'
		from WorkorderDetailBaseline wdb
		inner join WorkOrderDetail wd
			on wd.workorder_ID = wdb.workorder_id
			and wd.company_id = wdb.company_id
			and wd.profit_ctr_ID = wdb.profit_ctr_id
			and wd.resource_type = wdb.resource_type
			and wd.sequence_ID = wdb.sequence_id
		inner join WorkorderHeader wh
			on wd.workorder_ID = wh.workorder_id
			and wd.company_id = wh.company_id
			and wd.profit_ctr_ID = wh.profit_ctr_id
		INNER JOIN BaselineHeader bh ON  -- 1=1 is for debugging
			bh.customer_id = wh.customer_ID
		WHERE 1=1
		and bh.baseline_id = @baseline_id
		AND 1 = 
			CASE WHEN @month_startdate IS NOT NULL
					AND wh.start_date BETWEEN @start_date AND @end_date
			THEN 1
			WHEN @purchase_order IS NOT NULL
				AND wh.purchase_order = @purchase_order
				THEN 1
			WHEN @release_code IS NOT NULL
				AND wh.release_code = @release_code
				THEN 1
			END
		AND wh.generator_id = @generator_id
		and wdb.baseline_category_id not in (select baseline_category_id from BaselineDetail bd2 inner join BaselineHeader bh2 on bd2.baseline_id = bh2.baseline_id where bh2.customer_id = bh.customer_id)
		order by wdb.company_id, wdb.profit_ctr_ID, wdb.workorder_ID, wdb.resource_type, wdb.sequence_ID


	-- Look for inactive WDB Category assignments.
		insert #results
		select distinct
			'In-active Baseline Category Assignment' as problem,
			wdb.company_id, 
			wdb.profit_ctr_id, 
			wdb.workorder_id, 
			wdb.resource_type, 
			wdb.sequence_id, 
			'Category: ' + convert(varchar(20), wdb.baseline_category_id) + ' not Active in BaseLineDetail'
		from WorkorderDetailBaseline wdb
		inner join WorkOrderDetail wd
			on wd.workorder_ID = wdb.workorder_id
			and wd.company_id = wdb.company_id
			and wd.profit_ctr_ID = wdb.profit_ctr_id
			and wd.resource_type = wdb.resource_type
			and wd.sequence_ID = wdb.sequence_id
		inner join WorkorderHeader wh
			on wd.workorder_ID = wh.workorder_id
			and wd.company_id = wh.company_id
			and wd.profit_ctr_ID = wh.profit_ctr_id
		INNER JOIN BaselineHeader bh ON  -- 1=1 is for debugging
			bh.customer_id = wh.customer_ID
		WHERE 1=1
		and bh.baseline_id = @baseline_id
		AND 1 = 
			CASE WHEN @month_startdate IS NOT NULL
					AND wh.start_date BETWEEN @start_date AND @end_date
			THEN 1
			WHEN @purchase_order IS NOT NULL
				AND wh.purchase_order = @purchase_order
				THEN 1
			WHEN @release_code IS NOT NULL
				AND wh.release_code = @release_code
				THEN 1
			END
		AND wh.generator_id = @generator_id
		and wdb.baseline_category_id in (select baseline_category_id from BaselineDetail bd2 inner join BaselineHeader bh2 on bd2.baseline_id = bh2.baseline_id where bh2.customer_id = bh.customer_id)
		and wdb.baseline_category_id not in (select baseline_category_id from BaselineDetail bd2 inner join BaselineHeader bh2 on bd2.baseline_id = bh2.baseline_id where bh2.customer_id = bh.customer_id and bd2.status = 'A' and bh.status = 'A')
		order by wdb.company_id, wdb.profit_ctr_ID, wdb.workorder_ID, wdb.resource_type, wdb.sequence_ID


	-- Look for WOD 'D'isposal records with a goofy Manifest.
		insert #results
		select distinct
			'Workorder Disposal record with placeholder Manifest value' as problem,
			wd.company_id, 
			wd.profit_ctr_id, 
			wd.workorder_id, 
			wd.resource_type, 
			wd.sequence_id, 
			'Manifest: ' + wd.manifest + ' is a placeholder value, not a real value'
		from WorkorderDetailBaseline wdb
		inner join WorkOrderDetail wd
			on wd.workorder_ID = wdb.workorder_id
			and wd.company_id = wdb.company_id
			and wd.profit_ctr_ID = wdb.profit_ctr_id
			and wd.resource_type = wdb.resource_type
			and wd.sequence_ID = wdb.sequence_id
		inner join WorkorderHeader wh
			on wd.workorder_ID = wh.workorder_id
			and wd.company_id = wh.company_id
			and wd.profit_ctr_ID = wh.profit_ctr_id
		INNER JOIN BaselineHeader bh ON  -- 1=1 is for debugging
			bh.customer_id = wh.customer_ID
		WHERE 1=1
		and bh.baseline_id = @baseline_id
		AND 1 = 
			CASE WHEN @month_startdate IS NOT NULL
					AND wh.start_date BETWEEN @start_date AND @end_date
			THEN 1
			WHEN @purchase_order IS NOT NULL
				AND wh.purchase_order = @purchase_order
				THEN 1
			WHEN @release_code IS NOT NULL
				AND wh.release_code = @release_code
				THEN 1
			END
		AND wh.generator_id = @generator_id
		and wd.resource_type = 'D' and wd.manifest like 'manifest[_]%'


	-- Look for WD lines without pounds.
		insert #results
		select distinct
			'Workorder Disposal has no pounds' as problem,
			wd.company_id, 
			wd.profit_ctr_id, 
			wd.workorder_id, 
			wd.resource_type, 
			wd.sequence_id, 
			'No pounds, no Override, and ' + isnull(wodu.bill_unit_code, '''''') + ' does not convert to pounds'
		from WorkorderDetailBaseline wdb
		inner join WorkOrderDetail wd
			on wd.workorder_ID = wdb.workorder_id
			and wd.company_id = wdb.company_id
			and wd.profit_ctr_ID = wdb.profit_ctr_id
			and wd.resource_type = wdb.resource_type
			and wd.sequence_ID = wdb.sequence_id
		INNER JOIN WorkOrderDetailUnit wodu ON
			wd.workorder_id = wodu.workorder_id
			AND wd.company_id = wodu.company_id
			AND wd.profit_ctr_id = wodu.profit_ctr_id
			AND wd.sequence_id = wodu.sequence_id
			AND wodu.billing_flag = 'T'			
		inner join WorkorderHeader wh
			on wd.workorder_ID = wh.workorder_id
			and wd.company_id = wh.company_id
			and wd.profit_ctr_ID = wh.profit_ctr_id
		INNER JOIN BaselineHeader bh ON  -- 1=1 is for debugging
			bh.customer_id = wh.customer_ID
		inner join BaselineDetail bd
			on wdb.baseline_category_id = bd.baseline_category_id
			AND bh.baseline_id = bd.baseline_id
			AND bd.generator_id = wh.generator_id
			and wh.generator_id = bd.generator_id
		LEFT JOIN WorkOrderDetailUnit wodu_pounds ON
			wd.workorder_id = wodu_pounds.workorder_id
			AND wd.company_id = wodu_pounds.company_id
			AND wd.profit_ctr_id = wodu_pounds.profit_ctr_id
			AND wd.sequence_id = wodu_pounds.sequence_id
			AND wodu_pounds.billing_flag = 'F'
			AND wodu_pounds.bill_unit_code = 'LBS'
		WHERE 1=1
		and bh.baseline_id = @baseline_id
		AND 1 = 
			CASE WHEN @month_startdate IS NOT NULL
					AND wh.start_date BETWEEN @start_date AND @end_date
			THEN 1
			WHEN @purchase_order IS NOT NULL
				AND wh.purchase_order = @purchase_order
				THEN 1
			WHEN @release_code IS NOT NULL
				AND wh.release_code = @release_code
				THEN 1
			END
		AND wh.generator_id = @generator_id
		and wd.resource_type = 'D'
		and 0 = case
			when wodu_pounds.quantity is not null then 1
			when bd.pound_conv_override IS NOT NULL then 2
			when wodu.bill_unit_code in (
					select bill_unit_code 
					from BillUnit 
					where pound_conv is not null 
					and isnull(wodu.quantity, wd.quantity) is not null
				) then 3
			else 0
		end

	-- Look for WD records linked to a receipt where the receipt unit doesn't map to pounds
		insert #results
		select distinct
			'Workorder linked to a receipt that has no pounds' as problem,
			wd.company_id, 
			wd.profit_ctr_id, 
			wd.workorder_id, 
			wd.resource_type, 
			wd.sequence_id, 
			'Linked Receipt ' + convert(varchar(2), r.company_id) + '-' + convert(varchar(2), r.profit_ctr_id) + ': ' + convert(varchar(20), r.receipt_id) + ' line ' + CONVERT(varchar(4), r.line_id) + ' - No pounds, no Override, and ' + isnull(r.bill_unit_code, '''''') + ' does not convert to pounds'
		from WorkorderDetailBaseline wdb
		inner join WorkOrderDetail wd
			on wd.workorder_ID = wdb.workorder_id
			and wd.company_id = wdb.company_id
			and wd.profit_ctr_ID = wdb.profit_ctr_id
			and wd.resource_type = wdb.resource_type
			and wd.sequence_ID = wdb.sequence_id
		inner join WorkorderHeader wh
			on wd.workorder_ID = wh.workorder_id
			and wd.company_id = wh.company_id
			and wd.profit_ctr_ID = wh.profit_ctr_id
		INNER JOIN BaselineHeader bh ON  -- 1=1 is for debugging
			bh.customer_id = wh.customer_ID
		inner join BaselineDetail bd
			on wdb.baseline_category_id = bd.baseline_category_id
			AND bh.baseline_id = bd.baseline_id
			AND bd.generator_id = wh.generator_id
			and wh.generator_id = bd.generator_id
		inner join BillingLinkLookup bll
			on wd.workorder_ID = bll.source_id
			and wd.company_id = bll.source_company_id
			and wd.profit_ctr_ID = bll.source_profit_ctr_id
			-- and wd.resource_type = bll.source_type
			-- and wd.sequence_ID = bll.source_line_id
		inner join Receipt r
			on bll.receipt_id = r.receipt_id
			and bll.company_id = r.company_id
			and bll.profit_ctr_id = r.profit_ctr_id
			and bll.line_id = r.line_id
		WHERE 1=1
		and bh.baseline_id = @baseline_id
		AND 1 = 
			CASE WHEN @month_startdate IS NOT NULL
					AND wh.start_date BETWEEN @start_date AND @end_date
			THEN 1
			WHEN @purchase_order IS NOT NULL
				AND wh.purchase_order = @purchase_order
				THEN 1
			WHEN @release_code IS NOT NULL
				AND wh.release_code = @release_code
				THEN 1
			END
		AND wh.generator_id = @generator_id
		and 0 = case
			when r.net_weight is not null then 1
			when bd.pound_conv_override IS NOT NULL then 2
			when r.bill_unit_code in (
					select bill_unit_code 
					from BillUnit 
					where pound_conv is not null 
					and r.quantity is not null
				) then 3
			else 0
		end


	-- Send out the results...
		select 
			* 
		from #Results 
		order by 
			problem_description, 
			workorder_company_id, 
			workorder_profit_ctr_id, 
			workorder_id, 
			workorder_resource_type, 
			workorder_sequence_id

END

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_baseline_validation] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_baseline_validation] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_baseline_validation] TO [EQAI]
    AS [dbo];

