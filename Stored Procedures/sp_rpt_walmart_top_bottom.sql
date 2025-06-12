
create proc sp_rpt_walmart_top_bottom (
	@datayear		int = null,
	@datamonth		int = null,
	@recordset		varchar(100) = '',
		/*	Call with 'Generate' the first time to run the data routines
			Then call with the name of the recordset you want back afterward.
		*/
	@timestamp		varchar(50) = null
		/* Always pass a timestamp value. It should be getdate() but always pass one. */
)
as
/* **************************************************************************************
Wal-Mart * Better Data, Lower Charges <- That's not an official slogan.

--------------------------------------
Top & Bottom 10 Stores & Profiles Data
--------------------------------------

Now this is a Stored Procedure.  It used to be a script.

Now: 
	sp_rpt_walmart_top_bottom
		@datayear		= 2013,
		@datamonth		= 3,
			/*	Call with 'Generate' the first time to run the data routines
				Then call with the name of the recordset you want back afterward.
			*/
		-- @recordset		= 'Generate'
		-- Alternatives:
			-- @recordset		= 'all stores'
			-- @recordset		= 'total generation - Monthly RCRA generation by format'
			-- @recordset		= 'total generation - Monthly generation of all RCRA waste streams'
			-- @recordset		= 'total generation - Monthly Top 5 RCRA Waste Streams by Format: SUP'
			-- @recordset		= 'total generation - Monthly Top 5 RCRA Waste Streams by Format: WM'
			-- @recordset		= 'total generation - Monthly Top 5 RCRA Waste Streams by Format: SAMS'
			-- @recordset		= 'total generation - Monthly Top 5 RCRA Waste Streams by Format: SMALL'
			-- @recordset		= 'Average RCRA Generation per Facility by Format'
			-- @recordset		= 'Average RCRA Generation by Waste Stream (Rank High to Low)'
			-- @recordset		= 'Top 5 Average RCRA Generation by Waste Stream by Format (Rank High to Low): SUP'
			-- @recordset		= 'Top 5 Average RCRA Generation by Waste Stream by Format (Rank High to Low): WM'
			-- @recordset		= 'Top 5 Average RCRA Generation by Waste Stream by Format (Rank High to Low): SAMS'
			-- @recordset		= 'Top 5 Average RCRA Generation by Waste Stream by Format (Rank High to Low): SMALL'
			@recordset		= 'Top 10 Summary: SUP'
			-- @recordset		= 'Top 10 Summary: WM'
			-- @recordset		= 'Top 10 Summary: SAMS'
			-- @recordset		= 'Top 10 Summary: SMALL'
			-- @recordset		= 'Top 10 Detail: SUP'
			-- @recordset		= 'Top 10 Detail: WM'
			-- @recordset		= 'Top 10 Detail: SAMS'
			-- @recordset		= 'Top 10 Detail: SMALL'
			-- @recordset		= 'Bottom 10 Summary: SUP'
			-- @recordset		= 'Bottom 10 Summary: WM'
			-- @recordset		= 'Bottom 10 Summary: SAMS'
			-- @recordset		= 'Bottom 10 Summary: SMALL'
			-- @recordset		= 'Bottom 10 Detail: SUP'
			-- @recordset		= 'Bottom 10 Detail: WM'
			-- @recordset		= 'Bottom 10 Detail: SAMS'
			-- @recordset		= 'Bottom 10 Detail: SMALL'
		, @timestamp		= '2013-04-19 09:13:28.653'
		

	Running with 'Generate' as a recordset populates these tables with data:
		select * from EQ_Extract.dbo.WMTopBottom_GenerationData
		select * from EQ_Extract.dbo.WMTopBottom_TotalData 
		select * from EQ_Extract.dbo.WMTopBottom_YTDTops 

	Running with any other 'recordset' value runs/returns that labeled recordset.

		
Old:


To Run This:

	Update the @datayear and @datamonth variables below to reflect the "current" month
	Execute the whole script


More Detail Than You Want To Read... But really should, at least once.

Overview:
	The output from this script is expected to go into a multi-tab worksheet Excel file.
	
	The spec for that file is not createable by EQ's ExportToExcel routines (because of 
	multiple different datasets on 1 tab) so eventually an SSRS report will probably be
	required. During development & early runs, we'll probably just copy datasets to Excel
	by hand.
	
	This script creates the data for every requested worksheet & data-table in one run.
	They are:
		All Stores: A list of all the stores for WM and their monthly total RCRA waste generated in lbs.
		Total Generation: Several data-tables...
			Monthly RCRA generation by format: For each format, the total lbs per month, and for the whole YTD
			Monthly generation of RCRA waste streams: For each waste stream, monthly & YTD total lbs.
			Monthly Top 5 RCRA Waste Streams by Format: the top 5 streams' monthly & YTD total lbs, SUP store types
			Monthly Top 5 RCRA Waste Streams by Format: the top 5 streams' monthly & YTD total lbs, WM store types
			Monthly Top 5 RCRA Waste Streams by Format: the top 5 streams' monthly & YTD total lbs, SAMS store types
			Monthly Top 5 RCRA Waste Streams by Format: the top 5 streams' monthly & YTD total lbs, SMALL store types
		Average Generation: Several data-tables...
			Average RCRA Generation per Facility by Format: For each format, the avg lbs per month, and for the whole YTD
			Average RCRA Generation by Waste Stream: For each waste stream, monthly & YTD avg lbs.
			Top 5 Average RCRA Generation by Waste Stream by Format: the top 5 streams' monthly & YTD avg lbs, SUP store types
			Top 5 Average RCRA Generation by Waste Stream by Format: the top 5 streams' monthly & YTD lbs, WM store types
			Top 5 Average RCRA Generation by Waste Stream by Format: the top 5 streams' monthly & YTD lbs, SAMS store types
			Top 5 Average RCRA Generation by Waste Stream by Format: the top 5 streams' monthly & YTD lbs, SMALL store types
		Top 10 - (format): Two data-tables for each format of (SUP, WM, SAMS, SMALL)...
			1: The top 10 facilities of a format by waste for the current month
			2: The details of the profiles weights for the top 10 facilities of a format for the current month
		Bottom 10 - (format): Two data-tables for each format of (SUP, WM, SAMS, SMALL)...
			1: The bottom 10 facilities of a format by waste for the current month
			2: The details of the profiles weights for the bottom 10 facilities of a format for the current month

Output:
	All data tables are selected in one run.
	Before each is a simple select of the "Tab" that dataset should go on, and/or the labels that should preceed it
		on the spreadsheet.
	Hopefully that makes it easier to copy each tab name, data-table title, and data-table rows to Excel by hand.
		When this is migrated to SSRS output, those tab names & table titles can be removed & coded into the SSRS data
		But at that point we'll also have to overcome SSRS's preference for 1 recordset of output per SQL statement.
		Some days, you just can't win.
		
History:
	02/12/2013 - JPB - Development, Spec definition, all kinds of fun.
	03/13/2013 - JPB - First draft finalized, sample data given to Brie M for review
		This sample data was generated on DEV (recently restored from prod) because this script
		expects new fields in the Generator table that weren't ready for production yet (per EQAI).
	03/15/2013 - JPB - Total & Average should not be limited to 30-day stores, and generator_id should not be an output field anywhere.
	04/18/2013 - JPB - Conversion to SP for use with SSRS.

************************************************************************************** */

DECLARE
    @start_date         datetime,
    @end_date           datetime,
	@format				varchar(20)

select @start_date = convert(datetime, '1/1/' + convert(varchar(20), @datayear)),
	@end_date = convert(datetime, '12/31/' + convert(varchar(20), @datayear))


/* ****************************************************************
This was HUGELY copied from sp_rpt_extract_walmart_disposal on 2/27/2013

Then it was gutted so fewer fields & tables were involved.

**************************************************************** */


-- Fix/Set EndDate's time.
	if isnull(@end_date,'') <> ''
		if datepart(hh, @end_date) = 0 set @end_date = @end_date + 0.99999

	if object_id('tempdb..#Param') is not null
		drop table #Param
		
	CREATE TABLE #Param (
		idx				int,
		row				varchar(max),
		size			int
	)

IF @timestamp IS NULL OR @recordset = 'Generate' BEGIN -- Beginning of Generation Routine


	declare @customer table (customer_id 	int)
	INSERT @Customer values (10673)

	-- Create table to store important site types for this query (saves on update/retype issues)
	declare @SiteTypeToInclude table (site_type       varchar(40))
	INSERT @SiteTypeToInclude
		SELECT 'Neighborhood Market' 
		UNION SELECT 'Sams Club'
		UNION SELECT 'Supercenter'
		UNION SELECT 'Wal-Mart'
		UNION SELECT 'Optical Lab'
		UNION SELECT 'Wal-Mart Return Center'
		UNION SELECT 'Wal-Mart PMDC'
		UNION SELECT 'Sams DC'
		UNION SELECT 'Wal-Mart DC'
		-- UNION SELECT 'Amigo'

	-- Run Setup Finished'

	if object_id('tempdb..#WalmartDisposalExtract') is not null
		drop table #WalmartDisposalExtract

	if object_id('tempdb..#WalmartDisposalReceiptTransporter') is not null
		drop table #WalmartDisposalReceiptTransporter

	if object_id('tempdb..#WMDisposalGeneration') is not null
		drop table #WMDisposalGeneration

	if object_id('tempdb..#WMGenerationData') is not null
		drop table #WMGenerationData

	if object_id('tempdb..#WalmartDisposalExtract') is not null
		drop table #WalmartDisposalExtract

	if object_id('tempdb..#TotalData') is not null
		drop table #TotalData
			
		
	-- Work Orders using TSDFApprovals
	SELECT DISTINCT
		-- Walmart Fields:
		g.site_code AS site_code,
		g.generator_city AS generator_city,
		g.generator_state AS generator_state,
   		coalesce(wos.date_act_arrive, w.start_date) as service_date,
		g.epa_id AS epa_id,
		d.manifest AS manifest,
		CASE WHEN isnull(d.manifest_line, '') <> '' THEN
			CASE WHEN IsNumeric(d.manifest_line) <> 1 THEN
				dbo.fn_convert_manifest_line(d.manifest_line, d.manifest_page_num)
			ELSE
				d.manifest_line
			END
		ELSE
			NULL
		END AS manifest_line,
		CASE WHEN ISNULL(d.tsdf_approval_code, '') = '' THEN
			d.resource_class_code
		ELSE
			d.tsdf_approval_code
		END AS approval_or_resource,
		d.workorder_id as receipt_id,

		-- EQ Fields:
		w.company_id,
		w.profit_ctr_id,
		d.sequence_id as line_sequence_id,
		g.generator_id,
		g.site_type AS site_type,
		d.resource_type AS item_type,
		t.tsdf_approval_id,
		d.profile_id AS profile_id,
		'Workorder' AS source_table
	INTO #WalmartDisposalExtract
	FROM WorkOrderHeader w (nolock) 
	INNER JOIN WorkOrderDetail d  (nolock) ON w.workorder_id = d.workorder_id and w.company_id = d.company_id and w.profit_ctr_id = d.profit_ctr_id
		AND d.resource_type = 'D'
		AND d.bill_rate NOT IN (-2)
	INNER JOIN Generator g  (nolock) ON w.generator_id = g.generator_id
	LEFT OUTER JOIN TSDFApproval t  (nolock) ON d.tsdf_approval_id = t.tsdf_approval_id
		AND d.company_id = t.company_id
		AND d.profit_ctr_id = t.profit_ctr_id
	INNER JOIN TSDF t2  (nolock) ON d.tsdf_code = t2.tsdf_code
		AND ISNULL(t2.eq_flag, 'F') = 'F'
	LEFT OUTER JOIN WorkOrderStop wos (nolock) ON wos.workorder_id = w.workorder_id
		and wos.company_id = w.company_id
		and wos.profit_ctr_id = w.profit_ctr_id
		and wos.stop_sequence_id = 1 /* this will change in the future when there is more than 1 stop per workorder */
	WHERE 1=1
	AND (w.customer_id IN (select customer_id from @Customer)
		OR w.generator_id IN (SELECT generator_id FROM customergenerator  (nolock) WHERE customer_id IN (select customer_id from @Customer))
		OR w.generator_id IN (
			SELECT generator_id FROM generator (nolock) where site_type IN (
				SELECT site_type from @SiteTypeToInclude
			)
		)
	)
	AND w.start_date BETWEEN @start_date AND @end_date
	AND w.workorder_status IN ('A','C','D','N','P' /*,'X' */)
	AND w.billing_project_id not in (5486)
	AND w.submitted_flag = 'T'

	   -- 3rd party WOs Finished'


	--  Receipt/Transporter Fix'
	/*

	12/7/2010 - The primary source for EQ data is the Receipt table.
		It's out of order in the select logic below and needs to be reviewed/revised
		because it's misleading.
		
	This query has 2 union'd components:
	first component: workorder inner join to billinglinklookup and receipt
	third component: receipt not linked to either BLL or WMRWT
	*/

		select 
			r.receipt_id,
			r.line_id,
			r.company_id,
			r.profit_ctr_id,
			wo.workorder_id as receipt_workorder_id,
			wo.company_id as workorder_company_id,
			wo.profit_ctr_id as workorder_profit_ctr_id,
			isnull(rt1.transporter_sign_date, wo.start_date) as service_date,
			r.receipt_date,
			'F' as calc_recent_wo_flag
		into #WalmartDisposalReceiptTransporter
		from workorderheader wo (nolock) 
		inner join billinglinklookup bll  (nolock) on
			wo.company_id = bll.source_company_id
			and wo.profit_ctr_id = bll.source_profit_ctr_id
			and wo.workorder_id = bll.source_id
		inner join receipt r  (nolock) on bll.receipt_id = r.receipt_id
			and bll.profit_ctr_id = r.profit_ctr_id
			and bll.company_id = r.company_id
		left outer join receipttransporter rt1  (nolock) on rt1.receipt_id = r.receipt_id
			and rt1.profit_ctr_id = r.profit_ctr_id
			and rt1.company_id = r.company_id
			and rt1.transporter_sequence_id = 1
		inner join generator g  (nolock) on r.generator_id = g.generator_id
		where
			wo.start_date between @start_date AND @end_date
			and (1=0
				or wo.customer_id IN (select customer_id from @Customer)
				or wo.generator_id in (select generator_id from customergenerator  (nolock) where customer_id IN (select customer_id from @Customer))
				OR wo.generator_id IN (SELECT generator_id FROM generator  (nolock) where site_type IN (SELECT site_type from @SiteTypeToInclude))
				or r.customer_id IN (select customer_id from @Customer)
				or r.generator_id in (select generator_id from customergenerator  (nolock) where customer_id IN (select customer_id from @Customer))
				OR r.generator_id IN (SELECT generator_id FROM generator  (nolock) where site_type IN (SELECT site_type from @SiteTypeToInclude))
			)
			AND wo.billing_project_id not in (5486)
			AND r.billing_project_id not in (5486)
		union
		select 
			r.receipt_id,
			r.line_id,
			r.company_id,
			r.profit_ctr_id,
			null as receipt_workorder_id,
			null as workorder_company_id,
			null as workorder_profit_ctr_id,
			rt1.transporter_sign_date as service_date,
			r.receipt_date,
			'F' as calc_recent_wo_flag
		from receipt r (nolock) 
		inner join generator g  (nolock) on r.generator_id = g.generator_id
		left outer join receipttransporter rt1  (nolock) on rt1.receipt_id = r.receipt_id
			and rt1.profit_ctr_id = r.profit_ctr_id
			and rt1.company_id = r.company_id
			and rt1.transporter_sequence_id = 1
		where
			coalesce(rt1.transporter_sign_date, r.receipt_date) between @start_date AND @end_date
			and (r.customer_id IN (select customer_id from @Customer)
				or r.generator_id in (select generator_id from customergenerator  (nolock) where customer_id IN (select customer_id from @Customer))
				OR r.generator_id IN (SELECT generator_id FROM generator  (nolock) where site_type IN (SELECT site_type from @SiteTypeToInclude))
			)
			and not exists (
				select receipt_id from billinglinklookup bll (nolock) 
				where bll.company_id = r.company_id
				and bll.profit_ctr_id = r.profit_ctr_id
				and bll.receipt_id = r.receipt_id
			)
			AND r.billing_project_id not in (5486)


	   -- Receipt/Transporter Population Finished'





	-- Receipts
	INSERT #WalmartDisposalExtract
	SELECT distinct
		-- Walmart Fields:
		g.site_code AS site_code,
		g.generator_city AS generator_city,
		g.generator_state AS generator_state,
		wrt.service_date,
		g.epa_id,
		r.manifest AS manifest,
		CASE WHEN ISNULL(r.manifest_line, '') <> '' THEN
			CASE WHEN IsNumeric(r.manifest_line) <> 1 THEN
				dbo.fn_convert_manifest_line(r.manifest_line, r.manifest_page_num)
			ELSE
				r.manifest_line
			END
		ELSE
			NULL
		END AS manifest_line,
		COALESCE(replace(r.approval_code, 'WM' + right('0000' + g.site_code, 4), 'WM'), r.service_desc) AS approval_or_resource,
		wrt.receipt_id,

		-- EQ Fields:
		wrt.company_id,
		wrt.profit_ctr_id,
		r.line_id,
		r.generator_id,
		g.site_type AS site_type,
		r.trans_type AS item_type,
		NULL AS tsdf_approval_id,
		r.profile_id,
		'Receipt' AS source_table
	    
	FROM #WalmartDisposalReceiptTransporter wrt 
	INNER JOIN Receipt r ON
		r.company_id = wrt.company_id
		and r.profit_ctr_id = wrt.profit_ctr_id
		and r.receipt_id = wrt.receipt_id
		and r.line_id = wrt.line_id
		AND r.receipt_status = 'A'
		AND r.fingerpr_status = 'A'
		AND ISNULL(r.trans_type, '') = 'D'
		AND r.trans_mode = 'I'
		AND r.billing_project_id not in (5486)
		AND r.submitted_flag = 'T'
	INNER JOIN Generator g  (nolock) ON r.generator_id = g.generator_id


	   -- Receipts Finished'


	 -- Trip Export Information (where the data actually comes from workorder info that exists for disposal manifest info)
	  SELECT distinct
		  f.generator_id,
		  f.profile_id,
		  f.tsdf_approval_id,
		  f.site_code, 
		  f.generator_city, 
		  f.generator_state,
		  f.service_date as shipment_date,
		  case when wodi.month is null or wodi.year is null then
			convert(datetime, convert(varchar(2), datepart(m, f.service_date)) + '/01/' + convert(varchar(4), datepart(yyyy, f.service_date)))
			else
				convert(datetime, convert(varchar(2), wodi.month) + '/01/' + CONVERT(varchar(4), wodi.year)) 
		  end as generation_date,
		  f.epa_id,
		  case when f.approval_or_resource in (select approval_code from WalmartApprovalCodeRule where handling_rule = 'Generation Log Reported in hundredths of pounds') then
			 convert(numeric(6,2), round(sum( ( (isnull(wodi.pounds,0) * 1.0) + (isnull(wodi.ounces,0)/16.0) )  /* * isnull(wodi.merchandise_quantity,1) */ ),2) )
		  else
			  case when f.approval_or_resource in (select approval_code from WalmartApprovalCodeRule where handling_rule = '9-digit weight reporting') then
				 convert(numeric(20,9), 
					(sum(wodi.merchandise_quantity) * (select pound_conv from CustomerTypeEmptyBottleApproval where approval_code = f.approval_or_resource))
				 )
			  else
				 CASE WHEN 
					convert(numeric(7,2), round(sum( ( (isnull(wodi.pounds,0) * 1.0) + (isnull(wodi.ounces,0)/16.0) )  /* * isnull(wodi.merchandise_quantity,1) */ ),2) )
				 BETWEEN 0.0001 AND 1.0 THEN 
					1
				 ELSE
					round(convert(numeric(7,2), round(sum( ( (isnull(wodi.pounds,0) * 1.0) + (isnull(wodi.ounces,0)/16.0) )  /* * isnull(wodi.merchandise_quantity,1) */ ),2) ), 2)
				 END
			  end
		  END as Weight,
		  f.approval_or_resource,
		  f.manifest,
		  f.manifest_line,
		  f.company_id,
		  f.profit_ctr_id,
		  f.receipt_id,
		  f.item_type,
		  f.line_sequence_id,
		  exclude_flag = 
			  CASE WHEN (1=0
		  		-- exclude any generator that has a site type of Optical Lab, DC, Return Center, PMDC 
		  		OR f.site_type LIKE '%Optical Lab%'
		  		OR f.site_type LIKE '%DC%'
		  		OR f.site_type LIKE '%Return Center%'
		  		OR f.site_type LIKE '%PMDC%'
			  ) THEN 
				  'T'
			  ELSE
		  		/*
		  		exclude any non-hazardous or universal waste approvals: 
					approval numbers WMNHW01-WMNHW16, WMUW01-WMUW03 
					approvals that do not contain a RCRA hazardous waste code (D, F, K, P, U)
				*/
				  CASE WHEN (1=0
			  		OR f.approval_or_resource IN ('WMNHW01','WMNHW02','WMNHW03','WMNHW04','WMNHW05','WMNHW06','WMNHW07','WMNHW08','WMNHW09','WMNHW10','WMNHW11','WMNHW12','WMNHW13','WMNHW14','WMNHW15','WMNHW16')
					OR f.approval_or_resource IN ('WMUW01', 'WMUW02', 'WMUW03')
				  ) THEN
			  		'T'
				  ELSE
			  		CASE WHEN NOT EXISTS (
			  			SELECT tawc.waste_code
			  			FROM TSDFApprovalWasteCode tawc  (nolock)
			  			INNER JOIN WasteCode wc (nolock) on tawc.waste_code = wc.waste_code
			  			WHERE tawc.tsdf_approval_id = f.tsdf_approval_id
			  			AND tawc.company_id = f.company_id
			  			AND tawc.profit_ctr_id = f.profit_ctr_id
			  			AND f.tsdf_approval_id is not null
			  			AND wc.waste_code_origin = 'F'
			  			AND left(wc.waste_code, 1) in ('D', 'F', 'P', 'K', 'U')
			  			AND wc.haz_flag = 'T'
			  		) THEN
			  			'T'
			  		ELSE
			  			'F'
			  		END
				  END
				END
				
	  INTO #WMDisposalGeneration

	  from #WalmartDisposalExtract f (nolock)
	  inner join tsdfapproval tsdfa (nolock) on f.tsdf_approval_id = tsdfa.tsdf_approval_id
	  inner join tsdf (nolock) on tsdfa.tsdf_code = tsdf.tsdf_code and tsdf.eq_flag = 'F'
	  inner join workorderheader woh (nolock)       on f.receipt_id = woh.workorder_id
		  and f.company_id = woh.company_id
		  and f.profit_ctr_id = woh.profit_ctr_id
		  -- and woh.trip_id is not null
		  AND woh.billing_project_id not in (5486)
	  left outer join workorderdetailitem wodi (nolock)
		  on f.receipt_id = wodi.workorder_id
		  and f.line_sequence_id = wodi.sequence_id
		  and f.company_id = wodi.company_id
		  and f.profit_ctr_id = wodi.profit_ctr_id
		  AND wodi.added_by <> 'sa-extract'
	GROUP BY
		  f.generator_id,
		  f.profile_id,
		  f.tsdf_approval_id,
		  f.site_code, 
		  f.generator_city, 
		  f.generator_state,
		  f.service_date,
		  wodi.month,
		  wodi.year,
		  f.epa_id,
		  f.approval_or_resource,
		  f.manifest,
		  f.manifest_line,
		  f.company_id,
		  f.profit_ctr_id,
		  f.receipt_id,
		  f.item_type,
		  f.line_sequence_id,
		  f.site_type,
		  f.tsdf_approval_id
	HAVING -- 12/17/2010 - per Brie
		  case when f.approval_or_resource in (select approval_code from WalmartApprovalCodeRule where handling_rule = 'Generation Log Reported in hundredths of pounds') then
			 convert(numeric(6,2), round(sum( ( (isnull(wodi.pounds,0) * 1.0) + (isnull(wodi.ounces,0)/16.0) )  /* * isnull(wodi.merchandise_quantity,1) */ ),2) )
		  else
			  case when f.approval_or_resource in (select approval_code from WalmartApprovalCodeRule where handling_rule = '9-digit weight reporting') then
				 convert(numeric(20,9), 
					(sum(wodi.merchandise_quantity) * (select pound_conv from CustomerTypeEmptyBottleApproval where approval_code = f.approval_or_resource))
				 )
			  else
				 CASE WHEN 
					convert(numeric(7,2), round(sum( ( (isnull(wodi.pounds,0) * 1.0) + (isnull(wodi.ounces,0)/16.0) )  /* * isnull(wodi.merchandise_quantity,1) */ ),2) )
				 BETWEEN 0.0001 AND 1.0 THEN 
					1
				 ELSE
					round(convert(numeric(7,2), round(sum( ( (isnull(wodi.pounds,0) * 1.0) + (isnull(wodi.ounces,0)/16.0) )  /* * isnull(wodi.merchandise_quantity,1) */ ),2) ), 2)
				 END
			  end
		  END
		> 0
	  -- Above is 3rd party disposal
	  UNION
	  -- Below is EQ disposal
	  SELECT distinct
		  f.generator_id,
		  f.profile_id,
		  f.tsdf_approval_id,
		  f.site_code, 
		  f.generator_city, 
		  f.generator_state,
		  f.service_date as shipment_date,
		  case when rdi.month is null or rdi.year is null then
   			convert(datetime,  convert(varchar(2), datepart(m, f.service_date)) + '/01/' + convert(varchar(4), datepart(yyyy, f.service_date)) )
			else
				convert(datetime, convert(varchar(2), rdi.month) + '/01/' + CONVERT(varchar(4), rdi.year)) 
		  end as generation_date,
		  f.epa_id,
		  case when f.approval_or_resource in (select approval_code from WalmartApprovalCodeRule where handling_rule = 'Generation Log Reported in hundredths of pounds') then
      		convert(numeric(7,2), round(sum( ( (isnull(rdi.pounds,0) * 1.0) + (isnull(rdi.ounces,0)/16.0) )  /* * isnull(rdi.merchandise_quantity,1) */ ),2) ) 
		  else
			  case when f.approval_or_resource in (select approval_code from WalmartApprovalCodeRule where handling_rule = '9-digit weight reporting') then
				 convert(numeric(20,9), 
					(sum(rdi.merchandise_quantity) * (select pound_conv from CustomerTypeEmptyBottleApproval where approval_code = f.approval_or_resource))
				 )
			  else
				 CASE WHEN (
					CASE WHEN 
            			convert(numeric(7,2), round(sum( ( (isnull(rdi.pounds,0) * 1.0) + (isnull(rdi.ounces,0)/16.0) )  /* * isnull(rdi.merchandise_quantity,1) */ ),2) ) 
						BETWEEN 0.0001 AND 1.0 THEN 
						   1
						ELSE
						   round(convert(numeric(7,2), round(sum( ( (isnull(rdi.pounds,0) * 1.0) + (isnull(rdi.ounces,0)/16.0) )  /* * isnull(rdi.merchandise_quantity,1) */ ),2) ), 2)
					END
				 ) > 0 THEN
					CASE WHEN 
            				convert(numeric(7,2), round(sum( ( (isnull(rdi.pounds,0) * 1.0) + (isnull(rdi.ounces,0)/16.0) )  /* * isnull(rdi.merchandise_quantity,1) */ ),2) ) 
						BETWEEN 0.0001 AND 1.0 THEN 
						   1
						ELSE
						   round(convert(numeric(7,2), round(sum( ( (isnull(rdi.pounds,0) * 1.0) + (isnull(rdi.ounces,0)/16.0) )  /* * isnull(rdi.merchandise_quantity,1) */ ),2) ), 2)
					END
   				ELSE
   					(
   						select round(line_weight,0)
   						FROM receipt 
   						WHERE receipt_id = f.receipt_id 
   						and line_id = f.line_sequence_id 
   						AND company_id = f.company_id 
   						and profit_ctr_id = f.profit_ctr_id
   					)
   				END
   			  End
			END	AS Weight,
		  f.approval_or_resource,
		  f.manifest,
		  f.manifest_line,
		  f.company_id,
		  f.profit_ctr_id,
		  f.receipt_id,
		  f.item_type,
		  f.line_sequence_id,
		  exclude_flag = 
			  CASE WHEN (1=0
		  		-- exclude any generator that has a site type of Optical Lab, DC, Return Center, PMDC 
		  		OR f.site_type LIKE '%Optical Lab%'
		  		OR f.site_type LIKE '%DC%'
		  		OR f.site_type LIKE '%Return Center%'
		  		OR f.site_type LIKE '%PMDC%'
			  ) THEN 
				  'T'
			  ELSE
		  		/*
		  		exclude any non-hazardous or universal waste approvals: 
					approval numbers WMNHW01-WMNHW16, WMUW01-WMUW03 
					approvals that do not contain a RCRA hazardous waste code (D, F, K, P, U)
				*/
				  CASE WHEN (1=0
			  		OR f.approval_or_resource IN ('WMNHW01','WMNHW02','WMNHW03','WMNHW04','WMNHW05','WMNHW06','WMNHW07','WMNHW08','WMNHW09','WMNHW10','WMNHW11','WMNHW12','WMNHW13','WMNHW14','WMNHW15','WMNHW16')
					OR f.approval_or_resource IN ('WMUW01', 'WMUW02', 'WMUW03')
				  ) THEN
			  		'T'
				  ELSE
			  		CASE WHEN NOT EXISTS (
			  			SELECT wc.waste_code
			  			FROM ProfileWasteCode pwc  (nolock)
			  			INNER JOIN WasteCode wc (nolock) on pwc.waste_code = wc.waste_code
			  			WHERE pwc.profile_id = f.profile_id
			  			AND f.profile_id is not null
			  			AND wc.waste_code_origin = 'F'
			  			AND left(wc.waste_code, 1) in ('D', 'F', 'P', 'K', 'U')
			  			AND wc.haz_flag = 'T'
			  		) THEN
			  			'T'
			  		ELSE
			  			'F'
			  		END
				  END
				END
	  from 
	  (
		SELECT DISTINCT 
		  generator_id,
		  tsdf_approval_id,
		  site_code, 
		  generator_city, 
		  generator_state,
		  service_date,
		  epa_id,
		  approval_or_resource,
		  manifest,
		  manifest_line,
		  company_id,
		  profit_ctr_id,
		  receipt_id,
		  item_type,
		  line_sequence_id,
		  site_type,
		  profile_id
		FROM #WalmartDisposalExtract   (nolock)
	) f
	  inner join profilequoteapproval pro 
			on f.profile_id = pro.profile_id 
			and f.company_id = pro.company_id 
			and f.profit_ctr_id = pro.profit_ctr_id
	  left outer join ReceiptDetailItem rdi (nolock)
			on f.receipt_id = rdi.receipt_id
			and f.line_sequence_id = rdi.line_id
			and f.company_id = rdi.company_id
			and f.profit_ctr_id = rdi.profit_ctr_id
	  WHERE 1=1
	GROUP BY
		  f.generator_id,
		  f.profile_id,
		  f.tsdf_approval_id,
		  f.site_code, 
		  f.generator_city, 
		  f.generator_state,
		  f.service_date,
		  rdi.month,
		  rdi.year,
		  f.epa_id,
		  f.approval_or_resource,
		  f.manifest,
		  f.manifest_line,
		  f.company_id,
		  f.profit_ctr_id,
		  f.receipt_id,
		  f.item_type,
		  f.line_sequence_id,
		  f.site_type,
		  f.profile_id


	   -- Populating WMDisposalGeneration, Finished'

	UPDATE #WMDisposalGeneration
	SET weight = 
			 case when g.approval_or_resource in (select approval_code from WalmartApprovalCodeRule where handling_rule = 'Generation Log Reported in hundredths of pounds') then
					round(R.line_weight, 2)
				else
					case when g.approval_or_resource in (select approval_code from WalmartApprovalCodeRule where handling_rule = '9-digit weight reporting') then
						convert(numeric(20,9), 
							R.quantity * (select pound_conv from CustomerTypeEmptyBottleApproval where approval_code = g.approval_or_resource)
						)
					else
						case when round(R.line_weight, 0) between 0.00001 and 1 then 1 else round(R.line_weight, 0) end
					end
				end
	FROM #WMDisposalGeneration g
	INNER JOIN Receipt r
	   ON g.receipt_id = r.receipt_id
	   and g.company_id = r.company_id
	   and g.profit_ctr_id = r.profit_ctr_id
	   and g.line_sequence_id = r.line_id
	   and g.approval_or_resource = r.approval_code
	WHERE 1=1
		  and isnull(g.weight, 0) = 0
		  AND r.billing_project_id not in (5486)


	/*
	SELECT * FROM #WMDisposalGeneration where isnull(exclude_flag, 'F') = 'F'

	*/


	-- Summarize Generation Log info
	-- drop table #WMGenerationData

	select s.generator_id
		, CASE WHEN gst.generator_site_type_abbr IN ('Amigo', 'WNM', 'XPS') then 'SMALL' else gst.generator_site_type_abbr END AS store_format
		, g.generator_pickup_schedule_type as schedule
		, approval_or_resource
		, CASE WHEN s.profile_id is not null then p.approval_desc else ta.waste_desc end as description
		, generation_date
		, datepart(m, generation_date) as gen_month
		, datepart(yyyy, generation_date) as gen_year
		, sum(weight) as weight
	into #WMGenerationData
	from #WMDisposalGeneration s 
		inner join generator g on s.generator_id = g.generator_id
		LEFT OUTER JOIN GeneratorSiteType gst  (nolock) ON g.site_type = gst.generator_site_type
		LEFT OUTER JOIN profile p (nolock) on s.profile_id = p.profile_id and s.profile_id is not null
		LEFT OUTER JOIN tsdfapproval ta (nolock) ON ta.tsdf_approval_id = s.tsdf_approval_id and s.tsdf_approval_id is not null
	where isnull(exclude_flag, 'F') = 'F'
	group by 
		s.generator_id
		, CASE WHEN gst.generator_site_type_abbr IN ('Amigo', 'WNM', 'XPS') then 'SMALL' else gst.generator_site_type_abbr END
		, g.generator_pickup_schedule_type
		, approval_or_resource
		, CASE WHEN s.profile_id is not null then p.approval_desc else ta.waste_desc end
		, generation_date
		, datepart(m, generation_date)
		, datepart(yyyy, generation_date)
		
	-- For 2012 (whole year), everything above down to here took 49s.  That's not so bad.
	-- For 2013 (1/1 - 2/27, anyway), all above down to here took 34s.


		select 
			s.store_format AS format
			, s.approval_or_resource as waste_stream
			, s.description
			, sum(case when s.gen_month =  1 then weight else 0 end) as jan
			, sum(case when s.gen_month =  2 then weight else 0 end) as feb
			, sum(case when s.gen_month =  3 then weight else 0 end) as mar
			, sum(case when s.gen_month =  4 then weight else 0 end) as apr
			, sum(case when s.gen_month =  5 then weight else 0 end) as may
			, sum(case when s.gen_month =  6 then weight else 0 end) as jun
			, sum(case when s.gen_month =  7 then weight else 0 end) as jul
			, sum(case when s.gen_month =  8 then weight else 0 end) as aug
			, sum(case when s.gen_month =  9 then weight else 0 end) as sep
			, sum(case when s.gen_month = 10 then weight else 0 end) as oct
			, sum(case when s.gen_month = 11 then weight else 0 end) as nov
			, sum(case when s.gen_month = 12 then weight else 0 end) as dec
			, sum(weight) as totgen
		into #TotalData
		from #WMGenerationData s
		WHERE s.gen_year = @datayear
			-- AND s.schedule = '30'
		GROUP BY
			s.store_format
			, s.approval_or_resource
			, s.description

		if object_id('tempdb..#StoreRank') is not null
			drop table #StoreRank

		select gen_year, gen_month, store_format, generator_id
		, sum(weight) sumweight
		, row_number() over (partition by gen_year, gen_month, store_format order by sum(weight)) as row_desc
		, row_number() over (partition by gen_year, gen_month, store_format order by sum(weight) desc) as row_asc
		INTO #StoreRank
		FROM #WMGenerationData
		WHERE schedule = '30'
		group by gen_year, gen_month, store_format, generator_id

		
		if object_id('tempdb..#YTDTops') is not null
			drop table #YTDTops
		
		create table #YTDTops (
				ytd_year int
				,ytd_month int
				, store_format varchar(40)
				, schedule varchar(40)
				, generator_id int
				, store_rank int
				, store_rank_reverse int
				, waste_stream varchar(40)
				, description varchar(50)
				, waste_rank int
				, waste_rank_reverse int
				, monthly_total	float
			)
			
		insert #YTDTops
		select 
			s.gen_year as ytd_year
			, s.gen_month as ytd_month
			, s.store_format AS format
			, s.schedule
			, s.generator_id
			, sr.row_asc
			, sr.row_desc
			, s.approval_or_resource
			, s.description
			, row_number () OVER (
				PARTITION BY 
					s.gen_year
					, s.gen_month
					, s.store_format
					, s.generator_id
				ORDER BY sum(weight) desc
			) as waste_rank
			, row_number () OVER (
				PARTITION BY 
					s.gen_year
					, s.gen_month
					, s.store_format
					, s.generator_id
				ORDER BY sum(weight)
			) as waste_rank_reverse
			, sum(weight) as weight
		FROM #WMGenerationData s
		INNER JOIN #StoreRank sr 
			on s.generator_id = sr.generator_id
			and s.gen_year = sr.gen_year
			and s.gen_month = sr.gen_month
		WHERE s.schedule = '30'
		GROUP BY
			s.gen_year
			, s.gen_month
			, s.store_format
			, s.schedule
			, s.generator_id
			, sr.row_asc
			, sr.row_desc
			, s.approval_or_resource
			, s.description

	-- 3 minutes to finish #WMGeneratioNdata
	-- 14 minutes to finish #YTDTops

	delete from EQ_Extract.dbo.WMTopBottom_GenerationData where timestamp is null or timestamp = @timestamp
	delete from EQ_Extract.dbo.WMTopBottom_TotalData where timestamp is null or timestamp = @timestamp
	delete from EQ_Extract.dbo.WMTopBottom_YTDTops where timestamp is null or timestamp = @timestamp

	insert EQ_Extract.dbo.WMTopBottom_GenerationData  select *, @timestamp from #WMGenerationData
	insert EQ_Extract.dbo.WMTopBottom_TotalData  select *, @timestamp from #TotalData
	insert EQ_Extract.dbo.WMTopBottom_YTDTops  select *, @timestamp from #YTDTops

END -- End of Generation Routines

/***************************
Saved the run data into a permanent table for re-use by calls with specific timestmap & recordset values

-- Need to save:
	#WMGenerationData
	#TotalData -- derives from #WMGenerationData 
	#YTDTops -- derives from #WMGenerationData, #StoreRank

GRANT INSERT, UPDATE, DELETE, SELECT on EQ_Extract.dbo.WMTopBottom_GenerationData to EQAI, EQWEB
GRANT INSERT, UPDATE, DELETE, SELECT on EQ_Extract.dbo.WMTopBottom_TotalData to EQAI, EQWEB
GRANT INSERT, UPDATE, DELETE, SELECT on EQ_Extract.dbo.WMTopBottom_StoreRank to EQAI, EQWEB
GRANT INSERT, UPDATE, DELETE, SELECT on EQ_Extract.dbo.WMTopBottom_YTDTops to EQAI, EQWEB

***************************/



/* **************************************************************************
Finally:  ze Data.

We would probably want to save this to a REAL table with a date & user
and then refer to that data in future data shaping/exporting steps

SELECT * FROM #WMGenerationData

************************************************************************** */

-- OUTPUT REPORTS DATA


if @recordset = 'all stores' begin
-- All Stores

	select
		g.site_code as facility
		, s.store_format AS format
		, g.generator_city
		, g.generator_state
		, s.schedule
		, g.generator_facility_date_opened as opendate
		--  OpenDate
		--		This is the date that the store opened.
		, g.generator_market_code as market
		--	Market
		--		WM-supplied information
		, g.generator_region_code as region
		--	Region
		--		WM-supplied information
		, g.generator_annual_sales as annsales
		--	AnnSales
		--		WM-supplied information
		--		We may not ever get this, but should leave a column for it.
		, g.generator_facility_size as sqft
		--	SqFt
		--		WM-supplied information
		, sum(case when s.gen_month =  1 then weight else 0 end) as jan
		, sum(case when s.gen_month =  2 then weight else 0 end) as feb
		, sum(case when s.gen_month =  3 then weight else 0 end) as mar
		, sum(case when s.gen_month =  4 then weight else 0 end) as apr
		, sum(case when s.gen_month =  5 then weight else 0 end) as may
		, sum(case when s.gen_month =  6 then weight else 0 end) as jun
		, sum(case when s.gen_month =  7 then weight else 0 end) as jul
		, sum(case when s.gen_month =  8 then weight else 0 end) as aug
		, sum(case when s.gen_month =  9 then weight else 0 end) as sep
		, sum(case when s.gen_month = 10 then weight else 0 end) as oct
		, sum(case when s.gen_month = 11 then weight else 0 end) as nov
		, sum(case when s.gen_month = 12 then weight else 0 end) as dec
		, sum(weight) as totgensum
		, sum(weight) / (
			select count(distinct gen_month)
			from EQ_Extract.dbo.WMTopBottom_GenerationData
			where timestamp = @timestamp 
			and generator_id = s.generator_id 
			and gen_year = s.gen_year
			group by generator_id
			having sum(weight) > 0
		) as avgmogen
	from EQ_Extract.dbo.WMTopBottom_GenerationData s
	inner join generator g on s.generator_id = g.generator_id
	where timestamp = @timestamp 
		and  s.gen_year = @datayear
	GROUP BY
		s.gen_year
		, s.generator_id
		, g.site_code
		, s.store_format
		, g.generator_city
		, g.generator_state
		, s.schedule
		, g.generator_facility_date_opened
		, g.generator_market_code
		, g.generator_region_code
		, g.generator_annual_sales
		, g.generator_facility_size

	ORDER BY convert(int, g.site_code)
end


if @recordset = 'total generation - Monthly RCRA generation by format' begin
-- Total Generation

	-- Table 1: Monthly RCRA generation by format
	--	Small = Neighborhood Markets, Express, Amigos (PR) and Super Ahorros (PR)
	--	A total per sum-able column

	--	select 'Monthly RCRA generation by format' as table_name
	--	union
	--	select 'Total RCRA Generation' as table_name

	select a.*, 1 as _output_order_ignore 
	from
		( 
			select 
				s.format 
				, sum(jan) as jan , sum(feb) as feb , sum(mar) as mar , sum(apr) as apr , sum(may) as may , sum(jun) as jun 
				, sum(jul) as jul , sum(aug) as aug , sum(sep) as sep , sum(oct) as oct , sum(nov) as nov , sum(dec) as dec
				, sum(totgen) as totgensum
			from EQ_Extract.dbo.WMTopBottom_TotalData s WHERE timestamp = @timestamp
			GROUP BY s.format
		) a
	UNION
	select 'Total', sum(jan), sum(feb), sum(mar), sum(apr), sum(may), sum(jun), sum(jul), sum(aug), sum(sep), sum(oct), sum(nov), sum(dec), sum(totgensum), 2 as _output_order_ignore 
	from
		( 
			select 
				s.format 
				, sum(jan) as jan , sum(feb) as feb , sum(mar) as mar , sum(apr) as apr , sum(may) as may , sum(jun) as jun 
				, sum(jul) as jul , sum(aug) as aug , sum(sep) as sep , sum(oct) as oct , sum(nov) as nov , sum(dec) as dec
				, sum(totgen) as totgensum
			from EQ_Extract.dbo.WMTopBottom_TotalData s WHERE timestamp = @timestamp
			GROUP BY s.format
		) a
	ORDER BY _output_order_ignore, totgensum desc, format

END

if @recordset = 'total generation - Monthly generation of all RCRA waste streams' begin

	-- Table 2: Monthly generation of all RCRA waste streams
	--	Small = Neighborhood Markets, Express, Amigos (PR) and Super Ahorros (PR)
	--	A total per sum-able column

	-- select 'Monthly generation of all RCRA waste streams' as table_name
	-- union
	-- select 'Total RCRA Generation by Waste Stream (Rank High to Low)' as table_name

	select a.*, 1 as _output_order_ignore 
	from
		( 
			select 
				s.waste_stream , s.description 
				, sum(jan) as jan , sum(feb) as feb , sum(mar) as mar , sum(apr) as apr , sum(may) as may , sum(jun) as jun 
				, sum(jul) as jul , sum(aug) as aug , sum(sep) as sep , sum(oct) as oct , sum(nov) as nov , sum(dec) as dec
				, sum(totgen) as totgensum
			from EQ_Extract.dbo.WMTopBottom_TotalData s WHERE timestamp = @timestamp
			GROUP BY s.waste_stream , s.description
		) a
	UNION
	select 'Total', '', sum(jan), sum(feb), sum(mar), sum(apr), sum(may), sum(jun), sum(jul), sum(aug), sum(sep), sum(oct), sum(nov), sum(dec), sum(totgensum), 2 as _output_order_ignore 
	from
		( 
			select 
				s.waste_stream , s.description 
				, sum(jan) as jan , sum(feb) as feb , sum(mar) as mar , sum(apr) as apr , sum(may) as may , sum(jun) as jun 
				, sum(jul) as jul , sum(aug) as aug , sum(sep) as sep , sum(oct) as oct , sum(nov) as nov , sum(dec) as dec
				, sum(totgen) as totgensum
			from EQ_Extract.dbo.WMTopBottom_TotalData s WHERE timestamp = @timestamp
			GROUP BY s.waste_stream , s.description
		) a
	ORDER BY _output_order_ignore, totgensum desc, waste_stream

END

if @recordset LIKE 'total generation - Monthly Top 5 RCRA Waste Streams by Format%' begin

	-- 'total generation - Monthly Top 5 RCRA Waste Streams by Format: <TYPE>'
	-- <TYPE> must be one of: SUP WM SAMS SMALL
	-- ex 'total generation - Monthly Top 5 RCRA Waste Streams by Format: SAMS'
	
	delete from #param
	insert #param (idx, row, size)
	select idx, row, size from dbo.fn_splitxsvtext(':', 1, @recordset)
	select @format = row from #param where idx = 2

	-- Table 3: Monthly Top 5 RCRA Waste Streams by Format (For SUP format stores)
	--	Small = Neighborhood Markets, Express, Amigos (PR) and Super Ahorros (PR)
	--	A total per sum-able column

	-- select 'Monthly Top 5 RCRA Waste Streams by Format' as table_name


	-- select 'Top 5 Total RCRA Waste Stream by Format (Rank High to Low) - ' + @format as table_name

	select a.*, 1 as _output_order_ignore 
	from
		( 
			select top 5
				s.format , s.waste_stream , s.description 
				, sum(jan) as jan , sum(feb) as feb , sum(mar) as mar , sum(apr) as apr , sum(may) as may , sum(jun) as jun 
				, sum(jul) as jul , sum(aug) as aug , sum(sep) as sep , sum(oct) as oct , sum(nov) as nov , sum(dec) as dec
				, sum(totgen) as totgensum
			from EQ_Extract.dbo.WMTopBottom_TotalData s WHERE timestamp = @timestamp and s.format = @format
			GROUP BY s.format , s.waste_stream , s.description
			ORDER BY totgensum desc, waste_stream
		) a
	UNION
	select 'Total', '', '', sum(jan), sum(feb), sum(mar), sum(apr), sum(may), sum(jun), sum(jul), sum(aug), sum(sep), sum(oct), sum(nov), sum(dec), sum(totgensum), 2 as _output_order_ignore 
	from
		( 
			select top 5
				s.format , s.waste_stream , s.description 
				, sum(jan) as jan , sum(feb) as feb , sum(mar) as mar , sum(apr) as apr , sum(may) as may , sum(jun) as jun 
				, sum(jul) as jul , sum(aug) as aug , sum(sep) as sep , sum(oct) as oct , sum(nov) as nov , sum(dec) as dec
				, sum(totgen) as totgensum
			from EQ_Extract.dbo.WMTopBottom_TotalData s WHERE timestamp = @timestamp and s.format = @format
			GROUP BY s.format , s.waste_stream , s.description
			ORDER BY totgensum desc, waste_stream
		) a
	ORDER BY _output_order_ignore, totgensum desc, waste_stream
	
END


if @recordset = 'Average RCRA Generation per Facility by Format' begin

-- Average Generation
--	select 'Average Generation' as Tab


	-- prelim work
--	declare @datayear int = 2013

	-- Table 1: Average RCRA Generation per Facility by Format
	--	A total per sum-able column

-- select 'Average RCRA Generation per Facility by Format' as table_name

-- declare @datayear int = 2013

	select 
		s.store_format AS format
		, jan = ( select sum(weight) / count(distinct generator_id) from EQ_Extract.dbo.WMTopBottom_GenerationData sa where timestamp = @timestamp and sa.store_format = s.store_format and  
			 1 = sa.gen_month and sa.gen_year = s.gen_year)
		, feb = ( select sum(weight) / count(distinct generator_id) from EQ_Extract.dbo.WMTopBottom_GenerationData sa where timestamp = @timestamp and sa.store_format = s.store_format and  
			 2 = sa.gen_month and sa.gen_year = s.gen_year)
		, mar = ( select sum(weight) / count(distinct generator_id) from EQ_Extract.dbo.WMTopBottom_GenerationData sa where timestamp = @timestamp and sa.store_format = s.store_format and  
			 3 = sa.gen_month and sa.gen_year = s.gen_year)
		, apr = ( select sum(weight) / count(distinct generator_id) from EQ_Extract.dbo.WMTopBottom_GenerationData sa where timestamp = @timestamp and sa.store_format = s.store_format and  
			 4 = sa.gen_month and sa.gen_year = s.gen_year)
		, may = ( select sum(weight) / count(distinct generator_id) from EQ_Extract.dbo.WMTopBottom_GenerationData sa where timestamp = @timestamp and sa.store_format = s.store_format and  
			 5 = sa.gen_month and sa.gen_year = s.gen_year)
		, jun = ( select sum(weight) / count(distinct generator_id) from EQ_Extract.dbo.WMTopBottom_GenerationData sa where timestamp = @timestamp and sa.store_format = s.store_format and  
			 6 = sa.gen_month and sa.gen_year = s.gen_year)
		, jul = ( select sum(weight) / count(distinct generator_id) from EQ_Extract.dbo.WMTopBottom_GenerationData sa where timestamp = @timestamp and sa.store_format = s.store_format and  
			 7 = sa.gen_month and sa.gen_year = s.gen_year)
		, aug = ( select sum(weight) / count(distinct generator_id) from EQ_Extract.dbo.WMTopBottom_GenerationData sa where timestamp = @timestamp and sa.store_format = s.store_format and  
			 8 = sa.gen_month and sa.gen_year = s.gen_year)
		, sep = ( select sum(weight) / count(distinct generator_id) from EQ_Extract.dbo.WMTopBottom_GenerationData sa where timestamp = @timestamp and sa.store_format = s.store_format and  
			 9 = sa.gen_month and sa.gen_year = s.gen_year)
		, oct = ( select sum(weight) / count(distinct generator_id) from EQ_Extract.dbo.WMTopBottom_GenerationData sa where timestamp = @timestamp and sa.store_format = s.store_format and  
			10 = sa.gen_month and sa.gen_year = s.gen_year)
		, nov = ( select sum(weight) / count(distinct generator_id) from EQ_Extract.dbo.WMTopBottom_GenerationData sa where timestamp = @timestamp and sa.store_format = s.store_format and  
			11 = sa.gen_month and sa.gen_year = s.gen_year)
		, dec = ( select sum(weight) / count(distinct generator_id) from EQ_Extract.dbo.WMTopBottom_GenerationData sa where timestamp = @timestamp and sa.store_format = s.store_format and  
			12 = sa.gen_month and sa.gen_year = s.gen_year)
		, avggen = ( select (sum(weight) / count(distinct generator_id)) / count(distinct gen_month) from EQ_Extract.dbo.WMTopBottom_GenerationData sa where timestamp = @timestamp and sa.store_format = s.store_format and  
			 sa.gen_year = s.gen_year)
		, 1 as _output_order_ignore
	from EQ_Extract.dbo.WMTopBottom_GenerationData s
	WHERE s.timestamp = @timestamp
		AND s.gen_year = @datayear
		-- AND s.schedule = '30'
	GROUP BY 
		s.gen_year
		, s.store_format
		-- , s.schedule

	UNION

		-- Total row for above:
		select distinct 
			'Average'
		, jan = ( select sum(weight) / count(distinct generator_id) from EQ_Extract.dbo.WMTopBottom_GenerationData sa where timestamp = @timestamp and  
			 1 = sa.gen_month and sa.gen_year = s.gen_year)
		, feb = ( select sum(weight) / count(distinct generator_id) from EQ_Extract.dbo.WMTopBottom_GenerationData sa where timestamp = @timestamp and  
			 2 = sa.gen_month and sa.gen_year = s.gen_year)
		, mar = ( select sum(weight) / count(distinct generator_id) from EQ_Extract.dbo.WMTopBottom_GenerationData sa where timestamp = @timestamp and  
			 3 = sa.gen_month and sa.gen_year = s.gen_year)
		, apr = ( select sum(weight) / count(distinct generator_id) from EQ_Extract.dbo.WMTopBottom_GenerationData sa where timestamp = @timestamp and  
			 4 = sa.gen_month and sa.gen_year = s.gen_year)
		, may = ( select sum(weight) / count(distinct generator_id) from EQ_Extract.dbo.WMTopBottom_GenerationData sa where timestamp = @timestamp and  
			 5 = sa.gen_month and sa.gen_year = s.gen_year)
		, jun = ( select sum(weight) / count(distinct generator_id) from EQ_Extract.dbo.WMTopBottom_GenerationData sa where timestamp = @timestamp and  
			 6 = sa.gen_month and sa.gen_year = s.gen_year)
		, jul = ( select sum(weight) / count(distinct generator_id) from EQ_Extract.dbo.WMTopBottom_GenerationData sa where timestamp = @timestamp and  
			 7 = sa.gen_month and sa.gen_year = s.gen_year)
		, aug = ( select sum(weight) / count(distinct generator_id) from EQ_Extract.dbo.WMTopBottom_GenerationData sa where timestamp = @timestamp and  
			 8 = sa.gen_month and sa.gen_year = s.gen_year)
		, sep = ( select sum(weight) / count(distinct generator_id) from EQ_Extract.dbo.WMTopBottom_GenerationData sa where timestamp = @timestamp and  
			 9 = sa.gen_month and sa.gen_year = s.gen_year)
		, oct = ( select sum(weight) / count(distinct generator_id) from EQ_Extract.dbo.WMTopBottom_GenerationData sa where timestamp = @timestamp and  
			10 = sa.gen_month and sa.gen_year = s.gen_year)
		, nov = ( select sum(weight) / count(distinct generator_id) from EQ_Extract.dbo.WMTopBottom_GenerationData sa where timestamp = @timestamp and  
			11 = sa.gen_month and sa.gen_year = s.gen_year)
		, dec = ( select sum(weight) / count(distinct generator_id) from EQ_Extract.dbo.WMTopBottom_GenerationData sa where timestamp = @timestamp and  
			12 = sa.gen_month and sa.gen_year = s.gen_year)
		, avggen = ( select (sum(weight) / count(distinct generator_id)) / count(distinct gen_month) from EQ_Extract.dbo.WMTopBottom_GenerationData sa where timestamp = @timestamp and 
			 sa.gen_year = s.gen_year)
		, 2 as _output_order_ignore
		from EQ_Extract.dbo.WMTopBottom_GenerationData s
		WHERE s.timestamp = @timestamp 
		AND s.gen_year = @datayear
			-- AND s.schedule = '30'
	ORDER BY 
		_output_order_ignore
		, s.store_format
END

if @recordset = 'Average RCRA Generation by Waste Stream (Rank High to Low)' begin

	-- Table 2: Average RCRA Generation by Waste Stream (Rank High to Low)
	--	A total per sum-able column

	-- declare @datayear int = 2013
	-- select 'Average RCRA Generation by Waste Stream (Rank High to Low)' as table_name

	select 
		approval_or_resource as waste_stream
		, s.description
		, jan = ( select avg(weight) from EQ_Extract.dbo.WMTopBottom_GenerationData sa where timestamp = @timestamp and sa.approval_or_resource = s.approval_or_resource and 
			 1 = sa.gen_month and sa.gen_year = s.gen_year)
		, feb = ( select avg(weight) from EQ_Extract.dbo.WMTopBottom_GenerationData sa where timestamp = @timestamp and sa.approval_or_resource = s.approval_or_resource and 
			 2 = sa.gen_month and sa.gen_year = s.gen_year)
		, mar = ( select avg(weight) from EQ_Extract.dbo.WMTopBottom_GenerationData sa where timestamp = @timestamp and sa.approval_or_resource = s.approval_or_resource and 
			 3 = sa.gen_month and sa.gen_year = s.gen_year)
		, apr = ( select avg(weight) from EQ_Extract.dbo.WMTopBottom_GenerationData sa where timestamp = @timestamp and sa.approval_or_resource = s.approval_or_resource and 
			 4 = sa.gen_month and sa.gen_year = s.gen_year)
		, may = ( select avg(weight) from EQ_Extract.dbo.WMTopBottom_GenerationData sa where timestamp = @timestamp and sa.approval_or_resource = s.approval_or_resource and 
			 5 = sa.gen_month and sa.gen_year = s.gen_year)
		, jun = ( select avg(weight) from EQ_Extract.dbo.WMTopBottom_GenerationData sa where timestamp = @timestamp and sa.approval_or_resource = s.approval_or_resource and 
			 6 = sa.gen_month and sa.gen_year = s.gen_year)
		, jul = ( select avg(weight) from EQ_Extract.dbo.WMTopBottom_GenerationData sa where timestamp = @timestamp and sa.approval_or_resource = s.approval_or_resource and 
			 7 = sa.gen_month and sa.gen_year = s.gen_year)
		, aug = ( select avg(weight) from EQ_Extract.dbo.WMTopBottom_GenerationData sa where timestamp = @timestamp and sa.approval_or_resource = s.approval_or_resource and 
			 8 = sa.gen_month and sa.gen_year = s.gen_year)
		, sep = ( select avg(weight) from EQ_Extract.dbo.WMTopBottom_GenerationData sa where timestamp = @timestamp and sa.approval_or_resource = s.approval_or_resource and 
			 9 = sa.gen_month and sa.gen_year = s.gen_year)
		, oct = ( select avg(weight) from EQ_Extract.dbo.WMTopBottom_GenerationData sa where timestamp = @timestamp and sa.approval_or_resource = s.approval_or_resource and 
			10 = sa.gen_month and sa.gen_year = s.gen_year)
		, nov = ( select avg(weight) from EQ_Extract.dbo.WMTopBottom_GenerationData sa where timestamp = @timestamp and sa.approval_or_resource = s.approval_or_resource and 
			11 = sa.gen_month and sa.gen_year = s.gen_year)
		, dec = ( select avg(weight) from EQ_Extract.dbo.WMTopBottom_GenerationData sa where timestamp = @timestamp and sa.approval_or_resource = s.approval_or_resource and 
			12 = sa.gen_month and sa.gen_year = s.gen_year)
		, avggen = avg(weight)
		, 1 as _output_order_ignore
	from EQ_Extract.dbo.WMTopBottom_GenerationData s
	WHERE s.timestamp = @timestamp
		AND s.gen_year = @datayear
		-- AND s.schedule = '30'
	GROUP BY
		s.gen_year
		, s.approval_or_resource
		, s.description
		-- , s.schedule

	UNION
		-- Question: Spreadsheet says Total. Did they mean Total Average?
		-- Total row for above:
		select distinct 
			'Average', ''
		, jan = ( select avg(weight) from EQ_Extract.dbo.WMTopBottom_GenerationData sa where timestamp = @timestamp and 
			 1 = sa.gen_month and sa.gen_year = s.gen_year)
		, feb = ( select avg(weight) from EQ_Extract.dbo.WMTopBottom_GenerationData sa where timestamp = @timestamp and 
			 2 = sa.gen_month and sa.gen_year = s.gen_year)
		, mar = ( select avg(weight) from EQ_Extract.dbo.WMTopBottom_GenerationData sa where timestamp = @timestamp and 
			 3 = sa.gen_month and sa.gen_year = s.gen_year)
		, apr = ( select avg(weight) from EQ_Extract.dbo.WMTopBottom_GenerationData sa where timestamp = @timestamp and 
			 4 = sa.gen_month and sa.gen_year = s.gen_year)
		, may = ( select avg(weight) from EQ_Extract.dbo.WMTopBottom_GenerationData sa where timestamp = @timestamp and 
			 5 = sa.gen_month and sa.gen_year = s.gen_year)
		, jun = ( select avg(weight) from EQ_Extract.dbo.WMTopBottom_GenerationData sa where timestamp = @timestamp and 
			 6 = sa.gen_month and sa.gen_year = s.gen_year)
		, jul = ( select avg(weight) from EQ_Extract.dbo.WMTopBottom_GenerationData sa where timestamp = @timestamp and 
			 7 = sa.gen_month and sa.gen_year = s.gen_year)
		, aug = ( select avg(weight) from EQ_Extract.dbo.WMTopBottom_GenerationData sa where timestamp = @timestamp and 
			 8 = sa.gen_month and sa.gen_year = s.gen_year)
		, sep = ( select avg(weight) from EQ_Extract.dbo.WMTopBottom_GenerationData sa where timestamp = @timestamp and 
			 9 = sa.gen_month and sa.gen_year = s.gen_year)
		, oct = ( select avg(weight) from EQ_Extract.dbo.WMTopBottom_GenerationData sa where timestamp = @timestamp and 
			10 = sa.gen_month and sa.gen_year = s.gen_year)
		, nov = ( select avg(weight) from EQ_Extract.dbo.WMTopBottom_GenerationData sa where timestamp = @timestamp and 
			11 = sa.gen_month and sa.gen_year = s.gen_year)
		, dec = ( select avg(weight) from EQ_Extract.dbo.WMTopBottom_GenerationData sa where timestamp = @timestamp and 
			12 = sa.gen_month and sa.gen_year = s.gen_year)
		, NULL
		, 2 as _output_order_ignore
		from EQ_Extract.dbo.WMTopBottom_GenerationData s
		WHERE s.timestamp = @timestamp
		AND s.gen_year = @datayear
			-- AND s.schedule = '30'
	ORDER BY 
		_output_order_ignore
		, avg(weight) desc
		, approval_or_resource
END



if @recordset LIKE 'Top 5 Average RCRA Generation by Waste Stream by Format (Rank High to Low)%' begin

	-- 'Top 5 Average RCRA Generation by Waste Stream by Format (Rank High to Low): <TYPE>'
	-- <TYPE> must be one of: SUP WM SAMS SMALL
	-- ex 'Top 5 Average RCRA Generation by Waste Stream by Format (Rank High to Low): SAMS'

	-- Table 3: Top 5 Average RCRA Generation by Waste Stream by Format (Rank High to Low)
	--	A total per sum-able column

	-- declare @datayear int = 2013
	
	delete from #param
	insert #param (idx, row, size)
	select idx, row, size from dbo.fn_splitxsvtext(':', 1, @recordset)
	select @format = row from #param where idx = 2

	-- select 'Top 5 Average RCRA Generation by Waste Stream by Format (Rank High to Low) - ' + @format as table_name
	
	select *, 1 as _output_order_ignore 
	from (
		select top 5
			s.store_format AS format
			, s.approval_or_resource as waste_stream
			, s.description
			, jan = ( select sum(weight) / count(distinct generator_id) from EQ_Extract.dbo.WMTopBottom_GenerationData sa where timestamp = @timestamp and sa.store_format = s.store_format  and sa.approval_or_resource = s.approval_or_resource and 
				 1 = sa.gen_month and sa.gen_year = s.gen_year)
			, feb = ( select sum(weight) / count(distinct generator_id) from EQ_Extract.dbo.WMTopBottom_GenerationData sa where timestamp = @timestamp and sa.store_format = s.store_format  and sa.approval_or_resource = s.approval_or_resource and 
				 2 = sa.gen_month and sa.gen_year = s.gen_year)
			, mar = ( select sum(weight) / count(distinct generator_id) from EQ_Extract.dbo.WMTopBottom_GenerationData sa where timestamp = @timestamp and sa.store_format = s.store_format  and sa.approval_or_resource = s.approval_or_resource and 
				 3 = sa.gen_month and sa.gen_year = s.gen_year)
			, apr = ( select sum(weight) / count(distinct generator_id) from EQ_Extract.dbo.WMTopBottom_GenerationData sa where timestamp = @timestamp and sa.store_format = s.store_format  and sa.approval_or_resource = s.approval_or_resource and 
				 4 = sa.gen_month and sa.gen_year = s.gen_year)
			, may = ( select sum(weight) / count(distinct generator_id) from EQ_Extract.dbo.WMTopBottom_GenerationData sa where timestamp = @timestamp and sa.store_format = s.store_format  and sa.approval_or_resource = s.approval_or_resource and 
				 5 = sa.gen_month and sa.gen_year = s.gen_year)
			, jun = ( select sum(weight) / count(distinct generator_id) from EQ_Extract.dbo.WMTopBottom_GenerationData sa where timestamp = @timestamp and sa.store_format = s.store_format  and sa.approval_or_resource = s.approval_or_resource and 
				 6 = sa.gen_month and sa.gen_year = s.gen_year)
			, jul = ( select sum(weight) / count(distinct generator_id) from EQ_Extract.dbo.WMTopBottom_GenerationData sa where timestamp = @timestamp and sa.store_format = s.store_format  and sa.approval_or_resource = s.approval_or_resource and 
				 7 = sa.gen_month and sa.gen_year = s.gen_year)
			, aug = ( select sum(weight) / count(distinct generator_id) from EQ_Extract.dbo.WMTopBottom_GenerationData sa where timestamp = @timestamp and sa.store_format = s.store_format  and sa.approval_or_resource = s.approval_or_resource and 
				 8 = sa.gen_month and sa.gen_year = s.gen_year)
			, sep = ( select sum(weight) / count(distinct generator_id) from EQ_Extract.dbo.WMTopBottom_GenerationData sa where timestamp = @timestamp and sa.store_format = s.store_format  and sa.approval_or_resource = s.approval_or_resource and 
				 9 = sa.gen_month and sa.gen_year = s.gen_year)
			, oct = ( select sum(weight) / count(distinct generator_id) from EQ_Extract.dbo.WMTopBottom_GenerationData sa where timestamp = @timestamp and sa.store_format = s.store_format  and sa.approval_or_resource = s.approval_or_resource and 
				10 = sa.gen_month and sa.gen_year = s.gen_year)
			, nov = ( select sum(weight) / count(distinct generator_id) from EQ_Extract.dbo.WMTopBottom_GenerationData sa where timestamp = @timestamp and sa.store_format = s.store_format  and sa.approval_or_resource = s.approval_or_resource and 
				11 = sa.gen_month and sa.gen_year = s.gen_year)
			, dec = ( select sum(weight) / count(distinct generator_id) from EQ_Extract.dbo.WMTopBottom_GenerationData sa where timestamp = @timestamp and sa.store_format = s.store_format  and sa.approval_or_resource = s.approval_or_resource and 
				12 = sa.gen_month and sa.gen_year = s.gen_year)
			, avggen = ( select avg(weight) from EQ_Extract.dbo.WMTopBottom_GenerationData sa where timestamp = @timestamp and sa.store_format = s.store_format and sa.approval_or_resource = s.approval_or_resource and 
				sa.gen_year = s.gen_year)
		from EQ_Extract.dbo.WMTopBottom_GenerationData s
		WHERE s.timestamp = @timestamp
		AND s.gen_year = @datayear
			AND s.store_format = @format
			-- AND s.schedule = '30'
		GROUP BY
			s.gen_year , s.store_format , s.approval_or_resource , s.description -- , s.schedule
		ORDER BY avggen desc, approval_or_resource
	) a
	UNION
		-- declare @datayear int = 2013
	select 'Average', '', ''
			, avg(jan) as jan , avg(feb) as feb , avg(mar) as mar , avg(apr) as apr , avg(may) as may , avg(jun) as jun 
			, avg(jul) as jul , avg(aug) as aug , avg(sep) as sep , avg(oct) as oct , avg(nov) as nov , avg(dec) as dec
			, avg(avggen) as avggen
			, 2 as _output_order_ignore 
	from (
	-- declare @datayear int = 2013
		select top 5
			s.store_format AS format
			, s.approval_or_resource as waste_stream
			, s.description
			, jan = ( select sum(weight) / count(distinct generator_id) from EQ_Extract.dbo.WMTopBottom_GenerationData sa where timestamp = @timestamp and sa.store_format = s.store_format and sa.approval_or_resource = s.approval_or_resource and 
				 1 = sa.gen_month and sa.gen_year = s.gen_year)
			, feb = ( select sum(weight) / count(distinct generator_id) from EQ_Extract.dbo.WMTopBottom_GenerationData sa where timestamp = @timestamp and sa.store_format = s.store_format and sa.approval_or_resource = s.approval_or_resource and 
				 2 = sa.gen_month and sa.gen_year = s.gen_year)
			, mar = ( select sum(weight) / count(distinct generator_id) from EQ_Extract.dbo.WMTopBottom_GenerationData sa where timestamp = @timestamp and sa.store_format = s.store_format and sa.approval_or_resource = s.approval_or_resource and 
				 3 = sa.gen_month and sa.gen_year = s.gen_year)
			, apr = ( select sum(weight) / count(distinct generator_id) from EQ_Extract.dbo.WMTopBottom_GenerationData sa where timestamp = @timestamp and sa.store_format = s.store_format and sa.approval_or_resource = s.approval_or_resource and 
				 4 = sa.gen_month and sa.gen_year = s.gen_year)
			, may = ( select sum(weight) / count(distinct generator_id) from EQ_Extract.dbo.WMTopBottom_GenerationData sa where timestamp = @timestamp and sa.store_format = s.store_format and sa.approval_or_resource = s.approval_or_resource and 
				 5 = sa.gen_month and sa.gen_year = s.gen_year)
			, jun = ( select sum(weight) / count(distinct generator_id) from EQ_Extract.dbo.WMTopBottom_GenerationData sa where timestamp = @timestamp and sa.store_format = s.store_format and sa.approval_or_resource = s.approval_or_resource and 
				 6 = sa.gen_month and sa.gen_year = s.gen_year)
			, jul = ( select sum(weight) / count(distinct generator_id) from EQ_Extract.dbo.WMTopBottom_GenerationData sa where timestamp = @timestamp and sa.store_format = s.store_format and sa.approval_or_resource = s.approval_or_resource and 
				 7 = sa.gen_month and sa.gen_year = s.gen_year)
			, aug = ( select sum(weight) / count(distinct generator_id) from EQ_Extract.dbo.WMTopBottom_GenerationData sa where timestamp = @timestamp and sa.store_format = s.store_format and sa.approval_or_resource = s.approval_or_resource and 
				 8 = sa.gen_month and sa.gen_year = s.gen_year)
			, sep = ( select sum(weight) / count(distinct generator_id) from EQ_Extract.dbo.WMTopBottom_GenerationData sa where timestamp = @timestamp and sa.store_format = s.store_format and sa.approval_or_resource = s.approval_or_resource and 
				 9 = sa.gen_month and sa.gen_year = s.gen_year)
			, oct = ( select sum(weight) / count(distinct generator_id) from EQ_Extract.dbo.WMTopBottom_GenerationData sa where timestamp = @timestamp and sa.store_format = s.store_format and sa.approval_or_resource = s.approval_or_resource and 
				10 = sa.gen_month and sa.gen_year = s.gen_year)
			, nov = ( select sum(weight) / count(distinct generator_id) from EQ_Extract.dbo.WMTopBottom_GenerationData sa where timestamp = @timestamp and sa.store_format = s.store_format and sa.approval_or_resource = s.approval_or_resource and 
				11 = sa.gen_month and sa.gen_year = s.gen_year)
			, dec = ( select sum(weight) / count(distinct generator_id) from EQ_Extract.dbo.WMTopBottom_GenerationData sa where timestamp = @timestamp and sa.store_format = s.store_format and sa.approval_or_resource = s.approval_or_resource and 
				12 = sa.gen_month and sa.gen_year = s.gen_year)
			, avggen = ( select avg(weight) from EQ_Extract.dbo.WMTopBottom_GenerationData sa where timestamp = @timestamp and sa.store_format = s.store_format and sa.approval_or_resource = s.approval_or_resource and 
				sa.gen_year = s.gen_year)
		from EQ_Extract.dbo.WMTopBottom_GenerationData s
		WHERE s.timestamp = @timestamp
		AND s.gen_year = @datayear
			AND s.store_format = @format
			-- AND s.schedule = '30'
		GROUP BY
			s.gen_year , s.store_format , s.approval_or_resource , s.description -- , s.schedule
		ORDER BY avggen desc, approval_or_resource
	) a
	ORDER BY _output_order_ignore, avggen desc
	
END
	


if @recordset LIKE 'Top 10 Summary%' begin

	-- Top/Bottom 10

		-- Preliminary work:
			-- Need to calculate the ranks of every store and it's profiles for the YTD, per month


	-- Top 10
		-- First table: Top 10 SUP types, summary

	-- 'Top 10 Summary: <TYPE>'
	-- <TYPE> must be one of: SUP WM SAMS SMALL
	-- ex 'Top 10 Summary: SAMS'
	
	delete from #param
	insert #param (idx, row, size)
	select idx, row, size from dbo.fn_splitxsvtext(':', 1, @recordset)
	select @format = row from #param where idx = 2
		
	select TOP 10
		s.store_rank as row_rank
		, g.site_code as facility
		, s.store_format AS format
		, g.generator_city
		, g.generator_state
		, g.generator_region_code as region
		, g.generator_market_code as market
		-- , sum(s.monthly_total)
	from EQ_Extract.dbo.WMTopBottom_YTDTops s
	inner join generator g on s.generator_id = g.generator_id
	WHERE s.timestamp = @timestamp
	AND ytd_year = @datayear
	AND ytd_month = @datamonth
	AND store_format = @format
	and store_rank <= 10
	group by 
		s.store_rank
		, g.site_code
		, s.store_format
		, g.generator_city
		, g.generator_state
		, g.generator_region_code
		, g.generator_market_code
	order by s.store_rank, sum(s.monthly_total) desc
END

if @recordset LIKE 'Top 10 Detail%' begin

	-- 'Top 10 Detail: <TYPE>'
	-- <TYPE> must be one of: SUP WM SAMS SMALL
	-- ex 'Top 10 Detail: SAMS'
	
	delete from #param
	insert #param (idx, row, size)
	select idx, row, size from dbo.fn_splitxsvtext(':', 1, @recordset)
	select @format = row from #param where idx = 2
	
	select
		s.store_rank
		-- , s.generator_id
		, g.site_code as facility
		, s.store_format AS format
		, g.generator_city
		, g.generator_state
		, s.schedule
		, g.generator_region_code as region
		, g.generator_market_code as market
		, s.waste_rank
		, s.waste_stream
		, s.description
		, s.monthly_total as monthly_total
		, ( 
			select avg(monthly_total) 
			from EQ_Extract.dbo.WMTopBottom_YTDTops
			where timestamp = @timestamp
			and generator_id = s.generator_id 
			and waste_stream = s.waste_stream
			and ytd_year = s.ytd_year
			) as monthly_average 
		, ( 
			select avg(monthly_total) 
			from EQ_Extract.dbo.WMTopBottom_YTDTops
			where timestamp = @timestamp
			and generator_id = s.generator_id 
			and waste_stream = s.waste_stream
			and ytd_year = s.ytd_year
			and ytd_month in (1,2)
			) as standard_amount
		, s.monthly_total - ( 
			select avg(monthly_total) 
			from EQ_Extract.dbo.WMTopBottom_YTDTops
			where timestamp = @timestamp
			and generator_id = s.generator_id 
			and waste_stream = s.waste_stream
			and ytd_year = s.ytd_year
			and ytd_month in (1,2)
			) as CompToStd
		, round(((s.monthly_total / ( 
			select avg(monthly_total)
			from EQ_Extract.dbo.WMTopBottom_YTDTops
			where timestamp = @timestamp
			and generator_id = s.generator_id 
			and waste_stream = s.waste_stream
			and ytd_year = s.ytd_year
			and ytd_month in (1,2)
			)) * 100), 2) as CompToStdPercent
		, (
			select count(*)
			from EQ_Extract.dbo.WMTopBottom_YTDTops
			where timestamp = @timestamp
			and generator_id = s.generator_id
			and waste_stream = s.waste_stream
			and ytd_year = s.ytd_year
			and waste_rank <= 10
		) as TotalTop10
		, ( 
			select waste_rank 
			from EQ_Extract.dbo.WMTopBottom_YTDTops
			where timestamp = @timestamp
			and generator_id = s.generator_id 
			and waste_stream = s.waste_stream
			and ytd_year = s.ytd_year
			and ytd_month = s.ytd_month -1
		) as PrevRnk
		, ( 
			select sum(monthly_total)
			from EQ_Extract.dbo.WMTopBottom_YTDTops
			where timestamp = @timestamp
			and generator_id = s.generator_id 
			and waste_stream = s.waste_stream
			and ytd_year = s.ytd_year
			) as TotYTDGen
	from EQ_Extract.dbo.WMTopBottom_YTDTops s
	INNER JOIN generator g on s.generator_id = g.generator_id
	WHERE timestamp = @timestamp
		AND ytd_year = @datayear
		AND ytd_month = @datamonth
		AND store_format = @format
		AND store_rank <= 10
	order by s.store_rank, s.monthly_total desc
END	


if @recordset LIKE 'Bottom 10 Summary%' begin

	-- 'Bottom 10 Summary: <TYPE>'
	-- <TYPE> must be one of: SUP WM SAMS SMALL
	-- ex 'Bottom 10 Summary: SAMS'
	
	delete from #param
	insert #param (idx, row, size)
	select idx, row, size from dbo.fn_splitxsvtext(':', 1, @recordset)
	select @format = row from #param where idx = 2

	-- Bottom 10
	-- First table: Bottom 10 SUP types, summary
	
--	declare @datayear int = 2013, @datamonth int = 2, @format varchar(20)= 'SUP'

	-- select 'Bottom 10 - ' + @format as Tab

	select TOP 10
		s.store_rank_reverse as store_rank
		-- , g.generator_id
		, g.site_code as facility
		, s.store_format AS format
		, g.generator_city
		, g.generator_state
		, g.generator_region_code as region
		, g.generator_market_code as market
		, sum(s.monthly_total)
	from EQ_Extract.dbo.WMTopBottom_YTDTops s
	inner join generator g on s.generator_id = g.generator_id
	WHERE s.timestamp = @timestamp
	AND ytd_year = @datayear
	AND ytd_month = @datamonth
	AND store_format = @format
	and store_rank_reverse <= 10
	group by 
		s.ytd_year
		, s.ytd_month
		, s.store_rank_reverse
		, g.generator_id
		, g.site_code
		, s.store_format
		, g.generator_city
		, g.generator_state
		, g.generator_region_code
		, g.generator_market_code
	order by s.store_rank_reverse desc, sum(s.monthly_total) desc
END

if @recordset LIKE 'Bottom 10 Detail%' begin

	-- 'Bottom 10 Detail: <TYPE>'
	-- <TYPE> must be one of: SUP WM SAMS SMALL
	-- ex 'Bottom 10 Detail: SAMS'
	
	delete from #param
	insert #param (idx, row, size)
	select idx, row, size from dbo.fn_splitxsvtext(':', 1, @recordset)
	select @format = row from #param where idx = 2


	select
		store_rank_reverse as store_rank
		-- , s.generator_id
		, g.site_code as facility
		, s.store_format AS format
		, g.generator_city
		, g.generator_state
		, s.schedule
		, g.generator_region_code as region
		, g.generator_market_code as market
		, s.waste_rank
		, s.waste_stream
		, s.description
		, s.monthly_total as monthly_total
		, ( 
			select avg(monthly_total) 
			from EQ_Extract.dbo.WMTopBottom_YTDTops
			where timestamp = @timestamp
			and generator_id = s.generator_id 
			and waste_stream = s.waste_stream
			and ytd_year = s.ytd_year
			) as monthly_average 
		, ( 
			select avg(monthly_total) 
			from EQ_Extract.dbo.WMTopBottom_YTDTops
			where timestamp = @timestamp
			and generator_id = s.generator_id 
			and waste_stream = s.waste_stream
			and ytd_year = s.ytd_year
			and ytd_month in (1,2)
			) as standard_amount
		, s.monthly_total - ( 
			select avg(monthly_total) 
			from EQ_Extract.dbo.WMTopBottom_YTDTops
			where timestamp = @timestamp
			and generator_id = s.generator_id 
			and waste_stream = s.waste_stream
			and ytd_year = s.ytd_year
			and ytd_month in (1,2)
			) as CompToStd
		, round(((s.monthly_total / ( 
			select avg(monthly_total)
			from EQ_Extract.dbo.WMTopBottom_YTDTops
			where timestamp = @timestamp
			and generator_id = s.generator_id 
			and waste_stream = s.waste_stream
			and ytd_year = s.ytd_year
			and ytd_month in (1,2)
			)) * 100), 2) as CompToStdPercent
		, (
			select count(*)
			from EQ_Extract.dbo.WMTopBottom_YTDTops
			where timestamp = @timestamp
			and generator_id = s.generator_id 
			and waste_stream = s.waste_stream
			and ytd_year = s.ytd_year
			and store_rank_reverse <= 10
		) as TotalBot10
		, ( 
			select waste_rank
			from EQ_Extract.dbo.WMTopBottom_YTDTops
			where timestamp = @timestamp
			and generator_id = s.generator_id 
			and waste_stream = s.waste_stream
			and ytd_year = s.ytd_year
			and ytd_month = s.ytd_month -1
		) as PrevRnk
		, ( 
			select sum(monthly_total)
			from EQ_Extract.dbo.WMTopBottom_YTDTops
			where timestamp = @timestamp
			and generator_id = s.generator_id 
			and waste_stream = s.waste_stream
			and ytd_year = s.ytd_year
			) as TotYTDGen
	from EQ_Extract.dbo.WMTopBottom_YTDTops s
	inner join generator g on s.generator_id = g.generator_id
	where timestamp = @timestamp
	and ytd_year = @datayear
	AND ytd_month = @datamonth
	AND store_format = @format
	and store_rank_reverse <= 10
	order by store_rank_reverse desc
	, s.monthly_total 
	
END
