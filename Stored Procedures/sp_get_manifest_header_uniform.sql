USE [PLT_AI]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

-- 20191212 jcb #devops 11453
if exists (select 1 from sys.procedures where name = 'sp_get_manifest_header_uniform')
   BEGIN
     DROP PROCEDURE dbo.sp_get_manifest_header_uniform
   END
 GO

 
CREATE PROCEDURE [dbo].[sp_get_manifest_header_uniform] (
	@ra_source					varchar(20), 
	@ra_list					varchar(2000),
	@profit_center				int,
	@company_id					int,
	@rejection_manifest_flag	char(1) )
WITH RECOMPILE
AS
/***************************************************************************************
Returns manifest information for the manifest window
Requires: none
Loads on PLT_XX_AI

06/26/2006 rg	created
10/11/2006 rg	removed test for negative list_ids
02/04/2009 rb   Added TRIP source, trip_sequence_id to result set
03/09/2009 JPB	Modified to add blank/null handling for emergency_contact_phone
		was: COALESCE(Generator.emergency_phone_number, ProfitCenter.emergency_contact_phone),
		now: COALESCE(nullif(ltrim(rtrim(isnull(Generator.emergency_phone_number, ''))), ''), ProfitCenter.emergency_contact_phone),
		Added SET NOCOUNT ON ( and OFF)
04/14/2009 RWB  Retrieve all TSDF approvals, regardless of status
08/13/2009 RWB  Exclude void WorkOrderDetail records with bill_rate = -2
08/19/2010 RWB	Unlimited number of Transporters, pull first two for the header page
11/12/2012 JPB  Added call to fn_dot_shipping_desc to return DOT Shipping Desc.
01/02/2013 JDB	Fixed incorrect parameter in call to fn_dot_shipping_desc for inbound receipts.
08/19/2013 RWB	Added company_id to joins since proc is moving from company DBs to Plt_ai
12/08/2014 RWB	Suddenly started lots of blocking, added SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
08/10/2015 RWB	"On behalf of" is independent of EQ Approved Offerer description (print it based on flag)
08/10/2015 RWB	Fixed comparison of Generator site address to mailing address...look at more than just addr_1
08/17/2015 RWB	Extraneous generator city/state/zip was left in TSDF Approval insert into temp table...corrected
12/01/2015 RWB	Retrieve generator site name instead of mail name for manifest header
06/23/2017 MPM	Corrected the join between ProfitCenter and TSDF for inbound receipts.
06/25/2018 MPM	GEM 51165 - Added @rejection_manifest_flag input parameter and associated logic:
				If @rejection_manifest_flag = 'T', then populate the 'generator' fields with 'TSDF' values, 
				and populate 'TSDF' fields with 'alternate facility' values.
09/04/2018 MPM	GEM 47136 - Added column to indicate if the approval has RCRA hazardous waste.
09/21/2018 MPM	GEM 54617 - Corrected how has_rcra_haz_waste_codes is determined.
09/24/2018 MPM	GEM 54639 - Corrected (again!) how has_rcra_haz_waste_codes is determined.
11/05/2019 JCB  Devops #11453 get emergency phone # from profile not generator
12/12/2019 jcb  Devops #11453 chg to IF profile NULL then use Generator# unless thats null, then use ProfiCenter#
04/17/2020 MPM	DevOps 15221 - Increased #manifest.generator_addr5 to varchar(60).
11/22/2021 MPM	DevOps 19701 - Added logic for new customer billing offeror columns.
02/23/2022 MPM	DevOps 37370 - Increased the widths of some generator columns in #manifest to match the 
				increased widths of relevant columns in the Generator table.
03/01/2022 MPM	DevOps 30074 - Changed the setting of manifest form type for inbound and outbound receipts from 
				ProfitCenter.default_manifest_state to Receipt.manifest_form_type.
12/12/2023 Kamendra - DevOps #73851 - TSDF Approval - Print Manifest should handle default transporter.

sp_get_manifest_header_uniform 'WORKORDER', '-20',1,15
sp_get_manifest_header_uniform 'PROFILE', '155780',0,21
sp_get_manifest_header_uniform 'WORKORDER', '1000',0,47, 'F'
sp_get_manifest_header_uniform 'IRECEIPT', '640458',0,21
sp_get_manifest_header_uniform 'TSDFAPPR', '21977', 0, 21
sp_get_manifest_header_uniform 'TSDFAPPR', '22148', 2, 21, 'F'
sp_get_manifest_header_uniform 'IRECEIPT', '29601', 1, 21, 'T'
sp_get_manifest_header_uniform 'IRECEIPT', '29601', 1, 21, 'F'
sp_get_manifest_header_uniform 'IRECEIPT', '20928', 0, 55, 'F'

****************************************************************************************/

SET NOCOUNT ON

DECLARE  @more_rows int,
         @list_id 	int,
         @start 	int,
         @end 		int,
         @lnth 		int
         
CREATE TABLE #source_list (
	source_id int null	)

CREATE TABLE #manifest ( 
	control_id 						int null,
	source 							varchar(10) null,
	source_id 						int null,
	trip_sequence_id 				int null, -- rb
	source_code 					varchar(40) null,
	profit_center 					int null,
	num_pages 						int null,
	manifest 						varchar(15) null,
	manifest_state 					varchar(2) null,
	manifest_doc_num 				varchar(40) null,
	generator_id 					int null,
	generator_epaid 				varchar(12) null,
	generator_name 					varchar(75) null,
	generator_addr1 				varchar(85) null,
	generator_addr2 				varchar(40) null,
	generator_addr3 				varchar(40) null,
	generator_addr4 				varchar(40) null,
	generator_addr5 				varchar(60) null,
	generator_phone 				varchar(20) null,
	generator_site_1 				varchar(85) null,
	generator_site_2 				varchar(40) null,
	generator_city 					varchar(40) null,
	generator_state 				varchar(2) null,
	generator_zipcode 				varchar(15) null,
	transporter_code_1 				varchar(15) null,
	transporter_name_1 				varchar(40) null,
	transporter_epa_id_1 			varchar(15) null,
	transporter_phone_1 			varchar(20) null,   
	transporter_code_2 				varchar(15) null, 
	transporter_name_2 				varchar(40) null, 
	transporter_epa_id_2 			varchar(15) null,   
	transporter_phone_2 			varchar(20) null, 
	TSDF_code 						varchar(15) null,   
	TSDF_EPA_ID						varchar(15) null,   
	TSDF_name 						varchar(40) null,   
	TSDF_addr1 						varchar(40) null,   
	TSDF_addr2 						varchar(40) null,   
	TSDF_addr3 						varchar(40) null,   
	TSDF_phone 						varchar(20) null,
	emergency_contact_phone 		varchar(10) null,
	emergency_contact_name 			varchar(30) null,
	discrepancy_description 		varchar(255) null,
	discrepancy_qty_flag 			char(1)    null,
	discrepancy_type_flag 			char(1)       null,
	discrepancy_residue_flag 		char(1)   null,
	discrepancy_part_reject_flag 	char(1)  null,
	discrepancy_full_reject_flag 	char(1)   null,
	manifest_ref_number  			varchar(15)  null,
	export_from_us_flag  			char(1) null,
	import_to_us_flag    			char(1)   null,
	port_of_entry_exit   			varchar(30)  null,
	date_leaving_us      			datetime     null,
	alt_facility_type    			char(1)  null,
	alt_facility_code    			varchar(15) null,
	alt_facility_name    			varchar(40) null,
	alt_facility_addr1   			varchar(40) null,
	alt_facility_addr2   			varchar(40)  null,
	alt_facility_phone   			varchar(20) null,
	alt_facility_epa_id  			varchar(12)  null,
	dot_shipping_desc				varchar(max) null,
	emergency_contract_number       varchar(20) null,
	eq_approved_offerer_desc	varchar(255) null,
	eq_on_behalf_of_desc			varchar(80) null,
	has_rcra_haz_waste_codes		char(1) null	)

SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

-- decode the source list for retirieval

-- load the source list table
IF LEN(@ra_list) > 0
BEGIN
	SELECT	@more_rows = 1,
		@start = 1

	WHILE @more_rows = 1
	BEGIN
		SELECT @end = CHARINDEX(',',@ra_list,@start)
		
		IF @end > 0 
		BEGIN
			SELECT @lnth = @end - @start
			SELECT @list_id = CONVERT(int,SUBSTRING(@ra_list,@start,@lnth))
			SELECT @start = @end + 1
			INSERT INTO #source_list VALUES (@list_id)
		END
		ELSE 
		BEGIN
			SELECT @lnth = LEN(@ra_list)
			SELECT @list_id = CONVERT(int,SUBSTRING(@ra_list,@start,@lnth))
			SELECT @more_rows = 0
			INSERT INTO #source_list VALUES (@list_id)
		END
	END
END 
					 
-- determine the source; each source has its own query
-- out bound Receipts
IF @ra_source = 'ORECEIPT'
BEGIN
	INSERT #manifest
	SELECT DISTINCT
		0 AS print_control_id,
		CONVERT(varchar(10), @ra_source) AS source, 
		Receipt.receipt_id AS source_id,
		convert(int,null) as trip_sequence_id, -- rb
		CONVERT(varchar(40), '') AS source_code,
		Receipt.profit_ctr_id,
		0 AS num_pages,
		ISNULL(Receipt.manifest, ''),
		Receipt.manifest_form_type, --ProfitCenter.default_manifest_state,
		CONVERT(varchar(40),'') AS manifest_document_number,
		Receipt.generator_id,   
		Generator.EPA_ID,
		Generator.generator_name AS generator_mail_name,   
		Generator.gen_mail_addr1 AS generator_mail_addr1,   
		Generator.gen_mail_addr2 AS generator_mail_addr2,   
		Generator.gen_mail_addr3 AS generator_mail_addr3,   
		Generator.gen_mail_addr4 AS generator_mail_addr4,   
		RTRIM(CASE 
			WHEN (gen_mail_city + ', ' + gen_mail_state + ' ' + ISNULL(gen_mail_zip_code,'')) IS NULL 
			THEN 'Missing City, State, and ZipCode' 
			ELSE (gen_mail_city + ', ' + gen_mail_state + ' ' + ISNULL(gen_mail_zip_code,'')) 
			END) AS generator_mail_addr5,   
		Generator.generator_phone AS generator_phone , 
		CASE 
			WHEN isnull(ltrim(rtrim(Generator.generator_address_1)),'') = isnull(ltrim(rtrim(Generator.gen_mail_addr1)),'') and
				isnull(ltrim(rtrim(Generator.generator_address_2)),'') = isnull(ltrim(rtrim(Generator.gen_mail_addr2)),'') and
				isnull(ltrim(rtrim(Generator.generator_city)),'') = isnull(ltrim(rtrim(Generator.gen_mail_city)),'') and
				isnull(ltrim(rtrim(Generator.generator_state)),'') = isnull(ltrim(rtrim(Generator.gen_mail_state)),'') and
				isnull(ltrim(rtrim(Generator.generator_zip_code)),'') = isnull(ltrim(rtrim(Generator.gen_mail_zip_code)),'')
			THEN '' 
			ELSE Generator.generator_address_1
			END AS generator_site_addr1,   
		CASE
			WHEN isnull(ltrim(rtrim(Generator.generator_address_1)),'') = isnull(ltrim(rtrim(Generator.gen_mail_addr1)),'') and
				isnull(ltrim(rtrim(Generator.generator_address_2)),'') = isnull(ltrim(rtrim(Generator.gen_mail_addr2)),'') and
				isnull(ltrim(rtrim(Generator.generator_city)),'') = isnull(ltrim(rtrim(Generator.gen_mail_city)),'') and
				isnull(ltrim(rtrim(Generator.generator_state)),'') = isnull(ltrim(rtrim(Generator.gen_mail_state)),'') and
				isnull(ltrim(rtrim(Generator.generator_zip_code)),'') = isnull(ltrim(rtrim(Generator.gen_mail_zip_code)),'')
			THEN '' 
			ELSE Generator.generator_address_2
			END AS generator_site_addr2,   
		CASE
			WHEN isnull(ltrim(rtrim(Generator.generator_address_1)),'') = isnull(ltrim(rtrim(Generator.gen_mail_addr1)),'') and
				isnull(ltrim(rtrim(Generator.generator_address_2)),'') = isnull(ltrim(rtrim(Generator.gen_mail_addr2)),'') and
				isnull(ltrim(rtrim(Generator.generator_city)),'') = isnull(ltrim(rtrim(Generator.gen_mail_city)),'') and
				isnull(ltrim(rtrim(Generator.generator_state)),'') = isnull(ltrim(rtrim(Generator.gen_mail_state)),'') and
				isnull(ltrim(rtrim(Generator.generator_zip_code)),'') = isnull(ltrim(rtrim(Generator.gen_mail_zip_code)),'')
			THEN '' 
			ELSE Generator.generator_city
			END AS generator_site_city,
		CASE
			WHEN isnull(ltrim(rtrim(Generator.generator_address_1)),'') = isnull(ltrim(rtrim(Generator.gen_mail_addr1)),'') and
				isnull(ltrim(rtrim(Generator.generator_address_2)),'') = isnull(ltrim(rtrim(Generator.gen_mail_addr2)),'') and
				isnull(ltrim(rtrim(Generator.generator_city)),'') = isnull(ltrim(rtrim(Generator.gen_mail_city)),'') and
				isnull(ltrim(rtrim(Generator.generator_state)),'') = isnull(ltrim(rtrim(Generator.gen_mail_state)),'') and
				isnull(ltrim(rtrim(Generator.generator_zip_code)),'') = isnull(ltrim(rtrim(Generator.gen_mail_zip_code)),'')
			THEN '' 
			ELSE Generator.generator_state
			END AS generator_site_state,   
		CASE
			WHEN isnull(ltrim(rtrim(Generator.generator_address_1)),'') = isnull(ltrim(rtrim(Generator.gen_mail_addr1)),'') and
				isnull(ltrim(rtrim(Generator.generator_address_2)),'') = isnull(ltrim(rtrim(Generator.gen_mail_addr2)),'') and
				isnull(ltrim(rtrim(Generator.generator_city)),'') = isnull(ltrim(rtrim(Generator.gen_mail_city)),'') and
				isnull(ltrim(rtrim(Generator.generator_state)),'') = isnull(ltrim(rtrim(Generator.gen_mail_state)),'') and
				isnull(ltrim(rtrim(Generator.generator_zip_code)),'') = isnull(ltrim(rtrim(Generator.gen_mail_zip_code)),'')
			THEN '' 
			ELSE Generator.generator_zip_code
			END AS generator_site_zip_code,   
		Transporter.transporter_code AS transporter_code_1, 
		Transporter.transporter_name AS transporter_name_1, 
		Transporter.transporter_epa_id AS transporter_epa_id_1,   
		Transporter.transporter_phone AS transporter_phone_1,   
		CONVERT(varchar(40), '') AS transporter_code_2, 
		CONVERT(varchar(40), '') AS transporter_name_2, 
		CONVERT(varchar(15), '') AS transporter_epa_id_2,   
		CONVERT(varchar(20), '') AS  transporter_phone_2, 
		TSDF.TSDF_code AS TSDF_code,   
		TSDF.TSDF_EPA_ID AS TSDF_EPA_ID,   
		TSDF.TSDF_name AS TSDF_name,   
		TSDF.TSDF_addr1 AS TSDF_addr1,   
		TSDF.TSDF_addr2 AS TSDF_addr2,   
		RTRIM(CASE
			WHEN (TSDF.TSDF_city + ', ' + TSDF.TSDF_state + ' ' + ISNULL(TSDF.TSDF_zip_code,'')) IS NULL
			THEN 'Missing City, State, and ZipCode' 
			ELSE (TSDF.TSDF_city + ', ' + TSDF.TSDF_state + ' ' + ISNULL(TSDF.TSDF_zip_code,''))
			END) AS TSDF_addr3,   
		TSDF.TSDF_phone AS TSDF_phone,
		COALESCE(nullif(ltrim(rtrim(isnull(Generator.emergency_phone_number, ''))), ''), ProfitCenter.emergency_contact_phone),
		CONVERT(varchar(30), '') AS emergency_contact_name,
		NULL AS discrepancy_description,
                'F' AS discrepancy_qty_flag,
		'F' AS discrepancy_type_flag,
		'F' AS discrepancy_residue_flag,
		'F' AS discrepancy_part_reject_flag,
		'F' AS discrepancy_full_reject_flag,
		NULL AS manifest_ref_number,
                'F' AS export_from_us_flag,
		'F' AS import_to_us_flag,
		NULL AS port_of_entry_exit,
		NULL AS date_leaving_us,
		NULL AS alt_facility_type,
		NULL AS alt_facility_code,
		NULL AS alt_facility_name,
		NULL AS alt_facility_addr1,
		NULL AS alt_facility_addr2,
		NULL AS alt_facility_phone,
		NULL AS alt_facility_epa_id ,
		NULL as dot_shipping_desc,
		Generator.emergency_contract_number AS emergency_contract_number,
		dbo.fn_get_approved_offeror(@ra_source, Receipt.receipt_id, Receipt.company_id, Receipt.profit_ctr_id, 'F') as eq_approved_offerer_desc,
		dbo.fn_get_approved_offeror(@ra_source, Receipt.receipt_id, Receipt.company_id, Receipt.profit_ctr_id, 'T') as eq_on_behalf_of_desc,
		--case when isnull(Customer.eq_approved_offerer_flag,'F') = 'T' and isnull(Customer.eq_offerer_effective_dt,'2000-01-01 00:00:00') < getdate()
		--	then Customer.eq_approved_offerer_desc else convert(varchar(255),null) end as eq_approved_offerer_desc,
		--case when isnull(Customer.eq_approved_offerer_flag,'F') = 'T' and isnull(Customer.eq_offerer_effective_dt,'2000-01-01 00:00:00') < getdate()
		--	then convert(varchar(80),'On Behalf of ' + Customer.cust_name) else convert(varchar(80),null) end as eq_on_behalf_of_desc,
		case when exists (select 1
						from Receipt r
						join Profile p
						on p.profile_id = r.profile_id
						and p.RCRA_haz_flag = 'H'
						where r.company_id = Receipt.company_id
						and r.profit_ctr_ID = Receipt.profit_ctr_ID
						and r.receipt_id = Receipt.receipt_id
						union
				    	select 1
				    	from Receipt r
						join TSDFApproval ta 
						on ta.TSDF_approval_id = r.TSDF_approval_id
						and ta.RCRA_haz_flag = 'H'
						where r.company_id = Receipt.company_id
						and r.profit_ctr_ID = Receipt.profit_ctr_ID
						and r.receipt_id = Receipt.receipt_id)
			then 'T' else 'F' end as has_rcra_haz_waste_codes 	
	FROM Receipt
	INNER JOIN Generator ON Receipt.generator_id = Generator.generator_id
	INNER JOIN ProfitCenter ON Receipt.profit_ctr_id = ProfitCenter.profit_ctr_id
		AND Receipt.company_id = ProfitCenter.company_id
	INNER JOIN TSDF ON Receipt.TSDF_code = TSDF.TSDF_code
	LEFT OUTER JOIN Transporter ON Receipt.hauler = Transporter.transporter_code
	INNER JOIN Customer ON Receipt.customer_id = Customer.customer_id
	WHERE Receipt.company_id = @company_id
	AND Receipt.profit_ctr_id = @profit_center
	AND Receipt.trans_mode = 'O'
	AND Receipt.trans_type = 'D'
	AND Receipt.manifest_flag IN ('M','C')
	AND Receipt.receipt_status IN ('N','L','U','A')
	AND Receipt.receipt_id IN (SELECT source_id FROM #source_list)

	GOTO end_process
END


-- in bound receipts
IF @ra_source = 'IRECEIPT'
BEGIN
	INSERT #manifest
	SELECT DISTINCT
		0 AS print_control_id,
		CONVERT(varchar(10), @ra_source) AS source, 
		Receipt.receipt_id AS source_id,
		convert(int,null) as trip_sequence_id, -- rb
		CONVERT(varchar(40), '') AS source_code,
		Receipt.profit_ctr_id,
		0 AS num_pages,
		Receipt.manifest,
		Receipt.manifest_form_type, --ProfitCenter.default_manifest_state,
		CONVERT(varchar(40),'') AS manifest_document_number,
		CASE @rejection_manifest_flag 
			WHEN 'T' THEN 1 -- N/A generator	  
			ELSE Receipt.generator_id
		END,   
		CASE @rejection_manifest_flag 
			WHEN 'T' THEN TSDF.TSDF_EPA_ID 
			ELSE Generator.EPA_ID
		END,
		CASE @rejection_manifest_flag 
			WHEN 'T' THEN TSDF.TSDF_name 
			ELSE Generator.generator_name 
		END AS generator_mail_name,   
		CASE @rejection_manifest_flag 
			WHEN 'T' THEN TSDF.TSDF_addr1 
			ELSE Generator.gen_mail_addr1 
		END AS generator_mail_addr1,   
		CASE @rejection_manifest_flag 
			WHEN 'T' THEN TSDF.TSDF_addr2 
			ELSE Generator.gen_mail_addr2 
		END AS generator_mail_addr2,   
		CASE @rejection_manifest_flag 
			WHEN 'T' THEN TSDF.TSDF_addr3 
			ELSE Generator.gen_mail_addr3 
		END AS generator_mail_addr3,   
		CASE @rejection_manifest_flag 
			WHEN 'T' THEN NULL 
			ELSE Generator.gen_mail_addr4 
		END AS generator_mail_addr4,   
		CASE @rejection_manifest_flag 
			WHEN 'T' THEN RTRIM(CASE 
				WHEN (TSDF.TSDF_city + ', ' + TSDF.TSDF_state + ' ' + ISNULL(TSDF.TSDF_zip_code,'')) IS NULL 
				THEN 'Missing City, State, and ZipCode' 
				ELSE (TSDF.TSDF_city + ', ' + TSDF.TSDF_state + ' ' + ISNULL(TSDF.TSDF_zip_code,''))
			END) 
			ELSE RTRIM(CASE 
				WHEN (gen_mail_city + ', ' + gen_mail_state + ' ' + ISNULL(gen_mail_zip_code,'')) IS NULL 
				THEN 'Missing City, State, and ZipCode' 
				ELSE (gen_mail_city + ', ' + gen_mail_state + ' ' + ISNULL(gen_mail_zip_code,''))
				END) 
		END AS generator_mail_addr5,   
		CASE @rejection_manifest_flag 
			WHEN 'T' THEN TSDF.TSDF_phone 
			ELSE Generator.generator_phone 
		END AS generator_phone, 
		CASE @rejection_manifest_flag 
			WHEN 'T' THEN NULL 
			ELSE CASE 
				WHEN isnull(ltrim(rtrim(Generator.generator_address_1)),'') = isnull(ltrim(rtrim(Generator.gen_mail_addr1)),'') and
					isnull(ltrim(rtrim(Generator.generator_address_2)),'') = isnull(ltrim(rtrim(Generator.gen_mail_addr2)),'') and
					isnull(ltrim(rtrim(Generator.generator_city)),'') = isnull(ltrim(rtrim(Generator.gen_mail_city)),'') and
					isnull(ltrim(rtrim(Generator.generator_state)),'') = isnull(ltrim(rtrim(Generator.gen_mail_state)),'') and
					isnull(ltrim(rtrim(Generator.generator_zip_code)),'') = isnull(ltrim(rtrim(Generator.gen_mail_zip_code)),'')
				THEN '' 
				ELSE Generator.generator_address_1
				END 
			END AS generator_site_addr1,   
		CASE @rejection_manifest_flag
			WHEN 'T' THEN NULL 
			ELSE CASE
				WHEN isnull(ltrim(rtrim(Generator.generator_address_1)),'') = isnull(ltrim(rtrim(Generator.gen_mail_addr1)),'') and
					isnull(ltrim(rtrim(Generator.generator_address_2)),'') = isnull(ltrim(rtrim(Generator.gen_mail_addr2)),'') and
					isnull(ltrim(rtrim(Generator.generator_city)),'') = isnull(ltrim(rtrim(Generator.gen_mail_city)),'') and
					isnull(ltrim(rtrim(Generator.generator_state)),'') = isnull(ltrim(rtrim(Generator.gen_mail_state)),'') and
					isnull(ltrim(rtrim(Generator.generator_zip_code)),'') = isnull(ltrim(rtrim(Generator.gen_mail_zip_code)),'')
				THEN '' 
				ELSE Generator.generator_address_2
				END 
			END AS generator_site_addr2,   
		CASE @rejection_manifest_flag 
			WHEN 'T' THEN NULL 
			ELSE CASE
				WHEN isnull(ltrim(rtrim(Generator.generator_address_1)),'') = isnull(ltrim(rtrim(Generator.gen_mail_addr1)),'') and
					isnull(ltrim(rtrim(Generator.generator_address_2)),'') = isnull(ltrim(rtrim(Generator.gen_mail_addr2)),'') and
					isnull(ltrim(rtrim(Generator.generator_city)),'') = isnull(ltrim(rtrim(Generator.gen_mail_city)),'') and
					isnull(ltrim(rtrim(Generator.generator_state)),'') = isnull(ltrim(rtrim(Generator.gen_mail_state)),'') and
					isnull(ltrim(rtrim(Generator.generator_zip_code)),'') = isnull(ltrim(rtrim(Generator.gen_mail_zip_code)),'')
				THEN '' 
				ELSE Generator.generator_city
			END 
		END AS generator_site_city,
		CASE @rejection_manifest_flag 
			WHEN 'T' THEN NULL 
			ELSE CASE
				WHEN isnull(ltrim(rtrim(Generator.generator_address_1)),'') = isnull(ltrim(rtrim(Generator.gen_mail_addr1)),'') and
					isnull(ltrim(rtrim(Generator.generator_address_2)),'') = isnull(ltrim(rtrim(Generator.gen_mail_addr2)),'') and
					isnull(ltrim(rtrim(Generator.generator_city)),'') = isnull(ltrim(rtrim(Generator.gen_mail_city)),'') and
					isnull(ltrim(rtrim(Generator.generator_state)),'') = isnull(ltrim(rtrim(Generator.gen_mail_state)),'') and
					isnull(ltrim(rtrim(Generator.generator_zip_code)),'') = isnull(ltrim(rtrim(Generator.gen_mail_zip_code)),'')
				THEN '' 
				ELSE Generator.generator_state
			END
		END AS generator_site_state,   
		CASE @rejection_manifest_flag 
			WHEN 'T' THEN NULL 
			ELSE CASE
				WHEN isnull(ltrim(rtrim(Generator.generator_address_1)),'') = isnull(ltrim(rtrim(Generator.gen_mail_addr1)),'') and
					isnull(ltrim(rtrim(Generator.generator_address_2)),'') = isnull(ltrim(rtrim(Generator.gen_mail_addr2)),'') and
					isnull(ltrim(rtrim(Generator.generator_city)),'') = isnull(ltrim(rtrim(Generator.gen_mail_city)),'') and
					isnull(ltrim(rtrim(Generator.generator_state)),'') = isnull(ltrim(rtrim(Generator.gen_mail_state)),'') and
					isnull(ltrim(rtrim(Generator.generator_zip_code)),'') = isnull(ltrim(rtrim(Generator.gen_mail_zip_code)),'')
				THEN '' 
				ELSE Generator.generator_zip_code
			END 
		END AS generator_site_zip_code,   
		Transporter.transporter_code AS transporter_code_1, 
		Transporter.transporter_name AS transporter_name_1, 
		Transporter.transporter_epa_id AS transporter_epa_id_1,   
		Transporter.transporter_phone AS transporter_phone_1,   
		CONVERT(varchar(40), '') AS transporter_code_2, 
		CONVERT(varchar(40), '') AS transporter_name_2, 
		CONVERT(varchar(15), '') AS transporter_epa_id_2,   
		CONVERT(varchar(20), '') AS  transporter_phone_2, 
		CASE @rejection_manifest_flag WHEN 'T' THEN ReceiptDiscrepancy.alt_facility_code ELSE TSDF.TSDF_code END AS TSDF_code,   
		CASE @rejection_manifest_flag WHEN 'T' THEN ReceiptDiscrepancy.alt_facility_epa_id ELSE TSDF.TSDF_EPA_ID END AS TSDF_EPA_ID,   
		CASE @rejection_manifest_flag WHEN 'T' THEN ReceiptDiscrepancy.alt_facility_name ELSE TSDF.TSDF_name END AS TSDF_name,   
		CASE @rejection_manifest_flag WHEN 'T' THEN ReceiptDiscrepancy.alt_facility_addr1 ELSE TSDF.TSDF_addr1 END AS TSDF_addr1,   
		CASE @rejection_manifest_flag WHEN 'T' THEN ReceiptDiscrepancy.alt_facility_addr2 ELSE TSDF.TSDF_addr2 END AS TSDF_addr2,   
		CASE @rejection_manifest_flag 
			WHEN 'T' THEN 
				RTRIM(CASE 
					WHEN (ReceiptDiscrepancy.alt_facility_city + ', ' + ReceiptDiscrepancy.alt_facility_state + ' ' + ISNULL(ReceiptDiscrepancy.alt_facility_zip_code,'')) IS NULL 
					THEN 'Missing City, State, and ZipCode' 
					ELSE (ReceiptDiscrepancy.alt_facility_city + ', ' + ReceiptDiscrepancy.alt_facility_state + ' ' + ISNULL(ReceiptDiscrepancy.alt_facility_zip_code,''))
					END)			
			ELSE 
				RTRIM(CASE 
					WHEN (TSDF.TSDF_city + ', ' + TSDF.TSDF_state + ' ' + ISNULL(TSDF.TSDF_zip_code,'')) IS NULL 
					THEN 'Missing City, State, and ZipCode' 
					ELSE (TSDF.TSDF_city + ', ' + TSDF.TSDF_state + ' ' + ISNULL(TSDF.TSDF_zip_code,''))
				END) 
		END AS TSDF_addr3,
		CASE @rejection_manifest_flag 
			WHEN 'T' THEN ReceiptDiscrepancy.alt_facility_phone 
			ELSE TSDF.TSDF_phone 
		END AS TSDF_phone,
		CASE @rejection_manifest_flag 
			WHEN 'T' THEN COALESCE(nullif(ltrim(rtrim(isnull(TSDF.emergency_contact_phone, ''))), ''), ProfitCenter.emergency_contact_phone) 
			ELSE COALESCE(nullif(ltrim(rtrim(isnull(Generator.emergency_phone_number, ''))), ''), ProfitCenter.emergency_contact_phone) 
		END,
		CONVERT(varchar(30), '') AS emergency_contact_name,
		ReceiptDiscrepancy.discrepancy_description ,
		ISNULL(ReceiptDiscrepancy.discrepancy_qty_flag,'F') ,
		ISNULL(ReceiptDiscrepancy.discrepancy_type_flag,'F') ,
		ISNULL(ReceiptDiscrepancy.discrepancy_residue_flag,'F') ,
		ISNULL(ReceiptDiscrepancy.discrepancy_part_reject_flag,'F'),
		ISNULL(ReceiptDiscrepancy.discrepancy_full_reject_flag,'F') ,
		ReceiptDiscrepancy.manifest_ref_number,
		ISNULL(ReceiptDiscrepancy.export_from_us_flag,'F') ,
		ISNULL(ReceiptDiscrepancy.import_to_us_flag,'F'),
		ReceiptDiscrepancy.port_of_entry_exit,
		ReceiptDiscrepancy.date_leaving_us,
		ReceiptDiscrepancy.alt_facility_type,
		ReceiptDiscrepancy.alt_facility_code,
		ReceiptDiscrepancy.alt_facility_name,
		ReceiptDiscrepancy.alt_facility_addr1,
		ReceiptDiscrepancy.alt_facility_addr2,
		ReceiptDiscrepancy.alt_facility_phone,
		ReceiptDiscrepancy.alt_facility_epa_id,
-- rb		fn_dot_shipping_desc(Receipt.profile_id),
		NULL as dot_shipping_desc,
		CASE @rejection_manifest_flag WHEN 'T' THEN NULL ELSE Generator.emergency_contract_number END AS emergency_contract_number,
		dbo.fn_get_approved_offeror(@ra_source, Receipt.receipt_id, Receipt.company_id, Receipt.profit_ctr_id, 'F') as eq_approved_offerer_desc,
		dbo.fn_get_approved_offeror(@ra_source, Receipt.receipt_id, Receipt.company_id, Receipt.profit_ctr_id, 'T') as eq_on_behalf_of_desc,
		--case when isnull(Customer.eq_approved_offerer_flag,'F') = 'T' and isnull(Customer.eq_offerer_effective_dt,'2000-01-01 00:00:00') < getdate()
		--	then Customer.eq_approved_offerer_desc else convert(varchar(255),null) end as eq_approved_offerer_desc,
		--case when isnull(Customer.eq_approved_offerer_flag,'F') = 'T' and isnull(Customer.eq_offerer_effective_dt,'2000-01-01 00:00:00') < getdate()
		--	then convert(varchar(80),'On Behalf of ' + Customer.cust_name) else convert(varchar(80),null) end as eq_on_behalf_of_desc,
		case when exists (select 1
						from Receipt r
						join Profile p
						on p.profile_id = r.profile_id
						and p.RCRA_haz_flag = 'H'
						where r.company_id = Receipt.company_id
						and r.profit_ctr_ID = Receipt.profit_ctr_ID
						and r.receipt_id = Receipt.receipt_id
						union
				    	select 1
				    	from Receipt r
						join TSDFApproval ta 
						on ta.TSDF_approval_id = r.TSDF_approval_id
						and ta.RCRA_haz_flag = 'H'
						where r.company_id = Receipt.company_id
						and r.profit_ctr_ID = Receipt.profit_ctr_ID
						and r.receipt_id = Receipt.receipt_id)
			then 'T' else 'F' end as has_rcra_haz_waste_codes 		
	FROM	Receipt
	INNER JOIN Generator ON Receipt.generator_id = Generator.generator_id
	INNER JOIN ProfitCenter ON Receipt.profit_ctr_id = ProfitCenter.profit_ctr_id
		AND Receipt.company_id = ProfitCenter.company_id
	LEFT OUTER JOIN Transporter ON Receipt.hauler = Transporter.transporter_code
	LEFT OUTER JOIN ReceiptDiscrepancy ON Receipt.receipt_id = ReceiptDiscrepancy.receipt_id
		AND Receipt.company_id = ReceiptDiscrepancy.company_id
		AND Receipt.profit_ctr_id = ReceiptDiscrepancy.profit_ctr_id
	LEFT OUTER JOIN TSDF ON ProfitCenter.company_ID  = TSDF.eq_company
	    AND ProfitCenter.profit_ctr_ID = TSDF.eq_profit_ctr
	    AND TSDF.TSDF_status = 'A'
	INNER JOIN Customer ON Receipt.customer_id = Customer.customer_id
	WHERE Receipt.company_id = @company_id
	AND Receipt.profit_ctr_ID = @profit_center
	AND Receipt.trans_mode = 'I'
	AND Receipt.trans_type = 'D'
	AND Receipt.manifest_flag IN ('M','C')
	AND ((Receipt.receipt_status IN ('N','L','U','A') AND @rejection_manifest_flag = 'F') OR 
	     (Receipt.fingerpr_status = 'R' AND @rejection_manifest_flag = 'T'))
	AND Receipt.receipt_id IN (SELECT source_id FROM #source_list)
	
	GOTO end_process
END

-- workorders
IF @ra_source = 'WORKORDER'
BEGIN
        INSERT #manifest
	SELECT DISTINCT
		0 AS print_control_id,
		-- rb, trip
		case when WorkOrderHeader.workorder_id <= -1000 then convert(varchar(10),'TRIP ' + convert(varchar(5),WorkOrderHeader.trip_id)) else CONVERT(varchar(10), @ra_source) end AS source, 
		WorkOrderHeader.workorder_id as source_id,
		WorkOrderHeader.trip_sequence_id, -- rb
		CONVERT(varchar(40), '') AS source_code,
		WorkOrderHeader.profit_ctr_id,
		0 AS num_pages,
		WorkOrderManifest.manifest,
		WorkOrderManifest.manifest_state,
		LEFT(WorkOrderManifest.gen_manifest_doc_number, 10) AS manifest_document_number,
		WorkOrderHeader.generator_id AS generator_id,   
		Generator.EPA_ID,
		Generator.generator_name AS generator_mail_name,   
		Generator.gen_mail_addr1 AS generator_mail_addr1,   
		Generator.gen_mail_addr2 AS generator_mail_addr2,   
		Generator.gen_mail_addr3 AS generator_mail_addr3,   
		Generator.gen_mail_addr4 AS generator_mail_addr4,   
		RTrim(CASE WHEN (gen_mail_city + ', ' + gen_mail_state + ' ' + ISNULL(gen_mail_zip_code,'')) IS NULL THEN 'Missing City, State, and ZipCode' 
			ELSE (gen_mail_city + ', ' + gen_mail_state + ' ' + ISNULL(gen_mail_zip_code,'')) END) AS generator_mail_addr5,   
		Generator.generator_phone AS generator_phone , 
		CASE 
			WHEN isnull(ltrim(rtrim(Generator.generator_address_1)),'') = isnull(ltrim(rtrim(Generator.gen_mail_addr1)),'') and
				isnull(ltrim(rtrim(Generator.generator_address_2)),'') = isnull(ltrim(rtrim(Generator.gen_mail_addr2)),'') and
				isnull(ltrim(rtrim(Generator.generator_city)),'') = isnull(ltrim(rtrim(Generator.gen_mail_city)),'') and
				isnull(ltrim(rtrim(Generator.generator_state)),'') = isnull(ltrim(rtrim(Generator.gen_mail_state)),'') and
				isnull(ltrim(rtrim(Generator.generator_zip_code)),'') = isnull(ltrim(rtrim(Generator.gen_mail_zip_code)),'')
			THEN '' 
			ELSE Generator.generator_address_1
			END AS generator_site_addr1,   
		CASE
			WHEN isnull(ltrim(rtrim(Generator.generator_address_1)),'') = isnull(ltrim(rtrim(Generator.gen_mail_addr1)),'') and
				isnull(ltrim(rtrim(Generator.generator_address_2)),'') = isnull(ltrim(rtrim(Generator.gen_mail_addr2)),'') and
				isnull(ltrim(rtrim(Generator.generator_city)),'') = isnull(ltrim(rtrim(Generator.gen_mail_city)),'') and
				isnull(ltrim(rtrim(Generator.generator_state)),'') = isnull(ltrim(rtrim(Generator.gen_mail_state)),'') and
				isnull(ltrim(rtrim(Generator.generator_zip_code)),'') = isnull(ltrim(rtrim(Generator.gen_mail_zip_code)),'')
			THEN '' 
			ELSE Generator.generator_address_2
			END AS generator_site_addr2,   
		CASE
			WHEN isnull(ltrim(rtrim(Generator.generator_address_1)),'') = isnull(ltrim(rtrim(Generator.gen_mail_addr1)),'') and
				isnull(ltrim(rtrim(Generator.generator_address_2)),'') = isnull(ltrim(rtrim(Generator.gen_mail_addr2)),'') and
				isnull(ltrim(rtrim(Generator.generator_city)),'') = isnull(ltrim(rtrim(Generator.gen_mail_city)),'') and
				isnull(ltrim(rtrim(Generator.generator_state)),'') = isnull(ltrim(rtrim(Generator.gen_mail_state)),'') and
				isnull(ltrim(rtrim(Generator.generator_zip_code)),'') = isnull(ltrim(rtrim(Generator.gen_mail_zip_code)),'')
			THEN '' 
			ELSE Generator.generator_city
			END AS generator_site_city,
		CASE
			WHEN isnull(ltrim(rtrim(Generator.generator_address_1)),'') = isnull(ltrim(rtrim(Generator.gen_mail_addr1)),'') and
				isnull(ltrim(rtrim(Generator.generator_address_2)),'') = isnull(ltrim(rtrim(Generator.gen_mail_addr2)),'') and
				isnull(ltrim(rtrim(Generator.generator_city)),'') = isnull(ltrim(rtrim(Generator.gen_mail_city)),'') and
				isnull(ltrim(rtrim(Generator.generator_state)),'') = isnull(ltrim(rtrim(Generator.gen_mail_state)),'') and
				isnull(ltrim(rtrim(Generator.generator_zip_code)),'') = isnull(ltrim(rtrim(Generator.gen_mail_zip_code)),'')
			THEN '' 
			ELSE Generator.generator_state
			END AS generator_site_state,   
		CASE
			WHEN isnull(ltrim(rtrim(Generator.generator_address_1)),'') = isnull(ltrim(rtrim(Generator.gen_mail_addr1)),'') and
				isnull(ltrim(rtrim(Generator.generator_address_2)),'') = isnull(ltrim(rtrim(Generator.gen_mail_addr2)),'') and
				isnull(ltrim(rtrim(Generator.generator_city)),'') = isnull(ltrim(rtrim(Generator.gen_mail_city)),'') and
				isnull(ltrim(rtrim(Generator.generator_state)),'') = isnull(ltrim(rtrim(Generator.gen_mail_state)),'') and
				isnull(ltrim(rtrim(Generator.generator_zip_code)),'') = isnull(ltrim(rtrim(Generator.gen_mail_zip_code)),'')
			THEN '' 
			ELSE Generator.generator_zip_code
			END AS generator_site_zip_code,   
-- rb 08/19/2010 Unlimited transporters
		convert(varchar(40),'') /*T1.transporter_code*/ AS transporter_code_1, 
		convert(varchar(40),'') /*T1.transporter_name*/ AS transporter_name_1, 
		convert(varchar(15),'') /*T1.transporter_epa_id*/ AS transporter_epa_id_1,   
		convert(varchar(20),'') /*T1.transporter_phone*/ AS transporter_phone_1,   
		convert(varchar(40),'') /*T2.transporter_code*/ AS transporter_code_2, 
		convert(varchar(40),'') /*T2.transporter_name*/ AS transporter_name_2, 
		convert(varchar(15),'') /*T2.transporter_epa_id*/ AS transporter_epa_id_2,   
		convert(varchar(20),'') /*T2.transporter_phone*/ AS transporter_phone_2,
		TSDF.TSDF_code AS TSDF_code,   
		TSDF.TSDF_EPA_ID AS TSDF_EPA_ID,   
		TSDF.TSDF_name AS TSDF_name,   
		TSDF.TSDF_addr1 AS TSDF_addr1,   
		TSDF.TSDF_addr2 AS TSDF_addr2,   
		RTrim(CASE WHEN (TSDF.TSDF_city + ', ' + TSDF.TSDF_state + ' ' + ISNULL(TSDF.TSDF_zip_code,'')) IS NULL THEN 'Missing City, State, and ZipCode' 
			ELSE (TSDF.TSDF_city + ', ' + TSDF.TSDF_state + ' ' + ISNULL(TSDF.TSDF_zip_code,'')) END) AS TSDF_addr3,   
		TSDF.TSDF_phone AS TSDF_phone,
		COALESCE(nullif(ltrim(rtrim(isnull(Generator.emergency_phone_number, ''))), ''), ProfitCenter.emergency_contact_phone),
		CONVERT(varchar(30), '') AS emergency_contact_name,
		NULL AS discrepancy_description,
	        'F' AS discrepancy_qty_flag,
		'F' AS discrepancy_type_flag,
		'F' AS discrepancy_residue_flag,
		'F' AS discrepancy_part_reject_flag,
		'F' AS discrepancy_full_reject_flag,
		NULL AS manifest_ref_number,
	        'F' AS export_from_us_flag,
		'F' AS import_to_us_flag,
		NULL AS port_of_entry_exit,
		NULL AS date_leaving_us,
		NULL AS alt_facility_type,
		NULL AS alt_facility_code,
		NULL AS alt_facility_name,
		NULL AS alt_facility_addr1,
		NULL AS alt_facility_addr2,
		NULL AS alt_facility_phone,
		NULL AS alt_facility_epa_id ,
		NULL as dot_shipping_desc,
		Generator.emergency_contract_number AS emergency_contract_number,
		dbo.fn_get_approved_offeror(@ra_source, WorkOrderHeader.workorder_id, WorkOrderHeader.company_id, WorkOrderHeader.profit_ctr_id, 'F') as eq_approved_offerer_desc,
		dbo.fn_get_approved_offeror(@ra_source, WorkOrderHeader.workorder_id, WorkOrderHeader.company_id, WorkOrderHeader.profit_ctr_id, 'T') as eq_on_behalf_of_desc,
		--case when isnull(Customer.eq_approved_offerer_flag,'F') = 'T' and isnull(Customer.eq_offerer_effective_dt,'2000-01-01 00:00:00') < getdate()
		--	then Customer.eq_approved_offerer_desc else convert(varchar(255),null) end as eq_approved_offerer_desc,
		--case when isnull(Customer.eq_approved_offerer_flag,'F') = 'T' and isnull(Customer.eq_offerer_effective_dt,'2000-01-01 00:00:00') < getdate()
		--	then convert(varchar(80),'On Behalf of ' + Customer.cust_name) else convert(varchar(80),null) end as eq_on_behalf_of_desc,
		case when exists (select 1
						from WorkOrderDetail wod
						join Profile p
						on p.profile_id = wod.profile_id
						and p.RCRA_haz_flag = 'H'
						where wod.company_id = WorkOrderDetail.company_id
						and wod.profit_ctr_ID = WorkOrderDetail.profit_ctr_ID
						and wod.workorder_ID = WorkOrderDetail.workorder_id
						and wod.manifest = WorkOrderDetail.manifest
						union
				    	select 1
				    	from WorkOrderDetail wod
						join TSDFApproval ta 
						on ta.TSDF_approval_id = wod.TSDF_approval_id
						and ta.RCRA_haz_flag = 'H'
						where wod.company_id = WorkOrderDetail.company_id
						and wod.profit_ctr_ID = WorkOrderDetail.profit_ctr_ID
						and wod.workorder_ID = WorkOrderDetail.workorder_id
						and wod.manifest = WorkOrderDetail.manifest)
			then 'T' else 'F' end as has_rcra_haz_waste_codes 	
	FROM WorkOrderHeader
	INNER JOIN WorkOrderDetail ON (WorkOrderHeader.workorder_ID = WorkOrderDetail.workorder_id
		AND WorkOrderHeader.profit_ctr_ID = WorkOrderDetail.profit_ctr_ID
		AND WorkOrderHeader.company_id = WorkOrderDetail.company_id)
	INNER JOIN WorkOrderManifest ON (WorkOrderDetail.workorder_ID = WorkOrderManifest.workorder_id
		AND WorkOrderDetail.profit_ctr_ID = WorkOrderManifest.profit_ctr_ID
		AND WorkOrderDetail.manifest = WorkOrderManifest.manifest
		AND workOrderDetail.company_id = WorkOrderManifest.company_id)
	INNER JOIN Generator ON WorkOrderHeader.generator_id = Generator.generator_id
	INNER JOIN TSDF ON WorkOrderDetail.TSDF_code = TSDF.TSDF_code
-- rb 08/19/2010 Unlimited transporters
--	LEFT OUTER JOIN Transporter T1 ON WorkOrderManifest.transporter_code_1 = T1.transporter_code 
--	LEFT OUTER JOIN Transporter T2 ON WorkOrderManifest.transporter_code_2 = T2.transporter_code 
	INNER JOIN ProfitCenter ON (WorkOrderHeader.profit_ctr_id = ProfitCenter.profit_ctr_id
		AND WorkOrderHeader.company_ID = ProfitCenter.company_ID)
	INNER JOIN Customer ON WorkOrderHeader.customer_id = Customer.customer_id
	WHERE WorkOrderHeader.company_ID = @company_id
		AND WorkOrderHeader.profit_ctr_ID = @profit_center
		AND WorkOrderDetail.resource_type = 'D'
		AND WorkOrderHeader.workorder_id IN (SELECT source_id FROM #source_list)
		AND WorkOrderDetail.bill_rate <> -2 -- rb 08/13/2009
	GOTO end_process
END

-- Profiles
IF @ra_source = 'PROFILE'
BEGIN
	INSERT #manifest
	SELECT DISTINCT
		0 AS print_control_id,
		CONVERT(varchar(10), @ra_source) AS source, 
		Profile.profile_id AS source_id,
		convert(int,null) as trip_sequence_id, -- rb
		ProfileQuoteApproval.approval_code AS source_code,
		ProfileQuoteApproval.profit_ctr_id,
		0 AS num_pages,
		CONVERT(varchar(15), '') AS manifest,
		ProfitCenter.default_manifest_state AS manifest_state,
		CONVERT(varchar(40), '') AS manifest_document_number,
		Profile.generator_id AS generator_id,   
		Generator.EPA_ID,
		Generator.generator_name AS generator_mail_name,   
		Generator.gen_mail_addr1 AS generator_mail_addr1,   
		Generator.gen_mail_addr2 AS generator_mail_addr2,   
		Generator.gen_mail_addr3 AS generator_mail_addr3,   
		Generator.gen_mail_addr4 AS generator_mail_addr4,   
		RTrim(CASE WHEN (gen_mail_city + ', ' + gen_mail_state + ' ' + ISNULL(gen_mail_zip_code,'')) IS NULL THEN 'Missing City, State, and ZipCode' 
			ELSE (gen_mail_city + ', ' + gen_mail_state + ' ' + ISNULL(gen_mail_zip_code,'')) END) AS generator_mail_addr5,   
		Generator.generator_phone AS generator_phone , 
		CASE 
			WHEN isnull(ltrim(rtrim(Generator.generator_address_1)),'') = isnull(ltrim(rtrim(Generator.gen_mail_addr1)),'') and
				isnull(ltrim(rtrim(Generator.generator_address_2)),'') = isnull(ltrim(rtrim(Generator.gen_mail_addr2)),'') and
				isnull(ltrim(rtrim(Generator.generator_city)),'') = isnull(ltrim(rtrim(Generator.gen_mail_city)),'') and
				isnull(ltrim(rtrim(Generator.generator_state)),'') = isnull(ltrim(rtrim(Generator.gen_mail_state)),'') and
				isnull(ltrim(rtrim(Generator.generator_zip_code)),'') = isnull(ltrim(rtrim(Generator.gen_mail_zip_code)),'')
			THEN '' 
			ELSE Generator.generator_address_1
			END AS generator_site_addr1,   
		CASE
			WHEN isnull(ltrim(rtrim(Generator.generator_address_1)),'') = isnull(ltrim(rtrim(Generator.gen_mail_addr1)),'') and
				isnull(ltrim(rtrim(Generator.generator_address_2)),'') = isnull(ltrim(rtrim(Generator.gen_mail_addr2)),'') and
				isnull(ltrim(rtrim(Generator.generator_city)),'') = isnull(ltrim(rtrim(Generator.gen_mail_city)),'') and
				isnull(ltrim(rtrim(Generator.generator_state)),'') = isnull(ltrim(rtrim(Generator.gen_mail_state)),'') and
				isnull(ltrim(rtrim(Generator.generator_zip_code)),'') = isnull(ltrim(rtrim(Generator.gen_mail_zip_code)),'')
			THEN '' 
			ELSE Generator.generator_address_2
			END AS generator_site_addr2,   
		CASE
			WHEN isnull(ltrim(rtrim(Generator.generator_address_1)),'') = isnull(ltrim(rtrim(Generator.gen_mail_addr1)),'') and
				isnull(ltrim(rtrim(Generator.generator_address_2)),'') = isnull(ltrim(rtrim(Generator.gen_mail_addr2)),'') and
				isnull(ltrim(rtrim(Generator.generator_city)),'') = isnull(ltrim(rtrim(Generator.gen_mail_city)),'') and
				isnull(ltrim(rtrim(Generator.generator_state)),'') = isnull(ltrim(rtrim(Generator.gen_mail_state)),'') and
				isnull(ltrim(rtrim(Generator.generator_zip_code)),'') = isnull(ltrim(rtrim(Generator.gen_mail_zip_code)),'')
			THEN '' 
			ELSE Generator.generator_city
			END AS generator_site_city,
		CASE
			WHEN isnull(ltrim(rtrim(Generator.generator_address_1)),'') = isnull(ltrim(rtrim(Generator.gen_mail_addr1)),'') and
				isnull(ltrim(rtrim(Generator.generator_address_2)),'') = isnull(ltrim(rtrim(Generator.gen_mail_addr2)),'') and
				isnull(ltrim(rtrim(Generator.generator_city)),'') = isnull(ltrim(rtrim(Generator.gen_mail_city)),'') and
				isnull(ltrim(rtrim(Generator.generator_state)),'') = isnull(ltrim(rtrim(Generator.gen_mail_state)),'') and
				isnull(ltrim(rtrim(Generator.generator_zip_code)),'') = isnull(ltrim(rtrim(Generator.gen_mail_zip_code)),'')
			THEN '' 
			ELSE Generator.generator_state
			END AS generator_site_state,   
		CASE
			WHEN isnull(ltrim(rtrim(Generator.generator_address_1)),'') = isnull(ltrim(rtrim(Generator.gen_mail_addr1)),'') and
				isnull(ltrim(rtrim(Generator.generator_address_2)),'') = isnull(ltrim(rtrim(Generator.gen_mail_addr2)),'') and
				isnull(ltrim(rtrim(Generator.generator_city)),'') = isnull(ltrim(rtrim(Generator.gen_mail_city)),'') and
				isnull(ltrim(rtrim(Generator.generator_state)),'') = isnull(ltrim(rtrim(Generator.gen_mail_state)),'') and
				isnull(ltrim(rtrim(Generator.generator_zip_code)),'') = isnull(ltrim(rtrim(Generator.gen_mail_zip_code)),'')
			THEN '' 
			ELSE Generator.generator_zip_code
			END AS generator_site_zip_code,   
		T1.transporter_code AS transporter_code_1, 
		T1.transporter_name AS transporter_name_1, 
		T1.transporter_epa_id AS transporter_epa_id_1,   
		T1.transporter_phone AS transporter_phone_1,   
		T2.transporter_code AS transporter_code_2, 
		T2.transporter_name AS transporter_name_2, 
		T2.transporter_epa_id AS transporter_epa_id_2,   
		T2.transporter_phone AS transporter_phone_2, 
		TSDF.TSDF_code AS TSDF_code,   
		TSDF.TSDF_EPA_ID AS TSDF_EPA_ID,   
		TSDF.TSDF_name AS TSDF_name,   
		TSDF.TSDF_addr1 AS TSDF_addr1,   
		TSDF.TSDF_addr2 AS TSDF_addr2,   
		RTrim(CASE WHEN (TSDF.TSDF_city + ', ' + TSDF.TSDF_state + ' ' + ISNULL(TSDF.TSDF_zip_code,'')) IS NULL THEN 'Missing City, State, and ZipCode' 
			ELSE (TSDF.TSDF_city + ', ' + TSDF.TSDF_state + ' ' + ISNULL(TSDF.TSDF_zip_code,'')) END) AS TSDF_addr3,   
		TSDF.TSDF_phone AS TSDF_phone,
		-- 20191105 jcb #11453 REPL COALESCE(nullif(ltrim(rtrim(isnull(Generator.emergency_phone_number, ''))), ''), ProfitCenter.emergency_contact_phone),
        -- 20191212 jcb #11453 repl COALESCE(nullif(ltrim(rtrim(isnull(Profile.emergency_phone_number, ''))), ''), ProfitCenter.emergency_contact_phone),
	    COALESCE(nullif(ltrim(rtrim(isnull(Profile.emergency_phone_number, ''))), ''), COALESCE(nullif(ltrim(rtrim(isnull(Generator.emergency_phone_number, ''))), ''), ProfitCenter.emergency_contact_phone)),
		CONVERT(varchar(30), '') AS emergency_contact_name,
		NULL AS discrepancy_description,
	        'F' AS discrepancy_qty_flag,
		'F' AS discrepancy_type_flag,
		'F' AS discrepancy_residue_flag,
		'F' AS discrepancy_part_reject_flag,
		'F' AS discrepancy_full_reject_flag,
		NULL AS manifest_ref_number,
	        'F' AS export_from_us_flag,
		'F' AS import_to_us_flag,
		NULL AS port_of_entry_exit,
		NULL AS date_leaving_us,
		NULL AS alt_facility_type,
		NULL AS alt_facility_code,
		NULL AS alt_facility_name,
		NULL AS alt_facility_addr1,
		NULL AS alt_facility_addr2,
		NULL AS alt_facility_phone,
		NULL AS alt_facility_epa_id,
		dbo.fn_dot_shipping_desc(Profile.profile_id),
		Generator.emergency_contract_number AS emergency_contract_number,
		dbo.fn_get_approved_offeror(@ra_source, ProfileQuoteApproval.profile_id, ProfileQuoteApproval.company_id, ProfileQuoteApproval.profit_ctr_id, 'F') as eq_approved_offerer_desc,
		dbo.fn_get_approved_offeror(@ra_source, ProfileQuoteApproval.profile_id, ProfileQuoteApproval.company_id, ProfileQuoteApproval.profit_ctr_id, 'T') as eq_on_behalf_of_desc,
		--case when isnull(Customer.eq_approved_offerer_flag,'F') = 'T' and isnull(Customer.eq_offerer_effective_dt,'2000-01-01 00:00:00') < getdate()
		--	then Customer.eq_approved_offerer_desc else convert(varchar(255),null) end as eq_approved_offerer_desc,
		--case when isnull(Customer.eq_approved_offerer_flag,'F') = 'T' and isnull(Customer.eq_offerer_effective_dt,'2000-01-01 00:00:00') < getdate()
		--	then convert(varchar(80),'On Behalf of ' + Customer.cust_name) else convert(varchar(80),null) end as eq_on_behalf_of_desc,
		case when isnull(Profile.RCRA_haz_flag, 'F') = 'H' then 'T' else 'F' end as has_rcra_haz_waste_codes
	FROM Profile
	INNER JOIN ProfileQuoteApproval ON ProfileQuoteApproval.profile_id = Profile.profile_id
	INNER JOIN Generator ON Profile.generator_id = Generator.generator_id
	INNER JOIN ProfitCenter ON (ProfileQuoteApproval.profit_ctr_ID = ProfitCenter.profit_ctr_ID
		AND ProfileQuoteApproval.company_id = ProfitCenter.company_id)
	INNER JOIN TSDF ON ProfitCenter.default_TSDF_code =  TSDF.TSDF_code
	LEFT OUTER JOIN Transporter T1 ON COALESCE(Profile.transporter_code_1, ProfitCenter.default_transporter) = T1.transporter_code
	LEFT OUTER JOIN Transporter T2 ON Profile.transporter_code_2 = T2.transporter_code
	INNER JOIN Customer ON Profile.customer_id = Customer.customer_id
	WHERE ProfileQuoteApproval.company_id = @company_id
		AND ProfileQuoteApproval.profit_ctr_ID = @profit_center
		AND Profile.curr_status_code = 'A'
		AND ProfileQuoteApproval.profile_id IN (SELECT source_id FROM #source_list)

	GOTO end_process
END

-- TSDF Approvals
IF @ra_source = 'TSDFAPPR'
BEGIN
	INSERT #manifest
	SELECT DISTINCT
		0 AS print_control_id,
		CONVERT(varchar(10), @ra_source) AS source, 
		TSDFApproval.TSDF_approval_id AS source_id,
		convert(int,null) as trip_sequence_id, -- rb
		TSDFApproval.TSDF_approval_code AS source_code,
		TSDFApproval.profit_ctr_id,
		0 AS num_pages,
		CONVERT(varchar(15), '') AS manifest,
		ProfitCenter.default_manifest_state AS manifest_state,
		CONVERT(varchar(40), '') AS manifest_document_number,
		TSDFApproval.generator_id AS generator_id,   
		Generator.EPA_ID,
		Generator.generator_name AS generator_mail_name,   
		Generator.gen_mail_addr1 AS generator_mail_addr1,   
		Generator.gen_mail_addr2 AS generator_mail_addr2,   
		Generator.gen_mail_addr3 AS generator_mail_addr3,   
		Generator.gen_mail_addr4 AS generator_mail_addr4,   
		RTrim(CASE WHEN (gen_mail_city + ', ' + gen_mail_state + ' ' + ISNULL(gen_mail_zip_code,'')) IS NULL THEN 'Missing City, State, and ZipCode' 
			ELSE (gen_mail_city + ', ' + gen_mail_state + ' ' + ISNULL(gen_mail_zip_code,'')) END) AS generator_mail_addr5,   
		Generator.generator_phone AS generator_phone , 
		CASE 
			WHEN isnull(ltrim(rtrim(Generator.generator_address_1)),'') = isnull(ltrim(rtrim(Generator.gen_mail_addr1)),'') and
				isnull(ltrim(rtrim(Generator.generator_address_2)),'') = isnull(ltrim(rtrim(Generator.gen_mail_addr2)),'') and
				isnull(ltrim(rtrim(Generator.generator_city)),'') = isnull(ltrim(rtrim(Generator.gen_mail_city)),'') and
				isnull(ltrim(rtrim(Generator.generator_state)),'') = isnull(ltrim(rtrim(Generator.gen_mail_state)),'') and
				isnull(ltrim(rtrim(Generator.generator_zip_code)),'') = isnull(ltrim(rtrim(Generator.gen_mail_zip_code)),'')
			THEN '' 
			ELSE Generator.generator_address_1
			END AS generator_site_addr1,   
		CASE
			WHEN isnull(ltrim(rtrim(Generator.generator_address_1)),'') = isnull(ltrim(rtrim(Generator.gen_mail_addr1)),'') and
				isnull(ltrim(rtrim(Generator.generator_address_2)),'') = isnull(ltrim(rtrim(Generator.gen_mail_addr2)),'') and
				isnull(ltrim(rtrim(Generator.generator_city)),'') = isnull(ltrim(rtrim(Generator.gen_mail_city)),'') and
				isnull(ltrim(rtrim(Generator.generator_state)),'') = isnull(ltrim(rtrim(Generator.gen_mail_state)),'') and
				isnull(ltrim(rtrim(Generator.generator_zip_code)),'') = isnull(ltrim(rtrim(Generator.gen_mail_zip_code)),'')
			THEN '' 
			ELSE Generator.generator_address_2
			END AS generator_site_addr2,   
		CASE
			WHEN isnull(ltrim(rtrim(Generator.generator_address_1)),'') = isnull(ltrim(rtrim(Generator.gen_mail_addr1)),'') and
				isnull(ltrim(rtrim(Generator.generator_address_2)),'') = isnull(ltrim(rtrim(Generator.gen_mail_addr2)),'') and
				isnull(ltrim(rtrim(Generator.generator_city)),'') = isnull(ltrim(rtrim(Generator.gen_mail_city)),'') and
				isnull(ltrim(rtrim(Generator.generator_state)),'') = isnull(ltrim(rtrim(Generator.gen_mail_state)),'') and
				isnull(ltrim(rtrim(Generator.generator_zip_code)),'') = isnull(ltrim(rtrim(Generator.gen_mail_zip_code)),'')
			THEN '' 
			ELSE Generator.generator_city
			END AS generator_site_city,
		CASE
			WHEN isnull(ltrim(rtrim(Generator.generator_address_1)),'') = isnull(ltrim(rtrim(Generator.gen_mail_addr1)),'') and
				isnull(ltrim(rtrim(Generator.generator_address_2)),'') = isnull(ltrim(rtrim(Generator.gen_mail_addr2)),'') and
				isnull(ltrim(rtrim(Generator.generator_city)),'') = isnull(ltrim(rtrim(Generator.gen_mail_city)),'') and
				isnull(ltrim(rtrim(Generator.generator_state)),'') = isnull(ltrim(rtrim(Generator.gen_mail_state)),'') and
				isnull(ltrim(rtrim(Generator.generator_zip_code)),'') = isnull(ltrim(rtrim(Generator.gen_mail_zip_code)),'')
			THEN '' 
			ELSE Generator.generator_state
			END AS generator_site_state,   
		CASE
			WHEN isnull(ltrim(rtrim(Generator.generator_address_1)),'') = isnull(ltrim(rtrim(Generator.gen_mail_addr1)),'') and
				isnull(ltrim(rtrim(Generator.generator_address_2)),'') = isnull(ltrim(rtrim(Generator.gen_mail_addr2)),'') and
				isnull(ltrim(rtrim(Generator.generator_city)),'') = isnull(ltrim(rtrim(Generator.gen_mail_city)),'') and
				isnull(ltrim(rtrim(Generator.generator_state)),'') = isnull(ltrim(rtrim(Generator.gen_mail_state)),'') and
				isnull(ltrim(rtrim(Generator.generator_zip_code)),'') = isnull(ltrim(rtrim(Generator.gen_mail_zip_code)),'')
			THEN '' 
			ELSE Generator.generator_zip_code
			END AS generator_site_zip_code,   
		Transporter.transporter_code AS transporter_code_1, 
		Transporter.transporter_name AS transporter_name_1, 
		Transporter.transporter_epa_id AS transporter_epa_id_1,   
		Transporter.transporter_phone AS transporter_phone_1,   
		CONVERT(varchar(40), '') AS transporter_code_2, 
		CONVERT(varchar(40), '') AS transporter_name_2, 
		CONVERT(varchar(40), '') AS transporter_epa_id_2,   
		CONVERT(varchar(40), '') AS transporter_phone_2, 
		TSDF.TSDF_code AS TSDF_code,   
		TSDF.TSDF_EPA_ID AS TSDF_EPA_ID,   
		TSDF.TSDF_name AS TSDF_name,   
		TSDF.TSDF_addr1 AS TSDF_addr1,   
		TSDF.TSDF_addr2 AS TSDF_addr2,   
		RTrim(CASE WHEN (TSDF.TSDF_city + ', ' + TSDF.TSDF_state + ' ' + ISNULL(TSDF.TSDF_zip_code,'')) IS NULL THEN 'Missing City, State, and ZipCode' 
			ELSE (TSDF.TSDF_city + ', ' + TSDF.TSDF_state + ' ' + ISNULL(TSDF.TSDF_zip_code,'')) END) AS TSDF_addr3,   
		TSDF.TSDF_phone AS TSDF_phone,
		COALESCE(nullif(ltrim(rtrim(isnull(Generator.emergency_phone_number, ''))), ''), ProfitCenter.emergency_contact_phone),
		CONVERT(varchar(30), '') AS emergency_contact_name,
		NULL AS discrepancy_description,
	        'F' AS discrepancy_qty_flag,
		'F' AS discrepancy_type_flag,
		'F' AS discrepancy_residue_flag,
		'F' AS discrepancy_part_reject_flag,
		'F' AS discrepancy_full_reject_flag,
		NULL AS manifest_ref_number,
	        'F' AS export_from_us_flag,
		'F' AS import_to_us_flag,
		NULL AS port_of_entry_exit,
		NULL AS date_leaving_us,
		NULL AS alt_facility_type,
		NULL AS alt_facility_code,
		NULL AS alt_facility_name,
		NULL AS alt_facility_addr1,
		NULL AS alt_facility_addr2,
		NULL AS alt_facility_phone,
		NULL AS alt_facility_epa_id ,
		NULL as dot_shipping_desc,
		Generator.emergency_contract_number AS emergency_contract_number,
		dbo.fn_get_approved_offeror(@ra_source, TSDFApproval.tsdf_approval_id, TSDFApproval.company_id, TSDFApproval.profit_ctr_id, 'F') as eq_approved_offerer_desc,
		dbo.fn_get_approved_offeror(@ra_source, TSDFApproval.tsdf_approval_id, TSDFApproval.company_id, TSDFApproval.profit_ctr_id, 'T') as eq_on_behalf_of_desc,
		--case when isnull(Customer.eq_approved_offerer_flag,'F') = 'T' and isnull(Customer.eq_offerer_effective_dt,'2000-01-01 00:00:00') < getdate()
		--	then Customer.eq_approved_offerer_desc else convert(varchar(255),null) end as eq_approved_offerer_desc,
		--case when isnull(Customer.eq_approved_offerer_flag,'F') = 'T' and isnull(Customer.eq_offerer_effective_dt,'2000-01-01 00:00:00') < getdate()
		--	then convert(varchar(80),'On Behalf of ' + Customer.cust_name) else convert(varchar(80),null) end as eq_on_behalf_of_desc,
		case when isnull(TSDFApproval.RCRA_haz_flag, 'F') = 'H' then 'T' else 'F' end as has_rcra_haz_waste_codes
	FROM TSDFApproval
	INNER JOIN Generator ON TSDFApproval.generator_id = Generator.generator_id
	INNER JOIN ProfitCenter ON  TSDFApproval.profit_ctr_ID = ProfitCenter.profit_ctr_ID
		AND TSDFApproval.company_id = ProfitCenter.company_id
	INNER JOIN TSDF ON TSDFApproval.TSDF_code = TSDF.TSDF_code
	RIGHT OUTER JOIN Transporter ON Transporter.transporter_code = CASE WHEN ProfitCenter.default_transporter IS NULL OR LEN(TRIM(ProfitCenter.default_transporter)) = 0
																		THEN 'BLANK' ELSE ProfitCenter.default_transporter END
	INNER JOIN Customer ON TSDFApproval.customer_id = Customer.customer_id
	WHERE 	TSDFApproval.company_id = @company_id
		AND TSDFApproval.profit_ctr_ID = @profit_center
--rb		AND TSDFApproval.tsdf_approval_status = 'A'
		AND TSDFApproval.TSDF_approval_id IN (SELECT source_id FROM #source_list)

	GOTO end_process
END

end_process:
	
SET NOCOUNT OFF

-- dump the manifest table
SELECT	control_id ,
	source ,
	source_id ,
	trip_sequence_id, -- rb
	source_code ,
	profit_center ,
	num_pages ,
	manifest ,
	manifest_state ,
	manifest_doc_num ,
	generator_id ,
	generator_epaid ,
	generator_name ,
	generator_addr1 ,
	generator_addr2 ,
	generator_addr3 ,
	generator_addr4 ,
	generator_addr5 ,
	generator_phone ,
	generator_site_1 ,
	generator_site_2 ,
	generator_city ,
	generator_state ,
	generator_zipcode ,
	transporter_code_1 ,
	transporter_name_1 ,
	transporter_epa_id_1 ,
	transporter_phone_1 ,   
	transporter_code_2 , 
	transporter_name_2 , 
	transporter_epa_id_2 ,   
	transporter_phone_2 , 
	TSDF_code ,   
	TSDF_EPA_ID ,   
	TSDF_name ,   
	TSDF_addr1 ,   
	TSDF_addr2 ,   
	TSDF_addr3 ,   
	TSDF_phone ,
	emergency_contact_phone ,
	emergency_contact_name,
	discrepancy_description ,
	discrepancy_qty_flag ,
	discrepancy_type_flag ,
	discrepancy_residue_flag ,
	discrepancy_part_reject_flag,
	discrepancy_full_reject_flag ,
	manifest_ref_number,
	export_from_us_flag ,
	import_to_us_flag,
	port_of_entry_exit,
	date_leaving_us,
	alt_facility_type,
	alt_facility_code,
	alt_facility_name,
	alt_facility_addr1,
	alt_facility_addr2,
	alt_facility_phone,
	alt_facility_epa_id ,
	dot_shipping_desc,
	emergency_contract_number,
	eq_approved_offerer_desc,
	eq_on_behalf_of_desc,
	has_rcra_haz_waste_codes
FROM #manifest

GO



GRANT EXECUTE
    ON OBJECT::[dbo].[sp_get_manifest_header_uniform] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_get_manifest_header_uniform] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_get_manifest_header_uniform] TO [EQAI]
    AS [dbo];

go

