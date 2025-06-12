
drop proc if exists sp_biennial_report_output_extract_OH
go


CREATE PROCEDURE sp_biennial_report_output_extract_OH
	@biennial_id int,
	@report_to_output varchar(60), /* Values: GM1, GM2, GM4, OI, WR1, WR2, PS */
	@fill_from_source_table varchar(1) = 'F'
	
AS

/*
	
	Usage: 
		exec sp_biennial_report_output_extract_OH 230, 'OI', 'F'
		exec sp_biennial_report_output_extract_OH 1, 'WR1'
		exec sp_biennial_report_output_extract_OH 1, 'WR2'
	
SELECT DISTINCT biennial_id, company FROM EQ_Extract..biennialLog
order by biennial_id

	12/25/2023  JPB	Modified to just select results out, plus extra recordset of result names.

*/
BEGIN
SET NOCOUNT ON



if @fill_from_source_table = 'T'
begin
	-- clear out old data
	delete from EQ_Extract..BiennialReportWork_OH_GM1 where biennial_id <> @biennial_id
	delete from EQ_Extract..BiennialReportWork_OH_GM2 where biennial_id <> @biennial_id
	delete from EQ_Extract..BiennialReportWork_OH_GM4 where biennial_id <> @biennial_id
	delete from EQ_Extract..BiennialReportWork_OH_OI where biennial_id <> @biennial_id
	delete from EQ_Extract..BiennialReportWork_OH_WR1 where biennial_id <> @biennial_id
	delete from EQ_Extract..BiennialReportWork_OH_WR2 where biennial_id <> @biennial_id

	-- populate work table data for this run
	exec sp_biennial_report_output_OH_WR @biennial_id
	exec sp_biennial_report_output_OH_GM @biennial_id
	exec sp_biennial_report_output_OH_OI @biennial_id
end

--if object_id('eq_temp..sp_biennial_report_output_extract_OH_GM1') is not null drop table eq_temp..sp_biennial_report_output_extract_OH_GM1
--if object_id('eq_temp..sp_biennial_report_output_extract_OH_GM2') is not null drop table eq_temp..sp_biennial_report_output_extract_OH_GM2
--if object_id('eq_temp..sp_biennial_report_output_extract_OH_GM4')  is not null drop table eq_temp..sp_biennial_report_output_extract_OH_GM4
--if object_id('eq_temp..sp_biennial_report_output_extract_OH_OI') is not null drop table eq_temp..sp_biennial_report_output_extract_OH_OI
--if object_id('eq_temp..sp_biennial_report_output_extract_OH_WR1') is not null drop table eq_temp..sp_biennial_report_output_extract_OH_WR1
--if object_id('eq_temp..sp_biennial_report_output_extract_OH_WR2') is not null drop table eq_temp..sp_biennial_report_output_extract_OH_WR2
--if object_id('eq_temp..sp_biennial_report_output_extract_OH_PS') is not null drop table eq_temp..sp_biennial_report_output_extract_OH_PS

DECLARE @reports TABLE (report_name varchar(20))

INSERT INTO @reports
	SELECT row FROM dbo.fn_splitxsvtext(',', 1, @report_to_output) WHERE Isnull(row, '') <> ''

declare @recordsetname table (
	recordsetnumber	int identity(1,1),
	recordsetname varchar(30)
)

-------------------------------------------------------------------------------------------------------------------------------
-- The purpose of this script is to create the flat files for electronic submission of the 2010 Biennial Report to the EPA
-- Run these one a time and save the results as the flat file
-- SET THE RESULTS OPTION TO ALLOW 600 CHARACTERS ON THE OUTPUT LINE
-------------------------------------------------------------------------------------------------------------------------------

if EXISTS(SELECT 1 FROM @reports where report_name = 'Validation')
BEGIN
	exec sp_biennial_validate @biennial_id
	insert @recordsetname (recordsetname) values ('Validation.csv')
END

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
		-- INTO eq_temp..sp_biennial_report_output_extract_OH_GM1
		FROM EQ_Extract..BiennialReportWork_OH_GM1
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
	-- INTO eq_temp..sp_biennial_report_output_extract_OH_GM2
	FROM EQ_Extract..BiennialReportWork_OH_GM2
	WHERE biennial_id = @biennial_id
	ORDER BY 
	HANDLER_ID,
	HZ_PG,
	EPA_WASTE_CODE

	insert @recordsetname (recordsetname) values ('GM2')
		
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
	-- INTO eq_temp..sp_biennial_report_output_extract_OH_GM4
	FROM EQ_Extract..BiennialReportWork_OH_GM4
	WHERE biennial_id = @biennial_id
	ORDER BY
	HANDLER_ID,
	HZ_PG,
	IO_PG_NUM_SEQ	

	insert @recordsetname (recordsetname) values ('GM3')

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
	ONAME +
	O1STREET +
	O2STREET +
	OCITY +
	OSTATE +
	OZIP  as [Report]
	-- INTO eq_temp..sp_biennial_report_output_extract_OH_OI
	FROM EQ_Extract..BiennialReportWork_OH_OI
	WHERE biennial_id = @biennial_id
	ORDER BY
	HANDLER_ID +
	OSITE_PGNUM +
	OFF_ID +
	WST_GEN_FLG +
	WST_TRNS_FLG +
	WST_TSDR_FLG +
	ONAME +
	O1STREET +
	O2STREET +
	OCITY +
	OSTATE +
	OZIP

	insert @recordsetname (recordsetname) values ('OI')

END

if EXISTS(SELECT 1 FROM @reports where report_name = 'WR1')
BEGIN
	---------------------
	-- WR1	<name>.R19
	---------------------
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
	DESCRIPTION   as [Report]
	-- INTO eq_temp..sp_biennial_report_output_extract_OH_WR1
	FROM EQ_Extract..BiennialReportWork_OH_WR1
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
	-- INTO eq_temp..sp_biennial_report_output_extract_OH_WR2
	FROM EQ_Extract..BiennialReportWork_OH_WR2
	WHERE biennial_id = @biennial_id
	ORDER BY 
	HANDLER_ID,
	HZ_PG,
	SUB_PG_NUM,
	EPA_WASTE_CODE	
	
	insert @recordsetname (recordsetname) values ('WR2')

	
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
	 -- INTO eq_temp..sp_biennial_report_output_extract_OH_PS
	 FROM EQ_Extract..BiennialReportSourceData src
	 where src.biennial_id = @biennial_id
	group by management_code	

	insert @recordsetname (recordsetname) values ('PS')
	
END	

SELECT  * FROM    @recordsetname
	
END


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_biennial_report_output_extract_OH] TO [EQWEB]

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_biennial_report_output_extract_OH] TO [COR_USER]


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_biennial_report_output_extract_OH] TO [EQAI]

