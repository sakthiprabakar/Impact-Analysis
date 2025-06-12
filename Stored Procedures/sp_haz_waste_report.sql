USE [PLT_AI]
GO
--DROP PROCEDURE IF EXISTS [dbo].[sp_haz_waste_report]
GO
/****** Object:  StoredProcedure [dbo].[sp_haz_waste_report]    Script Date: 9/27/2022 9:37:50 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[sp_haz_waste_report] 
	@company_id		int
,	@profit_ctr_id	int
,	@start_date		datetime
,	@end_date		datetime
AS
/**************************************************************************************
This SP returns the list of container waste codes

Filename:	L:\Apps\SQL\EQAI\sp_haz_waste_export.sql
PB Object(s):	r_canadian_haz_waste

02/15/2006 MK	Created
02/23/2006 RG	Modified to include subsidiary haz class
07/30/2008 JDB	Replaced Receipt.outbound_kilograms field with a calculation based
				on manifest_quantity and BillUnit.kg_conv, and renamed
				un_na_number to manifes_un_na_number.
07/31/2009 KAM Updated the report to add new fields (Company Name, manifest Number, manifest line Number,
					Outbound receipt date, Outbound receipt number, AOC#)
11/03/2010 SK	Added company_id as input argument, added joins to company_id
				moved to Plt_AI
08/23/2011 SK	Changed AOC field to Varchar(20)	
02/08/2012 SK	Added logic to bypass voided lines			
05/31/2017 AM   Added waste_list_code field.
01/15/2019 RWB	GEM-57612 Add ability to connect to new MSS 2016 servers (removed "FOR BROWSE" clause because it has been deprecated)
09/27/2022 GDE  DevOps 42753 - Canadian Hazardous Waste Export Report - Add Consent # and change prenote text
sp_haz_waste_report 26, 0, '08/1/2011', '08/20/2011'
sp_haz_waste_report 21, 0, '02/25/2017', '02/28/2017'
**************************************************************************************/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

DECLARE	
	@tsdf_code				varchar(15),
	@prenote				varchar(40),
	@un_na_number			int,
	@count					int,
	@receipt_id				int,
	@line_id				int,
	@output_company_id		int,
	@output_profit_ctr_id	int

CREATE TABLE #output (
	generator_id			int				NULL,
	generator_name			varchar(40)		NULL,
	generator_epa_id		varchar(15)		NULL,
	generator_mail_addr1	varchar(40)		null,
	generator_mail_addr2	varchar(40)		null,
	generator_city			varchar(40)		NULL,
	generator_state			char(2)			null,
	generator_zip_code		varchar(15)		null,
	tsdf_code				varchar(15)		NULL,
	tsdf_name				varchar(40)		NULL,
	tsdf_addr1				varchar(40)		NULL,
	tsdf_addr2				varchar(40)		NULL,
	tsdf_addr3				varchar(40)		NULL,
	tsdf_city				varchar(40)		NULL,
	tsdf_state				char(2)			NULL,
	tsdf_zip_code			varchar(15)		NULL,
	tsdf_epa_id				varchar(15)		NULL,
	hauler					varchar(20)		NULL,
	transporter_name		varchar(40)		NULL,
	transporter_epa_id		varchar(15)		NULL,
	prenote_canada			varchar(40)		NULL,
	un_na_number			int				NULL,
	hazmat_class			varchar(15)		NULL,
	sub_hazmat_class		varchar(15)		null,
	dot_shipping_name		varchar(255)	NULL,
	waste_codes				varchar(4099)	NULL,
	kg						int				NULL,
	receipt_date			datetime		NULL,
	receipt_id				int				NULL,
	line_id					INT				NULL,
	manifest				Varchar(15)		NULL,
	manifest_line			int				NULL,
	AOC						varchar(30)		NULL,
	company_id				int				NULL,
	profit_ctr_id			int				NULL,
	company_name			varchar(35)		NULL,
	profit_ctr_name			varchar(50)		Null,
	process_flag			int				NULL,
	waste_list_code			varchar(15)		NULL,
	consent					varchar(40)		NULL
)

INSERT #output 
	SELECT
	g.generator_id, 
	g.generator_name,
	g.epa_id,
	g.gen_mail_addr1,
	g.gen_mail_addr2,
	g.gen_mail_city,
	g.gen_mail_state,
	g.gen_mail_zip_code,
	r.tsdf_code,
	t.tsdf_name,
	t.tsdf_addr1,
	t.tsdf_addr2,
	t.tsdf_addr3,
	t.tsdf_city,
	t.tsdf_state,
	t.tsdf_zip_code,
	t.tsdf_epa_id,
	r.hauler,
	tr.transporter_name,
	tr.transporter_epa_id,
	r.prenote_canada,
	r.manifest_un_na_number,
	r.manifest_hazmat_class,
	r.manifest_sub_hazmat_class,
	Cast(r.manifest_dot_shipping_name as Varchar(255)), 
	NULL,
--	ta.export_code,
	SUM(ISNULL(r.manifest_quantity, 0.0) * ISNULL(b.kg_conv, 0.0)) AS kg,
	r.receipt_date, 
	r.receipt_id,
	r.line_id, 
	r.manifest,
	r.manifest_line,
	r.AOC,
	c.company_id,
	p.profit_ctr_id,
	c.company_name,
	p.profit_ctr_name,
	0,
	r.waste_list_code,
	r.consent
FROM Receipt r
JOIN Company c
	ON c.company_id = r.company_id
JOIN ProfitCenter p
	ON p.company_ID = r.company_id
	AND p.profit_ctr_ID = r.profit_ctr_id
INNER JOIN TSDF t 
	ON r.tsdf_code = t.tsdf_code
	AND LEFT(t.tsdf_zip_code,1) BETWEEN 'a' AND 'Z'
INNER JOIN Generator g 
	ON r.generator_id = g.generator_id
INNER JOIN Transporter tr 
	ON r.hauler = tr.transporter_code
INNER JOIN BillUnit b 
	ON r.manifest_unit = b.manifest_unit
WHERE	r.trans_mode = 'O'
	AND r.receipt_status = 'A'
	AND r.fingerpr_status <> 'V'
	AND r.company_id = @company_id
	AND r.profit_ctr_id = @profit_ctr_id
	AND r.receipt_date Between @start_date AND @end_date
Group BY	
	g.generator_id, 
	g.generator_name,
	g.epa_id,
	g.gen_mail_addr1,
	g.gen_mail_addr2,
	g.gen_mail_city,
	g.gen_mail_state,
	g.gen_mail_zip_code,
	r.tsdf_code,
	t.tsdf_name,
	t.tsdf_addr1,
	t.tsdf_addr2,
	t.tsdf_addr3,
	t.tsdf_city,
	t.tsdf_state,
	t.tsdf_zip_code,
	t.tsdf_epa_id,
	r.hauler,
	tr.transporter_name,
	tr.transporter_epa_id,
	r.prenote_canada,
	r.manifest_un_na_number,
	r.manifest_hazmat_class,
	r.manifest_sub_hazmat_class,
	Cast(r.manifest_dot_shipping_name as Varchar(255)),
	r.receipt_date, 
	r.receipt_id,
	r.line_id, 
	r.manifest,
	r.manifest_line,
	r.AOC,
	c.company_id,
	p.profit_ctr_id,
	c.company_name,
	p.profit_ctr_name,
	r.waste_list_code,
	r.consent


SELECT @count = @@ROWCOUNT

SET ROWCOUNT 1
WHILE @count > 0
BEGIN
	SELECT @tsdf_code = tsdf_code,
		@prenote = prenote_canada, 
		@un_na_number = un_na_number,
		@receipt_id = receipt_id,
		@line_id = line_id,
		@output_company_id = company_id,
		@output_profit_ctr_id = profit_ctr_id
	FROM #output where process_flag = 0

	-- Get the waste codes for this line
	EXEC sp_haz_waste_report_waste_list @output_company_id, @output_profit_ctr_id, @receipt_id, @line_id
	
	SET @count = @count - 1
	UPDATE #output SET process_flag = 1 where process_flag = 0
END

SET ROWCOUNT 0
SELECT * FROM #output	
GO
GRANT EXECUTE
	ON [dbo].[sp_haz_waste_report]
	TO [EQAI]
GO