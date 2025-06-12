
/************************************************************
Procedure    : sp_reports_profiles_detail
Database     : plt_ai*
Created      : Wed Jun 28 18:05:04 EDT 2006 - Jonathan Broome
Description  : Retrieves multiple recordsets used to populate
	the approval detail page

sp_reports_profiles_detail 49200, 2, 21, -1

10/08/2007 JPB Modified for Prod/Test/Dev

************************************************************/
Create Procedure sp_reports_profiles_detail (
	@profile_id 	int,
	@company_id		int,
	@profit_ctr_id	int,
	@contact_id 	int = 0
)
AS

	set nocount on
	declare @sql varchar(1000),
		@images char(1)

	create table #images (image_count int)
	set @sql = 'insert #images select count(image_id) as image_count 
					from Plt_Image.dbo.scan where profile_id = ' + convert(varchar(20), @profile_id) + '  
					and company_id = ' + convert(varchar(20), @company_id) + ' 
					and profit_ctr_id = ' + convert(varchar(20), @profit_ctr_id) + ' 
					and document_source = ''approval''
					and view_on_web = ''T''
					and status = ''A''
				'
	exec(@sql)
	
	select @images = case when image_count = 0 then 'F' else 'T' end from #images
	
	drop table #images
	set nocount off


	-- Main Info Select
	SELECT
		prfi.profile_id,
		prfi.ap_expiration_date,
		prfi.approval_desc,
		prfi.comments_1,
		prfi.comments_2,
		prfi.comments_3,
		prfi.dot_shipping_name,
		prfi.erg_number,
		prfi.generic_flag,
		prfi.hazmat,
		prfi.hazmat_class,
		prfi.ldr_subcategory,
		prfi.ots_flag,
		prfi.package_group,
		prfi.un_na_flag,
		prfi.un_na_number,
		prfi.reapproval_allowed,
	
		pqa.approval_code,
		pqa.ldr_req_flag,
		pqa.sr_type_code,
		pqa.company_id,
		pqa.profit_ctr_id,
	
		plab.color,
		plab.consistency,
		plab.free_liquid,
		plab.ignitability,
		plab.ph_from,
		plab.ph_to,
	
		ldrwm.waste_managed_flag 
			+ '. - <u>' 
			+ convert(varchar(8000), ldrwm.underlined_text) 
			+ '</u> ' + convert(varchar(8000), ldrwm.regular_text) 
			as waste_managed_flag,
		ldrwm.contains_listed,
		ldrwm.exhibits_characteristic,
		ldrwm.soil_treatment_standards,
	
		cust.customer_id,
		cust.cust_name,
	
		gen.epa_id,
		gen.gen_mail_addr1,
		gen.gen_mail_addr2,
		gen.gen_mail_addr3,
		gen.gen_mail_addr4,
		gen.gen_mail_city,
		isnull(xGMC.name, xGC.name) as gen_mail_contact,
		isnull(xGMC.title, xGC.title) as gen_mail_contact_title,	
		gen.gen_mail_name,
		gen.gen_mail_state,
		gen.gen_mail_zip_code,
		gen.generator_address_1,
		gen.generator_address_2,
		gen.generator_address_3,
		gen.generator_address_4,
		gen.generator_city,
		xGC.name as generator_contact,
		xGC.title as generator_contact_title,
		gen.generator_fax,
		gen.generator_id,
		gen.generator_name,
		gen.generator_phone,
		gen.generator_state,
		gen.generator_zip_code,
		
		pc.name,
		pc.title,
	
		pctr.profit_ctr_name,
		
		(SELECT dbo.fn_profile_form_list (prfi.profile_id)) 
			as form_list,
		
		(SELECT dbo.fn_profile_wcr_list (prfi.profile_id)) 
			as wcr_list,

		@images as images,
		
		pqa.company_id as pqa_company_id,
		pqa.profit_ctr_id as pqa_profit_ctr_id
			
	FROM
		Profile prfi
		INNER JOIN ProfileQuoteApproval pqa 
			ON prfi.profile_id = pqa.profile_id
		INNER JOIN ProfileLab plab 
			ON pqa.profile_id = plab.profile_id 
			AND plab.type='A'
		INNER JOIN Customer cust 
			ON prfi.customer_id = cust.customer_id
		INNER JOIN Generator gen 
			ON prfi.generator_id = gen.generator_id
		INNER JOIN ProfitCenter pctr 
			ON pqa.company_id = pctr.company_id
			AND pqa.profit_ctr_id = pctr.profit_ctr_id
		LEFT OUTER JOIN ContactXRef xContact 
			ON gen.generator_id = xContact.generator_id 
			AND xContact.type = 'G' 
			AND xContact.status = 'A' 
			AND xContact.primary_contact = 'T'
		LEFT OUTER JOIN Contact xGC 
			ON xContact.contact_id = xGC.contact_id 
			AND xGC.contact_status = 'A'
		LEFT OUTER JOIN ContactXRef xMailContact 
			ON gen.generator_id = xMailContact.generator_id 
			AND xMailContact.type = 'G' 
			AND xMailContact.status = 'A' 
			AND xMailContact.primary_contact <> 'T'
		LEFT OUTER JOIN Contact xGMC 
			ON xMailContact.contact_id = xGMC.contact_id 
			AND xGMC.contact_status = 'A'
		LEFT OUTER JOIN LDRWasteManaged ldrwm 
			ON prfi.waste_managed_id = ldrwm.waste_managed_id
		LEFT OUTER JOIN Contact pc
			ON prfi.contact_id = pc.contact_id 
			
	WHERE 1=1
		AND prfi.profile_id = @profile_id
		AND pqa.company_id = @company_id
		AND pqa.profit_ctr_id = @profit_ctr_id


	-- Determine whether prices should be shown
	set nocount on
	
	declare @showprices char(1)
	set @showprices = 'F'

	if @contact_id > 0	
		select
			@showprices = 'T'
		from
			Profile prfi
			INNER JOIN ContactXRef cxr 
				ON prfi.customer_id = cxr.customer_id
				AND cxr.type = 'C'
				AND cxr.status = 'A'
				AND cxr.web_access = 'A'
			INNER JOIN Customer cust 
				ON prfi.customer_id = cust.customer_id
				AND cxr.customer_id = cust.customer_id
				AND cust.terms_code <> 'NOADMIT'
			INNER JOIN Contact con 
				ON cxr.contact_id = con.contact_id
				AND con.contact_status = 'A'
		WHERE
			prfi.profile_id = @profile_id
			AND con.contact_id = @contact_id
			
	if @contact_id = -1
		set @showprices = 'T' -- Associate
	
	set nocount off
		
		
	-- Prices / Bill Unit Select
	SELECT
		pqd.record_type,
		
		case when @showprices = 'T' 
				then pqd.price 
				else null 
			end	as price,
			
		case when @showprices = 'T' 
				then pqd.surcharge_price 
				else null
			end as surcharge_price,
			
		pqd.service_desc,
		pqd.hours_free_unloading,
		pqd.hours_free_loading,
		
		case when @showprices = 'T'
				then pqd.demurrage_price 
				else null 
			end as demurrage_price,
			
		case when @showprices = 'T' 
				then pqd.unused_truck_price 
				else null 
			end as unused_truck_price,
			
		case when @showprices = 'T' 
				then pqd.lay_over_charge 
				else null 
			end as lay_over_charge,
		
		pqdesc.description,
		
		bu.bill_unit_desc,
		
		pctr.surcharge_flag
	FROM
		Profile prfi
		INNER JOIN ProfileQuoteDetail pqd 
			ON prfi.profile_id = pqd.profile_id
		LEFT OUTER JOIN ProfileQuoteDetailDesc pqdesc 
			ON pqd.quote_id = pqdesc.quote_id
			AND pqd.sequence_id = pqdesc.sequence_id
		INNER JOIN BillUnit bu 
			ON pqd.bill_unit_code = bu.bill_unit_code
		INNER JOIN ProfileQuoteApproval pqa 
			ON prfi.profile_id = pqa.profile_id
		INNER JOIN ProfitCenter pctr 
			ON pqa.company_id = pctr.company_id
			AND pqa.profit_ctr_id = pctr.profit_ctr_id
	WHERE
		prfi.profile_id = @profile_id
	ORDER BY
		price
	
	
	-- Constituents Info Select
	SELECT
		prco.uhc,
		prco.concentration,
		prco.unit,
		
		cons.const_desc,
		cons.ldr_id
	FROM
		ProfileConstituent prco
		INNER JOIN Constituents cons 
			ON prco.const_id = cons.const_id
	WHERE
		prco.profile_id = @profile_id


	-- Waste Codes Select		
	SELECT
		waste_code,
		primary_flag
	FROM
		ProfileWasteCode pwc
	WHERE
		profile_id = @profile_id
	ORDER BY
		primary_flag desc,
		waste_code


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_reports_profiles_detail] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_reports_profiles_detail] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_reports_profiles_detail] TO [EQAI]
    AS [dbo];

