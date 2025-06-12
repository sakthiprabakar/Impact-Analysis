
create procedure sp_biennial_report_output_extract
	@biennial_id		int,
	@state				varchar(2),
	@report_to_output	varchar(20), /* Values: GM1, GM2, GM4, OI, WR1, WR2, PS */
	@fill_from_source	varchar(1) = 'F',
	@debug				int = 0
as

/* **************************************************************************************
sp_biennial_report_output_extract

	Created to neutralize state-specific versions based on OH.
	Includes build & validation outputs, THEN file outputs.

-- The purpose of this script is to create the flat files for electronic submission of 
	the 2010 Biennial Report to the EPA
-- Run these one a time and save the results as the flat file
-- SET THE RESULTS OPTION TO ALLOW 600 CHARACTERS ON THE OUTPUT LINE

History:
	02/09/2012	JPB	Created
	12/25/2023  JPB	Modified to just select results out, plus extra recordset of result names.
	
Example:

	exec sp_biennial_report_output_extract 1580, 'OH', 'WR1', 'T', 1
	exec sp_biennial_report_output_extract 1580, 'OH', 'WR2', 'T', 1

	
	SELECT * FROM ##sp_biennial_report_output_extract_WR1 where report like '%PADEP0016503%'
	SELECT * FROM ##sp_biennial_report_output_extract_WR2  where report like '%00093%'
		
	
************************************************************************************** */
if @debug > 0 select getdate(), 'Started'

SET NOCOUNT ON

DECLARE @reports TABLE (report_name varchar(20))

INSERT INTO @reports
	SELECT row FROM dbo.fn_splitxsvtext(',', 1, @report_to_output) WHERE Isnull(row, '') <> ''

if @fill_from_source = 'T'
begin
	-- clear out old data
	
	delete from EQ_Extract..BiennialReportWork_GM1 where biennial_id <> @biennial_id
	delete from EQ_Extract..BiennialReportWork_GM2 where biennial_id <> @biennial_id
	delete from EQ_Extract..BiennialReportWork_GM3 where biennial_id <> @biennial_id
	delete from EQ_Extract..BiennialReportWork_GM4 where biennial_id <> @biennial_id
	delete from EQ_Extract..BiennialReportWork_OI where biennial_id <> @biennial_id
	delete from EQ_Extract..BiennialReportWork_WR1 where biennial_id <> @biennial_id
	delete from EQ_Extract..BiennialReportWork_WR2 where biennial_id <> @biennial_id
	delete from EQ_Extract..BiennialReportWork_WR3 where biennial_id <> @biennial_id

/***********************************************************
	CREATE FILE DATA PHASE: Fill _GMn, _WRn, _OI tables with data from the built set (@biennial_id)
***********************************************************/
	if exists (select 1 from @reports where report_name like 'GM%')
		exec sp_biennial_report_output_GM @biennial_id, @state
	if exists (select 1 from @reports where report_name like 'WR%')
		exec sp_biennial_report_output_WR @biennial_id, @state
	if exists (select 1 from @reports where report_name like 'OI%')
		exec sp_biennial_report_output_OI @biennial_id, @state
end


declare @recordsetname table (
	recordsetnumber	int identity(1,1),
	recordsetname varchar(30)
)

/*************************************************************
	COLLECT OUTPUT FIELDS INTO TEMP TABLES FOR EXTRACTING
*************************************************************/
if EXISTS(SELECT 1 FROM @reports where report_name = 'GM1')
BEGIN
	---------------------
	-- GM1	<name>.G19
	---------------------
		SELECT
		HANDLER_ID +
		HZ_PG +
		FORM_CODE +
		UNIT_OF_MEASURE +
		WST_DENSITY +
		DENSITY_UNIT_OF_MEASURE +
		ORIGIN_MANAGEMENT_METHOD +
		WASTE_MINIMIZATION_CODE +
		SOURCE_CODE +
		GEN_QTY +
		INCLUDE_IN_NATIONAL_REPORT +
		DESCRIPTION +
		NOTES +
		ON_SITE_MANAGEMENT +
		OFF_SITE_SHIPMENT as [Report]
		-- INTO ##sp_biennial_report_output_extract_GM1
		FROM EQ_Extract..BiennialReportWork_GM1
		WHERE biennial_id = @biennial_id
		ORDER BY 
		HANDLER_ID,
		HZ_PG

		insert @recordsetname (recordsetname) values ('GM1')

end

if EXISTS(SELECT 1 FROM @reports where report_name = 'GM2')	
begin
	---------------------
	-- GM2	<name>.G29
	---------------------
	SELECT 
	HANDLER_ID +
	HZ_PG +
	EPA_WASTE_CODE as [Report]
	-- INTO ##sp_biennial_report_output_extract_GM2
	FROM EQ_Extract..BiennialReportWork_GM2
	WHERE biennial_id = @biennial_id
	ORDER BY 
	HANDLER_ID,
	HZ_PG,
	EPA_WASTE_CODE

	insert @recordsetname (recordsetname) values ('GM2')
		
END

if EXISTS(SELECT 1 FROM @reports where report_name = 'GM3')	
begin
	---------------------
	-- GM3	<name>.G39
	---------------------
	SELECT 
	HANDLER_ID +
	HZ_PG +
	STATE_WASTE_CODE as [Report]
	-- INTO ##sp_biennial_report_output_extract_GM3
	FROM EQ_Extract..BiennialReportWork_GM3
	WHERE biennial_id = @biennial_id
	ORDER BY 
	HANDLER_ID,
	HZ_PG,
	STATE_WASTE_CODE

	insert @recordsetname (recordsetname) values ('GM3')
		
END

if EXISTS(SELECT 1 FROM @reports where report_name = 'GM4')	
begin
	---------------------
	-- GM4	<name>.G49
	---------------------
	SELECT 
	HANDLER_ID +
	HZ_PG +
	IO_PG_NUM_SEQ +
	MANAGEMENT_METHOD +
	IO_TDR_ID +
	IO_TDR_QTY  as [Report]
	-- INTO ##sp_biennial_report_output_extract_GM4
	FROM EQ_Extract..BiennialReportWork_GM4
	WHERE biennial_id = @biennial_id
	ORDER BY
	HANDLER_ID,
	HZ_PG,
	IO_PG_NUM_SEQ	

	insert @recordsetname (recordsetname) values ('GM4')

end


if EXISTS(SELECT 1 FROM @reports where report_name = 'OI')
BEGIN
	---------------------
	-- OI1	<name>.O19 
	---------------------
	SELECT DISTINCT
	HANDLER_ID +
	OSITE_PGNUM +
	OFF_ID +
	WST_GEN_FLG +
	WST_TRNS_FLG +
	WST_TSDR_FLG +
	ONAME+
	O1STREET+
	O2STREET+
	OCITY+
	OSTATE+
	OZIP+
	CASE WHEN @state = 'OH' THEN '' ELSE LEFT(IsNull(NOTES,' ') + SPACE(240), 240) END as [Report]
	-- INTO ##sp_biennial_report_output_extract_OI
	FROM EQ_Extract..BiennialReportWork_OI
	WHERE biennial_id = @biennial_id
	ORDER BY
	HANDLER_ID +
	OSITE_PGNUM +
	OFF_ID +
	WST_GEN_FLG +
	WST_TRNS_FLG +
	WST_TSDR_FLG +
	ONAME+
	O1STREET+
	O2STREET+
	OCITY+
	OSTATE+
	OZIP+
	CASE WHEN @state = 'OH' THEN '' ELSE LEFT(IsNull(NOTES,' ') + SPACE(240), 240) END

	insert @recordsetname (recordsetname) values ('OI')

END

if EXISTS(SELECT 1 FROM @reports where report_name = 'WR1')
BEGIN
	---------------------
	-- WR1	<name>.R19
	---------------------
	/*
	-- PRE 2011 version
	SELECT 
	HANDLER_ID +
	HZ_PG +
	SUB_PG_NUM +
	FORM_CODE +
	UNIT_OF_MEASURE +
	WST_DENSITY +
	DENSITY_UNIT_OF_MEASURE +
	OBSOLETE_FIELD +			-- OHIO calls this field INCLUDE_IN_NATIONAL_REPORT and has a hard-coded 'Y' in it.
	MANAGEMENT_METHOD +
	IO_TDR_ID +
	IO_TDR_QTY +
	CASE @state 
		WHEN 'OH' THEN '' 
		ELSE INCLUDE_IN_NATIONAL_REPORT 
	END +
	CASE @state
		WHEN 'OH' THEN LEFT(IsNull(DESCRIPTION,' ') + SPACE(60), 60)
		ELSE LEFT(IsNull(DESCRIPTION,' ') + SPACE(240), 240)
	END +
	CASE @state 
		WHEN 'OH' THEN '' 
		ELSE LEFT(IsNull(NOTES,' ') + SPACE(240), 240)
	END	as [Report]
	-- INTO ##sp_biennial_report_output_extract_WR1
	FROM EQ_Extract..BiennialReportWork_WR1
	WHERE biennial_id = @biennial_id
	ORDER BY
	HANDLER_ID,
	HZ_PG,
	SUB_PG_NUM  
	
	
	-- 2011 EPA Spec Version:
	*/
	SELECT 
	HANDLER_ID +
	HZ_PG +
	SUB_PG_NUM +
	FORM_CODE +
	UNIT_OF_MEASURE +
	WST_DENSITY +
	DENSITY_UNIT_OF_MEASURE +
	INCLUDE_IN_NATIONAL_REPORT +	
	MANAGEMENT_METHOD +
	IO_TDR_ID +
	IO_TDR_QTY +
	CASE @state
		WHEN 'OH' THEN LEFT(IsNull(DESCRIPTION,' ') + SPACE(60), 60)
		ELSE LEFT(IsNull(DESCRIPTION,' ') + SPACE(240), 240)
	END +
	CASE @state 
		WHEN 'OH' THEN '' 
		ELSE LEFT(IsNull(NOTES,' ') + SPACE(240), 240)
	END	as [Report]
	-- INTO ##sp_biennial_report_output_extract_WR1
	FROM EQ_Extract..BiennialReportWork_WR1
	WHERE biennial_id = @biennial_id
	ORDER BY
	HANDLER_ID,
	HZ_PG,
	SUB_PG_NUM  	

	insert @recordsetname (recordsetname) values ('WR1')

END

if EXISTS(SELECT 1 FROM @reports where report_name = 'WR2')	
begin
	---------------------
	-- WR2	<name>.R29
	---------------------
	SELECT 
	HANDLER_ID +
	HZ_PG +
	SUB_PG_NUM +
	EPA_WASTE_CODE  as [Report]
	-- INTO ##sp_biennial_report_output_extract_WR2
	FROM EQ_Extract..BiennialReportWork_WR2
	WHERE biennial_id = @biennial_id
	ORDER BY 
	HANDLER_ID,
	HZ_PG,
	SUB_PG_NUM,
	EPA_WASTE_CODE	

	insert @recordsetname (recordsetname) values ('WR2')

END

if EXISTS(SELECT 1 FROM @reports where report_name = 'WR3')	
begin
	---------------------
	-- WR3	<name>.R39
	---------------------
	SELECT 
	HANDLER_ID +
	HZ_PG +
	SUB_PG_NUM +
	STATE_WASTE_CODE  as [Report]
	-- INTO ##sp_biennial_report_output_extract_WR3
	FROM EQ_Extract..BiennialReportWork_WR3
	WHERE biennial_id = @biennial_id
	ORDER BY 
	HANDLER_ID,
	HZ_PG,
	SUB_PG_NUM,
	STATE_WASTE_CODE	

	insert @recordsetname (recordsetname) values ('WR3')

END


if EXISTS(SELECT 1 FROM @reports where report_name = 'PS')
BEGIN

	---------------------
	-- PS File
	/*
	"PS Form
	The Process Systems for Treatment, Disposal, or Recycling (PS) Form (EPA 9030) 
	captures the amount of waste commercially processed in each treatment, disposal, or 
	recycling system at facilities that submit WR Forms. Each management method reported in 
	WR records must have a corresponding PS Form. Because there is no federal file specification for 
	this form and the number of records is not large, commercial receiving facilities will directly 
	enter the PS Form(s) using the screens provided, after the import of the other records is complete."
	*/
	---------------------

	SELECT 'PS Form' as [PS Form], SUM(lbs_haz_estimated) as lbs_haz_estimated
	 ,management_code,
	 convert(varchar(200), CONVERT(DECIMAL(18, 3), SUM(ISNULL(lbs_haz_estimated,0)))) + ' ' + ISNULL(management_code,'NULL') as Report
	 -- INTO ##sp_biennial_report_output_extract_PS
	 FROM EQ_Extract..BiennialReportSourceData src
	 where src.biennial_id = @biennial_id
	group by management_code	

	insert @recordsetname (recordsetname) values ('PS')
	
END	

SELECT  * FROM    @recordsetname


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_biennial_report_output_extract] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_biennial_report_output_extract] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_biennial_report_output_extract] TO [EQAI]
    AS [dbo];

