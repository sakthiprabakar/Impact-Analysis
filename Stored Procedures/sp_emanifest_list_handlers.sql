create proc sp_emanifest_list_handlers (
	@source_company_id		int 					/* company_id */
	, @source_profit_ctr_id 	int 				/* profit_ctr_id */
	, @source_table			varchar(40)				/* receipt, workorder, etc */
	, @source_id				int 				/* receipt_id, workorder_id, etc */
	, @manifest				varchar(20)				/* manifest number (not needed for EQAI) */
) as 
/******************************************************************************************
Retrieve Handler list of sources + id + order ordinal per emanifest source

sp_emanifest_list_handlers	21, 0, 'receipt', 2005458
sp_emanifest_list_handlers	3, 0, 'receipt', 1258903
exec sp_emanifest_list_handlers '22', '0', 'receipt', '200959'
sp_emanifest_list_handlers	21, 0, 'receipt', 2013669, ''
sp_emanifest_list_handlers	41, 0, 'receipt', 118318, ''

SELECT * FROM ReceiptTransporter WHERE receipt_id = 1258903 and company_id = 3 ORDER BY transporter_sequence_id


******************************************************************************************/

if @source_table = 'receipt' begin
	select * from (
	
		/* Generator Handler and Signature Info */
		
		select distinct 
			'generator'	handlerType
			, convert(varchar(20), r.generator_id)	handlerId
			, 1	handlerOrder
			, signatureDate = 
				coalesce(
					rm.generator_sign_date

					, rt1.transporter_sign_date

					, (select top 1 coalesce(wos.date_act_depart, woh.start_date) wo_date
						from BillingLinkLookup bll -- order by date_added desc
						left join WorkorderStop wos on wos.workorder_id = bll.source_id and wos.company_id = bll.source_company_id and wos.profit_ctr_id = bll.source_profit_ctr_id
						left join WorkOrderHeader woh on woh.workorder_id = bll.source_id and woh.company_id = bll.source_company_id and woh.profit_ctr_id = bll.source_profit_ctr_id
						where bll.receipt_id = r.receipt_id and bll.company_id = r.company_id and bll.profit_ctr_id = r.profit_ctr_id
					)

					, (select top 1 service_date
						from BillingComment bc
						where bc.receipt_id = r.receipt_id and bc.company_id = r.company_id and bc.profit_ctr_id = r.profit_ctr_id
					)
				)

			, signatureName = coalesce(rm.generator_sign_name, 'Illegible')
			, case when isnull(g.generator_country, 'USA') = 'USA' then g.epa_id else
					case when left(isnull(g.epa_id, ''), 2) = 'FC' then g.epa_id else null end
				end	epaSiteId
			, COALESCE(nullif(ltrim(rtrim(isnull(g.emergency_phone_number, ''))), ''), ProfitCenter.emergency_contact_phone) as emergencyPhone
		from receipt r
		join generator g on r.generator_id = g.generator_id -- and g.generator_country = 'USA'
		INNER JOIN ProfitCenter ON r.profit_ctr_id = ProfitCenter.profit_ctr_id
			AND r.company_id = ProfitCenter.company_id
		left join ReceiptTransporter rt1
			on rt1.receipt_id = r.receipt_id and rt1.company_id = r.company_id and rt1.profit_ctr_id = r.profit_ctr_id and rt1.transporter_sequence_id = 1
		left join ReceiptManifest rm
			on rm.receipt_id = r.receipt_id and rm.company_id = r.company_id and rm.profit_ctr_id = r.profit_ctr_id and rm.page = 1
		WHERE r.company_id = @source_company_id 
		and r.profit_ctr_id = @source_profit_ctr_id
		and r.receipt_id = @source_id

	union all

		/* TSDF Handler and Signature Info */
		
		/* 
		
		6/21/2018: This is our internal site when no rejections are involved.
			In a rejection (we receive what someone else rejected) the
			DesignatedFacility is THAT OTHER place, and WE are the
			rejectionInfo.alternateDesignatedFacility.
			
		*/

		select top 1 
			'tsdf'	handlerType
			, convert(varchar(20), t.tsdf_code)	handlerId
			, 1	handlerOrder
			, signatureDate = 
				coalesce(
					rm.tsdf_sign_date,
					r.time_out,
					r.receipt_date
				)
			, signatureName = rm.tsdf_sign_name
			
			, case when isnull(t.TSDF_country_code, 'USA') = 'USA' then TSDF_EPA_ID else
				case when left(isnull(TSDF_EPA_ID, ''), 2) = 'FC' then TSDF_EPA_ID else null end
			end	epaSiteId
			, nullif(ltrim(rtrim(isnull(t.emergency_contact_phone, ''))), '') as emergencyPhone

		from receipt r
			inner join tsdf t on r.company_id = t.eq_company and r.profit_ctr_id = t.eq_profit_ctr and t.tsdf_status = 'A'
			left join ReceiptManifest rm on r.receipt_id = rm.receipt_id and r.company_id = rm.company_id and r.profit_ctr_id = rm.profit_ctr_id
		WHERE r.company_id = @source_company_id 
		and r.profit_ctr_id = @source_profit_ctr_id
		and r.receipt_id = @source_id
		and not exists (
			select 1 from ReceiptDiscrepancy rd
			WHERE rd.receipt_id = r.receipt_id
			and rd.company_id = r.company_id
			and rd.profit_ctr_id = r.profit_ctr_id
			and isnull(rd.alt_facility_type, 'T') = 'O'
			and isnull(rd.discrepancy_full_reject_flag, 'F') = 'T'
		)
		
	union all

		/* 
		
		6/21/2018: This is the external site that rejected to us (only for FULL rejection)
			The DesignatedFacility is THAT OTHER place, and WE are the
			rejectionInfo.alternateDesignatedFacility.
			
			On a Partial rejection, the current manifest data is just between 
			the facilities, not the original facility
			
		*/

		select top 1 
			'tsdf'	handlerType
			, convert(varchar(20), t.tsdf_code)	handlerId
			, 1	handlerOrder
			, signatureDate = rd.date_rejected_from_another_facility
			, signatureName = coalesce(rd.rejection_contact_name, 'Illegible')
			
			, case when isnull(t.TSDF_country_code, 'USA') = 'USA' then TSDF_EPA_ID else
				case when left(isnull(TSDF_EPA_ID, ''), 2) = 'FC' then TSDF_EPA_ID else null end
			end	epaSiteId
			, nullif(ltrim(rtrim(isnull(t.emergency_contact_phone, ''))), '') as emergencyPhone

		from receipt r
			inner join ReceiptDiscrepancy rd on rd.receipt_id = r.receipt_id and rd.company_id = r.company_id and rd.profit_ctr_id = r.profit_ctr_id
			and isnull(rd.alt_facility_type, 'A') = 'O'
			and isnull(rd.discrepancy_full_reject_flag, 'F') = 'T'
			inner join tsdf t on rd.alt_facility_code = t.tsdf_code
		WHERE r.company_id = @source_company_id 
		and r.profit_ctr_id = @source_profit_ctr_id
		and r.receipt_id = @source_id
		
	union all

		/* Transporter Handler and Signature Info */
	
		select distinct 
			'transporter'	handlerType
			, rt.transporter_code	handlerId
			, transporter_sequence_id	handlerOrder
			, signatureDate = coalesce(
				rt.transporter_sign_date
				, dateadd(n, (200 - rt.transporter_sequence_id * 3) * -1, coalesce(r.time_in, r.receipt_date))
				, r.time_in
				, r.receipt_date
				)
			, signatureName = isnull(rt.transporter_sign_name, 'Illegible')
			, case when isnull(t.transporter_country, 'USA') = 'USA' then rt.transporter_EPA_ID else
				case when left(isnull(rt.transporter_EPA_ID, ''), 2) = 'FC' then rt.transporter_EPA_ID else null end
			end	epaSiteId
			, nullif(ltrim(rtrim(isnull(t.transporter_contact_phone, ''))), '') as emergencyPhone

		from receipttransporter rt
		join transporter t on rt.transporter_code = t.transporter_code
		join (select top 1 * from receipt 
			where receipt_id = @source_id and company_id = @source_company_id and profit_ctr_id = @source_profit_ctr_id ) r
			on r.receipt_id = rt.receipt_id and r.company_id = rt.company_id and r.profit_ctr_id = rt.profit_ctr_id
		WHERE rt.company_id = @source_company_id 
		and rt.profit_ctr_id = @source_profit_ctr_id
		and rt.receipt_id = @source_id

	) x
	order by case handlerType when 'generator' then 0 when 'transporter' then 1 when 'tsdf' then 2 end,
	handlerOrder
end

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_emanifest_list_handlers] TO [ATHENA_SVC]
    AS [dbo];


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_emanifest_list_handlers] TO [EQAI]
    AS [dbo];

