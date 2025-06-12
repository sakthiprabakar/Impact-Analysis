--drop proc sp_rad_surcharge_worksheet
--go

create proc sp_rad_surcharge_worksheet (
	@egle_reportable_only		char(1) = 'A'		-- 'A' (default value) -> All; 'T' -> EGLE reportable only; 'F' -> Not EGLE reportable 
	, @date_type				char(1) = 'D'		-- Denotes the type of date range:  'D' (default value) -> Disposal Date; 'R' -> Received Date
	, @date_from				datetime = null			
	, @date_to					datetime = null
) AS

/* ***************************************************************************************************

Report Name:					RAD Surcharge Worksheet
Report Description:				INTERNAL REPORT - for loads received that qualify as Norm / Tenorm / Radioactive / have 1 or more NORM waste 
								codes or a radioactive constituent
Report Criteria for running: 
	-- EGLE reportable only:	'A' (default value) -> All; 'T' -> EGLE reportable only; 'F' -> Not EGLE reportable
	-- Date type:				'D' (default value) -> Disposal Date; 'R' -> Received Date
	-- Date From/Date To:		Date range for the given date type

Examples:

exec sp_rad_surcharge_worksheet 'A', 'D', '1/1/2020', '3/31/2020'			

History:
    04/13/2020 PRK/MPM	Created for DevOps 11835/10590
	05/13/2020 MPM		DevOps 11835/10590:  Added 'Count_of_TNRM_Waste_Code' column to result set, which indicates if the profile has waste_code_uid 3752; also changed
						the logic to set the EGLE_Reportable based on the Count_of_TNRM_Waste_Code value instead of the Count_of_NORM_Waste_Code value.

*************************************************************************************************** */

BEGIN

IF OBJECT_ID(N'tempdb..#RADReviewWorksheet ') IS NOT NULL
	drop table #RADReviewWorksheet 

IF OBJECT_ID(N'tempdb..#ProfilesMaybeRAD ') IS NOT NULL
	drop table #ProfilesMaybeRAD

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
		select profile_id from ProfileWasteCode where waste_code_uid in (752, 3752)  
		union
		select profile_id from profilelab pl where pl.type = 'A' and (pl.norm = 'T' or pl.tenorm = 'T' or pl.radioactive_waste = 'T')  
		union
		select profile_id from ProfileConstituent pc join Constituents c on pc.const_id = c.const_id where reportable_nuclide = 'T'
	) x

select 
	'X' as 'EGLE_Reportable',   --this will be set later
	cast(isnull((dbo.fn_receipt_weight_container (r.receipt_id, r.line_id, r.profit_ctr_id, r.company_id, cd.container_id, cd.sequence_id)/2000), 0) as money) as  'container_weight from function (in TONS)',
	c.cust_name, g.generator_name, 
		r.approval_code, p.approval_desc, 
	(case when (select COUNT(*) from ProfileWasteCode where profile_id = p.profile_id and waste_code_uid = 752) > 0 then 'T' else 'F' end) as 'Count_of_NORM_Waste_Code', 
	(case when (select COUNT(*) from ProfileWasteCode where profile_id = p.profile_id and waste_code_uid = 3752) > 0 then 'T' else 'F' end) as 'Count_of_TNRM_Waste_Code', 
	isnull(pl.norm, 'F') as 'NORM Flag',
	isnull(pl.tenorm, 'F') as 'TENORM Flag',
	isnull(pl.radioactive_waste, 'F') as 'Radioactive Flag',
	(select COUNT(*) from ProfileConstituent pc where profile_id = p.profile_id and const_id in (select * from #RADConstituents)) as 'Count_of_Radioactive_Constituents',
	t.treatment_process_id, t.treatment_process_process, 
	r.company_id, r.profit_ctr_id, r.receipt_id, r.line_id, 
	p2.fee_exempt_flag as 'p2_fee_exempt_flag',
	p3.fee_exempt_flag as 'p3_fee_exempt_flag',
	p2.bill_method as 'p2_bill_method',
	p3.bill_method as 'p3_bill_method',
	'xxxxxxxxxxxxxxxxxxxxxxxxxxxx' as 'fee_status_on_approval',  --this will be set later
	(case when (disposal_date is not null ) then 'T' else 'F' end) as 'Disposed?',
	r.receipt_date, 
	r.manifest_flag, r.manifest, 
	cd.container_id, cd.sequence_id, cd.container_percent, cd.disposal_date, cd.location, cd.tracking_num,
	r.receipt_status, r.fingerpr_status, r.waste_accepted_flag, r.submitted_flag, 
	r.manifest_quantity, r.manifest_unit, r.line_weight, 
	rp.price, rp.bill_quantity, rp.bill_unit_code, rp.waste_extended_amt, rp.total_extended_amt,
	r.customer_id, c.cust_status, c.eq_flag as 'internal_customer_flag',
	r.generator_id, r.load_generator_EPA_ID, g.status, g.eq_flag as 'internal_generator_flag', 
	r.profile_id, p.ap_start_date, p.ap_expiration_date, p.tracking_type, p.curr_status_code,
	cd.treatment_id as 'container_treatment_id',
	pqa.treatment_id as 'current treatment on profile',
	t.wastetype_id, t.wastetype_description, t.disposal_service_id, t.disposal_service_desc
into #RADReviewWorksheet 
from Receipt r 
	join receiptprice rp on r.company_id = rp.company_id and r.profit_ctr_id = rp.profit_ctr_id and r.receipt_id = rp.receipt_id and r.line_id = rp.line_id
	join profile p on r.profile_id = p.profile_id
join #ProfilesMaybeRAD pmr on p.profile_id = pmr.profile_id
	join profilequoteapproval pqa on p.profile_id = pqa.profile_id and pqa.status = 'A' and pqa.company_id = r.company_id and pqa.profit_ctr_id = r.profit_ctr_id
	join ProfileLab pl on p.profile_id = pl.profile_id and pl.type = 'A'
	join Generator g on r.generator_id = g.generator_id
	join customer c on r.customer_id = c.customer_id
	join profilequotedetail pqd on rp.company_id = pqd.company_id and rp.profit_ctr_id = pqd.profit_ctr_id and rp.quote_id = pqd.quote_id and rp.quote_sequence_id = pqd.sequence_id
	join treatment t on pqa.treatment_id = t.treatment_id and pqa.company_id = t.company_id and pqa.profit_ctr_id = t.profit_ctr_id
	join containerdestination cd on r.company_id = cd.company_id and r.profit_ctr_id = cd.profit_ctr_id and r.receipt_id = cd.receipt_id and r.line_id = cd.line_id
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
	((r.company_id = 3 and r.profit_ctr_id = 0) or (r.company_id = 2 and r.profit_ctr_id = 0))
	and r.trans_mode = 'I'
	and r.trans_type = 'D'
	and r.receipt_status not in ('v', 'r')
	and r.fingerpr_status not in ('v', 'r')
	-- bringing back both, select off temp table allows for variable to use this
	and ((r.receipt_date between @date_from and @date_to) or (cd.disposal_date between @date_from and @date_to)) 
	
--updating the flags in the temp table
	update #RADReviewWorksheet set fee_status_on_approval = 'On Approval - Exempt' where (isnull(p2_fee_exempt_flag, 'F') = 'T' OR isnull(p3_fee_exempt_flag, 'F') = 'T') and fee_status_on_approval = 'xxxxxxxxxxxxxxxxxxxxxxxxxxxx'
	update #RADReviewWorksheet set fee_status_on_approval = 'On Approval - Bundled' where (isnull(p2_bill_method, 'X') = 'B' OR isnull(p3_bill_method, 'X') = 'B') and fee_status_on_approval = 'xxxxxxxxxxxxxxxxxxxxxxxxxxxx'
	update #RADReviewWorksheet set fee_status_on_approval = 'On Approval - Unbundled' where (isnull(p2_bill_method, 'X') = 'U' OR isnull(p3_bill_method, 'X') = 'U') and fee_status_on_approval = 'xxxxxxxxxxxxxxxxxxxxxxxxxxxx'
	update #RADReviewWorksheet set fee_status_on_approval = 'On Approval - Manual' where (isnull(p2_bill_method, 'X') = 'M' OR isnull(p3_bill_method, 'X') = 'M') and fee_status_on_approval = 'xxxxxxxxxxxxxxxxxxxxxxxxxxxx'
	update #RADReviewWorksheet set fee_status_on_approval = 'Not on Approval' where fee_status_on_approval = 'xxxxxxxxxxxxxxxxxxxxxxxxxxxx'
	update #RADReviewWorksheet set EGLE_Reportable = 'F' where Count_of_TNRM_Waste_Code = 'T' AND disposal_date is not null and (isnull(p2_fee_exempt_flag, 'F') = 'T') OR (isnull(p3_fee_exempt_flag, 'F') = 'T')
	update #RADReviewWorksheet set EGLE_Reportable = 'T' where Count_of_TNRM_Waste_Code = 'T' AND disposal_date is not null and (isnull(p2_fee_exempt_flag, 'F') <> 'T') AND (isnull(p3_fee_exempt_flag, 'F') <> 'T')
	update #RADReviewWorksheet set EGLE_Reportable = 'F' where Count_of_TNRM_Waste_Code = 'F'

select * from #RADReviewWorksheet 
	where @date_type = 'D' and disposal_date between @date_from AND @date_to
	and EGLE_Reportable = 
		case 
			when @egle_reportable_only = 'T' then 'T'
			when @egle_reportable_only = 'F' then 'F'
			else EGLE_Reportable
			end
	union 
select * from #RADReviewWorksheet 
	where @date_type = 'R' and receipt_date between @date_from AND @date_to
	and EGLE_Reportable = 
		case 
			when @egle_reportable_only = 'T' then 'T'
			when @egle_reportable_only = 'F' then 'F'
			else EGLE_Reportable
			end
order by disposal_date desc, receipt_date desc, company_id, profit_ctr_id, receipt_id, line_id
END
GO

GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rad_surcharge_worksheet] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rad_surcharge_worksheet] TO [COR_USER]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rad_surcharge_worksheet] TO [EQAI]
    AS [dbo];
GO
