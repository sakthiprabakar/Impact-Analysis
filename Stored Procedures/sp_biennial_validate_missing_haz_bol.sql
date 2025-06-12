-- drop proc sp_biennial_validate_missing_haz_bol
go

create proc sp_biennial_validate_missing_haz_bol
	@biennial_id	int,
	@debug			int = 0
as

/* **************************************************************************************
sp_biennial_validate_missing_haz_bol

	Created to report when BOL receipts have haz waste codes.
	These records are not included in a biennial by default
	and the people need to know.

History:
	02/24/2012	JPB	Created
	
Example:

	exec sp_biennial_validate_missing_haz_bol 1436

	
************************************************************************************** */
if @debug > 0 select getdate(), 'Started'

	declare @company_id int, @profit_ctr_id int, @start_date datetime, @end_date datetime
	

	select 
		@company_id = left(company, charindex('|', company)-1),
		@profit_ctr_id = right(company, len(company) - charindex('|', company)),
		@start_date = start_date,
		@end_date = end_date
	FROM EQ_Extract..BiennialLog
	where biennial_id = @biennial_id

	INSERT INTO EQ_Extract.dbo.BiennialReportSourceDataValidation
	SELECT 'Error: BOL type Receipt with Haz Waste Codes, INCLUDED in Report'
	, 1 as rowid
	, @biennial_id as biennial_id
	, 'EQAI' as rowid
	, NULL as enviroware_manifest_document
	, NULL as enviroware_manifest_document_line
	, r.trans_mode as TRANS_MODE
	, r.Company_id
	, r.profit_ctr_id
	, pc.epa_id as profit_ctr_epa_id
	, r.receipt_id
	, r.line_id
	, NULL as container_id
	, NULL as sequence_id
	, NULL as treatment_id
	, NULL as management_code
	, NULL as lbs_haz_estimated
	, NULL as lbs_haz_actual
	, NULL as gal_haz_estimated
	, NULL as gal_haz_actual
	, NULL as yard_haz_estimated
	, NULL as yard_haz_actual
	, NULL as container_percent
	, NULL as manifest
	, NULL as manifest_line_id
	, r.approval_code
	, NULL as EPA_form_code
	, NULL as EPA_source_code
	, NULL as waste_desc
	, NULL as waste_density
	, NULL as waste_consistency
	, r.generator_id as eq_generator_id
	, g.epa_id as generator_epa_id
	, g.generator_name
	, g.generator_address_1
	, g.generator_address_2
	, g.generator_address_3
	, g.generator_address_4
	, g.generator_address_5
	, g.generator_city
	, g.generator_state
	, g.generator_zip_code
	, NULL as generator_country
	, g.state_id as generator_state_id
	, NULL as transporter_EPA_ID
	, NULL as transporter_name
	, NULL as transporter_addr1
	, NULL as transporter_addr2
	, NULL as transporter_addr3
	, NULL as transporter_city
	, NULL as transporter_state
	, NULL as transporter_zip_code
	, NULL as transporter_country
	, NULL as TSDF_EPA_ID
	, NULL as TSDF_name
	, NULL as TSDF_addr1
	, NULL as TSDF_addr2
	, NULL as TSDF_addr3
	, NULL as TSDF_city
	, NULL as TSDF_state
	, NULL as TSDF_zip_code
	, NULL as TSDF_country
		FROM RECEIPT r
		INNER JOIN profitcenter pc on r.company_id = pc.company_id and r.profit_ctr_id = pc.profit_ctr_id
		INNER JOIN generator g on r.generator_id = g.generator_id
		INNER JOIN ReceiptWasteCode rwc
			on r.receipt_id = rwc.receipt_id
			and r.line_id = rwc.line_id
			and r.company_id = rwc.company_id
			and r.profit_ctr_id = rwc.profit_ctr_id
		INNER JOIN WasteCode w
			on rwc.waste_code = w.waste_code
			and isnull(waste_code_origin, 'S') = 'F'
			and isnull(haz_flag, 'F') = 'T'
		WHERE
		r.company_id = @company_id
		and r.profit_ctr_id = @profit_ctr_id
		AND (r.receipt_date >= @start_date AND r.receipt_date <= @end_date)
		and r.manifest_flag = 'B'
		AND r.receipt_status = 'A'
		AND r.fingerpr_status = 'A'


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_biennial_validate_missing_haz_bol] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_biennial_validate_missing_haz_bol] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_biennial_validate_missing_haz_bol] TO [EQAI]
    AS [dbo];

