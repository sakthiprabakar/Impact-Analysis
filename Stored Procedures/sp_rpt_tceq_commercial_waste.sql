-- DROP PROC sp_rpt_tceq_commercial_waste
GO

CREATE PROC sp_rpt_tceq_commercial_waste (
	@company_id			int	
	, @profit_ctr_id	int
	, @year				int
	, @month			int
)
AS
/* *****************************************************************************************************

06/05/2019	MPM	DevOps task 11291 - Created
07/18/2019	MPM DevOps 12160 - Modified to exclude void or rejected receipt lines.

sp_rpt_tceq_commercial_waste 46, 0, 2019, 4

***************************************************************************************************** */
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

create table #results (
	company_id					int
	, profit_ctr_id				int
	, receipt_id				int
	, line_id					int
	, generator_id				int
	, generator_name			varchar(75)
	, facility_id				varchar(40)
	, TSDF_name					varchar(40)
	, TSDF_addr1				varchar(40)
	, TSDF_addr2				varchar(40)
	, TSDF_addr3				varchar(40)
	, TSDF_city					varchar(40)
	, TSDF_state				char(2)
	, TSDF_zip_code				varchar(15)
	, state_regulatory_id		varchar(40)
	, profile_id				int
	, transporter_code			varchar(15)
	, transporter_name			varchar(40)
	, transporter_TX_id			varchar(40)
	, waste_code_display_name	varchar(10)
	, approval_desc				varchar(50)
	, gallons_received			float
	
	
)
	insert into #results (company_id, profit_ctr_id, receipt_id, line_id, generator_id, generator_name, facility_id, TSDF_name, TSDF_addr1,
							TSDF_addr2, TSDF_addr3, TSDF_city, TSDF_state, TSDF_zip_code, state_regulatory_id, profile_id, transporter_code, 
							transporter_name, transporter_TX_id, waste_code_display_name, approval_desc)
	select r.company_id
			, r.profit_ctr_id
			, r.receipt_id
			, r.line_id
			, g.generator_id
			, g.generator_name
			, CASE when g.generator_state = 'TX' THEN SUBSTRING(LTRIM(RTRIM(ISNULL(g.state_id,''))), 1, 12)
					else (select SUBSTRING(LTRIM(RTRIM(ISNULL(trlc.tx_out_of_state_generator_code,''))), 1, 12)  
							from  TexasReportingLocationCode trlc
							where g.generator_state = trlc.state_code)
					end as facility_id
			, TSDF.TSDF_name
			, TSDF.TSDF_addr1
			, TSDF.TSDF_addr2
			, TSDF.TSDF_addr3
			, TSDF.TSDF_city
			, TSDF.TSDF_state
			, TSDF.TSDF_zip_code
			, TSDF.state_regulatory_id
			, p.profile_id
			, t.transporter_code
			, t.transporter_name
			, t2.transporter_state_id as transporter_TX_id
			, wc.display_name as waste_code_display_name
			, p.approval_desc
	from Receipt r
	join Generator g
		on g.generator_id = r.generator_id
	join TSDF
		on TSDF.eq_company = @company_id
		and TSDF.eq_profit_ctr = @profit_ctr_id
		and TSDF.TSDF_status = 'A'
	join Profile p
		on p.profile_id = r.profile_id
	join ReceiptTransporter rt
		on rt.company_id = r.company_id
		and rt.profit_ctr_id = r.profit_ctr_id
		and rt.receipt_id = r.receipt_id
	join Transporter t
		on t.transporter_code = rt.transporter_code
	left outer join TransporterXStateID t2
		on t2.transporter_code = t.transporter_code
		and t2.transporter_state = 'TX'
		and t2.status = 'A'
	join ReceiptWasteCode rwc
		on rwc.company_id = r.company_id
		and rwc.profit_ctr_id = r.profit_ctr_id
		and rwc.receipt_id = r.receipt_id
		and rwc.line_id = r.line_id
	join WasteCode wc
		on wc.waste_code_uid = rwc.waste_code_uid
	where r.company_id = @company_id
		and r.profit_ctr_id = @profit_ctr_id
		and year(r.receipt_date) = @year
		and month(r.receipt_date) = @month 
		and r.receipt_status not in ('V', 'R')  
		and r.fingerpr_status not in ('V', 'R')
		and r.trans_mode = 'I'  
		and r.trans_type = 'D'  
--		and r.bulk_flag = 'T'
		and wc.waste_code_origin = 'S'
		and wc.state = 'TX'
		
	update #results	
		set gallons_received = dbo.fn_calculated_gallons(company_id, profit_ctr_id, receipt_id, line_id, null, null)
	
	select company_id
	, profit_ctr_id
	, generator_id
	, generator_name
	, facility_id
	, TSDF_name	
	, TSDF_addr1
	, TSDF_addr2
	, TSDF_addr3
	, TSDF_city	
	, TSDF_state
	, TSDF_zip_code
	, state_regulatory_id
	, profile_id
	, transporter_code
	, transporter_name
	, transporter_TX_id
	, waste_code_display_name
	, approval_desc				
	, gallons_received
	from #results
	order by company_id
			, profit_ctr_id 	
			, TSDF_name	
			, generator_name
			, approval_desc
			, transporter_name
			, waste_code_display_name	
/*	group by company_id
			, profit_ctr_id 	
			, TSDF_name	
			, TSDF_addr1
			, TSDF_addr2
			, TSDF_addr3
			, TSDF_city	
			, TSDF_state
			, TSDF_zip_code
			, state_regulatory_id
			, generator_id
			, generator_name
			, facility_id
			, profile_id
			, approval_desc
			, transporter_code
			, transporter_name
			, transporter_TX_id
*/
GO
GRANT EXECUTE ON sp_rpt_tceq_commercial_waste to EQAI
GO
