

create proc sp_reports_generator_onboarding_detail__10_most_recent_shipments (
	@generator_id		int
)
as
/* ****************************************************************************
sp_reports_generator_onboarding_detail__10_most_recent_shipments

Shell for calling sp_reports_GE_generator_onboarding_detail with varying arguments
This is because SSRS won't let me have multiple different recordsets in multiple different
calls of the same stored procedure: that is to say, it is stupid.

sp_reports_generator_onboarding_detail__10_most_recent_shipments 122153
**************************************************************************** */

	--Waste Volumes
	-- drop table #waste	
	create table #waste(
		trans_source		char(1)
		, receipt_id		int
		, line_id			int
		, company_id		int
		, profit_ctr_id		int
		, Shipment_Date		datetime
		, Manifest_Flag		char(1)
		, Manifest_Number	varchar(20)
		, Line				int
		, Profile			int
		, ProductDesc		varchar(100)
		, Haz_Non_Haz		varchar(20)
		, Quantity			float
		, Unit				varchar(20)
		, Number_of_Containers	int
		, Container_Type	varchar(20)
		, TSDF				varchar(100)
		, City				varchar(40)
		, State				varchar(20)
	)


	-- inserts
	insert #waste
	-- declare @generator_id int = 169151
	select top 10 
		wss.trans_source
		, wss.receipt_id
		, wss.line_id
		, wss.company_id
		, wss.profit_ctr_id
		, wss.service_date
		, r.manifest_flag
		, r.manifest
		, r.manifest_line
		, wss.profile_id
		, p.approval_desc
		, case wss.haz_flag when 'T' then 'Haz' else 'Non-Haz' end
		, r.manifest_quantity
		, r.manifest_unit
		, r.quantity
		, bu.bill_unit_desc
		, pc.profit_ctr_name
		, pll.city
		, pll.state
	from WasteSummaryStats wss
	inner join receipt r 
		on wss.receipt_id = r.receipt_id
		and wss.line_id = r.line_id
		and wss.company_id = r.company_id
		and wss.profit_ctr_id = r.profit_ctr_id
		and wss.trans_source = 'R'
	inner join profile p
		on wss.profile_id = p.profile_id
		and wss.profile_id is not null
	inner join billunit bu
		on r.bill_unit_code = bu.bill_unit_code
	left join tsdf
		on r.tsdf_code = tsdf.tsdf_code
	left join ProfitCenter pc
		on wss.company_id = pc.company_id
		and wss.profit_ctr_id = pc.profit_ctr_id
	left join PhoneListLocation pll (nolock)
		on pll.company_id = case wss.company_id when 2 then 3 else wss.company_id end
		and pll.profit_ctr_id = pll.profit_ctr_id
	WHERE wss.generator_id = @generator_id
	order by wss.service_date desc
	
	insert #waste
	-- declare @generator_id int = 169151
	select top 10 
		wss.trans_source
		, wss.receipt_id
		, wss.sequence_id
		, wss.company_id
		, wss.profit_ctr_id
		, wss.service_date
		, wom.manifest_flag
		, wod.manifest
		, wod.manifest_line
		, wod.profile_id
		, p.approval_desc
		, case wss.haz_flag when 'T' then 'Haz' else 'Non-Haz' end
		, wodum.quantity
		, wodumbu.manifest_unit
		, wod.container_count
		, wodubbu.bill_unit_desc
		, pc.profit_ctr_name
		, pll.city
		, pll.state
	from WasteSummaryStats wss
	inner join workorderdetail wod 
		on wss.receipt_id = wod.workorder_id
		and wss.sequence_id = wod.sequence_id
		and wss.resource_type = wod.resource_type
		and wss.company_id = wod.company_id
		and wss.profit_ctr_id = wod.profit_ctr_id
		and wss.trans_source = 'W'
		and wss.resource_type = 'D'
	inner join workordermanifest wom
		on wom.workorder_id = wod.workorder_id
		and wom.company_id = wod.company_id
		and wom.profit_ctr_id = wod.profit_ctr_id
		and wod.manifest = wom.manifest
	left join workorderdetailunit wodum
		on wod.workorder_id = wodum.workorder_id
		and wod.company_id = wodum.company_id
		and wod.profit_ctr_id = wodum.profit_ctr_id
		and wod.sequence_id = wodum.sequence_id
		and wodum.manifest_flag = 'T'
	left join billunit wodumbu
		on wodum.bill_unit_code = wodumbu.bill_unit_code
	left join workorderdetailunit wodub
		on wod.workorder_id = wodub.workorder_id
		and wod.company_id = wodub.company_id
		and wod.profit_ctr_id = wodub.profit_ctr_id
		and wod.sequence_id = wodub.sequence_id
		and wodub.billing_flag = 'T'
	left join billunit wodubbu
		on wodub.bill_unit_code = wodubbu.bill_unit_code
	inner join profile p
		on wss.profile_id = p.profile_id
		and wss.profile_id is not null
	left join tsdf
		on wod.tsdf_code = tsdf.tsdf_code
	left join ProfitCenter pc
		on wod.profile_company_id = pc.company_id
		and wod.profile_profit_ctr_id = pc.profit_ctr_id
	left join PhoneListLocation pll (nolock)
		on pll.company_id = case wod.profile_company_id when 2 then 3 else wod.profile_company_id end
		and pll.profit_ctr_id = wod.profile_profit_ctr_id
	WHERE wss.generator_id = @generator_id
	order by wss.service_date desc


	insert #waste
	-- declare @generator_id int = 122153
	select top 10 
		wss.trans_source
		, wss.receipt_id
		, wss.sequence_id
		, wss.company_id
		, wss.profit_ctr_id
		, wss.service_date
		, wom.manifest_flag
		, wod.manifest
		, wod.manifest_line
		, wod.tsdf_approval_id
		, ta.waste_desc
		, case wss.haz_flag when 'T' then 'Haz' else 'Non-Haz' end
		, wodum.quantity
		, wodumbu.manifest_unit
		, wod.container_count
		, wodubbu.bill_unit_desc
		, tsdf.tsdf_name
		, tsdf.tsdf_city
		, tsdf.tsdf_state
	from WasteSummaryStats wss
	inner join workorderdetail wod 
		on wss.receipt_id = wod.workorder_id
		and wss.sequence_id = wod.sequence_id
		and wss.resource_type = wod.resource_type
		and wss.company_id = wod.company_id
		and wss.profit_ctr_id = wod.profit_ctr_id
		and wss.trans_source = 'W'
		and wss.resource_type = 'D'
	inner join workordermanifest wom
		on wom.workorder_id = wod.workorder_id
		and wom.company_id = wod.company_id
		and wom.profit_ctr_id = wod.profit_ctr_id
		and wod.manifest = wom.manifest
	left join workorderdetailunit wodum
		on wod.workorder_id = wodum.workorder_id
		and wod.company_id = wodum.company_id
		and wod.profit_ctr_id = wodum.profit_ctr_id
		and wod.sequence_id = wodum.sequence_id
		and wodum.manifest_flag = 'T'
	left join billunit wodumbu
		on wodum.bill_unit_code = wodumbu.bill_unit_code
	left join workorderdetailunit wodub
		on wod.workorder_id = wodub.workorder_id
		and wod.company_id = wodub.company_id
		and wod.profit_ctr_id = wodub.profit_ctr_id
		and wod.sequence_id = wodub.sequence_id
		and wodub.billing_flag = 'T'
	left join billunit wodubbu
		on wodub.bill_unit_code = wodubbu.bill_unit_code
	inner join tsdfapproval ta
		on wss.tsdf_approval_id = ta.tsdf_approval_id
		and wss.tsdf_approval_id is not null
	left join tsdf
		on wod.tsdf_code = tsdf.tsdf_code
	WHERE wss.generator_id = @generator_id
	order by wss.service_date desc
	
/*			

	select '8/17/2017', '006150429SKS', 1, 1376507, 'Water From Mod. Units Vac.', 'Non-Haz', 4.00, 'G   ', 1, 'TT', 'Phillip Services Corp - Dallas', 'Dallas', 'TX' union all 
	select '8/15/2017', '006115319SKS', 1, 1376507, 'Water From Mod. Units Vac.', 'Non-Haz', 2175.00, 'G   ', 1, 'TT', 'Phillip Services Corp - Dallas', 'Dallas', 'TX' union all 
	select '8/15/2017', '006115320SKS', 1, 1376507, 'Water From Mod. Units Vac.', 'Non-Haz', 1450.00, 'G   ', 1, 'TT', 'Phillip Services Corp - Dallas', 'Dallas', 'TX' union all 
	select '8/15/2017', '006115336SKS', 1, 742014, 'Dober and Water', 'Non-Haz', 275.00, 'G   ', 1, 'TT', 'Phillip Services Corp - Dallas', 'Dallas', 'TX' union all 
	select '8/10/2017', '006054179SKS', 1, 150135, 'AQUEOUS SOLUTION PARTS WASHER  NHZW', 'Non-Haz', 75.00, 'G   ', 3, 'DM', 'La Porte, TX Facility', 'La Porte', 'TX' union all 
	select '8/10/2017', '006057190SKS', 1, 150135, 'AQUEOUS SOLUTION PARTS WASHER  NHZW', 'Non-Haz', 15.00, 'G   ', 1, 'DM', 'La Porte, TX Facility', 'La Porte', 'TX' union all 
	select '8/10/2017', '006150343SKS', 1, 1434600, 'Mod Sand', 'Non-Haz', 3900.00, 'P   ', 13, 'DM', 'La Porte, TX Facility', 'La Porte', 'TX' union all 
	select '8/10/2017', '006150343SKS', 2, 1394036, 'Insulation', 'Non-Haz', 100.00, 'P   ', 2, 'DM', 'La Porte, TX Facility', 'La Porte', 'TX' union all 
	select '8/10/2017', '006150343SKS', 3, 1435849, 'Mod. Debris', 'Non-Haz', 275.00, 'P   ', 1, 'DM', 'La Porte, TX Facility', 'La Porte', 'TX' union all 
	select '8/10/2017', '006150344SKS', 1, 40580113, 'Absorbent with oil', 'Non-Haz', 225.00, 'P   ', 3, 'DM', 'La Porte, TX Facility', 'La Porte', 'TX' union all 
	select '8/10/2017', '006150344SKS', 2, 1033431, 'Empty Poly Drum (Last Containing Sanitrete)', 'Non-Haz', 4.00, 'P   ', 4, 'DF', 'La Porte, TX Facility', 'La Porte', 'TX' union all 
	select '8/8/2017', '006114692SKS', 1, 742009, 'Air Compressor Condensate Water and oil', 'Non-Haz', 500.00, 'G   ', 1, 'TT', 'Phillip Services Corp - Dallas', 'Dallas', 'TX' union all 
	select '8/8/2017', '006114692SKS', 2, 742014, 'Dober and Water', 'Non-Haz', 250.00, 'G   ', 1, 'TT', 'Phillip Services Corp - Dallas', 'Dallas', 'TX' union all 
	select '8/8/2017', '006115318SKS', 1, 1376507, 'Water From Mod. Units Vac.', 'Non-Haz', 1650.00, 'G   ', 1, 'TT', 'Phillip Services Corp - Dallas', 'Dallas', 'TX' ; 
	
	
	SELECT * FROM wastesummarystats wss WHERE 1=1
			and wss.trans_source = 'R'
			and wss.generator_id = 122153
		and wss.resource_type = 'D'

		
	

*/	
	select top 10 * from #waste ORDER BY shipment_date desc
 

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_reports_generator_onboarding_detail__10_most_recent_shipments] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_reports_generator_onboarding_detail__10_most_recent_shipments] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_reports_generator_onboarding_detail__10_most_recent_shipments] TO [EQAI]
    AS [dbo];

