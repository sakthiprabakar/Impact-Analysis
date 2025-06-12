/* 6/21/2019 - JPB Commented because VS flips out on it.


CREATE PROCEDURE sp_biennial_report_output_extract_IL
	@biennial_id int,
	@report_to_output varchar(20) = 'WR1',
	@fill_from_source_table varchar(1) = 'T'
AS

/*
	Usage: 
		exec sp_biennial_report_output_extract_IL 1452, 'WR1', 'T'
		exec sp_biennial_report_output_extract_IL 1452, 'GM1', 'T'

		SELECT * FROM eq_temp..sp_biennial_report_output_extract_IL_WR1		
		SELECT * FROM eq_temp..sp_biennial_report_output_extract_IL_GM1		

		exec sp_biennial_report_output_extract_IL 339, 'C', 'T'
		SELECT * FROM eq_temp..sp_biennial_IL_WR1_comments
		
		
		2012-10-03 - JPB - Stripped decimal points out of numbers per Hope Wright @ IL EPA.
			207.5 lbs should be 0000002075
			Weird.
	
*/

BEGIN
SET NOCOUNT ON

if @fill_from_source_table = 'T'
begin
	-- clear out old data
	delete from EQ_Extract..BiennialReportWork_IL_GM1 where biennial_id <> @biennial_id
	delete from EQ_Extract..BiennialReportWork_IL_GM2 where biennial_id <> @biennial_id
	delete from EQ_Extract..BiennialReportWork_IL_WR1 where biennial_id <> @biennial_id
	delete from EQ_Extract..BiennialReportWork_IL_WR2 where biennial_id <> @biennial_id

	-- populate work table data for this run
	exec sp_biennial_report_output_IL_GM @biennial_id
	exec sp_biennial_report_output_IL_WR @biennial_id
end

DECLARE @reports TABLE (report_name varchar(20))

INSERT INTO @reports
	SELECT row FROM dbo.fn_splitxsvtext(',', 1, @report_to_output) WHERE Isnull(row, '') <> ''

if EXISTS(SELECT 1 FROM @reports where report_name = 'GM1')
BEGIN


	if object_id('eq_temp..sp_biennial_report_output_extract_IL_GM1') is not null drop table eq_temp..sp_biennial_report_output_extract_IL_GM1


	-- dbo.fn_get_IL_biennial_GM_waste_code (1, 1452, 2)
	SELECT DISTINCT
	CONVERT(VARCHAR(290),
		EQ_Extract.dbo.fn_space_delimit('12', HANDLER_ID) + 
		EQ_Extract.dbo.fn_space_delimit('5R', HZ_PG) + 
--		EQ_Extract.dbo.fn_space_delimit('1', HZ_PG) + 
		SPACE(3) + -- Filler1
		EQ_Extract.dbo.fn_space_delimit('10', EQ_STATE_ID) + 
		EQ_Extract.dbo.fn_space_delimit('4', dbo.fn_get_IL_biennial_GM_waste_code (hz_pg_tmp, biennial_id, 1)) +
		EQ_Extract.dbo.fn_space_delimit('4', dbo.fn_get_IL_biennial_GM_waste_code (hz_pg_tmp, biennial_id, 2)) +
		EQ_Extract.dbo.fn_space_delimit('4', dbo.fn_get_IL_biennial_GM_waste_code (hz_pg_tmp, biennial_id, 3)) +
		EQ_Extract.dbo.fn_space_delimit('4', dbo.fn_get_IL_biennial_GM_waste_code (hz_pg_tmp, biennial_id, 4)) +
		EQ_Extract.dbo.fn_space_delimit('4', dbo.fn_get_IL_biennial_GM_waste_code (hz_pg_tmp, biennial_id, 5)) +
		EQ_Extract.dbo.fn_space_delimit('3', SOURCE_CODE) + 
		EQ_Extract.dbo.fn_space_delimit('4', ORIGIN_MANAGEMENT_METHOD) + 
		EQ_Extract.dbo.fn_space_delimit('4', FORM_CODE) + 
		EQ_Extract.dbo.fn_space_delimit('1', WASTE_MINIMIZATION_CODE) + 
		EQ_Extract.dbo.fn_space_delimit('1', UNIT_OF_MEASURE) + 
		REPLACE(EQ_Extract.dbo.fn_space_delimit('4', replace(WST_DENSITY, '.', '')), ' ', '0') + 
		REPLACE(EQ_Extract.dbo.fn_space_delimit('10R', replace(convert(decimal(10,1), IO_TDR_QTY), '.', '')), ' ', '0') + 
		EQ_Extract.dbo.fn_space_delimit('1', ON_SITE_MANAGEMENT) + 
		SPACE(4) + -- ON_SITE_MANAGEMENT_METHOD_SITE_1
		SPACE(10) + -- QTY_MANAGED_ON_SITE_1
		SPACE(4) + -- ON_SITE_MANAGEMENT_METHOD_SITE_2
		SPACE(10) + -- QTY_MANAGED_ON_SITE_2
		EQ_Extract.dbo.fn_space_delimit('1', OFF_SITE_SHIPMENT) + 
		EQ_Extract.dbo.fn_space_delimit('12', SITE_1_US_EPAID_NUMBER) + 
		EQ_Extract.dbo.fn_space_delimit('4', SITE_1_MANAGEMENT_METHOD) + 
		REPLACE(EQ_Extract.dbo.fn_space_delimit('10R', REPLACE(SITE_1_TOTAL_QUANTITY_SHIPPED, '.', '')), ' ', '0') + 
		SPACE(12) + -- SITE_2_US_EPAID_NUMBER
		SPACE(4) + -- SITE_2_MANAGEMENT_METHOD
		SPACE(10) + -- SITE_2_TOTAL_QUANTITY_SHIPPED
		SPACE(12) + -- SITE_3_US_EPAID_NUMBER
		SPACE(4) + -- SITE_3_MANAGEMENT_METHOD
		SPACE(10) + -- SITE_3_TOTAL_QUANTITY_SHIPPED
		SPACE(12) + -- SITE_4_US_EPAID_NUMBER
		SPACE(4) + -- SITE_4_MANAGEMENT_METHOD
		SPACE(10) + -- SITE_4_TOTAL_QUANTITY_SHIPPED
		SPACE(12) + -- SITE_5_US_EPAID_NUMBER
		SPACE(4) + -- SITE_5_MANAGEMENT_METHOD
		SPACE(10) + -- SITE_5_TOTAL_QUANTITY_SHIPPED
		'N' + -- COMMENTS_INDICATOR			
		SPACE(1) + -- FILLER2
		EQ_Extract.dbo.fn_space_delimit('50', DESCRIPTION)
	) as [Result]
	INTO eq_temp..sp_biennial_report_output_extract_IL_GM1
	FROM EQ_Extract..BiennialReportWork_IL_GM1
	where biennial_id = @biennial_id



END


if EXISTS(SELECT 1 FROM @reports where report_name = 'WR1')
or EXISTS(SELECT 1 FROM @reports where report_name = 'C')
BEGIN
	
	declare @loop int = 0

	if object_id('tempdb..#tmp') is not null drop table #tmp

	SELECT * INTO #tmp FROM 
	(
	SELECT 
	US_EPA_ID = WR1.EQ_EPA_ID,
	PAGE_NUM = wr1.hz_pg_tmp,
	FILLER0 = space(1),
	wr1.EQ_STATE_ID,
	GEN_US_EPA_ID = wr1.gen_epa_id,
	wr1.GEN_STATE_EPA_ID, --wr1.generator_state_id,
	ds1.approval_code,
	ds1.hz_pg_tmp,
	ds1.hz_ln_tmp,
	WASTE1_WC1 = EQ_Extract.dbo.fn_get_IL_biennial_waste_code (ds1.hz_pg_tmp, ds1.hz_ln_tmp, 1, ds1.biennial_id, ds1.gen_epa_id, ds1.approval_code),
	WASTE1_WC2 = EQ_Extract.dbo.fn_get_IL_biennial_waste_code (ds1.hz_pg_tmp, ds1.hz_ln_tmp, 2, ds1.biennial_id, ds1.gen_epa_id, ds1.approval_code),
	WASTE1_WC3 = EQ_Extract.dbo.fn_get_IL_biennial_waste_code (ds1.hz_pg_tmp, ds1.hz_ln_tmp, 3, ds1.biennial_id, ds1.gen_epa_id, ds1.approval_code),
	WASTE1_WC4 = EQ_Extract.dbo.fn_get_IL_biennial_waste_code (ds1.hz_pg_tmp, ds1.hz_ln_tmp, 4, ds1.biennial_id, ds1.gen_epa_id, ds1.approval_code),
	WASTE1_WC5 = EQ_Extract.dbo.fn_get_IL_biennial_waste_code (ds1.hz_pg_tmp, ds1.hz_ln_tmp, 5, ds1.biennial_id, ds1.gen_epa_id, ds1.approval_code),
	WASTE1_QTY = ds1.GEN_QUANTITY,
	WASTE1_UOM = ds1.UNIT_OF_MEASURE,
	WASTE1_DENSITY = ds1.WASTE_DENSITY,
	WASTE1_FORM_CODE = ds1.FORM_CODE,
	FILLER1 = space(1),
	ds1.MANAGEMENT_METHOD as WASTE1_MANAGEMENT_METHOD,
	WASTE2_WC1 = EQ_Extract.dbo.fn_get_IL_biennial_waste_code (ds2.hz_pg_tmp, ds2.hz_ln_tmp, 1, ds2.biennial_id, ds2.gen_epa_id, ds2.approval_code),
	WASTE2_WC2 = EQ_Extract.dbo.fn_get_IL_biennial_waste_code (ds2.hz_pg_tmp, ds2.hz_ln_tmp, 2, ds2.biennial_id, ds2.gen_epa_id, ds2.approval_code),
	WASTE2_WC3 = EQ_Extract.dbo.fn_get_IL_biennial_waste_code (ds2.hz_pg_tmp, ds2.hz_ln_tmp, 3, ds2.biennial_id, ds2.gen_epa_id, ds2.approval_code),
	WASTE2_WC4 = EQ_Extract.dbo.fn_get_IL_biennial_waste_code (ds2.hz_pg_tmp, ds2.hz_ln_tmp, 4, ds2.biennial_id, ds2.gen_epa_id, ds2.approval_code),
	WASTE2_WC5 = EQ_Extract.dbo.fn_get_IL_biennial_waste_code (ds2.hz_pg_tmp, ds2.hz_ln_tmp, 5, ds2.biennial_id, ds2.gen_epa_id, ds2.approval_code),
	WASTE2_QTY = ds2.GEN_QUANTITY,
	WASTE2_UOM = ds2.UNIT_OF_MEASURE,
	WASTE2_DENSITY = ds2.WASTE_DENSITY,
	WASTE2_FORM_CODE = ds2.FORM_CODE,
	FILLER2 = space(1),
	ds2.MANAGEMENT_METHOD as WASTE2_MANAGEMENT_METHOD,
	WASTE3_WC1 = EQ_Extract.dbo.fn_get_IL_biennial_waste_code (ds3.hz_pg_tmp, ds3.hz_ln_tmp, 1, ds3.biennial_id, ds3.gen_epa_id, ds3.approval_code),
	WASTE3_WC2 = EQ_Extract.dbo.fn_get_IL_biennial_waste_code (ds3.hz_pg_tmp, ds3.hz_ln_tmp, 2, ds3.biennial_id, ds3.gen_epa_id, ds3.approval_code),
	WASTE3_WC3 = EQ_Extract.dbo.fn_get_IL_biennial_waste_code (ds3.hz_pg_tmp, ds3.hz_ln_tmp, 3, ds3.biennial_id, ds3.gen_epa_id, ds3.approval_code),
	WASTE3_WC4 = EQ_Extract.dbo.fn_get_IL_biennial_waste_code (ds3.hz_pg_tmp, ds3.hz_ln_tmp, 4, ds3.biennial_id, ds3.gen_epa_id, ds3.approval_code),
	WASTE3_WC5 = EQ_Extract.dbo.fn_get_IL_biennial_waste_code (ds3.hz_pg_tmp, ds3.hz_ln_tmp, 5, ds3.biennial_id, ds3.gen_epa_id, ds3.approval_code),
	WASTE3_QTY = ds3.GEN_QUANTITY,
	WASTE3_UOM = ds3.UNIT_OF_MEASURE,
	WASTE3_DENSITY = ds3.WASTE_DENSITY,
	WASTE3_FORM_CODE = ds3.FORM_CODE,
	FILLER3 = space(1),
	ds3.MANAGEMENT_METHOD as WASTE3_MANAGEMENT_METHOD,
	WASTE4_WC1 = EQ_Extract.dbo.fn_get_IL_biennial_waste_code (ds4.hz_pg_tmp, ds4.hz_ln_tmp, 1, ds4.biennial_id, ds4.gen_epa_id, ds4.approval_code),
	WASTE4_WC2 = EQ_Extract.dbo.fn_get_IL_biennial_waste_code (ds4.hz_pg_tmp, ds4.hz_ln_tmp, 2, ds4.biennial_id, ds4.gen_epa_id, ds4.approval_code),
	WASTE4_WC3 = EQ_Extract.dbo.fn_get_IL_biennial_waste_code (ds4.hz_pg_tmp, ds4.hz_ln_tmp, 3, ds4.biennial_id, ds4.gen_epa_id, ds4.approval_code),
	WASTE4_WC4 = EQ_Extract.dbo.fn_get_IL_biennial_waste_code (ds4.hz_pg_tmp, ds4.hz_ln_tmp, 4, ds4.biennial_id, ds4.gen_epa_id, ds4.approval_code),
	WASTE4_WC5 = EQ_Extract.dbo.fn_get_IL_biennial_waste_code (ds4.hz_pg_tmp, ds4.hz_ln_tmp, 5, ds4.biennial_id, ds4.gen_epa_id, ds4.approval_code),
	WASTE4_QTY = ds4.GEN_QUANTITY,
	WASTE4_UOM = ds4.UNIT_OF_MEASURE,
	WASTE4_DENSITY = ds4.WASTE_DENSITY,
	WASTE4_FORM_CODE = ds4.FORM_CODE,
	FILLER4 = space(1),
	ds4.MANAGEMENT_METHOD as WASTE4_MANAGEMENT_METHOD,
	WASTE5_WC1 = EQ_Extract.dbo.fn_get_IL_biennial_waste_code (ds5.hz_pg_tmp, ds5.hz_ln_tmp, 1, ds5.biennial_id, ds5.gen_epa_id, ds5.approval_code),
	WASTE5_WC2 = EQ_Extract.dbo.fn_get_IL_biennial_waste_code (ds5.hz_pg_tmp, ds5.hz_ln_tmp, 2, ds5.biennial_id, ds5.gen_epa_id, ds5.approval_code),
	WASTE5_WC3 = EQ_Extract.dbo.fn_get_IL_biennial_waste_code (ds5.hz_pg_tmp, ds5.hz_ln_tmp, 3, ds5.biennial_id, ds5.gen_epa_id, ds5.approval_code),
	WASTE5_WC4 = EQ_Extract.dbo.fn_get_IL_biennial_waste_code (ds5.hz_pg_tmp, ds5.hz_ln_tmp, 4, ds5.biennial_id, ds5.gen_epa_id, ds5.approval_code),
	WASTE5_WC5 = EQ_Extract.dbo.fn_get_IL_biennial_waste_code (ds5.hz_pg_tmp, ds5.hz_ln_tmp, 5, ds5.biennial_id, ds5.gen_epa_id, ds5.approval_code),
	WASTE5_QTY = ds5.GEN_QUANTITY,
	WASTE5_UOM = ds5.UNIT_OF_MEASURE,
	WASTE5_DENSITY = ds5.WASTE_DENSITY,
	WASTE5_FORM_CODE = ds5.FORM_CODE,
	FILLER5 = space(1),
	ds5.MANAGEMENT_METHOD as WASTE5_MANAGEMENT_METHOD,
	COMMENTS = 'N',
	FILLER6 = space(1)
	FROM
	EQ_Extract..BiennialReportWork_IL_WR1 wr1
		LEFT JOIN EQ_Extract..BiennialReportWork_IL_WR1 ds1 ON ds1.biennial_id = wr1.biennial_id
			and ds1.GEN_EPA_ID = wr1.GEN_EPA_ID
			-- and ds1.approval_code = wr1.approval_code
			and ds1.hz_pg_tmp = wr1.hz_pg_tmp
			and ds1.hz_ln_tmp = 1
	LEFT JOIN EQ_Extract..BiennialReportWork_IL_WR1 ds2 ON ds2.biennial_id = wr1.biennial_id
			and ds2.GEN_EPA_ID = wr1.GEN_EPA_ID
			-- and ds2.approval_code = wr1.approval_code
			and ds2.hz_pg_tmp = wr1.hz_pg_tmp
			and ds2.hz_ln_tmp = 2
	LEFT JOIN EQ_Extract..BiennialReportWork_IL_WR1 ds3 ON ds3.biennial_id = wr1.biennial_id
			and ds3.GEN_EPA_ID = wr1.GEN_EPA_ID
			-- and ds3.approval_code = wr1.approval_code
			and ds3.hz_pg_tmp = wr1.hz_pg_tmp
			and ds3.hz_ln_tmp = 3
	LEFT JOIN EQ_Extract..BiennialReportWork_IL_WR1 ds4 ON ds4.biennial_id = wr1.biennial_id
			and ds4.GEN_EPA_ID = wr1.GEN_EPA_ID
			-- and ds4.approval_code = wr1.approval_code
			and ds4.hz_pg_tmp = wr1.hz_pg_tmp
			and ds4.hz_ln_tmp = 4
	LEFT JOIN EQ_Extract..BiennialReportWork_IL_WR1 ds5 ON ds5.biennial_id = wr1.biennial_id
			and ds5.GEN_EPA_ID = wr1.GEN_EPA_ID
			-- and ds5.approval_code = wr1.approval_code
			and ds5.hz_pg_tmp = wr1.hz_pg_tmp
			and ds5.hz_ln_tmp = 5		
	WHERE wr1.hz_pg_tmp = 1
	and wr1.hz_ln_tmp = 1
	and wr1.biennial_id = @biennial_id

	UNION

	SELECT US_EPA_ID = WR1.EQ_EPA_ID,
	PAGE_NUM = wr1.hz_pg_tmp,
	FILLER0 = space(1),
	wr1.EQ_STATE_ID,
	GEN_US_EPA_ID = wr1.gen_epa_id,
	wr1.GEN_STATE_EPA_ID, --wr1.generator_state_id,
	ds2.approval_code,
	ds2.hz_pg_tmp,
	ds2.hz_ln_tmp,
	WASTE1_WC1 = EQ_Extract.dbo.fn_get_IL_biennial_waste_code (ds1.hz_pg_tmp, ds1.hz_ln_tmp, 1, ds1.biennial_id, ds1.gen_epa_id, ds1.approval_code),
	WASTE1_WC2 = EQ_Extract.dbo.fn_get_IL_biennial_waste_code (ds1.hz_pg_tmp, ds1.hz_ln_tmp, 2, ds1.biennial_id, ds1.gen_epa_id, ds1.approval_code),
	WASTE1_WC3 = EQ_Extract.dbo.fn_get_IL_biennial_waste_code (ds1.hz_pg_tmp, ds1.hz_ln_tmp, 3, ds1.biennial_id, ds1.gen_epa_id, ds1.approval_code),
	WASTE1_WC4 = EQ_Extract.dbo.fn_get_IL_biennial_waste_code (ds1.hz_pg_tmp, ds1.hz_ln_tmp, 4, ds1.biennial_id, ds1.gen_epa_id, ds1.approval_code),
	WASTE1_WC5 = EQ_Extract.dbo.fn_get_IL_biennial_waste_code (ds1.hz_pg_tmp, ds1.hz_ln_tmp, 5, ds1.biennial_id, ds1.gen_epa_id, ds1.approval_code),
	WASTE1_QTY = ds1.GEN_QUANTITY,
	WASTE1_UOM = ds1.UNIT_OF_MEASURE,
	WASTE1_DENSITY = ds1.WASTE_DENSITY,
	WASTE1_FORM_CODE = ds1.FORM_CODE,
	FILLER1 = space(1),
	ds1.MANAGEMENT_METHOD,
	WASTE2_WC1 = EQ_Extract.dbo.fn_get_IL_biennial_waste_code (ds2.hz_pg_tmp, ds2.hz_ln_tmp, 1, ds2.biennial_id, ds2.gen_epa_id, ds2.approval_code),
	WASTE2_WC2 = EQ_Extract.dbo.fn_get_IL_biennial_waste_code (ds2.hz_pg_tmp, ds2.hz_ln_tmp, 2, ds2.biennial_id, ds2.gen_epa_id, ds2.approval_code),
	WASTE2_WC3 = EQ_Extract.dbo.fn_get_IL_biennial_waste_code (ds2.hz_pg_tmp, ds2.hz_ln_tmp, 3, ds2.biennial_id, ds2.gen_epa_id, ds2.approval_code),
	WASTE2_WC4 = EQ_Extract.dbo.fn_get_IL_biennial_waste_code (ds2.hz_pg_tmp, ds2.hz_ln_tmp, 4, ds2.biennial_id, ds2.gen_epa_id, ds2.approval_code),
	WASTE2_WC5 = EQ_Extract.dbo.fn_get_IL_biennial_waste_code (ds2.hz_pg_tmp, ds2.hz_ln_tmp, 5, ds2.biennial_id, ds2.gen_epa_id, ds2.approval_code),
	WASTE2_QTY = ds2.GEN_QUANTITY,
	WASTE2_UOM = ds2.UNIT_OF_MEASURE,
	WASTE2_DENSITY = ds2.WASTE_DENSITY,
	WASTE2_FORM_CODE = ds2.FORM_CODE,
	FILLER2 = space(1),
	ds2.MANAGEMENT_METHOD,
	WASTE3_WC1 = EQ_Extract.dbo.fn_get_IL_biennial_waste_code (ds3.hz_pg_tmp, ds3.hz_ln_tmp, 1, ds3.biennial_id, ds3.gen_epa_id, ds3.approval_code),
	WASTE3_WC2 = EQ_Extract.dbo.fn_get_IL_biennial_waste_code (ds3.hz_pg_tmp, ds3.hz_ln_tmp, 2, ds3.biennial_id, ds3.gen_epa_id, ds3.approval_code),
	WASTE3_WC3 = EQ_Extract.dbo.fn_get_IL_biennial_waste_code (ds3.hz_pg_tmp, ds3.hz_ln_tmp, 3, ds3.biennial_id, ds3.gen_epa_id, ds3.approval_code),
	WASTE3_WC4 = EQ_Extract.dbo.fn_get_IL_biennial_waste_code (ds3.hz_pg_tmp, ds3.hz_ln_tmp, 4, ds3.biennial_id, ds3.gen_epa_id, ds3.approval_code),
	WASTE3_WC5 = EQ_Extract.dbo.fn_get_IL_biennial_waste_code (ds3.hz_pg_tmp, ds3.hz_ln_tmp, 5, ds3.biennial_id, ds3.gen_epa_id, ds3.approval_code),
	WASTE3_QTY = ds3.GEN_QUANTITY,
	WASTE3_UOM = ds3.UNIT_OF_MEASURE,
	WASTE3_DENSITY = ds3.WASTE_DENSITY,
	WASTE3_FORM_CODE = ds3.FORM_CODE,
	FILLER3 = space(1),
	ds3.MANAGEMENT_METHOD,
	WASTE4_WC1 = EQ_Extract.dbo.fn_get_IL_biennial_waste_code (ds4.hz_pg_tmp, ds4.hz_ln_tmp, 1, ds4.biennial_id, ds4.gen_epa_id, ds4.approval_code),
	WASTE4_WC2 = EQ_Extract.dbo.fn_get_IL_biennial_waste_code (ds4.hz_pg_tmp, ds4.hz_ln_tmp, 2, ds4.biennial_id, ds4.gen_epa_id, ds4.approval_code),
	WASTE4_WC3 = EQ_Extract.dbo.fn_get_IL_biennial_waste_code (ds4.hz_pg_tmp, ds4.hz_ln_tmp, 3, ds4.biennial_id, ds4.gen_epa_id, ds4.approval_code),
	WASTE4_WC4 = EQ_Extract.dbo.fn_get_IL_biennial_waste_code (ds4.hz_pg_tmp, ds4.hz_ln_tmp, 4, ds4.biennial_id, ds4.gen_epa_id, ds4.approval_code),
	WASTE4_WC5 = EQ_Extract.dbo.fn_get_IL_biennial_waste_code (ds4.hz_pg_tmp, ds4.hz_ln_tmp, 5, ds4.biennial_id, ds4.gen_epa_id, ds4.approval_code),
	WASTE4_QTY = ds4.GEN_QUANTITY,
	WASTE4_UOM = ds4.UNIT_OF_MEASURE,
	WASTE4_DENSITY = ds4.WASTE_DENSITY,
	WASTE4_FORM_CODE = ds4.FORM_CODE,
	FILLER4 = space(1),
	ds4.MANAGEMENT_METHOD,
	WASTE5_WC1 = EQ_Extract.dbo.fn_get_IL_biennial_waste_code (ds5.hz_pg_tmp, ds5.hz_ln_tmp, 1, ds5.biennial_id, ds5.gen_epa_id, ds5.approval_code),
	WASTE5_WC2 = EQ_Extract.dbo.fn_get_IL_biennial_waste_code (ds5.hz_pg_tmp, ds5.hz_ln_tmp, 2, ds5.biennial_id, ds5.gen_epa_id, ds5.approval_code),
	WASTE5_WC3 = EQ_Extract.dbo.fn_get_IL_biennial_waste_code (ds5.hz_pg_tmp, ds5.hz_ln_tmp, 3, ds5.biennial_id, ds5.gen_epa_id, ds5.approval_code),
	WASTE5_WC4 = EQ_Extract.dbo.fn_get_IL_biennial_waste_code (ds5.hz_pg_tmp, ds5.hz_ln_tmp, 4, ds5.biennial_id, ds5.gen_epa_id, ds5.approval_code),
	WASTE5_WC5 = EQ_Extract.dbo.fn_get_IL_biennial_waste_code (ds5.hz_pg_tmp, ds5.hz_ln_tmp, 5, ds5.biennial_id, ds5.gen_epa_id, ds5.approval_code),
	WASTE5_QTY = ds5.GEN_QUANTITY,
	WASTE5_UOM = ds5.UNIT_OF_MEASURE,
	WASTE5_DENSITY = ds5.WASTE_DENSITY,
	WASTE5_FORM_CODE = ds5.FORM_CODE,
	FILLER5 = space(1),
	WASTE5_SYS_TYPE = '',
	COMMENTS = 'N',
	FILLER6 = space(1)
	FROM
	EQ_Extract..BiennialReportWork_IL_WR1 wr1
		LEFT JOIN EQ_Extract..BiennialReportWork_IL_WR1 ds1 ON ds1.biennial_id = wr1.biennial_id
			and ds1.GEN_EPA_ID = wr1.GEN_EPA_ID
			-- and ds1.approval_code = wr1.approval_code
			and ds1.hz_pg_tmp = wr1.hz_pg_tmp
			and ds1.hz_ln_tmp = 1
	LEFT JOIN EQ_Extract..BiennialReportWork_IL_WR1 ds2 ON ds2.biennial_id = wr1.biennial_id
			and ds2.GEN_EPA_ID = wr1.GEN_EPA_ID
			-- and ds2.approval_code = wr1.approval_code
			and ds2.hz_pg_tmp = wr1.hz_pg_tmp
			and ds2.hz_ln_tmp = 2
	LEFT JOIN EQ_Extract..BiennialReportWork_IL_WR1 ds3 ON ds3.biennial_id = wr1.biennial_id
			and ds3.GEN_EPA_ID = wr1.GEN_EPA_ID
			-- and ds3.approval_code = wr1.approval_code
			and ds3.hz_pg_tmp = wr1.hz_pg_tmp
			and ds3.hz_ln_tmp = 3
	LEFT JOIN EQ_Extract..BiennialReportWork_IL_WR1 ds4 ON ds4.biennial_id = wr1.biennial_id
			and ds4.GEN_EPA_ID = wr1.GEN_EPA_ID
			-- and ds4.approval_code = wr1.approval_code
			and ds4.hz_pg_tmp = wr1.hz_pg_tmp
			and ds4.hz_ln_tmp = 4
	LEFT JOIN EQ_Extract..BiennialReportWork_IL_WR1 ds5 ON ds5.biennial_id = wr1.biennial_id
			and ds5.GEN_EPA_ID = wr1.GEN_EPA_ID
			-- and ds5.approval_code = wr1.approval_code
			and ds5.hz_pg_tmp = wr1.hz_pg_tmp
			and ds5.hz_ln_tmp = 5		
	WHERE wr1.hz_pg_tmp = 2
	and wr1.hz_ln_tmp = 1
	and wr1.biennial_id = @biennial_id

	UNION

	SELECT US_EPA_ID = WR1.EQ_EPA_ID,
	PAGE_NUM = wr1.hz_pg_tmp,
	FILLER0 = space(1),
	wr1.EQ_STATE_ID,
	GEN_US_EPA_ID = wr1.gen_epa_id,
	wr1.GEN_STATE_EPA_ID, --wr1.generator_state_id,
	ds3.approval_code,
	ds3.hz_pg_tmp,
	ds3.hz_ln_tmp,
	WASTE1_WC1 = EQ_Extract.dbo.fn_get_IL_biennial_waste_code (ds1.hz_pg_tmp, ds1.hz_ln_tmp, 1, ds1.biennial_id, ds1.gen_epa_id, ds1.approval_code),
	WASTE1_WC2 = EQ_Extract.dbo.fn_get_IL_biennial_waste_code (ds1.hz_pg_tmp, ds1.hz_ln_tmp, 2, ds1.biennial_id, ds1.gen_epa_id, ds1.approval_code),
	WASTE1_WC3 = EQ_Extract.dbo.fn_get_IL_biennial_waste_code (ds1.hz_pg_tmp, ds1.hz_ln_tmp, 3, ds1.biennial_id, ds1.gen_epa_id, ds1.approval_code),
	WASTE1_WC4 = EQ_Extract.dbo.fn_get_IL_biennial_waste_code (ds1.hz_pg_tmp, ds1.hz_ln_tmp, 4, ds1.biennial_id, ds1.gen_epa_id, ds1.approval_code),
	WASTE1_WC5 = EQ_Extract.dbo.fn_get_IL_biennial_waste_code (ds1.hz_pg_tmp, ds1.hz_ln_tmp, 5, ds1.biennial_id, ds1.gen_epa_id, ds1.approval_code),
	WASTE1_QTY = ds1.GEN_QUANTITY,
	WASTE1_UOM = ds1.UNIT_OF_MEASURE,
	WASTE1_DENSITY = ds1.WASTE_DENSITY,
	WASTE1_FORM_CODE = ds1.FORM_CODE,
	FILLER1 = space(1),
	ds1.MANAGEMENT_METHOD,
	WASTE2_WC1 = EQ_Extract.dbo.fn_get_IL_biennial_waste_code (ds2.hz_pg_tmp, ds2.hz_ln_tmp, 1, ds2.biennial_id, ds2.gen_epa_id, ds2.approval_code),
	WASTE2_WC2 = EQ_Extract.dbo.fn_get_IL_biennial_waste_code (ds2.hz_pg_tmp, ds2.hz_ln_tmp, 2, ds2.biennial_id, ds2.gen_epa_id, ds2.approval_code),
	WASTE2_WC3 = EQ_Extract.dbo.fn_get_IL_biennial_waste_code (ds2.hz_pg_tmp, ds2.hz_ln_tmp, 3, ds2.biennial_id, ds2.gen_epa_id, ds2.approval_code),
	WASTE2_WC4 = EQ_Extract.dbo.fn_get_IL_biennial_waste_code (ds2.hz_pg_tmp, ds2.hz_ln_tmp, 4, ds2.biennial_id, ds2.gen_epa_id, ds2.approval_code),
	WASTE2_WC5 = EQ_Extract.dbo.fn_get_IL_biennial_waste_code (ds2.hz_pg_tmp, ds2.hz_ln_tmp, 5, ds2.biennial_id, ds2.gen_epa_id, ds2.approval_code),
	WASTE2_QTY = ds2.GEN_QUANTITY,
	WASTE2_UOM = ds2.UNIT_OF_MEASURE,
	WASTE2_DENSITY = ds2.WASTE_DENSITY,
	WASTE2_FORM_CODE = ds2.FORM_CODE,
	FILLER2 = space(1),
	ds2.MANAGEMENT_METHOD,
	WASTE3_WC1 = EQ_Extract.dbo.fn_get_IL_biennial_waste_code (ds3.hz_pg_tmp, ds3.hz_ln_tmp, 1, ds3.biennial_id, ds3.gen_epa_id, ds3.approval_code),
	WASTE3_WC2 = EQ_Extract.dbo.fn_get_IL_biennial_waste_code (ds3.hz_pg_tmp, ds3.hz_ln_tmp, 2, ds3.biennial_id, ds3.gen_epa_id, ds3.approval_code),
	WASTE3_WC3 = EQ_Extract.dbo.fn_get_IL_biennial_waste_code (ds3.hz_pg_tmp, ds3.hz_ln_tmp, 3, ds3.biennial_id, ds3.gen_epa_id, ds3.approval_code),
	WASTE3_WC4 = EQ_Extract.dbo.fn_get_IL_biennial_waste_code (ds3.hz_pg_tmp, ds3.hz_ln_tmp, 4, ds3.biennial_id, ds3.gen_epa_id, ds3.approval_code),
	WASTE3_WC5 = EQ_Extract.dbo.fn_get_IL_biennial_waste_code (ds3.hz_pg_tmp, ds3.hz_ln_tmp, 5, ds3.biennial_id, ds3.gen_epa_id, ds3.approval_code),
	WASTE3_QTY = ds3.GEN_QUANTITY,
	WASTE3_UOM = ds3.UNIT_OF_MEASURE,
	WASTE3_DENSITY = ds3.WASTE_DENSITY,
	WASTE3_FORM_CODE = ds3.FORM_CODE,
	FILLER3 = space(1),
	ds3.MANAGEMENT_METHOD,
	WASTE4_WC1 = EQ_Extract.dbo.fn_get_IL_biennial_waste_code (ds4.hz_pg_tmp, ds4.hz_ln_tmp, 1, ds4.biennial_id, ds4.gen_epa_id, ds4.approval_code),
	WASTE4_WC2 = EQ_Extract.dbo.fn_get_IL_biennial_waste_code (ds4.hz_pg_tmp, ds4.hz_ln_tmp, 2, ds4.biennial_id, ds4.gen_epa_id, ds4.approval_code),
	WASTE4_WC3 = EQ_Extract.dbo.fn_get_IL_biennial_waste_code (ds4.hz_pg_tmp, ds4.hz_ln_tmp, 3, ds4.biennial_id, ds4.gen_epa_id, ds4.approval_code),
	WASTE4_WC4 = EQ_Extract.dbo.fn_get_IL_biennial_waste_code (ds4.hz_pg_tmp, ds4.hz_ln_tmp, 4, ds4.biennial_id, ds4.gen_epa_id, ds4.approval_code),
	WASTE4_WC5 = EQ_Extract.dbo.fn_get_IL_biennial_waste_code (ds4.hz_pg_tmp, ds4.hz_ln_tmp, 5, ds4.biennial_id, ds4.gen_epa_id, ds4.approval_code),
	WASTE4_QTY = ds4.GEN_QUANTITY,
	WASTE4_UOM = ds4.UNIT_OF_MEASURE,
	WASTE4_DENSITY = ds4.WASTE_DENSITY,
	WASTE4_FORM_CODE = ds4.FORM_CODE,
	FILLER4 = space(1),
	ds4.MANAGEMENT_METHOD,
	WASTE5_WC1 = EQ_Extract.dbo.fn_get_IL_biennial_waste_code (ds5.hz_pg_tmp, ds5.hz_ln_tmp, 1, ds5.biennial_id, ds5.gen_epa_id, ds5.approval_code),
	WASTE5_WC2 = EQ_Extract.dbo.fn_get_IL_biennial_waste_code (ds5.hz_pg_tmp, ds5.hz_ln_tmp, 2, ds5.biennial_id, ds5.gen_epa_id, ds5.approval_code),
	WASTE5_WC3 = EQ_Extract.dbo.fn_get_IL_biennial_waste_code (ds5.hz_pg_tmp, ds5.hz_ln_tmp, 3, ds5.biennial_id, ds5.gen_epa_id, ds5.approval_code),
	WASTE5_WC4 = EQ_Extract.dbo.fn_get_IL_biennial_waste_code (ds5.hz_pg_tmp, ds5.hz_ln_tmp, 4, ds5.biennial_id, ds5.gen_epa_id, ds5.approval_code),
	WASTE5_WC5 = EQ_Extract.dbo.fn_get_IL_biennial_waste_code (ds5.hz_pg_tmp, ds5.hz_ln_tmp, 5, ds5.biennial_id, ds5.gen_epa_id, ds5.approval_code),
	WASTE5_QTY = ds5.GEN_QUANTITY,
	WASTE5_UOM = ds5.UNIT_OF_MEASURE,
	WASTE5_DENSITY = ds5.WASTE_DENSITY,
	WASTE5_FORM_CODE = ds5.FORM_CODE,
	FILLER5 = space(1),
	WASTE5_SYS_TYPE = '',
	COMMENTS = 'N',
	FILLER6 = space(1)
	FROM
	EQ_Extract..BiennialReportWork_IL_WR1 wr1
		LEFT JOIN EQ_Extract..BiennialReportWork_IL_WR1 ds1 ON ds1.biennial_id = wr1.biennial_id
			and ds1.GEN_EPA_ID = wr1.GEN_EPA_ID
			-- and ds1.approval_code = wr1.approval_code
			and ds1.hz_pg_tmp = wr1.hz_pg_tmp
			and ds1.hz_ln_tmp = 1
	LEFT JOIN EQ_Extract..BiennialReportWork_IL_WR1 ds2 ON ds2.biennial_id = wr1.biennial_id
			and ds2.GEN_EPA_ID = wr1.GEN_EPA_ID
			-- and ds2.approval_code = wr1.approval_code
			and ds2.hz_pg_tmp = wr1.hz_pg_tmp
			and ds2.hz_ln_tmp = 2
	LEFT JOIN EQ_Extract..BiennialReportWork_IL_WR1 ds3 ON ds3.biennial_id = wr1.biennial_id
			and ds3.GEN_EPA_ID = wr1.GEN_EPA_ID
			-- and ds3.approval_code = wr1.approval_code
			and ds3.hz_pg_tmp = wr1.hz_pg_tmp
			and ds3.hz_ln_tmp = 3
	LEFT JOIN EQ_Extract..BiennialReportWork_IL_WR1 ds4 ON ds4.biennial_id = wr1.biennial_id
			and ds4.GEN_EPA_ID = wr1.GEN_EPA_ID
			-- and ds4.approval_code = wr1.approval_code
			and ds4.hz_pg_tmp = wr1.hz_pg_tmp
			and ds4.hz_ln_tmp = 4
	LEFT JOIN EQ_Extract..BiennialReportWork_IL_WR1 ds5 ON ds5.biennial_id = wr1.biennial_id
			and ds5.GEN_EPA_ID = wr1.GEN_EPA_ID
			-- and ds5.approval_code = wr1.approval_code
			and ds5.hz_pg_tmp = wr1.hz_pg_tmp
			and ds5.hz_ln_tmp = 5		
	WHERE wr1.hz_pg_tmp = 3
	and wr1.hz_ln_tmp = 1
	and wr1.biennial_id = @biennial_id

	union

	SELECT US_EPA_ID = WR1.EQ_EPA_ID,
	PAGE_NUM = wr1.hz_pg_tmp,
	FILLER0 = space(1),
	wr1.EQ_STATE_ID,
	GEN_US_EPA_ID = wr1.gen_epa_id,
	wr1.GEN_STATE_EPA_ID, --wr1.generator_state_id,
	ds4.approval_code,
	ds4.hz_pg_tmp,
	ds4.hz_ln_tmp,
	WASTE1_WC1 = EQ_Extract.dbo.fn_get_IL_biennial_waste_code (ds1.hz_pg_tmp, ds1.hz_ln_tmp, 1, ds1.biennial_id, ds1.gen_epa_id, ds1.approval_code),
	WASTE1_WC2 = EQ_Extract.dbo.fn_get_IL_biennial_waste_code (ds1.hz_pg_tmp, ds1.hz_ln_tmp, 2, ds1.biennial_id, ds1.gen_epa_id, ds1.approval_code),
	WASTE1_WC3 = EQ_Extract.dbo.fn_get_IL_biennial_waste_code (ds1.hz_pg_tmp, ds1.hz_ln_tmp, 3, ds1.biennial_id, ds1.gen_epa_id, ds1.approval_code),
	WASTE1_WC4 = EQ_Extract.dbo.fn_get_IL_biennial_waste_code (ds1.hz_pg_tmp, ds1.hz_ln_tmp, 4, ds1.biennial_id, ds1.gen_epa_id, ds1.approval_code),
	WASTE1_WC5 = EQ_Extract.dbo.fn_get_IL_biennial_waste_code (ds1.hz_pg_tmp, ds1.hz_ln_tmp, 5, ds1.biennial_id, ds1.gen_epa_id, ds1.approval_code),
	WASTE1_QTY = ds1.GEN_QUANTITY,
	WASTE1_UOM = ds1.UNIT_OF_MEASURE,
	WASTE1_DENSITY = ds1.WASTE_DENSITY,
	WASTE1_FORM_CODE = ds1.FORM_CODE,
	FILLER1 = space(1),
	ds1.MANAGEMENT_METHOD,
	WASTE2_WC1 = EQ_Extract.dbo.fn_get_IL_biennial_waste_code (ds2.hz_pg_tmp, ds2.hz_ln_tmp, 1, ds2.biennial_id, ds2.gen_epa_id, ds2.approval_code),
	WASTE2_WC2 = EQ_Extract.dbo.fn_get_IL_biennial_waste_code (ds2.hz_pg_tmp, ds2.hz_ln_tmp, 2, ds2.biennial_id, ds2.gen_epa_id, ds2.approval_code),
	WASTE2_WC3 = EQ_Extract.dbo.fn_get_IL_biennial_waste_code (ds2.hz_pg_tmp, ds2.hz_ln_tmp, 3, ds2.biennial_id, ds2.gen_epa_id, ds2.approval_code),
	WASTE2_WC4 = EQ_Extract.dbo.fn_get_IL_biennial_waste_code (ds2.hz_pg_tmp, ds2.hz_ln_tmp, 4, ds2.biennial_id, ds2.gen_epa_id, ds2.approval_code),
	WASTE2_WC5 = EQ_Extract.dbo.fn_get_IL_biennial_waste_code (ds2.hz_pg_tmp, ds2.hz_ln_tmp, 5, ds2.biennial_id, ds2.gen_epa_id, ds2.approval_code),
	WASTE2_QTY = ds2.GEN_QUANTITY,
	WASTE2_UOM = ds2.UNIT_OF_MEASURE,
	WASTE2_DENSITY = ds2.WASTE_DENSITY,
	WASTE2_FORM_CODE = ds2.FORM_CODE,
	FILLER2 = space(1),
	ds2.MANAGEMENT_METHOD,
	WASTE3_WC1 = EQ_Extract.dbo.fn_get_IL_biennial_waste_code (ds3.hz_pg_tmp, ds3.hz_ln_tmp, 1, ds3.biennial_id, ds3.gen_epa_id, ds3.approval_code),
	WASTE3_WC2 = EQ_Extract.dbo.fn_get_IL_biennial_waste_code (ds3.hz_pg_tmp, ds3.hz_ln_tmp, 2, ds3.biennial_id, ds3.gen_epa_id, ds3.approval_code),
	WASTE3_WC3 = EQ_Extract.dbo.fn_get_IL_biennial_waste_code (ds3.hz_pg_tmp, ds3.hz_ln_tmp, 3, ds3.biennial_id, ds3.gen_epa_id, ds3.approval_code),
	WASTE3_WC4 = EQ_Extract.dbo.fn_get_IL_biennial_waste_code (ds3.hz_pg_tmp, ds3.hz_ln_tmp, 4, ds3.biennial_id, ds3.gen_epa_id, ds3.approval_code),
	WASTE3_WC5 = EQ_Extract.dbo.fn_get_IL_biennial_waste_code (ds3.hz_pg_tmp, ds3.hz_ln_tmp, 5, ds3.biennial_id, ds3.gen_epa_id, ds3.approval_code),
	WASTE3_QTY = ds3.GEN_QUANTITY,
	WASTE3_UOM = ds3.UNIT_OF_MEASURE,
	WASTE3_DENSITY = ds3.WASTE_DENSITY,
	WASTE3_FORM_CODE = ds3.FORM_CODE,
	FILLER3 = space(1),
	ds3.MANAGEMENT_METHOD,
	WASTE4_WC1 = EQ_Extract.dbo.fn_get_IL_biennial_waste_code (ds4.hz_pg_tmp, ds4.hz_ln_tmp, 1, ds4.biennial_id, ds4.gen_epa_id, ds4.approval_code),
	WASTE4_WC2 = EQ_Extract.dbo.fn_get_IL_biennial_waste_code (ds4.hz_pg_tmp, ds4.hz_ln_tmp, 2, ds4.biennial_id, ds4.gen_epa_id, ds4.approval_code),
	WASTE4_WC3 = EQ_Extract.dbo.fn_get_IL_biennial_waste_code (ds4.hz_pg_tmp, ds4.hz_ln_tmp, 3, ds4.biennial_id, ds4.gen_epa_id, ds4.approval_code),
	WASTE4_WC4 = EQ_Extract.dbo.fn_get_IL_biennial_waste_code (ds4.hz_pg_tmp, ds4.hz_ln_tmp, 4, ds4.biennial_id, ds4.gen_epa_id, ds4.approval_code),
	WASTE4_WC5 = EQ_Extract.dbo.fn_get_IL_biennial_waste_code (ds4.hz_pg_tmp, ds4.hz_ln_tmp, 5, ds4.biennial_id, ds4.gen_epa_id, ds4.approval_code),
	WASTE4_QTY = ds4.GEN_QUANTITY,
	WASTE4_UOM = ds4.UNIT_OF_MEASURE,
	WASTE4_DENSITY = ds4.WASTE_DENSITY,
	WASTE4_FORM_CODE = ds4.FORM_CODE,
	FILLER4 = space(1),
	ds4.MANAGEMENT_METHOD,
	WASTE5_WC1 = EQ_Extract.dbo.fn_get_IL_biennial_waste_code (ds5.hz_pg_tmp, ds5.hz_ln_tmp, 1, ds5.biennial_id, ds5.gen_epa_id, ds5.approval_code),
	WASTE5_WC2 = EQ_Extract.dbo.fn_get_IL_biennial_waste_code (ds5.hz_pg_tmp, ds5.hz_ln_tmp, 2, ds5.biennial_id, ds5.gen_epa_id, ds5.approval_code),
	WASTE5_WC3 = EQ_Extract.dbo.fn_get_IL_biennial_waste_code (ds5.hz_pg_tmp, ds5.hz_ln_tmp, 3, ds5.biennial_id, ds5.gen_epa_id, ds5.approval_code),
	WASTE5_WC4 = EQ_Extract.dbo.fn_get_IL_biennial_waste_code (ds5.hz_pg_tmp, ds5.hz_ln_tmp, 4, ds5.biennial_id, ds5.gen_epa_id, ds5.approval_code),
	WASTE5_WC5 = EQ_Extract.dbo.fn_get_IL_biennial_waste_code (ds5.hz_pg_tmp, ds5.hz_ln_tmp, 5, ds5.biennial_id, ds5.gen_epa_id, ds5.approval_code),
	WASTE5_QTY = ds5.GEN_QUANTITY,
	WASTE5_UOM = ds5.UNIT_OF_MEASURE,
	WASTE5_DENSITY = ds5.WASTE_DENSITY,
	WASTE5_FORM_CODE = ds5.FORM_CODE,
	FILLER5 = space(1),
	WASTE5_SYS_TYPE = '',
	COMMENTS = 'N',
	FILLER6 = space(1)
	FROM
	EQ_Extract..BiennialReportWork_IL_WR1 wr1
		LEFT JOIN EQ_Extract..BiennialReportWork_IL_WR1 ds1 ON ds1.biennial_id = wr1.biennial_id
			and ds1.GEN_EPA_ID = wr1.GEN_EPA_ID
			-- and ds1.approval_code = wr1.approval_code
			and ds1.hz_pg_tmp = wr1.hz_pg_tmp
			and ds1.hz_ln_tmp = 1
	LEFT JOIN EQ_Extract..BiennialReportWork_IL_WR1 ds2 ON ds2.biennial_id = wr1.biennial_id
			and ds2.GEN_EPA_ID = wr1.GEN_EPA_ID
			-- and ds2.approval_code = wr1.approval_code
			and ds2.hz_pg_tmp = wr1.hz_pg_tmp
			and ds2.hz_ln_tmp = 2
	LEFT JOIN EQ_Extract..BiennialReportWork_IL_WR1 ds3 ON ds3.biennial_id = wr1.biennial_id
			and ds3.GEN_EPA_ID = wr1.GEN_EPA_ID
			-- and ds3.approval_code = wr1.approval_code
			and ds3.hz_pg_tmp = wr1.hz_pg_tmp
			and ds3.hz_ln_tmp = 3
	LEFT JOIN EQ_Extract..BiennialReportWork_IL_WR1 ds4 ON ds4.biennial_id = wr1.biennial_id
			and ds4.GEN_EPA_ID = wr1.GEN_EPA_ID
			-- and ds4.approval_code = wr1.approval_code
			and ds4.hz_pg_tmp = wr1.hz_pg_tmp
			and ds4.hz_ln_tmp = 4
	LEFT JOIN EQ_Extract..BiennialReportWork_IL_WR1 ds5 ON ds5.biennial_id = wr1.biennial_id
			and ds5.GEN_EPA_ID = wr1.GEN_EPA_ID
			-- and ds5.approval_code = wr1.approval_code
			and ds5.hz_pg_tmp = wr1.hz_pg_tmp
			and ds5.hz_ln_tmp = 5		
	WHERE wr1.hz_pg_tmp = 4
	and wr1.hz_ln_tmp = 1
	and wr1.biennial_id = @biennial_id

	UNION

	SELECT US_EPA_ID = WR1.EQ_EPA_ID,
	PAGE_NUM = wr1.hz_pg_tmp,
	FILLER0 = space(1),
	wr1.EQ_STATE_ID,
	GEN_US_EPA_ID = wr1.gen_epa_id,
	wr1.GEN_STATE_EPA_ID, --wr1.generator_state_id,
	ds5.approval_code,
	ds5.hz_pg_tmp,
	ds5.hz_ln_tmp,
	WASTE1_WC1 = EQ_Extract.dbo.fn_get_IL_biennial_waste_code (ds1.hz_pg_tmp, ds1.hz_ln_tmp, 1, ds1.biennial_id, ds1.gen_epa_id, ds1.approval_code),
	WASTE1_WC2 = EQ_Extract.dbo.fn_get_IL_biennial_waste_code (ds1.hz_pg_tmp, ds1.hz_ln_tmp, 2, ds1.biennial_id, ds1.gen_epa_id, ds1.approval_code),
	WASTE1_WC3 = EQ_Extract.dbo.fn_get_IL_biennial_waste_code (ds1.hz_pg_tmp, ds1.hz_ln_tmp, 3, ds1.biennial_id, ds1.gen_epa_id, ds1.approval_code),
	WASTE1_WC4 = EQ_Extract.dbo.fn_get_IL_biennial_waste_code (ds1.hz_pg_tmp, ds1.hz_ln_tmp, 4, ds1.biennial_id, ds1.gen_epa_id, ds1.approval_code),
	WASTE1_WC5 = EQ_Extract.dbo.fn_get_IL_biennial_waste_code (ds1.hz_pg_tmp, ds1.hz_ln_tmp, 5, ds1.biennial_id, ds1.gen_epa_id, ds1.approval_code),
	WASTE1_QTY = ds1.GEN_QUANTITY,
	WASTE1_UOM = ds1.UNIT_OF_MEASURE,
	WASTE1_DENSITY = ds1.WASTE_DENSITY,
	WASTE1_FORM_CODE = ds1.FORM_CODE,
	FILLER1 = space(1),
	ds1.MANAGEMENT_METHOD,
	WASTE2_WC1 = EQ_Extract.dbo.fn_get_IL_biennial_waste_code (ds2.hz_pg_tmp, ds2.hz_ln_tmp, 1, ds2.biennial_id, ds2.gen_epa_id, ds2.approval_code),
	WASTE2_WC2 = EQ_Extract.dbo.fn_get_IL_biennial_waste_code (ds2.hz_pg_tmp, ds2.hz_ln_tmp, 2, ds2.biennial_id, ds2.gen_epa_id, ds2.approval_code),
	WASTE2_WC3 = EQ_Extract.dbo.fn_get_IL_biennial_waste_code (ds2.hz_pg_tmp, ds2.hz_ln_tmp, 3, ds2.biennial_id, ds2.gen_epa_id, ds2.approval_code),
	WASTE2_WC4 = EQ_Extract.dbo.fn_get_IL_biennial_waste_code (ds2.hz_pg_tmp, ds2.hz_ln_tmp, 4, ds2.biennial_id, ds2.gen_epa_id, ds2.approval_code),
	WASTE2_WC5 = EQ_Extract.dbo.fn_get_IL_biennial_waste_code (ds2.hz_pg_tmp, ds2.hz_ln_tmp, 5, ds2.biennial_id, ds2.gen_epa_id, ds2.approval_code),
	WASTE2_QTY = ds2.GEN_QUANTITY,
	WASTE2_UOM = ds2.UNIT_OF_MEASURE,
	WASTE2_DENSITY = ds2.WASTE_DENSITY,
	WASTE2_FORM_CODE = ds2.FORM_CODE,
	FILLER2 = space(1),
	ds2.MANAGEMENT_METHOD,
	WASTE3_WC1 = EQ_Extract.dbo.fn_get_IL_biennial_waste_code (ds3.hz_pg_tmp, ds3.hz_ln_tmp, 1, ds3.biennial_id, ds3.gen_epa_id, ds3.approval_code),
	WASTE3_WC2 = EQ_Extract.dbo.fn_get_IL_biennial_waste_code (ds3.hz_pg_tmp, ds3.hz_ln_tmp, 2, ds3.biennial_id, ds3.gen_epa_id, ds3.approval_code),
	WASTE3_WC3 = EQ_Extract.dbo.fn_get_IL_biennial_waste_code (ds3.hz_pg_tmp, ds3.hz_ln_tmp, 3, ds3.biennial_id, ds3.gen_epa_id, ds3.approval_code),
	WASTE3_WC4 = EQ_Extract.dbo.fn_get_IL_biennial_waste_code (ds3.hz_pg_tmp, ds3.hz_ln_tmp, 4, ds3.biennial_id, ds3.gen_epa_id, ds3.approval_code),
	WASTE3_WC5 = EQ_Extract.dbo.fn_get_IL_biennial_waste_code (ds3.hz_pg_tmp, ds3.hz_ln_tmp, 5, ds3.biennial_id, ds3.gen_epa_id, ds3.approval_code),
	WASTE3_QTY = ds3.GEN_QUANTITY,
	WASTE3_UOM = ds3.UNIT_OF_MEASURE,
	WASTE3_DENSITY = ds3.WASTE_DENSITY,
	WASTE3_FORM_CODE = ds3.FORM_CODE,
	FILLER3 = space(1),
	ds3.MANAGEMENT_METHOD,
	WASTE4_WC1 = EQ_Extract.dbo.fn_get_IL_biennial_waste_code (ds4.hz_pg_tmp, ds4.hz_ln_tmp, 1, ds4.biennial_id, ds4.gen_epa_id, ds4.approval_code),
	WASTE4_WC2 = EQ_Extract.dbo.fn_get_IL_biennial_waste_code (ds4.hz_pg_tmp, ds4.hz_ln_tmp, 2, ds4.biennial_id, ds4.gen_epa_id, ds4.approval_code),
	WASTE4_WC3 = EQ_Extract.dbo.fn_get_IL_biennial_waste_code (ds4.hz_pg_tmp, ds4.hz_ln_tmp, 3, ds4.biennial_id, ds4.gen_epa_id, ds4.approval_code),
	WASTE4_WC4 = EQ_Extract.dbo.fn_get_IL_biennial_waste_code (ds4.hz_pg_tmp, ds4.hz_ln_tmp, 4, ds4.biennial_id, ds4.gen_epa_id, ds4.approval_code),
	WASTE4_WC5 = EQ_Extract.dbo.fn_get_IL_biennial_waste_code (ds4.hz_pg_tmp, ds4.hz_ln_tmp, 5, ds4.biennial_id, ds4.gen_epa_id, ds4.approval_code),
	WASTE4_QTY = ds4.GEN_QUANTITY,
	WASTE4_UOM = ds4.UNIT_OF_MEASURE,
	WASTE4_DENSITY = ds4.WASTE_DENSITY,
	WASTE4_FORM_CODE = ds4.FORM_CODE,
	FILLER4 = space(1),
	ds4.MANAGEMENT_METHOD,
	WASTE5_WC1 = EQ_Extract.dbo.fn_get_IL_biennial_waste_code (ds5.hz_pg_tmp, ds5.hz_ln_tmp, 1, ds5.biennial_id, ds5.gen_epa_id, ds5.approval_code),
	WASTE5_WC2 = EQ_Extract.dbo.fn_get_IL_biennial_waste_code (ds5.hz_pg_tmp, ds5.hz_ln_tmp, 2, ds5.biennial_id, ds5.gen_epa_id, ds5.approval_code),
	WASTE5_WC3 = EQ_Extract.dbo.fn_get_IL_biennial_waste_code (ds5.hz_pg_tmp, ds5.hz_ln_tmp, 3, ds5.biennial_id, ds5.gen_epa_id, ds5.approval_code),
	WASTE5_WC4 = EQ_Extract.dbo.fn_get_IL_biennial_waste_code (ds5.hz_pg_tmp, ds5.hz_ln_tmp, 4, ds5.biennial_id, ds5.gen_epa_id, ds5.approval_code),
	WASTE5_WC5 = EQ_Extract.dbo.fn_get_IL_biennial_waste_code (ds5.hz_pg_tmp, ds5.hz_ln_tmp, 5, ds5.biennial_id, ds5.gen_epa_id, ds5.approval_code),
	WASTE5_QTY = ds5.GEN_QUANTITY,
	WASTE5_UOM = ds5.UNIT_OF_MEASURE,
	WASTE5_DENSITY = ds5.WASTE_DENSITY,
	WASTE5_FORM_CODE = ds5.FORM_CODE,
	FILLER5 = space(1),
	WASTE5_SYS_TYPE = '',
	COMMENTS = 'N',
	FILLER6 = space(1)
	FROM
	EQ_Extract..BiennialReportWork_IL_WR1 wr1
		LEFT JOIN EQ_Extract..BiennialReportWork_IL_WR1 ds1 ON ds1.biennial_id = wr1.biennial_id
			and ds1.GEN_EPA_ID = wr1.GEN_EPA_ID
			-- and ds1.approval_code = wr1.approval_code
			and ds1.hz_pg_tmp = wr1.hz_pg_tmp
			and ds1.hz_ln_tmp = 1
	LEFT JOIN EQ_Extract..BiennialReportWork_IL_WR1 ds2 ON ds2.biennial_id = wr1.biennial_id
			and ds2.GEN_EPA_ID = wr1.GEN_EPA_ID
			-- and ds2.approval_code = wr1.approval_code
			and ds2.hz_pg_tmp = wr1.hz_pg_tmp
			and ds2.hz_ln_tmp = 2
	LEFT JOIN EQ_Extract..BiennialReportWork_IL_WR1 ds3 ON ds3.biennial_id = wr1.biennial_id
			and ds3.GEN_EPA_ID = wr1.GEN_EPA_ID
			-- and ds3.approval_code = wr1.approval_code
			and ds3.hz_pg_tmp = wr1.hz_pg_tmp
			and ds3.hz_ln_tmp = 3
	LEFT JOIN EQ_Extract..BiennialReportWork_IL_WR1 ds4 ON ds4.biennial_id = wr1.biennial_id
			and ds4.GEN_EPA_ID = wr1.GEN_EPA_ID
			-- and ds4.approval_code = wr1.approval_code
			and ds4.hz_pg_tmp = wr1.hz_pg_tmp
			and ds4.hz_ln_tmp = 4
	LEFT JOIN EQ_Extract..BiennialReportWork_IL_WR1 ds5 ON ds5.biennial_id = wr1.biennial_id
			and ds5.GEN_EPA_ID = wr1.GEN_EPA_ID
			-- and ds5.approval_code = wr1.approval_code
			and ds5.hz_pg_tmp = wr1.hz_pg_tmp
			and ds5.hz_ln_tmp = 5		
	WHERE wr1.hz_pg_tmp = 5 
	and wr1.hz_ln_tmp = 1
	and wr1.biennial_id = @biennial_id
	)
	 tbl 


	-- Number PAGE_NUM so it's meaningful:
	declare @i int = 1
	update #tmp set @i = PAGE_NUM = @i+1

	/* 
	the validation application requires a UOM to be entered
	regardless of whether or not there is waste in this slot
	
	2/29/2012 - Commented this out, seems to be causing problems. JPB

	update #tmp SET waste1_UOM = COALESCE(WASTE1_UOM, 2)
	update #tmp SET waste2_UOM = COALESCE(waste2_UOM, 2)
	update #tmp SET waste3_UOM = COALESCE(waste3_UOM, 2)
	update #tmp SET waste4_UOM = COALESCE(waste4_UOM, 2)
	update #tmp SET waste5_UOM = COALESCE(waste5_UOM, 2)

	*/

	-- output WR file
	IF EXISTS(SELECT 1 FROM @reports where report_name = 'WR1')
	begin
	

	if object_id('eq_temp..sp_biennial_report_output_extract_IL_WR1') is not null drop table eq_temp..sp_biennial_report_output_extract_IL_WR1
	
	select
	CONVERT(VARCHAR(280),
		EQ_Extract.dbo.fn_space_delimit(12, US_EPA_ID) + 
		EQ_Extract.dbo.fn_space_delimit('5R', PAGE_NUM) + 
		EQ_Extract.dbo.fn_space_delimit(3, FILLER0) + 
		EQ_Extract.dbo.fn_space_delimit(10, EQ_STATE_ID) + 
		EQ_Extract.dbo.fn_space_delimit(12, GEN_US_EPA_ID) + 
		EQ_Extract.dbo.fn_space_delimit(10, GEN_STATE_EPA_ID) + 
		-- approval_code + 
		-- hz_pg_tmp + 
		-- hz_ln_tmp + 
		EQ_Extract.dbo.fn_space_delimit(4, WASTE1_WC1) + 
		EQ_Extract.dbo.fn_space_delimit(4, WASTE1_WC2) + 
		EQ_Extract.dbo.fn_space_delimit(4, WASTE1_WC3) + 
		EQ_Extract.dbo.fn_space_delimit(4, WASTE1_WC4) + 
		EQ_Extract.dbo.fn_space_delimit(4, WASTE1_WC5) + 
		REPLACE(EQ_Extract.dbo.fn_space_delimit('10R', replace(convert(decimal(10,1), WASTE1_QTY), '.', '')), ' ', '0') + 
		EQ_Extract.dbo.fn_space_delimit(1, WASTE1_UOM) + 
		REPLACE(EQ_Extract.dbo.fn_space_delimit(4, replace(WASTE1_DENSITY, '.', '')), ' ', '0') + 
		EQ_Extract.dbo.fn_space_delimit(4, WASTE1_FORM_CODE) + 
		EQ_Extract.dbo.fn_space_delimit(2, FILLER1) + 
		EQ_Extract.dbo.fn_space_delimit(4, WASTE1_MANAGEMENT_METHOD) + 

		EQ_Extract.dbo.fn_space_delimit(4, WASTE2_WC1) + 
		EQ_Extract.dbo.fn_space_delimit(4, WASTE2_WC2) + 
		EQ_Extract.dbo.fn_space_delimit(4, WASTE2_WC3) + 
		EQ_Extract.dbo.fn_space_delimit(4, WASTE2_WC4) + 
		EQ_Extract.dbo.fn_space_delimit(4, WASTE2_WC5) + 
		REPLACE(EQ_Extract.dbo.fn_space_delimit('10R', replace(convert(decimal(10,1), WASTE2_QTY), '.', '')), ' ', '0') + 
		EQ_Extract.dbo.fn_space_delimit(1, WASTE2_UOM) + 
		REPLACE(EQ_Extract.dbo.fn_space_delimit(4, replace(WASTE2_DENSITY, '.', '')), ' ', '0') + 
		EQ_Extract.dbo.fn_space_delimit(4, WASTE2_FORM_CODE) + 
		EQ_Extract.dbo.fn_space_delimit(2, FILLER2) + 
		EQ_Extract.dbo.fn_space_delimit(4, WASTE2_MANAGEMENT_METHOD) + 

		EQ_Extract.dbo.fn_space_delimit(4, WASTE3_WC1) + 
		EQ_Extract.dbo.fn_space_delimit(4, WASTE3_WC2) + 
		EQ_Extract.dbo.fn_space_delimit(4, WASTE3_WC3) + 
		EQ_Extract.dbo.fn_space_delimit(4, WASTE3_WC4) + 
		EQ_Extract.dbo.fn_space_delimit(4, WASTE3_WC5) + 
		REPLACE(EQ_Extract.dbo.fn_space_delimit('10R', replace(convert(decimal(10,1), WASTE3_QTY), '.', '')), ' ', '0') + 
		EQ_Extract.dbo.fn_space_delimit(1, WASTE3_UOM) + 
		REPLACE(EQ_Extract.dbo.fn_space_delimit(4, replace(WASTE3_DENSITY, '.', '')), ' ', '0') + 
		EQ_Extract.dbo.fn_space_delimit(4, WASTE3_FORM_CODE) + 
		EQ_Extract.dbo.fn_space_delimit(2, FILLER3) + 
		EQ_Extract.dbo.fn_space_delimit(4, WASTE3_MANAGEMENT_METHOD) + 

		EQ_Extract.dbo.fn_space_delimit(4, WASTE4_WC1) + 
		EQ_Extract.dbo.fn_space_delimit(4, WASTE4_WC2) + 
		EQ_Extract.dbo.fn_space_delimit(4, WASTE4_WC3) + 
		EQ_Extract.dbo.fn_space_delimit(4, WASTE4_WC4) + 
		EQ_Extract.dbo.fn_space_delimit(4, WASTE4_WC5) + 
		REPLACE(EQ_Extract.dbo.fn_space_delimit('10R', replace(convert(decimal(10,1), WASTE4_QTY), '.', '')), ' ', '0') + 
		EQ_Extract.dbo.fn_space_delimit(1, WASTE4_UOM) + 
		REPLACE(EQ_Extract.dbo.fn_space_delimit(4, replace(WASTE4_DENSITY, '.', '')), ' ', '0') + 
		EQ_Extract.dbo.fn_space_delimit(4, WASTE4_FORM_CODE) + 
		EQ_Extract.dbo.fn_space_delimit(2, FILLER4) + 
		EQ_Extract.dbo.fn_space_delimit(4, WASTE4_MANAGEMENT_METHOD) + 

		EQ_Extract.dbo.fn_space_delimit(4, WASTE5_WC1) + 
		EQ_Extract.dbo.fn_space_delimit(4, WASTE5_WC2) + 
		EQ_Extract.dbo.fn_space_delimit(4, WASTE5_WC3) + 
		EQ_Extract.dbo.fn_space_delimit(4, WASTE5_WC4) + 
		EQ_Extract.dbo.fn_space_delimit(4, WASTE5_WC5) + 
		REPLACE(EQ_Extract.dbo.fn_space_delimit('10R', replace(convert(decimal(10,1), WASTE5_QTY), '.', '')), ' ', '0') + 
		EQ_Extract.dbo.fn_space_delimit(1, WASTE5_UOM) + 
		REPLACE(EQ_Extract.dbo.fn_space_delimit(4, replace(WASTE5_DENSITY, '.', '')), ' ', '0') + 
		EQ_Extract.dbo.fn_space_delimit(4, WASTE5_FORM_CODE) + 
		EQ_Extract.dbo.fn_space_delimit(2, FILLER5) + 
		EQ_Extract.dbo.fn_space_delimit(4, WASTE5_MANAGEMENT_METHOD) + 

		EQ_Extract.dbo.fn_space_delimit(1, COMMENTS) + 
		EQ_Extract.dbo.fn_space_delimit(1, FILLER6)
	) as [Result]
	INTO eq_temp..sp_biennial_report_output_extract_IL_WR1
	from #tmp
	end

	if EXISTS(SELECT 1 FROM @reports where report_name = 'C')
	begin

		if object_id('eq_temp..sp_biennial_IL_WR1_comments') is not null drop table eq_temp..sp_biennial_IL_WR1_comments

		-- Create comments:
		select 
			#tmp.page_num,
			--#tmp.gen_us_epa_id, 
			--#tmp.approval_code, 
			--#tmp.hz_pg_tmp, 
			#tmp.hz_ln_tmp, 
			--ds.GEN_QUANTITY, 
			--ds.UNIT_OF_MEASURE, 
			--w2.sequence_id, 
			w2.EPA_WASTE_CODE
		INTO eq_temp..sp_biennial_IL_WR1_comments
		from #tmp 
		inner join (
			select 
			w2.GEN_EPA_ID, 
			w2.approval_code, 
			w2.hz_pg_tmp, 
			w2.hz_ln_tmp,
			count(sequence_id) as waste_code_count
			from #tmp t
			inner join EQ_Extract..BiennialReportWork_IL_WR2 w2
			on t.gen_us_epa_id = w2.gen_epa_id
			and t.approval_code = w2.approval_code
			and t.hz_pg_tmp = w2.hz_pg_tmp
			and t.hz_ln_tmp = w2.hz_ln_tmp
			group by
			w2.GEN_EPA_ID, 
			w2.approval_code, 
			w2.hz_pg_tmp, 
			w2.hz_ln_tmp
			having count(sequence_id) > 5
		) tmp_count
			ON 	#tmp.GEN_US_EPA_ID = tmp_count.GEN_EPA_ID
			and #tmp.approval_code = tmp_count.approval_code
			and #tmp.hz_pg_tmp = tmp_count.hz_pg_tmp
			and #tmp.hz_ln_tmp = tmp_count.hz_ln_tmp
		inner join EQ_Extract..BiennialReportWork_IL_WR1 ds ON 
				ds.GEN_EPA_ID = #tmp.GEN_US_EPA_ID
				and ds.approval_code = #tmp.approval_code
				and ds.hz_pg_tmp = #tmp.hz_pg_tmp
				and ds.hz_ln_tmp = #tmp.hz_ln_tmp
		inner join EQ_Extract..BiennialReportWork_IL_WR2 w2
			on #tmp.gen_us_epa_id = w2.gen_epa_id
			and #tmp.approval_code = w2.approval_code
			and #tmp.hz_pg_tmp = w2.hz_pg_tmp
			and #tmp.hz_ln_tmp = w2.hz_ln_tmp
			and w2.sequence_id > 5
		where ds.biennial_id = @biennial_id
	end

	
END


END



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_biennial_report_output_extract_IL] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_biennial_report_output_extract_IL] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_biennial_report_output_extract_IL] TO [EQAI]
    AS [dbo];

*/
