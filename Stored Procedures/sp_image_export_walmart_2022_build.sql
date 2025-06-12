use plt_export
go

alter proc sp_image_export_walmart_2022_build
(
	@export_id int
)
as begin

	if object_id('tempdb..#tran') is null begin
		print 'No #tran table available, aborting.'
		return
	end

/*	

	should be...
	
	#tran (
		tran_id int not null identity(1,1)
		, trans_source char(1)
		, receipt_id int
		, company_id int
		, profit_ctr_id int
		, manifest varchar(20)
		, pickup_date datetime
		, generator_id int
		, site_code varchar(16)
		, generator_sublocation_id int
		, workorder_type varchar(40)
		, tran_filename varchar(255) -- can use this to build a filename
	)
	
*/


	-- build a Wal-Mart custom filename in #tran
	
		-- which requires a bit of info from Receipt
		select r.receipt_id, r.company_id, r.profit_ctr_id, r.manifest, min(r.manifest_flag) manifest_flag
		into #tmpReceipt
		from plt_ai..receipt r (nolock)
		join #tran t
			on t.receipt_id = r.receipt_id
			and t.company_id = r.company_id
			and t.profit_ctr_id = r.profit_ctr_id
			and t.trans_source = 'R'
		join #ImageExportDetail ied
			on t.tran_id = ied.tran_id
		GROUP BY r.receipt_id, r.company_id, r.profit_ctr_id, r.manifest

	update #tran set 
		tran_filename = replace(coalesce(t.manifest, s.manifest, s.document_name, convert(varchar(20), s.image_id)), 'BOL', '') 
		 + case when isnull(r.manifest_flag, 'M') = 'M' then '' else '-BOL' 
		 + right('00' + convert(varchar(2),t.company_id),2) 
		 + right('00' + convert(varchar(2),t.profit_ctr_id),2) 
		  end
	from #tran t
	inner join #ImageExportDetail ied
		on t.tran_id = ied.tran_id
	inner join #tmpReceipt r (nolock)
		on t.receipt_id = r.receipt_id
		and t.company_id = r.company_id
		and t.profit_ctr_id = r.profit_ctr_id
		and t.manifest = r.manifest
	inner join plt_image..scan s (nolock)  
		on t.receipt_id = s.receipt_id
		and s.company_id = t.company_id 
		and s.profit_ctr_id = t.profit_ctr_id 
		and s.document_source = 'receipt'
	WHERE t.trans_source in ('I', 'O', 'R')

	update #tran set 
		tran_filename = replace(coalesce(t.manifest, s.manifest, s.document_name, convert(varchar(20), s.image_id)), 'BOL', '') 
		 + case when isnull(r.manifest_flag, 'M') = 'M' then '' else '-BOL' 
		 + right('00' + convert(varchar(2),t.company_id),2) 
		 + right('00' + convert(varchar(2),t.profit_ctr_id),2) 
		  end
	from #tran t
	inner join #ImageExportDetail ied
		on t.tran_id = ied.tran_id
	inner join #tmpReceipt r (nolock)
		on t.receipt_id = r.receipt_id
		and t.company_id = r.company_id
		and t.profit_ctr_id = r.profit_ctr_id
		and t.manifest = r.manifest
	inner join plt_image..scan s (nolock)  
		on t.receipt_id = s.workorder_id
		and s.company_id = t.company_id 
		and s.profit_ctr_id = t.profit_ctr_id 
		and s.document_source = 'workorder'
	WHERE t.trans_source = 'W'

		
	update #ImageExportDetail set filename = t.tran_filename
	from #ImageExportDetail ied join #tran t on ied.tran_id = t.tran_id

	update #ImageExportDetail set page_number = x.page_number
	from
	#ImageExportDetail ied
	join (
		select 
			page_number = row_number() over (
			partition by 
				ltrim(rtrim(isnull( ied.filename, convert(varchar(20), (ied.image_id )))))
			order by
			isnull(s.page_order, 5000000) + isnull(ied.page_number, 1)
			)
			, ied.tran_id
			, ied.image_id
		from #ImageExportDetail ied
		join #ImageSource s on ied.tran_id = s.tran_id and ied.image_id = s.image_id
	) x
	on ied.tran_id = x.tran_id and ied.image_id = x.image_id

	update plt_export..EQIPImageExportHeader set file_count = (
		select count(distinct filename) from #ImageExportDetail
	) where export_id = @export_id
	
	delete from plt_export..EQIPImageExportWalmartMeta WHERE export_id = @export_id
	
	insert plt_export..EQIPImageExportWalmartMeta
	(
		export_id
		, [manifest number]
		, [service type]
		, [store number]
		, [city]
		, [state]
		, [zip code]
		, [service date]
		, [service provider]
	)
	select distinct
		@export_id as export_id
		, isnull(t.tran_filename,'') as [manifest number]
		, case woth.account_desc
			when 'Retail Product Offering' then 'Hazardous Waste'
			when 'Emergency Response' then 'ER - Hazardous Waste'
			when 'National Emergency Response' then 'ER - Hazardous Waste'
			else isnull(woth.account_desc,'')
			end as [service type]
		, isnull(t.site_code,'') as [store number]
		, isnull(g.generator_city,'') as [city]
		, isnull(g.generator_state,'') as [state]
		, isnull(g.generator_zip_code,'') as [zip code]
		, isnull(convert(varchar(10), t.pickup_date, 101),'') as [service date]
		, 'US Ecology' as [service provider]
	from #tran t
	join #ImageExportDetail ied
		on t.tran_id = ied.tran_id
	LEFT JOIN plt_ai..BillingLinkLookup bll
		on t.receipt_id = bll.receipt_id
		and t.company_id = bll.company_id
		and t.profit_ctr_id = bll.profit_ctr_id
	LEFT JOIN plt_ai..workorderheader woh
		on bll.source_id = woh.workorder_id
		and bll.source_company_id = woh.company_id
		and bll.source_profit_ctr_id = woh.profit_ctr_id
	left join plt_ai..workordertypeheader woth
		on woh.workorder_type_id = woth.workorder_type_id
	LEFT JOIN plt_ai..generator g
		on t.generator_id = g.generator_id

	
end
go


grant execute on sp_image_export_walmart_2022_build to eqai, eqweb, cor_user
go
