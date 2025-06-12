--drop proc sp_rad_profile_review_worksheet
--go

create proc sp_rad_profile_review_worksheet (
	@egle_reportable_only		char(1) = 'T'		-- 'T' (default value) -> EGLE reportable only; 'F' -> Not EGLE reportable; 'A' -> All
	, @date_type				char(1) = 'A'		-- Denotes the type of date range:  'A' (default value) -> Approval Added Date; 'E' -> Approval Expiration Date
	, @date_from				datetime = null			
	, @date_to					datetime = null
) AS

/* ***************************************************************************************************

Report Name:						RAD Profile Review Worksheet
Report Description:					Review report for all profiles into companies 2 or 3 that have the various indicators of radioactive flags.  This is to be reviewed to 
									ensure that the TENORM fee is appropriately applied to these.
Report Criteria for running: 
	-- EGLE reportable only:		'T' (default value) -> EGLE reportable only; 'F' -> Not EGLE reportable; 'A' -> All
	-- Date type:					'A' (default value) -> Approval Added Date; 'E' -> Approval Expiration Date
	-- Date From/Date To:			Date range for the given date type

Examples:

exec sp_rad_profile_review_worksheet 'T', 'A', '1/1/2017', '1/1/2021'			

History:
    04/13/2020 PRK/MPM	Created for DevOps 11835/10590
	05/13/2020 MPM		DevOps 11835/10590:  Added 'Count_of_TNRM_Waste_Code' column to result set, which indicates if the profile has waste_code_uid 3752; also changed
						the logic to set the EGLE_Reportable based on the Count_of_TNRM_Waste_Code value instead of the Count_of_NORM_Waste_Code value.

*************************************************************************************************** */

BEGIN

IF OBJECT_ID(N'tempdb..#ProfilesMaybeRAD ') IS NOT NULL
	drop table #ProfilesMaybeRAD

IF OBJECT_ID(N'tempdb..#ProfilesToCheck ') IS NOT NULL
	drop table #ProfilesToCheck 

IF OBJECT_ID(N'tempdb..#Products ') IS NOT NULL
	drop table #Products

IF OBJECT_ID(N'tempdb..#RADConstituents ') IS NOT NULL
	drop table #RADConstituents

DECLARE 
	@product_code varchar(10) = 'FEETENORM'  --use WHCA for testing, FEETENORM is not on any profiles, yet

select y.* into #Products from (select product_ID from Product where product_code = @product_code) y
select z.* into #RADConstituents from (select const_id from Constituents where reportable_nuclide = 'T') z

SELECT x.* 
  INTO #ProfilesMaybeRAD
  FROM (
		select profile_id from ProfileWasteCode where waste_code_uid in (752, 3752)  --1017
		union
		select profile_id from profilelab pl where pl.type = 'A' and (pl.norm = 'T' or pl.tenorm = 'T' or pl.radioactive_waste = 'T')  
		union
		select profile_id from ProfileConstituent pc join Constituents c on pc.const_id = c.const_id where reportable_nuclide = 'T' 
	) x

select 
	'99' as 'ES_Territory',
	'99' as customer_service_id,
	'xxxxxxxxxxxxxxxxxxxxxxxxxxx' as 'customer_service_name',
	pqa.billing_project_id as 'billing_project_id',	
	p.customer_id,
	p2.fee_exempt_flag as 'p2_fee_exempt_flag',
	p3.fee_exempt_flag as 'p3_fee_exempt_flag',
	p2.bill_method as 'p2_bill_method',
	p3.bill_method as 'p3_bill_method',
	'xxxxxxxxxxxxxxxxxxxxxxxxxxxx' as 'fee_status_on_approval',  --this will be set later
	'X' as 'EGLE_Reportable',   --this will be set later
	p.profile_ID, pqa.company_id, pqa.profit_ctr_id, pqd.bill_unit_code,
	p.date_added as 'profile_creation_date', pqa.date_added as 'approval_creation_date', p.ap_start_date, p.ap_expiration_date, 
	pqa.approval_code, p.approval_desc, p.tracking_type, p.curr_status_code, 
	isnull(pl.norm, 'F') as 'NORM_Flag', 
	isnull(pl.tenorm, 'F') as 'TENORM_Flag', 
	isnull(pl.radioactive_waste, 'F') as 'Radioactive_Flag',
	(case when (select COUNT(*) from ProfileWasteCode where profile_id = p.profile_id and waste_code_uid = 752) > 0 then 'T' else 'F' end) as 'Count_of_NORM_Waste_Code',
	(case when (select COUNT(*) from ProfileWasteCode where profile_id = p.profile_id and waste_code_uid = 3752) > 0 then 'T' else 'F' end) as 'Count_of_TNRM_Waste_Code',
	(select COUNT(*) from ProfileConstituent pc where profile_id = p.profile_id and const_id in (select * from #RADConstituents)) as 'Count_of_Radioactive_Constituents',
	(select count(*) from receipt r where r.company_id = pqa.company_id and r.profit_ctr_id = pqa.profit_ctr_id and r.profile_id = p.profile_id and r.receipt_status not in ('v', 'r') and r.fingerpr_status not in ('v', 'r') and r.trans_type = 'D' and r.trans_mode = 'I' ) as 'count of receipts with this profile',
	g.generator_id, g.EPA_ID, g.generator_name, g.status, g.eq_flag as 'internal_generator_flag',
	pqa.treatment_id, t.wastetype_id, t.wastetype_description, t.treatment_process_id, t.treatment_process_process, t.disposal_service_id, t.disposal_service_desc
into #ProfilesToCheck 
from profile p 
join #ProfilesMaybeRAD pmr on p.profile_id = pmr.profile_id
	join profilequoteapproval pqa on p.profile_id = pqa.profile_id and pqa.status = 'A'
	join ProfileLab pl on p.profile_id = pl.profile_id and pl.type = 'A'
	join Generator g on p.generator_id = g.generator_id
	left outer join treatment t on pqa.treatment_id = t.treatment_id and pqa.company_id = t.company_id and pqa.profit_ctr_id = t.profit_ctr_id
	join profilequotedetail pqd on pqa.profile_id = pqd.profile_id and pqa.company_id = pqd.company_id and pqa.profit_ctr_id = pqd.profit_ctr_id and pqd.record_type = 'D'
	left outer join ProfileQuoteDetail p2 
		on pqd.profile_id = p2.profile_id 
		and pqd.company_id = p2.company_id 
		and pqd.profit_ctr_id = p2.profit_ctr_id 
		and pqd.sequence_id = p2.ref_sequence_id 
--		and pqd.bill_unit_code = p2.bill_unit_code  --commented out because users get this wrong
		and pqd.record_type = 'D' and p2.record_type = 'S'
		and p2.product_ID in (select * from #Products)
	left outer join ProfileQuoteDetail p3 
		on pqd.profile_id = p3.profile_id 
		and pqd.company_id = p3.company_id 
		and pqd.profit_ctr_id = p3.profit_ctr_id 
		and p3.ref_sequence_id = 0
		and pqd.record_type = 'D' and p3.record_type = 'S'
		and p3.product_ID in (select * from #Products)
where 
	((pqa.company_id = 3 and pqa.profit_ctr_id = 0) or (pqa.company_id = 2 and pqa.profit_ctr_id = 0))
	and p.curr_status_code not in ('V', 'R', 'C')
	and (
		(pqa.date_added between @date_from and @date_to) 
		OR
		(p.ap_expiration_date between @date_from and @date_to) 
		)

--setting the flags in the temp table
	update #ProfilesToCheck set fee_status_on_approval = 'On Approval - Exempt' where (isnull(p2_fee_exempt_flag, 'F') = 'T' OR isnull(p3_fee_exempt_flag, 'F') = 'T') and fee_status_on_approval = 'xxxxxxxxxxxxxxxxxxxxxxxxxxxx'
	update #ProfilesToCheck set fee_status_on_approval = 'On Approval - Bundled' where (isnull(p2_bill_method, 'X') = 'B' OR isnull(p3_bill_method, 'X') = 'B') and fee_status_on_approval = 'xxxxxxxxxxxxxxxxxxxxxxxxxxxx'
	update #ProfilesToCheck set fee_status_on_approval = 'On Approval - Unbundled' where (isnull(p2_bill_method, 'X') = 'U' OR isnull(p3_bill_method, 'X') = 'U') and fee_status_on_approval = 'xxxxxxxxxxxxxxxxxxxxxxxxxxxx'
	update #ProfilesToCheck set fee_status_on_approval = 'On Approval - Manual' where (isnull(p2_bill_method, 'X') = 'M' OR isnull(p3_bill_method, 'X') = 'M') and fee_status_on_approval = 'xxxxxxxxxxxxxxxxxxxxxxxxxxxx'
	update #ProfilesToCheck set fee_status_on_approval = 'Not on Approval' where fee_status_on_approval = 'xxxxxxxxxxxxxxxxxxxxxxxxxxxx'
	update #ProfilesToCheck set EGLE_Reportable = 'T' where Count_of_TNRM_Waste_Code = 'T'
	update #ProfilesToCheck set EGLE_Reportable = 'F' where Count_of_TNRM_Waste_Code = 'F'

--select cbt.customer_billing_territory_code, * from #ProfilesToCheck ptc 
--left outer join CustomerBillingTerritory cbt 
--on ptc.customer_id = cbt.customer_id
--and ptc.billing_project_id = cbt.billing_project_id
--and cbt.businesssegment_uid = 1 and cbt.customer_billing_territory_primary_flag = 'T' and cbt.customer_billing_territory_status = 'A'
--where cbt.customer_billing_territory_code is not null

UPDATE #ProfilesToCheck  
SET #ProfilesToCheck.ES_Territory = CustomerBillingTerritory.customer_billing_territory_code
FROM #ProfilesToCheck
INNER JOIN CustomerBillingTerritory
on #ProfilesToCheck.customer_id = CustomerBillingTerritory.customer_id
and #ProfilesToCheck.billing_project_id = CustomerBillingTerritory.billing_project_id
and CustomerBillingTerritory.businesssegment_uid = 1 and CustomerBillingTerritory.customer_billing_territory_primary_flag = 'T' and CustomerBillingTerritory.customer_billing_territory_status = 'A'

update #ProfilesToCheck set ES_Territory = 'NA' where ES_Territory = '99'

--select cb.customer_service_id, * from #ProfilesToCheck ptc 
--inner join CustomerBilling cb
--on ptc.customer_id = cb.customer_id
--and ptc.billing_project_id = cb.billing_project_id
--and cb.customer_service_id is not null

UPDATE #ProfilesToCheck  
SET #ProfilesToCheck.customer_service_id = CustomerBilling.customer_service_id
FROM #ProfilesToCheck
INNER JOIN CustomerBilling
on #ProfilesToCheck.customer_id = CustomerBilling.customer_id
and #ProfilesToCheck.billing_project_id = CustomerBilling.billing_project_id
and CustomerBilling.customer_service_id is not null

update #ProfilesToCheck set customer_service_name = '' where customer_service_id = '99'

--select u.user_name, ux.type_id, ux.user_code, * from UsersXEQContact ux 
--left outer join users u on ux.user_code = u.user_code
--where ux.EQcontact_type = 'CSR'
--and ux.user_code is not null

UPDATE #ProfilesToCheck  
SET #ProfilesToCheck.customer_service_name = u.user_name
FROM #ProfilesToCheck
INNER JOIN 
UsersXEQContact ux on #ProfilesToCheck.customer_service_id = ux.type_id
left outer join users u on ux.user_code = u.user_code
where ux.EQcontact_type = 'CSR'
and ux.user_code is not null

select * from #ProfilesToCheck
	where @date_type = 'A' and approval_creation_date between @date_from AND @date_to 
	and	EGLE_Reportable = 
		case 
			when @egle_reportable_only = 'T' then 'T'
			when @egle_reportable_only = 'F' then 'F'
			else EGLE_Reportable
			end
	union 
select * from #ProfilesToCheck
	where @date_type = 'E' and ap_expiration_date between @date_from AND @date_to 
	and	EGLE_Reportable = 
		case 
			when @egle_reportable_only = 'T' then 'T'
			when @egle_reportable_only = 'F' then 'F'
			else EGLE_Reportable
			end

END
GO

GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rad_profile_review_worksheet] TO [EQWEB]
    AS [dbo];

GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rad_profile_review_worksheet] TO [COR_USER]
    AS [dbo];

GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rad_profile_review_worksheet] TO [EQAI]
    AS [dbo];

