use plt_export
go

--#region SP Header

alter proc sp_eqip_image_export (
	@source_list			varchar(20)		= NULL	-- 'I'nboundReceipt, 'O'utboundReceipt, 'W'orkOrder, In'V'oice			required
	
	, @customer_id_list		varchar(max)	= NULL	-- Customomer IDs (will include cust-gens), CSV							optional
	, @cust_type_list		varchar(max)	= NULL

	, @generator_id_list	varchar(max)	= NULL	-- Generator IDs														optional
	, @generator_sublocation_list	varchar(max)	= NULL	-- Generator Sublocations										optional
	, @site_type_list		varchar(max)	= NULL	-- Generator Site Types													optional
	, @generator_state_list	varchar(max)	= NULL	-- Generator State(s)													optional

	, @transporter_code_list	varchar(max)	= NULL	-- Transporter IDs													optional

	, @invoice_code_list	varchar(max)	= NULL	--																		optional
	, @facility_list		varchar(max)	= NULL	-- CO|PC company-profitcenter CSV value list '03|01, 2|1, 21|0', etc.	optional

	, @service_date_from	datetime		= NULL	-- service (pickup) date range begin									optional
	, @service_date_to		datetime		= NULL	-- service (pickup) date range end										optional
	, @receipt_date_from	datetime		= NULL	-- receipt.receipt_date or workorderheader.start_date range begin		optional
	, @receipt_date_to		datetime		= NULL	-- receipt.receipt_date or workorderheader.start_date range end			optional
	, @invoice_date_from	datetime		= NULL	-- billing.invoice_date range begin										optional
	, @invoice_date_to		datetime		= NULL	-- billing.invoice_date range end										optional

	, @haz_flag				char(1)			= 'A'	-- 'H'az, 'N'on-haz or 'A'll (determined by source waste codes)			optional

	, @document_type_list	varchar(max)	= NULL	-- scan.type_id (ScanDocumentType.type_id) list							optional
	, @name_option			varchar(40)		= 'M'	-- 'M'anifest Number (Scan.manifest)									REQUIRED
													-- 'D'ocument Name (Scan.document_name)
													-- 'S'can File (scan.scan_file)
													-- 'I'mage_id	(scan.image_id)
													-- 'W'al-mart: Generator Site Code + ServiceDate + Type
													-- 'K'roger: Generator Site Type + Site Code "-" Region Code + Service Date
													-- 'PickupDate_Manifest' (Receipt.PickupDate_Receipt.Manifest)
													-- 'Retail_Default' 'YYYYMMDD_USE_ManifestNo_GorF_Store#
	, @page_option			char(1)			= 'C'	-- 'C'ombine multiple pages into a single output file					REQUIRED
													-- 'S'eparate output files according to page number
	, @confirm_option		char(1)			= 'N'	-- 'Y'/'N' option - used to force dump confirmation						REQUIRED
	, @export_id			int				= NULL	-- If confirming a previous run, need to id that run here.				optional
	, @user_code			varchar(10)				-- EQIP user_code for permission check									REQUIRED
	, @permission_id		int						-- EQIP permission_id for permission check								REQUIRED
	, @debug				int				= 0		-- Debug option															optional
)
as


--#region Header Comments

/* *********************************************************************************************************
sp_eqip_image_export

sp_helptext sp_eqip_image_export

Creates an image export job on the EQIP web site.
	Populates a plt_export.ImageExportHeader & Detail table with image_id, filename, page_number requirements for an image export
	If @confirm_option = 'N' (default) the count of files to export is returned, waiting for user to re-submit request
		with the 'Y' @confirm_option value (and @export_id identifier) to actually run the export.
		This is to avoid running in-advertently large extracts, which would be bad for disk use, performance, etc.
	Then calls xp_eq_os_image_export to dump the files to disk, zip, send.
	Unconfirmed runs older than 7 days will be deleted from the Detail table.

	-- Original verbal design with LT...
		Select options:
			Inbound Receipt OR Outbound Receipt OR Workorder (or all)
			Facility (optional)
			Receipt Date Range (optional)
			Invoice Date Range (optional)
			Service Date Range (optional)
			Only Haz, or All
			Customer (optional - include all generators OF this customer)
			Generator (optional)
			Transporter (optional)

			Naming Option (image id, Manifest #)
			Page option (separate pages, combine pages)

		Only select Waste Accepted Active scans for Manifests
		...
		Run this bigger nasty query into a table
		Show the user the count of images/files that they'll get from it
		If they proceed, run the export.

Big Assumptions:
	if any *_date_from is given, its matching *_date_to value is also given (and vice versa)
	
History:
	2014-01-20	JPB	Created
	2015-12-14	JPB	Added site_type_list input
						Fixed work order source export bug
						added kroger naming output
	2016-06-27  JPB	Addressed a bug in non-manifest doc names where there are multiple manifests for 1 receipt in #tran
						could create duplicated images in output.
	2016-08-23	JPB	Converted Naming options to a Table in plt_export..ImageExportNameOptions to handle adding more as needed with less re-deploy.
	2019-05-31	JPB	Updated naming logic for Kroger
	2022-02-22  JPB heeey, 2s-day.  Rewrite for speed, added custom_build/export_sp options in Names
							
Example:

select generator_site_type_id from plt_ai..GeneratorSiteType where generator_site_type in (
select generator_site_type from plt_ai..CustomerGeneratorSiteType where customer_id = 15940
)


--   customer_id_list    : 12113   generator_id_list   :    transporter_id_list :    
--	 source_list         : I,W     facility_list       :    service_date_from   : 2013-12-01 00:00:00.000
--   service_date_to     : 2013-12-31 23:59:59.133   receipt_date_from   : 1900-01-01 00:00:00.000
--   receipt_date_to     : 2200-01-01 23:59:59.133   invoice_date_from   : 1900-01-01 00:00:00.000   
--   invoice_date_to     : 2200-01-01 23:59:59.133   haz_flag            :     
--   document_type_list  : 1,4,28   name_option         : M   page_option         : C   user_code           : JONATHAN   permission_id       : 180  

--  customer_id_list      : 10673   service_date_from     : 2016-05-01 00:00:00.000   service_date_to       : 2016-05-10 23:59:59.133   
--  document_type_list    : 80   name_option           : D   page_option           : S   user_code             : JONATHAN   permission_id         : 299  

select top 1000 * from plt_image..scan where status = 'A' and type_id= 1 and customer_id is not null and generator_id is not null order by date_added desc
select generator_state from plt_ai..generator where generator_id in (132701, 132787, 132867, 132894, 134332, 137719, 140263, 140264, 140274, 140582, 140583, 155511)


	plt_export..sp_eqip_image_export 
		@customer_id_list = '10673'				--		varchar(max)	= NULL	-- Customomer IDs (will include cust-gens), CSV							optional
		-- , @generator_id_list					--		varchar(max)	= NULL	-- Generator IDs														optional
		-- @site_type_list = '770, 771, 772, 773, 774, 775, 776, 782, 783, 784'						--		varchar(max)	= NULL	-- Generator Site Types													optional
		-- , @generator_state_list = ''
		-- ,@transporter_code_list = 'CSX'				--		varchar(max)	= NULL	-- Transporter IDs														optional
		-- , @source_list = 'I'					--		varchar(20)		= NULL	-- Receipt 'I'nbound or 'O'utbound, 'W'ork Order - any CSV combo.		optional
		-- , @facility_list = '2|0'						--		varchar(max)	= NULL	-- CO|PC company-profitcenter CSV value list '03|01, 2|1, 21|0', etc.	optional
		, @service_date_from = '1/1/2022'		--		datetime		= NULL	-- service (pickup) date range begin									optional
		, @service_date_to = '1/31/2022'		--		datetime		= NULL	-- service (pickup) date range end										optional
		-- , @receipt_date_from = '1/1/2022'					--		datetime		= NULL	-- receipt.receipt_date or workorderheader.start_date range begin		optional
		-- , @receipt_date_to = '1/31/2022'					--		datetime		= NULL	-- receipt.receipt_date or workorderheader.start_date range end			optional
		-- , @invoice_date_from = '1/1/2022'					--		datetime		= NULL	-- billing.invoice_date range begin										optional
		-- , @invoice_date_to = '6/21/2022'					--		datetime		= NULL	-- billing.invoice_date range end										optional
		, @haz_flag = 'H'							--		char(1)			= 'A'	-- 'H'az, 'N'on-haz or 'A'll (determined by source waste codes)			optional
		, @document_type_list = '1,2'		--		varchar(max)	= NULL	-- scan.type_id (ScanDocumentType.type_id) list							optional
			-- SELECT * FROM plt_image..ScanDocumentType where document_type like '%man%'
			-- select * from plt_export..ImageExportNameOptions
		, @name_option = 'Wal-Mart + Metadata'					--		char(1)			= 'M'	-- 'M'anifest Number (Scan.manifest)									REQUIRED
														-- 'D'ocument Name (Scan.document_name)
														-- 'S'can File (scan.scan_file)
														-- 'I'mage_id	(scan.image_id)
		, @page_option = 'C'					--		char(1)			= 'C'	-- 'C'ombine multiple pages into a single output file					REQUIRED
														-- 'S'eparate output files according to page number
		, @confirm_option = 'N'					--		char(1)			= 'N'	-- 'Y'/'N' option - used to force dump confirmation						REQUIRED
		, @export_id = NULL						--		int				= NULL	-- If confirming a previous run, need to id that run here.				optional
		, @user_code = 'JONATHAN'				--		varchar(10)				-- EQIP user_code for permission check									REQUIRED
		, @permission_id = 299					--		int						-- EQIP permission_id for permission check								REQUIRED
			-- SELECT * FROM plt_ai..AccessPermission where permission_description like '%wal%'
			-- select distinct customer_id from plt_ai..SecuredCustomer sc (nolock) where sc.user_code = 'JONATHAN' and sc.permission_id = 180
		, @debug = 0


compare timing for these results to time of result sin SQLQuery40 window nextdoor.

5563	36
-- 7m, 31s


SELECT  s.* FROM    plt_ai..receipt r
join plt_image..scan s on r.receipt_id = s.receipt_id and r.company_id = s.company_id and r.profit_ctr_id = s.profit_ctr_id and s.document_source = 'receipt'
and s.status = 'A'
join plt_image..scanimage i on s.image_id = i.image_id
where r.customer_id = 10673 and r.receipt_date > '1/1/2022'
-- has datas.  Should appear.

-- customer 14231, invoice 1/1 - 6/1/2018		
-- 1745 / USA-CA: 1067   USA-AZ: 38   USA-NV: 126

	sp_eqip_image_export 
		@confirm_option = 'Y'					--		char(1)			= 'N'	-- 'Y'/'N' option - used to force dump confirmation						REQUIRED
		, @export_id = 1949						--		int				= NULL	-- If confirming a previous run, need to id that run here.				optional
		, @user_code = 'JONATHAN'				--		varchar(10)				-- EQIP user_code for permission check									REQUIRED
		, @permission_id = 299					--		int						-- EQIP permission_id for permission check								REQUIRED
		, @debug = 1


Exec msdb.dbo.sysmail_help_configure_sp

SELECT  * FROM    plt_export..jpb_test WHERE tran_filename is not null
SELECT  * FROM    plt_export..EQIPImageExportHeader WHERE  export_id = 1949
SELECT  * FROM    plt_export..EQIPImageExportDetail WHERE  export_id = 1949 ORDER BY  filename
SELECT  * FROM    plt_export..EQIPImageExportWalmartMeta


		select
			'"' + [manifest number] + '"' as [sep=,
Manifest Number], '"' + [service type] + '"' as [Service Type]
			 , '"' + [store number] + '"' as [Store Number]
			 , '"' + [city] + '"' as [City]
			 , '"' + [state] + '"' as [State]
			 , '"' + [zip code] + '"' as [Zip Code]
			 , '"' + [service date] + '"' as [Service Date]
			 , '"' + [service provider] + '"' as  [Service Provider]
		from plt_export..EQIPImageExportWalmartMeta
		WHERE export_id = 1946
		order by row_id


SELECT * FROM plt_ai..customer where cust_name like 'PPG%'
SELECT distinct customer_id FROM plt_image..scan where customer_id in (SELECT customer_id FROM plt_ai..customer where cust_name like 'PPG%' and customer_id <= 90000000)

select export_id, image_id, filename, page_number from plt_export..EqipImageExportDetail where export_id = 342
	and image_id in (select image_id from plt_image..scanimage where datalength(image_blob) > 0)

select * from plt_export..EqipImageExportMeta where export_id = 348


SELECT *  from plt_export..EqipImageExportHeader where export_flag = 'Y'

SELECT * FROM plt_image..scan where image_id = 7853183
SELECT start_date, * FROM plt_ai..workorderheader where workorder_id = 21095000 and company_id = 14
SELECT * FROM plt_ai..workorderstop where workorder_id = 21095000 and company_id = 14

SELECT distinct h.export_id
, ltrim(rtrim(replace(replace(replace(replace(replace(replace(replace(replace(replace(
replace(replace(replace(replace(replace(replace(
replace(replace(replace(replace(replace(replace(replace(replace(replace(replace(replace(replace(replace(replace(
replace(h.criteria, char(10) + char(13), ''), '	', ' ')
, 'customer_id_list', ''), 'generator_id_list', ''), 'invoice_date_from', ''), 'service_date_from', '')
, 'service_date_to', ''), 'permission_id', ''), 'invoice_date_to', ''), 'haz_flag', '')
, 'document_type_list', ''), 'name_option', ''), 'page_option', ''), 'user_code', '')
, 'transporter_id_list', '')
, 'receipt_date_to', ' - ')
, '  ', ' '), '  ', ' '), '  ', ' ')
, '00:00:00.000', '')
, '23:59:59.133', '')
, '  : :  : A : 1,4  : M  : C  : JONATHAN : 180', '')
, '  ', ' ')
, 'source_list', 'Source')
, 'facility_list', 'Company')
, 'receipt_date_from', 'Dates')
, ': : : ', '')
, ' Company', ', Company')
, ' : :', ',')
, ' - : ', ' - ')
))
, d.filename
FROM plt_export..EqipImageExportDetail d inner join plt_export..EqipImageExportHeader h on d.export_id = h.export_id 
where h.export_flag = 'Y'
and export_id = 3
order by h.export_id, d.filename

     :    :     :    source_list         : I   facility_list       : 2|0   service_date_from   :    service_date_to     :    receipt_date_from   : 2014-01-01 00:00:00.000   receipt_date_to     : 2014-01-31 23:59:59.133   invoice_date_from   :    invoic

e_date_to     :    haz_flag            : A   document_type_list  : 1,4   name_option         : M   page_option         : C   user_code           : JONATHAN   permission_id       : 180  
     
-- ' customer_id_list    :    generator_id_list   :    transporter_id_list :    source_list         : I   facility_list       : 2|0   service_date_from   :    service_date_to     :    receipt_date_from   : 2014-01-01 00:00:00.000   receipt_date_to     : 
2

014-01-31 23:59:59.133   invoice_date_from   :    invoice_date_to     :    haz_flag            : A   document_type_list  : 1,4   name_option         : M   page_option         : C   user_code           : JONATHAN   permission_id       : 180  '

filename FROM plt_export..EqipImageExportDetail d inner join plt_export..EqipImageExportHeader h on d.export_id = h.export_id where h.export_flag = 'Y'
update plt_export..EqipImageExportHeader set export_flag = 'Y' where export_id in (20, 19, 17, 13, 11, 9, 7, 5, 3)

select top 20 * from plt_image..scanimage where datalength(image_blob) > 0 order by image_id desc
SELECT * FROM plt_image..scan where image_id = 6617230
SELECT * FROM plt_image..ScanDocumentType

SELECT TOP 10 * FROM plt_ai..message order by date_added desc 

Supporting Tables:
	-- Note: u.s.e. and g.r.a.n.t. are tweaked in this script because the SQL Deployer scans for
	--		those words and if found in a script, assumes they apply to the script in which they
	--		are found... and that's not true in this case.

	
	u.s.e. PLT_Export
	G O
	IF EXISTS (select 1 from sysobjects where name = 'EqipImageExportHeader')
		DROP TABLE EqipImageExportHeader
	G O
	
	CREATE TABLE EqipImageExportHeader (
		export_id			int		not null		identity(1,1)
		, added_by			varchar(10)	not null
		, date_added		datetime not null default getdate()
		, criteria			varchar(max)
		, export_flag		char(1)	not null default 'N'
		, image_count		int not null default 0
		, file_count		int not null default 0
		, report_log_id		int
		, export_start_date	datetime
		, export_end_date	datetime
	)
	G O

	grant INSERT, UPDATE, SELECT on EqipImageExportHeader to EQAI, EQWEB
	G O

	IF EXISTS (select 1 from sysobjects where name = 'EqipImageExportDetail')
		DROP TABLE EqipImageExportDetail
	G O
	
	CREATE TABLE EqipImageExportDetail (
		export_id			int				not null
		, image_id			int				not null
		, filename			varchar(255)	not null
		, page_number		int				not null
	)
	G O
	grant INSERT, UPDATE, DELETE, SELECT on EqipImageExportDetail to EQAI, EQWEB
	G O


SELECT * FROM 	EqipImageExportHeader order by export_id desc

********************************************************************************************************* */


--#endregion
--#endregion

set nocount on
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

--#region Set up Naming & related / setup variables
	declare @name_requires_manifest char(1) = 'F'
		, @name_requires_metadata char(1) = 'F'
		, @name_sql varchar(max) = 'convert(varchar(20), s.image_id)'
		, @name_custom_build_sp varchar(255) = null
		, @name_custom_export_sp varchar(255) = null
		, @crlf varchar(2) = char(10) + char(13)	
		, @run_timer datetime = getdate()
		, @operation_timer datetime = getdate()
		, @oldest_date_allowed datetime = dateadd(yy, -5, getdate())
		, @maxlenr varchar(20), @maxlenri int
		, @sql varchar(max)
		, @pickedCustomers bit = 0
		, @pickedGenerators bit = 0
		

--#endregion

--#region Debuggery
/*
declare
	@source_list			varchar(20)		= NULL	-- 'I'nboundReceipt, 'O'utboundReceipt, 'W'orkOrder, In'V'oice			required
	
	, @customer_id_list		varchar(max)	= NULL	-- Customomer IDs (will include cust-gens), CSV							optional
	, @cust_type_list		varchar(max)	= NULL

	, @generator_id_list	varchar(max)	= NULL	-- Generator IDs														optional
	, @generator_sublocation_list	varchar(max)	= NULL	-- Generator Sublocations										optional
	, @site_type_list		varchar(max)	= NULL	-- Generator Site Types													optional
	, @generator_state_list	varchar(max)	= NULL	-- Generator State(s)													optional

	, @transporter_code_list	varchar(max)	= NULL	-- Transporter IDs													optional

	, @invoice_code_list	varchar(max)	= NULL	--																		optional
	, @facility_list		varchar(max)	= NULL	-- CO|PC company-profitcenter CSV value list '03|01, 2|1, 21|0', etc.	optional

	, @service_date_from	datetime		= NULL	-- service (pickup) date range begin									optional
	, @service_date_to		datetime		= NULL	-- service (pickup) date range end										optional
	, @receipt_date_from	datetime		= NULL	-- receipt.receipt_date or workorderheader.start_date range begin		optional
	, @receipt_date_to		datetime		= NULL	-- receipt.receipt_date or workorderheader.start_date range end			optional
	, @invoice_date_from	datetime		= NULL	-- billing.invoice_date range begin										optional
	, @invoice_date_to		datetime		= NULL	-- billing.invoice_date range end										optional

	, @haz_flag				char(1)			= 'A'	-- 'H'az, 'N'on-haz or 'A'll (determined by source waste codes)			optional

	, @document_type_list	varchar(max)	= NULL	-- scan.type_id (ScanDocumentType.type_id) list							optional
	, @name_option			varchar(40)		= 'M'	-- 'M'anifest Number (Scan.manifest)									REQUIRED
													-- 'D'ocument Name (Scan.document_name)
													-- 'S'can File (scan.scan_file)
													-- 'I'mage_id	(scan.image_id)
													-- 'W'al-mart: Generator Site Code + ServiceDate + Type
													-- 'K'roger: Generator Site Type + Site Code "-" Region Code + Service Date
													-- 'PickupDate_Manifest' (Receipt.PickupDate_Receipt.Manifest)
													-- 'Retail_Default' 'YYYYMMDD_USE_ManifestNo_GorF_Store#
	, @page_option			char(1)			= 'C'	-- 'C'ombine multiple pages into a single output file					REQUIRED
													-- 'S'eparate output files according to page number
	, @confirm_option		char(1)			= 'N'	-- 'Y'/'N' option - used to force dump confirmation						REQUIRED
	, @export_id			int				= NULL	-- If confirming a previous run, need to id that run here.				optional
	, @user_code			varchar(10)				-- EQIP user_code for permission check									REQUIRED
	, @permission_id		int						-- EQIP permission_id for permission check								REQUIRED
	, @debug				int				= 0		-- Debug option															optional

-- SELECT  * FROM    plt_ai..invoiceheader WHERE customer_id = 15622 ORDER BY invoice_date desc


--SELECT  * FROM    ImageExportNameOptions WHERE name = 'Wal-Mart + Metadata'
--sp_helptext sp_image_export_walmart_2022_build
--SELECT  * FROM     plt_export..EQIPImageExportWalmartMeta

--SELECT  * FROM    plt_ai..customer WHERE  cust_name like 'amazon%'
--select 
--	@source_list = 'I'
--	, @transporter_code_list = '10673'
--	, @cust_type_list = ''
--	, @facility_list = 'all'
--	, @user_code = 'JONATHAN'
--	, @permission_id = 299
--	, @debug = 1


	select
		@source_list = 'V'
		, @invoice_code_list = '773140'
		-- , @customer_id_list = ''				--		varchar(max)	= NULL	-- Customomer IDs (will include cust-gens), CSV							optional
		-- , @transporter_code_list = 'CSX'
		--, @generator_sublocation_list = '12'
		-- , @receipt_date_from	= '11/1/2018'	-- service (pickup) date range begin									optional
		-- , @receipt_date_to		= '11/8/2018'	-- service (pickup) date range end										optional
		-- , @haz_flag = 'H'							--		char(1)			= 'A'	-- 'H'az, 'N'on-haz or 'A'll (determined by source waste codes)			optional
		-- , @document_type_list = '1'		--		varchar(max)	= NULL	-- scan.type_id (ScanDocumentType.type_id) list							optional
			-- SELECT * FROM plt_image..ScanDocumentType where document_type like '%man%'
			-- select * from plt_export..ImageExportNameOptions
		, @name_option = 'Image_ID'					--		char(1)			= 'M'	-- 'M'anifest Number (Scan.manifest)									REQUIRED
														-- 'D'ocument Name (Scan.document_name)
														-- 'S'can File (scan.scan_file)
														-- 'I'mage_id	(scan.image_id)
		, @page_option = 'C'					--		char(1)			= 'C'	-- 'C'ombine multiple pages into a single output file					REQUIRED
														-- 'S'eparate output files according to page number
		, @confirm_option = 'N'					--		char(1)			= 'N'	-- 'Y'/'N' option - used to force dump confirmation						REQUIRED
		, @export_id = NULL						--		int				= NULL	-- If confirming a previous run, need to id that run here.				optional
		, @user_code = 'JONATHAN'				--		varchar(10)				-- EQIP user_code for permission check									REQUIRED
		, @permission_id = 299					--		int						-- EQIP permission_id for permission check								REQUIRED
			-- SELECT * FROM plt_ai..AccessPermission where permission_description like '%wal%'
			-- select distinct customer_id from plt_ai..SecuredCustomer sc (nolock) where sc.user_code = 'JONATHAN' and sc.permission_id = 180
		, @debug = 1

*/
--#endregion

--#region pre-drop later temp tables

	drop table if exists #customer
	drop table if exists #customertype
	drop table if exists #generator
	drop table if exists #work
	drop table if exists #build
	drop table if exists #build2
	drop table if exists #tran
	drop table if exists #generatorsublocation 
	drop table if exists #GeneratorSiteType 
	drop table if exists #GeneratorState 
	drop table if exists #transporter 
	drop table if exists #source 
	drop table if exists #facility 
	drop table if exists #invoice
	drop table if exists #ScanDocumentType 
	drop table if exists #Secured_Customer
	drop table if exists #Secured_Generator
	drop table if exists #Secured_ProfitCenter 
	drop table if exists #DocTypeOrder 
	drop table if exists #ImageExportHeader 
	drop table if exists #ImageExportDetail 
	drop table if exists #ImageExportMeta 
	drop table if exists #imagesource

--#endregion

--#region Fix Date Inputs

	if datepart(yyyy, isnull(@service_date_to, '1/1/1900')) = 1900 and datepart(yyyy, isnull(@service_date_from, '1/1/1900')) = 1900 begin
		set @service_date_from = null
		set @service_date_to = null
	end
	if datepart(yyyy, isnull(@receipt_date_to, '1/1/1900')) = 1900 and datepart(yyyy, isnull(@receipt_date_from, '1/1/1900')) = 1900 begin
		set @receipt_date_from = null
		set @receipt_date_to = null
	end
	if datepart(yyyy, isnull(@invoice_date_to, '1/1/1900')) = 1900 and datepart(yyyy, isnull(@invoice_date_from, '1/1/1900')) = 1900 begin
		set @invoice_date_from = null
		set @invoice_date_to = null
	end

	-- Fix Ending Date datetime values
	if isnull(@service_date_to, '1/1/1900') > '1/1/1901' and datepart(hh, @service_date_to) = 0 set @service_date_to = @service_date_to + 0.99999
	if isnull(@receipt_date_to, '1/1/1900') > '1/1/1901' and datepart(hh, @receipt_date_to) = 0 set @receipt_date_to = @receipt_date_to + 0.99999
	if isnull(@invoice_date_to, '1/1/1900') > '1/1/1901' and datepart(hh, @invoice_date_to) = 0 set @invoice_date_to = @invoice_date_to + 0.99999


--#endregion

--#region Confirming an already-run export (that hasn't been exported before)
	
-----------------------------------	
-- First, handle the simplest case: Confirming an already-run export (that hasn't been exported before)
-----------------------------------

	if isnull(@export_id, -1) <> -1 and @confirm_option = 'Y' begin
		if @debug > 0 select 'Export branch reached'
		if exists (
			select 1 
			from plt_export..EqipImageExportHeader h (nolock)
			inner join plt_export..EqipImageExportDetail d (nolock) on h.export_id = d.export_id
			where h.export_id = @export_id
			and h.export_start_date is null
		)	begin
		
				if @debug > 0 select 'Valid export found'



				-- Check to see if this export was for a naming option that has a custom export sp
				-- just for test:  update ImageExportNameOptions set custom_export_sp = 'sp_blablabla' where name = 'Retail Default (with metadata)'
				-- reset test:  update ImageExportNameOptions set custom_export_sp = null where name = 'Retail Default (with metadata)'
				-- declare @export_id int = 1831, @crlf varchar(2) = char(10) + char(13)
				declare @export_sp_name_option varchar(40), @export_sp varchar(255) = '', @export_sql varchar(max)
				SELECT  @export_sp_name_option = ltrim(rtrim(replace(replace(substring(criteria, patindex('%name_option%', criteria), patindex('%page_option%', criteria)-patindex('%name_option%', criteria)-1), 'name_option           :', ''),@crlf,'')))
				FROM    EqipImageExportHeader 
				WHERE export_id = @export_id

				select @export_sp = custom_export_sp 
				from ImageExportNameOptions n
				WHERE name like '%' + @export_sp_name_option + '%'
				and isnull(custom_export_sp, '') <> ''
				if @@rowcount = 1 begin
					-- select @export_sp as todo
					select @export_sql = @export_sp + ' @export_id = ' + convert(varchar(20), @export_id)
					-- select @export_sql
					begin try
						exec(@export_sql)
					end try
					begin catch
						-- do nothing.
						print 'exec ' + @export_sql + ' failed'
					end catch
				end

				declare 
					  @report_id int
					, @report_log_id int
					, @criteria_id int

				select top 1 @report_id = report_id from plt_ai..Report (nolock) where report_name = 'ImageExportConsole.exe' and report_status = 'A'
				select top 1 @criteria_id = report_criteria_id FROM plt_ai..ReportXReportCriteria (nolock) where report_id = @report_id

				EXEC @report_log_id = plt_ai..sp_sequence_next 'ReportLog.report_log_ID', 1

				exec plt_ai..sp_ReportLog_add @report_log_id, @report_id, @user_code
				exec plt_ai..sp_ReportLogParameter_add @report_log_id, @criteria_id, @export_id
				
				if exists (Select 1 from plt_export..EqipImageExportMeta m (nolock)
				where m.export_id = @export_id) begin

					EXEC @report_log_id = plt_ai..sp_sequence_next 'ReportLog.report_log_ID', 1
					select top 1 @report_id = report_id from plt_ai..Report (nolock) where report_name = 'Image Export Meta File' and report_status = 'A'


					exec plt_ai..sp_ReportLog_add @report_log_id, @report_id, @user_code
					exec plt_ai..sp_ReportLogParameter_add @report_log_id, 68, @export_id
					exec plt_ai..sp_ReportLogParameter_add @report_log_id, 82, @user_code
					exec plt_ai..sp_ReportLogParameter_add @report_log_id, 83, @permission_id
					exec plt_ai..sp_ReportLogParameter_add @report_log_id, 81, @report_log_id
					update plt_ai..ReportLog set date_finished = null where report_log_id = @report_log_id
				end

				if @debug > 0 select 'End of export'
			

			end
			-- All done:
			
			if @debug > 0 select datediff(ms, @operation_timer, getdate()) as operation_elapsed_ms, datediff(ms, @run_timer, getdate()) as run_elaspsed_ms, 'End of output calls' as marker
			select @operation_timer = getdate()
			return
	end


--#endregion			

--#region Housekeeping
-----------------------------------	
-- If you're still here, let's do some housekeeping:
-----------------------------------

	-- Keep the header info, but delete detail records older than 7 days that haven't been exported.
	delete from plt_export..EqipImageExportDetail where export_id in (
		select export_id from plt_export..EqipImageExportHeader (nolock) where date_added < getdate() -7 and export_flag NOT IN ('Y', 'I')
	)

	if @debug > 0 select datediff(ms, @operation_timer, getdate()) as operation_elapsed_ms, datediff(ms, @run_timer, getdate()) as run_elaspsed_ms, 'End of housekeeping' as marker
	select @operation_timer = getdate()

--#endregion

--#region Parse Inputs
-----------------------------------	
-- Parse/Fix inputs preparing for a run...
-----------------------------------

-- Parse Source List
	declare @source table (source char(1))
	IF isnull(@source_list, '') <> ''
		insert @source select row from dbo.fn_splitXsvText(',', 1, @source_list) where row is not null
	ELSE
		insert @source select 'O' union select 'I' union select 'W' union select 'V'
	-- select * from @source

-- Parse Customer ID List
	declare @customer table (customer_id int)
	insert @customer select convert(int, row) from dbo.fn_splitXsvText(',', 1, @customer_id_list) where row is not null
	-- select * from @customer

-- Parse Customer Type List
	declare @customertype table (customer_type varchar(20))
	insert @customertype select row from dbo.fn_splitXsvText(',', 1, @cust_type_list) where row is not null
	-- select * from @customertype

-- Parse Generator ID List
	declare @generator table (generator_id int)
	insert @generator select convert(int, row) from dbo.fn_splitXsvText(',', 1, @generator_id_list) where row is not null
	-- select * from @generator

-- Parse Generator Sublocation List
	declare @generatorsublocation table (generator_sublocation_id int)
	insert @generatorsublocation select convert(int, row) from dbo.fn_splitXsvText(',', 1, @generator_sublocation_list) where row is not null
	-- select * from @generator	create table @generator (generator_id int)

-- Parse Generator Site Type List
	declare @generatorSiteType table (generator_site_type_id int)
	insert @generatorSiteType select convert(int, row) from dbo.fn_splitXsvText(',', 1, @site_type_list) where row is not null
	-- select * from @generatorSiteType

-- Parse Generator State List
	declare @generatorState table (combination varchar(6), generator_country varchar(3), generator_state varchar(2))
	-- declare @generator_state_list varchar(max) = 'USA-MI, USA-OH, CAN-NL, MEX-NL'
	insert @generatorState (combination) select row from dbo.fn_splitXsvText(',', 1, @generator_state_list) where row is not null
	if @@rowcount > 0 begin
		update @generatorState set generator_country = left(combination, charindex('-', combination)-1)
		update @generatorState set generator_state = replace(combination, generator_country+'-', '')
	end
	-- select * from @generatorState

-- Parse Transporter Code List
	declare @transporter table (transporter_code varchar(15))
	insert @transporter select row from dbo.fn_splitXsvText(',', 1, @transporter_code_list) where isnull(row, '')<> ''
	-- select * from @transporter

-- Parse Invoice Code List
	declare @invoice table (invoice_code varchar(16))
	insert @invoice select row from dbo.fn_splitXsvText(',', 1, @invoice_code_list) where isnull(row, '')<> ''
	-- select * from @invoice
	
-- Parse Facility List
	declare @facility table (copc varchar(20), company_id int, profit_ctr_id int)
	IF isnull(@facility_list, '') <> '' and @facility_list <> 'All'
		INSERT @facility (copc, company_id, profit_ctr_id)
		SELECT row, company_id, profit_ctr_id
		FROM dbo.fn_SplitXsvText(',', 1, @facility_list)
		INNER JOIN plt_ai..ProfitCenter (nolock) on row = convert(varchar(5), company_id) + '|' + convert(varchar(5), profit_ctr_id) and status = 'A'
		where row is not null
	ELSE
		insert @facility (copc, company_id, profit_ctr_id)
		SELECT NULL, company_id, profit_ctr_id from plt_ai..ProfitCenter (nolock) where status = 'A'
	-- select * from @facility

-- Parse Document Type List
	create table #ScanDocumentType (scan_type_id int)
	insert #ScanDocumentType select convert(int, row) from dbo.fn_SplitXsvText(',', 1, @document_type_list) where row is not null
	
	if (select count(*) from #ScanDocumentType) = 0
		insert #ScanDocumentType select distinct type_id from plt_image..ScanDocumentType
	
	-- SELECT * FROM #ScanDocumentType

--#endregion

--#region Set naming variable values
	select @name_sql = name_sql,
		@name_requires_manifest = isnull(requires_manifest, 'F'),
		@name_requires_metadata = isnull(requires_metadata, 'F'),
		@name_custom_build_sp = custom_build_sp,
		@name_custom_export_sp = custom_export_sp
	from ImageExportNameOptions (nolock)
	where name = @name_option			

	if @debug > 0 select datediff(ms, @operation_timer, getdate()) as operation_elapsed_ms, datediff(ms, @run_timer, getdate()) as run_elaspsed_ms, 'End of input parsing' as marker
	select @operation_timer = getdate()

--#endregion

--#region Set up HUB Access Tables
-----------------------------------	
-- Set up EQIP Access Tables
-----------------------------------

	declare @SecuredCustomerCount int = 0
		, @SecuredGeneratorCount int = 0
		
-- Secured Customer
	select distinct sc.customer_id, c.customer_type 
	into #Secured_Customer
	from plt_ai..SecuredCustomer sc (nolock) 
	join plt_ai..customer c on sc.customer_id = c.customer_id
	where sc.user_code = @user_code
	and sc.permission_id = @permission_id
	set @SecuredCustomerCount = @@rowcount
	
	if (select count(*) from @Customer) > 0 
		delete from #Secured_Customer where customer_id not in (select customer_id from @customer)
	
	if (select count(*) from @CustomerType) > 0
		delete from #Secured_Customer 
		WHERE isnull(customer_type, '') not in (select customer_type from #customertype)

	if (select count(*) from #Secured_Customer) < @SecuredCustomerCount set @pickedCustomers = 1
		
-- Secured Generator		
	select sg.generator_id, g.site_type, gst.generator_site_type_id, isnull(g.generator_country, 'USA') generator_country, g.generator_state
	into #Secured_Generator
	from plt_ai..SecuredGenerator sg (nolock) 
	join plt_ai..generator g on sg.generator_id = g.generator_id
	left join plt_ai..GeneratorSiteType gst (nolock) on g.site_type = gst.generator_site_type
	where sg.user_code = @user_code
	and sg.permission_id = @permission_id
	union
	select cg.generator_id, g.site_type, gst.generator_site_type_id, isnull(g.generator_country, 'USA') generator_country, g.generator_state
	from plt_ai..CustomerGenerator cg (nolock)
	join #Secured_Customer sc on cg.customer_id = sc.customer_id
	join plt_ai..generator g on cg.generator_id = g.generator_id
	left join plt_ai..GeneratorSiteType gst (nolock) on g.site_type = gst.generator_site_type

	
	if @pickedCustomers = 1
		delete from #Secured_Generator where generator_id not in (
			select generator_id from plt_ai..CustomerGenerator cg join #Secured_Customer sc on sc.customer_id = cg.customer_id
		)

	select @SecuredGeneratorCount = count(*) from #Secured_Generator

	if (select count(*) from @generator) > 0 
		delete from #Secured_Generator where generator_id not in (select generator_id from @generator)

	if (select count(*) from @GeneratorSiteType) > 0 
		delete from #Secured_Generator 
		WHERE isnull(generator_site_type_id,0) not in (select generator_site_type_id from @GeneratorSiteType )

	if (select count(*) from @GeneratorState) > 0 
		delete from #Secured_Generator 
		from #Secured_Generator sg
		left join @GeneratorState gstate on sg.generator_country = gstate.generator_country 
			and sg.generator_state = gstate.generator_state 
		where gstate.generator_state is null

	if (select count(*) from #Secured_Generator) < @SecuredGeneratorCount set @pickedGenerators = 1
	
-- Secured ProfitCenter
	create table #Secured_ProfitCenter (company_id int, profit_ctr_id int)
	IF isnull(@facility_list, '') <> '' and @facility_list <> 'All'
		insert #Secured_ProfitCenter
		select distinct secured_copc.company_id, secured_copc.profit_ctr_id
		FROM plt_ai..SecuredProfitCenter secured_copc (nolock)
		INNER JOIN @facility f on f.company_id = secured_copc.company_id and f.profit_ctr_id = secured_copc.profit_ctr_id
		where secured_copc.user_code = @user_code
		and secured_copc.permission_id = @permission_id
	ELSE
		insert #Secured_ProfitCenter
		select distinct secured_copc.company_id, secured_copc.profit_ctr_id
		FROM plt_ai..SecuredProfitCenter secured_copc (nolock)
		where secured_copc.user_code = @user_code
		and secured_copc.permission_id = @permission_id

	if @debug > 0 select datediff(ms, @operation_timer, getdate()) as operation_elapsed_ms, datediff(ms, @run_timer, getdate()) as run_elaspsed_ms, 'End of Access Restriction Setup' as marker
	select @operation_timer = getdate()

--#endregion

--#region Set up Page Order table
-----------------------------------
-- Set up Page Order table
-----------------------------------

create table #DocTypeOrder (
	document_type	varchar(100)
	, page_order	int
)

insert #DocTypeOrder
select distinct
	document_type
	/* Smaller #'s come first */
	, case document_type
		when  'Generator Initial Manifest' then    500
		when  'Manifest' then					  1000
		when  'Secondary Manifest' then			  2000
		when  'Pickup Manifest' then			  3000
		when  'Pick Up Report' then				  4000
		when  'Pick Up Request' then			  5000
		when  'COD' then						 10000
		when  'Receiving Document' then			 20000
		when  'Workorder Document' then			 30000
		when  'Attachment' then					 40000
		else									500000
	end
-- select * 
from plt_image.dbo.scandocumenttype (nolock)
where scan_type in ('receipt', 'workorder') 
and status = 'A' 
/* This is the same from-where query used in the list of options for doc types to export */

	if @debug > 0 select datediff(ms, @operation_timer, getdate()) as operation_elapsed_ms, datediff(ms, @run_timer, getdate()) as run_elaspsed_ms, 'End of Page Order Setup' as marker
	select @operation_timer = getdate()

--#endregion

--#region Set up #ImageExport___ tables
-----------------------------------	
-- Run to a temp table - gives the most flexibility/simpler stepwise queries...
-----------------------------------

-- Create temp tables mirroring the permanent tables
	CREATE TABLE #ImageExportHeader (
		-- export_id			int				not null
		added_by			varchar(10)	not null
		, date_added		datetime	not null default getdate()
		, criteria			varchar(max)
		, export_flag		char(1)		not null default 'N'
		, image_count		int			not null default 0
		, file_count		int			not null default 0
		, report_log_id		int
		, export_start_date	datetime
		, export_end_date	datetime
	)

	CREATE TABLE #ImageExportDetail (
		-- export_id			int				not null
		tran_id				int				not null
		, image_id			int				not null
		, filename			varchar(255)	not null
		, page_number		int				not null default 1
	)
	
	CREATE TABLE #ImageExportMeta (
		-- export_id			int				not null
		site_code			varchar(16)
		, generator_address	varchar(100)
		, generator_city	varchar(40)
		, generator_state	varchar(2)
		, service_date		datetime
		, manifest			varchar(20)
		, vendor			varchar(50)
		, type_of_service	varchar(40)
		, quantity			float
		, filename			varchar(255)
	)

	if @debug > 0 select datediff(ms, @operation_timer, getdate()) as operation_elapsed_ms, datediff(ms, @run_timer, getdate()) as run_elaspsed_ms, 'End of Temp Table Setup' as marker
	select @operation_timer = getdate()
--#endregion

--#region Populate #ImageExportHeader
-- Headers are easy:
	insert #ImageExportHeader select
		@user_code	as added_by
		, getdate()	as date_added
		,	'	source_list           : ' + isnull(@source_list, '') + @crlf +
			'	customer_id_list      : ' + isnull(@customer_id_list, '') + @crlf +
			'	customer_type_list    : ' + isnull(@cust_type_list, '') + @crlf +
			'	generator_id_list     : ' + isnull(@generator_id_list, '') + @crlf +
			'	generator_sublocation_list	: ' + isnull(@generator_sublocation_list, '') + @crlf +
			'	site_type_list        : ' + isnull(@site_type_list, '') + @crlf +
			'   generator_state_list  : ' + isnull(@generator_state_list, '') + @crlf +
			'	transporter_code_list : ' + isnull(@transporter_code_list, '') + @crlf +
			'	invoice_code_list	  : ' + isnull(@invoice_code_list, '') + @crlf +
			
			'	facility_list         : ' + isnull(@facility_list, '') + @crlf +
			'	service_date_from     : ' + isnull(convert(varchar(40), @service_date_from, 121), '') + @crlf +
			'	service_date_to       : ' + isnull(convert(varchar(40), @service_date_to, 121), '') + @crlf +
			'	receipt_date_from     : ' + isnull(convert(varchar(40), @receipt_date_from, 121), '') + @crlf +
			'	receipt_date_to       : ' + isnull(convert(varchar(40), @receipt_date_to, 121), '') + @crlf +
			'	invoice_date_from     : ' + isnull(convert(varchar(40), @invoice_date_from, 121), '') + @crlf +
			'	invoice_date_to       : ' + isnull(convert(varchar(40), @invoice_date_to, 121), '') + @crlf +
			'	haz_flag              : ' + isnull(@haz_flag, '') + @crlf +
			'	document_type_list    : ' + isnull(@document_type_list, '') + @crlf +
			'	name_option           : ' + isnull(@name_option, '') + @crlf +
			'	page_option           : ' + isnull(@page_option, '') + @crlf +
			'	user_code             : ' + isnull(@user_code, '') + @crlf +
			'	permission_id         : ' + isnull(convert(varchar(20), @permission_id), '') + @crlf
				as criteria
		, 'N'	as export_flag
		, 0		as image_count
		, 0		as file_count
		, null	as report_log_id
		, null	as export_start_date
		, null	as export_end_date
-- Headers finished

	if @debug > 0 select datediff(ms, @operation_timer, getdate()) as operation_elapsed_ms, datediff(ms, @run_timer, getdate()) as run_elaspsed_ms, 'End of Header Run' as marker
	select @operation_timer = getdate()

--#endregion

--#region Define #build and #tran working tables for gathering results

create table #build (
	trans_source				char(1),
	receipt_id					bigint,
	company_id					int,
	profit_ctr_id				int,
	receipt_date				datetime,
	pickup_date					datetime,
	invoice_date				datetime,
	manifest					varchar(20),
	haz_flag					char(1) default null,
	generator_id				int,
	site_code					varchar(16),
	generator_sublocation_id	int,
	workorder_type				varchar(40),
	tran_filename				varchar(255),
	process_flag				bit default 0
)

select * into #build2 from #build
select * into #work from #build

create table #tran (
	tran_id						int not null identity(1,1),
	trans_source				char(1),
	receipt_id					bigint,
	company_id					int,
	profit_ctr_id				int,
	receipt_date				datetime,
	pickup_date					datetime,
	invoice_date				datetime,
	manifest					varchar(20),
	haz_flag					char(1) default null,
	generator_id				int,
	site_code					varchar(16),
	generator_sublocation_id	int,
	workorder_type				varchar(40),
	tran_filename				varchar(255),
	process_flag				bit default 0
)


--#endregion

if @debug > 0 select datediff(ms, @operation_timer, getdate()) as operation_elapsed_ms, datediff(ms, @run_timer, getdate()) as run_elaspsed_ms, 'End of Setup' as marker
select @operation_timer = getdate()

if @debug > 0 select @pickedCustomers [@pickedCustomers], @pickedGenerators [@pickedGenerators]

--#region Inbound Receipts
if @source_list like '%I%' or @source_list like '%R%' begin -- 'I'nbound Receipts
	-- To pull receipts you need 1+ of any: Customers/Generators/Transporters/Invoices
	-- May also have 1+ of: facilities, service_date, receipt_date, invoice_date, haz_flag

	delete from #build

	-- declare @oldest_date_allowed datetime = dateadd(yy, -5, getdate()), @pickedCustomers bit = 0, @pickedGenerators bit = 0, @debug int = 1, @operation_timer datetime = getdate(), @run_timer datetime = getdate();declare @invoice table (invoice_code varchar(20));declare @transporter table (transporter_code varchar(20));insert @transporter values ('CSX')
	insert #build (trans_source, receipt_id, company_id, profit_ctr_id, receipt_date, pickup_date, invoice_date, process_flag)	
	select 'R', r.receipt_id, r.company_id, r.profit_ctr_id, r.receipt_date, r.pickup_date, r.invoice_date, 1
	from plt_ai..ContactCORReceiptBucket r (nolock)
	join #Secured_Customer sc on r.customer_id = sc.customer_id
	join #Secured_ProfitCenter sp on r.company_id = sp.company_id and r.profit_ctr_id = sp.profit_ctr_id
	WHERE r.receipt_date >= @oldest_date_allowed 
	and @pickedCustomers = 1
	union
	select 'R', r.receipt_id, r.company_id, r.profit_ctr_id, r.receipt_date, r.pickup_date, r.invoice_date, 1
	from plt_ai..ContactCORReceiptBucket r (nolock)
	join #Secured_Generator sc on r.generator_id = sc.generator_id
	join #Secured_ProfitCenter sp on r.company_id = sp.company_id and r.profit_ctr_id = sp.profit_ctr_id
	WHERE r.receipt_date >= @oldest_date_allowed
	and @pickedGenerators = 1

	if @debug > 0 select datediff(ms, @operation_timer, getdate()) as operation_elapsed_ms, datediff(ms, @run_timer, getdate()) as run_elaspsed_ms, 'Inbound Receipts: Populated Build from Bucket tables' as marker, (select count(*) from #build) as [rows]
	select @operation_timer = getdate()
	
	insert #build (trans_source, receipt_id, company_id, profit_ctr_id)	
	select 'R', r.receipt_id, r.company_id, r.profit_ctr_id
	from plt_ai..receipt r (nolock)
	join #Secured_Customer sc on r.customer_id = sc.customer_id
	join #Secured_ProfitCenter sp on r.company_id = sp.company_id and r.profit_ctr_id = sp.profit_ctr_id
	WHERE r.receipt_date >= @oldest_date_allowed
	and @pickedCustomers = 1
	except (select trans_source, receipt_id, company_id, profit_ctr_id from #build)
	union
	select 'R', r.receipt_id, r.company_id, r.profit_ctr_id
	from plt_ai..receipt r (nolock)
	join #Secured_Generator sc on r.generator_id = sc.generator_id 
	join #Secured_ProfitCenter sp on r.company_id = sp.company_id and r.profit_ctr_id = sp.profit_ctr_id
	WHERE r.receipt_date >= @oldest_date_allowed
	and @pickedGenerators = 1
	except (select trans_source, receipt_id, company_id, profit_ctr_id from #build)

	if @debug > 0 select datediff(ms, @operation_timer, getdate()) as operation_elapsed_ms, datediff(ms, @run_timer, getdate()) as run_elaspsed_ms, 'Inbound Receipts: Populated Build from Receipt' as marker, (select count(*) from #build) as [rows]
	select @operation_timer = getdate()
	
	insert #build (trans_source, receipt_id, company_id, profit_ctr_id)	
	select 'R', r.receipt_id, r.company_id, r.profit_ctr_id
	from plt_ai..receipttransporter r (nolock)
	join @transporter sc on r.transporter_code = sc.transporter_code
	join #Secured_ProfitCenter sp on r.company_id = sp.company_id and r.profit_ctr_id = sp.profit_ctr_id
	WHERE r.date_added >= @oldest_date_allowed
	except (select trans_source, receipt_id, company_id, profit_ctr_id from #build)
	union
	select 'R', r.receipt_id, r.company_id, r.profit_ctr_id
	from plt_ai..Billing r (nolock)
	join @invoice i on r.invoice_code = i.invoice_code and r.trans_source = 'R'
	join #Secured_ProfitCenter sp on r.company_id = sp.company_id and r.profit_ctr_id = sp.profit_ctr_id
	WHERE r.date_added >= @oldest_date_allowed
	except (select trans_source, receipt_id, company_id, profit_ctr_id from #build)

	if @debug > 0 select datediff(ms, @operation_timer, getdate()) as operation_elapsed_ms, datediff(ms, @run_timer, getdate()) as run_elaspsed_ms, 'Inbound Receipts: Wide Sources select into #build done' as marker, (select count(*) from #build) as [rows]
	select @operation_timer = getdate()

	update #build set
		receipt_date = b.receipt_date,
		pickup_date = b.pickup_date,
		invoice_date = b.invoice_date,
		process_flag = 1
	from #build t
	join plt_ai..ContactCORReceiptBucket b (nolock)
	on t.receipt_id = b.receipt_id
		and t.company_id = b.company_id
		and t.profit_ctr_id = b.profit_ctr_id
	WHERE process_flag = 0

	if @debug > 0 select datediff(ms, @operation_timer, getdate()) as operation_elapsed_ms, datediff(ms, @run_timer, getdate()) as run_elaspsed_ms, 'Inbound Receipts: Update #build with dates 1' as marker
	select @operation_timer = getdate()
	
	update #build set
		receipt_date = r.receipt_date,
		pickup_date = rt1.transporter_sign_date,
		invoice_date = b.invoice_date,
		process_flag = 1
	from #build t
	join plt_ai..receipt r (nolock)
		on t.receipt_id = r.receipt_id
		and t.company_id = r.company_id
		and t.profit_ctr_id = r.profit_ctr_id
		and r.trans_mode = 'I'
	LEFT JOIN plt_ai..receipttransporter rt1 (nolock)
		on t.receipt_id = rt1.receipt_id
		and t.company_id = rt1.company_id
		and t.profit_ctr_id = rt1.profit_ctr_id
		and rt1.transporter_sequence_id = 1
	LEFT JOIN plt_ai..billing b (nolock)
		on t.receipt_id = b.receipt_id
		and t.company_id = b.company_id
		and t.profit_ctr_id = b.profit_ctr_id
		and b.trans_source = 'R'
	WHERE t.process_flag = 0

	if @debug > 0 select datediff(ms, @operation_timer, getdate()) as operation_elapsed_ms, datediff(ms, @run_timer, getdate()) as run_elaspsed_ms, 'Inbound Receipts: Update #build with dates 2' as marker
	select @operation_timer = getdate()

	-- select process_flag, count(*) from #build GROUP BY process_flag
	
	-- SELECT  * FROM    #build ORDER BY pickup_date desc

	if @receipt_date_from is not null begin
		delete from #build2
		insert #build2 select * FROM    #build
		WHERE receipt_date between @receipt_date_from and @receipt_date_to
		delete from #build
		insert #build select * from #build2
	end

	if @debug > 0 select datediff(ms, @operation_timer, getdate()) as operation_elapsed_ms, datediff(ms, @run_timer, getdate()) as run_elaspsed_ms, 'Inbound Receipts: Filter build on receipt date' as marker
	select @operation_timer = getdate()

	if @service_date_from is not null begin	
		delete from #build2
		insert #build2 select * FROM    #build
		WHERE pickup_date between @service_date_from and @service_date_to
		delete from #build
		insert #build select * from #build2
	end

	if @debug > 0 select datediff(ms, @operation_timer, getdate()) as operation_elapsed_ms, datediff(ms, @run_timer, getdate()) as run_elaspsed_ms, 'Inbound Receipts: Filter build on service date' as marker
	select @operation_timer = getdate()

	if @invoice_date_from is not null begin
		delete from #build2
		insert #build2 select * FROM    #build
		WHERE invoice_date between @invoice_date_from and @invoice_date_to
		delete from #build
		insert #build select * from #build2
	end

	if @debug > 0 select datediff(ms, @operation_timer, getdate()) as operation_elapsed_ms, datediff(ms, @run_timer, getdate()) as run_elaspsed_ms, 'Inbound Receipts: Filter build on invoice date' as marker
	select @operation_timer = getdate()

	if isnull(@haz_flag, 'A') <> 'A' begin
		update #build set haz_flag = 'N'
		update #build set haz_flag = 'H' 
		from #build t
		join plt_ai..receipt r (nolock)
			on t.receipt_id = r.receipt_id
			and t.company_id = r.company_id
			and t.profit_ctr_id = r.profit_ctr_id
			and r.trans_mode = 'I'
			and r.trans_type = 'D'
			and r.fingerpr_status = 'A'
		join plt_ai..receiptwastecode rwc (nolock)
			on r.receipt_id = rwc.receipt_id
			and r.line_id = rwc.line_id
			and r.company_id = rwc.company_id
			and r.profit_ctr_id = rwc.profit_ctr_id
		join plt_ai..wastecode wc (nolock)
			on rwc.waste_code_uid= wc.waste_code_uid
			and wc.haz_flag = 'T'
		
		delete from #build2
		insert #build2 select * from #build
		WHERE haz_flag = @haz_flag
		delete from #build
		insert #build select * from #build2
	end

	if @debug > 0 select datediff(ms, @operation_timer, getdate()) as operation_elapsed_ms, datediff(ms, @run_timer, getdate()) as run_elaspsed_ms, 'Inbound Receipts: Filter build on haz flag' as marker
	select @operation_timer = getdate()
	
	delete from #build2
	insert #build2
	SELECT distinct t.* FROM    #build t
	join plt_ai..receipt r (nolock)
		on t.receipt_id = r.receipt_id
		and t.company_id = r.company_id
		and t.profit_ctr_id = r.profit_ctr_id
	WHERE 1=1
	and r.trans_mode = 'I'
	and r.receipt_status = 'A'
	and r.fingerpr_status = 'A'
	and r.waste_accepted_flag = 'T'
	delete from #build
	insert #build select * from #build2

	if @debug > 0 select datediff(ms, @operation_timer, getdate()) as operation_elapsed_ms, datediff(ms, @run_timer, getdate()) as run_elaspsed_ms, 'Inbound Receipts: Filter build on inbound and status' as marker
	select @operation_timer = getdate()

	insert #work select * from #build

	if @debug > 0 select datediff(ms, @operation_timer, getdate()) as operation_elapsed_ms, datediff(ms, @run_timer, getdate()) as run_elaspsed_ms, 'Inbound Receipts: Fill work from build' as marker, (select count(*) from #build) as [rows]
	select @operation_timer = getdate()

end
--#endregion

--#region Outbound Receipts
if @source_list like '%O%' begin -- 'O'utbound Receipts
	-- To pull receipts you need 1+ of any: Customers/Generators/Transporters/Invoices
	-- May also have 1+ of: facilities, service_date, receipt_date, invoice_date, haz_flag

	delete from #build
	
	insert #build (trans_source, receipt_id, company_id, profit_ctr_id)	
	-- declare @oldest_date_allowed datetime = dateadd(yy,-5,getdate())
	select 'R', r.receipt_id, r.company_id, r.profit_ctr_id
	from plt_ai..receipt r (nolock)
	join #Secured_Customer sc on r.customer_id = sc.customer_id
	join #Secured_ProfitCenter sp on r.company_id = sp.company_id and r.profit_ctr_id = sp.profit_ctr_id
	WHERE r.receipt_date >= @oldest_date_allowed
	and r.trans_mode = 'O'
	and @pickedCustomers = 1
	except (select trans_source, receipt_id, company_id, profit_ctr_id from #build)
	union
	select 'R', r.receipt_id, r.company_id, r.profit_ctr_id
	from plt_ai..receipt r (nolock)
	join #Secured_Generator sc on r.generator_id = sc.generator_id 
	join #Secured_ProfitCenter sp on r.company_id = sp.company_id and r.profit_ctr_id = sp.profit_ctr_id
	WHERE r.receipt_date >= @oldest_date_allowed
	and r.trans_mode = 'O'
	and @pickedGenerators = 1
	except (select trans_source, receipt_id, company_id, profit_ctr_id from #build)

	if @debug > 0 select datediff(ms, @operation_timer, getdate()) as operation_elapsed_ms, datediff(ms, @run_timer, getdate()) as run_elaspsed_ms, 'Outbound Receipts: Populated Build from Receipt' as marker
	select @operation_timer = getdate()
	
	insert #build (trans_source, receipt_id, company_id, profit_ctr_id)	
	-- declare @oldest_date_allowed datetime = dateadd(yy,-5,getdate())
	select 'R', r.receipt_id, r.company_id, r.profit_ctr_id
	from plt_ai..receipttransporter r (nolock)
	join @transporter sc on r.transporter_code = sc.transporter_code
	join #Secured_ProfitCenter sp on r.company_id = sp.company_id and r.profit_ctr_id = sp.profit_ctr_id
	WHERE r.date_added >= @oldest_date_allowed
	except (select trans_source, receipt_id, company_id, profit_ctr_id from #build)
	union
	select 'R', r.receipt_id, r.company_id, r.profit_ctr_id
	from plt_ai..Billing r (nolock)
	join @invoice i on r.invoice_code = i.invoice_code and r.trans_source = 'R'
	join #Secured_ProfitCenter sp on r.company_id = sp.company_id and r.profit_ctr_id = sp.profit_ctr_id
	WHERE r.date_added >= @oldest_date_allowed
	except (select trans_source, receipt_id, company_id, profit_ctr_id from #build)

	if @debug > 0 select datediff(ms, @operation_timer, getdate()) as operation_elapsed_ms, datediff(ms, @run_timer, getdate()) as run_elaspsed_ms, 'Outbound Receipts: Wide Sources select into #build done' as marker
	select @operation_timer = getdate()
	
	update #build set
		receipt_date = r.receipt_date,
		pickup_date = rt1.transporter_sign_date,
		invoice_date = b.invoice_date,
		process_flag = 1
	from #build t
	join plt_ai..receipt r (nolock)
		on t.receipt_id = r.receipt_id
		and t.company_id = r.company_id
		and t.profit_ctr_id = r.profit_ctr_id
		and r.trans_mode = 'O'
	LEFT JOIN plt_ai..receipttransporter rt1 (nolock)
		on t.receipt_id = rt1.receipt_id
		and t.company_id = rt1.company_id
		and t.profit_ctr_id = rt1.profit_ctr_id
		and rt1.transporter_sequence_id = 1
	LEFT JOIN plt_ai..billing b (nolock)
		on t.receipt_id = b.receipt_id
		and t.company_id = b.company_id
		and t.profit_ctr_id = b.profit_ctr_id
		and b.trans_source = 'R'
	WHERE t.process_flag = 0

	if @debug > 0 select datediff(ms, @operation_timer, getdate()) as operation_elapsed_ms, datediff(ms, @run_timer, getdate()) as run_elaspsed_ms, 'Outbound Receipts: Update #build with dates 2' as marker
	select @operation_timer = getdate()

	-- select process_flag, count(*) from #build GROUP BY process_flag
	
	-- SELECT  * FROM    #build ORDER BY pickup_date desc

	if @receipt_date_from is not null begin
		delete from #build2
		insert #build2 select * FROM    #build
		WHERE receipt_date between @receipt_date_from and @receipt_date_to
		delete from #build
		insert #build select * from #build2
	end

	if @debug > 0 select datediff(ms, @operation_timer, getdate()) as operation_elapsed_ms, datediff(ms, @run_timer, getdate()) as run_elaspsed_ms, 'Outbound Receipts: Filter build on receipt date' as marker
	select @operation_timer = getdate()

	if @service_date_from is not null begin	
		delete from #build2
		insert #build2 select * FROM    #build
		WHERE pickup_date between @service_date_from and @service_date_to
		delete from #build
		insert #build select * from #build2
	end

	if @debug > 0 select datediff(ms, @operation_timer, getdate()) as operation_elapsed_ms, datediff(ms, @run_timer, getdate()) as run_elaspsed_ms, 'Outbound Receipts: Filter build on service date' as marker
	select @operation_timer = getdate()

	if @invoice_date_from is not null begin
		delete from #build2
		insert #build2 select * FROM    #build
		WHERE invoice_date between @invoice_date_from and @invoice_date_to
		delete from #build
		insert #build select * from #build2
	end

	if @debug > 0 select datediff(ms, @operation_timer, getdate()) as operation_elapsed_ms, datediff(ms, @run_timer, getdate()) as run_elaspsed_ms, 'Outbound Receipts: Filter build on invoice date' as marker
	select @operation_timer = getdate()

	if isnull(@haz_flag, 'A') <> 'A' begin
		update #build set haz_flag = 'N'
		update #build set haz_flag = 'H' 
		from #build t
		join plt_ai..receipt r (nolock)
			on t.receipt_id = r.receipt_id
			and t.company_id = r.company_id
			and t.profit_ctr_id = r.profit_ctr_id
			and r.trans_mode = 'O'
			and r.trans_type = 'D'
			and r.fingerpr_status = 'A'
		join plt_ai..receiptwastecode rwc (nolock)
			on r.receipt_id = rwc.receipt_id
			and r.line_id = rwc.line_id
			and r.company_id = rwc.company_id
			and r.profit_ctr_id = rwc.profit_ctr_id
		join plt_ai..wastecode wc (nolock)
			on rwc.waste_code_uid= wc.waste_code_uid
			and wc.haz_flag = 'T'
		
		delete from #build2
		insert #build2 select * from #build
		WHERE haz_flag = @haz_flag
		delete from #build
		insert #build select * from #build2
	end

	if @debug > 0 select datediff(ms, @operation_timer, getdate()) as operation_elapsed_ms, datediff(ms, @run_timer, getdate()) as run_elaspsed_ms, 'Outbound Receipts: Filter build on haz flag' as marker
	select @operation_timer = getdate()
	
	delete from #build2
	insert #build2
	SELECT distinct t.* FROM    #build t
	join plt_ai..receipt r (nolock)
		on t.receipt_id = r.receipt_id
		and t.company_id = r.company_id
		and t.profit_ctr_id = r.profit_ctr_id
	WHERE 1=1
	and r.trans_mode = 'O'
	and r.receipt_status = 'A'
	and r.fingerpr_status = 'A'
	delete from #build
	insert #build select * from #build2
	
	if @debug > 0 select datediff(ms, @operation_timer, getdate()) as operation_elapsed_ms, datediff(ms, @run_timer, getdate()) as run_elaspsed_ms, 'Outbound Receipts: Filter build on inbound and status' as marker
	select @operation_timer = getdate()

	insert #work select * from #build

	if @debug > 0 select datediff(ms, @operation_timer, getdate()) as operation_elapsed_ms, datediff(ms, @run_timer, getdate()) as run_elaspsed_ms, 'Outbound Receipts: Fill work from build' as marker, (select count(*) from #build) as [rows]
	select @operation_timer = getdate()

end

--#endregion

--#region Work Orders
if @source_list like '%W%' begin -- 'W'ork Orders
	-- To pull work orders you need 1+ of any: Customers/Generators/Transporters/Invoices
	-- May also have 1+ of: facilities, service_date, receipt_date, invoice_date, haz_flag

	delete from #build

	insert #build (trans_source, receipt_id, company_id, profit_ctr_id, receipt_date, pickup_date, invoice_date, process_flag)	
	select 'W', r.workorder_id, r.company_id, r.profit_ctr_id, r.start_date, r.service_date, r.invoice_date, 1
	from plt_ai..ContactCORWorkorderHeaderBucket r (nolock)
	join #Secured_Customer sc on r.customer_id = sc.customer_id
	join #Secured_ProfitCenter sp on r.company_id = sp.company_id and r.profit_ctr_id = sp.profit_ctr_id
	WHERE r.start_date >= @oldest_date_allowed
	and @pickedCustomers = 1
	union
	select 'W', r.workorder_id, r.company_id, r.profit_ctr_id, r.start_date, r.service_date, r.invoice_date, 1
	from plt_ai..ContactCORWorkorderHeaderBucket r (nolock)
	join #Secured_Generator sc on r.generator_id = sc.generator_id
	join #Secured_ProfitCenter sp on r.company_id = sp.company_id and r.profit_ctr_id = sp.profit_ctr_id
	WHERE r.start_date >= @oldest_date_allowed
	and @pickedGenerators = 1

	if @debug > 0 select datediff(ms, @operation_timer, getdate()) as operation_elapsed_ms, datediff(ms, @run_timer, getdate()) as run_elaspsed_ms, 'Work Orders: Populated Build from Bucket tables' as marker
	select @operation_timer = getdate()
	
	insert #build (trans_source, receipt_id, company_id, profit_ctr_id)	
	select 'W', r.workorder_id, r.company_id, r.profit_ctr_id
	from plt_ai..workorderheader r (nolock)
	join #Secured_Customer sc on r.customer_id = sc.customer_id
	join #Secured_ProfitCenter sp on r.company_id = sp.company_id and r.profit_ctr_id = sp.profit_ctr_id
	WHERE r.start_date >= @oldest_date_allowed
	and @pickedCustomers = 1
	except (select trans_source, receipt_id, company_id, profit_ctr_id from #build)
	union
	select 'W', r.workorder_id, r.company_id, r.profit_ctr_id
	from plt_ai..workorderheader r (nolock)
	join #Secured_Generator sc on r.generator_id = sc.generator_id 
	join #Secured_ProfitCenter sp on r.company_id = sp.company_id and r.profit_ctr_id = sp.profit_ctr_id
	WHERE r.start_date >= @oldest_date_allowed
	and @pickedGenerators = 1
	except (select trans_source, receipt_id, company_id, profit_ctr_id from #build)

	if @debug > 0 select datediff(ms, @operation_timer, getdate()) as operation_elapsed_ms, datediff(ms, @run_timer, getdate()) as run_elaspsed_ms, 'Work Orders: Populated Build from WorkorderHeader' as marker
	select @operation_timer = getdate()
	
	insert #build (trans_source, receipt_id, company_id, profit_ctr_id)	
	select 'W', r.workorder_id, r.company_id, r.profit_ctr_id
	from plt_ai..workordertransporter r (nolock)
	join @transporter sc on r.transporter_code = sc.transporter_code
	join #Secured_ProfitCenter sp on r.company_id = sp.company_id and r.profit_ctr_id = sp.profit_ctr_id
	WHERE r.date_added >= @oldest_date_allowed
	except (select trans_source, receipt_id, company_id, profit_ctr_id from #build)
	union
	select 'W', r.receipt_id, r.company_id, r.profit_ctr_id
	from plt_ai..Billing r (nolock)
	join @invoice i on r.invoice_code = i.invoice_code and r.trans_source = 'W'
	join #Secured_ProfitCenter sp on r.company_id = sp.company_id and r.profit_ctr_id = sp.profit_ctr_id
	WHERE r.date_added >= @oldest_date_allowed
	except (select trans_source, receipt_id, company_id, profit_ctr_id from #build)

	if @debug > 0 select datediff(ms, @operation_timer, getdate()) as operation_elapsed_ms, datediff(ms, @run_timer, getdate()) as run_elaspsed_ms, 'Work Orders: Wide Sources select into #build done' as marker
	select @operation_timer = getdate()

	update #build set
		receipt_date = b.start_date,
		pickup_date = b.service_date,
		invoice_date = b.invoice_date,
		process_flag = 1
	from #build t
	join plt_ai..ContactCORWorkorderHeaderBucket b (nolock)
	on t.receipt_id = b.workorder_id
		and t.company_id = b.company_id
		and t.profit_ctr_id = b.profit_ctr_id
	WHERE process_flag = 0

	if @debug > 0 select datediff(ms, @operation_timer, getdate()) as operation_elapsed_ms, datediff(ms, @run_timer, getdate()) as run_elaspsed_ms, 'Work Orders: Update #build with dates 1' as marker
	select @operation_timer = getdate()
	
	update #build set
		receipt_date = r.start_date,
		pickup_date = coalesce(wos.date_act_arrive, rt1.transporter_sign_date),
		invoice_date = b.invoice_date,
		process_flag = 1
	from #build t
	join plt_ai..workorderheader r (nolock)
		on t.receipt_id = r.workorder_id
		and t.company_id = r.company_id
		and t.profit_ctr_id = r.profit_ctr_id
	LEFT JOIN plt_ai..workorderstop wos (nolock)
		on t.receipt_id = wos.workorder_id
		and t.company_id = wos.company_id
		and t.profit_ctr_id = wos.profit_ctr_id
	LEFT JOIN plt_ai..workordertransporter rt1 (nolock)
		on t.receipt_id = rt1.workorder_id
		and t.company_id = rt1.company_id
		and t.profit_ctr_id = rt1.profit_ctr_id
		and rt1.transporter_sequence_id = 1
	LEFT JOIN plt_ai..billing b (nolock)
		on t.receipt_id = b.receipt_id
		and t.company_id = b.company_id
		and t.profit_ctr_id = b.profit_ctr_id
		and b.trans_source = 'W'
	WHERE t.process_flag = 0

	if @debug > 0 select datediff(ms, @operation_timer, getdate()) as operation_elapsed_ms, datediff(ms, @run_timer, getdate()) as run_elaspsed_ms, 'Work Orders: Update #build with dates 2' as marker
	select @operation_timer = getdate()

	-- select process_flag, count(*) from #build GROUP BY process_flag
	
	-- SELECT  * FROM    #build ORDER BY pickup_date desc

	if @receipt_date_from is not null begin
		delete from #build2
		insert #build2 select * FROM    #build
		WHERE receipt_date between @receipt_date_from and @receipt_date_to
		delete from #build
		insert #build select * from #build2
	end

	if @debug > 0 select datediff(ms, @operation_timer, getdate()) as operation_elapsed_ms, datediff(ms, @run_timer, getdate()) as run_elaspsed_ms, 'Work Orders: Filter build on receipt date' as marker
	select @operation_timer = getdate()

	if @service_date_from is not null begin	
		delete from #build2
		insert #build2 select * FROM    #build
		WHERE pickup_date between @service_date_from and @service_date_to
		delete from #build
		insert #build select * from #build2
	end

	if @debug > 0 select datediff(ms, @operation_timer, getdate()) as operation_elapsed_ms, datediff(ms, @run_timer, getdate()) as run_elaspsed_ms, 'Work Orders: Filter build on service date' as marker
	select @operation_timer = getdate()

	if @invoice_date_from is not null begin
		delete from #build2
		insert #build2 select * FROM    #build
		WHERE invoice_date between @invoice_date_from and @invoice_date_to
		delete from #build
		insert #build select * from #build2
	end

	if @debug > 0 select datediff(ms, @operation_timer, getdate()) as operation_elapsed_ms, datediff(ms, @run_timer, getdate()) as run_elaspsed_ms, 'Work Orders: Filter build on invoice date' as marker
	select @operation_timer = getdate()

	if isnull(@haz_flag, 'A') <> 'A' begin
		update #build set haz_flag = 'N'
		update #build set haz_flag = 'H' 
		from #build t
		join plt_ai..workorderdetail r (nolock)
			on t.receipt_id = r.workorder_id
			and t.company_id = r.company_id
			and t.profit_ctr_id = r.profit_ctr_id
			and r.resource_type = 'D'
			and r.bill_rate > -2
		join plt_ai..workorderwastecode rwc (nolock)
			on r.workorder_id = rwc.workorder_id
			and r.sequence_id = rwc.sequence_id
			and r.company_id = rwc.company_id
			and r.profit_ctr_id = rwc.profit_ctr_id
		join plt_ai..wastecode wc (nolock)
			on rwc.waste_code_uid= wc.waste_code_uid
			and wc.haz_flag = 'T'
		
		delete from #build2
		insert #build2 select * from #build
		WHERE haz_flag = @haz_flag
		delete from #build
		insert #build select * from #build2
	end

	if @debug > 0 select datediff(ms, @operation_timer, getdate()) as operation_elapsed_ms, datediff(ms, @run_timer, getdate()) as run_elaspsed_ms, 'Inbound Receipts: Filter build on haz flag' as marker
	select @operation_timer = getdate()
	
	delete from #build2
	insert #build2
	SELECT distinct t.* FROM    #build t
	join plt_ai..workorderheader r (nolock)
		on t.receipt_id = r.workorder_id
		and t.company_id = r.company_id
		and t.profit_ctr_id = r.profit_ctr_id
	WHERE 1=1

	delete from #build
	insert #build select * from #build2

	if @debug > 0 select datediff(ms, @operation_timer, getdate()) as operation_elapsed_ms, datediff(ms, @run_timer, getdate()) as run_elaspsed_ms, 'Inbound Receipts: Filter build on inbound and status' as marker
	select @operation_timer = getdate()

	insert #work select * from #build

	if @debug > 0 select datediff(ms, @operation_timer, getdate()) as operation_elapsed_ms, datediff(ms, @run_timer, getdate()) as run_elaspsed_ms, 'Inbound Receipts: Fill work from build' as marker, (select count(*) from #build) as [rows]
	select @operation_timer = getdate()

end

--#endregion

--#region Invoices
if @source_list like '%V%' begin -- In'V'oices
	-- To pull invoices you need Invoice Codes.  Customer/Generator/Facility will LIMIT the search, but it starts with invoice_code
	-- May also have 1+ of: facilities, service_date, receipt_date, invoice_date, haz_flag

	delete from #build

	insert #build (trans_source, receipt_id, company_id, profit_ctr_id, invoice_date)	
	select distinct d.trans_source, d.receipt_id, d.company_id, d.profit_ctr_id, h.invoice_date
	from plt_ai..invoicedetail d (nolock)
	join plt_ai..invoiceheader h on d.invoice_id = h.invoice_id and d.revision_id = h.revision_id and h.status = 'I'
	join @invoice i on h.invoice_code = i.invoice_code
	join #Secured_Customer sc on h.customer_id = sc.customer_id
	join #Secured_Generator sg on d.generator_id = sg.generator_id
	join #Secured_ProfitCenter sp on d.company_id = sp.company_id and d.profit_ctr_id = sp.profit_ctr_id
	WHERE h.invoice_date >= @oldest_date_allowed

	if @debug > 0 select datediff(ms, @operation_timer, getdate()) as operation_elapsed_ms, datediff(ms, @run_timer, getdate()) as run_elaspsed_ms, 'Invoices: Populated Build from Invoice*' as marker, @@rowcount [rows]
	select @operation_timer = getdate()

	update #build set
		trans_source = 'I',
		receipt_date = b.receipt_date,
		pickup_date = b.pickup_date,
		process_flag = 1
	from #build t
	join plt_ai..ContactCORReceiptBucket b (nolock)
	on t.receipt_id = b.receipt_id
		and t.company_id = b.company_id
		and t.profit_ctr_id = b.profit_ctr_id
	WHERE process_flag = 0
	and t.trans_source = 'R'

	if @debug > 0 select datediff(ms, @operation_timer, getdate()) as operation_elapsed_ms, datediff(ms, @run_timer, getdate()) as run_elaspsed_ms, 'Invoiced Receipts: Update #build with dates 1' as marker
	select @operation_timer = getdate()
	
	update #build set
		trans_source = 'I',
		receipt_date = r.receipt_date,
		pickup_date = rt1.transporter_sign_date,
		process_flag = 1
	from #build t
	join plt_ai..receipt r (nolock)
		on t.receipt_id = r.receipt_id
		and t.company_id = r.company_id
		and t.profit_ctr_id = r.profit_ctr_id
		and r.trans_mode = 'I'
	LEFT JOIN plt_ai..receipttransporter rt1 (nolock)
		on t.receipt_id = rt1.receipt_id
		and t.company_id = rt1.company_id
		and t.profit_ctr_id = rt1.profit_ctr_id
		and rt1.transporter_sequence_id = 1
	WHERE t.process_flag = 0
	and t.trans_source = 'R'

	if @debug > 0 select datediff(ms, @operation_timer, getdate()) as operation_elapsed_ms, datediff(ms, @run_timer, getdate()) as run_elaspsed_ms, 'Invoiced Receipts: Update #build with dates 2' as marker
	select @operation_timer = getdate()

	update #build set
		receipt_date = b.start_date,
		pickup_date = b.service_date,
		process_flag = 1
	from #build t
	join plt_ai..ContactCORWorkorderHeaderBucket b (nolock)
	on t.receipt_id = b.workorder_id
		and t.company_id = b.company_id
		and t.profit_ctr_id = b.profit_ctr_id
	WHERE process_flag = 0
	and t.trans_source = 'W'

	if @debug > 0 select datediff(ms, @operation_timer, getdate()) as operation_elapsed_ms, datediff(ms, @run_timer, getdate()) as run_elaspsed_ms, 'Invoiced Work Orders: Update #build with dates 1' as marker
	select @operation_timer = getdate()
	
	update #build set
		receipt_date = r.start_date,
		pickup_date = coalesce(wos.date_act_arrive, rt1.transporter_sign_date),
		process_flag = 1
	from #build t
	join plt_ai..workorderheader r (nolock)
		on t.receipt_id = r.workorder_id
		and t.company_id = r.company_id
		and t.profit_ctr_id = r.profit_ctr_id
	LEFT JOIN plt_ai..workorderstop wos (nolock)
		on t.receipt_id = wos.workorder_id
		and t.company_id = wos.company_id
		and t.profit_ctr_id = wos.profit_ctr_id
	LEFT JOIN plt_ai..workordertransporter rt1 (nolock)
		on t.receipt_id = rt1.workorder_id
		and t.company_id = rt1.company_id
		and t.profit_ctr_id = rt1.profit_ctr_id
		and rt1.transporter_sequence_id = 1
	WHERE t.process_flag = 0
	and t.trans_source = 'W'

	if @debug > 0 select datediff(ms, @operation_timer, getdate()) as operation_elapsed_ms, datediff(ms, @run_timer, getdate()) as run_elaspsed_ms, 'Invoiced Work Orders: Update #build with dates 2' as marker
	select @operation_timer = getdate()

	-- select process_flag, count(*) from #build GROUP BY process_flag
	
	-- SELECT  * FROM    #build ORDER BY pickup_date desc

	if @receipt_date_from is not null begin
		delete from #build2
		insert #build2 select * FROM    #build
		WHERE receipt_date between @receipt_date_from and @receipt_date_to
		delete from #build
		insert #build select * from #build2
	end

	if @debug > 0 select datediff(ms, @operation_timer, getdate()) as operation_elapsed_ms, datediff(ms, @run_timer, getdate()) as run_elaspsed_ms, 'Invoices: Filter build on receipt date' as marker
	select @operation_timer = getdate()

	if @service_date_from is not null begin	
		delete from #build2
		insert #build2 select * FROM    #build
		WHERE pickup_date between @service_date_from and @service_date_to
		delete from #build
		insert #build select * from #build2
	end

	if @debug > 0 select datediff(ms, @operation_timer, getdate()) as operation_elapsed_ms, datediff(ms, @run_timer, getdate()) as run_elaspsed_ms, 'Invoices: Filter build on service date' as marker
	select @operation_timer = getdate()

	if @invoice_date_from is not null begin
		delete from #build2
		insert #build2 select * FROM    #build
		WHERE invoice_date between @invoice_date_from and @invoice_date_to
		delete from #build
		insert #build select * from #build2
	end

	if @debug > 0 select datediff(ms, @operation_timer, getdate()) as operation_elapsed_ms, datediff(ms, @run_timer, getdate()) as run_elaspsed_ms, 'Invoices: Filter build on invoice date' as marker
	select @operation_timer = getdate()

	if isnull(@haz_flag, 'A') <> 'A' begin
		update #build set haz_flag = 'N'
		
		update #build set haz_flag = 'H' 
		from #build t
		join plt_ai..workorderdetail r (nolock)
			on t.receipt_id = r.workorder_id
			and t.company_id = r.company_id
			and t.profit_ctr_id = r.profit_ctr_id
			and r.resource_type = 'D'
			and r.bill_rate > -2
		join plt_ai..workorderwastecode rwc (nolock)
			on r.workorder_id = rwc.workorder_id
			and r.sequence_id = rwc.sequence_id
			and r.company_id = rwc.company_id
			and r.profit_ctr_id = rwc.profit_ctr_id
		join plt_ai..wastecode wc (nolock)
			on rwc.waste_code_uid= wc.waste_code_uid
			and wc.haz_flag = 'T'
		WHERE t.trans_source = 'W'
		
		update #build set haz_flag = 'H' 
		from #build t
		join plt_ai..receipt r (nolock)
			on t.receipt_id = r.receipt_id
			and t.company_id = r.company_id
			and t.profit_ctr_id = r.profit_ctr_id
			and r.trans_mode = 'I'
			and r.trans_type = 'D'
			and r.fingerpr_status = 'A'
		join plt_ai..receiptwastecode rwc (nolock)
			on r.receipt_id = rwc.receipt_id
			and r.line_id = rwc.line_id
			and r.company_id = rwc.company_id
			and r.profit_ctr_id = rwc.profit_ctr_id
		join plt_ai..wastecode wc (nolock)
			on rwc.waste_code_uid= wc.waste_code_uid
			and wc.haz_flag = 'T'
		WHERE t.trans_source in ('I', 'R')
			
		delete from #build2
		insert #build2 select * from #build
		WHERE haz_flag = @haz_flag
		delete from #build
		insert #build select * from #build2
	end

	-- any receipts left are outbound.
	-- update #build set trans_source = 'O' WHERE trans_source = 'R'
	
	if @debug > 0 select datediff(ms, @operation_timer, getdate()) as operation_elapsed_ms, datediff(ms, @run_timer, getdate()) as run_elaspsed_ms, 'Inbound Receipts: Filter build on haz flag' as marker
	select @operation_timer = getdate()
	
	insert #work select * from #build

	if @debug > 0 select datediff(ms, @operation_timer, getdate()) as operation_elapsed_ms, datediff(ms, @run_timer, getdate()) as run_elaspsed_ms, 'Inbound Receipts: Fill work from build' as marker, (select count(*) from #build) as [rows]
	select @operation_timer = getdate()

end

--#endregion

--#region Populate additional fields before output logic

	-- There are now some un-filled #work fields (generator_id, manifest, generator_sublocation_id, workorder_type)
	-- that are only needed if they're used in file names/logic,really. But how hard to populate them?

	delete from #build

	insert #build
	(
		trans_source
		, receipt_id
		, company_id
		, profit_ctr_id
		, receipt_date
		, pickup_date
		, invoice_date
		, manifest
		, generator_id
	)
	select distinct
		t.trans_source
		, t.receipt_id
		, t.company_id
		, t.profit_ctr_id
		, t.receipt_date
		, t.pickup_date
		, t.invoice_date
		, r.manifest
		, r.generator_id
	from #work t
		join plt_ai..receipt r (nolock)
		on t.receipt_id = r.receipt_id
		and t.company_id = r.company_id
		and t.profit_ctr_id = r.profit_ctr_id
		and r.fingerpr_status = 'A'
	WHERE t.trans_source in ('I', 'O', 'R')	

	if @debug > 0 select datediff(ms, @operation_timer, getdate()) as operation_elapsed_ms, datediff(ms, @run_timer, getdate()) as run_elaspsed_ms, 'Populated Build Receipts from #work' as marker
	select @operation_timer = getdate()

	insert #build
	(
		trans_source
		, receipt_id
		, company_id
		, profit_ctr_id
		, receipt_date
		, pickup_date
		, invoice_date
		, manifest
		, generator_id
		, generator_sublocation_id
		, workorder_type
	)
	select
		t.trans_source
		, t.receipt_id
		, t.company_id
		, t.profit_ctr_id
		, t.receipt_date
		, t.pickup_date
		, t.invoice_date
		, d.manifest
		, h.generator_id
		, h.generator_sublocation_id
		, woth.account_desc
	from #work t
		join plt_ai..workorderheader h (nolock)
		on t.receipt_id = h.workorder_id
		and t.company_id = h.company_id
		and t.profit_ctr_id = h.profit_ctr_id
		join plt_ai..workorderdetail d (nolock)
		on t.receipt_id = d.workorder_id
		and t.company_id = d.company_id
		and t.profit_ctr_id = d.profit_ctr_id
		and d.resource_type = 'D'
		and d.bill_rate > -2
		and d.manifest not like '%manifest%'
		LEFT JOIN plt_ai..workordertypeheader woth (nolock)
		on h.workorder_type_id = woth.workorder_type_id
	WHERE t.trans_source in ('W')	

	if @debug > 0 select datediff(ms, @operation_timer, getdate()) as operation_elapsed_ms, datediff(ms, @run_timer, getdate()) as run_elaspsed_ms, 'Populated Build Work Orders from #work' as marker
	select @operation_timer = getdate()

	update #build set
		generator_sublocation_id = h.generator_sublocation_id
		, workorder_type = woth.account_desc
	from #build t
		join plt_ai..billinglinklookup bll (nolock)
		on t.receipt_id = bll.receipt_id
		and t.company_id = bll.company_id
		and t.profit_ctr_id = bll.profit_ctr_id
		join plt_ai..workorderheader h (nolock)
		on bll.source_id = h.workorder_id
		and bll.source_company_id = h.company_id
		and bll.source_profit_ctr_id = h.profit_ctr_id
		LEFT JOIN plt_ai..workordertypeheader woth (nolock)
		on h.workorder_type_id = woth.workorder_type_id
	WHERE t.trans_source in ('I', 'O', 'R')	

	if @debug > 0 select datediff(ms, @operation_timer, getdate()) as operation_elapsed_ms, datediff(ms, @run_timer, getdate()) as run_elaspsed_ms, 'Updated Build Generator Sublocations and WorkorderTypes in linked Receipts' as marker
	select @operation_timer = getdate()

	update #build set
		site_code = g.site_code
	from #build t
	join plt_ai..generator g (nolock)
		on t.generator_id = g.generator_id

	if @debug > 0 select datediff(ms, @operation_timer, getdate()) as operation_elapsed_ms, datediff(ms, @run_timer, getdate()) as run_elaspsed_ms, 'Updated Build Generator Site Codes' as marker
	select @operation_timer = getdate()

--#endregion

--#region Populate #ImageExportDetail

	insert #tran (trans_source, receipt_id, company_id, profit_ctr_id, receipt_date, pickup_date, invoice_date, manifest, haz_flag, generator_id, site_code, generator_sublocation_id, workorder_type)
	select 	distinct trans_source, receipt_id, company_id, profit_ctr_id, receipt_date, pickup_date, invoice_date, manifest, haz_flag, generator_id, site_code, generator_sublocation_id, workorder_type 
	FROM    #build


	if @debug > 0 select datediff(ms, @operation_timer, getdate()) as operation_elapsed_ms, datediff(ms, @run_timer, getdate()) as run_elaspsed_ms, 'Populated #tran from #build' as marker, (select count(*) from #tran) as [rows]
	select @operation_timer = getdate()

	--select * from #tran
	select @maxlenri = max(len(isnull(site_code, ''))) from #tran
	select @maxlenr = convert(varchar(20), @maxlenri)
	set @name_sql = replace(@name_sql, '[MAX_SITE_CODE_LEN]', @maxlenr)

	if @debug > 0 select datediff(ms, @operation_timer, getdate()) as operation_elapsed_ms, datediff(ms, @run_timer, getdate()) as run_elaspsed_ms, 'End of Max Site Code Length Calculation' as marker
	select @operation_timer = getdate()

	select r.tran_id, s.image_id, s.page_number, s.document_name, s.manifest, s.scan_file, s.type_id, dto.page_order
	into #imagesource
	from #tran r
	inner join plt_image..scan s (nolock)
		on r.receipt_id = s.receipt_id
			-- case r.trans_source when 'R' then s.receipt_id when 'I' then s.receipt_id when 'O' then s.receipt_id else s.workorder_id end     
		and r.company_id = s.company_id 
		and r.profit_ctr_id = s.profit_ctr_id      
		and s.document_source = 'receipt'
		and s.status = 'A'
			-- and s.document_source = case r.trans_source when 'R' then 'receipt' when 'I' then 'receipt' when 'O' then 'receipt' else 'workorder' end    
	inner join #ScanDocumentType ust on s.type_id = ust.scan_type_id
	inner join plt_image..scandocumenttype st (nolock) on s.type_id = st.type_id    
	left join #DocTypeOrder dto on st.document_type = dto.document_type        
	WHERE r.trans_source in ('I', 'O', 'R')
	union
	select r.tran_id, s.image_id, s.page_number, s.document_name, s.manifest, s.scan_file, s.type_id, dto.page_order
	from #tran r
	inner join plt_image..scan s (nolock)
		on r.receipt_id = s.workorder_id
		and r.company_id = s.company_id 
		and r.profit_ctr_id = s.profit_ctr_id      
		and s.document_source = 'workorder'
		and s.status = 'A'
	inner join #ScanDocumentType ust on s.type_id = ust.scan_type_id
	inner join plt_image..scandocumenttype st (nolock) on s.type_id = st.type_id    
	left join #DocTypeOrder dto on st.document_type = dto.document_type        
	WHERE r.trans_source in ('W')

	if @debug > 0 select datediff(ms, @operation_timer, getdate()) as operation_elapsed_ms, datediff(ms, @run_timer, getdate()) as run_elaspsed_ms, 'Created #ImageSource for detail export' as marker, @@rowcount [rows]
	select @operation_timer = getdate()

	set @sql = 'insert #ImageExportDetail ' +
		'select ' + -- distinct ' + 
		'r.tran_id ' +
		', s.image_id ' +
		', filename = ltrim(rtrim(isnull( ' + @name_sql + ', convert(varchar(20), (s.image_id ))))) ' /* This is still part of filename */

	if @page_option = 'S'
		set @sql = @sql + ' + ''_p'' + convert(varchar(20), isnull(s.page_number, 1)) ' -- force _pX on filename to force separate files per page.

	/* this is page number */					
	set @sql = @sql + '
		, page_number = row_number() over (
			partition by 
				ltrim(rtrim(isnull( ' + @name_sql + ', convert(varchar(20), (s.image_id )))))
			order by
			isnull(s.page_order, 5000000) + isnull(s.page_number, 1)
			)

		FROM #ImageSource s
		inner join #tran r on r.tran_id = s.tran_id
		inner join plt_image..scandocumenttype st (nolock) on s.type_id = st.type_id
		left join plt_ai..generator g (nolock) on r.generator_id = g.generator_id
	'

	if @debug > 0 select datediff(ms, @operation_timer, getdate()) as operation_elapsed_ms, datediff(ms, @run_timer, getdate()) as run_elaspsed_ms, 'End of Image Detail SQL Build' as marker
	select @operation_timer = getdate()

	if @debug > 0 select @sql
	exec (@sql)
	if @debug > 0 select count(*) [#ImageExportDetail Rowcount] from #ImageExportDetail

	if @debug > 0 select datediff(ms, @operation_timer, getdate()) as operation_elapsed_ms, datediff(ms, @run_timer, getdate()) as run_elaspsed_ms, 'End of Image Detail SQL Run' as marker
	select @operation_timer = getdate()

	-- If the naming option is 'S'can_File, let's clear off the path & existing extension:
	if @name_option in ( 'S', 'Scanned File' )
		update #ImageExportDetail set 
		filename = left(reverse(left(reverse(replace(isnull(filename, 
			convert(varchar(20), image_id)), '/', '\')) + '\', charindex('\', reverse(replace(isnull(filename, convert(varchar(20), image_id)), '/', '\')) + '\') -1)), 
			charindex('.', reverse(left(reverse(replace(isnull(filename, convert(varchar(20), image_id)), '/', '\')) + '\', charindex('\', 
			reverse(replace(isnull(filename, convert(varchar(20), image_id)), '/', '\')) + '\') -1))) -1)

	if @name_option = 'Kroger 2019 Image Naming' begin
		-- Here we assume there's a billing link lookup connection. It's the best type of lookup
		update #tran set
		-- select d.*,
		generator_sublocation_id = woh.generator_sublocation_id
		from #tran t
		inner join plt_ai..billinglinklookup bll 
			on t.trans_source = 'R'
			and t.receipt_id = bll.receipt_id
			and t.company_id = bll.company_id
			and t.profit_ctr_id = bll.profit_ctr_id
		inner join plt_ai..workorderheader woh
			on bll.source_id = woh.workorder_id
			and bll.company_id = woh.company_id
			and bll.profit_ctr_id = woh.profit_ctr_id
			and woh.generator_id = t.generator_id
		inner join plt_ai..generatorsublocation gsl
			on woh.generator_sublocation_id = gsl.generator_sublocation_id
		WHERE woh.generator_sublocation_id is not null
		and t.generator_sublocation_id is null

		-- SELECT  *  FROM    #tran
		
		-- Here we assume there's no billing link lookup connection. 
			-- must match on manifest + generator
		update #tran set
		-- select d.*,
		generator_sublocation_id = woh.generator_sublocation_id
		from #tran t
		inner join plt_ai..workordermanifest wom
			on wom.manifest = t.manifest
		inner join plt_ai..workorderheader woh
			on wom.workorder_id = woh.workorder_id
			and wom.company_id = woh.company_id
			and wom.profit_ctr_id = woh.profit_ctr_id
			and woh.generator_id = t.generator_id
		WHERE woh.generator_sublocation_id is not null
		and t.generator_sublocation_id is null

		-- now #tran is as updated as we can make it. update #ImageExportDetail
		update #ImageExportDetail set
		-- select d.*,
		filename = replace(filename, '/*gsl.description*/', gsl.description)
		from #ImageExportDetail d
		join #tran t on d.tran_id = t.tran_id
		join plt_ai..generatorsublocation gsl
			on gsl.generator_sublocation_id = t.generator_sublocation_id
		WHERE t.generator_sublocation_id is not null
		and d.filename like '%/*gsl.description*/%'

		-- GSL.Description Last resort
		update #ImageExportDetail set
		-- select d.*,
		filename = replace(filename, '/*gsl.description*/', 'unknown-location')
		from #ImageExportDetail d
		WHERE d.filename like '%/*gsl.description*/%'


		-- gsl.code is similar except has additional replace logic after.
		-- now #tran is as updated as we can make it. update #ImageExportDetail
		update #ImageExportDetail set
		-- select d.*,
		filename = replace(filename, '/*gsl.code-XX*/', 'XX')
		from #ImageExportDetail d
		join #tran t on d.tran_id = t.tran_id
		join plt_ai..generatorsublocation gsl
			on gsl.generator_sublocation_id = t.generator_sublocation_id
		WHERE t.generator_sublocation_id is not null
		and d.filename like '%/*gsl.code-XX*/%'
		and gsl.code in ('CF', 'DC', 'DH', 'DL', 'DM')

		-- SELECT  *  FROM    #ImageExportDetail
		
		-- GSL.code additional replace logic:
		update #ImageExportDetail
			set filename = replace(filename, '/*gsl.code-XX*/', '')
		WHERE filename like '%/*gsl.code-XX*/%'

		if @debug > 0 select datediff(ms, @operation_timer, getdate()) as operation_elapsed_ms, datediff(ms, @run_timer, getdate()) as run_elaspsed_ms, 'End of Kroger 2019 Filename Update' as marker
		select @operation_timer = getdate()

	end

	update #ImageExportDetail 
	set filename = replace(
		replace(
			replace(
				replace(
					replace(
						replace(
							replace(
								replace(
									replace(filename, '\', '_')
								, '/', '_')
							, ':', '_')
						, '*', '_')
					, '?', '_')
				, '"', '_')
			, '>', '_')
		, '<', '_')
	, '__', '_')

	if @debug > 0 select datediff(ms, @operation_timer, getdate()) as operation_elapsed_ms, datediff(ms, @run_timer, getdate()) as run_elaspsed_ms, 'End of Image Detail Filename Bad Character Update' as marker
	select @operation_timer = getdate()

--#endregion

--#region Populate #ImageExportMeta
	
	-- That's so meta:
	insert #ImageExportMeta 
	select
		RIGHT('0000000000000000' + isnull(t.site_code, ''), @maxlenr) as site_code
		, ltrim(rtrim(isnull(g.generator_address_1 + ' ', '') + isnull(g.generator_address_2, ''))) as generator_address
		, g.generator_city
		, g.generator_state
		, t.pickup_date
		, t.manifest
		, 'USE'
		, isnull(gsl.description, '') as type_of_service
		, count(distinct id.filename)
		, id.filename
	from #tran t
	join #ImageExportDetail id on t.tran_id = id.tran_id
	join plt_ai..generator g (nolock) on t.generator_id = g.generator_id
	left join plt_ai..workorderheader woh (nolock) on t.receipt_id = woh.workorder_id and t.company_id = woh.company_id and t.profit_ctr_id = woh.profit_ctr_id
	left join plt_ai..generatorsublocation gsl (nolock) on woh.generator_sublocation_id = gsl.generator_sublocation_id
	group by
		RIGHT('0000000000000000' + isnull(t.site_code, ''), @maxlenr)
		, ltrim(rtrim(isnull(g.generator_address_1 + ' ', '') + isnull(g.generator_address_2, '')))
		, g.generator_city
		, g.generator_state
		, t.pickup_date
		, t.manifest
--		, 'USE'
		, isnull(gsl.description, '')
		, id.filename

	if @debug > 0 select datediff(ms, @operation_timer, getdate()) as operation_elapsed_ms, datediff(ms, @run_timer, getdate()) as run_elaspsed_ms, 'End of Image Meta SQL Run' as marker, (select count(*) from #ImageExportMeta) as [rows]
	select @operation_timer = getdate()


--#endregion

--#region Populate EQIPImageExportHeader

	-- Headers:
	insert EqipImageExportHeader 
		(added_by, date_added, criteria, export_flag, image_count, file_count, report_log_id, export_start_date, export_end_date)
	select distinct
		 added_by, date_added, criteria, export_flag, (select count(distinct image_id) from #ImageExportDetail) as image_count, (select count(distinct filename) from #ImageExportDetail) as file_count, report_log_id, export_start_date, export_end_date
	from #ImageExportHeader
	
	set @export_id = @@IDENTITY

	if @debug > 0 select datediff(ms, @operation_timer, getdate()) as operation_elapsed_ms, datediff(ms, @run_timer, getdate()) as run_elaspsed_ms, 'End of Image Header Permanent Storage' as marker, @export_id export_id
	select @operation_timer = getdate()


--#endregion
	-- Insert call to custom_build_sp here -- After #tran is fully built, and after #ImageExport* (Header/Detail/Meta)
	-- This allows all 4 of those tables to be modified if desired, before saved into permanent tables.
	-- Need to do this *after* inserting to EqipImageExportHeader so we have an @export_id value.

--#region Custom Build SP Call

	-- select @name_custom_build_sp name_custom_build_sp
	if isnull(@name_custom_build_sp, '') <> '' begin

		select @sql = @name_custom_build_sp + ' @export_id = ' + convert(varchar(20), @export_id)
		
		if @debug > 0 select datediff(ms, @operation_timer, getdate()) as operation_elapsed_ms, datediff(ms, @run_timer, getdate()) as run_elaspsed_ms, 'Built custom build sp SQL' as marker, @sql as [sql]
		select @operation_timer = getdate()
		
		-- select @sql
--		begin try
			exec(@sql)
		--end try
		--begin catch
		--	-- do nothing.
		--	print 'exec ' + @sql + ' failed'
		--end catch
		
		if @debug > 0 select datediff(ms, @operation_timer, getdate()) as operation_elapsed_ms, datediff(ms, @run_timer, getdate()) as run_elaspsed_ms, @name_custom_build_sp + ' finished' as marker
		select @operation_timer = getdate()

	end
	-- SELECT  * FROM    #ImageExportDetail

--#endregion	

		if @debug > 1 select '#tran' as [table], * from #tran

--#region Populate EQIPImageExportDetail

	-- Detail:
	insert EqipImageExportDetail 
		(export_id, image_id, filename, page_number)
	select distinct
		@export_id, image_id, filename, page_number
	from
		#ImageExportDetail

	if @debug > 0 select datediff(ms, @operation_timer, getdate()) as operation_elapsed_ms, datediff(ms, @run_timer, getdate()) as run_elaspsed_ms, 'End of Image Detail Permanent Storage' as marker
	select @operation_timer = getdate()

--#endregion	

--#region Populate EQIPImageExportMeta

	-- Meta:
	IF @name_requires_metadata = 'T' begin
		insert EqipImageExportMeta
			(
				export_id
				, site_code			
				, generator_address	
				, generator_city	
				, generator_state	
				, service_date		
				, manifest			
				, vendor			
				, type_of_service	
				, quantity			
				, filename			
			)
		select distinct
			@export_id,
			site_code			
			, generator_address	
			, generator_city	
			, generator_state	
			, service_date		
			, manifest			
			, vendor			
			, type_of_service	
			, quantity			
			, filename			
		from
			#ImageExportMeta
	end		

	if @debug > 0 select datediff(ms, @operation_timer, getdate()) as operation_elapsed_ms, datediff(ms, @run_timer, getdate()) as run_elaspsed_ms, 'End of Image Meta Permanent Storage' as marker
	select @operation_timer = getdate()


--#endregion


-- Return info to user
	set nocount off

	select @export_id as export_id, file_count from plt_export..EqipImageExportHeader (nolock) where export_id = @export_id

if @debug > 0 select datediff(ms, @operation_timer, getdate()) as operation_elapsed_ms, datediff(ms, @run_timer, getdate()) as run_elaspsed_ms, 'Done' as marker
select @operation_timer = getdate()

go



go

grant execute on sp_eqip_image_export to eqweb
go
grant execute on sp_eqip_image_export to eqai
go
grant execute on sp_eqip_image_export to cor_user
go


/*


drop table if exists EQIPImageExportWalmartMeta
go

create table EQIPImageExportWalmartMeta
(
	row_id	bigint not null identity(1,1)
	, export_id bigint not null
	, [manifest number] varchar(40)
	, [service type] varchar(30)
	, [store number] varchar(16)
	, [city] varchar(40)
	, [state] char(2)
	, [zip code] varchar(15)
	, [service date] varchar(10)
	, [service provider]	varchar(20) not null
)
go
grant select, insert, update, delete on EQIPImageExportWalmartMeta to eqweb, eqai, cor_user
go

*/
